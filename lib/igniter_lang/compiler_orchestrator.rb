# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"

require "set"
require_relative "assembler"
require_relative "classifier"
require_relative "compilation_report"
require_relative "contract_call_sugar"
require_relative "const_resolver"
require_relative "derived_constructor_sugar"
require_relative "compiler_profile_contract_validator"
require_relative "compiler_result"
require_relative "multifile_resolver"
require_relative "parser"
require_relative "semanticir_emitter"
require_relative "typechecker"
require_relative "version"

module IgniterLang
  class CompilerOrchestrator
    FORMAT_VERSION = SemanticIREmitter::FORMAT_VERSION
    STRICT_REQUIREMENT_KIND = "compiler_profile_contract_strict_requirement"
    STRICT_REQUIREMENT_MODE = "strict_contract_digest"
    CONTRACT_DIGEST_MISMATCH_CODE =
      "compiler_profile_contract.contract_digest_mismatch"
    CONTRACT_DIGEST_REFUSAL_CODE =
      "compiler_profile_contract_refusal.contract_digest_mismatch"
    STRICT_REQUIREMENT_MALFORMED_CODE =
      "compiler_profile_contract_refusal.strict_requirement_malformed"
    STRICT_REQUIREMENT_SOURCES = ["proof_local_gate", "internal_test_seam"].freeze
    # Covenant CR-004: canon compiles a flat source unit and resolves module/import
    # names; it does NOT evaluate package policy (exports-sealing / lock / .igpkg).
    # This advisory is purely additive — it does not alter the verdict, status, or
    # any diagnostic code. It exists so a successful flat-list compile is not read
    # as package permission (see LANG-PACKAGE-TOOLING-BOUNDARY-DOC-P2 / FRUT-P11).
    PACKAGE_POLICY_ADVISORY =
      "compiled as a flat unit; package policy (exports/lock) NOT checked — " \
      "use the project toolchain for sealing/lock (Covenant CR-004)"

    def initialize(
      classifier: Classifier.new,
      typechecker: TypeChecker.new,
      emitter: SemanticIREmitter.new,
      assembler: Assembler.new,
      compiler_profile_contract_provider: nil,
      compiler_profile_contract_strict_requirement: nil
    )
      @classifier = classifier
      @typechecker = typechecker
      @emitter = emitter
      @assembler = assembler
      @compiler_profile_contract_provider = compiler_profile_contract_provider
      @compiler_profile_contract_strict_requirement = compiler_profile_contract_strict_requirement
    end

    def compile(
      source_path:,
      out_path:,
      sample_input: nil,
      sample_input_resolver: nil,
      runtime_smoke: nil,
      compiler_profile_source: nil
    )
      source_path = Pathname.new(source_path)
      out_path = Pathname.new(out_path)
      parsed = ParsedProgram.parse(File.read(source_path, encoding: "utf-8"), source_path: source_path.to_s).to_h
      parsed["parse_errors"].concat(ConstResolver.resolve_single!(parsed)) if parsed.fetch("parse_errors").empty?
      return parse_failure(parsed, source_path, out_path) unless parsed.fetch("parse_errors").empty?

      # LANG-STDLIB-IMPORT-VALIDATION-FLAT-PARITY-P1 (FRUT-P07 / IGDB-P08 residual):
      # flat single-file compiles used to accept bogus stdlib imports silently while
      # the multifile path failed closed (OOF-IMP2/OOF-IMP3). Validate stdlib.*
      # imports here with the SAME inventory-derived table as the multifile path.
      stdlib_import_diags = MultifileResolver.new.flat_stdlib_import_diagnostics(parsed)
      unless stdlib_import_diags.empty?
        report = flat_import_validation_failure_report(parsed, stdlib_import_diags)
        return refusal(report, source_path, out_path, status: "oof")
      end

      compile_parsed(
        parsed: parsed,
        source_path: source_path,
        out_path: out_path,
        sample_input: sample_input,
        sample_input_resolver: sample_input_resolver,
        runtime_smoke: runtime_smoke,
        compiler_profile_source: compiler_profile_source,
        source_units: nil
      )
    rescue AssemblyRefused => e
      report = CompilationReport.internal_error(
        format_version: FORMAT_VERSION,
        source_path: source_path,
        rule: "assembler_refused",
        error: e
      )
      refusal(report, source_path, out_path, status: "assembler_refused")
    rescue => e
      report = CompilationReport.internal_error(
        format_version: FORMAT_VERSION,
        source_path: source_path,
        rule: "compiler_error",
        error: e
      )
      refusal(report, source_path, out_path, status: "error")
    end

    def compile_sources(
      source_paths:,
      out_path:,
      sample_input: nil,
      sample_input_resolver: nil,
      runtime_smoke: nil,
      compiler_profile_source: nil
    )
      source_paths = Array(source_paths).map { |path| Pathname.new(path) }
      out_path = Pathname.new(out_path)
      return compile(
        source_path: source_paths.fetch(0),
        out_path: out_path,
        sample_input: sample_input,
        sample_input_resolver: sample_input_resolver,
        runtime_smoke: runtime_smoke,
        compiler_profile_source: compiler_profile_source
      ) if source_paths.length == 1

      resolved = MultifileResolver.new.resolve(source_paths)
      unless resolved.fetch("ok")
        report = multifile_resolution_failure_report(resolved)
        return refusal(report, Pathname.new(resolved.fetch("source_path")), out_path, status: "oof")
      end

      parsed = resolved.fetch("parsed_program")
      source_path = Pathname.new(parsed.fetch("source_path"))
      return parse_failure(parsed, source_path, out_path) unless parsed.fetch("parse_errors").empty?

      result = compile_parsed(
        parsed: parsed,
        source_path: source_path,
        out_path: out_path,
        sample_input: sample_input,
        sample_input_resolver: sample_input_resolver,
        runtime_smoke: runtime_smoke,
        compiler_profile_source: compiler_profile_source,
        source_units: resolved.fetch("source_units"),
        cross_module_registry: resolved.fetch("cross_module_registry", {}),
        per_module_imports: resolved.fetch("per_module_imports", {}),
        per_contract_module: resolved.fetch("per_contract_module", {}),
        variant_arm_owners: resolved.fetch("variant_arm_owners", {})
      )
      # CR-004 anti-drift: surface ONE non-fatal advisory that a multi-file flat
      # unit was compiled without package-policy checks. Additive only — verdict,
      # status, and diagnostics are untouched.
      result["package_policy_advisory"] = PACKAGE_POLICY_ADVISORY if result.is_a?(Hash)
      result
    rescue AssemblyRefused => e
      report = CompilationReport.internal_error(
        format_version: FORMAT_VERSION,
        source_path: source_path || Pathname.new("multifile:error"),
        rule: "assembler_refused",
        error: e
      )
      refusal(report, source_path || Pathname.new("multifile:error"), out_path, status: "assembler_refused")
    rescue => e
      report = CompilationReport.internal_error(
        format_version: FORMAT_VERSION,
        source_path: source_path || Pathname.new("multifile:error"),
        rule: "compiler_error",
        error: e
      )
      refusal(report, source_path || Pathname.new("multifile:error"), out_path, status: "error")
    end

    # LAB-IGNITER-SOURCE-CHECK-HARNESS-P2: native, no-write validation of an
    # explicit source set through the same resolver, constructor/call-sugar,
    # classifier and typechecker order as compilation. Emitter and assembler
    # are intentionally not referenced by this path.
    def check_sources(source_paths:, executable_sha256: nil)
      source_paths = Array(source_paths).map { |path| Pathname.new(path) }
      if source_paths.empty?
        return source_check_error_receipt(
          requested_order: [],
          status: "input_error",
          exit_code: 2,
          message: "check_sources requires at least one source",
          executable_sha256: executable_sha256
        )
      end

      requested_order = source_paths.map(&:to_s)
      if source_paths.length == 1
        source_path = source_paths.fetch(0)
        source = source_path.read(encoding: "utf-8")
        parsed = ParsedProgram.parse(source, source_path: source_path.to_s).to_h
        parsed["parse_errors"].concat(ConstResolver.resolve_single!(parsed)) if parsed.fetch("parse_errors").empty?
        source_units = [
          {
            "source_path" => source_path.to_s,
            "module" => parsed.fetch("module", nil),
            "source_hash" => parsed.fetch("source_hash")
          }
        ]
        unless parsed.fetch("parse_errors").empty?
          return source_check_receipt(
            requested_order: requested_order,
            source_units: source_units,
            source_hash: parsed.fetch("source_hash"),
            status: "refused",
            exit_code: 1,
            stages: source_check_stages("error", "not_run", "not_run"),
            diagnostics: Diagnostics.from_parse_errors(parsed.fetch("parse_errors")),
            executable_sha256: executable_sha256
          )
        end
        stdlib_import_diags = MultifileResolver.new.flat_stdlib_import_diagnostics(parsed)
        unless stdlib_import_diags.empty?
          return source_check_receipt(
            requested_order: requested_order,
            source_units: source_units,
            source_hash: parsed.fetch("source_hash"),
            status: "refused",
            exit_code: 1,
            stages: source_check_stages("ok", "not_run", "not_run"),
            diagnostics: stdlib_import_diags,
            executable_sha256: executable_sha256
          )
        end
        resolution_context = {}
      else
        resolved = MultifileResolver.new.resolve(source_paths)
        unless resolved.fetch("ok")
          return source_check_receipt(
            requested_order: requested_order,
            source_units: resolved.fetch("source_units"),
            source_hash: resolved.fetch("source_hash"),
            status: "refused",
            exit_code: 1,
            stages: source_check_stages("ok", "not_run", "not_run"),
            diagnostics: resolved.fetch("diagnostics"),
            executable_sha256: executable_sha256
          )
        end
        parsed = resolved.fetch("parsed_program")
        source_units = resolved.fetch("source_units")
        resolution_context = {
          cross_module_registry: resolved.fetch("cross_module_registry", {}),
          per_module_imports: resolved.fetch("per_module_imports", {}),
          per_contract_module: resolved.fetch("per_contract_module", {}),
          variant_arm_owners: resolved.fetch("variant_arm_owners", {})
        }
      end

      check_parsed_sources(
        parsed: parsed,
        requested_order: requested_order,
        source_units: source_units,
        resolution_context: resolution_context,
        executable_sha256: executable_sha256
      )
    rescue Errno::ENOENT, Errno::EACCES => e
      source_check_error_receipt(
        requested_order: Array(source_paths).map(&:to_s),
        status: "input_error",
        exit_code: 2,
        message: e.message,
        executable_sha256: executable_sha256
      )
    rescue => e
      source_check_error_receipt(
        requested_order: Array(source_paths).map(&:to_s),
        status: "internal_error",
        exit_code: 3,
        message: "#{e.class}: #{e.message}",
        executable_sha256: executable_sha256
      )
    end

    private

    def check_parsed_sources(parsed:, requested_order:, source_units:, resolution_context:, executable_sha256:)
      DerivedConstructorSugar.lower!(parsed)
      unless parsed.fetch("parse_errors").empty?
        return source_check_receipt(
          requested_order: requested_order,
          source_units: source_units,
          source_hash: parsed.fetch("source_hash"),
          status: "refused",
          exit_code: 1,
          stages: source_check_stages("error", "not_run", "not_run"),
          diagnostics: Diagnostics.from_parse_errors(parsed.fetch("parse_errors")),
          executable_sha256: executable_sha256
        )
      end

      resolved_sample_input = resolve_sample_input(parsed, nil)
      ContractCallSugar.lower!(parsed)
      classified = @classifier.classify(parsed, sample_input: resolved_sample_input)
      typed = @typechecker.typecheck(classified, **resolution_context)
      diagnostics = typed.fetch("type_errors", [])
      clean = classified.fetch("oof_log", []).empty? && diagnostics.empty?
      source_check_receipt(
        requested_order: requested_order,
        source_units: source_units,
        source_hash: parsed.fetch("source_hash"),
        status: clean ? "clean" : "refused",
        exit_code: clean ? 0 : 1,
        stages: source_check_stages("ok", "ok", clean ? "ok" : "refused"),
        contract_ids: typed.fetch("contracts", []).map { |contract| contract.fetch("contract_id") },
        diagnostics: diagnostics,
        executable_sha256: executable_sha256
      )
    end

    def source_check_receipt(
      requested_order:,
      source_units:,
      source_hash:,
      status:,
      exit_code:,
      stages:,
      diagnostics:,
      executable_sha256:,
      contract_ids: []
    )
      {
        "kind" => "igniter_native_source_check_receipt",
        "format_version" => "0.1.0",
        "command" => "igc check",
        "toolchain" => "ruby_canon",
        "toolchain_identity" => {
          "version" => IgniterLang::VERSION,
          "revision" => ENV.fetch("IGNITER_LANG_GIT_REVISION", nil),
          "executable_sha256" => executable_sha256
        },
        "status" => status,
        "exit_code" => exit_code,
        "source_set" => {
          "requested_order" => requested_order,
          "resolved_units" => source_units.map do |unit|
            {
              "path" => unit.fetch("source_path", nil),
              "module" => unit.fetch("module", nil),
              "sha256" => unit.fetch("source_hash", nil)
            }
          end,
          "composite_sha256" => source_hash
        },
        "source_hash" => source_hash,
        "stages" => stages,
        "claim_scope" => "parse_classify_typecheck_only",
        "contract_ids" => contract_ids,
        "diagnostics" => diagnostics.map { |entry| source_check_diagnostic(entry) },
        "writes" => { "source" => [], "artifacts" => [], "reports" => [], "temporary" => [] }
      }
    end

    def source_check_error_receipt(requested_order:, status:, exit_code:, message:, executable_sha256:)
      {
        "kind" => "igniter_native_source_check_receipt",
        "format_version" => "0.1.0",
        "command" => "igc check",
        "toolchain" => "ruby_canon",
        "toolchain_identity" => {
          "version" => IgniterLang::VERSION,
          "revision" => ENV.fetch("IGNITER_LANG_GIT_REVISION", nil),
          "executable_sha256" => executable_sha256
        },
        "status" => status,
        "exit_code" => exit_code,
        "source_set" => {
          "requested_order" => requested_order,
          "resolved_units" => [],
          "composite_sha256" => nil
        },
        "source_hash" => nil,
        "stages" => source_check_stages("not_run", "not_run", "not_run"),
        "claim_scope" => "parse_classify_typecheck_only",
        "contract_ids" => [],
        "diagnostics" => [],
        "message" => message,
        "writes" => { "source" => [], "artifacts" => [], "reports" => [], "temporary" => [] }
      }
    end

    def source_check_stages(parse, classify, typecheck)
      {
        "parse" => parse,
        "classify" => classify,
        "typecheck" => typecheck,
        "emit" => "not_run",
        "assemble" => "not_run"
      }
    end

    def source_check_diagnostic(entry)
      diagnostic = Diagnostics.stringify_keys(entry)
      diagnostic["severity"] ||= "error"
      diagnostic["source_path"] = nil unless diagnostic.key?("source_path")
      diagnostic["line"] = nil unless diagnostic.key?("line")
      diagnostic["col"] = nil unless diagnostic.key?("col")
      diagnostic["help_ref"] =
        if diagnostic.fetch("rule", nil) == "TASSUMP-1"
          "canon:ch2-source-surface#assumption-blocks-prop-032"
        end
      diagnostic
    end

    def compile_parsed(
      parsed:,
      source_path:,
      out_path:,
      sample_input:,
      sample_input_resolver:,
      runtime_smoke:,
      compiler_profile_source:,
      source_units:,
      cross_module_registry: {},
      per_module_imports: {},
      per_contract_module: {},
      variant_arm_owners: {}
    )
      # LANG-DERIVED-RECORD-CONSTRUCTOR-P2: constructor declarations and named
      # invocations are whole-program syntax sugar. Lower after single-file parse
      # or multifile merge, before any classify/typecheck work and before natural
      # contract-call sugar sees the now-ordinary derived contracts.
      DerivedConstructorSugar.lower!(parsed)
      return parse_failure(parsed, source_path, out_path) unless parsed.fetch("parse_errors").empty?

      resolved_sample_input = sample_input || resolve_sample_input(parsed, sample_input_resolver)
      # LANG-CONTRACT-CALL-SUGAR-P6: desugar a bare visible-contract call `Name(args)` into the
      # static contract-call form BEFORE classify (logic + rewrite live in ContractCallSugar; parity
      # with the Rust call_sugar pass). Orchestrator stays surface-clean per SURFACE-05.
      ContractCallSugar.lower!(parsed)
      classified = @classifier.classify(parsed, sample_input: resolved_sample_input)
      typed = @typechecker.typecheck(classified,
        cross_module_registry: cross_module_registry,
        per_module_imports: per_module_imports,
        per_contract_module: per_contract_module,
        variant_arm_owners: variant_arm_owners
      )
      compilation = @emitter.emit_typed(typed)
      attach_source_units!(compilation, source_units)
      report = CompilationReport.enrich(
        report: compilation.fetch("compilation_report"),
        parsed: parsed,
        typed: typed
      )
      semantic_ir = compilation.fetch("semantic_ir")
      report_for_assembly = report

      if report.fetch("pass_result") == "ok"
        validation = compiler_profile_contract_validation(
          source_path: source_path,
          out_path: out_path,
          parsed_program: parsed,
          compiler_profile_source: compiler_profile_source
        )
        report = CompilationReport.with_compiler_profile_contract_validation(
          report: report,
          validation: validation
        )
      end

      return refusal(report, source_path, out_path) unless report.fetch("pass_result") == "ok"

      strict_terminal = compiler_profile_contract_strict_terminal(
        report: report,
        source_path: source_path
      )
      return strict_terminal if strict_terminal

      # PROP-036: compiler_profile_source is passed unchanged to the assembler.
      # The orchestrator is a transport boundary only — it does not derive, load,
      # discover, default, finalize, or validate profiles. Assembler validation
      # remains authoritative. Nil preserves legacy_optional behavior.
      assembled = @assembler.assemble_artifacts(
        case_name: case_name_for(source_path, parsed),
        report: report_for_assembly,
        semantic_ir: semantic_ir,
        target_dir: out_path,
        compiler_profile_source: compiler_profile_source
      )
      smoke = runtime_smoke&.call(out_path: out_path, sample_input: resolved_sample_input)

      if smoke && !smoke.fetch("trusted")
        smoke_report = CompilationReport.runtime_smoke_failure(
          report: report,
          smoke: smoke,
          source_path: source_path
        )
        return refusal(smoke_report, source_path, out_path, status: "runtime_smoke_failed")
      end

      {
        "status" => "ok",
        "result" => CompilerResult.ok(
          format_version: FORMAT_VERSION,
          semantic_ir: semantic_ir,
          source_path: source_path,
          report: report,
          igapp_path: out_path,
          contracts: assembled.fetch("contracts"),
          runtime_smoke: smoke
        ),
        "parsed_program" => parsed,
        "classified_program" => classified,
        "typed_program" => typed,
        "semantic_ir" => semantic_ir,
        "compilation_report" => report,
        "assembled" => assembled,
        "sample_input" => resolved_sample_input
      }
    end

    def attach_source_units!(compilation, source_units)
      return unless source_units

      # Guard: semantic_ir is nil when type errors blocked emission
      sir = compilation["semantic_ir"]
      sir["source_units"] = source_units if sir
      compilation.fetch("compilation_report")["source_units"] = source_units
    end

    def multifile_resolution_failure_report(resolved)
      digest = resolved.fetch("source_hash").delete_prefix("sha256:")[0, 16]
      {
        "kind" => "compilation_report",
        "format_version" => FORMAT_VERSION,
        "program_id" => "compilation_report/multifile_resolve/#{digest}",
        "grammar_version" => "igniter-v0",
        "source_hash" => resolved.fetch("source_hash"),
        "source_path" => resolved.fetch("source_path"),
        "source_units" => resolved.fetch("source_units"),
        "pass_result" => "oof",
        "stages" => {
          "parse" => "ok",
          "multifile_resolve" => "oof",
          "classify" => "skipped",
          "typecheck" => "skipped",
          "emit" => "skipped"
        },
        "diagnostics" => Diagnostics.enrich(
          resolved.fetch("diagnostics"),
          category: Diagnostics::CATEGORIES.fetch(:classified)
        ),
        "semantic_ir_ref" => nil
      }
    end

    # LANG-STDLIB-IMPORT-VALIDATION-FLAT-PARITY-P1: OOF report for a flat single-file
    # compile whose stdlib.* imports failed inventory validation. Shape mirrors the
    # Rust flat path (stages.import_validation = "oof") and the multifile failure
    # report (pass_result "oof", enriched diagnostics, emission skipped).
    def flat_import_validation_failure_report(parsed, diagnostics)
      source_hash = parsed.fetch("source_hash", nil) ||
                    "sha256:#{Digest::SHA256.hexdigest(parsed.fetch("source", "").to_s)}"
      digest = source_hash.delete_prefix("sha256:")[0, 16]
      {
        "kind" => "compilation_report",
        "format_version" => FORMAT_VERSION,
        "program_id" => "compilation_report/import_validation/#{digest}",
        "grammar_version" => parsed.fetch("grammar_version", "igniter-v0"),
        "source_hash" => source_hash,
        "source_path" => parsed.fetch("source_path", nil),
        "pass_result" => "oof",
        "stages" => {
          "parse" => "ok",
          "import_validation" => "oof",
          "classify" => "skipped",
          "typecheck" => "skipped",
          "emit" => "skipped"
        },
        "diagnostics" => Diagnostics.enrich(
          diagnostics,
          category: Diagnostics::CATEGORIES.fetch(:classified)
        ),
        "semantic_ir_ref" => nil
      }
    end

    def parse_failure(parsed, source_path, out_path)
      report = CompilationReport.parse_failure(
        format_version: FORMAT_VERSION,
        parsed: parsed,
        source_path: source_path
      )
      refusal(report, source_path, out_path, status: "error")
    end

    def refusal(report, source_path, out_path, status: "oof")
      report_path = report_path_for(out_path)
      write_json(report_path, report)
      {
        "status" => status,
        "result" => CompilerResult.refusal(
          format_version: FORMAT_VERSION,
          status: status,
          report: report,
          source_path: source_path,
          report_path: report_path
        ),
        "compilation_report" => report,
        "report_path" => report_path.to_s
      }
    end

    def report_path_for(out_path)
      raw = out_path.to_s
      if raw.end_with?(".igapp")
        Pathname.new(raw.delete_suffix(".igapp") + ".compilation_report.json")
      else
        Pathname.new("#{raw}.compilation_report.json")
      end
    end

    def write_json(path, value)
      FileUtils.mkdir_p(Pathname.new(path).dirname)
      File.write(path, "#{JSON.pretty_generate(value)}\n")
    end

    def compiler_profile_contract_validation(source_path:, out_path:, parsed_program:, compiler_profile_source:)
      return nil unless @compiler_profile_contract_provider.respond_to?(:call)

      contract = @compiler_profile_contract_provider.call(
        source_path: source_path,
        out_path: out_path,
        parsed_program: parsed_program,
        compiler_profile_source: compiler_profile_source
      )
      return nil unless contract.is_a?(Hash)

      CompilerProfileContractValidator.validate(contract)
    rescue
      nil
    end

    def compiler_profile_contract_strict_terminal(report:, source_path:)
      return nil if @compiler_profile_contract_strict_requirement.nil?

      requirement = validate_compiler_profile_contract_strict_requirement(
        @compiler_profile_contract_strict_requirement
      )
      unless requirement.fetch("valid")
        diagnostic = strict_requirement_malformed_diagnostic(
          requirement.fetch("reason")
        )
        return strict_configuration_error(
          report: report,
          source_path: source_path,
          diagnostic: diagnostic
        )
      end

      validation = report.fetch("compiler_profile_contract_validation", nil)
      return nil unless validation.is_a?(Hash)

      diagnostic_codes = Array(validation["diagnostic_codes"])
      return nil unless diagnostic_codes.include?(CONTRACT_DIGEST_MISMATCH_CODE)

      strict_refusal(
        report: report,
        source_path: source_path,
        diagnostic: contract_digest_mismatch_refusal_diagnostic
      )
    end

    def validate_compiler_profile_contract_strict_requirement(requirement)
      unless requirement.is_a?(Hash)
        return invalid_strict_requirement(
          "expected compiler_profile_contract_strict_requirement hash"
        )
      end

      unless requirement["kind"] == STRICT_REQUIREMENT_KIND
        return invalid_strict_requirement(
          "expected compiler_profile_contract_strict_requirement kind"
        )
      end
      unless requirement["mode"] == STRICT_REQUIREMENT_MODE
        return invalid_strict_requirement("unsupported strict requirement mode")
      end

      source = requirement["source"]
      unless STRICT_REQUIREMENT_SOURCES.include?(source)
        return invalid_strict_requirement("unsupported strict validation source")
      end

      candidates = Array(requirement["refusal_candidates"])
      unless candidates.include?(CONTRACT_DIGEST_MISMATCH_CODE)
        return invalid_strict_requirement("missing contract_digest_mismatch refusal candidate")
      end

      unless requirement["recompute_unavailable_policy"] == "fail_open_report_only"
        return invalid_strict_requirement("unsupported recompute_unavailable_policy")
      end

      unless requirement["compile_refusal_authorized"] == false
        return invalid_strict_requirement("compile_refusal_authorized marker must remain false")
      end

      { "valid" => true }
    end

    def invalid_strict_requirement(reason)
      { "valid" => false, "reason" => reason }
    end

    def strict_refusal(report:, source_path:, diagnostic:)
      {
        "status" => "refused",
        "result" => CompilerResult.strict_terminal(
          format_version: FORMAT_VERSION,
          status: "refused",
          report: report,
          source_path: source_path,
          diagnostics: [diagnostic]
        ),
        "compilation_report" => report
      }
    end

    def strict_configuration_error(report:, source_path:, diagnostic:)
      {
        "status" => "configuration_error",
        "result" => CompilerResult.strict_terminal(
          format_version: FORMAT_VERSION,
          status: "configuration_error",
          report: report,
          source_path: source_path,
          diagnostics: [diagnostic]
        ),
        "compilation_report" => report
      }
    end

    def contract_digest_mismatch_refusal_diagnostic
      {
        "code" => CONTRACT_DIGEST_REFUSAL_CODE,
        "message" => "Strict compiler profile contract validation refused compilation " \
                     "because contract_digest does not match canonical contract material.",
        "path" => "compiler_profile_contract_validation.contract_digest",
        "evidence_code" => CONTRACT_DIGEST_MISMATCH_CODE
      }
    end

    def strict_requirement_malformed_diagnostic(_reason)
      {
        "code" => STRICT_REQUIREMENT_MALFORMED_CODE,
        "message" => "Malformed strict compiler profile contract requirement produced " \
                     "configuration_error before assembly.",
        "path" => "compiler_profile_contract_strict_requirement",
        "evidence_code" => nil
      }
    end

    def resolve_sample_input(parsed, sample_input_resolver)
      return sample_input_resolver.call(parsed) if sample_input_resolver

      default_sample_input(parsed.fetch("contracts").fetch(0, {}))
    end

    def default_sample_input(contract)
      contract.fetch("body", []).each_with_object({}) do |node, inputs|
        next unless node.fetch("kind") == "input"

        inputs[node.fetch("name")] = sample_value_for(node.fetch("type_annotation"))
      end
    end

    def sample_value_for(type_annotation)
      type_name = if type_annotation.is_a?(Hash)
                    type_annotation.fetch("name", "Unknown")
                  else
                    type_annotation.to_s
                  end
      case type_name
      when "Integer" then 1
      when "Float" then 1.0
      when "Bool" then true
      when "String" then "synthetic"
      else {}
      end
    end

    def case_name_for(source_path, parsed)
      basename = File.basename(source_path.to_s, ".ig")
      return basename unless basename.empty?

      parsed.fetch("contracts").fetch(0).fetch("name").downcase
    end
  end
end
