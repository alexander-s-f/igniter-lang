# Human-Agent Comprehension Results 001: Field Supply Watch v0

Role: `[Igniter-Lang Archive/Form Expert]`
Track: `human-agent-comprehension-results-001-field-supply-watch-v0`
Status: research-results
Date: 2026-05-07

Related:
- [Human-Agent Comprehension Testing](human-agent-comprehension-testing-v0.md)
- [Syntax Density Research](syntax-density-human-agent-research-v0.md)
- `igniter-lang/experiments/human_agent_syntax_comprehension_fixture/field_supply_watch.ig`

---

## Purpose

This document records the first two blind agent reviews of the hypothetical
`field_supply_watch.ig` syntax specimen.

It does not promote any syntax to canon. It extracts pressure signals for future
syntax design.

---

## Result Summary

| Review | Estimated score | Summary |
|--------|-----------------|---------|
| Agent Review 1 | 17/20 | Correctly understood overall workflow, evidence, temporal data, mesh delegation, human override; surfaced `compute` visual noise and some over-reading of `agent`/crypto evidence. |
| Agent Review 2 | 19/20 | Very strong comprehension; identified the main domain, data roles, temporal forms, audit flow, and most high-value ambiguities. |

[D] The specimen succeeded at the main test: an agent without external context
could recover the program's purpose, major structures, temporal model, evidence
model, human review point, and mesh delegation.

[D] The specimen also succeeded as a pressure test: both reviews surfaced syntax
tradeoffs that are not obvious from author-side design alone.

---

## What Reads Well

Across the first two reviews, these constructs communicated well:

- `type`, `packet`, `event`, `view`, `receipt` as distinct data roles.
- `store` vs `stream` vs `olap_point` as different data surfaces.
- `History[T]`, `BiHistory[T]`, explicit `as_of`, and `knowledge_as_of`.
- `range a .. b`, `at { vt, tt }`, and `window rolling 6.hours`.
- `invariant`, `severity`, and `overridable_with`.
- `evidence [...]` near outputs.
- `lifecycle :audit` / `:durable`.
- Top-level orchestration contract `MonitorSupply`.

[S] Data-shape profiles are a strong signal. Reviewers inferred useful
semantics from `packet`, `event`, `view`, and `receipt` without a language guide.

[S] Explicit time and evidence did not prevent comprehension. They added
readability because they explained why the program is trustworthy.

---

## Pressure Signals

### P1: `agent mesh` Over-Associates With AI

Review 1 interpreted `agent mesh` as "neural network or autonomous AI".

Pressure:

```text
agent / mesh / peer / model / tool vocabulary should be separated.
```

Possible direction:

```text
mesh SupplyAnalysisMesh {
  peer_capability :route_plan
}
```

or:

```text
delegate ... to SupplyAnalysisMesh capability :route_plan
```

### P2: `evidence` Was Partly Read As Cryptographic Proof

Review 1 treated evidence as "cryptographic or logical proof".

Pressure:

```text
evidence, receipt, hash, signature, and verification evidence need distinct
terms.
```

Possible direction:

```text
evidence [profile, alerts]
receipt DispatchDecisionReceipt
content_hash(...)
signature ...
```

Do not let `evidence` imply crypto unless a `signature`/`hash`/`VerificationReport`
surface is present.

### P3: `ObsId` And `obs_refs(...)` Hide Provenance Identity

Review 2 flagged `ObsId` as undeclared and `obs_refs(...)` as implicit magic.

Pressure:

```text
provenance identity must have an explicit source-level name.
```

Possible direction:

```text
type EvidenceRef
caused_by evidence_refs(posture, offers, route_options)
```

or a receipt builder:

```text
receipt caused_by [posture, offers, route_options]
```

### P4: Mesh Delegation Syntax Is Ambiguous

Review 2 flagged:

```text
mesh SupplyAnalysisMesh route_plan { ... } -> route_options
```

as unclear: is `route_plan` a capability, method, positional argument, or route?

Pressure:

```text
delegation syntax needs named slots.
```

Candidate:

```text
delegate route_options to SupplyAnalysisMesh capability :route_plan {
  input posture
  input candidate_suppliers
}
```

### P5: Trust Semantics Need A Lattice Or Explicit Quantifier

Review 2 flagged both:

```text
trust required [:verified_peer, :regional_operator]
trust_tier >= :regional_operator
```

Pressure:

```text
trust all/any/at_least must be explicit; Symbol ordering must not be hidden.
```

Candidate:

```text
trust all [:verified_peer, :regional_operator]
admit peer.trust at_least :regional_operator
```

### P6: `fold_stream` Needs Explicit Seed

Review 2 correctly asked what the accumulator starts with.

Candidate:

```text
fold_stream report_ingress window rolling 6.hours
  seed []
  into report_batch {
    step acc, report -> ...
  }
```

### P7: `human_review` Needs Sync/Async Semantics

Review 2 asked whether review blocks or suspends.

Pressure:

```text
review is lifecycle semantics, not UI syntax.
```

Candidate:

```text
await_review dispatch_override when ...
```

This says the contract may suspend/resume.

### P8: `view` Materialization Is Unclear

Review 2 understood the data shape but asked whether `view` is merely a schema
or a materialized projection.

Pressure:

```text
type shape and materialized view should be separated.
```

Candidate:

```text
type RegionalSupplyPosture { ... }

view regional_supply_posture: RegionalSupplyPosture {
  from BuildRegionalPosture
  lifecycle :audit
}
```

### P9: `olap_point` Name Is Precise But Not Friendly

Review 2 found `olap_point` less intuitive than "cube" or "metric", though the
body clarified it.

Pressure:

```text
surface syntax may use `metric` while SemanticIR remains OLAPPoint.
```

Candidate:

```text
metric regional_supply: Integer { dims ... }
```

### P10: `compute` Is Honest But Visually Heavy

Review 1 flagged repeated `compute` as noise.

Pressure:

```text
canonical block syntax may keep compute; dense syntax may allow local bindings.
```

Candidate:

```text
let demand_units = ...
let risk = RiskScore { ... }
```

Do not remove node identity accidentally. If `let` lowers to a compute node,
diagnostics must preserve that.

---

## V2 Specimen Changes

A second hypothetical specimen was created:

```text
igniter-lang/experiments/human_agent_syntax_comprehension_fixture/field_supply_watch_v2.ig
```

It tests these changes:

- `view RegionalSupplyPosture` becomes `type RegionalSupplyPosture` plus explicit
  `view regional_supply_posture`.
- `ObsId` becomes `EvidenceRef`.
- `obs_refs(...)` becomes `evidence_refs(...)`.
- `agent mesh` becomes `mesh`.
- `trust required [...]` becomes `trust all [...]`.
- `mesh SupplyAnalysisMesh route_plan` becomes `delegate ... to ... capability`.
- `trust_tier >= :regional_operator` becomes `peer.trust at_least :regional_operator`.
- `human_review` becomes `await_review`.
- `fold_stream` gains `seed []`.
- `olap_point` becomes `metric`.
- `Decimal[2]` becomes `Decimal[scale: 2]`.

[R] Use v2 for the next blind test batch and compare whether the same
ambiguities recur.

---

## Routing

| Pressure | Owning next role | Action |
|----------|------------------|--------|
| P3 evidence identity | Compiler/Grammar Expert | Decide whether evidence refs are first-class source constructs |
| P4/P5 mesh/trust syntax | Bridge Agent + Compiler/Grammar Expert | Align mesh package vocabulary with distributed source surface |
| P6 stream seed | Compiler/Grammar Expert | Consider explicit seed in future stream syntax |
| P7 review lifecycle | Research Agent | Treat review as await/suspend/resume proof pressure |
| P8 view materialization | Compiler/Grammar Expert | Separate structural type from materialized view declaration |
| P10 compute density | Archive/Form Expert | Include in SIR/density benchmark |

---

## Handoff

[D] First two blind agent reviews are recorded as comprehension results.

[S] Field Supply Watch v0 is broadly understandable without context.

[S] The strongest pressure points are provenance identity, mesh/trust syntax,
stream seed, review lifecycle, view materialization, and compute visual density.

[R] Run v2 against fresh reviewers; do not explain that it is a revised version.
