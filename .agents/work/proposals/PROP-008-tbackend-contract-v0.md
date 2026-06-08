# PROP-008: TBackend Contract v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-004-type-system-v0.md`,
             `proposals/PROP-005-bridge-observation-envelope-v0.md`,
             `proposals/PROP-006-runtime-contract-specification-v0.md`,
             `proposals/PROP-007-conformance-verification-v0.md`,
             `docs/runtime-machine.md`

---

## Purpose

`runtime-machine.md` establishes:

> **TBackend = temporal substrate contract.** It stores and serves the
> runtime machine's semantic time surface. It is pluggable — Ledger is
> one possible implementation, not the machine itself.

PROP-006 defined the `StorageContract` as a high-level runtime promise.
This proposal defines the **TBackend** formal interface: the typed contract
that any backend implementation must satisfy to serve as the temporal
substrate for the Runtime Machine.

Goals:

1. Formal type signatures for all six TBackend operations:
   `read`, `append`, `replay`, `snapshot`, `compact`, `subscribe`.
2. Capability and fragment classification for each operation.
3. Reproducible resume requirements (what a Session B needs to safely
   continue from Session A).
4. Relation to `StorageContract` (PROP-006) and `VerificationReport` (PROP-007).

---

## Core Claim

[D] A `TBackend` is a **typed, temporal substrate contract** with six
operations. Every operation is typed, observable, and either CORE or ESCAPE.

```text
TBackend[T] = Contract {
  read      : as_of, subject   -> Option[T]
  append    : Obs[kind, T]     -> AppendReceipt
  replay    : ReplayCursor     -> Stream[Obs[kind, T]]   (ESCAPE)
  snapshot  : ProjectionHorizon -> SnapshotRef
  compact   : CompactionPolicy -> CompactionReceipt
  subscribe : SliceRef         -> SubscriptionHandle      (ESCAPE)
}
```

`T` is the payload type of the observations stored. In practice a backend
stores heterogeneous `ObsPacket[kind, Any]`; the `T` parameter is applied
per-read/append call site.

[D] `replay` and `subscribe` are ESCAPE because they produce streams —
potentially unbounded sequences of observations. All other operations are
CORE.

[D] Ledger, Redis-like, file, memory, and remote are **adapters** behind
this interface. They are not language primitives. The language sees only
the typed `TBackend` contract.

---

## Backend Descriptor

Every TBackend must emit a `platform_observation` at bind time:

```text
Obs[:platform_observation, TBackendDescriptor] where TBackendDescriptor = Record {
  backend_id       : String          -- stable identity for this backend instance
  backend_kind     : BackendKind
  version          : String          -- semver
  capabilities     : TBackendCaps
  storage_contract : StorageContract -- from PROP-006; this backend's promises
}

BackendKind = :memory | :file | :ledger | :redis_like | :remote | :custom

TBackendCaps = Record {
  read_as_of       : Bool      -- supports arbitrary as_of reads
  append_atomic    : Bool      -- append is atomic (all-or-nothing)
  replay_enabled   : Bool      -- replay operation is available
  snapshot_enabled : Bool      -- snapshot operation is available
  compact_enabled  : Bool      -- compact operation is available
  subscribe_enabled: Bool      -- subscribe operation is available (ESCAPE)
  max_replay_window: Option[Duration | Int]  -- None = full history
  consistency      : ConsistencyModel        -- from PROP-006
}
```

This descriptor is the `TBackend`'s declaration of which operations are
available and at which semantics. A Runtime Machine that needs `replay`
but binds a backend with `replay_enabled: false` receives a
`capability.unsupported_platform_feature` failure at bind time, not at
replay call time.

---

## Operation 1: read

```text
read : Record {
  subject   : SubjectRef           -- which fact/contract/store to read
  as_of     : TimeRef              -- explicit temporal context (required)
  type_hint : Option[TypeTag]      -- optional: narrow Any to specific T
} -> Record {
  result    : Option[T]            -- None if not found or not visible at as_of
  temporal  : TemporalCtx          -- temporal context of the read result
  evidence  : ObsId                -- links to the underlying fact_observation
}
```

**Fragment class:** CORE when `as_of` is explicit. **OOF** when `as_of` is
absent (ambient read violates Law 6).

**Observation produced:**

```text
Obs[:fact_observation, T] emitted by the backend when a fact is read.
Carries temporal.as_of matching the read request.
```

**Typing rule:**

```text
backend : TBackend[T]
req.as_of is explicit
backend.capabilities.read_as_of = true
──────────────────────────────────────────────────────
backend.read(req) : Option[T]  with temporal evidence
```

**[D]** `read` always returns `Option[T]`. A fact not visible at `as_of`
is `None` — not an error. "Not found at this temporal context" is a valid,
typed result. Callers must handle `None` explicitly.

**[D]** Every `read` produces an underlying `fact_observation` with the
`as_of` point and the result's content hash. This makes reads auditable:
an agent can verify which value was visible at which temporal context.

---

## Operation 2: append

```text
append : Record {
  observation : ObsPacket[kind, T]   -- must be well-formed (PROP-005 WF-1..WF-8)
  idempotency_key: Option[String]    -- for deduplication
} -> Record {
  receipt   : AppendReceipt
  duplicate : Bool                   -- true if idempotency_key already seen
}

AppendReceipt = Record {
  seq_id        : Int                -- monotonic sequence position in backend
  transaction_time: Timestamp        -- when the backend accepted the append
  content_hash  : Hash               -- of the appended observation
  obs_id        : ObsId              -- identity of the appended observation
}
```

**Fragment class:** CORE. Append is a declared effect via `EffectDecl`.

**Observation produced:**

```text
Obs[:receipt_observation, AppendReceipt]
  links: [
    { rel: :caused_by, ref: observation.id, required: true },
    { rel: :materializes, ref: observation.subject, required: false }
  ]
```

**[D]** Append is **idempotent when `idempotency_key` is provided**. The
backend returns `duplicate: true` without re-appending. This is the
`receipt_observation` deduplication model from PROP-005.

**[D]** The `ObsPacket` passed to `append` must satisfy all eight WF rules
from PROP-005. A backend that accepts malformed packets violates its
`TBackendDescriptor.append_atomic` promise and emits a
`failure_observation` with `reason_code: input.schema_violation`.

**[D]** `append_atomic: true` means the append either fully commits (receipt
returned) or fully fails (failure_observation returned). There is no partial
append. Backends that cannot guarantee this must declare
`append_atomic: false` and are ESCAPE.

---

## Operation 3: replay

```text
replay : Record {
  cursor     : ReplayCursor          -- where to start
  filter     : Option[ReplayFilter]  -- kind, subject, or time range filter
  limit      : Option[Int]           -- max observations to return; None = no limit
} -> ReplayStream[Obs[kind, T]]

ReplayCursor = Record {
  anchor     : :seq_id | :timestamp | :fact_id | :beginning
  position   : Int | Timestamp | String  -- value for the chosen anchor
  inclusive  : Bool                  -- include the anchor position itself
}

ReplayFilter = Record {
  kinds      : Option[Collection[ObsKind]]
  subjects   : Option[Collection[SubjectRef]]
  time_range : Option[Record { from: TimeRef, to: TimeRef }]
}

ReplayStream[T] = Record {
  observations : Collection[T]       -- ordered by seq_id
  next_cursor  : Option[ReplayCursor]  -- None when stream is exhausted
  truncated    : Bool                -- true if limit was reached
}
```

**Fragment class:** ESCAPE (`stream_collection`). Replay produces a
potentially large ordered sequence; it is bounded by `limit` but `None`
limit is unbounded.

**Observation produced:**

```text
Obs[:platform_observation, ReplaySessionDescriptor]  at replay start
  subject: "replay://<backend_id>/<cursor>"
  payload: Some(ReplayCursor + ReplayFilter)
```

**[D]** Replay is always **forward-ordered** by `seq_id`. Backwards replay
is OOF — it violates the monotonic observation ordering required by Law 3
(Stratification).

**[D]** `truncated: true` means there are more observations beyond `limit`.
The caller must use `next_cursor` to continue. A caller that ignores
`truncated: true` and acts on a partial replay as if it were complete is
an application bug, not a backend fault. The type makes the truncation
visible.

**Capability requirement:** `backend.capabilities.replay_enabled = true`.
Calling `replay` on a backend that does not support it produces
`capability.unsupported_platform_feature` immediately.

---

## Operation 4: snapshot

```text
snapshot : Record {
  horizon    : ProjectionHorizon     -- from PROP-004; as_of + rule_version + fact_scope
  include    : Option[Collection[SubjectRef]]  -- what to include; None = all
  compress   : Bool
} -> SnapshotRef

SnapshotRef = Record {
  snapshot_id  : String              -- stable content-addressed id
  horizon      : ProjectionHorizon   -- exactly what was snapshotted
  created_at   : Timestamp
  content_hash : Hash                -- over the snapshot payload
  obs_id       : ObsId               -- links to a fact_observation or platform_observation
  size_bytes   : Option[Int]
}
```

**Fragment class:** CORE. Snapshot is a typed, declarative capture of a
`Projection[T, horizon]` materialised into the backend.

**Observation produced:**

```text
Obs[:fact_observation, SnapshotRef]
  subject  : "snapshot://<backend_id>/<snapshot_id>"
  temporal : Some(TemporalCtx { as_of: horizon.as_of })
  links    : [{ rel: :materializes, ref: horizon.fact_scope }]
```

**[D]** A `SnapshotRef` is a **content-addressed** stable reference. Its
`snapshot_id` is derived from the `horizon` and `content_hash`. Two
snapshots taken at the same horizon with the same facts must produce the
same `snapshot_id`. This makes snapshots reproducibility witnesses.

**[D]** Snapshot is the backend operation corresponding to the type-system
concept `Projection[T, horizon]` (PROP-004). The type says what the
projection is; the snapshot materialises it into the backend for fast
retrieval and resume.

**Resume use:** When Session B resumes from Session A, it may load a
`SnapshotRef` instead of replaying from the beginning. The snapshot's
`horizon` defines the temporal point from which Session B continues.

---

## Operation 5: compact

```text
compact : Record {
  policy     : CompactionPolicy
  dry_run    : Bool                  -- if true: plan only, no execution
} -> CompactionReceipt

CompactionPolicy = Record {
  strategy   : :ttl | :segment_seal | :fact_gc | :explicit
  ttl        : Option[Duration]      -- for :ttl strategy
  before_seq : Option[Int]           -- compact observations before this seq_id
  before_time: Option[TimeRef]       -- compact observations before this time
  preserve   : Collection[ObsId]     -- must not be compacted regardless of policy
  notify_obs : Bool                  -- emit platform_observation before executing
}

CompactionReceipt = Record {
  plan_id      : String
  strategy     : CompactionPolicy.strategy
  removed_count: Int
  preserved_count: Int
  new_baseline_cursor: ReplayCursor  -- after compaction, replay starts here
  obs_id       : ObsId               -- platform_observation emitted
}
```

**Fragment class:** CORE (when `dry_run: true` or `notify_obs: true`);
ESCAPE when `notify_obs: false` (silent compaction violates observation
conservation).

**[D]** Compaction with `notify_obs: true` emits:

```text
Obs[:platform_observation, CompactionEvent]
  subject  : "compact://<backend_id>/<plan_id>"
  payload  : Some(CompactionReceipt)
  temporal : Some(TemporalCtx { transaction_time: compaction_time })
```

**[D]** Compaction is **never silent** in a CORE-conformant backend. A
backend that compacts without emitting `platform_observation` violates
PROP-006's `retention.compaction_obs: true` requirement and fails the
`storage.compaction_obs` conformance check (PROP-007).

**[D]** The `preserve` set is a safety anchor: a compaction policy must
not remove any `ObsId` in `preserve`, regardless of strategy. This allows
callers to protect critical observations (e.g., AxiomDescriptor,
RuntimeContract, SnapshotRef obs) from garbage collection.

**[D]** `new_baseline_cursor` defines the new replay start point after
compaction. Session B resuming after compaction must use this cursor, not
a pre-compaction cursor.

---

## Operation 6: subscribe

```text
subscribe : Record {
  slice      : SliceRef              -- which named slice to watch
  cursor     : Option[ReplayCursor]  -- start from here; None = live tail
  filter     : Option[ReplayFilter]
} -> SubscriptionHandle

SliceRef = Record {
  name       : String                -- named slice (from temporal-positioning.md)
  horizon    : Option[ProjectionHorizon]  -- which horizon to watch
}

SubscriptionHandle = Record {
  subscription_id : String
  backend_id      : String
  slice           : SliceRef
  cursor          : ReplayCursor     -- current position in the subscription
  active          : Bool
}
```

**Fragment class:** ESCAPE (`stream_collection`). Subscribe produces a live
stream — potentially unbounded.

**Observation produced at subscribe time:**

```text
Obs[:platform_observation, SubscriptionDescriptor]
  subject  : "subscribe://<backend_id>/<subscription_id>"
  payload  : Some(SubscriptionHandle)
```

**Each delivered observation:**

```text
Obs[kind, T]  -- the actual observation matching the subscription filter
  links: [{ rel: :observed_under, ref: subscription_id }]
```

**[D]** Subscriptions deliver observations in **seq_id order** within a
backend. Cross-backend delivery order is undefined (DistributedContract
ESCAPE rules apply). A consumer must not assume global ordering across
multiple subscriptions.

**[D]** A `SliceRef` connects `subscribe` to the `temporal-positioning.md`
concept of a **named slice**: a named, time-indexed cut through contract
outputs. The backend delivers observations matching the slice's horizon and
filter as they are appended. This is the live-projection model for reactive
agents and materializers.

**Capability requirement:** `backend.capabilities.subscribe_enabled = true`.
Backends that do not support subscribe (e.g., `:file`, `:memory`) must
return `capability.unsupported_platform_feature`.

---

## Reproducible Resume Requirements

From `runtime-machine.md`:

> Session B resumes from: same or superseding descriptors, compatible runtime
> contract, replay cursor or snapshot, explicit temporal context, conformance
> verification evidence.

Formally, a Session B can claim **reproducible resume** from Session A if
and only if:

```text
ReproducibleResume = Record {
  -- Identity: what was Session A?
  session_a_id        : String
  axiom_descriptor_ref: ObsId     -- Session A's AxiomDescriptor
  runtime_contract_ref: ObsId     -- Session A's RuntimeContract

  -- Compatibility: is Session B compatible?
  axiom_compatible    : Bool      -- same AxiomDescriptor version or declared supersede
  runtime_compatible  : Bool      -- same or compatible RuntimeContract version
  verification_ref    : ObsId     -- Session B's VerificationReport (trust != :untrusted)

  -- Temporal continuity: where does Session B start?
  resume_anchor       : :snapshot | :replay_cursor | :beginning
  snapshot_ref        : Option[SnapshotRef]
  replay_cursor       : Option[ReplayCursor]
  as_of              : TimeRef    -- Session B's starting Tt

  -- Evidence chain: what links the sessions?
  checkpoint_obs_ids  : Collection[ObsId]  -- Session A's checkpoint observations
}
```

**[D]** Resume is **not reproducible** if:

| Condition | Failure reason |
|-----------|---------------|
| `axiom_compatible: false` | Semantic domain has changed; prior results may not be valid |
| `runtime_compatible: false` | Execution promises changed; cache/storage/capability behaviour differs |
| `verification_ref` has `trust_level: :untrusted` | Backend cannot be trusted for this session |
| `resume_anchor: :snapshot` but `snapshot_ref` is None | No snapshot; must replay from beginning |
| `as_of` is earlier than `snapshot_ref.horizon.as_of` | Temporal regression; facts at as_of may be lost |

**[D]** When any of the above conditions fails, Session B must emit a
`failure_observation` with `reason_code: constraint.resume_incompatible`
and `status: :rejected` before any user contract evaluation. It must NOT
silently evaluate contracts with stale or incompatible semantics.

---

## TBackend and StorageContract Relation

The `TBackend` is the **implementation interface** of the `StorageContract`
from PROP-006:

| StorageContract field | TBackend operation |
|-----------------------|--------------------|
| `store_type` | `TBackendDescriptor.backend_kind` |
| `consistency.model` | `TBackendDescriptor.capabilities.consistency` |
| `replay.enabled` | `TBackendDescriptor.capabilities.replay_enabled` |
| `replay.cursor_type` | `ReplayCursor.anchor` options |
| `replay.snapshot` | `TBackendDescriptor.capabilities.snapshot_enabled` |
| `retention.compaction_obs` | `CompactionPolicy.notify_obs` |

A `StorageContract` is a **promise** (declared by PROP-006). A `TBackend`
is the **typed interface** that a backend must implement to fulfil that
promise. A `VerificationReport` (PROP-007) checks that the implementation
matches the declaration.

---

## Fragment Classification Summary

| Operation | Class | Condition |
|-----------|-------|-----------|
| `read` (explicit as_of) | CORE | as_of declared; capability.read_as_of = true |
| `read` (no as_of) | OOF | Violates Law 6 |
| `append` (atomic, well-formed) | CORE | WF-1..WF-8 satisfied; atomic backend |
| `append` (non-atomic) | ESCAPE | append_atomic: false |
| `replay` (bounded, cursor) | ESCAPE `stream_collection` | Potentially large stream |
| `snapshot` | CORE | Typed, content-addressed; uses ProjectionHorizon |
| `compact` (notify_obs: true) | CORE | Observable compaction |
| `compact` (notify_obs: false) | ESCAPE | Silent compaction; Law 5 risk |
| `subscribe` | ESCAPE `stream_collection` | Live unbounded stream |
| Resume without VerificationReport | OOF | Unverified runtime trust |
| Resume with trust_level: :untrusted | OOF | Critical verification failure |

---

## Backend Adapter Classes

The five adapter classes from `runtime-machine.md` and their capability profiles:

| Backend | read | append | replay | snapshot | compact | subscribe | Class |
|---------|------|--------|--------|----------|---------|-----------|-------|
| `:memory` | CORE | CORE | ESCAPE | CORE | CORE | ESCAPE | CORE baseline |
| `:file` | CORE | CORE | ESCAPE | CORE | CORE | OOF | CORE (no subscribe) |
| `:ledger` | CORE | CORE | ESCAPE | CORE | CORE | ESCAPE | CORE baseline |
| `:redis_like` | CORE | CORE | ESCAPE | CORE | CORE | ESCAPE | CORE + subscribe |
| `:remote` | CORE | CORE | ESCAPE | CORE | CORE | ESCAPE | ESCAPE (distributed) |

**[D]** `:remote` backend is always ESCAPE because it introduces network
latency, potential partitions, and cross-node clock skew — all of which
require `DistributedContract` (PROP-006 §7).

**[D]** `:memory` backend is the **reference implementation** for conformance
testing. It is in-process, synchronous, and has deterministic behaviour.
Conformance checks (PROP-007) for any other backend compare against the
`:memory` baseline under identical inputs and `Tt`.

---

## Open Questions

[Q] Should `read` support **range reads** (read all facts for a subject
between `as_of_from` and `as_of_to`)? Recommendation: yes, as a bounded
ESCAPE operation — `read_range` with explicit time bounds and a `limit`.
Defer to v1; mark as reserved name `read_range`.

[Q] Should `subscribe` be a pull model (caller fetches next batch) or
push model (backend delivers observations)? Recommendation: pull in v0
(cursor-based, similar to `replay`). Push delivery is ESCAPE and requires
a network contract (WebSocket, SSE, gRPC stream) which is a bridge concern.

[Q] Should `compact` require explicit `preserve` declarations or derive them
from the active `SnapshotRef` and `RuntimeContract` observation IDs?
Recommendation: both. `preserve` is explicit; the backend also implicitly
preserves the most recent `SnapshotRef`, `AxiomDescriptor`, and
`RuntimeContract` platform observations even if not listed.

[Q] Is there a `TBackend` operation for **deleting** an observation?
Recommendation: No. Observations are append-only. Deletion is a policy
concern handled by `compact`. Explicit deletion would violate content-address
stability (WF-8 from PROP-005).

---

## Rejected Paths

[X] Ledger as mandatory backend. The language must not require Ledger.
TBackend is pluggable; Ledger is one adapter.

[X] Ambient state reads (no as_of). All reads must carry explicit temporal
context. Ambient reads are OOF.

[X] Silent compaction. Compaction that removes observations without a
platform_observation violates Law 5 and fails PROP-007 `storage.compaction_obs`.

[X] Mutable observation IDs. Once appended, an observation's `id` is
permanent. Mutation violates WF-8 and breaks resume identity.

[X] Backwards replay. Replay is always forward (seq_id order). Backwards
traversal requires a snapshot + forward replay from an earlier point.

[X] Global ordering across backends. Cross-backend ordering is undefined.
Distributed ordering is ESCAPE and requires DistributedContract.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-008
Status: done

[D] Decisions:
- TBackend[T] has six typed operations: read, append, replay, snapshot,
  compact, subscribe.
- read and append are CORE; replay and subscribe are ESCAPE (stream_collection);
  snapshot is CORE; compact is CORE when notify_obs: true, ESCAPE when silent.
- read without explicit as_of is OOF (Law 6 violation).
- append is idempotent with idempotency_key. Backends declare append_atomic:
  bool; non-atomic backends are ESCAPE.
- ReplayCursor has four anchor types: :seq_id, :timestamp, :fact_id, :beginning.
  Backwards replay is OOF.
- snapshot materialises Projection[T, horizon] into the backend. SnapshotRef
  is content-addressed; same horizon + same facts = same snapshot_id.
- compact is never silent in a CORE-conformant backend. preserve set protects
  critical observations from GC.
- subscribe delivers observations in seq_id order within a backend. Cross-backend
  ordering is undefined.
- ReproducibleResume requires: axiom_compatible, runtime_compatible,
  trust_level != :untrusted, valid resume anchor, no temporal regression.
- :memory backend is the reference implementation for conformance testing.
- :remote backend is always ESCAPE (network partitions, clock skew).
- Ledger is one adapter; it is not mandatory.

[R] Recommendations:
- The :memory TBackend should be the first implementation target —
  it enables all PROP-001..PROP-007 formal semantics with zero infrastructure.
- Add TBackendDescriptor to the session boot sequence: emit before
  RuntimeContract observation (it is a dependency of RuntimeContract).
- The SnapshotRef.snapshot_id content-addressing rule should use hash_content
  from PROP-004b (same canonical hash function as all other content addresses).
- Research Agent track: runtime-machine-lifecycle-v0 should use TBackend
  operations to specify the boot/load/evaluate/checkpoint/resume lifecycle.

[S] Signals:
- The six TBackend operations map directly to the runtime-machine.md lifecycle:
  read -> evaluate; append -> emit observations; replay -> resume;
  snapshot -> checkpoint; compact -> retention; subscribe -> reactive projections.
- SnapshotRef as a content-addressed reproducibility witness elegantly solves
  the "what was the state at that point?" question: if two sessions produce the
  same snapshot_id for the same horizon, they saw the same facts.
- The pull-model subscribe (cursor-based) is the right ESCAPE choice for v0:
  it has the same cursor semantics as replay, making the two operations
  interchangeable for testing purposes.

[Q] Open Questions:
- read_range as a bounded ESCAPE operation in v1?
- subscribe: pull vs. push model?
- compact: explicit preserve vs. implicit protection of key descriptors?
- Is there a delete operation? (Recommendation: no.)

[X] Rejected:
- Ledger as mandatory backend.
- Ambient reads without as_of.
- Silent compaction.
- Mutable observation IDs.
- Backwards replay.
- Global ordering across backends.

[Next] Proposed next slices:
- Research Agent track: runtime-machine-lifecycle-v0
  (boot/load/evaluate/checkpoint/resume using TBackend operations)
- Research Agent track: temporal-contracts-and-projections-v0
  (subscribe + SliceRef = live projection model; snapshot = reproducible slice)
- Bridge track: :memory TBackend implementation
  (first concrete adapter; reference for conformance testing)
```
