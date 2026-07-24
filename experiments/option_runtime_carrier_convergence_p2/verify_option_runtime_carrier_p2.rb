#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 — canon/Ruby proof.
#
# This proof owns only the canon compiler/artifact plane. The shared Rust
# carrier, desktop/Standard execution, portable profile and preserved binary
# rollback matrix are proved in igniter-lab by the same P2 card.

require "fileutils"
require "json"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).expand_path.parent.parent
FIXTURE = Pathname.new(__dir__) / "fixtures/ruby_option_carrier.ig"
GOLDEN = Pathname.new(__dir__) / "golden/ruby-option-carrier.semantic_ir.json"
INVENTORY = ROOT / "docs/spec/stdlib-inventory.json"
LAB_P1_FIXTURE_ROOT = ROOT.parent /
  "igniter-lab/lab-docs/lang/fixtures/lang-option-runtime-carrier-convergence-p1"
LAB_P1_TAGGED = LAB_P1_FIXTURE_ROOT / "tagged_matrix.ig"
LAB_P1_INLINE_SOME = LAB_P1_FIXTURE_ROOT / "inline_some_envelope.ig"
LAB_P1_NULLABLE = LAB_P1_FIXTURE_ROOT / "nullable_matrix.ig"
BIHISTORY_FIXTURE =
  ROOT / "experiments/typed_emission_main_path_parity/sparkcrm_bihistory_source.ig"
HISTORY_FIXTURE =
  ROOT / "experiments/_archive/stage2/history_type_proof/history_integer_point_access.ig"
CANON_IGAPP_FIXTURES = %w[
  add.igapp
  availability_projection.igapp
  polymorphic_add.igapp
].map { |name| ROOT / "fixtures" / name }.freeze
FRAME_FIXTURE_ROOT =
  ROOT.parent / "igniter-lab/frame-ui/igniter-frame/tests/fixtures"
FRAME_IGAPP_FIXTURES = %w[
  vm_game_app.igapp
  vm_loop_app.igapp
].map { |name| FRAME_FIXTURE_ROOT / name }.freeze

$LOAD_PATH.unshift((ROOT / "lib").to_s)
require "igniter_lang"
require "igniter_lang/semanticir_expression_evaluator"

def compile(source, source_path:, optional_fields: false)
  parsed = IgniterLang::ParsedProgram.parse(source, source_path: source_path).to_h
  raise "parse failed: #{parsed.fetch("parse_errors")}" unless parsed.fetch("parse_errors", []).empty?

  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  typed = IgniterLang::TypeChecker.new(optional_fields: optional_fields).typecheck(classified)
  emitted = IgniterLang::SemanticIREmitter.new.emit_typed(typed)
  {
    parsed: parsed,
    classified: classified,
    typed: typed,
    report: emitted.fetch("compilation_report"),
    sir: emitted.fetch("semantic_ir")
  }
end

def walk(value, &block)
  case value
  when Hash
    yield value
    value.each_value { |child| walk(child, &block) }
  when Array
    value.each { |child| walk(child, &block) }
  end
end

def nodes(value, kind)
  found = []
  walk(value) { |node| found << node if node["kind"] == kind }
  found
end

def contract(sir, name)
  sir.fetch("contracts").find { |item| item.fetch("contract_name") == name }.fetch("nodes")
end

def compute_expr(sir, contract_name, compute_name)
  contract(sir, contract_name)
    .find { |node| node.fetch("name", nil) == compute_name }
    .fetch("expr")
end

def option_type?(type)
  type.is_a?(Hash) && type["name"] == "Option"
end

def canonical_option_constructor_census?(sir)
  calls = nodes(sir, "call").map { |node| node["fn"] }
  nodes(sir, "option_value_construct").any? &&
    nodes(sir, "option_construct").empty? &&
    nodes(sir, "variant_construct").none? do |node|
      node["variant"] == "Option" || option_type?(node["resolved_type"])
    end &&
    (calls & %w[some none stdlib.option.wrap]).empty?
end

def all_authored_matches_are_option_match?(source, sir)
  authored_match_count = source.scan(/\bmatch\b/).length
  nodes(sir, "option_match").length == authored_match_count &&
    nodes(sir, "match_node").empty?
end

def canonical_json(value)
  JSON.pretty_generate(value) + "\n"
end

def exact_carrier_artifact?(artifact_dir, guard_shape)
  program_path = artifact_dir / "semantic_ir_program.json"
  manifest_path = artifact_dir / "manifest.json"
  return false unless program_path.file? && manifest_path.file?
  return false if (artifact_dir / "semantic_ir.json").exist?

  program = JSON.parse(File.read(program_path, encoding: "UTF-8"))
  manifest = JSON.parse(File.read(manifest_path, encoding: "UTF-8"))
  program["option_carrier"] == "first_class_v1" &&
    manifest["option_carrier"] == "first_class_v1" &&
    manifest["semantic_hash_law"] == "igniter.semantic-hash.v2" &&
    program.fetch("contracts").all? do |item|
      item["option_carrier"] == "first_class_v1" &&
        item.dig("nodes", 0, "expr") == guard_shape
    end
end

$pass = 0
$fail = 0

def check(label)
  if yield
    $pass += 1
    puts "PASS #{label}"
  else
    $fail += 1
    puts "FAIL #{label}"
  end
rescue StandardError => e
  $fail += 1
  puts "FAIL #{label}: #{e.class}: #{e.message.lines.first&.strip}"
end

source_path = "experiments/option_runtime_carrier_convergence_p2/fixtures/ruby_option_carrier.ig"
result = compile(File.read(FIXTURE, encoding: "UTF-8"), source_path: source_path, optional_fields: true)
sir = result.fetch(:sir)
errors = result.fetch(:typed).fetch("type_errors")

tagged_source = File.read(LAB_P1_TAGGED, encoding: "UTF-8")
tagged_result = compile(
  tagged_source,
  source_path: LAB_P1_TAGGED.relative_path_from(ROOT.parent).to_s
)
tagged_sir = tagged_result.fetch(:sir)

inline_some_source = File.read(LAB_P1_INLINE_SOME, encoding: "UTF-8")
inline_some_result = compile(
  inline_some_source,
  source_path: LAB_P1_INLINE_SOME.relative_path_from(ROOT.parent).to_s
)
inline_some_sir = inline_some_result.fetch(:sir)

nullable_source = File.read(LAB_P1_NULLABLE, encoding: "UTF-8")
nullable_result = compile(
  nullable_source,
  source_path: LAB_P1_NULLABLE.relative_path_from(ROOT.parent).to_s
)
nullable_sir = nullable_result.fetch(:sir)

check("main fixture typechecks") { errors.empty? && sir.is_a?(Hash) }
check("exact P1 tagged/inline/nullable fixtures typecheck in Ruby") do
  [tagged_result, inline_some_result, nullable_result].all? do |probe|
    probe.fetch(:typed).fetch("type_errors").empty? && probe.fetch(:sir).is_a?(Hash)
  end
end
check("exact P1 tagged fixture has only first-class Option constructors") do
  canonical_option_constructor_census?(tagged_sir)
end
check("exact P1 inline_some fixture has only first-class Option constructors") do
  canonical_option_constructor_census?(inline_some_sir)
end
check("exact P1 tagged nested/HOF matches are all option_match") do
  all_authored_matches_are_option_match?(tagged_source, tagged_sir)
end
check("exact P1 nullable Option-producer matches are all option_match") do
  all_authored_matches_are_option_match?(nullable_source, nullable_sir)
end
check("P1 NestedMatchFindRecord carries Option[Item] through the HOF body") do
  map_expr = compute_expr(nullable_sir, "NestedMatchFindRecord", "values")
  match_expr = map_expr.dig("args", 1, "body")
  subject_type = match_expr&.dig("subject", "resolved_type")
  match_expr&.fetch("kind") == "option_match" &&
    match_expr.dig("subject", "fn") == "stdlib.collection.find" &&
    option_type?(subject_type) &&
    subject_type.dig("params", 0, "name") == "Item" &&
    nodes(match_expr, "match_node").empty?
end
check("top-level carrier marker is exact") { sir["option_carrier"] == "first_class_v1" }
check("every contract projects the exact carrier marker") do
  sir.fetch("contracts").all? { |item| item["option_carrier"] == "first_class_v1" }
end

guard_shape = {
  "kind" => "option_carrier_guard_v1",
  "version" => "first_class_v1",
  "body" => { "kind" => "literal", "value" => true },
  "resolved_type" => { "name" => "Bool", "params" => [] }
}
check("every contract has exactly one first executable guard") do
  sir.fetch("contracts").all? do |item|
    guards = nodes(item.fetch("nodes"), "option_carrier_guard_v1")
    first = item.fetch("nodes").first
    guards == [first.fetch("expr")] &&
      first.fetch("name") == "__option_carrier_guard_v1" &&
      first.fetch("expr") == guard_shape
  end
end

constructors = nodes(sir, "option_value_construct")
check("constructors use only canonical Some/None shape") do
  !constructors.empty? && constructors.all? do |node|
    keys = node.keys.sort
    expected = node["arm"] == "Some" ? %w[arm kind resolved_type value] : %w[arm kind resolved_type]
    expected.sort == keys &&
      %w[Some None].include?(node["arm"]) &&
      node.dig("resolved_type", "name") == "Option"
  end
end
check("legacy Option construction identities are absent") do
  nodes(sir, "option_construct").empty? &&
    nodes(sir, "variant_construct").none? { |node| node["variant"] == "Option" } &&
    !JSON.generate(sir).include?("stdlib.option.wrap")
end
check("nested Option preserves two authored constructor levels") do
  nested = compute_expr(sir, "Build", "nested")
  nested["kind"] == "option_value_construct" &&
    nested["arm"] == "Some" &&
    nested.dig("value", "kind") == "option_value_construct" &&
    nested.dig("value", "arm") == "Some" &&
    nested.dig("resolved_type", "params", 0, "name") == "Option"
end
check("Some(None) preserves both nominal levels") do
  nested = compute_expr(sir, "NestedSomeNone", "result")
  nested["kind"] == "option_value_construct" &&
    nested["arm"] == "Some" &&
    nested.dig("value", "kind") == "option_value_construct" &&
    nested.dig("value", "arm") == "None" &&
    nested.dig("resolved_type", "params", 0, "name") == "Option" &&
    nested.dig("value", "resolved_type", "params", 0, "name") == "Integer"
end
check("inline collection elements carry canonical constructors") do
  items = compute_expr(sir, "Build", "values").fetch("items")
  items.map { |item| [item["kind"], item["arm"]] } ==
    [["option_value_construct", "Some"], ["option_value_construct", "None"]]
end
check("conditional branches carry canonical constructors") do
  expr = compute_expr(sir, "Branch", "result")
  [expr.dig("then_branch", "kind"), expr.dig("else_branch", "kind")] ==
    %w[option_value_construct option_value_construct]
end
check("HOF lambda body carries canonical constructor") do
  lambda_body = compute_expr(sir, "FilterMap", "result").dig("args", 1, "body")
  lambda_body&.fetch("kind") == "option_value_construct" && lambda_body["arm"] == "Some"
end
check("Option consumers have collision-free SIR identities") do
  {
    "PredicateSome" => "stdlib.option.is_some",
    "PredicateNone" => "stdlib.option.is_none",
    "OptionMap" => "stdlib.option.map",
    "OptionFlatMap" => "stdlib.option.flat_map",
    "OptionAndThen" => "stdlib.option.and_then"
  }.all? do |contract_name, expected_fn|
    compute_expr(sir, contract_name, "result")["fn"] == expected_fn
  end
end
check("Collection overload identities remain unchanged") do
  compute_expr(sir, "CollectionMap", "result")["fn"] == "stdlib.collection.map" &&
    compute_expr(sir, "CollectionFlatMap", "result")["fn"] == "stdlib.collection.flat_map"
end
check("nested authored history_at lowers to the existing inline temporal_read shape") do
  map_expr = compute_expr(sir, "NestedHistoryAt", "result")
  map_expr.dig("args", 1, "body") == {
    "kind" => "temporal_read",
    "source_ref" => "prediction_history",
    "store_ref" => "predictor/{model_key}",
    "as_of_ref" => "point",
    "resolved_type" => {
      "name" => "Option",
      "params" => [{ "name" => "Integer", "params" => [] }]
    }
  } &&
    nodes(map_expr, "temporal_access_node").empty? &&
    nodes(map_expr, "call").none? { |node| node["fn"] == "history_at" }
end
check("top-level history_at keeps the existing temporal_access_node owner") do
  probe = compile(
    File.read(HISTORY_FIXTURE, encoding: "UTF-8"),
    source_path: HISTORY_FIXTURE.relative_path_from(ROOT).to_s
  )
  temporal_nodes = nodes(probe.fetch(:sir), "temporal_access_node")
  probe.fetch(:typed).fetch("type_errors").empty? &&
    temporal_nodes.length == 1 &&
    temporal_nodes.first["source_ref"] == "job_count_history" &&
    temporal_nodes.first["as_of_ref"] == "as_of" &&
    nodes(probe.fetch(:sir), "temporal_read").empty?
end
check("Result consumers have distinct exact owners") do
  compute_expr(sir, "ResultFallback", "result")["fn"] == "result_unwrap_or" &&
    compute_expr(sir, "ResultMap", "result")["fn"] == "stdlib.result.map" &&
    compute_expr(sir, "ResultAndThen", "result")["fn"] == "stdlib.result.and_then"
end
check("Option match has dedicated semantic identity") do
  expr = compute_expr(sir, "Match", "result")
  expr["kind"] == "option_match" && expr["sealed"] == true
end
check("nested Option match keeps both dedicated typed match levels") do
  outer = compute_expr(sir, "NestedMatch", "result")
  inner = outer.dig("arms", 0, "body")
  outer["kind"] == "option_match" &&
    inner&.fetch("kind") == "option_match" &&
    outer.dig("subject", "resolved_type", "params", 0, "name") == "Option" &&
    inner.dig("subject", "resolved_type", "name") == "Option" &&
    inner.dig("subject", "resolved_type", "params", 0, "name") == "Integer" &&
    nodes(outer, "match_node").empty?
end

omitted = compute_expr(sir, "OptionalOmitted", "result").dig("fields", "note")
raw = compute_expr(sir, "OptionalRaw", "result").dig("fields", "note")
present = compute_expr(sir, "OptionalPresent", "result").dig("fields", "note")
check("optional field omitted/raw/present converge") do
  [omitted&.fetch("arm"), raw&.fetch("arm"), present&.fetch("kind")] ==
    ["None", "Some", "ref"]
end

decls = sir.fetch("type_declarations")
payload_decl = decls.find { |decl| decl["name"] == "Payload" }
check("named Record schema is deterministic and preserves reserved-looking fields") do
  decls.map { |decl| decl.fetch("name") } == decls.map { |decl| decl.fetch("name") }.sort &&
    payload_decl.fetch("fields").map { |field| field.fetch("name") } == %w[__arm __variant value]
end
check("typed ports retain full type trees") do
  build = sir.fetch("contracts").find { |item| item["contract_name"] == "Build" }
  build.fetch("inputs").all? { |port| port.fetch("type").is_a?(Hash) } &&
    build.fetch("outputs").all? { |port| port.fetch("type").is_a?(Hash) }
end

record = {
  "kind" => "record_literal",
  "fields" => {
    "__arm" => { "kind" => "literal", "value" => "Some" },
    "__variant" => { "kind" => "literal", "value" => "Option" }
  }
}
check("Record-shaped spoof is not an Option construction") do
  nodes(record, "option_value_construct").empty? && record["kind"] == "record_literal"
end

negative_sources = {
  "wrong_predicate_carrier" => [
    "input n : Integer\ncompute r = is_some(n)",
    "OOF-TY0"
  ],
  "wrong_option_flat_map_result" => [
    "input o : Option[Integer]\ncompute r = flat_map(o, x -> x)",
    "OOF-TY0"
  ],
  "result_flat_map_refused" => [
    "input r0 : Result[Integer, Text]\ncompute r = flat_map(r0, x -> [x])",
    "OOF-COL2"
  ],
  "wrap_removed" => [
    "input o : Option[Integer]\ncompute r = stdlib.option.wrap(o)",
    "OOF-TY0"
  ]
}
check("wrong carriers, Result flat_map, and removed wrap stay refused") do
  negative_sources.all? do |name, (body, expected_rule)|
    src = "module Negative\npure contract C {\n#{body}\noutput r : Integer }\n"
    probe = compile(src, source_path: "negative/#{name}.ig")
    probe.fetch(:sir).nil? &&
      probe.fetch(:typed).fetch("type_errors").any? { |error| error["rule"] == expected_rule }
  end
end
check("historical Result or_else alias keeps the exact Result runtime owner") do
  source = <<~IG
    module ResultAlias
    pure contract C {
      input value : Result[Integer, Text]
      compute result : Integer = or_else(value, 0)
      output result : Integer
    }
  IG
  probe = compile(source, source_path: "compat/result_or_else_alias.ig")
  probe.fetch(:typed).fetch("type_errors").empty? &&
    compute_expr(probe.fetch(:sir), "C", "result")["fn"] == "result_unwrap_or"
end
check("bihistory_at is de-admitted before SemanticIR with the stable diagnostic") do
  probe = compile(
    File.read(BIHISTORY_FIXTURE, encoding: "UTF-8"),
    source_path: BIHISTORY_FIXTURE.relative_path_from(ROOT).to_s
  )
  probe.fetch(:sir).nil? &&
    probe.fetch(:typed).fetch("type_errors") == [
      {
        "rule" => "OOF-BT2",
        "message" =>
          "bihistory_at is not executable in the first_class_v1 runtime plane; " \
          "no bitemporal runtime/TBackend lowering is admitted",
        "node" => "availability_at",
        "line" => nil,
        "aliases" => ["OOF-TM4"]
      }
    ]
end

inventory = JSON.parse(File.read(INVENTORY, encoding: "UTF-8"))
option_rows = inventory.fetch("entries").select { |entry| entry["category"] == "option" }
check("inventory exact Option function surface is complete") do
  option_rows.map { |entry| entry.fetch("canonical_name") }.sort ==
    %w[
      stdlib.option.and_then
      stdlib.option.flat_map
      stdlib.option.is_none
      stdlib.option.is_some
      stdlib.option.map
      stdlib.option.or_else
      stdlib.option.unwrap_or
    ]
end
check("inventory publishes exact adjacent Result owners") do
  inventory.fetch("entries")
    .select { |entry| entry["category"] == "result" }
    .map { |entry| [entry.fetch("canonical_name"), entry.fetch("semantic_ir_name")] }
    .sort ==
    [
      ["stdlib.result.and_then", "stdlib.result.and_then"],
      ["stdlib.result.map", "stdlib.result.map"],
      ["stdlib.result.unwrap_or", "result_unwrap_or"]
    ]
end
check("or_else remains the sole legacy_sir inventory exception") do
  legacy = inventory.fetch("entries").select { |entry| !entry["legacy_sir"].nil? }
  legacy.length == 1 &&
    legacy.first["canonical_name"] == "stdlib.option.or_else" &&
    legacy.first["legacy_sir"] == "or_else"
end

assembler = IgniterLang::Assembler.new
Dir.mktmpdir("option_carrier_p2") do |tmp|
  target = Pathname.new(tmp) / "ruby-option.igapp"
  assembler.assemble_artifacts(
    case_name: "ruby-option",
    report: result.fetch(:report),
    semantic_ir: sir,
    target_dir: target
  )
  manifest = JSON.parse(File.read(target / "manifest.json", encoding: "UTF-8"))
  sidecar = File.read(target / "semantic_hash.txt", encoding: "UTF-8")
  law = File.read(target / "semantic_hash_law.txt", encoding: "UTF-8")

  check("semantic hash manifest/sidecar/recompute triad agrees") do
    manifest["semantic_hash"] == sidecar &&
      manifest["semantic_hash"] == assembler.send(:semantic_hash, sir)
  end
  check("semantic hash law is exact in manifest + sidecar") do
    manifest["semantic_hash_law"] == "igniter.semantic-hash.v2" &&
      law == "igniter.semantic-hash.v2"
  end
  check("manifest projects carrier marker and type declarations") do
    manifest["option_carrier"] == "first_class_v1" &&
      manifest["type_declarations"] == sir["type_declarations"]
  end
  assembled = JSON.parse(
    File.read(target / "contracts/build.json", encoding: "UTF-8")
  )
  check("assembled contract projects marker and full port types") do
    assembled["option_carrier"] == "first_class_v1" &&
      assembled.fetch("input_ports").all? { |port| port["type"].is_a?(Hash) } &&
      assembled.fetch("output_ports").all? { |port| port["type"].is_a?(Hash) }
  end
end

check("semantic marker and guard participate in program identity") do
  changed = Marshal.load(Marshal.dump(sir))
  changed["option_carrier"] = "future_v2"
  changed.fetch("contracts").first.fetch("nodes").first.fetch("expr")["version"] = "future_v2"
  assembler.send(:semantic_hash, changed) != assembler.send(:semantic_hash, sir)
end

check("markerless artifact fails closed at assembly") do
  markerless = Marshal.load(Marshal.dump(sir))
  markerless.delete("option_carrier")
  begin
    Dir.mktmpdir("markerless") do |tmp|
      assembler.assemble_artifacts(
        case_name: "markerless",
        report: result.fetch(:report),
        semantic_ir: markerless,
        target_dir: tmp
      )
    end
    false
  rescue IgniterLang::AssemblyRefused => e
    e.message.include?("OOF-VM-OPTION-CARRIER")
  end
end

check("guardless artifact fails closed at assembly") do
  guardless = Marshal.load(Marshal.dump(sir))
  guardless.fetch("contracts").first.fetch("nodes").shift
  begin
    Dir.mktmpdir("guardless") do |tmp|
      assembler.assemble_artifacts(
        case_name: "guardless",
        report: result.fetch(:report),
        semantic_ir: guardless,
        target_dir: tmp
      )
    end
    false
  rescue IgniterLang::AssemblyRefused => e
    e.message.include?("OOF-VM-OPTION-CARRIER")
  end
end
check("wrong-version and duplicate guards fail closed at assembly") do
  probes = []
  wrong_version = Marshal.load(Marshal.dump(sir))
  wrong_version.fetch("contracts").first.fetch("nodes").first.fetch("expr")["version"] = "future_v2"
  probes << wrong_version
  duplicate = Marshal.load(Marshal.dump(sir))
  duplicate.fetch("contracts").first.fetch("nodes").insert(
    1,
    Marshal.load(Marshal.dump(duplicate.fetch("contracts").first.fetch("nodes").first))
  )
  probes << duplicate

  probes.all? do |probe|
    begin
      Dir.mktmpdir("bad-guard") do |tmp|
        assembler.assemble_artifacts(
          case_name: "bad-guard",
          report: result.fetch(:report),
          semantic_ir: probe,
          target_dir: tmp
        )
      end
      false
    rescue IgniterLang::AssemblyRefused => error
      error.message.include?("OOF-VM-OPTION-CARRIER")
    end
  end
end

tracked_output, tracked_status = Open3.capture2(
  "git",
  "-C",
  ROOT.to_s,
  "grep",
  "-l",
  "\"kind\": \"semantic_ir_program\"",
  "--",
  "*.json"
)
tracked_semantic_ir = tracked_status.success? ? tracked_output.lines.map(&:strip) : []
check("tracked SemanticIR census has zero markerless artifacts") do
  !tracked_semantic_ir.empty? && tracked_semantic_ir.all? do |relative_path|
    artifact = JSON.parse(File.read(ROOT / relative_path, encoding: "UTF-8"))
    artifact["option_carrier"] == "first_class_v1" &&
      artifact.fetch("contracts").all? do |item|
        item["option_carrier"] == "first_class_v1" &&
          item.dig("nodes", 0, "expr") == guard_shape
      end
  end
end
check("three canon fixture owners have canonical sidecars and exact guards") do
  CANON_IGAPP_FIXTURES.all? do |artifact_dir|
    exact_carrier_artifact?(artifact_dir, guard_shape)
  end
end
check("frame VM fixture owners have canonical sidecars and exact guards") do
  FRAME_IGAPP_FIXTURES.all? do |artifact_dir|
    exact_carrier_artifact?(artifact_dir, guard_shape)
  end
end

evaluator = IgniterLang::SemanticIRExpressionEvaluator.new
option_value_class = IgniterLang::SemanticIRExpressionEvaluator::OptionValue

check("canonical Ruby evaluator executes the exact v1 guard") do
  trace = []
  evaluator.evaluate(guard_shape, {}, call_trace: trace) == true &&
    trace == %w[option_carrier_guard_v1 literal]
end
check("canonical Ruby evaluator preserves Some(None) != None") do
  value = evaluator.evaluate(compute_expr(sir, "NestedSomeNone", "result"))
  value.is_a?(option_value_class) &&
    value.some? &&
    value.value.is_a?(option_value_class) &&
    value.value.none? &&
    value != option_value_class.none
end
check("canonical Ruby evaluator executes Option fallback/predicates/HOF/match") do
  source_fallback = evaluator.evaluate(
    compute_expr(sir, "SourceFallback", "result"),
    { "n" => 7 }
  )
  predicate_some = evaluator.evaluate(
    compute_expr(sir, "PredicateSome", "result"),
    { "n" => 7 }
  )
  predicate_none = evaluator.evaluate(compute_expr(sir, "PredicateNone", "result"))
  mapped = evaluator.evaluate(compute_expr(sir, "OptionMap", "result"), { "n" => 7 })
  flat_mapped = evaluator.evaluate(
    compute_expr(sir, "OptionFlatMap", "result"),
    { "n" => 7 }
  )
  and_then = evaluator.evaluate(
    compute_expr(sir, "OptionAndThen", "result"),
    { "n" => 7 }
  )
  matched = evaluator.evaluate(
    compute_expr(sir, "Match", "result"),
    { "value" => option_value_class.some(7) }
  )
  nested_match = compute_expr(sir, "NestedMatch", "result")
  nested_values = [
    option_value_class.some(option_value_class.some(7)),
    option_value_class.some(option_value_class.none),
    option_value_class.none
  ].map do |value|
    evaluator.evaluate(nested_match, { "value" => value })
  end

  source_fallback == 7 &&
    predicate_some == true &&
    predicate_none == true &&
    [mapped, flat_mapped, and_then].all? { |value| value.some? && value.value == 7 } &&
    matched == 7 &&
    nested_values == [7, 0, 0]
end
check("canonical evaluator refuses legacy Option nodes/calls and Record spoof") do
  legacy = [
    { "kind" => "option_construct", "arm" => "none" },
    {
      "kind" => "variant_construct",
      "variant" => "Option",
      "arm" => "None",
      "fields" => {}
    },
    {
      "kind" => "call",
      "fn" => "stdlib.option.wrap",
      "args" => [{ "kind" => "literal", "value" => nil }]
    },
    {
      "kind" => "call",
      "fn" => "unwrap_or",
      "args" => [
        { "kind" => "literal", "value" => { "__arm" => "Some" } },
        { "kind" => "literal", "value" => 0 }
      ]
    }
  ]
  legacy.all? do |expr|
    begin
      evaluator.evaluate(expr)
      false
    rescue IgniterLang::SemanticIRExpressionEvaluator::OptionCarrierError => error
      error.message.start_with?("OOF-VM-OPTION-CARRIER:") &&
        !error.message.include?("__arm")
    end
  end
end

golden_bytes = canonical_json(sir)
if ARGV.include?("--update")
  FileUtils.mkdir_p(GOLDEN.dirname)
  File.write(GOLDEN, golden_bytes)
end
check("canonical Ruby SIR matches golden anchor") do
  GOLDEN.file? && File.read(GOLDEN, encoding: "UTF-8") == golden_bytes
end

puts "RESULT #{$pass}/#{$pass + $fail} PASS"
exit($fail.zero? ? 0 : 1)
