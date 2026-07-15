#!/usr/bin/env ruby
# frozen_string_literal: true
#
# experiments/intent_multifile_proof/intent_multifile_proof.rb
#
# LANG-INTENT-DUAL-TOOLCHAIN-PARITY-P3 — multifile module-intent law (Ruby half).
#
# The law (mirrors the Rust multifile implementation):
#   1. contract intent remains attached to its qualified contract;
#   2. module intent remains attached to its source module/unit — preserved in
#      the deterministic `source_units` evidence;
#   3. an aggregate program must not silently choose one module's intent
#      (merged `intent_text` stays nil);
#   4. units without intent gain no evidence key (absence is no-churn).
#
# Before this card the resolver hardcoded top-level `intent_text => nil` and
# dropped every module intent silently.
#
# Gate result: must reach 10/10 PASS.

require "json"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(__dir__).parent.parent
$LOAD_PATH.unshift(ROOT.join("lib").to_s) unless $LOAD_PATH.include?(ROOT.join("lib").to_s)

require "igniter_lang/multifile_resolver"

GREEN  = "\e[32m"
RED    = "\e[31m"
CYAN   = "\e[36m"
BOLD   = "\e[1m"
RESET  = "\e[0m"

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

UNIT_A = <<~IG
  module ModA
  intent "module A purpose"

  pure contract FromA {
    intent "contract-level purpose in A"
    input x: Integer
    compute y = x
    output y: Integer
  }
IG

UNIT_B = <<~IG
  module ModB
  intent "module B purpose"

  pure contract FromB {
    input x: Integer
    compute y = x
    output y: Integer
  }
IG

UNIT_C = <<~IG
  module ModC

  pure contract FromC {
    input x: Integer
    compute y = x
    output y: Integer
  }
IG

puts "#{BOLD}#{CYAN}LANG-INTENT-DUAL-TOOLCHAIN-PARITY-P3 — multifile module-intent law#{RESET}"
puts "Path: igniter-lang/experiments/intent_multifile_proof/"

Dir.mktmpdir("intent_multifile_proof") do |dir|
  path_a = File.join(dir, "a.ig")
  path_b = File.join(dir, "b.ig")
  path_c = File.join(dir, "c.ig")
  File.write(path_a, UNIT_A)
  File.write(path_b, UNIT_B)
  File.write(path_c, UNIT_C)

  resolved = IgniterLang::MultifileResolver.new.resolve([path_a, path_b, path_c])

  section "MF-INTENT — resolution and aggregate law"

  check("MF-INTENT-01: three-unit multifile resolves ok") do
    resolved.fetch("ok") == true
  end

  merged = resolved.fetch("parsed_program")

  check("MF-INTENT-02: merged program intent_text is nil (aggregate never selects)") do
    merged.fetch("intent_text", :missing).nil?
  end

  check("MF-INTENT-03: merged module is the synthetic universe") do
    merged.fetch("module") == IgniterLang::MultifileResolver::SYNTHETIC_MODULE
  end

  section "MF-INTENT — per-unit evidence preservation"

  units = resolved.fetch("source_units")
  by_module = units.to_h { |u| [u.fetch("module"), u] }

  check("MF-INTENT-04: ModA unit evidence carries its module intent") do
    by_module.fetch("ModA").fetch("intent_text", nil) == "module A purpose"
  end

  check("MF-INTENT-05: ModB unit evidence carries its module intent") do
    by_module.fetch("ModB").fetch("intent_text", nil) == "module B purpose"
  end

  check("MF-INTENT-06: intent-free ModC unit has no intent_text key") do
    !by_module.fetch("ModC").key?("intent_text")
  end

  check("MF-INTENT-07: evidence order is deterministic (sorted by module)") do
    units.map { |u| u.fetch("module") } == %w[ModA ModB ModC]
  end

  section "MF-INTENT — contract intent survives the merge"

  from_a = merged.fetch("contracts").find { |c| c.fetch("name") == "FromA" }

  check("MF-INTENT-08: FromA keeps its contract-level intent node") do
    node = from_a.fetch("body").find { |n| n["kind"] == "intent" }
    node&.fetch("text") == "contract-level purpose in A"
  end

  check("MF-INTENT-09: FromA is tagged with its origin module") do
    from_a.fetch("origin_module", nil) == "ModA"
  end

  check("MF-INTENT-10: intent-free contracts carry no intent node") do
    %w[FromB FromC].all? do |name|
      contract = merged.fetch("contracts").find { |c| c.fetch("name") == name }
      contract.fetch("body").none? { |n| n["kind"] == "intent" }
    end
  end
end

total  = RESULTS.length
passed = RESULTS.count { |r| r[:pass] }
failed = total - passed

puts ""
colour = failed.zero? ? GREEN : RED
puts "#{BOLD}MF-INTENT: #{colour}#{passed}/#{total} #{failed.zero? ? "PASS" : "FAIL"}#{RESET}"
unless failed.zero?
  RESULTS.reject { |r| r[:pass] }.each { |r| puts "  #{RED}✗ #{r[:label]}#{RESET}" }
  exit 1
end
