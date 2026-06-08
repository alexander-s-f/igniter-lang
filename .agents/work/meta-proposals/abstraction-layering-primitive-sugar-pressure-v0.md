# Abstraction Layering Primitive Sugar Pressure v0

Role: `[Igniter-Lang Archive/Form Expert]`
Track: `abstraction-layering-primitive-sugar-pressure-v0`
Status: research-note
Date: 2026-05-07

Related:
- [Syntax Density Research](syntax-density-human-agent-research-v0.md)
- [Data Structures Surface Pressure](data-structures-as-contract-surface-pressure-v0.md)
- [Rust Comparison Pressure](rust-comparison-language-pressure-v0.md)

---

## Purpose

This note records a growing pressure signal:

```text
Igniter-Lang risks becoming visually monotone.
```

Everything can be explained as a contract, but not everything should be shown to
the user at the same abstraction level.

The problem:

- core contracts
- data structures
- primitive operations
- runtime evidence
- domain workflows
- stores
- mesh execution
- examples / fixtures

can all appear on one flat plane.

That is formally honest, but it can weaken human comprehension.

---

## Core Diagnosis

[D] "Everything is contract" is a substrate principle, not necessarily a surface
syntax principle.

The surface needs visible abstraction levels:

```text
primitive values
  -> ordinary data structures
  -> structural domain shapes
  -> contract workflows
  -> runtime/evidence/storage profiles
  -> distributed/mesh execution
```

If every layer looks like a top-level contract declaration, the language becomes
academically clean but visually flat.

---

## Monotonicity Symptoms

Signals observed so far:

1. Academic examples feel harder than business workflows.
2. Linked-list definitions are precise but not a good everyday `Array` surface.
3. It is unclear where the program starts.
4. Modules/namespaces/groups are needed for scanning.
5. Instances like Alice/Bob need a data syntax, not a contract ceremony.
6. Primitive arithmetic/comparison/indexing should be familiar.
7. Data profiles (`packet`, `event`, `view`, `receipt`) help because they create
   visible levels.
8. `compute` repeated everywhere can make intermediate graph nodes look heavier
   than their semantic importance.

---

## Primitive Surface / Contract Substrate

The design principle to pressure after current critical stages:

```text
surface primitives are allowed when they lower to explicit contract semantics.
```

Examples:

```text
[1, 2, 3]             -> Array[Int] literal / stdlib contract primitive
{ name: "Alice" }     -> Record literal
scores.sort()         -> Ordered + Array.sort lowering
employee.name         -> field access
users["alice"]        -> Map[String, User].get
entry MonitorSupply   -> module execution metadata
fixture People { ... } -> typed data set, not runtime contract
```

[D] This is not a retreat from contract theory. It is a readability layer over
contract-correct lowering.

---

## Proposed Future Pressure Track

After the important Stage 2 critical path closes, create a focused track:

```text
primitive-surface-and-abstraction-layering-v0
```

Goal:

```text
make Igniter-Lang visibly layered without losing SemanticIR/contract rigor.
```

Scope candidates:

- `entry` / `export` / main contract surface
- `namespace` / grouping / module organization
- primitive literals: arrays, maps, records
- standard collection profiles: `Array`, `Map`, `Set`, `Enumerable`
- basic operators and method-like sugar
- instance / fixture syntax
- data shape profiles: `packet`, `event`, `view`, `receipt`, `snapshot`
- canonical formatter rules that make abstraction levels visible

Non-goals:

- no arbitrary Ruby-like metaprogramming
- no hidden time/evidence/lifecycle defaults
- no sugar that cannot round-trip to ParsedProgram/SemanticIR
- no grammar changes before compiler/runtime critical path is stable

---

## Layering Sketch

### Layer 0: Literals

```text
1
"Alice"
:dispatcher
[1, 2, 3]
{ name: "Alice", role: :dispatcher }
```

### Layer 1: Structural Values

```text
Employee {
  id: "emp-1"
  name: "Alice"
  role: :dispatcher
}
```

### Layer 2: Data Profiles

```text
packet EmployeeImported { ... }
event EmployeeHired { ... }
receipt HiringDecision { ... }
view EmployeeSummary { ... }
```

### Layer 3: Contracts

```text
contract ScoreCandidate(candidate: Candidate) -> score: RiskScore {
  ...
}
```

### Layer 4: Runtime/Evidence Profiles

```text
profile audited {
  lifecycle: :audit
  evidence: required
  backend: :ledger
}
```

### Layer 5: System/Distributed Surface

```text
mesh DispatchMesh { ... }
store decisions: History[Decision] { ... }
metric regional_supply: Integer { ... }
```

[R] The formatter should make these layers visually recognizable.

---

## Timing Recommendation

[R] Do not force this into the current critical path.

Current priority remains:

```text
SemanticIR emitter extraction
OLAP TypeChecker/SemanticIR
production RuntimeMachine/TBackend integration
```

After those close, this pressure deserves a deliberate syntax/design round
because it affects the language's long-term learnability.

---

## Success Criteria For The Later Track

A later primitive/sugar track should succeed only if:

- sugar lowers to explicit ParsedProgram/SemanticIR structures
- diagnostics can point to both surface and lowered meaning
- agent round-trip remains possible
- human examples become shorter and clearer
- no evidence/time/lifecycle claim becomes implicit accidentally
- business examples and academic examples both become easier to read

---

## Handoff

[D] Recorded monotone-abstraction pressure as a future language-design concern.

[S] The language needs primitive surfaces and visible abstraction levels after
the critical Stage 2 path, not during it.

[R] Create `primitive-surface-and-abstraction-layering-v0` after current major
Stage 2 blockers close.
