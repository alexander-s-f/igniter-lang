# META-EXPERT-008.5: Runtime Ledger Mesh Concordance v0

Role: `[Igniter-Lang Archive/Form Expert]`
Card: `S2-AF-R1-C2-S`
Track: `archaeology-round2-runtime-ledger-mesh-concordance-v0`
Status: proposal
Date: 2026-05-07
Depends on: `S2-AF-R1-C1-S`

Affected neighbors:
- `[Igniter-Lang Research Agent]`
- `[Igniter-Lang Compiler/Grammar Expert]`
- `[Igniter-Lang Bridge Agent]`

---

## Purpose

This document tests the C1 Signal record format against runtime, ledger, durable
model, and mesh history.

It does not promote package behavior into Igniter-Lang canon. It classifies
signals by where they belong next:

```text
current canon | package bridge | future proof | parked or rejected
```

The practical question for Stage 2 is:

```text
what should influence the language after compiler extraction, without
interrupting the current SemanticIR emitter / OLAP TC+IR path?
```

---

## Source Layers

Primary archaeology slices:

```text
A04 -- RuntimeMachine, SemanticImage, and TBackend
A11 -- Cluster, Mesh, Ownership, Trust, Consensus
A12 -- Ledger, Durable Model, Store Protocol, MCP
```

Read set:

```text
igniter-lang/docs/proposals/PROP-008-tbackend-contract-v0.md
igniter-lang/docs/proposals/accepted/PROP-009-semantic-image-resume-compatibility-v0.md
igniter-lang/docs/proposals/accepted/PROP-009.1-resume-ordering-errata.md
igniter-lang/docs/proposals/PROP-010-temporal-lifecycle-retention-semantics-v0.md
igniter-lang/docs/spec/ch7-runtime.md
igniter-lang/docs/tracks/runtime-machine-*.md
igniter-lang/docs/tracks/production-runtime-machine-temporal-access-integration-v0.md
packages/igniter-ledger/docs/README.md
packages/igniter-ledger/docs/open-protocol.md
packages/igniter-ledger/docs/intelligent-ledger/README.md
packages/igniter-ledger/docs/tracks/changefeed-ordering-replay-v0.md
packages/igniter-ledger/docs/tracks/compaction-lifecycle-unification-v0.md
packages/igniter-ledger/docs/tracks/contractable-receipt-ledger-sink-v0.md
packages/igniter-durable-model/docs/README.md
packages/igniter-durable-model/docs/tracks/durable-model-client-history-partition-replay-v0.md
packages/igniter-mcp-adapter/README.md
packages/igniter-cluster/README.md
playgrounds/docs/dev/legacy/MESH_V1.md
playgrounds/docs/dev/legacy/MESH_QL_V1.md
playgrounds/docs/dev/legacy/CONSENSUS_V1.md
playgrounds/docs/dev/legacy/DISTRIBUTED_CONTRACTS_V1.md
```

Current Stage 2 baseline:

- Production compiler has seven libraries extracted; SemanticIR emitter is next.
- `History[T]` / `BiHistory[T]` proof stack and RuntimeMachine hook proof are PASS.
- Production RuntimeMachine temporal integration still needs a TBackend adapter.
- `stream T` OOF proof is complete; SemanticIR emission remains.
- `OLAPPoint` parser implementation is PASS; OLAP TypeChecker/SemanticIR is next.

---

## Concordance Table

| ID | Runtime/ledger/mesh signal | Source layer | Current relation | Status | Routing |
|----|----------------------------|--------------|------------------|--------|---------|
| RLM01 | Typed RuntimeMachine lifecycle: boot/load/evaluate/checkpoint/resume | A04 | Accepted spec, memory proof | current_canon | Protect during SemanticIR emitter extraction |
| RLM02 | TBackend six-operation contract: read/append/replay/snapshot/compact/subscribe | A04 | PROP-008 canon; production adapter pending | current_canon | Bridge to production RuntimeMachine TBackend adapter after compiler extraction |
| RLM03 | SemanticImage as content-addressed session root | A04 | PROP-009 accepted | current_canon | Keep as agent handoff and resume identity anchor |
| RLM04 | CompatibilityReport as resume gate with canonical observation ordering | A04 | PROP-009.1 accepted errata | current_canon | Runtime integration must preserve GATE-1 |
| RLM05 | Lifecycle classes, retention, semantic GC roots, boundary receipts | A04/A12 | PROP-010 proposal + package compaction pressure | future_proof | Needs runtime/ledger lifecycle bridge, not parser work |
| RLM06 | RuntimeMachineHook for temporal access needs production TBackend selection | A04/A05 | Hook proof PASS; production integration open | package_bridge | Immediate post-compiler-extraction bridge candidate |
| RLM07 | Proof sidecar packet profiles: full log vs selected profile | A04 | Track proof tooling exists | package_bridge | Use selected_profile as first package candidate conformance shape |
| RLM08 | Schema migration receipts and replacement SemanticImage | A04 | Migration fixture exists; replacement image future | future_proof | Future proof after SemanticIR emitter and RuntimeMachine adapter |
| RLM09 | Ledger Open Protocol as thin waist over descriptors/facts/receipts/queries/subscriptions/replay | A12 | Shipped package protocol, not language canon | package_bridge | Strong candidate for TBackend/Ledger adapter vocabulary |
| RLM10 | Intelligent Ledger: base facts, derived facts, transitions, derivation receipts | A12 | Research/package docs | future_proof | Future bounded inference proof over facts |
| RLM11 | Compaction vocabulary: compact/prune/purge plus resurrection barrier | A12 | Package bridge implemented | package_bridge | Align with PROP-010 lifecycle classes before language exposure |
| RLM12 | Changefeed ordering and replay cursors | A12 | Package track done | package_bridge | Bridge to stream/replay semantics, but keep best-effort v0 limits explicit |
| RLM13 | Durable Model client History partition replay | A12 | Package track done | package_bridge | Candidate lowering path for History partition reads |
| RLM14 | Contractable observation/event receipts persisted as Ledger facts | A12 | Package sink implemented | package_bridge | Bridge ObsPacket/receipt evidence to Ledger facts |
| RLM15 | MCP adapter as transport-thin tool surface | A12 | Package exists; semantics live elsewhere | package_bridge | Future language tool surface should not duplicate MCP semantics |
| RLM16 | Cluster profile: peer identity/topology/capability/ownership/lease/failover plans | A11 | New package surface | package_bridge | Future distributed RuntimeContract pressure |
| RLM17 | Mesh execution traces with membership, retry, trust, and admission decisions | A11 | New package surface | package_bridge | Candidate evidence shape for distributed evaluation receipts |
| RLM18 | MeshQL grammar over ObservationQuery for peer selection | A11 | Legacy grammar over package query model | future_proof | Preserve as placement/query grammar pressure, not source language now |
| RLM19 | Gossip discovery and topology convergence | A11 | Legacy shipped pattern; new package has membership/discovery | package_bridge | Future causal mesh proof must include topology observation freshness |
| RLM20 | Consensus/Raft-style log as contract-backed durability | A11 | Legacy reference only | parked | Keep as warning and pattern library; do not revive as Stage 2 feature |

---

## Compact Signal Records

### RLM01

```text
id: RLM01-runtime-machine-lifecycle
source_paths: igniter-lang/docs/spec/ch7-runtime.md
first_seen_layer: A04
current_status: current_canon
concept: RuntimeMachine lifecycle is typed and ordered: boot, load, evaluate, checkpoint, resume.
why_it_matters: Gives Stage 2 a runtime spine that compiler extraction must feed, not replace.
current_canonical_home: Ch7 RuntimeMachine; runtime_machine_memory_proof.
missing_formal_home: Production stdlib/operator evaluation remains outside this archaeology slice.
proof_candidate: Keep lifecycle regression around load/evaluate/checkpoint/resume as SemanticIR emitter changes.
bridge_candidate: Production RuntimeMachine temporal integration.
risk_if_lost: Compiler extraction creates a program artifact that no proven runtime lifecycle owns.
```

### RLM02

```text
id: RLM02-tbackend-six-ops
source_paths: igniter-lang/docs/proposals/PROP-008-tbackend-contract-v0.md
first_seen_layer: A04
current_status: current_canon
concept: TBackend has six typed operations: read, append, replay, snapshot, compact, subscribe.
why_it_matters: It is the implementation interface of StorageContract and the narrowest bridge from language runtime to packages.
current_canonical_home: PROP-008.
missing_formal_home: Production adapter selection and capability checking in RuntimeMachine.
proof_candidate: Adapter conformance against memory backend plus CompatibilityReport backend_check.
bridge_candidate: Ledger Open Protocol adapter.
risk_if_lost: Runtime persistence becomes ad hoc package calls instead of a typed contract boundary.
```

### RLM03

```text
id: RLM03-semantic-image-root
source_paths: igniter-lang/docs/proposals/accepted/PROP-009-semantic-image-resume-compatibility-v0.md
first_seen_layer: A04
current_status: current_canon
concept: SemanticImage is a content-addressed root over session semantics, observations, receipts, verification, checkpoint, and replay cursors.
why_it_matters: It is the language-level handoff object for agents, resumes, migration, and reproducibility.
current_canonical_home: PROP-009.
missing_formal_home: Retention policy and replacement-image production are still future pressure.
proof_candidate: SemanticImage identity must survive package-derived selected profiles.
bridge_candidate: Ledger receipt sink and TBackend snapshot/replay.
risk_if_lost: Agents resume from loose process state instead of justified semantic evidence.
```

### RLM04

```text
id: RLM04-compatibility-gate
source_paths: PROP-009.1-resume-ordering-errata.md, docs/spec/ch7-runtime.md
first_seen_layer: A04
current_status: current_canon
concept: CompatibilityReport is emitted after boot and verification, before any load/evaluate user-facing observation.
why_it_matters: It closes the trust loophole in resume and makes unsafe resume OOF.
current_canonical_home: PROP-009.1 GATE-1.
missing_formal_home: Production enforcement in runtime integration.
proof_candidate: Negative packet fixture: no LoadReceipt before CompatibilityReport.
bridge_candidate: RuntimeMachine production proof.
risk_if_lost: Resume can silently cross incompatible runtime/backend/schema boundaries.
```

### RLM05

```text
id: RLM05-lifecycle-retention-gc-roots
source_paths: PROP-010-temporal-lifecycle-retention-semantics-v0.md, packages/igniter-ledger/docs/tracks/compaction-lifecycle-unification-v0.md
first_seen_layer: A04/A12
current_status: future_proof
concept: Observations have lifecycle classes, retention policies, semantic GC roots, and boundary receipts.
why_it_matters: It makes compaction epistemic: what can be forgotten depends on what remains provable.
current_canonical_home: PROP-010 proposal, not current Stage 2 implementation canon.
missing_formal_home: Runtime/ledger lifecycle bridge and retention-aware TBackend conformance.
proof_candidate: Boundary receipt preserves result truth after detail compaction.
bridge_candidate: Ledger compaction activity and Store prune/purge vocabulary.
risk_if_lost: Storage cleanup becomes deletion by convenience, breaking reproducibility.
```

### RLM06

```text
id: RLM06-production-temporal-tbackend-adapter
source_paths: runtime-machine-temporal-access-hook-v0.md, runtime-machine-temporal-access-hook-proof-v0.md, current-status.md
first_seen_layer: A04
current_status: package_bridge
concept: Temporal access hook is proven, but production RuntimeMachine still needs TBackend adapter selection and compatibility integration.
why_it_matters: This is the first live bridge from Stage 2 History/BiHistory types into package-backed runtime evidence.
current_canonical_home: PROP-022 hook proof and Stage 2 current status.
missing_formal_home: Production adapter contract in RuntimeMachine.
proof_candidate: Production RuntimeMachine temporal access integration proof.
bridge_candidate: Ledger/Open Protocol read_as_of and history partition replay.
risk_if_lost: History/BiHistory remain proof-local instead of runtime substrate.
```

### RLM07

```text
id: RLM07-proof-sidecar-selected-profile
source_paths: runtime-machine-proof-sidecar-profile-modes-v0.md
first_seen_layer: A04
current_status: package_bridge
concept: full_log is for proof regression; selected_profile is for early bridge/package candidates.
why_it_matters: It gives packages a realistic conformance target before they can emit full proof logs.
current_canonical_home: RuntimeMachine proof sidecar tracks.
missing_formal_home: Which SemanticImage/report fields may differ for package-derived candidates.
proof_candidate: Selected profile acceptance test for Ledger-backed packet candidates.
bridge_candidate: Ledger receipt sink and future TBackend adapter.
risk_if_lost: Package bridges either fake full proof logs or are blocked until too late.
```

### RLM08

```text
id: RLM08-schema-migration-replacement-image
source_paths: runtime-machine-schema-migration-fixture-v0.md, runtime-machine-migration-replacement-image-v0.md
first_seen_layer: A04
current_status: future_proof
concept: Schema migration emits migration descriptors/receipts and should eventually produce a replacement SemanticImage.
why_it_matters: Migration is not just a compiler concern; it changes the evidence root of a resumable system.
current_canonical_home: Migration fixture track.
missing_formal_home: Replacement SemanticImage semantics and multi-hop migration policy.
proof_candidate: Resume old image, apply migration, emit replacement image, prove compatibility.
bridge_candidate: Ledger migration receipt storage.
risk_if_lost: Schema evolution becomes report-only and cannot support durable resume.
```

### RLM09

```text
id: RLM09-ledger-open-protocol-thin-waist
source_paths: packages/igniter-ledger/docs/open-protocol.md
first_seen_layer: A12
current_status: package_bridge
concept: Ledger Open Protocol exposes packets for descriptors, facts, receipts, queries, subscriptions, replay, and sync.
why_it_matters: It is the package-side thin waist closest to TBackend.
current_canonical_home: package protocol, not Igniter-Lang canon.
missing_formal_home: TBackend adapter mapping and capability equivalence.
proof_candidate: Map TBackend read/append/replay/snapshot/compact/subscribe to protocol packets.
bridge_candidate: Bridge Agent Ledger-to-TBackend alignment slice.
risk_if_lost: Igniter-Lang invents a second persistence protocol while a strong package waist already exists.
```

### RLM10

```text
id: RLM10-intelligent-ledger-derived-facts
source_paths: packages/igniter-ledger/docs/intelligent-ledger/README.md
first_seen_layer: A12
current_status: future_proof
concept: Facts can feed bounded inference, derived facts, transitions, and receipts without arbitrary Ruby execution.
why_it_matters: It aligns Ledger with the stratified-Datalog identity from C1.
current_canonical_home: package research docs.
missing_formal_home: Bounded fact inference proof and rule/version receipt semantics.
proof_candidate: Conformance-only Datalog-like inference over ledger facts.
bridge_candidate: Future rule/RDG work from C1.
risk_if_lost: Ledger stays storage-only and loses the explainable derivation path.
```

### RLM11

```text
id: RLM11-compaction-compact-prune-purge
source_paths: compaction-lifecycle-unification-v0.md, PROP-010-temporal-lifecycle-retention-semantics-v0.md
first_seen_layer: A12
current_status: package_bridge
concept: compact is semantic lifecycle, prune is exact fact-id removal, purge is physical storage artifact removal.
why_it_matters: It separates epistemic compaction from physical cleanup.
current_canonical_home: package track; PROP-010 pressure.
missing_formal_home: Language/runtime lifecycle vocabulary alignment.
proof_candidate: Resurrection-free reopen plus boundary truth preservation.
bridge_candidate: TBackend compact operation.
risk_if_lost: Compaction receipts and purge receipts get confused, weakening audit.
```

### RLM12

```text
id: RLM12-changefeed-replay-cursor
source_paths: packages/igniter-ledger/docs/tracks/changefeed-ordering-replay-v0.md
first_seen_layer: A12
current_status: package_bridge
concept: Changefeed has explicit event ordering and replay cursor semantics, including cursor_too_old.
why_it_matters: It is the package-side ancestor of stream/replay runtime behavior.
current_canonical_home: package Changefeed track.
missing_formal_home: Durable replay and relation to `stream T` windows.
proof_candidate: Bridge retained changefeed replay to bounded stream fold inputs.
bridge_candidate: stream SemanticIR emission and TBackend subscribe/replay.
risk_if_lost: Live subscriptions hide missed events instead of making replay gaps explicit.
```

### RLM13

```text
id: RLM13-durable-model-history-partition-replay
source_paths: durable-model-client-history-partition-replay-v0.md
first_seen_layer: A12
current_status: package_bridge
concept: Client-backed Durable Model supports History partition replay through LedgerClient replay filters.
why_it_matters: It is a concrete lowering path for `History[T]` partitioned by business key.
current_canonical_home: durable-model/ledger-client package track.
missing_formal_home: Type-directed History lowering contract.
proof_candidate: `History[T]` temporal access through client-backed replay filter.
bridge_candidate: Production RuntimeMachine temporal TBackend adapter.
risk_if_lost: Local and remote History semantics diverge.
```

### RLM14

```text
id: RLM14-contractable-receipt-ledger-sink
source_paths: packages/igniter-ledger/docs/tracks/contractable-receipt-ledger-sink-v0.md
first_seen_layer: A12
current_status: package_bridge
concept: Contractable observation and event receipts can be persisted as ordinary Ledger facts.
why_it_matters: It closes the evidence loop between runtime observations and durable fact history.
current_canonical_home: package receipt sink.
missing_formal_home: ObsPacket-to-Ledger fact equivalence rule.
proof_candidate: Selected profile packets persisted and replayed with causation chain intact.
bridge_candidate: RuntimeMachine proof sidecar selected_profile.
risk_if_lost: Runtime proof evidence remains ephemeral or package-specific.
```

### RLM15

```text
id: RLM15-mcp-adapter-tool-surface
source_paths: packages/igniter-mcp-adapter/README.md
first_seen_layer: A12
current_status: package_bridge
concept: MCP adapter is transport-thin; tooling semantics remain in the contracts extension surface.
why_it_matters: It shows how agent tooling can be exposed without making transport a semantic source of truth.
current_canonical_home: package boundary.
missing_formal_home: Language-level tool surface and MCP observation receipts.
proof_candidate: Tool invocation emits contract/runtime receipts without duplicating semantics.
bridge_candidate: Future MCP/tooling bridge after runtime evidence stabilizes.
risk_if_lost: MCP integration becomes a second language/runtime model.
```

### RLM16

```text
id: RLM16-cluster-profile-plans
source_paths: packages/igniter-cluster/README.md
first_seen_layer: A11
current_status: package_bridge
concept: Cluster models peer identity, topology, capability queries, ownership, leases, failover, remediation, and execution reports.
why_it_matters: It is the package-side vocabulary for distributed RuntimeContract.
current_canonical_home: new igniter-cluster package.
missing_formal_home: Distributed contract profile in Igniter-Lang.
proof_candidate: Plan report as typed distributed evaluation receipt.
bridge_candidate: Bridge Agent distributed RuntimeContract pressure map.
risk_if_lost: Mesh features enter language as transport knobs instead of contract semantics.
```

### RLM17

```text
id: RLM17-mesh-execution-trust-admission
source_paths: packages/igniter-cluster/README.md
first_seen_layer: A11
current_status: package_bridge
concept: Mesh execution records request, response, attempts, trace, membership, retry, trust, and admission decisions.
why_it_matters: Distributed execution needs evidence for who was tried, who was refused, and why.
current_canonical_home: new igniter-cluster package.
missing_formal_home: Distributed evaluation receipt schema.
proof_candidate: MeshExecutionTrace -> ObsPacket mapping.
bridge_candidate: TBackend remote backend / distributed RuntimeMachine.
risk_if_lost: Distributed failures become opaque network errors rather than explainable contract observations.
```

### RLM18

```text
id: RLM18-meshql-observation-query
source_paths: playgrounds/docs/dev/legacy/MESH_QL_V1.md
first_seen_layer: A11
current_status: future_proof
concept: MeshQL is a grammar over ObservationQuery for capability, trust, health, locality, metrics, order, and limit.
why_it_matters: It points to a query language over runtime observations and placement candidates.
current_canonical_home: legacy cluster docs only.
missing_formal_home: Placement query type system and observation schema.
proof_candidate: Parse-to-query equivalence with no separate execution engine.
bridge_candidate: Compiler/Grammar Expert only after distributed profile exists.
risk_if_lost: Placement criteria stay informal and cannot be audited or round-tripped.
```

### RLM19

```text
id: RLM19-gossip-topology-freshness
source_paths: playgrounds/docs/dev/legacy/MESH_V1.md, packages/igniter-cluster/README.md
first_seen_layer: A11
current_status: package_bridge
concept: Mesh topology converges through peer discovery and gossip; membership freshness affects routing truth.
why_it_matters: A distributed contract result depends on the observed topology, not only the code and inputs.
current_canonical_home: legacy mesh docs and new membership/discovery package surface.
missing_formal_home: Topology observation freshness and causal context in distributed RuntimeContract.
proof_candidate: Routing decision receipt links to membership snapshot and freshness window.
bridge_candidate: Cluster mesh diagnostics / runtime observations.
risk_if_lost: Placement decisions cannot explain stale or partitioned topology knowledge.
```

### RLM20

```text
id: RLM20-consensus-log-reference
source_paths: playgrounds/docs/dev/legacy/CONSENSUS_V1.md
first_seen_layer: A11
current_status: parked
concept: Raft-like consensus log and state machine DSL were explored as distributed durability.
why_it_matters: It preserves useful patterns: quorum, leader, log, state-machine reducers, read queries.
current_canonical_home: legacy reference only.
missing_formal_home: none for Stage 2.
proof_candidate: none now.
bridge_candidate: Later cluster/ledger durability research, if Architect requests.
risk_if_lost: The project may repeat old consensus experiments without remembering what was already tried.
```

---

## Stage 2 Influence After Compiler Extraction

[R] Do not interrupt the current compiler extraction order. The immediate
language work should stay:

```text
SemanticIR emitter extraction
-> OLAP TypeChecker/SemanticIR
-> production RuntimeMachine temporal integration
```

After SemanticIR emitter extraction, the strongest runtime/ledger/mesh influence
is the production RuntimeMachine TBackend bridge:

- use RLM02 as the contract boundary
- use RLM06 as the immediate temporal-access adapter pressure
- use RLM09/RLM13 for Ledger/Durable Model replay lowering
- use RLM07/RLM14 as conformance/evidence packet bridge

A11 cluster/mesh signals are important, but should not become Stage 2 source
language work yet. They should feed a later distributed RuntimeContract pressure
map after the production RuntimeMachine adapter exists.

---

## Covered Or Already Bridged

Already current canon:

- RuntimeMachine lifecycle.
- TBackend operation contract.
- SemanticImage.
- CompatibilityReport gate and resume ordering.

Already package bridge:

- Ledger Open Protocol packet waist.
- Ledger compaction activity and receipt vocabulary.
- Changefeed replay cursor semantics.
- Durable Model History partition replay.
- Contractable receipt sink.
- Cluster profile/plans and mesh execution trace surface.

These should be protected and mapped, not reauthored.

---

## Richer Than Current Canon

Richer-than-canon signals needing future proof or bridge:

- Runtime/ledger lifecycle alignment for retention, semantic GC roots, and
  boundary receipts.
- Replacement SemanticImage after migration.
- Bounded inference over ledger facts with derivation receipts.
- Stream/replay relationship between `stream T`, Changefeed, and TBackend
  `subscribe`.
- Distributed RuntimeContract over mesh membership, topology freshness, trust,
  admission, ownership, and lease evidence.
- MeshQL-like query grammar over runtime observations and placement candidates.

---

## Parked Or Rejected

- Consensus/Raft work is parked as reference material, not a Stage 2 feature.
- MeshQL is not a source-language grammar candidate yet.
- Raw transport, router, placement, and admission seams should remain low-level
  package escape hatches until a distributed RuntimeContract exists.
- Package behavior is not canon merely because it exists.

---

## Living Signal Ledger Recommendation

[D] The C1 and C2 slices together are enough to create a living signal ledger.

[R] Create it now, but keep it deliberately small:

- one index file only, likely in `igniter-lang/docs/meta-proposals/`
- records only signals that already appeared in a concordance slice
- no automatic promotion to PROP or current canon
- status enum must include `package_bridge`
- each record must point to an owning next role, not a vague future

The ledger should start as an index over META-EXPERT-008.4 and 008.5, not as a
new archive database. That keeps the archaeology useful without letting the map
become a swamp.

---

## Handoff

Card: `S2-AF-R1-C2-S`
Role: `[Igniter-Lang Archive/Form Expert]`
Track: `archaeology-round2-runtime-ledger-mesh-concordance-v0`
Status: proposal

[D] Delivered A04/A11/A12 runtime-ledger-mesh concordance with 20 compact Signal
records and a current-canon/package-bridge/future-proof/parked routing table.

[S] The format from C1 holds, but needs `package_bridge` as a first-class status
because package work contains strong evidence that is not yet language canon.

[T] Current Stage 2 should stay on compiler extraction first. After SemanticIR
emitter extraction, the strongest next influence is production RuntimeMachine
TBackend integration using Ledger/Durable Model replay and receipt evidence.

[R] Living signal ledger is ready now, as a small concordance index over 008.4
and 008.5, not as a giant database.

[Next] Bridge Agent should receive a Ledger-to-TBackend alignment slice after
SemanticIR emitter extraction. Compiler/Grammar Expert should later receive a
distributed RuntimeContract pressure map from RLM16/RLM17/RLM19, but not as
current Stage 2 source grammar work.
