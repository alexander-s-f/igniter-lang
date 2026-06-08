# Human-Agent Comprehension Results 004: Surface Layering From Spec Review v0

Role: `[Igniter-Lang Archive/Form Expert]`
Track: `human-agent-comprehension-results-004-surface-layering-from-spec-review-v0`
Status: research-results
Date: 2026-05-07

Related:
- [Human-Agent Comprehension Testing](human-agent-comprehension-testing-v0.md)
- [Data Structures as Contract Surface Pressure](data-structures-as-contract-surface-pressure-v0.md)
- [Rust Comparison Pressure](rust-comparison-language-pressure-v0.md)
- [Abstraction Layering Pressure](abstraction-layering-primitive-sugar-pressure-v0.md)
- [Comprehension Results 002](human-agent-comprehension-results-002-field-supply-watch-v2.md)
- [Comprehension Results 003](human-agent-comprehension-results-003-academic-sorting-structures-v0.md)

---

## Purpose

This document records a follow-up review after exposing part of the language
specification to an external agent.

The review is useful because it moved from pure blind comprehension into
surface-design pressure: what syntax would make the language easier for both
humans and agents while preserving the contract substrate.

This document does not promote any syntax to canon.

---

## Result Summary

| Area | Reviewer preference | Signal |
|------|---------------------|--------|
| Entry point | `entrypoint` block | Best human-agent surface because it declares contract, schedule, and context together |
| Grouping | `section` blocks | Visual/semantic grouping without namespace complexity |
| Basic operations | familiar operators | Least-surprise arithmetic, comparison, boolean logic, indexing |
| Instances | `entity alice: Employee` | Distinguishes living identity-over-time from plain structural values |
| Primitives | arrays/maps/sets as sugar | Familiar surface lowering to contract-backed primitives |
| Streams | method-chain surface | Reads naturally for window/map/filter pipelines |

[D] The review independently reinforced the current pressure: Igniter-Lang needs
visible abstraction layers above the uniform contract substrate.

[S] The proposed direction is compatible with "everything is contract" if source
syntax is treated as surface sugar over typed SemanticIR and contract-correct
lowerings.

---

## Pressure Signals

### L1: `entrypoint` Is Stronger Than `run` Or Annotation

The reviewer compared:

```text
run MonitorSupply { ... }
entrypoint watch_supply { ... }
contract MonitorSupply(...) -> ... @entrypoint
```

and preferred:

```text
entrypoint watch_supply {
  contract: MonitorSupply
  schedule: every 6.hours
  context: production_mesh
}
```

Pressure:

```text
entrypoints should be explicit orchestration declarations, not hidden annotations
or one-off run calls.
```

Why it matters:

- humans see "where the program starts"
- agents see schedule, context, and invocation shape
- runtime can compile entrypoints as contracts over execution

[R] Future entrypoint syntax should support scheduled, manual, service, CLI, and
test/fixture invocation without making "first contract wins" a hidden rule.

### L2: `section` Solves Readability Without Premature Namespace Semantics

The reviewer preferred:

```text
section Domain { ... }
section Storage { ... }
section Contracts { ... }
section Entry { ... }
```

over nested modules for first-pass comprehension.

Pressure:

```text
large files need visual and semantic grouping before they need nested namespace
semantics.
```

[S] `section` is promising because it improves scanning, agent summarization,
and generated docs while keeping symbol resolution simple.

[T] If `section` is purely organizational, diagnostics and formatting must make
that clear. If it later gains visibility/import semantics, it should become a
different construct such as `namespace` or nested `module`.

### L3: Ordinary Operators Should Stay Ordinary

The review explicitly expected:

```text
+ - * / == != > >= < <= && || !
```

and ordinary expressions:

```text
let shortage = max(0, demand - supply)
let is_critical = risk.value >= 0.700 && shortage > 0
```

Pressure:

```text
least-surprise operators are part of human-agent readability.
```

[D] This reinforces primitive surface pressure: ordinary expressions may lower
to typed standard contracts without making users write those contracts directly.

### L4: `entity` Names Identity-Over-Time

The reviewer distinguished:

```text
let alice: Employee = Employee { ... }
```

from:

```text
entity alice: Employee {
  name: "Alice"
  role: :engineer
}
```

Pressure:

```text
plain structural values and living durable identities need different surfaces.
```

Possible interpretation:

- `type Employee` defines shape
- `Employee { ... }` creates a structural value
- `entity alice: Employee { ... }` creates a named identity with lifecycle,
  history, permissions, or storage semantics

[S] `entity` resonates with temporal/audit language goals, especially History,
BiHistory, CRM/ERP, mesh ownership, and OSINT-like subject modeling.

[T] `entity` must not become a vague object/class replacement. It should mean
identity, lifecycle, and traceability.

### L5: Primitive Literals Should Lower To Contract-Backed Types

The review proposed:

```text
let nums = [1, 2, 3]
let lookup = { "kyiv" => :ua_kv, "lviv" => :ua_lv }
let tags = #{ :urgent, :medical, :cold_chain }
```

with inferred types:

```text
Array[Integer]
HashMap[String, Symbol]
Set[Symbol]
```

Pressure:

```text
familiar collection literals are necessary for general-purpose readability.
```

[S] This is the clearest bridge between ordinary programming and the contract
substrate: the source looks familiar, but the compiler still owns type,
lowering, diagnostics, and invariant obligations.

[T] Map literal syntax should be tested carefully. `=>` is clear for Ruby users,
but JSON-like `{ key: value }` is also heavily familiar. The language may need
different surfaces for maps and structural records.

### L6: Method-Chain Stream Surface Is Readable

The review rewrote stream work as:

```text
let signals = report_ingress
  .window(rolling: 6.hours)
  .map(r -> NormalizeReport(r, as_of).signal)
  .filter(s -> s.clinic.region.code == region.code)
```

Pressure:

```text
pipeline syntax may be better for stream transformations than low-level
fold-style primitives in human-facing examples.
```

[T] This creates a design fork:

- keep `fold_stream` / `accumulate` for explicit stateful stream folding
- allow method-chain sugar for common map/filter/window pipelines

[R] Treat stream method chains as source sugar over stream contracts, not as a
separate untyped collection API.

### L7: Record Spread Needs Care

The reviewer used:

```text
DemandSignal { ...report, reported_at: report.source.captured_at, evidence: evidence }
```

Pressure:

```text
record spread is compact but can hide field mapping and domain translation.
```

[S] Spread syntax may be useful for DTO transformations.

[T] In audit-heavy code, spread should probably be constrained by type checking,
explicit override rules, and diagnostics that show which fields moved.

---

## Recommended Surface Layers

The review suggests a useful layered model:

```text
section       organizational readability
entrypoint    execution start and schedule
entity        identity/lifecycle value
type          structural shape
literal       primitive value surface
contract      computation/evaluation boundary
profile       runtime/proof/evidence mode
store/stream  durable and temporal data surfaces
```

[D] This is exactly the missing visual stratification noted in the monotonicity
pressure documents.

---

## Routing

| Signal | Owning next role | Action |
|--------|------------------|--------|
| L1 entrypoint | Compiler/Grammar Expert + Research Agent | Compare entrypoint block vs export/main forms after Stage 2 critical path |
| L2 section | Archive/Form Expert + Compiler/Grammar Expert | Test purely organizational grouping in specimens before namespace semantics |
| L3 operators | Compiler/Grammar Expert | Preserve least-surprise expression grammar and typed lowering |
| L4 entity | Research Agent + Bridge Agent | Explore entity as identity/lifecycle/history surface |
| L5 literals | Compiler/Grammar Expert | Design primitive literal lowerings for Array/HashMap/Set |
| L6 stream chains | Compiler/Grammar Expert | Compare chain sugar with `accumulate`/`fold_stream` core |
| L7 spread | Compiler/Grammar Expert | Decide if record spread belongs in DTO/profile syntax |

---

## Handoff

[D] Follow-up spec review is recorded as surface-layering pressure.

[S] Strongest resonant ideas: `entrypoint`, `section`, `entity`, primitive
collection literals, and ordinary operators.

[T] These are not cosmetic. They reduce surface monotony and make abstraction
levels visible to both humans and agents.

[R] Do not open this as active canon work until critical Stage 2 is safe. After
that, create a bounded `primitive-surface-and-entrypoint-v0` syntax specimen.
