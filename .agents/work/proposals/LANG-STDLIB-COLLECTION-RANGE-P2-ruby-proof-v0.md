# LANG-STDLIB-COLLECTION-RANGE-P2 — Ruby Proof Packet v0

**Route:** BOUNDED RUBY IMPLEMENTATION / PROOF  
**Card:** `igniter-lang/.agents/work/cards/lang/LANG-STDLIB-COLLECTION-RANGE-P2.md`  
**Status:** CLOSED / PROVED — 50/50 PASS  
**Date:** 2026-06-13

---

## Summary

This phase implements `stdlib.collection.range` in the Ruby TypeChecker and adds the corresponding entry to `stdlib-inventory.json`. No Rust changes. No emitter changes. No parser changes. No app changes.

**Implemented form:** `range(start: Integer, stop: Integer) -> Collection[Integer]`  
**Interval semantics:** exclusive `[start, stop)` — total: `range(a, a) = []`, `range(b, a where b>a) = []`  
**OOF codes:** OOF-COL1 (arity ≠ 2 only) — arg types Unknown-permissive in v0

---

## Authorized Changes

| File | Change |
|------|--------|
| `igniter-lang/lib/igniter_lang/typechecker.rb` | `when "range"` dispatch arm + `infer_range_call` method |
| `igniter-lang/docs/spec/stdlib-inventory.json` | New entry + updated `stdlib_surface_digest` |

---

## Implementation

### typechecker.rb — dispatch arm

Added after `when "char_at"`, before `when "or_else"` in `infer_call`:

```ruby
when "range"
  # LANG-STDLIB-COLLECTION-RANGE-P2: range(start, stop) -> Collection[Integer]
  infer_range_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

### typechecker.rb — infer_range_call method

Added after `infer_is_empty_call` ends, before `infer_char_at_call`:

```ruby
# LANG-STDLIB-COLLECTION-RANGE-P2: stdlib.collection.range
# range(start: Integer, stop: Integer) -> Collection[Integer]
# Generates the exclusive interval [start, stop). Total: range(a, a) = []; range(b, a where b>a) = [].
# OOF-COL1: arity != 2 (only diagnostic in v0 — arg types Unknown-permissive, not validated).
def infer_range_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  qualified   = "stdlib.collection.range"
  result_type = collection_type_ir_from(type_ir("Integer"))

  # ── OOF-COL1: arity must be exactly 2 ───────────────────────────────────
  unless args.length == 2
    type_errors << oof("OOF-COL1",
      "#{qualified}: expected 2 arguments (start, stop), got #{args.length}", node_name)
    return typed_expr("call", result_type, [], "fn" => qualified, "args" => [])
  end

  # ── Infer both args — Unknown-permissive (no type validation in v0) ──────
  start_typed = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  stop_typed  = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
  deps        = (start_typed.fetch("deps", []) + stop_typed.fetch("deps", [])).uniq

  typed_expr("call", result_type, deps, "fn" => qualified, "args" => [start_typed, stop_typed])
end
```

### stdlib-inventory.json — new entry

Entry added (36 entries total):

```json
{
  "canonical_name": "stdlib.collection.range",
  "semantic_ir_name": "stdlib.collection.range",
  "legacy_sir": null,
  "aliases": [{"kind": "source_alias", "name": "range"}],
  "category": "collection",
  "lifecycle_status": "lab-implemented",
  "semantic_stability": "experiment-pass",
  "lowering_status": "ruby-only",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total",
  "type_params": [],
  "input_signature": ["Integer", "Integer"],
  "output_signature": "Collection[Integer]",
  "diagnostics": ["OOF-COL1"],
  "failure_behavior": "none",
  "authority_surface": "none",
  "proof_lineage": [
    "LANG-STDLIB-COLLECTION-RANGE-P1 proposal + readiness proof 42/42 PASS",
    "LANG-STDLIB-COLLECTION-RANGE-P2 Ruby TC implemented"
  ],
  "examples": ["range(0, 5) -> [0, 1, 2, 3, 4]", "range(3, 6) -> [3, 4, 5]", "range(5, 5) -> []"],
  "compatibility_note": "Generator: exclusive [start, stop) interval as Collection[Integer]. Total: range(a, a) and range(b, a where b>a) both return empty collection. OOF-COL1 on arity != 2; arg types Unknown-permissive in v0 (no OOF-COL2 — arg must be Integer not Collection). Ruby-only in P2; Rust parity in P3.",
  "owner_surface": "LANG-STDLIB-COLLECTION-RANGE-P1",
  "entry_digest": null
}
```

**Updated stdlib_surface_digest:** `cfe520dc02138b5cd0cb2d7e78096c2e908187efed5da6e5be773543b803a3f2`

---

## Proof Results

**Runner:** `igniter-lang/experiments/stdlib_collection_range_proof/verify_stdlib_collection_range_p2.rb`  
**Result:** 50/50 PASS — VERDICT: ACCEPT

| Section | Checks | Scope |
|---------|--------|-------|
| A — Source Structure | 6/6 | arm present; method defined; OOF-COL1 ref; qualified name; placement (after char_at, before or_else) |
| B — Inventory | 8/8 | entry exists; lifecycle/lowering/input/output/diagnostics/alias correct; digest stable |
| C — Happy Path | 8/8 | range(0,5) ok; SIR fn qualified; bare 'range' absent from SIR; var args ok; non-zero start ok; fold chain ok; no OOF-TY1 |
| D — OOF-COL1 Arity | 6/6 | 0-arg; 1-arg (message 'got 1'); 3-arg; code; message references qualified name; no OOF-TY1 cascade |
| E — Totality | 4/4 | range(5,5) ok; range(5,3) ok; both return qualified SIR fn |
| F — Map Over Range | 6/6 | map(range(0,n), i→i) ok; SIR has both range + map qualified; bloom_filter slot pattern clean; fold(range(0,5),...) ok |
| G — Regression | 8/8 | append/filter/count/fold/is_empty/concat/char_at clean; P1 gap fixed (OOF-TY0 gone) |
| H — Authority Closed | 4/4 | no emitter changes; Rust arm untouched; no parser OOF codes; bloom_filter example.ig unchanged |

---

## Design Decisions

**Q1: OOF-COL2 or not?**  
Not applicable. OOF-COL2 is for "first argument must be a Collection[T]" (see `infer_collection_hof_call`). `range` arguments are scalars (Integer), not Collections. No OOF-COL2 applies.

**Q2: Arg type validation in v0?**  
Unknown-permissive, matching Rust TC behavior. Both Integer args are inferred but their types are not checked against `Integer`. This is P2 scope: arity guard only. Type validation (rejecting `range("a", "b")`) is deferred to a future Px.

**Q3: Result type on arity error?**  
`Collection[Integer]` is returned even on OOF-COL1. This prevents OOF-TY1 cascade at output boundaries where `output result : Collection[Integer]` is declared.

**Q4: Digest algorithm?**  
Ruby canonical JSON (sorted keys + sorted entries by canonical_name + SHA256), matching the proof runner's `compute_surface_digest` implementation. The prior Python-written digest was recomputed to match this algorithm.

---

## Closed Surfaces

- No Rust TC changes (`typechecker.rs` untouched)
- No emitter changes (`semanticir_emitter.rb` untouched)
- No parser changes
- No app source changes (`bloom_filter/example.ig` still has manual slot pattern)
- No new OOF codes

---

## Next Route

**LANG-STDLIB-COLLECTION-RANGE-P3** — Rust parity implementation in `typechecker.rs` and `emitter.rs`. The Rust TC already has a `"range" =>` arm at ~line 2865 that returns `Collection[Integer]`. P3 must verify the Rust arm is correct (SIR name qualified, OOF-COL1 parity) and update inventory to `lowering_status: "dual-toolchain"`.
