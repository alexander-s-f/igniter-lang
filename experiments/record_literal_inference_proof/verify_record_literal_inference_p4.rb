#!/usr/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

# LANG-RUBY-RECORD-LITERAL-INFERENCE-P4: Readiness Proof
#
# Verifies that empty array literals ([]) in record fields are accepted during
# structural candidate matching when the declared field type is Collection[T].
#
# Root cause: structurally_assignable?(Collection[Unknown], Collection[T]) returns
# false (correct for output boundary), but the record literal field check should
# treat Collection[Unknown] arising from [] as compatible with Collection[T].
#
# Fix: new helper empty_collection_assignable? + or-clause in field check.
#
# Sections:
#   A — Source guards: new helper present; output boundary scope not widened
#   B — Empty array field resolves to named type (core fix)
#   C — Non-empty Collection field regression (P3 still works)
#   D — Output boundary not relaxed (OOF-TY1 still fires)
#   E — sim_framework SIM-P14 pressure fixture (initial_state pattern)
#   F — Scope closure: parser, Rust, emitter unchanged

$LOAD_PATH.unshift(File.join(__dir__, "../../lib"))
require "igniter_lang"

PASS = "PASS"
FAIL = "FAIL"

@results = []

def check(label, condition, detail = nil)
  status = condition ? PASS : FAIL
  @results << [label, status, detail]
  puts "#{status}  #{label}#{detail ? " — #{detail}" : ""}"
end

def typecheck(src)
  parsed     = IgniterLang::ParsedProgram.parse(src, source_path: "inline").to_h
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  IgniterLang::TypeChecker.new.typecheck(classified)
end

def errors(result)
  result["type_errors"] || []
end

def has_error?(result, rule, msg_fragment = nil)
  errors(result).any? do |e|
    e["rule"] == rule && (msg_fragment.nil? || e["message"].include?(msg_fragment))
  end
end

def clean?(result)
  errors(result).empty?
end

def find_compute(result, name, contract_idx: 0)
  result["contracts"][contract_idx]["declarations"]
      .find { |d| d["kind"] == "compute" && d["name"] == name }
end

def compute_type_name(result, name, contract_idx: 0)
  td = find_compute(result, name, contract_idx: contract_idx)
  td && td["type"] && td["type"]["name"]
end

def compute_expr_type_name(result, name, contract_idx: 0)
  td = find_compute(result, name, contract_idx: contract_idx)
  td && td["expr"] && td["expr"]["resolved_type"] && td["expr"]["resolved_type"]["name"]
end

puts "=" * 70
puts "LANG-RUBY-RECORD-LITERAL-INFERENCE-P4: Readiness Proof"
puts "=" * 70
puts

tc_src = File.read(File.join(__dir__, "../../lib/igniter_lang/typechecker.rb"), encoding: "utf-8")

# ── SECTION A: Source guards ──────────────────────────────────────────────

puts "── A: Source guards ─────────────────────────────────────────────────"

check("A-01 source: empty_collection_assignable? method defined",
      tc_src.include?("def empty_collection_assignable?"))

check("A-02 source: empty_collection_assignable? called in infer_record_literal",
      tc_src.include?("empty_collection_assignable?(act_type, exp_type)"))

check("A-03 source: P3 structural path preserved (candidates = @type_shapes.select)",
      tc_src.include?("candidates = @type_shapes.select"))

# A-04: output boundary must use structurally_assignable? only — not the new helper
# The output boundary line contains 'structurally_assignable?' but not 'empty_collection_assignable?'
# immediately adjacent to the unless/blocking_rule_present? pair.
output_boundary_region = tc_src[/unless structurally_assignable.*?blocking_rule_present.*?\n/m] || ""
check("A-04 scope: output boundary does not call empty_collection_assignable?",
      !output_boundary_region.include?("empty_collection_assignable?"),
      "output boundary region: #{output_boundary_region.strip.inspect[0..80]}")

check("A-05 source: no new OOF rule codes added",
      !tc_src.include?("OOF-TY-P4") && !tc_src.include?("OOF-COLL"))

puts

# ── SECTION B: Empty array field resolves to named type ──────────────────

puts "── B: Empty array field resolves to named type (core fix) ──────────"

# B-01: single Collection[T] field, empty array → type inferred
src_b01 = <<~IG
  module test_b01
  type Item { id : Integer  name : String }
  type Basket { label : String  items : Collection[Item] }
  contract BuildEmpty {
    compute b = { label: "cart", items: [] }
    compute result = 0
    output result : Integer
  }
IG
r_b01 = typecheck(src_b01)
check("B-01 single empty Collection field: Basket inferred",
      compute_expr_type_name(r_b01, "b") == "Basket",
      "got=#{compute_expr_type_name(r_b01, "b").inspect}")

check("B-02 single empty Collection field: no errors",
      !has_error?(r_b01, "OOF-TY0") && !has_error?(r_b01, "OOF-TY1"),
      "errors=#{errors(r_b01).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

# B-03: multiple Collection[T] fields, all empty → type inferred
src_b03 = <<~IG
  module test_b03
  type Event { kind : String  amount : Integer }
  type Proof { rule_name : String  value : Integer }
  type SimState { tick : Integer  events : Collection[Event]  proofs : Collection[Proof] }
  contract Build {
    compute s = { tick: 0, events: [], proofs: [] }
    compute result = s.tick
    output result : Integer
  }
IG
r_b03 = typecheck(src_b03)
check("B-03 multiple empty Collection fields: SimState inferred",
      compute_expr_type_name(r_b03, "s") == "SimState",
      "got=#{compute_expr_type_name(r_b03, "s").inspect}")

check("B-04 multiple empty Collection fields: no errors",
      clean?(r_b03),
      "errors=#{errors(r_b03).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

# B-05: mixed — one field is empty array, one is non-empty → type inferred
src_b05 = <<~IG
  module test_b05
  type Item { id : Integer }
  type Event { kind : String }
  type Bundle { items : Collection[Item]  events : Collection[Event] }
  contract Mix {
    compute item1 = { id: 1 }
    compute b = { items: [item1], events: [] }
    compute result = 0
    output result : Integer
  }
IG
r_b05 = typecheck(src_b05)
check("B-05 mixed empty + non-empty Collection fields: Bundle inferred",
      compute_expr_type_name(r_b05, "b") == "Bundle",
      "got=#{compute_expr_type_name(r_b05, "b").inspect}")

check("B-06 mixed: no errors",
      !has_error?(r_b05, "OOF-TY0") && !has_error?(r_b05, "OOF-TY1"),
      "errors=#{errors(r_b05).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

# B-07: scalar field access on inferred type works downstream
src_b07 = <<~IG
  module test_b07
  type Event { kind : String }
  type Container { tick : Integer  events : Collection[Event] }
  contract Downstream {
    compute c = { tick: 5, events: [] }
    compute t = c.tick
    output t : Integer
  }
IG
r_b07 = typecheck(src_b07)
check("B-07 scalar field access after empty-collection inference: clean",
      clean?(r_b07),
      "errors=#{errors(r_b07).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

puts

# ── SECTION C: Non-empty Collection field regression ─────────────────────

puts "── C: Non-empty Collection field regression (P3 still works) ────────"

# C-01: record with Collection field populated — should still infer (P3 existing behavior)
src_c01 = <<~IG
  module test_c01
  type Cell { row : Integer  col : Integer  val : Integer }
  type Matrix { rows : Integer  cols : Integer  cells : Collection[Cell] }
  contract Build {
    compute c00 = { row: 0, col: 0, val: 1 }
    compute c01 = { row: 0, col: 1, val: 2 }
    compute m = { rows: 1, cols: 2, cells: [c00, c01] }
    compute result = m.rows
    output result : Integer
  }
IG
r_c01 = typecheck(src_c01)
check("C-01 non-empty Collection field: Matrix inferred (P3 regression)",
      compute_expr_type_name(r_c01, "m") == "Matrix",
      "got=#{compute_expr_type_name(r_c01, "m").inspect}")

check("C-02 non-empty Collection field: no errors",
      clean?(r_c01),
      "errors=#{errors(r_c01).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

# C-03: scalar-only record still works (core P3 regression)
src_c03 = <<~IG
  module test_c03
  type Point { x : Integer  y : Integer }
  contract Pt {
    compute p = { x: 1, y: 2 }
    output p : Point
  }
IG
r_c03 = typecheck(src_c03)
check("C-03 scalar-only record: P3 regression — Point still infers",
      compute_expr_type_name(r_c03, "p") == "Point",
      "got=#{compute_expr_type_name(r_c03, "p").inspect}")

check("C-04 scalar-only: clean",
      clean?(r_c03),
      "errors=#{errors(r_c03).map { |e| e["message"] }.inspect}")

puts

# ── SECTION D: Output boundary not relaxed ───────────────────────────────

puts "── D: Output boundary not relaxed (OOF-TY1 still fires) ────────────"

# D-01 (revised by LANG-EMPTY-COLLECTION-TYPE-PARITY-P1): an EMPTY `[]` whose
# compute flows into a declared `output : Collection[T]` now adopts the output's
# Collection[T] contextually (Ruby twin of Rust LAB-TC-ARRAY-P1) — the original
# OOF-TY1 refusal here was a dual-toolchain parity gap, not a law. The boundary
# is NOT generally relaxed: D-01b locks that a NON-EMPTY mismatching literal in
# the same position still refuses, and D-02 keeps the Unknown-scalar refusal.
src_d01 = <<~IG
  module test_d01
  type Item { id : Integer }
  contract Boundary {
    input raw_data : Integer
    compute items = []
    output items : Collection[Item]
  }
IG
r_d01 = typecheck(src_d01)
check("D-01 output boundary: empty [] adopts Collection[Item] (EMPTY-COLLECTION-TYPE-PARITY-P1)",
      clean?(r_d01),
      "errors=#{errors(r_d01).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

src_d01b = <<~IG
  module test_d01b
  type Item { id : Integer }
  contract Boundary {
    input raw_data : Integer
    compute items = [1]
    output items : Collection[Item]
  }
IG
r_d01b = typecheck(src_d01b)
check("D-01b output boundary: NON-empty mismatching literal still rejected — OOF-TY1",
      has_error?(r_d01b, "OOF-TY1"),
      "errors=#{errors(r_d01b).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

# D-02: Unknown scalar at output boundary → still rejected
src_d02 = <<~IG
  module test_d02
  contract ScalarBoundary {
    input x : Integer
    compute result = unknown_ref
    output result : Integer
  }
IG
r_d02 = typecheck(src_d02)
check("D-02 output boundary: Unknown scalar output still rejected (OOF-P1 or OOF-TY1)",
      has_error?(r_d02, "OOF-TY1") || has_error?(r_d02, "OOF-P1"),
      "errors=#{errors(r_d02).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

# D-03: confirmed: the inferred type used in a clean output passes boundary fine
src_d03 = <<~IG
  module test_d03
  type Event { kind : String }
  type Container { tick : Integer  events : Collection[Event] }
  contract Clean {
    compute c = { tick: 1, events: [] }
    output c : Container
  }
IG
r_d03 = typecheck(src_d03)
check("D-03 inferred Container via empty[] passes output : Container boundary cleanly",
      clean?(r_d03),
      "errors=#{errors(r_d03).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

puts

# ── SECTION E: sim_framework SIM-P14 pressure fixture ────────────────────

puts "── E: SIM-P14 sim_framework initial_state pressure fixture ──────────"

# E-01: SimState-like type — tick + Collection fields, three of which are empty
src_e01 = <<~IG
  module test_e01_sim_state

  type TemporalInteger { current : Integer  prev_t1 : Integer  prev_t2 : Integer  prev_t3 : Integer }

  type Entity {
    id           : Integer
    entity_type  : String
    name         : String
    region       : String
    population   : TemporalInteger
    resources    : TemporalInteger
    health       : Integer
  }

  type SimEvent {
    tick         : Integer
    event_type   : String
    source_id    : Integer
    target_id    : Integer
    amount       : Integer
    rule_name    : String
  }

  type ProofEntry {
    tick         : Integer
    rule_name    : String
    entity_id    : Integer
    field        : String
    old_val      : Integer
    new_val      : Integer
    reason       : String
  }

  type ConstraintViolation {
    constraint_name : String
    entity_id       : Integer
    field           : String
    actual_val      : Integer
    message         : String
  }

  type SimState {
    tick       : Integer
    entities   : Collection[Entity]
    events     : Collection[SimEvent]
    proofs     : Collection[ProofEntry]
    violations : Collection[ConstraintViolation]
  }

  contract BuildInitialState {
    compute wolf = {
      id: 1,
      entity_type: "predator",
      name: "Wolf",
      region: "Forest",
      population: { current: 50, prev_t1: 50, prev_t2: 50, prev_t3: 50 },
      resources: { current: 200, prev_t1: 200, prev_t2: 200, prev_t3: 200 },
      health: 80
    }

    compute initial_state = {
      tick: 0,
      entities: [wolf],
      events: [],
      proofs: [],
      violations: []
    }

    compute result = initial_state.tick
    output result : Integer
  }
IG
r_e01 = typecheck(src_e01)
check("E-01 SIM-P14: initial_state with events:[], proofs:[], violations:[] infers SimState",
      compute_expr_type_name(r_e01, "initial_state") == "SimState",
      "got=#{compute_expr_type_name(r_e01, "initial_state").inspect}")

check("E-02 SIM-P14: no OOF-TY0 / OOF-TY1 on initial_state construction",
      !has_error?(r_e01, "OOF-TY0") && !has_error?(r_e01, "OOF-TY1"),
      "errors=#{errors(r_e01).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

check("E-03 SIM-P14: initial_state.tick field access is clean",
      clean?(r_e01),
      "errors=#{errors(r_e01).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

# E-04: three-field minimal SimState (pure isolated case without Entity nesting)
src_e04 = <<~IG
  module test_e04_minimal_sim
  type Ev   { kind : String }
  type Pr   { rule_name : String }
  type Viol { message : String }
  type State { tick : Integer  evs : Collection[Ev]  prs : Collection[Pr]  vs : Collection[Viol] }
  contract Minimal {
    compute s = { tick: 0, evs: [], prs: [], vs: [] }
    compute result = s.tick
    output result : Integer
  }
IG
r_e04 = typecheck(src_e04)
check("E-04 minimal sim: three empty Collection fields → State inferred",
      compute_expr_type_name(r_e04, "s") == "State",
      "got=#{compute_expr_type_name(r_e04, "s").inspect}")

check("E-05 minimal sim: clean",
      clean?(r_e04),
      "errors=#{errors(r_e04).map { |e| "#{e["rule"]}:#{e["message"]}" }.inspect}")

puts

# ── SECTION F: Scope closure ──────────────────────────────────────────────

puts "── F: Scope closure ─────────────────────────────────────────────────"

parser_src  = File.read(File.join(__dir__, "../../lib/igniter_lang/parser.rb"))
emitter_src = File.read(File.join(__dir__, "../../lib/igniter_lang/semanticir_emitter.rb"))

check("F-01 parser: no empty_collection_assignable? in parser.rb",
      !parser_src.include?("empty_collection_assignable?"))

check("F-02 emitter: no empty_collection_assignable? in semanticir_emitter.rb",
      !emitter_src.include?("empty_collection_assignable?"))

rust_tc_path = File.join(__dir__, "../../igniter-compiler/src/typechecker.rs")
if File.exist?(rust_tc_path)
  rust_tc_src = File.read(rust_tc_path)
  check("F-03 Rust TC: no empty_collection_assignable in typechecker.rs",
        !rust_tc_src.include?("empty_collection_assignable"))
else
  check("F-03 Rust TC: typechecker.rs path not found (no Rust changes expected)", true)
end

check("F-04 scope: structurally_assignable? body unchanged (no new branch added)",
      tc_src.include?("return false if type_name(actual)   == \"Unknown\""))

check("F-05 scope: P2 paths preserved (temp_hint_installed present)",
      tc_src.include?("temp_hint_installed"))

puts

# ── Summary ───────────────────────────────────────────────────────────────

puts "=" * 70
pass_count = @results.count { |_, s, _| s == PASS }
fail_count = @results.count { |_, s, _| s == FAIL }
total      = @results.size
puts "TOTAL: #{pass_count}/#{total} PASS  |  #{fail_count} FAIL"
if fail_count > 0
  puts
  puts "FAILURES:"
  @results.select { |_, s, _| s == FAIL }.each do |label, _, detail|
    puts "  FAIL  #{label}#{detail ? " — #{detail}" : ""}"
  end
end
puts "=" * 70

exit(fail_count > 0 ? 1 : 0)
