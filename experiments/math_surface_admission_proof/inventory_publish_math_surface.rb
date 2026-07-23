#!/usr/bin/env ruby
# frozen_string_literal: true
#
# inventory_publish_math_surface.rb — LANG-STDLIB-MATH-SURFACE-CANON-ADMISSION-P2
#
# Publishes the 15 admitted `stdlib.math.*` rows and recomputes `stdlib_surface_digest` with the
# canonical method documented in the inventory note. Same `deep_sort`/`surface_digest` functions
# and the same `JSON.pretty_generate` write as every prior per-card script — no second serializer.
#
# Usage:
#   ruby inventory_publish_math_surface.rb verify
#   ruby inventory_publish_math_surface.rb update

require "digest"
require "json"
require "pathname"

INV = Pathname.new(__dir__).parent.parent / "docs" / "spec" / "stdlib-inventory.json"

def deep_sort(o)
  case o
  when Hash then o.keys.sort.each_with_object({}) { |k, h| h[k] = deep_sort(o[k]) }
  when Array then o.map { |e| deep_sort(e) }
  else o
  end
end

def surface_digest(entries)
  stripped = entries.sort_by { |e| e["canonical_name"].to_s }
                    .map { |e| e.reject { |k, _| k == "entry_digest" } }
  Digest::SHA256.hexdigest(JSON.generate(deep_sort(stripped)))
end

LINEAGE = [
  "LANG-FLOAT-MATH-SURFACE-CANON-READINESS-P1 — measured 20 candidates x 8 planes (UNIFORM: Rust " \
  "clean / canon Ruby OOF-TY0 / VM direct AND nested success / spec absent / inventory absent / " \
  "import OOF-IMP2 / catalog lab_path_candidate+live_unregistered) and a payoff curve of 48 app " \
  "diagnostics -> 1 residual for the chosen 15-name surface",
  "LANG-STDLIB-MATH-SURFACE-CANON-ADMISSION-P2 — ch8 §8.15 written with the three reproducibility " \
  "tiers; canon Ruby typing via one owner-local MATH_STDLIB_FNS table; Rust emitter qualifies the " \
  "bare source spelling at both ownership points; VM Tier-F1 domain/finite refusals hardened " \
  "(sqrt(-1.0) previously returned a canon-visible NaN); these inventory rows + Surface Catalog"
].freeze

TIERS = {
  "N0" => "Deterministic BY CONSTRUCTION — comparisons and sign flips are bit-identical on every " \
          "target, so this tier needs no det_* sibling.",
  "F1" => "FAST platform-f64. Tolerance-tested; NO bit-identical cross-ISA claim. A replay that " \
          "must be bit-exact on another architecture uses the D1 tier instead.",
  "D1" => "DETERMINISTIC fixed-result carrier plus golden-bit drift locks: vendored pure-Rust " \
          "libm owns det_sin/det_cos/det_ln/det_exp/det_tan; IEEE-correct f64::sqrt owns " \
          "det_sqrt. Governed deterministic execution is claimed; VERIFIED multi-ISA parity is " \
          "NOT — cross-arch confirmation is a separate CI matter and must not be inferred from " \
          "this row."
}.freeze

def row(name, tier:, inputs:, output:, totality:, failure:, note:, examples:, type_params: [])
  {
    "canonical_name" => "stdlib.math.#{name}",
    "semantic_ir_name" => "stdlib.math.#{name}",
    "legacy_sir" => nil,
    "aliases" => [{ "kind" => "source_alias", "name" => name }],
    "category" => "numeric",
    "lifecycle_status" => "lab-implemented",
    "semantic_stability" => "experiment-pass",
    "lowering_status" => "dual-toolchain",
    "compatibility_status" => "pre-v1-none",
    "fragment_class" => "core",
    "purity" => "pure",
    "deterministic" => true,
    "totality" => totality,
    "type_params" => type_params,
    "input_signature" => inputs,
    "output_signature" => output,
    "diagnostics" => %w[OOF-MATH1 OOF-MATH2 OOF-MATH3],
    "failure_behavior" => failure,
    "authority_surface" => "none",
    "proof_lineage" => LINEAGE,
    "examples" => examples,
    "compatibility_note" =>
      "Tier #{tier}. #{TIERS.fetch(tier)} " \
      "The natural BARE spelling `#{name}(...)` is the source form; both toolchains lower it to " \
      "the qualified identity `stdlib.math.#{name}`, and no newly emitted SIR carries a bare math " \
      "identity (bare names remain runtime compatibility inputs so previously compiled artifacts " \
      "keep executing). Recognized typed collection-HOF bodies emit the same qualified identity as " \
      "direct positions. Diagnostics reuse the already-authoritative OOF-MATH1 (arity) / " \
      "OOF-MATH2 (argument type) / OOF-MATH3 (mixed numeric family) verbatim in BOTH toolchains — " \
      "no new code minted. #{note} Canon Ruby owns typing parity; execution is Rust VM authority, " \
      "and the direct OP_CALL and nested eval-AST paths share one semantic owner. See ch8 §8.15.",
    "owner_surface" => "LANG-FLOAT-MATH-SURFACE-CANON-READINESS-P1",
    "entry_digest" => nil
  }
end

NO_COERCION = "T is Integer or Float, homogeneous — a mixed numeric pair is refused with " \
              "OOF-MATH3, never widened. Decimal is deliberately not admitted here."

ROWS = [
  row("abs", tier: "N0", type_params: ["T"], inputs: ["T"], output: "T", totality: "partial",
      failure: "Integer overflow fails closed, including abs(i64::MIN) which has no positive " \
               "counterpart; a non-finite Float input is a deterministic runtime error.",
      note: NO_COERCION,
      examples: ["abs(-5) -> 5", "abs(-2.5) -> 2.5", "abs(i64::MIN) -> runtime error (overflow)"]),
  row("min", tier: "N0", type_params: ["T"], inputs: %w[T T], output: "T", totality: "partial",
      failure: "Mixed numeric operands are OOF-MATH3 at typecheck; a non-finite Float input is a " \
               "deterministic runtime error.",
      note: NO_COERCION, examples: ["min(3, 7) -> 3", "min(1.5, 2.5) -> 1.5"]),
  row("max", tier: "N0", type_params: ["T"], inputs: %w[T T], output: "T", totality: "partial",
      failure: "Mixed numeric operands are OOF-MATH3 at typecheck; a non-finite Float input is a " \
               "deterministic runtime error.",
      note: NO_COERCION, examples: ["max(3, 7) -> 7", "max(1.5, 2.5) -> 2.5"]),
  row("clamp", tier: "N0", type_params: ["T"], inputs: %w[T T T], output: "T", totality: "partial",
      failure: "clamp(value, lo, hi) refuses lo > hi at runtime rather than silently reordering " \
               "the bounds; mixed operands are OOF-MATH3; non-finite Float input is an error.",
      note: NO_COERCION, examples: ["clamp(9, 1, 5) -> 5", "clamp(0.5, 1.0, 2.0) -> 1.0"]),
  row("sign", tier: "N0", type_params: ["T"], inputs: ["T"], output: "Integer", totality: "partial",
      failure: "A non-finite Float input is a deterministic runtime error.",
      note: "#{NO_COERCION} Result is Integer in {-1, 0, 1}. sign(-0.0) == 0, consistent with " \
            "ch8 §8.14's signed-zero law where -0.0 == 0.0.",
      examples: ["sign(-2.5) -> -1", "sign(0) -> 0", "sign(-0.0) -> 0"]),

  row("sin", tier: "F1", inputs: ["Float"], output: "Float", totality: "partial",
      failure: "A non-finite input is refused — a canon-visible NaN is a leak, not a value.",
      note: "No implicit Integer/Decimal conversion.", examples: ["sin(0.5) -> 0.479425538604203"]),
  row("cos", tier: "F1", inputs: ["Float"], output: "Float", totality: "partial",
      failure: "A non-finite input is refused.",
      note: "No implicit Integer/Decimal conversion.", examples: ["cos(0.5) -> 0.8775825618903728"]),
  row("sqrt", tier: "F1", inputs: ["Float"], output: "Float", totality: "partial",
      failure: "x < 0 is refused with a domain error, and a non-finite input is refused. BEFORE " \
               "this admission sqrt(-1.0) returned a NaN that serialized as null; closing that " \
               "leak was a precondition of publishing this row, not a footnote.",
      note: "No implicit Integer/Decimal conversion.", examples: ["sqrt(4.0) -> 2.0", "sqrt(-1.0) -> runtime domain error"]),
  row("pi", tier: "F1", inputs: [], output: "Float", totality: "total",
      failure: "Arity other than zero is OOF-MATH1. Cannot fail at runtime.",
      note: "Zero-argument constant surface.", examples: ["pi() -> 3.141592653589793"]),

  row("det_sin", tier: "D1", inputs: ["Float"], output: "Float", totality: "partial",
      failure: "Non-finite input or non-finite result fails closed.",
      note: "Vendored pure-Rust libm with a local golden-bit lock.", examples: ["det_sin(0.5) -> 0.479425538604203"]),
  row("det_cos", tier: "D1", inputs: ["Float"], output: "Float", totality: "partial",
      failure: "Non-finite input or non-finite result fails closed.",
      note: "Vendored pure-Rust libm with a local golden-bit lock.", examples: ["det_cos(0.5) -> 0.8775825618903728"]),
  row("det_sqrt", tier: "D1", inputs: ["Float"], output: "Float", totality: "partial",
      failure: "Requires x >= 0; a negative input or a non-finite input fails closed.",
      note: "IEEE-correct f64::sqrt — exact on every conforming target.", examples: ["det_sqrt(4.0) -> 2.0"]),
  row("det_ln", tier: "D1", inputs: ["Float"], output: "Float", totality: "partial",
      failure: "Requires x > 0; det_ln(0.0) and det_ln(x<0) are deterministic domain errors.",
      note: "Vendored libm — one fixed algorithm on every target.", examples: ["det_ln(2.0) -> 0.6931471805599453", "det_ln(0.0) -> runtime domain error"]),
  row("det_exp", tier: "D1", inputs: ["Float"], output: "Float", totality: "partial",
      failure: "Overflow to a non-finite result is refused; finite UNDERFLOW to zero is permitted " \
               "(det_exp(-1000.0) -> 0.0).",
      note: "Vendored libm — one fixed algorithm on every target.", examples: ["det_exp(1.0) -> 2.7182818284590455", "det_exp(1000.0) -> runtime overflow error"]),
  row("det_tan", tier: "D1", inputs: ["Float"], output: "Float", totality: "partial",
      failure: "A non-finite input or a non-finite pole result fails closed. Note that an exact " \
               "pole is not reachable in f64 (pi()/2.0 is not exactly pi/2), so a large finite " \
               "value near the pole is a correct result, not a missed refusal.",
      note: "Vendored libm — one fixed algorithm on every target.", examples: ["det_tan(0.5) -> 0.5463024898437905"])
].freeze

mode = ARGV[0] || "verify"
doc = JSON.parse(File.read(INV, encoding: "UTF-8"))
entries = doc.fetch("entries")
stored = doc.fetch("stdlib_surface_digest")
names = entries.map { |e| e["canonical_name"] }
missing = ROWS.map { |r| r["canonical_name"] }.reject { |n| names.include?(n) }

if mode == "verify"
  puts "missing rows: #{missing.length}"
  puts "  #{missing.inspect}" unless missing.empty?
  recomputed = surface_digest(entries)
  if recomputed == stored
    puts "OK verify: stored digest matches recomputed"
    puts "  digest=#{stored}"
    exit(0)
  end
  puts "DRIFT: stored=#{stored} computed=#{recomputed}"
  exit(1)
end

abort "FAIL: unknown mode #{mode.inspect} (use verify|update)" unless mode == "update"

ROWS.each do |r|
  normalized = JSON.parse(JSON.generate(r))
  index = entries.index { |entry| entry["canonical_name"] == r["canonical_name"] }
  if index
    entries[index] = normalized
    puts "refreshed #{r['canonical_name']}"
  else
    entries << normalized
    names << r["canonical_name"]
    puts "appended #{r['canonical_name']}"
  end
end

recomputed = surface_digest(entries)
doc["stdlib_surface_digest"] = recomputed
doc["note"] = doc["note"].to_s.sub(
  "and D1 deterministic algorithm-fixed (det_sin/det_cos/det_sqrt/det_ln/ det_exp/det_tan, " \
  "vendored libm + golden-bit locks, domain and non-finite refusals)",
  "and D1 deterministic fixed-carrier (det_sin/det_cos/det_sqrt/det_ln/ det_exp/det_tan, " \
  "function-specific carriers + golden-bit locks, domain and non-finite refusals)"
)
unless doc["note"].to_s.include?("MATH-SURFACE-CANON-ADMISSION-P2")
  doc["note"] = doc["note"].to_s +
    " LANG-STDLIB-MATH-SURFACE-CANON-ADMISSION-P2 admits the 15-name stdlib.math surface in three" \
    " reproducibility tiers (ch8 §8.15): N0 scalar helpers deterministic by construction" \
    " (abs/min/max/clamp/sign, homogeneous Integer|Float, no coercion, sign(-0.0)==0), F1 fast" \
    " platform-f64 with NO cross-ISA bit-identity claim (sin/cos/sqrt/pi, finite-only," \
    " sqrt(x<0) refused), and D1 deterministic fixed-carrier (det_sin/det_cos/det_sqrt/det_ln/" \
    " det_exp/det_tan, function-specific carriers + golden-bit locks, domain and non-finite" \
    " refusals);" \
    " recomputes the digest."
end

File.write(INV, JSON.pretty_generate(doc) + "\n")
puts "OK update: stdlib_surface_digest recomputed"
puts "OLD digest: #{stored}"
puts "NEW digest: #{recomputed}"
