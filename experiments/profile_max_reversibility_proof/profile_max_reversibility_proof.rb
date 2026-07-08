#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/profile_max_reversibility_proof/profile_max_reversibility_proof.rb
#
# LANG-PROFILE-MAX-REVERSIBILITY-P32 (PROP-048) — second profile-policy rule and
# the FIRST place the ch12 reversibility scale ORDERING is encoded (P25 left it
# un-encoded). `max_reversibility: <scale>` on a profile is a ceiling on a bound
# contract's declared ch12 `reversibility`. Namespace/severity per P30:
#   - OOF-PROF5 (hard error) — declared reversibility exceeds the ceiling;
#   - OOF-PROF6 (parse-time, fail-closed) — malformed `max_reversibility` value.
# Compile-time POLICY only (Covenant P10). Ruby-canon (P33).
#
# Scale (least → most irreversible):
#   reversible < compensatable < refundable < append_only < irreversible < destructive

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
  IgniterLang::ParsedProgram.parse(src, source_path: "maxrev").to_h
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

# ceiling in the profile; contract_rev = optional `reversibility :<v>` clause.
def wrap(ceiling:, contract_rev:, via: "rp")
  rev_line = contract_rev ? "  reversibility :#{contract_rev}" : ""
  <<~IG
    module Proof.ProfileMaxRev

    profile rp {
      authority: effect
      max_reversibility: #{ceiling}
    }

    effect contract Act#{via ? " via #{via}" : ""} {
      capability net: IO.NetworkCapability
      effect go using net
    #{rev_line}
    }
  IG
end

puts "#{BOLD}#{CYAN}Profile max_reversibility proof (LANG-PROFILE-MAX-REVERSIBILITY-P32)#{RESET}"
puts "Path: igniter-lang/experiments/profile_max_reversibility_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "AST — `max_reversibility` retained; all six values accepted"

SCALE = %w[reversible compensatable refundable append_only irreversible destructive].freeze

check("AST-1: `max_reversibility` is stored on the profile node") do
  parse(wrap(ceiling: "compensatable", contract_rev: nil)).fetch("profiles").first
       .fetch("max_reversibility", nil) == "compensatable"
end

check("AST-2: all six scale values accepted in profile field position (no parse errors)") do
  SCALE.all? { |v| parse(wrap(ceiling: v, contract_rev: nil)).fetch("parse_errors").empty? }
end

check("AST-3: absent `max_reversibility` ⇒ key absent (no ceiling)") do
  src = <<~IG
    module Proof.ProfileMaxRev
    profile rp { authority: effect }
    effect contract Act via rp {
      capability net: IO.NetworkCapability
      effect go using net
    }
  IG
  !parse(src).fetch("profiles").first.key?("max_reversibility")
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF5 — declared reversibility exceeds the ceiling (hard error)"

check("PROF5-1: ceiling compensatable, contract :irreversible ⇒ OOF-PROF5") do
  contract_oofs(classify(wrap(ceiling: "compensatable", contract_rev: "irreversible")),
                "Act", "OOF-PROF5").any?
end

check("PROF5-2: OOF-PROF5 is a HARD error — contract is blocked") do
  typed(wrap(ceiling: "compensatable", contract_rev: "irreversible"))
    .fetch("contracts").find { |x| x.fetch("name") == "Act" }.fetch("status") == "blocked"
end

check("PROF5-3: message names contract, declared value, ceiling, and profile") do
  m = contract_oofs(classify(wrap(ceiling: "compensatable", contract_rev: "irreversible")),
                    "Act", "OOF-PROF5").first.fetch("message")
  m.include?("Act") && m.include?("irreversible") && m.include?("compensatable") && m.include?("rp")
end

check("PROF5-4: adjacent step over the line — refundable ceiling, :append_only ⇒ OOF-PROF5") do
  contract_oofs(classify(wrap(ceiling: "refundable", contract_rev: "append_only")),
                "Act", "OOF-PROF5").any?
end

check("PROF5-5: far over — reversible ceiling, :destructive ⇒ OOF-PROF5") do
  contract_oofs(classify(wrap(ceiling: "reversible", contract_rev: "destructive")),
                "Act", "OOF-PROF5").any?
end

# ══════════════════════════════════════════════════════════════════════════════
section "Clean — at/below ceiling, absent reversibility, no `via`"

check("CLEAN-1: equal to ceiling — compensatable ceiling, :compensatable ⇒ clean") do
  contract_oofs(classify(wrap(ceiling: "compensatable", contract_rev: "compensatable")),
                "Act", "OOF-PROF5").empty?
end

check("CLEAN-2: below ceiling — irreversible ceiling, :compensatable ⇒ clean") do
  contract_oofs(classify(wrap(ceiling: "irreversible", contract_rev: "compensatable")),
                "Act", "OOF-PROF5").empty?
end

check("CLEAN-3: absent contract reversibility (null, not a default) ⇒ clean") do
  contract_oofs(classify(wrap(ceiling: "reversible", contract_rev: nil)),
                "Act", "OOF-PROF5").empty?
end

check("CLEAN-4: highest ceiling destructive, :destructive ⇒ clean (boundary)") do
  contract_oofs(classify(wrap(ceiling: "destructive", contract_rev: "destructive")),
                "Act", "OOF-PROF5").empty?
end

check("CLEAN-5: contract WITHOUT `via` ⇒ no ceiling applies") do
  src = <<~IG
    module Proof.ProfileMaxRev
    profile rp { authority: effect max_reversibility: reversible }
    effect contract Unbound {
      capability net: IO.NetworkCapability
      effect go using net
      reversibility :destructive
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Unbound", "OOF-PROF5").empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF6 — malformed max_reversibility fails closed at parse"

check("PROF6-1: `max_reversibility: mostly` ⇒ parse-time OOF-PROF6") do
  parse(wrap(ceiling: "mostly", contract_rev: "compensatable"))
    .fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" }
end

check("PROF6-2: malformed ceiling is NOT stored (no OOF-PROF5 masking)") do
  !parse(wrap(ceiling: "mostly", contract_rev: "compensatable"))
    .fetch("profiles").first.key?("max_reversibility")
end

# ══════════════════════════════════════════════════════════════════════════════
section "Regression — P25 reversibility metadata + M7/M8 untouched"

check("REG-1: unbound contract with reversibility still emits the field (P25 intact)") do
  src = <<~IG
    module Proof.ProfileMaxRev
    effect contract Solo {
      capability net: IO.NetworkCapability
      effect go using net
      reversibility :irreversible
    }
  IG
  c = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
       .fetch("contracts").find { |x| x.fetch("name") == "Solo" }
  c.fetch("declarations").any? { |d| d.fetch("kind") == "reversibility" && d.fetch("value") == "irreversible" }
end

check("REG-2: retry (P31) and max_reversibility (P32) coexist on one profile") do
  src = <<~IG
    module Proof.ProfileMaxRev
    profile rp { authority: effect retry: enabled max_reversibility: compensatable }
    effect contract Both via rp {
      input k: Text
      capability net: IO.NetworkCapability
      effect go using net
      idempotency key k
      reversibility :compensatable
    }
  IG
  c = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
  contract_oofs(c, "Both", "OOF-PROF4").empty? && contract_oofs(c, "Both", "OOF-PROF5").empty?
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
