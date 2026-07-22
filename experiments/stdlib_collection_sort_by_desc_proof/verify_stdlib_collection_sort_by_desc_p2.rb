#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_stdlib_collection_sort_by_desc_p2.rb
# LANG-STDLIB-COLLECTION-SORT-BY-DESC-P2
# ======================================
# Proves the canon Ruby TypeChecker admits `sort_by_desc` (ch8 §8.14, canon-accepted by
# LANG-STDLIB-COLLECTION-SORT-BY-DESC-PROP-P1) with:
#   - signature sort_by_desc(Collection[T], (T -> K)) -> Collection[T], element type UNCHANGED;
#   - BOTH the bare and the qualified source form dispatching to the SAME qualified identity
#     stdlib.collection.sort_by_desc (§8.14 Fixed Law 7 — note sort_by itself is bare-only);
#   - key lambda param bound to the collection's element type T;
#   - K restricted to exactly Integer, Text, or Decimal; every other key shape fails closed with
#     the REUSED diagnostic OOF-COL11 in the `sort_by_desc` spelling (no new code minted);
#   - the Float OOF-COL11 message routes to Decimal/Integer;
#   - reused OOF-COL1 (arity / non-lambda second arg) + OOF-COL2 (non-Collection first arg);
#   - empty/singleton contextual typing preserved;
#   - the §8.14.2 duplicate-key tie specimen (fixtures/tie_specimen.ig) ACCEPTED and lowered with
#     the correct shapes — NO runtime-order claim (that is P3 VM authority);
#   - `sort_by` behavior and diagnostic spelling byte-stable (dispatch arm, qualified name,
#     message text, and its bare-only match all untouched);
#   - NO regression to map/filter/at/take/count.
#
# Route: BOUNDED RUBY IMPLEMENTATION / PROOF
# Card:  igniter-lab/.agents/work/cards/lang/LANG-STDLIB-COLLECTION-SORT-BY-DESC-P2.md
# Canon: igniter-lang/docs/spec/ch8-stdlib.md §8.14
# Decision packet: igniter-lab/lab-docs/lang/lang-stdlib-collection-sort-by-desc-prop-p1-v0.md
#
# NOTE ON FIXTURE SHAPE: all fixtures use SINGLE-output contracts. The older sibling proofs
# (sort_by P3 §5.1, take P5 §6.1, at P3 §6.1) carry multi-output regression fixtures that now
# fail with OOF-RET1 under the single-output law (OOF-OUT1, 2026-07-13) — a pre-existing red
# baseline this card reproduces independently and must not extend.

require "fileutils"
require "json"
require "pathname"
require "tmpdir"

SCRIPT_DIR   = Pathname.new(__dir__)
IGNITER_LANG = SCRIPT_DIR.parent.parent
IGNITER_LIB  = IGNITER_LANG / "lib"
TC_RUBY      = IGNITER_LIB / "igniter_lang" / "typechecker.rb"
TIE_FIXTURE  = SCRIPT_DIR / "fixtures" / "tie_specimen.ig"

$LOAD_PATH.unshift(IGNITER_LIB.to_s) unless $LOAD_PATH.include?(IGNITER_LIB.to_s)
require "igniter_lang"

abort "Ruby TC not found: #{TC_RUBY}" unless TC_RUBY.exist?
abort "Tie fixture not found: #{TIE_FIXTURE}" unless TIE_FIXTURE.exist?

$pass = 0
$fail = 0

def check(label)
  ok = yield
  if ok
    $pass += 1
    puts "PASS #{label}"
  else
    $fail += 1
    puts "FAIL #{label}"
  end
rescue => e
  $fail += 1
  puts "FAIL #{label} [exception: #{e.message.lines.first&.strip}]"
end

def ruby_compile_source(src)
  c = IgniterLang::CompilerOrchestrator.new
  Dir.mktmpdir do |tmpdir|
    path = File.join(tmpdir, "inline.ig")
    File.write(path, src)
    out = File.join(tmpdir, "out.igapp")
    r = c.compile_sources(source_paths: [path], out_path: out)
    diags = r.dig("result", "diagnostics") || []
    igapp = r.dig("result", "igapp_path") || out
    sir_path = File.join(igapp, "semantic_ir_program.json")
    sir = File.exist?(sir_path) ? JSON.parse(File.read(sir_path, encoding: "UTF-8")) : {}
    {
      status:   r["status"] || "error",
      codes:    diags.map { |d| d["rule"].to_s },
      messages: diags.map { |d| d["message"].to_s },
      sir:      sir
    }
  end
end

def collect_sir_fns(node)
  return [] unless node.is_a?(Hash) || node.is_a?(Array)
  return node.flat_map { |v| collect_sir_fns(v) } if node.is_a?(Array)
  r = []
  r << node["fn"] if node["kind"] == "call" && node["fn"]
  node.each_value { |v| r.concat(collect_sir_fns(v)) }
  r
end

def collect_sir_calls(node, fn_name, acc = [])
  return acc unless node.is_a?(Hash) || node.is_a?(Array)
  if node.is_a?(Array)
    node.each { |v| collect_sir_calls(v, fn_name, acc) }
    return acc
  end
  acc << node if node["kind"] == "call" && node["fn"] == fn_name
  node.each_value { |v| collect_sir_calls(v, fn_name, acc) }
  acc
end

TC_SRC = TC_RUBY.read(encoding: "UTF-8")

# ── Fixtures (single-output; see NOTE ON FIXTURE SHAPE) ──────────────────────

INTEGER_KEY = <<~IG
  module SortByDescIntegerKey
  contract T {
    input xs : Collection[Integer]
    compute g = sort_by_desc(xs, x -> x)
    output g : Collection[Integer]
  }
IG

QUALIFIED_FORM = <<~IG
  module SortByDescQualified
  contract T {
    input xs : Collection[Integer]
    compute g = stdlib.collection.sort_by_desc(xs, x -> x)
    output g : Collection[Integer]
  }
IG

TEXT_KEY = <<~IG
  module SortByDescTextKey
  contract T {
    input xs : Collection[Text]
    compute g = sort_by_desc(xs, x -> x)
    output g : Collection[Text]
  }
IG

DECIMAL_KEY = <<~IG
  module SortByDescDecimalKey
  contract T {
    input xs : Collection[Decimal[2]]
    compute g = sort_by_desc(xs, x -> x)
    output g : Collection[Decimal[2]]
  }
IG

ELEMENT_TYPE_PRESERVED = <<~IG
  module SortByDescElementPreserved
  type Item {
    key : Integer,
    tag : Text
  }
  contract T {
    input xs : Collection[Item]
    compute g = sort_by_desc(xs, x -> x.key)
    output g : Collection[Item]
  }
IG

ELEMENT_TYPE_MISMATCH = <<~IG
  module SortByDescElementMismatch
  type Item {
    key : Integer,
    tag : Text
  }
  contract T {
    input xs : Collection[Item]
    compute g = sort_by_desc(xs, x -> x.key)
    output g : Collection[Integer]
  }
IG

EMPTY_CONTEXTUAL = <<~IG
  module SortByDescEmpty
  contract T {
    input n : Integer
    compute e : Collection[Integer] = []
    compute g = sort_by_desc(e, x -> x)
    output g : Collection[Integer]
  }
IG

SINGLETON = <<~IG
  module SortByDescSingleton
  contract T {
    input n : Integer
    compute s : Collection[Integer] = [42]
    compute g = sort_by_desc(s, x -> x)
    output g : Collection[Integer]
  }
IG

ARITY = <<~IG
  module SortByDescArity
  contract T {
    input xs : Collection[Integer]
    compute g = sort_by_desc(xs)
    output g : Collection[Integer]
  }
IG

NON_LAMBDA_SECOND = <<~IG
  module SortByDescNonLambda
  contract T {
    input xs : Collection[Integer]
    compute g = sort_by_desc(xs, 1)
    output g : Collection[Integer]
  }
IG

FIRST_ARG = <<~IG
  module SortByDescFirstArg
  contract T {
    input n : Integer
    compute g = sort_by_desc(n, x -> x)
    output g : Integer
  }
IG

FLOAT_KEY = <<~IG
  module SortByDescFloatKey
  contract T {
    input xs : Collection[Float]
    compute g = sort_by_desc(xs, x -> x)
    output g : Collection[Float]
  }
IG

FLOAT_KEY_QUALIFIED = <<~IG
  module SortByDescFloatKeyQualified
  contract T {
    input xs : Collection[Float]
    compute g = stdlib.collection.sort_by_desc(xs, x -> x)
    output g : Collection[Float]
  }
IG

BOOL_KEY = <<~IG
  module SortByDescBoolKey
  contract T {
    input xs : Collection[Integer]
    compute g = sort_by_desc(xs, x -> x > 0)
    output g : Collection[Integer]
  }
IG

RECORD_KEY = <<~IG
  module SortByDescRecordKey
  type Item {
    key : Integer,
    tag : Text
  }
  contract T {
    input xs : Collection[Item]
    compute g = sort_by_desc(xs, x -> x)
    output g : Collection[Item]
  }
IG

SORT_BY_BYTE_STABLE = <<~IG
  module SortByAscStillWorks
  contract T {
    input xs : Collection[Integer]
    compute g = sort_by(xs, x -> x)
    output g : Collection[Integer]
  }
IG

SORT_BY_FLOAT_SPELLING = <<~IG
  module SortByAscFloatSpelling
  contract T {
    input xs : Collection[Float]
    compute g = sort_by(xs, x -> x)
    output g : Collection[Float]
  }
IG

REGRESSION = <<~IG
  module SortByDescRegression
  type RegOut {
    a : Collection[Integer],
    b : Collection[Integer],
    c : Option[Integer],
    d : Integer,
    e : Collection[Integer]
  }
  contract T {
    input xs : Collection[Integer]
    compute a = map(xs, x -> x)
    compute b = filter(xs, x -> x > 0)
    compute c = at(xs, 0)
    compute d = count(xs)
    compute e = take(xs, 2)
    compute out : RegOut = { a: a, b: b, c: c, d: d, e: e }
    output out : RegOut
  }
IG

# ── 1. Source registration ───────────────────────────────────────────────────
check("1.1 dedicated dispatch arm routes bare AND qualified forms to infer_sort_by_desc_call") do
  TC_SRC.include?('when "sort_by_desc", "stdlib.collection.sort_by_desc"') &&
    TC_SRC.include?("infer_sort_by_desc_call")
end
check("1.2 dedicated method emits qualified identity stdlib.collection.sort_by_desc") do
  TC_SRC.include?("def infer_sort_by_desc_call") &&
    TC_SRC.scan('qualified = "stdlib.collection.sort_by_desc"').length == 1
end
check("1.3 sort_by_desc is NOT registered in the generic COLLECTION_HOF_FNS dict") do
  hof_block = TC_SRC[/COLLECTION_HOF_FNS = \{.*?\}\.freeze/m].to_s
  !hof_block.include?('"sort_by_desc"')
end
check("1.4 NOT an alias: infer_sort_by_desc_call does not delegate to infer_sort_by_call") do
  body = TC_SRC[/def infer_sort_by_desc_call.*?\n    end\n/m].to_s
  !body.empty? && !body.include?("infer_sort_by_call")
end

# ── 2. Hit: bare + qualified, three key types, qualified SIR ─────────────────
int_key = ruby_compile_source(INTEGER_KEY)
check("2.1 bare sort_by_desc(Collection[Integer], x -> x) compiles clean as Collection[Integer]") do
  int_key[:status] == "ok" && int_key[:codes].empty?
end
check("2.2 SIR emits stdlib.collection.sort_by_desc") do
  collect_sir_fns(int_key[:sir]).include?("stdlib.collection.sort_by_desc")
end
check("2.3 SIR never emits bare `sort_by_desc`") do
  !collect_sir_fns(int_key[:sir]).include?("sort_by_desc")
end

qual = ruby_compile_source(QUALIFIED_FORM)
check("2.4 QUALIFIED source form compiles clean (Fixed Law 7)") do
  qual[:status] == "ok" && qual[:codes].empty?
end
check("2.5 qualified source form emits the SAME identity stdlib.collection.sort_by_desc") do
  collect_sir_fns(qual[:sir]).include?("stdlib.collection.sort_by_desc")
end

text_key = ruby_compile_source(TEXT_KEY)
check("2.6 Text key compiles clean") { text_key[:status] == "ok" && text_key[:codes].empty? }

decimal_key = ruby_compile_source(DECIMAL_KEY)
check("2.7 Decimal key compiles clean") { decimal_key[:status] == "ok" && decimal_key[:codes].empty? }

# ── 3. Result discipline + contextual typing ─────────────────────────────────
preserved = ruby_compile_source(ELEMENT_TYPE_PRESERVED)
check("3.1 sort_by_desc(Collection[Item], Item -> Integer) still outputs Collection[Item]") do
  preserved[:status] == "ok" && preserved[:codes].empty?
end
mismatch = ruby_compile_source(ELEMENT_TYPE_MISMATCH)
check("3.2 output typed Collection[Integer] MISMATCHES (result is Collection[Item], not Collection[key])") do
  mismatch[:status] != "ok" && !mismatch[:codes].empty?
end
empty_ctx = ruby_compile_source(EMPTY_CONTEXTUAL)
check("3.3 pinned-empty Collection[Integer] sorts clean with contextual element type") do
  empty_ctx[:status] == "ok" && empty_ctx[:codes].empty?
end
singleton = ruby_compile_source(SINGLETON)
check("3.4 singleton [42] sorts clean as Collection[Integer]") do
  singleton[:status] == "ok" && singleton[:codes].empty?
end

# ── 4. Diagnostics: OOF-COL1 / OOF-COL2 / reused OOF-COL11 ───────────────────
check("4.1 wrong arity -> OOF-COL1 in the sort_by_desc spelling") do
  r = ruby_compile_source(ARITY)
  r[:codes].include?("OOF-COL1") &&
    r[:messages].any? { |m| m.include?("stdlib.collection.sort_by_desc: expected 2 arguments") }
end
check("4.2 non-lambda second arg -> OOF-COL1 in the sort_by_desc spelling") do
  r = ruby_compile_source(NON_LAMBDA_SECOND)
  r[:codes].include?("OOF-COL1") &&
    r[:messages].any? { |m| m.include?("stdlib.collection.sort_by_desc: second argument must be a lambda") }
end
check("4.3 non-Collection first arg -> OOF-COL2 in the sort_by_desc spelling") do
  r = ruby_compile_source(FIRST_ARG)
  r[:codes].include?("OOF-COL2") &&
    r[:messages].any? { |m| m.include?("stdlib.collection.sort_by_desc: first argument must be Collection[T]") }
end

float_res = ruby_compile_source(FLOAT_KEY)
check("4.4 Float key -> reused OOF-COL11 (no new code minted)") do
  float_res[:codes].include?("OOF-COL11") && !TC_SRC.include?("OOF-COL13")
end
check("4.5 OOF-COL11 message uses the sort_by_desc spelling and routes to Decimal/Integer") do
  float_res[:messages].any? do |m|
    m.start_with?("sort_by_desc key must have a total order") && m.include?("Decimal") && m.include?("Integer")
  end
end
check("4.6 qualified source form produces the SAME OOF-COL11 refusal") do
  r = ruby_compile_source(FLOAT_KEY_QUALIFIED)
  r[:codes].include?("OOF-COL11") &&
    r[:messages].any? { |m| m.start_with?("sort_by_desc key must have a total order") }
end
check("4.7 Bool key -> OOF-COL11") { ruby_compile_source(BOOL_KEY)[:codes].include?("OOF-COL11") }
check("4.8 record key -> OOF-COL11 in the sort_by_desc spelling, not OOF-COL10") do
  r = ruby_compile_source(RECORD_KEY)
  r[:codes].include?("OOF-COL11") && !r[:codes].include?("OOF-COL10") &&
    r[:messages].any? { |m| m.include?("sort_by_desc key must have a total order") && m.include?("got Item") }
end

# ── 5. §8.14.2 tie specimen — durable P3 handoff (accepted shape ONLY) ───────
tie = ruby_compile_source(TIE_FIXTURE.read(encoding: "UTF-8"))
check("5.1 tie specimen (fixtures/tie_specimen.ig) compiles clean") do
  tie[:status] == "ok" && tie[:codes].empty?
end
check("5.2 tie specimen lowers exactly one stdlib.collection.sort_by_desc call") do
  collect_sir_calls(tie[:sir], "stdlib.collection.sort_by_desc").length == 1
end
check("5.3 tie specimen call shape: elements Collection[Item], key lambda Integer, result Collection[Item]") do
  call = collect_sir_calls(tie[:sir], "stdlib.collection.sort_by_desc").first
  next false unless call
  args = call["args"] || []
  col  = args[0] || {}
  lam  = args[1] || {}
  col_t = col.dig("resolved_type", "params", 0, "name") || col.dig("resolved_type", "params", 0)
  key_t = lam.dig("resolved_type", "name") || lam["resolved_type"]
  out_t = call.dig("resolved_type", "params", 0, "name") || call.dig("resolved_type", "params", 0)
  col_t.to_s.include?("Item") && key_t.to_s.include?("Integer") && out_t.to_s.include?("Item")
end
check("5.4 no runtime-order claim leaks into P2: expected vectors live ONLY in fixture comments") do
  # The §8.14.2 expected runtime vectors are documented for P3 in `--` comment lines of the
  # fixture; no executable line of the specimen (and no check in this script) asserts them.
  fixture_src = TIE_FIXTURE.read(encoding: "UTF-8")
  vector_lines = fixture_src.lines.select { |l| l.include?("[10, 10, 7") || l.include?("[1, 3, 5") }
  !vector_lines.empty? && vector_lines.all? { |l| l.strip.start_with?("--") }
end

# ── 6. sort_by byte-stability ────────────────────────────────────────────────
check("6.1 sort_by dispatch arm is untouched (bare-only match, own infer)") do
  TC_SRC.include?('when "sort_by"') &&
    !TC_SRC.include?('when "sort_by", "stdlib.collection.sort_by"') &&
    TC_SRC.include?('qualified = "stdlib.collection.sort_by"')
end
asc = ruby_compile_source(SORT_BY_BYTE_STABLE)
check("6.2 ascending sort_by still compiles clean and emits its own identity") do
  asc[:status] == "ok" && asc[:codes].empty? &&
    collect_sir_fns(asc[:sir]).include?("stdlib.collection.sort_by") &&
    !collect_sir_fns(asc[:sir]).include?("stdlib.collection.sort_by_desc")
end
check("6.3 sort_by Float refusal keeps the ORIGINAL sort_by spelling (no desc bleed)") do
  r = ruby_compile_source(SORT_BY_FLOAT_SPELLING)
  r[:codes].include?("OOF-COL11") &&
    r[:messages].any? { |m| m.start_with?("sort_by key must have a total order") } &&
    r[:messages].none? { |m| m.include?("sort_by_desc key") }
end

# ── 7. Regression: neighboring collection ops ────────────────────────────────
reg = ruby_compile_source(REGRESSION)
check("7.1 map/filter/at/count/take still compile clean (single-output fixture)") do
  reg[:status] == "ok" && reg[:codes].empty?
end

# ─────────────────────────────────────────────────────────────────────────────
puts
puts "sort_by_desc P2: #{$pass} passed, #{$fail} failed"
exit($fail.zero? ? 0 : 1)
