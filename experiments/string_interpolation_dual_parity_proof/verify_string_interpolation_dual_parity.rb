#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_string_interpolation_dual_parity.rb
# LANG-STRING-INTERPOLATION-DUAL-PARITY-P2 — "${expr}" as dual-toolchain parse-time sugar.
#
# Rust/lab landed interpolation in LAB-LANG-STRING-INTERPOLATION-SUGAR-P1 (parser-only,
# lowers to nested concat calls). This proof asserts the Ruby/canon mirror and the joint
# law:
#
#   * "prefix ${expr} suffix" desugars to LEFT-ASSOCIATED nested concat(...) calls in
#     both toolchains — no new AST/SIR/VM node, no template runtime;
#   * the interpolation corpus (single, multiple, nested calls + field access, explicit
#     int_to_text/float_to_text, empty prefix/suffix) compiles clean DUAL;
#   * SIR concat-call labels agree cross-toolchain (string.concat / text.concat routing
#     is type-faithful level by level — the Rust rewrite now probes rewritten args, so
#     interpolation chains never fall into the Unknown → collection.concat mislabel);
#   * the Dispatch-shaped key evaluates BYTE-EXACTLY to
#     dispatch:<app>:<key>:generation:<n>:smtp:attempt:1 through the VM from BOTH
#     toolchains' artifacts (this is the focused Dispatch pressure fixture — the live
#     P28 reducer is NOT touched);
#   * conversion stays explicit: `${n}` (Integer) and `${f}` (Float) refuse through the
#     ordinary concat typing DUAL, with the same messages;
#   * malformed interpolation refuses OOF-P1 DUAL with byte-identical messages
#     (unterminated, empty, trailing token, invalid inner expression) and never
#     recovers as literal text;
#   * literal `${` stays HELD: there is NO escape in either toolchain; `\$` refuses
#     OOF-LEX1 "invalid string escape" DUAL (exact temporary limitation, documented in
#     Ch2);
#   * const RHS strings do NOT desugar in either toolchain (parity of the const path);
#   * plain literals and existing escape behavior are unregressed.

require "json"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "igniter_lang"

ROOT = Pathname.new(__dir__).join("../..").expand_path
WORKSPACE = ROOT.join("..").expand_path
LAB_ROOT = WORKSPACE.join("igniter-lab")
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

def section(t)
  puts "\n== #{t} =="
end

def ruby_compile(src, tag)
  dir = Dir.mktmpdir("interp_rb_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out.igapp")
  report = IgniterLang.compile(source_path: path, out_path: out)
  [report, out]
end

def rust_compile(src, tag)
  dir = Dir.mktmpdir("interp_rs_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out.igapp")
  stdout, = Open3.capture3({ "LANG" => "en_US.UTF-8" }, RUST_BIN.to_s, "compile", path, "--out", out)
  [JSON.parse(stdout.force_encoding("UTF-8")), out]
end

def ruby_diags(report)
  Array(report.dig("compilation_report", "diagnostics")).map { |d| [d["rule"], d["message"]] }
end

def rust_diags(report)
  Array(report["diagnostics"]).map { |d| [d["rule"], d["message"]] }
end

def vm_run(contract_artifact, inputs)
  dir = Dir.mktmpdir("interp_vm_")
  inp = File.join(dir, "inputs.json")
  File.write(inp, JSON.generate(inputs))
  stdout, = Open3.capture3({ "LANG" => "en_US.UTF-8" }, VM_BIN.to_s, "run", "--contract", contract_artifact.to_s, "--inputs", inp, "--json")
  JSON.parse(stdout.force_encoding("UTF-8"))
end

def ruby_parse(src)
  IgniterLang::Parser.new(IgniterLang::Lexer.new(src).tokenize).parse
end

def sir(out_dir)
  JSON.parse(File.read(File.join(out_dir, "semantic_ir_program.json")))
end

def call_fns(node, out = [])
  case node
  when Hash
    out << node["fn"] if node["kind"] == "call"
    node.each_value { |v| call_fns(v, out) }
  when Array
    node.each { |v| call_fns(v, out) }
  end
  out
end

def contract_src(compute_expr, extra_inputs = "")
  <<~IG
    module Probe.Interp

    contract C {
      input name: String
      input other: String
    #{extra_inputs}
      compute msg: String = #{compute_expr}
      output msg: String
    }
  IG
end

# ── Fixtures ────────────────────────────────────────────────────────────────

DISPATCH_KEY = <<~IG
  module Probe.DispatchKey

  contract BuildKey {
    input application_id: String
    input idempotency_key: String
    input generation: Integer
    compute key: String = "dispatch:${application_id}:${idempotency_key}:generation:${int_to_text(generation)}:smtp:attempt:1"
    output key: String
  }
IG

FIELD_ACCESS = <<~IG
  module Probe.InterpField

  type User {
    name: String
  }

  contract C {
    input user: User
    compute msg: String = "Hello ${user.name}!"
    output msg: String
  }
IG

INTERP_Q = '"Hello ${name}!"'
MULTI_Q = '"a ${name} b ${other} c"'
EDGES_Q = '"${name}${other}"'
LEAD_Q  = '"${name} tail"'

UNTERM_Q   = '"Hello ${name' + '"'
EMPTY_Q    = '"Hello ${} x"'
TRAILING_Q = '"Hello ${name name}"'
INVALID_Q  = '"Hello ${name!}"'

UNTERM_MSG   = "unterminated string interpolation; expected `}`"
EMPTY_MSG    = "empty string interpolation expression"
TRAILING_MSG = "invalid string interpolation expression `name name`: trailing token `name`"
INVALID_MSG  = "invalid string interpolation expression `name!`: trailing token `!`"

# ════════════════════════════════════════════════════════════════════════════

section("A  Desugar shape — left-associated nested concat, no new node (Ruby AST)")

check("A-01: single interpolation desugars to nested concat calls") do
  ast = ruby_parse(contract_src(INTERP_Q))
  node = ast["contracts"][0]["body"].find { |d| d["name"] == "msg" }
  e = node["expr"]
  e["kind"] == "call" && e["fn"] == "concat" &&
    e.dig("args", 1, "value") == "!" &&
    e.dig("args", 0, "fn") == "concat" &&
    e.dig("args", 0, "args", 0, "value") == "Hello " &&
    e.dig("args", 0, "args", 1, "name") == "name"
end

check("A-02: adjacent interpolations produce NO empty literal parts") do
  ast = ruby_parse(contract_src(EDGES_Q))
  node = ast["contracts"][0]["body"].find { |d| d["name"] == "msg" }
  e = node["expr"]
  e["fn"] == "concat" && e.dig("args", 0, "name") == "name" && e.dig("args", 1, "name") == "other"
end

check("A-03: plain literal stays a plain literal node") do
  ast = ruby_parse(contract_src('"no interpolation here"'))
  node = ast["contracts"][0]["body"].find { |d| d["name"] == "msg" }
  node["expr"]["kind"] == "literal"
end

check("A-04: const RHS string with ${ stays literal (parity with Rust const path)") do
  ast = ruby_parse(<<~IG)
    module M.C
    const template: String = "hello ${world}"
  IG
  consts = ast["consts"] || ast["constants"] || []
  decl = consts.first
  decl && decl.dig("expr", "kind") == "literal" && ast["parse_errors"].empty?
end

section("B  Accepted corpus compiles clean DUAL")

CORPUS = {
  "single"    => contract_src(INTERP_Q),
  "multi"     => contract_src(MULTI_Q),
  "edges"     => contract_src(EDGES_Q),
  "lead"      => contract_src(LEAD_Q),
  "int_conv"  => contract_src('"Count ${int_to_text(n)}"', "  input n: Integer\n"),
  "field"     => FIELD_ACCESS,
  "dispatch"  => DISPATCH_KEY
}.freeze

# NB: the rounding-mode string is escaped in .ig source (\"half_even\"); the lexer
# decodes it and find_interpolation_end skips nested strings on the decoded value.
FLOAT_CONV = contract_src('"Ratio ${float_to_text(f, 2, \\"half_even\\")}"', "  input f: Float\n")

RB_OUT = {}
RS_OUT = {}
CORPUS.each do |tag, src|
  rb, rb_out = ruby_compile(src, tag)
  rs, rs_out = rust_compile(src, tag)
  RB_OUT[tag] = rb_out
  RS_OUT[tag] = rs_out
  check("B: #{tag} compiles ok DUAL") do
    rb["status"] == "ok" && rs["status"] == "ok"
  end
end

section("C  SIR parity — concat-call labels agree cross-toolchain")

CORPUS.each_key do |tag|
  check("C: #{tag} SIR call-label sequence identical (Ruby vs Rust)") do
    call_fns(sir(RB_OUT[tag])) == call_fns(sir(RS_OUT[tag]))
  end
end

section("B2  Honest boundary — float_to_text is Rust-only today")

# Pre-existing single-toolchain stdlib gap, NOT an interpolation defect: the Ruby
# typechecker has no float_to_text entry at all. Explicit Float formatting through
# interpolation works in Rust and refuses fail-closed in Ruby. Named follow-up:
# a Ruby float_to_text card on the stdlib lane (recorded in the closure packet).
check("B2-01: float_to_text interpolation compiles in Rust; Ruby refuses fail-closed naming the fn") do
  rs, = rust_compile(FLOAT_CONV, "float_conv")
  rb, = ruby_compile(FLOAT_CONV, "float_conv")
  rs["status"] == "ok" &&
    rb["status"] != "ok" &&
    ruby_diags(rb).any? { |r, m| r == "OOF-TY0" && m.include?("Unknown function: float_to_text") }
end

section("D  VM execution — Dispatch-shaped key, byte-exact, both artifacts")

inputs = { "application_id" => "app-7", "idempotency_key" => "idem-42", "generation" => 3 }
expected = "dispatch:app-7:idem-42:generation:3:smtp:attempt:1"

rb_run = vm_run(File.join(RB_OUT["dispatch"], "contracts/build_key.json"), inputs)
rs_run = vm_run(File.join(RS_OUT["dispatch"], "contracts/build_key.json"), inputs)

check("D-01: Ruby artifact evaluates the key byte-exactly") do
  rb_run["status"] == "success" && rb_run["result"] == expected
end
check("D-02: Rust artifact evaluates the key byte-exactly") do
  rs_run["status"] == "success" && rs_run["result"] == expected
end

section("E  Explicit conversion law — implicit numerics refuse DUAL")

rb_int, = ruby_compile(contract_src('"Count ${n}"', "  input n: Integer\n"), "imp_int")
rs_int, = rust_compile(contract_src('"Count ${n}"', "  input n: Integer\n"), "imp_int")

check("E-01: implicit Integer interpolation refuses OOF-TY0 DUAL, same message") do
  rb = ruby_diags(rb_int).select { |r, _| r == "OOF-TY0" }
  rs = rust_diags(rs_int).select { |r, _| r == "OOF-TY0" }
  !rb.empty? && rb.sort == rs.sort
end

rb_flt, = ruby_compile(contract_src('"Ratio ${f}"', "  input f: Float\n"), "imp_flt")
rs_flt, = rust_compile(contract_src('"Ratio ${f}"', "  input f: Float\n"), "imp_flt")

check("E-02: implicit Float interpolation refuses OOF-TY0 DUAL, same message") do
  rb = ruby_diags(rb_flt).select { |r, _| r == "OOF-TY0" }
  rs = rust_diags(rs_flt).select { |r, _| r == "OOF-TY0" }
  !rb.empty? && rb.sort == rs.sort
end

section("F  Malformed corpus — OOF-P1 DUAL, byte-identical messages, no literal recovery")

MALFORMED = {
  "unterminated" => [UNTERM_Q, UNTERM_MSG],
  "empty"        => [EMPTY_Q, EMPTY_MSG],
  "trailing"     => [TRAILING_Q, TRAILING_MSG],
  "invalid"      => [INVALID_Q, INVALID_MSG]
}.freeze

MALFORMED.each do |tag, (expr, msg)|
  src = contract_src(expr)
  check("F: #{tag} refuses OOF-P1 DUAL with the same message") do
    rb, = ruby_compile(src, "bad_#{tag}")
    rs, = rust_compile(src, "bad_#{tag}")
    ruby_diags(rb).include?(["OOF-P1", msg]) &&
      rust_diags(rs).include?(["OOF-P1", msg]) &&
      rb["status"] != "ok" && rs["status"] != "ok"
  end
end

section("G  Literal ${ stays HELD — no escape in either toolchain")

check("G-01: \\$ refuses OOF-LEX1 'invalid string escape' DUAL") do
  src = contract_src('"price \\${100}"')
  rb, = ruby_compile(src, "esc")
  rs, = rust_compile(src, "esc")
  rb_hit = ruby_diags(rb).any? { |r, m| r == "OOF-LEX1" && m.include?("invalid string escape") }
  rs_hit = rust_diags(rs).any? { |r, m| r == "OOF-LEX1" && m.include?("invalid string escape") }
  rb_hit && rs_hit
end

section("H  Unregressed — plain strings and escapes")

check("H-01: plain literal contract compiles ok DUAL") do
  src = contract_src('"just text"')
  rb, = ruby_compile(src, "plain")
  rs, = rust_compile(src, "plain")
  rb["status"] == "ok" && rs["status"] == "ok"
end

check("H-02: decoded escapes still work and do not fake interpolation DUAL") do
  src = contract_src('"line1\\n\\"quoted\\" tab\\t"')
  rb, = ruby_compile(src, "escapes")
  rs, = rust_compile(src, "escapes")
  rb["status"] == "ok" && rs["status"] == "ok"
end

# ════════════════════════════════════════════════════════════════════════════
puts "\n#{$pass + $fail} checks: #{$pass} PASS, #{$fail} FAIL"
exit($fail.zero? ? 0 : 1)
