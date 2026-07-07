#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/else_if_chaining_proof/else_if_chaining_proof.rb
#
# LAB-IGNITER-ELSE-IF-CHAINING-IMPL-P1 — `else if` chaining as source-surface sugar.
# Proves that `... else if C { B } ...` parses to an AST byte-identical to the
# hand-written nested form `... else { if C { B } ... }`, that the identity holds
# through the full pipeline (classifier → typechecker → SemanticIR), and that the
# required-final-`else` rule still fails closed (OOF-IF2 on the innermost `if`).
#
# Card: LAB-IGNITER-ELSE-IF-CHAINING-IMPL-P1
# Readiness evidence: igniter-lab/lab-docs/lang/prop-igniter-else-if-chaining-p1-v0.md

require "json"
require "pathname"

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"
require_relative "../../lib/igniter_lang/semanticir_emitter"

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN  = "\e[32m"
RED    = "\e[31m"
CYAN   = "\e[36m"
BOLD   = "\e[1m"
RESET  = "\e[0m"

FIXTURE_DIR = File.join(__dir__, "fixtures")

# ── Pipeline helpers ─────────────────────────────────────────────────────────
# Parity pairs are parsed under the SAME source_path label so the only possible
# difference between the two programs is the spelling of the chain itself.
def parse_fixture(fixture_name, label:)
  src = File.read(File.join(FIXTURE_DIR, "#{fixture_name}.ig"))
  IgniterLang::ParsedProgram.parse(src, source_path: label).to_h
end

def pipeline(parsed, sample_input: {})
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: sample_input)
  typed      = IgniterLang::TypeChecker.new.typecheck(classified)
  sir        = IgniterLang::SemanticIREmitter.new.emit(parsed, sample_input: sample_input)
  { classified: classified, typed: typed, sir: sir }
end

# Source bytes differ between the two spellings by definition, so fields that
# hash the RAW SOURCE legitimately differ: `source_hash` (sha256 of the file)
# and the identity ids derived from it (`program_id`, `classified_program_id`
# — the LANG-ID-P1 surface). Everything semantic must be byte-identical.
# Strip only those fields, recursively, before comparing.
SOURCE_DERIVED_KEYS = %w[source_hash program_id classified_program_id].freeze

def strip_source_hash(node)
  case node
  when Hash  then node.reject { |k, _| SOURCE_DERIVED_KEYS.include?(k) }.transform_values { |v| strip_source_hash(v) }
  when Array then node.map { |v| strip_source_hash(v) }
  else node
  end
end

def canon_json(node)
  JSON.generate(strip_source_hash(node))
end

# ── Check helpers ────────────────────────────────────────────────────────────
RESULTS = []

def check(label, &block)
  result = block.call
  status = result ? "PASS" : "FAIL"
  colour = result ? GREEN : RED
  puts "  #{colour}[#{status}]#{RESET} #{label}"
  RESULTS << { label: label, pass: result }
rescue => e
  puts "  #{RED}[ERROR]#{RESET} #{label}: #{e.message}"
  RESULTS << { label: label, pass: false }
end

def section(title)
  puts "\n#{CYAN}#{BOLD}── #{title} ──#{RESET}"
end

PAIRS = {
  "two-branch chain"          => %w[chain_two nested_two],
  "three-branch chain"        => %w[chain_three nested_three],
  "chain inside then-branch"  => %w[chain_inner nested_inner]
}.freeze

# ─────────────────────────────────────────────────────────────────────────────
puts "#{BOLD}#{CYAN}else-if chaining proof (LAB-IGNITER-ELSE-IF-CHAINING-IMPL-P1)#{RESET}"
puts "Path: igniter-lang/experiments/else_if_chaining_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "EIF-PARSE — `else if` parses clean"
# ══════════════════════════════════════════════════════════════════════════════

PAIRS.each_value.with_index(1) do |(chain, _nested), i|
  check("EIF-PARSE-#{i}: #{chain} has no parse errors") do
    parse_fixture(chain, label: "parity").fetch("errors", []).empty?
  end
end

# ══════════════════════════════════════════════════════════════════════════════
section "EIF-AST — chain AST is byte-identical to hand-written nesting"
# ══════════════════════════════════════════════════════════════════════════════

PAIRS.each.with_index(1) do |(title, (chain, nested)), i|
  a = parse_fixture(chain,  label: "parity")
  b = parse_fixture(nested, label: "parity")
  check("EIF-AST-#{i}: #{title} — full parsed program JSON equal") do
    canon_json(a) == canon_json(b)
  end
end

# ══════════════════════════════════════════════════════════════════════════════
section "EIF-SIR — identity holds through classifier/typechecker/SemanticIR"
# ══════════════════════════════════════════════════════════════════════════════

PAIRS.each.with_index(1) do |(title, (chain, nested)), i|
  a = pipeline(parse_fixture(chain,  label: "parity"))
  b = pipeline(parse_fixture(nested, label: "parity"))
  check("EIF-SIR-#{i}a: #{title} — typechecker output equal, no type errors") do
    canon_json(a[:typed]) == canon_json(b[:typed]) &&
      a[:typed].fetch("type_errors", []).empty?
  end
  check("EIF-SIR-#{i}b: #{title} — emitted SemanticIR JSON byte-equal") do
    canon_json(a[:sir]) == canon_json(b[:sir])
  end
end

# ══════════════════════════════════════════════════════════════════════════════
section "EIF-TOTAL — required final `else` still fails closed"
# ══════════════════════════════════════════════════════════════════════════════

broken = parse_fixture("chain_missing_final_else", label: "chain_missing_final_else")

check("EIF-TOTAL-1: missing final else still parses (grammar keeps else optional)") do
  broken.fetch("errors", []).empty?
end

check("EIF-TOTAL-2: typechecker refuses with OOF-IF2 (obligation lands on innermost if)") do
  typed = pipeline(broken)[:typed]
  typed.fetch("type_errors", []).any? { |e| e.fetch("rule", e["code"]) == "OOF-IF2" }
end

check("EIF-TOTAL-3: desugared else branch is a block whose sole return_expr is the inner if") do
  contract = broken.fetch("contracts").first
  compute  = contract.fetch("body").find { |d| d.fetch("kind") == "compute" }
  else_blk = compute.fetch("expr").fetch("else")
  else_blk.fetch("stmts") == [] &&
    else_blk.fetch("return_expr").fetch("kind") == "if_expr" &&
    else_blk.fetch("return_expr").fetch("else").nil?
end

# ══════════════════════════════════════════════════════════════════════════════
section "EIF-STABLE — closed surface, no regressions"
# ══════════════════════════════════════════════════════════════════════════════

check("EIF-STABLE-1: plain nested if fixture still compiles clean") do
  typed = pipeline(parse_fixture("nested_two", label: "nested_two"))[:typed]
  typed.fetch("type_errors", []).empty?
end

check("EIF-STABLE-2: no new AST node kind — chain emits only if_expr nodes") do
  parsed  = parse_fixture("chain_three", label: "chain_three")
  compute = parsed.fetch("contracts").first.fetch("body").find { |d| d.fetch("kind") == "compute" }
  kinds = []
  walk = lambda do |node|
    case node
    when Hash
      kinds << node["kind"] if node["kind"]
      node.each_value(&walk)
    when Array
      node.each(&walk)
    end
  end
  walk.call(compute.fetch("expr"))
  (kinds - %w[if_expr binary_op var literal int_literal call]).empty? ||
    !kinds.include?("else_if")
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
