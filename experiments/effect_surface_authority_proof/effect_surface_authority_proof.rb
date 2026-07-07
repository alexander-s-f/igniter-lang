#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/effect_surface_authority_proof/effect_surface_authority_proof.rb
#
# LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10 — declared authority intent, the
# final placeholder field of `effect_surface_v1`.
# Proves `authority <ident>` parses (bare role symbol ONLY — dotted and string
# forms fail closed with OOF-M13), classifies (core metadata; placement OOF-M6
# incl. observed-refusal), and emits `effect_surface_v1.authority_ref` as the
# PARSED ident; absent clause stays nil.
#
# Ratified boundary (ch12 §12.3, P9 decision A / model F): this is DECLARED
# INTENT ONLY — no host policy, no verify_passport change, no enforcement.

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

puts "#{BOLD}#{CYAN}Effect Surface authority proof (LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10)#{RESET}"
puts "Path: igniter-lang/experiments/effect_surface_authority_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "AUTH-PARSE — bare role ident parses; dotted/string forms fail closed"
# ══════════════════════════════════════════════════════════════════════════════

basic = compile("authority_basic")

check("AUTH-PARSE-1: `authority billing_operator` parses; ref preserved") do
  n = basic[:parsed].fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "authority" }
  basic[:parsed].fetch("parse_errors", []).empty? && n&.fetch("ref") == "billing_operator"
end

check("AUTH-PARSE-2: dotted authority ref → OOF-M13 at parse") do
  compile("authority_dotted")[:parsed].fetch("parse_errors", [])
    .any? { |e| e.fetch("rule", e["code"]) == "OOF-M13" }
end

check("AUTH-PARSE-3: string-literal authority ref → OOF-M13 at parse") do
  compile("authority_string")[:parsed].fetch("parse_errors", [])
    .any? { |e| e.fetch("rule", e["code"]) == "OOF-M13" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "AUTH-CLASS — metadata classification and placement (OOF-M6)"
# ══════════════════════════════════════════════════════════════════════════════

oof = compile("authority_oof")

check("AUTH-CLASS-1: authority classifies as core metadata (no fragment flip)") do
  d = basic[:classified].fetch("contracts").first.fetch("declarations")
       .find { |x| x.fetch("kind") == "authority" }
  d&.fetch("fragment_class") == "core" && d.fetch("ref") == "billing_operator"
end

check("AUTH-CLASS-2: pure contract with authority → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("PureWithAuthority") }
end

check("AUTH-CLASS-3: observed contract with authority → OOF-M6 (gates mutation)") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("ObservedWithAuthority") }
end

check("AUTH-CLASS-4: duplicate authority clause → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? do |d|
    d.fetch("message").include?("DuplicateAuthority") && d.fetch("message").include?("more than once")
  end
end

check("AUTH-CLASS-5: valid fixtures typecheck clean") do
  basic[:typed].fetch("type_errors", []).empty? &&
    compile("authority_only")[:typed].fetch("type_errors", []).empty?
end

# ══════════════════════════════════════════════════════════════════════════════
section "AUTH-SIR — effect_surface_v1.authority_ref carries the PARSED ident"
# ══════════════════════════════════════════════════════════════════════════════

check("AUTH-SIR-1: authority_ref = billing_operator (declared intent)") do
  es = contract_ir(basic[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.fetch("authority_ref") == "billing_operator"
end

check("AUTH-SIR-2: authority-only privileged contract still emits the object") do
  es = contract_ir(compile("authority_only")[:sir], "DropTable")&.fetch("effect_surface", nil)
  es && es.fetch("authority_ref") == "db_admin" && es.fetch("capability_bindings") == []
end

check("AUTH-SIR-3: absent clause keeps authority_ref nil") do
  es = contract_ir(compile("authority_absent")[:sir], "NoAuthority")&.fetch("effect_surface", nil)
  es && es.fetch("authority_ref").nil?
end

check("AUTH-SIR-4: P1/P2/P5 fields coexist (kind v1, defaults intact)") do
  es = contract_ir(basic[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.fetch("kind") == "effect_surface_v1" &&
    es.fetch("affects_scope") == "external" && es.fetch("idempotency_mode") == "none"
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
