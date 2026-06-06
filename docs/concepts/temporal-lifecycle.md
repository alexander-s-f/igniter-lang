# Temporal Lifecycle

Status: meta thesis
Date: 2026-05-05
Author: `[Architect Supervisor / Codex]`

## Claim

`T` in Igniter-Lang is not "store everything forever".

`T` is the language-visible temporal surface that answers:

- what is visible now
- what can be replayed
- what can be resumed
- what can be compacted
- what must be preserved for audit or action rights

Igniter-Lang is the language for contract applications. Igniter Ledger is one
possible persistence backend for applications and one possible `TBackend`
adapter. Ledger must not become the definition of language time.

```text
igniter-lang
  = contract language + runtime semantics + temporal lifecycle

igniter-ledger
  = durable persistence substrate / TBackend adapter candidate
```

## Lifecycle Classes

Different temporal facts have different lifetimes.

```text
T.local
  lives for one evaluation/request
  flush after result unless linked to evidence

T.session
  lives for one RuntimeMachine session
  can enter SemanticImage at checkpoint

T.window
  lives for a bounded business or temporal window
  examples: hour, day, technician shift, order lifecycle

T.durable
  app fact / receipt / decision that must survive restarts

T.audit
  long-lived proof, approval, legal, or business explanation

T.compacted
  old detailed facts replaced by snapshot, summary, or boundary receipt
```

[D] The language should let contracts declare which class they require. Runtime
and TBackend adapters then prove, downgrade, or reject that requirement.

## Flush

`flush` is not only memory cleanup. It is a semantic lifecycle transition.

```text
flush(T.scope)
  -> discard unlinked ephemeral observations
  -> persist selected facts/receipts/decisions
  -> checkpoint SemanticImage when required
  -> emit lifecycle / compaction evidence
  -> downgrade or block claims when evidence is insufficient
```

Possible flush scopes:

- after evaluation
- after request
- after session
- after named slice
- after business boundary
- before process shutdown
- before runtime/backend migration

[D] Flush must be configurable. A language runtime that silently discards data
needed for reproducibility is OOF. A runtime that keeps everything forever is
valid but operationally weak.

## Semantic GC

Igniter-Lang needs semantic garbage collection for `T`.

It should behave like mark/compact over meaning roots, not like ordinary heap
GC.

### Preserve Roots

The following are preserve roots unless an explicit migration or archive policy
says otherwise:

- active contracts and loaded units
- latest trusted SemanticImages
- open checkpoints and replay cursors
- audit receipts and approval receipts
- command/decision evidence used for action rights
- unclosed windows or business boundaries
- snapshots required for resume
- explicit `preserve` refs from compaction policy

### Collectable Material

The following can usually be collected, compacted, or archived:

- ephemeral evaluation traces
- live diagnostics without open failures
- raw high-frequency signals after snapshot/summary
- cache entries whose source facts can be replayed
- old provisional observations not linked to receipts
- detailed facts inside closed windows when a trusted boundary exists

## Boundary / Container Relation

Large temporal surfaces should close into boundaries.

```text
raw facts in window
  -> projection / summary / snapshot
  -> boundary receipt
  -> optional detail retention
  -> compact old detail
```

For example:

```text
GeoSignal[technician, day]
  -> RouteSegmentSnapshot
  -> AvailabilitySnapshot
  -> DispatchDecision receipts
  -> DailyTechnicianBoundary
```

After the boundary is trusted, raw details may be retained only for a short
window while business/audit evidence remains long-lived.

[D] Boundaries and SemanticImages complement each other:

- boundary proves a domain window was summarized
- SemanticImage proves a runtime session can resume or be compared

## Hypothetical App: Technician Dispatch

Contracts:

```text
Technician
Order
ScheduleSlot
OffSchedule
GeoSignal
AvailabilityProjection
DispatchCandidate
DispatchDecision
NotificationReceipt
```

Flow:

```text
GeoSignal + Schedule + OffSchedule + Orders + DayOffConfig
  -> AvailabilityProjection[technician, day]
  -> DispatchCandidate[order]
  -> DispatchDecision
  -> Receipt / Notification / Route update
```

Retention sketch:

| Material | Lifecycle | Policy |
|----------|-----------|--------|
| raw geo signals | `T.window` | keep 24-72h, compact into route segments |
| schedule/order facts | `T.durable` | keep as business facts |
| availability projections | `T.window` / `T.compacted` | snapshot hourly or daily |
| dispatch decisions | `T.audit` | preserve as explanation/action evidence |
| runtime traces | `T.local` / `T.session` | flush unless pinned, failed, or checkpointed |
| SemanticImage | `T.session` / `T.audit` | retain while resume/audit may need it |

High-frequency signals cannot all become permanent language meaning:

```text
50 technicians * 8h * 360 geo events/hour = 144,000 geo facts/day
```

The language should keep the decision-relevant meaning, not blindly keep every
raw signal forever.

## Contract Surface Direction

Possible future syntax:

```text
contract AvailabilityProjection do
  temporal retention:
    raw: ttl("48h"),
    snapshot: every("1h"),
    boundary: by(:day),
    preserve: [:dispatch_decisions, :order_receipts]
end
```

This is intentionally not final syntax. The stable claim is that contracts need
a lifecycle declaration for temporal evidence.

## Relation to Current Proposals

- PROP-004 defines `Projection[T, horizon]`.
- PROP-008 defines TBackend operations: read, append, replay, snapshot,
  compact, subscribe.
- PROP-009 defines SemanticImage and CompatibilityReport.

This meta thesis adds the missing lifecycle pressure:

```text
Projection[T, horizon]
  + TBackend lifecycle operations
  + SemanticImage / CompatibilityReport
  + retention / flush / semantic GC
  -> operationally bounded temporal language
```

## Next Research Need

The next formal slice should define:

- lifecycle classes for `T`
- flush semantics
- semantic GC roots
- retention policy types
- compaction/boundary interaction
- downgrade rules when retention cannot satisfy reproducibility

Until then, agents should avoid assuming that all observations live forever.
