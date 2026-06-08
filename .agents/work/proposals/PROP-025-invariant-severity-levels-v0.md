# PROP-025: Invariant Severity Levels v0

Status: closed
Closed: 2026-05-07 (Stage 2 — experiment PASS, META-EXPERT-009.1)
Date: 2026-05-06
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: PROP-007 (conformance verification), PROP-022 (BiHistory for audit trail)
Stage: 2
Source: META-EXPERT-005 §4.8; META-EXPERT-006 §2.4; playgrounds/docs/experts/igniter-science-critical.md §6.2

---

## § 1. Motivation

PROP-004 and PROP-007 define invariants as binary: an invariant either holds
or it raises `InvariantViolation` (a compile-time error for static invariants,
a runtime failure for dynamic ones).

This is correct for `severity: :error`. But the cross-domain validation
(META-EXPERT-005 §5, science-critical.md) reveals that safety-critical,
regulated, and scientific domains all require **gradations**:

| Domain | Invariant type | Expected behaviour |
|--------|---------------|-------------------|
| Medicine | Contraindicated drug combination | Hard block (`:error`) |
| Medicine | Major interaction, unacknowledged | Warn + require acknowledgement (`:warn`) |
| Robotics | Safety constraint | Hard block (`:error`) |
| Robotics | Advisory margin | Log only (`:metric`) |
| Science | Confidence threshold | Tag output as uncertain (`:soft`) |
| Space | Housekeeping anomaly | Metric only (`:metric`) |

Without severity levels, one of two bad things happens:
1. Everything is `:error` → the system is unusable for advisory constraints
2. Everything is `:warn` (runtime log only) → safety constraints are not enforced

This PROP adds four severity levels to the invariant system.

---

## § 2. Four Severity Levels

### `:error` (default — preserves existing behaviour)

```
invariant "velocity <= MAX_VEL"
  severity: :error
  message:  "Velocity limit exceeded"
```

**Behaviour**: raises `InvariantViolation`. Execution stops. No output is
produced. This is the current (v0) invariant behaviour. Specifying
`severity: :error` or omitting `severity:` are equivalent.

**Use cases**: safety-critical constraints, contraindicated combinations,
dose limits, velocity limits, thermal limits.

### `:warn`

```
invariant "interactions.none? { |i| i.severity == :major && !i.acknowledged? }"
  severity: :warn
  label:    "CG-INTERACTION-02"
  message:  "Major drug interaction requires acknowledgement"
  overridable_with: :documented_justification
```

**Behaviour**: does NOT raise. Sets a `warning` flag on the contract output.
Logs to the ObsPacket as a `warning_observation`. Execution continues and
output is produced — but the output is tagged with `warnings: [...]`.

Callers must explicitly handle the warnings array. A CORE caller that
ignores warnings is OOF (OOF-I2).

**Use cases**: advisory constraints, major-but-overridable clinical rules,
non-critical sensor margin warnings.

### `:soft`

```
invariant "confidence >= 0.85"
  severity: :soft
  message:  "Confidence below threshold — output is approximate"
```

**Behaviour**: does NOT raise. Tags the output as `:uncertain` (connects to
the `~T` probabilistic type from PROP-004 errata). The output value is still
produced; its type is promoted from `T` to `~T` when the invariant is violated.

Callers must handle the `~T` uncertain case. A CORE caller that treats `~T`
as `T` without `@exact` or `@best_effort(fallback)` is OOF (OOF-I3).

**Use cases**: confidence thresholds, data quality gates, approximation validity.

### `:metric`

```
invariant "p95_latency < 500.milliseconds"
  severity: :metric
  label:    "PERF-01"
```

**Behaviour**: does NOT raise. Does NOT affect the output or its type.
Records a metric observation to the ObsPacket only. Execution continues
normally. The output is unaffected.

**Use cases**: performance monitoring, housekeeping anomaly detection,
SLA tracking. Invariants that should be visible to operators but must never
interrupt the computation.

---

## § 3. The `label:` Parameter

```
invariant "velocity <= MAX_VEL"
  severity: :error
  label:    "REQ-SAFE-01"
```

**Purpose**: connects an invariant to an external requirements ID.
Used for:
- Safety requirements traceability (DO-178C, ISO 26262, IEC 62443)
- Clinical guideline references (FDA, clinical decision support)
- Audit reports: "invariant REQ-SAFE-01 was satisfied" or "violated"

**Compiler behaviour**: labels appear in:
- `InvariantViolation` exception metadata
- ObsPacket `verification_observation` entries
- `CompilationReport` invariant coverage section

A contract whose label set matches a requirements database can generate
**100% requirement coverage evidence** automatically.

---

## § 4. The `overridable_with:` Parameter

```
invariant "interactions.none? { |i| i.severity == :major && !i.acknowledged? }"
  severity:         :warn
  label:            "CG-INTERACTION-02"
  overridable_with: :documented_justification
```

**Purpose**: allows a `:warn` invariant to be explicitly overridden by a
caller who provides a typed justification.

**Type**:
```
overridable_with: :documented_justification | :supervisor_approval | Symbol
```

**Behaviour**:
1. The contract raises a `InvariantWarning` with `overridable: true` and `requires: :documented_justification`
2. The caller can re-invoke the contract with `override: { invariant: "CG-INTERACTION-02", justification: "..." }`
3. The override is recorded in the `BiHistory` audit trail (requires `BiHistory` ESCAPE capability)
4. Without the override, the output carries the warning flag

**OOF rule**: `overridable_with:` on a `:error` severity invariant is OOF.
You cannot override a hard safety block.

```
OOF-I4: overridable_with: on severity: :error invariant
         → ":error invariants cannot be overridden — use :warn if override is intended"
```

---

## § 5. SemanticIR Shape

### § 5.1 Invariant node with severity

```json
{
  "kind": "invariant_node",
  "name": "velocity_limit",
  "predicate_ref": "velocity_limit_pred",
  "severity": "error",
  "label": "REQ-SAFE-01",
  "message": "Velocity limit exceeded",
  "overridable_with": null
}
```

```json
{
  "kind": "invariant_node",
  "name": "interaction_check",
  "predicate_ref": "interaction_pred",
  "severity": "warn",
  "label": "CG-INTERACTION-02",
  "message": "Major drug interaction requires acknowledgement",
  "overridable_with": "documented_justification"
}
```

```json
{
  "kind": "invariant_node",
  "name": "confidence_gate",
  "predicate_ref": "confidence_pred",
  "severity": "soft",
  "label": null,
  "message": "Confidence below threshold — output is approximate",
  "overridable_with": null
}
```

### § 5.2 Output effect of severity levels

The compiler propagates invariant severity to the contract output node:

```json
{
  "kind": "output_node",
  "name": "approved_dose",
  "type": "Decimal[2]",
  "warnings_from": ["interaction_check"],
  "uncertain_from": ["confidence_gate"],
  "metrics_from": ["latency_metric"]
}
```

Callers that do not handle `warnings_from` or `uncertain_from` → OOF.

---

## § 6. Runtime Execution Semantics

### Execution order

Invariant nodes are evaluated **after** their `depends_on` nodes resolve and
**before** the output nodes that depend on them.

The invariant check is not a separate pass — it is a node in the dependency
graph, with the predicate as its computation and severity as its output policy.

### Severity dispatch table

| Severity | Predicate false | Output type | ObsPacket entry |
|----------|-----------------|-------------|-----------------|
| `:error`  | raise InvariantViolation | — (no output) | failure_observation |
| `:warn`   | set warnings flag | T (with warnings: [...]) | warning_observation |
| `:soft`   | set uncertain flag | ~T (uncertain promoted) | soft_observation |
| `:metric` | record metric | T (unaffected) | metric_observation |

---

## § 7. OOF Rules

```
OOF-I1: overridable_with: without @bitemporal audit store in the contract
         → "overridable_with requires a BiHistory audit store to record the override"

OOF-I2: caller ignores warnings_from field on a :warn invariant output
         → "output has :warn invariants; caller must handle warnings array"
         (only checked if static analysis can detect it — advisory in v0)

OOF-I3: caller treats ~T output as T without @exact or @best_effort
         → ":soft invariant promoted output to ~T; caller must handle uncertainty"

OOF-I4: overridable_with: on severity: :error invariant
         → ":error invariants cannot be overridden"

OOF-I5: label: on invariant with no requirements database reference
         → advisory warning: "label 'REQ-SAFE-01' not found in requirements database"
         (only if a requirements database is configured — ignored otherwise)
```

---

## § 8. Examples

### Robotics — safety requirements as invariants

```
contract NavigationStep
  deadline: 10.milliseconds
{
  in sensor_fusion: SensorState
  in mission_plan:  MissionPlan
  in robot_state:   RobotState

  compute obstacle_map   = ObstacleMapper { sensor: sensor_fusion }
  compute path_candidate = PathPlanner { obstacles: obstacle_map, plan: mission_plan, state: robot_state }
  compute velocity_cmd   = VelocityController { path: path_candidate, state: robot_state }

  -- Safety invariants with ISO 26262 traceability
  invariant "sensor_fusion.staleness < 100.milliseconds"
    severity: :error
    label:    "REQ-SENSE-01"
    message:  "Sensor data stale"

  invariant "velocity_cmd.linear.abs <= MAX_LINEAR_VEL"
    severity: :error
    label:    "REQ-SAFE-01"
    message:  "Linear velocity limit exceeded"

  invariant "velocity_cmd.angular.abs <= MAX_ANGULAR_VEL"
    severity: :error
    label:    "REQ-SAFE-02"
    message:  "Angular velocity limit exceeded"

  -- Advisory constraint — logged but does not block
  invariant "path_candidate.clearance >= PREFERRED_MARGIN"
    severity: :metric
    label:    "REQ-QUAL-01"
    message:  "Below preferred clearance margin"

  out command: VelocityCommand = velocity_cmd
}
```

### Medicine — clinical decision support

```
contract MedicationDosing {
  in patient_id: String
  in order:      MedicationOrder
  in as_of:      DateTime = now()

  -- ... compute nodes ...

  -- Hard block: contraindicated
  invariant "interactions.none? { |i| i.severity == :contraindicated }"
    severity: :error
    label:    "CG-INTERACTION-01"
    message:  "Contraindicated drug combination — order blocked"

  -- Soft block: major interaction, overridable with justification
  invariant "interactions.none? { |i| i.severity == :major && !i.acknowledged? }"
    severity: :warn
    label:    "CG-INTERACTION-02"
    message:  "Major drug interaction requires acknowledgement"
    overridable_with: :documented_justification

  -- Confidence gate: dose calculation
  invariant "renal_function.confidence >= 0.85"
    severity: :soft
    label:    "CG-RENAL-CONF-01"
    message:  "Low confidence renal function — dose is approximate"

  -- Metric: response time tracking
  invariant "computation_time < 500.milliseconds"
    severity: :metric
    label:    "PERF-DOSE-01"

  out approved_dose: Decimal[2] = adjusted_dose
  out warnings: Collection[InteractionWarning] = interactions
}
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: PROP-025-invariant-severity-levels-v0
Status: proposal

[D] Decisions:
- Four severity levels: :error (default, existing), :warn, :soft, :metric.
- :error: raise InvariantViolation (preserves existing behaviour exactly).
- :warn: continue, tag output with warnings, log to ObsPacket.
- :soft: continue, promote output type T -> ~T (uncertain), log to ObsPacket.
- :metric: continue, output unaffected, metric_observation to ObsPacket only.
- label: connects invariant to external requirements ID (traceability).
- overridable_with: allows :warn invariants to be bypassed with typed justification.
- overridable_with: on :error invariant is OOF-I4.
- Invariant nodes are graph nodes; severity dispatch is part of the dependency graph evaluation.
- SemanticIR: severity field on invariant_node; warnings_from/uncertain_from on output_node.
- Stage 2: no Stage 1 pipeline impact (severity field is additive to invariant_node).

[R] Recommendations:
- When PROP-026 (~T probabilistic types) is written, cross-reference § 2 (:soft severity → ~T)
- Requirements database integration (OOF-I5) deferred to Stage 3
- overridable_with: BiHistory requirement deferred until BiHistory implementation is stable

[X] Rejected:
- overridable_with: on :error invariants
- Automatic override without explicit caller action
- Severity levels affecting the compilation pipeline (severity is runtime-only dispatch)
- :info as a fifth severity level (metric covers this; :info would be redundant)
```
