#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-VARIANT-ARM-QUALIFIED-CONSTRUCT-P1 — Ruby canon proof.
#
# Locks the Ruby half of the dual-toolchain surface:
#   * contextual `Variant::Arm` parsing without widening lexer tokenization;
#   * optional qualifier in ParsedProgram only;
#   * deterministic visible-owner resolution for bare construction;
#   * qualified construction bypass of derived-record-constructor arbitration;
#   * subject-authoritative qualified match patterns;
#   * no qualifier or new carrier in TypedProgram / SemanticIR.

require "json"
require "tmpdir"

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "igniter_lang"

module VariantArmQualifiedConstructP1Proof
  module_function

  CHECKS = []

  def check(label)
    passed = yield
    CHECKS << [label, passed]
    puts "#{passed ? 'PASS' : 'FAIL'}  #{label}"
  rescue => e
    CHECKS << [label, false]
    puts "FAIL  #{label}  [#{e.class}: #{e.message.lines.first&.strip}]"
  end

  def parse(source, tag = "inline")
    IgniterLang::ParsedProgram.parse(source, source_path: "#{tag}.ig").to_h
  end

  def pipeline(source, tag: "inline", lower_constructors: false)
    parsed = parse(source, tag)
    IgniterLang::DerivedConstructorSugar.lower!(parsed) if lower_constructors
    classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
    typed = IgniterLang::TypeChecker.new.typecheck(classified)
    emitted = IgniterLang::SemanticIREmitter.new.emit_typed(typed)
    { parsed: parsed, classified: classified, typed: typed, emitted: emitted }
  end

  def multifile_pipeline(sources)
    Dir.mktmpdir("variant-arm-qualified-ruby-proof") do |dir|
      paths = sources.map do |name, source|
        path = File.join(dir, name)
        File.write(path, source)
        path
      end
      source_check = IgniterLang::CompilerOrchestrator.new.check_sources(source_paths: paths)
      resolved = IgniterLang::MultifileResolver.new.resolve(paths)
      return { source_check: source_check, resolved: resolved } unless resolved.fetch("ok")

      classified = IgniterLang::Classifier.new.classify(
        resolved.fetch("parsed_program"), sample_input: {}
      )
      typed = IgniterLang::TypeChecker.new.typecheck(
        classified,
        cross_module_registry: resolved.fetch("cross_module_registry", {}),
        per_module_imports: resolved.fetch("per_module_imports", {}),
        per_contract_module: resolved.fetch("per_contract_module", {}),
        variant_arm_owners: resolved.fetch("variant_arm_owners", {})
      )
      emitted = IgniterLang::SemanticIREmitter.new.emit_typed(typed)
      {
        source_check: source_check,
        resolved: resolved,
        classified: classified,
        typed: typed,
        emitted: emitted
      }
    end
  end

  def parsed_compute(parsed, contract_name, compute_name)
    contract = parsed.fetch("contracts").find { |entry| entry.fetch("name") == contract_name }
    contract.fetch("body").find do |decl|
      decl.fetch("kind", nil) == "compute" && decl.fetch("name") == compute_name
    end.fetch("expr")
  end

  def typed_compute(typed, contract_name, compute_name)
    contract = typed.fetch("contracts").find { |entry| entry.fetch("name") == contract_name }
    contract.fetch("declarations").find do |decl|
      decl.fetch("kind", nil) == "compute" && decl.fetch("name") == compute_name
    end.fetch("expr")
  end

  def sir_compute(semantic_ir, contract_name, compute_name)
    contract = semantic_ir.fetch("contracts").find do |entry|
      entry.fetch("contract_name") == contract_name
    end
    contract.fetch("nodes").find do |node|
      node.fetch("kind", nil) == "compute" && node.fetch("name") == compute_name
    end.fetch("expr")
  end

  def diagnostics(typed, rule = nil)
    entries = typed.fetch("type_errors", [])
    rule ? entries.select { |entry| entry.fetch("rule") == rule } : entries
  end

  def deep_key?(value, key)
    case value
    when Hash
      value.key?(key) || value.any? { |_nested_key, nested| deep_key?(nested, key) }
    when Array
      value.any? { |nested| deep_key?(nested, key) }
    else
      false
    end
  end

  PARSER_SOURCE = <<~IG
    module QualifiedParser

    variant State {
      Held { value : String }
      Open { }
    }

    pure contract Exercise {
      input state : State
      compute qualified : State = State::Held { value: "q" }
      compute bare : State = Held { value: "b" }
      compute label : String = match state {
        State::Held { value } => value
        Open { } => "open"
      }
      output label : String
    }
  IG

  DOTTED_SOURCE = <<~IG
    module QualifiedParser
    variant State { Held { } }
    pure contract Bad {
      compute held : State = QualifiedParser.State::Held { }
      output held : State
    }
  IG

  def collision_source(order)
    variants = order.map do |name|
      "variant #{name} { Held { value : String } }"
    end.join("\n")
    <<~IG
      module Collision
      #{variants}
      pure contract Make {
        compute held = Held { value: "v" }
        output held : AlphaState
      }
    IG
  end

  QUALIFIED_COLLISION_SOURCE = <<~IG
    module Collision
    variant ZuluState { Held { value : String } }
    variant AlphaState { Held { value : String } }
    pure contract Make {
      compute held : AlphaState = AlphaState::Held { value: "v" }
      output held : AlphaState
    }
  IG

  THREE_OWNER_SOURCE = <<~IG
    module ThreeOwners
    variant ZuluState { Held { } }
    variant AlphaState { Held { } }
    variant MiddleState { Held { } }
    pure contract Make {
      compute held = Held { }
      output held : AlphaState
    }
  IG

  QUALIFIED_PATTERN_SOURCE = <<~IG
    module QualifiedPattern
    variant SeatState {
      Held { user : String }
      Available { }
    }
    pure contract Read {
      input state : SeatState
      compute user : String = match state {
        SeatState::Held { user } => user
        SeatState::Available { } => ""
      }
      output user : String
    }
  IG

  BARE_PATTERN_SOURCE = QUALIFIED_PATTERN_SOURCE
    .gsub("SeatState::Held", "Held")
    .gsub("SeatState::Available", "Available")

  FOREIGN_PATTERN_SOURCE = <<~IG
    module ForeignPattern
    variant SeatEvent { Held { user : String } }
    variant SeatState {
      Held { user : String }
      Available { }
    }
    pure contract Read {
      input state : SeatState
      compute user : String = match state {
        SeatEvent::Held { user } => user
        SeatState::Available { } => ""
      }
      output user : String
    }
  IG

  CONSTRUCTOR_SOURCE = <<~IG
    module ConstructorBypass
    type HeldTicket { user : String }
    constructor Held -> (out: HeldTicket)
    variant SeatState { Held { user : String } }
    pure contract MakeState {
      input user : String
      compute state : SeatState = SeatState::Held { user }
      output state : SeatState
    }
  IG

  BARE_CONSTRUCTOR_CONFLICT_SOURCE = CONSTRUCTOR_SOURCE
    .gsub("SeatState::Held { user }", "Held { user }")
    .gsub("compute state : SeatState", "compute state : HeldTicket")
    .gsub("output state : SeatState", "output state : HeldTicket")

  HIDDEN_OWNER = <<~IG
    module HiddenOwner
    variant EventLog { Held { note : String } }
  IG

  VISIBLE_OWNER = <<~IG
    module VisibleOwner
    variant DoorState { Held { angle : Integer } }
  IG

  SELECTIVE_USE = <<~IG
    module SelectiveUse
    import VisibleOwner.{ DoorState }
    pure contract MakeDoor {
      input angle : Integer
      compute door : DoorState = Held { angle }
      output door : DoorState
    }
  IG

  NO_VISIBLE_USE = <<~IG
    module NoVisibleUse
    pure contract Probe {
      compute hidden = Held { angle: 1 }
      compute result = "ok"
      output result : String
    }
  IG

  LOCAL_SUPPRESSION_SOURCE = <<~IG
    module LocalSuppression
    variant AlphaState { Held {} }
    variant ZuluState { Held {} }
    pure contract Probe {
      compute ambiguous = Held {}
      compute independent = 1
      output independent : String
    }
  IG

  def run
    puts "== parser / AST =="
    token_types = IgniterLang::Lexer.new("State::Held { }").tokenize.map(&:type)
    check("A01 lexer remains ident + colon + symbol_lit") do
      token_types.first(4) == %i[ident colon symbol_lit lbrace]
    end

    parser = pipeline(PARSER_SOURCE, tag: "parser")
    check("A02 qualified source parses clean") { parser[:parsed].fetch("parse_errors").empty? }
    qualified = parsed_compute(parser[:parsed], "Exercise", "qualified")
    bare = parsed_compute(parser[:parsed], "Exercise", "bare")
    match = parsed_compute(parser[:parsed], "Exercise", "label")
    check("A03 qualified construct carries qualifier in ParsedProgram") do
      qualified.fetch("qualifier") == "State" && qualified.fetch("arm") == "Held"
    end
    check("A04 bare construct has no qualifier key") { !bare.key?("qualifier") }
    check("A05 qualified pattern carries qualifier in ParsedProgram") do
      match.fetch("arms").first.fetch("pattern").fetch("qualifier") == "State"
    end
    check("A06 bare pattern has no qualifier key") do
      !match.fetch("arms")[1].fetch("pattern").key?("qualifier")
    end
    dotted = parse(DOTTED_SOURCE, "dotted")
    check("A07 Module.Variant::Arm is refused at parse") do
      dotted.fetch("parse_errors").map { |entry| entry.fetch("message") } == [
        "module-qualified variant arm 'QualifiedParser.State::Held' is not admitted; use Variant::Arm"
      ]
    end

    puts "\n== owner resolution / determinism =="
    first = pipeline(collision_source(%w[ZuluState AlphaState]), tag: "collision-a")
    flipped = pipeline(collision_source(%w[AlphaState ZuluState]), tag: "collision-b")
    expected_two = {
      "rule" => "OOF-KIND8",
      "message" => "arm 'Held' is declared by visible variants AlphaState and ZuluState; " \
                   "write AlphaState::Held { ... } or ZuluState::Held { ... }",
      "node" => "held",
      "line" => nil
    }
    check("B01 ambiguous unannotated construction emits one root diagnostic") do
      diagnostics(first[:typed]) == [expected_two]
    end
    check("B02 declaration-order reversal emits byte-identical diagnostics") do
      diagnostics(flipped[:typed]) == diagnostics(first[:typed])
    end
    repeated = Array.new(10) do |index|
      run = pipeline(
        collision_source(index.even? ? %w[ZuluState AlphaState] : %w[AlphaState ZuluState]),
        tag: "collision-repeat-#{index}"
      )
      diagnostics(run[:typed])
    end
    check("B03 ten alternating-order runs emit byte-identical diagnostics") do
      repeated.uniq == [[expected_two]]
    end
    qualified_collision = pipeline(QUALIFIED_COLLISION_SOURCE, tag: "qualified-collision")
    check("B04 qualification selects a visible colliding owner") do
      diagnostics(qualified_collision[:typed]).empty? &&
        typed_compute(qualified_collision[:typed], "Make", "held").fetch("variant") == "AlphaState"
    end
    three = pipeline(THREE_OWNER_SOURCE, tag: "three-owner")
    check("B05 three-owner diagnostic uses sorted Oxford list and sorted spellings") do
      diagnostics(three[:typed], "OOF-KIND8").map { |entry| entry.fetch("message") } == [
        "arm 'Held' is declared by visible variants AlphaState, MiddleState, and ZuluState; " \
        "write AlphaState::Held { ... } or MiddleState::Held { ... } or ZuluState::Held { ... }"
      ]
    end
    local_suppression = pipeline(LOCAL_SUPPRESSION_SOURCE, tag: "local-suppression")
    check("B06 KIND8 suppresses only its own derivative output mismatch") do
      diagnostics(local_suppression[:typed]).map { |entry| [entry.fetch("rule"), entry.fetch("node")] } == [
        ["OOF-KIND8", "ambiguous"],
        ["OOF-TY1", "independent"]
      ]
    end

    puts "\n== multifile visibility =="
    visible = multifile_pipeline(
      "hidden.ig" => HIDDEN_OWNER,
      "visible.ig" => VISIBLE_OWNER,
      "use.ig" => SELECTIVE_USE
    )
    check("C01 one imported + one hidden owner resolves cleanly") do
      visible.dig(:resolved, "ok") && diagnostics(visible[:typed]).empty?
    end
    check("C02 hidden owner does not win or participate") do
      typed_compute(visible[:typed], "MakeDoor", "door").fetch("variant") == "DoorState"
    end
    check("C03 real check_sources accepts the visible-owner source set") do
      visible.fetch(:source_check).values_at("status", "exit_code", "diagnostics") ==
        ["clean", 0, []]
    end
    check("C04 ownership stays out of source_units evidence") do
      !deep_key?(visible.dig(:resolved, "source_units"), "variant_arm_owners")
    end
    hidden = multifile_pipeline(
      "hidden.ig" => HIDDEN_OWNER,
      "visible.ig" => VISIBLE_OWNER,
      "use.ig" => NO_VISIBLE_USE
    )
    check("C05 no visible owner emits exact zero-owner KIND8") do
      diagnostics(hidden[:typed], "OOF-KIND8").map { |entry| entry.fetch("message") } == [
        "no visible variant declares arm 'Held'; import the owning variant"
      ]
    end
    check("C06 zero-owner diagnostic leaks no hidden declaration name") do
      message = diagnostics(hidden[:typed], "OOF-KIND8").first.fetch("message")
      !message.include?("DoorState") && !message.include?("EventLog") &&
        diagnostics(hidden[:typed]).length == 1
    end

    puts "\n== constructor arbitration =="
    constructor = pipeline(CONSTRUCTOR_SOURCE, tag: "constructor", lower_constructors: true)
    check("D01 qualified arm bypasses derived-constructor arbitration") do
      constructor[:parsed].fetch("parse_errors").empty? && diagnostics(constructor[:typed]).empty?
    end
    check("D02 qualified arm remains a variant_construct after constructor lowering") do
      expr = parsed_compute(constructor[:parsed], "MakeState", "state")
      expr.fetch("kind") == "variant_construct" && expr.fetch("qualifier") == "SeatState"
    end
    bare_conflict = pipeline(
      BARE_CONSTRUCTOR_CONFLICT_SOURCE, tag: "constructor-bare", lower_constructors: true
    )
    check("D03 bare constructor/arm arbitration remains OOF-CTOR5") do
      bare_conflict[:parsed].fetch("parse_errors").map { |entry| entry.fetch("rule", nil) }.include?("OOF-CTOR5")
    end

    puts "\n== qualified patterns / SIR erasure =="
    pattern = pipeline(QUALIFIED_PATTERN_SOURCE, tag: "pattern")
    check("E01 matching qualified patterns typecheck clean") do
      diagnostics(pattern[:typed]).empty?
    end
    typed_match = typed_compute(pattern[:typed], "Read", "user")
    check("E02 qualifier is removed before TypedProgram") do
      !deep_key?(typed_match, "qualifier")
    end
    foreign = pipeline(FOREIGN_PATTERN_SOURCE, tag: "foreign-pattern")
    expected_kind9 = {
      "rule" => "OOF-KIND9",
      "message" => "qualified pattern 'SeatEvent::Held' does not agree with match subject variant 'SeatState'",
      "node" => "user",
      "line" => nil
    }
    check("E03 foreign qualifier emits one targeted KIND9") do
      diagnostics(foreign[:typed]) == [expected_kind9]
    end
    check("E04 mismatched qualifier still narrows/binds by subject arm") do
      foreign_match = typed_compute(foreign[:typed], "Read", "user")
      foreign_match.fetch("arms").first.fetch("body").dig("resolved_type", "name") == "String"
    end

    bare_pattern = pipeline(BARE_PATTERN_SOURCE, tag: "bare-pattern")
    qualified_sir = pattern.dig(:emitted, "semantic_ir")
    bare_sir = bare_pattern.dig(:emitted, "semantic_ir")
    check("E05 accepted SemanticIR contains no qualifier key") do
      qualified_sir && !deep_key?(qualified_sir, "qualifier")
    end
    check("E06 qualified and bare pattern spellings emit identical match carrier") do
      sir_compute(qualified_sir, "Read", "user") == sir_compute(bare_sir, "Read", "user")
    end

    bare_construct_source = PARSER_SOURCE.gsub("State::Held { value: \"q\" }", "Held { value: \"q\" }")
    bare_construct = pipeline(bare_construct_source, tag: "bare-construct")
    qualified_sir_all = parser.dig(:emitted, "semantic_ir")
    bare_construct_sir = bare_construct.dig(:emitted, "semantic_ir")
    check("E07 qualified and bare construction emit identical variant carrier") do
      sir_compute(qualified_sir_all, "Exercise", "qualified") ==
        sir_compute(bare_construct_sir, "Exercise", "qualified")
    end
    check("E08 no new runtime/SIR carrier is introduced") do
      expr = sir_compute(qualified_sir_all, "Exercise", "qualified")
      expr.keys.sort == %w[arm fields kind resolved_type variant] &&
        expr.fetch("kind") == "variant_construct"
    end

    failed = CHECKS.reject { |_label, passed| passed }
    puts "\n#{CHECKS.length - failed.length}/#{CHECKS.length} checks passed"
    failed.each { |label, _passed| puts "  FAIL: #{label}" }
    exit(failed.empty? ? 0 : 1)
  end
end

VariantArmQualifiedConstructP1Proof.run
