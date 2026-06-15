# LANG-MATCH-ARM-PARAM-UNIFICATION-P1 — Readiness + Implementation Planning

**Status:** CLOSED — READINESS PROVED 72/72 — ROUTE: (A) structural param-preserving join; implement in a dedicated P2 impl card
**Track:** lang / typechecker / match / parametric arm unification
**Date:** 2026-06-15
**Authority:** readiness and implementation **planning** only — NO implementation
**Gate:** after `LANG-SUMTYPE-CONSTRUCT-MATCH-P3` (CLOSED) + `LANG-SUMTYPE-COLLECT-P1` (CLOSED). May run parallel to `LANG-SUMTYPE-COLLECT-P2`; P2 must consume this decision.

---

## 0. TL;DR

`unify_match_arm_types` (both toolchains) reduces every match arm to its type
**name** and rebuilds the result with `type_ir(name)` — so a `match` whose arms all
resolve to `Option[ImportRecord]` collapses to **bare `Option`** (params dropped).
This is **dual-consistent**, **byte-identical** across Ruby canon and Rust lab, and
**not Option-specific**: `Result`, `Collection`, and `Map` collapse identically.

**Decision: ACCEPT route (A) — preserve params via a structural join.** Replace the
name-reduction with a position-wise recursive join over the arm type IRs:

- same top-level name across arms ⇒ join params position-wise;
- **`Unknown` is the join bottom** (Q4): `join(Unknown, X) = X` — the concrete side wins;
- preserve the joined type **iff** it is non-empty-param **and** not
  `unknown_or_unknown_bearing?`; **otherwise fall back to exactly today's
  `type_ir(name)`** (bare).

This makes the change a **pure precision widening**: it newly *preserves* a param
only where all arms already agree on a concrete one (the BI-P01 case); in every other
case the output is byte-identical to today. Name divergence keeps `OOF-KIND5`;
non-parametric matches stay byte-unchanged. The building blocks
(`structurally_assignable?`, `unknown_or_unknown_bearing?`, `type_ir`) already exist
in **both** toolchains, so the edit is a localized, single-call-site, two-function
mirror — the same discipline as the sumtype wave.

---

## 1. The gap, grounded (empirical, dual-toolchain)

Probes against the **live** compilers (Ruby canon + Rust release binary). Subject is
the live `batch_importer` shape `variant RowResult { Valid { record : ImportRecord } | Invalid { row_id, message } }`,
plus a minimal `variant Flag { On | Off }` to isolate the bug from sealed machinery:

| Fixture (arms all resolve to →) | Ruby | Rust | Meaning |
|---|---|---|---|
| `match r { Valid{record}=>some(record); Invalid{}=>none() } : Option[ImportRecord]` | `OOF-TY1 got Option` | same | **Option** param dropped |
| `match r { Valid{record}=>ok(record); Invalid{message}=>err(message) } : Result[ImportRecord,String]` | `OOF-TY1 got Result` | same | **Result** params dropped |
| `match f { On{}=>recs; Off{}=>recs } : Collection[ImportRecord]` | `OOF-TY1 got Collection` | same | **Collection** param dropped |
| `match f { On{}=>mp; Off{}=>mp } : Map[String,ImportRecord]` | `OOF-TY1 got Map` | same | **Map** params dropped |
| same Option match `: Option` (bare boundary) | **clean** | clean | result IS bare `Option` |
| `match r { Valid{record}=>record; Invalid{}=>fb } : ImportRecord` | **clean** | clean | non-parametric unaffected |
| `match f { On{}=>1; Off{}=>"x" } : Integer` | `OOF-KIND5` | same | name divergence unchanged |

Two facts pin the diagnosis:

1. **The arms individually carry the param.** `some(record) : Option[ImportRecord]`,
   `none() : Option[ImportRecord]` (via P3 `@sealed_output_hints`), `ok(record)`,
   `err(message)` all typecheck clean against the parameterised boundary. So each
   `arm_type` entering unification is already `Option[ImportRecord]` /
   `Result[ImportRecord,String]`. **The only lossy step is the unify itself.**
2. **The same match is accepted against the *bare* type** (`: Option`), proving the
   produced `resolved_type` is literally `{name:"Option", params:[]}`.

## 2. The root cause — exact insertion points

**Ruby — `lib/igniter_lang/typechecker.rb` `unify_match_arm_types` (≈ line 3552):**

```ruby
def unify_match_arm_types(arm_types, subject_type, node_name, type_errors)
  return type_ir("Unknown") if arm_types.empty?
  concrete = arm_types.map { |t| type_name(t) }.reject { |t| t == "Unknown" }.uniq  # ← drops params to a String
  return type_ir("Unknown") if concrete.empty?
  return type_ir(concrete.first) if concrete.length == 1                            # ← rebuilds with params=[]
  type_errors << oof("OOF-KIND5", "... divergent arm result types: ...", node_name)
  type_ir("Unknown")
end
```

**Rust — `igniter-compiler/src/typechecker.rs` `unify_match_arm_types` (≈ line 4088):**
structurally identical — `arm_types.iter().map(|t| self.type_name(t))` into a
`HashSet<String>`, then `self.type_ir(&Value::String(concrete[0].clone()))`.

Single call site each (`Ruby:3501`, `Rust:4054`), feeding the `match_expr`
`resolved_type`. The fix is contained entirely within this one function per toolchain.

## 3. The nine questions

1. **Where exactly do Ruby & Rust drop params?** In `unify_match_arm_types`: both map
   each arm to `type_name(t)` (a bare string), dedup, then rebuild the single survivor
   with `type_ir(name)` which sets `params: []`. Insertion points in §2.
2. **Only `Option`, or all parametric types?** **All of them.** The reduction is
   name-only and family-agnostic — `Result`, `Collection`, and `Map` collapse
   identically (proved live, dual). Fixing unify fixes every parametric `match`.
3. **Safest v0 join rule when names match and params differ?** A **position-wise
   recursive structural join** with `Unknown` as bottom (§4). Where two *concrete*
   params genuinely conflict at the same position, **degrade to today's bare result**
   rather than newly rejecting — this keeps v0 a pure precision widening (zero
   regression). A stricter param-divergence diagnostic is deferred (Q5).
4. **How should `Unknown` params behave: bottom, wildcard, or mismatch?** **Bottom.**
   `join(Unknown, X) = X` — the concrete partner wins; `join(Unknown, Unknown) =
   Unknown`. This matches the existing `structurally_assignable?` policy (expected
   `Unknown` accepts any) and the current "reject top-level `Unknown` arms" behavior.
   Not wildcard (would freeze the result at `Unknown` and lose the recoverable param),
   not mismatch (would over-reject and regress).
5. **Diagnostics for incompatible parametric arms?** v0 emits **no new diagnostic**:
   genuine concrete-param conflict silently degrades to the bare type (today's
   behavior) and surfaces, if at all, at the existing output boundary as `OOF-TY1`.
   Reserve **`OOF-KIND6` "divergent arm parameters"** as an opt-in *stricter* surface
   for a later card — keeping P1/P2 a clean no-regression change. Top-level name
   divergence keeps `OOF-KIND5` unchanged.
6. **Does preserving params change existing user-variant match SIR or only
   `resolved_type`?** **Only `match_expr.resolved_type`, and only where params are
   currently being dropped.** The fallback rebuilds via `type_ir(name)` exactly as
   today for non-parametric / unknown-bearing / conflicting cases, so non-parametric
   match SIR is **byte-unchanged**. Arms, `variant_env`, the sealed `sealed:true`
   marker, and payload bindings are all untouched. (The fresh `{name, params:[…]}` is
   built only when concrete params are preserved — a case that produced an *error*
   today, so no clean golden depended on the old bare shape.)
7. **What regressions must prove no behavior change for non-parametric matches?**
   (a) non-parametric arm result (`… => record; … => fb : ImportRecord`) stays clean;
   (b) name divergence stays `OOF-KIND5` with the same message; (c) all-`Unknown`
   arms still yield `Unknown`; (d) arms that resolve to `Option[Unknown]` still
   degrade to bare `Option` (not a spurious `Option[Unknown]`). All four are asserted
   in the proof (§G) and pass dual-toolchain today; the fix must keep them green.
8. **Small enough for direct implementation in P2, or P1 plans only?** **Small enough
   to implement in a single dedicated P2 impl card** — a localized two-function mirror
   reusing existing helpers, one call site each, with the SIR-parity discipline of the
   sumtype wave. **P1 plans only** (this card's authority); implementation requires an
   explicit P2/P3 card.
9. **How does this unblock `filter_map` and future parametric match expressions?**
   With params preserved, the `filter_map` callback body `match r { … => some(u); … =>
   none() }` resolves to `Option[U]` directly, so `filter_map` reads `U` and emits
   `Collection[U]` as a thin **`map` mirror** (COLLECT-P1 route (A)). Route (B)
   (driving `U` from the `Collection[U]` output annotation) becomes unnecessary. More
   broadly, every parametric-returning `match` (Result railways, nested
   Option/Collection, Map) gains correct inference.

## 4. The locked v0 join algorithm

Pseudocode (both toolchains mirror it; helpers already exist):

```
unify_match_arm_types(arm_types):
  present = arm_types.reject { |t| type_name(t) == "Unknown" }       # top-level Unknown arms contribute nothing
  return type_ir("Unknown") if present.empty?
  names = present.map { type_name }.uniq
  if names.length > 1:
    emit OOF-KIND5(divergent names); return type_ir("Unknown")        # UNCHANGED top-level divergence path
  name = names.first
  joined = present.reduce { |acc, t| join_types(acc, t) }             # nil ⇒ conflict
  if joined && !joined["params"].empty? && !unknown_or_unknown_bearing?(joined):
    return joined                                                     # PRECISION WIN: e.g. Option[ImportRecord]
  return type_ir(name)                                                # EXACT legacy fallback (bare)

join_types(a, b):                # precondition: type_name(a) == type_name(b) (single shared name here)
  pa, pb = a["params"], b["params"]
  return nil if pa.length != pb.length                               # arity conflict ⇒ degrade
  joined = []
  pa.zip(pb).each { |x, y| joined << join_param(x, y) or return nil }
  { "name" => type_name(a), "params" => joined }

join_param(x, y):
  return y if type_name(x) == "Unknown"                              # Unknown = BOTTOM
  return x if type_name(y) == "Unknown"
  return nil if type_name(x) != type_name(y)                         # concrete conflict ⇒ degrade (v0)
  join_types(x, y)                                                   # recurse (handles Map[String, Option[..]] etc.)
```

Key properties:
- **Pure precision widening.** Every path except "all arms agree on a concrete param"
  returns `type_ir(name)` — byte-identical to today.
- **Unknown = bottom** throughout (Q4), so P3's partially-recovered arms (one arm
  `Option[ImportRecord]`, another transiently `Option[Unknown]`) still join up to
  `Option[ImportRecord]`.
- **No new error in v0** (Q5); `OOF-KIND6` reserved for a later stricter card.
- **Recursive**, so nested parametrics (`Collection[Option[T]]`, `Map[String, Result[T,E]]`)
  preserve correctly.

## 5. Interaction with P3 expected-type propagation

The fix and P3 compose cleanly and are **complementary, not overlapping**:

- **P3** (`@sealed_output_hints`) makes the *constructor arms* parameterised:
  `none()`/`err()`/`ok()` recover the missing param from the Option/Result-annotated
  output boundary, so both arms enter unification already carrying the concrete param.
- **This fix** stops unify from throwing that param away.

Because P3 already lands the param on each arm, the structural join recovers
`Option[U]` in **one step** with no extra context plumbing. This is why route (A) is
strictly cleaner than route (B): (B) would re-derive `U` from the `Collection[U]`
output hint, duplicating information the arms already carry.

## 6. Route, sequencing & gating

- **Route:** **(A) preserve params structurally.** Recommended over (B) — general
  (fixes all parametric matches, not just `filter_map`), minimal, zero-regression.
- **Implementation card:** a dedicated dual-toolchain P2 impl card (or fold into
  `LANG-SUMTYPE-COLLECT-P2`'s impl step). Edit `unify_match_arm_types` in both
  toolchains in lockstep; add a `join_types`/`join_param` private helper each; proof
  runner asserting (i) the four parametric families now preserve, (ii) the four
  no-regression baselines unchanged, (iii) SIR byte-parity for user-variant matches.
- **`LANG-SUMTYPE-COLLECT-P3` gating — reconciliation with COLLECT-P2 (CLOSED).**
  COLLECT-P2 (already closed, 73/73) chose route **(B)** for `filter_map` — drive `U`
  from the declared `Collection[U]` output context via a new `@collection_output_hints`
  lever reusing P3's `sealed_output_hints` temp-install — and explicitly recorded that
  *"P3 does NOT hard-gate on LANG-MATCH-ARM-PARAM-UNIFICATION (fallback B2)"*, citing
  this card's *"high blast radius (moves every parametric match's result type)."*
  **This card revises that risk assessment downward:** §4 shows route (A) is a *pure
  precision widening* — every path except all-arms-agree-on-a-concrete-param returns
  the byte-identical legacy `type_ir(name)`, name-divergence keeps `OOF-KIND5`, and
  user-variant SIR is byte-unchanged (proof §G, dual-toolchain). So the blast radius is
  **bounded to gaining params on currently-erroring matches**, not perturbing clean
  ones. **Net:** as-planned, COLLECT-P3 does **not** hard-gate on this (B is the
  fallback). (A) is recommended as an **independent, low-risk general improvement** that
  — once landed — lets a future `filter_map` shed the (B) `@collection_output_hints`
  plumbing and become a thin `map` mirror. The two are compatible: ship (A) when
  convenient; it strictly subsumes (B)'s need.
- **Unblocks:** `filter_map` (thin `map` mirror, Q9); Result-railway matches;
  nested-parametric and `Map`-valued matches across the fleet.

## 7. Closed surfaces (this P1)

No implementation. No new syntax. No runtime changes. No app migration. No widening of
variant arm matching. No generic type inference beyond match-result unification. No
`OOF-KIND6` in v0 (reserved). P1 ends at PLAN; implementation needs explicit P2/P3
reauthorization.

## 8. Proof

`experiments/match_param_unification_proof/verify_match_arm_param_unification_p1.rb`
— **72/72 PASS** (target ≥60), dual-toolchain against the live Ruby canon and Rust
release binary. Sections A–J: gate/authority, the param-drop (Option headline),
family-agnostic collapse (Result/Collection/Map), arms-carry-the-param,
exact-insertion-points, reusable structural building blocks, the no-regression
baseline, the locked join rule, P3 interaction, and sequencing/gating.
