# LANG-OPTIONAL-FIELD-PARTIAL-RECORD-PROP-P2 — Optional Record Fields (`field : T?`)

**Status:** CLOSED — PROP PROVED 57/57 — ROUTE: P3 IMPLEMENTATION READINESS (conditional)
**Track:** lang / PROP / optional record fields
**Date:** 2026-06-14
**Authority:** full PROP authoring only — no compiler implementation, no app migration
**Card:** LANG-OPTIONAL-FIELD-PARTIAL-RECORD-PROP-P2
**Gate:** LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P1 (62/62) CLOSED
**Grounding:** PROP-004 / ch3-type-system §3.1–3.2 (`Option[T] -- Some(T) | None`; record width subtyping) · PROP-043 (`or_else`) · PROP-044 §9.1 (Option is built-in, match deferred)

---

## 0. Abstract

`field : T?` on a record type declaration is **surface sugar for `field : Option[T]`**,
the type the canon type system already defines as `Some(T) | None` (ch3 §3.1, Stage-1
subset). The `?` marker additionally makes the field **omissible at construction**:

- omit it → the field is `None` (compiler-injected);
- give it a `T` value → auto-wrapped to `Some(v)`;
- give it an `Option[T]` value → taken as-is.

A read `r.field` has type `Option[T]` and is unwrapped with the **existing** `or_else`
(PROP-043) — there is **no raw-`T` read** of an optional field, so absence is
fail-closed at the type level (no null-deref). The runtime value of an omitted field
is **named**: it is the canon `Option[T]` `None` arm, not an untyped `null`/`nil`.

This PROP defines omission, read, output-assignability, serialization, and
wrong-type semantics, and ends at **P3 implementation readiness**, conditional on two
named, bounded P3 tasks.

---

## 1. Motivation & current state

**Origin:** `vector_editor` `GraphicObject` declares `path_pts : Collection[Point]?`,
`rect_data : RectData?`, `text_data : TextData?`. The `?` is currently a **no-op**:

| Toolchain | `?` handling today |
|-----------|--------------------|
| Ruby | lexer drops `?`; `String?` parses as `String`; `type_shapes` keeps only `name→type_ir` |
| Rust | parser keeps `FieldDecl.optional: bool`, but `build_type_shapes` drops it before validation |
| Both | partial record over a `T?` field → `OOF-TY0` "missing required field" + `OOF-TY1` cascade |

So apps must supply explicit values for every field (`path_pts: []`). P1 proved this is
a **real dual-toolchain gap** and routed a full PROP because omission touches type
shapes, validation, output assignability, serialization, and possible runtime/null
semantics (62/62).

---

## 2. The seven PROP questions — normative answers

### Q1. What does `field : T?` mean in type-shape metadata?

`field : T?` is **exactly `field : Option[T]`**. In the type shape, the field's type is
recorded as `Option[T]` **and** the field carries an `optional: true` flag (so the
constructor knows omission is permitted; an explicitly-spelled `Option[T]` field without
`?` may also be treated as optional — see §3). No new kind of "optional metadata" is
invented beyond what canon already has for `Option[T]`.

### Q2. May a record literal omit the field? If yes, absent or present-with-value?

**Yes, it may be omitted.** When omitted, the field is **present with value `None`**
— *not* absent. The record stays **rectangular** (every declared field has a value in
the constructed record and in the SIR). Omission is a construction convenience; it is
never a hole in the record's shape. Three accepted construction forms:

```
{ ..., field: v }            -- v : T          → Some(v)        (auto-wrap)
{ ..., field: opt }          -- opt : Option[T]→ opt           (as-is)
{ ... }                      -- field omitted  → None           (injected)
```

### Q3. Is there a `None`/nullable runtime value? How do reads work?

**Yes, and it is named.** The value is the canon `Option[T]` **`None` arm** (ch3 §3.1),
a typed sum-type value — **not** an untyped `null`/`nil`/`Unknown`. A read `r.field`
has type `Option[T]` (Rule 3 field access yields the declared type). To obtain a `T`,
the program **must** unwrap:

```
or_else(r.field, default) : T          -- PROP-043, exists today, dual-clean
```

There is **no** way to read an optional field as a raw `T` without handling the `None`
case → **fail-closed**, no null-deref. (`match` on `Option` is deferred per PROP-044
§9.1; `or_else` is the v0 reader.)

### Q4. How does optionality interact with output assignability & structural comparison?

A record literal/value `L` is assignable to an expected record type `R` when:

1. every **required** (non-optional) field of `R` is present in `L` with an assignable
   type (else `OOF-TY0` — unchanged);
2. every **optional** field of `R` may be present (as `T`→`Some`, or `Option[T]`) **or
   absent** (→`None`); absence is **not** an error;
3. `L` has **no field absent from `R`** (unexpected field → `OOF-TY0` — unchanged).

This is consistent with canon **record width subtyping** (`{a,b,c} <: {a,b}`, ch3 §3.2):
optional fields lower the *required* field set. **No relaxation occurs outside
declared-optional fields** — required fields stay strict. Structural comparison treats
two records as equal up to `Option[T]` value equality (`None == None`, `Some(a) == Some(b)`
iff `a == b`), inheriting canon Option covariance.

### Q5. What diagnostics fire?

| Situation | Diagnostic | Status |
|-----------|-----------|--------|
| required (non-optional) field omitted | `OOF-TY0` "missing required field" | **preserved** |
| optional field omitted | — (becomes `None`) | **new: accepted** |
| optional field present with value `: T` | — (wrapped `Some`) | **new: accepted** |
| optional field present with value `: Option[T]` | — | **new: accepted** |
| optional field present with wrong type (neither `T` nor `Option[T]`) | `OOF-TY0` | **preserved (fail-closed)** |
| unexpected field not in type | `OOF-TY0` | **preserved** |
| reading `r.field` and using it as raw `T` without `or_else` | `OOF-TY0`/`OOF-TC1` (type is `Option[T]`, not `T`) | **preserved (fail-closed)** |

No new OOF code is introduced.

### Q6. Does optionality affect serialization / SIR shape?

**The SIR record shape is rectangular and stable**: the field always appears as
`Option[T]`. Omission is lowered to an explicit `None` at construction; a present `T`
to `Some(v)`. Therefore the manifest/serialized shape **does not vary** with omission —
no variable-shape records, no serialization ambiguity, deterministic artifact hash.

This requires one **new SIR node** — `option_construct` — encoding field-level Some/None
(modeled on PROP-044 `variant_construct`):

```json
{ "kind": "option_construct", "case": "some", "value": <expr>, "inner_type": <T-ir> }
{ "kind": "option_construct", "case": "none", "inner_type": <T-ir> }
```

The **runtime representation of `Option[T]` already exists** (stdlib `map_get`/`or_else`
produce/consume it); `option_construct` extends it to construction sites. No new runtime
value family is created.

### Q7. v0 scope — construction only, read semantics only, or both?

**Both construction and read-type — but no new read *surface*.** Concretely, v0 is:

- **In:** `T?` ≡ `Option[T]` sugar; omission→`None`; auto-wrap `T`→`Some`; read-type
  `Option[T]`; unwrap via existing `or_else`; the `option_construct` SIR node;
  output-assignability optional rule; preserved fail-closed diagnostics.
- **Out (deferred):** surface `Some(x)` / `None` literal constructors; `Option`
  pattern-matching (`match opt { Some(v) -> … None -> … }`, PROP-044 §9.1);
  defaulted-fields (`field : T = default`, a *distinct* feature — see §4);
  nested/recursive optionality interactions beyond one level; app source migration.

Construction and read-type are **inseparable**: permitting omission *forces* a defined
read meaning, else the null question reappears. Anchoring reads to the existing typed
`Option[T]` + `or_else` keeps the v0 surface minimal (zero new read syntax).

---

## 3. Formal rules

**Desugaring.** For every record field `f : T?`, set shape type `Option[T]` and
`optional(f) = true`. (An explicitly-spelled `Option[T]` field is constructable by the
same rules; whether bare `Option[T]` is also omissible is a P3 toggle — recommended:
omissible, since it unifies the rule and bare `Option[T]` fields are currently
**unconstructable** in literals, so this is purely additive with no regression.)

**Construction (`{ … }` against expected record `R`).** For each field `f` of `R` with
shape `Option[U]`:
- present `e : U` → lower to `option_construct{some, e}`;
- present `e : Option[U]` → keep `e`;
- present `e : V`, `V ∉ {U, Option[U], Unknown}` → `OOF-TY0` (fail-closed);
- absent → lower to `option_construct{none, U}`.
For each **required** field of `R`: absent → `OOF-TY0` (unchanged).
Any literal field not in `R` → `OOF-TY0` (unchanged).

**Read.** `r.f : Option[U]` (Rule 3). `or_else(r.f, d : U) : U`. No implicit unwrap.

**Assignability.** As Q4: required strict; optional may be absent (→`None`); width-extra
forbidden. No change to any non-record assignability.

**Determinism.** `None`-injection and `Some`-wrapping are pure, total, compile-time
lowering decisions; identical sources produce identical SIR.

---

## 4. Alternatives considered (and why rejected)

| Alternative | Meaning of omission | Verdict |
|-------------|--------------------|---------|
| **Option-anchored `T?` ≡ `Option[T]`** (this PROP) | `None` (named canon value) | **CHOSEN** — canon-aligned, fail-closed reads, rectangular SIR, no new value family |
| Absent field / partial record shape | field truly absent | **Rejected** — variable-shape records break structural comparison, SIR rectangularity, serialization determinism |
| Nullable value (`null`/`nil`) | untyped null | **Rejected** — exactly the "unnamed nullable runtime value" the card forbids; null-deref risk |
| Documentation-only (`?` stays inert) | nothing | **Rejected** — P1 already proved the gap is real and routed a PROP; inert `?` is a latent footgun |
| **Defaulted fields** `field : T = default` | the declared default (type `T`) | **Separate feature, out of scope** — reads stay raw `T` (ergonomically closer to vector_editor's actual want), but needs default-expr syntax + CORE-purity rules and is *not* optionality. Noted as a complementary future PROP. |

The **defaulted-fields** alternative deserves emphasis: vector_editor arguably wants
`path_pts` to *read as* `Collection[Point]` defaulting to `[]`, not as
`Option[Collection[Point]]`. That is a legitimately different feature; `?` (which canon
ties to `Option`) should mean optionality, and defaults should get their own `= expr`
surface. This PROP scopes `?` to Option and explicitly leaves defaults to a future card.

---

## 5. Migration impact (must be handled by P3)

Activating `?` semantics is a **breaking change for any app currently using `?` as a
no-op** — per P1's survey, only `vector_editor`. Its `GraphicObject` fields become
`Option[T]`, so existing reads of `obj.path_pts` (as raw `Collection[Point]`) would need
`or_else(obj.path_pts, [])`, and constructions `path_pts: []` would auto-wrap to
`Some([])`. P3 must therefore either:

- **(a)** migrate the app's read sites to `or_else` (a separate app card), or
- **(b)** gate semantic activation so the app can drop `?` from fields it wants raw, or
- **(c)** adopt the defaulted-fields feature for those fields instead.

App migration is a **closed surface** for this PROP; it is named as a P3 precondition,
not performed here.

---

## 6. Route — P3 implementation readiness (conditional)

**The design is fully decided and canon-anchored.** The route is **P3 implementation
readiness**, conditional on two bounded P3 tasks:

1. **`option_construct` SIR node** — Some/None field wrapping in both emitters, reusing
   the existing `Option[T]` runtime representation.
2. **Read-site migration coordination** for existing `T?` apps (vector_editor), or a
   gated activation (§5).

### Insertion points (named for P3)

- **Ruby TC** (`typechecker.rb`): `type_shapes` (carry `optional`); `infer_record_literal`
  — exempt declared-optional fields from the "missing required field" `OOF-TY0`, and
  relax the structural field-set exact-match so a literal omitting only optional fields
  still matches; auto-wrap present `T` values.
- **Rust TC** (`typechecker.rs`): `build_type_shapes` (carry `f.optional`);
  `check_record_literal_shape` — exempt optional fields from the required-missing
  `OOF-TY0`; auto-wrap present `T`.
- **Rust parser** (`parser.rs`): already captures `FieldDecl.optional` from
  `TokenType::Question` — **no parser work**.
- **Ruby parser/lexer**: must emit a `?` token after a type annotation so the existing
  `:question` branch fires (today the lexer drops it) — small lexer addition.
- **Both emitters**: emit `option_construct` for field Some/None.

### Proof matrix required before P3 closes

Positive (omit→None, T→Some, Option→as-is, dual-toolchain) · Negative (required-missing,
wrong-type-present, unexpected-field all still `OOF-TY0`) · Read (`or_else` over optional
field) · SIR (rectangular shape; `option_construct` byte-identical across toolchains) ·
Regression (non-optional records unchanged; scalar/Collection fields untouched;
vector_editor handled per §5). Target ≥ 60 checks.

### Acceptance (card §Acceptance)

- ✅ Defines omission / read / serialization / output-assignability semantics (§2–§3).
- ✅ Does not sneak in nullable runtime values un-named — the value is the canon `None`
  arm (§2 Q3, named explicitly).
- ✅ Ends with **P3 implementation readiness** (conditional) — §6.
- ✅ No compiler source changes (authoring only).

---

## 7. Proof

```
runner:   igniter-lang/experiments/optional_field_proof/verify_optional_field_prop_p2.rb
result:   57/57 PASS
sections: A gate (6) / B current no-op gap (8) / C canon grounding (9) /
          D read path realizable (6) / E construction gap (6) /
          F insertion points (8) / G semantics+fail-closed (7) / H evidence+route (7)
```

---

## 8. Closed surfaces

- No implementation.
- No app source migration.
- No runtime nullable value beyond the **named** canon `Option` `None`.
- No output-assignability relaxation outside the declared-optional rule.
- No surface `Some`/`None` literal or Option pattern-match in v0 (deferred).
- No defaulted-fields feature (separate future PROP).

---

## 9. Open routes (successors)

| Card | Scope |
|------|-------|
| LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3 | Dual-toolchain implementation: shape `optional`, missing-field exemption, auto-wrap, `option_construct` SIR; proof ≥60 |
| (app) vector_editor optional migration | Migrate `GraphicObject` read sites to `or_else` (or drop `?`) once P3 lands |
| (future) defaulted fields `field : T = default` | Distinct feature — raw-`T` reads with compile-time defaults |
| (future) Option surface | `Some`/`None` literals + `match` arms (PROP-044 §9.1 deferral) |
