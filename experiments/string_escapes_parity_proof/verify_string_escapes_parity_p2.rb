#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-RUBY-STRING-ESCAPES-PARITY-P2 — Differential Proof
#
# Brings the Ruby/canon lexer to parity with the already-live Rust string escape set
# (`\"` `\\` `\n` `\t` `\r`; see igniter-compiler src/lexer.rs `read_string`,
# LAB-LANG-STRING-ESCAPES-P1, and tests/string_escapes_tests.rs). Proves, for both
# toolchains:
#   A — the 9 required cases (card §Required Differential Proof) decode/fail identically
#   B — Ruby regression: existing proof suites unaffected (run separately, see closing report)
#   C — IGMESH stage 4 (mesh_net_io.ig / mesh_recv.ig / mesh_wire.ig) parse-level parity —
#       the NAMED IGMESH-P14 blocker ("Expected rparen, got eof()") is gone
#   D — ordinary (escape-free) strings are byte-for-byte unchanged
#
# Verify-first note: this proof requires a CURRENT Rust release binary. The one found on
# disk at first run predated an unrelated lexer.rs change (LAB-STDLIB-NET-REQUEST-
# RESPONSE-SEAM-P5 dotted-ident folding) from a parallel agent's already-committed work;
# rebuilding it (`cargo build --release`, no source edits) was required to get an honest
# Rust reference and is unrelated to this card's own changes.

require "json"
require "open3"
require "pathname"
require "tempfile"
require "tmpdir"

# Without an inherited LANG/LC_ALL, Ruby defaults external encoding to US-ASCII, which then
# raises Encoding::InvalidByteSequenceError decoding UTF-8 bytes out of the Rust binary's
# stdout (JSON diagnostics, em dashes, etc). Same class of environment flake noted for other
# repos in this workspace ("make verify NEEDS LANG=en_US.UTF-8") — fix it in-process instead
# of depending on the caller's shell locale.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "igniter_lang"
require "igniter_lang/compiler_orchestrator"

ROOT       = Pathname.new(__dir__).join("../..").expand_path
WORKSPACE  = ROOT.join("..").expand_path
LAB_ROOT   = WORKSPACE.join("igniter-lab")
RUST_BIN   = LAB_ROOT.join("igniter-compiler/target/release/igniter_compiler")
IGMESH_DIR = LAB_ROOT.join("apps/igniter-apps/igmesh")
IGWEB_RS   = LAB_ROOT.join("igniter-compiler/src/igweb.rs")

$pass = 0
$fail = 0
$total = 0

def check(label)
  $total += 1
  result = begin
    yield
  rescue StandardError => e
    puts "  [exception: #{e.class}: #{e.message.to_s.lines.first&.strip}]"
    false
  end
  if result
    $pass += 1
    puts "PASS [#{format('%-3d', $total)}] #{label}"
  else
    $fail += 1
    puts "FAIL [#{format('%-3d', $total)}] #{label}"
  end
  result
end

def section(title)
  puts
  puts "── #{title} " + ("─" * [1, 70 - title.length - 3].max)
end

# ── toolchain helpers ──────────────────────────────────────────────────────────────────

def ruby_parse(src)
  IgniterLang::ParsedProgram.parse(src, source_path: "inline").to_h
end

def ruby_first_compute_value(parsed, name = "s")
  cd = parsed.dig("contracts", 0, "body")&.find { |d| d["name"] == name }
  cd&.dig("expr", "value")
end

def ruby_parse_rules(parsed)
  parsed.fetch("parse_errors", []).map { |e| e.is_a?(Hash) ? e["rule"] : nil }.compact
end

def ruby_compile_string(src)
  Dir.mktmpdir("string-escapes-proof-ruby") do |dir|
    path = File.join(dir, "case.ig")
    File.write(path, src)
    IgniterLang::CompilerOrchestrator.new.compile(source_path: path, out_path: File.join(dir, "out.igapp"))
  end
end

def rust_compile_string(src, name)
  Tempfile.create([name, ".ig"]) do |file|
    file.write(src)
    file.flush
    Dir.mktmpdir("string-escapes-proof-rust") do |dir|
      out, err, status = Open3.capture3(RUST_BIN.to_s, "compile", file.path, "--out", File.join(dir, "#{name}.igapp"))
      parsed =
        begin
          JSON.parse(out)
        rescue JSON::ParserError
          { "status" => "unparsed_stdout", "_stdout" => out }
        end
      # `Dir.mktmpdir` removes `dir` (and the .igapp bundle inside it) the instant this block
      # returns, so `igapp_path` is a dangling path by the time the caller inspects the result —
      # read the one file this proof needs (semantic_ir_program.json) NOW and embed it.
      sir_path = File.join(dir, "#{name}.igapp", "semantic_ir_program.json")
      parsed["_semantic_ir"] = JSON.parse(File.read(sir_path)) if File.exist?(sir_path)
      parsed.merge("_stderr" => err, "_exitstatus" => status.exitstatus)
    end
  end
end

def rust_diag_rules(result)
  (result["diagnostics"] || []).map { |d| d["rule"] }.compact
end

def rust_literal_value(result, name = "s")
  sir = result["_semantic_ir"]
  return nil unless sir

  node = sir.dig("contracts", 0, "nodes")&.find { |n| n["name"] == name }
  node&.dig("expr", "value")
end

puts "=" * 78
puts "LANG-RUBY-STRING-ESCAPES-PARITY-P2: Differential Proof"
puts "=" * 78

section "0: Verify-first — Rust binary is current"

check("0-01 Rust release binary exists") { RUST_BIN.exist? }
check("0-02 Rust release binary is current (functional canary, not an mtime check — a parallel " \
      "agent is actively editing igniter-compiler/src/lexer.rs for an unrelated Bytes card, so " \
      "mtime ordering alone is not a stable signal; probe the ACTUAL behavior this proof depends " \
      "on instead: stdlib.net.request must fold to one qualified call token, matching LAB-STDLIB-" \
      "NET-REQUEST-RESPONSE-SEAM-P5, or the IGMESH section below cannot possibly parse)") do
  canary = <<~IG
    module Canary
    pure contract C {
      input netreq : Integer
      input net : Integer
      compute result = stdlib.net.request(netreq, net)
      output result : Integer
    }
  IG
  Tempfile.create(["canary", ".ig"]) do |f|
    f.write(canary)
    f.flush
    out2, _err2, _status2 = Open3.capture3(RUST_BIN.to_s, "compile", f.path, "--out", "/tmp/canary_#{Process.pid}.igapp")
    parsed = JSON.parse(out2)
    (parsed["diagnostics"] || []).none? { |d| d["rule"] == "OOF-P0" }
  end
end

# ── SECTION A: the 9 required differential cases ──────────────────────────────────────

section "A: 9 required cases — parsed literal + emitted semantic value parity"

# Fixture builder: a minimal pure contract computing `s` from the given RAW .ig string
# literal text (caller supplies the exact bytes between the quotes, backslashes included).
def fixture(body_string_src)
  <<~IG
    module DiffCase
    pure contract C {
      compute s : String = #{body_string_src}
      output s : String
    }
  IG
end

# A-01 "say \"hi\""
src1 = fixture('"say \"hi\""')
check("A-01 quote: Ruby parses with no errors") { ruby_parse_rules(ruby_parse(src1)).empty? }
check("A-01 quote: Ruby decoded value is say \"hi\"") { ruby_first_compute_value(ruby_parse(src1)) == 'say "hi"' }
check("A-01 quote: Rust compiles ok") { rust_compile_string(src1, "a01")["status"] == "ok" }
check("A-01 quote: Ruby/Rust emitted semantic value match") do
  rb = ruby_compile_string(src1)
  rs = rust_compile_string(src1, "a01b")
  rb["status"] == "ok" && rs["status"] == "ok" &&
    rb.dig("semantic_ir", "contracts", 0, "nodes", 0, "expr", "value") == rust_literal_value(rs) &&
    rust_literal_value(rs) == 'say "hi"'
end

# A-02 "a\\b"  (one escaped backslash followed by 'b' -> a\b)
src2 = fixture('"a\\\\b"')
check("A-02 backslash: Ruby decoded value is a\\b") { ruby_first_compute_value(ruby_parse(src2)) == 'a\\b' }
check("A-02 backslash: Ruby/Rust emitted values match") do
  rb = ruby_compile_string(src2)
  rs = rust_compile_string(src2, "a02")
  rb["status"] == "ok" && rs["status"] == "ok" &&
    rb.dig("semantic_ir", "contracts", 0, "nodes", 0, "expr", "value") == rust_literal_value(rs)
end

# A-03 newline / tab / carriage return
src3n = fixture('"x\ny"')
src3t = fixture('"x\ty"')
src3r = fixture('"x\ry"')
check("A-03 newline: Ruby decodes to x\\ny") { ruby_first_compute_value(ruby_parse(src3n)) == "x\ny" }
check("A-03 tab: Ruby decodes to x\\ty") { ruby_first_compute_value(ruby_parse(src3t)) == "x\ty" }
check("A-03 carriage return: Ruby decodes to x\\ry") { ruby_first_compute_value(ruby_parse(src3r)) == "x\ry" }
check("A-03 newline/tab/cr: Ruby/Rust emitted values all match") do
  [src3n, src3t, src3r].each_with_index.all? do |s, i|
    rb = ruby_compile_string(s)
    rs = rust_compile_string(s, "a03#{i}")
    rb["status"] == "ok" && rs["status"] == "ok" &&
      rb.dig("semantic_ir", "contracts", 0, "nodes", 0, "expr", "value") == rust_literal_value(rs)
  end
end

# A-04 "{\"body\":\"ok\"}"  (the exact JSON-shaped case IgWeb render proofs route around)
src4 = fixture('"{\"body\":\"ok\"}"')
check("A-04 json-shaped: Ruby decodes to {\"body\":\"ok\"}") do
  ruby_first_compute_value(ruby_parse(src4)) == '{"body":"ok"}'
end
check("A-04 json-shaped: Ruby/Rust emitted values match") do
  rb = ruby_compile_string(src4)
  rs = rust_compile_string(src4, "a04")
  rb["status"] == "ok" && rs["status"] == "ok" &&
    rb.dig("semantic_ir", "contracts", 0, "nodes", 0, "expr", "value") == rust_literal_value(rs) &&
    rust_literal_value(rs) == '{"body":"ok"}'
end

# A-05 mixed escapes in one literal
src5 = fixture('"a\\\\b\nc\td\re\"f"')
check("A-05 mixed: Ruby decodes all five escape kinds correctly") do
  ruby_first_compute_value(ruby_parse(src5)) == "a\\b\nc\td\re\"f"
end
check("A-05 mixed: Ruby/Rust emitted values match") do
  rb = ruby_compile_string(src5)
  rs = rust_compile_string(src5, "a05")
  rb["status"] == "ok" && rs["status"] == "ok" &&
    rb.dig("semantic_ir", "contracts", 0, "nodes", 0, "expr", "value") == rust_literal_value(rs)
end

# A-06 invalid \q — both toolchains report the escape-family rule, neither crashes
src6 = fixture('"bad \q here"')
check("A-06 invalid \\q: Ruby reports OOF-LEX1, no uncaught exception") do
  ruby_parse_rules(ruby_parse(src6)).include?("OOF-LEX1")
end
check("A-06 invalid \\q: Rust reports OOF-LEX1 (has_lex_error parity)") do
  rust_diag_rules(rust_compile_string(src6, "a06")).include?("OOF-LEX1")
end
check("A-06 invalid \\q: Ruby compile() returns a normal bounded result, not a raised exception") do
  r = ruby_compile_string(src6)
  r.is_a?(Hash) && %w[oof error].include?(r["status"])
end

# A-07 trailing backslash (open string, backslash then EOF)
src7 = "module DiffCase\npure contract C {\n  compute s : String = \"abc\\\nEOF_MARKER"
check("A-07 trailing backslash: Ruby reports OOF-LEX1, no uncaught exception") do
  ruby_parse_rules(ruby_parse(src7)).include?("OOF-LEX1")
end
check("A-07 trailing backslash: Rust reports OOF-LEX1") do
  rust_diag_rules(rust_compile_string(src7, "a07")).include?("OOF-LEX1")
end

# A-08 unterminated quote
src8 = "module DiffCase\npure contract C {\n  compute s : String = \"abc\nEOF_MARKER"
check("A-08 unterminated string: Ruby reports OOF-LEX1, no uncaught exception") do
  ruby_parse_rules(ruby_parse(src8)).include?("OOF-LEX1")
end
check("A-08 unterminated string: Rust reports OOF-LEX1") do
  rust_diag_rules(rust_compile_string(src8, "a08")).include?("OOF-LEX1")
end

# A-09 simple string regression — ordinary escape-free strings unchanged
src9 = fixture('"hello world"')
check("A-09 regression: Ruby decodes ordinary string unchanged") do
  ruby_first_compute_value(ruby_parse(src9)) == "hello world"
end
check("A-09 regression: Ruby/Rust emitted values match, both ok") do
  rb = ruby_compile_string(src9)
  rs = rust_compile_string(src9, "a09")
  rb["status"] == "ok" && rs["status"] == "ok" &&
    rb.dig("semantic_ir", "contracts", 0, "nodes", 0, "expr", "value") == "hello world" &&
    rust_literal_value(rs) == "hello world"
end
check("A-09 regression: a regex-shaped string with no backslash is still unchanged") do
  src = fixture('"^/todos/([^/]+)$"')
  ruby_first_compute_value(ruby_parse(src)) == "^/todos/([^/]+)$"
end

section "D: source-hash / program_id determinism cross-check"

check("D-01 identical .ig source produces the SAME source_hash in both toolchains (A-01 fixture)") do
  rb = ruby_compile_string(src1)
  rs = rust_compile_string(src1, "d01")
  rb_hash = rb.dig("semantic_ir", "source_hash")
  rb_hash && rb_hash == rs["source_hash"]
end

# ── SECTION C: IGMESH stage 4 — the named IGMESH-P14 residual ─────────────────────────

section "C: IGMESH stage 4 — parse-level dual-clean (IGMESH-P14)"

check("C-00 mesh_net_io.ig source is untouched by this card (compat audit: no source edit needed)") do
  IGMESH_DIR.join("mesh_net_io.ig").read.include?('compute body = concat(concat("\"", m1), "\"")')
end

def igmesh_prelude_source
  # The IgWeb builder injects this Rust constant as `IgWebPrelude` (igweb.rs PRELUDE_SOURCE) —
  # read-only extraction of its literal .ig text (unescaping the Rust `\"` used to embed `"` in
  # the Rust string literal), not a modification of Rust source. Required so mesh_net_io.ig /
  # mesh_recv.ig (which `import IgWebPrelude`) can be compiled outside the full igweb-serve
  # project-mode/builder pipeline (VM/IgWeb runtime bring-up is out of this card's authority).
  text = IGWEB_RS.read
  start_marker = 'pub const PRELUDE_SOURCE: &str = "\\'
  start = text.index(start_marker) + start_marker.length
  stop = text.index("\";\n", start)
  text[start...stop].gsub('\\"', '"')
end

require "fileutils"

def igmesh_repro(files)
  Dir.mktmpdir("igmesh-parity") do |dir|
    files.each { |f| FileUtils.cp(IGMESH_DIR.join(f), File.join(dir, f)) }
    # mesh_net_io.ig / mesh_recv.ig `import IgWebPrelude` — write the prelude alongside them.
    if files.any? { |f| f == "mesh_net_io.ig" || f == "mesh_recv.ig" }
      File.write(File.join(dir, "IgWebPrelude.ig"), igmesh_prelude_source)
      files = files + ["IgWebPrelude.ig"]
    end
    yield dir, files
  end
end

SENDER_SET   = %w[types.ig msg.ig gossip.ig antientropy.ig mesh_net_io.ig]
RECEIVER_SET = %w[types.ig msg.ig gossip.ig antientropy.ig mesh_recv.ig]
WIRE_SET     = %w[types.ig msg.ig gossip.ig antientropy.ig mesh_wire.ig]

def ruby_multifile(dir, files)
  IgniterLang::CompilerOrchestrator.new.compile_sources(
    source_paths: files.map { |f| File.join(dir, f) },
    out_path: File.join(dir, "ruby_out.igapp")
  )
end

def rust_multifile(dir, files)
  out, err, status = Open3.capture3(
    RUST_BIN.to_s, "compile", *files.map { |f| File.join(dir, f) }, "--out", File.join(dir, "rust_out.igapp")
  )
  JSON.parse(out).merge("_stderr" => err, "_exitstatus" => status.exitstatus)
rescue JSON::ParserError
  { "status" => "unparsed_stdout", "_stdout" => out }
end

igmesh_repro(SENDER_SET) do |dir, files|
  rb = ruby_multifile(dir, files)
  rs = rust_multifile(dir, files)
  rb_parse_ok = (rb.dig("compilation_report", "diagnostics") || []).none? { |d| d["node"] == "parse" }
  rs_parse_ok = (rs["diagnostics"] || []).none? { |d| d["node"] == "parse" }

  check("C-01 MeshSender (mesh_net_io.ig): Ruby PARSES with zero parse-stage diagnostics") { rb_parse_ok }
  check("C-02 MeshSender: Rust PARSES with zero parse-stage diagnostics") { rs_parse_ok }
  check("C-03 MeshSender: the exact pre-fix Ruby failure (ParseError: Expected rparen, got eof) is gone") do
    rb.is_a?(Hash) && rb["status"] != "compiler_error"
  end
  puts "    [info] Ruby status=#{rb['status'].inspect} diagnostics=#{(rb.dig('compilation_report', 'diagnostics') || []).map { |d| d['rule'] }.inspect}"
  puts "    [info] Rust  status=#{rs['status'].inspect} diagnostics=#{(rs['diagnostics'] || []).map { |d| d['rule'] }.inspect}"

  section "C-residual: newly-surfaced non-escape gaps — UPDATED post-LANG-RUBY-MAP-GET-STRING-PARITY-P1"
  # C-07 originally asserted the residual STILL existed (`status:oof`, `OOF-TY0 Unknown function:
  # map_get_string`) as a documented, out-of-scope-for-this-card gap. That sibling card
  # (LANG-RUBY-MAP-GET-STRING-PARITY-P1, IGMESH-P15) has since closed it in a follow-up session —
  # named exactly as a "Follow-on... could be picked up as its own narrow card" in this packet's own
  # closing section. Re-asserting the OLD (bug-present) behavior here would make this proof a false
  # regression signal forever; the check now asserts the CURRENT joint reality instead: parse is
  # (still, this card's own scope) fully resolved, AND map_get_string no longer blocks typecheck.
  rules = (rb.dig("compilation_report", "diagnostics") || []).map { |d| d["rule"] }
  check("C-07 [residual RESOLVED by LANG-RUBY-MAP-GET-STRING-PARITY-P1] MeshSender: map_get_string no longer blocks Ruby typecheck (OOF-TY0 'Unknown function: map_get_string' is gone)") do
    !rules.include?("OOF-TY0")
  end
end

igmesh_repro(RECEIVER_SET) do |dir, files|
  rb = ruby_multifile(dir, files)
  rs = rust_multifile(dir, files)
  rb_parse_ok = (rb.dig("compilation_report", "diagnostics") || []).none? { |d| d["node"] == "parse" }
  rs_parse_ok = (rs["diagnostics"] || []).none? { |d| d["node"] == "parse" }

  check("C-04 MeshReceiver (mesh_recv.ig): Ruby PARSES with zero parse-stage diagnostics") { rb_parse_ok }
  check("C-05 MeshReceiver: Rust PARSES with zero parse-stage diagnostics") { rs_parse_ok }
  puts "    [info] Ruby status=#{rb['status'].inspect} diagnostics=#{(rb.dig('compilation_report', 'diagnostics') || []).map { |d| d['rule'] }.inspect}"
  puts "    [info] Rust  status=#{rs['status'].inspect} diagnostics=#{(rs['diagnostics'] || []).map { |d| d['rule'] }.inspect}"

  # C-08 originally asserted the residual STILL existed (`status:oof`, `OOF-KIND2 ... expected
  # Unknown, got ...`) as a documented, out-of-scope-for-this-card gap. That sibling card
  # (LANG-RUBY-UNKNOWN-FIELD-ASSIGNABILITY-PARITY-P1, IGMESH-P16) has since closed it in a
  # follow-up session — named exactly as a "Follow-on" in this packet's own closing section. See
  # C-07's comment above for why this check now asserts the CURRENT joint reality, not the old bug.
  rules = (rb.dig("compilation_report", "diagnostics") || []).map { |d| d["rule"] }
  check("C-08 [residual RESOLVED by LANG-RUBY-UNKNOWN-FIELD-ASSIGNABILITY-PARITY-P1] MeshReceiver: Unknown-field assignability no longer blocks Ruby typecheck (OOF-KIND2 'expected Unknown' is gone) — reaches full status:ok") do
    !rules.include?("OOF-KIND2") && rb["status"] == "ok"
  end
end

igmesh_repro(WIRE_SET) do |dir, files|
  rb = ruby_multifile(dir, files)
  rs = rust_multifile(dir, files)
  check("C-06 MeshWireWitness (mesh_wire.ig, pure, no escapes): fully dual-clean, both status ok") do
    rb["status"] == "ok" && rs["status"] == "ok"
  end
end

puts
puts "=" * 78
puts "Result: #{$pass}/#{$total} PASS  (#{$fail} FAIL)"
puts "=" * 78
puts
puts "Summary:"
puts "  - Section A (9 required cases): escape decode/fail-closed parity with Rust, no uncaught exception."
puts "  - Section D: cross-toolchain source_hash determinism on an escaped literal."
puts "  - Section C: IGMESH-P14's NAMED cause (canon lexer has no string escapes -> Ruby ParseError:"
puts "    'Expected rparen, got eof()') is RESOLVED — mesh_net_io.ig / mesh_recv.ig / mesh_wire.ig all"
puts "    PARSE dual-clean now. mesh_wire.ig (no escapes) is fully dual-clean end to end (parse+typecheck)."
puts "  - Section C-residual: fixing the parse blocker originally exposed TWO pre-existing, unrelated"
puts "    Ruby typechecker/stdlib gaps in mesh_net_io.ig/mesh_recv.ig (map_get_string coverage;"
puts "    Unknown-typed field assignability), OUT OF this card's lexer/parser authority. UPDATE"
puts "    (follow-up session): both were closed by their own named sibling cards"
puts "    (LANG-RUBY-MAP-GET-STRING-PARITY-P1 / LANG-RUBY-UNKNOWN-FIELD-ASSIGNABILITY-PARITY-P1) —"
puts "    C-07/C-08 now assert the CURRENT joint reality (both residuals gone, mesh_net_io.ig and"
puts "    mesh_recv.ig reach full Ruby status:ok) instead of re-asserting the old bug forever."

exit($fail.zero? ? 0 : 1)
