#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/profile_policy_fields_grounding_proof/profile_policy_fields_grounding_proof.rb
#
# LANG-PROFILE-POLICY-FIELDS-PROP-P29 (PROP-048) — EMPIRICAL GROUNDING for the
# profile-policy-fields proposal. Proof-first per house PROP discipline
# (mirrors the optional-field PROP P1/P2 "gap is real + additive" grounding).
#
# This proves the PRESSURE and the SHAPE OF THE GAP — it does NOT implement any
# rule. It shows:
#   (1) the live profile grammar (PROP-040) stores ONLY `authority` — a
#       `retry:` / `max_reversibility:` profile field parses cleanly but is
#       SILENTLY DROPPED (additive no-op today, exactly like optional-field `?`);
#   (2) the `via` binding + `idempotency none` effect-surface metadata are both
#       LIVE — so a retry-enabled profile bound to a `idempotency none` contract
#       is realizable today, but NOTHING connects the two (the hazard is
#       un-checked, not prevented);
#   (3) the fields are ADDITIVE: adding them introduces no parse errors on
#       existing profiles (absent field ⇒ absent, no default).
#
# The proposal (this card body) allocates OOF-PROF4 / OOF-PROF5 in ch11's
# declared profile-diagnostics namespace and defers all enforcement to P30/P31.

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
  IgniterLang::ParsedProgram.parse(src, source_path: "grounding").to_h
end

def profile(parsed, name)
  parsed.fetch("profiles").find { |p| p.fetch("name") == name }
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

puts "#{BOLD}#{CYAN}Profile policy fields — PROP-048 grounding (LANG-PROFILE-POLICY-FIELDS-PROP-P29)#{RESET}"
puts "Path: igniter-lang/experiments/profile_policy_fields_grounding_proof/"

# The gap fixture: a profile carrying the PROPOSED fields, bound to a contract
# that declares the exact hazard combination (`idempotency none`).
WITH_PROPOSED = <<~IG
  module Proof.ProfilePolicy.Grounding

  profile retrying_billing {
    authority: privileged
    retry: enabled
    max_reversibility: compensatable
  }

  privileged contract ChargeCard via retrying_billing {
    capability pay: IO.NetworkCapability
    effect charge using pay
    idempotency none
    reversibility :irreversible
  }
IG

# A pre-existing-shape profile (authority-only) — must be untouched by the proposal.
AUTHORITY_ONLY = <<~IG
  module Proof.ProfilePolicy.Grounding

  profile plain_billing {
    authority: privileged
  }

  privileged contract Charge via plain_billing {
    capability pay: IO.NetworkCapability
    effect charge using pay
  }
IG

# NOTE (2026-07-08): FULLY SUPERSEDED. This proof grounded PROP-048 by
# documenting the pre-implementation gap. Both policy dimensions have since
# landed — LANG-PROFILE-IDEMPOTENCY-RETRY-P31 (`retry` + OOF-PROF4) and
# LANG-PROFILE-MAX-REVERSIBILITY-P32 (`max_reversibility` + OOF-PROF5) — so the
# gap checks below are flipped to assert the post-implementation reality. Kept
# green as a historical witness that both fields moved from silently-dropped
# no-ops to enforced policy. The retry×idempotency-none hazard is now rejected.

# ══════════════════════════════════════════════════════════════════════════════
section "GAP-1 — grammar storage (BOTH fields now retained: P31 retry, P32 max_reversibility)"

check("GAP-1a: proposed profile parses with NO errors (fields accepted lexically)") do
  parse(WITH_PROPOSED).fetch("parse_errors").empty?
end

check("GAP-1b: `retry` is now RETAINED (P31 closed this gap)") do
  p = profile(parse(WITH_PROPOSED), "retrying_billing")
  p.fetch("retry", nil) == "enabled"
end

check("GAP-1c: `max_reversibility` is now RETAINED (P32 closed this gap)") do
  p = profile(parse(WITH_PROPOSED), "retrying_billing")
  p.fetch("max_reversibility", nil) == "compensatable"
end

check("GAP-1d: profile now carries authority + retry + max_reversibility") do
  p = profile(parse(WITH_PROPOSED), "retrying_billing")
  p.fetch("authority") == "privileged" &&
    (p.keys.sort == %w[authority kind max_reversibility name retry])
end

# ══════════════════════════════════════════════════════════════════════════════
section "GAP-2 — the retry×idempotency hazard is now CHECKED (P31)"

check("GAP-2a: `via` binding is live (contract carries via_profile)") do
  parsed = parse(WITH_PROPOSED)
  c = parsed.fetch("contracts").find { |x| x.fetch("name") == "ChargeCard" }
  c.fetch("via_profile") == "retrying_billing"
end

check("GAP-2b: `idempotency none` is live effect-surface metadata (P2 slice)") do
  parsed = parse(WITH_PROPOSED)
  c = parsed.fetch("contracts").find { |x| x.fetch("name") == "ChargeCard" }
  c.fetch("body").any? { |d| d.fetch("kind") == "idempotency" && d.fetch("mode") == "none" }
end

check("GAP-2c: the combination is now REJECTED (OOF-PROF4, P31 closed the hazard)") do
  parsed = parse(WITH_PROPOSED)
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  c = classified.fetch("contracts").find { |x| x.fetch("name") == "ChargeCard" }
  c.fetch("oof_log", []).any? { |e| e.fetch("rule", e["code"]) == "OOF-PROF4" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "ADDITIVE — existing authority-only profiles are untouched"

check("ADD-1: authority-only profile parses clean (absent fields ⇒ absent)") do
  parse(AUTHORITY_ONLY).fetch("parse_errors").empty?
end

check("ADD-2: authority-only profile stores exactly its live shape") do
  p = profile(parse(AUTHORITY_ONLY), "plain_billing")
  p.keys.sort == %w[authority kind name] && p.fetch("authority") == "privileged"
end

check("ADD-3: OOF-M7/M8 binding still validates (authority-only, clean bind)") do
  parsed = parse(AUTHORITY_ONLY)
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  # privileged contract via a privileged-authority profile ⇒ no M7/M8.
  oofs = classified.fetch("contracts").flat_map { |c| c.fetch("oof_log", []) }
  oofs.none? { |d| %w[OOF-M7 OOF-M8].include?(d.fetch("rule", d["code"])) }
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
