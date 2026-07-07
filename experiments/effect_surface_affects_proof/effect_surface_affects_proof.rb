#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/effect_surface_affects_proof/effect_surface_affects_proof.rb
#
# LANG-EFFECT-SURFACE-AFFECTS-P5 — third Effect Surface metadata slice.
# Proves `affects external|internal <qualified-name>` parses (dotted target,
# source spelling preserved), classifies (core metadata; placement OOF-M6 incl.
# observed-refusal — an observation mutates nothing), and replaces the former
# hardcoded `effect_surface_v1.affects_scope/affects_target` constants with
# parsed values; absent clause keeps the documented defaults.
# Malformed scope keyword fails closed at parse with OOF-M12.

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

puts "#{BOLD}#{CYAN}Effect Surface affects proof (LANG-EFFECT-SURFACE-AFFECTS-P5)#{RESET}"
puts "Path: igniter-lang/experiments/effect_surface_affects_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "AFF-PARSE — both scopes parse with dotted qualified names"
# ══════════════════════════════════════════════════════════════════════════════

ext = compile("affects_external")
int = compile("affects_internal")

check("AFF-PARSE-1: `affects external` parses; target spelling preserved") do
  n = ext[:parsed].fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "affects" }
  ext[:parsed].fetch("parse_errors", []).empty? &&
    n&.fetch("scope") == "external" && n.fetch("target") == "PaymentGateway.ChargeEndpoint"
end

check("AFF-PARSE-2: `affects internal` parses; target spelling preserved") do
  n = int[:parsed].fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "affects" }
  int[:parsed].fetch("parse_errors", []).empty? &&
    n&.fetch("scope") == "internal" && n.fetch("target") == "Ledger.WriteModel"
end

check("AFF-PARSE-3: malformed scope fails closed at parse with OOF-M12") do
  malformed = compile("affects_malformed")
  malformed[:parsed].fetch("parse_errors", []).any? { |e| e.fetch("rule", e["code"]) == "OOF-M12" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "AFF-CLASS — metadata classification and placement (OOF-M6)"
# ══════════════════════════════════════════════════════════════════════════════

oof = compile("affects_oof")

check("AFF-CLASS-1: affects classifies as core metadata (no fragment flip)") do
  d = ext[:classified].fetch("contracts").first.fetch("declarations")
       .find { |x| x.fetch("kind") == "affects" }
  d&.fetch("fragment_class") == "core" && d.fetch("scope") == "external"
end

check("AFF-CLASS-2: pure contract with affects → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("PureWithAffects") }
end

check("AFF-CLASS-3: observed contract with affects → OOF-M6 (mutation target)") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("ObservedWithAffects") }
end

check("AFF-CLASS-4: duplicate affects clause → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? do |d|
    d.fetch("message").include?("DuplicateAffects") && d.fetch("message").include?("more than once")
  end
end

check("AFF-CLASS-5: valid fixtures typecheck clean") do
  ext[:typed].fetch("type_errors", []).empty? && int[:typed].fetch("type_errors", []).empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "AFF-SIR — effect_surface_v1 carries PARSED scope/target"
# ══════════════════════════════════════════════════════════════════════════════

check("AFF-SIR-1: external scope + dotted target emitted") do
  es = contract_ir(ext[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.fetch("affects_scope") == "external" &&
    es.fetch("affects_target") == "PaymentGateway.ChargeEndpoint"
end

check("AFF-SIR-2: internal scope emitted; affects-only contract still gets the object") do
  es = contract_ir(int[:sir], "WriteLedger")&.fetch("effect_surface", nil)
  es && es.fetch("affects_scope") == "internal" &&
    es.fetch("affects_target") == "Ledger.WriteModel" &&
    es.fetch("capability_bindings") == []
end

check("AFF-SIR-3: absent clause keeps documented defaults (external / IO.Capability)") do
  es = contract_ir(compile("affects_absent")[:sir], "Defaulted")&.fetch("effect_surface", nil)
  es && es.fetch("affects_scope") == "external" && es.fetch("affects_target") == "IO.Capability"
end

check("AFF-SIR-4: P1/P2 fields coexist (kind v1, idempotency default none)") do
  es = contract_ir(ext[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.fetch("kind") == "effect_surface_v1" && es.fetch("idempotency_mode") == "none"
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
