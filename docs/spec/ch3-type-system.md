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
