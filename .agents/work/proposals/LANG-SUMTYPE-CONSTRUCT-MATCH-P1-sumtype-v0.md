# LANG-SUMTYPE-CONSTRUCT-MATCH-P1 — Built-in Sum-Type Construct & Match Readiness

**Status:** CLOSED — READINESS PROVED 76/76 — ROUTE: P2 PLANNING (sealed-variant reuse)
**Track:** lang / type-system / built-in sumtypes (Option + Result) construct & match
**Date:** 2026-06-14
**Authority:** readiness + unification planning only — NO implementation
**Card:** LANG-SUMTYPE-CONSTRUCT-MATCH-P1
**Unifies:** LANG-STDLIB-COLLECTION-FIRST-LAST-OPTION-P1 · LANG-STDLIB-OUTCOME-BIND-P1 · LANG-OPTIONAL-FIELD-PARTIAL-RECORD-PROP-P2

---

## 0. TL;DR

`Option[T]` and `Result[T,E]` are **recognized types in both toolchains** (ch3 §3.1),
but they are **not constructible and not matchable** dual-clean:

- **Construction** diverges hard: **Ruby has NONE** (`some/none/ok/err/unwrap_or/
  and_then/first` all → `OOF-TY0 Unknown function`); **Rust is PARTIAL** (`some`,
  `unwrap_or`, `first` clean; `none/ok/err/and_then` recognized but infer
  `Option[Unknown]`/`Result[Unknown,…]`).
- **Matchability** is dual-broken **consistently**: `match opt { Some {…} None {…} }`
  → **`OOF-KIND4` "subject has type 'Option' which is not a variant"** in BOTH
  (PROP-044 §9.1 deferred it).
- **`or_else` is the one dual-clean reader** (the v0 idiom).
- **User-`variant` match IS dual-clean** — the `variant_construct` + `match_node`
  machinery works; only the `OOF-KIND4` non-variant guard keeps Option/Result out.

**Route:** recognize `Option`/`Result` as **sealed built-in variants** and route them
through the **existing variant match machinery** (lift the `OOF-KIND4` guard for the
two sealed types). v0 **construction = function aliases** (`some/none/ok/err`,
already spec'd in ch8 and Rust-partial); v0 **match = variant-style arms**
(`Some/None/Ok/Err`). Because a construct/match spelling asymmetry and the SIR shape
are genuinely undecided, **route to P2 implementation planning**, not direct impl.

---

## 1. Measured dual-toolchain state (76/76 proof)

| Construct | Ruby canon TC | Rust lab TC |
|---|---|---|
| `Option[T]` / `Result[T,E]` annotation | ✅ accepted | ✅ accepted |
| `or_else(opt, fb)` | ✅ clean | ✅ clean |
| `some(v)` | ❌ `OOF-TY0 Unknown function: some` | ✅ clean |
| `unwrap_or(r, fb)` | ❌ Unknown function | ✅ clean |
| `first(coll)` → Option | ❌ Unknown function | ✅ clean |
| `none()` / `ok(v)` / `err(e)` / `and_then` | ❌ Unknown function | ⚠️ recognized, payload `Unknown` (`OOF-TY1`, not `OOF-TY0`) |
| `Some { value: v }` constructor-form | ❌ `OOF-KIND2` (not a user arm) | ❌ `OOF-KIND2` |
| `match opt { Some/None }` | ❌ `OOF-KIND4` + cascade `OOF-P1` | ❌ `OOF-KIND4` + `OOF-TY1` |
| `match v { … }` over a user `variant` | ✅ clean | ✅ clean |

Spec: ch3 §3.1 declares `Option[T] -- Some(T) | None` and `Result[T,E] -- Ok(T) | Err(E)`;
ch8 §8.3–8.4 names `some/none/ok/err/map/unwrap_or` but **not `and_then`**; PROP-044
§9.1 explicitly defers Option match ("Option[T] is not a `variant`… deferred… `or_else`
remains the idiomatic Option handler"). Inventory has only `stdlib.option.or_else`
(dual) + `stdlib.option.wrap` (single-toolchain orphan); no some/none/ok/err/first/
last/and_then entries.

---

## 2. The twelve proof questions

**Q1. What do canon docs say (names/constructors/helpers/matchability)?**
`Option[T]`/`Result[T,E]` are built-in parameterised types (ch3 §3.1) with arm spelling
`Some(T)|None` / `Ok(T)|Err(E)`. ch8 specs `some/none/ok/err/map/flat_map/unwrap_or`
(no `and_then`). **No spec for source-level Option/Result match** — PROP-044 §9.1
defers it; `or_else` is the v0 reader.

**Q2. What compiles in Ruby vs Rust?** See §1 table. **Ruby: only `or_else` (+ type
annotations).** **Rust: `or_else`, `some`, `unwrap_or`, `first` clean; `none/ok/err/
and_then` recognized-but-Unknown-payload.** `map_get` returns Option (both, via the
Map surface). The divergence is asymmetric: Rust is partially implemented, Ruby is not.

**Q3. Why does `match opt { Some/None }` fail? Exact code/stage?** **`OOF-KIND4`** in
BOTH — "match subject has type 'Option' which is not a variant". The arms **parse**
fine; failure is at **kind classification** (the match path fast-rejects any subject
that is not a user-declared `variant`). Ruby then cascades `OOF-P1 Unresolved symbol:
value`; Rust cascades `OOF-TY1`. So it is a *kind-guard* gap, not a parser or
arm-shape gap.

**Q4. Reuse variant match machinery, or a separate path?** **Reuse.** User-`variant`
`match` is dual-clean today; the only thing blocking Option/Result is the
`OOF-KIND4` non-variant guard. Model `Option`/`Result` as **sealed built-in variants**
(implicit arms `Some/None`, `Ok/Err`) and admit them to the existing `match_node`
path. A separate match path would duplicate proven machinery and risk divergence.

**Q5. v0 constructor spelling?** **Function aliases** `some(v)/none()/ok(v)/err(e)`:
(a) spec'd in ch8, (b) already Rust-recognized, (c) the constructor-form `Some {…}`
is rejected `OOF-KIND2` in BOTH (it collides with the user `variant_construct` path).
**Asymmetry to lock in P2:** construct via `some(v)` (function), match via `Some {…}`
(variant arm). Either accept the asymmetry or also admit `Some {…}` construction for
the sealed types — a deliberate P2 decision.

**Q6. v0 SIR shape?** **Reuse `variant_construct` / `match_node` with a sealed/builtin
marker** (e.g. `builtin: "Option"`), rather than dedicated `option_construct`/
`result_construct` nodes. This maximizes reuse of the dual-clean machinery and gives
optional-field P3 (`option_construct{some|none}`) a single shared lowering. P2
finalizes whether the marker rides on `variant_construct` or a thin alias node.

**Q7. Diagnostics?** Reuse existing codes — `OOF-KIND1` (non-exhaustive), `OOF-KIND2`
(arm not in the type), `OOF-KIND4` (subject not a sum type — now *passes* for sealed
Option/Result, still fires for non-sum subjects), `OOF-TY1` (payload/type mismatch),
`OOF-TY0` (wrong constructor arity / unknown). **No new OOF code is justified.**
Fail-closed must be preserved for non-sumtype subjects and malformed arms.

**Q8. Does first/last Ruby parity depend on matchability?** **No.** `first`/`last`
return `Option[T]`, readable via the dual-clean `or_else` even before matchability.
So `LANG-STDLIB-COLLECTION-FIRST-LAST-P2` (Ruby parity) **can land first** with an
explicit "or_else-only ergonomics until match lands" caveat.

**Q9. Does `Result.and_then` satisfy lead_router LR-P01?** **Yes, once Result is
dual-clean.** `lead_router`'s railway is `Result[Ctx, {stage,message}]` with bind;
a dual-clean built-in `Result` + `and_then` removes the 7 hand-written `match prev`
steps. ⇒ prefer **Candidate A** (complete the built-in Result monad) over Candidate B
(a bind combinator over a user 2-arm variant); B becomes unnecessary.

**Q10. How does optional-field `T? ≡ Option[T]` consume this?** Omitted field →
`none()`; present `T` → `some(T)`; read via `or_else` or (post-P3) `match`. No nullable
runtime value — `None` is a **named sealed arm**, not null. Optional-field P3 reuses
the same construction + lowering this card routes.

**Q11. Inventory gaps?** Add entries for `some/none/ok/err/unwrap_or/and_then` (and
`first/last` from the collection track) with `lowering_status` starting `ruby-only`/
`rust-only` as appropriate and ending `dual-toolchain` after P3. Reconcile the
`stdlib.option.wrap` orphan (single-toolchain) — either promote or remove.

**Q12. Safest P2/P3 split?** **P2 implementation planning first.** There is genuine
ambiguity (construct/match spelling asymmetry §Q5; SIR marker shape §Q6; Candidate
A-vs-B already adjudicated to A but needs an impl plan). P2 locks spelling + SIR +
the per-pass edit list; P3 does the dual-toolchain implementation with a fleet
parity proof.

---

## 3. Route decision

**Recognize `Option`/`Result` as sealed built-in variants reusing the proven variant
match machinery.** v0 construct = function aliases (`some/none/ok/err`); v0 match =
variant-style arms (`Some/None/Ok/Err`); SIR = sealed marker on
`variant_construct`/`match_node`; diagnostics reuse OOF-KIND/OOF-TY. **Route → P2
implementation planning.**

Sequencing of the dependent tracks:
- `LANG-STDLIB-COLLECTION-FIRST-LAST-P2` — may proceed independently (or_else caveat).
- `LANG-STDLIB-RESULT-BIND-P2` — Candidate A (built-in Result + `and_then`), gated on this.
- `LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3` — gated on Option construction + lowering here.

### Acceptance
- ✅ Grounds the route in all three predecessors (first/last, outcome-bind, optional-field).
- ✅ Separates construction / matchability / stdlib-helper parity / optional-field lowering.
- ✅ Names v0 source spelling + SIR shape (function-alias construct + sealed-variant match), routes spelling/SIR finalization to P2.
- ✅ Defines Option/Result reuse of user-variant machinery without dynamic-dispatch widening (sealed/static arms).
- ✅ Preserves fail-closed for non-sumtype subjects + malformed arms (OOF-KIND/OOF-TY).
- ✅ No implementation; no app source edits.

---

## 4. Proof

```
runner:  igniter-lang/experiments/sumtype_construct_match_proof/verify_sumtype_construct_match_p1.rb
result:  76/76 PASS
sections: A spec (9) / B types accepted (5) / C construction state (13) / D or_else (3) /
          E constructor-form rejected (4) / F matchability gap (8) / G machinery reuse (6) /
          H predecessor convergence (8) / I inventory (6) / J route (8) / K closed (6)
```

---

## 5. Closed surfaces (this P1)

No parser/typechecker/emitter/runtime change; no optional-field impl; no first/last
Ruby parity impl; no `Result.and_then` impl; no app migration; no nullable runtime
value; no dynamic dispatch widening; no VM/runtime authority.

---

## 6. Open routes

| Card | Scope |
|------|-------|
| LANG-SUMTYPE-CONSTRUCT-MATCH-P2 | Implementation planning: lock construct/match spelling + SIR sealed marker + per-pass edits + fleet parity matrix |
| LANG-STDLIB-COLLECTION-FIRST-LAST-P2 | Ruby parity for first/last (or_else caveat) — may proceed |
| LANG-STDLIB-RESULT-BIND-P2 | Built-in Result + `and_then` (Candidate A) — gated here |
| LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3 | `T?` omit→none / present→some lowering — gated here |
