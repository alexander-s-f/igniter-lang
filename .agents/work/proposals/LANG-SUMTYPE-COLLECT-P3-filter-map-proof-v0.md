# LANG-SUMTYPE-COLLECT-P3 — filter_map implementation proof

**Status:** CLOSED — IMPLEMENTED DUAL-TOOLCHAIN — 95/95 PASS
**Track:** lang / stdlib / collection filter_map / dual-toolchain
**Date:** 2026-06-15
**Authority:** dual-toolchain stdlib implementation; app migration deferred

---

## 0. Result

```
filter_map(xs : Collection[T], fn : T -> Option[U]) -> Collection[U]
```

Implemented in **both** toolchains (Ruby canon + Rust lab). Keeps each `Some(u)`
payload, drops every `None`. A TypeChecker HOF arm mirroring `map`; agnostic to `T`
(serves the user `variant` `RowResult` AND built-in `Result`/`Option`); reuses the
P3 sealed `Option` + `match` substrate; does **not** overload `map`.

| Proof | Verdict |
|---|---|
| `experiments/sumtype_collect_proof/verify_sumtype_collect_p3.rb` | **95/95 PASS** (target ≥90) |
| `verify_sumtype_collect_p1.rb` (readiness, fixed-state) | 68/68 PASS |
| `verify_sumtype_collect_p2.rb` (planning, fixed-state) | 73/73 PASS |
| `verify_sumtype_construct_match_p3.rb` (regression) | 109/109 PASS |

**BI-P01 collapses** — `Collection[RowResult] → Collection[ImportRecord]` compiles
dual-clean **without migrating `batch_importer`** source.

## 1. Edit sites (as mirrored from `map`)

**Ruby** (`lib/igniter_lang/typechecker.rb`):
- `@collection_output_hints` seeded from output/compute `Collection[U]` annotations
  (parallel to `@sealed_output_hints`).
- `infer_call` dispatch: `when "filter_map"` → `infer_filter_map_call`.
- `infer_filter_map_call`: OOF-COL1 (arity/non-lambda), OOF-COL2 (non-Collection),
  bind callback param to `T`, temp-install `@sealed_output_hints[node] = Option[U]`
  around the callback body inference, OOF-COL3 (callback must return Option), result
  `Collection[U]`. SIR = `stdlib.collection.filter_map`, **lambda dropped** (map convention).

**Rust** (`igniter-compiler/src/`):
- `typechecker.rs`: new `collection_elem_hints: RefCell<HashMap>` field, seeded per
  contract from output/compute `Collection[U]` annotations.
- `typechecker/stdlib_calls.rs`: `"filter_map" =>` arm copied from `map`@458 — bind
  param to `T`, temp-install + restore `sealed_output_hints[node]=Option[U]` around the
  callback body, OOF-COL1/2/3, result `Collection[U]`.
- `emitter.rs`: `COLLECTION_HOF_OPS` gains `("filter_map","stdlib.collection.filter_map")`,
  and the `semantic_expr_for_compute` HOF whitelist gains `filter_map` (so compute-level
  calls reach the qualification path). SIR = qualified fn, **lambda kept** (map convention).

## 2. U-extraction — route B2 + sibling route A composed

`U` is taken from the callback's **concrete** `Option[U]` param when available, else from
the `Collection[U]` output context (route B2 — `collection_elem_hints` /
`@collection_output_hints`), else `Unknown`. The expected `Option[U]` is temp-installed as
a sealed hint while inferring the callback body so `some(x)`/`none()` resolve against `U`.

The sibling card **`LANG-MATCH-ARM-PARAM-UNIFICATION-P2` (route A) landed in parallel**
(dual-toolchain `join_match_param_types`), so a parametric `match` now **preserves** its
type param. Consequently the BI-P01 callback `match r { Valid{record}=>some(record);
Invalid{}=>none() }` resolves to a concrete `Option[ImportRecord]`, and `filter_map`
reads `U` straight from the callback param — the B2 context becomes the **fallback** path
(still valuable when there is no output annotation or a callback yields a bare Option).
`filter_map` works **identically with or without route A** (P3 95/95 confirms), so P3 did
not hard-gate on the sibling, as planned in P2.

## 3. SIR shape (per-toolchain mirror of `map`)

| | Ruby | Rust |
|---|---|---|
| fn | `stdlib.collection.filter_map` (qualified) | `stdlib.collection.filter_map` (qualified) |
| lambda in args | **dropped** | **kept** |
| `resolved_type` on call node | present (`Collection[U]`) | omitted |

Cross-toolchain byte-parity is **not** asserted (it does not hold for `map`/`filter`
either — verified live); the dual metric is status + diagnostics, with per-toolchain SIR
goldens. Both toolchains qualify to the same canonical fn name.

## 4. Diagnostics (reused, no new family)

`OOF-COL1` (arity ≠ 2 / non-lambda 2nd arg, Ruby), `OOF-COL2` (non-Collection first arg),
`OOF-COL3` ("callback must return Option[U]"). Dual-consistent on the primary code. Rust
mirrors `map`'s existing leniency on a non-lambda 2nd arg (Rust-parity fallback).

## 5. Inventory + spec

- `stdlib-inventory.json`: added `stdlib.collection.filter_map`
  (`semantic_ir_name == canonical_name`, no `legacy_sir`; `type_params [T,U]`;
  `input_signature ["Collection[T]","(T) -> Option[U]"]`; `output_signature "Collection[U]"`;
  `diagnostics [OOF-COL1,OOF-COL2,OOF-COL3]`; `lowering_status dual-toolchain`).
  `stdlib_surface_digest` recomputed (canonical algorithm); entry-contract digest-stability
  proof B-01..B-08 PASS. (Pre-existing stale `A-05: exactly 24 entries` assertion is
  unrelated — the inventory already held 39 before this card.)
- ch8 §8.2: added the `filter_map` line.

## 6. Regression + fleet

`map` / `filter` / `fold` / `count` / `first` / `some()` construct / user-variant `match`
all dual-clean and unchanged (P3 §I, 16 checks). `batch_importer` Rust baseline `status ok
/ 0 diags` and still on the user `variant RowResult` (unmigrated). Fleet smoke: `lead_router`
+ `batch_importer` compile; `rule_engine` frozen boundary untouched. sumtype construct+match
109/109.

## 7. Closed surfaces

No app source migration; no parser change; no `collect` name; no `map` overload for
Result/Option; no `partition`/Pair/tuple; no `group_by`/`sort_by`/indexed-map; no
parse/storage effects; no generic Monad/typeclass.

## 8. Coordination note

The shared working tree contained the sibling `LANG-MATCH-ARM-PARAM-UNIFICATION-P2`
(route A) implementation, uncommitted, landed in parallel. This card's `filter_map` is
independent of it and composes cleanly. The COLLECT-P1/P2 predecessor proofs were updated
to fixed-state: their `filter_map`-absent checks now assert the implemented surface, and
their param-drop sub-gap checks now assert the route-A resolution (cross-referencing the
sibling card, not claiming it).

## 9. Next

- `batch_importer` migration (BI-P04) — now purely ergonomic; a separate app-authorized card.
- Optional: shed the `@collection_output_hints` / `collection_elem_hints` B2 plumbing now
  that route A preserves params, reducing `filter_map` to a thinner `map` mirror — a small
  cleanup card, not required.
