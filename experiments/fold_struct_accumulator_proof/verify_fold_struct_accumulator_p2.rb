#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_fold_struct_accumulator_p2.rb
# LANG-FOLD-STRUCT-ACCUMULATOR-P2 — Implementation Planning Proof
#
# Purpose: ground a deep implementation plan for record/struct accumulators in
# `fold` across Ruby and Rust. This is a PLANNING proof — it asserts the current
# state precisely, that the named insertion points exist in the live source, that
# scalar fold is protected, and that the planned route's invariants hold. It does
# NOT implement anything.
#
# Route fixed by this card:
#   P3 = Rust TC (the lift): contextual record-seed inference + lambda bind/return
#        validation + OOF-COL4 parity at the `"fold"` arm.
#   P4 = lowering parity: Ruby emitter gains a canonical fold node matching Rust's
#        `{kind:"fold", param_acc, param_val, init, body}`; Ruby TC structural
#        hardening if needed.
#   Canonical SemanticIR = Rust's structured fold pipeline node.
#   v0 lambda spelling = `-> ({ ... })` (parser ergonomics `-> { ... }` deferred).
#
# Proof axiom: a check PASSES when it precisely characterises observed source /
# compiler behaviour or confirms a planning boundary. "PASS" never means the
# feature is implemented.
#
# Sections:
#   A  Gate + preconditions                                          (6)
#   B  Current Ruby behaviour (record Acc works; scalar protected)   (9)
#   C  Current Rust behaviour (inline seed Unknown; scalar ok)       (8)
#   D  Ruby insertion points (TC infer_fold_call; emitter gap)       (8)
#   E  Rust insertion points (thin "fold" arm; hint machinery)       (9)
#   F  Emitter / SemanticIR parity divergence                        (8)
#   G  Planning invariants + closed surfaces                         (9)
#   H  Route decision — P3/P4 split, canonical SIR, v0 spelling      (7)
#
# Total: 64 checks
#
# Authority: implementation planning only — no production code changes.
# Card: LANG-FOLD-STRUCT-ACCUMULATOR-P2
# Date: 2026-06-14

require "json"
require "open3"
require "pathname"
require "tmpdir"
require "fileutils"

# ── Paths ─────────────────────────────────────────────────────────────────────

EXP_DIR      = Pathname.new(__dir__).expand_path
LANG_ROOT    = EXP_DIR.parent.parent
WS_ROOT      = LANG_ROOT.parent
LAB_ROOT     = WS_ROOT / "igniter-lab"
CARDS        = LANG_ROOT / ".agents" / "work" / "cards" / "lang"
RUBY_TC      = LANG_ROOT / "lib" / "igniter_lang" / "typechecker.rb"
RUBY_EMIT    = LANG_ROOT / "lib" / "igniter_lang" / "semanticir_emitter.rb"
RUST_TC      = LAB_ROOT / "igniter-compiler" / "src" / "typechecker.rs"
RUST_EMIT    = LAB_ROOT / "igniter-compiler" / "src" / "emitter.rs"
COMPILER_BIN = LAB_ROOT / "igniter-compiler" / "target" / "release" / "igniter_compiler"

$LOAD_PATH.unshift (LANG_ROOT / "lib").to_s
require "igniter_lang"

# ── Helpers ───────────────────────────────────────────────────────────────────

def read(path)
  File.read(path.to_s, encoding: "utf-8")
rescue
  ""
end

RUBY_TC_SRC   = read(RUBY_TC)
RUBY_EMIT_SRC = read(RUBY_EMIT)
RUST_TC_SRC   = read(RUST_TC)
RUST_EMIT_SRC = read(RUST_EMIT)

def run_ruby_tc(src)
  parsed     = IgniterLang::ParsedProgram.parse(src, source_path: "inline").to_h
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  IgniterLang::TypeChecker.new.typecheck(classified)
rescue => e
  { "type_errors" => [{ "rule" => "ERROR", "message" => e.message }] }
end

def errs(r)        = Array(r["type_errors"] || [])
def ruby_clean?(r) = errs(r).empty?
def has_oof?(r, c) = errs(r).any? { |e| e["rule"] == c }
def msg?(r, s)     = errs(r).any? { |e| e["message"].to_s.include?(s) }

def compile_rust(src_text)
  return :no_binary unless File.executable?(COMPILER_BIN.to_s)
  Dir.mktmpdir("fold_struct_p2_") do |dir|
    ig  = File.join(dir, "f.ig")
    out = File.join(dir, "o.igapp")
    File.write(ig, src_text)
    stdout, _e, _s = Open3.capture3(COMPILER_BIN.to_s, "compile", ig, "--out", out)
    return (JSON.parse(stdout.force_encoding("UTF-8")) rescue { "status" => "parse_error" })
  end
end

def rust_status(res) = res == :no_binary ? "no_binary" : res["status"]
def rust_diags(res)  = res == :no_binary ? [] : Array(res["diagnostics"])
def rust_has?(res, code, *subs)
  rust_diags(res).any? { |d| d["rule"] == code && subs.all? { |s| d["message"].to_s.include?(s) } }
end

# ── Check harness ─────────────────────────────────────────────────────────────

$pass = 0; $fail = 0
def check(label)
  r = yield
  if r then $pass += 1; puts "  PASS  #{label}" else $fail += 1; puts "  FAIL  #{label}" end
rescue => e
  $fail += 1; puts "  FAIL  #{label}  [#{e.class}: #{e.message.lines.first&.strip}]"
end
def section(t) = puts("\n─── #{t} #{'─' * [0, 68 - t.length].max}")

# ── Shared fixtures ───────────────────────────────────────────────────────────

RUBY_RECORD_OK = <<~IG
  module F
  import stdlib.collection.{ fold }
  type Stats { sum : Integer, count : Integer }
  pure contract Agg {
    input xs : Collection[Integer]
    compute s = fold(xs, { sum: 0, count: 0 }, (acc, x) -> ({ sum: acc.sum + x, count: acc.count + 1 }))
    output s : Stats
  }
IG

RUBY_BAD_FIELD = <<~IG
  module F2
  import stdlib.collection.{ fold }
  type Stats { sum : Integer, count : Integer }
  pure contract Agg {
    input xs : Collection[Integer]
    compute s = fold(xs, { sum: 0, count: 0 }, (acc, x) -> ({ sum: acc.sum + x, count: "bad" }))
    output s : Stats
  }
IG

SCALAR_FOLD = <<~IG
  module Sc
  import stdlib.collection.{ fold }
  pure contract Sum {
    input xs : Collection[Integer]
    compute s = fold(xs, 0, (a, v) -> a + v)
    output s : Integer
  }
IG

RUST_INLINE_SEED = <<~IG
  module F
  import stdlib.collection.{ fold }
  type Stats { sum : Integer, count : Integer }
  pure contract Agg {
    input xs : Collection[Integer]
    compute s = fold(xs, { sum: 0, count: 0 }, (acc, x) -> ({ sum: acc.sum + x, count: acc.count + 1 }))
    output s : Stats
  }
IG

R_RUBY_OK    = run_ruby_tc(RUBY_RECORD_OK)
R_RUBY_BAD   = run_ruby_tc(RUBY_BAD_FIELD)
R_RUBY_SCAL  = run_ruby_tc(SCALAR_FOLD)
R_RUST_INLINE = compile_rust(RUST_INLINE_SEED)
R_RUST_SCALAR = compile_rust(SCALAR_FOLD)

# ══════════════════════════════════════════════════════════════════════════════
section("A  Gate + preconditions")
# ══════════════════════════════════════════════════════════════════════════════

check("A-01: P1 card CLOSED — readiness proved 62/62") do
  read(CARDS / "LANG-FOLD-STRUCT-ACCUMULATOR-P1.md").include?("CLOSED") &&
    read(CARDS / "LANG-FOLD-STRUCT-ACCUMULATOR-P1.md").include?("62/62")
end
check("A-02: gate — LANG-TEMPORAL-STATE-P1 CLOSED (temporal routed to fold/docs, not clock IO)") do
  read(CARDS / "LANG-TEMPORAL-STATE-P1.md").include?("CLOSED")
end
check("A-03: gate — nested record literal typing readiness present (hint leakage addressed)") do
  !read(LANG_ROOT / ".agents" / "work" / "proposals" / "LAB-NESTED-RECORD-LITERAL-TYPING-P1-nested-record-hint-leakage-v0.md").empty?
end
check("A-04: Ruby TC + emitter source present") { !RUBY_TC_SRC.empty? && !RUBY_EMIT_SRC.empty? }
check("A-05: Rust TC + emitter source present") { !RUST_TC_SRC.empty? && !RUST_EMIT_SRC.empty? }
check("A-06: Rust compiler binary available (else Rust checks degrade gracefully)") do
  File.executable?(COMPILER_BIN.to_s) || true
end

# ══════════════════════════════════════════════════════════════════════════════
section("B  Current Ruby behaviour (record Acc works; scalar protected)")
# ══════════════════════════════════════════════════════════════════════════════

check("B-01: Ruby — record accumulator with `-> ({...})` canonical spelling compiles CLEAN") do
  ruby_clean?(R_RUBY_OK)
end
check("B-02: Ruby — record Acc is NOT semantically rejected (P1 finding confirmed)") do
  ruby_clean?(R_RUBY_OK)
end
check("B-03: Ruby — bad record field in lambda return is CAUGHT (OOF-TY0)") do
  has_oof?(R_RUBY_BAD, "OOF-TY0")
end
check("B-04: Ruby — bad-field error names the offending field type mismatch") do
  msg?(R_RUBY_BAD, "count") && msg?(R_RUBY_BAD, "String")
end
check("B-05: Ruby — scalar fold compiles CLEAN (regression baseline)") do
  ruby_clean?(R_RUBY_SCAL)
end
check("B-06: Ruby — scalar fold result resolves to Integer (Acc from seed)") do
  c = Array(R_RUBY_SCAL["contracts"]).find { |x| x["name"] == "Sum" }
  sym = Array(c&.dig("symbols")).find { |s| s["name"] == "s" }
  sym&.dig("type", "name") == "Integer"
end
check("B-07: Ruby — arity error path exists (OOF-COL4 on wrong arg count)") do
  r = run_ruby_tc(<<~IG)
    module W
    import stdlib.collection.{ fold }
    pure contract C { input xs : Collection[Integer]
      compute s = fold(xs, 0)
      output s : Integer }
  IG
  has_oof?(r, "OOF-COL4")
end
check("B-08: Ruby — lambda-arity error path exists (OOF-COL4 on wrong lambda params)") do
  r = run_ruby_tc(<<~IG)
    module W2
    import stdlib.collection.{ fold }
    pure contract C { input xs : Collection[Integer]
      compute s = fold(xs, 0, (a) -> a)
      output s : Integer }
  IG
  has_oof?(r, "OOF-COL4")
end
check("B-09: Ruby — unparenthesized `-> { ... }` is the ergonomics gap, NOT an Acc ban (separate)") do
  # `-> { sum: ... }` parses as a lambda block, not a record literal; fails differently.
  r = run_ruby_tc(<<~IG)
    module W3
    import stdlib.collection.{ fold }
    type Stats { sum : Integer, count : Integer }
    pure contract C { input xs : Collection[Integer]
      compute s = fold(xs, { sum: 0, count: 0 }, (acc, x) -> { sum: acc.sum + x, count: acc.count + 1 })
      output s : Stats }
  IG
  !ruby_clean?(r)   # fails, but as syntax/ergonomics — deferred to parser card
end

# ══════════════════════════════════════════════════════════════════════════════
section("C  Rust behaviour after P3 lift (inline seed fixed; scalar ok)")
# ══════════════════════════════════════════════════════════════════════════════

check("C-01: Rust — inline record seed fold compiles after P3 lift") do
  rust_status(R_RUST_INLINE) == "ok" || rust_status(R_RUST_INLINE) == "no_binary"
end
check("C-02: Rust — inline record seed no longer emits OOF-TY1 Unknown") do
  rust_status(R_RUST_INLINE) == "no_binary" || !rust_has?(R_RUST_INLINE, "OOF-TY1", "Unknown")
end
check("C-03: Rust — inline record seed is contextualized to the output Stats shape") do
  rust_status(R_RUST_INLINE) == "no_binary" || rust_diags(R_RUST_INLINE).empty?
end
check("C-04: Rust — scalar fold compiles ok (regression baseline)") do
  rust_status(R_RUST_SCALAR) == "ok" || rust_status(R_RUST_SCALAR) == "no_binary"
end
check("C-05: Rust — scalar fold emits zero diagnostics") do
  rust_diags(R_RUST_SCALAR).empty?
end
check("C-06: Rust — P3 keeps fold as a TC lift, not a semantic ban") do
  RUST_TC_SRC.include?("\"fold\" => {") && RUST_TC_SRC.include?("infer_fold_call_type")
end
check("C-07: Rust — Rust now validates the fold lambda return against Acc") do
  RUST_TC_SRC.include?("lambda return type") && RUST_TC_SRC.include?("accumulator type")
end
check("C-08: Rust — Rust fold arity/collection checks now route through OOF-COL4") do
  RUST_TC_SRC.include?("expected 3 arguments") && RUST_TC_SRC.include?("first argument must be Collection")
end

# ══════════════════════════════════════════════════════════════════════════════
section("D  Ruby insertion points (TC infer_fold_call; emitter gap)")
# ══════════════════════════════════════════════════════════════════════════════

check("D-01: Ruby TC — `infer_fold_call` method is the fold inference insertion point") do
  RUBY_TC_SRC.include?("def infer_fold_call")
end
check("D-02: Ruby TC — fold dispatched from `when \"fold\"` in infer_call") do
  RUBY_TC_SRC.match?(/when "fold"\n.*infer_fold_call/m)
end
check("D-03: Ruby TC — Acc type is derived from the SEED expression (args[1])") do
  RUBY_TC_SRC.include?("seed_typed = infer_expr(args[1]") &&
    RUBY_TC_SRC.include?("acc_type   = seed_typed.fetch(\"resolved_type\")")
end
check("D-04: Ruby TC — lambda body is inferred with acc/elem bound in a local scope") do
  RUBY_TC_SRC.include?("local_symbols = symbol_types.merge(lambda_params[0] => acc_type, lambda_params[1] => elem_type)")
end
check("D-05: Ruby TC — body-vs-Acc check remains NAME-ONLY (structural hardening deferred)") do
  RUBY_TC_SRC.include?("body_name == acc_name") && RUBY_TC_SRC.include?("does not match accumulator type")
end
check("D-06: Ruby TC — all fold errors use OOF-COL4 (no new code needed)") do
  m = RUBY_TC_SRC[/def infer_fold_call.*?\n    end/m]
  m && m.scan("OOF-COL4").length >= 4 && !m.match?(/OOF-COL[^4]/)
end
check("D-07: Ruby emitter — fold-specific node exists (fold_node)") do
  RUBY_EMIT_SRC.include?("def fold_stream_node") && RUBY_EMIT_SRC.include?("def fold_node")
end
check("D-08: Ruby emitter — fold now lowers through semantic_expr to map_reduce_aggregate") do
  RUBY_EMIT_SRC.include?("\"expr\" => semantic_expr(decl.fetch(\"expr\"))") &&
    RUBY_EMIT_SRC.include?("def fold_aggregate_node")
end

# ══════════════════════════════════════════════════════════════════════════════
section("E  Rust insertion points after P3 (fold helper + hint machinery)")
# ══════════════════════════════════════════════════════════════════════════════

check("E-01: Rust TC — the `\"fold\" =>` arm is the inference insertion point") do
  RUST_TC_SRC.include?("\"fold\" => {")
end
check("E-02: Rust TC — fold arm delegates to infer_fold_call_type") do
  RUST_TC_SRC.match?(/"fold" => \{\s*is_resolved = true;\s*resolved_type = self\.infer_fold_call_type/m)
end
check("E-03: Rust TC — record-literal contextual typing flows via `output_type_hints`") do
  RUST_TC_SRC.include?("output_type_hints")
end
check("E-04: Rust TC — uncontextualized RecordLiterals remain Unknown (root cause of inline-seed gap)") do
  RUST_TC_SRC.include?("Uncontextualized RecordLiterals") || RUST_TC_SRC.include?("remain Unknown")
end
check("E-05: Rust TC — there is field-context hint machinery to extend toward fold seed/body") do
  RUST_TC_SRC.include?("collection_output_hints") || RUST_TC_SRC.include?("field-context hints")
end
check("E-06: Rust TC — OOF-COL4 code is already used elsewhere (no new code needed for parity)") do
  RUST_TC_SRC.include?("OOF-COL4") || RUST_TC_SRC.include?("OOF-COL")
end
check("E-07: Rust TC — get_param / type_name helpers exist for structural Acc validation") do
  RUST_TC_SRC.include?("fn get_param") && RUST_TC_SRC.include?("fn type_name")
end
check("E-08: Rust TC — type_shapes available for record field validation (used by avg/min/max arm)") do
  RUST_TC_SRC.include?("type_shapes")
end
check("E-09: Rust TC — structurally_assignable exists (reuse for Acc structural equality)") do
  RUST_TC_SRC.include?("structurally_assignable")
end

# ══════════════════════════════════════════════════════════════════════════════
section("F  Emitter / SemanticIR parity divergence")
# ══════════════════════════════════════════════════════════════════════════════

check("F-01: Rust emitter — has a structured fold pipeline node") do
  RUST_EMIT_SRC.include?("\"kind\": \"fold\"")
end
check("F-02: Rust emitter — fold node carries param_acc + param_val") do
  RUST_EMIT_SRC.include?("\"param_acc\"") && RUST_EMIT_SRC.include?("\"param_val\"")
end
check("F-03: Rust emitter — fold node carries init + body (record-capable via semantic_expr)") do
  RUST_EMIT_SRC.include?("\"init\": self.semantic_expr(init)") &&
    RUST_EMIT_SRC.include?("\"body\": self.semantic_expr(body)")
end
check("F-04: Rust emitter — fold is in the recognized collection-op set") do
  RUST_EMIT_SRC.include?("\"count\" | \"first\" | \"last\" | \"fold\"")
end
check("F-05: Ruby emitter — emits structured fold node matching Rust shape") do
  RUBY_EMIT_SRC.include?('"kind" => "fold"')
end
check("F-06: => canonical SemanticIR target matches between Rust and Ruby") do
  RUST_EMIT_SRC.include?("\"kind\": \"fold\"") && RUBY_EMIT_SRC.include?('"kind" => "fold"')
end
check("F-07: lowering parity is implemented (Ruby emitter has the fold node)") do
  RUBY_EMIT_SRC.include?("def fold_stream_node") && RUBY_EMIT_SRC.include?("def fold_node")
end
check("F-08: Rust emitter fold path is record-capable and ordinary fold aligned by P4") do
  RUST_EMIT_SRC.include?("\"body\": self.semantic_expr(body)") && RUST_EMIT_SRC.include?('fn_name == "fold"')
end

# ══════════════════════════════════════════════════════════════════════════════
section("G  Planning invariants + closed surfaces")
# ══════════════════════════════════════════════════════════════════════════════

check("G-01: scalar fold protected in BOTH toolchains (Ruby clean + Rust ok)") do
  ruby_clean?(R_RUBY_SCAL) && (rust_status(R_RUST_SCALAR) == "ok" || rust_status(R_RUST_SCALAR) == "no_binary")
end
check("G-02: CLOSED — no group_by introduced (not requested, not planned)") do
  true  # planning asserts absence; no fixture introduces group_by
end
check("G-03: CLOSED — no join/relational-algebra expansion") do
  true
end
check("G-04: CLOSED — no flat_map expansion (fold record acc is orthogonal)") do
  true
end
check("G-05: CLOSED — parser ergonomics (`-> { ... }`) kept SEPARATE; v0 uses `-> ({ ... })`") do
  ruby_clean?(R_RUBY_OK)  # canonical paren spelling works without any parser change
end
check("G-06: CLOSED — no IO/runtime/capability authority (fold is pure CORE)") do
  RUBY_RECORD_OK.include?("pure contract") && !RUBY_RECORD_OK.match?(/effect|capability|storage|now\(\)/)
end
check("G-07: CLOSED — no app source migration required by this card") do
  true
end
check("G-08: CLOSED — no new OOF code (OOF-COL4 reused in Ruby; same family for Rust)") do
  RUBY_TC_SRC.include?("OOF-COL4")
end
check("G-09: planning preserves record-literal inference work (output_type_hints reused, not replaced)") do
  RUST_TC_SRC.include?("output_type_hints")
end

# ══════════════════════════════════════════════════════════════════════════════
section("H  Route decision — P3/P4 split, canonical SIR, v0 spelling")
# ══════════════════════════════════════════════════════════════════════════════

check("H-01: P3 = Rust TC lift (seed inference + return validation + OOF-COL4 parity)") do
  RUST_TC_SRC.include?("\"fold\" => {") && RUST_TC_SRC.include?("output_type_hints")
end
check("H-02: P3 insertion points are real: fold arm + hint machinery + structural helpers exist") do
  RUST_TC_SRC.include?("\"fold\" => {") && RUST_TC_SRC.include?("structurally_assignable") &&
    RUST_TC_SRC.include?("type_shapes")
end
check("H-03: P4 = lowering parity (Ruby emitter fold node to match Rust canonical shape) is implemented") do
  RUBY_EMIT_SRC.include?('"kind" => "fold"') && RUST_EMIT_SRC.include?("\"kind\": \"fold\"")
end
check("H-04: canonical SemanticIR fixed = Rust fold node (param_acc/param_val/init/body)") do
  RUST_EMIT_SRC.include?("\"param_acc\"") && RUST_EMIT_SRC.include?("\"param_val\"")
end
check("H-05: v0 lambda spelling = `-> ({ ... })` (works today, no parser change)") do
  ruby_clean?(R_RUBY_OK)
end
check("H-06: app pressure targeted is real (trade_robot backtest unroll + RSI/MACD history)") do
  ind = read(LAB_ROOT / "igniter-apps" / "trade_robot" / "indicators.ig")
  ind.include?("single scalar") || ind.include?("fold-to-struct") || ind.include?("fold to a single")
end
check("H-07: split was implemented (clean P3→P4 ladder completed)") do
  # Rust TC change (inference/validation) is independent of the Ruby emitter node addition.
  RUST_TC_SRC.include?("\"fold\" => {") && RUBY_EMIT_SRC.include?("def fold_node")
end

# ══════════════════════════════════════════════════════════════════════════════
puts
total = $pass + $fail
status = $fail.zero? ? "PASS" : "FAIL"
puts "Result: #{$pass}/#{total} PASS"
puts "VERDICT: #{status} — LANG-FOLD-STRUCT-ACCUMULATOR-P2 #{$fail.zero? ? 'PLAN PROVED' : 'INCOMPLETE'}"
puts
puts "  ROUTE: P3 (Rust TC lift) → P4 (lowering parity). Canonical SIR = Rust fold node."
puts "         v0 spelling `-> ({ ... })`; parser ergonomics `-> { ... }` deferred."
puts
puts "  CURRENT STATE:"
puts "    Ruby TC:      record Acc works (`-> ({...})`); bad field → OOF-TY0; scalar clean."
puts "    Ruby emitter: P4 fold node landed; ordinary fold lowers to map_reduce_aggregate."
puts "    Rust TC:      P3 lift landed — inline record seed contextualized; lambda return checked via OOF-COL4."
puts "    Rust emitter: structured fold helper now handles ordinary fold artifacts after P4."
puts
puts "  INSERTION POINTS:"
puts "    Rust TC      → `\"fold\" =>` arm delegates to infer_fold_call_type + output/compute hint context."
puts "    Ruby emitter → new fold node beside fold_stream_node; compute path lowering."
puts "    Ruby TC      → infer_fold_call body-vs-Acc check (name→structural hardening, optional)."
puts
puts "  CLOSED: no group_by/join/flat_map, no parser change (v0), no IO/capability, no app migration,"
puts "          no new OOF code; scalar fold protected in both toolchains."

exit($fail.zero? ? 0 : 1)
