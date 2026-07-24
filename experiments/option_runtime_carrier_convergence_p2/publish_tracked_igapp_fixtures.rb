#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2
#
# Re-publish the three tracked canon .igapp fixtures through the canonical Ruby
# Assembler. `add` is compiled from source. The availability and bounded
# polymorphic fixtures predate the current source compiler; on the first run
# their existing contract evidence is lifted into current SemanticIR. Every
# later run uses the committed identity-bound semantic_ir_program.json as the
# assembly owner. This does not promote either historical fixture to current
# source-compilation or runtime-execution authority.

require "digest"
require "fileutils"
require "json"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).expand_path.parent.parent
$LOAD_PATH.unshift((ROOT / "lib").to_s)

require "igniter_lang"

FIXTURES = {
  "add" => {
    source: ROOT / "source/add.ig",
    target: ROOT / "fixtures/add.igapp",
    module: "Lang.Examples.Add",
    mode: :compile
  },
  "availability_projection" => {
    source: ROOT / "source/availability_projection.ig",
    target: ROOT / "fixtures/availability_projection.igapp",
    module: "SparkCRM.Availability",
    mode: :preserve
  },
  "polymorphic_add" => {
    source: ROOT / "source/polymorphic_add.ig",
    target: ROOT / "fixtures/polymorphic_add.igapp",
    module: "Lang.Examples.PolymorphicAdd",
    mode: :preserve
  }
}.freeze

BOOL_TYPE = { "name" => "Bool", "params" => [] }.freeze
GUARD = {
  "kind" => "compute",
  "name" => "__option_carrier_guard_v1",
  "expr" => {
    "kind" => "option_carrier_guard_v1",
    "version" => "first_class_v1",
    "body" => { "kind" => "literal", "value" => true },
    "resolved_type" => BOOL_TYPE
  },
  "type" => BOOL_TYPE,
  "deps" => [],
  "fragment" => "core"
}.freeze

def canonical_json(value)
  IgniterLang::Assembler::Canonical.json(value)
end

def parse_type(type)
  return type if type.is_a?(Hash)

  text = type.to_s.strip
  open = text.index("[")
  return { "name" => text, "params" => [] } unless open && text.end_with?("]")

  name = text[0...open]
  body = text[(open + 1)...-1]
  parts = []
  depth = 0
  start = 0
  body.each_char.with_index do |char, index|
    depth += 1 if char == "["
    depth -= 1 if char == "]"
    next unless char == "," && depth.zero?

    parts << body[start...index]
    start = index + 1
  end
  parts << body[start..]
  { "name" => name, "params" => parts.map { |part| parse_type(part) } }
end

def source_path(path)
  path.relative_path_from(ROOT).to_s
end

def compile_source(path)
  parsed = IgniterLang::ParsedProgram.parse(
    File.read(path, encoding: "UTF-8"),
    source_path: source_path(path)
  ).to_h
  raise "parse failed: #{parsed.fetch("parse_errors")}" unless parsed.fetch("parse_errors", []).empty?

  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  typed = IgniterLang::TypeChecker.new(optional_fields: true).typecheck(classified)
  emitted = IgniterLang::SemanticIREmitter.new.emit_typed(typed)
  report = emitted.fetch("compilation_report")
  semantic_ir = emitted.fetch("semantic_ir")
  unless report["pass_result"] == "ok" && semantic_ir
    raise "source compilation refused: #{report.fetch("diagnostics", [])}"
  end

  [report, semantic_ir]
end

def current_artifact_pair(target)
  sir_path = target / "semantic_ir_program.json"
  report_path = target / "compilation_report.json"
  return unless sir_path.file? && report_path.file?

  [
    JSON.parse(File.read(report_path, encoding: "UTF-8")),
    JSON.parse(File.read(sir_path, encoding: "UTF-8"))
  ]
end

def legacy_expr(expr)
  return expr unless expr.is_a?(Hash)

  case expr["kind"]
  when "apply"
    {
      "kind" => "call",
      "fn" => expr.fetch("operator"),
      "args" => expr.fetch("operands", []).map { |item| legacy_expr(item) }
    }
  when "literal"
    result = { "kind" => "literal", "value" => expr["value"] }
    result["resolved_type"] = parse_type(expr["type_tag"]) if expr["type_tag"]
    result
  when "ref"
    { "kind" => "ref", "name" => expr.fetch("name") }
  when "field_access"
    {
      "kind" => "field_access",
      "object" => legacy_expr(expr.fetch("object")),
      "field" => expr.fetch("field")
    }
  else
    expr.transform_values do |value|
      case value
      when Hash then legacy_expr(value)
      when Array then value.map { |item| item.is_a?(Hash) ? legacy_expr(item) : item }
      else value
      end
    end
  end
end

def dependency_name(value)
  value.to_s.delete_prefix("input:").sub(/\Anode_/, "")
end

def legacy_node(node)
  {
    "kind" => node.fetch("kind", "compute"),
    "name" => node.fetch("name"),
    "expr" => legacy_expr(node.fetch("expression")),
    "type" => parse_type(node.fetch("type_tag", "Unknown")),
    "deps" => node.fetch("dependencies", []).map { |dep| dependency_name(dep) },
    "fragment" => node.fetch("fragment_class", "core")
  }
end

def legacy_port(port)
  {
    "name" => port.fetch("name"),
    "type" => parse_type(port.fetch("type_tag")),
    "lifecycle" => port.fetch("lifecycle", "local")
  }
end

def legacy_contract(contract, module_name)
  full_name = contract.fetch("contract_id")
  contract_name =
    if module_name == "Lang.Examples.PolymorphicAdd"
      full_name
    else
      contract.fetch("name", full_name)
    end
  specialization = contract["specialization_of"]
  specialization = specialization.split(".").last if specialization
  result = {
    "kind" => "contract_ir",
    "option_carrier" => "first_class_v1",
    "contract_ref" => nil,
    "contract_name" => contract_name,
    "modifier" => contract.fetch("fragment_class") == "escape" ? "observed" : "pure",
    "specialization_of" => specialization,
    "type_args" => contract.fetch("type_args", {}),
    "fragment_class" => contract.fetch("fragment_class"),
    "inputs" => contract.fetch("input_ports", []).map { |port| legacy_port(port) },
    "outputs" => contract.fetch("output_ports", []).map { |port| legacy_port(port) },
    "nodes" => [Marshal.load(Marshal.dump(GUARD))] +
      contract.fetch("compute_nodes", []).map { |node| legacy_node(node) },
    "escape_boundaries" => contract.fetch("escape_set", []).map do |name|
      { "name" => name, "required_caps" => [], "produces" => [] }
    end,
    "capabilities" => [],
    "effects" => []
  }
  result["implements"] = contract.fetch("implements") if contract.key?("implements")
  emitter = IgniterLang::SemanticIREmitter.new
  result["contract_ref"] = emitter.send(:contract_ref, result)
  result
end

def preserved_pair(spec)
  current = current_artifact_pair(spec.fetch(:target))
  return current if current

  target = spec.fetch(:target)
  legacy_path = target / "semantic_ir.json"
  raise "legacy fixture owner missing: #{legacy_path}" unless legacy_path.file?

  legacy_contracts = Dir[target.join("contracts/*.json").to_s].sort.map do |path|
    legacy_contract(
      JSON.parse(File.read(path, encoding: "UTF-8")),
      spec.fetch(:module)
    )
  end
  digest = Digest::SHA256.file(spec.fetch(:source)).hexdigest
  program_id = "semanticir/#{digest[0, 16]}"
  report_id = "compilation_report/#{digest[0, 16]}"
  provenance = {
    "kind" => "historical_fixture_reassembly_v1",
    "owner" => "experiments/option_runtime_carrier_convergence_p2/publish_tracked_igapp_fixtures.rb",
    "source_compilation_authority" => false,
    "runtime_execution_authority" => false,
    "purpose" => "preserve a pre-current compiler fixture behind the mandatory Option carrier fence"
  }
  semantic_ir = {
    "kind" => "semantic_ir_program",
    "format_version" => "0.1.0",
    "option_carrier" => "first_class_v1",
    "program_id" => program_id,
    "grammar_version" => "0.1.0",
    "source_hash" => "sha256:#{digest}",
    "source_path" => source_path(spec.fetch(:source)),
    "module" => spec.fetch(:module),
    "compilation_report_ref" => report_id,
    "fixture_provenance" => provenance,
    "contracts" => legacy_contracts
  }
  report = {
    "kind" => "compilation_report",
    "format_version" => "0.1.0",
    "program_id" => report_id,
    "grammar_version" => "0.1.0",
    "source_hash" => "sha256:#{digest}",
    "source_path" => source_path(spec.fetch(:source)),
    "pass_result" => "ok",
    "stages" => {
      "parse" => "fixture_preserved",
      "classify" => "fixture_preserved",
      "typecheck" => "fixture_preserved",
      "emit" => "ok"
    },
    "diagnostics" => [],
    "semantic_ir_ref" => program_id,
    "fixture_provenance" => provenance
  }
  [report, semantic_ir]
end

def add_specialization_metadata(target, semantic_ir)
  specializations = semantic_ir.fetch("contracts").filter_map do |contract|
    specialization_of = contract["specialization_of"]
    next unless specialization_of

    {
      "template_contract_id" => "#{semantic_ir.fetch("module")}.#{specialization_of}",
      "type_args" => contract.fetch("type_args", {}),
      "emitted_contract_id" => contract.fetch("contract_name")
    }
  end
  return if specializations.empty?

  template_ids = specializations.map { |item| item.fetch("template_contract_id") }.uniq.sort
  manifest_path = target / "manifest.json"
  manifest = JSON.parse(File.read(manifest_path, encoding: "UTF-8"))
  manifest["specialization_manifest_ref"] = "specialization_manifest.json"
  manifest["metadata_only_templates"] = template_ids
  File.write(manifest_path, canonical_json(manifest))

  classified_path = target / "classified_ast.json"
  classified = JSON.parse(File.read(classified_path, encoding: "UTF-8"))
  classified["generic_templates"] = template_ids.map do |template_id|
    { "template_contract_id" => template_id, "loadable" => false }
  end
  File.write(classified_path, canonical_json(classified))

  File.write(
    target / "specialization_manifest.json",
    canonical_json(
      "kind" => "specialization_manifest",
      "specializations" => specializations
    )
  )
end

def publish_to(target, report, semantic_ir)
  IgniterLang::Assembler.new.assemble_artifacts(
    case_name: target.basename(".igapp").to_s,
    report: report,
    semantic_ir: semantic_ir,
    target_dir: target
  )
  add_specialization_metadata(target, semantic_ir)
end

def directory_snapshot(path)
  Dir[path.join("**/*").to_s].sort.filter_map do |item|
    file = Pathname.new(item)
    next unless file.file?

    [file.relative_path_from(path).to_s, File.binread(file)]
  end.to_h
end

mode = ARGV.fetch(0, "check")
unless %w[check update].include?(mode)
  warn "usage: ruby #{Pathname.new(__FILE__).relative_path_from(ROOT)} [check|update]"
  exit 64
end

failures = []
FIXTURES.each do |name, spec|
  report, semantic_ir =
    if spec.fetch(:mode) == :compile
      compile_source(spec.fetch(:source))
    else
      preserved_pair(spec)
    end

  if mode == "update"
    publish_to(spec.fetch(:target), report, semantic_ir)
    puts "UPDATED #{name} #{spec.fetch(:target).relative_path_from(ROOT)}"
    next
  end

  Dir.mktmpdir("igniter-tracked-fixture-#{name}") do |tmp|
    candidate = Pathname.new(tmp) / "#{name}.igapp"
    publish_to(candidate, report, semantic_ir)
    if directory_snapshot(candidate) == directory_snapshot(spec.fetch(:target))
      puts "PASS #{name}"
    else
      failures << name
      puts "FAIL #{name}"
    end
  end
end

exit(failures.empty? ? 0 : 1)
