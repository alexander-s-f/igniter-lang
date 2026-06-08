# PROP-016: Polymorphism, Traits, and Contract Shapes v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Track: igniter-lang/polymorphism-traits-contract-shapes-v0
Depends on: `PROP-013`, `PROP-014`, `PROP-015`

---

## Purpose

PROP-015 established the grammar kernel. It leaves open how Igniter-Lang
handles **abstraction over types**. This proposal answers:

- How do contracts become generic? (`contract Add[T]`)
- How are constraints expressed? (`T: Additive`)
- What are traits? (compile-time capability, not OO parent class)
- What is a `contract_shape`? (structural API surface)
- How does `implements` work? (structural satisfaction check)
- How does overload resolution work? (compile-time only)
- What enters SemanticIR? (no unresolved polymorphism at runtime)

[D] The primary model is:
**parametric types + trait constraints + structural contract shapes**.
Not OO inheritance. The distinction is critical:

```text
OO inheritance: contract Add < AddBase { override! compute sum }
  -> runtime vtable, dynamic dispatch, fragile base class

ECL polymorphism: contract Add[T: Additive] implements AddShape[T] {
  compute sum = add(a, b)
}
  -> compile-time monomorphization, no dynamic dispatch, structural proof
```

---

## Part 1: Generic Contracts

### Syntax

```text
contract Add[T: Additive] {
  input  a: T
  input  b: T
  compute sum = add(a, b)
  output sum: T
}
```

### Grammar extension

```text
TypeParam    := Name (":" ConstraintList)?
ConstraintList := Constraint ("&" Constraint)*
Constraint   := Name ("[" TypeRef "]")?

ContractDecl := "contract" Name ("[" TypeParams "]")? "{" BodyDecl* "}"
FunctionDecl := "def" Name ("[" TypeParams "]")? "(" Params? ")" "->" TypeRef "{" Body "}"
TypeDecl     := "type" Name ("[" TypeParams "]")? "{" FieldDecl* "}"
TypeParams   := TypeParam ("," TypeParam)*
```

### Monomorphization at classify time (Pass 0)

```text
A generic contract is NOT a runtime entity.
At Pass 0 (Classify), every use of a generic contract must provide
concrete type arguments:

  -- Usage site:
  compute result = Add[Integer]{ a: x, b: y }

The classifier resolves T := Integer, checks T satisfies Additive[Integer],
and emits a monomorphized ContractIR with T replaced by Integer throughout.
SemanticIR contains only concrete types. No type variables survive to runtime.
```

**[D] Monomorphization is mandatory. No type variables in SemanticIR.**

This is a fundamental decision: Igniter-Lang trades binary size (potentially
multiple specializations) for runtime simplicity (no generics dispatch) and
CORE determinism (no polymorphic runtime dispatch path).

---

## Part 2: Traits (Type Classes)

### Definition

A trait is a **compile-time capability declaration**. It defines a set of
operations that a type must provide. It is not a class, not an interface in
the OO sense, and not a mixin.

```text
TraitDecl := "trait" Name "[" TypeParam "]" "{" TraitMethod* "}"
TraitMethod := "def" Name "(" Params? ")" "->" TypeRef
```

### Example: Additive

```text
trait Additive[T] {
  def add(a: T, b: T) -> T
  def zero() -> T
}
```

### Example: Ordered

```text
trait Ordered[T] {
  def compare(a: T, b: T) -> Integer   -- negative, zero, positive
}

-- Derived: less_than, greater_than, etc. are stdlib defs over compare.
```

### Example: Hashable (for Map keys in PROP-013)

```text
trait Hashable[T] {
  def hash(v: T) -> Integer
  def eq(a: T, b: T) -> Bool
}
```

---

## Part 3: Trait Implementations (`impl`)

### Syntax

```text
ImplDecl := "impl" Name "[" TypeRef "]" "{" ImplMethod* "}"
ImplMethod := FunctionDecl
```

### Example: impl Additive[Integer]

```text
impl Additive[Integer] {
  def add(a: Integer, b: Integer) -> Integer { a + b }
  def zero() -> Integer { 0 }
}
```

### Example: impl Additive[Float]

```text
impl Additive[Float] {
  def add(a: Float, b: Float) -> Float { a + b }
  def zero() -> Float { 0.0 }
}
```

### Example: impl Additive[String] — rejected

```text
-- Rejected: String + String is ambiguous (concat or type error?)
-- See Part 7 for String operator policy.
-- String is NOT Additive. Use stdlib.string.concat explicitly.
```

### Coherence rule (no orphan impls)

```text
CR-1: An impl must be declared in the same module as the trait OR
      in the same module as the type.
      No orphan impls (implementing a foreign trait for a foreign type).

CR-2: At most one impl of trait T for type A in the entire program.
      Duplicate impl -> compile error.

CR-3: impl must satisfy all trait methods.
      Missing method -> compile error at Pass 1.
```

---

## Part 4: Contract Shapes

A `contract_shape` is a **structural API surface declaration**. It defines
what inputs and outputs a conforming contract must provide. It is not
a contract itself — it does not compute anything.

### Syntax

```text
ShapeDecl := "contract_shape" Name ("[" TypeParams "]")? "{" ShapePort* "}"
ShapePort := ("input" | "output") Name ":" TypeRef (LifecycleAnn)?
```

### Example: AddShape

```text
contract_shape AddShape[T] {
  input  a: T
  input  b: T
  output sum: T
}
```

### Example: DispatchShape

```text
contract_shape DispatchShape {
  input  order_id:      String
  input  technician_id: String
  output assignment_id: String  lifecycle :durable
  output receipt:       AssignmentReceipt lifecycle :audit
}
```

### contract_shape as specification

```text
A contract_shape is a promise about ports only.
It does not constrain:
  - internal compute nodes
  - escape declarations
  - window declarations
  - TBackend read strategy

Two contracts that implement the same shape may have completely different
internal implementations. The shape is a structural interface, not a template.
```

---

## Part 5: `implements` — Structural Satisfaction

### Syntax

```text
ContractDecl := "contract" Name ("[" TypeParams "]")?
                ("implements" ShapeRef ("," ShapeRef)*)?
                "{" BodyDecl* "}"
ShapeRef     := Name ("[" TypeRef ("," TypeRef)* "]")?
```

### Example

```text
contract Add[T: Additive] implements AddShape[T] {
  input  a: T
  input  b: T
  compute sum = add(a, b)
  output sum: T
}
```

### Implements check (Pass 1)

```text
For each ShapeRef in implements list:
  1. Resolve ShapeRef with concrete type args (T := Integer for Add[Integer])
  2. For each shape input port:
       Check contract has input port with same name and type_tag. -> error if missing
  3. For each shape output port:
       Check contract has output port with same name, type_tag, and lifecycle. -> error if missing
  4. If all ports satisfied -> implements check: PASS
  5. Else -> compile error: "contract X does not satisfy shape Y: missing port Z"
```

**[D] `implements` is structural, not nominal.**

If a contract has all required ports, it satisfies the shape, even without
the `implements` keyword. The keyword makes the constraint explicit and
compiler-verified.

**[D] `implements` is checked at Pass 1 (TypedProgram), not at runtime.**

A failed `implements` check is a compile error. There is no runtime
"does this conform?" check.

---

## Part 6: `refines` and `composes` (vs inheritance)

### Problem with inheritance

```text
OO: contract B < A
  -> B inherits all of A's compute nodes (implicit behavior)
  -> B can override A's nodes (fragile base class problem)
  -> runtime dispatch needed: which version runs?
  -> violates CORE determinism (which node? when?)
```

Igniter-Lang does not have inheritance. Instead:

### `refines` — shape narrowing

```text
ShapeDecl := "contract_shape" Name ("[" TypeParams "]")?
             ("refines" ShapeRef)?
             "{" ShapePort* "}"
```

`refines` means: this shape is a superset of the refined shape's ports.

```text
contract_shape AuditDispatchShape refines DispatchShape {
  -- all ports from DispatchShape, plus:
  output audit_log: AuditRecord lifecycle :audit
}
```

**[D] `refines` is port addition only. No behavior inheritance.**

A shape that refines another must satisfy the base shape's ports AND declare
additional ports. There is no behavior to inherit — shapes have no compute nodes.

### `composes` — contract composition

```text
contract Pipeline[T, U] composes [StageA[T], StageB[T, U]] {
  -- Pipeline must satisfy all output ports of StageA used as inputs to StageB
  -- The compiler verifies composition compatibility at Pass 0
}
```

**[D] `composes` is explicit wiring, not automatic delegation.**

Unlike OO delegation, `composes` requires the contract to explicitly wire the
outputs of one component to the inputs of another. There is no implicit
forwarding.

---

## Part 7: String and `++` Operator Policy

### The problem

`+` is overloaded in many languages for both numeric addition and string
concatenation. This creates ambiguity:

```text
-- Ambiguous in many languages:
"hello" + " world"   -- string concat or type error?
1 + 2                -- numeric add
```

### Decision: `+` for numeric only; `++` for sequence append

```text
[D] Igniter-Lang uses separate operators:
  +   -> Additive[T] addition (numeric types only)
  ++  -> append for Collection[T] and String

String is NOT Additive. "hello" + "world" is a type error.
String concatenation: "hello" ++ " world"  (preferred)
                   or concat("hello", " world")  (explicit stdlib call)

-- Why ++?
-- ++ is the Collection append operator from PROP-013.
-- String is Collection[Character] conceptually.
-- This unifies String and Collection under the same append operator.
-- No ambiguity with numeric +.
```

**impl Ordered[String]** is valid (lexicographic compare).
**impl Additive[String]** is rejected (OOF: `zero()` for String is undefined).
**impl Hashable[String]** is valid (required for Map[String, V]).

---

## Part 8: Overload Resolution

### Rule: compile-time only, no dynamic dispatch

```text
Overload resolution in Igniter-Lang:
  1. At each call site, collect all visible impls for the called trait method.
  2. Resolve the concrete type argument (from type inference or annotation).
  3. Select the unique matching impl.
  4. Inline the impl body at the call site (monomorphization).
  5. If zero matching impls -> compile error: "no impl of T for Additive"
  6. If multiple matching impls -> compile error (CR-2 violation)
  7. No resolution deferred to runtime.
```

**[D] There is exactly one impl per (trait, type) pair. Ambiguity is a
compile error, not a runtime dispatch.**

### OOF: dynamic dispatch

```text
OOF-P1: Dynamic dispatch.
  Any call where the impl cannot be resolved at compile time -> OOF.
  No `send`, no method_missing, no reflection-based dispatch.

OOF-P2: Runtime monkey patching.
  Adding an impl after compile time -> OOF. Impls are compile-time entities.

OOF-P3: Ambiguous overloads.
  If two impls match the same (trait, type) -> OOF (CR-2 violation).

OOF-P4: Recursive trait bounds.
  trait A[T: B] where trait B[T: A] -> OOF (undecidable constraint cycle).

OOF-P5: Higher-kinded types in v0.
  trait Functor[F[_]] -> not supported in v0.
  F[_] (type constructor polymorphism) is deferred to PROP-017.
```

---

## Part 9: SemanticIR Representation

### No type variables in SemanticIR

```text
SemanticIR must contain only concrete types. After Pass 0 (Classify), all
type parameters are resolved to concrete types by monomorphization.

Add[Integer] monomorphizes to:
  ContractIR {
    contract_id:    "add_integer",
    name:           "Add[Integer]",
    fragment_class: "core",
    input_ports:    [{ name: "a", type_tag: "Integer" },
                     { name: "b", type_tag: "Integer" }],
    compute_nodes:  [{ name: "sum",
                       expression: { kind: "apply",
                                     operator: "impl.additive.integer.add",
                                     operands: [ref(a), ref(b)] } }],
    output_ports:   [{ name: "sum", type_tag: "Integer" }]
  }
```

### Trait impl in SemanticIR

```text
Trait impls are inlined at monomorphization time.
They do NOT appear as separate entities in SemanticIR.

After monomorphization:
  add(a, b) where T := Integer
  -> apply("impl.additive.integer.add", [ref(a), ref(b)])
  -> which is identical to stdlib.numeric.add for Integer

The impl is erased. Only the concrete operator reference remains.
```

### contract_shape in SemanticIR

```text
contract_shape declarations emit a ShapeDescriptor in SemanticIR:

"shapes": {
  "AddShape[Integer]": {
    "input_ports":  [{ "name": "a", "type_tag": "Integer" },
                     { "name": "b", "type_tag": "Integer" }],
    "output_ports": [{ "name": "sum", "type_tag": "Integer" }]
  }
}

The implements check result is recorded:
"implements": [{ "shape": "AddShape[Integer]", "check": "passed" }]
```

---

## Part 10: Relation to PROP-013 Stdlib

### Stdlib traits

```text
PROP-013 stdlib operations (fold, map, filter, count, sum, avg, min, max)
now formally require trait constraints:

sum(c: Collection[T]) -> T  requires T: Additive
  -- sum = fold(c, T.zero(), (acc, x) -> add(acc, x))

min(c: Collection[T]) -> Option[T]  requires T: Ordered
max(c: Collection[T]) -> Option[T]  requires T: Ordered

avg(c: Collection[T]) -> Option[Float]  requires T: Additive & T: DivByInt
  -- DivByInt: def div_by_int(v: T, n: Integer) -> Float
```

**[D] The stdlib operations from PROP-013 are now formally trait-constrained.**
Their signatures are updated:

| Operation | Constraint |
|-----------|------------|
| `sum` | `T: Additive` |
| `min`, `max` | `T: Ordered` |
| `avg` | `T: Additive & T: DivByInt` |
| `group_by` | `K: Hashable` |
| `fold(c, init, f)` | no constraint on T, constraint on f |
| `map`, `filter` | no constraint on T |

### Stdlib impls provided

```text
module stdlib/core/impls.ig:
  impl Additive[Integer] { ... }
  impl Additive[Float]   { ... }
  impl Ordered[Integer]  { ... }
  impl Ordered[Float]    { ... }
  impl Ordered[String]   { ... }  -- lexicographic
  impl Hashable[Integer] { ... }
  impl Hashable[String]  { ... }
  impl Hashable[Symbol]  { ... }
```

---

## Part 11: Relation to PROP-015 Modules

### Trait visibility

```text
A trait is visible within its module.
Other modules import traits explicitly:
  import stdlib/core.{ Additive, Ordered, Hashable }

An impl is visible in the module where it is declared.
The coherence rule (CR-1) prevents conflicting impls across modules.
```

### Trait in module fragment class

```text
A trait declaration is CORE by definition (no behavior, just signatures).
An impl is CORE if all its methods are CORE.
An impl is ESCAPE if any method contains TBackend reads or FFI calls.
A generic contract is CORE or ESCAPE depending on its impl resolution.
```

---

## Part 12: Future Macro Boundary

The following features are explicitly deferred and are NOT in PROP-016:

```text
[DEFERRED to PROP-017+]
  Higher-kinded types (Functor[F[_]], Monad[M[_]])
  Associated types (trait Iterator[T] { type Item })
  Trait inheritance (trait B[T] extends A[T])
  Conditional impls (impl Additive[Collection[T]] where T: Additive)
  Derive macros (@derive Additive)
  Type aliases (type IntPair = Pair[Integer, Integer])
  Existential types (impl AddShape[?])
  Default trait method implementations
  Negative bounds (T: !Mutable)
```

**[D] No macro system in PROP-016.** The "future macro boundary" is:
if a feature requires generating code from annotations, it is post-PROP-018.
The `@derive` syntax is reserved but not defined.

---

## Open Questions

[Q-1] Should `DivByInt` be a separate trait, or should `avg` require a
different constraint? Option: `avg` takes a separate `divisor` function
as an explicit parameter (`avg(c, div: (T, Integer) -> Float)`).

[Q-2] Should `refines` be in v0, or deferred to PROP-017? It is simple
(port addition only) but may not be needed for the two existing fixtures.

[Q-3] Should `composes` have syntax in v0, or is it a semantic concept
only? The two existing contracts don't use composition at the contract level.

[Q-4] Should impl coherence require that impls be in the trait's module,
the type's module, or either? Rust uses "either" — is that sufficient?

[Q-5] Should generic contracts emit a single polymorphic SemanticIR entry
or one entry per monomorphization? Recommendation: one per monomorphization.

---

## Rejected Paths

[X] OO inheritance as a first-class language feature.
The fragile base class problem is incompatible with CORE determinism.
A compute node that can be silently overridden cannot be reproduced.

[X] Dynamic dispatch / virtual method tables at runtime.
Overload resolution is compile-time only. No vtables, no `send`, no reflection.

[X] String as Additive.
`zero()` for String is undefined. String concatenation uses `++`.

[X] Higher-kinded types in v0.
`Functor[F[_]]` requires a more complex type system. Deferred to PROP-017.

[X] Orphan impls.
Implementing a foreign trait for a foreign type creates global coherence
problems. Prohibited by CR-1.

[X] Default method implementations in traits.
Too close to OO mixin semantics. Deferred to PROP-017.

[X] Structural subtyping for contracts.
`contract A[T]` is not a subtype of `contract B[T]` even if they have
identical ports. Contracts are not types — they are computation units.
Shapes are the structural API surface; contracts satisfy shapes.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/polymorphism-traits-contract-shapes-v0
Proposal: igniter-lang/docs/proposals/PROP-016-polymorphism-traits-contract-shapes-v0.md
Status: done

[D] Decisions:
- Monomorphization at Pass 0. No type variables in SemanticIR.
- Traits are compile-time capability declarations (not OO parents).
- impl is unique per (trait, type) pair. Duplicate impl -> compile error.
- Coherence rule CR-1: impl must be in trait module or type module.
- contract_shape is structural port declaration only. No behavior.
- implements is structural satisfaction check at Pass 1. No runtime check.
- refines is port addition only. No behavior inheritance.
- composes is explicit wiring, not automatic delegation.
- + is Additive[T] only (numeric). ++ is append (Collection, String).
- String is NOT Additive. String is Ordered and Hashable.
- Overload resolution is compile-time only. No dynamic dispatch.
- All OOF-P1..OOF-P5 violations are compile errors.
- Impls are inlined/erased at monomorphization. Only concrete operators in SemanticIR.
- Stdlib PROP-013 operations are now trait-constrained (sum: T: Additive, etc.)
- Generic contracts monomorphize to "add_integer", "add_float", etc. in SemanticIR.

[R] Recommendations:
- Update PROP-013 stdlib function signatures with trait constraints.
- Add impl stdlib/core/impls.ig to stdlib module map.
- Implement implements check in Accept Pass after TypedProgram.
- Grammar extension: add TypeParams, ShapeDecl, ImplDecl, TraitDecl.
- No macro system until PROP-017+.

[S] Signals:
- The two existing fixtures (Add, AvailabilityProjection) are already
  implicitly monomorphized (Add[Integer] is already concrete).
  PROP-016 formalizes what is already true in the devkit.
- contract_shape AddShape[T] covers the "what does a contract expose"
  question that comes up in bridge/package integration (selected_profile).
- impl Additive[Integer] + monomorphization means the SemanticIR operator
  "stdlib.numeric.add" is exactly the resolved form of "add" in Add[Integer].

[Q] Open Questions:
- DivByInt trait vs explicit divisor param for avg?
- refines in v0 or deferred?
- composes syntax in v0 or semantic concept only?
- One SemanticIR entry per monomorphization or a polymorphic template?

[X] Rejected:
- OO inheritance.
- Dynamic dispatch at runtime.
- String as Additive.
- Higher-kinded types in v0.
- Orphan impls.
- Default method implementations in traits.
- Structural subtyping for contracts.

[Next] Proposed next slice:
- PROP-017: Schema Evolution and Contract Migration v0
  (CompatibilityReport dimension for type changes across versions)
- Devkit: update add.igapp/ fixture to reflect Add[Integer] monomorphized form
  and ShapeDescriptor in SemanticIR
- Parser extension: add TypeParams, TraitDecl, ImplDecl, ShapeDecl to lexer/parser
```
