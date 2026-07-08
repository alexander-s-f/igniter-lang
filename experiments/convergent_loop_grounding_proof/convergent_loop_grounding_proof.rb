#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/convergent_loop_grounding_proof/convergent_loop_grounding_proof.rb
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

check("GAP-1: `loop contract …` header does not parse cleanly (many errors or raise)") do
  p = parse(LOOP_CONTRACT)
  p["__raised"] || !p.fetch("parse_errors", []).empty?
end

check("GAP-2: `convergent` is NOT a contract modifier today (body clauses unrecognized)") do
  p = parse(CONVERGENT_MOD)
  # `convergent` is not in CONTRACT_MODIFIERS, and variant/convergence/on_exhaustion
  # are not clauses ⇒ parse errors (or the header is mis-read).
  p["__raised"] || !p.fetch("parse_errors", []).empty? ||
    (p.fetch("contracts", []).first && p["contracts"].first.fetch("modifier", "pure") != "convergent")
end

check("GAP-3: `variant` / `convergence` / `on_exhaustion` are unknown clauses") do
  src = <<~IG
    module M
    fuel_bounded contract X {
      input n: Integer
      compute result = n
      output result: Integer
      max_steps 100
      convergence epsilon: 0.001
    }
  IG
  p = parse(src)
  p["__raised"] || !p.fetch("parse_errors", []).empty?
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
