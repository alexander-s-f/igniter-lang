#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/emitter_max_steps_proof/emitter_max_steps_proof.rb
#
# LANG-EMITTER-MAX-STEPS-P1 — the declared static `max_steps` budget reaches the
# SemanticIR artifact as `termination.max_steps` (the VM fuel loop reads it;
# previously BOTH emitters dropped the declared value, so the VM always used its
# default budget). Mirrors igniter-compiler/tests/emitter_max_steps_tests.rs.

require_relative "../../lib/igniter_lang/parser"
require_relative "../../lib/igniter_lang/classifier"
require_relative "../../lib/igniter_lang/typechecker"
require_relative "../../lib/igniter_lang/semanticir_emitter"

GREEN = "\e[32m"; RED = "\e[31m"; BOLD = "\e[1m"; RESET = "\e[0m"
$passed = 0; $failed = 0

def check(label, cond, detail = nil)
  if cond
    $passed += 1
    puts "  #{GREEN}[PASS]#{RESET} #{label}"
  else
    $failed += 1
    puts "  #{RED}[FAIL]#{RESET} #{label}#{detail ? "  #{detail}" : ""}"
  end
end

def sir_contract(src, name)
  parsed = IgniterLang::ParsedProgram.parse(src, source_path: "proof").to_h
  raise "parse errors: #{parsed["parse_errors"]}" unless parsed.fetch("parse_errors").empty?
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  typed = IgniterLang::TypeChecker.new.typecheck(classified)
  errs = typed.fetch("contracts").flat_map { |c| c.fetch("type_errors", []) }
  raise "type errors: #{errs}" unless errs.empty?
  res = IgniterLang::SemanticIREmitter.new.emit_typed(typed)
  sir = res.fetch("semantic_ir")
  sir.fetch("contracts").find { |c| c["contract_name"] == name || c["name"] == name } or
    raise "contract #{name} missing"
end

FUEL_SRC = <<~IG
  module Proof.MaxSteps

  recursive contract SumTo {
    input n : Integer
    input acc : Integer
    decreases fuel
    max_steps 5
    compute done = n <= 0
    compute result = if done { acc } else { recur(n - 1, acc + n) }
    output result : Integer
  }
IG

SYNTACTIC_SRC = <<~IG
  module Proof.MaxSteps

  recursive contract CountDown {
    input n : Integer
    decreases n
    max_steps 7
    compute done = n <= 0
    compute result = if done { 0 } else { recur(n - 1) }
    output result : Integer
  }
IG

NO_MS_SRC = <<~IG
  module Proof.MaxSteps

  recursive contract CountDown {
    input n : Integer
    decreases n
    compute done = n <= 0
    compute result = if done { 0 } else { recur(n - 1) }
    output result : Integer
  }
IG

puts "#{BOLD}LANG-EMITTER-MAX-STEPS-P1 proof#{RESET}"

# (1) recursive + decreases fuel — the previously-dropped case: minimal termination
c = sir_contract(FUEL_SRC, "SumTo")
term = c["termination"]
check("fuel case emits termination", !term.nil?)
check("fuel case termination.max_steps == 5", term && term["max_steps"] == 5, term.inspect)
check("fuel case invents no decreases evidence", term && !term.key?("decreases"), term.inspect)

# (2) syntactic T1 — max_steps JOINS existing evidence
c = sir_contract(SYNTACTIC_SRC, "CountDown")
term = c["termination"]
check("T1 evidence preserved (syntactic_v0)", term && term["variant_check"] == "syntactic_v0", term.inspect)
check("T1 decreases preserved", term && term["decreases"] == "n", term.inspect)
check("T1 termination.max_steps == 7", term && term["max_steps"] == 7, term.inspect)

# (3) no max_steps — byte-unchanged shape
c = sir_contract(NO_MS_SRC, "CountDown")
term = c["termination"]
check("no-max_steps keeps T1 shape", term && term["variant_check"] == "syntactic_v0", term.inspect)
check("no-max_steps adds no key", term && !term.key?("max_steps"), term.inspect)

puts "\n#{BOLD}#{$failed.zero? ? GREEN : RED}PASS #{$passed}/#{$passed + $failed}#{RESET}"
exit($failed.zero? ? 0 : 1)
