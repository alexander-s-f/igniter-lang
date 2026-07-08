#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/profile_idempotency_retry_proof/profile_idempotency_retry_proof.rb
#
# LANG-PROFILE-IDEMPOTENCY-RETRY-P31 (PROP-048) — first profile-policy rule.
# `retry: enabled|disabled` on profile declarations + the retry×idempotency
# contradiction. Namespace/severity ratified by
# LANG-CH11-OOF-NAMESPACE-RECONCILE-P30:
#   - OOF-PROF4 (hard error) — retry-enabled profile bound to a contract that
#     declares `idempotency none`;
#   - OOF-PROF6 (parse-time, fail-closed) — malformed `retry` value.
# Compile-time POLICY only (Covenant P10): grants nothing at runtime; host
# authority (P12–P20) is untouched. Ruby-canon (profiles are Ruby-only; P33).
#
# Matrix (P31 card § Semantics):
#   enabled  + none    → OOF-PROF4
#   enabled  + key     → clean
#   enabled  + natural → clean
#   disabled + none    → clean
#   absent   + none    → clean
#   no `via` + none    → clean
#   malformed retry    → OOF-PROF6 (parse)

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
  IgniterLang::ParsedProgram.parse(src, source_path: "retry").to_h
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

def profile_wrap(profile_body, contract_body, via: "rp")
  <<~IG
    module Proof.ProfileRetry

    profile rp {
    #{profile_body}
    }

    effect contract SendThing#{via ? " via #{via}" : ""} {
      input order_id: Text
      capability net: IO.NetworkCapability
      effect send using net
    #{contract_body}
    }
  IG
end

puts "#{BOLD}#{CYAN}Profile retry × idempotency proof (LANG-PROFILE-IDEMPOTENCY-RETRY-P31)#{RESET}"
puts "Path: igniter-lang/experiments/profile_idempotency_retry_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "AST — `retry` is retained (P31 core)"

check("AST-1: `retry: enabled` is stored on the profile node") do
  p = parse(profile_wrap("  authority: effect\n  retry: enabled", "  idempotency none")).fetch("profiles").first
  p.fetch("retry", nil) == "enabled"
end

check("AST-2: `retry: disabled` is stored") do
  p = parse(profile_wrap("  authority: effect\n  retry: disabled", "  idempotency none")).fetch("profiles").first
  p.fetch("retry", nil) == "disabled"
end

check("AST-3: absent `retry` ⇒ key absent (no default)") do
  p = parse(profile_wrap("  authority: effect", "  idempotency none")).fetch("profiles").first
  !p.key?("retry")
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF4 — the retry × idempotency-none contradiction (hard error)"

check("PROF4-1: enabled + `idempotency none` ⇒ OOF-PROF4") do
  c = classify(profile_wrap("  authority: effect\n  retry: enabled", "  idempotency none"))
  contract_oofs(c, "SendThing", "OOF-PROF4").any?
end

check("PROF4-2: OOF-PROF4 is a HARD error — contract is blocked") do
  t = typed(profile_wrap("  authority: effect\n  retry: enabled", "  idempotency none"))
  t.fetch("contracts").find { |x| x.fetch("name") == "SendThing" }.fetch("status") == "blocked"
end

check("PROF4-3: OOF-PROF4 message names both the contract and the profile") do
  c = classify(profile_wrap("  authority: effect\n  retry: enabled", "  idempotency none"))
  m = contract_oofs(c, "SendThing", "OOF-PROF4").first.fetch("message")
  m.include?("SendThing") && m.include?("rp") && m.include?("idempotency none")
end

# ══════════════════════════════════════════════════════════════════════════════
section "Clean cases — the rule fires ONLY on the exact contradiction"

check("CLEAN-1: enabled + `idempotency key order_id` ⇒ no OOF-PROF4") do
  c = classify(profile_wrap("  authority: effect\n  retry: enabled", "  idempotency key order_id"))
  contract_oofs(c, "SendThing", "OOF-PROF4").empty?
end

check("CLEAN-2: enabled + `idempotency natural` ⇒ no OOF-PROF4") do
  c = classify(profile_wrap("  authority: effect\n  retry: enabled", "  idempotency natural"))
  contract_oofs(c, "SendThing", "OOF-PROF4").empty?
end

check("CLEAN-3: `retry: disabled` + `idempotency none` ⇒ no OOF-PROF4") do
  c = classify(profile_wrap("  authority: effect\n  retry: disabled", "  idempotency none"))
  contract_oofs(c, "SendThing", "OOF-PROF4").empty?
end

check("CLEAN-4: absent `retry` + `idempotency none` ⇒ no OOF-PROF4") do
  c = classify(profile_wrap("  authority: effect", "  idempotency none"))
  contract_oofs(c, "SendThing", "OOF-PROF4").empty?
end

check("CLEAN-5: contract WITHOUT `via` + `idempotency none` ⇒ no OOF-PROF4") do
  src = <<~IG
    module Proof.ProfileRetry

    profile rp {
      authority: effect
      retry: enabled
    }

    effect contract Unbound {
      capability net: IO.NetworkCapability
      effect send using net
      idempotency none
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}), "Unbound", "OOF-PROF4").empty?
end

check("CLEAN-6: enabled + no idempotency clause at all ⇒ no OOF-PROF4") do
  c = classify(profile_wrap("  authority: effect\n  retry: enabled", ""))
  contract_oofs(c, "SendThing", "OOF-PROF4").empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "OOF-PROF6 — malformed retry value fails closed at parse"

check("PROF6-1: `retry: sometimes` ⇒ parse-time OOF-PROF6") do
  parsed = parse(profile_wrap("  authority: effect\n  retry: sometimes", "  idempotency none"))
  parsed.fetch("parse_errors").any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF6" }
end

check("PROF6-2: malformed retry is NOT stored (no OOF-PROF4 masking)") do
  parsed = parse(profile_wrap("  authority: effect\n  retry: sometimes", "  idempotency none"))
  !parsed.fetch("profiles").first.key?("retry")
end

# ══════════════════════════════════════════════════════════════════════════════
section "Regression — OOF-M7/M8 binding untouched by the new field"

check("REG-1: OOF-M8 still fires for an unknown profile (retry present elsewhere)") do
  src = <<~IG
    module Proof.ProfileRetry

    profile rp {
      authority: effect
      retry: enabled
    }

    effect contract Bound via ghost_profile {
      capability net: IO.NetworkCapability
      effect send using net
    }
  IG
  contract_oofs(IgniterLang::Classifier.new.classify(parse(src), sample_input: {}), "Bound", "OOF-M8").any?
end

check("REG-2: clean retry-enabled + key contract stays fully accepted") do
  t = typed(profile_wrap("  authority: effect\n  retry: enabled", "  idempotency key order_id"))
  t.fetch("contracts").find { |x| x.fetch("name") == "SendThing" }.fetch("status") == "accepted"
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
