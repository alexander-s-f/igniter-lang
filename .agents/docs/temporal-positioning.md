# Temporal Positioning

Status: meta thesis
Date: 2026-05-05
Owner: `[Architect Supervisor / Codex]`

## Claim

[D] Time should be a fundamental language dimension in Igniter-Lang, not an
adapter concern and not a hidden runtime clock.

Igniter-Lang's emerging center is:

```text
contract + explicit time + projection/slice = reproducible meaning
```

Contracts describe what can be known or promised. Time says from which
semantic horizon it is known. Projections and slices turn that horizon into a
usable view for humans, agents, compilers, and runtimes.

## Why Time Is Core

Without first-class time, a contract can say what it computes, but not:

- when the input world was observed
- which rule version produced the result
- which facts were visible
- whether a result is replayed, current, stale, provisional, or historical
- why two correct results differ
- which projection is safe for a user or agent to act on

With first-class time, a result becomes reproducible:

```text
eval(G, Tt, inputs) -> outputs | failures
```

`Tt` is not metadata after the fact. It is part of the meaning.

## Temporal Vocabulary

Terms agents should treat as language-level candidates:

- `as_of`: semantic read point
- `valid_time`: when a fact is true in the modeled world
- `transaction_time`: when a system accepted the fact
- `rule_version`: which rules shaped the result
- `replay_cursor`: historical/replay horizon
- `causal_clock`: causal consistency boundary
- `projection_horizon`: which facts/rules a projection includes
- `slice`: a named cut through contract/time/facts
- `lifecycle_stage`: temporal state in an app-owned command/process

## Positioning Against Nearby Systems

### General-Purpose Languages

Ruby, Python, JavaScript, Swift, and similar languages treat time mostly as a
library/runtime concern. They can build temporal systems, but time is not part
of ordinary program meaning.

Igniter-Lang's vector: make temporal context visible at the contract boundary.

### SQL / Temporal Databases

SQL and temporal databases can query historical data and bitemporal tables.
They are strong for storage/query, weaker as a general contract/explanation
language across agents, effects, materializers, and failures.

Igniter-Lang's vector: time applies to contracts, projections, failures,
effects, receipts, and agents, not only tables.

### Event Sourcing / CQRS

Event sourcing preserves history and builds projections. It is close to our
direction, but usually lives as an architecture pattern rather than a language
semantics.

Igniter-Lang's vector: make event history, projection horizon, and command
lifecycle observable language concepts.

### Datalog / Dedalus / Logic Languages

Datalog gives declarative relations and decidable fragments. Dedalus adds time
to logic in a deep way. This is one of our strongest theoretical neighbors.

Igniter-Lang's vector: borrow the discipline of finite, stratified, temporal
logic, but add contract boundaries, observation packets, failures, effects,
materializers, and agent participation as first-class product semantics.

### FRP / Reactive Systems / Spreadsheets / MobX

Reactive systems make derived values update from dependencies. They are strong
for live views, but often weak on historical replay, provenance, explicit
temporal context, and durable observation receipts.

Igniter-Lang's vector: reactive projection with replayable, explainable,
time-indexed meaning.

### Workflow / Saga Languages

Workflow systems model long-running processes and retries. They are useful,
but often operational-first.

Igniter-Lang's vector: keep workflow-like movement as projections over
contracts, facts, lifecycle stages, and time before introducing workflow loops
as a named escape.

### Agent Frameworks

Agent frameworks orchestrate tools and prompts, but often treat evidence,
time, capability, and receipts as app conventions.

Igniter-Lang's vector: agent actions are contract participants with temporal
evidence, policy boundaries, projections, and receipts.

## Unique Vector

Igniter-Lang should position itself as:

```text
a contract-native temporal observation language
for explainable, replayable, agent-friendly systems
```

Not just:

- a DSL over Ruby
- a database query language
- an event-sourcing framework
- a workflow engine
- an agent orchestration format
- a theorem prover

The unique combination is:

```text
typed contracts
+ explicit temporal context
+ durable facts/histories
+ projections/slices
+ first-class observations/failures/receipts
+ agent-readable boundaries
```

## Research Directives

[R] Research Agent should investigate `temporal-contracts-and-projections-v0`:

- What is a named slice?
- How does a projection declare its temporal horizon?
- How do command lifecycle and durable model projections map to language time?
- What makes a projection reproducible?
- Which temporal fields are core vs ESCAPE?

[R] Compiler/Grammar Expert should account for time in `PROP-004 Type System
v0`:

- Is `Tt` a parameter to every contract type?
- Do `Store[T]`, `History[T]`, and `BiHistory[T]` carry temporal capabilities?
- Can projections be typed by their horizon?
- Which temporal constructs stay CORE vs ESCAPE?

[R] Bridge work should wait until temporal vocabulary is stable enough to map
Ledger/Durable Model facts, histories, command lifecycle, and projections into
the observation envelope.

## Guardrails

[X] Do not collapse time into `observed_at`.

[X] Do not treat current wall-clock time as ambient language state.

[X] Do not make every temporal feature CORE. Causal clocks, bitemporal queries,
and streams may remain ESCAPE until the semantics are proven.

[X] Do not turn Igniter-Lang into a workflow engine before the projection/slice
model is clear.
