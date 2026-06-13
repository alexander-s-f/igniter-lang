# LANG-STDLIB-COLLECTION-RANGE-P3 — Rust Parity Proof Packet v0

**Route:** BOUNDED RUST IMPLEMENTATION / PROOF  
**Card:** `igniter-lang/.agents/work/cards/lang/LANG-STDLIB-COLLECTION-RANGE-P3.md`  
**Status:** CLOSED / PROVED — 50/50 PASS  
**Date:** 2026-06-13

---

## Summary

This phase completes Rust parity for `stdlib.collection.range` — adding OOF-COL1 arity guard to the Rust TC and adding `"range"` to the emitter's `COLLECTION_HOF_OPS` table so the SIR fn is qualified to `"stdlib.collection.range"`. The inventory entry is updated to `lowering_status: "dual-toolchain"`.

**Prior state (P2 end):**
- Rust TC `"range" =>` arm existed but had no OOF-COL1 guard (range() / range(5) compiled clean)
- Rust emitter emitted `"fn": "range"` (bare name) — not qualified

**P3 changes:**
- Rust TC: OOF-COL1 arity guard added
- Rust emitter: `("range", "stdlib.collection.range")` added to `COLLECTION_HOF_OPS`; `"range"` added to `semantic_expr_for_compute` delegate list
- Inventory: `lowering_status` → `"dual-toolchain"`, P3 added to `proof_lineage`, digest recomputed

---

## Authorized Changes

| File | Change |
|------|--------|
| `igniter-lab/igniter-compiler/src/typechecker.rs` | OOF-COL1 arity guard in `"range" =>` arm |
| `igniter-lab/igniter-compiler/src/emitter.rs` | `"range"` in `COLLECTION_HOF_OPS` + `semantic_expr_for_compute` delegate |
| `igniter-lang/docs/spec/stdlib-inventory.json` | `lowering_status: "dual-toolchain"` + P3 `proof_lineage` + digest |
| `igniter-lang/experiments/stdlib_collection_range_proof/verify_stdlib_collection_range_p2.rb` | B-03 fixed-state: accepts `ruby-only` OR `dual-toolchain` |

---

## Implementation

### typechecker.rs — OOF-COL1 arity guard

Added inside the `"range" =>` arm after setting `resolved_type`:

```rust
if args.len() != 2 {
    type_errors.push(ClassifierDiagnostic {
        rule: "OOF-COL1".to_string(),
        message: format!(
            "stdlib.collection.range: expected 2 arguments (start, stop), got {}",
            args.len()
        ),
        node: node_name.to_string(),
        line: None,
    });
}
```

`resolved_type = Collection[Integer]` is set **before** the arity check, so the arm always returns `Collection[Integer]` regardless — preventing OOF-TY1 cascade (parity with Ruby TC).

### emitter.rs — COLLECTION_HOF_OPS

Added `("range", "stdlib.collection.range")` to the constant:

```rust
const COLLECTION_HOF_OPS: &[(&str, &str)] = &[
    ("map",       "stdlib.collection.map"),
    ("filter",    "stdlib.collection.filter"),
    ("count",     "stdlib.collection.count"),
    ("append",    "stdlib.collection.append"),
    ("is_empty",  "stdlib.collection.is_empty"),
    ("non_empty", "stdlib.collection.non_empty"),
    ("range",     "stdlib.collection.range"),   // LANG-STDLIB-COLLECTION-RANGE-P3
];
```

Added `"range"` to the `semantic_expr_for_compute` delegate `matches!` macro:

```rust
|| matches!(fn_val, "map" | "filter" | "count" | "append" | "is_empty" | "non_empty" | "range")
```

Both edits are required: `COLLECTION_HOF_OPS` handles the rewrite in `semantic_expr`; the `matches!` delegate ensures standalone `compute result = range(...)` goes through `semantic_expr` instead of the bare-copy fallthrough in `semantic_expr_for_compute`.

### emitter.rs — build_pipeline note

The `build_pipeline` function already handles `range` inside pipeline contexts (e.g., `map(range(0,n), fn)`) by emitting a `{kind: "range", start, end}` node — this is a special IR shape for the runtime and was NOT changed. P3 only fixes the standalone call case.

### stdlib-inventory.json

```json
"lowering_status": "dual-toolchain",
"proof_lineage": [
  "LANG-STDLIB-COLLECTION-RANGE-P1 proposal + readiness proof 42/42 PASS",
  "LANG-STDLIB-COLLECTION-RANGE-P2 Ruby TC implemented",
  "LANG-STDLIB-COLLECTION-RANGE-P3 Rust TC parity + SIR qualification 50/50 PASS"
]
```

**Updated stdlib_surface_digest:** `db5b8555401d1bd40553096487d7d7545edee5614e3b6f7d95acb02a8884c1f9`

---

## Proof Results

**Runner:** `igniter-lab/igniter-compiler/verify_stdlib_collection_range_p3.rb`  
**Result:** 50/50 PASS — VERDICT: ACCEPT

| Section | Checks | Scope |
|---------|--------|-------|
| A — Inventory | 6/6 | dual-toolchain; digest stable; P3 in lineage; output_signature; diagnostics |
| B — Rust TC Happy Path | 8/8 | range(0,5) ok; qualified SIR; no bare 'range'; var args; non-zero start; no OOF-TY1; fold chain |
| C — Rust OOF-COL1 Arity | 6/6 | 0-arg; 1-arg (message 'got 1'); 3-arg; code; no OOF-TY1 cascade |
| D — Rust Totality | 4/4 | range(5,5) ok; range(5,3) ok; both qualified |
| E — map(range) Pipeline | 6/6 | map+range ok; SIR has both qualified; bare 'range' absent; count(range) ok; fold+range qualified |
| F — Ruby P2 Unchanged | 8/8 | happy path; qualified; OOF-COL1 0/1 arg; totality; map chain; char_at/fold regression |
| G — Source Structure | 6/6 | Rust TC arm; OOF-COL1 in arm; message qualified; emitter COLLECTION_HOF_OPS; delegate list; Ruby method unchanged |
| H — Authority Closed | 6/6 | bloom untouched; fast-path unchanged; OOF-COL1 only; no parser changes; build_pipeline unchanged; Ruby TC unchanged |

**P2 proof (post-P3):** 50/50 PASS (B-03 updated to accept `ruby-only` OR `dual-toolchain`)

---

## Design Notes

**Why two emitter edits?**

`semantic_expr` is called recursively from `semantic_expr_for_compute` only when explicitly delegated. Without the `matches!` addition, a standalone `compute result = range(0, n)` goes through `semantic_expr_for_compute`'s generic copy-loop, which copies `"fn": "range"` as-is. Adding `"range"` to the delegate list routes it to `semantic_expr` where `COLLECTION_HOF_OPS` performs the rewrite.

**Why NOT change build_pipeline?**

`build_pipeline` emits `{kind: "range", start, end}` — a special IR node consumed by the runtime in pipeline contexts. This is the correct shape for `map(range(0,n), fn)` and is intentional. The qualification fix only applies to standalone `range` call nodes where `{kind: "call", fn: ...}` is the IR shape.

---

## Closed Surfaces

- No parser changes
- No Ruby TC changes (P2 implementation unchanged)
- No app source changes (`bloom_filter/example.ig` still has manual slot pattern)
- No new OOF codes
- `build_pipeline` range arm (`{kind: "range"}`) unchanged

---

## Track Closure

`stdlib.collection.range` is now `dual-toolchain`. The `igniter-lab` Rust compiler and the `igniter-lang` Ruby TypeChecker both:
- Return `Collection[Integer]` for `range(start, stop)`
- Emit `"fn": "stdlib.collection.range"` in the SIR
- Emit OOF-COL1 on arity ≠ 2
- Accept totality (`range(a,a)`, `range(b,a where b>a)`) without diagnostic

Next route is application migration (`bloom_filter/example.ig` replacing the 31-node manual pattern with `map(range(0,16), ...)`) when authorized by a separate application card.
