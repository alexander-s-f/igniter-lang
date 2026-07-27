#!/usr/bin/env ruby
# frozen_string_literal: true
#
# LAB-STDLIB-LEDGER-APPEND-READ-SEAM-P8 — focused Ruby canon compiler proof.
#
# The shared lab fixture is the dual-toolchain contract witness. This proof locks
# Ruby recognition to exactly three qualified calls, their nominal request and
# IO.LedgerCapability checks, and their distinct Result shapes. It makes no VM,
# executor, adapter, runner, or durable-authority claim.
#
# NOTE: /experiments/ is gitignored in this repo; add this proof with `git add -f`.

require "json"
require "tmpdir"

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "igniter_lang/compiler_orchestrator"

FIXTURE_PATH = File.expand_path(
  "../../../igniter-lab/igniter-compiler/tests/fixtures/ledger_seam/ledger_seam.ig",
  __dir__
)
FIXTURE = File.read(FIXTURE_PATH, encoding: "UTF-8")

EXPECTED_TYPES = {
  "append_result" => {
    "name" => "Result",
    "params" => [
      { "name" => "LedgerAppendOutcome", "params" => [] },
      { "name" => "LedgerError", "params" => [] },
    ],
  },
  "latest_result" => {
    "name" => "Result",
    "params" => [
      {
        "name" => "Option",
        "params" => [{ "name" => "LedgerFact", "params" => [] }],
      },
      { "name" => "LedgerError", "params" => [] },
    ],
  },
  "seq_result" => {
    "name" => "Result",
    "params" => [
      { "name" => "LedgerSeqPage", "params" => [] },
      { "name" => "LedgerError", "params" => [] },
    ],
  },
}.freeze

CALLS = {
  "stdlib.ledger.append_once" => ["LedgerAppendRequest", "append_request"],
  "stdlib.ledger.latest" => ["LedgerLatestRequest", "latest_request"],
  "stdlib.ledger.facts_by_seq" => ["LedgerSeqRequest", "seq_request"],
}.freeze

def compile_source(source, tag)
  Dir.mktmpdir(["ledger-p8-#{tag}-", ".proof"]) do |dir|
    input = File.join(dir, "main.ig")
    output = File.join(dir, "main.igapp")
    File.write(input, source)
    raw = IgniterLang::CompilerOrchestrator.new.compile_sources(
      source_paths: [input],
      out_path: output
    )
    result = raw.fetch("result", {})
    sir_path = File.join(output, "semantic_ir_program.json")
    {
      status: raw["status"],
      diagnostics: Array(result["diagnostics"]),
      sir: File.exist?(sir_path) ? JSON.parse(File.read(sir_path)) : nil,
    }
  end
rescue => error
  { status: "exception", diagnostics: [], sir: nil, error: error }
end

def compute_node(result, name)
  result.fetch(:sir).fetch("contracts").first.fetch("nodes")
    .find { |node| node["kind"] == "compute" && node["name"] == name }
end

def diagnostic?(result, rule, message)
  result.fetch(:diagnostics).any? do |diagnostic|
    diagnostic["rule"] == rule && diagnostic["message"] == message
  end
end

checks = []
def check(checks, label)
  ok = yield
  checks << ok
  puts "#{ok ? 'PASS' : 'FAIL'} #{label}"
rescue => error
  checks << false
  puts "FAIL #{label} — #{error.class}: #{error.message}"
end

valid = compile_source(FIXTURE, "valid")
check(checks, "valid shared fixture compiles cleanly in Ruby canon") do
  valid[:status] == "ok" && valid[:diagnostics].empty?
end

check(checks, "value carrier is opaque Text and both temporal coordinates are Float?") do
  FIXTURE.include?("value_canonical_json: Text") &&
    FIXTURE.scan("valid_time: Float?").length == 2 &&
    FIXTURE.scan("transaction_time: Float?").length == 2 &&
    !FIXTURE.match?(/\bAny\b|\bJsonValue\b/)
end

check(checks, "fixture grant is write (write implies read in the shared passport mapping)") do
  FIXTURE.include?("effect write using ledger_cap") &&
    !FIXTURE.include?("effect ledger_access using ledger_cap")
end

check(checks, "exact three qualified identities survive into SIR") do
  actual = %w[append_result latest_result seq_result].map do |name|
    compute_node(valid, name).dig("expr", "fn")
  end
  actual == CALLS.keys
end

EXPECTED_TYPES.each do |node_name, expected|
  check(checks, "#{node_name} has exact sealed Result shape") do
    compute_node(valid, node_name).dig("expr", "resolved_type") == expected
  end
end

CALLS.each do |fn_name, (request_type, request_ref)|
  arity = compile_source(
    FIXTURE.sub("#{fn_name}(#{request_ref}, ledger_cap)", "#{fn_name}(#{request_ref})"),
    "arity-#{fn_name.split('.').last}"
  )
  check(checks, "#{fn_name} exact arity diagnostic") do
    diagnostic?(
      arity,
      "OOF-TM1",
      "#{fn_name} expects exactly 2 arguments (request, capability), got 1"
    )
  end

  request = compile_source(
    FIXTURE.sub("#{fn_name}(#{request_ref}, ledger_cap)", "#{fn_name}(0, ledger_cap)"),
    "request-#{fn_name.split('.').last}"
  )
  check(checks, "#{fn_name} exact nominal request diagnostic") do
    diagnostic?(
      request,
      "OOF-TY0",
      "#{fn_name} arg 0: expected #{request_type}, got Integer"
    )
  end
end

wrong_capability = compile_source(
  FIXTURE.sub(
    "capability ledger_cap: IO.LedgerCapability",
    "capability ledger_cap: IO.NetworkCapability"
  ),
  "wrong-capability"
)
CALLS.each_key do |fn_name|
  check(checks, "#{fn_name} exact nominal capability diagnostic") do
    diagnostic?(
      wrong_capability,
      "OOF-TY0",
      "#{fn_name} arg 1: expected IO.LedgerCapability, got IO.NetworkCapability"
    )
  end
end

unknown_member = compile_source(
  FIXTURE.sub("stdlib.ledger.append_once", "stdlib.ledger.overwrite"),
  "unknown-member"
)
check(checks, "unknown qualified ledger member remains closed") do
  diagnostic?(unknown_member, "OOF-TY0", "Unknown function: stdlib.ledger.overwrite")
end

bare_alias = compile_source(
  FIXTURE.sub("stdlib.ledger.append_once", "append_once"),
  "bare-alias"
)
check(checks, "bare append_once alias remains closed") do
  diagnostic?(bare_alias, "OOF-TY0", "Unknown function: append_once")
end

type_prefix = FIXTURE.split("observed contract LedgerSeam", 2).first
pure_direct = compile_source(
  type_prefix + <<~IG,
    pure contract PureLedger {
      input req: LedgerLatestRequest
      input ledger_cap: IO.LedgerCapability
      compute result = stdlib.ledger.latest(req, ledger_cap)
      output result: Result[Option[LedgerFact], LedgerError]
    }
  IG
  "pure-direct"
)
check(checks, "direct ledger call in pure contract is authority-blocked") do
  diagnostic?(
    pure_direct,
    "E-IO-AMBIENT-BLOCKED",
    "I/O calls are blocked in pure contract 'PureLedger'"
  )
end

ambient_direct = compile_source(
  type_prefix + <<~IG,
    observed contract AmbientLedger {
      input req: LedgerLatestRequest
      input ledger_cap: IO.LedgerCapability
      compute result = stdlib.ledger.latest(req, ledger_cap)
      output result: Result[Option[LedgerFact], LedgerError]
    }
  IG
  "ambient-direct"
)
check(checks, "direct ledger call without capability declaration is authority-blocked") do
  diagnostic?(
    ambient_direct,
    "E-IO-AMBIENT-BLOCKED",
    "Ambient call to standard I/O function 'stdlib.ledger.latest' is blocked without capability context"
  )
end

passed = checks.count(true)
puts "#{passed}/#{checks.length} PASS"
exit(passed == checks.length ? 0 : 1)
