# Axiomatic Contract Model

Status: meta thesis
Date: 2026-05-05
Owner: `[Architect Supervisor / Codex]`

## Claim

[D] Igniter-Lang should treat the language, runtime, distributed execution,
and time as contract-addressable semantic boundaries.

This does not mean every implementation detail is literally a user contract.
It means every layer that can change the meaning of a result must expose a
contract boundary: typed promise, constraints, temporal context, observations,
failures, policy, and receipts.

```text
Contract
  = typed observable promise

Language
  = contract over valid contracts

Runtime
  = contract over execution of contracts

Distributed runtime
  = composition of runtime contracts

Time
  = contract dimension that indexes meaning and change

Projection / Slice
  = named observation of contract meaning at a temporal horizon
```

## Fractal Contract Stack

The model is intentionally fractal: the same contract lens applies at different
semantic levels without flattening those levels into one object model.

```text
LanguageContract
  defines valid meaning:
  types, composition, time, observation, failure, effects

RuntimeContract
  promises execution semantics:
  scheduler, clock, cache, storage, isolation, capabilities

UserContract
  defines business semantics:
  inputs -> outputs | projections | effects | observations

Execution
  = compose(LanguageContract, RuntimeContract, UserContract, TemporalCtx)
```

A user contract is not meaningful alone. It is meaningful under a language
contract, executed by a runtime contract, at an explicit temporal context.

## Runtime As Contract

[D] A runtime is not just "where code runs." It is a contract that promises how
contract evaluation behaves.

Runtime contract surfaces may include:

- supported language fragment: CORE / ESCAPE capabilities
- scheduling and concurrency guarantees
- clock and temporal source guarantees
- storage consistency and replay support
- cache and invalidation policy
- effect boundary and capability executor
- observation envelope support
- failure and diagnostic guarantees

If a runtime cannot expose one of these surfaces, the missing surface should be
observable as a limitation, not hidden as platform noise.

## Multiple Runtimes

[D] Multiple parallel runtimes are a composition of runtime contracts.

```text
RuntimeA + RuntimeB + RuntimeC
  -> RuntimeCompositionContract
```

The composition contract must make visible:

- which runtime evaluated which contract
- which temporal horizon each runtime used
- how observations are synchronized or deduplicated
- which capability boundary allowed each effect
- whether the resulting projection is reproducible, live, stale, or provisional

This keeps distributed execution from becoming an implicit side-channel.

## Time As Contract Dimension

[D] Time is not only a value and not only a packet field. Time is a language
dimension that indexes contract meaning.

Time answers:

- which facts were visible
- which contract/rule version was used
- which runtime guarantees were active
- which projection horizon was observed
- whether a value is reproducible or live
- why two correct results differ

```text
eval(G, Tt, inputs) -> outputs | observations | failures
```

`Tt` is part of the contract meaning. A contract evaluated at two different
temporal horizons may produce two different correct results.

## Change Over Time

[D] Change is a projection of contracts through time.

Not only data changes. These can all change:

- user contracts
- language rules
- type rules
- runtime guarantees
- capability policies
- observation envelope versions
- axiom/platform versions

Therefore "history" is not just fact history. Igniter-Lang should be able to
observe contract evolution, runtime evolution, and projection evolution.

## Relationship To Current Work

This thesis anchors the current research stack:

- `PROP-001` gives `eval(G, Tt, inputs)`.
- `PROP-002` gives contract composition.
- `PROP-003` classifies valid language fragments.
- `PROP-004` makes temporal capabilities and `Projection[T, horizon]` typed.
- `PROP-005` makes observations a typed envelope across language/platform.
- `temporal-contracts-and-projections-v0` makes named slices actionable.

## Guardrails

[X] Do not collapse the language into the runtime.

[X] Do not treat runtime behavior as ambient platform magic when it affects
semantic meaning.

[X] Do not make distributed execution invisible.

[X] Do not reduce time to `observed_at`.

[X] Do not turn this thesis into a requirement that every host implementation
detail becomes a user-facing contract. Only semantic boundaries matter.

## Next Research Pressure

[R] Research Agent should investigate runtime contracts as product semantics:
what a human or agent can rely on when a projection says it was produced by a
specific runtime under a specific temporal horizon.

[R] Compiler/Grammar Expert should investigate axiom-layer type signatures:
which built-ins are language contracts, which are runtime contracts, and which
host details must remain platform observations.
