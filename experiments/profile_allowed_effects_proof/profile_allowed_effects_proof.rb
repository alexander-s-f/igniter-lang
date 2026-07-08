#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/profile_allowed_effects_proof/profile_allowed_effects_proof.rb
#
# LANG-PROFILE-ALLOWED-EFFECTS-P35 (PROP-048) — third profile-policy rule.
# `allowed_effects: [<scope>.<system>, ...]` on a profile is an allow-list over
# a bound contract's Effect Surface `affects <scope> <target>` clause. Semantics
# ratified by LANG-PROFILE-ALLOWED-EFFECTS-READINESS-P34; namespace/severity by
# P30:
#   - OOF-PROF1 (hard error) — bound `affects` target not permitted by the list;
#   - OOF-PROF6 (parse-time, fail-closed) — malformed list entry.
# Match rule: same scope AND (exact target OR dot-boundary prefix). Absent list ⇒
# no restriction; no `affects` ⇒ no violation; empty list ⇒ lock-down.
# Compile-time POLICY only (Covenant P10). Ruby-canon (P33).

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
  IgniterLang::ParsedProgram.parse(src, source_path: "allowed").to_h
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

# profile with an allowed_effects list; contract with one affects clause.
def wrap(allowed:, affects:, via: "rp")
  <<~IG
    module Proof.ProfileAllowed

    profile rp {
      authority: effect
      allowed_effects: [#{allowed}]
    }

    effect contract Act#{via ? " via #{via}" : ""} {
      capability net: IO.NetworkCapability
      effect go using net
      affects #{affects}
    }
  IG
end

puts "#{BOLD}#{CYAN}Profile allowed_effects proof (LANG-PROFILE-ALLOWED-EFFECTS-P35)#{RESET}"
puts "Path: igniter-lang/experiments/profile_allowed_effects_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "AST — `allowed_effects` list retained and normalized"

check("AST-1: list stored as [{scope,target_prefix}]") do
  p = parse(wrap(allowed: "external.payment_gateway, internal.ledger",
                 affects: "external payment_gateway.charge")).fetch("profiles").first
  p.fetch("allowed_effects", nil) ==
    [{ "scope" => "external", "target_prefix" => "payment_gateway" },
     { "scope" => "internal", "target_prefix" => "ledger" }]
end

check("AST-2: absent allowed_effects ⇒ key absent") do
  src = <<~IG
    module Proof.ProfileAllowed
    profile rp { authority: effect }
    effect contract Act via rp {
      capability net: IO.NetworkCapability
      effect go using net
      affects external x.y
    }
  IG
  !parse(src).fetch("profiles").first.key?("allowed_effects")
end

check("AST-3: empty list stored as [] (lock-down, distinct from absent)") do
  src = <<~IG
    module Proof.ProfileAllowed
    profile rp { authority: effect allowed_effects: [] }
    effect contract Act via rp {
      capability net: IO.NetworkCapability
      effect go using net
    }
  IG
  parse(src).fetch("profiles").first.fetch("allowed_effects", :missing) == []
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF1 — affects target outside the allow-list (hard error)"

check("PROF1-1: affects external evil.x, list [external.payment_gateway] ⇒ OOF-PROF1") do
  contract_oofs(classify(wrap(allowed: "external.payment_gateway", affects: "external evil.charge")),
                "Act", "OOF-PROF1").any?
end

check("PROF1-2: OOF-PROF1 is a HARD error — contract is blocked") do
  typed(wrap(allowed: "external.payment_gateway", affects: "external evil.charge"))
    .fetch("contracts").find { |x| x.fetch("name") == "Act" }.fetch("status") == "blocked"
end

check("PROF1-3: message names contract, affects scope+target, and profile") do
  m = contract_oofs(classify(wrap(allowed: "external.payment_gateway", affects: "external evil.charge")),
                    "Act", "OOF-PROF1").first.fetch("message")
  m.include?("Act") && m.include?("external evil.charge") && m.include?("rp")
end

check("PROF1-4: scope discrimination — external.X does NOT permit internal.X") do
  contract_oofs(classify(wrap(allowed: "external.payment_gateway", affects: "internal payment_gateway.charge")),
                "Act", "OOF-PROF1").any?
end

check("PROF1-5: prefix is dot-bounded — payment_gateway does NOT permit payment_gateway_evil") do
  contract_oofs(classify(wrap(allowed: "external.payment_gateway", affects: "external payment_gateway_evil.x")),
                "Act", "OOF-PROF1").any?
end

check("PROF1-6: empty allow-list ⇒ any affects is rejected (lock-down)") do
  src = <<~IG
    module Proof.ProfileAllowed
    profile rp { authority: effect allowed_effects: [] }
    effect contract Act via rp {
      capability net: IO.NetworkCapability
      effect go using net
      affects external anything.here
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Act", "OOF-PROF1").any?
end

# ══════════════════════════════════════════════════════════════════════════════
section "Clean — permitted targets, absent list, no affects, no via"

check("CLEAN-1: exact target match ⇒ clean") do
  contract_oofs(classify(wrap(allowed: "external.payment_gateway.charge",
                              affects: "external payment_gateway.charge")),
                "Act", "OOF-PROF1").empty?
end

check("CLEAN-2: dot-boundary prefix match ⇒ clean (system covers its ops)") do
  contract_oofs(classify(wrap(allowed: "external.payment_gateway",
                              affects: "external payment_gateway.charge")),
                "Act", "OOF-PROF1").empty?
end

check("CLEAN-3: one of several entries matches ⇒ clean") do
  contract_oofs(classify(wrap(allowed: "external.payment_gateway, internal.ledger",
                              affects: "internal ledger.write")),
                "Act", "OOF-PROF1").empty?
end

check("CLEAN-4: absent allowed_effects ⇒ no restriction") do
  src = <<~IG
    module Proof.ProfileAllowed
    profile rp { authority: effect }
    effect contract Act via rp {
      capability net: IO.NetworkCapability
      effect go using net
      affects external whatever.x
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Act", "OOF-PROF1").empty?
end

check("CLEAN-5: contract with NO affects clause ⇒ no violation") do
  src = <<~IG
    module Proof.ProfileAllowed
    profile rp { authority: effect allowed_effects: [external.payment_gateway] }
    effect contract Act via rp {
      capability net: IO.NetworkCapability
      effect go using net
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Act", "OOF-PROF1").empty?
end

check("CLEAN-6: contract WITHOUT `via` ⇒ list does not apply") do
  src = <<~IG
    module Proof.ProfileAllowed
    profile rp { authority: effect allowed_effects: [external.payment_gateway] }
    effect contract Unbound {
      capability net: IO.NetworkCapability
      effect go using net
      affects external evil.x
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Unbound", "OOF-PROF1").empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF6 — malformed list entry fails closed at parse"

check("PROF6-1: entry without a scope (`payment_gateway`) ⇒ OOF-PROF6") do
  parse(wrap(allowed: "payment_gateway", affects: "external payment_gateway.charge"))
    .fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" }
end

check("PROF6-2: entry with a non-external/internal scope (`sideways.x`) ⇒ OOF-PROF6") do
  parse(wrap(allowed: "sideways.x", affects: "external payment_gateway.charge"))
    .fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "Regression — affects metadata + M7/M8 + PROF4/5 coexistence"

check("REG-1: unbound affects still parses+emits (P5 intact)") do
  src = <<~IG
    module Proof.ProfileAllowed
    effect contract Solo {
      capability net: IO.NetworkCapability
      effect go using net
      affects external system.op
    }
  IG
  c = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
       .fetch("contracts").find { |x| x.fetch("name") == "Solo" }
  c.fetch("declarations").any? { |d| d.fetch("kind") == "affects" && d.fetch("target") == "system.op" }
end

check("REG-2: all four PROP-048 fields coexist on one profile, clean bound contract") do
  src = <<~IG
    module Proof.ProfileAllowed
    profile rp {
      authority: effect
      retry: enabled
      max_reversibility: compensatable
      allowed_effects: [external.payment_gateway]
    }
    effect contract Both via rp {
      input k: Text
      capability net: IO.NetworkCapability
      effect go using net
      affects external payment_gateway.charge
      idempotency key k
      reversibility :compensatable
    }
  IG
  c = IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
  %w[OOF-PROF1 OOF-PROF4 OOF-PROF5].all? { |r| contract_oofs(c, "Both", r).empty? }
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
