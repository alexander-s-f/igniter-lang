#!/usr/bin/env ruby
# frozen_string_literal: true
#
# verify_ruby_io_typecheck_parity_p3.rb — LANG-RUBY-IO-TYPECHECK-COMPILE-PARITY-P3
#
# Proves canon COMPILE-parity typing for the lab `stdlib.IO.*` surface (IO_STDLIB_FNS in
# typechecker.rb, keys = qualified names from the P2 parser production; signatures mirror live
# Rust/VM). Execution is and stays VM/host authority — canon Ruby has no runtime IO path; no
# per-call "not runnable" diagnostic is emitted (it would be cascade noise), the boundary is
# structural. Also proves the or_else Result-unwrap typing (ok-type), matching the live VM.
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
  dir = "/tmp/rio_p3_#{Process.pid}"
  Dir.mkdir(dir) unless Dir.exist?(dir)
  path = File.join(dir, "#{tag}.ig")
  File.write(path, src)
  c = IgniterLang::CompilerOrchestrator.new
  r = c.compile_sources(source_paths: [path], out_path: File.join(dir, "#{tag}.igapp"))
  res = r["result"] || {}
  { status: r["status"], stages: res["stages"] || {}, diags: (res["diagnostics"] || []) }
end

msgs = ->(r) { r[:diags].map { |d| "#{d['rule']}: #{d['message']}" } }

# ── 1. observed + capability + effect + read_text: compile-CLEAN end to end ──
r1 = compile_src(<<~IG, "read_clean")
  module T1
  observed contract Reader {
    capability io_r: IO.Capability
    effect read_file using io_r
    compute r = stdlib.IO.read_text("x.txt", io_r)
    output r : Result[String, IoError]
  }
IG
check("IO-01: observed read_text contract compiles ok/0 (typed Result[String, IoError])") do
  [r1[:status] == "ok" && r1[:diags].empty?, msgs.call(r1).inspect]
end

# ── 2. or_else over Result unwraps to ok-type ────────────────────────────────
r2 = compile_src(<<~IG, "or_else_result")
  module T2
  observed contract R {
    capability io_r: IO.Capability
    effect read_file using io_r
    compute t = or_else(stdlib.IO.read_text("x.txt", io_r), "")
    output t : String
  }
IG
check("IO-02: or_else(read_text, \"\") types as String (Result ok-unwrap; output annotation satisfied)") do
  [r2[:status] == "ok" && r2[:diags].empty?, msgs.call(r2).inspect]
end

# ── 3. write/append/replace return-type shapes ───────────────────────────────
r3 = compile_src(<<~IG, "writers")
  module T3
  observed contract W {
    capability io_w: IO.Capability
    effect write_file using io_w
    compute w = stdlib.IO.write_text("f", "body", io_w)
    compute a = stdlib.IO.append_text("f", "chunk", io_w)
    compute p = stdlib.IO.replace_text_atomic("f", "content", io_w)
    output w : Result[WriteReceipt, IoError]
  }
IG
check("IO-03: write_text/append_text/replace_text_atomic type as their Result receipt shapes") do
  [r3[:status] == "ok" && r3[:diags].empty?, msgs.call(r3).inspect]
end

# ── 4. exists -> Result[Bool, IoError]; the exists-guard idiom is clean ─────
r4 = compile_src(<<~IG, "exists_guard")
  module T4
  observed contract E {
    capability io_r: IO.Capability
    effect read_file using io_r
    compute present = or_else(stdlib.IO.exists("wal.log", io_r), false)
    compute t = if present { "y" } else { "n" }
    output t : String
  }
IG
check("IO-04: or_else(exists, false) -> Bool; bare `if` over it is clean (OOF-IF1 avoided by unwrap)") do
  [r4[:status] == "ok" && r4[:diags].empty?, msgs.call(r4).inspect]
end

# ── 5. wrong capability arg rejected ─────────────────────────────────────────
r5 = compile_src(<<~IG, "bad_cap")
  module T5
  observed contract B {
    capability io_r: IO.Capability
    effect read_file using io_r
    compute r = stdlib.IO.read_text("x.txt", "not-a-cap")
    output r : Result[String, IoError]
  }
IG
check("IO-05: non-capability trailing arg -> OOF-TY0 (expected IO.Capability)") do
  ty0 = r5[:diags].select { |d| d["rule"] == "OOF-TY0" && d["message"].to_s.include?("IO.Capability") }
  [r5[:status] == "oof" && ty0.length == 1, msgs.call(r5).inspect]
end

# ── 6. wrong path/body type rejected ─────────────────────────────────────────
r6 = compile_src(<<~IG, "bad_path")
  module T6
  observed contract B {
    capability io_w: IO.Capability
    effect write_file using io_w
    compute w = stdlib.IO.write_text(42, "body", io_w)
    output w : Result[WriteReceipt, IoError]
  }
IG
check("IO-06: Integer path arg -> OOF-TY0 (expected String/Text)") do
  [r6[:status] == "oof" &&
     r6[:diags].any? { |d| d["rule"] == "OOF-TY0" && d["message"].to_s.include?("String/Text") },
   msgs.call(r6).inspect]
end

# ── 7. wrong arity rejected with OOF-TM1 (Rust code parity) ──────────────────
r7 = compile_src(<<~IG, "bad_arity")
  module T7
  observed contract B {
    capability io_r: IO.Capability
    effect read_file using io_r
    compute r = stdlib.IO.read_text("x.txt")
    output r : Result[String, IoError]
  }
IG
check("IO-07: wrong arity -> OOF-TM1") do
  [r7[:diags].any? { |d| d["rule"] == "OOF-TM1" }, msgs.call(r7).inspect]
end

# ── 8. unknown IO function rejected ONCE, bounded ─────────────────────────────
r8 = compile_src(<<~IG, "unknown_io")
  module T8
  observed contract B {
    capability io_r: IO.Capability
    effect read_file using io_r
    compute r = stdlib.IO.frobnicate("x.txt", io_r)
    output r : Result[String, IoError]
  }
IG
check("IO-08: unknown stdlib.IO fn -> ONE bounded OOF-TY0 Unknown function") do
  ty0 = r8[:diags].select { |d| d["rule"] == "OOF-TY0" && d["message"].to_s.include?("stdlib.IO.frobnicate") }
  [ty0.length == 1, msgs.call(r8).inspect]
end

# ── 9. positional IO (page fixture shapes) type-checks ───────────────────────
r9 = compile_src(<<~IG, "positional")
  module T9
  observed contract P {
    capability io_r: IO.Capability
    effect read_file using io_r
    compute sz = or_else(stdlib.IO.file_size("pages.bin", io_r), 0)
    output sz : Integer
  }
IG
check("IO-09: file_size -> Result[Integer, IoError]; or_else unwrap -> Integer output clean") do
  [r9[:status] == "ok" && r9[:diags].empty?, msgs.call(r9).inspect]
end

# ── 10. pure dotted stdlib call from P2 remains bounded-unknown (no IO leak) ──
r10 = compile_src(<<~IG, "pure_dotted_still")
  module T10
  pure contract Main {
    compute t = stdlib.text.concat("a", "b")
    output t : Text
  }
  entrypoint Main
IG
check("IO-10: pure dotted non-IO call unchanged by P3 (bounded OOF-TY0, not silently typed)") do
  [r10[:diags].any? { |d| d["rule"] == "OOF-TY0" && d["message"].to_s.include?("stdlib.text.concat") },
   msgs.call(r10).inspect]
end

puts "\n" + "─" * 60
total = CHECKS.length
pass = CHECKS.count(true)
puts pass == total ? "\e[32m\e[1m#{pass}/#{total} PASS\e[0m" : "\e[31m\e[1m#{pass}/#{total} — FAIL\e[0m"
exit(pass == total ? 0 : 1)
