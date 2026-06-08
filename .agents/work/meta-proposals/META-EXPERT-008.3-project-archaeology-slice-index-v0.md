# META-EXPERT-008.3: Project Archaeology Slice Index v0

Role: `[Igniter-Lang Meta Expert]`
Profile: inherited `[Igniter-Lang Compiler/Grammar Expert]` formal lens +
archaeology/history ownership
Track: `igniter-lang/docs/meta-proposals/META-EXPERT-008.3-project-archaeology-slice-index-v0.md`
Status: proposal
Date: 2026-05-07

Affected neighbors:
- `[Igniter-Lang Research Agent]`
- `[Igniter-Lang Compiler/Grammar Expert]`
- `[Igniter-Lang Bridge Agent]`
- `[Igniter-Lang Applied Pressure Agent]`

---

## Purpose

This document is a map for archaeological consolidation, not the consolidation
itself.

The project now has several historical layers:

```text
Ruby Igniter platform
  + active package rewrite
  + legacy package archive
  + application examples
  + Spark CRM pressure code
  + research-horizon docs
  + early igniter-lang expert docs
  + current igniter-lang Stage 1/2 lab
```

The material is too large to load in one slice. The goal is to index the
history into bounded context slices so future work can recover ideas without
turning every session into a full-repo reread.

[D] The archaeology objective:

```text
do not let valuable signals disappear under formal implementation rounds.
```

[D] The formal objective:

```text
every recovered signal must eventually be classified as:
research | proposal | approved_experiment | implementation_candidate | rejected
```

---

## Role Clarification

The requested role is effectively a meta-role:

```text
Meta Expert
  inherits Compiler/Grammar Expert discipline
  adds historical memory and signal preservation
```

For document compatibility, this slice uses the accepted identity:

```text
[Igniter-Lang Meta Expert]
```

The inherited compiler/grammar lens is applied as a filter:

- preserve concepts, but do not accept vague language features without
  parser/type/runtime implications
- prefer narrow future PROP/proof requests over broad idea dumps
- map idea origin and later transformations
- keep alive concepts that are not ready for formalization yet

---

## Repository Surface Inventory

Inventory snapshot, excluding `.git`, `target`, `tmp`, `node_modules`,
`vendor`, and package artifact directories:

```text
igniter-lang/                  652 files
playgrounds/docs/              242 files
playgrounds/legacy/packages/   618 files
playgrounds/urgently/sparkcrm/  49 files
playgrounds/extracted/sparkcrm/185 files
packages/                      829 files
examples/                      271 files
docs/                           57 files
lib/                            12 files
spec/                          175 files
```

Active package map:

```text
packages/igniter-ledger         167
packages/igniter-extensions     127
packages/igniter-cluster        112
packages/igniter-application    102
packages/igniter-contracts      102
packages/igniter-durable-model   86
packages/igniter-web             38
packages/igniter-embed           27
packages/igniter-ledger-client   21
packages/igniter-ai              15
packages/igniter-agents          12
packages/igniter-mcp-adapter     11
packages/igniter-hub              8
```

Legacy package archive:

```text
playgrounds/legacy/packages/igniter-core        187
playgrounds/legacy/packages/igniter-app         130
playgrounds/legacy/packages/igniter-cluster     103
playgrounds/legacy/packages/igniter-frontend     58
playgrounds/legacy/packages/igniter-server       30
playgrounds/legacy/packages/igniter-agents       29
playgrounds/legacy/packages/igniter-ai           22
playgrounds/legacy/packages/igniter-sdk          19
playgrounds/legacy/packages/igniter-extensions-legacy 14
playgrounds/legacy/packages/igniter-schema-rendering  13
playgrounds/legacy/packages/igniter-rails        12
```

Igniter-Lang internal docs:

```text
docs/archive       188
docs/tracks        124
docs/proposals      36
docs/bridge         16
docs/meta-proposals 12
docs/spec           10
```

---

## Archaeology Method

Each future archaeology slice should produce a compact note with:

```text
1. Source layer
2. Read set
3. Recovered signals
4. Which signals are already canonical
5. Which signals are missing from current canon
6. Formal pressure: parser/type/runtime/diagnostics/bridge
7. Recommended next PROP/proof/bridge
8. Rejected or parked ideas
```

Use this signal record:

```text
Signal = Record {
  id,
  source_paths,
  first_seen_layer,
  current_status,
  concept,
  why_it_matters,
  current_canonical_home?,
  missing_formal_home?,
  proof_candidate?,
  bridge_candidate?,
  risk_if_lost
}
```

[R] Create a living signal ledger only after 2-3 slices validate the schema.
Do not create a giant database before the first consolidation passes prove the
shape.

---

## Global Layer Map

### Layer L0: Current Igniter-Lang Canon

Primary sources:

```text
igniter-lang/docs/README.md
igniter-lang/docs/current-status.md
igniter-lang/docs/spec/
igniter-lang/docs/proposals/
igniter-lang/docs/tracks/stage2-round6-map-refresh-v0.md
igniter-lang/lib/igniter_lang/
igniter-lang/experiments/
```

Meaning:

```text
current language state, proof spine, Stage 2 open gaps
```

Archaeology risk:

```text
low for current facts, high for stale entrypoints and duplicated older claims
```

### Layer L1: Early Igniter-Lang Expert Series

Primary sources:

```text
playgrounds/docs/experts/igniter-lang/
```

Known high-value signals:

- five formal identities
- Semantic Information Ratio
- Turing-completeness paths
- property model / synthesis
- invariants as contracts
- History / BiHistory / temporal rules
- OLAPPoint
- persistence and Store/History lowering
- Ruby DSL as reference implementation
- grammar should follow semantics, not precede it

Archaeology risk:

```text
very high: this layer contains concepts not yet fully reflected in Stage 2
```

### Layer L2: Research Horizon And Process Doctrine

Primary sources:

```text
playgrounds/docs/research-horizon/
playgrounds/docs/dev/process/
playgrounds/docs/dev/reference/
```

Known high-value signals:

- agent handoff protocol
- interaction kernel
- runtime observatory graph
- grammar-compressed interaction
- DSL/REPL authoring
- documentation compression doctrine
- operator interface doctrines

Archaeology risk:

```text
medium-high: rich human-agent and tooling concepts may not map cleanly to current Stage 2
```

### Layer L3: Active Ruby Platform Packages

Primary sources:

```text
packages/
lib/
docs/guide/
docs/dev/
examples/
spec/
```

Known high-value signals:

- contract graph kernel
- embed/shadowing
- Ledger facts/history/receipts/replay/compaction
- durable model Record/History facade
- application capsules and session seams
- web/operator surfaces
- cluster planning/mesh attempts/trust/admission
- MCP transport
- extension packs: provenance, saga, reactive, dataflow, differential,
  invariants, execution reports

Archaeology risk:

```text
medium: active code may contain current product truth not yet reflected in language canon
```

### Layer L4: Legacy Package Archive

Primary sources:

```text
playgrounds/legacy/packages/
playgrounds/legacy/docs/
```

Known high-value signals:

- earlier core DSL/runtime/compiler shapes
- cluster mesh, ownership, trust, consensus, placement
- agent runtime and proactive agents
- frontend Arbre/Tailwind path
- saga, content-addressing, dataflow, provenance
- app capsules and server host concepts

Archaeology risk:

```text
very high: valuable ideas are mixed with obsolete implementation shapes
```

### Layer L5: Application And Product Pressure

Primary sources:

```text
examples/application/
examples/contracts/
examples/cluster/
playgrounds/urgently/sparkcrm/
playgrounds/extracted/sparkcrm/
igniter-lang/docs/tracks/spark-*.md
igniter-lang/docs/tracks/osint-*.md
igniter-lang/docs/tracks/personal-osint-*.md
igniter-lang/docs/tracks/sandbox-simulation-*.md
```

Known high-value signals:

- Companion assistant shell
- Scout / Chronicle / Dispatch / Lense application patterns
- Spark CRM real business constraints
- availability, lead signal, operation action lifecycle
- extracted Arbre/Tailwind UI component system
- OSINT product traceability
- simulation/world-model pressure

Archaeology risk:

```text
high: product pressure contains the "why this language matters" evidence
```

---

## Slice Index

### A00 — Archaeology Control Room

Sources:

```text
igniter-lang/docs/README.md
igniter-lang/docs/current-status.md
igniter-lang/docs/meta-proposals/
igniter-lang/docs/tracks/README.md
this document
```

Question:

```text
what is canon, what is current, and where do we park recovered signals?
```

Output:

```text
living archaeology index + signal ledger schema
```

Priority: immediate.

### A01 — Origin Series: Language Birth

Sources:

```text
playgrounds/docs/experts/igniter-lang/README.md
playgrounds/docs/experts/igniter-lang/igniter-lang.md
playgrounds/docs/experts/igniter-lang/igniter-lang-theory.md
playgrounds/docs/experts/igniter-lang/igniter-lang-spec.md
playgrounds/docs/experts/igniter-lang/igniter-lang-implementation.md
```

Question:

```text
what were the first principles before Stage 1 crystallized them?
```

Expected signals:

- SIR metric
- grammar-after-semantics discipline
- five formal identities
- Ruby DSL as reference implementation
- early syntax and node taxonomy
- semantic density as language motivation

Output:

```text
origin-to-canon concordance table
```

Priority: immediate.

### A02 — Formal Foundations And General-Purpose Boundary

Sources:

```text
playgrounds/docs/experts/igniter-lang/igniter-lang-theory2.md
playgrounds/docs/experts/igniter-lang/igniter-lang-algebra.md
playgrounds/docs/experts/igniter-lang/igniter-lang-propmodel.md
igniter-lang/docs/proposals/PROP-002-contract-composition-algebra-v0.md
igniter-lang/docs/proposals/PROP-016-polymorphism-traits-contract-shapes-v0.md
```

Question:

```text
how far can Igniter-Lang move toward general-purpose coverage
without destroying CORE decidability?
```

Expected signals:

- contract algebra
- property models
- synthesis boundary
- trait/coherence pressure
- typed holes / reverse planning candidates
- self-hosting prerequisites

Output:

```text
general-purpose-profile pressure map
```

Priority: high.

### A03 — Compiler And Grammar Spine

Sources:

```text
igniter-lang/docs/spec/ch2-source-surface.md
igniter-lang/docs/spec/ch3-type-system.md
igniter-lang/docs/spec/ch4-fragment-classification.md
igniter-lang/docs/spec/ch5-compiler-pipeline.md
igniter-lang/docs/spec/ch6-semanticir.md
igniter-lang/docs/proposals/accepted/
igniter-lang/lib/igniter_lang/
igniter-lang/experiments/parser
igniter-lang/experiments/classifier_pass_proof
igniter-lang/experiments/typechecker_proof
igniter-lang/experiments/source_to_semanticir_fixture
```

Question:

```text
what does the working language proof preserve, and what old ideas were excluded?
```

Expected signals:

- parser/classifier/typechecker boundary rules
- OOF ownership drift
- SemanticIR shape constraints
- old syntax forms not yet carried forward
- production compiler extraction gaps

Output:

```text
compiler archaeology map + missing-source-surface register
```

Priority: high.

### A04 — RuntimeMachine, SemanticImage, And TBackend

Sources:

```text
igniter-lang/docs/proposals/PROP-008-tbackend-contract-v0.md
igniter-lang/docs/proposals/PROP-010-temporal-lifecycle-retention-semantics-v0.md
igniter-lang/docs/proposals/accepted/PROP-009-semantic-image-resume-compatibility-v0.md
igniter-lang/docs/spec/ch7-runtime.md
igniter-lang/docs/tracks/runtime-machine-*.md
packages/igniter-ledger/
packages/igniter-ledger-client/
packages/igniter-durable-model/
```

Question:

```text
how did persistence become temporal substrate, and what does language-level
runtime composition require?
```

Expected signals:

- RuntimeMachine lifecycle
- SemanticImage as agent handoff
- TBackend operations
- Ledger fact/event/receipt model
- Durable Model Record/History facade
- LanguageContract + RuntimeContract pressure

Output:

```text
runtime-substrate concordance + TBackend language bridge queue
```

Priority: high.

### A05 — Temporal, History, BiHistory, OLAP, Stream

Sources:

```text
playgrounds/docs/experts/igniter-lang/igniter-lang-temporal.md
playgrounds/docs/experts/igniter-lang/igniter-lang-temporal-deep.md
playgrounds/docs/experts/igniter-lang/igniter-lang-olap.md
playgrounds/docs/experts/igniter-lang/igniter-lang-persistence.md
igniter-lang/docs/proposals/PROP-022-history-type-constructor-v0.md
igniter-lang/docs/proposals/PROP-023-stream-input-surface-v0.md
igniter-lang/docs/proposals/PROP-024-olap-point-primitive-v0.md
igniter-lang/experiments/history_type_proof
igniter-lang/experiments/stream_t_proof
igniter-lang/experiments/olap_point_proof
```

Question:

```text
what is the full temporal model, and which parts are Stage 2 vs later?
```

Expected signals:

- `T ⊑ History[T] ⊑ BiHistory[T]`
- `History[T] == OLAPPoint[T, {time: DateTime}]`
- temporal synthesis
- causal rule cycles
- stream/window reactive model
- time_machine / Forecast candidates
- distributed time and vector clocks

Output:

```text
temporal concept matrix + Stage 2/3/4 split
```

Priority: immediate after A01/A04.

### A06 — Observations, Evidence, OSINT, Fact-Checking

Sources:

```text
igniter-lang/docs/proposals/PROP-005-bridge-observation-envelope-v0.md
igniter-lang/docs/proposals/PROP-005.1-obspacket-patch-lifecycle-verification-v0.md
igniter-lang/docs/tracks/observable-*.md
igniter-lang/docs/tracks/osint-*.md
igniter-lang/docs/tracks/personal-osint-*.md
igniter-lang/docs/bridge/osint-*.md
igniter-lang/experiments/osint_fractal_traceability_fixture
igniter-lang/experiments/personal_osint_assistant_product_fixture
examples/application/scout/
examples/application/chronicle/
```

Question:

```text
why is OSINT a native language projection rather than an app vertical?
```

Expected signals:

- Claim / EvidenceLink / ConfidenceAssessment
- ContradictionReport and CorrectionReceipt
- evidence-linked alert gate
- source provenance
- fact-check snapshot
- traceability from language axiom to final report

Output:

```text
OSINT traceability spine + minimum executable vertical plan
```

Priority: high.

### A07 — Human-Agent Symbiosis And Meaning Diff

Sources:

```text
playgrounds/docs/research-horizon/agent-handoff-protocol.md
playgrounds/docs/research-horizon/interaction-kernel-report.md
playgrounds/docs/research-horizon/grammar-compressed-interaction.md
playgrounds/docs/research-horizon/dsl-repl-authoring-research.md
igniter-lang/docs/tracks/human-agent-readable-contracts-*.md
igniter-lang/docs/tracks/meaning-diff-and-acceptance-semantics-v0.md
igniter-lang/docs/bridge/human-agent-review-approval-bridge-profile-v0.md
examples/application/agent_native_plan_review.rb
packages/igniter-agents/
packages/igniter-ai/
```

Question:

```text
what makes the language readable by humans when agents author contracts?
```

Expected signals:

- MeaningDiff
- ReviewProjection
- AcceptanceReceipt
- fresh review rules
- agent handoff
- grammar-compressed interaction
- contract-as-dialog surface

Output:

```text
human-agent review language surface map
```

Priority: high.

### A08 — Applications, Capsules, Web, Operator Surface

Sources:

```text
docs/guide/application-capsules.md
docs/guide/application-showcase-portfolio.md
docs/dev/application-target-plan.md
docs/dev/igniter-web-target-plan.md
packages/igniter-application/
packages/igniter-web/
examples/application/
playgrounds/docs/dev/tracks/application-*.md
```

Question:

```text
how do contracts become applications that humans and agents operate?
```

Expected signals:

- application capsule
- manifest / surface manifest
- flow sessions
- pending action / pending input
- operator dashboards
- web surface as contract projection
- app-local vs stack-level boundary

Output:

```text
application-as-contract map + language/app bridge requests
```

Priority: medium-high.

### A09 — Spark CRM, Planning, Logistics, Business Processes

Sources:

```text
playgrounds/urgently/sparkcrm/
playgrounds/extracted/sparkcrm/
igniter-lang/docs/tracks/spark-*.md
igniter-lang/docs/tracks/operation-action-result-types-and-transition-semantics-v0.md
igniter-lang/docs/bridge/spark-*.md
examples/application/dispatch/
examples/cluster/incident_workflow.rb
```

Question:

```text
which real business constraints should shape the language?
```

Expected signals:

- tenant scope
- technician availability
- lead signal boundary
- operation action lifecycle
- executable vs visible action
- policy freshness
- idempotent no-op
- compensation and approval workflow
- Arbre/Tailwind frontend pressure

Output:

```text
business-process primitive queue + compensation/approval PROP pressure
```

Priority: high.

### A10 — Legacy Core And Extension Packs

Sources:

```text
playgrounds/legacy/packages/igniter-core/
playgrounds/legacy/packages/igniter-extensions-legacy/
packages/igniter-contracts/
packages/igniter-extensions/
examples/contracts/
```

Question:

```text
which old runtime/extension ideas still deserve language status?
```

Expected signals:

- dataflow
- saga/compensation
- provenance
- content addressing
- differential/shadow
- reactive subscriptions
- invariants
- incremental computation
- property testing
- diagnostics/introspection

Output:

```text
legacy-extension to language-primitive classification table
```

Priority: medium-high.

### A11 — Cluster, Mesh, Ownership, Trust, Consensus

Sources:

```text
playgrounds/legacy/packages/igniter-cluster/
playgrounds/docs/dev/legacy/MESH_V1.md
playgrounds/docs/dev/legacy/MESH_QL_V1.md
playgrounds/docs/dev/legacy/CONSENSUS_V1.md
playgrounds/docs/dev/legacy/DISTRIBUTED_CONTRACTS_V1.md
packages/igniter-cluster/
examples/cluster/
```

Question:

```text
what is the formal distributed contract model hiding in legacy cluster work?
```

Expected signals:

- PeerProfile / PeerTopology
- MeshTopology
- ownership and lease policy
- trust/admission
- placement and rebalance
- consensus receipts
- partition observations
- vector clocks / causal context
- MeshQL

Output:

```text
distributed semantics staging plan: handoff -> causal mesh -> proactive cluster
```

Priority: medium-high.

### A12 — Ledger, Durable Model, Store Protocol, MCP

Sources:

```text
packages/igniter-ledger/docs/
packages/igniter-ledger/docs/intelligent-ledger/
packages/igniter-ledger-client/docs/
packages/igniter-durable-model/docs/
packages/igniter-mcp-adapter/
docs/store/
```

Question:

```text
how should facts, histories, receipts, protocol reads, and MCP become language
substrate rather than package-only behavior?
```

Expected signals:

- fact log and causation chain
- valid time / transaction time
- changefeed and replay
- compaction boundary
- relation reports
- derivation/inference
- protocol receipts
- MCP adapter as language tool surface

Output:

```text
Ledger-to-TBackend alignment report
```

Priority: high after A04.

### A13 — FFI, External Contracts, Interop

Sources:

```text
igniter-lang/docs/tracks/ffi-ruby-contractable-proof-v0.md
igniter-lang/docs/tracks/runtime-machine-ffi-ruby-receipt-fixtures-v0.md
igniter-lang/docs/tracks/runtime-machine-external-candidate-*.md
igniter-lang/docs/spec/ch2-source-surface.md
packages/igniter-embed/
examples/contracts/contractable_service.rb
examples/contracts/contractable_shadow.rb
```

Question:

```text
how does Igniter-Lang integrate other languages without hiding effects?
```

Expected signals:

- `external ruby|rust|js|wasm`
- contractable services
- shadow execution
- external candidate normalization
- FFI receipt
- purity/determinism/capability claims

Output:

```text
ExternalContract formal proposal pressure map
```

Priority: medium-high.

### A14 — Modeling, Simulation, Science, Physical Units, Deadlines

Sources:

```text
igniter-lang/docs/tracks/sandbox-simulation-world-modeling-*.md
igniter-lang/docs/tracks/observation-trust-classes-and-simulation-loop-semantics-v0.md
playgrounds/docs/experts/igniter-lang/igniter-lang-invariants.md
playgrounds/docs/experts/igniter-lang/igniter-lang-implementation.md
playgrounds/docs/research-horizon/line-up-approximation-method.md
```

Question:

```text
which scientific/modeling primitives should enter the language, and in what order?
```

Expected signals:

- WorldModel
- AssumptionSet
- ScenarioRun
- SyntheticObservation vs RealObservation
- CalibrationContract
- physical unit types
- deadline / WCET contracts
- forecast and counterfactual boundaries

Output:

```text
modeling primitives staging report
```

Priority: medium.

### A15 — Tooling, Diagnostics, REPL, Observatory, MCP

Sources:

```text
playgrounds/docs/research-horizon/runtime-observatory-graph.md
playgrounds/docs/research-horizon/dsl-repl-authoring-research.md
playgrounds/docs/dev/process/runtime-observatory-doctrine.md
igniter-lang/docs/proposals/PROP-027-production-compiler-diagnostics-contract-v0.md
igniter-lang/docs/tracks/compiler-diagnostics-*.md
packages/igniter-mcp-adapter/
packages/igniter-web/
```

Question:

```text
what tools make ECL usable, inspectable, and agent-operated?
```

Expected signals:

- structured diagnostics
- runtime observatory
- graph navigation
- MCP tool/read surface
- DSL/REPL authoring
- compiler reports as UI material

Output:

```text
devkit and observatory roadmap
```

Priority: medium.

### A16 — Frontend, Arbre, Tailwind, App-Local UI

Sources:

```text
playgrounds/legacy/packages/igniter-frontend/
playgrounds/extracted/sparkcrm/
packages/igniter-web/
docs/dev/igniter-web-dsl-sketch.md
```

Question:

```text
what should the language know about UI surfaces, and what should remain app-local?
```

Expected signals:

- Arbre as frontend authoring path
- Tailwind class composition
- UI components as app-local code
- operator surface contracts
- hardcoded HTML string rejection

Output:

```text
frontend boundary report: language vs app vs package
```

Priority: medium.

### A17 — Rebuild From Scratch And Self-Hosting

Sources:

```text
playgrounds/docs/experts/igniter-lang/igniter-lang-implementation.md
playgrounds/docs/research-horizon/igniter-lang-implementation-delta-report.md
docs/guide/igniter-lang-foundation.md
packages/igniter-contracts/
igniter-lang/lib/igniter_lang/
```

Question:

```text
what would rebuilding Igniter in Igniter-Lang prove, and what is the minimal path?
```

Expected signals:

- Ruby backend as reference implementation
- Rust backend future
- compiler self-hosting prerequisites
- `.igapp/` as knowledge unit
- language-foundation package bridge
- rebuild-from-scratch experiment boundaries

Output:

```text
self-hosting readiness ladder
```

Priority: medium-low until compiler extraction stabilizes.

---

## First Consolidation Rounds

### Round 1: Orientation And Origin

```text
A00 Archaeology Control Room
A01 Origin Series
A05 Temporal/History/OLAP/Stream
```

Reason:

```text
these slices recover the language's root identity before implementation details
dominate the story.
```

Expected deliverable:

```text
origin-to-current-canon concordance
```

### Round 2: Runtime And Evidence

```text
A04 RuntimeMachine/TBackend
A06 Observations/OSINT
A12 Ledger/Durable Model
```

Reason:

```text
this binds the "justified belief" thesis to actual storage/runtime evidence.
```

Expected deliverable:

```text
observation-history-substrate map
```

### Round 3: Human-Agent And Applications

```text
A07 Human-Agent Symbiosis
A08 Applications/Web
A09 Spark CRM
```

Reason:

```text
this grounds the language in human-readable workflows and real business pressure.
```

Expected deliverable:

```text
human-agent application primitive queue
```

### Round 4: Distributed And Interop

```text
A11 Cluster/Mesh
A13 FFI/Interop
A15 Tooling/MCP/Observatory
```

Reason:

```text
this shows how ECL scales across runtimes, languages, and agent-operated tools.
```

Expected deliverable:

```text
system-profile formal pressure map
```

### Round 5: Deferred Paradigm Expansion

```text
A02 General-Purpose Boundary
A10 Legacy Extensions
A14 Modeling/Science
A16 Frontend Boundary
A17 Self-Hosting
```

Reason:

```text
these are rich but should be interpreted after the core/history/runtime/product
signals are stable.
```

Expected deliverable:

```text
Stage 3+ concept staging proposal
```

---

## Signal Classes To Preserve

[D] Treat these as first-class archaeology tags:

```text
origin_signal
  idea present in early research before formal canon

canon_signal
  idea already accepted in spec/proposal/proof

lost_signal
  idea appears in old material but has no current formal home

package_signal
  idea exists in active Ruby packages but not in language docs

legacy_signal
  idea exists in legacy code; must be separated from obsolete implementation

product_signal
  idea appears only under application/business pressure

bridge_signal
  idea has package integration pressure but lacks formal language decision

rejection_signal
  idea should be explicitly rejected or deferred to prevent rediscovery loops
```

---

## Known High-Value Signals Already Identified

These should be tracked explicitly in future consolidation:

```text
SIR metric
out node as result-forming factor
contract as five formal identities
grammar-after-semantics
Ruby DSL as reference implementation
Backend interface: compile/execute/verify/export
HistorySegment content addressing
History[T] == OLAPPoint[T, {time}]
BiHistory four canonical queries
temporal synthesis via LP
Rule Dependency Graph and causal cycle classification
Plastic Runtime Cells / ownership unit
Igniter Plane / runtime observatory graph
physical unit types
deadline / WCET contracts
uplink-able rule declarations
CompensationContract / saga
ApprovalWorkflow / review freshness
MeaningDiff
SemanticImage as agent handoff
ExternalContract / FFI receipt
MeshTopology / ownership / trust / admission
LedgerBoundary / compaction / proof packets
MCP as operator/tool substrate
Arbre + Tailwind app-local frontend path
```

---

## Rejected For This Archaeology Pass

[X] Do not consolidate every idea immediately.

Reason:

```text
full consolidation would exceed context and recreate the same problem this
index is meant to solve.
```

[X] Do not treat legacy code as canon.

Reason:

```text
legacy code is evidence of pressure and prior implementation experiments,
not an accepted architecture.
```

[X] Do not promote ideas directly from playgrounds into Stage 2 implementation.

Reason:

```text
every recovered idea still needs formal ownership, proof path, and current
dependency placement.
```

---

## Handoff

```text
[Igniter-Lang Meta Expert]
Track: igniter-lang/docs/meta-proposals/META-EXPERT-008.3-project-archaeology-slice-index-v0.md
Status: done

[D] Decisions:
- Project archaeology is split into 18 bounded slices: A00..A17.
- The first consolidation round should be A00 + A01 + A05.
- Recovered concepts must be recorded as signals before they become PROPs,
  proofs, bridges, or rejections.
- Legacy/package/product signals are valuable but not canonical by default.
- The accepted role identity is Meta Expert, with inherited Compiler/Grammar
  formal discipline applied as a filter.

[R] Recommendations:
- Run Round 1 next: origin-to-current-canon concordance.
- Create a signal ledger only after Round 1 validates the record shape.
- Use this document as the archaeology control-room index.
- Keep future slices bounded to one layer or one concept cluster.

[S] Signals:
- The highest-density unmined sources are the early expert series, legacy
  cluster/core packages, Ledger/Durable Model docs, Spark CRM pressure, and
  research-horizon human-agent/tooling docs.
- Active packages contain language-relevant behavior not yet reflected in
  Igniter-Lang canon.
- Some ideas already promoted to Stage 2 still have richer older forms that
  should be rechecked, especially OLAP, temporal synthesis, time_machine,
  physical units, deadlines, and runtime cells.

[T] Tests / Proofs:
- No executable tests run. This is an inventory and indexing document.

[Q] Open Questions:
- Should future archaeology signal ledger live in `igniter-lang/docs/meta-proposals/`
  as markdown, or in a structured `igniter-lang/docs/archive/index/` directory?
- Should active package docs receive backlink notes once a signal is consolidated?
- Should Playground docs be marked with canonical successor links after each slice?

[X] Rejected:
- One-pass full archaeology.
- Treating legacy packages as accepted architecture.
- Starting new implementation from recovered concepts before formal routing.

[Next] Proposed next slice:
- archaeology-round1-origin-concordance-v0
  Read A01 + A05 sources and produce an origin-to-current-canon concordance
  with signal records for lost/deferred concepts.
```
