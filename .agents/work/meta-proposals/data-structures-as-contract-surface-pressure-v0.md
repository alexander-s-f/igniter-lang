# Data Structures as Contract Surface Pressure v0

Role: `[Igniter-Lang Archive/Form Expert]`
Track: `data-structures-as-contract-surface-pressure-v0`
Status: research-note
Date: 2026-05-07

Related:
- [Syntax Density Research](syntax-density-human-agent-research-v0.md)
- [Human-Agent Comprehension Testing](human-agent-comprehension-testing-v0.md)
- `igniter-lang/experiments/human_agent_syntax_comprehension_fixture/academic_sorting_structures.ig`

---

## Purpose

The academic sorting specimen created useful pressure:

```text
"everything is contract" is theoretically coherent, but humans need familiar
surface primitives for arrays, maps, records, entrypoints, grouping, and object
instances.
```

This note records the design pressure without promoting any syntax to canon.

---

## Core Tension

Igniter-Lang wants a strong contract substrate:

```text
types, values, operations, runtime, storage, evidence, and execution are all
contract-shaped.
```

But a human should not need to read a full contract definition to understand:

```text
[1, 2, 3]
users["alice"]
employee.name
sort(scores)
```

[D] The language should preserve the contract semantics underneath while giving
ordinary data structures a familiar surface.

This is a least-surprise rule:

```text
[1, 2, 3] should look like an array.
It may lower to Array[Int] contract semantics.
```

---

## User Pressure

The following comprehension issues were surfaced:

1. **Entry point is unclear.**
   Where does execution start? Is there a `main()`? A top-level `contract`?
   A selected exported contract?

2. **Everything appears on one flat plane.**
   Modules, namespaces, groups, packages, examples, tests, contracts, types, and
   data instances need visible organization.

3. **Business examples read better than academic primitives.**
   A logistics workflow is easier to understand than a fully contract-modeled
   linked list.

4. **Basic operations should not require ceremony.**
   Arithmetic, comparison, indexing, array literals, map literals, and simple
   field access should feel ordinary.

5. **Instances are missing.**
   If there is a contract or type `Employee`, how do we create Alice and Bob?

6. **Primitive collections may be syntactic sugar.**
   Arrays, maps, sets, and enumerables can look normal while lowering to
   contract-correct primitives.

---

## Contract Substrate vs Surface Primitive

The key distinction:

```text
surface syntax      what humans write
contract substrate  what the compiler proves/lowers
```

Example surface:

```text
let xs = [1, 2, 3]
let ys = xs.push(4).sort()
let second = ys[1]
```

Possible lowering:

```text
Array[Int].from([1, 2, 3])
Array[Int].push(xs, 4)
Array[Int].sort(...)
Array[Int].get(ys, 1)
```

The user does not need to see the full contract form unless they are defining
or verifying the primitive.

---

## Primitive Contract Sketch

The underlying primitive can still be contract-shaped:

```text
contract Array[T] {
  input values: Collection[T]

  operation get(index: Integer) -> Option[T]
  operation push(value: T) -> Array[T]
  operation pop() -> Pair[Option[T], Array[T]]
  operation sort() -> Array[T] where T: Ordered[T]

  invariant size_non_negative: size(values) >= 0
    severity :error
}
```

But most programs should use the familiar surface:

```text
let names = ["Alice", "Bob"]
let first = names[0]
let sorted = names.sort()
```

[R] Treat primitive collection syntax as a standard-library profile over
contracts, not as a rejection of the contract model.

---

## Entry Point Options

Possible entrypoint surfaces:

### Option A: Exported Contract

```text
export contract MonitorSupply
```

Pros:
- simple for current contract model
- works for services and CLI invocation

Cons:
- less familiar to general-purpose programmers

### Option B: Main Contract

```text
main contract Run(args: Args) -> result: Result {
  ...
}
```

Pros:
- obvious start point
- still contract-shaped

Cons:
- may overfit to app execution, not library/module code

### Option C: Module Manifest

```text
module SupplyWatch {
  entry MonitorSupply
}
```

Pros:
- separates organization from execution
- good for packages with multiple contracts

Cons:
- another layer of syntax

[R] Prefer explicit `entry` or `export` metadata over hidden "first contract wins"
rules.

---

## Grouping And Hierarchy

Flat files are readable only up to a point. The language likely needs visible
organization:

```text
module SupplyWatch

namespace Domain {
  type ClinicRef { ... }
  type SupplierRef { ... }
}

namespace Events {
  event ReportReceived { ... }
}

namespace Workflows {
  contract MonitorSupply(...) -> ... { ... }
}
```

This is not just aesthetics. Grouping improves:

- human scanning
- agent summarization
- diagnostics paths
- ownership boundaries
- imports
- generated docs

[R] Keep grouping low-magic. Namespaces should not change semantics except
symbol resolution and visibility.

---

## Instances And Fixtures

The language needs a way to express data instances without making every value a
contract definition.

Possible syntax:

```text
let alice = Employee {
  id: "emp-1",
  name: "Alice",
  role: :dispatcher
}

let bob = Employee {
  id: "emp-2",
  name: "Bob",
  role: :technician
}
```

For reusable examples:

```text
fixture People {
  alice: Employee = { id: "emp-1", name: "Alice", role: :dispatcher }
  bob: Employee = { id: "emp-2", name: "Bob", role: :technician }
}
```

[R] Use `fixture` or `sample` for named data sets. Do not force examples into
runtime contracts.

---

## Arithmetic And Comparison

Basic operators should be ordinary:

```text
a + b
x < y
xs[0]
user.name
```

Under the hood:

```text
a + b   -> stdlib.numeric.add(a, b)
x < y   -> Ordered.compare(x, y) == :less
xs[0]   -> Array.get(xs, 0)
```

[D] Ordinary operator surface does not contradict contract semantics if lowering
is typed, explicit in SemanticIR, and diagnostic-friendly.

---

## Layered Data Model

A useful hierarchy:

```text
Primitive literals:
  1, "x", true, :symbol

Collection literals:
  [1, 2, 3]
  { "alice": employee1 }

Structural values:
  Employee { id: "emp-1", name: "Alice" }

Profiles over structural values:
  packet, event, receipt, view, snapshot

Contracts:
  computation and verification over typed values

Runtime contracts:
  storage, history, ledger, mesh, evidence, lifecycle
```

This gives humans levels of abstraction while preserving the "everything has a
contract interpretation" principle.

---

## Academic Specimen Lessons

The academic sorting specimen is still valuable, but mainly as a stress test for
general-purpose language pressure:

- ADTs and generics are understandable but feel academic.
- `List[T] = nil | cons` is precise but not the everyday collection surface.
- `decreases` is useful for proof-minded readers but too formal for ordinary
  business code.
- `Array`, `Map`, and `Enumerable` should probably be primitive surface forms.
- Contract-mode definitions of primitives should exist in the standard library,
  not in every user program.

[S] Business workflows are better first-screen examples. Academic examples are
better for proving general-purpose capability and compiler reasoning.

---

## Recommendations

[R1] Introduce the idea of **primitive surface / contract substrate** as a
language design principle.

[R2] Keep familiar literals:

```text
[1, 2, 3]
{ key: value }
Employee { ... }
```

and lower them into typed SemanticIR/contract primitives.

[R3] Add explicit entrypoint syntax before using large examples for human tests:

```text
entry MonitorSupply
```

or:

```text
main contract Run(...)
```

[R4] Add namespaces/groups as a readability feature, with minimal semantic
effect.

[R5] Treat `Array`, `Map`, `Set`, and `Enumerable` as standard primitive
profiles backed by contracts.

[R6] Add fixture/sample syntax for named instances like Alice and Bob.

---

## Handoff

[D] Recorded data-structure and entrypoint pressure from the academic sorting
specimen.

[S] The language needs familiar primitive surfaces over contract-correct
lowerings.

[R] Next specimen should test a mixed level: ordinary arrays/maps/instances on
the surface, with evidence and contracts still visible where they matter.
