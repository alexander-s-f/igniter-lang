# PROP-041: T2 Structural-Size Relation v0

Status: experiment-pass
Date: 2026-06-08
Author: `[Portfolio Architect Supervisor]`
Depends on: PROP-039 (managed recursion and loop classes), PROP-041-P3 (proof-local gate, 48/48 PASS)
Stage: 3
Evidence: igniter-lang/experiments/prop041_structural_size_relation_proof/ — 48/48 PASS (2026-06-08)
P4 review: igniter-lang/.agents/work/tracks/prop041-structural-size-relation-production-graduation-authorization-review-v0.md

---

## Authority Boundary

Authorized by this document:
- Grammar design for module-level `size_relation TypeName accessor` declarations
- STDLIB_REGISTRY design: Collection.tail, Collection.rest (stdlib_certified)
- Trust-metadata model: stdlib_certified / user_assumed trust levels
- OOF-R8 and OOF-R9 diagnostic code specifications (candidate → canonical)
- SemanticIR shape: `structural_size_v1` termination variant with `size_relation` sub-object
- Backward compatibility rule for T2-unaware compilers
- Numeric dotted-path boundary (OOF-R3 scope preservation)

Not authorized by this document:
- Production edits to classifier.rb / typechecker.rb / semanticir_emitter.rb (requires P6)
- Lab Rust symmetry implementation (requires proposal lock → P6)
- Cross-module size_relation import (post-T2)
- Contract-inline size_relation shorthand (v1 deferred)
- Compiler verification of user-assumed relations (post-T2)
- T3 numeric measure level (post-T2)
- T4 lexicographic / T5 proof-receipt levels (post-T2)
- SMT-backed relation verification (pre-v1)
- Runtime execution, VM changes, production, release, certification
- Stable public API for size_relation surface

---

## § 1. Purpose

### § 1.1 The Problem

PROP-039 introduced StructuralRecursion and the `decreases variant` clause, with a proof
gate showing that variant checking for simple identifiers (e.g., `decreases items`) and
numeric subtraction (e.g., `decreases n - 1`) can be classified as `syntactic_v0`
termination evidence.

For dotted-path decreases variants (e.g., `decreases items.tail`), PROP-039 leaves a
**fail-closed boundary**: OOF-R3 fires for all dotted-path forms. This is conservative
and correct for T1, but it blocks a broad class of useful structural recursion:

```igniter
recursive contract ProcessList {
  input items: Collection[Integer]
  compute result = recur(items.tail)
  output result: Integer
  decreases items.tail
  max_steps 100
}
```

The compiler knows that `Collection.tail` structurally decreases the input. Yet under
T1, it fires OOF-R3 because dotted-path variants are fail-closed.

### § 1.2 T2 Structural-Size Evidence

PROP-041 introduces the second termination trust level: **T2 structural-size relation**.

T2 is not a proof of termination. It is a mechanism for the compiler to record
**structural-size evidence with explicit trust metadata**. The compiler checks that:

1. A size relation is registered for the (type, accessor) pair used in `decreases`;
2. The `recur()` call site passes the registered accessor at the correct argument position;
3. The SemanticIR records the evidence and trust level.

What the compiler does NOT do:
- Verify that the accessor returns a structurally smaller value (post-T2).
- Prove termination in a formal sense.
- Treat user declarations as compiler-verified proof.

The trust levels carry this distinction explicitly:

| Trust level | Meaning |
|-------------|---------|
| `stdlib_certified` | The standard library author certifies this accessor structurally decreases the type. Hardcoded in the compiler. |
| `user_assumed` | The module author has declared a structural decrease relation. The compiler records the assertion but does not verify it. |

### § 1.3 Design Postulates

1. **Evidence is not proof.** `structural_size_v1` in SemanticIR means "structural-size
   evidence recorded with trust metadata." It does not mean "termination proven."

2. **Opt-in surface.** T2 is triggered only by `decreases items.accessor` (dotted-path
   form). Programs using simple-identifier `decreases items` remain T1 / `syntactic_v0`
   without modification or upgrade.

3. **Order-independent declarations.** `size_relation` declarations are pre-scanned
   before any contract body is processed. A declaration appearing after the contract
   that uses it is equally valid.

4. **Numeric boundary preservation.** Dotted-path variants where the accessor name
   belongs to the compiler-known numeric list route to OOF-R3, not OOF-R8. This
   preserves the T3/numeric boundary and prevents numeric measures from silently
   appearing as T2 structural relations.

---

## § 2. Grammar Design

### § 2.1 New module-level production

`size_relation` declarations appear at module level, alongside `type`, `contract`, and
`profile` declarations. They are not body-level declarations inside a contract.

```
size-relation-decl ::= "size_relation" type-name accessor-name

type-name     ::= ident     -- the type whose structural size is related
accessor-name ::= ident     -- the field/method that returns a smaller value of the same type
```

### § 2.2 Usage in recursive contracts

A `size_relation` declaration enables a matching dotted-path `decreases` clause:

```igniter
module ItemProcessing

size_relation ItemList remaining

type ItemList {
  remaining: ItemList
}

recursive contract Process {
  input items: ItemList
  compute result = recur(items.remaining)
  output result: Integer
  decreases items.remaining
  max_steps 1000
}
```

**Call-site requirement:** The argument at the position corresponding to the decreasing
parameter must be `subject.accessor`, not any other expression. OOF-R9 fires if the
relation is registered but the call site does not use the required accessor.

### § 2.3 Multiple relations

Each `size_relation` declaration covers exactly one `(TypeName, accessor)` pair.
Multiple relations are declared on separate lines:

```igniter
size_relation WorkQueue remaining_tasks
size_relation WorkQueue deferred_tasks
```

There is no multi-accessor shorthand syntax in v1. One declaration per accessor.

### § 2.4 Declaration order

`size_relation` declarations are order-independent with respect to contract bodies.
The following is valid:

```igniter
module T2C

recursive contract OrderIndependent {
  input queue: JobQueue
  compute result = recur(queue.pending_jobs)
  output result: Integer
  decreases queue.pending_jobs
  max_steps 500
}

type JobQueue {
  pending_jobs: JobQueue
}

size_relation JobQueue pending_jobs   -- appears after the contract, still valid
```

### § 2.5 Scope

`size_relation` declarations are module-scoped. Cross-module import of size relations
is deferred (post-v1).

---

## § 3. Registry Model

### § 3.1 Two-tier registry

At compile time, the compiler maintains a structural-size registry — a map from
`(TypeName, accessor)` pairs to trust metadata objects. The registry has two layers:

| Layer | Contents | How populated |
|-------|----------|---------------|
| STDLIB layer | `stdlib_certified` entries | Hardcoded in compiler |
| USER layer | `user_assumed` entries | Module-level `size_relation` declarations |

User-declared entries are scoped to the module where they appear. Stdlib entries
are always available regardless of module.

### § 3.2 Stdlib-certified entries (v1)

| Type | Accessor | Trust | Source |
|------|----------|-------|--------|
| Collection | tail | stdlib_certified | compiler_builtin |
| Collection | rest | stdlib_certified | compiler_builtin |

`source = "compiler_builtin"` is the canonical source string for stdlib entries.
This string appears verbatim in SemanticIR output and must not vary by compiler
implementation.

The v1 stdlib list is exhaustive. Future stdlib entries require PROP amendment.

### § 3.3 Trust levels (exhaustive in v1)

| Level | Value string | Meaning |
|-------|-------------|---------|
| Stdlib-certified | `"stdlib_certified"` | Compiler-attested structural decrease |
| User-assumed | `"user_assumed"` | Module-author-declared; not compiler-verified |

No other trust levels exist in v1. Trust levels are not user-extensible. A future
`compiler_verified` or `proof_backed` level would require a new PROP.

### § 3.4 Numeric accessor boundary

The compiler maintains a **closed list** of accessor names that are categorically
excluded from T2 treatment. When a dotted-path `decreases` variant uses an accessor
from this list, the compiler routes to OOF-R3 (not OOF-R8), regardless of whether
a `size_relation` declaration exists for that name.

**v1 numeric-excluded accessor list (hardcoded, closed):**

```
count  length  size  total_count  num_items  num_elements
```

Rationale: these names conventionally denote integer-measure values, not structural
sub-values. Routing them to OOF-R3 preserves the T3 numeric-measure territory
and prevents accidental T2 classification of integer accessors.

This list is **not user-extensible in v1**. If a user-defined type has an accessor
named `count` that returns a structurally-smaller value of the same type, they must
rename the accessor to avoid the numeric-excluded boundary. Extension of this list,
or a mechanism to override it, is deferred to T3.

---

## § 4. Diagnostics

### § 4.1 OOF-R8 — Missing structural size relation

**Code:** OOF-R8
**Stage:** TypeChecker
**Trigger:** `decreases items.accessor` where `accessor` is not in the numeric-excluded
list AND no `size_relation` entry exists for `(subject_type, accessor)`.
**Severity:** blocking (same as OOF-R3)

**Message format:**
```
contract '<name>' — decreases variant '<subject>.<accessor>': no size-relation
registered for (<SubjectType>, <accessor>); declare
'size_relation <SubjectType> <accessor>' at module scope
```

**Example:**
```
contract 'Process' — decreases variant 'items.remaining': no size-relation
registered for (ItemList, remaining); declare 'size_relation ItemList remaining'
at module scope
```

### § 4.2 OOF-R9 — Structural size relation call-site mismatch

**Code:** OOF-R9
**Stage:** TypeChecker
**Trigger:** A `size_relation` entry exists for `(subject_type, accessor)` and
`decreases subject.accessor` is present, but the `recur()` call site does not pass
`subject.accessor` at the corresponding argument position.
**Severity:** blocking

**Message format:**
```
recur() in '<contract>' — T2 structural decrease violated: expected
'<subject>.<accessor>' at position <N>, got: <actual_arg_description>;
declared size_relation (<SubjectType>, <accessor>) requires the registered
accessor at the call site
```

**Example (wrong accessor):**
```
recur() in 'WrongAccessor' — T2 structural decrease violated: expected
'queue.remaining' at position 1, got: queue.secondary;
declared size_relation (ItemQueue, remaining) requires the registered
accessor at the call site
```

**Example (plain ref instead of dotted accessor):**
```
recur() in 'PlainRef' — T2 structural decrease violated: expected
'items.remaining' at position 1, got: ref:items;
declared size_relation (ItemList, remaining) requires the registered
accessor at the call site
```

### § 4.3 OOF-R3 scope — unchanged by T2

OOF-R3 continues to fire for all non-T2 forms:

| Form | Fires |
|------|-------|
| `decreases items.count` (numeric-excluded) | OOF-R3 |
| `decreases items.accessor` where accessor not registered and is numeric-excluded | OOF-R3 |
| T1 program using `decreases n + 1` (increasing) | OOF-R3 |
| `recur()` with wrong variant arg (T1 form) | OOF-R3 |
| Unwhitelisted dotted field in T1 context | OOF-R3 |

T2 extension does NOT weaken OOF-R3. OOF-R3 remains the fail-closed diagnostic
for all unsupported termination evidence forms.

### § 4.4 Diagnostic precedence

When a dotted-path variant is present:

1. Check if accessor is in numeric-excluded list → OOF-R3 (stop)
2. Check if `(subject_type, accessor)` is in registry → T2 pass path
3. If not in registry → OOF-R8
4. If in registry, check call site → OOF-R9 if mismatch

OOF-R8 and OOF-R9 are mutually exclusive for a given contract. A contract cannot
fire both.

---

## § 5. SemanticIR Shape

### § 5.1 T2 clean contract — structural_size_v1

When a contract passes T2 validation (relation registered + call site correct), the
SemanticIR termination object is emitted as `structural_size_v1`:

**stdlib_certified (Collection.tail):**
```json
{
  "contract_name": "TailDotted",
  "modifier": "recursive",
  "termination": {
    "decreases": "items.tail",
    "variant_check": "structural_size_v1",
    "size_relation": {
      "accessor": "tail",
      "trust": "stdlib_certified",
      "source": "compiler_builtin"
    }
  }
}
```

**user_assumed (module declaration):**
```json
{
  "contract_name": "Process",
  "modifier": "recursive",
  "termination": {
    "decreases": "items.remaining",
    "variant_check": "structural_size_v1",
    "size_relation": {
      "accessor": "remaining",
      "trust": "user_assumed",
      "source": "ItemProcessing"
    }
  }
}
```

`source` for user-assumed entries is the module name where the `size_relation`
declaration appears.

### § 5.2 T1 contract — syntactic_v0 unchanged

T1 programs do not change their SemanticIR output under T2 extension:

```json
{
  "contract_name": "T1Arithmetic",
  "modifier": "recursive",
  "termination": {
    "decreases": "n",
    "variant_check": "syntactic_v0"
  }
}
```

`syntactic_v0` is the T1 variant check value. Programs with `decreases items` (simple
identifier, no dot) stay `syntactic_v0`. There is no auto-upgrade path from T1 to T2.

### § 5.3 OOF-R8 / OOF-R9 contracts

Contracts that fire OOF-R8 or OOF-R9 receive `status: "blocked"` and do not emit
a `termination` object in SemanticIR (same behavior as OOF-R3 blocking contracts).

### § 5.4 fuel_bounded contracts

`fuel_bounded` contracts are unaffected by T2. They do not have a `termination`
object in SemanticIR and do not interact with the structural-size registry.

---

## § 6. Backward Compatibility

### § 6.1 T1 programs — no change

All existing T1 programs (simple-identifier `decreases`, numeric arithmetic, `decreases fuel`)
are unaffected. The T2 path is entered only when `decreases_variant` contains a `.` (dotted path).
There is no automatic upgrade.

### § 6.2 T2-unaware compiler conformance allowance

A compiler that does not implement T2 (`structural_size_v1`) may continue to emit
OOF-R3 for dotted-path `decreases` variants without conformance break.

This allowance is explicit: the PROP-039 G5 gate established OOF-R3 as the fail-closed
default for dotted-path forms. A compiler that fires OOF-R3 where a T2-capable compiler
would rehabilitate is conservative, not incorrect.

Once a compiler implements T2, the following hold:
- OOF-R8 must be distinct from OOF-R3 (separate code, separate message).
- OOF-R9 must be distinct from OOF-R3 and OOF-R8.
- A registered (type, accessor) pair must not fire OOF-R3.
- The numeric-excluded list must be applied before registry lookup.

### § 6.3 OOF-R3 message stability

OOF-R3 message format and diagnostic code are unchanged by this PROP. PROP-041
introduces new codes (R8/R9); it does not modify R3.

---

## § 7. Closed Surfaces

| Surface | Status |
|---------|--------|
| Production compiler edits (classifier.rb, typechecker.rb, semanticir_emitter.rb) | Closed — P6 planning required |
| Lab Rust T2 symmetry | Closed — open after P6 |
| Cross-module size_relation import | Closed — post-v1 |
| Contract-inline size_relation shorthand | Closed — v1 |
| Multi-accessor shorthand syntax (`size_relation T a, b`) | Closed — v1 |
| Compiler verification of user-assumed relations | Closed — post-T2 |
| T3 numeric measure level (numeric accessor as decreasing measure) | Closed — post-T2 |
| T4 lexicographic ordering | Closed — post-T2 |
| T5 proof receipts / proof obligations | Closed — post-T2 |
| SMT-backed relation verification | Closed — pre-v1 |
| User-extensible numeric-excluded list | Closed — v1 |
| Trust level beyond stdlib_certified / user_assumed | Closed — v1 |
| Runtime execution, VM stack, TCO | Closed — PROP-039 boundary |
| Stable public API for size_relation surface | Closed — experiment-pass only |
| Production / release / certification / portability | Closed — standing authorization |

---

## § 8. Open Questions Resolved (from P4 review)

| # | Question | Decision |
|---|----------|----------|
| Q1 | NUMERIC_ACCESSORS policy | Hardcoded closed list in v1 (§ 3.4). Not user-extensible. Extension deferred to T3. |
| Q2 | Backward-compat for T2-unaware compilers | Formal allowance in § 6.2: OOF-R3 for dotted-path is conservative, not incorrect. |
| Q3 | Multi-accessor syntax | One declaration per accessor, multi-line (§ 2.3). No shorthand in v1. |
| Q4 | Trust level exhaustiveness | Exhaustive in v1: only `stdlib_certified` and `user_assumed` (§ 3.3). |
| Q5 | Canonical stdlib source string | `"compiler_builtin"` — verbatim, must not vary by implementation (§ 3.2). |

---

## § 9. Conformance Evidence

| Artifact | Location | Checks |
|----------|----------|--------|
| T2a stdlib-certified gate | igniter-lang/experiments/prop041_structural_size_relation_proof/fixtures/t2a_* | 7 |
| T2b user-assumed gate | igniter-lang/experiments/prop041_structural_size_relation_proof/fixtures/t2b_* | 8 |
| T2c dotted-path rehabilitation | igniter-lang/experiments/prop041_structural_size_relation_proof/fixtures/t2c_* | 9 |
| T2d OOF-R8 firing | igniter-lang/experiments/prop041_structural_size_relation_proof/fixtures/t2d_* | 4 |
| T2e OOF-R9 firing | igniter-lang/experiments/prop041_structural_size_relation_proof/fixtures/t2e_* | 3 |
| T2f numeric boundary | igniter-lang/experiments/prop041_structural_size_relation_proof/fixtures/t2f_* | 4 |
| T2g T1 regression | igniter-lang/experiments/prop041_structural_size_relation_proof/fixtures/t2g_* | 10 |
| T2h OOF-R3 scope | igniter-lang/experiments/prop041_structural_size_relation_proof/fixtures/t2h_* | 3 |
| Verify script | igniter-lang/experiments/prop041_structural_size_relation_proof/verify_prop041_t2.rb | **48/48 PASS** |
| T2 pipeline (proof-local) | igniter-lang/experiments/prop041_structural_size_relation_proof/t2_pipeline.rb | reference impl |

---

## § 10. Next Route

This proposal is the canonical specification for T2. It is the authority surface
for production graduation.

| Next step | Route | Status |
|-----------|-------|--------|
| Production-edit planning (classifier.rb + typechecker.rb + semanticir_emitter.rb) | P6 | Opens after this proposal is accepted |
| Lab Rust T2 symmetry | LAB-TERM-T2-P6 (or equivalent) | Opens after P6 auth |
| PROP-039 conformance package §1.2 update (OOF-R8/R9 rows) | In-place update | Opens with P6 planning |
| Cross-module size_relation | Post-v1 PROP | Closed |
| T3 numeric measure | Post-T2 PROP | Closed |
