# LANG-SUMTYPE-COLLECT-P1 — Readiness

**Status:** CLOSED — READINESS PROVED — ROUTE: P2 `filter_map` (TC HOF arm) + match-param sub-gap
**Track:** lang / stdlib / sumtype collection extraction / readiness
**Date:** 2026-06-15
**Authority:** readiness and design only — NO implementation
**Gate:** may run before/after P3; implementation gates on `LANG-SUMTYPE-CONSTRUCT-MATCH-P3` (CLOSED)

---

## 0. TL;DR

`batch_importer` BI-P01 wants `Collection[ImportRecord]` extracted from the `Valid`
arm of a `Collection[RowResult]` (a **user** `variant`). Today `filter` keeps the
element type `RowResult`, and you cannot project a variant payload outside a `match`.

**Recommended v0 surface — one primitive covers everything:**

```
filter_map(xs : Collection[T], fn : T -> Option[U]) -> Collection[U]
```

The callback returns `Option[U]`; `filter_map` keeps each `Some(u)`'s payload and
drops every `None`. For BI-P01:

```igniter
filter_map(results, r -> match r {
  Valid   { record } => some(record)
  Invalid { }        => none()
})   -- : Collection[ImportRecord]
```

This is the smallest surface because it is **agnostic to T**: the element may be a
user `variant` (`RowResult`), a sealed built-in `Option`/`Result`, or anything — only
the callback's `Option[U]` return matters. It reuses P3's now-dual-clean `Option`
construction + `match`, does **not** overload `map`, and subsumes the Result case
(`Ok{value}=>some(value); Err{}=>none()`) without a Result-specific surface.

**It is a TypeChecker HOF arm (like `map`/`filter`/`fold`), not a library call**, and
it surfaces one separable dependency: **`match`-arm result unification currently drops
type parameters** (a parametric `match` returning `Option[ImportRecord]` collapses to
bare `Option`). P2 must either preserve match params (preferred, general) or have
`filter_map` drive `U` from the `Collection[U]` output context.

---

## 1. The gap, grounded (empirical, dual-toolchain)

`batch_importer` is dual-clean (Ruby ok/0, Rust ok/0; baseline frozen by
`LAB-BATCH-IMPORTER-BASELINE-P1`, 161/161). Probes against the live compilers
(`variant RowResult { Valid { record : ImportRecord } | Invalid { row_id, message } }`):

| Probe | Ruby | Rust |
|---|---|---|
| `filter_map(rs, r -> …)` | `OOF-TY0 Unknown function: filter_map` | same |
| `collect(rs, r -> …)` | `OOF-TY0 Unknown function: collect` | same |
| `filter(rs, IsValid) : Collection[RowResult]` | clean — **element type unchanged** | clean |
| `map(rs, r -> r.record)` | `OOF-P1 Unresolved field: RowResult.record` | same |
| `match r { Valid{record} => some(record); Invalid{} => none() } : Option[ImportRecord]` | `OOF-TY1 expected Option[ImportRecord], got Option` | same |

So: (a) the extraction primitive is **absent and dual-consistent**; (b) `filter` cannot
change the element type; (c) a variant payload is **unreachable outside `match`**; and
(d) even the manual `match → some/none` building block does not yield a *parameterised*
`Option` — see §4.

## 2. Why `filter_map`, not `collect` / `partition` / a Result helper

| Candidate | Verdict |
|---|---|
| **`filter_map(T -> Option[U]) -> Collection[U]`** | ✅ **v0.** Minimal, composable (filter+map fused), agnostic to T, reuses P3 `Option`+`match`, one surface for user-variant AND built-in extraction. |
| `collect` (as the function name) | ❌ name only. `collect` conventionally means "materialise an iterator"; it does not describe filter-and-project. Keep `collect` as the *track* name; the function is `filter_map` (consistent with the `map`/`filter` family in ch8 §8.2). |
| `partition_result(Collection[Result[T,E]]) -> (Collection[T], Collection[E])` | ⛔ deferred. Result-specific; needs tuple/Pair ergonomics the app does not have; BI-P01 needs **one** arm, not a split. |
| Result-specific `collect`/`oks`/`errs` | ⛔ deferred. `filter_map` already expresses it via `Ok{value}=>some(value)`. Adding a Result-only surface duplicates the general primitive. |
| overload `map` for Result/Option | ⛔ explicitly closed by this card. |

## 3. The nine questions

1. **Best model?** Option-returning **filter-map**. Not partition (split, not needed),
   not a Result helper (the app is a user variant; `filter_map` subsumes Result anyway).
2. **v0 spelling + signature.** `filter_map(xs : Collection[T], fn : T -> Option[U]) -> Collection[U]`.
   Keeps `Some` payloads in order, drops `None`.
3. **Needs source-level `match Option/Result`?** No. `filter_map` only *reads* the
   callback's `Option[U]` **constructor return type**; it does not itself `match`. The
   BI-P01 callback `match`es the **user** variant `RowResult` (dual-clean pre-P3) and
   constructs `Option` (P3). `filter_map` never matches Option/Result.
4. **Library call or TC support?** **Typechecker support** — a new HOF arm beside
   `map`/`filter`/`fold`. It must bind the callback param to `T`, inspect the callback's
   `Option[U]` return, and produce `Collection[U]`. Not expressible as a plain library
   call (no first-class generic functions; lambda-return inference is TC-special).
5. **Current map/filter/fold lambda inference.** `map`: binds the callback param to the
   element type `T`, infers the body type `U`, returns `Collection[U]`. `filter`: binds
   param to `T`, requires `Bool` body (`OOF-COL3`), returns `Collection[T]` (element
   unchanged). `fold`: 3-arg `(acc:A, elem:T)`, body must be `A`. `filter_map` mirrors
   `map` but unwraps the body's `Option[U]` to `U`. (Ruby `infer_collection_hof_call`;
   Rust `stdlib_calls.rs` `map`/`filter` arms — structurally symmetric, as for P3.)
6. **Malformed-callback diagnostics.** Reuse the `OOF-COL` family — no new code:
   `OOF-COL1` wrong arity; `OOF-COL2` non-`Collection` first arg; `OOF-COL3`-analog
   "callback must return `Option[U]`" (when the body resolves to a non-`Option`,
   non-`Unknown` type) — mirrors `filter`'s "predicate must return `Bool`".
7. **Generalises to sealed built-ins AND user variants?** **Yes, uniformly** — it is the
   key property. `filter_map` constrains only the callback's `Option[U]` return, not the
   element `T`. User-variant extraction (`RowResult`) and built-in `Result`/`Option`
   extraction are the same call. No separate user-variant path; the only built-in
   dependency is `Option`, made dual-clean by P3.
8. **Pressures that collapse.** **BI-P01** (primary — collapses directly). **BI-P07**
   (first-error surfacing) is *enabled*: `first(filter_map(rows, r -> match r {
   Invalid{message}=>some(message); Valid{}=>none() }))` → `Option[String]` (needs the
   existing `first` + `filter_map`). **lead_router LR-P01** is *not* a collect need — it
   is `Result` railway sequencing already served by built-in `Result` + `and_then` (P3 /
   RESULT-BIND). So `filter_map` collapses BI-P01 and enables BI-P07; it does not touch LR-P01.
9. **Out of scope for P2.** `partition`/`partition_result` + Pair/tuple; Result-specific
   `oks`/`errs`/`collect`; `group_by`/`sort_by`/indexed-`map` (BI-P03); String→Int parse
   (BI-P02); storage write (BI-P06); migrating `batch_importer` off the user variant
   (BI-P04); any `map` overload.

## 4. Separable dependency — match-arm parametric unification (sub-gap)

A parametric `match` does **not** preserve its type parameter through arm unification.
`unify_match_arm_types` (both toolchains) reduces arms to their type **name** and returns
`type_ir(concrete.first)` — so `match r { Valid{record}=>some(record);
Invalid{}=>none() }` collapses to bare `Option` (params dropped), failing an
`Option[ImportRecord]` boundary (`OOF-TY1`, confirmed live in both). This bites any
parametric-returning `match` (Option/Result/Collection/Map), not just `filter_map`.

Consequence for `filter_map`: if it reads `U` from the callback's collapsed `Option`,
`U = Unknown`. Two P2 routes:

- **(A) Preferred — preserve match-arm params.** Make `unify_match_arm_types` unify
  *structurally* (keep params when names agree, `Unknown` is the join bottom). Small,
  general, improves `match` ergonomics broadly; then `filter_map` reads `Option[U]`
  directly. P3's expected-type propagation already lets `none()` recover `U` inside the
  callback, so all arms become `Option[U]` and structural unify yields `Option[U]`.
- **(B) Fallback — drive `U` from context.** `filter_map` takes `U` from the
  `Collection[U]` output annotation (P3's `output_type_hints` lever), tolerating a
  bare-`Option` callback return. Scopes `filter_map` alone but leaves the match
  limitation in place.

**Recommendation:** P2 lands (A) as a prerequisite step (or a sibling P-card), then
`filter_map` is a thin mirrored HOF arm. Either way, **implementation gates on P3**
(callback needs `match` + `some`/`none`), which is CLOSED.

## 5. Route + sequencing

- **P2** = implementation planning for `filter_map`: lock the HOF arm edit sites (mirror
  `map`), the `OOF-COL` diagnostics, the SIR `call` shape (`stdlib.collection.filter_map`,
  qualified), and **decide (A) vs (B)** for the match-param sub-gap. Then a dual-toolchain
  P3 implements it (mirrored, like the sumtype wave).
- **Inventory:** P-impl adds `stdlib.collection.filter_map` (`lowering_status` none →
  dual-toolchain), beside `map`/`filter`. ch8 §8.2 gains a `filter_map` line.
- **Unblocks:** BI-P01 extraction; BI-P07 first-error (with existing `first`); a future
  `batch_importer` migration off the user variant (BI-P04) becomes purely ergonomic.

## 6. Closed surfaces (this P1)

No implementation; no app migration; no `map` overload for Result; no
`partition`/Pair; no parser/runtime change; no `group_by`/`sort_by`/indexed-map; no
String→Int parse / storage write.
