#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-PURE-CONTRACT-EXPRESSION-BODY-P1 — dual-toolchain/canonical proof.

require "json"
require "open3"
require "pathname"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "igniter_lang"
require "igniter_lang/compiler_orchestrator"

ROOT = Pathname.new(__dir__).join("../..").expand_path
LAB_ROOT = ROOT.join("../igniter-lab").expand_path
RUST_BIN = LAB_ROOT.join("igniter-compiler/target/release/igniter_compiler")
VM_BIN = LAB_ROOT.join("igniter-vm/target/release/igniter-vm")

$pass = 0
$fail = 0

def check(label)
  ok = yield
  if ok
    $pass += 1
    puts "PASS  #{label}"
  else
    $fail += 1
    puts "FAIL  #{label}"
  end
rescue => e
  $fail += 1
  puts "FAIL  #{label}  [#{e.class}: #{e.message.lines.first&.strip}]"
end

def section(label)
  puts "\n== #{label} =="
end

def ruby_parse(src)
  IgniterLang::ParsedProgram.parse(src, source_path: "inline").to_h
end

def ruby_compile(src, tag)
  dir = Dir.mktmpdir("pceb_rb_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out.igapp")
  [IgniterLang.compile(source_path: path, out_path: out), out]
end

def ruby_diags(report)
  Array(report.dig("compilation_report", "diagnostics"))
end

def rust_compile(src, tag)
  dir = Dir.mktmpdir("pceb_rs_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out")
  stdout, stderr, = Open3.capture3(
    { "LANG" => "en_US.UTF-8" }, RUST_BIN.to_s, "compile", path, "--out", out
  )
  raise "Rust compiler returned no JSON: #{stderr}" if stdout.empty?
  [JSON.parse(stdout.force_encoding("UTF-8")), out]
end

def rust_diags(report)
  Array(report["diagnostics"])
end

def rust_sir(out_dir)
  JSON.parse(File.read(File.join(out_dir, "semantic_ir_program.json")))
end

def vm_run(artifact, inputs)
  dir = Dir.mktmpdir("pceb_vm_")
  input_path = File.join(dir, "inputs.json")
  File.write(input_path, JSON.generate(inputs))
  stdout, stderr, = Open3.capture3(
    { "LANG" => "en_US.UTF-8" }, VM_BIN.to_s, "run", "--contract", artifact.to_s,
    "--inputs", input_path, "--json"
  )
  raise "VM returned no JSON: #{stderr}" if stdout.empty?
  JSON.parse(stdout.force_encoding("UTF-8"))
end

ENVELOPE = %w[program_id source_hash source_path compilation_report_ref].freeze

def sir_identical_modulo_envelope(a, b)
  a.is_a?(Hash) && b.is_a?(Hash) && a.keys == b.keys &&
    a.keys.all? { |key| ENVELOPE.include?(key) || JSON.generate(a[key]) == JSON.generate(b[key]) }
end

TYPE = <<~IG
  type AcceptSliceResult {
    disposition         : String
    http_status         : Integer
    notification_id     : String
    generation          : Integer
    body_equality_known : Integer
    detail              : String
  }
IG

HEADER = <<~IG
  pure contract MakeAcceptResult(
    disposition: String,
    http_status: Integer,
    notification_id: String,
    generation: Integer,
    body_equality_known: Integer,
    detail: String
  ) -> (result: AcceptSliceResult)
IG

EXPRESSION = <<~IG
  module Proof.ExpressionBody
  #{TYPE}
  #{HEADER} =
    { disposition, http_status, notification_id, generation,
      body_equality_known, detail }
IG

SIGNATURE_BLOCK = <<~IG
  module Proof.ExpressionBody
  #{TYPE}
  #{HEADER} {
    result = { disposition, http_status, notification_id, generation,
      body_equality_known, detail }
  }
IG

EXPLICIT = <<~IG
  module Proof.ExpressionBody
  #{TYPE}
  pure contract MakeAcceptResult {
    input disposition         : String
    input http_status         : Integer
    input notification_id     : String
    input generation          : Integer
    input body_equality_known : Integer
    input detail              : String
    compute result : AcceptSliceResult = {
      disposition: disposition,
      http_status: http_status,
      notification_id: notification_id,
      generation: generation,
      body_equality_known: body_equality_known,
      detail: detail
    }
    output result : AcceptSliceResult
  }
IG

EXPRESSION_EXPLICIT_RHS = EXPRESSION.sub(
  "{ disposition, http_status, notification_id, generation,\n  body_equality_known, detail }",
  "{ disposition: disposition, http_status: http_status,\n  notification_id: notification_id, generation: generation,\n  body_equality_known: body_equality_known, detail: detail }"
)

INPUTS = {
  "disposition" => "accepted", "http_status" => 202,
  "notification_id" => "n-1", "generation" => 1,
  "body_equality_known" => 1, "detail" => "queued"
}.freeze
EXPECTED = INPUTS.freeze

BAD = {
  "missing signature" => "module M\npure contract NoSig = 1 + 1",
  "zero outputs" => "module M\npure contract Zero(x: Integer) -> () = x",
  "multiple outputs" => "module M\npure contract Multi(x: Integer) -> (a: Integer, b: Integer) = x",
  "non-pure" => "module M\neffect contract Eff(x: Integer) -> (y: Integer) = x"
}.freeze

BAD_MESSAGES = {
  "missing signature" => "expression-bodied contract `NoSig` requires a signature `(inputs...) -> (name: Type)`",
  "zero outputs" => "expression-bodied contract `Zero` requires exactly one named signature output; found 0",
  "multiple outputs" => "expression-bodied contract `Multi` requires exactly one named signature output; found 2",
  "non-pure" => "expression body is only allowed on a `pure` contract; `Eff` is `effect`"
}.freeze

TYPE_MISMATCH = "module M\npure contract Bad() -> (result: Integer) = \"text\"\n"

NATURAL_CALLS = <<~IG
  module M
  pure contract Double(x: Integer) -> (result: Integer) = x + x
  pure contract PureCaller {
    input x : Integer
    compute result = Double(x)
    output result : Integer
  }
  effect contract EffectDouble {
    capability net: IO.Capability
    effect send using net
    input x : Integer
    compute result = x + x
    output result : Integer
  }
  effect contract EffectCaller {
    capability net: IO.Capability
    effect send using net
    input x : Integer
    invoke result = EffectDouble(x) using net
    output result : Integer
  }
IG

abort("Rust compiler release binary missing: #{RUST_BIN}") unless RUST_BIN.exist?
abort("igniter-vm release binary missing: #{VM_BIN}") unless VM_BIN.exist?

section("A  Canonical AST desugar")

check("A-01: Ruby accepts the Dispatch-shaped expression body") do
  ruby_parse(EXPRESSION)["parse_errors"].empty?
end

check("A-02: expression == signature block == fully explicit AST") do
  bodies = [EXPRESSION, SIGNATURE_BLOCK, EXPLICIT].map do |src|
    ruby_parse(src).fetch("contracts").first.fetch("body")
  end
  bodies.uniq.length == 1
end

check("A-03: punned RHS == field-explicit RHS AST") do
  ruby_parse(EXPRESSION)["contracts"] == ruby_parse(EXPRESSION_EXPLICIT_RHS)["contracts"]
end

section("B  Dual compiler SIR")

check("B-01: all three forms compile cleanly in Ruby") do
  [EXPRESSION, SIGNATURE_BLOCK, EXPLICIT].all? { |src| ruby_compile(src, "three")[0]["status"] == "ok" }
end

check("B-02: all three forms compile cleanly in Rust") do
  [EXPRESSION, SIGNATURE_BLOCK, EXPLICIT].all? { |src| rust_compile(src, "three")[0]["status"] == "ok" }
end

check("B-03: Ruby expression/block/explicit SIR are identical modulo source envelope") do
  sirs = [EXPRESSION, SIGNATURE_BLOCK, EXPLICIT].map { |src| ruby_compile(src, "sir")[0]["semantic_ir"] }
  sir_identical_modulo_envelope(sirs[0], sirs[1]) && sir_identical_modulo_envelope(sirs[0], sirs[2])
end

check("B-04: Rust expression/block/explicit SIR are identical modulo source envelope") do
  sirs = [EXPRESSION, SIGNATURE_BLOCK, EXPLICIT].map do |src|
    _, out = rust_compile(src, "sir")
    rust_sir(out)
  end
  sir_identical_modulo_envelope(sirs[0], sirs[1]) && sir_identical_modulo_envelope(sirs[0], sirs[2])
end

section("C  VM values")

check("C-01: Ruby/Rust x three spellings execute to the same record") do
  artifacts = [EXPRESSION, SIGNATURE_BLOCK, EXPLICIT].flat_map do |src|
    [ruby_compile(src, "vm")[1], rust_compile(src, "vm")[1]]
  end
  values = artifacts.map { |artifact| vm_run(artifact, INPUTS) }
  values.all? { |value| value["status"] == "success" && value["result"] == EXPECTED }
end

check("C-02: punned and explicit record RHS execute identically") do
  artifacts = [EXPRESSION, EXPRESSION_EXPLICIT_RHS].flat_map do |src|
    [ruby_compile(src, "pun")[1], rust_compile(src, "pun")[1]]
  end
  artifacts.map { |artifact| vm_run(artifact, INPUTS)["result"] }.uniq == [EXPECTED]
end

section("D  Fail-closed diagnostics")

BAD.each do |label, src|
  expected = BAD_MESSAGES.fetch(label)
  check("D Ruby #{label}: one OOF-P1 root") do
    errors = ruby_parse(src)["parse_errors"]
    errors.length == 1 && errors[0]["rule"] == "OOF-P1" && errors[0]["message"] == expected
  end
  check("D Rust #{label}: one OOF-P1 root") do
    report, = rust_compile(src, "bad")
    errors = rust_diags(report)
    report["status"] != "ok" && errors.length == 1 &&
      errors[0]["rule"] == "OOF-P1" && errors[0]["message"] == expected
  end
end

check("D-09: Ruby mismatch is anchored at declared output binding `result`") do
  report, = ruby_compile(TYPE_MISMATCH, "mismatch")
  diagnostics = ruby_diags(report)
  diagnostics.length == 1 && diagnostics[0]["rule"] == "OOF-TY0" &&
    diagnostics[0]["node"] == "result" &&
    diagnostics[0]["message"] == "Binding type mismatch: declared Integer, got String"
end

check("D-10: Rust mismatch matches Ruby at declared output binding `result`") do
  report, = rust_compile(TYPE_MISMATCH, "mismatch")
  diagnostics = rust_diags(report)
  diagnostics.length == 1 && diagnostics[0]["rule"] == "OOF-TY0" &&
    diagnostics[0]["node"] == "result" &&
    diagnostics[0]["message"] == "Binding type mismatch: declared Integer, got String"
end

section("E  Call grammar and old forms unchanged")

check("E-01: Ruby keeps pure Call and effect Invoke natural spellings") do
  parsed = ruby_parse(NATURAL_CALLS)
  pure_compute = parsed["contracts"][1]["body"].find { |node| node["kind"] == "compute" }
  invoke = parsed["contracts"][3]["body"].find { |node| node["kind"] == "invoke" }
  parsed["parse_errors"].empty? && pure_compute.dig("expr", "kind") == "call" &&
    pure_compute.dig("expr", "fn") == "Double" && invoke["callee"] == "EffectDouble" && invoke["using"] == ["net"]
end

check("E-02: Rust accepts the unchanged natural call spellings") do
  report, = rust_compile(NATURAL_CALLS, "calls")
  report["status"] == "ok" && rust_diags(report).empty?
end

check("E-03: existing signature block and explicit forms remain accepted") do
  [SIGNATURE_BLOCK, EXPLICIT].all? do |src|
    ruby_parse(src)["parse_errors"].empty? && rust_compile(src, "regression")[0]["status"] == "ok"
  end
end

puts "\n#{$pass + $fail} checks: #{$pass} PASS, #{$fail} FAIL"
exit($fail.zero? ? 0 : 1)
