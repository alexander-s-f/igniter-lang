# frozen_string_literal: true
# LANG-CONTRACT-SINGLE-OUTPUT-LAW-P2: OOF-RET1 declaration-law proof runner
# Law: 0 outputs = current behavior (ruling OPEN), 1 output = valid,
#      2+ outputs = ONE root OOF-RET1 naming contract, count, named-record remedy.

$LOAD_PATH.unshift File.join(__dir__, "../../lib")
require "igniter_lang"

BOLD  = "\e[1m"
RESET = "\e[0m"
GREEN = "\e[32m"
RED   = "\e[31m"
CYAN  = "\e[36m"

FIXTURE_DIR = File.join(__dir__, "fixtures")
RESULTS = []

def compile(fixture_name, sample_input: {})
  src        = File.read(File.join(FIXTURE_DIR, "#{fixture_name}.ig"))
  parsed     = IgniterLang::ParsedProgram.parse(src, source_path: fixture_name).to_h
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: sample_input)
  typed      = IgniterLang::TypeChecker.new.typecheck(classified)
  { parsed: parsed, classified: classified, typed: typed }
rescue => e
  { error: e.message, parsed: {}, classified: {}, typed: {} }
end

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
  puts "\n#{BOLD}#{CYAN}== #{title} ==#{RESET}"
end

def type_errors(compiled)
  compiled[:typed].fetch("type_errors", [])
end

section "LAW-1: two outputs refuse with exactly one root OOF-RET1"
two = compile("two_output_refused")
out1 = type_errors(two).select { |e| e["rule"] == "OOF-RET1" }
check("exactly one OOF-RET1") { out1.length == 1 }
check("message names the contract") { out1.first&.fetch("message", "")&.include?("'TwoOut'") }
check("message reports the count") { out1.first&.fetch("message", "")&.include?("2 outputs") }
check("message shows the named-record remedy") { out1.first&.fetch("message", "")&.include?("named result record") }
check("derivative OOF-TY1 suppressed by the blocking rule") do
  type_errors(two).none? { |e| e["rule"] == "OOF-TY1" }
end
check("Rust-parity wording (declares N outputs; exactly one value)") do
  msg = out1.first&.fetch("message", "").to_s
  msg.include?("declares 2 outputs") && msg.include?("exactly one value")
end

section "LAW-2: one-output and zero-output contracts stay accepted"
one = compile("one_output_ok")
check("one output: zero type errors") { type_errors(one).empty? }
zero = compile("zero_output_ok")
check("zero outputs: no OOF-RET1 (ruling stays OPEN)") do
  type_errors(zero).none? { |e| e["rule"] == "OOF-RET1" }
end

section "LAW-3: the named result record is the accepted migration shape"
mig = compile("migrated_record_ok")
check("migrated shape: zero type errors") { type_errors(mig).empty? }
check("SIR-visible outputs count is exactly one") do
  contract = mig[:typed].fetch("contracts", []).find { |c| c["name"] == "TwoOut" } ||
             mig[:typed]["contract"] || {}
  decls = contract.fetch("declarations", [])
  decls.count { |d| d["kind"] == "output" } == 1
end

puts
passed = RESULTS.count { |r| r[:pass] }
puts "#{BOLD}#{passed}/#{RESULTS.length} checks passed#{RESET}"
exit(passed == RESULTS.length ? 0 : 1)
