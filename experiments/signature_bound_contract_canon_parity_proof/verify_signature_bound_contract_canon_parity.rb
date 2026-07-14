#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_signature_bound_contract_canon_parity.rb
# LANG-SIGNATURE-BOUND-CONTRACT-CANON-PARITY-P1 — signature-bound pure contracts as
# dual-toolchain parser sugar.
#
# Rust/lab landed the compact signature surface (LAB-LANG-SIGNATURE-BOUND-CONTRACT-
# SURFACE-P2, parser-only, AST/SIR-identical to the explicit form):
#
#   pure contract Name(a: X, b: Y) -> (out: Z) {
#     out = expr
#   }
#
# This proof asserts the Ruby/canon mirror:
#
#   * the signature form desugars at parse time into the existing explicit
#     `input` / `compute` / `output` declarations — no new AST/SIR node, no second
#     semantic path;
#   * signature == explicit is BYTE-IDENTICAL at the parsed-body AST level AND at the
#     SemanticIR `contracts` level in BOTH toolchains; the only SIR fields that differ
#     are the four text/path-anchored envelope fields (program_id, source_hash,
#     source_path, compilation_report_ref) — documented, expected;
#   * cross-toolchain (Ruby vs Rust) the signature fixture's contract SIR is
#     equivalent after dropping the known decoration axes (resolved_type / modifier /
#     literal_type — conformance-runner volatile keys — plus the lab-only node_id /
#     capabilities / effects / contract_ref envelope decorations);
#   * VM-visible values are identical across all four artifacts
#     (Ruby/Rust x signature/explicit);
#   * missing output binding → OOF-P1 "signature output `z` is not defined in the
#     contract body" — SAME message dual;
#   * duplicate body binding → OOF-P1 "duplicate body binding `t` in signature
#     contract" — SAME message dual;
#   * unsupported placement (keyword decl such as `input` inside a signature body) →
#     OOF-P1 "Expected assign/Assign, got ident/Ident(q)" (same message modulo the
#     known token-name casing axis) + the same follow-on missing-output error dual;
#   * malformed signature (missing `->`) fails CLOSED in both toolchains (Ruby names
#     the arrow: "Expected arrow, got lparen(("; Rust resyncs at top level with
#     OOF-G1 — same fail-closed class, delta documented);
#   * a multi-output signature desugars into multiple `output` decls and hits the
#     one-output law OOF-RET1 with the IDENTICAL message dual (the law stays
#     authoritative; this surface does not reopen multiple runtime returns);
#   * explicit canonical contracts are unregressed, and the Gap-I form-invocation
#     expression (canon-only surface) still parses in explicit compute decls — the
#     suppress guard is scoped to signature bodies only.

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
  dir = Dir.mktmpdir("sbc_rb_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out.igapp")
  orch = IgniterLang.compile(source_path: path, out_path: out)
  [orch, out]
end

def ruby_diags(orch)
  Array(orch.dig("compilation_report", "diagnostics"))
end

# ── Rust helpers (require the sibling release binaries) ─────────────────────

def rust_compile(src, tag)
  dir = Dir.mktmpdir("sbc_rs_#{tag}_")
  path = File.join(dir, "m.ig")
  File.write(path, src)
  out = File.join(dir, "out")
  # LANG=en_US.UTF-8: the Rust binaries emit UTF-8; without it Open3 captures
  # US-ASCII and JSON.parse raises Encoding::InvalidByteSequenceError.
  stdout, = Open3.capture3({ "LANG" => "en_US.UTF-8" }, RUST_BIN.to_s, "compile", path, "--out", out)
  [JSON.parse(stdout.force_encoding("UTF-8")), out]
end

def rust_diags(report)
  Array(report["diagnostics"])
end

def rust_sir(out_dir)
  JSON.parse(File.read(File.join(out_dir, "semantic_ir_program.json")))
end

def vm_run(artifact, inputs)
  dir = Dir.mktmpdir("sbc_vm_")
  inp = File.join(dir, "inputs.json")
  File.write(inp, JSON.generate(inputs))
  stdout, = Open3.capture3({ "LANG" => "en_US.UTF-8" }, VM_BIN.to_s, "run", "--contract", artifact.to_s, "--inputs", inp, "--json")
  JSON.parse(stdout.force_encoding("UTF-8"))
end

# ── SIR normalization ───────────────────────────────────────────────────────

# The ONLY SemanticIR fields allowed to differ between the signature form and the
# explicit form (both toolchains): text/path-anchored envelope fields. Everything
# else — in particular the whole `contracts` subtree — must be byte-identical.
SIG_VS_EXPLICIT_ENVELOPE = %w[program_id source_hash source_path compilation_report_ref].freeze

# Decoration keys one toolchain adds and the other doesn't — dropped ONLY for the
# cross-toolchain comparison (same axis as the conformance runner's VOLATILE_KEYS):
#   resolved_type/modifier/literal_type — Ruby-side type decorations;
#   node_id/capabilities/effects — lab SIR envelope decorations Ruby doesn't emit;
#   contract_ref — text-anchored hash (differs by design, semantic_hash side-note).
CROSS_TOOLCHAIN_VOLATILE = %w[
  resolved_type modifier literal_type fragment fragment_class
  node_id capabilities effects contract_ref
].freeze

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

# sig-vs-explicit intra-toolchain: top-level keys must be identical except the
# documented envelope fields, and every non-envelope value byte-identical.
def sir_identical_modulo_envelope(a, b)
  return false unless a.is_a?(Hash) && b.is_a?(Hash) && a.keys == b.keys
  a.keys.all? do |k|
    SIG_VS_EXPLICIT_ENVELOPE.include?(k) || JSON.generate(a[k]) == JSON.generate(b[k])
  end
end

# ── Fixtures ────────────────────────────────────────────────────────────────

SIG_SINGLE = <<~IG
  module T
  type WV { account_id: String  title: String }
  pure contract MakeWV(account_id: String, title: String) -> (v: WV) {
    v = { account_id, title }
  }
IG

EXP_SINGLE = <<~IG
  module T
  type WV { account_id: String  title: String }
  pure contract MakeWV {
    input account_id : String
    input title : String
    compute v : WV = { account_id, title }
    output v : WV
  }
IG

# multi-input, intermediate typed binding, output binding omitting its type
# (inherits the signature output type — the P2 type rule).
SIG_MULTI = <<~IG
  module T
  pure contract Total(a: Integer, b: Integer, c: Integer) -> (total: Integer) {
    partial : Integer = a + b
    total = partial + c
  }
IG

EXP_MULTI = <<~IG
  module T
  pure contract Total {
    input a : Integer
    input b : Integer
    input c : Integer
    compute partial : Integer = a + b
    compute total : Integer = partial + c
    output total : Integer
  }
IG

MISSING_OUTPUT = <<~IG
  module T
  pure contract Bad(x: Int) -> (y: Int, z: Int) {
    y = x
  }
IG

DUPLICATE_BINDING = <<~IG
  module T
  pure contract Dup(x: Int) -> (y: Int) {
    t : Int = x
    t : Int = x
    y = t
  }
IG

KEYWORD_PLACEMENT = <<~IG
  module T
  pure contract P(x: Int) -> (y: Int) {
    input q : Int
    y = x
  }
IG

MALFORMED_SIGNATURE = <<~IG
  module T
  pure contract M(x: Int) (y: Int) {
    y = x
  }
IG

TWO_OUTPUT_SIG = <<~IG
  module T
  pure contract Build(a: Int) -> (x: Int, y: Int) {
    x = a
    y = a
  }
IG

# Gap-I form invocation in an explicit compute — canon-only expression surface;
# must stay parseable (the suppress guard is signature-body scoped).
FORM_INVOCATION_EXPLICIT = <<~IG
  module T
  pure contract F {
    input x : Int
    compute v = panel title = "t" { x }
    output v : Int
  }
IG

INPUTS_SINGLE = { "account_id" => "a1", "title" => "t1" }.freeze

# ════════════════════════════════════════════════════════════════════════════
abort("Rust compiler release binary missing: #{RUST_BIN}") unless RUST_BIN.exist?
abort("igniter-vm release binary missing: #{VM_BIN}") unless VM_BIN.exist?

section("A  Ruby parser — signature form desugars to the canonical explicit AST")

check("A-01: signature form parses with ZERO parse errors") do
  ruby_parse(SIG_SINGLE)["parse_errors"].empty?
end

check("A-02: signature contract AST == explicit contract AST (byte-identical)") do
  sig = ruby_parse(SIG_SINGLE)["contracts"][0]
  exp = ruby_parse(EXP_SINGLE)["contracts"][0]
  JSON.generate(sig) == JSON.generate(exp) &&
    sig["body"].map { |n| n["kind"] } == %w[input input compute output]
end

check("A-03: multi-input + intermediate + inherited output type == explicit AST") do
  sig = ruby_parse(SIG_MULTI)
  exp = ruby_parse(EXP_MULTI)
  sig["parse_errors"].empty? &&
    JSON.generate(sig["contracts"]) == JSON.generate(exp["contracts"])
end

check("A-04: output binding inherited the signature output type (compute total : Integer)") do
  body = ruby_parse(SIG_MULTI)["contracts"][0]["body"]
  total = body.find { |n| n["kind"] == "compute" && n["name"] == "total" }
  total && total["type_annotation"] == "Integer"
end

section("B  Ruby compile — signature form is typecheck-clean; SIR identical to explicit")

check("B-01: signature fixture compiles ok (Ruby)") do
  ruby_compile(SIG_SINGLE, "sig")[0]["status"] == "ok"
end

check("B-02: Ruby SIR: signature == explicit byte-identical modulo the 4 envelope fields") do
  sig_sir = ruby_compile(SIG_SINGLE, "sig_sir")[0]["semantic_ir"]
  exp_sir = ruby_compile(EXP_SINGLE, "exp_sir")[0]["semantic_ir"]
  sir_identical_modulo_envelope(sig_sir, exp_sir) &&
    JSON.generate(sig_sir["contracts"]) == JSON.generate(exp_sir["contracts"])
end

check("B-03: Ruby SIR: multi-input fixture signature == explicit (contracts byte-identical)") do
  sig_sir = ruby_compile(SIG_MULTI, "sigm_sir")[0]["semantic_ir"]
  exp_sir = ruby_compile(EXP_MULTI, "expm_sir")[0]["semantic_ir"]
  sir_identical_modulo_envelope(sig_sir, exp_sir) &&
    JSON.generate(sig_sir["contracts"]) == JSON.generate(exp_sir["contracts"])
end

section("C  Rust regression — signature surface unchanged; SIR identity holds")

check("C-01: signature fixture compiles ok with ZERO diagnostics (Rust)") do
  rep, = rust_compile(SIG_SINGLE, "sig")
  rep["status"] == "ok" && rust_diags(rep).empty?
end

check("C-02: Rust SIR: signature == explicit byte-identical modulo the 4 envelope fields") do
  _, sig_dir = rust_compile(SIG_SINGLE, "sig_sir")
  _, exp_dir = rust_compile(EXP_SINGLE, "exp_sir")
  sig_sir = rust_sir(sig_dir)
  exp_sir = rust_sir(exp_dir)
  sir_identical_modulo_envelope(sig_sir, exp_sir) &&
    JSON.generate(sig_sir["contracts"]) == JSON.generate(exp_sir["contracts"])
end

check("C-03: Rust SIR: multi-input fixture signature == explicit (contracts byte-identical)") do
  _, sig_dir = rust_compile(SIG_MULTI, "sigm_sir")
  _, exp_dir = rust_compile(EXP_MULTI, "expm_sir")
  JSON.generate(rust_sir(sig_dir)["contracts"]) == JSON.generate(rust_sir(exp_dir)["contracts"])
end

section("D  Cross-toolchain — Ruby vs Rust contract SIR equivalence + VM values")

check("D-01: signature contract SIR equivalent Ruby vs Rust (decoration axes dropped)") do
  rb_sir = ruby_compile(SIG_SINGLE, "x_rb")[0]["semantic_ir"]
  _, rs_dir = rust_compile(SIG_SINGLE, "x_rs")
  rb_c = strip_volatile(rb_sir["contracts"])
  rs_c = strip_volatile(rust_sir(rs_dir)["contracts"])
  !rb_c.empty? && sorted_json(rb_c) == sorted_json(rs_c)
end

check("D-02: VM-visible values identical across Ruby/Rust x signature/explicit (4 artifacts)") do
  _, rb_sig = ruby_compile(SIG_SINGLE, "vm_rb_sig")
  _, rb_exp = ruby_compile(EXP_SINGLE, "vm_rb_exp")
  _, rs_sig = rust_compile(SIG_SINGLE, "vm_rs_sig")
  _, rs_exp = rust_compile(EXP_SINGLE, "vm_rs_exp")
  results = [rb_sig, rb_exp, rs_sig, rs_exp].map { |a| vm_run(a, INPUTS_SINGLE) }
  expected = { "account_id" => "a1", "title" => "t1" }
  results.all? { |r| r["status"] == "success" } &&
    results.map { |r| r["result"] }.uniq == [expected]
end

section("E  Diagnostics — aligned dual-toolchain, existing root paths")

check("E-01: missing output binding → OOF-P1 exact message (Ruby)") do
  errs = ruby_parse(MISSING_OUTPUT)["parse_errors"]
  errs.any? { |e| e["rule"] == "OOF-P1" && e["message"] == "signature output `z` is not defined in the contract body" }
end

check("E-02: missing output binding → OOF-P1 exact message (Rust)") do
  rep, = rust_compile(MISSING_OUTPUT, "missing")
  rep["status"] != "ok" &&
    rust_diags(rep).any? { |d| d["rule"] == "OOF-P1" && d["message"] == "signature output `z` is not defined in the contract body" }
end

check("E-03: duplicate body binding → OOF-P1 exact message (Ruby)") do
  errs = ruby_parse(DUPLICATE_BINDING)["parse_errors"]
  errs.any? { |e| e["rule"] == "OOF-P1" && e["message"] == "duplicate body binding `t` in signature contract" }
end

check("E-04: duplicate body binding → OOF-P1 exact message (Rust)") do
  rep, = rust_compile(DUPLICATE_BINDING, "dup")
  rep["status"] != "ok" &&
    rust_diags(rep).any? { |d| d["rule"] == "OOF-P1" && d["message"] == "duplicate body binding `t` in signature contract" }
end

check("E-05: keyword decl in signature body → OOF-P1 'Expected assign, got ident(q)' + missing output (Ruby)") do
  errs = ruby_parse(KEYWORD_PLACEMENT)["parse_errors"]
  errs.any? { |e| e["rule"] == "OOF-P1" && e["message"].include?("Expected assign, got ident(q)") } &&
    errs.any? { |e| e["message"] == "signature output `y` is not defined in the contract body" }
end

check("E-06: keyword decl in signature body → OOF-P1 'Expected Assign, got Ident(q)' + missing output (Rust)") do
  rep, = rust_compile(KEYWORD_PLACEMENT, "placement")
  msgs = rust_diags(rep).map { |d| d["message"].to_s }
  rep["status"] != "ok" &&
    msgs.any? { |m| m.include?("Expected Assign, got Ident(q)") } &&
    msgs.any? { |m| m == "signature output `y` is not defined in the contract body" }
end

check("E-07: malformed signature (missing ->) fails CLOSED, arrow named (Ruby)") do
  errs = ruby_parse(MALFORMED_SIGNATURE)["parse_errors"]
  errs.any? { |e| e["message"].to_s.include?("Expected arrow, got lparen") }
end

check("E-08: malformed signature (missing ->) fails CLOSED (Rust, top-level resync)") do
  rep, = rust_compile(MALFORMED_SIGNATURE, "malformed")
  rep["status"] != "ok" && !rust_diags(rep).empty?
end

check("E-09: multi-output signature hits the one-output law OOF-RET1 (Ruby)") do
  orch, = ruby_compile(TWO_OUTPUT_SIG, "twoout")
  orch["status"] != "ok" &&
    ruby_diags(orch).any? { |d| d["rule"] == "OOF-RET1" && d["message"].include?("declares 2 outputs; a contract returns exactly one value") }
end

check("E-10: multi-output signature hits the one-output law OOF-RET1, SAME message (Rust)") do
  rep, = rust_compile(TWO_OUTPUT_SIG, "twoout")
  rb_msg = ruby_diags(ruby_compile(TWO_OUTPUT_SIG, "twoout_rb")[0]).find { |d| d["rule"] == "OOF-RET1" }&.fetch("message")
  rs_msg = rust_diags(rep).find { |d| d["rule"] == "OOF-RET1" }&.fetch("message")
  rep["status"] != "ok" && !rs_msg.nil? && rs_msg == rb_msg
end

section("F  Unregressed — explicit canonical contracts and canon-only surfaces")

check("F-01: explicit fixture still compiles ok (Ruby)") do
  ruby_compile(EXP_SINGLE, "exp_reg")[0]["status"] == "ok"
end

check("F-02: explicit fixture still compiles ok (Rust)") do
  rust_compile(EXP_SINGLE, "exp_reg")[0]["status"] == "ok"
end

check("F-03: Gap-I form invocation still parses in explicit compute (guard is signature-scoped)") do
  parsed = ruby_parse(FORM_INVOCATION_EXPLICIT)
  compute = parsed["contracts"][0]["body"].find { |n| n["kind"] == "compute" }
  parsed["parse_errors"].empty? && compute.dig("expr", "kind") == "form_invocation"
end

# ════════════════════════════════════════════════════════════════════════════
puts "\n#{$pass + $fail} checks: #{$pass} PASS, #{$fail} FAIL"
exit($fail.zero? ? 0 : 1)
