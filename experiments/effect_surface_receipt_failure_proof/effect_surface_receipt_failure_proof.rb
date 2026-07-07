#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/effect_surface_receipt_failure_proof/effect_surface_receipt_failure_proof.rb
#
# LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1 — first Effect Surface completion slice.
# Proves `receipt <TypeRef>` / `failure <TypeRef>` parse, classify (metadata,
# placement rules OOF-M6), typecheck (type resolution, OOF-M10) and emit into
# `effect_surface_v0_stub` as PARSED values instead of hardcoded nils.
#
# In-card decisions this proof anchors:
#   D1 (OOF-M numbering): implemented v0 allocation KEPT (OOF-M2/M4/M5 stay
#      structural capability checks); NEW codes for this slice: OOF-M6
#      (placement/duplicate), OOF-M10 (unresolvable type). ch12 §12.5 table is
#      target-allocation prose pending re-allocation (ledger D-009).
#   D2 (outcome vocabulary): composed with PROP-047 — see OUTCOME_VOCABULARY_V0.

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

# ── D2 artifact: canonical effect-outcome vocabulary v0 ─────────────────────
# Composed with PROP-047 (six stable cross-domain terms) + ch12 §12.3 + live
# machine taxonomy. Terminal outcome kinds an effect receipt/failure story
# must be able to express:
OUTCOME_VOCABULARY_V0 = %w[
  succeeded
  denied
  retryable
  permanent_failure
  unknown_external_state
  compensated
].freeze
# Per PROP-047: `timed_out` is a transport OBSERVATION, not a terminal kind —
# post-dispatch it classifies to unknown_external_state, pre-dispatch to
# retryable. `partial_success` requires per-item observed evidence and is
# deferred to a batch-shaped slice.

def compile(fixture_name)
  src        = File.read(File.join(FIXTURE_DIR, "#{fixture_name}.ig"))
  parsed     = IgniterLang::ParsedProgram.parse(src, source_path: fixture_name).to_h
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  typed      = IgniterLang::TypeChecker.new.typecheck(classified)
  # emit_typed is the path that builds typed_contract_ir + effect_surface
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

def diagnostics_of(classified, rule)
  classified.fetch("contracts").flat_map { |c| c.fetch("oof_log", []) }
            .select { |d| d.fetch("rule", d["code"]) == rule }
end

puts "#{BOLD}#{CYAN}Effect Surface receipt/failure proof (LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1)#{RESET}"
puts "Path: igniter-lang/experiments/effect_surface_receipt_failure_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "RF-PARSE — parser produces receipt/failure metadata nodes"
# ══════════════════════════════════════════════════════════════════════════════

basic = compile("receipt_failure_basic")

check("RF-PARSE-1: no parse errors on receipt_failure_basic") do
  basic[:parsed].fetch("parse_errors", []).empty? && basic[:parsed].fetch("errors", []).empty?
end

check("RF-PARSE-2: body has receipt node with type_annotation ChargeReceipt") do
  body = basic[:parsed].fetch("contracts").first.fetch("body")
  r = body.find { |d| d.fetch("kind") == "receipt" }
  t = r&.fetch("type_annotation")
  (t.is_a?(Hash) ? t["name"] : t) == "ChargeReceipt"
end

check("RF-PARSE-3: body has failure node with type_annotation PaymentFailure") do
  body = basic[:parsed].fetch("contracts").first.fetch("body")
  f = body.find { |d| d.fetch("kind") == "failure" }
  t = f&.fetch("type_annotation")
  (t.is_a?(Hash) ? t["name"] : t) == "PaymentFailure"
end

# ══════════════════════════════════════════════════════════════════════════════
section "RF-CLASS — metadata classification and placement rules"
# ══════════════════════════════════════════════════════════════════════════════

check("RF-CLASS-1: receipt/failure classify as core metadata (no fragment flip)") do
  decls = basic[:classified].fetch("contracts").first.fetch("declarations")
  r = decls.find { |d| d.fetch("kind") == "receipt" }
  f = decls.find { |d| d.fetch("kind") == "failure" }
  r&.fetch("fragment_class") == "core" && f&.fetch("fragment_class") == "core"
end

check("RF-CLASS-2: contract fragment_class still escape (from capability, not metadata)") do
  basic[:classified].fetch("contracts").first.fetch("fragment_class") == "escape"
end

check("RF-CLASS-3: no OOF-M diagnostics on the valid basic fixture") do
  basic[:classified].fetch("contracts").first.fetch("oof_log", [])
       .none? { |d| d.fetch("rule", "").start_with?("OOF-M") }
end

oof = compile("receipt_failure_oof")

check("RF-CLASS-4: pure contract with receipt → OOF-M6") do
  diagnostics_of(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("PureWithReceipt") }
end

check("RF-CLASS-5: duplicate receipt declaration → OOF-M6") do
  diagnostics_of(oof[:classified], "OOF-M6").any? { |d| d.fetch("message").include?("more than once") }
end

# ══════════════════════════════════════════════════════════════════════════════
section "RF-TYPE — type resolution and OOF-M10 fail-closed"
# ══════════════════════════════════════════════════════════════════════════════

check("RF-TYPE-1: declared record types resolve; basic fixture has no type errors") do
  basic[:typed].fetch("type_errors", []).empty?
end

check("RF-TYPE-2: builtin scalar receipt/failure (Text) resolve clean") do
  compile("receipt_builtin_scalar")[:typed].fetch("type_errors", []).empty?
end

check("RF-TYPE-3: unknown failure type → OOF-M10") do
  oof[:typed].fetch("type_errors", []).any? do |e|
    e.fetch("rule", e["code"]) == "OOF-M10" && e.fetch("message").include?("NoSuchType")
  end
end

# ══════════════════════════════════════════════════════════════════════════════
section "RF-SIR — effect_surface carries PARSED values, not hardcoded nils"
# ══════════════════════════════════════════════════════════════════════════════

check("RF-SIR-1: effect_surface.receipt_type = ChargeReceipt (parsed type_ir)") do
  es = contract_ir(basic[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.dig("receipt_type", "name") == "ChargeReceipt"
end

check("RF-SIR-2: effect_surface.failure_type = PaymentFailure (parsed type_ir)") do
  es = contract_ir(basic[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.dig("failure_type", "name") == "PaymentFailure"
end

check("RF-SIR-3: capability bindings unchanged next to receipt/failure") do
  es = contract_ir(basic[:sir], "ChargeCard")&.fetch("effect_surface", nil)
  es && es.fetch("capability_bindings").first&.fetch("capability_name") == "payments"
end

check("RF-SIR-4: receipt-only effect contract (no capability) still emits effect_surface") do
  sir = compile("receipt_only_no_capability")[:sir]
  es  = contract_ir(sir, "RecordOnly")&.fetch("effect_surface", nil)
  es && es.dig("receipt_type", "name") == "AuditReceipt" && es.fetch("capability_bindings") == []
end

# ══════════════════════════════════════════════════════════════════════════════
section "RF-VOCAB — D2 outcome vocabulary artifact (PROP-047 composition)"
# ══════════════════════════════════════════════════════════════════════════════

check("RF-VOCAB-1: vocabulary covers the card's minimum set") do
  %w[succeeded denied retryable permanent_failure unknown_external_state].all? do |t|
    OUTCOME_VOCABULARY_V0.include?(t)
  end
end

check("RF-VOCAB-2: timed_out is NOT a terminal kind (PROP-047 Term 3)") do
  !OUTCOME_VOCABULARY_V0.include?("timed_out")
end

check("RF-VOCAB-3: compensation-linked status present (ch12 `compensated`)") do
  OUTCOME_VOCABULARY_V0.include?("compensated")
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
