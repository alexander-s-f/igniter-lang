# PROP-006: Runtime Contract Specification v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-001-semantic-domain-v0.md`,
             `proposals/PROP-004-type-system-v0.md`,
             `proposals/PROP-004b-axiom-layer-type-signatures-v0.md`,
             `proposals/PROP-005-bridge-observation-envelope-v0.md`,
             `docs/axiomatic-contract-model.md`

---

## Purpose

`axiomatic-contract-model.md` declares:

> **Runtime = contract over execution of contracts.**
>
> A runtime is not just "where code runs." It is a contract that promises
> how contract evaluation behaves.

PROP-004b defined the Tier 2 runtime contracts (clock, randomness, storage,
capability executor) as typed handles. This proposal formalizes the
**RuntimeContract** itself: the top-level typed declaration that a runtime
must expose, covering scheduler, clock, cache/invalidation, storage/replay,
capability executor, and distributed composition.

This is a **formal specification only**. No implementation. No Ruby changes.
No package edits.

---

## Compact Claim

[D] A `RuntimeContract` is a versioned, typed, observable declaration of
how a runtime executes user contracts. It is not a configuration file and
not ambient environment. It is a first-class semantic artifact that:

1. Declares which language fragment is supported (CORE / ESCAPE capabilities).
2. Promises specific behaviours for scheduler, clock, cache, storage, and
   capability execution.
3. Exposes its promises as `Obs[:platform_observation, RuntimeDescriptor]`
   packets before the first evaluation.
4. Is itself verifiable: a conformance check can compare declared promises
   against observed behaviour.

```text
eval(G, Tt, inputs)
  under  LanguageContract (PROP-001..PROP-005)
  under  RuntimeContract  (this proposal)
  ->     outputs | observations | failures
```

Both contracts must be in force for an evaluation to be semantically
meaningful and reproducible.

---

## RuntimeContract Type

```text
RuntimeContract = Record {
  id               : String              -- stable runtime identity
  version          : String              -- semver
  language_version : String              -- which Igniter-Lang spec version

  -- Fragment support
  fragment         : FragmentSupport

  -- Sub-contracts (one per concern)
  scheduler        : SchedulerContract
  clock            : ClockContract
  cache            : CacheContract
  storage          : StorageContract
  capability       : CapabilityContract

  -- Distributed composition (ESCAPE)
  distributed      : Option[DistributedContract]

  -- Axiom descriptor link
  axiom_descriptor : AxiomDescriptor     -- from PROP-004b
}
```

The `RuntimeContract` is emitted as an `Obs[:platform_observation, RuntimeDescriptor]`
at the start of every evaluation session, before any user contract runs.
Evaluations that proceed without a visible `RuntimeContract` observation are
flagged with `platform.backend_unavailable`.

---

## 1. Fragment Support

```text
FragmentSupport = Record {
  core_fragment    : Bool                -- always true for any conformant runtime
  escape_set       : Collection[EscapeName]  -- which named escapes are supported
  oof_enforcement  : Bool               -- does runtime enforce OOF rejection?
}
```

**[D]** A conformant runtime must support the full CORE fragment. If it does
not, it must declare `core_fragment: false` and the evaluation is flagged
`platform.unsupported_platform_feature` for any CORE construct it cannot
execute.

**[D]** `oof_enforcement: true` means the runtime actively rejects OOF
constructs at evaluation time (in addition to compile-time Pass 0 rejection).
Runtimes that receive pre-validated ClassifiedAST may set this to `false`
when they trust the compiler's Pass 0 output.

**[D]** The `escape_set` declares which ESCAPE groups are supported. A
contract using `causal_clock` escape on a runtime that does not list it
in `escape_set` receives a `capability.unsupported_platform_feature` failure.

---

## 2. SchedulerContract

```text
SchedulerContract = Record {
  model            : :sequential | :concurrent | :parallel
  concurrency_max  : Option[Int]        -- max parallel evaluations; None = unbounded
  evaluation_order : :demand_driven | :eager | :topological
  isolation        : :shared | :isolated | :transactional
  timeout_policy   : TimeoutPolicy
  observation_emit : :inline | :async | :batched
}
```

### Guarantees by model

| Model | Guarantee |
|-------|-----------|
| `:sequential` | One evaluation at a time. No concurrency. Deterministic order. |
| `:concurrent` | Multiple evaluations may overlap. No shared mutable state between contracts. |
| `:parallel` | Explicit `||` and `over` compositions may execute in parallel. Result order is deterministic (by port name), completion order is not. |

**[D]** `evaluation_order: :demand_driven` is the CORE semantic (Law 1:
Result-orientation). Runtimes using `:eager` or `:topological` order must
prove that their order produces the same results as demand-driven evaluation
for all CORE contracts. If they cannot, they must declare the difference as
a `platform_observation` with `semantics_divergence: true`.

**[D]** `isolation: :transactional` means the runtime provides atomic
evaluation: either all effects in a contract execution are committed or none
are. This is ESCAPE (it requires transactional storage support). CORE
isolation is `:shared` with no cross-contract mutation guarantees.

```text
TimeoutPolicy = Record {
  enabled         : Bool
  default_deadline: Option[Duration]    -- None = no default
  on_timeout      : :failure | :partial -- partial = emit available results + failure
  timeout_obs     : Bool                -- emit Obs[:failure_observation] on timeout?
}
```

**[D]** Timeout failures emit `failure_observation` with
`reason_code: constraint.deadline_unmet` and `status: :blocked`. They are
observable; they are not silent terminations.

---

## 3. ClockContract

```text
ClockContract = Record {
  source           : :wall | :monotonic | :logical | :test
  resolution       : Duration           -- minimum measurable interval
  drift_bound      : Option[Duration]   -- max drift from true UTC; None = unknown
  as_of_policy     : AsoPolicy
  version          : String             -- clock source version / reference epoch
}

AsoPolicy = Record {
  allows_caller_supplied : Bool         -- caller may pass explicit as_of
  allows_context_supplied: Bool         -- execution context may supply as_of
  allows_store_consistency: Bool        -- store consistency model supplies as_of
  allows_replay          : Bool         -- replay cursor may supply as_of
  default_source         : :caller | :context | :store | :wall | :logical
}
```

**[D]** The `ClockContract` is the formal backing for `TemporalCtx[policy]`
from PROP-004. A `TemporalCtx` with `requires_as_of: true` is only satisfiable
if the `ClockContract.as_of_policy` permits the declared `as_of_source`.

**[D]** Clock source `:test` is a special ESCAPE source for deterministic
testing: the clock is a declared input value, not a host resource. Contracts
evaluated under `:test` clock are fully reproducible (same inputs → same
outputs) because time is a value.

**[D]** `drift_bound: None` means the clock makes no drift promise. Any
contract that requires freshness guarantees (e.g., `freshness.lag_sla`) must
check that the clock's `drift_bound` satisfies the SLA. If it does not,
the constraint check emits `temporal.freshness_lag_exceeded`.

**Observation emitted at session start:**

```text
Obs[:platform_observation, ClockDescriptor] = {
  subject  : "clock://<runtime_id>/<clock_version>"
  payload  : Some(ClockContract)
  temporal : Some(TemporalCtx { transaction_time: session_start_time })
}
```

---

## 4. CacheContract

```text
CacheContract = Record {
  enabled         : Bool
  strategy        : :demand | :eager | :write_through | :none
  invalidation    : InvalidationPolicy
  scope           : :node | :contract | :session | :global
  observation_emit: :on_hit | :on_miss | :on_invalidation | :never
}

InvalidationPolicy = Record {
  model      : :dependency_graph | :ttl | :explicit | :none
  ttl        : Option[Duration]         -- for :ttl model
  cascade    : Bool                     -- does invalidating a node invalidate dependents?
}
```

**[D]** Cache invalidation is a **semantic event**, not a runtime internal.
When `observation_emit` includes `:on_invalidation`, the runtime emits an
`Obs[:platform_observation, CacheInvalidation]` packet. This makes cache
invalidation observable and auditable.

**[D]** `strategy: :none` means no caching. Every evaluation recomputes.
This is the safest default for reproducibility: results always reflect
current inputs. Other strategies trade reproducibility for performance.

**Cache and Observation Conservation (Law 5):**

If a node's result is cached and a dependency changes, the cache must be
invalidated before the next evaluation. If it is not, the runtime violates
Law 5 (Observation Conservation): a changed dependency did not produce a
changed result. The `InvalidationPolicy` is the runtime's declared promise
about when this is guaranteed.

**[D]** `cascade: true` means invalidating a node also invalidates all
nodes that depend on it (transitively). This is the only model that fully
preserves Law 5. `cascade: false` is ESCAPE: the runtime may serve stale
derived values until explicit re-evaluation.

---

## 5. StorageContract

```text
StorageContract = Record {
  store_type       : :in_memory | :ledger | :external | :hybrid
  consistency      : ConsistencyModel
  replay           : ReplaySupport
  retention        : RetentionPolicy
  observation_emit : :on_write | :on_read | :on_replay | :never
}

ConsistencyModel = Record {
  model      : :strong | :eventual | :causal | :bounded_staleness | :session
  read_your_writes: Bool
  monotonic_reads : Bool
  lag_bound       : Option[Duration]    -- for :bounded_staleness
}

ReplaySupport = Record {
  enabled     : Bool
  cursor_type : :sequence | :timestamp | :fact_id | :none
  horizon     : Option[Duration | Int]  -- max replay window; None = full history
  snapshot    : Bool                    -- supports snapshot reads?
}

RetentionPolicy = Record {
  default_ttl     : Option[Duration]    -- None = forever
  compaction      : Bool
  compaction_obs  : Bool                -- emit platform_observation on compaction?
}
```

**[D]** The `ConsistencyModel` backs the `TemporalCtx.as_of_source:
:store_consistency` from PROP-004. If a contract reads from a store with
`as_of_source: :store_consistency`, the `ConsistencyModel` determines what
"consistent" means. This must be declared, not assumed.

**[D]** Replay is a first-class `StorageContract` capability, not an
afterthought. If `ReplaySupport.enabled: false`, contracts may not use
`History[T]` replay operations (they emit `platform.unsupported_platform_feature`).

**[D]** Compaction is observable. When `retention.compaction_obs: true`, the
runtime emits `Obs[:platform_observation, CompactionEvent]` when compaction
occurs. This allows consumers to know when a fact's raw history may no longer
be available — critical for reproducibility claims.

**Consistency model and Observation Conservation:**

| Consistency | Law 5 (Observation Conservation) status |
|-------------|----------------------------------------|
| `:strong` | Full: every write is immediately visible to all readers |
| `:causal` | Partial: causally-related reads are consistent; concurrent writes may diverge |
| `:eventual` | ESCAPE: results may differ between evaluations at different nodes |
| `:bounded_staleness` | ESCAPE: results within `lag_bound` window are acceptable |
| `:session` | Partial: read-your-writes guaranteed within a session |

**[D]** Only `:strong` consistency fully satisfies Law 5 for distributed
reads. `:eventual` and `:bounded_staleness` are ESCAPE — they require the
`causal_clock` or `platform_extension_code` escape annotations on contracts
that use them.

---

## 6. CapabilityContract

```text
CapabilityContract = Record {
  executor_model   : :inline | :async | :approval_gated | :dry_run_only
  capability_set   : Collection[CapabilityDescriptor]
  audit_obs        : Bool               -- emit obs for every capability check?
  approval_required: Collection[CapabilityName]  -- subset requiring human approval
  grants_by_default: Bool               -- false = all capabilities denied by default
}

CapabilityDescriptor = Record {
  name      : String
  kind      : :read | :write | :execute | :approve | :audit
  scope     : String                    -- what the capability governs
  revocable : Bool
  version   : String
}
```

**[D]** `grants_by_default: false` is the **required** CORE runtime posture.
A conformant runtime denies all capabilities by default. Every capability
must be explicitly granted through a declared `CapabilityDescriptor` and,
for `approval_required` capabilities, through a human approval receipt.

**[D]** `executor_model: :dry_run_only` means the runtime never executes
effects — it produces `intent_observation` packets and `failure_observation`
with `status: :blocked`. This is the safe default for materializer and agent
review flows.

**[D]** `audit_obs: true` means the runtime emits a `capability_observation`
for every capability check (granted, denied, or consumed). This makes
capability decisions observable and auditable — agents and humans can inspect
which capabilities were active during any evaluation.

**Capability and Observation Spine:**

```text
capability_check ->
  Obs[:constraint_observation, CapabilityCheckResult] when audit_obs: true

effect execution ->
  Obs[:intent_observation, EffectPlan]
  Obs[:receipt_observation, EffectReceipt]  (when executed)
  Obs[:failure_observation, blocked]        (when not executed)
```

---

## 7. Distributed Runtime Composition (ESCAPE)

```text
DistributedContract = Record {
  topology         : :federation | :cluster | :peer | :hierarchical
  node_contracts   : Collection[RuntimeNodeContract]
  synchronization  : SyncPolicy
  partition        : PartitionPolicy
  observation_sync : ObsSyncPolicy
}

RuntimeNodeContract = Record {
  node_id          : String
  runtime_contract : RuntimeContract     -- recursive: each node has its own RC
  temporal_horizon : TemporalCtx         -- this node's time base
  reachability     : :always | :eventual | :unknown
}

SyncPolicy = Record {
  model      : :synchronous | :eventual | :causal | :none
  clock_sync : :ntp | :ptp | :logical | :none
  max_skew   : Option[Duration]
}

PartitionPolicy = Record {
  tolerance  : :yes | :no | :bounded
  on_partition: :fail_fast | :continue_degraded | :read_only
}

ObsSyncPolicy = Record {
  dedup_by_identity: Bool               -- dedup using Identity group
  merge_provenance : Bool               -- merge provenance on re-emission
  conflict_model   : :last_writer | :crdt | :manual | :none
}
```

**[D]** Distributed runtime composition is always ESCAPE. A single isolated
runtime may be CORE; adding a distributed layer introduces non-determinism
in observation ordering, potential split-brain, and clock skew — none of
which are decidable from a pure language perspective.

**[D]** The `observation_sync.dedup_by_identity` field references PROP-005's
Identity group: when `true`, observations received from multiple nodes are
deduplicated using `(id, space, kind)` — the same equivalence rule used
by single-node runtimes. This ensures distributed observation deduplication
is consistent with the formal envelope spec.

**[D]** `on_partition: :continue_degraded` must emit a `failure_observation`
with `status: :degraded` and `reason_code: diagnostic.delivery_degraded`.
It must NOT silently serve potentially inconsistent data without a
degraded-status observation.

**Distributed Composition and Observation Conservation:**

For a distributed evaluation to satisfy Law 5, all nodes must use either:
- the same fixed `Tt` (fully reproducible), or
- a declared causal consistency model (`SyncPolicy.model: :causal`) with
  documented bounds.

A distributed evaluation without a declared `SyncPolicy` violates Law 5 and
must emit `platform.unsupported_platform_feature` for any reproducibility
claims.

---

## 8. Relation between RuntimeContract and AxiomDescriptor

From PROP-004b, the `AxiomDescriptor` declares the built-in function set and
its versioning. The `RuntimeContract` is a higher-level contract that uses
the `AxiomDescriptor` as a component:

```text
RuntimeContract
  |
  +-- axiom_descriptor : AxiomDescriptor    -- which built-ins and at which version
  |     |
  |     +-- axiom_group   : :arithmetic | :string | :structural | :clock | ...
  |     +-- version       : String
  |     +-- hash_algorithm: String          -- for hash_content
  |     +-- capabilities  : [EscapeName]    -- supported ESCAPE groups
  |
  +-- clock.version    links to AxiomDescriptor.clock_version
  +-- storage.store_type determines which storage built-ins are active
  +-- capability.executor_model determines which effect built-ins are active
```

**[D]** The `AxiomDescriptor` answers "which language-level built-ins are
available and at which version." The `RuntimeContract` answers "how those
built-ins and user contracts are executed." They are complementary:

| Concern | Answered by |
|---------|-------------|
| `add(1, 2) = 3`? | AxiomDescriptor (arithmetic group, deterministic) |
| Does clock return wall time or test time? | RuntimeContract.clock |
| Is hash_content SHA-256 or BLAKE3? | AxiomDescriptor.hash_algorithm |
| Is storage eventually or strongly consistent? | RuntimeContract.storage.consistency |
| Are capabilities deny-by-default? | RuntimeContract.capability |
| Is parallel execution supported? | RuntimeContract.scheduler.model |

**[D]** Reproducibility requires BOTH to be fixed:
- Same AxiomDescriptor version → same built-in semantics
- Same RuntimeContract version → same execution behaviour

A result that claims reproducibility must cite both via `observed_under` links
to the `Obs[:platform_observation, AxiomDescriptor]` and
`Obs[:platform_observation, RuntimeDescriptor]` packets emitted at session
start.

---

## Conformance Levels

A runtime may declare its conformance level:

```text
RuntimeConformance = Record {
  level    : :core_only | :core_plus_escape | :distributed
  verified : Bool           -- has conformance been externally verified?
  caveats  : Collection[String]  -- known deviations with descriptions
}
```

| Level | Guarantees |
|-------|-----------|
| `:core_only` | Full CORE fragment; no ESCAPE; no distribution; full Law 5 |
| `:core_plus_escape` | CORE + declared ESCAPE set; Law 5 for CORE; partial for ESCAPE |
| `:distributed` | CORE + ESCAPE + DistributedContract; Law 5 only with fixed Tt |

**[D]** `:core_only` is the gold standard for reproducibility. Any
`Projection[T, horizon]` produced under a `:core_only` runtime with a fixed
`Tt` is **fully reproducible**: given the same `AxiomDescriptor` version,
`RuntimeContract` version, `Tt`, and inputs, the result is identical.

---

## RuntimeContract as Platform Observation

The full `RuntimeContract` is emitted at session start:

```text
Obs[:platform_observation, RuntimeDescriptor] = {
  schema_version : 1
  kind           : :platform_observation
  observation_id : hash(runtime_id + version + session_id)
  space          : "runtime://<runtime_id>"
  subject        : "runtime://<runtime_id>/contract/<version>"
  status         : :observed
  producer       : ProducerRef { kind: :platform, id: runtime_id, version: version }
  observed_at    : session_start_timestamp
  content_hash   : hash(canonical(RuntimeContract))
  privacy        : PrivacyPolicy { payload_policy: :present }
  links          : [
    { rel: :describes, ref: "runtime://<runtime_id>" },
    { rel: :observed_under,
      ref: axiom_descriptor_obs_id }   -- links to AxiomDescriptor observation
  ]
  payload        : Some(RuntimeContract)
}
```

All evaluations in the session carry an `observed_under` link to this
platform observation. This makes the runtime's promises part of every
observation's provenance chain.

---

## Fragment Classification

| Construct | Class | Reason |
|-----------|-------|--------|
| `RuntimeContract` declaration | CORE | It is a descriptor; not evaluated |
| Reading `RuntimeContract` fields | CORE | Read-only; typed |
| Single-runtime evaluation | CORE | Deterministic under fixed Tt |
| Multi-runtime composition | ESCAPE | Non-deterministic ordering possible |
| Distributed evaluation (`:distributed`) | ESCAPE | Clock skew, partition risk |
| Evaluation without visible RuntimeContract | OOF | `platform.backend_unavailable` |
| Mutable RuntimeContract mid-session | OOF | Violates observation conservation |

---

## Open Questions

[Q] Should `RuntimeContract` version changes mid-session be allowed? If a
runtime upgrades during a session (rolling deploy), the `RuntimeContract`
changes. Recommendation: emit a superseding `Obs[:platform_observation, ...]`
with `links: [{ rel: :supersedes, ref: old_obs_id }]`. Evaluations after
the supersede use the new contract. Evaluations in-flight at supersede time
carry both links.

[Q] Should `StorageContract.consistency` be per-store or per-runtime?
In practice, different stores may have different consistency models.
Recommendation: `StorageContract` is a runtime-level default; individual
`Store[T]` and `History[T]` types may carry per-instance `ConsistencyModel`
overrides declared in their `descriptor_observation`.

[Q] Should `CapabilityContract.approval_required` be a set of names or a
typed policy rule? Names are simpler; rules allow conditional approval.
Recommendation: names in v0; typed approval policies in v1.

[Q] Should `DistributedContract` support heterogeneous runtimes (nodes with
different `RuntimeContract` versions)? Recommendation: yes, but only with
`SyncPolicy.model: :none` or explicit version reconciliation. Heterogeneous
distribution is ESCAPE.

---

## Rejected Paths

[X] Runtime as ambient environment (no formal declaration). If the runtime
does not declare its promises, contracts cannot be validated against them.
This is the primary antipattern this proposal eliminates.

[X] Single global `RuntimeContract` singleton. Each runtime instance must
have its own versioned `RuntimeContract`. Singletons prevent multi-runtime
composition.

[X] Cache invalidation as internal-only. Cache invalidation is a semantic
event (it affects observation conservation). It must be observable when it
occurs.

[X] Distributed composition as CORE. Non-deterministic observation ordering
and partition behavior are not decidable from the language level. Distribution
is always ESCAPE.

[X] Capability grants by default. All capabilities must be explicitly granted.
Default-grant runtimes violate the no-hidden-capability-grant principle from
`observable-spine-v0` and `failure-observation-v0`.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-006
Status: done

[D] Decisions:
- RuntimeContract is a versioned, typed, observable declaration with six
  sub-contracts: FragmentSupport, SchedulerContract, ClockContract,
  CacheContract, StorageContract, CapabilityContract.
- Distributed composition is a seventh optional sub-contract (ESCAPE).
- RuntimeContract is emitted as Obs[:platform_observation, RuntimeDescriptor]
  at session start. All evaluations carry observed_under link to it.
- The AxiomDescriptor (PROP-004b) is a component of RuntimeContract:
  AxiomDescriptor answers "which built-ins at which version";
  RuntimeContract answers "how they are executed."
- Reproducibility requires BOTH AxiomDescriptor AND RuntimeContract to be
  fixed. Results citing reproducibility must link to both platform_observation
  packets.
- Distributed composition is always ESCAPE. Single-runtime evaluation is CORE
  when Tt is fixed and storage is :strong or :causal.
- Cache invalidation cascade: cascade: true is required for full Law 5
  compliance. cascade: false is ESCAPE (stale derived values possible).
- capability grants_by_default: false is required for CORE conformance.
- Evaluation without a visible RuntimeContract is OOF (platform.backend_unavailable).
- Three conformance levels: core_only (gold standard), core_plus_escape, distributed.

[R] Recommendations:
- Emit RuntimeContract and AxiomDescriptor platform_observations as the very
  first packets of every evaluation session, before any user contract runs.
- The bridge implementation track should add RuntimeContract emission to the
  existing Igniter::Contracts execution path.
- Research Agent track: temporal-contracts-and-projections-v0 should reference
  ClockContract and StorageContract.replay when specifying named slice
  reproducibility guarantees.
- Consider PROP-007: Conformance Verification — a spec for checking that a
  runtime's actual behaviour matches its declared RuntimeContract.

[S] Signals:
- The six sub-contracts map cleanly to the existing Igniter platform structure:
  Scheduler = Ruby thread pool / inline runner;
  Clock = system clock (currently ambient — needs TemporalPolicy declaration);
  Cache = resolver cache and invalidation;
  Storage = Ledger + DurableModel;
  Capability = materializer gate + approval receipts;
  Distributed = cluster/multi-process (future).
- The cascade: false ESCAPE for cache aligns with the existing platform's
  partial invalidation model (nodes are invalidated lazily). Formalizing this
  as ESCAPE gives a clear path to upgrading to cascade: true in the future.
- The DistributedContract.observation_sync.dedup_by_identity field is the
  formal bridge between PROP-005 (identity group) and distributed systems:
  the same deduplication rule works at any scale.

[Q] Open Questions:
- RuntimeContract version changes mid-session: supersede or reject?
- Per-store vs. per-runtime StorageContract.consistency model?
- Named vs. policy-rule capability approval in v0?
- Heterogeneous distributed runtimes: allowed with reconciliation?

[X] Rejected:
- Runtime as ambient environment.
- Single global RuntimeContract singleton.
- Cache invalidation as internal-only.
- Distributed composition as CORE.
- Default capability grants.

[Next] Proposed next slices:
- Research Agent track: temporal-contracts-and-projections-v0
  (can now reference ClockContract and StorageContract for named slice
   reproducibility; uses Projection[T, horizon] from PROP-004)
- PROP-007: Conformance Verification
  (how to check that a runtime's declared RuntimeContract matches its actual
   behaviour; defines the verification observation protocol)
- Bridge implementation track: cite PROP-005 + PROP-006 for runtime session
  packet emission
```
