#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/profile_loop_class_proof/profile_loop_class_proof.rb
#
# LANG-PROFILE-LOOP-CLASS-P42 (PROP-048) — the LAST profile-policy rule; finishes
# the ch11 §11.4 obligations/restrictions set. `loop: <class>` on a profile
# restricts which loop-class a bound contract may use. Namespace/severity per P30:
#   - OOF-PROF3 (hard error) — bound contract's loop-class ≠ the permitted class;
#   - OOF-PROF6 (parse-time, fail-closed) — an unknown / aspirational value.
#
# v0 vocabulary is the LIVE loop-class surface, NOT ch11's aspirational set:
#   none | recursive | fuel_bounded | budgeted
# A contract's loop-class(es) are live source facts: the `recursive` /
# `fuel_bounded` modifiers and a `budgeted_loop` (`loop … max_steps …`) body
# decl. ch11's `finite_loop` / `convergent` / `service` are Ch13 (Managed
# Recursion) target prose with no compiler surface — they fail closed
# (OOF-PROF6) until Ch13 lands, and the §11.4 "loop: service ⇒ service-contract
# form" rule stays HELD. Compile-time policy only (Covenant P10). Ruby-canon.

require "json"

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"

GREEN = "\e[32m"
RED   = "\e[31m"
CYAN  = "\e[36m"
BOLD  = "\e[1m"
RESET = "\e[0m"

def parse(src)
  IgniterLang::ParsedProgram.parse(src, source_path: "loop").to_h
end

def classify(src)
  IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
end

def typed(src)
  IgniterLang::TypeChecker.new.typecheck(classify(src))
end

def contract_oofs(classified, name, rule)
  c = classified.fetch("contracts").find { |x| x.fetch("name") == name }
  c.fetch("oof_log", []).select { |d| d.fetch("rule", d["code"]) == rule }
end

RESULTS = []

def check(label, &block)
  result = block.call
  colour = result ? GREEN : RED
  puts "  #{colour}[#{result ? "PASS" : "FAIL"}]#{RESET} #{label}"
  RESULTS << { label: label, pass: result }
rescue => e
  puts "  #{RED}[ERROR]#{RESET} #{label}: #{e.message}"
  RESULTS << { label: label, pass: false }
end

def section(title)
  puts "\n#{CYAN}#{BOLD}── #{title} ──#{RESET}"
end

# Reusable bound contracts (each OOF-P1-clean: compute precedes output).
def profile(loop_val)
  loop_val ? "profile rp { loop: #{loop_val} }" : "profile rp { authority: pure }"
end

RECURSIVE = <<~C
  recursive contract Act via rp {
    input n: Integer
    compute total = n
    output total: Integer
    decreases n
  }
C

FUEL = <<~C
  fuel_bounded contract Act via rp {
    input n: Integer
    compute result = n
    output result: Integer
    max_steps 100
  }
C

BUDGETED = <<~C
  observed contract Act via rp {
    input candidates: Collection[Item]
    loop L item in candidates max_steps: 200 {
      compute score = item.score
    }
  }
C

NOLOOP = <<~C
  pure contract Act via rp {
    input x: Integer
    compute y = x
    output y: Integer
  }
C

def prog(loop_val, contract)
  "module Proof.ProfileLoop\n#{profile(loop_val)}\n#{contract}"
end

puts "#{BOLD}#{CYAN}Profile loop-class proof (LANG-PROFILE-LOOP-CLASS-P42)#{RESET}"
puts "Path: igniter-lang/experiments/profile_loop_class_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "AST — `loop` retained; live vocab only"

check("AST-1: `loop: fuel_bounded` stored on the profile node") do
  parse(prog("fuel_bounded", FUEL)).fetch("profiles").first.fetch("loop", nil) == "fuel_bounded"
end

check("AST-2: absent `loop` ⇒ key absent (no restriction)") do
  !parse(prog(nil, NOLOOP)).fetch("profiles").first.key?("loop")
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF3 — loop class not permitted (hard error)"

check("PROF3-1: loop:none + recursive contract ⇒ OOF-PROF3") do
  contract_oofs(classify(prog("none", RECURSIVE)), "Act", "OOF-PROF3").any?
end

check("PROF3-2: OOF-PROF3 is a HARD error — contract is blocked") do
  typed(prog("none", RECURSIVE)).fetch("contracts").find { |x| x.fetch("name") == "Act" }
    .fetch("status") == "blocked"
end

check("PROF3-3: loop:none + fuel_bounded ⇒ OOF-PROF3") do
  contract_oofs(classify(prog("none", FUEL)), "Act", "OOF-PROF3").any?
end

check("PROF3-4: loop:none + budgeted_loop body ⇒ OOF-PROF3") do
  contract_oofs(classify(prog("none", BUDGETED)), "Act", "OOF-PROF3").any?
end

check("PROF3-5: loop:fuel_bounded + recursive (wrong class) ⇒ OOF-PROF3") do
  contract_oofs(classify(prog("fuel_bounded", RECURSIVE)), "Act", "OOF-PROF3").any?
end

check("PROF3-6: message names contract, offending class, and profile") do
  m = contract_oofs(classify(prog("fuel_bounded", RECURSIVE)), "Act", "OOF-PROF3").first.fetch("message")
  m.include?("Act") && m.include?("recursive") && m.include?("fuel_bounded") && m.include?("rp")
end

# ══════════════════════════════════════════════════════════════════════════════
section "Clean — permitted class, absent loop, no via"

check("CLEAN-1: loop:none + no-loop contract ⇒ clean") do
  contract_oofs(classify(prog("none", NOLOOP)), "Act", "OOF-PROF3").empty?
end

check("CLEAN-2: loop:recursive + recursive ⇒ clean") do
  contract_oofs(classify(prog("recursive", RECURSIVE)), "Act", "OOF-PROF3").empty?
end

check("CLEAN-3: loop:fuel_bounded + fuel_bounded ⇒ clean") do
  contract_oofs(classify(prog("fuel_bounded", FUEL)), "Act", "OOF-PROF3").empty?
end

check("CLEAN-4: loop:budgeted + budgeted_loop ⇒ clean") do
  contract_oofs(classify(prog("budgeted", BUDGETED)), "Act", "OOF-PROF3").empty?
end

check("CLEAN-5: loop:fuel_bounded + no-loop contract ⇒ clean (nothing to restrict)") do
  contract_oofs(classify(prog("fuel_bounded", NOLOOP)), "Act", "OOF-PROF3").empty?
end

check("CLEAN-6: absent `loop` + recursive ⇒ no constraint") do
  contract_oofs(classify(prog(nil, RECURSIVE)), "Act", "OOF-PROF3").empty?
end

check("CLEAN-7: contract WITHOUT `via` ⇒ loop restriction does not apply") do
  src = <<~IG
    module Proof.ProfileLoop
    profile rp { loop: none }
    recursive contract Unbound {
      input n: Integer
      compute total = n
      output total: Integer
      decreases n
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Unbound", "OOF-PROF3").empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF6 — aspirational / unknown loop value fails closed at parse"

check("PROF6-1: `loop: service` (Ch13 aspirational) ⇒ parse-time OOF-PROF6") do
  parse(prog("service", NOLOOP)).fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" }
end

check("PROF6-2: `loop: convergent` / `loop: finite_loop` also OOF-PROF6") do
  %w[convergent finite_loop].all? do |v|
    parse(prog(v, NOLOOP)).fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" }
  end
end

check("PROF6-3: aspirational value NOT stored (no spurious OOF-PROF3)") do
  !parse(prog("service", NOLOOP)).fetch("profiles").first.key?("loop")
end

# ══════════════════════════════════════════════════════════════════════════════
section "Regression — profile-policy suite coexists"

check("REG-1: all six PROF fields coexist; a fully-conforming contract is clean") do
  src = <<~IG
    module Proof.ProfileLoop
    profile rp {
      authority: effect
      retry: enabled
      max_reversibility: compensatable
      allowed_effects: [external.payment_gateway]
      requires_authority: [billing_operator]
      loop: none
    }
    effect contract Both via rp {
      input k: Text
      capability net: IO.NetworkCapability
      effect go using net
      affects external payment_gateway.charge
      authority billing_operator
      idempotency key k
      reversibility :compensatable
    }
  IG
  c = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
  %w[OOF-PROF1 OOF-PROF2 OOF-PROF3 OOF-PROF4 OOF-PROF5].all? { |r| contract_oofs(c, "Both", r).empty? }
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
