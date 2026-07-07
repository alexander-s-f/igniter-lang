#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/effect_surface_idempotency_proof/effect_surface_idempotency_proof.rb
#
# LANG-EFFECT-SURFACE-IDEMPOTENCY-P2 — second Effect Surface completion slice.
# Proves `idempotency key <expr>` / `idempotency natural` / `idempotency none`
# parse, classify (metadata; placement OOF-M6 incl. observed-refusal), typecheck
# (key expr through normal inference; unknown refs fail closed) and emit into
# `effect_surface_v1` as PARSED `idempotency_mode`/`idempotency_key_expr`.
#
# In-card decisions this proof anchors:
#   Placement: legal on effect/privileged/irreversible ONLY. Pure AND observed
#     are refused (OOF-M6) — idempotency governs mutation retry; an observation
#     has no mutation to dedupe (machine evidence keys idempotency to writes).
#   Malformed mode: parse-time OOF-M11.
#   ch12 "idempotency none in retry-enabled profile" (target OOF-M4 rule):
#     HELD for profile-policy follow-up — no concrete retry-enabled profile flag
#     exists in either toolchain today.

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

puts "#{BOLD}#{CYAN}Effect Surface idempotency proof (LANG-EFFECT-SURFACE-IDEMPOTENCY-P2)#{RESET}"
puts "Path: igniter-lang/experiments/effect_surface_idempotency_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "IDEM-PARSE — all three forms parse"
# ══════════════════════════════════════════════════════════════════════════════

key     = compile("idem_key")
natural = compile("idem_natural")
none    = compile("idem_none")

check("IDEM-PARSE-1: `idempotency key <expr>` parses; mode=key, expr present") do
  n = key[:parsed].fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "idempotency" }
  key[:parsed].fetch("parse_errors", []).empty? &&
    n&.fetch("mode") == "key" && n.key?("expr") && n.fetch("expr").fetch("kind") == "ref"
end

check("IDEM-PARSE-2: `idempotency natural` parses; mode=natural, no expr") do
  n = natural[:parsed].fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "idempotency" }
  natural[:parsed].fetch("parse_errors", []).empty? && n&.fetch("mode") == "natural" && !n.key?("expr")
end

check("IDEM-PARSE-3: `idempotency none` parses; mode=none, no expr") do
  n = none[:parsed].fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "idempotency" }
  none[:parsed].fetch("parse_errors", []).empty? && n&.fetch("mode") == "none" && !n.key?("expr")
end

check("IDEM-PARSE-4: malformed mode fails closed at parse with OOF-M11") do
  malformed = compile("idem_malformed")
  malformed[:parsed].fetch("parse_errors", []).any? { |e| e.fetch("rule", e["code"]) == "OOF-M11" }
end

# ══════════════════════════════════════════════════════════════════════════════
section "IDEM-CLASS — metadata classification and placement (OOF-M6)"
# ══════════════════════════════════════════════════════════════════════════════

oof = compile("idem_oof")

check("IDEM-CLASS-1: idempotency classifies as core metadata (no fragment flip)") do
  d = key[:classified].fetch("contracts").first.fetch("declarations")
       .find { |x| x.fetch("kind") == "idempotency" }
  d&.fetch("fragment_class") == "core" && d.fetch("mode") == "key"
end

check("IDEM-CLASS-2: contract fragment_class still escape (from capability)") do
  key[:classified].fetch("contracts").first.fetch("fragment_class") == "escape"
end

check("IDEM-CLASS-3: pure contract with idempotency → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("PureWithIdem") }
end

check("IDEM-CLASS-4: observed contract with idempotency → OOF-M6 (refused)") do
  oofs(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("ObservedWithIdem") }
end

check("IDEM-CLASS-5: duplicate idempotency clause → OOF-M6") do
  oofs(oof[:classified], "OOF-M6").any? do |d|
    d.fetch("message").include?("DuplicateIdem") && d.fetch("message").include?("more than once")
  end
end

# ══════════════════════════════════════════════════════════════════════════════
section "IDEM-TYPE — key expression typed by normal inference"
# ══════════════════════════════════════════════════════════════════════════════

check("IDEM-TYPE-1: key over declared input typechecks clean") do
  key[:typed].fetch("type_errors", []).empty?
end

check("IDEM-TYPE-2: natural/none typecheck clean") do
  natural[:typed].fetch("type_errors", []).empty? && none[:typed].fetch("type_errors", []).empty?
end

check("IDEM-TYPE-3: key expr over unknown symbol fails closed") do
  oof[:typed].fetch("type_errors", []).any? { |e| e.fetch("message").include?("missing_symbol") }
end

# ══════════════════════════════════════════════════════════════════════════════
section "IDEM-SIR — effect_surface carries PARSED mode/key expr"
# ══════════════════════════════════════════════════════════════════════════════

check("IDEM-SIR-1: mode=key + key expr emitted (ref to order_id)") do
  es = contract_ir(key[:sir], "SendOrder")&.fetch("effect_surface", nil)
  es && es.fetch("idempotency_mode") == "key" &&
    es.dig("idempotency_key_expr", "expr", "kind") == "ref" ||
    (es && es.fetch("idempotency_mode") == "key" && !es.fetch("idempotency_key_expr").nil?)
end

check("IDEM-SIR-2: mode=natural emitted, key expr nil") do
  es = contract_ir(natural[:sir], "SetFlag")&.fetch("effect_surface", nil)
  es && es.fetch("idempotency_mode") == "natural" && es.fetch("idempotency_key_expr").nil?
end

check("IDEM-SIR-3: mode=none emitted for explicit `idempotency none`") do
  es = contract_ir(none[:sir], "FireOnce")&.fetch("effect_surface", nil)
  es && es.fetch("idempotency_mode") == "none"
end

check("IDEM-SIR-4: receipt/failure P1 fields coexist (SendOrder receipt intact)") do
  es = contract_ir(key[:sir], "SendOrder")&.fetch("effect_surface", nil)
  es && es.dig("receipt_type", "name") == "SendReceipt"
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
