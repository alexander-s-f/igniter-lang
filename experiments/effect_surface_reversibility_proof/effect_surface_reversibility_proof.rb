#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/effect_surface_reversibility_proof/effect_surface_reversibility_proof.rb
#
# LANG-EFFECT-SURFACE-REVERSIBILITY-P25 — the SEVENTH and final Effect Surface
# metadata field. Proves `reversibility :<value>` parses (colon symbol, six ch12
# scale values, bare value stored), classifies (placement/duplicate OOF-M6 + the
# ONE specified contradiction: :irreversible/:destructive together with
# `compensation <Ref>`), and emits `effect_surface_v1.reversibility` with
# ABSENT ⇒ null (no default — required-enforcement is a later slice).
# Unknown/malformed value fails closed at parse with OOF-M16.
#
# Held (unchanged by this slice): profile max-reversibility (future PROP +
# fresh code — target-OOF-M5 collides with implemented M5), required-field
# enforcement (target OOF-M2 family), host/executor interpretation.

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

FIXTURE_DIR = File.join(__dir__, "fixtures")

def compile(fixture_name)
  src        = File.read(File.join(FIXTURE_DIR, "#{fixture_name}.ig"))
  parsed     = IgniterLang::ParsedProgram.parse(src, source_path: fixture_name).to_h
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  typed      = IgniterLang::TypeChecker.new.typecheck(classified)
  sir        = IgniterLang::SemanticIREmitter.new.emit_typed(typed)
  { parsed: parsed, classified: classified, typed: typed, sir: sir }
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

def contract_ir(sir, name)
  sir.dig("semantic_ir", "contracts")&.find { |c| c.fetch("contract_name") == name }
end

def oofs(classified, rule)
  classified.fetch("contracts").flat_map { |c| c.fetch("oof_log", []) }
            .select { |d| d.fetch("rule", d["code"]) == rule }
end

puts "#{BOLD}#{CYAN}Effect Surface reversibility proof (LANG-EFFECT-SURFACE-REVERSIBILITY-P25)#{RESET}"
puts "Path: igniter-lang/experiments/effect_surface_reversibility_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "REV-PARSE — colon symbol, six values, bare storage"
# ══════════════════════════════════════════════════════════════════════════════

base = compile("rev_compensatable")
all  = compile("rev_all_values")

check("REV-PARSE-1: `reversibility :compensatable` parses; bare value stored") do
  n = base[:parsed].fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "reversibility" }
  base[:parsed].fetch("parse_errors", []).empty? && n&.fetch("value") == "compensatable"
end

check("REV-PARSE-2: all six scale values parse across contracts") do
  vals = all[:parsed].fetch("contracts").flat_map { |c| c.fetch("body") }
           .select { |d| d.fetch("kind") == "reversibility" }.map { |d| d.fetch("value") }
  all[:parsed].fetch("parse_errors", []).empty? &&
    (vals + ["compensatable"]).sort == %w[append_only compensatable destructive irreversible refundable reversible].sort
end

check("REV-PARSE-3: unknown value fails closed at parse with OOF-M16") do
  malformed = compile("rev_malformed")
  malformed[:parsed].fetch("parse_errors", []).any? { |e| e.fetch("rule", e["code"]) == "OOF-M16" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "REV-CLASS — placement, duplicate, the ONE contradiction (OOF-M6)"
# ══════════════════════════════════════════════════════════════════════════════

oof = compile("rev_oof")

check("REV-CLASS-1: reversibility classifies as core metadata (no fragment flip)") do
  d = base[:classified].fetch("contracts").first.fetch("declarations")
       .find { |x| x.fetch("kind") == "reversibility" }
  d&.fetch("fragment_class") == "core" && d.fetch("value") == "compensatable"
end

check("REV-CLASS-2: pure contract with reversibility → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("PureWithScale") }
end

check("REV-CLASS-3: observed contract with reversibility → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("ObservedWithScale") }
end

check("REV-CLASS-4: duplicate reversibility → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? do |d|
    d.fetch("message").include?("DoubleScale") && d.fetch("message").include?("more than once")
  end
end

check("REV-CLASS-5: :irreversible + compensation ref → OOF-M6 (specified contradiction)") do
  oofs(oof[:classified], "OOF-M6").any? do |d|
    d.fetch("message").include?("Contradiction") && d.fetch("message").include?("contradicts the named compensator")
  end
end

check("REV-CLASS-6: soft case NOT rejected — :compensatable + no_compensation accepted") do
  soft = compile("rev_waived_soft")
  soft[:classified].fetch("contracts").first.fetch("oof_log", [])
      .none? { |d| d.fetch("rule", "") == "OOF-M6" } &&
    soft[:typed].fetch("type_errors", []).empty?
end

check("REV-CLASS-7: :irreversible + no_compensation accepted (waiver, not contradiction)") do
  v4 = all[:typed].fetch("contracts").find { |c| c.fetch("name") == "V4" }
  v4.fetch("status") == "accepted"
end

# ══════════════════════════════════════════════════════════════════════════════
section "REV-SIR — effect_surface_v1.reversibility, absent ⇒ null"
# ══════════════════════════════════════════════════════════════════════════════

check("REV-SIR-1: bare value emitted (compensatable)") do
  es = contract_ir(base[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.fetch("reversibility") == "compensatable"
end

check("REV-SIR-2: all six values emit their bare names") do
  pairs = { "V1" => "reversible", "V2" => "refundable", "V3" => "append_only",
            "V4" => "irreversible", "V5" => "destructive" }
  pairs.all? do |name, val|
    contract_ir(all[:sir], name)&.dig("effect_surface", "reversibility") == val
  end
end

check("REV-SIR-3: absent clause ⇒ null (NO default)") do
  es = contract_ir(compile("rev_absent")[:sir], "NoScale")&.fetch("effect_surface", nil)
  es && es.fetch("reversibility").nil?
end

check("REV-SIR-4: coexistence — P22 compensation fields intact next to the scale") do
  es = contract_ir(base[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.fetch("kind") == "effect_surface_v1" &&
    es.fetch("compensation_mode") == "ref" && es.fetch("compensation_ref") == "RefundCustomer"
end

check("REV-SIR-5: all seven fields present in one object (surface complete)") do
  es = contract_ir(base[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  %w[affects_scope affects_target authority_ref idempotency_mode receipt_type
     failure_type compensation_mode reversibility].all? { |k| es&.key?(k) }
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
