#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"

require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/semanticir_emitter"
require_relative "../../lib/igniter_lang/typechecker"

module AssumptionsProof
  ROOT = File.expand_path("../../..", __dir__)
  FIXTURE_DIR = File.join(__dir__, "fixtures")
  GOLDEN_DIR = File.join(__dir__, "golden")
  CLASSIFIER_VERSION = IgniterLang::Classifier::DEFAULT_VERSION
  TYPECHECKER_VERSION = IgniterLang::TypeChecker::DEFAULT_VERSION

  CASES = {
    "assumption_basic" => {
      expected_contract: "ScoreInteraction",
      expected_fragment: "escape",
      expected_refs: ["homophily"],
      expected_rules: [],
      expected_typed_status: "accepted"
    },
    "epistemic_only_pure" => {
      expected_contract: "PureEpistemicScore",
      expected_fragment: "epistemic",
      expected_refs: ["calibration_prior"],
      expected_rules: [],
      expected_typed_status: "accepted"
    },
    "oof_a1_undeclared_assumption" => {
      expected_contract: "BadAssumptionUse",
      expected_fragment: "oof",
      expected_refs: ["undeclared_heuristic"],
      expected_rules: ["OOF-A1"],
      expected_typed_status: "blocked"
    }
  }.freeze
  PARSER_ERROR_CASES = {
    "oof_p28_unnamed_assumption_body" => {
      expected_rule: "OOF-P28"
    }
  }.freeze

  module_function

  def run(mode: :write)
    FileUtils.mkdir_p(GOLDEN_DIR)
    outputs = build_outputs
    parser_error_outputs = build_parser_error_outputs
    write_outputs(outputs, parser_error_outputs) if mode == :write

    checks = build_checks(outputs, parser_error_outputs)
    checks = checks.merge(build_golden_checks(outputs, parser_error_outputs)) if mode == :check_golden
    checks.each { |label, ok| puts "#{label}: #{ok ? "ok" : "FAIL"}" }
    puts "golden.dir: #{rel(GOLDEN_DIR)}"

    if checks.all? { |_label, ok| ok }
      puts mode == :check_golden ? "PASS assumptions_golden_check" : "PASS assumptions_proof"
    else
      abort(mode == :check_golden ? "FAIL assumptions_golden_check" : "FAIL assumptions_proof")
    end
  end

  def build_outputs
    classifier = IgniterLang::Classifier.new(classifier_version: CLASSIFIER_VERSION)
    typechecker = IgniterLang::TypeChecker.new(typechecker_version: TYPECHECKER_VERSION)
    emitter = IgniterLang::SemanticIREmitter.new
    CASES.each_with_object({}) do |(case_id, config), outputs|
      parsed = read_json(File.join(FIXTURE_DIR, "#{case_id}.parsed_ast.json"))
      parsed = parse_source_case(case_id) if File.exist?(File.join(FIXTURE_DIR, "#{case_id}.ig"))
      classified = classifier.classify(parsed, sample_input: {})
      typed = typechecker.typecheck(classified)
      emitted = emitter.emit_typed(typed)
      outputs[case_id] = {
        parsed: parsed,
        classified: classified,
        typed: typed,
        semantic_ir: emitted.fetch("semantic_ir"),
        compilation_report: emitted.fetch("compilation_report"),
        config: config
      }
    end
  end

  def build_parser_error_outputs
    PARSER_ERROR_CASES.each_with_object({}) do |(case_id, config), outputs|
      parsed = parse_source_case(case_id)
      outputs[case_id] = { parsed: parsed, config: config }
    end
  end

  def write_outputs(outputs, parser_error_outputs)
    outputs.each do |case_id, result|
      write_json(File.join(GOLDEN_DIR, "#{case_id}.classified.json"), result.fetch(:classified))
      write_json(File.join(GOLDEN_DIR, "#{case_id}.typed.json"), result.fetch(:typed))
      semantic_ir_path = File.join(GOLDEN_DIR, "#{case_id}.semantic_ir.json")
      if result.fetch(:semantic_ir)
        write_json(semantic_ir_path, result.fetch(:semantic_ir))
      else
        FileUtils.rm_f(semantic_ir_path)
      end
      write_json(File.join(GOLDEN_DIR, "#{case_id}.compilation_report.json"), result.fetch(:compilation_report))
    end
    parser_error_outputs.each do |case_id, result|
      write_json(File.join(GOLDEN_DIR, "#{case_id}.parsed_ast.json"), result.fetch(:parsed))
    end
  end

  def build_checks(outputs, parser_error_outputs)
    {
      "parser.assumption_sources_parse" => outputs.values.all? { |result| result.fetch(:parsed).fetch("parse_errors").empty? },
      "parser.assumptions_grammar_version" => outputs.values.all? { |result| result.fetch(:parsed).fetch("grammar_version") == "assumptions-v0" },
      "parser.p28_unnamed_assumption_body" => parser_error?(parser_error_outputs, "oof_p28_unnamed_assumption_body"),
      "classifier.assumption_basic_escape" => classified_ok?(outputs, "assumption_basic"),
      "classifier.epistemic_only_fragment" => classified_ok?(outputs, "epistemic_only_pure"),
      "classifier.oof_a1_fragment" => classified_ok?(outputs, "oof_a1_undeclared_assumption"),
      "registry.assumption_basic_shape" => registry_entry?(outputs, "assumption_basic", "homophily", "heuristic"),
      "registry.epistemic_only_shape" => registry_entry?(outputs, "epistemic_only_pure", "calibration_prior", "calibrated"),
      "uses.assumption_basic_node_epistemic" => uses_decl_epistemic?(outputs, "assumption_basic", "homophily", []),
      "uses.epistemic_only_node_epistemic" => uses_decl_epistemic?(outputs, "epistemic_only_pure", "calibration_prior", []),
      "uses.oof_a1_missing_ref_recorded" => uses_decl_epistemic?(outputs, "oof_a1_undeclared_assumption", "undeclared_heuristic", ["undeclared_heuristic"]),
      "refs.assumption_basic" => assumption_refs?(outputs, "assumption_basic"),
      "refs.epistemic_only" => assumption_refs?(outputs, "epistemic_only_pure"),
      "refs.oof_a1" => assumption_refs?(outputs, "oof_a1_undeclared_assumption"),
      "oof_a1.rule_only" => rules_match?(outputs, "oof_a1_undeclared_assumption"),
      "oof_a1.message" => oof_a1_message?(outputs),
      "typechecker.assumption_basic_accepted" => typed_status?(outputs, "assumption_basic"),
      "typechecker.epistemic_only_accepted" => typed_status?(outputs, "epistemic_only_pure"),
      "typechecker.oof_a1_blocked" => typed_status?(outputs, "oof_a1_undeclared_assumption"),
      "typechecker.registry_passthrough" => typed_registry_passthrough?(outputs),
      "typechecker.refs_passthrough" => CASES.keys.all? { |case_id| typed_assumption_refs?(outputs, case_id) },
      "typechecker.uses_decls_typed" => CASES.keys.all? { |case_id| typed_uses_decl?(outputs, case_id) },
      "typechecker.oof_a1_in_type_errors" => typed_oof_a1?(outputs),
      "typechecker.valid_strengths_not_rejected" => valid_strengths_not_rejected?(outputs),
      "typechecker.invalid_strength_rejected" => invalid_strength_rejected?(outputs),
      "typechecker.unused_invalid_strength_rejected_once" => unused_invalid_strength_is_rejected_once?,
      "typechecker.two_use_invalid_strength_not_duplicated" => two_contracts_citing_same_invalid_assumption_do_not_duplicate?,
      "semanticir.assumption_basic_emitted" => semanticir_emitted?(outputs, "assumption_basic"),
      "semanticir.epistemic_only_emitted" => semanticir_emitted?(outputs, "epistemic_only_pure"),
      "semanticir.registry_lowered" => semanticir_registry_lowered?(outputs),
      "semanticir.refs_lowered" => semanticir_refs_lowered?(outputs),
      "semanticir.uses_nodes_lowered" => semanticir_uses_nodes_lowered?(outputs),
      "semanticir.oof_a1_report_only" => semanticir_report_only?(outputs, "oof_a1_undeclared_assumption", "OOF-A1"),
      "semanticir.invalid_strength_report_only" => invalid_strength_report_only?(outputs),
      "prop034.pure_fixture_has_no_output_evidence" => pure_fixture_has_no_output_evidence?(outputs),
      "semanticir.blocked_cases_not_emitted" => outputs.fetch("oof_a1_undeclared_assumption").fetch(:semantic_ir).nil?,
      "golden.classified_outputs" => Dir[File.join(GOLDEN_DIR, "*.classified.json")].length == CASES.length,
      "golden.typed_outputs" => Dir[File.join(GOLDEN_DIR, "*.typed.json")].length == CASES.length,
      "golden.semanticir_outputs" => Dir[File.join(GOLDEN_DIR, "*.semantic_ir.json")].length == 2,
      "golden.compilation_report_outputs" => Dir[File.join(GOLDEN_DIR, "*.compilation_report.json")].length == CASES.length,
      "golden.parser_error_outputs" => parser_error_golden_count == PARSER_ERROR_CASES.length
    }
  end

  def build_golden_checks(outputs, parser_error_outputs)
    {
      "check.golden_classified_equal" => outputs.all? do |case_id, result|
        golden_equal?(File.join(GOLDEN_DIR, "#{case_id}.classified.json"), result.fetch(:classified))
      end,
      "check.golden_typed_equal" => outputs.all? do |case_id, result|
        golden_equal?(File.join(GOLDEN_DIR, "#{case_id}.typed.json"), result.fetch(:typed))
      end,
      "check.golden_semanticir_equal" => outputs.all? do |case_id, result|
        path = File.join(GOLDEN_DIR, "#{case_id}.semantic_ir.json")
        result.fetch(:semantic_ir) ? golden_equal?(path, result.fetch(:semantic_ir)) : !File.exist?(path)
      end,
      "check.golden_compilation_report_equal" => outputs.all? do |case_id, result|
        golden_equal?(File.join(GOLDEN_DIR, "#{case_id}.compilation_report.json"), result.fetch(:compilation_report))
      end,
      "check.golden_parser_errors_equal" => parser_error_outputs.all? do |case_id, result|
        golden_equal?(File.join(GOLDEN_DIR, "#{case_id}.parsed_ast.json"), result.fetch(:parsed))
      end,
      "check.deterministic_generation" => deterministic_outputs?
    }
  end

  def parser_error?(outputs, case_id)
    result = outputs.fetch(case_id)
    expected_rule = result.fetch(:config).fetch(:expected_rule)
    result.fetch(:parsed).fetch("parse_errors").any? { |entry| entry.fetch("rule") == expected_rule }
  end

  def classified_ok?(outputs, case_id)
    contract = only_contract(outputs.fetch(case_id))
    config = outputs.fetch(case_id).fetch(:config)
    contract.fetch("name") == config.fetch(:expected_contract) &&
      contract.fetch("fragment_class") == config.fetch(:expected_fragment)
  end

  def registry_entry?(outputs, case_id, name, kind)
    entry = outputs.fetch(case_id).fetch(:classified).fetch("assumption_registry", [])
      .find { |candidate| candidate.fetch("name") == name }
    entry&.fetch("kind") == "assumption_entry" &&
      entry.fetch("declared_in_module") == outputs.fetch(case_id).fetch(:parsed).fetch("module") &&
      entry.fetch("fields").fetch("kind") == kind
  end

  def uses_decl_epistemic?(outputs, case_id, name, missing)
    decl = only_contract(outputs.fetch(case_id)).fetch("declarations")
      .find { |candidate| candidate.fetch("kind") == "uses_assumptions" && candidate.fetch("name") == name }
    decl&.fetch("fragment_class") == "epistemic" &&
      decl.fetch("deps") == [] &&
      decl.fetch("missing_refs") == missing
  end

  def assumption_refs?(outputs, case_id)
    contract = only_contract(outputs.fetch(case_id))
    contract.fetch("assumption_refs") == outputs.fetch(case_id).fetch(:config).fetch(:expected_refs)
  end

  def rules_match?(outputs, case_id)
    contract = only_contract(outputs.fetch(case_id))
    actual = contract.fetch("oof_log").map { |entry| entry.fetch("rule") }.uniq
    actual == outputs.fetch(case_id).fetch(:config).fetch(:expected_rules)
  end

  def oof_a1_message?(outputs)
    entry = only_contract(outputs.fetch("oof_a1_undeclared_assumption")).fetch("oof_log").first
    entry.fetch("rule") == "OOF-A1" &&
      entry.fetch("node") == "uses_assumptions:undeclared_heuristic" &&
      entry.fetch("message").include?("no assumption named 'undeclared_heuristic' is declared")
  end

  def pure_fixture_has_no_output_evidence?(outputs)
    contract = only_contract(outputs.fetch("epistemic_only_pure"))
    output = contract.fetch("declarations").find { |decl| decl.fetch("kind") == "output" }
    contract.fetch("oof_log").empty? && output && !output.key?("evidence")
  end

  def typed_status?(outputs, case_id)
    contract = typed_contract(outputs.fetch(case_id))
    contract.fetch("status") == outputs.fetch(case_id).fetch(:config).fetch(:expected_typed_status)
  end

  def typed_registry_passthrough?(outputs)
    CASES.keys.all? do |case_id|
      outputs.fetch(case_id).fetch(:typed).fetch("assumption_registry", []) ==
        outputs.fetch(case_id).fetch(:classified).fetch("assumption_registry", [])
    end
  end

  def typed_assumption_refs?(outputs, case_id)
    typed_contract(outputs.fetch(case_id)).fetch("assumption_refs") ==
      outputs.fetch(case_id).fetch(:config).fetch(:expected_refs)
  end

  def typed_uses_decl?(outputs, case_id)
    name = outputs.fetch(case_id).fetch(:config).fetch(:expected_refs).fetch(0)
    decl = typed_contract(outputs.fetch(case_id)).fetch("declarations")
      .find { |candidate| candidate.fetch("kind") == "uses_assumptions" && candidate.fetch("name") == name }
    decl&.fetch("type") == { "name" => "Assumption", "params" => [] } &&
      decl.fetch("fragment_class") == "epistemic"
  end

  def typed_oof_a1?(outputs)
    contract = typed_contract(outputs.fetch("oof_a1_undeclared_assumption"))
    contract.fetch("type_errors").any? { |entry| entry.fetch("rule") == "OOF-A1" }
  end

  def valid_strengths_not_rejected?(outputs)
    %w[assumption_basic epistemic_only_pure].all? do |case_id|
      typed_contract(outputs.fetch(case_id)).fetch("type_errors").none? { |entry| entry.fetch("rule") == "TASSUMP-1" }
    end
  end

  def invalid_strength_rejected?(outputs)
    # LANG-ASSUMPTION-DECLARATION-VALIDATION-PARITY-P1: TASSUMP-1 is now a module-level
    # diagnostic (validated once over the whole assumption registry, not gated by any single
    # contract's `assumption_refs`), so it no longer appears in a citing contract's OWN
    # `type_errors`/`status` — check the module-level `typed.type_errors` instead.
    emitted = invalid_strength_emit(outputs)
    emitted.fetch("typed").fetch("type_errors").any? { |entry| entry.fetch("rule") == "TASSUMP-1" } &&
      emitted.fetch("semantic_ir").nil?
  end

  # LANG-ASSUMPTION-DECLARATION-VALIDATION-PARITY-P1 fixtures: neither is tracked as a golden
  # CASE (both are synthetic, in-memory, disposable — same convention as `invalid_strength_emit`
  # above) — they exist only to prove the parity fix and are not part of the golden-count checks.
  UNUSED_INVALID_STRENGTH_SOURCE = <<~IG
    module Tassump.UnusedInvalidStrength

    assumptions {
      assumption homophily {
        kind :heuristic
        statement "unused premise"
        strength 3
      }
    }

    pure contract Plain {
      input a: String
      compute out = a
      output out: String
    }
  IG

  TWO_USE_INVALID_STRENGTH_SOURCE = <<~IG
    module Tassump.TwoUseInvalidStrength

    assumptions {
      assumption homophily {
        kind :heuristic
        statement "used premise"
        strength 3
      }
    }

    observed contract One {
      input a: Signal
      uses assumptions homophily
      escape profile_source
      compute out = homophily.statement
      output out: String evidence [a, homophily]
    }

    observed contract Two {
      input a: Signal
      uses assumptions homophily
      escape profile_source
      compute out = homophily.statement
      output out: String evidence [a, homophily]
    }
  IG

  def synthetic_emit(source, source_path)
    parsed = IgniterLang::ParsedProgram.parse(source, source_path: source_path).to_h
    classifier = IgniterLang::Classifier.new(classifier_version: CLASSIFIER_VERSION)
    typechecker = IgniterLang::TypeChecker.new(typechecker_version: TYPECHECKER_VERSION)
    emitter = IgniterLang::SemanticIREmitter.new
    classified = classifier.classify(parsed, sample_input: {})
    typed = typechecker.typecheck(classified)
    emitted = emitter.emit_typed(typed)
    {
      "parsed" => parsed,
      "typed" => typed,
      "semantic_ir" => emitted.fetch("semantic_ir"),
      "compilation_report" => emitted.fetch("compilation_report")
    }
  end

  def tassump_count(result)
    result.fetch("compilation_report").fetch("diagnostics").count { |entry| entry.fetch("rule") == "TASSUMP-1" }
  end

  # A declared-but-never-cited invalid assumption must still be refused — `declared_only` is a
  # legitimate epistemic state, not permission to carry malformed metadata.
  def unused_invalid_strength_is_rejected_once?
    result = synthetic_emit(UNUSED_INVALID_STRENGTH_SOURCE, "synthetic:unused_invalid_strength")
    tassump_count(result) == 1 &&
      result.fetch("semantic_ir").nil? &&
      result.fetch("compilation_report").fetch("pass_result") == "oof"
  end

  # Two different contracts citing the SAME invalid assumption must not multiply the diagnostic.
  def two_contracts_citing_same_invalid_assumption_do_not_duplicate?
    result = synthetic_emit(TWO_USE_INVALID_STRENGTH_SOURCE, "synthetic:two_use_invalid_strength")
    tassump_count(result) == 1 && result.fetch("semantic_ir").nil?
  end

  def semanticir_emitted?(outputs, case_id)
    semantic_ir = outputs.fetch(case_id).fetch(:semantic_ir)
    report = outputs.fetch(case_id).fetch(:compilation_report)
    semantic_ir&.fetch("kind") == "semantic_ir_program" &&
      report.fetch("pass_result") == "ok" &&
      report.fetch("semantic_ir_ref") == semantic_ir.fetch("program_id")
  end

  def semanticir_registry_lowered?(outputs)
    %w[assumption_basic epistemic_only_pure].all? do |case_id|
      semantic_ir = outputs.fetch(case_id).fetch(:semantic_ir)
      expected = outputs.fetch(case_id).fetch(:typed).fetch("assumption_registry").map do |entry|
        assumption_ir(entry)
      end
      semantic_ir.fetch("assumption_registry") == expected
    end
  end

  def assumption_ir(entry)
    {
      "kind" => "assumption_ir",
      "name" => entry.fetch("name"),
      "fields" => entry.fetch("fields"),
      "declared_in_module" => entry.fetch("declared_in_module")
    }
  end

  def semanticir_refs_lowered?(outputs)
    %w[assumption_basic epistemic_only_pure].all? do |case_id|
      only_semantic_contract(outputs, case_id).fetch("assumption_refs") ==
        outputs.fetch(case_id).fetch(:config).fetch(:expected_refs)
    end
  end

  def semanticir_uses_nodes_lowered?(outputs)
    %w[assumption_basic epistemic_only_pure].all? do |case_id|
      name = outputs.fetch(case_id).fetch(:config).fetch(:expected_refs).fetch(0)
      node = only_semantic_contract(outputs, case_id).fetch("nodes")
        .find { |candidate| candidate.fetch("kind") == "assumption_ref_node" && candidate.fetch("name") == name }
      node&.fetch("assumption_ref") == name &&
        node.fetch("fragment") == "epistemic" &&
        node.fetch("type") == { "name" => "Assumption", "params" => [] }
    end
  end

  def semanticir_report_only?(outputs, case_id, rule)
    result = outputs.fetch(case_id)
    report = result.fetch(:compilation_report)
    result.fetch(:semantic_ir).nil? &&
      report.fetch("pass_result") == "oof" &&
      report.fetch("semantic_ir_ref").nil? &&
      report.fetch("diagnostics").any? { |entry| entry.fetch("rule") == rule }
  end

  def invalid_strength_report_only?(outputs)
    emitted = invalid_strength_emit(outputs)
    report = emitted.fetch("compilation_report")
    emitted.fetch("semantic_ir").nil? &&
      report.fetch("pass_result") == "oof" &&
      report.fetch("semantic_ir_ref").nil? &&
      report.fetch("diagnostics").any? { |entry| entry.fetch("rule") == "TASSUMP-1" }
  end

  def invalid_strength_emit(outputs)
    parsed = JSON.parse(JSON.generate(outputs.fetch("assumption_basic").fetch(:parsed)))
    parsed["source_hash"] = "sha256:assumption-basic-invalid-strength"
    parsed.fetch("assumptions").fetch(0).fetch("fields")["strength"] = 1.2

    classifier = IgniterLang::Classifier.new(classifier_version: CLASSIFIER_VERSION)
    typechecker = IgniterLang::TypeChecker.new(typechecker_version: TYPECHECKER_VERSION)
    emitter = IgniterLang::SemanticIREmitter.new
    typed = typechecker.typecheck(classifier.classify(parsed, sample_input: {}))
    emitted = emitter.emit_typed(typed)
    {
      "typed" => typed,
      "semantic_ir" => emitted.fetch("semantic_ir"),
      "compilation_report" => emitted.fetch("compilation_report")
    }
  end

  def deterministic_outputs?
    first = build_outputs
    second = build_outputs
    first_parser_errors = build_parser_error_outputs
    second_parser_errors = build_parser_error_outputs
    CASES.keys.all? do |case_id|
      render_json(first.fetch(case_id).fetch(:classified)) == render_json(second.fetch(case_id).fetch(:classified)) &&
        render_json(first.fetch(case_id).fetch(:typed)) == render_json(second.fetch(case_id).fetch(:typed)) &&
        render_json(first.fetch(case_id).fetch(:semantic_ir)) == render_json(second.fetch(case_id).fetch(:semantic_ir)) &&
        render_json(first.fetch(case_id).fetch(:compilation_report)) == render_json(second.fetch(case_id).fetch(:compilation_report))
    end && PARSER_ERROR_CASES.keys.all? do |case_id|
      render_json(first_parser_errors.fetch(case_id).fetch(:parsed)) ==
        render_json(second_parser_errors.fetch(case_id).fetch(:parsed))
    end
  end

  def only_contract(result)
    result.fetch(:classified).fetch("contracts").fetch(0)
  end

  def typed_contract(result)
    result.fetch(:typed).fetch("contracts").fetch(0)
  end

  def only_semantic_contract(outputs, case_id)
    outputs.fetch(case_id).fetch(:semantic_ir).fetch("contracts").fetch(0)
  end

  def read_json(path)
    JSON.parse(File.read(path))
  end

  def parse_source_case(case_id)
    path = File.join(FIXTURE_DIR, "#{case_id}.ig")
    IgniterLang::ParsedProgram.parse(File.read(path), source_path: rel(path)).to_h
  end

  def write_json(path, object)
    File.write(path, render_json(object))
  end

  def render_json(object)
    "#{JSON.pretty_generate(object)}\n"
  end

  def golden_equal?(path, expected)
    return false unless File.exist?(path)

    JSON.parse(File.read(path)) == expected
  end

  def rel(path)
    Pathname.new(path).relative_path_from(Pathname.new(ROOT)).to_s
  end

  def parser_error_golden_count
    PARSER_ERROR_CASES.keys.count do |case_id|
      File.exist?(File.join(GOLDEN_DIR, "#{case_id}.parsed_ast.json"))
    end
  end
end

if $PROGRAM_NAME == __FILE__
  mode = ARGV.include?("--check-golden") ? :check_golden : :write
  AssumptionsProof.run(mode: mode)
end
