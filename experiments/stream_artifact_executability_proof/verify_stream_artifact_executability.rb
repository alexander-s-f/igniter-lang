#!/usr/bin/env ruby
# frozen_string_literal: true

# LAB-IGNITER-STREAM-ARTIFACT-EXECUTABILITY-P2 — Ruby-toolchain regression proof.
#
# The stream artifact is EXECUTABLE-OR-REFUSED:
#   A. callable registry — SIR root + contract files carry callables; every
#      fold_stream fn_ref is content-addressed ("lambda/" + SHA256[0,16] over
#      the canonical callable_v1 value) and resolvable; the integer_sum_lambda
#      magic name is retired; non-stream artifacts carry NO callables key.
#   B. bound fidelity — @window_bounded / @count_bounded(n) reach the artifact
#      verbatim with the resolved window_ref; OOF-S5 refuses non-positive n;
#      event_binding is explicit (no fabricated value_path).
#   C. init fidelity — record/collection/scalar inits type via the same static
#      inference compute nodes use and are emitted through the compute-expr path.
#   D. determinability — exactly one window binds explicitly; >1 windows refuse
#      with the OOF-S2 ambiguity law.
#   E. window vocabulary — closed set validated at parse; calendar/session stay
#      valid DECLARATIONS.
#   F. compute-alias unbounded fold_stream fires OOF-S1 like the keyword form.
#   H. delegated experimental runtime refuses any stream-surface artifact with
#      OOF-ST1 at admission (before any evaluate).
#   K. fragment alignment — stream_input_node fragment=escape; fold_stream_node
#      fragment=stream, result_fragment=core.

require "digest"
require "fileutils"
require "json"
require "pathname"

ROOT = Pathname.new(__dir__).join("../..").expand_path
LIB = ROOT.join("lib").to_s
$LOAD_PATH.unshift(LIB) unless $LOAD_PATH.include?(LIB)

require "igniter_lang"
require "igniter_lang/experimental_igc_run"

FIXTURES = Pathname.new(__dir__).join("fixtures")
OUT = Pathname.new(__dir__).join("out")
FileUtils.rm_rf(OUT)
FileUtils.mkdir_p(OUT)

FN_REF_LAW = %r{\Alambda/[0-9a-f]{16}\z}

def compile_fixture(name)
  source = FIXTURES.join("#{name}.ig")
  out = OUT.join("#{name}.igapp")
  result = IgniterLang.compile(source_path: source, out_path: out)
  { result: result, out: out }
end

def parse_fixture(name)
  IgniterLang::ParsedProgram.parse(
    FIXTURES.join("#{name}.ig").read,
    source_path: "experiments/stream_artifact_executability_proof/fixtures/#{name}.ig"
  ).to_h
end

def read_json(path)
  JSON.parse(path.read)
end

def contract_files(igapp_dir)
  igapp_dir.join("contracts").glob("*.json").sort.map { |path| read_json(path) }
end

def stream_nodes_of(contract, kind)
  contract.fetch("stream_nodes", []).select { |node| node.fetch("kind") == kind }
end

def deep_sort(value)
  case value
  when Hash
    value.keys.sort.each_with_object({}) { |key, sorted| sorted[key] = deep_sort(value[key]) }
  when Array
    value.map { |item| deep_sort(item) }
  else
    value
  end
end

def canonical_json(value)
  JSON.generate(deep_sort(value))
end

def diagnostics_of(result)
  result.dig("compilation_report", "diagnostics") || []
end

def check(label, checks, &block)
  result = block.call
  checks << [label, result]
  raise "check failed: #{label}" unless result
end

checks = []

# ── main specimen: callables + real fn_ref + explicit binding ────────────────
main = compile_fixture("stream_exec_main")
check("main stream specimen compiles clean", checks) do
  main.fetch(:result).fetch("status") == "ok"
end

main_sir = read_json(main.fetch(:out).join("semantic_ir_program.json"))
main_contract = contract_files(main.fetch(:out)).first
main_fold = stream_nodes_of(main_contract, "fold_stream_node").first
main_stream = stream_nodes_of(main_contract, "stream_input_node").first
main_window = stream_nodes_of(main_contract, "window_decl_node").first

check("A: SIR root carries the callable registry", checks) do
  main_sir.fetch("callables", {}).any?
end

check("A: fold fn_ref follows the content-address law (magic name retired)", checks) do
  fn_ref = main_fold.fetch("fn_ref")
  fn_ref != "integer_sum_lambda" && fn_ref.match?(FN_REF_LAW)
end

check("A: contract file carries exactly the referenced callable, resolvable", checks) do
  fn_ref = main_fold.fetch("fn_ref")
  entry = main_contract.fetch("callables", {}).fetch(fn_ref, nil)
  entry && entry == main_sir.fetch("callables").fetch(fn_ref) &&
    main_contract.fetch("callables").keys == [fn_ref]
end

check("A: fn_ref recomputes from the callable value (lambda/ + SHA256[0,16])", checks) do
  fn_ref = main_fold.fetch("fn_ref")
  entry = main_sir.fetch("callables").fetch(fn_ref)
  entry.fetch("kind") == "callable_v1" &&
    entry.fetch("params") == %w[acc r] &&
    fn_ref == "lambda/#{Digest::SHA256.hexdigest(canonical_json(entry))[0, 16]}"
end

check("B: window_bounded bound carries the resolved window_ref", checks) do
  main_fold.fetch("bound") == { "kind" => "window_bounded", "window_ref" => "thermal/{device_id}" }
end

check("B: event_binding is explicit and carries NO fabricated value_path", checks) do
  binding = main_fold.fetch("event_binding")
  binding.fetch("value_ref") == "r" && !binding.key?("value_path")
end

check("D: stream_input window_ref == fold bound window_ref == declared window ref", checks) do
  main_stream.fetch("window_ref") == main_fold.fetch("bound").fetch("window_ref") &&
    main_stream.fetch("window_ref") == main_window.fetch("ref")
end

check("K: fragments — stream_input escape / fold stream / result core", checks) do
  sir_nodes = main_sir.fetch("contracts").first.fetch("nodes")
  sir_stream = sir_nodes.find { |node| node.fetch("kind") == "stream_input_node" }
  sir_fold = sir_nodes.find { |node| node.fetch("kind") == "fold_stream_node" }
  sir_stream.fetch("fragment") == "escape" &&
    sir_fold.fetch("fragment") == "stream" &&
    sir_fold.fetch("result_fragment") == "core" &&
    main_fold.fetch("result_fragment") == "core"
end

# ── record init (C law acceptance) ───────────────────────────────────────────
record = compile_fixture("stream_record_init")
check("C: record-literal init COMPILES clean", checks) do
  record.fetch(:result).fetch("status") == "ok"
end

record_fold = stream_nodes_of(contract_files(record.fetch(:out)).first, "fold_stream_node").first
check("C: record init carried faithfully through the compute-expr path", checks) do
  init = record_fold.fetch("init")
  init.fetch("kind") == "record_literal" &&
    init.fetch("resolved_type") == { "name" => "Totals", "params" => [] } &&
    init.fetch("fields").keys.sort == %w[count sum] &&
    record_fold.fetch("result_type_tag") == "Totals"
end

# ── count bound fidelity ─────────────────────────────────────────────────────
count = compile_fixture("stream_count_bounded")
count_fold = stream_nodes_of(contract_files(count.fetch(:out)).first, "fold_stream_node").first
check("B: count_bounded preserves n AND window_ref", checks) do
  count.fetch(:result).fetch("status") == "ok" &&
    count_fold.fetch("bound") ==
      { "kind" => "count_bounded", "n" => 3, "window_ref" => "thermal/{device_id}" }
end

check("B: non-positive count bound refuses with OOF-S5", checks) do
  zero = compile_fixture("stream_count_zero")
  zero.fetch(:result).fetch("status") != "ok" &&
    diagnostics_of(zero.fetch(:result)).any? { |diag| diag.fetch("rule", nil) == "OOF-S5" }
end

# ── determinability: two windows refuse ──────────────────────────────────────
check("D: two windows refuse with the OOF-S2 ambiguity law", checks) do
  two = compile_fixture("stream_two_windows")
  diags = diagnostics_of(two.fetch(:result))
  two.fetch(:result).fetch("status") != "ok" &&
    diags.any? do |diag|
      diag.fetch("rule", nil) == "OOF-S2" &&
        diag.fetch("message", "").include?("ambiguous window binding for stream 'readings'") &&
        diag.fetch("message", "").include?("declare exactly one window")
    end
end

# ── window vocabulary (E law) ────────────────────────────────────────────────
check("E: bogus kind/on_close refuse at parse", checks) do
  bogus = compile_fixture("stream_bogus_vocab")
  messages = diagnostics_of(bogus.fetch(:result)).map { |diag| diag.fetch("message", "") }
  bogus.fetch(:result).fetch("status") != "ok" &&
    messages.any? { |msg| msg.include?("kind must be one of :count, :calendar, :session") } &&
    messages.any? { |msg| msg.include?("on_close must be one of :snapshot, :emit, :discard") }
end

check("E: unknown/extra window option key refuses at parse", checks) do
  extra = compile_fixture("stream_window_extra_key")
  extra.fetch(:result).fetch("status") != "ok" &&
    diagnostics_of(extra.fetch(:result))
      .any? { |diag| diag.fetch("message", "").include?("option 'flavor' is not in the window vocabulary") }
end

check("E: missing on_close refuses at parse", checks) do
  missing = compile_fixture("stream_window_missing_on_close")
  missing.fetch(:result).fetch("status") != "ok" &&
    diagnostics_of(missing.fetch(:result))
      .any? { |diag| diag.fetch("message", "").include?("on_close must be one of") }
end

check("E: calendar window remains a VALID DECLARATION (parses clean)", checks) do
  parse_fixture("stream_calendar_window_decl").fetch("parse_errors").empty?
end

# ── compute-alias unbounded fold (F law) ─────────────────────────────────────
check("F: compute-alias unbounded fold_stream fires OOF-S1 at parse", checks) do
  parsed = parse_fixture("stream_unbounded_compute_alias")
  parsed.fetch("parse_errors").any? { |entry| entry.fetch("rule", nil) == "OOF-S1" }
end

# ── delegated runtime admission (H law) ──────────────────────────────────────
check("H: delegated runtime refuses the stream artifact with OOF-ST1", checks) do
  begin
    IgniterLang::ExperimentalIgcRun.refuse_stream_surface!(main.fetch(:out))
    false
  rescue IgniterLang::ExperimentalIgcRun::RunFailure => e
    e.code == "OOF-ST1" &&
      e.message == "OOF-ST1: artifact declares a stream surface (stream_nodes) " \
                   "but this VM has no stream runtime; admission refused"
  end
end

# ── non-stream byte-compat ───────────────────────────────────────────────────
control = compile_fixture("nonstream_control")
check("A/byte-compat: non-stream artifact carries NO callables key anywhere", checks) do
  control_sir = read_json(control.fetch(:out).join("semantic_ir_program.json"))
  control.fetch(:result).fetch("status") == "ok" &&
    !control_sir.key?("callables") &&
    contract_files(control.fetch(:out)).none? { |contract| contract.key?("callables") }
end

check("H: delegated runtime admission leaves non-stream artifacts untouched", checks) do
  IgniterLang::ExperimentalIgcRun.refuse_stream_surface!(control.fetch(:out))
  true
end

puts "PASS stream_artifact_executability_proof"
checks.each do |label, result|
  puts "- #{result ? "PASS" : "FAIL"} #{label}"
end
