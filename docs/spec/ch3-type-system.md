# Ch3: Type System

Source PROPs: PROP-004, PROP-004 errata v0.1, PROP-021
Status: ✅ PASS ✅ boundary fixture CLOSED
Proof: experiments/typechecker_proof/ — PASS (includes `boundary.classified_program_input_only: ok`)
       TypeChecker now reads from own `classified/` directory; no external golden dir dependency.

---

## 3.1 Type Grammar (PROP-004 §Type Grammar)

```
Type :=
    Integer | Float | String | Bool | Timestamp | Date | Symbol
  | Text                          -- canonical text type (experiment-pass; see §8.10 stdlib)
  | Decimal[N]                    -- fixed-point, N decimal places
  | Record { f₁: T₁, ..., fₙ: Tₙ }
  | Variant { case₁: T₁ | ... | caseₙ: Tₙ }
  | Collection[T]                 -- finite, bounded
  | Option[T]                     -- Some(T) | None
  | Result[T, E]                  -- Ok(T) | Err(E)
  | Map[K, V]                     -- derived from group_by
  | Store[T]                      -- TBackend-backed storage
  | History[T]                    -- temporal storage (single axis)
  | BiHistory[T]                  -- bitemporal storage (two axes)
  | TemporalCtx[policy]           -- contract-level time parameter
  | Projection[T, horizon]        -- named temporal slice
  | T where φ                     -- refinement type (CORE if φ decidable; else ESCAPE)
  | Obs[kind, T]                  -- observation packet
  | Ref[T]                        -- mutable reference (ESCAPE)
  | ContractRef[In, Out]          -- contract as value
  | Any                           -- top type (dynamic boundary)
  | Never                         -- bottom type (unreachable)
```

**Stage 1 subset** (what the TypeChecker v0 handles):
`Integer, Float, String, Bool, Text, Decimal[N], Record{}, Collection[T], Option[T], Result[T,E]`

Note: `Text` is the experiment-pass canonical type for text stdlib operations (§8.10).
`String` literals (`⊢ "x" : String`) are accepted as `Text` arguments at call sites
via the v0 compat rule — no explicit coercion needed.

`History[T]`, `BiHistory[T]`, `OLAPPoint[T,Dims]`, `~T` → **Stage 2** (reserved, OOF if used in Stage 1).

---

## 3.2 Subtyping (PROP-004 §Subtyping)

```
Record width subtyping:   { a: T, b: U, c: V } <: { a: T, b: U }
Record depth subtyping:   { a: T } <: { a: U }  if T <: U
Collection covariant:     Collection[T] <: Collection[U]  if T <: U
Option covariant:         Option[T] <: Option[U]          if T <: U
ContractRef contravariant on inputs, covariant on outputs
Ref invariant:            Ref[T] <: Ref[U]  only if T = U
```

Record width and depth subtyping are not used by the join or the boundary fit of §3.3b.

### 3.2a Nominal `Option[T]` law

`Option[T]` has exactly two semantic arms:

```text
Some(value: T)
None
```

The carrier is nominal and preserves authored nesting. In particular,
`Some(None) != None`, and `Option[Option[T]]` retains both levels. A consumer
observes only this arm/payload law, independently of whether the value came
from a source constructor, an optional field, a collection/map/text producer,
or a temporal read.

A Record never becomes Option because it contains `$option`, `__arm`, or
`__variant`; Record keys are not carrier evidence. The internal VM layout is
not source syntax, a Record convention, or a user-constructible API. Source
constructors remain `some(value)` and `none()`. Their canonical SemanticIR
identity is specified in Ch6.

At the typed host boundary the declared port type, including recursively
resolved named-record fields, selects Option decoding. Generic JSON decoding
does not infer Option from object shape. Malformed or wrong-carrier values fail
with `OOF-VM-OPTION-CARRIER` under Ch7.

---

## 3.3 Typing Rules (PROP-004 §Typing Rules)

```
Rule 1 Literal:        ⊢ 42 : Integer;  ⊢ "x" : String;  ⊢ true : Bool
                       (v0 compat: String literal accepted as Text arg in stdlib.text.* calls)
Rule 2 Variable:       Γ(x) = T  ⊢  x : T
Rule 3 Field access:   e : { f: T, ... }  ⊢  e.f : T
Rule 4 Built-in call:  fn : (T₁..Tₙ → U)  e₁:T₁..eₙ:Tₙ  ⊢  fn(e₁..eₙ) : U
Rule 5 Case:           e : Variant { case₁:T₁ | ... }
                       ⊢  case e of case₁(x) -> e₁ | ... : U
                       where U = J(branch types) (§3.3b); no join: OOF-KIND5
Rule 6 Temporal:       e : Store[T]  Tt : TemporalCtx
                       ⊢  e.at(Tt) : T
```

Rule 3 applies to declared record types. A field read of an unnamed record family (§3.3b) stays
`OOF-P1: Unresolved field`; R21 does not open it (an open point of the R20 A1 law).

### 3.3a Variant-arm identity and visible-owner resolution

Variant arms have variant-qualified identity. For a construction
`Q::A { ... }`, `Q` must name a visible variant and that variant must declare
arm `A`; when it does, `Q` is the construction's resolved variant. A qualified
construction never consults an expected output or binding type.

For compatibility sugar `A { ... }`, let `owners(A)` be the set of variants
that are visible at the lexical use site and declare `A`. Visibility is the
ordinary module/import visibility of the variant declaration; arms are not
separate import units. Resolution is exact:

```text
|owners(A)| = 1  => resolve to that variant
|owners(A)| = 0  => refuse OOF-KIND8
|owners(A)| > 1  => refuse OOF-KIND8
```

Expected types, declaration order, and map iteration order never narrow this
set. Candidate variant names and their `Variant::Arm` spellings are sorted
lexicographically before diagnostics are formed. The ambiguity diagnostic is:

```text
arm 'A' is declared by visible variants V1 and V2; write V1::A { ... } or V2::A { ... }
```

For three or more owners, the variant-name list uses comma separation plus
Oxford `and` before the final name (`V1, V2, and V3`); the qualified spelling
list uses ` or ` between every item. Both lists retain the same sorted order.
The zero-owner diagnostic is `no visible variant declares arm 'A';
import the owning variant`. A qualified spelling that does not name a visible
declared arm is refused as `qualified arm 'Q::A' does not name a visible
variant arm`. None of these diagnostics may enumerate or otherwise reveal a
declaration that is outside the use site's visibility set.

This owner-set law applies to user-declared variant arms. The non-admitted
PascalCase spellings `Some { ... }`, `None { ... }`, `Ok { ... }`, and
`Err { ... }` remain governed by their existing sealed-constructor refusal;
the admitted Option/Result source constructors remain `some`, `none`, `ok`,
and `err`.

A match subject remains the pattern-resolution authority. A bare pattern arm
uses the subject variant exactly as before. For a qualified pattern `Q::A`,
`Q` must equal the known subject variant; otherwise typechecking refuses
`OOF-KIND9: qualified pattern 'Q::A' does not agree with match subject variant
'S'`. After agreement, the existing arm-membership, binding, duplicate-arm,
and exhaustiveness rules apply unchanged.

This law changes no variant, match, SemanticIR, or VM carrier. It is landed by
LANG-VARIANT-ARM-QUALIFIED-CONSTRUCT-P1 (2026-07-20).

### Rule IF-v0: Expression-Level if_expr (R190 Internal Compiler Support)

```
Rule IF-v0:
  Γ ⊢ cond : Bool
  Γ ⊢ then_expr : T₁
  Γ ⊢ else_expr : T₂
  T = J(T₁, T₂)            (§3.3b; no join: OOF-IF3)
  --------------------------------------------------
  Γ ⊢ if cond { then_expr } else { else_expr } : T
```

The TypeChecker owns this rule. `cond` must resolve to canonical Bool
`{"name":"Bool","params":[]}`. The branches must have a join T (§3.3b): a hole takes the other branch's
family, a declared-open position stays open, and branch order never changes T. Under an annotated compute, output
or argument, each branch (and each `match` arm, Rule 5) is instead fit to the declared type and the expression has
that type.
Dependencies are the union of condition, then-branch, and else-branch deps.
Nested `if_expr` is governed by the same rule at every nesting level.

This rule is internal compiler support only. Runtime/lazy branch execution
is not claimed. See §3.6 for rejection diagnostics.

### 3.3b Collection and alternative join law (LANG-COLLECTION-EVIDENCE-JOIN-LAW-CANON-ADOPTION-R21)

Normative since R21 (2026-09-26). This section is the law; its accepted evidence is the curator-accepted R20 A1
packet (Lab `proofs/lang-collection-evidence-and-join-law-convergence-r20-a1/`). Neither compiler implements it yet:
where the Canon Ruby or Lab Rust typechecker differs from this section, that is an implementation gap measured
against it, not an alternative semantics (see "Implementation status" at the end of this section).

**Four carriers.** Every inferred position carries exactly one of:

- **a known family**;
- **declared openness** — `Unknown` written by the author or a declared signature (nested in a port, field,
  parameter, annotation or declared output, e.g. `Map[String, Unknown]`, `Collection[Unknown]`) and values read
  from such a slot. It is the author's permission, checked at run time. Inference never produces it;
- **a hole** — a type parameter no argument or context determines: the element of `[]`, the payload of `none()`,
  the value of `map_empty()`, the missing side of `ok(x)` / `err(e)`. Its value never exists. It is solved by
  context and joins and never licenses a family; as an operand it is permissive in every position, each result
  typed from the other operands;
- **an error** — the value of an expression whose diagnostic reaches the verdict. Every judgment that receives an
  error at any depth in any operand, including an expected type, yields the error and reports nothing further; an
  error never satisfies a boundary and never becomes openness. A probe or provisional pass that discards its
  diagnostics yields no type; the owning pass re-derives it.

A site that can justify none of the four is a diagnostic.

**Record literals are named first.** This amends the R13 naming rule (§3.5a keeps the R13 observations as
history). Before any join, every record literal is named, innermost first:

- a hint names it: its own expected named record type (annotation, declared field, parameter or element), which
  also reaches a literal written in a field of that shape. A failing hint is refused, never retried (an annotation
  hint: `OOF-TY0`);
- otherwise the one declared shape with exactly its field names whose fields each FIT its values (the boundary rule
  below: holes and declared openness are permissive at any depth) names it. Optional-field construction (the gated
  LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3 behavior for `f : T?`) is not changed by this section and applies inside
  this fit. Several such shapes are ambiguous
  (`OOF-TY0`); with none the literal keeps its own record family. An unnamed inner literal is judged by that record
  family, never as open;
- a `Map[K, V]` or declared-open expected type suppresses structural naming; the literal meets it by fit.

A named literal IS that record, and an open value flows into its field as at any boundary. Naming belongs to the
literal expression and happens once, before the literal is joined: the join never names a literal, and a type
produced by a join is never re-named. A declaration can therefore change a verdict: adding a shape that fits one
member of a literal can leave that member named and the others unnamed, with no join.

**Join.** The join `J` of a set of normalized types (branches of an `if` / `match`, members of a collection
literal, a `fold` seed and its body, an `unwrap_or` payload and fallback) is defined on the whole set:

1. an error at any depth makes the result an error (no further diagnostic);
2. with declared-open positions and holes contributing nothing, the remaining known families must have one least
   upper bound: equal families; `String` and `Text` as one scalar; one constructor (`Collection`, `Option`,
   `Result`, `Map`, keys and values) position-wise; unnamed record families with the same field names,
   field-wise; named records and variants only by name. Otherwise there is no join. A declared-open member never
   hides a conflict between known members;
3. every position some member declares open is open in the result.

Joining never produces openness or an error that no member had. A `let` / compute alias binds the joined TYPE.
Record width/depth subtyping (§3.2) is not used by the join or by boundary fit; two declared records with
identical fields are different names and have no join.

**Order and grouping.** For one literal, `if` or `match` the join is commutative and independent of member,
branch and arm order. Associativity is not universal. Grouping is free for members without declared openness;
binding or grouping part of a set through a declared-open value keeps only openness (its known families are not
remembered), so a grouped form can be admitted where the flat set has no join. With `open : Collection[Unknown]`
declared, `[[1], open, ["a"]]` has no join (`OOF-COL13`), while `a = if c { [1] } else { open }` followed by
`[a, ["a"]]` is `Collection[Collection[Unknown]]`. This loss of evidence across bindings and groupings is part of
the law, and it happens only through author-declared openness.

**Operators.** An operator that requires its operands to share a family (equality, ordering, same-family
arithmetic; ch2 §2.2, unchanged) decides that agreement by the join: a hole or declared-open operand is permissive,
also nested in a structured operand the operator admits (`++`). No join is `OOF-TY0` (`OOF-COL7` for `++`). This
admits no operand family an operator does not already accept (for example `==` over collections or records stays
refused) and changes no other operator rule: the §3.6 Decimal rules keep their results and owner
(`Decimal[A] * Decimal[B]` is `Decimal[A+B]`; `+` over different scales is `OOF-TC5`), and equality and ordering
over the `Decimal` family are unchanged.

**Collections are homogeneous or explicitly opaque.**

- `[] : Collection[_]`; `[e₁, …, eₙ] : Collection[J(e₁, …, eₙ)]`. Members with no join are refused `OOF-COL13`
  unless the literal's own expected element type is declared open (`Collection[Unknown]` at the annotated compute,
  port, field or parameter it is written in), which types it `Collection[Unknown]`. That context reaches the
  annotated expression (its branches and literal members), not an earlier binding, and a slot open only as a whole
  (e.g. a `Map[String, Unknown]` value) does not make a literal opaque. A named variant is the explicit
  heterogeneous carrier; there is no inferred union type.
- A HOF callback parameter is the carrier's ONE element type, and a selecting or reordering HOF returns the carrier
  type. When all members have one family that family is the element type; a heterogeneous literal has no
  carrier unless its element is declared open (bullet 1).
- `concat` / `++` require a join of both element types, `append` / `set_at` a join of the element type and the
  item (`OOF-COL7` / `OOF-COL6` otherwise); the result element is that join.
- `fold(xs, seed, (acc, v) -> body)`: the accumulator is ONE value typed `J(seed, body)` at its least fixed point.
  The first refinement `J(seed, body(seed))` is free. After it, a pass may fill a hole only with a hole-free type
  (or make a position open) and never adds a hole, so refinement terminates: each changing step lowers (holes,
  known positions) lexicographically. Provisional passes report nothing; the verdict and the lowering come from the
  pass with the settled accumulator. No join, or a later pass that would fill a hole with a type that still has a
  hole, is `OOF-COL4`; such a fold is refused even when a further pass would settle. The accumulator is never
  typed from one carrier item. This rule governs `fold`. `fold_stream` is outside the A1 evidence and keeps its
  ch6 §6.4.1 admission rule until a later card aligns it.
- `unwrap_or` / `or_else`: `J(payload, fallback)`; no join is `OOF-TY0`.
- Maps: `map_get` / `map_put` need a join of the key with the map's key family (a `map_put` result has that joined
  key family, so a declared-open key keeps only openness), and join values. A record literal used as a map has key
  family `String` (also with no fields) and value family the join of its fields. A record literal meets a map only
  at a boundary, never in a join; `map_empty()` is the Map seed. A stdlib map call's argument is not a Map expected
  type for naming: once a declared shape fits a record literal, the literal is that record and not a map (a
  `Map[String, V]`-annotated binding keeps it a map). A written map key type is `String` or declared open
  (`OOF-MAP1`, unchanged).

**Boundaries (family before deferral).** An annotated compute, port, argument, record or variant field, element or
return accepts an actual when: the slot is declared open; the actual is declared open (checked at run time); the
actual is a hole there; or the families agree position-wise. Expected types come from written or declared slots
and contain no holes; an unsolved expectation constrains nothing. A record literal fits a named shape with exactly
its fields (optional-field construction as in naming, unchanged), and a `Map[K, V]` slot when `String` fits `K` and every field
fits `V`. An unsolved or erroneous inner
position never defers the known outer family. A `match` subject must be known to be a variant (Rule 5); declared
openness is not a variant (a hole subject never exists).

**Diagnostics.** No join is `OOF-IF3` (`if`), `OOF-KIND5` (`match`), `OOF-COL13` (collection literal),
`OOF-COL7` (`concat` / `++`), `OOF-COL6` (`append` / `set_at`), `OOF-COL4` (fold) and `OOF-TY0` (same-family
operators other than the §3.6 Decimal `OOF-TC5`, `unwrap_or` / `or_else`, record naming). A boundary that does not
fit is refused by that boundary's existing owner (for example §3.5 `OOF-TC1`); every other diagnostic keeps its
owner.

**SemanticIR** is unchanged: a hole and declared openness both lower with today's `Unknown` spelling, and an error
never reaches SemanticIR (a refused program emits none).

**Implementation status (observation, not law).** R21 adopts text only; no compiler changed. Read at Canon
`aa0e67e` and Lab `5f587b3f3`, both typecheckers still carry holes, declared openness and errors as one `Unknown`
sentinel. They join `if` branches by an order-sensitive (then-arm) rule and `match` arms by a
top-level-`Unknown`-skipping join that degrades a parameter conflict to the bare family name; type inline literal
carriers without a whole-set join or `OOF-COL13` and bind HOF parameters from the first member; leave `map_get`
keys unchecked and check a `map_put` key only by its top-level name, which refuses keys the join admits (an
`Integer` key into a declared `Map[Unknown, V]`); do not implement the fold refinement rule; and can report a
derivative `OOF-TY0` after a refused expression. Record naming differs as recorded in §3.5a. The owner
checklist for a later implementation card is in Lab `lab-docs/lang/lang-collection-evidence-join-law-canon-adoption-r21.md`.

---

## 3.4 Temporal Capability System (PROP-004 §Temporal Capability)

**Tt as contract-level parameter**: every contract receives an implicit `Tt: TemporalCtx`
parameter. Evaluations without explicit `Tt` are OOF (Law 6).

**Storage type capabilities**:
```
Store[T]      — as_of-capable (point read at Tt)
History[T]    — as_of + replay-capable (Stage 2)
BiHistory[T]  — requires bi_temporal ESCAPE capability (Stage 2)
```

**Projection[T, horizon]**: type-level representation of a named temporal slice.
Reproducible iff `horizon` contains no `:latest` references.

---

## 3.5 Annotation-Driven Type Resolution (PROP-021 §Part 3)

The TypeChecker v0 is **annotation-driven**: declared `type_annotation` is ground truth.
The inferred type must fit it (§3.3b boundaries); a misfit → `OOF-TC1`.

```
parse_type_annotation("Integer")     → TypeRef::Base(:integer)
parse_type_annotation("Decimal[2]")  → TypeRef::Decimal(scale: 2)
parse_type_annotation("Option[String]") → TypeRef::Generic(:option, [TypeRef::Base(:string)])
```

**Three environments**:
```
TypeEnv     — global: type aliases, struct fields
ShapeEnv    — per-contract: node name → TypeRef
OperatorEnv — stdlib operator signatures
```

---

## 3.5a Contract Port Type Resolution (LANG-TYPE-REF-UNRESOLVED-FAIL-CLOSED-P1)

Every declared contract `input` and `output` type annotation is **closed over builtins and
project-visible declarations**: it must resolve, recursively through parametric constructors
(`Collection`, `Option`, `Result`, `Map`, `History`) and through the field shapes of any declared
record or variant it names, to one of —

1. a language scalar or a small, closed set of compiler-known opaque nominal builtins
   (`Integer`, `Float`, `Decimal[N]`, `Bool`, `Text`, `String`, `Unit`, `Bytes`, `DateTime`,
   `IoError`, `SecretRef`, `WriteReceipt`, `AppendReceipt`, `ReplaceReceipt`, `WriteAtReceipt`);
2. a `type` or `variant` declared in the compiling module; or
3. a `type` or `variant` made visible by the multifile/package import resolver.

An undeclared nominal name — including a dotted spelling that resembles a package path (e.g.
`Foo.Bar`) or a variant arm (e.g. `Evidence.Observed`, which does not become a standalone type) —
fails closed with `OOF-TY0: Unresolved type reference '<name>' in <input|output> '<port>' of
contract '<contract>'`, once per `(contract, port, type_ref)`, before emit/assemble; the refused
source produces no artifact. A bare `Unknown` is refused as a port's own
direct annotation, but stays admissible where it already appears nested inside a resolved
parametric param or declared field (the pre-existing "untyped JSON value" idiom, e.g.
`Map[String, Unknown]`) — nested `Unknown` is not itself an unresolved *reference*. Written
`Unknown` is declared openness (§3.3b); inference never produces it.
Malformed builtin constructor arity also fails with `OOF-TY0` at the owning port.
The existing bare `History` read envelope and typed `History[T]` form are both admitted.

This closes only the reference-resolution half of the defect: an admitted opaque builtin (item 1
above) still carries no checked field structure, so a field access on one still produces the
pre-existing `OOF-P1: Unresolved field` symptom. Effect Surface `receipt`/`failure` metadata keeps
its own, separate builtin-scalar-only law (`OOF-M10`); this section governs `input`/`output` ports
only. This section documents the resolution law only — it introduces no arm-refined types, no
external/opaque type syntax, and no package-resolver change.

### Record literals, bound-but-unknown binders and HOF result evidence (LANG-CALLABLE-TYPED-CARRIER-ADOPTION-R13)

The record-literal naming law is §3.3b (R13 as amended by R21). **History (R13 implementation
observations, not the current law):** at R13 an available declared named-record hint (for example an
annotated output or compute, PROP-043) was validated against the literal, and a failed hint was not retried
with another named shape. Without a hint, exactly one shape with the same field-name set whose field types
admitted the typed field values (Unknown values permissive) named the type; otherwise the inferred type
stayed `Unknown`. Several matching shapes were ambiguous: canon reported `OOF-TY0: Ambiguous record literal
type …`; Rust retained `Unknown`, and the demonstrated field-access control refused with `OOF-P1: Unresolved
field`. R13 converged the exercised nested record literals (fold seeds, branch results and literal carrier
elements). A1 reading of Canon `aa0e67e`: canon treats only a top-level `Unknown` value (or an all-`Unknown`
empty collection) as permissive and refuses a nested `Unknown`, and it passes a hint into nested literals.
These observations are what the §3.3b amendment changes (fit at any depth, an unnamed inner literal judged by
its record family, no match keeps the record family, ambiguity refused in both). Both implementations still
behave as observed here (§3.3b "Implementation status"); R21 changed neither.

`OOF-P1: Unresolved symbol` names a MISSING declaration. A name that is bound — a lambda parameter over
an empty or untyped carrier, a block `let`, an input — is never unresolved merely because it carries no known
family (a hole or declared openness, §3.3b); it keeps the permissive typing of such an operand (its ordering
identity is the integer-named one), and the effect, arity, callee and result-family checks still apply to a body that
never executes.

A selecting or reordering HOF (`filter`, `sort_by`, `sort_by_desc`) carries its carrier's element evidence
through its RESULT: over an inline literal carrier the result is `Collection[T]` with `T` the join of all the
literal's members (§3.3b; a record-literal member is named first), so a fold over `filter([r, 1.0], …)` with
`r : Float` binds its element `Float`. `map` / `filter_map` / `flat_map` results are typed from their lambda;
`find` is `Option[T]`. (R13 recorded the first element's type here, and both frontends still use it; §3.3b
retires that rule: a heterogeneous literal has no carrier and is `OOF-COL13` unless its element is declared
open.)

The lexical law applies to block and branch statements in value expressions. R14 implements this law for
the admitted HOF lambda bodies, aggregate stages and `if` branches it qualifies, alongside the accepted
stream carrier; it is not a claim that every block form already compiles and executes. These statements are
typed in a block scope, in authored order: a `let`'s own expression is typed in the scope BEFORE its binding,
the name then binds that type for the rest of the block only, and it shadows any outer binder of the same
spelling. Where ordering-identity selection is implemented, an Integer/Float shadow selects the inner
binder's identity; the other branch reads the outer binder. On the qualified routes both frontends carry
statements through the existing right-nested `let` lowering (ch6 §6.4.1). Dropping a statement is an
implementation defect, never an alternative semantics (R13 review: `32.0` for `6.0`, `2` for `3`; both repaired
by R14). That lowering binds a bare statement to the reserved name `__seq__`, so NO source value binder — an
input, a compute, a lambda or def parameter, a `let`, a match-pattern binding, a loop item — may spell `__seq__`
on any route (`OOF-COL4`); a record FIELD or TYPE of that spelling is not a value binder.

Implementation residuals and limits, not alternative language semantics:

- The classifier's free-name pass is one ORDERED lexical walk (R15), in both frontends: a block `let` —
  fresh-named or shadowing — in a lambda block, an `if` branch or a match-arm block binds for the statements and
  tail AFTER it; its initializer is read in the scope BEFORE it (`let k = k + 1` depends on the outer `k`; a
  fresh `let d = d + 1`, and a name read before its own `let`, are `OOF-P1`); lambda parameters and
  match-pattern bindings scope their own body / arm; a local reaches no sibling branch or arm, no enclosing block
  and no later declaration. Every expression child is visited (array items, record and variant fields, match
  subjects and arms), so a declaration's classifier dependency set is its FREE names, and a law decided from
  that set — `OOF-S4` direct stream use, Rust `OOF-P4` compute cycles — applies in every child position. This
  is the classifier's name resolution, not universal block admission: the other typing, lowering and execution
  limits below still apply. Surface limits outside the classifier remain: the Canon parser has no match-arm
  block and cannot END a statement block in a record literal (bind it with a `let` or end in a constructor
  call), and in both parsers a block tail that starts with `[` after a `let` is an index access on the
  initializer. Canon SemanticIR `deps` are typechecker-owned and still list callable-local names.
- The Rust classifier's EFFECT checks (ambient-IO / capability / effect-mode / observed-write) visit every
  expression child too (R15-A1): inside a `compute`, `snapshot`, `fold_stream`, loop collection or loop inner
  compute, a host-IO or write call under a `match` (subject or arm), in a block, in a variant field or under `?`
  is decided exactly like the same call in a directly visited position — refused with the same rules
  (`E-IO-AMBIENT-BLOCKED` and, in a `pure` contract, `OOF-M1`; `E-IO-CAP-*`), or admitted with the same
  `escape` fragment and effect metadata. Before A1 those positions were skipped, and once fresh locals were
  admitted a `pure` contract with host IO under `match` compiled as `core`. Still outside this law: the
  expressions of `invoke` arguments, a `write` value and an `idempotency key` are not fed to the capability /
  effect-mode check (unchanged since before R15). Canon has no effect-mode check in either position.
- A statement before a tail `recur()` (`if n > 0 { let acc = acc + n   recur(n - 1, acc) } else { acc }`) is
  tail-positioned for both typecheckers, but the VM compiler's tail backstop does not see through a `let` body
  and refuses it (`OOF-R15`).
- In a DEF body the Rust frontend does not run the ordering-identity selection at all (R11 `d1`, inherited): an
  ordering over Floats there keeps the integer-named identity and refuses at activation, with or without a
  shadowing `let`. Canon selects the inner binder's identity in def bodies too.
- A standalone compute-level block can still reach the VM as `kind: block` and be refused. It is not among
  R14's qualified HOF/branch routes.
- The current temporal-read executor resolves `as_of` BY NAME from contract inputs rather than the lexical
  environment. The R14 review identified this structurally, not through fresh temporal execution. Temporal
  shadowing remains unqualified; this is not a new exception to the lexical law and R14 does not repair it.

---

## 3.6 Type-Level OOF Rules (PROP-021 §Part 6)

```
OOF-TC1  Inferred type does not fit the declared type_annotation (§3.3b boundaries)
OOF-TC2  Field access on non-record type
OOF-TC3  Call arity mismatch
OOF-TC4  retired by §3.3b (formerly: Collection[T] where element type is unknown); an unsolved
         element is a lawful hole; any other element without a known family is declared open or an
         error
OOF-COL13 collection literal members have no join and no declared-open element is expected (§3.3b)
OOF-TC5  Decimal scale mismatch in add (must be equal)
OOF-CE4  ConfidenceLabel used as Bool (enforced with full inferred types)
OOF-DM2  Decimal division by statically-known zero
```

### if_expr Diagnostics (R190 Internal Compiler Support)

| Code | Owner | Trigger |
| --- | --- | --- |
| `OOF-IF1` | TypeChecker | condition does not resolve to canonical Bool `{"name":"Bool","params":[]}` |
| `OOF-IF2` | TypeChecker | expression-level `if_expr` has no `else` branch (missing else is not accepted v0 semantics) |
| `OOF-IF3` | TypeChecker | then/else branch result types have no join (§3.3b) |
| `OOF-IF4` | TypeChecker | branch has no value-producing final expression (empty block body) |

`OOF-IF5` is unowned and outside v0.

`OOF-TY0 Unsupported expression kind: if_expr` is closed and replaced by the
specific `OOF-IF*` diagnostic for any supported or diagnosed `if_expr` path.
Other unsupported expression kinds remain owned by `OOF-TY0`.

A rejected `if_expr`, like every refused expression, yields an error (§3.3b): no
derivative diagnostic is reported against it, and it never satisfies a boundary.
History: before R21 this section accepted derivative `OOF-TY0 Type mismatch:
expected ..., got Unknown` diagnostics after a rejected `if_expr` as secondary
"for now", because the rejected expression resolved to `Unknown`. That allowance
is retired; an implementation that still reports them has an open gap.

**Decimal rules**:
- `Decimal[A] + Decimal[B]`: requires `A == B` → result `Decimal[A]`; else `OOF-TC5`
- `Decimal[A] * Decimal[B]`: result `Decimal[A+B]` (always valid)

**Decimal construction** (LAB-NUMERIC-DECIMAL-CONSTRUCT-P1): the only way to mint a
`Decimal[N]` constant is the explicit constructor `decimal(value, scale)`:
- `decimal(value: Integer, scale: Integer literal) -> Decimal[scale]` — `value` is the
  exact amount in minor units (e.g. `decimal(150, 2)` is `1.50` at scale 2). The `scale`
  must be a non-negative **Integer literal** so the result type `Decimal[scale]` is
  statically known; a non-literal or negative scale is `OOF-DM4`. Wrong arity or a
  non-`Integer` `value` is `OOF-TY0`.
- There is **no Decimal literal** (`0.00` types as `Float`) and **no implicit
  `Float`/`Integer` → `Decimal` coercion** (`OOF-TY1`, unchanged). `decimal()` is the
  sole money-safe path from exact integer minor-units into the `Decimal` family.

---

## 3.7 TypedProgram Shape (PROP-021 §Part 5)

```json
{
  "kind": "typed_program",
  "pass_result": "ok | oof | skipped",
  "grammar_version": "0.1.0",
  "source_path": "source/add.ig",
  "contracts": [
    {
      "name": "Add",
      "fragment_class": "core",
      "nodes": [
        { "name": "a",   "node_kind": "input",   "resolved_type": "Integer" },
        { "name": "b",   "node_kind": "input",   "resolved_type": "Integer" },
        { "name": "sum", "node_kind": "compute",
          "resolved_type": "Integer",
          "operator": "stdlib.integer.add",
          "arg_refs": ["a", "b"] },
        { "name": "result", "node_kind": "output", "resolved_type": "Integer" }
      ]
    }
  ],
  "diagnostics": []
}
```

**Skipping rule**: if `ClassifiedProgram.pass_result == "oof"`, TypeChecker
returns `pass_result: "skipped"` and forwards classifier diagnostics unchanged.
