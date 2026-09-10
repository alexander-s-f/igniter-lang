#!/usr/bin/env ruby
# frozen_string_literal: true
#
# LANG-CANON-TEXT-CONCAT-TYPED-ARG-REUSE-IMPLEMENTATION-P3 — permanent regression proof
#
# Protects the landed H+B change in lib/igniter_lang/typechecker.rb:
#   B: infer_concat_call passes its already-inferred positional arguments to infer_text_call
#      (keyword `typed:`), so a Text-prefixed interpolation chain is typed once per node instead
#      of once per visit of every enclosing concat (visits followed 1 + 2V(left) + V(right)).
#   H: the guarded `DEBUG: unresolved l backtrace` puts block in infer_expr's ref case is gone.
# Self-contained: loads THIS repo's lib (asserted by realpath), needs no Lab packet.
#
#   ruby experiments/text_concat_typed_arg_reuse_proof/verify_text_concat_typed_arg_reuse.rb            # full suite
#   ruby experiments/text_concat_typed_arg_reuse_proof/verify_text_concat_typed_arg_reuse.rb --controls  # only the two
#     sensitivity controls (work-count guard + DEBUG-free stdout); they FAIL on the pre-H+B source by design.
require "json"
require "digest"
require "open3"
require "rbconfig"

LIB = File.expand_path("../../lib", __dir__)
$LOAD_PATH.unshift(LIB)
require "igniter_lang"

TC_LOADED = $LOADED_FEATURES.find { |f| f.end_with?("igniter_lang/typechecker.rb") }
TC_REPO   = File.join(LIB, "igniter_lang", "typechecker.rb")
unless TC_LOADED && File.realpath(TC_LOADED) == File.realpath(TC_REPO)
  abort "identity: typechecker loaded from #{TC_LOADED.inspect}, expected this repo's #{TC_REPO}"
end
TC_SHA = Digest::SHA256.file(TC_LOADED).hexdigest
RUBY   = RbConfig.ruby
IGC    = File.expand_path("../../bin/igc", __dir__)
FIX    = File.join(__dir__, "fixtures")
CONTROLS_ONLY = ARGV.include?("--controls")

puts "typechecker: #{File.realpath(TC_LOADED)}"
puts "typechecker sha256: #{TC_SHA}"
puts "ruby: #{RUBY}"

$pass = 0
$fail = 0
$total = 0

def check(label)
  $total += 1
  ok = begin
    yield
  rescue => e
    puts "  [exception: #{e.class}: #{e.message.lines.first.strip}]"
    false
  end
  puts "#{ok ? "PASS" : "FAIL"} [#{format("%-3d", $total)}] #{label}"
  ok ? $pass += 1 : $fail += 1
  ok
end

def typecheck(src)
  parsed = IgniterLang::ParsedProgram.parse(src, source_path: "inline.ig").to_h
  raise "parse errors: #{parsed["parse_errors"].inspect}" unless parsed.fetch("parse_errors").empty?
  IgniterLang::DerivedConstructorSugar.lower!(parsed)
  IgniterLang::ContractCallSugar.lower!(parsed)
  classified = IgniterLang::Classifier.new.classify(parsed, sample_input: {})
  IgniterLang::TypeChecker.new.typecheck(classified)
end

def contract(typed, name)
  typed.fetch("contracts").find { |c| c["name"] == name } or raise "no contract #{name}"
end

def compute(typed, cname, dname)
  c = contract(typed, cname)
  d = c.fetch("declarations").find { |x| x["kind"] == "compute" && x["name"] == dname } or raise "no compute #{dname}"
  [c, d.fetch("expr")]
end

def chain_levels(expr)
  levels = []
  node = expr
  while node["kind"] == "call" && node["fn"].to_s.end_with?("concat")
    levels << [node["fn"], node["args"].length, node["resolved_type"]["name"]]
    node = node["args"][0]
  end
  levels
end

def errs(c) = c.fetch("type_errors").map { |x| [x["rule"], x["message"]] }

# ── test-only instrumentation: count infer_expr entries in THIS process only (never part of lib) ──
module InferExprCounter
  @count = 0
  class << self; attr_accessor :count; end
  def infer_expr(*a, **k)
    InferExprCounter.count += 1
    super
  end
end
IgniterLang::TypeChecker.prepend(InferExprCounter)

def visits_for(src)
  InferExprCounter.count = 0
  typecheck(src)
  InferExprCounter.count
end

def igc_check(fixture)
  env = { "PATH" => "/usr/bin:/bin", "HOME" => ENV.fetch("HOME", "/tmp"), "LANG" => "en_US.UTF-8", "LC_ALL" => "en_US.UTF-8", "RUBYLIB" => LIB }
  out, err, st = Open3.capture3(env, RUBY, IGC, "check", File.join(FIX, fixture), "--json", unsetenv_others: true)
  [out, err, st.exitstatus]
end

# ═════════════════════════ sensitivity controls (fail on the pre-H+B source) ═════════════════════════
# S1 bounded work-count guard: exact single-visit counts; the old source gave 19112 / 37 / 7.
seg6 = "\"a${int_to_text(n)}b${int_to_text(n)}c${int_to_text(n)}d${int_to_text(n)}e${int_to_text(n)}f${int_to_text(n)}g\""
adj4 = "\"${int_to_text(n)}${int_to_text(n)}${int_to_text(n)}${int_to_text(n)}\""
mix1 = "\"a${int_to_text(n)}\""
check("S1 work-count guard: 6 segmented Text holes = 31 infer_expr entries, 4 adjacent = 11, String-then-Text pair = 4 (no repeated argument inference)") do
  v6 = visits_for("module W6\npure contract R { input n : Integer  compute line : Text = #{seg6}  output line : Text }\n")
  v4 = visits_for("module W4\npure contract R { input n : Integer  compute line : Text = #{adj4}  output line : Text }\n")
  v1 = visits_for("module W1\npure contract R { input n : Integer  compute line : Text = #{mix1}  output line : Text }\n")
  puts "  counts: seg6=#{v6} adj4=#{v4} mix1=#{v1} (expected 31 / 11 / 4)"
  v6 == 31 && v4 == 11 && v1 == 4
end

# S2 stdout hygiene: real `igc check --json` on an unresolved ref named `l` — strict JSON, no DEBUG, refused, ordered OOF-P1.
check("S2 unresolved `l`: igc check --json stdout is strict JSON with no DEBUG text, exit 1, diagnostics [OOF-P1 Unresolved symbol: l]") do
  out, err, code = igc_check("unresolved_l.ig")
  j = JSON.parse(out)
  puts "  exit=#{code} bytes=#{out.bytesize} debug=#{out.include?("DEBUG")} stderr=#{err.bytesize}"
  code == 1 && err.empty? && !out.include?("DEBUG") && j["status"] == "refused" &&
    j["diagnostics"].map { |d| [d["rule"], d["message"]] } == [["OOF-P1", "Unresolved symbol: l"]]
end

check("S3 unresolved `zz` control: strict JSON, exit 1, diagnostics [OOF-P1 Unresolved symbol: zz], no DEBUG") do
  out, err, code = igc_check("unresolved_zz.ig")
  j = JSON.parse(out)
  code == 1 && err.empty? && !out.include?("DEBUG") && j["status"] == "refused" &&
    j["diagnostics"].map { |d| [d["rule"], d["message"]] } == [["OOF-P1", "Unresolved symbol: zz"]]
end

if CONTROLS_ONLY
  puts "controls: PASS=#{$pass} FAIL=#{$fail} (on the pre-H+B source S1 and S2 are EXPECTED to fail)"
  exit($fail.zero? ? 0 : 1)
end

# ═════════════════════════ typing / routing preservation ═════════════════════════
check("T1 String/String fast path: \"a${s}b\" nests stdlib.string.concat, resolved String, deps [s]") do
  c, e = compute(typecheck("module T1\npure contract R { input s : String  compute line : Text = \"a${s}b\"  output line : Text }\n"), "R", "line")
  c["status"] == "accepted" && chain_levels(e) == [["stdlib.string.concat", 2, "String"], ["stdlib.string.concat", 2, "String"]] && e["deps"] == ["s"]
end

check("T2 Text/Text: concat(t, u) is stdlib.text.concat with two typed ref args, resolved Text, deps [t, u]") do
  c, e = compute(typecheck("module T2\npure contract R { input t : Text  input u : Text  compute line : Text = concat(t, u)  output line : Text }\n"), "R", "line")
  c["status"] == "accepted" && e["fn"] == "stdlib.text.concat" && e["args"].map { |a| a["kind"] } == %w[ref ref] && e["resolved_type"]["name"] == "Text" && e["deps"] == %w[t u]
end

check("T3 mixed String-then-Text: \"a${int_to_text(n)}\" -> stdlib.text.concat(literal, int_to_text) Text, deps [n]") do
  c, e = compute(typecheck("module T3\npure contract R { input n : Integer  compute line : Text = \"a${int_to_text(n)}\"  output line : Text }\n"), "R", "line")
  c["status"] == "accepted" && e["fn"] == "stdlib.text.concat" && e["args"][0]["kind"] == "literal" && e["args"][1]["fn"] == "stdlib.integer.int_to_text" && e["resolved_type"]["name"] == "Text" && e["deps"] == ["n"]
end

check("T4 mixed Text-then-String: \"${int_to_text(n)}a\" -> stdlib.text.concat(int_to_text, literal) Text") do
  c, e = compute(typecheck("module T4\npure contract R { input n : Integer  compute line : Text = \"${int_to_text(n)}a\"  output line : Text }\n"), "R", "line")
  c["status"] == "accepted" && e["fn"] == "stdlib.text.concat" && e["args"][0]["fn"] == "stdlib.integer.int_to_text" && e["args"][1]["kind"] == "literal" && e["resolved_type"]["name"] == "Text"
end

check("T5 long Text chain: every level stdlib.text.concat with exactly 2 typed args; result Text; deps [n]; no errors") do
  c, e = compute(typecheck("module T5\npure contract R { input n : Integer  compute line : Text = #{seg6}  output line : Text }\n"), "R", "line")
  lv = chain_levels(e)
  c["status"] == "accepted" && lv.length == 12 && lv.all? { |fn, n, t| fn == "stdlib.text.concat" && n == 2 && t == "Text" } && e["deps"] == ["n"] && c["type_errors"].empty?
end

check("T6 Collection concat: concat(xs, ys) routes to stdlib.collection.concat, Collection[Integer], deps [xs, ys]") do
  c, e = compute(typecheck("module T6\npure contract R { input xs : Collection[Integer]  input ys : Collection[Integer]  compute zs : Collection[Integer] = concat(xs, ys)  output zs : Collection[Integer] }\n"), "R", "zs")
  c["status"] == "accepted" && e["fn"] == "stdlib.collection.concat" && e["resolved_type"]["name"] == "Collection" && e["deps"] == %w[xs ys]
end

check("T7 Unknown-first part: \"${nope}b${int_to_text(n)}c\" -> ordered [OOF-P1, OOF-COL2 got String, OOF-COL2 got Text], top fn stdlib.collection.concat") do
  c, e = compute(typecheck("module T7\npure contract R { input n : Integer  compute line : Text = \"${nope}b${int_to_text(n)}c\"  output line : Text }\n"), "R", "line")
  es = errs(c)
  es.map(&:first) == %w[OOF-P1 OOF-COL2 OOF-COL2] && es[1][1].end_with?("got String") && es[2][1].end_with?("got Text") && e["fn"] == "stdlib.collection.concat"
end

check("T8 wrong arity: concat(t) refuses OOF-TY0 'expected 2 argument(s), got 1' with empty typed args (early return before any reuse)") do
  c, e = compute(typecheck("module T8\npure contract R { input t : Text  compute one : Text = concat(t)  output one : Text }\n"), "R", "one")
  c["status"] == "blocked" && errs(c) == [["OOF-TY0", "stdlib.text.concat: expected 2 argument(s), got 1"]] && e["args"] == []
end

check("T9 unknown NON-ref second argument: \"${p.a}${p.zzz}\" -> exactly one public OOF-P1 'Unresolved field: P.zzz'; result Text; deps [p]") do
  c, e = compute(typecheck("module T9\ntype P { a : String }\npure contract R { input p : P  compute line : Text = \"${p.a}${p.zzz}\"  output line : Text }\n"), "R", "line")
  c["status"] == "blocked" && errs(c) == [["OOF-P1", "Unresolved field: P.zzz"]] && e["resolved_type"]["name"] == "Text" && e["deps"] == ["p"]
end

check("T10 default typed: {} path: trim(t) accepted, fn stdlib.text.trim, single typed ref arg") do
  c, e = compute(typecheck("module T10\npure contract R { input t : Text  compute u : Text = trim(t)  output u : Text }\n"), "R", "u")
  c["status"] == "accepted" && e["fn"] == "stdlib.text.trim" && e["args"].length == 1 && e["args"][0]["kind"] == "ref"
end

check("T11 nested dependencies: compute t then \"${t}:${int_to_text(m)}\" carries deps [t, m] in order; \"${s}${s}\" deps [s] (uniq)") do
  typed = typecheck("module T11\npure contract R { input n : Integer  input m : Integer  input s : String  compute t : Text = int_to_text(n)  compute line : Text = \"${t}:${int_to_text(m)}\"  compute dup : Text = \"${s}${s}\"  output line : Text }\n")
  _, e = compute(typed, "R", "line"); _, d = compute(typed, "R", "dup")
  e["deps"] == %w[t m] && d["deps"] == ["s"] && contract(typed, "R")["status"] == "accepted"
end

check("T12 branch context: chain inside if/else keeps both arms typed once, result Text, deps [b, n, m]") do
  c, e = compute(typecheck("module T12\npure contract R { input b : Bool  input n : Integer  input m : Integer  compute line : Text = if b { \"y${int_to_text(n)}\" } else { \"n${int_to_text(m)}\" }  output line : Text }\n"), "R", "line")
  c["status"] == "accepted" && e["kind"] == "if_expr" && e["resolved_type"]["name"] == "Text" && e["deps"] == %w[b n m]
end

check("T13 ordered multiple refusals: \"a${n}b${b}\" -> [OOF-TY0 arg 2 got Integer, OOF-TY0 arg 2 got Bool] in source order") do
  c, _ = compute(typecheck("module T13\npure contract R { input n : Integer  input b : Bool  compute line : Text = \"a${n}b${b}\"  output line : Text }\n"), "R", "line")
  errs(c) == [["OOF-TY0", "stdlib.text.concat arg 2: expected Text, got Integer"], ["OOF-TY0", "stdlib.text.concat arg 2: expected Text, got Bool"]]
end

check("T14 dedupe preserved: \"a${n}b${int_to_text(n)}c\" publishes exactly one OOF-TY0 (arg 2 Integer); result Text") do
  c, e = compute(typecheck("module T14\npure contract R { input n : Integer  compute line : Text = \"a${n}b${int_to_text(n)}c\"  output line : Text }\n"), "R", "line")
  errs(c) == [["OOF-TY0", "stdlib.text.concat arg 2: expected Text, got Integer"]] && e["resolved_type"]["name"] == "Text"
end

check("T15 nonempty OOF-M3: irreversible contract with escape keeps exactly one OOF-M3 warning on the typed program; chain Text") do
  c, e = compute(typecheck("module T15\nirreversible contract Burn { input n : Integer  compute line : Text = \"burn ${int_to_text(n)} units over ${int_to_text(n)} steps\"  escape burn_write  output line : Text }\n"), "Burn", "line")
  w = c.fetch("type_warnings", [])
  c["status"] == "accepted" && w.length == 1 && w[0]["rule"] == "OOF-M3" && e["resolved_type"]["name"] == "Text"
end

OLAP = <<~IG
  module T16
  olap_point sales {
    dimensions: { region: String }
    measure: Integer
    source: sales_feed
  }
  olap_point sales_ix {
    dimensions: { region: String }
    measure: Integer
    source: sales_feed
    indexed: [region]
  }
  pure contract WARN { input n : Integer  compute line : Text = "${int_to_text(n)} sum ${olap_rollup(sales, :region)} end"  output line : Text }
  pure contract NOWARN { input n : Integer  compute line : Text = "${int_to_text(n)} sum ${olap_rollup(sales_ix, :region)} end"  output line : Text }
IG
check("T16 in-expression OOF-O2: olap_rollup over a non-indexed dimension inside a Text chain -> exactly one OOF-O2 warning (WARN) and none for the indexed control (NOWARN); both refuse OOF-TY0 (OLAPPoint in Text)") do
  typed = typecheck(OLAP)
  w, nw = contract(typed, "WARN"), contract(typed, "NOWARN")
  w.fetch("type_warnings", []).map { |x| x["rule"] } == ["OOF-O2"] && nw.fetch("type_warnings", []).empty? &&
    errs(w).map(&:first) == ["OOF-TY0"] && errs(nw).map(&:first) == ["OOF-TY0"] && w["status"] == "blocked"
end

check("T17 source law: the DEBUG puts block is absent from the loaded typechecker and infer_text_call accepts typed:") do
  src = File.read(TC_LOADED)
  !src.include?('puts "DEBUG: unresolved l backtrace:"') && src.include?("def infer_text_call(fn, args, symbol_types, type_errors, type_warnings, node_name, typed: {})") &&
    src.include?("typed.fetch(idx) { infer_expr(arg, symbol_types, type_errors, type_warnings, node_name) }")
end

puts "text_concat_typed_arg_reuse proof: PASS=#{$pass} FAIL=#{$fail} TOTAL=#{$total} typechecker=#{TC_SHA[0, 16]}"
exit($fail.zero? ? 0 : 1)
