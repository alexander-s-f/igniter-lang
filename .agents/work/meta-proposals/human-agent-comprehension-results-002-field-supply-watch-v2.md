# Human-Agent Comprehension Results 002: Field Supply Watch v2

Role: `[Igniter-Lang Archive/Form Expert]`
Track: `human-agent-comprehension-results-002-field-supply-watch-v2`
Status: research-results
Date: 2026-05-07

Related:
- [Human-Agent Comprehension Testing](human-agent-comprehension-testing-v0.md)
- [Comprehension Results 001](human-agent-comprehension-results-001-field-supply-watch-v0.md)
- [Syntax Density Research](syntax-density-human-agent-research-v0.md)
- `igniter-lang/experiments/human_agent_syntax_comprehension_fixture/field_supply_watch_v2.ig`

---

## Purpose

This document records a blind agent review of the revised
`field_supply_watch_v2.ig` syntax specimen.

It does not promote v2 syntax to canon. It extracts additional pressure signals
after applying the first round of comprehension fixes.

---

## Result Summary

| Review | Estimated score | Summary |
|--------|-----------------|---------|
| Agent Review 3 | 18/20 | Correctly recovered the full supply-watch workflow, audit profile, BiHistory model, mesh delegation, and human review semantics; surfaced remaining ambiguity around stream naming, magic thresholds, external helpers, and hash identity syntax. |

[D] The v2 specimen preserved the high comprehension score from v0 while
reducing several earlier ambiguities.

[D] The strongest new signal is not "the agent cannot read the program"; it can.
The signal is that verifiability requires named semantics for thresholds,
external functions, and receipt identity.

---

## V2 Improvements Confirmed

The review explicitly understood these revised forms:

- `profile audited_mesh` as an audit/ledger/causal/evidence mode.
- `BiHistory[InventorySnapshot]` with `valid_axis` and `transaction_axis`.
- `delegate route_options to SupplyAnalysisMesh capability :route_plan`.
- `admit peer.trust at_least :regional_operator`.
- `await_review ... when`.
- `metric regional_supply` as the operational analytics output.
- `evidence [...]` and `receipt DispatchDecisionReceipt` as first-class audit
  surfaces.

[S] `delegate`, `await_review`, `metric`, and explicit trust phrasing are better
human-agent surfaces than the v0 forms.

---

## New Pressure Signals

### P11: `fold_stream` Reads As Compiler-Technical

The reviewer understood `fold_stream`, but flagged the name as more technical
than intentional.

Pressure:

```text
stream accumulation should have a human-facing surface name.
```

Possible direction:

```text
accumulate report_ingress window rolling 6.hours seed [] into report_batch {
  step acc, report -> ...
}
```

or:

```text
collect_stream report_ingress window rolling 6.hours seed [] into report_batch
```

[R] Keep `fold_stream` as the precise SemanticIR/core primitive if useful, but
test a friendlier source alias.

### P12: Risk Thresholds Need Names

The numeric values were readable but semantically opaque:

```text
0.850, 0.180, 0.420, 0.760, 0.700
```

Pressure:

```text
important domain thresholds should be named declarations, not inline literals.
```

Candidate:

```text
threshold demand_contradiction_risk: Decimal[scale: 3] = 0.850
threshold review_required_risk: Decimal[scale: 3] = 0.700
```

or:

```text
const REVIEW_REQUIRED_RISK: RiskScore.value = 0.700
```

[S] Named thresholds improve both human explanation and agent reasoning.

### P13: External Helper Functions Need Visible Contracts

The reviewer correctly flagged helper calls as blind spots:

```text
count_matching_reports(...)
count_contradictions(...)
explain_demand_risk(...)
rank_suppliers(...)
choose_plan(...)
```

Pressure:

```text
an agent cannot reason about correctness when important domain functions are
used without source-level signatures, purity, effects, or evidence behavior.
```

Candidate:

```text
external pure count_matching_reports(
  reports: History[ReportReceived],
  clinic: ClinicRef,
  item: SupplyItem
) -> Integer
```

[R] Add a future syntax lane for `external`, `native`, `ffi`, and package bridge
signatures with explicit purity/effect/evidence annotations.

### P14: `content_hash(...)` Feels Like A Magic Function

The hash call inside a receipt was the only place where identity generation felt
less declarative than the rest of the file.

Pressure:

```text
receipt identity should be declared as receipt semantics, not hidden inside a
normal function call.
```

Candidate:

```text
receipt DispatchDecisionReceipt {
  id decision_id by content_hash(plan, posture, as_of)
  ...
}
```

or:

```text
decision_id: auto content_hash [plan, posture, as_of]
```

[S] Receipt identity is part of audit semantics and deserves a first-class
surface.

### P15: Readability Is Not Enough For Agent Correctness

The agent could describe the program accurately, but still could not verify:

- why the thresholds have these values
- what external helpers mean
- whether helper calls are pure
- whether hash identity is canonical

Pressure:

```text
human-agent syntax tests should score both comprehension and verifiability.
```

[R] Extend future evaluator guides with a second axis:

```text
Can the reviewer explain the program?
Can the reviewer identify what would be needed to verify it?
```

---

## Routing

| Pressure | Owning next role | Action |
|----------|------------------|--------|
| P11 stream alias | Compiler/Grammar Expert | Consider `accumulate`/`collect_stream` as source sugar over `fold_stream` |
| P12 thresholds | Compiler/Grammar Expert + Research Agent | Design named threshold/constant syntax and test in v3 specimen |
| P13 external signatures | Bridge Agent + Compiler/Grammar Expert | Align FFI/package bridge signatures with source-level contracts |
| P14 receipt identity | Compiler/Grammar Expert | Consider declarative receipt identity syntax |
| P15 verifiability axis | Archive/Form Expert | Update comprehension-test rubric before larger human testing |

---

## Handoff

[D] Field Supply Watch v2 review is recorded.

[S] v2 reduced ambiguity and preserved strong blind comprehension.

[T] The remaining issues are higher-order: named thresholds, external helper
contracts, stream surface friendliness, and receipt identity semantics.

[R] Create a v3 specimen only after deciding whether threshold/external syntax
should be tested together or separately.
