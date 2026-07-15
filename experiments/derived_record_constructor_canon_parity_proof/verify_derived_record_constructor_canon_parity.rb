#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-DERIVED-RECORD-CONSTRUCTOR-P2 — dual-toolchain canon proof.
#
# This proof locks the structural constructor as source sugar only:
#
#   constructor PlanEmailSend -> (intent: EmailSendIntent)
#
# Before classify/typecheck it becomes the already-canonical signature-bound
# pure contract, and a visible bare named invocation becomes the already-
# canonical static call_contract. The proof deliberately consumes the Rust lab
# release binaries; it does not carry a second implementation.

require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "igniter_lang"
require "igniter_lang/compiler_orchestrator"

module DerivedRecordConstructorCanonParityProof
  module_function

  ROOT = Pathname.new(__dir__).join("../..").expand_path
  WORKSPACE = ROOT.join("..").expand_path
  LAB_ROOT = WORKSPACE.join("igniter-lab")
  RUST_BIN = LAB_ROOT.join("igniter-compiler/target/release/igniter_compiler")
  VM_BIN = LAB_ROOT.join("igniter-vm/target/release/igniter-vm")
  GOLDEN = Pathname.new(__dir__).join("golden/plan_email_send.normalized-contract-sir.json")

  CROSS_TOOLCHAIN_VOLATILE = %w[
    resolved_type modifier literal_type fragment fragment_class
    node_id capabilities effects contract_ref
  ].freeze

  PLAN_FIELD_TYPES = {
    "notification_id" => "String",
    "delivery_id" => "String",
    "event_id" => "String",
    "contract_digest" => "String",
    "from" => "String",
    "recipient" => "String",
    "subject" => "String",
    "body" => "String",
    "message_body_sha256" => "String",
    "correlation_id" => "String",
    "audit_context" => "AuditContext"
  }.freeze
  PLAN_FIELDS = PLAN_FIELD_TYPES.keys.freeze
  PLAN_INPUTS = {
    "notification_id" => "notification-1",
    "delivery_id" => "delivery-1",
    "event_id" => "event-1",
    "contract_digest" => "sha256:contract",
    "from" => "sender@example.test",
    "recipient" => "recipient@example.test",
    "subject" => "Subject",
    "body" => "Body",
    "message_body_sha256" => "sha256:body",
    "correlation_id" => "correlation-1",
    "audit_context" => {
      "actor_id" => "actor-1",
      "source" => "dispatch-proof"
    }
  }.freeze

  @checks = []
  @tmpdirs = []

  def plan_types
    <<~IG
      type AuditContext {
        actor_id: String
        source: String
      }

      type EmailSendIntent {
      #{PLAN_FIELD_TYPES.map { |name, type| "  #{name}: #{type}" }.join("\n")}
      }
    IG
  end

  def plan_params
    PLAN_FIELD_TYPES.map { |name, type| "  #{name}: #{type}" }.join(",\n")
  end

  def plan_inputs
    PLAN_FIELD_TYPES.map { |name, type| "  input #{name}: #{type}" }.join("\n")
  end

  def plan_record
    "{ #{PLAN_FIELDS.join(", ")} }"
  end

  PLAN_CONSTRUCTOR = lambda do
    <<~IG
      module Constructor.Proof

      #{plan_types}
      entrypoint PlanEmailSend
      constructor PlanEmailSend -> (intent: EmailSendIntent)
    IG
  end.call.freeze

  PLAN_COMPACT = lambda do
    <<~IG
      module Constructor.Proof

      #{plan_types}
      entrypoint PlanEmailSend
      pure contract PlanEmailSend(
      #{plan_params}
      ) -> (intent: EmailSendIntent) =
        #{plan_record}
    IG
  end.call.freeze

  PLAN_EXPLICIT = lambda do
    <<~IG
      module Constructor.Proof

      #{plan_types}
      entrypoint PlanEmailSend
      pure contract PlanEmailSend {
      #{plan_inputs}
        compute intent: EmailSendIntent = #{plan_record}
        output intent: EmailSendIntent
      }
    IG
  end.call.freeze

  SCRAMBLED_NAMED_FIELDS = [
    "audit_context: audit_context",
    "subject",
    "notification_id: notification_id",
    "from",
    "message_body_sha256: message_body_sha256",
    "recipient",
    "correlation_id",
    "body: body",
    "contract_digest",
    "event_id: event_id",
    "delivery_id"
  ].freeze

  CANONICAL_EXPLICIT_FIELDS = PLAN_FIELDS.map { |field| "#{field}: #{field}" }.freeze

  def plan_invoker_source(fields, module_name: "Constructor.Named")
    <<~IG
      module #{module_name}

      #{plan_types}
      constructor PlanEmailSend -> (intent: EmailSendIntent)
      entrypoint InvokePlanEmailSend

      pure contract InvokePlanEmailSend(
      #{plan_params}
      ) -> (intent: EmailSendIntent) =
        PlanEmailSend {
          #{fields.join(",\n    ")}
        }
    IG
  end

  NAMED_SCRAMBLED = plan_invoker_source(SCRAMBLED_NAMED_FIELDS).freeze
  NAMED_CANONICAL = plan_invoker_source(CANONICAL_EXPLICIT_FIELDS).freeze

  EXPLICIT_ESCAPE = lambda do
    <<~IG
      module Constructor.Escape

      #{plan_types}
      constructor PlanEmailSend -> (intent: EmailSendIntent)
      entrypoint EscapePlanEmailSend

      pure contract EscapePlanEmailSend(
      #{plan_params}
      ) -> (intent: EmailSendIntent) =
        call_contract(
          "PlanEmailSend",
          #{PLAN_FIELDS.join(",\n    ")}
        )
    IG
  end.call.freeze

  OOF_BASE = <<~IG.freeze
    module Constructor.OOF
    type Pair { left: String right: String }
  IG

  OOF_CASES = {
    ctor1_missing_output: {
      source: "module Constructor.OOF\nconstructor Bad\n",
      rule: "OOF-CTOR1",
      fragment: "must declare exactly one named record output"
    },
    ctor1_empty_output: {
      source: "module Constructor.OOF\nconstructor Bad -> ()\n",
      rule: "OOF-CTOR1",
      fragment: "must declare exactly one named record output"
    },
    ctor1_malformed_named_output: {
      source: "module Constructor.OOF\nconstructor Bad -> (out MissingRecord)\n",
      rule: "OOF-CTOR1",
      fragment: "must declare exactly one named record output"
    },
    ctor1_unknown: {
      source: "module Constructor.OOF\nconstructor Bad -> (out: MissingRecord)\n",
      rule: "OOF-CTOR1",
      fragment: "visible non-generic record type"
    },
    ctor1_non_record: {
      source: "module Constructor.OOF\nconstructor Bad -> (out: Collection[String])\n",
      rule: "OOF-CTOR1",
      fragment: "visible non-generic record type"
    },
    ctor1_zero_field: {
      source: "module Constructor.OOF\ntype Empty { }\nconstructor Bad -> (out: Empty)\n",
      rule: "OOF-CTOR1",
      fragment: "at least one field"
    },
    ctor1_recursive: {
      source: "module Constructor.OOF\ntype Node { next: Node }\nconstructor Bad -> (out: Node)\n",
      rule: "OOF-CTOR1",
      fragment: "recursive"
    },
    ctor2_body: {
      source: OOF_BASE + "constructor Bad -> (out: Pair) { }\n",
      rule: "OOF-CTOR2",
      fragment: "body-free"
    },
    ctor3_modifier: {
      source: OOF_BASE + "pure constructor Bad -> (out: Pair)\n",
      rule: "OOF-CTOR3",
      fragment: "only `constructor` is legal"
    },
    ctor4_positional: {
      source: OOF_BASE + <<~IG,
        constructor BuildPair -> (out: Pair)
        pure contract Use(left: String, right: String) -> (out: Pair) =
          BuildPair(left, right)
      IG
      rule: "OOF-CTOR4",
      fragment: "does not accept positional invocation"
    },
    ctor5_variant_ambiguity: {
      source: OOF_BASE + <<~IG,
        variant Choice { BuildPair { left: String right: String } }
        constructor BuildPair -> (out: Pair)
        pure contract Use(left: String, right: String) -> (out: Pair) =
          BuildPair { left, right }
      IG
      rule: "OOF-CTOR5",
      fragment: "ambiguous between a constructor and a variant arm"
    },
    ctor7_missing: {
      source: OOF_BASE + <<~IG,
        constructor BuildPair -> (out: Pair)
        pure contract Use(left: String) -> (out: Pair) = BuildPair { left }
      IG
      rule: "OOF-CTOR7",
      fragment: "missing required field(s): right"
    },
    ctor8_extra: {
      source: OOF_BASE + <<~IG,
        constructor BuildPair -> (out: Pair)
        pure contract Use(left: String, right: String) -> (out: Pair) =
          BuildPair { left, right, third: "third" }
      IG
      rule: "OOF-CTOR8",
      fragment: "unknown field(s): third"
    },
    duplicate_inherited: {
      source: OOF_BASE + <<~IG,
        constructor BuildPair -> (out: Pair)
        pure contract Use(left: String, right: String) -> (out: Pair) =
          BuildPair { left, left: left, right }
      IG
      rule: "OOF-P1",
      fragment: "duplicate field `left`"
    },
    wrong_type_inherited: {
      source: OOF_BASE + <<~IG,
        constructor BuildPair -> (out: Pair)
        pure contract Use(right: String) -> (out: Pair) =
          BuildPair { left: 1, right }
      IG
      rule: "OOF-TY0",
      fragment: "parameter 'left' expects String, got Integer"
    },
    multiple_outputs_inherited: {
      source: OOF_BASE + "constructor Bad -> (first: Pair, second: Pair)\n",
      rule: "OOF-RET1",
      fragment: "declares 2 outputs; a contract returns exactly one value"
    }
  }.freeze

  IMPORT_LIB = <<~IG.freeze
    module Constructor.Imported
    type ImportedPayload { value: String }
    constructor MakeImported -> (payload: ImportedPayload)
  IG

  IMPORT_USER = <<~IG.freeze
    module Constructor.ImportUser
    import Constructor.Imported.{ ImportedPayload, MakeImported }
    entrypoint UseImported
    pure contract UseImported(value: String) -> (payload: ImportedPayload) =
      MakeImported { value }
  IG

  QUALIFIED_CALL_USER = <<~IG.freeze
    module Constructor.QualifiedUser
    import Constructor.Imported.{ ImportedPayload, MakeImported }
    entrypoint UseQualified
    pure contract UseQualified(value: String) -> (payload: ImportedPayload) =
      call_contract("Constructor.Imported.MakeImported", value)
  IG

  QUALIFIED_ENTRYPOINT = <<~IG.freeze
    module Constructor.QualifiedEntrypoint
    type QualifiedPayload { value: String }
    entrypoint Constructor.QualifiedEntrypoint.MakeQualified
    constructor MakeQualified -> (payload: QualifiedPayload)
  IG

  AMBIG_LIB_A = <<~IG.freeze
    module Constructor.A
    type PayloadA { value: String }
    constructor Make -> (payload: PayloadA)
  IG

  AMBIG_LIB_B = <<~IG.freeze
    module Constructor.B
    type PayloadB { value: String }
    constructor Make -> (payload: PayloadB)
  IG

  AMBIG_USER = <<~IG.freeze
    module Constructor.AmbiguousUser
    import Constructor.A.{ Make }
    import Constructor.B.{ Make }
    pure contract Use(value: String) -> (out: String) = Make { value }
  IG

  SINGLE_VISIBLE_USER = <<~IG.freeze
    module Constructor.SingleVisible
    import Constructor.A.{ PayloadA, Make }
    entrypoint Use
    pure contract Use(value: String) -> (out: PayloadA) = Make { value }
  IG

  HIDDEN_VARIANT_USER = <<~IG.freeze
    module Constructor.HiddenVariant
    variant LocalChoice { Make { value: String } }
    entrypoint Use
    pure contract Use(value: String) -> (out: LocalChoice) = Make { value }
  IG

  HIDDEN_TARGET_LIB = <<~IG.freeze
    module Constructor.HiddenTarget
    type HiddenPayload { value: String }
  IG

  HIDDEN_TARGET_USER = <<~IG.freeze
    module Constructor.HiddenTargetUser
    constructor BuildHidden -> (out: HiddenPayload)
  IG

  DEF_PRECEDENCE = <<~IG.freeze
    module Constructor.DefPrecedence
    type BuiltRecord { value: Integer }
    constructor Build -> (out: BuiltRecord)
    def Build(value: Integer) -> Integer { value }
    entrypoint Use
    pure contract Use(value: Integer) -> (out: Integer) = Build(value)
  IG

  ORDER_AB = <<~IG.freeze
    module Constructor.Order
    type OrderedPair { left: String right: String }
    entrypoint BuildOrderedPair
    constructor BuildOrderedPair -> (out: OrderedPair)
  IG

  ORDER_BA = <<~IG.freeze
    module Constructor.Order
    type OrderedPair { right: String left: String }
    entrypoint BuildOrderedPair
    constructor BuildOrderedPair -> (out: OrderedPair)
  IG

  EVOLUTION_ADD_STALE_CALL = <<~IG.freeze
    module Constructor.Evolution
    type Evolving { left: String right: String added: String }
    constructor BuildEvolving -> (out: Evolving)
    pure contract Use(left: String, right: String) -> (out: Evolving) =
      BuildEvolving { left, right }
  IG

  def check(label)
    pass = !!yield
    @checks << [label, pass, nil]
    puts "#{pass ? 'PASS' : 'FAIL'}  #{label}"
  rescue StandardError => e
    @checks << [label, false, "#{e.class}: #{e.message}"]
    puts "FAIL  #{label}  [#{e.class}: #{e.message.lines.first&.strip}]"
  end

  def section(title)
    puts "\n== #{title} =="
  end

  def compile_pair(tag, sources)
    dir = Pathname.new(Dir.mktmpdir("derived_ctor_#{tag}_"))
    @tmpdirs << dir
    paths = sources.map do |name, body|
      path = dir.join(name)
      FileUtils.mkdir_p(path.dirname)
      File.write(path, body)
      path
    end

    ruby_out = dir.join("ruby.igapp")
    ruby_report = begin
      IgniterLang::CompilerOrchestrator.new.compile_sources(
        source_paths: paths.map(&:to_s), out_path: ruby_out.to_s
      )
    rescue StandardError => e
      { "status" => "exception", "exception" => "#{e.class}: #{e.message}" }
    end

    rust_out = dir.join("rust.igapp")
    stdout, stderr, process = Open3.capture3(
      { "LANG" => "en_US.UTF-8" },
      RUST_BIN.to_s, "compile", *paths.map(&:to_s), "--out", rust_out.to_s
    )
    rust_report = begin
      JSON.parse(stdout.force_encoding("UTF-8"))
    rescue JSON::ParserError
      { "status" => "unparsed_stdout", "stdout" => stdout.force_encoding("UTF-8") }
    end
    rust_report["_stderr"] = stderr.force_encoding("UTF-8")
    rust_report["_exitstatus"] = process.exitstatus

    {
      ruby: load_side(ruby_report, ruby_out),
      rust: load_side(rust_report, rust_out)
    }
  end

  def load_side(report, artifact)
    sir_path = artifact.join("semantic_ir_program.json")
    manifest_path = artifact.join("manifest.json")
    {
      report: report,
      artifact: artifact,
      sir: report["semantic_ir"] || (JSON.parse(sir_path.read) if sir_path.file?),
      manifest: (JSON.parse(manifest_path.read) if manifest_path.file?)
    }
  end

  def ok?(side)
    side.dig(:report, "status") == "ok"
  end

  def diagnostics(side)
    report = side.fetch(:report)
    candidates = [
      report["diagnostics"],
      report.dig("compilation_report", "diagnostics"),
      report.dig("result", "diagnostics"),
      report.dig("result", "report", "diagnostics"),
      report.dig("parsed_program", "parse_errors")
    ]
    candidates.compact.flatten.select { |entry| entry.is_a?(Hash) }.uniq
  end

  def diagnostic(side, rule)
    diagnostics(side).find { |entry| (entry["rule"] || entry["code"]).to_s == rule }
  end

  def check_diag_pair(label, pair, rule, fragment)
    rb = diagnostic(pair.fetch(:ruby), rule)
    rs = diagnostic(pair.fetch(:rust), rule)
    check("#{label}: Ruby/Rust both refuse with #{rule}") do
      !ok?(pair.fetch(:ruby)) && !ok?(pair.fetch(:rust)) && rb && rs
    end
    check("#{label}: #{rule} message parity + actionable text") do
      rb_message = rb&.fetch("message", "").to_s
      rs_message = rs&.fetch("message", "").to_s
      !rb_message.empty? && rb_message == rs_message && rb_message.include?(fragment)
    end
  end

  def contract(side, name)
    Array(side.dig(:sir, "contracts")).find { |entry| entry["contract_name"] == name }
  end

  def strip_volatile(node, parent_key = nil)
    case node
    when Hash
      node.each_with_object({}) do |(key, value), out|
        next if CROSS_TOOLCHAIN_VOLATILE.include?(key)

        out[key] = strip_volatile(value, key)
      end
    when Array
      values = node.map { |value| strip_volatile(value, parent_key) }
      # Ruby preserves declaration/reference order in dependency evidence while
      # Rust stores the same dependency SET in sorted order. Dependency order is
      # not executable semantics; normalize only this known cross-tool axis.
      parent_key == "deps" ? values.sort_by(&:to_s) : values
    else
      node
    end
  end

  def canonical(node)
    case node
    when Hash
      node.keys.sort.to_h { |key| [key, canonical(node.fetch(key))] }
    when Array
      node.map { |value| canonical(value) }
    else
      node
    end
  end

  def canonical_json(node)
    JSON.generate(canonical(node))
  end

  def normalized_contracts(side)
    canonical(strip_volatile(Array(side.dig(:sir, "contracts"))))
  end

  def manifest_value(side, key)
    side.dig(:manifest, key)
  end

  def vm_run(side, inputs)
    dir = Pathname.new(Dir.mktmpdir("derived_ctor_vm_"))
    @tmpdirs << dir
    inputs_path = dir.join("inputs.json")
    File.write(inputs_path, JSON.generate(inputs))
    stdout, stderr, process = Open3.capture3(
      { "LANG" => "en_US.UTF-8" },
      VM_BIN.to_s, "run", "--contract", side.fetch(:artifact).to_s,
      "--inputs", inputs_path.to_s, "--json"
    )
    parsed = JSON.parse(stdout.force_encoding("UTF-8"))
    parsed["_stderr"] = stderr.force_encoding("UTF-8")
    parsed["_exitstatus"] = process.exitstatus
    parsed
  rescue JSON::ParserError
    {
      "status" => "unparsed_stdout",
      "stdout" => stdout.to_s.force_encoding("UTF-8"),
      "stderr" => stderr.to_s.force_encoding("UTF-8"),
      "_exitstatus" => process&.exitstatus
    }
  end

  def call_contract_nodes(node, out = [])
    case node
    when Hash
      out << node if node["kind"] == "call" && node["fn"] == "call_contract"
      node.each_value { |value| call_contract_nodes(value, out) }
    when Array
      node.each { |value| call_contract_nodes(value, out) }
    end
    out
  end

  def run
    abort("Rust compiler release binary missing: #{RUST_BIN}") unless RUST_BIN.file?
    abort("igniter-vm release binary missing: #{VM_BIN}") unless VM_BIN.file?

    forms = {
      constructor: compile_pair("plan_constructor", [["main.ig", PLAN_CONSTRUCTOR]]),
      compact: compile_pair("plan_compact", [["main.ig", PLAN_COMPACT]]),
      explicit: compile_pair("plan_explicit", [["main.ig", PLAN_EXPLICIT]])
    }
    named = {
      scrambled: compile_pair("named_scrambled", [["main.ig", NAMED_SCRAMBLED]]),
      canonical: compile_pair("named_canonical", [["main.ig", NAMED_CANONICAL]])
    }
    escape = compile_pair("explicit_escape", [["main.ig", EXPLICIT_ESCAPE]])
    oof = OOF_CASES.to_h do |name, row|
      [name, compile_pair(name.to_s, [["main.ig", row.fetch(:source)]])]
    end
    imported = compile_pair(
      "imported", [["lib.ig", IMPORT_LIB], ["user.ig", IMPORT_USER]]
    )
    qualified_call = compile_pair(
      "qualified_call", [["lib.ig", IMPORT_LIB], ["user.ig", QUALIFIED_CALL_USER]]
    )
    qualified_entrypoint = compile_pair(
      "qualified_entrypoint", [["main.ig", QUALIFIED_ENTRYPOINT]]
    )
    ambiguous = compile_pair(
      "ambiguous",
      [["a.ig", AMBIG_LIB_A], ["b.ig", AMBIG_LIB_B], ["user.ig", AMBIG_USER]]
    )
    single_visible = compile_pair(
      "single_visible",
      [["a.ig", AMBIG_LIB_A], ["b.ig", AMBIG_LIB_B], ["user.ig", SINGLE_VISIBLE_USER]]
    )
    hidden_variant = compile_pair(
      "hidden_variant",
      [["hidden.ig", AMBIG_LIB_A], ["user.ig", HIDDEN_VARIANT_USER]]
    )
    hidden_target = compile_pair(
      "hidden_target",
      [["hidden.ig", HIDDEN_TARGET_LIB], ["user.ig", HIDDEN_TARGET_USER]]
    )
    def_precedence = compile_pair(
      "def_precedence", [["main.ig", DEF_PRECEDENCE]]
    )
    order_ab = compile_pair("order_ab", [["main.ig", ORDER_AB]])
    order_ba = compile_pair("order_ba", [["main.ig", ORDER_BA]])
    evolution_add = compile_pair(
      "evolution_add", [["main.ig", EVOLUTION_ADD_STALE_CALL]]
    )

    section("A  Declaration lowering — constructor == compact == explicit")
    %i[ruby rust].each do |toolchain|
      check("A-#{toolchain}: all three PlanEmailSend spellings compile clean") do
        forms.values.all? { |pair| ok?(pair.fetch(toolchain)) }
      end
      check("A-#{toolchain}: normalized contracts are byte-identical across all spellings") do
        payloads = forms.values.map { |pair| canonical_json(pair.fetch(toolchain).dig(:sir, "contracts")) }
        payloads.uniq.length == 1
      end
      check("A-#{toolchain}: derived input order is the 11-field TypeDecl order, including `from`") do
        inputs = contract(forms.fetch(:constructor).fetch(toolchain), "PlanEmailSend").fetch("inputs")
        inputs.map { |entry| entry.fetch("name") } == PLAN_FIELDS
      end
    end

    check("A-cross: PlanEmailSend constructor SIR is Ruby/Rust equivalent modulo known decorations") do
      rb = normalized_contracts(forms.fetch(:constructor).fetch(:ruby))
      rs = normalized_contracts(forms.fetch(:constructor).fetch(:rust))
      canonical_json(rb) == canonical_json(rs)
    end
    check("A-lowering: no constructor/constructor_decl/variant_construct node survives emitted SIR") do
      forms.values.all? do |pair|
        %i[ruby rust].all? do |toolchain|
          serialized = JSON.generate(pair.fetch(toolchain).fetch(:sir))
          !serialized.include?("constructor_decl") && !serialized.include?("variant_construct")
        end
      end
    end
    check("A-golden: deterministic normalized PlanEmailSend contract matches the checked-in golden") do
      GOLDEN.file? &&
        canonical_json(JSON.parse(GOLDEN.read)) ==
          canonical_json(normalized_contracts(forms.fetch(:constructor).fetch(:ruby)))
    end

    section("B  VM — six artifacts return the same 11-field nested value")
    vm_form_results = forms.values.flat_map do |pair|
      %i[ruby rust].map { |toolchain| vm_run(pair.fetch(toolchain), PLAN_INPUTS) }
    end
    check("B-01: Ruby/Rust x constructor/compact/explicit all execute successfully") do
      vm_form_results.all? { |result| result["status"] == "success" }
    end
    check("B-02: all six VM results equal the exact PlanEmailSend record") do
      vm_form_results.map { |result| result["result"] }.uniq == [PLAN_INPUTS]
    end
    check("B-03: nested AuditContext and keyword-shaped `from` survive unchanged") do
      vm_form_results.all? do |result|
        result.dig("result", "from") == PLAN_INPUTS.fetch("from") &&
          result.dig("result", "audit_context") == PLAN_INPUTS.fetch("audit_context")
      end
    end
    check("B-04: constructor entrypoint is ordinary resolved contract metadata dual") do
      %i[ruby rust].all? do |toolchain|
        ep = forms.fetch(:constructor).fetch(toolchain).dig(:manifest, "entrypoint")
        ep && ep["resolved_contract"] == "PlanEmailSend"
      end
    end

    section("C  Named invocation — order-independent, punning + explicit mix")
    %i[ruby rust].each do |toolchain|
      check("C-#{toolchain}-01: scrambled mixed and canonical explicit calls compile") do
        named.values.all? { |pair| ok?(pair.fetch(toolchain)) }
      end
      check("C-#{toolchain}-02: named-call lowering is SIR-identical after target-order reordering") do
        a = named.fetch(:scrambled).fetch(toolchain).dig(:sir, "contracts")
        b = named.fetch(:canonical).fetch(toolchain).dig(:sir, "contracts")
        canonical_json(a) == canonical_json(b)
      end
      check("C-#{toolchain}-03: invocation is an ordinary static call_contract node") do
        calls = call_contract_nodes(contract(named.fetch(:scrambled).fetch(toolchain), "InvokePlanEmailSend"))
        first_arg = calls.first&.dig("args", 0)
        calls.length == 1 && first_arg && first_arg["value"] == "PlanEmailSend"
      end
    end
    named_vm = named.values.flat_map do |pair|
      %i[ruby rust].map { |toolchain| vm_run(pair.fetch(toolchain), PLAN_INPUTS) }
    end
    check("C-07: both field orders and both toolchains execute to the exact same record") do
      named_vm.all? { |result| result["status"] == "success" && result["result"] == PLAN_INPUTS }
    end

    section("D  Positional refusal and explicit call_contract escape")
    check_diag_pair(
      "D-01 positional natural call",
      oof.fetch(:ctor4_positional),
      "OOF-CTOR4",
      "use `BuildPair { field: ... }`"
    )
    check("D-03: literal call_contract escape remains accepted dual") do
      %i[ruby rust].all? { |toolchain| ok?(escape.fetch(toolchain)) }
    end
    escape_vm = %i[ruby rust].map { |toolchain| vm_run(escape.fetch(toolchain), PLAN_INPUTS) }
    check("D-04: explicit escape executes through ordinary contract behavior dual") do
      escape_vm.all? { |result| result["status"] == "success" && result["result"] == PLAN_INPUTS }
    end

    section("E  Fail-closed OOF matrix — dual rules and message parity")
    OOF_CASES.each do |name, row|
      next if name == :ctor4_positional

      check_diag_pair(
        "E-#{name}", oof.fetch(name), row.fetch(:rule), row.fetch(:fragment)
      )
    end
    check("E-ctor1_malformed_named_output: CTOR1 is the exact single root diagnostic dual") do
      %i[ruby rust].all? do |toolchain|
        diagnostics(oof.fetch(:ctor1_malformed_named_output).fetch(toolchain)).map do |entry|
          (entry["rule"] || entry["code"]).to_s
        end == ["OOF-CTOR1"]
      end
    end

    section("F  Visibility, qualification, and inherited ambiguity")
    check("F-01: selectively imported constructor is visible through bare MakeImported { value } dual") do
      %i[ruby rust].all? { |toolchain| ok?(imported.fetch(toolchain)) }
    end
    imported_vm = %i[ruby rust].map do |toolchain|
      vm_run(imported.fetch(toolchain), { "value" => "imported" })
    end
    check("F-02: imported bare invocation executes to the same value dual") do
      imported_vm.all? do |result|
        result["status"] == "success" && result["result"] == { "value" => "imported" }
      end
    end
    check("F-03: qualified literal call_contract identity compiles dual") do
      %i[ruby rust].all? { |toolchain| ok?(qualified_call.fetch(toolchain)) }
    end
    qualified_vm = %i[ruby rust].map do |toolchain|
      vm_run(qualified_call.fetch(toolchain), { "value" => "qualified" })
    end
    check("F-04: qualified literal call executes to the same value dual") do
      qualified_vm.all? do |result|
        result["status"] == "success" && result["result"] == { "value" => "qualified" }
      end
    end
    check("F-05: qualified entrypoint resolves the ordinary constructor contract identity dual") do
      %i[ruby rust].all? do |toolchain|
        side = qualified_entrypoint.fetch(toolchain)
        ep = side.dig(:manifest, "entrypoint")
        ok?(side) && ep && ep["declared_target"] == "Constructor.QualifiedEntrypoint.MakeQualified"
      end
    end
    check_diag_pair(
      "F-06 same short constructor name from two modules",
      ambiguous,
      "OOF-DECL-AMBIGUOUS-CONTRACT",
      "multiple visible constructors declare 'Make'"
    )
    check("F-08: one selectively imported same-short constructor wins without false ambiguity dual") do
      %i[ruby rust].all? { |toolchain| ok?(single_visible.fetch(toolchain)) }
    end
    check("F-09: imported named call lowers to its ordinary qualified contract identity dual") do
      %i[ruby rust].all? do |toolchain|
        calls = call_contract_nodes(contract(single_visible.fetch(toolchain), "Use"))
        calls.length == 1 && calls.first.dig("args", 0, "value") == "Constructor.A.Make"
      end
    end
    check("F-10: unimported same-short constructor does not collide with a local variant arm dual") do
      %i[ruby rust].all? { |toolchain| ok?(hidden_variant.fetch(toolchain)) }
    end
    check_diag_pair(
      "F-11 nonvisible target TypeDecl",
      hidden_target,
      "OOF-CTOR1",
      "must be a visible non-generic record type"
    )
    check("F-13: same-name def keeps natural-call precedence and is never hijacked by CTOR4 dual") do
      %i[ruby rust].all? do |toolchain|
        diagnostic(def_precedence.fetch(toolchain), "OOF-CTOR4").nil?
      end
    end

    section("G  Identity, pin rotation, and evolution")
    %i[ruby rust].each do |toolchain|
      sides = forms.values.map { |pair| pair.fetch(toolchain) }
      check("G-#{toolchain}-01: structural contract_ref is stable across equal lowered contracts") do
        sides.map { |side| side.dig(:manifest, "contract_refs", "PlanEmailSend") }.uniq.length == 1
      end
      check("G-#{toolchain}-02: source_hash rotates across constructor/compact/explicit spellings") do
        sides.map { |side| manifest_value(side, "source_hash") }.uniq.length == 3
      end
      check("G-#{toolchain}-03: artifact_hash rotates across constructor/compact/explicit spellings") do
        sides.map { |side| manifest_value(side, "artifact_hash") }.uniq.length == 3
      end
    end
    check("G-rust-04: Rust path-independent semantic_hash also rotates on source respelling") do
      forms.values.map { |pair| manifest_value(pair.fetch(:rust), "semantic_hash") }.uniq.length == 3
    end
    %i[ruby rust].each do |toolchain|
      ab = order_ab.fetch(toolchain)
      ba = order_ba.fetch(toolchain)
      check("G-#{toolchain}-05: reordered TypeDecl reorders derived contract inputs") do
        contract(ab, "BuildOrderedPair").fetch("inputs").map { |input| input["name"] } == %w[left right] &&
          contract(ba, "BuildOrderedPair").fetch("inputs").map { |input| input["name"] } == %w[right left]
      end
      check("G-#{toolchain}-06: TypeDecl reorder rotates structural contract_ref") do
        manifest_value(ab, "contract_refs").fetch("BuildOrderedPair") !=
          manifest_value(ba, "contract_refs").fetch("BuildOrderedPair")
      end
    end
    reorder_vm = [order_ab, order_ba].flat_map do |pair|
      %i[ruby rust].map do |toolchain|
        vm_run(pair.fetch(toolchain), { "left" => "L", "right" => "R" })
      end
    end
    check("G-09: named host inputs keep the runtime value stable across field reorder") do
      reorder_vm.all? do |result|
        result["status"] == "success" && result["result"] == { "left" => "L", "right" => "R" }
      end
    end
    check_diag_pair(
      "G-10 added field rejects stale named call",
      evolution_add,
      "OOF-CTOR7",
      "missing required field(s): added"
    )

    failed = @checks.reject { |(_, pass, _)| pass }
    puts "\n#{@checks.length} checks: #{@checks.length - failed.length} PASS, #{failed.length} FAIL"
    failed.each do |label, _, detail|
      puts "  FAIL: #{label}#{detail ? " [#{detail}]" : ""}"
    end
    exit(failed.empty? ? 0 : 1)
  ensure
    @tmpdirs.each { |dir| FileUtils.rm_rf(dir) }
  end
end

DerivedRecordConstructorCanonParityProof.run if $PROGRAM_NAME == __FILE__
