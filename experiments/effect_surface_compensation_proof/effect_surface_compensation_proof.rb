#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/effect_surface_compensation_proof/effect_surface_compensation_proof.rb
#
# LANG-EFFECT-SURFACE-COMPENSATION-P22 — compensation metadata slice.
# Proves `compensation <ContractName>` / `no_compensation` parse, classify
# (placement + mutual exclusion, OOF-M6), typecheck (same-module existence,
# OOF-M15; OOF-M3 WARN for bare irreversible) and emit the THREE-STATE
# `effect_surface_v1.compensation_mode` / `compensation_ref`
# (null=undeclared ≠ "none"=explicit waiver ≠ "ref"+name — Covenant P17).
#
# Declaration only: names intent. Grants NO authority, binds NO host executor,
# executes NOTHING (runtime = machine P12 territory, future host-policy card).

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

puts "#{BOLD}#{CYAN}Effect Surface compensation proof (LANG-EFFECT-SURFACE-COMPENSATION-P22)#{RESET}"
puts "Path: igniter-lang/experiments/effect_surface_compensation_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "COMP-PARSE — both forms parse"
# ══════════════════════════════════════════════════════════════════════════════

ref  = compile("comp_ref")
none = compile("comp_none")

check("COMP-PARSE-1: `compensation RefundCustomer` parses; ref captured") do
  n = ref[:parsed].fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "compensation" }
  ref[:parsed].fetch("parse_errors", []).empty? && n&.fetch("contract_ref") == "RefundCustomer"
end

check("COMP-PARSE-2: `no_compensation` parses as its own kind (no args)") do
  n = none[:parsed].fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "no_compensation" }
  none[:parsed].fetch("parse_errors", []).empty? && !n.nil? && !n.key?("contract_ref")
end

check("COMP-PARSE-3: dotted ref fails closed at parse with OOF-M14") do
  malformed = compile("comp_malformed")
  malformed[:parsed].fetch("parse_errors", []).any? { |e| e.fetch("rule", e["code"]) == "OOF-M14" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "COMP-CLASS — placement + mutual exclusion (OOF-M6)"
# ══════════════════════════════════════════════════════════════════════════════

oof = compile("comp_oof")

check("COMP-CLASS-1: compensation classifies as core metadata (no fragment flip)") do
  d = ref[:classified].fetch("contracts").first.fetch("declarations")
       .find { |x| x.fetch("kind") == "compensation" }
  d&.fetch("fragment_class") == "core" && d.fetch("contract_ref") == "RefundCustomer"
end

check("COMP-CLASS-2: pure contract with compensation → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("PureWithComp") }
end

check("COMP-CLASS-3: observed contract with no_compensation → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("ObservedWithWaiver") }
end

check("COMP-CLASS-4: duplicate compensation clause → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? do |d|
    d.fetch("message").include?("DoubleComp") && d.fetch("message").include?("more than once")
  end
end

check("COMP-CLASS-5: compensation + no_compensation together → OOF-M6 (mutual exclusion)") do
  oofs(oof[:classified], "OOF-M6").any? do |d|
    d.fetch("message").include?("BothForms") && d.fetch("message").include?("exactly one compensation decision")
  end
end

# ══════════════════════════════════════════════════════════════════════════════
section "COMP-TYPE — existence check (OOF-M15) + OOF-M3 warn"
# ══════════════════════════════════════════════════════════════════════════════

check("COMP-TYPE-1: same-module compensator resolves clean") do
  ref[:typed].fetch("type_errors", []).empty?
end

check("COMP-TYPE-2: unknown compensator fails closed with OOF-M15") do
  oof[:typed].fetch("type_errors", []).any? do |e|
    e.fetch("rule", e["code"]) == "OOF-M15" && e.fetch("message").include?("NoSuchContract")
  end
end

warned = compile("comp_irreversible_warn")

check("COMP-TYPE-3: irreversible without any compensation decision → OOF-M3 WARN") do
  warned[:typed].fetch("contracts").first.fetch("type_warnings", []).any? do |w|
    w.fetch("rule", w["code"]) == "OOF-M3" && w.fetch("severity", "") == "warning"
  end
end

check("COMP-TYPE-4: OOF-M3 is warn, NOT a hard failure (contract stays accepted)") do
  warned[:typed].fetch("contracts").first.fetch("status") == "accepted" &&
    warned[:typed].fetch("type_errors", []).empty?
end

check("COMP-TYPE-5: irreversible WITH no_compensation gets no OOF-M3 warn") do
  none[:typed].fetch("contracts").first.fetch("type_warnings", [])
      .none? { |w| w.fetch("rule", "") == "OOF-M3" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "COMP-SIR — three-state effect_surface_v1 fields"
# ══════════════════════════════════════════════════════════════════════════════

check("COMP-SIR-1: mode=ref + ref name emitted") do
  es = contract_ir(ref[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.fetch("compensation_mode") == "ref" && es.fetch("compensation_ref") == "RefundCustomer"
end

check("COMP-SIR-2: mode=none for explicit no_compensation; ref null") do
  es = contract_ir(none[:sir], "SendEmail")&.fetch("effect_surface", nil)
  es && es.fetch("compensation_mode") == "none" && es.fetch("compensation_ref").nil?
end

check("COMP-SIR-3: absent decision ⇒ mode null AND ref null (three-state, not 'none')") do
  es = contract_ir(compile("comp_absent")[:sir], "PingOnly")&.fetch("effect_surface", nil)
  es && es.fetch("compensation_mode").nil? && es.fetch("compensation_ref").nil?
end

check("COMP-SIR-4: earlier fields coexist (kind v1, idempotency default, authority null)") do
  es = contract_ir(ref[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.fetch("kind") == "effect_surface_v1" &&
    es.fetch("idempotency_mode") == "none" && es.fetch("authority_ref").nil?
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
