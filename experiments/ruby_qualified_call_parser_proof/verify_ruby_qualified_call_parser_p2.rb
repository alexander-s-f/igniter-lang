#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_ruby_qualified_call_parser_p2.rb — LANG-RUBY-QUALIFIED-CALL-EXPR-PARSER-P2
#
# Proves the general qualified-call expression production (parser.rb parse_postfix +
# callable_path_name): a pure dotted NAME path followed by `(` parses as a call with the joined
# dotted `fn` — at RHS root AND nested inside another call's args — and the two old failure modes
# are gone:
#   * RHS root:  "Unknown body declaration: (" parser spray        -> parse ok, bounded typecheck
#   * nested:    IgniterLang::ParseError "Expected rparen, got comma" RAISE -> parse ok, no raise
# The parser makes NO stdlib/IO claim: unknown dotted names surface as ONE bounded
# `OOF-TY0 Unknown function: <dotted>` per call site (IO typing itself is P3's scope).
#
# NOTE: /experiments/ is gitignored in this repo (.gitignore:19) — commit with `git add -f`.

require "json"
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "igniter_lang/compiler_orchestrator"

CHECKS = []
def check(name)
  ok, detail = yield
  CHECKS << ok
  puts (ok ? "  \e[32m[PASS]\e[0m " : "  \e[31m[FAIL]\e[0m ") + name + (ok ? "" : " — #{detail}")
end

def compile_src(src, tag)
  dir = "/tmp/rqc_proof_#{Process.pid}"
  Dir.mkdir(dir) unless Dir.exist?(dir)
  path = File.join(dir, "#{tag}.ig")
  File.write(path, src)
  c = IgniterLang::CompilerOrchestrator.new
  begin
    r = c.compile_sources(source_paths: [path], out_path: File.join(dir, "#{tag}.igapp"))
    res = r["result"] || {}
    { raised: false, status: r["status"], stages: res["stages"] || {},
      diags: (res["diagnostics"] || []) }
  rescue => e
    { raised: true, error: "#{e.class}: #{e.message}", status: "raised", stages: {}, diags: [] }
  end
end

msgs = ->(r) { r[:diags].map { |d| "#{d['rule']}: #{d['message']}" } }
no_spray = ->(r) { r[:diags].none? { |d| d["message"].to_s.include?("Unknown body declaration") } }

# ── 1. pure qualified call at RHS root (NON-IO — the gap is general) ─────────
r1 = compile_src(<<~IG, "pure_dotted")
  module P1
  pure contract Main {
    compute t = stdlib.text.concat("a", "b")
    output t : Text
  }
  entrypoint Main
IG
check("Q-01: pure stdlib.text.concat(…) — parse stage ok") { [r1[:stages]["parse"] == "ok", r1.inspect[0, 200]] }
check("Q-02: no 'Unknown body declaration' spray") { [no_spray.call(r1), msgs.call(r1).first(3).inspect] }
check("Q-03: reaches typecheck with ONE bounded unknown-function diagnostic") do
  ty0 = r1[:diags].select { |d| d["rule"] == "OOF-TY0" && d["message"].to_s.include?("stdlib.text.concat") }
  [r1[:stages]["typecheck"] == "oof" && ty0.length == 1, msgs.call(r1).inspect]
end

# ── 2. qualified IO call at RHS root ─────────────────────────────────────────
r2 = compile_src(<<~IG, "io_root")
  module P2
  observed contract Reader {
    capability io_r: IO.Capability
    effect read_file using io_r
    compute r = stdlib.IO.read_text("x.txt", io_r)
    output r : Result[String, IoError]
  }
IG
check("Q-04: stdlib.IO.read_text at RHS root — parse ok, no spray") do
  [r2[:stages]["parse"] == "ok" && no_spray.call(r2), r2.inspect[0, 200]]
end
check("Q-05: IO call never parser-noise — either typed clean (post-P3) or ONE bounded OOF-TY0") do
  typed_clean = r2[:status] == "ok" && r2[:diags].empty?
  bounded = r2[:diags].count { |d| d["rule"] == "OOF-TY0" && d["message"].to_s.include?("stdlib.IO.read_text") } == 1
  [typed_clean || bounded, msgs.call(r2).inspect]
end

# ── 3. qualified call NESTED in another call's args (the old RAISE) ─────────
r3 = compile_src(<<~IG, "nested")
  module P3
  observed contract R {
    capability io_r: IO.Capability
    effect read_file using io_r
    compute t = or_else(stdlib.IO.read_text("x.txt", io_r), "")
    output t : String
  }
IG
check("Q-06: nested dotted call NEVER raises (was ParseError 'Expected rparen, got comma')") do
  [!r3[:raised], r3[:error].to_s]
end
check("Q-07: nested — parse ok, never spray (typed clean post-P3 or bounded oof)") do
  ty_ok = %w[ok oof].include?(r3[:stages]["typecheck"])
  [r3[:stages]["parse"] == "ok" && ty_ok && no_spray.call(r3), msgs.call(r3).inspect]
end

# ── 4. non-call dotted path (field access) unchanged ────────────────────────
r4 = compile_src(<<~IG, "field_access")
  module P4
  type Pt { x : Integer  y : Integer }
  pure contract Main {
    input p : Pt
    compute v = p.x + p.y
    output v : Integer
  }
  entrypoint Main
IG
check("Q-08: non-call dotted path (field access) still ok/0") do
  [r4[:status] == "ok" && r4[:diags].empty?, r4.inspect[0, 200]]
end

# ── 5. bare imported call unchanged ──────────────────────────────────────────
r5 = compile_src(<<~IG, "bare")
  module P5
  import stdlib.integer.{ parse_int, int_to_text }
  pure contract Main {
    compute t = int_to_text(42)
    compute n = or_else(parse_int(t), 0)
    output n : Integer
  }
  entrypoint Main
IG
check("Q-09: bare imported calls still ok/0") { [r5[:status] == "ok" && r5[:diags].empty?, msgs.call(r5).inspect] }

# ── 6. observed/capability/effect decls (no dotted call) unchanged ──────────
r6 = compile_src(<<~IG, "decls")
  module P6
  observed contract Decls {
    capability io_w: IO.Capability
    effect write_file using io_w
    compute x = 1 + 1
    output x : Integer
  }
IG
check("Q-10: observed+capability+effect decls still ok/0") { [r6[:status] == "ok" && r6[:diags].empty?, msgs.call(r6).inspect] }

# ── 7. computed-object postfix is NOT hijacked (call result . field, no call) ─
# (type name deliberately avoids the BUILT-IN `Pair` — zip's sealed Pair{first,second} shadows
# user types of that name in the typechecker, an unrelated pre-existing seam)
r7 = compile_src(<<~IG, "computed_postfix")
  module P7
  type MyPair { head : Integer  tail : Integer }
  pure contract Main {
    input p : MyPair
    compute a = p.head
    output a : Integer
  }
  entrypoint Main
IG
check("Q-11: field access over input record still ok (no call hijack)") do
  [r7[:status] == "ok", msgs.call(r7).inspect]
end

puts "\n" + "─" * 60
total = CHECKS.length
pass = CHECKS.count(true)
verdict = pass == total ? "\e[32m\e[1m#{pass}/#{total} PASS\e[0m" : "\e[31m\e[1m#{pass}/#{total} — FAIL\e[0m"
puts verdict
exit(pass == total ? 0 : 1)
