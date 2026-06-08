# Gate Decision: PROP-037 Progression Acceptance Review v0

Card: S3-R37-C3-A
Agent: `[Architect Supervisor / Codex]`
Role: architect-supervisor
Track: `prop037-progression-acceptance-review-v0`
Status: accepted-proposal-only
Date: 2026-05-12

---

## Decision

Accept **PROP-037: External Progression and Service Liveness Semantics v0** as
an accepted proposal.

This is proposal acceptance only. It does not authorize parser implementation,
TypeChecker implementation, SemanticIR implementation, RuntimeMachine scheduler,
Ledger/TBackend binding, durable queues/checkpoints, production execution, or a
new `PROGRESSION` fragment class.

---

## Evidence Read

- `docs/proposals/PROP-037-external-progression-service-liveness-v0.md`
- `docs/gates/progression-prop-number-assignment-decision-v0.md`
- `docs/tracks/prop037-external-progression-proposal-authoring-v0.md`
- `docs/discussions/r36-deployment-prop032-prop036-prop037-mundane-pressure-v0.md`
- `docs/tracks/stage3-round36-status-curation-v0.md`

---

## Accepted Proposal Shape

PROP-037 is accepted as the semantic proposal for:

- `Progression` as runtime-managed event potential plus bounded
  materialization;
- service liveness as a progression-backed surface;
- `ProgressionSource` descriptors;
- `ProgressionEvent` minimum shape;
- `ProgressionStepReceipt` minimum shape;
- cancellation, checkpoint/resume, backpressure, bounded-step obligations;
- capability and manifest metadata first;
- explicit separation from `Stream[T]`, `fold_stream`, and local managed loops.

The accepted boundary sentence remains:

```text
service loop is the surface;
progression is the semantic substrate.
```

---

## Required Answers

### Closed v0 `source_kind` vocabulary

Accepted.

The v0 top-level `source_kind` vocabulary is closed:

```text
clock.every
queue
external_event
```

New top-level `source_kind` values require a future accepted PROP, errata, or
accepted profile-extension decision. Implementations must not silently mint new
top-level source kinds.

### `external_event` extension point

Accepted.

`external_event` is the v0 extension point below the top-level `source_kind`
vocabulary. A profile or runtime descriptor may specialize:

- `source_ref`;
- `payload_type`;
- `authority_ref`;
- capability metadata;
- readiness/refusal metadata.

Example:

```json
{
  "source_kind": "external_event",
  "source_ref": "http_listener/on_request",
  "payload_type": "HttpRequest"
}
```

This does not authorize production HTTP listeners, schedulers, queues, or
RuntimeMachine execution.

### Profile-level specialization rule

Accepted with this governance boundary:

- Specializing an existing `external_event` through profile/runtime descriptor
  metadata does **not** require a new PROP when it stays under the accepted
  descriptor shape and does not claim production execution.
- Adding a new top-level `source_kind` requires a future PROP, errata, or
  accepted profile-extension decision.
- Turning a descriptor specialization into executable production behavior
  requires a separate runtime/production gate.

### OOF-PR5 severity

Accepted.

`OOF-PR5` is an error in v0 for service or infinite progression without bounded
step policy, such as `max_step_latency`.

A future bounded experiment profile may define softer local warnings only with
explicit authorization. The accepted default remains error.

---

## Authorized Next Design/Proof Boundaries

The following follow-up cards may be routed without reopening proposal
acceptance, provided they preserve all exclusions:

1. **Descriptor-shape proof**
   - proof-local descriptors for `clock.every`, `queue`, and `external_event`;
   - validate required fields, closed `source_kind`, bounded materialization,
     cancellation, checkpoint, receipt policy, and bounded-step requirements;
   - no parser syntax.

2. **CompatibilityReport readiness proof**
   - metadata may be present;
   - runtime readiness must remain false with a stable refusal such as
     `progression.runtime_execution_not_authorized`;
   - no RuntimeMachine scheduler.

3. **OOF-PR diagnostic design/proof**
   - design or proof-local validation for OOF-PR1..OOF-PR9;
   - no TypeChecker implementation unless separately authorized;
   - no SemanticIR implementation unless separately authorized.

4. **Profile descriptor specialization proof**
   - prove `external_event` specialization below the top-level source kind;
   - no new top-level `source_kind`;
   - no production listener or queue execution.

5. **ProgressionPack boundary plan**
   - may map future capability ownership;
   - remains shadow/design-only;
   - no compiler dispatch migration.

---

## Non-Authorizations

This decision does not authorize:

- parser implementation;
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
- `ProgressionPack` migration or compiler dispatch changes;
- a new `PROGRESSION` fragment class.

---

## Blockers Before Implementation

Before any implementation card, the owning card must name and satisfy the layer
authority it touches:

| Layer | Required blocker closure |
| --- | --- |
| Parser | Accepted syntax proposal and parser implementation authorization. |
| Classifier/TypeChecker | Accepted diagnostic ownership and typed descriptor proof plan. |
| SemanticIR | Accepted node/artifact shape and golden fixture plan. |
| Assembler/.igapp | Manifest schema authorization. |
| RuntimeMachine | Scheduler/materializer gate and proof-local implementation plan. |
| Durability | Durable queue/checkpoint/receipt sink design and authorization. |
| Ledger/TBackend | Separate binding decision; never implied by progression. |
| Production execution | Explicit runtime/production gate. |
| ProgressionPack | Compiler profile/pack migration authorization. |

---

## Compact Summary

PROP-037 is accepted proposal-only. It defines progression as the semantic
substrate for service liveness while keeping Stream[T], fold_stream, and managed
local loops distinct. The v0 `source_kind` set is closed, `external_event` is the
descriptor-level extension point, and OOF-PR5 is an error by default. All
implementation and production surfaces remain closed.
