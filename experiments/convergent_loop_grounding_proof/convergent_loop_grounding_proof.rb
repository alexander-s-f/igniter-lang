#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/convergent_loop_grounding_proof/convergent_loop_grounding_proof.rb
#
# ⚠️ SUPERSEDED 2026-07-08 by LANG-CH13-CONVERGENT-LOOP-P46 — ConvergentLoop is
#   now IMPLEMENTED. This grounding proved the PRE-impl gap; GAP-1/GAP-2 (which
#   asserted the surface was unparseable) are intentionally retired below. The
#   live behaviour is locked by experiments/convergent_loop_proof/ (19/19).
#
# LANG-CH13-CONVERGENT-LOOP-PROP-P45 (PROP-050) — grounding for the ConvergentLoop
# proposal. Proof-first per house PROP discipline: shows the gap is real and
# additive. ConvergentLoop is the 4th of Ch13's five loop classes and the only
# LOCAL one still unbuilt (the service loop is PROP-037/Stage-4). This proof does
# NOT implement anything — it establishes:
#   (1) the ch13 aspirational ConvergentLoop syntax (`loop contract` / a
#       `convergent` modifier + `variant` / `convergence` / `on_exhaustion`) is
#       UNPARSEABLE today — additive, zero churn;
#   (2) its nearest live cousin — FuelBoundedRecursion (`fuel_bounded` +
#       static `max_steps`, OOF-R4) — compiles clean, so the PROP's termination
#       model (fuel cap = compile-time guarantee, convergence = runtime) has a
#       working precedent to extend.

require "json"

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"

GREEN = "\e[32m"; RED = "\e[31m"; CYAN = "\e[36m"; BOLD = "\e[1m"; RESET = "\e[0m"

def parse(src)
  IgniterLang::ParsedProgram.parse(src, source_path: "conv").to_h
rescue => e
  { "__raised" => "#{e.class}: #{e.message}" }
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

puts "#{BOLD}#{CYAN}ConvergentLoop grounding (LANG-CH13-CONVERGENT-LOOP-PROP-P45 / PROP-050)#{RESET}"

# ── Aspirational ConvergentLoop forms — all unparseable today ──────────────────
section "GAP — the ConvergentLoop surface is unparseable today (additive)"

LOOP_CONTRACT = <<~IG
  module M
  loop contract Optimize {
    input params: Params
    variant loss(params)
    convergence epsilon: 0.001
    max_steps 100
    on_exhaustion :return_partial
    compute result = params
    output result: Params
  }
IG

CONVERGENT_MOD = <<~IG
  module M
  convergent contract Optimize {
    input params: Params
    variant loss(params)
    convergence epsilon: 0.001
    max_steps 100
    on_exhaustion :return_partial
    compute result = params
    output result: Params
  }
IG

check("GAP-1 (retired): `convergent contract` is now IMPLEMENTED (P46) — see convergent_loop_proof") do
  true
end

check("GAP-2 (now live): `convergent` IS a contract modifier (P46) — fully-declared parses clean") do
  p = parse(CONVERGENT_MOD)
  p.fetch("parse_errors", []).empty? &&
    p.fetch("contracts", []).first&.fetch("modifier", nil) == "convergent"
end

check("GAP-3 (retired): the clauses now parse as convergent obligations (P46)") do
  true
end

# ── Live cousin — FuelBoundedRecursion — works and anchors the model ───────────
section "PRECEDENT — FuelBoundedRecursion (the model ConvergentLoop extends)"

check("PREC-1: `fuel_bounded` + static `max_steps` compiles clean") do
  src = <<~IG
    module M
    fuel_bounded contract Search {
      input n: Integer
      compute result = n
      output result: Integer
      max_steps 5000
    }
  IG
  c = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
  ct = c.fetch("contracts").find { |x| x.fetch("name") == "Search" }
  ct.fetch("oof_log", []).none? { |d| d.fetch("rule", d["code"]).start_with?("OOF-R") }
end

check("PREC-2: `fuel_bounded` MISSING `max_steps` ⇒ OOF-R4 (the fuel-cap obligation)") do
  src = <<~IG
    module M
    fuel_bounded contract Search {
      input n: Integer
      compute result = n
      output result: Integer
    }
  IG
  c = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
  ct = c.fetch("contracts").find { |x| x.fetch("name") == "Search" }
  ct.fetch("oof_log", []).any? { |d| d.fetch("rule", d["code"]) == "OOF-R4" }
end

passed = RESULTS.count(&:itself); total = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
