# LANG-SUMTYPE-CONSTRUCT-MATCH-P2 — Implementation Planning

**Status:** CLOSED — PLAN PROVED 78/78 — ROUTE: single dual-toolchain P3
**Track:** lang / type-system / built-in sumtypes / implementation planning
**Date:** 2026-06-14
**Authority:** implementation planning only — NO compiler changes
**Gate:** LANG-SUMTYPE-CONSTRUCT-MATCH-P1 CLOSED 76/76

---

## 0. TL;DR

The two toolchains are **structurally symmetric**: each has a 3-level
`variant_shapes` registry, an `OOF-KIND4` "subject not a variant" guard in
`infer_match_expr` (byte-identical message), and the same `variant_construct` /
`match_node` SIR shapes. So admitting sealed `Option`/`Result` is **5 mirrored
edit sites per side**:

1. **Register** sealed `Option`/`Result` into the `variant_shapes` registry at TC startup.
2. **Relax** the `OOF-KIND4` guard for `{Option, Result}` only.
3. **Construct** via `some/none/ok/err` (Ruby: new dispatch arms; Rust: extend `stdlib_calls.rs`).
4. **Mark** SIR `variant_construct`/`match_node` with `sealed: true` (sealed-only; user-variant byte shape unchanged).
5. **(refinement)** expected-type propagation so `none()`/`ok()`/`err()` infer the missing payload param.

**Route = a single dual-toolchain P3** — splitting Ruby/Rust risks a SIR byte-parity
window (the whole fleet's dual-clean depends on identical SIR). Sites 1-4 are the
unblock; site 5 is a separable refinement (can be P3b).

---

## 1. Exact insertion points (mirrored, confirmed live)

| # | Ruby canon | Rust lab |
|---|---|---|
| Registry | `typechecker.rb` ~`variant_shapes` builder (`def variant_type?` :238, `find_variant_for_arm` :277) — pre-register Option/Result after the user build | `typechecker.rs` `build_variant_shapes` :3555 + init :300-303; `variant_type_exists` :3587, `find_variant_for_arm` :3591 |
| OOF-KIND4 guard | `typechecker.rb` `infer_match_expr` :3194-3201 (`unless variant_type?(subject_type) …`) | `typechecker.rs` `infer_match_expr` :3732-3745 (`!self.variant_type_exists(...)`) |
| Construct | `typechecker.rb` call dispatch :1000-1057 (Unknown-fn fallthrough :1055) — add `some/none/ok/err` arms | `typechecker/stdlib_calls.rs` — `some`@628, `none`@640, `ok`@647, `err`@662 already exist (extend payload inference) |
| OOF-KIND2 (reused) | `typechecker.rb` `infer_variant_construct` :3137-3184 | `typechecker.rs` `infer_variant_construct` :3609-3711 |
| SIR marker | `semanticir_emitter.rb` `semantic_variant_construct` :442-450, `semantic_match_node` :453-463 | `typechecker.rs` annotated `variant_construct` :3695-3701 + emitter `match_node` rename :887-891 |

SIR keys to preserve (both): `variant_construct{kind,arm,variant,fields,resolved_type}`,
`match_node{kind,subject,subject_type,arms,exhaustive,has_wildcard,resolved_type}`.

---

## 2. The twelve planning questions

**Q1. Sealed registry shape.** `Option` → `{ Some: {value: T}, None: {} }`;
`Result` → `{ Ok: {value: T}, Err: {error: E} }`. Loaded into the same 3-level
`variant_shapes` (variant→arm→field→type) at TC startup, after the user build, only
if not already present. `T`/`E` are the type's params (param[0]/param[1]).

**Q2. Construction spelling.** **Function-only in P3** (`some(v)/none()/ok(v)/err(e)`)
— per P1, and because constructor-form `Some {…}` is rejected `OOF-KIND2` in both
(it collides with the user `variant_construct` path). Admitting `Some {…}` for
sealed types is a *possible later* convenience, not v0.

**Q3. Match arm shapes (v0 accepted).** `Some { value }`, `None`, `None { }`,
`Ok { value }`, `Err { error }`. Binding names follow the locked payload labels
(`value`/`error`). `Some { value: x }` (rename binding) follows the existing
user-variant binding grammar.

**Q4. Pass owning sealed kind classification.** The **typechecker** in both —
`variant_shapes` is a TC-time structure; sealed registration + the `OOF-KIND4`
relax live in the TC. Parser is **untouched** (arms already parse as
`variant_construct`/`match` patterns; PascalCase + `{` already routes there).

**Q5. Relaxing OOF-KIND4 for Option/Result only.** Add a 2-name allowlist at the
guard: `variant_type?(t) || t == "Unknown" || t ∈ {"Option","Result"}` (Ruby :3195)
and the mirror (Rust :3732). Because the sealed types are also **registered** in
`variant_shapes` (Q1), arm validation (OOF-KIND2) and exhaustiveness (OOF-KIND1)
then work for free — arbitrary named types stay rejected.

**Q6. SIR marker shape.** `"sealed": true` added **only** to `variant_construct` /
`match_node` nodes whose variant/subject_type ∈ {Option, Result}. User-variant SIR
is **byte-unchanged** (key absent). The variant name already identifies the type, so
the marker is informational/forward-proofing; lock `sealed: true` for both toolchains
identically.

**Q7. Preserve user-variant byte shape.** The marker is conditional (sealed-only), so
existing `variant_construct`/`match_node` JSON for user variants is identical
pre/post. P3 proof asserts byte-identical SIR for the user-variant fixtures.

**Q8. Diagnostics (all reused, no new code).** `OOF-KIND4` non-sumtype subject (still
fires for genuine non-variants); `OOF-KIND2` arm-not-in-Option/Result; `OOF-KIND1`
non-exhaustive (e.g. `Some` without `None`/`_`); `OOF-TY1` payload type mismatch;
`OOF-TY0` wrong constructor arity / unknown name.

**Q9. Inventory.** Add `stdlib.option.{some,none}`, `stdlib.result.{ok,err}`,
`stdlib.option.unwrap_or` (or `result.unwrap_or`), `stdlib.collection.{first,last}`;
keep `stdlib.option.or_else` (dual); reconcile `stdlib.option.wrap` orphan
(promote-or-remove). `and_then` is added by RESULT-BIND-P2, not here. Each starts
`ruby-only`/`rust-partial`, ends `dual-toolchain` after P3.

**Q10. One P3 or split? (risk-based)** **One dual-toolchain P3.** The dominant risk
is **SIR byte-parity** — if Ruby lands the sealed marker / construct SIR before Rust
(or vice versa), the 16-app fleet's SIR goldens diverge and dual-clean breaks. The
two-sided edit is small (~50 lines/side) and mirrored, so a single card keeping them
in lockstep is lower-risk than a Ruby-P3/Rust-P4 split.

**Q11. Regressions.** P1 runner (76/76); this P2 runner (78/78); optional-field P2
(57/57); first/last-Option P1 (54/54); outcome-bind P1 (56/56); **user-variant match
fixtures byte-identical SIR**; full 16-app Wave P11 fleet recheck with **exact
diagnostic sets + SIR goldens**; `rule_engine` fail-closed unchanged.

**Q12. Dependent unblocking.** After P3: `LANG-STDLIB-COLLECTION-FIRST-LAST-P2`
(Ruby parity — may also proceed independently with the or_else caveat),
`LANG-STDLIB-RESULT-BIND-P2` (Candidate A: built-in Result + `and_then`),
`LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3` (`T?` omit→`none()`, present→`some(T)`).

---

## 3. The payload-from-context sub-gap (site 5)

`none()`→`Option[Unknown]`, `ok(v)`→`Result[T,Unknown]`, `err(e)`→`Result[Unknown,E]`;
the missing param is not inferred, so `output : Option[Integer]` with `none()` →
`OOF-TY1` (confirmed live, both). `some()`/`first()` resolve because their param comes
from the argument/collection. Fix via **expected-type propagation** — reuse the
existing `output_type_hints` lever (the fold-seed / record-literal precedent) to pass
the expected `Option[T]`/`Result[T,E]` into the constructor call. **Separable** from
the admission (sites 1-4); can land as P3b if P3 scope is tight.

---

## 4. Route, acceptance, sequencing

**Single dual-toolchain P3:** sites 1-4 (admission + SIR marker) in lockstep; site 5
(payload inference) folded in or P3b. SIR byte-parity is the proof keystone.

### Acceptance
- ✅ Exact mirrored insertion points for both toolchains (§1, live-confirmed).
- ✅ v0 source spelling locked (function-construct + Some/None/Ok/Err match arms) and SIR marker locked (`sealed: true`, sealed-only).
- ✅ User-variant behavior + current diagnostics preserved outside sealed built-ins (Q7/Q8; E-03/E-04 guard).
- ✅ Proof matrix strong enough for direct implementation (regressions Q11 + SIR goldens).
- ✅ Sequences FIRST-LAST-P2 / RESULT-BIND-P2 / OPTIONAL-FIELD-P3.
- ✅ No implementation.

---

## 5. Proof

```
runner:  igniter-lang/experiments/sumtype_construct_match_proof/verify_sumtype_construct_match_p2.rb
result:  78/78 PASS
sections: A gate (5) / B symmetry (8) / C Ruby anchors (9) / D Rust anchors (10) /
          E dual behaviour (9) / F registry locked (6) / G payload sub-gap (7) /
          H SIR marker (5) / I P3 split + diagnostics (7) / J sequencing (6) / K closed (6)
```

---

## 6. Closed surfaces (this P2)

No parser/typechecker/emitter/runtime change; no app migration; no nullable runtime;
no dynamic dispatch widening; no optional-field / first-last / Result implementation.

---

## 7. Open routes

| Card | Scope |
|------|-------|
| LANG-SUMTYPE-CONSTRUCT-MATCH-P3 | Single dual-toolchain impl: register sealed Option/Result + relax OOF-KIND4 + some/none/ok/err construct + `sealed` SIR marker (+ payload propagation as P3/P3b); 16-app SIR-golden parity proof |
| LANG-STDLIB-COLLECTION-FIRST-LAST-P2 | Ruby parity for first/last (or_else caveat) — may proceed in parallel |
| LANG-STDLIB-RESULT-BIND-P2 | Built-in Result + `and_then` (Candidate A) — gated on P3 |
| LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3 | `T?` omit→none / present→some lowering — gated on P3 |
