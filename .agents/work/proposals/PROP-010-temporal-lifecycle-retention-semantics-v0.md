# PROP-010: Temporal Lifecycle and Retention Semantics v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-004-type-system-v0.md`,
             `proposals/PROP-005-bridge-observation-envelope-v0.md`,
             `proposals/PROP-008-tbackend-contract-v0.md`,
             `proposals/PROP-009-semantic-image-resume-compatibility-v0.md`,
             `docs/temporal-lifecycle.md`

---

## Purpose

`temporal-lifecycle.md` establishes that `T` is not "store everything
forever." It defines six lifecycle classes for temporal facts and calls for
a formal slice covering lifecycle types, flush semantics, semantic GC roots,
retention policies, compaction/boundary interaction, and downgrade rules.

This proposal delivers that formal slice in full.

---

## Compact Claim

[D] Every observation in Igniter-Lang has a declared **lifecycle class**.
The lifecycle class determines:

- how long the observation must be retained
- when it may be flushed, compacted, or archived
- what happens to claims (reproducibility, audit rights) if retention cannot
  be satisfied
- which GC roots protect the observation from collection

```text
LifecycleClass × RetentionPolicy × GCRoots
  -> flush | checkpoint | compact | archive | preserve | downgrade | block
```

---

## Lifecycle Classes

```text
LifecycleClass =
  :local      -- one evaluation/request; flush after result unless linked
  | :session  -- one RuntimeMachine session; enters SemanticImage at checkpoint
  | :window   -- bounded business or temporal window; compacted at boundary close
  | :durable  -- app fact/receipt/decision; survives restarts
  | :audit    -- long-lived proof, approval, legal, business explanation
  | :compacted -- old detail replaced by snapshot, summary, or boundary receipt
```

### Formal typing

`LifecycleClass` is carried in two places:

**1. In the observation envelope (PROP-005):**

```text
ObsPacket[kind, T] extended with:
  lifecycle    : LifecycleClass        -- declared at production time
  lifecycle_ref: Option[ObsId]         -- links to the boundary or window that owns this obs
```

**2. In contract declarations (future DSL; informative in v0):**

```text
contract C do
  temporal retention:
    lifecycle: :durable,
    raw_ttl:   "48h",
    snapshot:  every("1h"),
    boundary:  by(:day),
    preserve:  [:decisions, :receipts]
end
```

This is not final syntax. The stable claim is that the lifecycle class must
be declarable per contract and verifiable per observation.

---

## Lifecycle Class Semantics

### T.local

```text
LifecycleClass = :local

Survives: one evaluation (demand-driven resolution of one graph node or
          request boundary)
Flush after: result is produced and no open link requires this observation
May enter SemanticImage: No (unless explicitly pinned by :session or higher)
Compaction: immediate after evaluation; not subject to TBackend retention
```

**Collectable material at :local:**

- ephemeral resolution traces
- intermediate `value_observation` packets for nodes not in the output set
- live diagnostics that resolved without failure
- cache fill records not linked to any open failure or receipt

**[D]** A `:local` observation that is linked as `evidence` in an
`Obs[:failure_observation, ...]` is automatically **promoted** to `:session`
— it must survive until the failure is resolved or closed.

### T.session

```text
LifecycleClass = :session

Survives: one RuntimeMachine session
Flush after: session ends and SemanticImage is checkpoint-emitted
May enter SemanticImage: Yes — included in observation_log summary
Compaction: eligible after CompatibilityReport confirms no Session C will need it
```

**Enters SemanticImage:** `observation_log` (ObsId list), `replay_cursors`.
The detail is in the TBackend; the SemanticImage carries the reference, not
the payload.

**[D]** Runtime traces, diagnostic summaries, and cache invalidation records
are typically `:session`. They matter for the session's `:provisional` or
`:downgraded` claims but are not long-lived.

### T.window

```text
LifecycleClass = :window

Survives: a declared business or temporal window (TTL, shift, order lifecycle)
Flush after: window closes AND boundary receipt is emitted AND trusted
May enter SemanticImage: Yes — as ProjectionRef with snapshot_ref
Compaction: eligible after boundary receipt is trusted and detail_retention TTL expires
```

**Window definition (declarative):**

```text
TemporalWindow = Record {
  name           : String
  kind           : :ttl | :business | :calendar
  ttl            : Option[Duration]    -- for :ttl and :calendar
  boundary_key   : Option[Symbol]      -- for :business (e.g. :order_id, :shift_id)
  close_trigger  : CloseTrigger
  detail_retain  : Option[Duration]    -- how long after close to keep raw facts
}

CloseTrigger = :ttl_expired | :business_event | :explicit_close | :boundary_receipt
```

**Example from `temporal-lifecycle.md` (technician dispatch):**

```text
GeoSignal window:
  name: "geo_signal_day"
  kind: :calendar
  ttl:  "24h"
  close_trigger: :ttl_expired
  detail_retain: "48h"

After close:
  -> snapshot (RouteSegmentSnapshot, AvailabilitySnapshot)
  -> boundary receipt (DailyTechnicianBoundary)
  -> compact raw GeoSignals (eligible after detail_retain expires)
```

**[D]** A `:window` observation that has NOT been summarised by a boundary
receipt when its window closes is **not eligible for compaction** — it is
automatically promoted to `:session` until the boundary receipt is produced.
This prevents silent data loss.

### T.durable

```text
LifecycleClass = :durable

Survives: restarts, migrations, TBackend swaps
Flush: never automatic; only explicit :explicit_close or migration policy
May enter SemanticImage: Yes — as contract_descriptors and receipts
Compaction: only via explicit CompactionPolicy with :fact_gc strategy and preserve checks
```

**[D]** `:durable` observations are **always in the TBackend's implicit
preserve set** (see PROP-008 compact semantics). A `CompactionPolicy` may
not remove a `:durable` observation unless it carries an explicit migration
receipt proving the fact was migrated to a new location.

**Typical :durable material:**

- `fact_observation` for business facts (orders, users, contracts, schedules)
- `receipt_observation` for commands and decisions
- `descriptor_observation` for loaded contracts
- `AxiomDescriptor` and `RuntimeContract` platform_observations

### T.audit

```text
LifecycleClass = :audit

Survives: regulatory, legal, or business explanation horizon (years)
Flush: never automatic
May enter SemanticImage: Yes — as receipts and verification evidence
Compaction: prohibited; only archival (move to cold storage with access policy)
```

**[D]** `:audit` observations are **never compacted**. They may be archived
(moved to slower storage with an access receipt) but the ObsId and
content_hash must remain resolvable. A `CompatibilityReport` that cannot
resolve an `:audit` observation's ObsId is a `storage.replay_availability`
block (PROP-009).

**Typical :audit material:**

- approval receipts (`capability.approval_required` events)
- dispatch decisions (`DispatchDecision` receipt)
- `VerificationReport` observations
- `SemanticImage` observations linked from active checkpoints
- failure_observations for open or legally significant failures

### T.compacted

```text
LifecycleClass = :compacted

Meaning: this observation's original detail has been replaced by a snapshot,
         summary, or boundary receipt.
Survives: as a stub ObsId with content_hash and lifecycle_ref -> boundary receipt
Payload: :hashed or :omitted (PrivacyPolicy.payload_policy)
Compaction: the stub itself is :audit — it proves compaction occurred
```

**[D]** Compaction is not deletion. A compacted observation becomes a
`:compacted` stub: its `ObsId` remains valid, its `payload` is set to
`:hashed` (hash-only) or `:omitted`, and it carries a `lifecycle_ref` link
to the `CompactionReceipt` that explains what replaced it.

This preserves the **content-addressing chain**: a consumer can verify that
the compacted observation existed (via `content_hash`) even after the payload
is gone.

---

## Flush Semantics

`flush` is a typed lifecycle transition, not a memory operation.

```text
FlushScope = :after_evaluation
           | :after_request
           | :after_session
           | :after_named_slice
           | :after_business_boundary
           | :before_process_shutdown
           | :before_migration

FlushResult = Record {
  flushed_count  : Int
  persisted_count: Int
  checkpointed   : Bool              -- was SemanticImage emitted?
  compacted_count: Int
  promoted_count : Int               -- promoted to higher lifecycle class
  blocked_count  : Int               -- could not be flushed (open dependencies)
  obs_id         : ObsId             -- the FlushReceipt observation
}
```

**Flush decision rules per lifecycle class:**

| Class | Flush action | Condition for blocking |
|-------|-------------|----------------------|
| `:local` | Discard immediately after evaluation | Linked as evidence in open failure |
| `:session` | Persist to TBackend; enter SemanticImage summary | Session not ended |
| `:window` | Persist; compact detail after boundary receipt + detail_retain | Boundary receipt not yet produced |
| `:durable` | Persist; never flush automatically | Explicit migration receipt required |
| `:audit` | Archive with access receipt; never compact | — |
| `:compacted` | Stub persists; payload gone | Stub itself is :audit |

**Flush observation:**

```text
Obs[:platform_observation, FlushReceipt]
  subject  : "flush://<session_id>/<scope>"
  payload  : Some(FlushResult)
  temporal : Some(TemporalCtx { as_of: flush_time })
  links    : [
    { rel: :caused_by, ref: scope_trigger_obs_id }
  ]
```

**[D]** A flush that silently discards observations needed for reproducibility
is OOF. Any flush that cannot safely discard an observation must either
promote it to a higher lifecycle class or emit a `failure_observation` with
`reason_code: constraint.lifecycle_violation`.

---

## Retention Policy Types

```text
RetentionPolicy = Record {
  raw_ttl        : Option[Duration]        -- how long raw observations are kept
  snapshot       : Option[SnapshotSchedule]
  boundary       : Option[BoundaryPolicy]
  preserve       : Collection[ObsId | SubjectRef]  -- explicit preserve set
  on_violation   : RetentionViolationAction
}

SnapshotSchedule = Record {
  frequency : Duration | :on_close | :on_demand
  type_tag  : TypeTag          -- T in Projection[T, horizon]; required
  horizon   : ProjectionHorizon
}

BoundaryPolicy = Record {
  kind           : :calendar | :business | :explicit
  unit           : Option[:hour | :day | :week | :month | Symbol]
  boundary_key   : Option[Symbol]
  close_trigger  : CloseTrigger
  receipt_kind   : ObsKind             -- what kind of observation closes the boundary
}

RetentionViolationAction = :downgrade | :block | :warn | :extend
```

**[D]** `RetentionPolicy` is a **contract-level declaration**. The
TBackend `compact` operation (PROP-008) uses `CompactionPolicy` to execute
retention decisions. `RetentionPolicy` is the semantic declaration;
`CompactionPolicy` is the operational instruction.

**[D]** `on_violation: :downgrade` means: if raw_ttl expires before a
boundary receipt is produced, the affected results are downgraded to
`:provisional`. `on_violation: :block` means: block compaction until the
boundary receipt is produced.

---

## Semantic GC Roots

A semantic GC root is an observation that must never be collected without
an explicit migration, archive, or supersede policy.

### Formal GC root set (v0)

```text
SemanticGCRoots = {
  -- Active contracts
  contract_descriptors: all loaded contract descriptor_observations

  -- Runtime identity
  axiom_descriptor_obs  : current session's AxiomDescriptor
  runtime_contract_obs  : current session's RuntimeContract
  backend_descriptor_obs: current session's TBackendDescriptor

  -- Session continuity
  latest_semantic_image : most recent checkpointed SemanticImage
  open_checkpoints      : all CheckpointRefs without a successor
  active_replay_cursors : all ReplayCursors with active subscribers or sessions

  -- Evidence chain
  audit_receipts        : all :audit lifecycle observations
  approval_receipts     : all capability.approval_required receipts
  open_failure_evidence : all evidence ObsIds linked from unresolved failure_observations

  -- Business boundaries
  open_windows          : all TemporalWindows without a boundary receipt
  unclosed_projections  : all ProjectionRefs without a trusted snapshot

  -- Explicit preserves
  explicit_preserves    : CompactionPolicy.preserve lists (PROP-008)
}
```

**[D]** The GC root set is **monotonically safe**: adding roots never causes
incorrect collection; removing roots requires an explicit lifecycle transition
(boundary receipt, migration receipt, or supersede observation).

**[D]** Semantic GC is **not heap GC**. It does not run automatically on a
timer. It runs as the `compact` operation (PROP-008) triggered explicitly by
a flush scope or a retention policy schedule. This makes compaction
observable and auditable.

---

## Compaction and Boundary Interaction

The pattern from `temporal-lifecycle.md`:

```text
raw facts in window
  -> projection / summary / snapshot
  -> boundary receipt
  -> optional detail retention (detail_retain TTL)
  -> compact old detail -> :compacted stubs
```

**Formal compaction eligibility rule:**

```text
obs : ObsPacket[kind, T]  is eligible for compaction iff:

  obs.lifecycle ∈ {:local, :session, :window}
  AND obs is NOT in SemanticGCRoots
  AND (
    obs.lifecycle = :local
    OR (obs.lifecycle = :window
        AND boundary_receipt_for(obs) is trusted
        AND detail_retain_ttl_expired(obs))
    OR (obs.lifecycle = :session
        AND SemanticImage covering obs is checkpointed
        AND no active Session B needs obs for resume)
  )
```

**Ineligible for compaction (always preserved):**

```text
obs.lifecycle ∈ {:durable, :audit, :compacted}   -- :compacted stub itself
OR obs ∈ SemanticGCRoots
OR obs.privacy.payload_policy = :present
   AND obs is linked as evidence from a :trusted claim
```

---

## Downgrade Rules: Retention Cannot Satisfy Reproducibility

When a retention policy expires or compaction runs before reproducibility
claims are settled, the following downgrade rules apply:

### Rule DR-1: Local flush before evidence linked

```text
IF obs.lifecycle = :local
AND flush(after_evaluation) runs
AND obs is linked as evidence from an open failure_observation:
  -> promote obs to :session
  -> emit platform_observation: LifecyclePromotion
  -> DO NOT discard
```

### Rule DR-2: Window closed without boundary receipt

```text
IF obs.lifecycle = :window
AND window.close_trigger fires
AND boundary_receipt_for(obs) does NOT exist:
  -> promote obs to :session
  -> emit failure_observation:
       reason_code: constraint.lifecycle_violation
       status: :pending
       remediation: "Produce boundary receipt before next compaction"
  -> block compaction for this window's observations
```

### Rule DR-3: Durable fact compacted without migration receipt

```text
IF compact runs with :fact_gc strategy
AND target obs has lifecycle = :durable
AND no migration_receipt exists for obs:
  -> BLOCK compaction for this obs
  -> emit failure_observation:
       reason_code: constraint.lifecycle_violation
       status: :rejected
       remediation: "Produce migration receipt or move to :audit"
```

### Rule DR-4: Reproducibility claim with compacted evidence

```text
IF Projection[T, horizon] claims reproducible: true
AND any evidence obs in the projection's scope has lifecycle = :compacted
AND that obs is not covered by a trusted snapshot_ref:
  -> downgrade reproducible: true -> reproducible: false
  -> emit constraint_observation: status: :pending
  -> ReproducibilityAssertion.level -> :partial
```

### Rule DR-5: Session resume after compaction

```text
IF Session B requests ResumeStatus for Session A's SemanticImage
AND replay_cursor for Session A's observation_log is no longer satisfiable
   (observations were compacted):
  -> check if snapshot_ref covers the gap
  -> if snapshot covers: CompatibilityDimension.replay_availability = :downgrade
  -> if snapshot does NOT cover: CompatibilityDimension.replay_availability = :blocked
  -> emit CompatibilityReport with appropriate ResumeStatus
```

---

## Lifecycle × Retention × GC: Summary Matrix

| Lifecycle | Auto-flush | Compaction eligible | GC root? | Reproducibility |
|-----------|-----------|---------------------|----------|----------------|
| `:local` | After eval | Immediately (if no open links) | No | None |
| `:session` | After session | After SemanticImage checkpoint | Yes (open checkpoint) | Session-scoped |
| `:window` | After boundary receipt + detail_retain | After window close + detail_retain | Yes (if window open) | Window-scoped |
| `:durable` | Never automatic | Only with migration receipt | Yes | Full |
| `:audit` | Never | Prohibited; archival only | Yes | Full + audit chain |
| `:compacted` | N/A | N/A (stub is :audit) | Stub is root | Hash-only witness |

---

## Fragment Classification

| Construct | Class | Reason |
|-----------|-------|--------|
| Lifecycle class declaration | CORE | Typed; declarative |
| Flush with FlushReceipt emitted | CORE | Observable transition |
| Flush without FlushReceipt | OOF | Silent lifecycle change |
| Compaction with CompactionReceipt | CORE | Observable; PROP-008 semantics |
| Compaction of :durable without migration receipt | OOF | DR-3 |
| Compaction of :audit | OOF | Audit observations are never compacted |
| Lifecycle promotion | CORE | Observable; typed |
| Lifecycle demotion (higher to lower without receipt) | OOF | Data loss risk |
| Downgrade of reproducibility claim (DR-4) | CORE | Typed; observable |
| SemanticImage with :local observations in observation_log | OOF | :local must not persist to SemanticImage |

---

## Relation to TBackend and SemanticImage

```text
TBackend.compact(policy)
  uses: CompactionPolicy (PROP-008)
  respects: SemanticGCRoots
  respects: lifecycle class of each observation
  emits: CompactionReceipt + :compacted stubs

TBackend.snapshot(horizon)
  materialises: :window or :session projections
  enables: safe compaction of raw facts after boundary receipt

SemanticImage (PROP-009)
  includes: :session + :durable + :audit observations (by ObsId)
  excludes: :local observations
  checkpoint: triggers flush(after_session) for :local and eligible :session obs

CompatibilityReport (PROP-009)
  replay_availability dimension:
    checks if required observations are still in TBackend or covered by snapshot
    uses DR-5 downgrade/block rule
```

---

## Open Questions

[Q] Should `lifecycle` be a field on `ObsPacket` in v0 or only a contract-level
declaration? Recommendation: contract-level declaration in v0; packet-level
field in v1 when bridge adapters need to route observations by lifecycle class.

[Q] Should `:compacted` stubs be a separate observation kind, or should they
be `:platform_observation` with a `compacted: true` flag?
Recommendation: `:platform_observation` with `compacted: true` field in v0
(reuses PROP-005 envelope). Separate `ObsKind` if bridge pressure repeats.

[Q] Should lifecycle promotion (DR-1, DR-2) require human approval?
Recommendation: no for DR-1 (automatic; safety-preserving). Yes for DR-3
(durable fact compaction). Always emit a `platform_observation` for any
promotion.

[Q] Is `detail_retain` a duration from window close, or from the last write
into the window? Recommendation: from window close (cleaner semantics; avoids
perennial extension of the retain window by late-arriving signals).

---

## Rejected Paths

[X] "Store everything forever." High-frequency signals cannot all become
permanent language meaning. Semantic GC roots define what must be preserved;
everything else has a lifecycle.

[X] Silent flush or compaction. Every flush and compaction must emit a typed
observation. Silent lifecycle transitions are OOF.

[X] Heap-style automatic GC on a timer. Semantic GC runs explicitly (flush
scope, compact operation). It does not run automatically without a declared
scope or policy.

[X] Lifecycle demotion (moving from :audit to :session). Lifecycle class is
monotonically non-decreasing. An observation may be promoted but never
demoted. Demotion would allow silently weakening retention promises.

[X] Compaction without GC root check. Compaction must check the full
`SemanticGCRoots` set before removing any observation. A compaction that
removes a GC root without an explicit transition is OOF.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-010
Status: done

[D] Decisions:
- Six lifecycle classes: :local, :session, :window, :durable, :audit, :compacted.
  Each has defined flush action, compaction eligibility, GC root membership,
  and reproducibility scope.
- LifecycleClass is carried in the ObsPacket envelope (lifecycle field) and
  declared at contract level (RetentionPolicy).
- Flush is a typed lifecycle transition with FlushResult and FlushReceipt
  observation. Silent flush is OOF.
- Semantic GC roots: contract descriptors, runtime identity obs, latest
  SemanticImage, open checkpoints, active replay cursors, audit receipts,
  approval receipts, open failure evidence, open windows, unclosed projections,
  explicit preserves.
- Semantic GC runs as TBackend.compact (PROP-008), not on a timer.
- Five downgrade rules (DR-1..DR-5): local flush before evidence linked;
  window close without boundary receipt; durable compaction without migration;
  reproducibility claim with compacted evidence; session resume after compaction.
- Lifecycle is monotonically non-decreasing (promotion only; demotion is OOF).
- :compacted stub persists as a content-addressing witness (payload: :hashed
  or :omitted; ObsId and content_hash remain valid).
- RetentionPolicy is a contract-level semantic declaration;
  CompactionPolicy (PROP-008) is the operational execution.
- detail_retain TTL is measured from window close time.

[R] Recommendations:
- Add lifecycle field to ObsPacket in PROP-005 v0.1 (alongside
  :verification_observation ObsKind extension).
- TBackend.compact must check SemanticGCRoots before removing any observation.
  Update PROP-008 compact semantics with this requirement.
- The Research Agent lifecycle track (runtime-machine-lifecycle-v0) should
  reference DR-1..DR-5 for the checkpoint/flush steps.
- Technician Dispatch is a strong motivating example; consider using it as
  the reference application in the lifecycle track.

[S] Signals:
- The six lifecycle classes map cleanly to the GeoSignal example:
  :local (cache fill), :session (resolution trace), :window (raw geo, 24-72h),
  :durable (orders, schedules), :audit (dispatch decisions), :compacted
  (route segments after day boundary).
- DR-4 (reproducibility downgrade when evidence is compacted) elegantly connects
  temporal lifecycle to PROP-009 ReproducibilityAssertion: if evidence is gone,
  the claim is :partial or :none.
- Semantic GC as explicit compact (not timer-based) is the right choice for an
  observable language: every collection event produces a typed observation.

[Q] Open Questions:
- lifecycle field on ObsPacket in v0 or v1?
- :compacted stubs as platform_observation vs new ObsKind?
- Lifecycle promotion: always automatic, or human approval for DR-3?
- detail_retain from window close vs. last write?

[X] Rejected:
- Store everything forever.
- Silent flush or compaction.
- Heap-style automatic GC on a timer.
- Lifecycle demotion.
- Compaction without GC root check.

[Next] Proposed next slices:
- Research Agent track: runtime-machine-lifecycle-v0
  (boot/load/evaluate/checkpoint/resume now has all types: SemanticImage,
   CompatibilityReport, ResumeStatus, LifecycleClass, FlushResult)
- PROP-005.1 / PROP-010.1: add lifecycle field to ObsPacket;
  add :verification_observation to ObsKind family
- Research Agent track: temporal-contracts-and-projections-v0
  (TemporalWindow, BoundaryPolicy, SnapshotSchedule = named slice mechanics)
```
