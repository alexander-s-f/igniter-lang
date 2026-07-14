#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_record_field_punning_canon_parity.rb
# LANG-RECORD-FIELD-PUNNING-CANON-PARITY-P1 — record field punning as dual-toolchain parser sugar.
#
# Rust/lab landed `{ name }` ⇒ `{ name: name }` as pure parse-time sugar (LAB-LANG-RECORD-FIELD-
# PUNNING-P2, parser-only, byte-identical SIR). This proof asserts the Ruby/canon mirror:
#
#   * `{ name }` and mixed `{ name, other: expr }` parse to the SAME canonical record_literal
#     AST as the explicit form (value = ref) — no new AST/SIR node;
#   * punned == explicit is BYTE-IDENTICAL at the SIR record_literal level in BOTH toolchains;
#   * cross-toolchain (Ruby vs Rust) the punned fixture's record_literal nodes are equivalent
#     after dropping the known volatile decoration keys (resolved_type — Ruby annotates, Rust
#     does not; same normalization as tests/conformance/conformance_runner.rb);
#   * VM-visible values are identical across all four artifacts (Ruby/Rust x punned/explicit);
#   * missing punned symbol falls through the normal unresolved-symbol path (OOF-P1) dual;
#   * unexpected punned field falls through the normal record-shape path (OOF-TY0 / "unexpected
#     field") dual;
#   * duplicate fields fail CLOSED with the same message dual ("duplicate field `x` in record
#     literal") — no last-write-wins;
#   * dotted punning `{ a.b }` is a parse error dual ("Expected name, got dot/Dot");
#   * closed forms stay closed: string-key punning is a parse error;
#   * explicit records are unregressed.
#
# Honest boundary: `{ ...base, name }` (spread + punning) is Rust/lab-only — Ruby/canon has NO
# record spread surface at all (pre-existing delta, not introduced here). This proof asserts the
# Rust side still compiles it and that Ruby fails CLOSED (parse diagnostic, never a silent wrong
# AST).

require "json"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "igniter_lang"
require "igniter_lang/compiler_orchestrator"

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

# ── Ruby helpers ────────────────────────────────────────────────────────────

def ruby_parse(src)
  IgniterLang::ParsedProgram.parse(src, source_path: "inline").to_h
end

def ruby_compile(src, tag)
  dir = Dir.mktmpdir("pun_rb_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out.igapp")
  orch = IgniterLang.compile(source_path: path, out_path: out)
  [orch, out]
end

# ── Rust helpers (require the sibling release binaries) ─────────────────────

def rust_compile(src, tag)
  dir = Dir.mktmpdir("pun_rs_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out")
  # LANG=en_US.UTF-8: the Rust binaries emit UTF-8; without it Open3 captures
  # US-ASCII and JSON.parse raises Encoding::InvalidByteSequenceError.
  stdout, = Open3.capture3({ "LANG" => "en_US.UTF-8" }, RUST_BIN.to_s, "compile", path, "--out", out)
  [JSON.parse(stdout.force_encoding("UTF-8")), out]
end

def rust_diag_messages(report)
  Array(report["diagnostics"]).map { |d| d["message"].to_s }
end

def vm_run(artifact, inputs)
  dir = Dir.mktmpdir("pun_vm_")
  inp = File.join(dir, "inputs.json")
  File.write(inp, JSON.generate(inputs))
  stdout, = Open3.capture3({ "LANG" => "en_US.UTF-8" }, VM_BIN.to_s, "run", "--contract", artifact.to_s, "--inputs", inp, "--json")
  JSON.parse(stdout.force_encoding("UTF-8"))
end

# ── SIR extraction / normalization ──────────────────────────────────────────

# Decoration keys one toolchain adds and the other doesn't (same axis as the
# conformance runner's VOLATILE_KEYS) — dropped ONLY for the cross-toolchain
# comparison. Intra-toolchain comparisons are byte-identical, nothing dropped.
CROSS_TOOLCHAIN_VOLATILE = %w[resolved_type].freeze

def record_literal_nodes(node, out = [])
  case node
  when Hash
    out << node if node["kind"] == "record_literal"
    node.each_value { |v| record_literal_nodes(v, out) }
  when Array
    node.each { |v| record_literal_nodes(v, out) }
  end
  out
end

def strip_volatile(node)
  case node
  when Hash
    node.each_with_object({}) do |(k, v), h|
      next if CROSS_TOOLCHAIN_VOLATILE.include?(k)
      h[k] = strip_volatile(v)
    end
  when Array
    node.map { |v| strip_volatile(v) }
  else
    node
  end
end

def sorted_json(node)
  case node
  when Hash
    JSON.generate(node.keys.sort.to_h { |k| [k, JSON.parse(sorted_json(node[k]))] })
  when Array
    JSON.generate(node.map { |v| JSON.parse(sorted_json(v)) })
  else
    JSON.generate(node)
  end
end

def rust_sir(out_dir)
  JSON.parse(File.read(File.join(out_dir, "semantic_ir_program.json")))
end

# ── Fixtures ────────────────────────────────────────────────────────────────

WV_TYPE = "type WV { account_id: String  title: String  done: String }\n"

PUNNED = <<~IG
  module T
  #{WV_TYPE}
  pure contract MakeWriteValues {
    input account_id : String
    input title : String
    input done : String
    compute v : WV = { account_id, title, done }
    output v : WV
  }
IG

EXPLICIT = <<~IG
  module T
  #{WV_TYPE}
  pure contract MakeWriteValues {
    input account_id : String
    input title : String
    input done : String
    compute v : WV = { account_id: account_id, title: title, done: done }
    output v : WV
  }
IG

MIXED = <<~IG
  module T
  type QF { field: String  op: String  value: String }
  pure contract C {
    input value : String
    compute f : QF = { field: "account_id", op: "eq", value }
    output f : QF
  }
IG

MIXED_EXPLICIT = <<~IG
  module T
  type QF { field: String  op: String  value: String }
  pure contract C {
    input value : String
    compute f : QF = { field: "account_id", op: "eq", value: value }
    output f : QF
  }
IG

MISSING_SYMBOL = <<~IG
  module T
  type WV { account_id: String }
  pure contract C {
    compute v : WV = { account_id }
    output v : WV
  }
IG

UNEXPECTED_FIELD = <<~IG
  module T
  type WV { account_id: String }
  pure contract C {
    input account_id : String
    input nope : String
    compute v : WV = { account_id, nope }
    output v : WV
  }
IG

DUPLICATE = <<~IG
  module T
  pure contract C {
    input a : String
    compute v = { a, a }
    output v : String
  }
IG

DOTTED = <<~IG
  module T
  type WV { id: String }
  pure contract C {
    input account : String
    compute v : WV = { account.id }
    output v : WV
  }
IG

STRING_KEY = <<~IG
  module T
  pure contract C {
    input a : String
    compute v = { "a" }
    output v : String
  }
IG

SPREAD_PUN = <<~IG
  module T
  type Ctx { account_id: String  todo_id: String }
  pure contract C {
    input ctx : Ctx
    input todo_id : String
    compute next : Ctx = { ...ctx, todo_id }
    output next : Ctx
  }
IG

INPUTS = { "account_id" => "a1", "title" => "t1", "done" => "yes" }.freeze

# ════════════════════════════════════════════════════════════════════════════
abort("Rust compiler release binary missing: #{RUST_BIN}") unless RUST_BIN.exist?
abort("igniter-vm release binary missing: #{VM_BIN}") unless VM_BIN.exist?

section("A  Ruby parser — punned forms parse to the canonical record_literal AST")

check("A-01: { name, ... } parses with ZERO parse errors") do
  ruby_parse(PUNNED)["parse_errors"].empty?
end

check("A-02: punned AST == explicit AST (identical record_literal, value = ref)") do
  pun = ruby_parse(PUNNED)
  exp = ruby_parse(EXPLICIT)
  pun_c = pun["contracts"][0]["body"].find { |n| n["kind"] == "compute" }
  exp_c = exp["contracts"][0]["body"].find { |n| n["kind"] == "compute" }
  pun_c == exp_c && pun_c.dig("expr", "fields", "title") == { "kind" => "ref", "name" => "title" }
end

check("A-03: mixed punned + explicit parses and equals fully-explicit AST") do
  ruby_parse(MIXED)["parse_errors"].empty? &&
    ruby_parse(MIXED)["contracts"] == ruby_parse(MIXED_EXPLICIT)["contracts"]
end

section("B  Ruby compile — punned forms are typecheck-clean; SIR identical to explicit")

check("B-01: punned fixture compiles ok") do
  ruby_compile(PUNNED, "pun")[0]["status"] == "ok"
end

check("B-02: mixed fixture compiles ok") do
  ruby_compile(MIXED, "mixed")[0]["status"] == "ok"
end

check("B-03: Ruby SIR record_literal nodes: punned BYTE-IDENTICAL to explicit") do
  pun_sir = ruby_compile(PUNNED, "pun_sir")[0]["semantic_ir"]
  exp_sir = ruby_compile(EXPLICIT, "exp_sir")[0]["semantic_ir"]
  pun_nodes = record_literal_nodes(pun_sir)
  exp_nodes = record_literal_nodes(exp_sir)
  !pun_nodes.empty? && JSON.generate(pun_nodes) == JSON.generate(exp_nodes)
end

section("C  Rust regression — proven lab forms still compile; SIR identity holds")

check("C-01: Rust punned fixture compiles ok") do
  rust_compile(PUNNED, "pun")[0]["status"] == "ok"
end

check("C-02: Rust spread + punning `{ ...ctx, todo_id }` compiles ok (lab-only surface)") do
  rust_compile(SPREAD_PUN, "spread")[0]["status"] == "ok"
end

check("C-03: Rust SIR record_literal nodes: punned BYTE-IDENTICAL to explicit") do
  _, pun_dir = rust_compile(PUNNED, "pun_sir")
  _, exp_dir = rust_compile(EXPLICIT, "exp_sir")
  pun_nodes = record_literal_nodes(rust_sir(pun_dir))
  exp_nodes = record_literal_nodes(rust_sir(exp_dir))
  !pun_nodes.empty? && sorted_json(pun_nodes) == sorted_json(exp_nodes)
end

section("D  Cross-toolchain — Ruby vs Rust record_literal SIR equivalence + VM values")

check("D-01: punned record_literal nodes equivalent Ruby vs Rust (volatile keys dropped)") do
  rb_sir = ruby_compile(PUNNED, "x_rb")[0]["semantic_ir"]
  _, rs_dir = rust_compile(PUNNED, "x_rs")
  rb_nodes = strip_volatile(record_literal_nodes(rb_sir))
  rs_nodes = strip_volatile(record_literal_nodes(rust_sir(rs_dir)))
  !rb_nodes.empty? && sorted_json(rb_nodes) == sorted_json(rs_nodes)
end

check("D-02: VM-visible values identical across Ruby/Rust x punned/explicit (4 artifacts)") do
  _, rb_pun = ruby_compile(PUNNED, "vm_rb_pun")
  _, rb_exp = ruby_compile(EXPLICIT, "vm_rb_exp")
  _, rs_pun = rust_compile(PUNNED, "vm_rs_pun")
  _, rs_exp = rust_compile(EXPLICIT, "vm_rs_exp")
  results = [rb_pun, rb_exp, rs_pun, rs_exp].map { |a| vm_run(a, INPUTS) }
  expected = { "account_id" => "a1", "title" => "t1", "done" => "yes" }
  results.all? { |r| r["status"] == "success" } &&
    results.map { |r| r["result"] }.uniq == [expected]
end

section("E  Diagnostics — existing root paths, aligned dual-toolchain")

check("E-01: missing punned symbol → OOF-P1 'Unresolved symbol' (Ruby)") do
  orch, = ruby_compile(MISSING_SYMBOL, "missing")
  diags = Array(orch.dig("compilation_report", "diagnostics"))
  orch["status"] != "ok" &&
    diags.any? { |d| d["rule"] == "OOF-P1" && d["message"].to_s.include?("Unresolved symbol: account_id") }
end

check("E-02: missing punned symbol → 'Unresolved symbol' (Rust)") do
  rep, = rust_compile(MISSING_SYMBOL, "missing")
  rep["status"] != "ok" && rust_diag_messages(rep).any? { |m| m.include?("Unresolved symbol: account_id") }
end

check("E-03: unexpected punned field → OOF-TY0 'unexpected field' (Ruby)") do
  orch, = ruby_compile(UNEXPECTED_FIELD, "extra")
  diags = Array(orch.dig("compilation_report", "diagnostics"))
  orch["status"] != "ok" &&
    diags.any? { |d| d["rule"] == "OOF-TY0" && d["message"].to_s.include?("unexpected field") }
end

check("E-04: unexpected punned field → 'unexpected field' (Rust)") do
  rep, = rust_compile(UNEXPECTED_FIELD, "extra")
  rep["status"] != "ok" && rust_diag_messages(rep).any? { |m| m.include?("unexpected field") }
end

check("E-05: duplicate field fails CLOSED with the shared message (Ruby)") do
  parsed = ruby_parse(DUPLICATE)
  parsed["parse_errors"].any? { |e| e["message"].to_s.include?("duplicate field `a` in record literal") }
end

check("E-06: duplicate field fails CLOSED with the shared message (Rust)") do
  rep, = rust_compile(DUPLICATE, "dup")
  rep["status"] != "ok" && rust_diag_messages(rep).any? { |m| m.include?("duplicate field `a` in record literal") }
end

check("E-07: dotted punning is a parse error (Ruby: 'Expected name, got dot')") do
  parsed = ruby_parse(DOTTED)
  parsed["parse_errors"].any? { |e| e["message"].to_s.include?("Expected name, got dot") }
end

check("E-08: dotted punning is a parse error (Rust: 'Expected name, got Dot')") do
  rep, = rust_compile(DOTTED, "dotted")
  rep["status"] != "ok" && rust_diag_messages(rep).any? { |m| m.include?("Expected name, got Dot") }
end

check("E-09: string-key punning stays closed (parse error, Ruby)") do
  !ruby_parse(STRING_KEY)["parse_errors"].empty?
end

check("E-10: spread + punning fails CLOSED in Ruby (canon has no record spread — parse diagnostic, no silent AST)") do
  parsed = ruby_parse(SPREAD_PUN)
  !parsed["parse_errors"].empty?
end

section("F  Unregressed — explicit records unchanged")

check("F-01: explicit fixture still compiles ok (Ruby)") do
  ruby_compile(EXPLICIT, "exp_reg")[0]["status"] == "ok"
end

check("F-02: explicit fixture still compiles ok (Rust)") do
  rust_compile(EXPLICIT, "exp_reg")[0]["status"] == "ok"
end

# ════════════════════════════════════════════════════════════════════════════
puts "\n#{$pass + $fail} checks: #{$pass} PASS, #{$fail} FAIL"
exit($fail.zero? ? 0 : 1)
