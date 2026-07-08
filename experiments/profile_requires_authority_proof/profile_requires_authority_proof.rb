#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/profile_requires_authority_proof/profile_requires_authority_proof.rb
#
# LANG-PROFILE-REQUIRES-AUTHORITY-P41 (PROP-049) — fourth profile-policy rule.
# `requires_authority: [role, ...]` on a profile OBLIGATES a bound contract to
# declare a ch12 `authority` clause whose role is among the list. This is a
# DECLARATION-CONSISTENCY check over source facts only (Covenant P10) — it
# resolves no roles, checks no passport, and GRANTS NOTHING at runtime. The
# runtime authority line (ch12 authority_ref → host AuthorityPolicy, P12–P20)
# is separate and HELD. Namespace/severity per P30: OOF-PROF2 hard error;
# malformed entry → OOF-PROF6. Ruby-canon (P33 HOLD Rust).
#
# PROP-049 ratified the DECLARATION-CONSISTENCY reading (ch11 §11.3), rejecting
# the §11.4 modifier-floor reading as redundant with OOF-M7. v0 matches the
# contract's single declared role; multi-role "declare ALL" is deferred to a
# ch12 multi-authority-clause extension.

require "json"

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"
require_relative "../../lib/igniter_lang/semanticir_emitter"

GREEN = "\e[32m"
RED   = "\e[31m"
CYAN  = "\e[36m"
BOLD  = "\e[1m"
RESET = "\e[0m"

def parse(src)
  IgniterLang::ParsedProgram.parse(src, source_path: "reqauth").to_h
end

def classify(src)
  IgniterLang::Classifier.new.classify(parse(src), sample_input: {})
end

def typed(src)
  IgniterLang::TypeChecker.new.typecheck(classify(src))
end

def sir(src)
  IgniterLang::SemanticIREmitter.new.emit_typed(typed(src))
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

# profile with requires_authority; contract that optionally declares authority.
def wrap(required:, declared:, via: "rp", profile_authority: "effect")
  auth_line = declared ? "  authority #{declared}" : ""
  <<~IG
    module Proof.ProfileReqAuth

    profile rp {
      authority: #{profile_authority}
      requires_authority: [#{required}]
    }

    effect contract Act#{via ? " via #{via}" : ""} {
      capability net: IO.NetworkCapability
      effect go using net
    #{auth_line}
    }
  IG
end

puts "#{BOLD}#{CYAN}Profile requires_authority proof (LANG-PROFILE-REQUIRES-AUTHORITY-P41 / PROP-049)#{RESET}"
puts "Path: igniter-lang/experiments/profile_requires_authority_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "GROUNDING — the PROP resolved a real gap"

check("GROUND-1: the list form now PARSES (was an uncaught ParseError pre-P41)") do
  parse(wrap(required: "billing_operator", declared: "billing_operator")).fetch("parse_errors").empty?
end

check("GROUND-2: `requires_authority` is retained as a role list on the profile") do
  parse(wrap(required: "billing_operator, refund_operator", declared: "billing_operator"))
    .fetch("profiles").first.fetch("requires_authority", nil) == %w[billing_operator refund_operator]
end

check("GROUND-3: the comparand is the live ch12 authority_ref (declared intent)") do
  c = classify(wrap(required: "billing_operator", declared: "billing_operator"))
  ct = c.fetch("contracts").find { |x| x.fetch("name") == "Act" }
  ct.fetch("declarations").any? { |d| d.fetch("kind") == "authority" && d.fetch("ref") == "billing_operator" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF2 — obligation not met (hard error)"

check("PROF2-1: required role, NO authority clause ⇒ OOF-PROF2") do
  contract_oofs(classify(wrap(required: "billing_operator", declared: nil)), "Act", "OOF-PROF2").any?
end

check("PROF2-2: OOF-PROF2 is a HARD error — contract is blocked") do
  typed(wrap(required: "billing_operator", declared: nil))
    .fetch("contracts").find { |x| x.fetch("name") == "Act" }.fetch("status") == "blocked"
end

check("PROF2-3: declared role NOT in the required set ⇒ OOF-PROF2") do
  contract_oofs(classify(wrap(required: "billing_operator", declared: "janitor")), "Act", "OOF-PROF2").any?
end

check("PROF2-4: message names contract, declared/missing authority, and profile") do
  m = contract_oofs(classify(wrap(required: "billing_operator", declared: "janitor")),
                    "Act", "OOF-PROF2").first.fetch("message")
  m.include?("Act") && m.include?("janitor") && m.include?("billing_operator") && m.include?("rp")
end

# ══════════════════════════════════════════════════════════════════════════════
section "Clean — obligation met, absent list, no via"

check("CLEAN-1: required role declared exactly ⇒ clean") do
  contract_oofs(classify(wrap(required: "billing_operator", declared: "billing_operator")),
                "Act", "OOF-PROF2").empty?
end

check("CLEAN-2: declared role is one of several required ⇒ clean") do
  contract_oofs(classify(wrap(required: "billing_operator, refund_operator", declared: "refund_operator")),
                "Act", "OOF-PROF2").empty?
end

check("CLEAN-3: absent requires_authority ⇒ no constraint") do
  src = <<~IG
    module Proof.ProfileReqAuth
    profile rp { authority: effect }
    effect contract Act via rp {
      capability net: IO.NetworkCapability
      effect go using net
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Act", "OOF-PROF2").empty?
end

check("CLEAN-4: contract WITHOUT `via` ⇒ requirement does not apply") do
  src = <<~IG
    module Proof.ProfileReqAuth
    profile rp { authority: effect requires_authority: [billing_operator] }
    effect contract Unbound {
      capability net: IO.NetworkCapability
      effect go using net
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}),
                "Unbound", "OOF-PROF2").empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF6 — malformed role entry fails closed at parse"

check("PROF6-1: dotted role (`Billing.Operator`) ⇒ OOF-PROF6") do
  parse(wrap(required: "Billing.Operator", declared: "billing_operator"))
    .fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" }
end

check("PROF6-2: dotted role is NOT stored (no spurious OOF-PROF2)") do
  p = parse(wrap(required: "Billing.Operator", declared: "billing_operator")).fetch("profiles").first
  (p.fetch("requires_authority", []) || []).none? { |r| r.include?(".") }
end

# ══════════════════════════════════════════════════════════════════════════════
section "GRANT-NOTHING — a passing check confers NO runtime authority (boundary guard)"

check("GRANT-1: passing requires_authority emits only the declared authority_ref (intent), no grant") do
  s = sir(wrap(required: "billing_operator", declared: "billing_operator"))
  es = s.dig("semantic_ir", "contracts")&.find { |c| c.fetch("contract_name") == "Act" }
        &.fetch("effect_surface", nil)
  # authority_ref is the SOURCE-DECLARED role, unchanged; there is NO granted
  # scope / passport / authorization field minted by the check.
  es && es.fetch("authority_ref") == "billing_operator" &&
    %w[granted scopes passport authorized authority_grant resolved_scopes].none? { |k| es.key?(k) }
end

check("GRANT-2: OOF-PROF2 lives only in oof_log — it mints no authority IR node") do
  c = classify(wrap(required: "billing_operator", declared: nil))
  ct = c.fetch("contracts").find { |x| x.fetch("name") == "Act" }
  # the failure is a diagnostic; no declaration was synthesized to satisfy it.
  ct.fetch("declarations").none? { |d| d.fetch("kind", "") == "authority" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "Regression — OOF-M7/M8 + PROF1/4/5 coexistence"

check("REG-1: profile authority floor (OOF-M7) still independent of requires_authority") do
  # effect contract binding a privileged-authority profile ⇒ OOF-M7 regardless.
  c = classify(wrap(required: "billing_operator", declared: "billing_operator",
                    profile_authority: "privileged"))
  contract_oofs(c, "Act", "OOF-M7").any?
end

check("REG-2: all PROP-048/049 fields coexist on one profile, fully-satisfied contract clean") do
  src = <<~IG
    module Proof.ProfileReqAuth
    profile rp {
      authority: effect
      retry: enabled
      max_reversibility: compensatable
      allowed_effects: [external.payment_gateway]
      requires_authority: [billing_operator]
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
  %w[OOF-PROF1 OOF-PROF2 OOF-PROF4 OOF-PROF5].all? { |r| contract_oofs(c, "Both", r).empty? }
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
