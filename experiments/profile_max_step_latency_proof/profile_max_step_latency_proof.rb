#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/profile_max_step_latency_proof/profile_max_step_latency_proof.rb
#
# LANG-PROFILE-MAX-STEP-LATENCY-P52 (ch11 §11.3) — the last compile-time
# profile-policy field. A profile `max_step_latency: <dur>` is a CEILING over a
# bound service contract's declared `max_step_latency <dur>` clause (P50).
# Durations are normalized to milliseconds (ms/second/minute/hour, singular +
# plural); a bound latency ABOVE the ceiling — or one whose unit is unrecognized
# — fails closed with OOF-PROF8 (hard). Equal/below/absent/no-via clean; a
# malformed profile duration fails closed at parse with OOF-PROF6. Declaration
# policy (Covenant P10) — grants no runtime liveness (runtime heartbeat/latency
# checking is SL10+, HELD). Ruby-canon.

require "json"

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"

GREEN = "\e[32m"; RED = "\e[31m"; CYAN = "\e[36m"; BOLD = "\e[1m"; RESET = "\e[0m"

def parse(src) = IgniterLang::ParsedProgram.parse(src, source_path: "msl").to_h
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

# service contract with a given max_step_latency budget, bound to profile sp.
def svc(latency: "2.seconds")
  <<~C
    service contract Watch via sp {
      heartbeat every 10.seconds
      cancellation required
      max_step_latency #{latency}
    }
  C
end

def prog(profile_body, contract)
  "module Proof.MSL\nprofile sp { #{profile_body} }\n#{contract}"
end

puts "#{BOLD}#{CYAN}Profile max_step_latency ceiling proof (LANG-PROFILE-MAX-STEP-LATENCY-P52)#{RESET}"
puts "Path: igniter-lang/experiments/profile_max_step_latency_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "AST + parse"

check("AST-1: `max_step_latency: 10.seconds` stored raw on the profile") do
  parse(prog("loop: service  max_step_latency: 10.seconds", svc)).fetch("profiles").first
    .fetch("max_step_latency", nil) == "10.seconds"
end

check("AST-2: absent ceiling ⇒ key absent") do
  !parse(prog("loop: service", svc)).fetch("profiles").first.key?("max_step_latency")
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF8 — bound latency exceeds the ceiling (hard error)"

check("PROF8-1: budget 5.seconds > ceiling 2.seconds ⇒ OOF-PROF8") do
  contract_oofs(classify(prog("loop: service  max_step_latency: 2.seconds", svc(latency: "5.seconds"))),
                "Watch", "OOF-PROF8").any?
end

check("PROF8-2: OOF-PROF8 is a HARD error — contract blocked") do
  typed(prog("max_step_latency: 2.seconds", svc(latency: "5.seconds")))
    .fetch("contracts").find { |x| x.fetch("name") == "Watch" }.fetch("status") == "blocked"
end

check("PROF8-3: mixed units — 90.seconds > 1.minute ⇒ OOF-PROF8 (normalized compare)") do
  contract_oofs(classify(prog("max_step_latency: 1.minute", svc(latency: "90.seconds"))),
                "Watch", "OOF-PROF8").any?
end

check("PROF8-4: message names contract, budget, and ceiling") do
  m = contract_oofs(classify(prog("max_step_latency: 2.seconds", svc(latency: "5.seconds"))),
                    "Watch", "OOF-PROF8").first.fetch("message")
  m.include?("Watch") && m.include?("5.seconds") && m.include?("2.seconds")
end

# ══════════════════════════════════════════════════════════════════════════════
section "Clean — equal, below (incl. mixed units), absent, no via"

check("CLEAN-1: budget 2.seconds == ceiling 2.seconds ⇒ clean") do
  contract_oofs(classify(prog("max_step_latency: 2.seconds", svc(latency: "2.seconds"))),
                "Watch", "OOF-PROF8").empty?
end

check("CLEAN-2: budget 500.ms < ceiling 1.seconds (mixed) ⇒ clean") do
  contract_oofs(classify(prog("max_step_latency: 1.seconds", svc(latency: "500.ms"))),
                "Watch", "OOF-PROF8").empty?
end

check("CLEAN-3: budget 30.seconds < ceiling 1.minute (mixed) ⇒ clean") do
  contract_oofs(classify(prog("max_step_latency: 1.minute", svc(latency: "30.seconds"))),
                "Watch", "OOF-PROF8").empty?
end

check("CLEAN-4: absent ceiling ⇒ no constraint") do
  contract_oofs(classify(prog("loop: service", svc(latency: "5.hours"))), "Watch", "OOF-PROF8").empty?
end

check("CLEAN-5: contract WITHOUT `via` ⇒ ceiling does not apply") do
  src = <<~IG
    module Proof.MSL
    profile sp { max_step_latency: 1.seconds }
    service contract Unbound {
      heartbeat every 10.seconds
      cancellation required
      max_step_latency 5.hours
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Unbound", "OOF-PROF8").empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "Fail-closed — malformed / unrecognized units"

check("MAL-1: malformed profile ceiling (10.fortnights) ⇒ OOF-PROF6, not stored") do
  p = parse(prog("max_step_latency: 10.fortnights", svc))
  p.fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" } &&
    !p.fetch("profiles").first.key?("max_step_latency")
end

check("MAL-2: refused ceiling cannot spuriously fire OOF-PROF8") do
  contract_oofs(classify(prog("max_step_latency: 10.fortnights", svc(latency: "9.hours"))),
                "Watch", "OOF-PROF8").empty?
end

check("MAL-3: bound latency with unrecognized unit ⇒ fail-closed OOF-PROF8") do
  contract_oofs(classify(prog("max_step_latency: 1.minute", svc(latency: "2.fortnights"))),
                "Watch", "OOF-PROF8").any?
end

check("MAL-4: non-numeric profile value (max_step_latency: soon) ⇒ OOF-PROF6") do
  parse(prog("max_step_latency: soon", svc)).fetch("parse_errors")
    .any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "Coexistence with P50/P51 + grant-nothing"

check("COEX-1: ceiling + service obligations + loop:service all satisfied ⇒ clean") do
  src = prog("loop: service  checkpoint: required  max_step_latency: 5.seconds",
             <<~C)
               service contract Watch via sp {
                 heartbeat every 10.seconds
                 cancellation required
                 checkpoint every 1.minute
                 max_step_latency 2.seconds
               }
             C
  c = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
  %w[OOF-PROF3 OOF-PROF7 OOF-PROF8 OOF-SL1 OOF-SL2 OOF-SL3].all? { |r| contract_oofs(c, "Watch", r).empty? }
end

check("GRANT-1: a within-ceiling pass mints no runtime/liveness node") do
  t = typed(prog("max_step_latency: 5.seconds", svc(latency: "2.seconds")))
  kinds = t.fetch("contracts").find { |x| x.fetch("name") == "Watch" }.fetch("declarations", []).map { |d| d.fetch("kind", "") }
  %w[alive liveness scheduler latency_grant].none? { |k| kinds.include?(k) }
end

passed = RESULTS.count(&:itself); total = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
