# PROP-037: External Progression and Service Liveness Semantics v0

Status: accepted proposal-only  [descriptor shape proof PASS; OOF-PR1..9 all closed (2026-06-07); progression_sources schema ownership: PROP-037 (closed 2026-06-07)]
Evidence: experiments/prop037_oof_pr6_pr8_proof/ — 38/38 PASS (2026-06-07)
Date: 2026-05-11
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Stage: 3
Authoring card: S3-R36-C4-P
Numbering authority: `docs/gates/progression-prop-number-assignment-decision-v0.md`
Depends on: PROP-023, Chapter 13 managed recursion draft
Source tracks:
- `docs/tracks/external-progression-semantics-decision-prep-v0.md`
- `docs/tracks/external-progression-prop-scope-draft-v0.md`
- `docs/tracks/progression-pack-shadow-boundary-v0.md`

---

## Queue And Authority Note

PROP-037 is assigned to External Progression and Service Liveness Semantics by
the Architect numbering decision `S3-R35-C4-A`.

That decision is numbering-only. This PROP authors the formal proposal text. It
does not accept the proposal, authorize parser syntax, TypeChecker changes,
SemanticIR changes, RuntimeMachine scheduling, durable queues, durable
checkpoints, Ledger/TBackend binding, ProgressionPack migration, production
execution, or a new `PROGRESSION` fragment class.

The hard boundary is:

```text
service loop is the surface;
progression is the semantic substrate.
```

---

## §1. Purpose

Igniter-Lang currently has a strong doctrine for bounded computation:

- CORE contracts are finite graph evaluations.
- `Stream[T]` is external data flow.
- `fold_stream` bridges ESCAPE stream windows back to CORE values only through
  explicit bounded windows.
- Chapter 13 proposes managed local loop classes with finite, structural,
  fuel-bounded, convergent, and service-loop shapes.

The missing boundary is long-lived service liveness. A service can be alive for
an unbounded duration without implying eager infinite body execution. It needs a
language-visible contract for event potential, bounded materialization,
cancellation, checkpoint/resume, backpressure, and receipts.

PROP-037 defines **Progression** as that semantic boundary:

```text
Progression =
  declared external/runtime event potential
  + bounded materialization
  + service step lifecycle
  + receipts/checkpoint/backpressure obligations
```

Progression is not a stream fold, not a local recursion class, and not a runtime
scheduler. It is the language contract a future scheduler must satisfy before
service liveness can be executed.

---

## §2. Terminology

| Term | Meaning |
| --- | --- |
| `Progression` | Named semantic entity describing runtime-managed event potential and bounded step materialization. |
| `ServiceLoop` | User-facing service liveness surface backed by progression obligations. |
| `ProgressionSource` | Descriptor for the external or runtime source that may materialize progression events. |
| `ProgressionEvent` | Bounded materialized event handed to one service step. |
| `ProgressionStepReceipt` | Receipt proving how one materialized event was handled. |
| `Materialization` | Runtime act of selecting a bounded batch/event from the progression source. |
| `Backpressure` | Structured state that prevents unbounded materialization when capacity or policy is exhausted. |
| `Checkpoint` | Resumption reference for service progressions that may suspend, resume, or run indefinitely. |

Progression is a **liveness and event lifecycle** concept. It is not a value type
like `Stream[T]`, and it is not a computation fragment class.

---

## §3. Relationship To Stream[T] And fold_stream

PROP-023 remains authoritative for streams:

```text
stream name: T        -> ESCAPE data source
window {...}          -> bounded materialization window
fold_stream(...)      -> bounded ESCAPE-to-CORE fold result
```

PROP-037 draws a separate line:

| Surface | Owns | Result |
| --- | --- | --- |
| `Stream[T]` | External data flow and windowed data ingress | ESCAPE handle requiring window discipline |
| `fold_stream` | Bounded fold over a materialized stream window | CORE value result |
| `Progression` | Event potential, service step lifecycle, receipts, cancellation, checkpoint, backpressure | Runtime capability and manifest metadata contract |

Allowed relationships:

- A progression source may consume a stream-like external event source.
- A progression step may evaluate bounded `fold_stream` logic if all stream OOF
  rules still hold.
- Progression may emit observations that later appear as stream data.

Forbidden conflations:

- A stream window is not a service scheduler.
- A `fold_stream` accumulator is not a service loop.
- A progression source is not a CORE value.
- Progression must not weaken OOF-S1..OOF-S5.

---

## §4. Relationship To Managed Local Loops

PROP-037 preserves the Chapter 13 managed local loop classes:

| Class | Status under PROP-037 |
| --- | --- |
| `FiniteLoop` | Unchanged. Local bounded repetition over finite collections. |
| `StructuralRecursion` | Unchanged. `recur()` must decrease a structural variant. |
| `FuelBoundedRecursion` | Unchanged. Static fuel remains required. |
| `ConvergentLoop` | Unchanged. Metric, threshold, and fuel remain required. |
| `ServiceLoop` | Reinterpreted as a progression-backed liveness surface. |

Service loops do not become eager repeated body execution. They lower
conceptually to:

```text
ProgressionSource
ProgressionMaterializationPolicy
ProgressionStepHandler
ProgressionReceiptPolicy
ServiceLivenessObligations
```

This preserves the no-hidden-infinite-loop doctrine while allowing service
liveness to be represented.

### §4.1 Service-Loop Source Binding Companion Wording

This companion wording reconciles Chapter 13 service-loop examples with
PROP-037 progression descriptors. It is design text only and does not authorize
parser, TypeChecker, SemanticIR, runtime, scheduler, or public runtime support.

A future service-loop source surface such as:

```igniter
loop TickLoop tick in clock.every(250.ms) {
  as_of = tick.time
  ...
}
```

maps conceptually to a `ProgressionSource` descriptor with:

```json
{
  "kind": "progression_source",
  "source_kind": "clock.every",
  "payload_type": "Tick",
  "liveness": {
    "max_step_latency": "..."
  }
}
```

`clock.every` is therefore a progression `source_kind` / service-liveness source
binding. It is not semantically equivalent to `Stream[DateTime]`, and it does
not weaken PROP-023 `fold_stream` / window OOF rules.

`tick.time` is explicit event-time binding from the materialized progression
event, corresponding to the event-time fields defined by this proposal such as
`scheduled_at` and/or `materialized_at` under the source policy. It is not
ambient time. Source-level `now()` remains prohibited and should be replaced by
an explicit TemporalCtx-style input or a materialized event-time binding.

Managed local loops, structural recursion, fuel-bounded recursion, and
`decreases fuel` remain Chapter 13 / PROP-039+ territory. They are not owned by
PROP-037 service-liveness semantics.

---

## §5. Initial Adoption Model: Capability And Manifest Metadata First

PROP-037 does not introduce a new `PROGRESSION` fragment class.

The initial compiler-visible shape is runtime capability and manifest metadata:

```json
{
  "progression_sources": [
    {
      "kind": "progression_source",
      "progression_ref": "progression/service/LiveNewsClarity",
      "source_kind": "clock.every",
      "source_ref": "clock/10s",
      "payload_type": "Tick",
      "required_caps": [
        "progression_materialize",
        "progression_step_execute",
        "progression_step_receipt",
        "progression_cancel",
        "progression_checkpoint_resume"
      ],
      "runtime_authority": "not_authorized"
    }
  ]
}
```

Rationale:

- fragment classes describe value/evaluation fragment behavior;
- progression describes service/event lifecycle obligations;
- capability and manifest metadata can make progression visible without
  changing the current fragment lattice;
- a future `PROGRESSION` fragment class requires a separate accepted proposal
  proving metadata is insufficient.

---

## §6. Source Descriptor Shape

The canonical v0 descriptor shape is:

```json
{
  "kind": "progression_source",
  "progression_ref": "progression/service/LiveNewsClarity",
  "source_kind": "clock.every",
  "source_ref": "clock/10s",
  "payload_type": "Tick",
  "materialization_policy": {
    "mode": "bounded_demand",
    "max_batch_size": 1,
    "backpressure": "block"
  },
  "handler_ref": "contract/HandleTick",
  "receipt_policy": {
    "required": true,
    "sink_ref": "receipt_sink/progression"
  },
  "liveness": {
    "cancellation": "required",
    "checkpoint": {
      "required": true,
      "every": "1m"
    },
    "max_step_latency": "2s"
  }
}
```

Required fields:

```text
kind
progression_ref
source_kind
source_ref
payload_type
materialization_policy
handler_ref
receipt_policy
liveness
```

### §6.1 Source Kind Vocabulary

The v0 `source_kind` vocabulary is closed:

```text
clock.every
queue
external_event
```

`external_event` is an extension point only below the `source_kind` level. A
profile or runtime descriptor may specialize `source_ref`, `payload_type`,
`authority_ref`, or capability metadata, for example:

```json
{
  "source_kind": "external_event",
  "source_ref": "http_listener/on_request",
  "payload_type": "HttpRequest"
}
```

New top-level `source_kind` values require a future PROP, errata, or accepted
profile extension. This prevents implementations from silently minting
source-kind semantics.

### §6.2 Materialization Policy

Materialization must be bounded. At minimum:

```json
{
  "mode": "bounded_demand",
  "max_batch_size": 1,
  "backpressure": "block"
}
```

Allowed `mode` values:

```text
bounded_demand
bounded_schedule
bounded_queue
```

Allowed `backpressure` values:

```text
block
drop
suspend
```

Unbounded eager materialization is not valid progression.

---

## §7. ProgressionEvent Shape

Minimum event shape:

```json
{
  "kind": "progression_event",
  "version": "progression-event-v1",
  "progression_ref": "progression/service/LiveNewsClarity",
  "source_kind": "clock.every",
  "source_ref": "clock/10s",
  "sequence": 42,
  "scheduled_at": "2026-05-11T12:00:00Z",
  "materialized_at": "2026-05-11T12:00:00Z",
  "payload": {},
  "event_id": "progression-event/sha256:<hash>"
}
```

Required fields:

```text
kind
version
progression_ref
source_kind
source_ref
sequence
payload
event_id
```

Time fields:

- `scheduled_at` is required for schedule-like sources such as `clock.every`.
- `materialized_at` is required for demand/event/queue sources.
- Both may be present.

`event_id` must be stable for the same event identity. This PROP does not define
durable storage or replay cursor implementation.

---

## §8. ProgressionStepReceipt Shape

Minimum step receipt shape:

```json
{
  "kind": "progression_step_receipt",
  "version": "progression-step-receipt-v1",
  "progression_ref": "progression/service/LiveNewsClarity",
  "event_id": "progression-event/sha256:<hash>",
  "sequence": 42,
  "scheduled_at": "2026-05-11T12:00:00Z",
  "materialized_at": "2026-05-11T12:00:00Z",
  "started_at": "2026-05-11T12:00:01Z",
  "finished_at": "2026-05-11T12:00:02Z",
  "outcome": "completed",
  "reason": "progression.step_completed",
  "artifact_hash": "sha256:<hash>",
  "checkpoint_ref": "checkpoint/sha256:<hash>"
}
```

Required fields:

```text
kind
version
progression_ref
event_id
sequence
started_at
finished_at
outcome
reason
artifact_hash or output_ref
```

Optional or policy-bound fields:

```text
scheduled_at
materialized_at
checkpoint_ref
error_ref
authority_ref
receipt_sink_ref
```

Outcome vocabulary:

```text
completed
failed
timeout
cancelled
skipped
suspended
blocked
```

Reason codes should be stable strings such as:

```text
progression.step_completed
progression.cancelled
progression.backpressure_blocked
progression.checkpoint_required
progression.step_timeout
progression.handler_failed
```

---

## §9. Cancellation, Checkpoint, And Backpressure Obligations

### §9.1 Cancellation

Every service progression must declare cancellation behavior:

```json
{
  "cancellation": "required"
}
```

The semantic obligation is:

```text
The service can stop accepting new materialized events and can finish or refuse
the current step with a ProgressionStepReceipt.
```

This PROP does not implement cancellation signaling or scheduler interruption.

### §9.2 Checkpoint

Checkpoint policy is required for resumable or infinite progressions.

Minimum shape:

```json
{
  "checkpoint": {
    "required": true,
    "every": "1m",
    "resume": "from_checkpoint"
  }
}
```

The semantic obligation is:

```text
A suspended or restarted progression must have an explicit resume boundary.
```

This PROP does not authorize durable checkpoint storage.

### §9.3 Backpressure

Backpressure is a structured materialization state, not a hidden runtime detail.

Minimum materialization states:

```text
materialized
blocked
cancelled
suspended
```

Required blocked reasons:

```text
progression.backpressure_queue_capacity
progression.backpressure_policy_block
progression.runtime_execution_not_authorized
```

Backpressure prevents unbounded materialization. It does not guarantee
production queue behavior in this PROP.

### §9.4 Bounded Step Policy

Service progressions must declare a bounded-step policy such as:

```json
{
  "max_step_latency": "2s"
}
```

For service or infinite progressions, missing bounded-step policy is an error.

---

## §10. OOF-PR Categories

Initial OOF/refusal categories:

| Code | Condition | Severity |
| --- | --- | --- |
| `OOF-PR1` | Progression-like service has no explicit source descriptor | error |
| `OOF-PR2` | Progression source implies unbounded eager execution | error |
| `OOF-PR3` | Service progression lacks cancellation obligation | error |
| `OOF-PR4` | Infinite/resumable progression lacks checkpoint policy | error |
| `OOF-PR5` | Service/infinite progression has no bounded-step policy such as `max_step_latency` | error |
| `OOF-PR6` | Progression handler hides external/effectful work inside CORE/pure step | error |
| `OOF-PR7` | Progression emits no step receipt policy | error |
| `OOF-PR8` | Nested progression declared inside pure contract or pure compute | error |
| `OOF-PR9` | Progression claims unsupported source kind or missing runtime capability | error |

`OOF-PR5` is an error in v0 for service/infinite progressions. A future bounded
experiment profile may downgrade analogous local proof warnings, but that is not
part of this PROP.

---

## §11. CompatibilityReport And Runtime Readiness

Metadata presence must not imply execution readiness.

Future CompatibilityReports may include:

```json
{
  "progression_profile_status": "present",
  "progression_runtime_readiness": {
    "ready": false,
    "reason": "progression.runtime_execution_not_authorized"
  }
}
```

Allowed `progression_profile_status` values:

```text
present
absent
unsupported
mismatch
```

Runtime readiness remains false until a separate runtime/scheduler authority is
accepted and implemented.

---

## §12. Future SemanticIR Candidate Shape

This section is descriptive only. It does not authorize SemanticIR implementation.

Candidate future nodes:

```text
progression_source_node
progression_materialization_policy_node
progression_step_handler_node
progression_receipt_policy_node
progression_liveness_obligation_node
```

Candidate future contract artifact sections:

```text
progression_sources
progression_receipt_policy
progression_liveness
```

These must remain future work until an implementation card is explicitly
authorized.

---

## §13. ProgressionPack Position

If the future profile-assembled compiler adopts this proposal,
`ProgressionPack` is the natural capability owner.

Initial capability ownership target:

```text
progression_source
bounded_materialization
progression_step_receipt
progression_checkpoint_resume
progression_backpressure
progression_cancellation
```

`ProgressionPack` remains proposed/shadow-only. This PROP does not migrate
compiler dispatch, pack registries, `.igapp`, `.ilk`, or production compiler
profiles.

---

## §14. Non-Authorization

This PROP does not authorize:

- parser syntax;
- TypeChecker implementation;
- SemanticIR implementation;
- assembler or `.igapp` changes;
- RuntimeMachine scheduler;
- live service execution;
- Ledger / TBackend binding;
- durable queues;
- durable checkpoints;
- receipt sink implementation;
- production cache;
- production execution;
- ProgressionPack migration or compiler dispatch changes;
- a new `PROGRESSION` fragment class.

---

## §15. Acceptance Criteria

The proposal is reviewable when:

1. It defines progression separately from `Stream[T]`, `fold_stream`, and local
   managed loops.
2. It states that service loops are progression-backed liveness surfaces.
3. It preserves finite, structural, fuel-bounded, and convergent loop classes.
4. It requires bounded materialization and forbids hidden eager infinite
   execution.
5. It defines minimum `ProgressionEvent` and `ProgressionStepReceipt` shapes.
6. It defines cancellation, checkpoint/resume, and backpressure obligations.
7. It separates language obligations from runtime scheduler implementation.
8. It names initial `OOF-PR*` categories.
9. It declares no parser, SemanticIR, RuntimeMachine, Ledger/TBackend,
   durable-queue, ProgressionPack migration, production execution, or fragment
   class authority.
10. It defines `external_event` as a closed v0 source kind that provides an
    extension point through descriptor/profile metadata, not arbitrary new
    `source_kind` values.

---

## §16. Implementation Blockers

Implementation remains blocked until separate authority exists for each layer:

| Layer | Blocker |
| --- | --- |
| Parser | Accepted syntax proposal and parser implementation card. |
| Classifier/TypeChecker | Accepted OOF-PR ownership and typed descriptor proof plan. |
| SemanticIR | Accepted node/artifact shape and golden fixture plan. |
| Assembler/.igapp | Manifest and requirements schema authorization. |
| RuntimeMachine | Scheduler/materializer authority and proof-local implementation plan. |
| Durability | Durable queue/checkpoint/receipt sink design and authorization. |
| Ledger/TBackend | Separate binding decision; not implied by progression. |
| Production execution | Explicit runtime gate; metadata alone is insufficient. |
| ProgressionPack | Compiler profile/pack migration authorization. |

---

## §17. Future Proof Plan

Future proof slices should be split:

1. Descriptor-only parser/classifier fixture for `clock.every`, `queue`, and
   `external_event`.
2. TypeChecker proof for source kind, payload type, handler signature, and
   liveness obligations.
3. SemanticIR proof for descriptor nodes, without runtime execution.
4. CompatibilityReport proof where metadata is present but runtime readiness is
   false.
5. Proof-local materialization model for cancellation, checkpoint, and
   backpressure, still without production scheduling.

Each slice must preserve PROP-023 stream boundaries and Chapter 13 local loop
classes.
