# PROP-011: Runtime Machine Lifecycle v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-006-runtime-contract-specification-v0.md`,
             `proposals/PROP-007-conformance-verification-v0.md`,
             `proposals/PROP-008-tbackend-contract-v0.md`,
             `proposals/PROP-009-semantic-image-resume-compatibility-v0.md`,
             `proposals/PROP-010-temporal-lifecycle-retention-semantics-v0.md`,
             `docs/runtime-machine.md`

---

## Purpose

`runtime-machine.md` defines five lifecycle steps: boot, load, evaluate,
checkpoint, resume. All the necessary formal types now exist across
PROP-006..PROP-010. This proposal assembles the complete formal lifecycle:
each step as a typed contract with inputs, outputs, observations emitted,
and fragment classification.

---

## Lifecycle as a Contract Sequence

```text
RuntimeMachine lifecycle =

  boot(BootInputs)
    -> BootReceipt + AxiomDescriptor obs + RuntimeContract obs + TBackendDescriptor obs

  load(ContractSource)
    -> LoadReceipt + ClassifiedAST obs + descriptor_observations

  evaluate(EvaluationRequest)
    -> EvaluationReceipt + value/constraint/fact/failure observations

  checkpoint(CheckpointPolicy)
    -> CheckpointReceipt + SemanticImage obs + FlushResult obs

  resume(ResumeRequest)
    -> CompatibilityReport obs + (boot | rejection)
```

Each step is a **typed contract** — it has declared inputs, outputs, emitted
observations, temporal context, and fragment classification. No step is
ambient or implicit.

---

## Step 1: Boot

```text
BootInputs = Record {
  axiom_version    : String             -- which AxiomDescriptor version to use
  runtime_config   : RuntimeContract    -- declared runtime promises
  backend_binding  : TBackendDescriptor -- which TBackend to attach
  session_id       : String             -- stable session identity
  started_at       : Timestamp          -- explicit; not ambient clock
}

BootReceipt = Record {
  session_id          : String
  axiom_descriptor_ref: ObsId
  runtime_contract_ref: ObsId
  backend_descriptor_ref: ObsId
  verification_report_ref: Option[ObsId]  -- if verification run at boot
  status              : :ready | :degraded | :blocked
}
```

**Observations emitted (in order):**

```text
1. Obs[:platform_observation, AxiomDescriptor]       (lifecycle: :durable)
2. Obs[:platform_observation, RuntimeContract]        (lifecycle: :durable)
3. Obs[:platform_observation, TBackendDescriptor]     (lifecycle: :durable)
4. Obs[:verification_observation, VerificationReport] (lifecycle: :audit)
   -- if VerificationSuite is run at boot (recommended)
5. Obs[:platform_observation, BootReceipt]            (lifecycle: :durable)
   -- last; signals that the machine is ready for load
```

**[D]** Observations are emitted in this exact order. A consumer that
receives `BootReceipt` knows all three identity descriptors are already
in the TBackend and linked via `observed_under`.

**[D]** `status: :blocked` means the verification report returned
`trust_level: :untrusted`. The machine emits `BootReceipt` with
`:blocked` but does NOT proceed to the `load` step. It must surface
the `VerificationReport` to the operator.

**[D]** `status: :degraded` means `trust_level: :conditional`. The
machine proceeds to `load` but all evaluations carry a
`constraint_observation: :pending` until a re-verification clears it.

**Fragment class:** CORE. Boot is deterministic given the same
`RuntimeContract` and `TBackendDescriptor`. The clock is taken from
`started_at` — explicit, not ambient.

---

## Step 2: Load

```text
LoadInputs = Record {
  source           : ContractSource     -- file, registry, inline
  session_id       : String
  classify_options : FragmentClassifyOptions
}

ContractSource = Record {
  kind     : :file | :registry | :inline
  ref      : String                     -- path, URI, or inline text
  version  : Option[String]
}

FragmentClassifyOptions = Record {
  strict_oof  : Bool   -- reject OOF at load? (default: true)
  escape_allow: Collection[EscapeName]  -- which escapes to permit
}

LoadReceipt = Record {
  session_id       : String
  contracts_loaded : Int
  fragment_report  : ObsId             -- ClassifiedAST observation
  descriptors      : Collection[ObsId] -- one descriptor_observation per contract
  status           : :loaded | :partial | :rejected
}
```

**Observations emitted:**

```text
1. For each contract C:
   Obs[:descriptor_observation, ContractDescriptor]  (lifecycle: :durable)
   -- ContractDescriptor carries: name, type signature, fragment_class, escape_set

2. Obs[:platform_observation, ClassifiedAST]         (lifecycle: :durable)
   -- Pass 0 + Pass 1 output; fragment_class for every node

3. Obs[:platform_observation, LoadReceipt]           (lifecycle: :durable)
```

**[D]** `status: :partial` means some contracts were loaded as CORE,
others were rejected as OOF. The machine proceeds with the loaded subset.
The rejected contracts produce `failure_observation` with
`reason_code: compile.oof_construct`.

**[D]** `status: :rejected` means all contracts failed Pass 0. The
machine does not proceed to `evaluate`. It emits `LoadReceipt` with
`status: :rejected` and halts.

**[D]** Each `descriptor_observation` has `lifecycle: :durable` because
contract definitions must survive restarts (PROP-010 default for
`:descriptor_observation`).

**Fragment class:** CORE. Load is a compile-time step — it runs Pass 0
(fragment classification) and Pass 1 (type checking). No runtime effects.

---

## Step 3: Evaluate

```text
EvaluationRequest = Record {
  session_id   : String
  contract_ref : ContractRef           -- which contract to evaluate
  inputs       : Record                -- input values matching contract signature
  temporal_ctx : TemporalCtx           -- explicit Tt; required
  options      : EvaluationOptions
}

EvaluationOptions = Record {
  observation_emit : :all | :outputs_only | :failures_only
  lifecycle_default: LifecycleClass    -- override default lifecycle for emitted obs
  timeout          : Option[Duration]
  dry_run          : Bool              -- produce intent_obs but no effects
}

EvaluationReceipt = Record {
  session_id      : String
  contract_ref    : ContractRef
  temporal_ctx    : TemporalCtx        -- echo of the Tt used
  status          : :ok | :partial | :failed | :blocked | :timed_out
  output_obs_ids  : Collection[ObsId]  -- value_observation or projection refs
  failure_obs_ids : Collection[ObsId]  -- failure_observation if any
  effect_intents  : Collection[ObsId]  -- intent_observation for declared effects
  effect_receipts : Collection[ObsId]  -- receipt_observation for executed effects
  duration_ms     : Int
}
```

**Observations emitted during evaluation:**

```text
For each resolved node N:
  Obs[:value_observation, T]            (lifecycle: options.lifecycle_default or :session)

For each NamedSlice produced:
  Obs[:value_observation, NamedSlice[T]] (lifecycle: window.lifecycle or :window)

For each constraint check:
  Obs[:constraint_observation, ...]     (lifecycle: :session)

For each declared effect (dry_run: false):
  Obs[:intent_observation, EffectPlan]  (lifecycle: :session -> :durable on receipt)
  Obs[:receipt_observation, EffectReceipt] OR
  Obs[:failure_observation, blocked]    (lifecycle: :durable or :audit)

For each TemporalWindow that closes during evaluation:
  Obs[:receipt_observation, BoundaryReceipt]  (lifecycle: :audit)

On failure:
  Obs[:failure_observation, FailurePayload]   (lifecycle: :session)

On timeout:
  Obs[:failure_observation, ...]
    reason_code: constraint.deadline_unmet
    status: :blocked                          (lifecycle: :session)

After all nodes resolved:
  Obs[:platform_observation, EvaluationReceipt] (lifecycle: :session)
```

**[D]** `temporal_ctx` is **required** in `EvaluationRequest`. An
evaluation without an explicit `TemporalCtx` is OOF (violates Law 6).
The scheduler injects the `ClockContract.as_of_policy` default only if
the contract's `TemporalPolicy` explicitly declares
`as_of_source: :context`.

**[D]** `dry_run: true` produces `intent_observation` packets for all
effects but does not execute them. All `effect_receipts` in the
`EvaluationReceipt` are empty. The executor returns `:blocked` for
each effect in the `failure_obs_ids`.

**[D]** `NamedSlice` outputs: when a contract declares `produces slice:
"name"` (PROP-010 / temporal-contracts-and-projections-v0), the
evaluation produces a `value_observation` carrying `NamedSlice[T]`
in its payload. If `SnapshotSchedule.frequency: :on_close` and the
window closes, `TBackend.snapshot(horizon)` is called automatically.

**Fragment class:** CORE for CORE contracts. ESCAPE when the contract
uses ESCAPE constructs (marked in ClassifiedAST from load step).

---

## Step 4: Checkpoint

```text
CheckpointPolicy = Record {
  scope            : FlushScope        -- from PROP-010
  snapshot_slices  : Collection[SliceName]  -- which named slices to snapshot
  compact_eligible : Bool              -- run compaction after checkpoint?
  retain_local     : Bool              -- keep :local obs past this checkpoint?
}

CheckpointReceipt = Record {
  session_id       : String
  semantic_image   : ObsId            -- the emitted SemanticImage
  flush_result     : ObsId            -- FlushResult observation
  compaction_receipt: Option[ObsId]   -- if compact_eligible: true
  as_of            : TimeRef          -- Tt at checkpoint time
  seq_id           : Int              -- TBackend seq_id at checkpoint
}
```

**Checkpoint sequence:**

```text
1. For each SliceName in snapshot_slices:
   TBackend.snapshot(horizon) -> SnapshotRef
   -> Obs[:fact_observation, SnapshotRef] (lifecycle: :durable)

2. flush(scope) -> FlushResult
   -> Obs[:platform_observation, FlushResult] (lifecycle: :session)
   Flush actions per lifecycle class (PROP-010):
     :local  -> discard (unless open failure evidence)
     :session -> persist to TBackend summary
     :window  -> check boundary receipt; promote if missing
     :durable -> persist; no discard
     :audit   -> archive if policy says; never compact

3. Assemble SemanticImage (PROP-009):
   -> image_id = hash_content(axiom_hash ++ runtime_hash ++ obs_hash ++ checkpoint_id)
   -> Obs[:platform_observation, SemanticImage] (lifecycle: :audit)

4. If compact_eligible: true:
   TBackend.compact(CompactionPolicy {
     preserve: SemanticGCRoots,      -- from PROP-010
     notify_obs: true
   })
   -> Obs[:platform_observation, CompactionReceipt] (lifecycle: :durable)

5. Obs[:platform_observation, CheckpointReceipt] (lifecycle: :durable)
```

**[D]** Checkpoint is a **gate** for compaction. Compaction may only
run after the `SemanticImage` is emitted and its `ObsId` is in the
implicit preserve set. This ensures the image survives its own
checkpoint's compaction.

**[D]** If any `:window` observation fails the boundary receipt check
during flush (PROP-010 DR-2), checkpoint emits:
```text
Obs[:failure_observation, ConstraintViolation]
  reason_code: constraint.lifecycle_violation
  status: :pending
  remediation: "Produce boundary receipt before next compaction"
```
Checkpoint still completes; compaction of affected window is blocked.

**[D]** `lifecycle: :audit` for `SemanticImage` ensures it survives
future compactions and is resolvable for any `CompatibilityReport`
that references it.

**Fragment class:** CORE. Checkpoint is a deterministic, typed
sequence with observable output at every step.

---

## Step 5: Resume

```text
ResumeRequest = Record {
  prior_image_ref  : ObsId            -- Session A's SemanticImage
  session_id       : String           -- Session B's new session_id
  runtime_config   : RuntimeContract  -- Session B's declared runtime
  backend_binding  : TBackendDescriptor
  requested_as_of  : TimeRef          -- where Session B wants to start
  intent           : ResumeIntent     -- from PROP-009
  verification_run : Bool             -- run VerificationSuite before compatibility?
}
```

**Resume sequence:**

```text
1. Boot(BootInputs for Session B)
   -> AxiomDescriptor obs + RuntimeContract obs + TBackendDescriptor obs

2. If verification_run: true:
   VerificationSession(suite_ids: all, as_of: requested_as_of)
   -> Obs[:verification_observation, VerificationReport] (lifecycle: :audit)

3. CompatibilityReport (PROP-009):
   SemanticImage(Session A) + EnvironmentDescriptor(Session B)
   -> Obs[:platform_observation, CompatibilityReport] (lifecycle: :audit)

4. Decision by ResumeStatus:

   :trusted ->
     Load contracts from SemanticImage.contract_descriptors
     Restore from checkpoint: snapshot_ref or replay_cursor
     Obs[:platform_observation, ResumeReceipt { status: :trusted }]

   :provisional ->
     Load contracts
     Restore from checkpoint
     Mark all affected results: constraint_observation: :pending
     Obs[:platform_observation, ResumeReceipt { status: :provisional }]

   :downgraded ->
     Load contracts
     Restore from checkpoint
     All write effects require human approval
     Obs[:platform_observation, ResumeReceipt { status: :downgraded }]

   :blocked ->
     Obs[:failure_observation]
       reason_code: constraint.resume_incompatible
       status: :rejected
       links: [{ rel: :caused_by, ref: compatibility_report_obs_id }]
     -- DO NOT proceed to load or evaluate
```

**[D]** The `CompatibilityReport` observation is emitted **before** any
contract load in Session B. It is the single gate that determines whether
Session B may proceed. No evaluation happens before this gate.

**[D]** Restoration from checkpoint:
- If `intent: :snapshot_load` and `SemanticImage.checkpoint.snapshot_ref`
  exists: load from snapshot. O(1) restore.
- If `intent: :continue` and no snapshot: call
  `TBackend.replay(cursor: SemanticImage.checkpoint.seq_id)`.
  Replay up to the checkpoint seq_id to rebuild session state.
- If `intent: :exact_replay`: full replay from `replay_cursors[0]`
  (beginning). Most expensive; most reproducible.

**Fragment class:** CORE for `:trusted` and `:provisional` resume.
ESCAPE for `:downgraded` resume (human approval required; non-deterministic
gate). OOF for `:blocked` (evaluation must not proceed).

---

## Session Identity and Observation Linking

Every observation emitted during a session carries:

```text
links: [
  { rel: :observed_under, ref: axiom_descriptor_ref,  required: true },
  { rel: :observed_under, ref: runtime_contract_ref,  required: true },
  { rel: :produced_in,    ref: session_id,            required: true }
]
```

This makes every observation traceable to the exact runtime environment
that produced it — required for `CompatibilityReport.reproducibility`
claims and for `VerificationReport` evidence chains.

**[D]** `produced_in` is a non-standard link rel for this proposal.
It carries the `session_id` as a stable string reference, not an `ObsId`,
because session identity is not itself an observation — it is declared
in the `BootReceipt`.

---

## Lifecycle Step × Fragment Classification

| Step | Class | Condition |
|------|-------|-----------|
| Boot | CORE | Deterministic; explicit clock |
| Boot (trust_level: :untrusted) | → `:blocked` status; halts | — |
| Load | CORE | Compile-time; no effects |
| Load (OOF construct) | Rejected at Pass 0 | — |
| Evaluate (CORE contract) | CORE | Deterministic under fixed Tt |
| Evaluate (ESCAPE contract) | ESCAPE | Declared ESCAPE constructs |
| Evaluate (no TemporalCtx) | OOF | Law 6 violation |
| Evaluate (dry_run: true) | CORE | No side effects |
| Checkpoint | CORE | Deterministic sequence; all steps typed |
| Resume (:trusted) | CORE | All compatibility checks pass |
| Resume (:provisional) | ESCAPE | Downgraded dimensions; results flagged |
| Resume (:downgraded) | ESCAPE | Human review required |
| Resume (:blocked) | OOF | Must not evaluate |
| Any step without BootReceipt | OOF | Session identity unestablished |

---

## RuntimeMachineInstance Type (updated from runtime-machine.md)

```text
RuntimeMachineInstance = Record {
  session_id           : String
  status               : :booting | :loading | :ready | :evaluating
                       | :checkpointing | :resuming | :blocked | :shutdown

  -- Descriptor refs (from boot)
  axiom_descriptor_ref : ObsId
  runtime_contract_ref : ObsId
  backend_descriptor_ref: ObsId
  verification_report_ref: Option[ObsId]

  -- Load state
  fragment_report_ref  : Option[ObsId]
  contract_descriptor_refs: Collection[ObsId]

  -- Checkpoint state
  latest_checkpoint    : Option[CheckpointRef]   -- from PROP-009
  latest_semantic_image: Option[ObsId]

  -- Observation routing
  observation_sink     : TBackend                -- where obs are appended
  active_windows       : Collection[TemporalWindow]  -- open windows
  active_subscriptions : Collection[SubscriptionHandle]  -- from TBackend.subscribe
}
```

---

## Open Questions

[Q] Should the VerificationSuite always run at boot, or only before the
first evaluation? Recommendation: always at boot in strict mode; optional
at boot in development mode. Before first evaluation in both modes.

[Q] Should `checkpoint` be triggered automatically (e.g., every N
evaluations, every T seconds) or only explicitly? Recommendation: explicit
trigger in v0 (declared in `CheckpointPolicy.scope`). Automatic triggering
is a runtime extension (ESCAPE).

[Q] Should Session B's `session_id` be derived from Session A's
`session_id` to form a chain? Recommendation: yes — `session_b_id =
hash_content(session_a_id ++ boot_timestamp)`. This makes the resume
chain content-addressed and traceable.

[Q] Should `evaluate` accept a batch of requests (multiple contracts in
one call) or only single contracts? Recommendation: single contract per
call in v0; batch as ESCAPE in v1. Batch evaluation with shared Tt
requires careful observation ordering.

---

## Rejected Paths

[X] Implicit session start (no BootReceipt). Every session must begin
with a `BootReceipt`. Implicit sessions hide runtime identity from the
observation chain.

[X] Load without Pass 0 classification. All contracts must pass through
the fragment classifier before evaluation. Unclassified contracts are OOF.

[X] Evaluate without TemporalCtx. All evaluations require explicit `Tt`.
Ambient clock evaluation is OOF (Law 6).

[X] Checkpoint without SemanticImage emission. A checkpoint that does
not emit a `SemanticImage` observation provides no auditable evidence for
resume. Silent checkpoints are OOF.

[X] Resume without CompatibilityReport. Session B may not evaluate without
a `CompatibilityReport` gate. Silent resume is OOF.

[X] Compaction before checkpoint. Compaction must run after checkpoint
(SemanticImage in preserve set). Pre-checkpoint compaction risks removing
observations needed for the image.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-011
Status: done

[D] Decisions:
- Five lifecycle steps formalised: boot, load, evaluate, checkpoint, resume.
  Each is a typed contract with declared inputs, emitted observations, and
  fragment classification.
- Boot emits: AxiomDescriptor, RuntimeContract, TBackendDescriptor,
  VerificationReport (if run), BootReceipt — in this order.
  trust_level: :untrusted -> :blocked; machine halts.
- Load emits: descriptor_observation per contract, ClassifiedAST,
  LoadReceipt. OOF contracts rejected at Pass 0.
- Evaluate requires explicit TemporalCtx (OOF without it). Emits value,
  constraint, intent, receipt, failure observations per resolved node.
  NamedSlice outputs trigger TBackend.snapshot if SnapshotSchedule fires.
  dry_run: true produces intent_obs but no effect_receipts.
- Checkpoint sequence: snapshot named slices -> flush(scope) ->
  SemanticImage -> compact (if eligible) -> CheckpointReceipt.
  SemanticImage is :audit; always in GC preserve set.
  Compaction runs AFTER SemanticImage is emitted.
- Resume sequence: Boot(B) -> VerificationReport(B) -> CompatibilityReport ->
  decision by ResumeStatus. :blocked = halt. :provisional = proceed with
  constraint_observation: :pending. :downgraded = human approval for effects.
- Restoration: snapshot_load (O(1)) | continue (replay from cursor) |
  exact_replay (full replay from beginning).
- Every observation carries observed_under links to AxiomDescriptor and
  RuntimeContract, plus produced_in: session_id.
- RuntimeMachineInstance type formalised with all state fields.

[R] Recommendations:
- The :memory TBackend (PROP-008) should be the first implementation target
  for the full lifecycle. It enables end-to-end testing of all five steps
  without infrastructure.
- VerificationSuite should run at boot in strict mode, before first evaluate
  in all modes.
- Session B's session_id should be derived from Session A's to form a
  content-addressed resume chain.
- PROP-011 is the capstone of the formal foundation. The bridge
  implementation track may now cite PROP-001..PROP-011 as a complete spec.

[S] Signals:
- The five steps map cleanly to the runtime-machine.md lifecycle with no
  gaps: every step has typed inputs, typed outputs, and typed observations.
- The checkpoint -> compaction ordering rule (emit SemanticImage before
  compact) elegantly resolves the tension between storage efficiency and
  resume safety: compact after you've preserved what you need.
- dry_run: true in evaluate corresponds to the materializer review pattern
  already present in Igniter: produce intent but don't execute.

[Q] Open Questions:
- VerificationSuite: always at boot or before first evaluation?
- Checkpoint: explicit or automatic trigger?
- Session B session_id: derived from Session A?
- Evaluate: single contract or batch per call?

[X] Rejected:
- Implicit session start.
- Load without Pass 0.
- Evaluate without TemporalCtx.
- Checkpoint without SemanticImage.
- Resume without CompatibilityReport.
- Compaction before checkpoint.

[Next] The formal foundation is complete (PROP-001..PROP-011).
Proposed next tracks:
- Bridge implementation: :memory TBackend + boot/load/evaluate/checkpoint
  against the Ruby Igniter platform
- Research Agent: runtime-machine-lifecycle-v0 (operational view of PROP-011)
- Temporal contracts bridge: NamedSlice + BoundaryReceipt in Igniter DSL
```
