#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_concat_operator_dual_parity.rb
# LANG-CONCAT-OPERATOR-DUAL-PARITY-P1 — `++` honest and identical in both toolchains.
#
# `++` was already declared in the canon grammar (ch2) and implemented in the Rust
# typechecker; the Ruby typechecker had no `++` arm and refused every use with
# OOF-TY0 "Unsupported operator: ++". This proof asserts the closed split:
#
#   * String ++ String and Collection[T] ++ Collection[T] compile clean DUAL;
#   * Ruby lowers `++` to the existing qualified concat calls (stdlib.string.concat /
#     stdlib.collection.concat) — no new AST/SIR node; Rust SIR keeps its binary_op
#     node (pre-existing shape, normalized by the conformance op_map);
#   * the VM executes BOTH toolchains' artifacts byte-identically, including `++`
#     inside a HOF lambda (eval_ast path) and at the top level (bytecode path);
#   * mixed operands refuse OOF-TY0 with the SAME message dual;
#   * collection element mismatch refuses through the existing concat law (OOF-COL7,
#     first Rust activation) with the SAME message dual — on ANNOTATED collections.
#     Array-literal element mismatch stays a known pre-existing split (Rust types
#     array literals Unknown by design, LAB-TC-ARRAY-P1; same asymmetry exists on the
#     named concat(...) path — routed to the collection-concat wave, NOT this card);
#   * Text ++ Text refuses DUAL today (current alias policy: `++` accepts the String
#     spelling only; named concat(Text, Text) stays the Text route) — no implicit
#     coercion invented;
#   * `String + String` refuses OOF-TY0 with an actionable dual hint naming `++` and
#     string interpolation; non-text `+` refusals keep the plain message;
#   * numeric `+` and its SIR stay unchanged.

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
  dir = Dir.mktmpdir("concat_rb_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out.igapp")
  report = IgniterLang.compile(source_path: path, out_path: out)
  [report, out]
end

def rust_compile(src, tag)
  dir = Dir.mktmpdir("concat_rs_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out.igapp")
  # LANG=en_US.UTF-8: the Rust binaries emit UTF-8; without it Open3 captures
  # US-ASCII and JSON.parse raises Encoding::InvalidByteSequenceError.
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
  dir = Dir.mktmpdir("concat_vm_")
  inp = File.join(dir, "inputs.json")
  File.write(inp, JSON.generate(inputs))
  stdout, = Open3.capture3({ "LANG" => "en_US.UTF-8" }, VM_BIN.to_s, "run", "--contract", contract_artifact.to_s, "--inputs", inp, "--json")
  JSON.parse(stdout.force_encoding("UTF-8"))
end

def sir_exprs(out_dir)
  JSON.parse(File.read(File.join(out_dir, "semantic_ir_program.json")))
end

def find_nodes(node, out = [], &pred)
  case node
  when Hash
    out << node if pred.call(node)
    node.each_value { |v| find_nodes(v, out, &pred) }
  when Array
    node.each { |v| find_nodes(v, out, &pred) }
  end
  out
end

# ── Fixtures ────────────────────────────────────────────────────────────────

GOOD = <<~IG
  module Probe.ConcatGood

  type ConcatResult {
    label: String
    merged: Collection[Integer]
  }

  contract GoodCases {
    input prefix: String
    input suffix: String
    input ints: Collection[Integer]
    input more: Collection[Integer]
    compute label: String = prefix ++ suffix
    compute merged: Collection[Integer] = ints ++ more
    compute result: ConcatResult = { label: label, merged: merged }
    output result: ConcatResult
  }
IG

HOF = <<~IG
  module Probe.ConcatHof

  contract FoldConcat {
    input items: Collection[Integer]
    compute rebuilt: Collection[Integer] = fold(items, [], (acc, x) -> acc ++ [x])
    output rebuilt: Collection[Integer]
  }
IG

MIXED = <<~IG
  module Probe.ConcatMixed

  contract Mixed {
    input prefix: String
    input n: Integer
    compute label: String = prefix ++ n
    output label: String
  }
IG

ELEM_MISMATCH = <<~IG
  module Probe.ConcatElems

  contract ElemMismatch {
    input ints: Collection[Integer]
    input texts: Collection[String]
    compute merged: Collection[Integer] = ints ++ texts
    output merged: Collection[Integer]
  }
IG

TEXT_ALIAS = <<~IG
  module Probe.ConcatText

  contract TextAlias {
    input a: Text
    input b: Text
    compute label: Text = a ++ b
    output label: Text
  }
IG

PLUS_HINT = <<~IG
  module Probe.PlusHint

  contract PlusHint {
    input prefix: String
    input suffix: String
    compute label: String = prefix + suffix
    output label: String
  }
IG

PLUS_PLAIN = <<~IG
  module Probe.PlusPlain

  contract PlusPlain {
    input a: Integer
    input flag: Bool
    compute s: Integer = a + flag
    output s: Integer
  }
IG

NUMERIC_OK = <<~IG
  module Probe.NumericOk

  contract Add {
    input a: Integer
    input b: Integer
    compute sum: Integer = a + b
    output sum: Integer
  }
IG

MIXED_MSG = "Type mismatch: expected String/String or Collection/Collection, got String++Integer"
TEXT_MSG  = "Type mismatch: expected String/String or Collection/Collection, got Text++Text"
COL7_MSG  = "stdlib.collection.concat: element type mismatch — first collection contains Integer, second contains String"
HINT_MSG  = "Type mismatch: expected Integer, got String+String; `+` is arithmetic — use `++` or string interpolation for text"
PLAIN_MSG = "Type mismatch: expected Integer, got Integer+Bool"

# ════════════════════════════════════════════════════════════════════════════

section("A  Accepted surface compiles clean DUAL")

rb_good, rb_good_out = ruby_compile(GOOD, "good")
rs_good, rs_good_out = rust_compile(GOOD, "good")

check("A-01: String/Collection ++ compiles ok (Ruby)") { rb_good["status"] == "ok" }
check("A-02: String/Collection ++ compiles ok (Rust)") { rs_good["status"] == "ok" }

rb_hof, rb_hof_out = ruby_compile(HOF, "hof")
rs_hof, rs_hof_out = rust_compile(HOF, "hof")

check("A-03: ++ inside HOF lambda compiles ok (Ruby)") { rb_hof["status"] == "ok" }
check("A-04: ++ inside HOF lambda compiles ok (Rust)") { rs_hof["status"] == "ok" }

section("B  Lowering shape — no new AST/SIR node")

rb_sir = sir_exprs(rb_good_out)
rs_sir = sir_exprs(rs_good_out)

check("B-01: Ruby lowers String ++ to a stdlib.string.concat call") do
  find_nodes(rb_sir) { |n| n["kind"] == "call" && n["fn"] == "stdlib.string.concat" }.size == 1
end

check("B-02: Ruby lowers Collection ++ to a stdlib.collection.concat call") do
  find_nodes(rb_sir) { |n| n["kind"] == "call" && n["fn"] == "stdlib.collection.concat" }.size == 1
end

check("B-03: Ruby emits NO unsupported-operator node") do
  find_nodes(rb_sir) { |n| n["fn"].to_s.start_with?("stdlib.unsupported") }.empty?
end

check("B-04: Rust SIR keeps the pre-existing binary_op '++' shape (2 nodes)") do
  find_nodes(rs_sir) { |n| n["kind"] == "binary_op" && n["op"] == "++" }.size == 2
end

check("B-05: operand refs agree cross-toolchain for the String case") do
  rb_call = find_nodes(rb_sir) { |n| n["kind"] == "call" && n["fn"] == "stdlib.string.concat" }.first
  rs_op = find_nodes(rs_sir) { |n| n["kind"] == "binary_op" && n["op"] == "++" }
              .find { |n| n.dig("left", "name") == "prefix" }
  rb_call.dig("args", 0, "name") == "prefix" && rb_call.dig("args", 1, "name") == "suffix" &&
    rs_op.dig("left", "name") == "prefix" && rs_op.dig("right", "name") == "suffix"
end

section("C  VM execution — full tuple, both toolchains, both paths")

inputs = { "prefix" => "foo", "suffix" => "bar", "ints" => [1, 2], "more" => [3] }
rb_run = vm_run(File.join(rb_good_out, "contracts/good_cases.json"), inputs)
rs_run = vm_run(File.join(rs_good_out, "contracts/good_cases.json"), inputs)

check("C-01: Ruby artifact runs (top-level/bytecode path)") { rb_run["status"] == "success" }
check("C-02: Rust artifact runs (top-level/bytecode path)") { rs_run["status"] == "success" }
check("C-03: results byte-identical dual: label 'foobar', merged [1,2,3]") do
  rb_run["result"] == { "label" => "foobar", "merged" => [1, 2, 3] } &&
    rb_run["result"] == rs_run["result"]
end

hof_inputs = { "items" => [4, 5, 6] }
rb_hof_run = vm_run(File.join(rb_hof_out, "contracts/fold_concat.json"), hof_inputs)
rs_hof_run = vm_run(File.join(rs_hof_out, "contracts/fold_concat.json"), hof_inputs)

# Single-output contracts project the bare value into "result".
check("C-04: ++ in HOF lambda executes (Ruby artifact, eval_ast path)") do
  rb_hof_run["status"] == "success" && rb_hof_run["result"] == [4, 5, 6]
end
check("C-05: ++ in HOF lambda executes (Rust artifact, eval_ast path)") do
  rs_hof_run["status"] == "success" && rs_hof_run["result"] == [4, 5, 6]
end

section("D  Refusals — aligned OOF families, byte-identical messages")

rb_mixed, = ruby_compile(MIXED, "mixed")
rs_mixed, = rust_compile(MIXED, "mixed")

check("D-01: String ++ Integer refuses OOF-TY0 (Ruby)") { ruby_diags(rb_mixed).include?(["OOF-TY0", MIXED_MSG]) }
check("D-02: String ++ Integer refuses OOF-TY0 (Rust), same message") { rust_diags(rs_mixed).include?(["OOF-TY0", MIXED_MSG]) }

rb_elem, = ruby_compile(ELEM_MISMATCH, "elem")
rs_elem, = rust_compile(ELEM_MISMATCH, "elem")

check("D-03: annotated element mismatch refuses OOF-COL7 (Ruby)") { ruby_diags(rb_elem).include?(["OOF-COL7", COL7_MSG]) }
check("D-04: annotated element mismatch refuses OOF-COL7 (Rust, first activation), same message") do
  rust_diags(rs_elem).include?(["OOF-COL7", COL7_MSG])
end

rb_text, = ruby_compile(TEXT_ALIAS, "text")
rs_text, = rust_compile(TEXT_ALIAS, "text")

check("D-05: Text ++ Text refuses DUAL today (alias policy: `++` accepts the String spelling)") do
  ruby_diags(rb_text).include?(["OOF-TY0", TEXT_MSG]) && rust_diags(rs_text).include?(["OOF-TY0", TEXT_MSG])
end

section("E  `+` stays arithmetic; text refusal carries the actionable hint")

rb_hint, = ruby_compile(PLUS_HINT, "hint")
rs_hint, = rust_compile(PLUS_HINT, "hint")

check("E-01: String + String refuses with the `++`/interpolation hint (Ruby)") { ruby_diags(rb_hint).include?(["OOF-TY0", HINT_MSG]) }
check("E-02: String + String refuses with the `++`/interpolation hint (Rust), same message") { rust_diags(rs_hint).include?(["OOF-TY0", HINT_MSG]) }

rb_plain, = ruby_compile(PLUS_PLAIN, "plain")
rs_plain, = rust_compile(PLUS_PLAIN, "plain")

check("E-03: non-text + refusal keeps the plain message, no hint (Ruby)") do
  msgs = ruby_diags(rb_plain)
  msgs.include?(["OOF-TY0", PLAIN_MSG]) && msgs.none? { |_, m| m.include?("string interpolation") }
end
check("E-04: non-text + refusal keeps the plain message, no hint (Rust)") do
  msgs = rust_diags(rs_plain)
  msgs.include?(["OOF-TY0", PLAIN_MSG]) && msgs.none? { |_, m| m.include?("string interpolation") }
end

section("F  Numeric + unregressed — full tuple")

rb_num, rb_num_out = ruby_compile(NUMERIC_OK, "num")
rs_num, rs_num_out = rust_compile(NUMERIC_OK, "num")

check("F-01: Integer + Integer compiles ok dual") { rb_num["status"] == "ok" && rs_num["status"] == "ok" }
check("F-02: numeric SIR unchanged (Ruby stdlib.integer.add, Rust binary_op '+')") do
  find_nodes(sir_exprs(rb_num_out)) { |n| n["kind"] == "call" && n["fn"] == "stdlib.integer.add" }.size == 1 &&
    find_nodes(sir_exprs(rs_num_out)) { |n| n["kind"] == "binary_op" && n["op"] == "+" }.size == 1
end
check("F-03: 19 + 23 still executes to 42 dual") do
  a = vm_run(File.join(rb_num_out, "contracts/add.json"), { "a" => 19, "b" => 23 })
  b = vm_run(File.join(rs_num_out, "contracts/add.json"), { "a" => 19, "b" => 23 })
  a["result"] == 42 && b["result"] == 42
end

# ════════════════════════════════════════════════════════════════════════════
puts "\n#{$pass + $fail} checks: #{$pass} PASS, #{$fail} FAIL"
exit($fail.zero? ? 0 : 1)
