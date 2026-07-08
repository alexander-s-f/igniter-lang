# frozen_string_literal: true
# PROP-039 Gate 4: Loop TypeChecker Boundary Proof
# Coverage: LOOP-CL-FOR, LOOP-CL-BUDGET, LOOP-CL-REC, LOOP-CL-FUEL,
#           LOOP-TC-COLLECTION, LOOP-TC-CLEAN, LOOP-REGRESSION
#
# Gate 4 scope: Classifier + TypeChecker only.
#   - Proves the Classifier handles for_loop/budgeted_loop/decreases/max_steps nodes.
#   - Proves OOF-R2 fires for recursive contract missing decreases.
#   - Proves OOF-R4 fires for fuel_bounded missing max_steps.
#   - Proves OOF-R4 fires for recursive + decreases fuel missing max_steps.
#   - Proves OOF-L1 fires for for_loop source that is not Collection[T].
#   - Verifies backwards compatibility: existing contracts unaffected.
#
# Pipeline additions (gate 4):
#   Classifier: for_loop, budgeted_loop pass-through as declarations
#   Classifier: decreases/max_steps are meta-nodes (OOF checks only, not in declarations)
#   Classifier: OOF-R2 for recursive without decreases
#   Classifier: OOF-R4 for fuel_bounded without max_steps
#   Classifier: OOF-R4 for recursive + decreases fuel without max_steps
#   TypeChecker: for_loop source must be Collection[T] → OOF-L1
#   TypeChecker: budgeted_loop pass-through with Unit type
#
# Authority surface:
#   Authorized: igniter-lang classifier, typechecker, experiments/loop_typechecker_proof/
#   Closed: SemanticIR (gate 5), runtime, igniter-org, igniter-ruby, no real TCP sockets

$LOAD_PATH.unshift File.join(__dir__, "../../lib")
require "igniter_lang"

BOLD  = "\e[1m"
RESET = "\e[0m"
GREEN = "\e[32m"
RED   = "\e[31m"
CYAN  = "\e[36m"

FIXTURE_DIR = File.join(__dir__, "fixtures")
RESULTS = []

def parse_fixture(name)
  src = File.read(File.join(FIXTURE_DIR, "#{name}.ig"))
  IgniterLang::ParsedProgram.parse(src, source_path: name).to_h
rescue => e
  { "parse_errors" => [{ "message" => e.message }], "contracts" => [], "profiles" => [], "types" => [] }
end

def parse_inline(src)
  IgniterLang::ParsedProgram.parse(src, source_path: "inline").to_h
rescue => e
  { "parse_errors" => [{ "message" => e.message }], "contracts" => [], "profiles" => [], "types" => [] }
end

def classify(parsed)
  IgniterLang::Classifier.new.classify(parsed, sample_input: {})
rescue => e
  { "error" => e.message, "contracts" => [], "oof_log" => [] }
end

def typecheck(classified)
  IgniterLang::TypeChecker.new.typecheck(classified)
rescue => e
  { "error" => e.message, "contracts" => [], "type_errors" => [] }
end

def pipeline(fixture_name)
  parsed     = parse_fixture(fixture_name)
  classified = classify(parsed)
  typed      = typecheck(classified)
  { parsed: parsed, classified: classified, typed: typed }
rescue => e
  { error: e.message }
end

def pipeline_inline(src)
  parsed     = parse_inline(src)
  classified = classify(parsed)
  typed      = typecheck(classified)
  { parsed: parsed, classified: classified, typed: typed }
rescue => e
  { error: e.message }
end

def check(label, &block)
  result = block.call
  status = result ? "PASS" : "FAIL"
  colour = result ? GREEN : RED
  puts "  #{colour}[#{status}]#{RESET} #{label}"
  RESULTS << { label: label, pass: result }
rescue => e
  puts "  #{RED}[ERROR]#{RESET} #{label}: #{e.message}"
  RESULTS << { label: label, pass: false }
end

def section(title)
  puts "\n#{CYAN}#{BOLD}── #{title} ──#{RESET}"
end

# ──────────────────────────────────────────────────────────────────────────────
section "LOOP-CL-FOR: Classifier handles for_loop nodes"
# ──────────────────────────────────────────────────────────────────────────────

for_clean = pipeline("finite_loop_clean")

check "CL-FOR-1: for_loop fixture parses without error" do
  !for_clean.fetch(:parsed).key?("parse_errors") ||
    for_clean.fetch(:parsed).fetch("parse_errors", []).empty?
end

check "CL-FOR-2: for_loop declaration present in classified contract" do
  decls = for_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  decls.any? { |d| d.fetch("kind") == "for_loop" }
end

check "CL-FOR-3: for_loop declaration name is the loop name (ClaimLoop)" do
  decls = for_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  decls.any? { |d| d.fetch("kind") == "for_loop" && d.fetch("name") == "ClaimLoop" }
end

check "CL-FOR-4: for_loop declaration has source field" do
  decls = for_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  loop_decl = decls.find { |d| d.fetch("kind") == "for_loop" }
  loop_decl&.key?("source") && loop_decl.fetch("source") == "claims"
end

check "CL-FOR-5: for_loop declaration has item field" do
  decls = for_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  loop_decl = decls.find { |d| d.fetch("kind") == "for_loop" }
  loop_decl&.key?("item") && loop_decl.fetch("item") == "claim"
end

check "CL-FOR-6: for_loop source in deps array" do
  decls = for_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  loop_decl = decls.find { |d| d.fetch("kind") == "for_loop" }
  loop_decl&.fetch("deps", [])&.include?("claims")
end

check "CL-FOR-7: for_loop with declared source — no OOF-P1 fired for loop source" do
  oofs = for_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  loop_oofs = oofs.select { |o| o.fetch("rule") == "OOF-P1" && o.fetch("node", "").start_with?("ClaimLoop") }
  loop_oofs.empty?
end

# ──────────────────────────────────────────────────────────────────────────────
section "LOOP-CL-BUDGET: Classifier handles budgeted_loop nodes"
# ──────────────────────────────────────────────────────────────────────────────

budget_clean = pipeline("budgeted_loop_clean")

check "CL-BUDGET-1: budgeted_loop fixture parses without error" do
  !budget_clean.fetch(:parsed).key?("parse_errors") ||
    budget_clean.fetch(:parsed).fetch("parse_errors", []).empty?
end

check "CL-BUDGET-2: budgeted_loop declaration present in classified contract" do
  decls = budget_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  decls.any? { |d| d.fetch("kind") == "budgeted_loop" }
end

check "CL-BUDGET-3: budgeted_loop declaration name is SearchLoop" do
  decls = budget_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  decls.any? { |d| d.fetch("kind") == "budgeted_loop" && d.fetch("name") == "SearchLoop" }
end

check "CL-BUDGET-4: budgeted_loop declaration has max_steps field" do
  decls = budget_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  loop_decl = decls.find { |d| d.fetch("kind") == "budgeted_loop" }
  loop_decl&.key?("max_steps") && loop_decl.fetch("max_steps") == 500
end

check "CL-BUDGET-5: budgeted_loop has source and item fields" do
  decls = budget_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  loop_decl = decls.find { |d| d.fetch("kind") == "budgeted_loop" }
  loop_decl&.fetch("source") == "candidates" && loop_decl&.fetch("item") == "candidate"
end

check "CL-BUDGET-6: budgeted_loop source in deps" do
  decls = budget_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  loop_decl = decls.find { |d| d.fetch("kind") == "budgeted_loop" }
  loop_decl&.fetch("deps", [])&.include?("candidates")
end

check "CL-BUDGET-7: decreases/max_steps meta-nodes not added to declarations array" do
  # decreases and max_steps body nodes should be absent from declarations
  # (they are checked for OOF purposes only, not promoted to named symbols)
  all_decls = budget_clean.fetch(:classified).fetch("contracts", [])
                           .flat_map { |c| c.fetch("declarations", []) }
  all_decls.none? { |d| %w[decreases max_steps].include?(d.fetch("kind")) }
end

# ──────────────────────────────────────────────────────────────────────────────
section "LOOP-CL-REC: Classifier emits OOF-R2 for recursive without decreases"
# ──────────────────────────────────────────────────────────────────────────────

rec_clean   = pipeline("recursive_clean")
rec_missing = pipeline("recursive_missing_decreases")

check "CL-REC-1: recursive_clean parses without error" do
  rec_clean.fetch(:parsed).fetch("parse_errors", []).empty?
end

check "CL-REC-2: recursive_clean — no OOF-R2 fired (has decreases)" do
  oofs = rec_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.none? { |o| o.fetch("rule") == "OOF-R2" }
end

check "CL-REC-3: recursive_missing_decreases — OOF-R2 fires" do
  oofs = rec_missing.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.any? { |o| o.fetch("rule") == "OOF-R2" }
end

check "CL-REC-4: OOF-R2 message references contract name (SumBroken)" do
  oofs = rec_missing.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  r2 = oofs.find { |o| o.fetch("rule") == "OOF-R2" }
  r2&.fetch("message", "")&.include?("SumBroken")
end

check "CL-REC-5: decreases_fuel_clean — no OOF-R2 (has decreases fuel)" do
  fuel_clean = pipeline("decreases_fuel_clean")
  oofs = fuel_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.none? { |o| o.fetch("rule") == "OOF-R2" }
end

check "CL-REC-6: decreases_fuel_clean — no OOF-R4 (has decreases fuel + max_steps)" do
  fuel_clean = pipeline("decreases_fuel_clean")
  oofs = fuel_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.none? { |o| o.fetch("rule") == "OOF-R4" }
end

check "CL-REC-7: decreases_fuel_missing_steps — OOF-R4 fires (missing max_steps)" do
  fuel_missing = pipeline("decreases_fuel_missing_steps")
  oofs = fuel_missing.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.any? { |o| o.fetch("rule") == "OOF-R4" }
end

# ──────────────────────────────────────────────────────────────────────────────
section "LOOP-CL-FUEL: Classifier emits OOF-R4 for fuel_bounded without max_steps"
# ──────────────────────────────────────────────────────────────────────────────

fuel_clean   = pipeline("fuel_bounded_clean")
fuel_missing = pipeline("fuel_bounded_missing_steps")

check "CL-FUEL-1: fuel_bounded_clean parses without error" do
  fuel_clean.fetch(:parsed).fetch("parse_errors", []).empty?
end

check "CL-FUEL-2: fuel_bounded_clean — no OOF-R4 (has max_steps)" do
  oofs = fuel_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.none? { |o| o.fetch("rule") == "OOF-R4" }
end

check "CL-FUEL-3: fuel_bounded_missing_steps — OOF-R4 fires" do
  oofs = fuel_missing.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.any? { |o| o.fetch("rule") == "OOF-R4" }
end

check "CL-FUEL-4: OOF-R4 message references contract name (SearchBroken)" do
  oofs = fuel_missing.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  r4 = oofs.find { |o| o.fetch("rule") == "OOF-R4" }
  r4&.fetch("message", "")&.include?("SearchBroken")
end

check "CL-FUEL-5: OOF-R4 node points to contract name" do
  oofs = fuel_missing.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  r4 = oofs.find { |o| o.fetch("rule") == "OOF-R4" }
  r4&.fetch("node") == "SearchBroken"
end

check "CL-FUEL-6: fuel_bounded_clean — max_steps body node NOT in declarations" do
  decls = fuel_clean.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("declarations", []) }
  decls.none? { |d| d.fetch("kind") == "max_steps" }
end

check "CL-FUEL-7: fuel_bounded with max_steps colon form (inline) — no OOF-R4" do
  src = <<~IG
    module Fuel.Colon
    fuel_bounded contract ColanBound {
      input n: Integer
      compute result = n
      output result: Integer
      max_steps: 250
    }
  IG
  result = pipeline_inline(src)
  oofs = result.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.none? { |o| o.fetch("rule") == "OOF-R4" }
end

# ──────────────────────────────────────────────────────────────────────────────
section "LOOP-TC-COLLECTION: TypeChecker emits OOF-L1 for non-Collection source"
# ──────────────────────────────────────────────────────────────────────────────

for_clean_tc  = pipeline("finite_loop_clean")
for_bad_tc    = pipeline("finite_loop_bad_source")

check "TC-COLL-1: for_loop with Collection[T] source — no OOF-L1" do
  type_errs = for_clean_tc.fetch(:typed).fetch("type_errors", [])
  type_errs.none? { |e| e.fetch("rule") == "OOF-L1" }
end

check "TC-COLL-2: for_loop with Integer source — OOF-L1 fires" do
  type_errs = for_bad_tc.fetch(:typed).fetch("type_errors", [])
  type_errs.any? { |e| e.fetch("rule") == "OOF-L1" }
end

check "TC-COLL-3: OOF-L1 message references loop name (LimitLoop)" do
  type_errs = for_bad_tc.fetch(:typed).fetch("type_errors", [])
  l1 = type_errs.find { |e| e.fetch("rule") == "OOF-L1" }
  l1&.fetch("message", "")&.include?("LimitLoop")
end

check "TC-COLL-4: OOF-L1 message references source name (limit)" do
  type_errs = for_bad_tc.fetch(:typed).fetch("type_errors", [])
  l1 = type_errs.find { |e| e.fetch("rule") == "OOF-L1" }
  l1&.fetch("message", "")&.include?("limit")
end

check "TC-COLL-5: OOF-L1 message mentions got type (Integer)" do
  type_errs = for_bad_tc.fetch(:typed).fetch("type_errors", [])
  l1 = type_errs.find { |e| e.fetch("rule") == "OOF-L1" }
  l1&.fetch("message", "")&.include?("Integer")
end

check "TC-COLL-6: for_loop with Array source (not Collection) — OOF-L1 fires" do
  src = <<~IG
    module Loop.Array
    pure contract ArrayLoop {
      input items: Array[Integer]
      compute count = 0
      output count: Integer
      for ItemLoop item in items {
      }
    }
  IG
  result = pipeline_inline(src)
  type_errs = result.fetch(:typed).fetch("type_errors", [])
  type_errs.any? { |e| e.fetch("rule") == "OOF-L1" }
end

check "TC-COLL-7: budgeted_loop — OOF-L1 does NOT fire (Collection check is for_loop only)" do
  type_errs = for_clean_tc.fetch(:typed).fetch("type_errors", [])
  # budgeted_loop fixture has Collection source; verify no OOF-L1 from budget loops
  budget_result = pipeline("budgeted_loop_clean")
  budget_errs = budget_result.fetch(:typed).fetch("type_errors", [])
  budget_errs.none? { |e| e.fetch("rule") == "OOF-L1" }
end

# ──────────────────────────────────────────────────────────────────────────────
section "LOOP-TC-CLEAN: TypeChecker passes loop contracts without spurious errors"
# ──────────────────────────────────────────────────────────────────────────────

rec_clean_tc    = pipeline("recursive_clean")
fuel_clean_tc   = pipeline("fuel_bounded_clean")
dfuel_clean_tc  = pipeline("decreases_fuel_clean")

check "TC-CLEAN-1: recursive_clean — no type_errors in typed output" do
  rec_clean_tc.fetch(:typed).fetch("type_errors", []).empty?
end

check "TC-CLEAN-2: fuel_bounded_clean — no type_errors in typed output" do
  fuel_clean_tc.fetch(:typed).fetch("type_errors", []).empty?
end

check "TC-CLEAN-3: decreases_fuel_clean — no type_errors in typed output" do
  dfuel_clean_tc.fetch(:typed).fetch("type_errors", []).empty?
end

check "TC-CLEAN-4: for_loop typed declaration has kind = for_loop" do
  typed_contracts = for_clean_tc.fetch(:typed).fetch("contracts", [])
  typed_decls = typed_contracts.flat_map { |c| c.fetch("declarations", []) }
  typed_decls.any? { |d| d.fetch("kind") == "for_loop" }
end

check "TC-CLEAN-5: budgeted_loop typed declaration has kind = budgeted_loop" do
  budget_result = pipeline("budgeted_loop_clean")
  typed_contracts = budget_result.fetch(:typed).fetch("contracts", [])
  typed_decls = typed_contracts.flat_map { |c| c.fetch("declarations", []) }
  typed_decls.any? { |d| d.fetch("kind") == "budgeted_loop" }
end

check "TC-CLEAN-6: for_loop typed declaration type is Unit" do
  typed_contracts = for_clean_tc.fetch(:typed).fetch("contracts", [])
  typed_decls = typed_contracts.flat_map { |c| c.fetch("declarations", []) }
  loop_typed = typed_decls.find { |d| d.fetch("kind") == "for_loop" }
  loop_typed&.fetch("type", {})&.fetch("name") == "Unit"
end

check "TC-CLEAN-7: loop-v0 grammar_version preserved through full pipeline" do
  gv = for_clean_tc.fetch(:typed).fetch("grammar_version")
  gv == "loop-v0"
end

# ──────────────────────────────────────────────────────────────────────────────
section "LOOP-REGRESSION: Existing contracts unaffected by gate 4 additions"
# ──────────────────────────────────────────────────────────────────────────────

regression = pipeline("regression_pure")

check "REGRESSION-1: regression_pure — no parse errors" do
  regression.fetch(:parsed).fetch("parse_errors", []).empty?
end

check "REGRESSION-2: regression_pure — no classifier OOF" do
  regression.fetch(:classified).fetch("oof_log", []).empty?
end

check "REGRESSION-3: regression_pure — no type_errors" do
  regression.fetch(:typed).fetch("type_errors", []).empty?
end

check "REGRESSION-4: regression_pure — status accepted" do
  regression.fetch(:typed).fetch("contracts", []).all? { |c| c.fetch("status") == "accepted" }
end

check "REGRESSION-5: OOF-R2 does NOT fire for pure contract without decreases" do
  oofs = regression.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.none? { |o| o.fetch("rule") == "OOF-R2" }
end

check "REGRESSION-6: OOF-R4 does NOT fire for pure contract without max_steps" do
  oofs = regression.fetch(:classified).fetch("contracts", []).flat_map { |c| c.fetch("oof_log", []) }
  oofs.none? { |o| o.fetch("rule") == "OOF-R4" }
end

check "REGRESSION-7: gate 3 parser proof still passes (FOR-PARSE fixture parseable)" do
  src = <<~IG
    module Compat.ForLoop
    pure contract CheckCompat {
      input claims: Collection[Integer]
      compute count = 0
      output count: Integer
      for ClaimLoop claim in claims { }
    }
  IG
  parsed = parse_inline(src)
  parsed.fetch("contracts", []).any? do |c|
    c.fetch("body", []).any? { |n| n.fetch("kind") == "for_loop" && n.fetch("name") == "ClaimLoop" }
  end
end

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────

puts "\n#{BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#{RESET}"
pass_count = RESULTS.count { |r| r[:pass] }
fail_count = RESULTS.count { |r| !r[:pass] }
total      = RESULTS.size
colour     = fail_count.zero? ? GREEN : RED
puts "#{colour}#{BOLD}RESULT: #{pass_count}/#{total} PASS#{RESET}"
if fail_count > 0
  puts "\n#{RED}FAILURES:#{RESET}"
  RESULTS.reject { |r| r[:pass] }.each { |r| puts "  ✗ #{r[:label]}" }
end
puts "#{BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━#{RESET}"
exit(fail_count.zero? ? 0 : 1)
