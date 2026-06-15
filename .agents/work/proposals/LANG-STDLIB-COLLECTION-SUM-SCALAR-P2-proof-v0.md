# LANG-STDLIB-COLLECTION-SUM-SCALAR-P2 — scalar sum implementation proof

**Status:** CLOSED — IMPLEMENTED DUAL-TOOLCHAIN + VM — 91/91 PASS
**Track:** lang / stdlib / collection sum scalar form
**Date:** 2026-06-15
**Authority:** dual-toolchain stdlib + VM implementation; no app migration

---

## 0. Result

```igniter
sum(xs : Collection[T]) -> T        -- scalar; T = Integer / Float / Decimal[N]
sum(xs : Collection[R], :field) -> F -- field projection (unchanged)
```

The scalar one-argument form is implemented in **Ruby TC + Rust TC + VM**, coexisting with
the field-projection form by arity dispatch. It returns the **element type T exactly** —
not bare `Decimal` — preserving `Decimal` scale end-to-end.

| Proof | Verdict |
|---|---|
| `experiments/stdlib_sum_proof/verify_stdlib_collection_sum_scalar_p2.rb` | **91/91 PASS** (target ≥90) |
| `verify_stdlib_collection_sum_scalar_p1.rb` (planning, fixed-state) | 66/66 PASS |
| `verify_stdlib_sum_p3.rb` (2-arg field form, fixed-state) | PASS |
| `verify_sumtype_collect_p3.rb` (filter_map, fixed-state) | 95/95 PASS |
| `verify_lab_numeric_decimal_boundary_p1.rb` (regression) | 62/62 PASS |

## 1. Edit sites (exact, as planned in P1)

- **Ruby TC** `typechecker.rb` `infer_sum_call`: arity gate now `{1,2}`; a 1-arg scalar
  branch validates the element type against `NUMERIC_SUM_FAMILIES`
  (`Integer`/`Float`/`Decimal`/`Unknown`) and returns the element type exactly, else
  `OOF-COL8`. The 2-arg field path is unchanged.
- **Rust TC** `typechecker/stdlib_calls.rs` `"sum"` arm: the bare-`Decimal` default is
  replaced — 1-arg returns `get_param(coll, 0)` (the element type) with the same
  Numeric check + `OOF-COL8`; the 2-arg field path is preserved in the `else` branch.
- **Rust VM** `vm.rs` `"sum"`: a new `"sum" if args.len() == 1` arm sums the elements
  directly (`Integer`/`Float`/`Decimal{value,scale}`), reading family and Decimal scale from
  the elements; empty → `Integer 0` (additive zero, consistent with the field form);
  non-numeric → fail-closed.
- **Inventory** `stdlib-inventory.json`: the **previously-missing** `stdlib.collection.sum`
  entry is added (both forms documented; `output_signature: "T"`; diagnostics
  `OOF-COL1/2/5/8`; `lowering_status: dual-toolchain`); `stdlib_surface_digest` recomputed.
- **ch8 §8.2**: both the scalar and field-projection signatures are now documented.

## 2. Behaviour (grounded, dual-toolchain)

| Probe | Ruby | Rust |
|---|---|---|
| `sum(Collection[Integer]) -> Integer` | clean | clean |
| `sum(Collection[Float]) -> Float` | clean | clean |
| `sum(Collection[Decimal[2]]) -> Decimal[2]` | clean | clean |
| `sum(Collection[Decimal[2]]) -> Decimal[4]` | `OOF-TY1` | `OOF-TY1` (scale preserved) |
| `sum(Collection[Integer]) -> Float` | `OOF-TY1` | `OOF-TY1` (no implicit widening) |
| `sum(Collection[Float]) -> Decimal[2]` | `OOF-TY1` | `OOF-TY1` (no Float→Decimal via sum) |
| `sum(Collection[Text])` | `OOF-COL8` | `OOF-COL8` (non-numeric) |
| `sum()` (arity 0) | `OOF-COL1` | — |
| `sum(xs, :field)` (2-arg) | clean | clean |

`OOF-COL8` is a new diagnostic ("scalar sum element type must be Numeric…"), mirrored in
both toolchains.

## 3. VM execution (live)

| Input | Result |
|---|---|
| `sum([1,2,3,4])` | `10` (Integer) |
| `sum([1.5,2.5])` | `4.0` (Float) |
| `sum([{value:150,scale:2},{value:250,scale:2}])` | `{value:400, scale:2}` — **Decimal[2] scale preserved** |
| `sum([])` | `0` (additive zero) |

## 4. Empty-collection identity (limitation, honest)

For non-empty collections the family and `Decimal` scale are read from the elements
(correct). For an **empty** collection the VM returns `Integer 0` — the universal additive
zero — because there is no element to read the family/scale from at runtime. This matches
the existing 2-arg field-sum behaviour and is only observable on empty collections (which
`bookkeeping` does not hit). The TYPE is still `T` (e.g. `Decimal[N]`); only the runtime
value's family on empty is the universal zero. Synthesising `decimal(0,N)` on an empty
collection would require threading the static element type into the VM `sum` call — deferred.

## 5. BK-P04

`bookkeeping` `VerifyBalancing` uses `sum(debit_amounts)` over `Collection[Decimal[2]]`.
With scalar sum landed, the Rust full compile is clean and the value preserves
`Decimal[2]`. BK-P04 is solved by scalar `sum`, not `fold` or app migration; the app source
is unchanged by this card. (The independent Ruby `Decimal + Decimal` numeric-parity gate was
closed separately by `LANG-RUBY-NUMERIC-OPS-PARITY-P1`.)

## 6. Regression / fixed-state

- `verify_stdlib_sum_p3.rb` (the 2-arg field proof): five assertions that asserted "1-arg
  sum → OOF-COL1" were updated to fixed-state — 1-arg is now the scalar form
  (`sum(Collection[Row])` non-numeric → `OOF-COL8`; `sum(Collection[Integer])` → valid).
- `verify_sumtype_collect_p3.rb` J-02/J-03: updated to fixed-state — `batch_importer` was
  migrated to `filter_map` by the migration card (unrelated to sum); they now assert the
  migrated reality.
- Boundary regression (no implicit `Float/Integer → Decimal` coercion; `decimal()` identity)
  holds 62/62.

## 7. Closed surfaces

No app source migration; no `avg`/`min`/`max`/`group_by`/`reduce`/aggregation framework; no
implicit numeric coercion; no `Money` type; no parser change.

## 8. Next

`bookkeeping` remaining Ruby residual is the independent `Decimal + Decimal` numeric-parity
(now closed by `LANG-RUBY-NUMERIC-OPS-PARITY-P1`). Optional: thread the static element type
into the VM scalar-sum call so an empty `Collection[Decimal[N]]` yields `decimal(0,N)`
instead of `Integer 0`.
