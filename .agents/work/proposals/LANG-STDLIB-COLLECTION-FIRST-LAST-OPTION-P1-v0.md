# LANG-STDLIB-COLLECTION-FIRST-LAST-OPTION-P1 — Readiness (call_router CR-P03)

**Status:** CLOSED — READINESS PROVED 54/54 — ROUTE: SPLIT TRACK (P2 planning)
**Track:** lang / stdlib.collection + Option / readiness
**Date:** 2026-06-14
**Authority:** proposal/readiness only — no implementation
**Primary evidence:** `call_router` CR-P03 (pure re-model of SparkCRM Ringcentral webhook correlation)

---

## 0. TL;DR

`call_router` wants to pick the most-recent matched CallRail candidate —
`candidates.order(desc).first` — but in pure source that needs `first`/`last`
returning a **matchable** `Option[T]`. Today there are **two separable gaps**:

1. **`first`/`last` are not dual-clean** — Ruby TC: `Unknown function: first/last`;
   Rust TC implements them, returning `Option[T]`.
2. **`Option[T]` is not source-matchable** — `match opt { Some {…} None {…} }` →
   Rust **`OOF-KIND4`** ("match subject has type 'Option' which is not a variant").
   User variants *are* matchable (the app's own `CustomerPhoneOf` matches a user
   `variant Telephony`).

So the app **sidesteps both**: the resolved `matched_call` is **injected**, and the
pure `MatchCall` only `count`s hits to return a user `MatchResult` variant.

**Route: SPLIT TRACK.** Track 1 = dual-toolchain `first`/`last` parity (cheap,
independent, but **insufficient alone** — the returned Option still isn't
consumable). Track 2 = **`Option[T]` construction + matchability** (lift the
PROP-044 §9.1 deferral) — the real unblock, **shared** with
`LANG-OPTIONAL-FIELD-PARTIAL-RECORD-PROP-P2` and `LANG-STDLIB-OUTCOME-BIND-P1`. No
sort/order_by. No implementation in P1.

---

## 1. CR-P03 grounded in source (not over-generalized)

`correlate.ig` / `MatchCall` (the CR-P03 site), verbatim shape:

```igniter
pure contract MatchCall {
  input customer_phone : String
  input candidates : Collection[CallrailCall]
  input matched_call : CallrailCall          -- INJECTED (the DB .first result)
  compute hits = filter(candidates, c -> if c.customer_phone == customer_phone { true } else { false })
  compute n = count(hits)
  compute r = if n > 0 { Matched { call: matched_call } } else { Unmatched { } }
  output r : MatchResult
}
```

The source comment states it: production is
`CallrailInboundCall.where("… LIKE ?").order(created_at: :desc).first`; the pure
core "only decides **IF** a match exists" because `first` returns `Option[T]`, is
Rust-only, and `Option` isn't matchable. **Ordering** (`order(desc)`) is a DB
concern, injected — *not* in scope (this keeps CR-P03 from ballooning into a
query/order subsystem, per the acceptance constraint).

---

## 2. The seven proof questions — answers

**Q1. Current Ruby behavior for `first`/`last`?**
**Not implemented** — `first(xs)` / `last(xs)` → `OOF-TY0 Unknown function: first` /
`last`, with the usual `OOF-TY1` output-mismatch cascade.

**Q2. Current Rust behavior and emitted type?**
**Implemented**, returning **`Option[T]`** — `first(Collection[Integer])` typed
`Option[Integer]` compiles `ok`; `last` is at parity. (Rust uses `Option` as the
total signature: empty collection → `None`.)

**Q3. Is `Option[T]` source-matchable today? OOF proof?**
**No.** `match opt { Some {…} None {…} }` → Rust **`OOF-KIND4`**: *"match subject has
type 'Option' which is not a variant."* `Option[T]` is a built-in parametric type,
not a user `variant`; matching on it is deferred (PROP-044 §9.1). By contrast, user
variants match cleanly (the app's `CustomerPhoneOf` matches `variant Telephony`).

**Q4. Does `or_else` give enough read ergonomics, or is matchability required?**
**Matchability is required for CR-P03.** `or_else(opt, default)` needs a sensible
default of the payload type, but "the most recent `CallrailCall`" has **no zero
value** — fabricating a null record reintroduces the very absence problem `Option`
exists to make explicit. `or_else` suits *scalar*-default reads; selecting a domain
record from a possibly-empty collection wants `match Some/None`. (This is exactly why
the app falls back to a user `MatchResult` variant.)

**Q5. Should `first`/`last` return `Option[T]`, `Unknown`, or fail-on-empty?**
**`Option[T]`.** It is the **total** signature — empty → `None`, no panic, no
partiality — and Rust already proves it. `Unknown` would erase the element type and
defeat downstream typing; fail-on-empty would make a legitimate empty case an error.
`Option[T]` is the canon-correct answer (ch3 §3.1 `Option[T] -- Some(T) | None`).

**Q6. Does `call_router` need ordering beyond `first`/`last` (sort/order_by)?**
**No.** Production orders **in the DB** (`order(created_at: :desc)`); the pure core
receives already-ordered candidates and needs only `.first`/`.last` of them. A
sort/order_by query API is **out of scope** (closed surface) — `.first` pressure is
enough. This is the line that keeps CR-P03 from over-generalizing.

**Q7. Should P2 split `collection.first/last` parity from the Option surface?**
**Yes — split track.** They are **separable authorities**:
- Track 1 (`first`/`last` parity) is a **stdlib.collection** task — mechanical: add
  Ruby `first`/`last` returning `Option[T]` to match Rust. Low-risk, independent.
- Track 2 (Option construction + matchability) is a **type-system / match** task —
  lifting the PROP-044 §9.1 deferral (`Some`/`None` patterns + exhaustiveness, plus
  a construction surface). Larger; shared with optional-field and outcome-bind.

Crucially, **Track 1 alone does not unblock CR-P03**: a Rust-parity `first` still
returns an Option you can't `match` (OOF-KIND4) and can't `or_else` cleanly (no
default). Track 2 is the load-bearing unlock; Track 1 is a cheap independent win.

---

## 3. Convergence — the built-in sum-type debt

This is the **third** readiness card to land on the same root:

| Card | Surfaces the gap as |
|------|---------------------|
| LANG-OPTIONAL-FIELD-PARTIAL-RECORD-PROP-P2 | `T?` ≡ `Option[T]`; needs Some/None construction + (deferred) match |
| LANG-STDLIB-OUTCOME-BIND-P1 | `Result[T,E]` spec'd but not dual-clean; needs `and_then` + construct/match |
| **this card (CR-P03)** | `first`/`last` → `Option[T]` not matchable (OOF-KIND4); needs construct + match |

All three converge on **dual-clean construction + matchability for the built-in sum
types (`Option[T]`, `Result[T,E]`)**. Track 2 here *is* that shared unlock. The
recommendation is to recognize this as a single high-leverage foundational track
rather than re-deriving it per app card. **This card routes `first`/`last` and names
the dependency; it does not duplicate the sum-type work.**

---

## 4. Route decision

**ROUTE = SPLIT TRACK, P2 planning.**

- **Track 1 — dual-toolchain `first`/`last` parity.** Add Ruby `first`/`last`
  returning `Option[T]`; align inventory; dual-clean proof. Independent, mechanical.
- **Track 2 — `Option[T]` construction + matchability.** Lift PROP-044 §9.1: `match
  o { Some { value } => … None { } => … }` + a construction surface; the genuine
  CR-P03 unblock; shared foundational work (see §3).

Default expectation = P2 planning; **no implementation in P1**. `first`/`last`
return `Option[T]`; no sort/order_by/query API.

### Acceptance (card §Acceptance)

- ✅ CR-P03 grounded in `call_router`, not over-generalized into a query/order subsystem (§1, Q6).
- ✅ Ruby/Rust divergence explicitly classified (Q1/Q2: Ruby Unknown fn; Rust → Option[T]).
- ✅ Option matchability + construction separated from `first`/`last` (split track, §2 Q7, §3).
- ✅ No implementation in P1.
- ✅ No app source edits.

---

## 5. Proof

```
runner:   igniter-lang/experiments/stdlib_collection_first_last_option_proof/verify_stdlib_collection_first_last_option_p1.rb
result:   54/54 PASS
sections: A preconditions (6) / B CR-P03 grounded (8) / C first/last divergence (8) /
          D Option matchability OOF-KIND4 (7) / E or_else insufficient (6) /
          F sum-type convergence (6) / G route split (7) / H closed surfaces (6)
```

---

## 6. Closed surfaces

- No implementation.
- No query/order_by/sort API.
- No DB `.first` authority.
- No Option runtime representation change.
- No optional-field implementation (its own PROP-P2 track).
- No app migration.

---

## 7. Open routes (successors)

| Card | Scope |
|------|-------|
| LANG-STDLIB-COLLECTION-FIRST-LAST-P2 (planning) | Track 1: dual-toolchain `first`/`last` → `Option[T]`; Ruby parity + inventory + proof matrix |
| (foundational) Option construction + matchability | Track 2: lift PROP-044 §9.1 — `Some`/`None` match + construction; shared with optional-field PROP-P2 + outcome-bind. Recommend a unified sum-type track |
| LAB-STDLIB-FOUNDATION | stdlib surface governance context |
