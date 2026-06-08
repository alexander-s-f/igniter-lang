# PROP-004: Type System v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-001-semantic-domain-v0.md`,
             `proposals/PROP-002-contract-composition-algebra-v0.md`,
             `proposals/PROP-003-grammar-fragment-classification-v0.md`,
             `docs/temporal-positioning.md`

---

## Purpose

PROP-003 defined Pass 0 (fragment classification). Pass 1 is **type
checking**: the compiler receives a ClassifiedAST (all OOF already rejected)
and verifies that every port binding, expression, guard, and temporal claim
is well-typed.

This proposal defines the **v0 type system** for Igniter-Lang:

- the type grammar (what types exist)
- the typing rules (what makes a term well-typed)
- the subtyping relation (what is substitutable for what)
- the soundness statement (what the type system guarantees)
- how temporal context `Tt` enters the type system
- how `Store[T]`, `History[T]`, and `BiHistory[T]` carry temporal capabilities
- whether projections can be typed by their horizon

`docs/temporal-positioning.md` is a direct input: the Architect Supervisor
has directed that temporal constructs must be first-class in PROP-004. This
proposal takes that directive seriously.

---

## Design Principles

1. **Structural, not nominal.** Types are decided by shape, not by declared
   name. Two records with the same field names and types are the same type.
   Nominal identity is reserved for `ContractRef` and `ObservationRef`.

2. **Decidable type checking.** The type system must remain decidable in the
   CORE fragment. Undecidable features (dependent types, higher-rank
   polymorphism) are OOF.

3. **Temporal capabilities are part of the type.** `Store[T]`, `History[T]`,
   and `BiHistory[T]` carry declared temporal capabilities. A type without
   temporal capability cannot make temporal claims. This makes the type
   system the enforcement mechanism for `temporal-positioning.md`'s directive.

4. **Refinement types are ESCAPE by default.** A refinement `T where φ`
   is CORE only when `φ` is a linear-arithmetic or structural predicate.
   Arbitrary predicates require the `refinement_predicate` escape.

5. **Soundness before expressiveness.** The type system should be sound
   (no well-typed program produces an ill-typed observation) even if it
   rejects some correct programs. Completeness is a later goal.

---

## Type Grammar

```text
T ::=
  -- Base types
  Int | Float | String | Bool | Symbol | Unit | Any | Never

  -- Structural composites
  | Record { label₁: T₁, ..., labelₙ: Tₙ }
  | Variant { tag₁: T₁, ..., tagₙ: Tₙ }
  | Collection[T]
  | Option[T]                            -- sugar for Variant { some: T, none: Unit }

  -- Reference types
  | Ref[T]                               -- stable handle to a contract of type T
  | ContractRef[In, Out]                 -- typed contract reference (static only)

  -- Temporal storage types (carry temporal capabilities)
  | Store[T]                             -- point-read/write; as_of capable
  | History[T]                           -- append-only; as_of + replay capable
  | BiHistory[T]                         -- bitemporal; ESCAPE bi_temporal required

  -- Temporal context type
  | TemporalCtx[policy]                  -- typed temporal context with declared policy

  -- Projection type (new — from temporal-positioning.md directive)
  | Projection[T, horizon]               -- a named slice of T at declared horizon

  -- Refinement type (ESCAPE for non-linear φ)
  | T where φ                            -- φ: Predicate over T

  -- Observation type
  | Obs[kind, T]                         -- an observation packet of kind `kind` carrying T

  -- Never (bottom type: subtype of all types, used for failure paths)
  | Never
```

**`Any` and `Never`** form the top and bottom of the subtype lattice:

```text
Never <: T <: Any    for all T
```

`Never` is the type of an expression that never produces a value (always
fails). It is useful for total-function typing of failure branches.

---

## Typing Rules

### Rule 1: Literal

```text
──────────────────────────
Γ ⊢ Literal(v: Int) : Int

(and similarly for all base literals)
```

### Rule 2: Variable

```text
(x : T) ∈ Γ
─────────────
Γ ⊢ Var x : T
```

### Rule 3: Field Access

```text
Γ ⊢ e : Record { ..., label: T, ... }
───────────────────────────────────────
Γ ⊢ FieldAccess(e, label) : T
```

### Rule 4: Built-in Application

```text
built_in : T₁ × ... × Tₙ → T    (from axiom layer)
Γ ⊢ eᵢ : Tᵢ    for each i
──────────────────────────────────────────────────
Γ ⊢ Apply(built_in, [e₁,...,eₙ]) : T
```

Built-ins are typed by the axiom layer descriptor. They are total: they
never return `Never` (failures from built-ins become `platform_observation`).

### Rule 5: Case (Variant Elimination)

```text
Γ ⊢ e : Variant { tag₁: T₁, ..., tagₙ: Tₙ }
Γ, xᵢ: Tᵢ ⊢ eᵢ : T    for each i    (all arms return same T)
──────────────────────────────────────────────────────────────
Γ ⊢ Case(e, { tagᵢ → eᵢ }) : T
```

All arms must have the same return type. If arms have incompatible types,
the compiler emits `input.invalid_input_type` and fails.

**Practical note:** when arms have types with a common supertype (structural
widening), the compiler may infer the least upper bound `T` if it is unique.
If no unique LUB exists, an explicit type annotation is required.

### Rule 6: Temporal Expression

```text
Γ, Tt_ctx: TemporalCtx[policy] ⊢ e : T
policy includes as_of capability
────────────────────────────────────────────────────────────────
Γ ⊢ Temporal(as_of: t, body: e) : T   with TemporalCtx[as_of]
```

The `Temporal` constructor is well-typed only when the body expression
`e` uses a `TemporalCtx` that declares `as_of` capability. The resulting
type is `T`, but the evaluation context carries the new `as_of` binding.

This rule enforces Law 6 (Temporal Explicitness): an expression that reads
a store or history must do so under an explicit temporal context.

---

## Subtyping Relation (<:)

The subtyping relation is defined structurally:

```text
-- Reflexivity
T <: T

-- Top and Bottom
Never <: T
T <: Any

-- Record width subtyping (more fields = subtype)
Record { l₁:T₁, ..., lₙ:Tₙ, lₙ₊₁:Tₙ₊₁ } <: Record { l₁:T₁, ..., lₙ:Tₙ }

-- Record depth subtyping (covariant fields)
Tᵢ <: Sᵢ  for all i
──────────────────────────────────────────────────────────
Record { l₁:T₁,...,lₙ:Tₙ } <: Record { l₁:S₁,...,lₙ:Sₙ }

-- Variant subtyping (fewer tags = subtype)
Variant { tag₁:T₁ } <: Variant { tag₁:T₁, tag₂:T₂ }

-- Collection (covariant)
T <: S
──────────────────────
Collection[T] <: Collection[S]

-- Option (covariant)
T <: S
──────────────────────
Option[T] <: Option[S]

-- Ref (invariant — reading and writing)
T = S
──────────────────────
Ref[T] <: Ref[S]

-- Store (covariant for reads, invariant for writes)
-- In v0: Store[T] is read-only at the type system level;
-- writes go through EffectDecl. Therefore: covariant.
T <: S
──────────────────────
Store[T] <: Store[S]

-- History (covariant — append-only; no destructive writes)
T <: S
──────────────────────
History[T] <: History[S]

-- BiHistory — invariant in v0 (bitemporal corrections require precise types)
T = S
──────────────────────────────────
BiHistory[T] <: BiHistory[S]

-- Refinement strips down
T where φ <: T

-- ContractRef (contravariant inputs, covariant outputs)
In₂ <: In₁    Out₁ <: Out₂
─────────────────────────────────────────────────────
ContractRef[In₁, Out₁] <: ContractRef[In₂, Out₂]

-- Projection (covariant in T, invariant in horizon)
T <: S    horizon₁ = horizon₂
──────────────────────────────────────────────────
Projection[T, horizon₁] <: Projection[T, horizon₂]
```

**[D]** `Ref[T]` is **invariant** because it supports both reads and writes
(through EffectDecl). Making it covariant would allow substituting a
`Ref[Animal]` where a `Ref[Dog]` is expected, which is unsound for writes.

**[D]** `Store[T]` is **covariant** in v0 because writes go through
`EffectDecl` (a separate contract declaration), not through the type itself.
This is a deliberate v0 simplification; it may become invariant if in-place
writes are added.

---

## Temporal Capability System

This section directly answers the directives from `temporal-positioning.md`:

> Is `Tt` a parameter to every contract type?
> Do `Store[T]`, `History[T]`, and `BiHistory[T]` carry temporal capabilities?
> Can projections be typed by their horizon?

### Tt as Contract-Level Parameter

Every contract type is implicitly parameterized by `TemporalCtx`:

```text
Contract : (In, Out) under TemporalCtx[policy]
```

The `policy` is a set of temporal capabilities the contract requires:

```text
TemporalPolicy ::= {
  requires_as_of     : Bool     -- contract reads are as_of-sensitive
  requires_replay    : Bool     -- contract may be evaluated in replay mode
  requires_versioned : Bool     -- result depends on rule_version
  causal_boundary    : Bool     -- ESCAPE: causal_clock required
}
```

A contract with `requires_as_of: false` is **temporally pure**: given the
same inputs, it always returns the same output regardless of `Tt`. This is
the CORE default.

A contract with `requires_as_of: true` is **temporally indexed**: it must
declare its `as_of` source (caller, context, or store consistency model).

### Temporal Capabilities of Storage Types

| Type | as_of | replay | versioned | causal | Write | Class |
|------|-------|--------|-----------|--------|-------|-------|
| `Store[T]` | YES | NO | NO | NO | via EffectDecl | CORE |
| `History[T]` | YES | YES | NO | NO | append-only | CORE |
| `BiHistory[T]` | YES (both axes) | YES | NO | ESCAPE | corrections | ESCAPE |
| `Projection[T, h]` | YES (at h) | YES (replay h) | YES | NO | read-only | CORE |

**[D]** `Store[T]` reads are `as_of`-capable in v0: every read from a
`Store[T]` inside a contract must occur under an explicit `as_of` context
(either from the contract's `TemporalPolicy` or a `Temporal(as_of: t, ...)
scope). Silent reads at "current time" are OOF.

**[D]** `History[T]` additionally carries `replay` capability: it can be
iterated from a `replay_cursor`. This does not require the `bi_temporal`
escape; it is part of the CORE temporal model.

**[D]** `BiHistory[T]` requires the `bi_temporal` escape because querying
both `valid_time` and `transaction_time` axes simultaneously requires
two-dimensional temporal reasoning that is outside the CORE temporal model.

### Projection[T, horizon]

A `Projection[T, horizon]` is a **typed, reproducible view** over a
contract's outputs at a declared horizon:

```text
Projection[T, horizon] = {
  value_type   : T
  horizon      : ProjectionHorizon
  as_of_policy : :fixed | :latest | :caller_supplied
  reproducible : Bool
}

ProjectionHorizon ::= {
  as_of        : TimeRef | :latest
  rule_version : VersionRef | :latest
  fact_scope   : StoreRef | HistoryRef | :all
}
```

**Typing rules for projections:**

```text
-- A contract with temporally-indexed output can produce a Projection
Γ ⊢ C : ContractRef[In, Out]  under TemporalCtx[requires_as_of: true]
h : ProjectionHorizon
────────────────────────────────────────────────────────────────────────
Γ ⊢ project(C, at: h) : Projection[Out, h]
```

```text
-- A Projection can be unwrapped to its value type
Γ ⊢ p : Projection[T, h]
────────────────────────────────
Γ ⊢ project_value(p) : T    (with temporal link observed_under: h)
```

**[D]** A `Projection` is **reproducible** when its `horizon` is fully
fixed (fixed `as_of`, fixed `rule_version`, bounded `fact_scope`). A
projection with `as_of: :latest` is **not** reproducible — it is a live
view. Both are valid types; the `reproducible` field makes the distinction
observable.

**[S]** This answers the Architect Supervisor's question "what makes a
projection reproducible?" at the type level: a projection is reproducible
iff its `horizon` contains no `:latest` references.

---

## Refinement Types

A refinement type `T where φ` constrains the values of type `T`:

```text
T where φ  ≡  { v : T | φ(v) }
```

**Typing rule:**

```text
Γ ⊢ e : T
Γ ⊢ φ(e) : Bool    (φ is a decidable predicate in CORE fragment)
──────────────────────────────────────────────────────────────────
Γ ⊢ e : T where φ
```

**Decidable predicates (CORE):**

- Linear arithmetic: `x > 0`, `x + y < 100`, `length(xs) == n`
- Structural checks: `has_field(r, label)`, `tag(v) == :some`
- Comparison: `x == y`, `x != y`
- Boolean combination: `φ₁ && φ₂`, `!φ`, `φ₁ || φ₂`

**Non-decidable predicates (ESCAPE — `refinement_predicate`):**

- Non-linear arithmetic: `x * y > 0`
- String patterns: `matches(s, regex)`
- Recursive predicates: `sorted(xs)`
- Calls to user-defined contract nodes

**Subsumption rule** (checking a refinement at a use site):

```text
Γ ⊢ e : T where φ
φ(e) follows from Γ    (provable by linear-arithmetic decision procedure)
───────────────────────────────────────────────────────────────────────────
Γ ⊢ e : T    (strip refinement when constraint is satisfied)
```

When the subsumption check cannot be decided statically, the compiler emits
a `constraint_observation` with status `:pending` and defers to runtime
evaluation (which then emits `:satisfied` or `:failed`).

---

## Observation Type: Obs[kind, T]

The type system makes observations first-class:

```text
Obs[kind, T] = an observation packet of packet kind `kind` carrying payload T
```

Typing rules:

```text
-- Producing an observation
Γ ⊢ e : T
kind ∈ PacketKind    (closed v0 family)
──────────────────────────────────────────
Γ ⊢ observe(kind, e) : Obs[kind, T]

-- Consuming an observation's payload
Γ ⊢ obs : Obs[kind, T]
──────────────────────────────────────────
Γ ⊢ obs.payload : Option[T]    (None when redacted)
```

**[D]** The payload is `Option[T]` not `T` because observations may be
redacted. A consumer must handle the `None` (redacted) case explicitly.
This makes privacy policy visible in the type system.

---

## Soundness Statement

**Theorem (Type Safety for v0):**

If `Γ ⊢ e : T` and `eval(e, Tt, inputs)` terminates, then the result is
either:

1. A value `v ∈ V` such that `v : T`, or
2. A `failure_observation` with a typed diagnostic and at least one `violates`
   link pointing to the constraint or contract that was not satisfied.

In other words: **a well-typed Igniter-Lang v0 program never produces an
untyped, unstructured, or invisible failure.**

**Proof sketch (Progress and Preservation):**

- *Progress*: Every well-typed, fully-supplied expression either evaluates
  to a value or produces a well-typed `failure_observation`. There is no
  stuck state (no "undefined behaviour").
- *Preservation*: If `Γ ⊢ e : T` and `e → e'` (one evaluation step), then
  `Γ ⊢ e' : T`. The type is preserved under reduction.

Both properties follow from the structural induction on typing derivations,
given the decidable expressions (no recursion, no higher-order, no open
world) and the explicit `Never` bottom type for failure paths.

---

## Named Slice vs. Projection (Terminology Clarification)

`temporal-positioning.md` uses both "named slice" and "projection." This
proposal defines:

| Term | Definition |
|------|-----------|
| `Projection[T, horizon]` | The *type* of a view over contract outputs at a declared horizon |
| Named slice | A contract or computed node declared with an explicit name and `ProjectionHorizon`; its type is `Projection[T, horizon]` |
| As-of view | An evaluation of a contract at a specific `as_of` point; the result type is `T` with temporal link, or `Projection[T, fixed_horizon]` if the horizon is fully fixed |

A **named slice** is the product-language term for what the type system
represents as `Projection[T, horizon]`. The naming is important for
human/agent readability; the type is important for the compiler.

---

## Compiler Pass 1: Type Checking

Pass 1 operates on the ClassifiedAST from Pass 0:

```text
Pass 1: Type Checking
  Input:  ClassifiedAST (all OOF rejected, ESCAPE annotated)
  Output: TypedAST where every node has an inferred type
          + list of type errors (if any)
  Algorithm:
    1. Collect all InputPort types (declared).
    2. Propagate types forward through the DAG (topological order).
    3. At each ComputeNode: type-check body Expr under Γ = {deps → types}.
    4. At each PortBinding: check source type <: target type.
    5. At each Guard: check predicate is decidable (CORE) or ESCAPE.
    6. At each TemporalCtx use: verify TemporalPolicy of consuming nodes.
    7. At each Store/History/Projection use: verify temporal capability.
    8. Emit TypeError observations for failures (compile.type_mismatch etc).
```

**Complexity:** O(n · |T|) where n is the number of nodes and |T| is the
depth of the type derivation. For typical contract sizes, this is fast.
Structural type unification is O(n) with union-find.

---

## Type System and DSL Keyword Mapping

| DSL keyword | Type-level meaning |
|-------------|-------------------|
| `input :x, type: T` | Adds `x: T` to input port Γ |
| `output :y` | Checks final node type against declared `T`; emits `Projection[T, Tt]` |
| `compute :n, return_type: T` | Node body must type-check to `T` |
| `compose :c, ContractRef` | Port bindings must satisfy subtyping |
| `guard { ... }` | Predicate type-checked as `Bool`; ESCAPE if non-linear |
| `lookup :store, as_of: t` | `store: Store[T]` under `TemporalCtx[as_of]` |
| `scope :s` | Creates named `Projection[Out, horizon_from_scope]` |
| `history :h` | `h: History[T]`; replay-capable under explicit cursor |
| `effect :e` | `e: EffectDecl[In, ReceiptType]`; write typed as `Obs[:receipt_observation, ReceiptType]` |

---

## Open Questions

[Q] Should `ContractRef[In, Out]` be in CORE or is it always ESCAPE?
In v0 contracts are not first-class values (PROP-001 decision). But
`ContractRef` as a *type* (used in `embed` signatures) is different from
a *value*. Recommendation: `ContractRef[In, Out]` as a type annotation is
CORE; passing a `ContractRef` as a runtime value is OOF.

[Q] Should `TemporalPolicy` be inferred or declared?
Recommendation: inferred in v0 (the type checker propagates temporal
requirements upward from `Store` / `History` / `Temporal` uses). Explicit
declaration is allowed as a documentation override and checked for consistency.

[Q] How should the type system handle `Any` inputs from external systems
(e.g., raw JSON from an HTTP boundary)?
Recommendation: an adapter contract at the boundary must narrow `Any` to
a declared type via a guard. `Any` may not appear inside a CORE contract
body. Entry-point adapters may use `Any` with the `refinement_predicate`
escape on the narrowing guard.

[Q] Is `Projection[T, horizon]` too early for v0? Could it be deferred
to a later track?
Recommendation: Keep `Projection[T, horizon]` in v0 because the Architect
Supervisor's directive from `temporal-positioning.md` explicitly asks for
typed projections. Defer only the *runtime semantics* (e.g., incremental
materialization of projections); the *type* should be settled now.

---

## Rejected Paths

[X] Nominal types as primary. Structural types are the right default for
a demand-driven, composable contract language. Nominal types require a
central registry and create artificial incompatibilities.

[X] Full Hindley-Milner type inference. HM inference requires unification
over arbitrary term shapes. For v0, explicit type annotations on contract
ports are required; inference is limited to node bodies within a contract.
This keeps type checking fast and errors local.

[X] Effect types as part of T (effect system inside the type grammar).
Effects are declared separately via `EffectDecl` and `Obs` types. Embedding
effects into the type grammar (à la Koka or Haskell) would require an effect
row system, which is complex and out-of-scope for v0.

[X] Dependent types (types that depend on runtime values). Breaks decidability.

[X] `T where φ` as CORE for arbitrary predicates. Refinement types with
arbitrary predicates are ESCAPE (`refinement_predicate`). CORE refinements
are restricted to decidable predicates.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-004
Status: done

[D] Decisions:
- Type grammar: base, structural (Record, Variant, Collection, Option),
  reference (Ref, ContractRef), temporal storage (Store, History, BiHistory),
  TemporalCtx[policy], Projection[T, horizon], refinement (T where φ),
  Obs[kind, T], Any, Never.
- Subtyping: structural width/depth for Record; covariant Collection/History/
  Store/Option; invariant Ref/BiHistory; contravariant ContractRef inputs.
- Temporal capabilities are part of the type: Store[T] is as_of-capable;
  History[T] additionally replay-capable; BiHistory[T] requires bi_temporal ESCAPE.
- Projection[T, horizon] is the type-level representation of a named slice.
  Reproducible iff horizon contains no :latest references.
- Observation payload is Option[T] (not T): the None case handles redacted
  observations. Privacy policy is visible in the type system.
- Soundness statement: well-typed programs never produce untyped or invisible
  failures. Progress + Preservation hold for the v0 CORE fragment.
- Type checking is Pass 1; operates on ClassifiedAST from Pass 0.
- Store reads without explicit as_of context are OOF (not just a warning).
- TemporalPolicy is inferred in v0 (not required to be declared explicitly).

[R] Recommendations:
- Directly address temporal-positioning.md directives: Tt as contract parameter,
  storage types with temporal capabilities, and Projection[T, horizon] as typed
  horizon — all included.
- Proceed to bridge-observation-envelope-v0 (Research Agent track): the type
  system now provides a formal basis for typing observation packets in the
  bridge mapping.
- Consider a follow-up PROP-005 on the axiom/built-in function type signatures
  (the "thin axiom layer" from Law 9).

[S] Signals:
- Projection[T, horizon] as a first-class type is the key novelty that
  distinguishes Igniter-Lang from plain Datalog or SQL. It gives reproducibility
  a formal home in the type system.
- Option[T] for observation payloads elegantly handles redaction at the type
  level — agents and compilers must explicitly handle the redacted case.
- The TemporalPolicy inference strategy (propagate upward from storage uses)
  is similar to Rust's lifetime inference: annotations are optional; the
  compiler derives requirements from usage.

[Q] Open Questions:
- Should ContractRef[In, Out] be CORE as a type annotation only?
- Should TemporalPolicy be inferred or require explicit declaration?
- How to handle Any-typed inputs at external boundaries (JSON, HTTP)?
- Is Projection[T, horizon] ready for v0 or better deferred as a type descriptor?

[X] Rejected:
- Nominal types as primary.
- Full Hindley-Milner inference.
- Effect system inside type grammar.
- Dependent types.
- Arbitrary refinement predicates as CORE.

---

## Errata v0.1 — Stage 2 type constructors reserved (2026-05-06)

_Source: META-EXPERT-005 (archaeology), META-EXPERT-006-language-model-revision-v0.md (Q1, Q3, Q4 resolved)._

### E1 — `History[T]` and `BiHistory[T]` as first-class type constructors (Stage 2)

PROP-004 v0 declares `History[T]` and `BiHistory[T]` as **storage types**
(temporal capability markers on `Store`). This was correct for Stage 1.

Stage 2 promotes them to **first-class type constructors** with operations:

```
History[T]     -- temporal container; carries a time-indexed sequence of T values
BiHistory[T]   -- bitemporal container; two-axis: valid time × transaction time

-- Subtyping chain (Stage 2):
T  ⊑  History[T]  ⊑  BiHistory[T]
```

**Operations (Stage 2, specified in PROP-022)**:

```
history[T].[t]                  →  T        -- point access at time t
history[T].avg[period]          →  T        -- requires Numeric[T]
history[T].rollup(:grain)       →  History[T]
history[T].history_until(t)     →  History[T]
bi_history[T].[vt: t1, tt: t2] →  T        -- bitemporal point access
```

The formal unification (Stage 2):
```
History[T]  ≡  OLAPPoint[T, {time: DateTime}]
```

### E2 — `OLAPPoint[T, Dims]` reserved as Stage 2 type constructor

A multi-dimensional generalisation of `History[T]`. Not in scope for Stage 1.

```
OLAPPoint[T, Dims]   -- value of type T at a point in dimension space Dims

-- Type rules (Stage 2, specified in PROP-024):
OLAPPoint[T, D][d: v]  →  OLAPPoint[T, D - {d}]   -- slice reduces dims by 1
OLAPPoint[T, {}]       →  T                         -- fully resolved = scalar
```

Stage 1 compilers must reject `OLAPPoint` type expressions as OOF.

### E3 — `~T` probabilistic lift reserved as Stage 2

```
~T   -- probabilistic lift: a value of type T carrying confidence metadata
     -- { value: T, confidence: Float, lo: T?, hi: T? }

-- Subtyping: T is a subtype of ~T (exact is a special case of approximate)
T  ⊑  ~T
```

Stage 2 specified in PROP-026 (future). Stage 1 compilers must reject `~T`
type expressions as OOF.

### E4 — Minimal trait set (Stage 2)

PROP-016 specifies the full polymorphism/trait system. This errata records
the four minimal traits required to type the Stage 2 primitives:

```
trait Numeric   { add, sub, mul, div, neg, compare }
trait Temporal  { as_of, at, rollup, history_until }
trait Foldable  { fold, map, filter, count, first, last }
trait Observable { to_obs_packet }

-- Implementations (Stage 2):
impl Numeric  for Integer, Float, Decimal[N]
impl Temporal for History[T], BiHistory[T], OLAPPoint[T, Dims]
impl Foldable for Collection[T], History[T], OLAPPoint[T, Dims]
impl Observable for all contract output types
```

### E5 — Unit types as refinement types (Stage 2, via existing machinery)

Physical unit types are refinement types expressed via the existing `T where φ`
syntax (already in PROP-004 §Refinement Types):

```
type Kelvin          = Float where value >= 0.0
type Meter           = Float
type Second          = Float where value >= 0.0
type MeterPerSecond  = Float  -- semantic alias; full unit algebra in Stage 3
```

Full dimensional unit algebra (compile-time dimensional analysis) is Stage 3.
Stage 2 allows unit aliases as named refinement types only.

[Next] Proposed next slices:
- PROP-005: Bridge Observation Envelope v0
  (now has formal type grounding: typed packets, Obs[kind, T], Option payload)
- Research Agent track: temporal-contracts-and-projections-v0
  (the named slice / projection model from temporal-positioning.md;
   can now reference Projection[T, horizon] from PROP-004)
- Optional: PROP-004b Axiom Layer Type Signatures
  (formal types for the built-in function set / thin axiom layer)
```
