# PROP-030A: TEMPORAL Scope Exclusion Refusal Errata v0

Status: proposal
Date: 2026-05-09
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Depends on: PROP-028, PROP-030,
  `docs/gates/runtime-temporal-executor-gate3-request-v0.md`
Stage: 3

Errata to: `PROP-030-executor-approval-token-contract-v0.md`

---

## 1. Purpose

The restricted Gate 3 request defines a `TemporalExecutor` scope:

```text
History[T] valid_time read only
```

The request also requires refusals for artifacts that reach the TEMPORAL
executor but are outside that scope:

- AT-7: no live `BiHistory[T]` evaluation;
- AT-12: CORE artifacts must not be evaluated by the TEMPORAL executor;
- request exclusions: STREAM, OLAP, production cache, Ledger writes/replay.

The request uses the phrase "gate-scope-exclusion refusal" but does not name a
canonical runtime reason code.

PROP-030A defines that code.

---

## 2. Canonical Refusal Code

[D] Canonical code:

```text
runtime.temporal_scope_exclusion
```

Meaning:

```text
The artifact reached a TEMPORAL executor path, but its fragment/surface/axis
is outside the currently approved Gate 3 temporal execution scope.
```

For the restricted Gate 3 request, the only approved temporal execution scope
is:

```text
History[T] + valid_time + history_read + read_as_of(as_of: DateTime)
```

Everything else that reaches the TEMPORAL executor must refuse before any
evaluation, cache lookup, TBackend call, Ledger call, or live adapter call.

---

## 3. What This Code Is Not

`runtime.temporal_scope_exclusion` is not:

- parser OOF;
- typechecker OOF;
- approval-token validation failure;
- Gate 3 closed failure;
- capability missing failure;
- cache schema mismatch;
- generic unsupported runtime error.

Use the more specific refusal when applicable:

| Situation | Canonical code |
| --- | --- |
| missing/invalid approval token | `runtime.executor_approval_*` |
| valid token but Gate 3 closed | `runtime.temporal_gate3_closed` |
| missing required temporal capability | `runtime.temporal_capability_missing` |
| CORE-shaped cache key for a TEMPORAL contract | `runtime.temporal_cache_schema_mismatch` |
| TEMPORAL execution unsupported before Gate 3 | `runtime.temporal_execution_unsupported` |
| artifact is outside the approved TEMPORAL executor scope | `runtime.temporal_scope_exclusion` |

Ordering:

```text
load validation
  -> CompatibilityReport evaluation_readiness
  -> approval token validation
  -> Gate 3 state check
  -> temporal scope check
  -> TEMPORAL cache-key schema check
  -> artifact guard
  -> executor/TBackend call
```

The scope check must happen before cache lookup or live TBackend access.

---

## 4. Reason-Code Matrix

For the restricted Gate 3 request:

| Incoming artifact/surface | Example | Refusal | Detail fields |
| --- | --- | --- | --- |
| CORE contract | `fragment_class: core` reaches `TemporalExecutor` | `runtime.temporal_scope_exclusion` | `expected_scope: history_valid_time`, `actual_fragment: core` |
| STREAM contract | `fragment_class: stream` or `stream_nodes` reaches `TemporalExecutor` | `runtime.temporal_scope_exclusion` | `expected_scope: history_valid_time`, `actual_fragment: stream` |
| OLAP temporal surface | `olap_access_node`, `olap_point_read`, multidimensional temporal view | `runtime.temporal_scope_exclusion` | `expected_scope: history_valid_time`, `actual_surface: olap` |
| BiHistory | `BiHistory[T]`, `bihistory_read`, `axis: bitemporal`, `vt/tt` | `runtime.temporal_scope_exclusion` | `expected_scope: history_valid_time`, `actual_axis: bitemporal` |
| Ledger write/replay surface | append/write/replay/compact capability reaches executor path | `runtime.temporal_scope_exclusion` | `expected_operation: temporal_evaluate`, `actual_operation: write|replay|compact` |
| Unknown temporal surface | `fragment_class: temporal` but no recognized History valid_time metadata | `runtime.temporal_scope_exclusion` | `expected_scope: history_valid_time`, `actual_surface: unknown` |

Required minimum diagnostic envelope:

```json
{
  "reason_code": "runtime.temporal_scope_exclusion",
  "expected_scope": "history_valid_time",
  "actual_fragment": "core|stream|temporal|unknown",
  "actual_surface": "core|stream|olap|bihistory|ledger_write|unknown",
  "actual_axis": "valid_time|bitemporal|multi_dimensional|unknown",
  "artifact_ref": "igapp/sha256:<artifact-hash>",
  "contract_ref": "contract/<name>/sha256:<contract-hash>"
}
```

Fields may be `null` when unavailable, but `reason_code`,
`expected_scope`, `artifact_ref`, and `contract_ref` should be present whenever
the runtime has loaded the artifact.

---

## 5. Alignment With Gate 3 Request

This errata crystallizes existing request language:

- AT-7 "gate-scope-exclusion refusal" for BiHistory becomes
  `runtime.temporal_scope_exclusion`.
- AT-12 "gate-scope-exclusion refusal" for CORE artifacts becomes
  `runtime.temporal_scope_exclusion`.
- Section III exclusions for STREAM, OLAP, production cache, and Ledger
  write/replay remain closed and use the same scope-exclusion code if they
  reach the TEMPORAL executor path.

The code does not expand Gate 3 scope.

The code does not authorize:

- BiHistory production evaluation;
- stream executor;
- OLAP executor;
- Ledger write/replay/compact;
- production cache;
- parser syntax changes;
- new SemanticIR node kinds.

---

## 6. Relationship To PROP-030

PROP-030 defines approval and Gate 3 refusal semantics. PROP-030A adds one
runtime refusal code for the case where approval/Gate checks are otherwise
well-formed, but the artifact is outside the approved temporal execution
scope.

Recommended insertion point in PROP-030 §6 runtime approval refusals:

```text
runtime.temporal_scope_exclusion
```

Recommended ordering note:

```text
Temporal scope exclusion must refuse before cache lookup, TBackend access,
Ledger access, or executor evaluation.
```

---

## 7. Spec-Lag Notes

[R] Ch7 Runtime should be synced only if Gate 3 is approved or if Phase 1
implementation starts under an approved gate decision.

Ch7 sync should add:

- `runtime.temporal_scope_exclusion` to TEMPORAL evaluate refusals;
- the restricted `history_valid_time` scope;
- the reason-code matrix for CORE/STREAM/OLAP/BiHistory/unknown scope;
- no-live-call invariant for scope exclusions;
- distinction from `runtime.temporal_cache_schema_mismatch`.

[R] Ch6 SemanticIR does not need an immediate sync. No new SemanticIR node kind
is introduced.

---

## 8. Acceptance Checklist

An implementation or proof-local fixture satisfies this errata when:

- CORE artifacts reaching `TemporalExecutor` refuse with
  `runtime.temporal_scope_exclusion`;
- STREAM artifacts reaching `TemporalExecutor` refuse with
  `runtime.temporal_scope_exclusion`;
- OLAP temporal artifacts reaching `TemporalExecutor` refuse with
  `runtime.temporal_scope_exclusion`;
- BiHistory artifacts reaching `TemporalExecutor` refuse with
  `runtime.temporal_scope_exclusion`;
- unknown temporal artifacts reaching `TemporalExecutor` refuse with
  `runtime.temporal_scope_exclusion`;
- no refusal case attempts cache, TBackend, Ledger, or executor evaluation.

---

## Handoff

```text
Card: S3-R13-C2-P
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: prop-030-temporal-scope-exclusion-errata-v0
Status: proposal written

[D] Decisions
- Canonical out-of-scope TEMPORAL executor refusal:
  runtime.temporal_scope_exclusion.
- Applies to CORE, STREAM, OLAP, BiHistory, Ledger write/replay surfaces, and
  unknown temporal surfaces that reach TemporalExecutor outside approved scope.
- Does not replace approval, Gate 3, capability, or cache-schema refusals.

[S] Signals
- Aligns PROP-030 with Gate 3 request AT-7 and AT-12.
- Keeps restricted Gate 3 scope at History[T] valid_time only.

[T] Tests / Proofs
- Proposal/errata only; no runtime implementation.

[R] Risks / Recommendations
- Ch7 should sync this refusal only after Gate 3 approval or Phase 1
  implementation authorization.

[Next] Suggested next slice
- proof-local temporal-scope-exclusion fixture, if Phase 1 implementation needs
  executable acceptance before production binding.
```
