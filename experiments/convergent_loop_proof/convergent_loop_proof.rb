#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/convergent_loop_proof/convergent_loop_proof.rb
#
# LANG-CH13-CONVERGENT-LOOP-P46 (PROP-050) — the 4th of Ch13's five loop classes.
# `convergent contract` repeats while driving a metric toward a threshold,
# terminating on convergence OR fuel exhaustion. This proof locks the v0
# COMPILE-TIME obligations (the compiler does NOT prove convergence — termination
# is guaranteed by `max_steps`, exactly like `fuel_bounded`):
#   required clauses: `variant <metric>` (OOF-R12), `convergence epsilon: <n>`
#   (OOF-R13), `max_steps <n>` (OOF-R4, reused), `on_exhaustion :<action>`
#   (OOF-R14). Malformed on_exhaustion / non-numeric epsilon fail closed.
#   `convergent` is recur-authorized (recur() valid, fuel-capped) and has no
#   `decreases`, so OOF-R3 does not apply. ch11 `loop: convergent` now enforces
#   the class. Ruby-canon (Rust parity HOLD, P33).

require "json"

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"

GREEN = "\e[32m"; RED = "\e[31m"; CYAN = "\e[36m"; BOLD = "\e[1m"; RESET = "\e[0m"

def parse(src) = IgniterLang::ParsedProgram.parse(src, source_path: "conv").to_h
def classify(src) = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
def typed(src) = IgniterLang::TypeChecker.new.typecheck(classify(src))

def contract_oofs(classified, name, rule)
  c = classified.fetch("contracts").find { |x| x.fetch("name") == name }
  c.fetch("oof_log", []).select { |d| d.fetch("rule", d["code"]) == rule }
end

RESULTS = []
def check(label, &b)
  r = b.call
  puts "  #{r ? GREEN : RED}[#{r ? 'PASS' : 'FAIL'}]#{RESET} #{label}"
  RESULTS << r
rescue => e
  puts "  #{RED}[ERROR]#{RESET} #{label}: #{e.message}"; RESULTS << false
end
def section(t) = puts("\n#{CYAN}#{BOLD}── #{t} ──#{RESET}")

# A fully-declared convergent contract. `drop` clauses to trigger obligations.
def convergent(drop: [])
  lines = {
    "variant"       => "  variant loss(params)",
    "convergence"   => "  convergence epsilon: 0.001",
    "max_steps"     => "  max_steps 100000",
    "on_exhaustion" => "  on_exhaustion :return_partial"
  }
  drop.each { |k| lines.delete(k) }
  <<~IG
    module Proof.Convergent
    convergent contract Optimize {
      input params: Integer
    #{lines.values.join("\n")}
      compute result = params
      output result: Integer
    }
  IG
end

puts "#{BOLD}#{CYAN}ConvergentLoop proof (LANG-CH13-CONVERGENT-LOOP-P46 / PROP-050)#{RESET}"
puts "Path: igniter-lang/experiments/convergent_loop_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "MODIFIER + fully-declared convergent contract is clean"

check("CONV-1: `convergent` is a valid contract modifier (parses, no errors)") do
  p = parse(convergent)
  p.fetch("parse_errors").empty? &&
    p.fetch("contracts").first.fetch("modifier") == "convergent"
end

check("CONV-2: all four obligations present ⇒ no OOF-R* diagnostics") do
  c = classify(convergent)
  ct = c.fetch("contracts").find { |x| x.fetch("name") == "Optimize" }
  ct.fetch("oof_log", []).none? { |d| d.fetch("rule", d["code"]).start_with?("OOF-R") }
end

check("CONV-3: fully-declared convergent contract typechecks (status accepted)") do
  typed(convergent).fetch("contracts").first.fetch("status") == "accepted"
end

# ══════════════════════════════════════════════════════════════════════════════
section "Required obligations — each missing clause is a hard error"

check("R8: missing `variant` ⇒ OOF-R12") do
  contract_oofs(classify(convergent(drop: ["variant"])), "Optimize", "OOF-R12").any?
end

check("R9: missing `convergence` ⇒ OOF-R13") do
  contract_oofs(classify(convergent(drop: ["convergence"])), "Optimize", "OOF-R13").any?
end

check("R4: missing `max_steps` ⇒ OOF-R4 (fuel cap = termination guarantee)") do
  contract_oofs(classify(convergent(drop: ["max_steps"])), "Optimize", "OOF-R4").any?
end

check("R10: missing `on_exhaustion` ⇒ OOF-R14") do
  contract_oofs(classify(convergent(drop: ["on_exhaustion"])), "Optimize", "OOF-R14").any?
end

check("R-ALL: a bare convergent contract fires all four obligations") do
  c = classify(convergent(drop: %w[variant convergence max_steps on_exhaustion]))
  %w[OOF-R12 OOF-R13 OOF-R4 OOF-R14].all? { |r| contract_oofs(c, "Optimize", r).any? }
end

check("R-HARD: a missing obligation blocks the contract (status blocked)") do
  typed(convergent(drop: ["variant"])).fetch("contracts").first.fetch("status") == "blocked"
end

# ══════════════════════════════════════════════════════════════════════════════
section "Malformed clauses fail closed"

check("MAL-1: `on_exhaustion :nonsense` (unknown action) fails closed ⇒ OOF-R14") do
  src = convergent.sub("on_exhaustion :return_partial", "on_exhaustion :teleport")
  # parse-time refusal drops the clause; classifier then reports it missing.
  pe = parse(src).fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-R14" }
  cl = contract_oofs(classify(src), "Optimize", "OOF-R14").any?
  pe && cl
end

check("MAL-2: `convergence epsilon: fast` (non-numeric) fails closed ⇒ OOF-R13") do
  src = convergent.sub("convergence epsilon: 0.001", "convergence epsilon: fast")
  parse(src).fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-R13" } &&
    contract_oofs(classify(src), "Optimize", "OOF-R13").any?
end

check("MAL-3: integer epsilon (`epsilon: 1`) is accepted (int_lit or float_lit)") do
  src = convergent.sub("epsilon: 0.001", "epsilon: 1")
  parse(src).fetch("parse_errors").empty? &&
    contract_oofs(classify(src), "Optimize", "OOF-R13").empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "Recursion model — convergent is recur-authorized, no OOF-R3"

check("REC-1: recur() inside a convergent contract is NOT OOF-R1 (authorized)") do
  src = <<~IG
    module Proof.Convergent
    convergent contract Optimize {
      input params: Integer
      variant loss(params)
      convergence epsilon: 0.001
      max_steps 100000
      on_exhaustion :return_partial
      compute result = recur(params)
      output result: Integer
    }
  IG
  t = IgniterLang::TypeChecker.new.typecheck(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}))
  errs = t.fetch("contracts").first.fetch("type_errors", []).map { |d| d.fetch("rule", d["code"]) }
  !errs.include?("OOF-R1")
end

check("REC-2: convergent has no `decreases` ⇒ OOF-R3 does not apply") do
  src = <<~IG
    module Proof.Convergent
    convergent contract Optimize {
      input params: Integer
      variant loss(params)
      convergence epsilon: 0.001
      max_steps 100000
      on_exhaustion :return_partial
      compute result = recur(params)
      output result: Integer
    }
  IG
  t = IgniterLang::TypeChecker.new.typecheck(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}))
  t.fetch("contracts").first.fetch("type_errors", []).none? { |d| d.fetch("rule", d["code"]) == "OOF-R3" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "ch11 hook — `loop: convergent` now enforces the class"

check("CH11-1: profile `loop: convergent` + convergent contract ⇒ clean") do
  src = <<~IG
    module Proof.Convergent
    profile rp { loop: convergent }
    convergent contract Optimize via rp {
      input params: Integer
      variant loss(params)
      convergence epsilon: 0.001
      max_steps 100000
      on_exhaustion :return_partial
      compute result = params
      output result: Integer
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Optimize", "OOF-PROF3").empty?
end

check("CH11-2: profile `loop: none` + convergent contract ⇒ OOF-PROF3") do
  src = <<~IG
    module Proof.Convergent
    profile rp { loop: none }
    convergent contract Optimize via rp {
      input params: Integer
      variant loss(params)
      convergence epsilon: 0.001
      max_steps 100000
      on_exhaustion :return_partial
      compute result = params
      output result: Integer
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Optimize", "OOF-PROF3").any?
end

check("CH11-3: `loop: convergent` is live vocab (no OOF-PROF6)") do
  parse("module M\nprofile rp { loop: convergent }\n").fetch("parse_errors")
    .none? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "Regression — the live loop-class family is intact"

check("REG-1: `fuel_bounded` + max_steps still clean (OOF-R4 unchanged)") do
  src = <<~IG
    module M
    fuel_bounded contract S {
      input n: Integer
      compute result = n
      output result: Integer
      max_steps 5000
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}), "S", "OOF-R4").empty?
end

check("REG-2: top-level `variant` sum-type decl still parses (no body-clause shadow)") do
  src = <<~IG
    module M
    variant Color { Red, Green, Blue }
    pure contract P { input x: Integer compute y = x output y: Integer }
  IG
  parse(src).fetch("parse_errors").empty? &&
    parse(src).fetch("variants").any? { |v| v.fetch("name") == "Color" }
end

passed = RESULTS.count(&:itself); total = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
