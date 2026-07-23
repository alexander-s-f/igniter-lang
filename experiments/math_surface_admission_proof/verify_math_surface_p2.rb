# frozen_string_literal: true
#
# LANG-STDLIB-MATH-SURFACE-CANON-ADMISSION-P2 — dual-toolchain proof matrix for the
# `stdlib.math` admission (ch8 §8.15).
#
# Every row is MEASURED by running the real dual-toolchain front door
# (`igniter-lab/bin/igniter source check --toolchain both`) against a fixture in this
# directory. Nothing here asserts from prose: a row that cannot be produced by the live
# binaries fails.
#
#   ruby experiments/math_surface_admission_proof/verify_math_surface_p2.rb
#
# Row groups:
#   A. 15/15 admitted operations typecheck dual-clean (scalar readings).
#   B. Negative diagnostics are BYTE-IDENTICAL across the two toolchains — the admission
#      owns the refusal text, not just the accept path.
#   C. The `min`/`max` OVERLOAD is additive-only. The bare names are declared twice in canon
#      `.ig` source (stdlib.Math math.ig:41-42 scalar; stdlib.Collections collections.ig:20-21
#      aggregate). Rust routes by first-argument type. Ruby canon has no aggregate arm, so the
#      aggregate shape must still refuse EXACTLY as it did before this card
#      (`OOF-TY0: Unknown function: min`) — never an OOF-MATH2 that would declare a live
#      `collections.ig` declaration a type error.

require "open3"
require "pathname"

LANG_DIR  = Pathname.new(File.expand_path("../..", __dir__))
FIXTURES  = Pathname.new(__dir__)
IGNITER   = LANG_DIR.parent / "igniter-lab/bin/igniter"

abort "front door not found: #{IGNITER}" unless IGNITER.exist?

GREEN = "\e[32m"
RED   = "\e[31m"
RESET = "\e[0m"

Result = Struct.new(:verdict, :rust, :ruby, :raw)

# Run the dual front door on one fixture and split diagnostics per plane.
def check(fixture)
  out, _err, _st = Open3.capture3(IGNITER.to_s, "source", "check", (FIXTURES / fixture).to_s,
                                  "--toolchain", "both")
  verdict = out.lines.first.to_s[/check: (\w+)/, 1]
  plane   = nil
  rust    = []
  ruby    = []
  out.lines.each do |line|
    case line
    when /^\s{2}rust_lab:/  then plane = rust
    when /^\s{2}ruby_canon:/ then plane = ruby
    when /^\s{4}(OOF-\S+|UNKNOWN):/ then plane&.push(line.strip)
    end
  end
  Result.new(verdict, rust, ruby, out)
end

$failures = []

def row(label)
  ok, detail = yield
  puts format("  %s %-52s %s", ok ? "#{GREEN}PASS#{RESET}" : "#{RED}FAIL#{RESET}", label, detail)
  $failures << label unless ok
end

# ── Group A — 15/15 admitted operations typecheck dual-clean ────────────────────────────
ADMITTED = %w[
  abs min max clamp sign
  sin cos sqrt pi
  det_sin det_cos det_sqrt det_ln det_exp det_tan
].freeze

puts "\nA. admitted surface typechecks dual-clean"
r = check("math_surface_15.ig")
row("15/15 operations, both toolchains clean") do
  ok = r.verdict == "clean" && r.rust.empty? && r.ruby.empty?
  [ok, "verdict=#{r.verdict} rust=#{r.rust.size} ruby=#{r.ruby.size}"]
end
row("fixture exercises every admitted name") do
  src = (FIXTURES / "math_surface_15.ig").read
  missing = ADMITTED.reject { |n| src.match?(/(?<![a-z_])#{Regexp.escape(n)}\(/) }
  [missing.empty?, missing.empty? ? "#{ADMITTED.size} names" : "missing=#{missing.join(',')}"]
end

# ── Group B — negative diagnostics byte-identical across toolchains ─────────────────────
puts "\nB. refusal text is owned by the admission (byte-identical across toolchains)"
n = check("math_surface_negatives.ig")
row("both toolchains refuse") do
  [n.verdict == "refused", "verdict=#{n.verdict}"]
end
row("diagnostic sets are byte-identical") do
  [n.rust.sort == n.ruby.sort, "rust=#{n.rust.size} ruby=#{n.ruby.size}"]
end
{
  "OOF-MATH3 mixed numeric types" =>
    'OOF-MATH3: min: mixed numeric types ["Integer", "Float"] (no implicit coercion)',
  "OOF-MATH1 arity"               => "OOF-MATH1: sqrt: expected 1 argument, got 2",
  "OOF-MATH2 argument type"       => "OOF-MATH2: sqrt: argument must be Float, got String"
}.each do |label, expected|
  row(label) do
    [n.rust.include?(expected) && n.ruby.include?(expected), expected[0, 44]]
  end
end

# ── Group C — the min/max overload stays additive-only ──────────────────────────────────
puts "\nC. min/max overload: admission is additive-only"
o = check("minmax_overload.ig")
row("scalar reading resolves on both toolchains") do
  # The only surviving Ruby diagnostic must concern the AGGREGATE call; the scalar
  # `min(7, 3)` bound to the output must typecheck.
  scalar_noise = o.ruby.grep(/OOF-MATH/)
  [scalar_noise.empty? && o.rust.empty?, "rust=#{o.rust.size} ruby_math_errors=#{scalar_noise.size}"]
end
row("Rust routes the aggregate shape by first-arg type") do
  [o.rust.empty?, "rust clean (is_legacy_minmax_aggregate)"]
end
row("Ruby aggregate refusal is the PRE-CARD one, not a new OOF-MATH") do
  expected = ["OOF-TY0: Unknown function: min"]
  [o.ruby == expected, o.ruby.inspect]
end
row("no OOF-MATH2 ever calls a live collections.ig def a type error") do
  offending = o.ruby.grep(/OOF-MATH2.*got Collection|OOF-MATH2.*got Symbol/)
  [offending.empty?, offending.empty? ? "none" : offending.join(" | ")]
end

# ── Group D — the overload resolves to the right SIR IDENTITY, not just the right type ──
#
# This group exists because the first implementation of this admission passed every row above
# and was still WRONG. The Rust emitter has no symbol-type table, so qualifying `min`/`max`
# there rewrote the AGGREGATE call `min(xs, :v)` into `stdlib.math.min`; it typechecked clean on
# both toolchains and only failed at VM eval with "min expects two Integer or two Float
# arguments". Type-agreement is not identity-agreement — so identity is measured directly, from
# the emitted SIR of both toolchains, and the aggregate is executed end-to-end.
require "json"
require "tmpdir"

RUST_IGC = LANG_DIR.parent / "igniter-lab/igniter-compiler/target/debug/igniter_compiler"

def sir_call_names(igapp_dir)
  sir = Pathname.new(igapp_dir) / "semantic_ir_program.json"
  return [] unless sir.exist?

  names = []
  walk = lambda do |node|
    case node
    when Hash
      names << node["fn"] if node["kind"] == "call" && node["fn"]
      node.each_value { |v| walk.call(v) }
    when Array then node.each { |v| walk.call(v) }
    end
  end
  walk.call(JSON.parse(sir.read))
  names
end

# Rust plane: compile with the managed debug fleet binary and read back the SIR identities.
def rust_sir(fixture)
  return nil unless RUST_IGC.exist?

  Dir.mktmpdir do |d|
    out = File.join(d, "o.igapp")
    _o, _e, _s = Open3.capture3(RUST_IGC.to_s, "compile", (FIXTURES / fixture).to_s, "--out", out)
    return sir_call_names(out).grep(/\A(stdlib\.math\.)?m(in|ax)\z/).uniq.sort
  end
end

# Ruby plane: drive the canon orchestrator in-process.
def ruby_sir(fixture)
  $LOAD_PATH.unshift((LANG_DIR / "lib").to_s)
  require "igniter_lang"
  Dir.mktmpdir do |d|
    r = IgniterLang::CompilerOrchestrator.new.compile_sources(
      source_paths: [(FIXTURES / fixture).to_s], out_path: File.join(d, "o.igapp")
    )
    return nil unless r["status"] == "ok"

    sir_call_names(r.dig("result", "igapp_path") || File.join(d, "o.igapp"))
      .grep(/\A(stdlib\.math\.)?m(in|ax)\z/).uniq.sort
  end
rescue StandardError
  nil
end

puts "\nD. the overload resolves to the right SIR IDENTITY on both toolchains"
scalar_rust = rust_sir("minmax_scalar.ig")
scalar_ruby = ruby_sir("minmax_scalar.ig")
row("scalar reading carries the canon stdlib.math.* identity") do
  want = ["stdlib.math.max", "stdlib.math.min"]
  [scalar_rust == want && scalar_ruby == want, "rust=#{scalar_rust.inspect} ruby=#{scalar_ruby.inspect}"]
end
row("both toolchains emit the SAME identity (no silent SIR drift)") do
  [!scalar_rust.nil? && scalar_rust == scalar_ruby, "#{scalar_rust.inspect} == #{scalar_ruby.inspect}"]
end

agg_rust = rust_sir("minmax_aggregate.ig")
row("aggregate reading keeps the BARE spelling its own owner dispatches") do
  # The regression lock: if this ever reads `stdlib.math.min`, the emitter has started
  # qualifying by name again and the VM will refuse the call at eval.
  [agg_rust == %w[max min], agg_rust.inspect]
end
row("aggregate executes end-to-end on the VM (span = 1.5 - -2.5)") do
  out, _e, _s = Open3.capture3(
    { "IGNITER_IGC_BIN" => RUST_IGC.to_s },
    (LANG_DIR.parent / "igniter-lab/bin/igniter").to_s,
    "run", (FIXTURES / "minmax_aggregate.ig").to_s, "--entry", "AggSpan"
  )
  got = out.lines.map { |l| (JSON.parse(l)["result"] rescue nil) }.compact.last
  [got == 4.0, "result=#{got.inspect}"]
end

puts
if $failures.empty?
  puts "#{GREEN}math surface P2: all rows pass#{RESET}"
else
  puts "#{RED}math surface P2: #{$failures.size} row(s) failed#{RESET}"
  $failures.each { |f| puts "  - #{f}" }
  exit 1
end
