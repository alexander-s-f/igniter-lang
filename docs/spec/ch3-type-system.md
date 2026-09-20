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
                       ⊢  case e of case₁(x) -> e₁ : U   if each branch : U
Rule 6 Temporal:       e : Store[T]  Tt : TemporalCtx
                       ⊢  e.at(Tt) : T
```

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
  Γ ⊢ then_expr : T
  Γ ⊢ else_expr : T
  --------------------------------------------------
  Γ ⊢ if cond { then_expr } else { else_expr } : T
```

The TypeChecker owns this rule. `cond` must resolve to canonical Bool
`{"name":"Bool","params":[]}`. Both branches must resolve to the same type T.
Dependencies are the union of condition, then-branch, and else-branch deps.
Nested `if_expr` is governed by the same rule at every nesting level.

This rule is internal compiler support only. Runtime/lazy branch execution
is not claimed. See §3.6 for rejection diagnostics.

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
Inferred type must match; mismatch → `OOF-TC1`.

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
source produces no artifact. The bare inference sentinel `Unknown` is refused as a port's own
direct annotation, but stays admissible where it already appears nested inside a resolved
parametric param or declared field (the pre-existing "untyped JSON value" idiom, e.g.
`Map[String, Unknown]`) — nested `Unknown` is not itself an unresolved *reference*.
Malformed builtin constructor arity also fails with `OOF-TY0` at the owning port.
The existing bare `History` read envelope and typed `History[T]` form are both admitted.

This closes only the reference-resolution half of the defect: an admitted opaque builtin (item 1
above) still carries no checked field structure, so a field access on one still produces the
pre-existing `OOF-P1: Unresolved field` symptom. Effect Surface `receipt`/`failure` metadata keeps
its own, separate builtin-scalar-only law (`OOF-M10`); this section governs `input`/`output` ports
only. This section documents the resolution law only — it introduces no arm-refined types, no
external/opaque type syntax, and no package-resolver change.

### Record literals, bound-but-unknown binders and HOF result evidence (LANG-CALLABLE-TYPED-CARRIER-ADOPTION-R13)

An available declared named-record hint (for example an annotated output or compute, PROP-043)
is validated against the literal. A failed hint is not permission to retry another named shape:
the hinted path retains its existing diagnostics/`Unknown` result. Only when no hint is available
does structural matching select a declared shape: exactly one shape with the same field-name set
whose field types admit the typed field values (Unknown values permissive) names the type;
otherwise the inferred type stays `Unknown`. Several matching shapes are ambiguous: canon
reports `OOF-TY0: Ambiguous record literal type …`; Rust retains `Unknown`, and the demonstrated
field-access control refuses with `OOF-P1: Unresolved field`. This is not a claim that Rust rejects
every bare ambiguous literal. R13 converges the exercised nested record literals (fold seeds,
branch results and literal carrier elements); hint availability remains context-dependent.

`OOF-P1: Unresolved symbol` names a MISSING declaration. A name that is bound — a lambda parameter over
an empty or untyped carrier, a block `let`, an input — is never unresolved merely because its type is
`Unknown`; it keeps the permissive ordinary typing of an `Unknown` operand (its ordering identity is the
integer-named one), and the effect, arity, callee and result-family checks still apply to a body that
never executes.

A selecting or reordering HOF (`filter`, `sort_by`, `sort_by_desc`) carries its carrier's element evidence
through its RESULT: over an inline literal carrier the result is `Collection[T]` with `T` the literal's
first element type (a record-literal element by the same order above), so a fold over `filter([r, 1.0], …)`
binds its element `Float`. `map` / `filter_map` / `flat_map` results are typed from their lambda; `find`
is `Option[T]`.

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
OOF-TC1  Declared type_annotation does not match inferred type
OOF-TC2  Field access on non-record type
OOF-TC3  Call arity mismatch
OOF-TC4  Collection[T] where element type is unknown
OOF-TC5  Decimal scale mismatch in add (must be equal)
OOF-CE4  ConfidenceLabel used as Bool (enforced with full inferred types)
OOF-DM2  Decimal division by statically-known zero
```

### if_expr Diagnostics (R190 Internal Compiler Support)

| Code | Owner | Trigger |
| --- | --- | --- |
| `OOF-IF1` | TypeChecker | condition does not resolve to canonical Bool `{"name":"Bool","params":[]}` |
| `OOF-IF2` | TypeChecker | expression-level `if_expr` has no `else` branch (missing else is not accepted v0 semantics) |
| `OOF-IF3` | TypeChecker | then/else branch result types do not exact-match |
| `OOF-IF4` | TypeChecker | branch has no value-producing final expression (empty block body) |

`OOF-IF5` is unowned and outside v0.

`OOF-TY0 Unsupported expression kind: if_expr` is closed and replaced by the
specific `OOF-IF*` diagnostic for any supported or diagnosed `if_expr` path.
Other unsupported expression kinds remain owned by `OOF-TY0`.

Derivative `OOF-TY0` type-mismatch diagnostics after rejected `if_expr` remain
accepted secondary diagnostics for now. These arise because a rejected `if_expr`
produces an `Unknown` resolved type, which downstream type-mismatch checks
(`OOF-TY0 Type mismatch: expected ..., got Unknown`) then flag as a secondary
consequence of the rejected branch. They are not unsupported-expression
diagnostics and do not indicate an `if_expr` regression.

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
