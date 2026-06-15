# LANG-STDLIB-COLLECTION-SUM-SCALAR-P1 — Readiness / Implementation Planning

**Status:** CLOSED — PLAN PROVED — DECISION: authorize scalar `sum(Collection[T]) -> T`; dual-toolchain P2 (TC + VM)
**Track:** lang / stdlib / collection sum scalar form
**Date:** 2026-06-15
**Authority:** planning only — no implementation in P1

---

## 0. TL;DR

`bookkeeping` BK-P04 wants the one-argument scalar form `sum(xs : Collection[Numeric]) ->
Numeric` (e.g. `sum(debit_amounts)` over `Collection[Decimal[2]]`). It is **specified** in
ch8 §8.2 (`sum(xs: Collection[T]) -> T -- requires Numeric[T]`) but **not implemented** —
and the three layers disagree:

| Layer | 1-arg `sum(xs)` today |
|---|---|
| **ch8 spec** | `Collection[T] -> T` (element-typed) — the correct intent |
| **Ruby TC** | `OOF-COL1` — strictly rejected (only `sum(xs, :field)` authorized) |
| **Rust TC** | silently resolves to **bare `Decimal`** (a hardcoded default), so it `OOF-TY1`s against any `Integer`/`Float`/`Decimal[N]` output — a latent bug, "works" only when the result feeds `==` (as in `VerifyBalancing`) |
| **VM** | only 2-arg field projection (`sum expects exactly 2 arguments`) — scalar `sum` cannot execute |

**Decision:** **authorize scalar `sum(Collection[T]) -> T`** (Integer / Float / Decimal[N]),
returning the **element type T** (not bare `Decimal`), with the empty-collection identity
synthesized per family — `Decimal[N]`'s identity is the explicit `decimal(0, N)`
(`LANG/LAB-NUMERIC-DECIMAL-CONSTRUCT-P1`), so no implicit coercion. Implement **dual-toolchain
in P2** (Ruby TC + Rust TC fix + VM execution), because the Rust default is a latent bug and
VM execution is required for `bookkeeping` to run. BK-P04 is solved by scalar `sum`, not
`fold` and not app migration — `sum(debit_amounts)` is already the natural, ch8-matching spelling.

---

## 1. Grounded current state (dual-toolchain, live)

`sum(Collection[T])` against a typed `-> T` output:

| Probe | Ruby | Rust |
|---|---|---|
| `sum(Collection[Integer]) -> Integer` | `OOF-COL1` + `OOF-TY1` | `OOF-TY1` (sum→`Decimal` ≠ Integer) |
| `sum(Collection[Float]) -> Float` | `OOF-COL1` + `OOF-TY1` | `OOF-TY1` (sum→`Decimal` ≠ Float) |
| `sum(Collection[Decimal[2]]) -> Decimal[2]` | `OOF-COL1` + `OOF-TY1` | `OOF-TY1` (sum→bare `Decimal` ≠ `Decimal[2]`) |
| `sum(Collection[R], :field) -> F` (2-arg, sanity) | clean | clean |
| `decimal(0, 2) -> Decimal[2]` (the Decimal identity) | clean | clean |

So scalar `sum` produces a usable scalar in **neither** toolchain: Ruby rejects it; Rust
types it as bare `Decimal`, which fails for `Integer`/`Float` and drops scale for `Decimal[N]`.
The only reason `bookkeeping` Rust is `ok/0` is that `VerifyBalancing` feeds the sum into
`total_debits == total_credits` (a `Decimal == Decimal` comparison), never into a scaled
output.

## 2. The nine questions

**Q1 — Authorize scalar `sum`, or spell it `fold(xs, zero, …)`?** **Authorize scalar `sum`.**
It is ch8-specified, ergonomic, and the *de facto* spelling in `bookkeeping`. `fold` is the
lower-level fallback but requires the author to write the zero seed explicitly (and for
`Decimal[N]` that seed is `decimal(0, N)`) — scalar `sum` hides exactly that. The Rust
bare-`Decimal` default is a latent bug that authorization fixes.

**Q2 — Element types accepted?** The Numeric family: `Integer`, `Float`, `Decimal[N]`. A
non-numeric element type is rejected with a diagnostic (Q7). `Unknown` element passes
permissively (consistent with the rest of the collection HOFs).

**Q3 — Return type for `Collection[Decimal[N]]`, scale preservation?** **`Decimal[N]` — the
element scale, preserved.** Summation is repeated `Decimal[N] + Decimal[N]`, which keeps
scale `N` (existing `OOF-TC5` rule: equal scale → same scale). The result type **is the
element type T**, never bare `Decimal`. (Fixing Rust's default is the core of P2.)

**Q4 — Empty-collection identity per family?** `Integer → 0`, `Float → 0.0`,
`Decimal[N] → decimal(0, N)` (zero at the element's scale). The empty sum is the additive
identity of the element family.

**Q5 — How does the TC know the identity without a seed?** From the **element type** of
`Collection[T]`. `T` (including a `Decimal` scale) fully determines both the return type and
the zero identity; no seed argument is needed. Scalar `sum` returns `T`.

**Q6 — Does the VM/runtime support scalar `sum`?** **No** — the VM `sum` op requires exactly
2 arguments and reads a **field** from record items. P2 must add a **1-arg VM branch** that
sums the elements directly and returns the family zero on empty (`Integer 0`, `Float 0.0`,
`Decimal { value: 0, scale }`). The element-summing logic already exists in the field path
(it sums `Value::Integer` / `Value::Decimal{value,scale}`); the 1-arg branch reuses it
against elements instead of `element.field`.

**Q7 — Diagnostics: wrong arity vs non-numeric element?** After authorization, **arity ∈
{1, 2} is valid**, so the arity gate changes (`OOF-COL1` only for arity ∉ {1,2}). Dispatch by
arity: 1-arg = scalar (validate `T` is Numeric → a non-numeric element raises a
Numeric-family diagnostic, e.g. reuse `OOF-COL2`/a new `OOF-COL6` "element must be Numeric");
2-arg = field projection (unchanged: `OOF-COL5` for the `:field`). Keep the two forms
unambiguous: 1-arg has no second arg; 2-arg requires a `Symbol`.

**Q8 — Interaction with `Decimal[N]` money policy / explicit `decimal(0,N)` identity?**
Scalar `sum` over `Collection[Decimal[N]]` stays **entirely within the Decimal family** —
the empty identity is the explicit `decimal(0, N)` from CONSTRUCT-P1, and non-empty sums are
`Decimal[N] + Decimal[N]`. **No implicit `Float→Decimal` coercion** is introduced; scalar
`sum` is fully consistent with `LAB-NUMERIC-DECIMAL-BOUNDARY-P1`.

**Q9 — Dual-toolchain in P2, or Ruby-first?** **Dual-toolchain.** Unlike the field-projection
form (Ruby-first P3), scalar `sum` requires (a) fixing Rust's latent bare-`Decimal` default,
and (b) a VM execution path — so Ruby TC + Rust TC + VM must move together. Ruby-first would
leave Rust mis-typing and `bookkeeping` unable to run.

## 3. P2 edit sites (exact)

| Layer | Site | Change |
|---|---|---|
| Ruby TC | `typechecker.rb` `infer_sum_call` (~:2844) | Branch on arity: **1-arg → scalar** (return `element_type_from_collection`, validate Numeric, `OOF-COL6` on non-numeric); 2-arg → existing field path. Arity gate accepts `{1,2}`. |
| Rust TC | `typechecker/stdlib_calls.rs` `"sum"` arm (~:349) | Replace the bare-`Decimal` default: **1-arg → `get_param(coll, 0)`** (element T), validate Numeric; 2-arg → existing field path. |
| Rust VM | `vm.rs` `"sum"` (~:1065) | Add a **1-arg branch**: sum elements directly; empty → family zero (`Integer 0` / `Float 0.0` / `Decimal{0, scale}`). |
| Inventory | `stdlib-inventory.json` | **Add the missing `stdlib.collection.sum` entry** (no entry exists today) covering both forms; recompute `stdlib_surface_digest`. |
| Spec | ch8 §8.2 | Scalar form already documented (`sum(xs) -> T`); add the 2-arg field-projection form alongside for completeness. |

## 4. Decision record

- **Authorize scalar `sum(Collection[T]) -> T`** (Integer/Float/Decimal[N]); return **T**, not
  bare `Decimal`; preserve `Decimal` scale.
- **Empty identity** synthesized per family; `Decimal[N]` → `decimal(0, N)` (CONSTRUCT-P1).
  No implicit coercion (boundary policy preserved).
- **BK-P04 is solved by scalar `sum`** — not `fold`, not app migration.
- **Dual-toolchain P2** (Ruby TC + Rust TC fix + VM); add the inventory entry + digest.

## 5. Follow-up

`LANG-STDLIB-COLLECTION-SUM-SCALAR-P2` (implementation, dual-toolchain). After it lands,
`bookkeeping` `VerifyBalancing`/`ComputeAccountBalance` compile and run dual-clean (closing
the BK-P04 Ruby `sum` residual noted in the bookkeeping migration). The separate Ruby
`Decimal + Decimal` numeric-parity gap (`LANG-RUBY-NUMERIC-OPS-PARITY`) is independent.

## 6. Closed surfaces (this P1)

No compiler/VM/app changes; no implicit numeric coercion; no generalized aggregation
framework; no `avg`/`min`/`max`/`group_by`/`reduce` expansion.
