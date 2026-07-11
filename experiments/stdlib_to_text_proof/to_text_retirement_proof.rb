#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/stdlib_to_text_proof/to_text_retirement_proof.rb
#
# LANG-STDLIB-TO-TEXT-DUAL-INVENTORY-P1 — DECISION B (retirement) proof.
#
# Decision record: bare `to_text` is RETIRED from active authoring. The
# canonical numeric→text authoring surface is the type-prefixed family the
# inventory already carries (`stdlib.integer.int_to_text`; `float_to_text`
# exists lab-side under the same scheme; a future Decimal card would add
# `decimal_to_text` — same scheme, NOT a third one). `to_text` stays a
# lab-legacy Rust callable (LAB-LANG-NUMBER-TO-TEXT-P1 + DECIMAL-TO-TEXT-P2
# keep its semantics locked) but is intentionally NEVER inventoried and NEVER
# added to canon Ruby. This script is VERIFY-ONLY: under decision B the
# inventory is NOT modified, so unlike the sibling digest scripts
# (stdlib_text_join_proof/inventory_digest_join.rb) there is no `update` mode —
# it proves the stored digest still reproduces and that the retirement
# invariants hold on the canon side.
#
# Rust-side enforcement mirror: igniter-compiler/tests/stdlib_inventory_drift_tests.rs
# (HELD set annotates to_text as RETIRED; inventory admission would fail the gate).
#
# Usage:
#   ruby to_text_retirement_proof.rb        # runs all checks, exits 0 on PASS

require "digest"
require "json"
require "pathname"
require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"

GREEN = "\e[32m"; RED = "\e[31m"; CYAN = "\e[36m"; BOLD = "\e[1m"; RESET = "\e[0m"

INV = Pathname.new(__dir__).parent.parent / "docs" / "spec" / "stdlib-inventory.json"

# ── canonical digest method (same as every inventory_digest_* sibling) ────────
def deep_sort(o)
  case o
  when Hash then o.keys.sort.each_with_object({}) { |k, h| h[k] = deep_sort(o[k]) }
  when Array then o.map { |e| deep_sort(e) }
  else o
  end
end

def surface_digest(entries)
  stripped = entries.sort_by { |e| e["canonical_name"].to_s }
                    .map { |e| e.reject { |k, _| k == "entry_digest" } }
  Digest::SHA256.hexdigest(JSON.generate(deep_sort(stripped)))
end

# ── functional callable probe (same method as stdlib_inventory_drift_proof) ───
# callable = the call NAME resolves (no OOF-TY0 unresolved-symbol diagnostic).
def callable_ruby?(call)
  src = <<~IG
    module ToText.Probe
    pure contract Probe {
      input n: Integer
      compute r = #{call}
      output r: Text
    }
  IG
  parsed = IgniterLang::ParsedProgram.parse(src, source_path: "probe").to_h
  return false unless parsed.fetch("parse_errors", []).empty?
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  typed = IgniterLang::TypeChecker.new.typecheck(classified)
  errs = (typed.fetch("contracts").first.fetch("type_errors", []) || []).map { |d| d.fetch("rule", d["code"]) }
  !errs.include?("OOF-TY0")
end

RESULTS = []
def check(label, &b)
  r = b.call
  puts "  #{r ? GREEN : RED}[#{r ? 'PASS' : 'FAIL'}]#{RESET} #{label}"
  RESULTS << r
rescue => e
  puts "  #{RED}[ERROR]#{RESET} #{label}: #{e.message}"; RESULTS << false
end

puts "#{BOLD}#{CYAN}to_text retirement proof — LANG-STDLIB-TO-TEXT-DUAL-INVENTORY-P1 decision B#{RESET}"

doc = JSON.parse(File.read(INV, encoding: "UTF-8"))
entries = doc.fetch("entries")
all_names = entries.flat_map do |e|
  [e["canonical_name"], e["semantic_ir_name"]] + (e["aliases"] || []).map { |a| a["name"] }
end.compact

check("R1: stored stdlib_surface_digest reproduces via the canonical method (inventory untouched)") do
  surface_digest(entries) == doc.fetch("stdlib_surface_digest")
end

check("R2: `to_text` is NOT in the inventory — no canonical name, no dotted name, no alias (retired, never inventoried)") do
  all_names.none? { |n| n == "to_text" || n.to_s.end_with?(".to_text") }
end

check("R3: canonical replacement `stdlib.integer.int_to_text` IS inventoried, dual-toolchain, bare-alias importable") do
  e = entries.find { |x| x["canonical_name"] == "stdlib.integer.int_to_text" }
  !e.nil? &&
    e["lowering_status"] == "dual-toolchain" &&
    (e["aliases"] || []).any? { |a| a["name"] == "int_to_text" }
end

check("R4: bare `to_text(n)` is NOT Ruby-callable (OOF-TY0) — canon never grew the retired alias") do
  !callable_ruby?("to_text(n)")
end

check("R5: bare `int_to_text(n)` IS Ruby-callable — the replacement is live in canon") do
  callable_ruby?("int_to_text(n)")
end

passed = RESULTS.count(&:itself); total = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
exit(passed == total ? 0 : 1)
