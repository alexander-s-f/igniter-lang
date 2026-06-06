# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"

require_relative "assembler"
require_relative "classifier"
require_relative "compilation_report"
require_relative "compiler_profile_contract_validator"
require_relative "compiler_result"
require_relative "parser"
require_relative "semanticir_emitter"
require_relative "typechecker"

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
      parsed = ParsedProgram.parse(File.read(source_path), source_path: source_path.to_s).to_h
      return parse_failure(parsed, source_path, out_path) unless parsed.fetch("parse_errors").empty?

      resolved_sample_input = sample_input || resolve_sample_input(parsed, sample_input_resolver)
      classified = @classifier.classify(parsed, sample_input: resolved_sample_input)
      typed = @typechecker.typecheck(classified)
      compilation = @emitter.emit_typed(typed)
      report = CompilationReport.enrich(
        report: compilation.fetch("compilation_report"),
        parsed: parsed
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

    private

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
