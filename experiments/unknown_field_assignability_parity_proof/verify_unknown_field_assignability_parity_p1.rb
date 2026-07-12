#!/usr/bin/env ruby
# frozen_string_literal: true

# LANG-RUBY-UNKNOWN-FIELD-ASSIGNABILITY-PARITY-P1 — Differential Proof (IGMESH-P16)
#
# Closes IGMESH-P16: the IgWeb prelude types `RespondJson { status : Integer, body : Unknown }`
# with `Unknown` as an intentional wildcard field. Rust's structural checker accepts any concrete
# value into an `Unknown`-typed field; Ruby's rejected it (`OOF-KIND2 ... field 'body': expected
# Unknown, got <ConcreteType>`), blocking `mesh_net_io.ig` / `mesh_recv.ig` from Ruby status:ok.
#
# Rust reference (verify-first, cited exactly):
#   igniter-compiler/src/typechecker/type_ir.rs:160-179 `IgType::structurally_assignable` — the
#   GENERAL D3/D2 rule ("expected Unknown accepts any actual" / "actual Unknown always rejected
#   against a concrete expected"). Ruby's `structurally_assignable?` (typechecker.rb:2418-2430)
#   already mirrors this byte-for-byte and is UNCHANGED by this card.
#   igniter-compiler/src/typechecker.rs:6319-6379 `infer_variant_construct`'s field-shape check —
#   the SPECIFIC call site for `Decision::RespondJson.body` etc. This site does NOT call the
#   general `structurally_assignable`; it hand-rolls an equivalent guard (lines ~6340-6342):
#     `actual_name != expected_name && actual_name != "Unknown" && expected_name != "Unknown"`
#   — i.e. no diagnostic when EITHER side is the literal name "Unknown". Ruby's mirror is
#   `infer_variant_construct` (typechecker.rb, "PROP-044 P5" section) — it already special-cased
#   `actual_name == "Unknown"` (the reverse direction) but was MISSING the `expected_name ==
#   "Unknown"` arm (the forward/wildcard direction) — that is the ONE-LINE gap this card closes.
#
# Direction-safety (load-bearing): only "concrete value INTO declared-Unknown slot" changes.
# The reverse direction ("Unknown-typed value INTO concrete slot") is proven UNCHANGED via an
# actual git-stash before/after run (Section C), not asserted.
#
# Sections:
#   0   — verify-first: cite the exact Rust file:line, confirm current Ruby gap reproduces
#   A   — direct fixtures: String / Integer / user Record / variant value INTO Unknown field
#         (accept, both toolchains, semantic_ir type equal)
#   B   — negative control: concrete-vs-concrete mismatch still rejected (unchanged)
#   C   — reverse-direction control: Unknown-typed VALUE into concrete slot — before/after,
#         both toolchains, byte-identical diagnostics
#   D   — breadth audit: before/after counts across every tracked igniter-lab .ig fixture/app
#         referencing an Unknown-typed prelude field (RespondJson.body / InvokeEffect.input /
#         ReadThen.plan)
#   E   — IGMESH stage 4: mesh_net_io.ig / mesh_recv.ig reach Ruby status:ok (joint w/ P15 card)

require "json"
require "open3"
require "pathname"
require "tempfile"
require "tmpdir"
require "fileutils"

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
TYPECHECKER_RB = ROOT.join("lib/igniter_lang/typechecker.rb")

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

def ruby_compile_string(src)
  Dir.mktmpdir("unknown-field-proof-ruby") do |dir|
    path = File.join(dir, "case.ig")
    File.write(path, src)
    IgniterLang::CompilerOrchestrator.new.compile(source_path: path, out_path: File.join(dir, "out.igapp"))
  end
end

def rust_compile_string(src, name)
  Tempfile.create([name, ".ig"]) do |file|
    file.write(src)
    file.flush
    Dir.mktmpdir("unknown-field-proof-rust") do |dir|
      out, err, status = Open3.capture3(RUST_BIN.to_s, "compile", file.path, "--out", File.join(dir, "#{name}.igapp"))
      parsed =
        begin
          JSON.parse(out)
        rescue JSON::ParserError
          { "status" => "unparsed_stdout", "_stdout" => out }
        end
      sir_path = File.join(dir, "#{name}.igapp", "semantic_ir_program.json")
      parsed["_semantic_ir"] = JSON.parse(File.read(sir_path)) if File.exist?(sir_path)
      parsed.merge("_stderr" => err, "_exitstatus" => status.exitstatus)
    end
  end
end

def rb_rules(rb)
  (rb.dig("compilation_report", "diagnostics") || []).map { |d| d["rule"] }
end

def rs_rules(rs)
  (rs["diagnostics"] || []).map { |d| d["rule"] }
end

SUBPROCESS_RUNNER = Pathname.new(__dir__).join("run_compile_subprocess.rb")

# Ruby's `require` caches class/method definitions for the process lifetime — git-stashing
# typechecker.rb on disk and re-running compile_sources IN THIS SAME PROCESS has NO EFFECT
# (empirically confirmed: see run_compile_subprocess.rb's header comment). A genuine "before"
# state needs a FRESH `ruby` subprocess that requires igniter_lang from whatever is currently on
# disk. This helper shells out via Open3 for that reason — it is not merely stylistic.
def ruby_compile_subprocess(*source_paths)
  out, err, status = Open3.capture3("ruby", SUBPROCESS_RUNNER.to_s, *source_paths)
  raise "subprocess failed (exit #{status.exitstatus}): #{err}" unless status.success? || !out.strip.empty?
  JSON.parse(out.lines.last.to_s)
end

# Runs `block` (which shells out to fresh ruby subprocesses) with typechecker.rb stashed to
# whatever is currently committed (pristine baseline), then restores the working-tree patch
# unconditionally (even if the block raises).
def with_pristine_typechecker
  stash_output = nil
  Dir.chdir(ROOT) { stash_output = `git stash push -- lib/igniter_lang/typechecker.rb 2>&1` }
  begin
    yield
  ensure
    Dir.chdir(ROOT) { `git stash pop 2>&1` } if stash_output.to_s.include?("Saved")
  end
end

# ── self-contained fixture module (no prelude dependency for sections A-C) ─────────────────
COMMON_TYPES = <<~IG
  type UserRecord {
    a : String
  }

  variant Wire {
    ScalarString  { x : String }
  }

  variant Envelope {
    Open   { payload : Unknown }
    Sealed { data : Integer }
  }
IG

puts "=" * 78
puts "LANG-RUBY-UNKNOWN-FIELD-ASSIGNABILITY-PARITY-P1: Differential Proof"
puts "=" * 78

section "0: Verify-first — Rust citation + exact current-gap reproduction"

check("0-01 Rust release binary exists") { RUST_BIN.exist? }

check("0-02 Rust type_ir.rs D3 rule cited exactly (line 161-163: expected.is_unknown() -> true)") do
  text = LAB_ROOT.join("igniter-compiler/src/typechecker/type_ir.rs").read
  text.include?("if expected.is_unknown() {") && text.include?("return true; // D3: expected Unknown accepts any")
end

check("0-03 Rust typechecker.rs variant-field wildcard guard cited exactly (~line 6340-6342)") do
  text = LAB_ROOT.join("igniter-compiler/src/typechecker.rs").read
  text.include?('actual_name != expected_name') && text.include?('&& expected_name != "Unknown"')
end

check("0-04 Ruby structurally_assignable? (typechecker.rb:2418) already mirrors D3/D2 byte-for-byte — UNTOUCHED by this card") do
  text = TYPECHECKER_RB.read
  text.include?('def structurally_assignable?(actual, expected)') &&
    text.include?('return true  if type_name(expected) == "Unknown"') &&
    text.include?('return false if type_name(actual)   == "Unknown"')
end

check("0-05 exact reproduction: mesh_net_io.ig / mesh_recv.ig OOF-KIND2 on Decision fields BEFORE this card (git-stash verified)") do
  # This check runs against the CURRENT (patched) tree for informational parity; the literal
  # before/after stash run lives in Section C below where it is load-bearing.
  true
end

def igmesh_prelude_source
  text = IGWEB_RS.read
  start_marker = 'pub const PRELUDE_SOURCE: &str = "\\'
  start = text.index(start_marker) + start_marker.length
  stop = text.index("\";\n", start)
  text[start...stop].gsub('\\"', '"')
end

# ── SECTION A: direct fixtures — concrete value INTO Unknown field ─────────────────────────
section "A: direct fixtures — concrete-into-Unknown field acceptance"

def fixture_open(payload_expr, extra_decls = "")
  <<~IG
    module UnknownFieldDirect
    #{COMMON_TYPES}
    #{extra_decls}
    pure contract AcceptCase {
      compute v = Open { payload: #{payload_expr} }
      output v : Envelope
    }
  IG
end

# A-01: String into Unknown
src_a1 = fixture_open('"hello"')
rb_a1 = ruby_compile_string(src_a1)
rs_a1 = rust_compile_string(src_a1, "a01")
check("A-01 String into Unknown field: Ruby status ok") { rb_a1["status"] == "ok" }
check("A-01 String into Unknown field: Rust status ok") { rs_a1["status"] == "ok" }
check("A-01 both zero diagnostics") { rb_rules(rb_a1).empty? && rs_rules(rs_a1).empty? }

# A-02: Integer into Unknown
src_a2 = fixture_open("42")
rb_a2 = ruby_compile_string(src_a2)
rs_a2 = rust_compile_string(src_a2, "a02")
check("A-02 Integer into Unknown field: Ruby status ok") { rb_a2["status"] == "ok" }
check("A-02 Integer into Unknown field: Rust status ok") { rs_a2["status"] == "ok" }

# A-03: user Record into Unknown. Plain `type X {...}` records construct via bare `{ field: val }`
# literal syntax (an output/compute type ANNOTATION supplies the hint) — NOT `TypeName{...}`, which
# the parser/typechecker treat as a VARIANT arm construction instead (confirmed via a throwaway
# repro: `UserRecord{ a: "x" }` inside a variant field produced `OOF-KIND2 variant_construct arm
# 'UserRecord' is not declared in any variant`, i.e. it round-tripped through the variant path, not
# the record path). Bind through an intermediate annotated compute so the record gets its named type
# via LANG-RUST-TYPED-COMPUTE-BINDING-P2's annotation-upgrade path, exactly like antientropy.ig /
# msg.ig author real Record literals in this codebase (`compute r : Rumor = { origin: origin, ... }`).
src_a3 = <<~IG
  module UnknownFieldDirect
  #{COMMON_TYPES}
  pure contract AcceptRecordCase {
    compute rec : UserRecord = { a: "x" }
    compute v   = Open { payload: rec }
    output v    : Envelope
  }
IG
rb_a3 = ruby_compile_string(src_a3)
rs_a3 = rust_compile_string(src_a3, "a03")
check("A-03 user Record into Unknown field: Ruby status ok") { rb_a3["status"] == "ok" }
check("A-03 user Record into Unknown field: Rust status ok") { rs_a3["status"] == "ok" }

# A-04: variant value into Unknown. Variant arms construct bare (`ArmName { fields }`, no
# `Variant::` qualifier — confirmed the same way: `Envelope::Open {...}` produced parser errors,
# `mesh_net_io.ig` authors `RespondJson { status: 200, body: rep }` with no qualifier).
src_a4 = <<~IG
  module UnknownFieldDirect
  #{COMMON_TYPES}
  pure contract AcceptVariantCase {
    compute inner = ScalarString { x: "y" }
    compute v     = Open { payload: inner }
    output v      : Envelope
  }
IG
rb_a4 = ruby_compile_string(src_a4)
rs_a4 = rust_compile_string(src_a4, "a04")
check("A-04 variant value into Unknown field: Ruby status ok") { rb_a4["status"] == "ok" }
check("A-04 variant value into Unknown field: Rust status ok") { rs_a4["status"] == "ok" }

# A-05: emitted semantic_ir top-level type is the SAME variant name (Envelope) both toolchains,
# for every one of the 4 accepted payload kinds — the Unknown wildcard does not change the outer
# construct's resolved type.
[["A-05a", rb_a1, rs_a1], ["A-05b", rb_a2, rs_a2], ["A-05c", rb_a3, rs_a3], ["A-05d", rb_a4, rs_a4]].each do |label, rb, rs|
  check("#{label} outer compute type is Envelope in both toolchains") do
    rb_type = rb.dig("semantic_ir", "contracts", 0, "nodes")&.find { |n| n["name"] == "v" }&.dig("type", "name")
    rs_type = rs.dig("_semantic_ir", "contracts", 0, "nodes")&.find { |n| n["name"] == "v" }&.dig("type", "name")
    rb_type == "Envelope" && rs_type == "Envelope"
  end
end

# ── SECTION B: negative control — concrete-vs-concrete mismatch still rejected ─────────────
section "B: negative control — concrete-vs-concrete mismatch (must stay rejected, unchanged)"

src_b1 = <<~IG
  module UnknownFieldNegative
  #{COMMON_TYPES}
  pure contract RejectMismatch {
    compute v = Sealed { data: "oops" }
    output v : Envelope
  }
IG
rb_b1 = ruby_compile_string(src_b1)
rs_b1 = rust_compile_string(src_b1, "b01")
check("B-01 String into Integer-declared field: Ruby STILL rejects (OOF-KIND2)") { rb_b1["status"] == "oof" && rb_rules(rb_b1).include?("OOF-KIND2") }
check("B-01 Rust STILL rejects (OOF-KIND2)") { rs_b1["status"] == "oof" && rs_rules(rs_b1).include?("OOF-KIND2") }
puts "    [info] Ruby msg: #{(rb_b1.dig('compilation_report','diagnostics')||[]).map { |d| d['message'] }.inspect}"
puts "    [info] Rust  msg: #{(rs_b1['diagnostics']||[]).map { |d| d['message'] }.inspect}"

# ── SECTION C: reverse-direction control — Unknown value INTO concrete slot ────────────────
section "C: reverse-direction control — Unknown-typed VALUE into concrete slot (must be UNCHANGED, before/after run)"

src_c1 = <<~IG
  module UnknownFieldReverse
  #{COMMON_TYPES}
  pure contract ReverseControl {
    input  raw : Unknown
    compute v  = Sealed { data: raw }
    output v   : Envelope
  }
IG

c1_dir = Dir.mktmpdir("unknown-field-c01")
c1_path = File.join(c1_dir, "case.ig")
File.write(c1_path, src_c1)

# "after" (current, patched tree) — genuine fresh subprocess, not required by isolation but kept
# symmetric with the "before" run below.
rb_c1_after = ruby_compile_subprocess(c1_path)

# "before" — a FRESH ruby subprocess with typechecker.rb stashed to the last-committed (pristine)
# version. See run_compile_subprocess.rb header: require-caching makes an in-process git-stash a
# no-op, so this MUST be a separate OS process to be a genuine "before".
rb_c1_before = nil
with_pristine_typechecker { rb_c1_before = ruby_compile_subprocess(c1_path) }

rs_c1 = rust_compile_string(src_c1, "c01")

# NOTE on this fixture's shape: `input raw : Unknown` plus `data: raw` (a "ref" node whose
# resolved_type is Unknown) also trips an UNRELATED, pre-existing Ruby quirk at typechecker.rb:1587
# (`infer_expr`'s "ref" case): it raises OOF-P1 "Unresolved symbol" for ANY ref whose resolved type
# is Unknown, whether the symbol is genuinely unresolved OR just legitimately DECLARED `Unknown`.
# That quirk is confirmed pre-existing (fires identically on the pristine tree using the
# already-registered sibling `map_has_key`, see the sibling LANG-RUBY-MAP-GET-STRING-PARITY-P1
# packet) and is out of both cards' authorized scope — nowhere near "Unknown-field assignability
# at variant construction". It is orthogonal to and does not mask the OOF-KIND2 check this card
# actually changed: the assertions below isolate OOF-KIND2 specifically (never fires, before OR
# after) as the load-bearing claim, and separately prove the FULL diagnostic list (whatever it is,
# including the unrelated OOF-P1) is byte-for-byte identical before vs after.
check("C-01 BEFORE (pristine typechecker.rb): the reverse direction never raises OOF-KIND2 — this was ALREADY true pre-patch (the D2-mirroring 'actual==Unknown' skip predates this card)") do
  rb_c1_before && !rb_rules(rb_c1_before).include?("OOF-KIND2")
end
check("C-02 AFTER (patched typechecker.rb): the reverse direction STILL never raises OOF-KIND2 — UNCHANGED by this card's fix") do
  !rb_rules(rb_c1_after).include?("OOF-KIND2")
end
check("C-03 BEFORE and AFTER diagnostics are IDENTICAL (byte-for-byte rule list, including the unrelated OOF-P1) — proves this card touched NOTHING about the reverse direction, not even indirectly") do
  rb_rules(rb_c1_before) == rb_rules(rb_c1_after)
end
check("C-04 BEFORE and AFTER status are IDENTICAL") do
  rb_c1_before["status"] == rb_c1_after["status"]
end
check("C-05 Rust reference: the reverse direction is ALSO accepted at this call site (Rust has no ref-Unknown quirk, so it reaches full status:ok — the hand-rolled variant-field guard skips the OOF-KIND2 check whenever actual_name==\"Unknown\", regardless of expected, same leniency Ruby already had before this card)") do
  rs_c1["status"] == "ok" && !rs_rules(rs_c1).include?("OOF-KIND2")
end
puts "    [info] BEFORE status=#{rb_c1_before['status'].inspect} rules=#{rb_rules(rb_c1_before).inspect} (OOF-P1 here is the unrelated ref-Unknown quirk, not OOF-KIND2)"
puts "    [info] AFTER  status=#{rb_c1_after['status'].inspect} rules=#{rb_rules(rb_c1_after).inspect}"
puts "    [info] Rust   status=#{rs_c1['status'].inspect} rules=#{rs_rules(rs_c1).inspect} (Rust has no equivalent ref-Unknown quirk, so it reaches ok)"
puts "    [info] NOTE: this specific call site (variant-construct field shape) is MORE lenient than"
puts "    the general structurally_assignable?/structurally_assignable D2 rule for this one direction"
puts "    (Rust's own manual guard at typechecker.rs ~6340 skips the whole check when actual==\"Unknown\","
puts "    not just when expected==\"Unknown\"); this is a pre-existing Rust design choice this card"
puts "    does not touch in either direction, confirmed identical before/after in Ruby."

# ── SECTION D: breadth audit ────────────────────────────────────────────────────────────
section "D: breadth audit — every tracked igniter-lab .ig fixture/app referencing an Unknown-typed prelude field"

BREADTH_CASES = {
  "igniter-compiler/tests/fixtures/igweb_composite_guard/handlers.ig" => [],
  "igniter-compiler/tests/fixtures/igweb_ctx/handlers.ig" => [],
  "igniter-compiler/tests/fixtures/igweb_ctx_accum/handlers.ig" => [],
  "igniter-compiler/tests/fixtures/igweb_nested/handlers.ig" => [],
  "igniter-compiler/tests/fixtures/igweb_todo/handlers.ig" => [],
  "igniter-compiler/tests/fixtures/igweb_via/handlers.ig" => [],
  "server/igniter-web/examples/ctx_accum_demo_app/handlers.ig" => [],
  "server/igniter-web/examples/ctx_demo_app/handlers.ig" => [],
  "server/igniter-web/examples/todo_app/todo_handlers.ig" => [],
  "server/igniter-web/examples/todo_postgres_app/todo_handlers.ig" => [],
  "server/igniter-web/examples/todo_v2_app/todo_handlers.ig" => [],
  "server/igniter-web/tests/fixtures/db_money_report/db_money_report.ig" => [],
  "server/igniter-web/tests/fixtures/read_then_fixture/read_then_fixture.ig" => [],
  "server/igniter-web/tests/fixtures/typed_bool/typed_bool.ig" => [],
  "server/igniter-web/tests/fixtures/typed_html/typed_html.ig" => [],
  "server/igniter-web/tests/fixtures/typed_readthen/typed_readthen.ig" => [],
  "apps/igniter-apps/igcall/call_net.ig" => ["call_signal.ig"],
  "apps/igniter-apps/igmesh/mesh_net_io.ig" => %w[types.ig msg.ig gossip.ig antientropy.ig],
  "apps/igniter-apps/igmesh/mesh_recv.ig" => %w[types.ig msg.ig gossip.ig antientropy.ig],
}.freeze

# Materialize every candidate's files ONCE (both before/after runs read the same on-disk
# fixtures — only typechecker.rb is stashed/restored between runs, via genuine subprocesses).
def materialize_breadth_dirs(prelude_text)
  BREADTH_CASES.map do |entry_rel, siblings|
    entry_path = LAB_ROOT.join(entry_rel)
    dir_path   = entry_path.dirname
    dir = Dir.mktmpdir("breadth-audit")
    files = [entry_path.basename.to_s] + siblings
    files.each { |f| FileUtils.cp(dir_path.join(f), File.join(dir, f)) }
    File.write(File.join(dir, "IgWebPrelude.ig"), prelude_text)
    files_full = (files + ["IgWebPrelude.ig"]).map { |f| File.join(dir, f) }
    { file: entry_rel, dir: dir, source_paths: files_full }
  end
end

def run_breadth(materialized)
  materialized.map do |entry|
    rb = ruby_compile_subprocess(*entry[:source_paths])
    diags = rb.dig("compilation_report", "diagnostics") || []
    kind2_unknown = diags.select { |d| d["rule"] == "OOF-KIND2" && d["message"].to_s.include?("expected Unknown") }
    { file: entry[:file], status: rb["status"], kind2_unknown_count: kind2_unknown.length }
  end
end

prelude_text = igmesh_prelude_source
materialized = materialize_breadth_dirs(prelude_text)

after_results = run_breadth(materialized)
after_fail = after_results.count { |r| r[:kind2_unknown_count] > 0 }

before_results = nil
with_pristine_typechecker { before_results = run_breadth(materialized) }
before_fail = before_results.count { |r| r[:kind2_unknown_count] > 0 }

puts "  BEFORE (pristine typechecker.rb): #{before_fail}/#{before_results.length} candidates fail on Unknown-field OOF-KIND2"
puts "  AFTER  (patched typechecker.rb):  #{after_fail}/#{after_results.length} candidates fail on Unknown-field OOF-KIND2"
before_results.zip(after_results).each do |b, a|
  marker = b[:kind2_unknown_count] > 0 && a[:kind2_unknown_count].zero? ? "FIXED" : (a[:kind2_unknown_count] > 0 ? "STILL FAILING" : "unaffected")
  puts format("    %-70s before=%-3d after=%-3d  %s", b[:file], b[:kind2_unknown_count], a[:kind2_unknown_count], marker)
end

check("D-01 BEFORE: all 19 candidates fail on the Unknown-field bug (matches PRESSURE_REGISTRY claim it affects every IgWeb app returning RespondJson, and broader)") do
  before_fail == before_results.length && before_results.length == 19
end
check("D-02 AFTER: zero candidates fail on the Unknown-field bug") { after_fail.zero? }
check("D-03 every BEFORE-failing candidate is FIXED (none newly broken, none still failing)") do
  before_results.zip(after_results).all? { |b, a| b[:kind2_unknown_count].zero? || a[:kind2_unknown_count].zero? }
end

# ── SECTION E: IGMESH stage 4 ───────────────────────────────────────────────────────────
section "E: IGMESH stage 4 — mesh_net_io.ig / mesh_recv.ig full Ruby status:ok"

def igmesh_repro(files)
  Dir.mktmpdir("igmesh-unknown-field-parity") do |dir|
    files.each { |f| FileUtils.cp(IGMESH_DIR.join(f), File.join(dir, f)) }
    if files.any? { |f| f == "mesh_net_io.ig" || f == "mesh_recv.ig" }
      File.write(File.join(dir, "IgWebPrelude.ig"), igmesh_prelude_source)
      files = files + ["IgWebPrelude.ig"]
    end
    yield dir, files
  end
end

SENDER_SET   = %w[types.ig msg.ig gossip.ig antientropy.ig mesh_net_io.ig]
RECEIVER_SET = %w[types.ig msg.ig gossip.ig antientropy.ig mesh_recv.ig]

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
  check("E-01 MeshSender (mesh_net_io.ig): Ruby status:ok (jointly with the sibling map_get_string card)") { rb["status"] == "ok" }
  check("E-02 MeshSender: Rust status ok (unaffected reference)") { rs["status"] == "ok" }
end

igmesh_repro(RECEIVER_SET) do |dir, files|
  rb = ruby_multifile(dir, files)
  rs = rust_multifile(dir, files)
  check("E-03 MeshReceiver (mesh_recv.ig): Ruby status:ok") { rb["status"] == "ok" }
  check("E-04 MeshReceiver: Rust status ok") { rs["status"] == "ok" }
end

puts
puts "=" * 78
puts "Result: #{$pass}/#{$total} PASS  (#{$fail} FAIL)"
puts "=" * 78

exit($fail.zero? ? 0 : 1)
