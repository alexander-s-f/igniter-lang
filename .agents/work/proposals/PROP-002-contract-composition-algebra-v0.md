# PROP-002: Contract Composition Algebra v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-001-semantic-domain-v0.md`

---

## Purpose

PROP-001 defined the semantic domain: values (V), types (T), temporal context
(Tt), contracts (C), expressions (Expr), observations (O), and failures (F).

A contract is a named, typed, demand-driven DAG computation. But contracts
in real systems are never single, isolated graphs. They compose:

- sequentially (one contract's output feeds another's input)
- in parallel (multiple independent contracts run concurrently)
- conditionally (branch on a value, select a contract)
- collectively (a collection of homogeneous contract instances)
- hierarchically (a contract embeds another as a sub-computation)

This proposal defines the **contract composition algebra** for Igniter-Lang
v0: the composition operators, their signatures, their algebraic properties,
and which properties are proved vs. assumed.

---

## Core Claim

[D] Contract composition in Igniter-Lang v0 is a **typed, demand-driven
graph algebra** over named ports. It is NOT:

- a monad (no bind, no flatMap, no monadic failure propagation)
- a free category (contracts are not morphisms between arbitrary objects)
- a dataflow graph without types (all ports carry declared types)

The closest formal analog is a **typed port graph algebra** — more
specifically, the structure of a **symmetric monoidal category of typed
signal-flow graphs** where objects are type-labeled port sets and morphisms
are contracts.

We do not require category theory to state the algebra. The v0 algebra is
stated as explicit operators with algebraic laws, proved or falsified case
by case.

---

## Named Port Model

Before defining operators, we need a precise port model.

A contract C exposes:

```text
Ports(C) = {
  in  : Map[PortName, T]   -- typed input ports
  out : Map[PortName, T]   -- typed output ports
}
```

A **port binding** connects an output port of one contract to an input
port of another:

```text
Binding = (C1, out_port) -> (C2, in_port)
  where type(C1.out[out_port]) <: type(C2.in[in_port])
```

Types must be compatible (subtype, not just equal) to allow flexible
composition without coercions.

[D] Port names are **semantically significant**. Two output ports with
different names but the same type are different semantic outputs. Renaming
requires an explicit adapter, not a silent cast.

---

## Composition Operators

### 1. Sequential Composition (>>)

```text
C1 >> C2 = C3
  where:
    C3.in  = C1.in union (C2.in minus bound_ports)
    C3.out = C2.out union (C1.out minus bound_ports)
    bound_ports = { p | (C1, p) -> (C2, q) is a valid binding }
```

Precondition: at least one binding exists from C1.out to C2.in.

**Result:** a new contract whose inputs are the unbound inputs of C1 and C2,
and whose outputs are the unbound outputs of C1 and C2. The bound ports
become internal nodes.

**Example:**

```text
PriceCalculator >> TaxApplier
  PriceCalculator.out.subtotal -> TaxApplier.in.subtotal
  Result.in  = PriceCalculator.in
  Result.out = TaxApplier.out
```

**Algebraic properties:**

| Property | Holds? | Proof sketch |
|----------|--------|-------------|
| Associativity: `(C1 >> C2) >> C3 = C1 >> (C2 >> C3)` | YES | DAG union is associative; port bindings are the same edges regardless of grouping |
| Commutativity: `C1 >> C2 = C2 >> C1` | NO | Port binding direction is ordered; C1's outputs connect to C2's inputs, not vice versa |
| Identity element | YES | Identity contract `Id[T]`: `in.x: T`, `out.x: T`, body = pass-through. `C >> Id = Id >> C = C` |

**Typing rule:**

```text
C1 : (In1, Out1)
C2 : (In2, Out2)
B  : Out1 compatible-with In2 (at least one valid binding)
------------------------------------------------------------
C1 >> C2 : (In1 union (In2 minus bound(B)), Out2 union (Out1 minus bound(B)))
```

---

### 2. Parallel Composition (||)

```text
C1 || C2 = C3
  where:
    C3.in    = C1.in union C2.in     (disjoint union; rename on collision)
    C3.out   = C1.out union C2.out   (disjoint union; rename on collision)
    C3.nodes = C1.nodes union C2.nodes
    C3.deps  = C1.deps union C2.deps (no cross-edges)
```

Precondition: C1 and C2 share no node names (rename if needed).

**Result:** a new contract that runs both contracts independently. No output
of C1 feeds into C2, and vice versa.

**Algebraic properties:**

| Property | Holds? | Proof sketch |
|----------|--------|-------------|
| Associativity: `(C1 \|\| C2) \|\| C3 = C1 \|\| (C2 \|\| C3)` | YES | Disjoint union of DAGs is associative |
| Commutativity: `C1 \|\| C2 = C2 \|\| C1` | YES | Disjoint union is commutative (up to port renaming) |
| Identity element | YES | Empty contract: `in = {}`, `out = {}`, no nodes. `C \|\| Empty = C` |

**Key property:** `||` is a **symmetric monoidal product** over contracts.
Together with `>>` and the identity contract, this gives the algebra the
structure of a **traced symmetric monoidal category** — the standard model
for dataflow languages (Petri nets, signal-flow graphs).

**Typing rule:**

```text
C1 : (In1, Out1)
C2 : (In2, Out2)
In1 and In2 disjoint (or renamed)
Out1 and Out2 disjoint (or renamed)
------------------------------------------------------------
C1 || C2 : (In1 union In2, Out1 union Out2)
```

---

### 3. Branch Composition (branch)

```text
branch(selector: C0, arms: { tag1: C1, ..., tagN: CN }) = C
  where:
    C0.out.tag : Variant { tag1: T1, ..., tagN: TN }
    Ci.in compatible with Ti for each i
    all Ci.out must share a common output type (or explicit result annotation)
```

**Semantics:** C0 is evaluated first. Its output determines which arm is
evaluated. Only one arm is evaluated per execution.

**Algebraic properties:**

| Property | Holds? | Proof sketch |
|----------|--------|-------------|
| Associativity | N/A | `branch` is not binary; arms are a labeled set |
| Commutativity of arms | YES | The arm map is unordered; evaluation follows the selector value |
| Identity | Partial | A single-arm `branch { only: C }` is equivalent to `C >> adapter` |

**Key constraint:** Branch arms must have **compatible output types**. If
arms have different output types, an explicit result type annotation is
required. This is the primary typing burden for branch composition.

**Out-of-fragment:** Dynamic branch selection where the arm set is not
statically known at compile time is **out-of-fragment** in v0. The arm set
must be a closed, statically enumerable variant.

---

### 4. Collection Composition (over)

```text
over(source: C0, element: C1) = C
  where:
    C0.out.items     : Collection[T]
    C1.in.item       : T
    C.in             = C0.in union (C1.in minus {item})
    C.out.results    : Collection[C1.out.result_type]
```

**Semantics:** C0 produces a collection. C1 is applied to each element
independently. Results are collected into a new collection of the same
cardinality.

**Algebraic properties:**

| Property | Holds? | Proof sketch |
|----------|--------|-------------|
| Associativity (homogeneous) | YES | `over(over(C0, C1), C2)` = `over(C0, C1 >> C2)` if types align |
| Commutativity | NO | C0 produces the source; it cannot swap roles with C1 |
| Distributivity | YES | `over(C0, C1 \|\| C2)` = `over(C0, C1) \|\| over(C0, C2)` if C1 and C2 are independent |

**Key constraint:** The element contract C1 must be **pure relative to
shared state**: it may read from stores through temporal context, but it
must not write to stores inside the collection loop without explicit
effect declarations.

---

### 5. Hierarchical Composition (embed)

```text
embed(outer: C_outer, inner_ref: ContractRef, as: NodeName) = C
  where:
    inner_ref resolves to C_inner at compile time
    C_outer has a compute node named `as` with body Apply(inner_ref, ...)
    The node's input/output types match C_inner.in / C_inner.out
```

**Semantics:** An outer contract treats an inner contract as a single compute
node — a black box with a typed port interface.

This is the composition that the current Igniter `compose` and `project`
DSL keywords implement.

**Algebraic properties:**

| Property | Holds? | Proof sketch |
|----------|--------|-------------|
| Observation transparency | YES | Inner contract's observations accessible via typed links |
| Associativity | YES | Embed chains are DAG edges; they compose associatively |
| Idempotency | NO | Embedding the same contract twice under different node names is valid but not idempotent |

**Key property: Observation transparency.** An embedded contract's
observations are accessible through typed links (`describes`, `depends_on`)
from the outer contract. The embedding namespaces, not hides, the inner
contract's observable surface.

---

## Algebraic Laws Summary

| Operator | Associative | Commutative | Has Identity | Notes |
|----------|-------------|-------------|-------------|-------|
| `>>` Sequential | YES | NO | YES (`Id[T]`) | Directed; ports must bind |
| `\|\|` Parallel | YES | YES | YES (`Empty`) | Symmetric monoidal product |
| `branch` Branch | N/A | YES (arms) | Partial | Arms must be statically closed |
| `over` Collection | YES (hom.) | NO | NO | C0 and C1 have fixed roles |
| `embed` Hierarchical | YES | NO | NO | DAG edges; observation transparent |

---

## Composition Closure Theorem

[D] The composition of well-typed v0 contracts is a well-typed v0 contract.

```text
If C1 and C2 are valid v0 contracts (DAG, stratified, decidable core),
then C1 >> C2, C1 || C2, branch(...), over(...), and embed(...) are also
valid v0 contracts, provided:
  - the resulting dep graph is still a DAG (no cycles introduced)
  - all port bindings are type-compatible
  - branch arms are statically closed
  - collection element contracts declare effects explicitly
```

**Proof strategy:** DAG union of DAGs is a DAG if and only if no new
cycles are introduced. Type compatibility is checked at binding points.
Both conditions are decidable in polynomial time (cycle detection + type
unification).

---

## Commutativity and Observation Conservation

If `C1 || C2 = C2 || C1` (up to port renaming), then both orderings must
produce the same observation set.

This connects to **Law 5 (Observation Conservation)**:

```text
If eval(C1 || C2, Tt, inputs) = eval(C2 || C1, Tt, inputs)
then the observation packets produced must be equivalent:
  same identity fields, possibly different provenance fields.
```

Parallel composition commutativity extends to the observation domain:
semantic content is invariant under reordering of independent parallel
contracts. Only provenance (producer, observed_at) may differ.

---

## Temporal Context and Composition

All composition operators are **transparent with respect to Tt**:

```text
eval(C1 >> C2, Tt, inputs) uses the same Tt throughout.
```

Exception: the `Temporal(as_of: t, body: Expr)` constructor creates a
**scoped temporal fork**:

```text
eval_at_Tt(Temporal(as_of: t, body: E)) = eval_at_{Tt with as_of=t}(E)
```

The fork is always explicit (Law 6) and visible as a temporal link in the
observation of the containing node.

**Implication for composition:** Contracts containing `Temporal` expressions
may produce observations at different temporal contexts than their caller.
The compiler must track temporal forks in the dependency graph to ensure
observation conservation is maintained across composition boundaries.

---

## Failure Propagation Through Composition

| Operator | Failure propagation rule |
|----------|--------------------------|
| `>>` | If C1 fails, C2 is not evaluated. The composed contract emits `dependency_failed` for C2's outputs that depended on C1. |
| `\|\|` | C1 and C2 fail independently. Failures in C1 do not prevent evaluation of C2. |
| `branch` | If C0 (selector) fails: all arms emit `dependency_failed`. If arm Ci fails: that failure is the composed contract's failure for that evaluation. |
| `over` | If C0 fails: all elements emit `dependency_failed`. If C1 fails for element k: `collection_element_failed` for that element; other elements continue. |
| `embed` | Same as `>>` at the embedding node: inner contract failure becomes `dependency_failed` for outer nodes depending on the embedded output. |

[D] Partial collection failure is a first-class outcome. The composed `over`
contract emits `collection_element_failed` failures alongside successful
element results — it does not discard the successful results.

---

## Fragment Classifier: Which Operators Are In v0 Core?

| Operator | In v0 core? | Condition |
|----------|-------------|-----------|
| `>>` | YES | No cycle introduced |
| `\|\|` | YES | Always (independent DAGs) |
| `branch` | YES | Arms statically closed, no recursion through branch |
| `over` | YES | Finite collection; no infinite streams |
| `embed` | YES | No circular embedding (self-embed = cycle = rejected) |

[X] Self-embedding: a contract embedding itself directly or transitively is
a cycle in the dependency DAG. It is `compile.cycle_detected` and
out-of-fragment in v0.

[X] Dynamic contract selection: choosing which contract to embed at runtime
based on a value is out-of-fragment in v0. All contract references must be
statically resolvable at compile time.

---

## Open Questions

[Q] Should `>>` allow **partial bindings** — where some outputs of C1 are
not consumed by C2 but passed through to the composed contract's outputs?
Current definition: YES (passthrough by default). Is this the right default,
or should unused bindings require explicit passthrough declarations?

[Q] How do **effects compose** across composition boundaries? If C1 and C2
both declare effect E, does `C1 >> C2` declare E once or twice? Proposal:
effects compose additively — the composed contract declares both instances,
and the runtime emits separate receipts. Effects are NOT merged unless an
explicit idempotency contract is declared.

[Q] Is `over` the right name for collection composition? The existing Igniter
DSL uses `map`. Alternatives: `map`, `apply_each`, `foreach`. `over` reads
most naturally as "run this contract over a collection" and avoids collision
with functional `map` expectations.

[Q] Should the algebra reserve a **feedback/loop** operator as a named
escape for saga/workflow patterns? Proposal: defer to v1; mark as
out-of-fragment in v0 with `workflow_loop` as the reserved escape keyword.

---

## Rejected Paths

[X] Monadic composition (`bind`/`flatMap`). The monadic model forces
sequential chains where failure short-circuits. This is too restrictive:
parallel and collection compositions have different failure semantics.
The typed port graph algebra is strictly more expressive.

[X] Implicit port binding by type. If C1 has one output of type `Money`
and C2 has one input of type `Money`, automatically binding them is
semantically dangerous — two contracts may produce `Money` for different
reasons. Port names must be explicit.

[X] Record smashing. Merging all output records into one flat record and
using structural matching for composition loses semantic port identity.

[X] Open-world composition (dynamically adding contracts to a running
graph). This requires reactive/incremental evaluation that is out-of-fragment
in v0.

[X] Recursive composition as a first-class operator. Self-embedding and
mutually-recursive contracts are out-of-fragment in v0.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-002
Status: done

[D] Decisions:
- Contract composition is a typed port graph algebra with five operators:
  sequential (>>), parallel (||), branch, collection (over), hierarchical (embed).
- >> is associative but NOT commutative. Identity is Id[T].
- || is associative AND commutative. Identity is Empty.
- Composition closure theorem: composition of well-typed v0 contracts is
  well-typed v0 (provable via DAG cycle detection + type unification).
- Partial collection failure is a first-class outcome (collection_element_failed).
- All operators are transparent with respect to Tt, except explicit
  Temporal(as_of: t, ...) scopes which create observable temporal forks.
- Dynamic contract selection and self-embedding are out-of-fragment in v0.
- Monadic composition rejected: the port graph algebra captures
  parallel/collection failure semantics more precisely.

[R] Recommendations:
- Accept the five-operator algebra as the v0 composition model.
- Use this algebra in PROP-003 to map DSL keywords (compose, project,
  map, branch, collection, guard) to composition operators.
- Document effect composition rules in PROP-004 (Type System v0).
- The bridge-observation-envelope-v0 research track should note which
  observation packets are produced at each composition boundary.

[S] Signals:
- || as symmetric monoidal product + >> as sequential composition gives
  the structure of a traced symmetric monoidal category: the categorical
  model for Petri nets, dataflow graphs, and signal-flow graphs. Rich
  decidability results are available in this family.
- Partial collection failure aligns with existing Igniter node-level failure
  state (not graph-level abort).
- Observation transparency of embed means agent introspection of composed
  contracts is always possible — no composition operator hides its
  sub-contracts' observable surface.

[Q] Open Questions:
- Partial binding in >>: passthrough by default or explicit passthrough?
- Effect composition: additive or deduplicated with idempotency contract?
- Is `over` the right name for collection composition?
- Should workflow_loop be reserved as an explicit escape keyword?

[X] Rejected:
- Monadic composition.
- Implicit port binding by type.
- Record smashing.
- Open-world dynamic composition.
- Recursive composition as first-class operator.

[Next] Proposed next slices:
- PROP-003: Grammar Fragment Classification
- PROP-004: Type System v0
- bridge-observation-envelope-v0 (Research Agent track, benefits from
  knowing which composition boundaries produce observation packets)
```
