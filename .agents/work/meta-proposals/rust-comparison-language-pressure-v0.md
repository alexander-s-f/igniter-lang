# Rust Comparison Language Pressure v0

Role: `[Igniter-Lang Archive/Form Expert]`
Track: `rust-comparison-language-pressure-v0`
Status: research-note
Date: 2026-05-07

Related:
- [Syntax Density Research](syntax-density-human-agent-research-v0.md)
- [Data Structures Surface Pressure](data-structures-as-contract-surface-pressure-v0.md)
- `playgrounds/docs/experts/igniter-lang/igniter-lang-implementation.md`

---

## Purpose

Rust is a useful comparison target for Igniter-Lang because it is strict,
compiled, explicit, practical, and unusually good at turning hard correctness
constraints into everyday programming discipline.

This note asks:

```text
What should Igniter-Lang learn from Rust without becoming Rust-shaped?
```

It is not a proposal and does not promote syntax to canon.

---

## Short Verdict

[D] Rust is a good model for:

- explicitness over metamagic
- algebraic data types
- pattern matching
- `Option` / `Result`
- traits as capability contracts
- strong diagnostics
- standard tooling culture
- "zero-cost" surface abstractions backed by precise lowering

[D] Rust is not a good model for:

- lifetime/borrow complexity as a user-facing center
- dense punctuation-heavy signatures everywhere
- systems-programming ergonomics as the default audience
- macro power as a substitute for language-level semantic clarity

Igniter-Lang should take Rust's discipline, not Rust's cognitive burden.

---

## High-Value Ideas To Borrow

### 1. Enums / ADTs As First-Class Data Shapes

Rust:

```rust
enum List<T> {
    Nil,
    Cons { head: T, tail: Box<List<T>> },
}
```

Igniter-Lang pressure:

```text
variant List[T] {
  nil: Unit
  cons: ConsCell[T]
}
```

Why it matters:

- `Option[T]`, `Result[T,E]`, state machines, workflow states, and domain unions
  become explicit.
- Pattern matching becomes natural.
- Agents can inspect closed cases.

[R] Keep `variant` or equivalent. It is a strong general-purpose language
primitive.

### 2. Pattern Matching

Rust made `match` ordinary. Igniter-Lang should do the same for closed shapes:

```text
match result {
  ok value -> ...
  err e -> ...
}
```

But Igniter-Lang should keep pattern matching tied to fragment classification:

- CORE for finite closed variants and structural values
- ESCAPE only when matching depends on external runtime state
- OOF when cases are non-exhaustive in high-trust contexts

### 3. `Option` And `Result` As Normal Values

Rust's biggest ergonomic win is forcing absence and failure into types:

```rust
Option<T>
Result<T, E>
```

Igniter-Lang already has these. The Rust lesson is to make them pleasant, not
merely formal:

```text
decision.map(d -> d.plan)
read_user(id) ? else default_user
```

[R] Design Option/Result ergonomics early. Otherwise users will ask for nulls
and exceptions.

### 4. Traits As Capability Contracts

Rust traits are close to Igniter-Lang's capability/typeclass pressure:

```rust
fn sort<T: Ord>(xs: Vec<T>) -> Vec<T>
```

Igniter-Lang:

```text
contract Sort[T where Ordered[T]](xs: Array[T]) -> sorted: Array[T]
```

The useful lesson:

```text
trait bounds are readable contracts on generic code.
```

The warning:

```text
do not expose trait-resolution complexity too early.
```

### 5. Modules And Explicit Visibility

Rust's `mod`, `use`, `pub`, crate structure, and paths are a good reference for
solving the flat-plane problem.

Igniter-Lang likely needs:

```text
module SupplyWatch

namespace Domain { ... }
namespace Workflows { ... }

export contract MonitorSupply
```

or:

```text
entry MonitorSupply
```

[R] Borrow Rust's visible organization, but keep it simpler than crates/modules
until package boundaries need more power.

### 6. Tooling And Diagnostics Culture

Rust's language success is partly compiler UX:

- precise spans
- actionable errors
- suggestions
- formatting
- lints
- docs generated from source

Igniter-Lang should treat this as central, not optional:

```text
source -> ParsedProgram -> SemanticIR -> diagnostics -> explanation
```

Because Igniter-Lang is agent-facing, diagnostics are also machine-facing.

### 7. Familiar Surface, Precise Lowering

Rust gives familiar collection surfaces:

```rust
vec![1, 2, 3]
xs.push(4)
xs.sort()
```

Igniter-Lang should go further toward least surprise:

```text
let xs = [1, 2, 3]
let ys = xs.push(4).sort()
```

while lowering to contract-correct primitives:

```text
Array[Int].from(...)
Array[Int].push(...)
Array[Int].sort(...)
```

This directly supports the primitive surface / contract substrate principle.

---

## Ideas To Avoid Or Soften

### 1. Borrow Checker As User-Facing Center

Rust's ownership/borrow model is powerful but cognitively expensive.

Igniter-Lang should not copy it directly because the language's center is not
manual memory safety. Its center is:

```text
contracts + time + evidence + runtime compatibility
```

Possible adaptation:

```text
ownership in Igniter-Lang should mean data/workflow/agent/store ownership,
not memory ownership.
```

Examples:

- owner of a workflow cell
- owner of a store partition
- owner of a mesh task
- lease holder for a capability

This can learn from Rust's discipline while applying it to distributed/runtime
semantics.

### 2. Lifetime Syntax

Rust lifetimes are not a good surface model for Igniter-Lang users.

Igniter-Lang already has richer time:

```text
as_of
knowledge_as_of
valid_time
transaction_time
lifecycle
retention
```

[R] Use explicit temporal/lifecycle names, not symbolic lifetime notation.

### 3. Macro Culture

Rust macros are powerful, but Igniter-Lang should avoid making macros the route
to core expressiveness.

Reason:

```text
agent-readable source and stable ParsedProgram boundaries suffer when meaning
is hidden behind arbitrary expansion.
```

If macros exist later, they should be:

- hygienic
- typed
- expansion-visible
- diagnostics-preserving
- forbidden from hiding evidence/time/lifecycle claims

### 4. Error Handling Ceremony

Rust's `?` is elegant, but Igniter-Lang must preserve evidence and lifecycle.

Naive:

```text
read_supplier(id)?
```

Better:

```text
read supplier: Supplier from suppliers by id
  on_missing -> failure supplier_missing evidence [...]
```

or an explicit `Result` surface that keeps observations.

---

## Comparison Table

| Rust idea | Igniter-Lang adaptation | Take / avoid |
|-----------|-------------------------|--------------|
| `enum` | `variant` / closed data shape | Take |
| `match` | exhaustive match over variants/results | Take |
| `Option` / `Result` | absence/failure as typed values with evidence | Take |
| traits | capability/type contracts | Take, simplify |
| crates/modules | modules/namespaces/entry/export | Take, simplify |
| ownership | workflow/store/mesh ownership and leases | Adapt |
| borrow checker | memory aliasing discipline | Avoid as central UX |
| lifetimes | temporal/lifecycle semantics | Replace with explicit time |
| macros | typed expansion, maybe later | Avoid early |
| `Vec`, `HashMap` | `Array`, `Map`, familiar literals | Take as surface |
| compiler diagnostics | diagnostic-first design | Strongly take |
| `cargo fmt` | canonical formatter | Strongly take |
| `cargo test/doc` | proof/test/doc workflows | Take conceptually |

---

## Rust-Like Surface Sketch

The goal is not Rust syntax, but Rust-like clarity:

```text
module Examples.Sorting

entry SortScores

type Score {
  student: String
  value: Integer
}

impl Ordered[Score] {
  compare left, right -> compare(left.value, right.value)
}

contract SortScores(scores: Array[Score]) -> sorted: Array[Score] {
  let sorted = scores.sort()

  invariant sorted_output: is_sorted(sorted)
    severity :error

  output sorted = sorted
    evidence [scores]
}
```

This is closer to what humans expect:

- arrays look like arrays
- sort looks like sort
- proof stays visible
- evidence stays visible
- lowering can still be contract/SemanticIR-based

---

## Where Igniter-Lang Should Go Beyond Rust

Rust does not natively model:

- valid time / transaction time
- observations as trust units
- SemanticImage handoff
- CompatibilityReport resume gate
- evidence-linked outputs
- human review as typed workflow suspension
- mesh/agent trust and admission
- contract-level runtime compatibility

Igniter-Lang's differentiator is exactly this layer:

```text
typed computation + typed time + typed evidence + typed runtime handoff
```

So Rust is a mentor for rigor, not the destination.

---

## Recommendations

[R1] Borrow Rust's ADTs, match, traits, Option/Result ergonomics, module
discipline, formatter culture, and diagnostic quality.

[R2] Do not borrow Rust's lifetime/borrow UX as a central language experience.
Translate "ownership" into store/workflow/mesh ownership instead.

[R3] Make arrays/maps/sets ordinary at the surface, backed by contract-correct
stdlib primitives.

[R4] Add `entry` / `export` thinking before more large comprehension specimens.

[R5] Treat macros as a late feature, if ever. Stable ParsedProgram and
agent-readable source matter more.

[R6] Use Rust as a backend inspiration when real-time/certification/WCET pressure
arrives, but keep Ruby/reference semantics while language ideas are still moving.

---

## Handoff

[D] Rust is a strong comparison model for discipline, data shapes, traits,
modules, diagnostics, and tooling.

[S] Igniter-Lang should borrow Rust's rigor while preserving its own center:
contracts, evidence, time, runtime compatibility, and human-agent handoff.

[R] Next syntax specimen should test a Rust-inspired ordinary surface:
arrays/maps, `variant`, `match`, traits, `entry`, and evidence-bearing outputs.
