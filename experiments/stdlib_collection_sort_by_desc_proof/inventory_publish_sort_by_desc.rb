#!/usr/bin/env ruby
# frozen_string_literal: true
#
# inventory_publish_sort_by_desc.rb — LANG-STDLIB-COLLECTION-SORT-BY-DESC-P4
# Publishes the ONE `stdlib.collection.sort_by_desc` inventory row and recomputes
# `stdlib_surface_digest` using the canonical method documented in the inventory note:
#
#   stdlib_surface_digest = sha256(canonical_json(
#     entries.sort_by { canonical_name }.map { reject "entry_digest" }))
#   canonical_json = recursively key-sorted, compact JSON.
#
# Mirrors experiments/stdlib_collection_sort_by_proof/inventory_digest_sort_by.rb exactly (same
# deep_sort/surface_digest functions, same JSON.pretty_generate write) so the file's byte format
# and the digest algorithm are the ESTABLISHED ones — this card invents no second serializer.
# Unlike the sort_by script, this one also INSERTS the row (idempotently, positioned immediately
# after stdlib.collection.sort_by so the file keeps its stable authored ordering; the digest is
# order-independent by construction since it sorts by canonical_name first).
#
# Usage:
#   ruby inventory_publish_sort_by_desc.rb verify    # read-only: report row presence + digest state
#   ruby inventory_publish_sort_by_desc.rb update    # insert row (if absent) + recompute + write

require "digest"
require "json"
require "pathname"

INV = Pathname.new(__dir__).parent.parent / "docs" / "spec" / "stdlib-inventory.json"
CANON = "stdlib.collection.sort_by_desc"

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

ROW = {
  "canonical_name" => CANON,
  "semantic_ir_name" => CANON,
  "legacy_sir" => nil,
  "aliases" => [{ "kind" => "source_alias", "name" => "sort_by_desc" }],
  "category" => "collection",
  "lifecycle_status" => "lab-implemented",
  "semantic_stability" => "experiment-pass",
  "lowering_status" => "dual-toolchain",
  "compatibility_status" => "pre-v1-none",
  "fragment_class" => "core",
  "purity" => "pure",
  "deterministic" => true,
  "totality" => "total",
  "type_params" => %w[T K],
  "input_signature" => ["Collection[T]", "T -> K"],
  "output_signature" => "Collection[T]",
  "diagnostics" => %w[OOF-COL1 OOF-COL2 OOF-COL11],
  "failure_behavior" =>
    "OOF-COL11 refuses any key type other than Integer, Text, or Decimal at typecheck (Float " \
    "included, message routes to Decimal/Integer) in the sort_by_desc spelling; a well-typed " \
    "program's key extractor never fails at runtime for the type reason, but arbitrary extractor " \
    "bodies can still error, propagating deterministically in input order. A runtime key pair " \
    "that is still incomparable (only reachable outside the typechecker) fails closed with a " \
    "bounded operational error — never a panic, never a silent Equal.",
  "authority_surface" => "none",
  "proof_lineage" => [
    "LANG-STDLIB-COLLECTION-REVERSE-PREPEND-READINESS-P1 — readiness packet: prepend closed by " \
    "measurement, reverse HOLD-sequenced, sort_by_desc selected as the one implementation card " \
    "(measured tie counterexample: reverse(sort_by(k)) anti-stabilizes tie groups)",
    "LANG-STDLIB-COLLECTION-SORT-BY-DESC-PROP-P1 — canon admission: ch8 §8.14 written spec-first, " \
    "§8.12.3's v0 'descending ordering' closure narrowed by a dated note; all eight candidate laws " \
    "adopted, §8.14.2 tie non-law normative",
    "LANG-STDLIB-COLLECTION-SORT-BY-DESC-P2 — canon Ruby typechecker.rb infer_sort_by_desc_call " \
    "(dedicated mirror, bare + qualified dispatch), OOF-COL11 reused with the sort_by_desc " \
    "spelling (proof 31/31 PASS) + tracked tie fixture for P3",
    "LANG-STDLIB-COLLECTION-SORT-BY-DESC-P3 — lab Rust igniter-compiler typechecker/emitter parity " \
    "(both qualification ownership points) + igniter-vm execution: bytecode OP_CALL arm and the " \
    "eval_ast HOF dispatch share one stable merge with the comparison inverted (compiler 13/13, " \
    "VM 13/13 incl. tie specimen, both-path parity, 100k budget; dual_clean true)",
    "LANG-STDLIB-COLLECTION-SORT-BY-DESC-P4 — this inventory row + surface-digest recompute + " \
    "generated Surface Catalog regeneration"
  ],
  "examples" => [
    "sort_by_desc([5, 1, 4, 1, 3], x -> x) -> [5, 4, 3, 1, 1]",
    "sort_by_desc([\"banana\", \"apple\", \"cherry\"], x -> x) -> [\"cherry\", \"banana\", \"apple\"]",
    "sort_by_desc([(key 10,seq 1),(5,2),(10,3),(5,4),(7,5)], x -> x.key) -> keys [10,10,7,5,5], " \
    "seqs [1,3,5,2,4] — TIE LAW: equal keys keep authored order (an element-reversal of ascending " \
    "would give seqs [3,1,5,4,2])",
    "sort_by_desc(xs, x -> x) with Collection[Float] -> OOF-COL11 at typecheck (Float is not " \
    "admissible — convert to Decimal or Integer)"
  ],
  "compatibility_note" =>
    "Stable DESCENDING sort — the sibling of stdlib.collection.sort_by, NOT an alias for it and " \
    "NOT `reverse` applied to an ascending result. Equal keys preserve authored/input order " \
    "exactly, the SAME tie discipline as ascending: descending is realized by inverting only the " \
    "non-equal comparison (Less<->Greater) INSIDE the shared stable merge, and Equal is never " \
    "inverted, so tie groups are never reversed. The keys-only duality holds (the key column " \
    "equals the reversal of ascending's key column) but the full element sequence does NOT — ch8 " \
    "§8.14.2 carries the measured counterexample as normative prose. Result type is Collection[T], " \
    "the ORIGINAL element type, never Collection[K]. K is restricted to exactly Integer, Text, or " \
    "Decimal, defined as the strict inversion of the SAME order relations as sort_by (Integer " \
    "numeric; Text byte/codepoint lexicographic, no locale collation; Decimal cmp_decimal " \
    "scale-normalized) — descending-by-Text is therefore a first-class capability, not an " \
    "arithmetic key trick. The key extractor runs exactly once per item (decorate-sort-undecorate); " \
    "empty and singleton collections return unchanged; budgets are exactly sort_by's. OOF-COL11 is " \
    "REUSED (no new diagnostic code) with the sort_by_desc spelling. No comparator lambda, runtime " \
    "direction parameter, multi-key ordering, Float ordering, reverse or prepend in v0. Ruby canon " \
    "is typecheck/emit parity only; execution is Rust VM authority (bytecode OP_CALL + eval_ast " \
    "HOF dispatch share one implementation). Authored source uses the bare alias sort_by_desc; the " \
    "SIR/runtime identity is the qualified name and both toolchains emit it.",
  "owner_surface" => "LANG-STDLIB-COLLECTION-SORT-BY-DESC-PROP-P1",
  "entry_digest" => nil
}.freeze

mode = ARGV[0] || "verify"
doc = JSON.parse(File.read(INV, encoding: "UTF-8"))
entries = doc.fetch("entries")
stored = doc.fetch("stdlib_surface_digest")
present = entries.any? { |e| e["canonical_name"] == CANON }

if mode == "verify"
  puts "row present: #{present}"
  recomputed = surface_digest(entries)
  if recomputed == stored
    puts "OK verify: stored digest matches recomputed over the CURRENT entries"
    puts "  digest=#{stored}"
    exit(0)
  else
    puts "DRIFT: stored digest does not match recomputed over the CURRENT entries"
    puts "  stored=#{stored}"
    puts "  computed=#{recomputed}"
    exit(1)
  end
end

abort "FAIL: unknown mode #{mode.inspect} (use verify|update)" unless mode == "update"

unless entries.any? { |e| e["canonical_name"] == "stdlib.collection.sort_by" }
  abort "FAIL: stdlib.collection.sort_by row missing — refusing to publish its descending sibling"
end

if present
  puts "row already present — recomputing digest only (idempotent re-run)"
else
  idx = entries.index { |e| e["canonical_name"] == "stdlib.collection.sort_by" }
  entries.insert(idx + 1, JSON.parse(JSON.generate(ROW)))
  puts "inserted #{CANON} at position #{idx + 1} (immediately after stdlib.collection.sort_by)"
end

recomputed = surface_digest(entries)
doc["stdlib_surface_digest"] = recomputed
unless doc["note"].to_s.include?("SORT-BY-DESC-P4")
  doc["note"] = doc["note"].to_s +
    " LANG-STDLIB-COLLECTION-SORT-BY-DESC-P4 adds stdlib.collection.sort_by_desc (Collection[T] x" \
    " (T -> K) -> Collection[T], stable DESCENDING with equal keys preserving authored order, K in" \
    " {Integer, Text, Decimal}, OOF-COL11 reused in the sort_by_desc spelling) and recomputes the" \
    " digest."
end

File.write(INV, JSON.pretty_generate(doc) + "\n")
puts "OK update: stdlib_surface_digest recomputed"
puts "OLD digest: #{stored}"
puts "NEW digest: #{recomputed}"
