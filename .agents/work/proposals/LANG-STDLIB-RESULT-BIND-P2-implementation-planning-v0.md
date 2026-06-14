# LANG-STDLIB-RESULT-BIND-P2 — Implementation Planning (Candidate A)

**Status:** CLOSED — PLAN PROVED 66/66 — ROUTE: thin Result layer gated on Sumtype P3
**Track:** lang / stdlib.result / bind-and-then
**Date:** 2026-06-14
**Authority:** implementation planning only — NO compiler changes
**Gate:** LANG-STDLIB-OUTCOME-BIND-P1 (56/56) · LANG-SUMTYPE-CONSTRUCT-MATCH-P1 (76/76) · P2 (78/78)

---

## 0. TL;DR

Complete the **built-in `Result[T,E]` monad** (Candidate A) with the minimal
surface `lead_router` LR-P01 needs: **`ok` · `err` · `unwrap_or` · `and_then`**
under **`stdlib.result.*`**. `and_then` is `Result[T,E] × (T -> Result[U,E]) ->
Result[U,E]` (E fixed, **lambda-only**, no dynamic callee). This collapses
`lead_router`'s **7** hand-written `match prev { Reject => carry; Proceed => work }`
steps into one auto-short-circuiting `and_then` chain.

Current state (live): **Ruby has NONE** (all 4 → `Unknown function`); **Rust is
PARTIAL** (`ok/err/and_then` arms exist but infer `Unknown` payload; `unwrap_or`
clean). So the work is **Ruby parity + dual payload inference** — the *same* sites
and the *same* expected-type lever (`output_type_hints`) as Sumtype P3.

**Route: a thin Result layer, gated on Sumtype P3** (which lands `ok`/`err` as
sealed-Result construction + SIR). Crucially **bind needs construction, not source
`match`** — `and_then`+`unwrap_or` consume Result functionally. Recommendation:
**fold the 4 Result arms into Sumtype P3** (they touch identical dispatch sites and
the identical payload lever), or land them as the immediate follow-on.

---

## 1. The eleven planning questions

**Q1. Surface for LR-P01 v0.** `ok(v)`, `err(e)`, `unwrap_or(r, fb)`,
`and_then(r, λ)`. **`map` is DEFERRED** — the name `map` is owned by
`stdlib.collection.map`; `map(Result,…)` → `OOF-COL2` in both today, and the
railway doesn't need it (it binds, not maps).

**Q2. Namespace.** **`stdlib.result.*`** — distinct from `stdlib.outcome.*`
(PROP-047 Map[String,String] inspection predicates, a different axis) and from
`stdlib.collection.map`. Source spelling = function aliases `ok/err/unwrap_or/
and_then` resolving to `stdlib.result.*`. ch8 §8.4 already names `ok/err/map/
unwrap_or`; P3 adds `and_then` to the spec.

**Q3. `and_then` signature.** `Result[T,E] × (T -> Result[U,E]) -> Result[U,E]`.
**E is fixed** across the bind in v0 (the continuation may change `T→U` but keeps
the error type). Different/widened error types = deferred. (`lead_router` is
`Result[Ctx, {stage,message}]` — fixed E fits perfectly.)

**Q4. Continuation.** **Lambda only** in v0 (matches the existing Rust
`flat_map|and_then` arm that infers `U` from the lambda body). A statically-named
contract may be called *inside* the lambda (`and_then(r, x -> ok(call_contract("Step", x)))`).
**No dynamic callee** — dynamic dispatch stays closed.

**Q5. Ruby insertion points.** Add `ok/err/unwrap_or/and_then` arms in the call
dispatch **before the `Unknown function` fallthrough** (`typechecker.rb` ~:1055),
mirroring `stdlib_calls.rs`. `ok`/`err` are the **sealed-Result constructors**
shared with Sumtype P3; `unwrap_or` returns `param[0]`; `and_then` is a HOF arm that
binds `acc:T` and infers `Result[U,E]` from the lambda body (same shape as the fold
lambda handling).

**Q6. Rust fixes.** `ok(v)`→`Result[T,Unknown]`, `err(e)`→`Result[Unknown,E]`,
`and_then`→Err-type can fall to `Unknown` — all are the **payload-from-context
gap**. Fix by the Sumtype-P2 lever: propagate the expected `Result[T,E]` (via
`output_type_hints`) into the constructor/bind call so the missing param resolves.
`unwrap_or` already clean.

**Q7. SIR shape (coordinated with Sumtype P2).** `ok`/`err` emit
`variant_construct` with `sealed: true` (Ok/Err arms, payload label `value`/`error`)
— the Sumtype P2 locked shape. `and_then`/`unwrap_or` emit ordinary stdlib **`call`
nodes** (like `fold`/`map` ops) — **no new SIR node type**.

**Q8. `and_then` vs source `match`.** **Bind lands WITHOUT match.** `and_then` +
`unwrap_or` are stdlib functions over Result; consuming a Result needs no
`match Ok/Err`. So Result bind is a thin layer on top of Sumtype P3's `ok`/`err`
construction; `match Ok/Err` (Sumtype P3) is orthogonal and not required for LR-P01.

**Q9. Diagnostics (reuse, no new code).** wrong arity → `OOF-TY0`/arity; non-Result
first arg → a first-arg type error (COL-style, mirroring `map`'s `OOF-COL2`); lambda
return not `Result` → `OOF-TY1`; error-type mismatch / Unknown payload → `OOF-TY1`
(the payload-context gap). No `OOF-RES*` code is justified — `and_then` validates
like an existing HOF.

**Q10. App proof.** `lead_router`'s 7-step railway re-expressed as a single
`and_then` chain over `Result[Ctx, Reject]`:
```igniter
result =
  and_then(and_then(and_then(ok(ctx0),
    c -> find_trade(c)), c -> find_vendor(c)), c -> find_zip(c)) … -- ×7
final = unwrap_or_result(result, …)   -- or match in Sumtype P3
```
No user `variant`, no dynamic dispatch — each step is `Ctx -> Result[Ctx, Reject]`
and `and_then` carries the `Err` automatically (removing the 7 `Reject => carry`
arms). P3 proves a fixture of this shape compiles dual-clean.

**Q11. Closed.** No audit receipts, retry policy, runtime routing, capabilities,
user-variant generic bind (Candidate B rejected).

---

## 2. Insertion anchors (live-confirmed)

| | Ruby canon | Rust lab |
|---|---|---|
| ok / err (construct) | NEW arms before `Unknown function` fallthrough `typechecker.rb`~:1055 (shared with Sumtype P3 sealed Result) | `typechecker/stdlib_calls.rs` `ok`@647 / `err`@662 (fix Err/Ok-payload) |
| unwrap_or | NEW arm (Ruby missing) | `stdlib_calls.rs` `unwrap_or`@327 (clean) |
| and_then | NEW HOF arm (Ruby missing) | `stdlib_calls.rs` `flat_map\|and_then`@558 (fix Err-type) |
| SIR | `semantic_variant_construct` (sealed via Sumtype P2) | annotated `variant_construct` + emitter (Sumtype P2) |
| payload lever | new expected-type pass | reuse `output_type_hints` (typechecker.rs) |

---

## 3. Route & sequencing

**Thin Result layer, gated on Sumtype P3** (for `ok`/`err` sealed construction +
the SIR sealed marker). `and_then`/`unwrap_or` add on top with **no match
dependency**. **Recommendation:** fold the four `stdlib.result.*` arms into Sumtype
P3 (identical dispatch sites + identical payload-context lever) — one pass over the
Ruby dispatch and the Rust payload inference instead of two. If kept separate, this
is `LANG-STDLIB-RESULT-BIND-P3`, landing immediately after Sumtype P3.

### Acceptance
- ✅ Chose `stdlib.result.*` (not `stdlib.outcome.*`; not `collection.map`).
- ✅ Per-toolchain insertion points + payload-context fix + proof matrix.
- ✅ Dynamic dispatch stays closed (lambda-only, no dynamic callee).
- ✅ SIR/constructor shape coordinated with Sumtype P2 (sealed `variant_construct`).
- ✅ States gating: implementation waits for Sumtype P3 construction; bind needs no match.
- ✅ No implementation.

---

## 4. Proof

```
runner:  igniter-lang/experiments/stdlib_result_bind_proof/verify_stdlib_result_bind_p2.rb
result:  66/66 PASS
sections: A gate (5) / B Result state (9) / C map-collision+namespace (6) /
          D railway evidence (6) / E Ruby anchors (7) / F Rust anchors (7) /
          G locked decisions (8) / H bind≠match+gating (6) / I diagnostics+reexpr (6) / J closed (6)
```

---

## 5. Closed surfaces

No parser/typechecker/emitter/runtime change; no app source migration; no
user-variant generic bind; no retry/policy/capability authority; no dynamic dispatch
widening; no audit receipt model.

---

## 6. Open routes

| Card | Scope |
|------|-------|
| LANG-SUMTYPE-CONSTRUCT-MATCH-P3 | Sealed Option/Result construct+match (consider folding the 4 `stdlib.result.*` arms in here) |
| LANG-STDLIB-RESULT-BIND-P3 (if separate) | `ok/err/unwrap_or/and_then` dual-clean + payload inference; LR-P01 and_then-chain fixture |
| (downstream) lead_router railway migration | Replace 7 `match prev` steps with an `and_then` chain (its own app card) |
