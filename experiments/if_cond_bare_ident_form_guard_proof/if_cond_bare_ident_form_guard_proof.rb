#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/if_cond_bare_ident_form_guard_proof/if_cond_bare_ident_form_guard_proof.rb
#
# LANG-RUBY-IF-COND-BARE-IDENT-FORM-GUARD-P1 — a lowercase ident immediately
# before `{` inside an `if` CONDITION must stay a plain ref so the `{` opens
# the then-block, instead of being greedily claimed as a Gap-I form invocation
# (`if flag { 1 } else { 2 }` used to raise "Expected lbrace, got keyword(else)").
#
# The guard is condition-scoped: form invocations must keep working everywhere
# they were valid before, including INSIDE an if's then/else blocks.
#
# Rust parity matrix:
#   igniter-lab/igniter-compiler/tests/if_cond_bare_ident_before_brace_tests.rs
#
# Card: LANG-RUBY-IF-COND-BARE-IDENT-FORM-GUARD-P1

require "json"

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN  = "\e[32m"
RED    = "\e[31m"
CYAN   = "\e[36m"
BOLD   = "\e[1m"
RESET  = "\e[0m"

# ── Pipeline helpers ─────────────────────────────────────────────────────────
def parse_src(src, label:)
  IgniterLang::ParsedProgram.parse(src, source_path: label).to_h
end

def typecheck(parsed, sample_input:)
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: sample_input)
  IgniterLang::TypeChecker.new.typecheck(classified)
end

def compute_expr(parsed, name)
  parsed.fetch("contracts").first.fetch("body")
        .find { |d| d["kind"] == "compute" && d["name"] == name }
        .fetch("expr")
end

# Parse errors AND raises both count as "did not parse clean".
def parses_clean?(src, label:)
  parsed = parse_src(src, label: label)
  parsed.fetch("errors", []).empty?
rescue IgniterLang::ParseError
  false
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

# ── Fixtures (inline; mirror the Rust parity matrix) ─────────────────────────
BARE_BOOL = <<~IG
  module Proof.IfCondGuard
  contract C {
    input flag: Bool
    compute y = if flag { 1 } else { 2 }
    output y: Integer
  }
IG

FIELD_REF = <<~IG
  module Proof.IfCondGuard
  type Item {
    done : Bool
    id : String
  }
  contract C {
    input item: Item
    compute y = if item.done { 1 } else { 2 }
    output y: Integer
  }
IG

EQUALITY_FIELD = <<~IG
  module Proof.IfCondGuard
  type Item {
    done : Bool
    id : String
  }
  contract C {
    input item: Item
    compute y = if item.id == "x" { 1 } else { 2 }
    output y: Integer
  }
IG

EQUALITY_BARE = <<~IG
  module Proof.IfCondGuard
  contract C {
    input current: String
    input target: String
    compute y = if current == target { 1 } else { 2 }
    output y: Integer
  }
IG

NESTED_NATURAL = <<~IG
  module Proof.IfCondGuard
  contract C {
    input flag: Bool
    input ready: Bool
    compute y = if flag { if ready { 700 } else { 0 } } else { 0 }
    output y: Integer
  }
IG

ELSE_IF_BARE = <<~IG
  module Proof.IfCondGuard
  contract C {
    input a: Bool
    input b: Bool
    compute y = if a { 1 } else if b { 2 } else { 3 }
    output y: Integer
  }
IG

FORM_BASIC = <<~IG
  module Proof.IfCondGuard
  type Element {
    tag : String
    children : Collection[Element]
  }
  contract Page {
    uses col
    uses leaf
    compute view = col {
      leaf text="Ada" {}
    }
    output view: Element
  }
IG

FORM_IN_IF_BODY = <<~IG
  module Proof.IfCondGuard
  type Element {
    tag : String
    children : Collection[Element]
  }
  contract Page {
    input flag: Bool
    uses col
    uses leaf
    compute view = if flag { col { leaf text="Ada" {} } } else { leaf text="B" {} }
    output view: Element
  }
IG

# ─────────────────────────────────────────────────────────────────────────────
puts "#{BOLD}#{CYAN}if-cond bare-ident form guard proof (LANG-RUBY-IF-COND-BARE-IDENT-FORM-GUARD-P1)#{RESET}"
puts "Path: igniter-lang/experiments/if_cond_bare_ident_form_guard_proof/"

# ══════════════════════════════════════════════════════════════════════════════
section "IFG-PARSE — natural if-condition spellings parse clean"
# ══════════════════════════════════════════════════════════════════════════════

check("IFG-PARSE-1: bare Bool condition `if flag { .. } else { .. }`") do
  parses_clean?(BARE_BOOL, label: "bare_bool")
end

check("IFG-PARSE-2: field-ref condition `if item.done { .. }`") do
  parses_clean?(FIELD_REF, label: "field_ref")
end

check("IFG-PARSE-3: field equality condition `if item.id == \"x\" { .. }`") do
  parses_clean?(EQUALITY_FIELD, label: "equality_field")
end

check("IFG-PARSE-4: bare-ident equality condition `if current == target { .. }`") do
  parses_clean?(EQUALITY_BARE, label: "equality_bare")
end

check("IFG-PARSE-5: nested natural spelling `if flag { if ready { .. } .. }`") do
  parses_clean?(NESTED_NATURAL, label: "nested_natural")
end

check("IFG-PARSE-6: else-if chain with bare ident conditions") do
  parses_clean?(ELSE_IF_BARE, label: "else_if_bare")
end

# ══════════════════════════════════════════════════════════════════════════════
section "IFG-AST — condition stays a ref, then-branch stays a block"
# ══════════════════════════════════════════════════════════════════════════════

check("IFG-AST-1: bare Bool cond parses to if_expr with ref cond + block then") do
  expr = compute_expr(parse_src(BARE_BOOL, label: "bare_bool"), "y")
  expr["kind"] == "if_expr" &&
    expr.dig("cond", "kind") == "ref" &&
    expr.dig("cond", "name") == "flag" &&
    expr.dig("then", "return_expr", "value") == 1 &&
    expr.dig("else", "return_expr", "value") == 2
end

check("IFG-AST-2: no form_invocation node anywhere in the bare-Bool if_expr") do
  json = JSON.generate(compute_expr(parse_src(BARE_BOOL, label: "bare_bool"), "y"))
  !json.include?("form_invocation")
end

# ══════════════════════════════════════════════════════════════════════════════
section "IFG-TC — accepted shapes also typecheck clean (Rust assert_clean parity)"
# ══════════════════════════════════════════════════════════════════════════════

check("IFG-TC-1: bare Bool condition typechecks clean") do
  typed = typecheck(parse_src(BARE_BOOL, label: "bare_bool"), sample_input: { "flag" => true })
  typed.fetch("type_errors", []).empty? &&
    typed.dig("contracts", 0, "status") == "accepted"
end

check("IFG-TC-2: bare-ident equality condition typechecks clean") do
  typed = typecheck(parse_src(EQUALITY_BARE, label: "equality_bare"),
                    sample_input: { "current" => "a", "target" => "b" })
  typed.fetch("type_errors", []).empty? &&
    typed.dig("contracts", 0, "status") == "accepted"
end

# ══════════════════════════════════════════════════════════════════════════════
section "IFG-FORM — form invocation regression guard (guard is cond-scoped)"
# ══════════════════════════════════════════════════════════════════════════════

check("IFG-FORM-1: `col { leaf text=\"Ada\" {} }` still parses as form_invocation") do
  expr = compute_expr(parse_src(FORM_BASIC, label: "form_basic"), "view")
  expr["kind"] == "form_invocation" &&
    expr["trigger"] == "col" &&
    expr["children"].first["kind"] == "form_invocation" &&
    expr["children"].first["trigger"] == "leaf" &&
    expr["children"].first["attrs"].first["name"] == "text"
end

check("IFG-FORM-2: form invocation INSIDE if then/else blocks still parses") do
  expr = compute_expr(parse_src(FORM_IN_IF_BODY, label: "form_in_if_body"), "view")
  expr["kind"] == "if_expr" &&
    expr.dig("then", "return_expr", "kind") == "form_invocation" &&
    expr.dig("then", "return_expr", "trigger") == "col" &&
    expr.dig("else", "return_expr", "kind") == "form_invocation" &&
    expr.dig("else", "return_expr", "trigger") == "leaf"
end

# ── Summary ──────────────────────────────────────────────────────────────────
passed = RESULTS.count { |r| r[:pass] }
total  = RESULTS.length
colour = passed == total ? GREEN : RED
puts "\n#{BOLD}═══════════════════════════════════════#{RESET}"
puts "#{BOLD}#{colour}PASS #{passed}/#{total}#{RESET}"
puts "#{BOLD}═══════════════════════════════════════#{RESET}"
exit(passed == total ? 0 : 1)
