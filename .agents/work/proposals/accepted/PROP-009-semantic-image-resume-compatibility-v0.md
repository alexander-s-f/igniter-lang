# PROP-009: Semantic Image and Resume Compatibility v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-004-type-system-v0.md`,
             `proposals/PROP-005-bridge-observation-envelope-v0.md`,
             `proposals/PROP-006-runtime-contract-specification-v0.md`,
             `proposals/PROP-007-conformance-verification-v0.md`,
             `proposals/PROP-008-tbackend-contract-v0.md`,
             `docs/runtime-machine.md`

---

## Purpose

`runtime-machine.md` defines the **Semantic Image** — what persists across
sessions — and the **resume** lifecycle step. PROP-008 defined the
`ReproducibleResume` record as a pre-condition check. But neither document
formally types:

- `SemanticImage` — the full structure of what a session saves and restores
- `ResumeStatus` — the outcome of a resume compatibility assessment
- `CompatibilityReport` — the detailed evidence of why resume is allowed,
  downgraded, or blocked
- The decision rules for `:trusted`, `:provisional`, `:downgraded`,
  and `:blocked` resume outcomes

This proposal formalises all four, making the lifecycle track
(`runtime-machine-lifecycle-v0`) free to reference them directly without
re-deriving the types inline.

---

## Compact Claim

[D] A **Semantic Image** is the typed, content-addressed record of a session's
observable outputs. It is not a process memory snapshot. It is the evidence
chain that Session B needs to continue from Session A.

[D] A **CompatibilityReport** is the structured output of comparing Session
B's environment against Session A's `SemanticImage`. It produces a
`ResumeStatus` that determines what Session B may claim and do.

```text
SemanticImage(Session A)
  + EnvironmentDescriptor(Session B)
  -> CompatibilityReport
       -> ResumeStatus
            :trusted | :provisional | :downgraded | :blocked
```

---

## SemanticImage

```text
SemanticImage = Record {
  -- Identity
  image_id         : String          -- content hash of the full image
  session_id       : String          -- session that produced this image
  produced_at      : Timestamp

  -- Semantic contracts (what governed this session)
  axiom_descriptor : ObsId           -- AxiomDescriptor platform_observation
  runtime_contract : ObsId           -- RuntimeContract platform_observation
  backend_descriptor: ObsId          -- TBackendDescriptor platform_observation

  -- Contract graph (what was loaded)
  contract_descriptors: Collection[ObsId]   -- descriptor_observations for each contract
  fragment_report  : ObsId           -- Pass 0 ClassifiedAST result

  -- Observations produced (the session's semantic output)
  observation_log  : Collection[ObsId]      -- ordered by seq_id in TBackend
  observation_count: Int
  observation_hash : Hash            -- hash over observation_log (ordered)

  -- Projections and receipts
  projections      : Collection[ProjectionRef]
  receipts         : Collection[ObsId]      -- receipt_observations

  -- Verification evidence
  verification_report: Option[ObsId]        -- VerificationReport from PROP-007

  -- Resume anchors
  checkpoint       : CheckpointRef
  replay_cursors   : Collection[ReplayCursor]  -- one per TBackend partition
}

ProjectionRef = Record {
  name             : String          -- human name for the projection
  type_tag         : TypeTag         -- T in Projection[T, horizon]
  horizon          : ProjectionHorizon
  snapshot_ref     : Option[SnapshotRef]    -- materialised snapshot if available
  obs_id           : ObsId           -- the value_observation for this projection
}

CheckpointRef = Record {
  checkpoint_id    : String          -- content hash
  as_of            : TimeRef         -- Tt at checkpoint time
  seq_id           : Int             -- TBackend seq_id at checkpoint
  snapshot_ref     : Option[SnapshotRef]
  created_at       : Timestamp
}
```

**[D]** `image_id` is computed as:

```text
image_id = hash_content(
  axiom_descriptor_hash
  ++ runtime_contract_hash
  ++ observation_hash
  ++ checkpoint.checkpoint_id
)
```

This makes the `SemanticImage` a **content-addressed root** over the full
session output. Two sessions that produced identical semantics under identical
runtime contracts will have the same `image_id`.

**[D]** The `SemanticImage` is emitted as a `platform_observation` at session
end (checkpoint):

```text
Obs[:platform_observation, SemanticImage]
  subject  : "image://<session_id>"
  links    : [
    { rel: :describes,      ref: session_id },
    { rel: :observed_under, ref: axiom_descriptor },
    { rel: :observed_under, ref: runtime_contract }
  ]
  temporal : Some(TemporalCtx { as_of: checkpoint.as_of })
```

---

## EnvironmentDescriptor

Before computing a `CompatibilityReport`, Session B assembles its own
environment descriptor:

```text
EnvironmentDescriptor = Record {
  session_id       : String
  axiom_descriptor : ObsId           -- Session B's AxiomDescriptor
  runtime_contract : ObsId           -- Session B's RuntimeContract
  backend_descriptor: ObsId          -- Session B's TBackendDescriptor
  verification_report: Option[ObsId] -- Session B's VerificationReport
  requested_as_of  : TimeRef         -- where Session B wants to start
  intent           : ResumeIntent
}

ResumeIntent = :exact_replay       -- reproduce Session A's results exactly
             | :continue           -- continue from Session A's last state
             | :snapshot_load      -- load a specific snapshot and continue
             | :fresh_with_history -- new session but reads Session A's history
```

The `intent` guides how compatibility is assessed. `:exact_replay` requires
the strictest compatibility; `:fresh_with_history` is the most permissive.

---

## CompatibilityReport

```text
CompatibilityReport = Record {
  report_id        : String
  image_ref        : ObsId           -- Session A's SemanticImage
  environment_ref  : EnvironmentDescriptor
  checks           : Collection[CompatibilityCheck]
  summary          : CompatibilitySummary
}

CompatibilityCheck = Record {
  check_id         : String
  dimension        : CompatibilityDimension
  outcome          : :compatible | :downgrade | :blocked | :unknown
  severity         : :info | :warning | :error | :critical
  expected         : String          -- what Session A had
  actual           : String          -- what Session B has
  remediation      : Option[RemediationHint]
}

CompatibilityDimension =
  :axiom_version         -- AxiomDescriptor version match
  | :runtime_version     -- RuntimeContract version match
  | :fragment_class      -- Session B supports all fragment classes used in A
  | :escape_set          -- Session B's escape_set covers Session A's escapes
  | :storage_consistency -- Session B's consistency >= Session A's
  | :clock_source        -- Session B's clock source is compatible
  | :capability_set      -- Session B's capabilities cover Session A's effects
  | :temporal_continuity -- requested_as_of does not regress
  | :trust_level         -- Session B's verification trust level
  | :snapshot_integrity  -- snapshot content hash matches
  | :replay_availability -- TBackend can serve Session A's replay_cursors

CompatibilitySummary = Record {
  resume_status    : ResumeStatus
  blocked_dimensions: Collection[CompatibilityDimension]
  downgraded_dimensions: Collection[CompatibilityDimension]
  reproducibility  : ReproducibilityAssertion
}
```

---

## ResumeStatus

```text
ResumeStatus = :trusted | :provisional | :downgraded | :blocked
```

### :trusted

All compatibility checks pass. Session B may:
- Continue from Session A's last checkpoint without qualification
- Claim full reproducibility for results computed under the same inputs and Tt
- Issue `Projection[T, horizon]` with `reproducible: true`
- Act on results without human review (for capability-gated effects, approval
  rules still apply)

Conditions:

```text
ALL of:
  axiom_version    = :compatible
  runtime_version  = :compatible
  fragment_class   = :compatible
  escape_set       = :compatible
  storage_consistency = :compatible
  clock_source     = :compatible
  capability_set   = :compatible
  temporal_continuity = :compatible
  trust_level      = :compatible    (verification trust_level != :untrusted)
  snapshot_integrity  = :compatible (if snapshot used)
  replay_availability = :compatible (if replay used)
```

### :provisional

One or more dimensions are `:downgrade` (not `:blocked`). Session B may
continue but with restrictions:

- Must emit a `constraint_observation` with `status: :pending` for any
  result that depends on a downgraded dimension
- Must NOT claim `reproducible: true` for projections over downgraded dimensions
- Must surface the `CompatibilityReport` to any consuming agent or human
  before irreversible effects

**Downgrade rules by dimension:**

| Dimension | Downgrade condition | Restriction |
|-----------|--------------------|-----------| 
| `axiom_version` | Minor version bump (patch/minor) | Results may differ in edge cases; flag affected nodes |
| `runtime_version` | Minor version bump; declared backward-compatible | Cache/scheduler details may differ |
| `escape_set` | Session B supports a subset; missing escapes are unused in A | Only blocks if A actually used missing escape |
| `storage_consistency` | Session B's consistency < Session A's (e.g., eventual vs strong) | All reads marked `:provisional` |
| `clock_source` | Session B clock is compatible but different source | Temporal facts marked `:provisional` |
| `trust_level` | Session B's VerificationReport is `trust_level: :conditional` | Warned dimensions propagate |

### :downgraded

`ResumeStatus: :downgraded` is a stronger form of `:provisional` where
**multiple** dimensions are downgraded, OR where a single downgrade affects
the **core evaluation path** (not peripheral escapes).

Session B may continue with heavy qualification:

- All results are marked `provisional: true` in their `value_observation`
- All `Projection[T, horizon]` are marked `reproducible: false`
- Human review is required before any write effect (capability approval
  required for all, not just `approval_required` set)
- A `platform_observation` with subject `"resume://downgraded"` is emitted
  before any evaluation

**[D]** The distinction between `:provisional` and `:downgraded` is one
of **scope**. `:provisional` means some results are affected; `:downgraded`
means the core evaluation path is suspect. The compiler uses the
`blocked_dimensions` and `downgraded_dimensions` lists to determine scope.

### :blocked

One or more dimensions are `:blocked`. Session B **must not** evaluate
user contracts. It must:

1. Emit a `failure_observation` with:
   ```text
   status      : :blocked
   reason_code : constraint.resume_incompatible
   links       : [
     { rel: :caused_by, ref: compatibility_report_obs_id },
     { rel: :violates,  ref: blocked_dimension_ref }
   ]
   ```
2. Make the `CompatibilityReport` available to agents and operators.
3. NOT proceed to evaluation.

**Block rules by dimension:**

| Dimension | Block condition |
|-----------|----------------|
| `axiom_version` | Major version change; semantic domain incompatible |
| `runtime_version` | Major version change; breaking promises |
| `fragment_class` | Session B cannot execute OOF constructs that Session A used (should not occur; OOF is rejected at Pass 0) |
| `escape_set` | Session B lacks escape that Session A actually used |
| `temporal_continuity` | `requested_as_of < checkpoint.as_of` (temporal regression) |
| `trust_level` | Session B's VerificationReport has `trust_level: :untrusted` |
| `snapshot_integrity` | `SnapshotRef.content_hash` does not match backend content |
| `replay_availability` | TBackend cannot serve required `ReplayCursor` (compacted away) |
| `capability_set` | Session A's effects require capabilities Session B does not have |

---

## ReproducibilityAssertion

```text
ReproducibilityAssertion = Record {
  level      : :full | :partial | :none
  scope      : Collection[SubjectRef]   -- which contracts/projections are reproducible
  conditions : Collection[String]       -- human-readable conditions for reproducibility
  blocking_refs: Collection[ObsId]      -- obs that prevent full reproducibility
}
```

| Level | Meaning |
|-------|---------|
| `:full` | Given same inputs + Tt, all results are identical. `ResumeStatus: :trusted`. |
| `:partial` | Some results reproducible; others marked `:provisional`. `ResumeStatus: :provisional` or `:downgraded`. |
| `:none` | No reproducibility guarantee. `ResumeStatus: :blocked` or critical verification failure. |

**[D]** A `Projection[T, horizon]` with `horizon` containing no `:latest`
references AND `ReproducibilityAssertion.level: :full` may set
`reproducible: true`. All other combinations must set `reproducible: false`.

---

## CompatibilityReport as Observation

```text
Obs[:platform_observation, CompatibilityReport]
  subject  : "resume://<session_b_id>/compatibility"
  temporal : Some(TemporalCtx { as_of: environment.requested_as_of })
  links    : [
    { rel: :describes,   ref: session_b_id },
    { rel: :caused_by,   ref: image_ref          },   -- Session A's SemanticImage
    { rel: :observed_under, ref: verification_ref }    -- Session B's VerificationReport
  ]
  payload  : Some(CompatibilityReport)
  privacy  : PrivacyPolicy { payload_policy: :present }
```

This observation is emitted by the Runtime Machine before any user contract
evaluation in Session B. It is a **gate**: evaluation proceeds only if
`resume_status != :blocked`.

---

## Decision Rules: Full Compatibility Matrix

```text
trust_level     axiom_compat    runtime_compat    temporal_ok    -> ResumeStatus
-----------     ------------    --------------    -----------       ------------
:trusted        :compatible     :compatible       yes            -> :trusted
:trusted        downgrade       :compatible       yes            -> :provisional
:trusted        downgrade       downgrade         yes            -> :downgraded
:trusted        :compatible     :compatible       regressed      -> :blocked
:conditional    :compatible     :compatible       yes            -> :provisional
:conditional    downgrade       *                 yes            -> :downgraded
:untrusted      *               *                 *              -> :blocked
*               major_change    *                 *              -> :blocked
*               *               major_change      *              -> :blocked
snapshot mismatch *             *                 *              -> :blocked
replay unavailable *            *                 *              -> :blocked (if replay needed)
```

---

## Fragment Classification

| Construct | Class | Reason |
|-----------|-------|--------|
| `SemanticImage` production | CORE | Typed; content-addressed; emitted at checkpoint |
| `CompatibilityReport` production | CORE | Deterministic from Environment + Image |
| `ResumeStatus: :trusted` evaluation | CORE | All guarantees hold |
| `ResumeStatus: :provisional` evaluation | ESCAPE | Downgraded dimensions; results flagged |
| `ResumeStatus: :downgraded` evaluation | ESCAPE | Wider impact; human review required |
| `ResumeStatus: :blocked` evaluation | OOF | Must not proceed; `constraint.resume_incompatible` |
| Evaluation without CompatibilityReport | OOF | Silent resume without compatibility check |
| SemanticImage with mutable `image_id` | OOF | Violates content-address stability |

---

## Relation to Prior Proposals

| Prior proposal | What PROP-009 builds on |
|----------------|------------------------|
| PROP-004 `Projection[T, horizon]` | `ProjectionRef` in SemanticImage; `reproducible` flag uses ReproducibilityAssertion |
| PROP-005 `ObsPacket` WF rules | SemanticImage emitted as well-formed platform_observation |
| PROP-006 `RuntimeContract` | `runtime_contract` field; version compatibility checks |
| PROP-007 `VerificationReport` | `trust_level` dimension; Session B's report is gate |
| PROP-008 `TBackend.snapshot` | `SnapshotRef` in CheckpointRef; `replay_availability` check |
| PROP-008 `ReproducibleResume` | PROP-009 supersedes/extends that record with full CompatibilityReport |

**[D]** PROP-008's `ReproducibleResume` record is absorbed into PROP-009's
`CompatibilityReport`. Future proposals should reference PROP-009 for resume
semantics, not the PROP-008 record directly.

---

## Open Questions

[Q] Should `SemanticImage` include the full `observation_log` (all ObsIds)
or only a **summary cursor** (first + last seq_id + count + hash)? Full list
enables precise audit; summary enables fast compatibility check.
Recommendation: summary by default (`observation_count + observation_hash +
replay_cursors`); full list available on demand via TBackend replay.

[Q] Should `:downgraded` be a distinct status or collapse into `:provisional`?
The distinction is in scope (core path vs. peripheral). Recommendation: keep
separate — the lifecycle track needs the distinction to decide whether to
require human review.

[Q] How long should a `SemanticImage` be retained in the TBackend?
It must survive long enough for any Session B that may resume from it.
Recommendation: `compact` must include the most recent `SemanticImage`
ObsId in its implicit `preserve` set (see PROP-008 compact semantics).

[Q] Should `CompatibilityReport` be computed by the Runtime Machine or by a
dedicated compatibility verifier service? Recommendation: Runtime Machine
computes it at resume time using declared contracts (no external service
needed for v0). An external verifier is an ESCAPE extension.

---

## Rejected Paths

[X] Resume without CompatibilityReport. Silent resume is OOF. Every resume
must produce a CompatibilityReport before evaluation proceeds.

[X] Mutable SemanticImage. The `image_id` is a content hash over the full
image. It cannot change after emission. A session that updates its image
must emit a new `SemanticImage` observation, not mutate the existing one.

[X] Process-memory snapshot as SemanticImage. A Smalltalk-style object-memory
image is not a semantic artifact — it hides runtime internals. The Semantic
Image is only typed observations, projections, receipts, and cursors.

[X] Trust override at resume time. `:blocked` from `trust_level: :untrusted`
cannot be overridden by additional evidence or human approval. The
verification must be re-run with a conformant backend.

[X] `:provisional` without qualification. A `:provisional` resume must
emit `constraint_observation: :pending` on affected results. Returning
provisional results without marking them is OOF.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-009
Status: done

[D] Decisions:
- SemanticImage is the typed, content-addressed record of a session's outputs:
  axiom/runtime/backend descriptors, contract descriptors, observation_log
  (summary), projections, receipts, verification evidence, checkpoint, cursors.
- image_id = hash_content(axiom_hash ++ runtime_hash ++ observation_hash ++
  checkpoint_id). Two sessions with identical semantics and runtime produce
  the same image_id.
- CompatibilityReport has eleven CompatibilityDimensions with per-dimension
  outcomes: :compatible | :downgrade | :blocked | :unknown.
- ResumeStatus four values: :trusted / :provisional / :downgraded / :blocked.
  :trusted = all dimensions compatible. :blocked = any critical dimension blocked.
  :provisional = peripheral downgrade. :downgraded = core path downgrade.
- trust_level: :untrusted always blocks. Major axiom/runtime version change
  always blocks. Temporal regression always blocks.
- :provisional evaluation requires constraint_observation: :pending on affected
  results. :downgraded requires human review for all write effects.
- :blocked evaluation must not proceed. Emits failure_observation:
  constraint.resume_incompatible. No override.
- PROP-008 ReproducibleResume is absorbed into PROP-009 CompatibilityReport.
  Future references should use PROP-009 for resume semantics.
- ReproducibilityAssertion: :full / :partial / :none.
  Projection[T, horizon] with reproducible: true requires :full assertion.
- SemanticImage is emitted as platform_observation at checkpoint time.
  CompatibilityReport is emitted as platform_observation before first
  Session B evaluation. Both are gating observations.

[R] Recommendations:
- The lifecycle track (runtime-machine-lifecycle-v0) should reference
  SemanticImage, CompatibilityReport, and ResumeStatus directly from PROP-009.
- Add SemanticImage emission to the TBackend.append sequence at session end
  (checkpoint step).
- CompatibilityReport must be emitted as the first platform_observation of
  Session B (before AxiomDescriptor, before RuntimeContract).
- compact implicit preserve set must include the most recent SemanticImage
  ObsId (extend PROP-008 compact semantics in a patch note).

[S] Signals:
- The four-value ResumeStatus scale (:trusted / :provisional / :downgraded /
  :blocked) gives the lifecycle track a clean decision tree:
  trusted = proceed; provisional = proceed with flags; downgraded = proceed
  with human review; blocked = stop.
- The image_id as a content-addressed root is the formal basis for
  "session equivalence": two sessions that produced the same image_id are
  semantically interchangeable for resume purposes.
- Absorbing PROP-008 ReproducibleResume into CompatibilityReport avoids
  two competing resume-check types. CompatibilityReport is the single source
  of truth for resume decisions.

[Q] Open Questions:
- SemanticImage: full observation_log or summary cursor?
- :downgraded as distinct from :provisional?
- SemanticImage retention policy in TBackend?
- CompatibilityReport: Runtime Machine or external verifier service?

[X] Rejected:
- Resume without CompatibilityReport.
- Mutable SemanticImage.
- Process-memory snapshot as SemanticImage.
- Trust override at resume time.
- :provisional results without qualification marks.

[Next] Proposed next slices:
- Research Agent track: runtime-machine-lifecycle-v0
  (can now reference SemanticImage, CompatibilityReport, ResumeStatus directly)
- Research Agent track: temporal-contracts-and-projections-v0
  (ProjectionRef in SemanticImage; subscribe(SliceRef) for live projections)
- Bridge track: checkpoint/resume implementation
  (cite PROP-008 + PROP-009; :memory TBackend first)
```
