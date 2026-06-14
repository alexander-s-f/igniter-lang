# LANG-STDLIB-STRING-CONTAINS-ENDS-WITH-P1 — Readiness

**Status:** CLOSED — READINESS PROVED 50/50 — ROUTE: NO NEW IMPLEMENTATION (capability already shipped)
**Track:** lang / stdlib.string / contains + ends_with readiness
**Date:** 2026-06-14
**Authority:** proposal/readiness only — no implementation, no inventory/app edits
**Origin:** call_router CR-P02 (phone suffix / `LIKE %suffix%` matching)

---

## 0. TL;DR (the readiness pivot)

The card's premise — "`stdlib.string` has `char_at`/`substring` but **no** `contains`
or `ends_with`" — is **stale**. The functions already exist:

> `stdlib.text.contains` / `stdlib.text.ends_with` / `stdlib.text.starts_with` are
> **`lifecycle = production-implemented`, `lowering = dual-toolchain`**, return
> **`Bool`**, and accept **`String`** inputs via the canon **String→Text v0 compat
> rule** (ch3 §3.1). Verified end-to-end: a `MatchPhone` contract using
> `ends_with(phone, suffix)` / `contains(phone, suffix)` on `String` inputs compiles
> **dual-clean today** (Ruby 0 / Rust ok 0), both qualified and unqualified.

`call_router`'s belief that they were missing came from looking under the wrong
namespace (`stdlib.string`) — the predicates live under `stdlib.text`.

**Route: NO new implementation. P2 would implement ZERO new functions.** CR-P02 is
resolvable in `call_router` **today** by replacing exact equality with
`ends_with(c.customer_phone, suffix)` (last-N-digits) or `contains(...)` (`%suffix%`).
The only residual is a *namespace-consistency* question (predicates under
`stdlib.text`, slicers `char_at`/`substring` under `stdlib.string`) — optional,
belongs to the **CLOSED** `LANG-STRING-TEXT-ALIAS` lineage, and is **not** required
to unblock the app.

---

## 1. CR-P02 grounded in source (not just report text)

`call_router/correlate.ig` — `MatchCall` (the production CallRail correlation):

```igniter
-- CR-P02: phone matching is EXACT-equality only. CallRail uses LIKE %suffix%;
--   stdlib.string has no contains/ends_with, so fuzzy suffix matching is not expressible.
pure contract MatchCall {
  input customer_phone : String
  ...
  compute hits = filter(candidates, c -> if c.customer_phone == customer_phone { true } else { false })
  ...
}
```

- **Workaround in source:** exact equality `c.customer_phone == customer_phone`.
- **Production behavior (report.md):** `CallrailInboundCall.where("customer_phone_number LIKE ?")` — a `LIKE %suffix%` match. This is a **genuine** production need (phones arrive with country-code / formatting variance; correlation is by trailing digits), not convenience.
- **Registry (CR-P02):** routed to "new `LANG-STDLIB-STRING` contains/ends_with" — the route this card re-evaluates.

The need is real. What is **false** is the premise that the language cannot express it.

---

## 2. The capability already exists — evidence

| Op | Namespace | lifecycle | lowering | shape |
|----|-----------|-----------|----------|-------|
| `contains` | `stdlib.text` | **production-implemented** | **dual-toolchain** | `(Text, Text) -> Bool` |
| `ends_with` | `stdlib.text` | **production-implemented** | **dual-toolchain** | `(Text, Text) -> Bool` |
| `starts_with` | `stdlib.text` | **production-implemented** | **dual-toolchain** | `(Text, Text) -> Bool` |
| `char_at` | `stdlib.string` | lab-implemented | dual-toolchain | precedent (not re-opened) |
| `substring` | `stdlib.string` | lab-implemented | dual-toolchain | precedent (not re-opened) |

(Source: `docs/spec/stdlib-inventory.json`; Ruby TC text-stdlib table; Rust TC
`text_stdlib_return_type` / `check_text_stdlib_call`.)

**Empirical (this proof):**
- `ends_with(phone, suffix)`, `contains(phone, suffix)`, `starts_with(phone, suffix)`
  on `String` inputs → Ruby `0`, Rust `ok/0` (qualified `import stdlib.text.{…}` and unqualified).
- Used directly as a `filter` predicate (`filter(cands, c -> ends_with(c.customer_phone, suffix))`) → dual-clean.
- `call_router` whole app compiles `ok/0` today.

---

## 3. The seven proof questions

**Q1. Does call_router prove a real production need (not convenience)?**
**Yes.** CallRail correlation is `customer_phone_number LIKE %suffix%` in production
(report.md). Phone numbers vary by formatting/country-code; matching is by trailing
digits. The pure model was forced to exact equality only because the author believed
the predicate was absent.

**Q2. Minimal op for phone matching — `ends_with`, `contains`, or both?**
**Both already exist, so the minimal-surface question is moot.** Mapping:
`LIKE %suffix%` (substring anywhere) = `contains`; "last-N-digits" correlation =
`ends_with`. P2 implements **neither** new — both are shipped.

**Q3. Should they live under `stdlib.string.*` and return `Bool`?**
They live under **`stdlib.text.*`** and **return `Bool`**. A duplicate
`stdlib.string.*` binding is **not** recommended: `Text` is the canonical text type
and `String` is accepted at `Text` positions (v0 compat). If canon later wants
namespace symmetry with `char_at`/`substring`, that is an **aliasing** decision under
the CLOSED `LANG-STRING-TEXT-ALIAS` lineage — not a new function.

**Q4. Byte/string exact only, Unicode/case folding closed?**
**Yes — exact.** The registered ops take two `Text` positions with no fold/locale
flag; matching is byte/string exact. Case folding, locale, and Unicode normalization
stay **closed**.

**Q5. Diagnostics for arity/type mismatch — OOF-TY0 or string-specific?**
**`OOF-TY0`** (verified): wrong arity → `stdlib.text.ends_with: expected 2
argument(s), got 1`; wrong type → `stdlib.text.ends_with arg 2: expected Text, got
Integer`. No new string-specific OOF code is needed or introduced.

**Q6. Dual-toolchain implementation shape if P2/P3 proceeds?**
**N/A — there is no P2/P3 implementation.** The ops are already implemented in both
toolchains and lowered. A follow-up, if any, is documentation/namespace only.

**Q7. Text vs String interaction, or strictly String?**
The surface is strictly **`Text`**. `String` works at those positions via the
canon String→Text v0 compat rule (`⊢ "x" : String` accepted as `Text`). No
String-specific overload is required.

---

## 4. Route decision

**ROUTE = NO NEW IMPLEMENTATION.**

- `contains` / `ends_with` / `starts_with` are production-implemented, dual-toolchain,
  `Bool`-returning, String-compatible **today**.
- **CR-P02 is resolvable now**: `call_router/MatchCall` can use
  `ends_with(c.customer_phone, suffix)` (or `contains`) instead of exact `==`. (App
  migration is out of this card's scope — closed surface — but the capability is
  there.)
- **No P2 implementation card is authorized.** Optional, non-blocking follow-up: a
  namespace-consistency note (predicates under `stdlib.text` vs slicers under
  `stdlib.string`) routed to the CLOSED `LANG-STRING-TEXT-ALIAS` lineage if canon
  wants the symmetry. Not required for call_router.

### Acceptance (card §Acceptance)

- ✅ CR-P02 grounded in source/report and production-proven (§1).
- ✅ Existing `char_at`/`substring` treated as precedent, not re-opened (§2 table; F-section).
- ✅ Names whether P2 implements one function or two: **neither — both already exist** (Q2).
- ✅ No compiler or inventory edits in P1.
- ✅ No app source edits.

---

## 5. Proof

```
runner:  igniter-lang/experiments/stdlib_string_surface_proof/verify_stdlib_string_contains_ends_with_p1.rb
result:  50/50 PASS
sections: A preconditions (6) / B CR-P02 grounded (6) / C already-shipped inventory (6) /
          D empirical dual-clean (9) / E diagnostics+semantics (6) / F precedent+namespaces (5) /
          G route=no-impl (6) / H closed surfaces (6)
```

---

## 6. Closed surfaces

- No implementation. No regex. No locale / case folding / Unicode normalization.
- No fuzzy scoring. No phone-number parser. No DB LIKE authority. No app migration.
- No compiler or inventory edits.

---

## 7. Open routes (successors)

| Card | Scope |
|------|-------|
| (none required) | CR-P02 is unblockable today with the shipped `stdlib.text.ends_with`/`contains` |
| (app, optional) call_router phone-match adoption | swap exact `==` for `ends_with`/`contains` in `MatchCall` — app-side, separate |
| (optional, non-blocking) namespace consistency | `stdlib.string.*` predicate aliases vs `stdlib.text.*` — `LANG-STRING-TEXT-ALIAS` lineage (CLOSED) |
