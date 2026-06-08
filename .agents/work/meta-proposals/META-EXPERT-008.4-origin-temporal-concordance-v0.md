# META-EXPERT-008.4: Origin Temporal Concordance v0

Role: `[Igniter-Lang Archive/Form Expert]`
Card: `S2-AF-R1-C1-S`
Track: `archaeology-round1-origin-concordance-v0`
Status: proposal
Date: 2026-05-07
Depends on: `META-EXPERT-008.3-project-archaeology-slice-index-v0`

Affected neighbors:
- `[Igniter-Lang Research Agent]`
- `[Igniter-Lang Compiler/Grammar Expert]`
- `[Igniter-Lang Bridge Agent]`

---

## Purpose

This document is the first origin-to-current-canon concordance for the early
Igniter-Lang language-birth and temporal research layers.

It does not create a giant signal database. It preserves only high-value signals
from A01 and A05, then classifies each against the current Stage 2 canon:

```text
current canon | current proof | missing formal home | rejected or parked
```

Recovered ideas are not promoted to canon here. They are routed.

---

## Source Layers

Primary archaeology slices:

```text
A01 -- Origin Series: Language Birth
A05 -- Temporal, History, BiHistory, OLAP, Stream
```

Read set:

```text
playgrounds/docs/experts/igniter-lang/README.md
playgrounds/docs/experts/igniter-lang/igniter-lang.md
playgrounds/docs/experts/igniter-lang/igniter-lang-theory.md
playgrounds/docs/experts/igniter-lang/igniter-lang-spec.md
playgrounds/docs/experts/igniter-lang/igniter-lang-implementation.md
playgrounds/docs/experts/igniter-lang/igniter-lang-temporal.md
playgrounds/docs/experts/igniter-lang/igniter-lang-temporal-deep.md
playgrounds/docs/experts/igniter-lang/igniter-lang-olap.md
playgrounds/docs/experts/igniter-lang/igniter-lang-persistence.md
igniter-lang/docs/current-status.md
igniter-lang/docs/spec/README.md
igniter-lang/docs/proposals/PROP-022-history-type-constructor-v0.md
igniter-lang/docs/proposals/PROP-023-stream-input-surface-v0.md
igniter-lang/docs/proposals/PROP-024-olap-point-primitive-v0.md
```

Current canon baseline:

- Stage 1 is closed.
- Stage 2 is active.
- `History[T]` / `BiHistory[T]` proof stack is PASS, with temporal access
  runtime and hook proof still being wired.
- `stream T` runtime proof is PASS, with OOF-S2 and OOF-S3 classifier/typechecker
  work still pending.
- `OLAPPoint[T, Dims]` proof is PASS, with grammar spec complete and parser /
  typechecker implementation pending.

---

## Concordance Table

| ID | Origin signal | First source layer | Current canon / proof | Status | Formal routing |
|----|---------------|-------------------|-----------------------|--------|----------------|
| S01 | Five formal identities: TFS, attribute grammar, CCP, stratified Datalog, category theory | A01 theory | Partly reflected in language model and Stage 1 pipeline, but not a single current proof artifact | partial_canon | Future doctrine/proof bridge: every new construct should name its formal identity pressure |
| S02 | Semantic Information Ratio: business claims per LOC, target greater than 2x Ruby DSL + executors | A01 language birth | Not in Stage 2 proofs | research | Future benchmark/diagnostic proposal, likely after real app corpus exists |
| S03 | Grammar-after-semantics discipline | A01 implementation | Active process norm: parser/spec follows SemanticIR/proof evidence | current_canon | Keep as governance rule, not a grammar feature |
| S04 | Ruby DSL as reference implementation plus explicit Backend interface | A01 implementation | Partly embodied by current Ruby foundation and package split | partial_canon | Needs LanguageContract/BackendContract formal home before multi-backend claims |
| S05 | DAG core is intentionally not Turing-complete; recursion/iterate/stream are explicit opt-ins | A01 language birth/theory | Stage 2 stream formalizes one opt-in escape path | partial_canon | Future general-purpose profile proof should keep CORE/ESCAPE boundary explicit |
| S06 | Early construct inventory: guard, branch, collection, aggregate, effect, await, compose, const, out | A01 spec | Some exist in Ruby Igniter and current pipeline; not all are Stage 2 language surface | mixed | Route per construct; do not bulk-promote old surface syntax |
| S07 | `History[T]`, temporal access, `as_of`, `@temporal` | A05 temporal | PROP-022 proof PASS; temporal access runtime partial/hook smoke exists | covered_by_stage2_proof | Continue current RuntimeMachine hook proof; preserve non-ambient time discipline |
| S08 | `BiHistory[T]` valid time + transaction time, four canonical queries | A05 temporal/deep | PROP-022 proof PASS; axes typechecked | covered_by_stage2_proof | Current canon is adequate for first bitemporal layer |
| S09 | Temporal rules, rule algebra, priority/combines, causal chain detection/RDG | A05 temporal/deep | Not in PROP-022 core | richer_than_canon | Future rule-system PROP/proof; Bridge Agent should map to invariants and diagnostics |
| S10 | Temporal synthesis: synthesize rules from temporal goals via LP/simplex | A05 temporal/deep | Not current canon | research | Keep as future proof candidate after rule algebra has a home |
| S11 | Distributed time: Lamport/vector clocks, causal `as_of`, consistency parameter | A05 temporal/deep/persistence | Not current Stage 2 canon | richer_than_canon | Future mesh/runtime consistency PROP or bridge to Ledger/cluster |
| S12 | `stream T` as explicit ESCAPE with bounded fold bridge back to CORE | A01 language birth, A05 current canon | PROP-023 runtime proof PASS | covered_by_stage2_proof | Finish OOF-S2/OOF-S3 classifier/typechecker work |
| S13 | `History[T] == OLAPPoint[T, {time: DateTime}]` unification | A05 OLAP | PROP-022 and PROP-024 both state the unification; OLAP proof PASS | covered_by_stage2_proof | Preserve as cross-PROP invariant |
| S14 | OLAPPoint first-class construct with slice/rollup/drill/compare/transform/resolve/source/scatter-gather | A05 OLAP | PROP-024 proof PASS; grammar spec done | covered_by_stage2_proof | Finish parser/typechecker implementation |
| S15 | `time_machine` and `Forecast[T]` for backward/forward/counterfactual/approximate time travel | A05 OLAP/implementation | Not current canon | richer_than_canon | Future temporal synthesis/forecast PROP after History/OLAP lowering stabilizes |
| S16 | `Store[T]` as language construct; persistence as type-directed backend contract | A05 persistence/implementation | Not formal language canon; related platform/runtime pressure exists | richer_than_canon | Future Store/Backend/RuntimeContract bridge, not immediate Stage 2 PROP |
| S17 | HistorySegment/DistributedHistory internals, append-only sealed segments, cluster partitioning | A05 OLAP/persistence | Current Stage 2 says type semantics, not physical lowering | bridge_candidate | Route to Bridge Agent for Ledger/Store lowering, keep out of source grammar for now |
| S18 | Ambient current-time aliases such as `price.current` / implicit `DateTime.now()` | A05 temporal | Current PROP-022 rejects ambient Time.now direction | parked_or_rejected | Preserve as historical warning: use explicit `as_of` / hook semantics |

---

## Signal Records

### Signal S01

```text
id: S01-five-formal-identities
source_paths: igniter-lang-theory.md, README.md
first_seen_layer: A01
current_status: partial_canon
concept: Contract as the shared mathematical object seen through TFS, attribute grammar, CCP, stratified Datalog, and category theory.
why_it_matters: This is the deepest anti-drift anchor: new features should be checked against the same convergence, not merely against syntax taste.
current_canonical_home: Stage 1/Stage 2 language model, SemanticIR, typechecker, runtime proof style.
missing_formal_home: A compact doctrine tying each future construct to one or more identities.
proof_candidate: Construct-level identity matrix: parser/type/runtime/diagnostic obligations per identity.
bridge_candidate: Compiler/Grammar Expert review checklist.
risk_if_lost: Igniter-Lang becomes a normal DSL with contract words instead of an epistemic contract language.
```

### Signal S02

```text
id: S02-semantic-information-ratio
source_paths: igniter-lang.md, igniter-lang-theory.md, README.md
first_seen_layer: A01
current_status: research
concept: SIR = distinct business claims / total LOC; hypothesis that contract-native syntax reaches greater than 2x Ruby DSL plus executor classes.
why_it_matters: Gives language design an empirical density metric instead of relying on aesthetic brevity.
current_canonical_home: none
missing_formal_home: Benchmark protocol and claim-counting rubric.
proof_candidate: Rewrite corpus across Ruby Igniter DSL, current Igniter-Lang surface, and future grammar.
bridge_candidate: Diagnostics/reporting can emit claim density once SemanticIR is stable.
risk_if_lost: Grammar work may optimize for prettiness rather than semantic compression.
```

### Signal S03

```text
id: S03-grammar-after-semantics
source_paths: igniter-lang-implementation.md, README.md
first_seen_layer: A01
current_status: current_canon
concept: Ruby DSL is used to prove semantics before freezing concrete grammar.
why_it_matters: Prevents syntax from becoming a premature constraint on the language model.
current_canonical_home: Stage 2 operating practice: proof/SemanticIR before parser implementation.
missing_formal_home: Governance gate naming when grammar is allowed to advance.
proof_candidate: Require every grammar extension to point to a SemanticIR/proof/OOF artifact.
bridge_candidate: Meta governance and Compiler/Grammar Expert review.
risk_if_lost: Parser surface locks in early historical vocabulary before the contract model stabilizes.
```

### Signal S04

```text
id: S04-ruby-dsl-reference-backend
source_paths: igniter-lang-implementation.md
first_seen_layer: A01
current_status: partial_canon
concept: Ruby DSL as reference implementation; Backend interface with compile, execute, verify, export.
why_it_matters: Keeps implementation evidence and future Rust/certified/export backends aligned to the same AST/SemanticIR.
current_canonical_home: Ruby Igniter implementation, package split, current compiler/runtime proof practice.
missing_formal_home: LanguageContract/BackendContract model that treats language, runtime, and backend as contracts.
proof_candidate: Backend equivalence proof: same SemanticIR, same OOF, same externally visible contract result.
bridge_candidate: Bridge Agent can map Ruby runtime packages to future backend contract boundary.
risk_if_lost: Multi-backend ambition fragments into ad hoc ports.
```

### Signal S05

```text
id: S05-dag-core-explicit-escape
source_paths: igniter-lang.md, igniter-lang-theory.md
first_seen_layer: A01
current_status: partial_canon
concept: DAG CORE remains decidable/PTIME/non-Turing-complete; recursion, iterate, and stream are explicit escape mechanisms.
why_it_matters: This is the language's safety contract and the basis for diagnostics, resource bounds, and explainability.
current_canonical_home: CORE/ESCAPE split, PROP-023 stream ESCAPE proof.
missing_formal_home: General-purpose profile that names all allowed escape constructors.
proof_candidate: Extension hierarchy proof: DAG, bounded fold, iterate, recursion, stream.
bridge_candidate: RuntimeMachine and diagnostics severity routing.
risk_if_lost: General-purpose language pressure quietly erodes decidability and traceability.
```

### Signal S06

```text
id: S06-origin-construct-inventory
source_paths: igniter-lang-spec.md, igniter-lang.md
first_seen_layer: A01
current_status: mixed
concept: Early v0.1 construct set: contract, in, compute, const, guard, branch, compose, collection, aggregate, effect, await, out.
why_it_matters: It preserves the original breadth of the language beyond the current Stage 2 type-constructor focus.
current_canonical_home: Some constructs exist in Ruby Igniter and current language pipeline; others are not active Stage 2 canon.
missing_formal_home: Per-construct concordance against parser/type/runtime/OOF.
proof_candidate: One small table, not one giant PROP, classifying each construct as CORE, ESCAPE, runtime-only, or parked.
bridge_candidate: Compiler/Grammar Expert plus Bridge Agent.
risk_if_lost: Stage 2 may over-focus on temporal types and forget workflow/effect/await pressure.
```

### Signal S07

```text
id: S07-history-temporal-access-as-of
source_paths: igniter-lang-temporal.md, PROP-022-history-type-constructor-v0.md
first_seen_layer: A05
current_status: covered_by_stage2_proof
concept: History[T] as value over valid time, temporal access, explicit as_of, @temporal annotation pressure.
why_it_matters: This is the first major temporal identity of the language: values become histories without breaking existing contracts.
current_canonical_home: PROP-022, current status History/BiHistory proof stack, temporal_access_runtime lib.
missing_formal_home: RuntimeMachine hook proof still needs full closure.
proof_candidate: Finish temporal access hook proof against current RuntimeMachine.
bridge_candidate: Runtime/Bridge Agent.
risk_if_lost: Temporal model regresses to ad hoc timestamps and reporting filters.
```

### Signal S08

```text
id: S08-bihistory-axes-and-queries
source_paths: igniter-lang-temporal.md, igniter-lang-temporal-deep.md, PROP-022-history-type-constructor-v0.md
first_seen_layer: A05
current_status: covered_by_stage2_proof
concept: BiHistory[T] adds valid time and transaction time; four canonical query forms distinguish truth and knowledge.
why_it_matters: It is the audit/compliance backbone for corrections without historical mutation.
current_canonical_home: PROP-022 proof PASS and current spec fixture/typecheck notes.
missing_formal_home: Physical lowering and distributed consistency are not in PROP-022.
proof_candidate: No new language proof needed for first layer; use future lowering bridge.
bridge_candidate: Ledger/Store lowering later.
risk_if_lost: Corrections and audit semantics collapse into mutable History.
```

### Signal S09

```text
id: S09-temporal-rules-rdg
source_paths: igniter-lang-temporal.md, igniter-lang-temporal-deep.md
first_seen_layer: A05
current_status: richer_than_canon
concept: Temporal rule declarations, priority, combines, rule dependency graph, causal cycle detection.
why_it_matters: Older temporal work models business policy change, not only historical data access.
current_canonical_home: none in Stage 2 temporal core.
missing_formal_home: Rule algebra PROP/proof and diagnostics.
proof_candidate: Horn-fragment temporal rule evaluation with RDG cycle OOF.
bridge_candidate: Invariant diagnostics and future rule system.
risk_if_lost: Time-aware policy behavior remains outside the language while temporal storage becomes formal.
```

### Signal S10

```text
id: S10-temporal-synthesis
source_paths: igniter-lang-temporal.md, igniter-lang-temporal-deep.md
first_seen_layer: A05
current_status: research
concept: Synthesize pricing/discount/rule changes from temporal goals, with linear cases reducible to LP/simplex.
why_it_matters: This points from contract execution to contract planning and reverse composition.
current_canonical_home: none
missing_formal_home: Needs rule algebra, objective types, and solver boundary.
proof_candidate: Bounded linear temporal synthesis proof after rule algebra exists.
bridge_candidate: Research Agent later, not current Stage 2 implementation.
risk_if_lost: Igniter-Lang misses its planning/logistics/ERP leverage point.
```

### Signal S11

```text
id: S11-distributed-time-consistency
source_paths: igniter-lang-temporal.md, igniter-lang-temporal-deep.md, igniter-lang-persistence.md
first_seen_layer: A05
current_status: richer_than_canon
concept: as_of over DateTime or LogicalTimestamp, knowledge_as_of, consistency parameter, Lamport/vector clocks.
why_it_matters: Mesh and decentralized agent systems need time semantics that survive clock disagreement.
current_canonical_home: none in Stage 2 language canon.
missing_formal_home: Runtime/cluster consistency contract.
proof_candidate: Causal as_of semantics for distributed RuntimeMachine.
bridge_candidate: Ledger, cluster, and MCP/agent runtime bridge.
risk_if_lost: Distributed apps inherit ambient wall-clock ambiguity.
```

### Signal S12

```text
id: S12-stream-escape-fold-bridge
source_paths: igniter-lang.md, PROP-023-stream-input-surface-v0.md
first_seen_layer: A01 to Stage 2
current_status: covered_by_stage2_proof
concept: stream T is never CORE by itself; bounded fold_stream bridges stream input back to CORE.
why_it_matters: It is the cleanest example of explicit escape with formal re-entry.
current_canonical_home: PROP-023 runtime proof PASS.
missing_formal_home: OOF-S2 classifier and OOF-S3 typechecker still pending.
proof_candidate: Complete classifier/typechecker diagnostics for missing window and non-CORE accumulator.
bridge_candidate: Compiler/Grammar Expert.
risk_if_lost: Streams become an unbounded loophole in the decidable core.
```

### Signal S13

```text
id: S13-history-olap-unification
source_paths: igniter-lang-olap.md, PROP-022-history-type-constructor-v0.md, PROP-024-olap-point-primitive-v0.md
first_seen_layer: A05
current_status: covered_by_stage2_proof
concept: History[T] is OLAPPoint[T, {time: DateTime}].
why_it_matters: This turns temporal data and analytical data into one dimensional model rather than two subsystems.
current_canonical_home: PROP-022 and PROP-024.
missing_formal_home: Cross-PROP invariant should be preserved during implementation.
proof_candidate: Parser/typechecker tests should assert the unification does not fork.
bridge_candidate: Compiler/Grammar Expert.
risk_if_lost: History and OLAP diverge into incompatible features.
```

### Signal S14

```text
id: S14-olap-point-primitive
source_paths: igniter-lang-olap.md, PROP-024-olap-point-primitive-v0.md
first_seen_layer: A05
current_status: covered_by_stage2_proof
concept: OLAPPoint with dimensions, measure, source, indexed dimensions, slice/rollup/drill/compare/transform/resolve.
why_it_matters: It makes analytical surfaces first-class language artifacts, not external BI queries.
current_canonical_home: PROP-024 proof PASS and grammar spec.
missing_formal_home: Parser/typechecker implementation.
proof_candidate: Current OLAPPoint parser/typechecker boundary track.
bridge_candidate: Compiler/Grammar Expert.
risk_if_lost: Enterprise modeling pressure falls back to external analytics tools.
```

### Signal S15

```text
id: S15-time-machine-forecast
source_paths: igniter-lang-olap.md, igniter-lang-implementation.md
first_seen_layer: A05
current_status: richer_than_canon
concept: time_machine and Forecast[T] for backward replay, deterministic future, counterfactual scenarios, and approximate extrapolation.
why_it_matters: This is the temporal bridge from audit to planning and simulation.
current_canonical_home: none in current Stage 2 canon.
missing_formal_home: Forecast type, scenario semantics, approximate value boundary, and counterfactual execution contract.
proof_candidate: Future temporal simulation PROP after History/OLAP and rule algebra are stable.
bridge_candidate: Research Agent plus Bridge Agent.
risk_if_lost: Forward-looking model remains an application convention instead of a language capability.
```

### Signal S16

```text
id: S16-store-type-directed-persistence
source_paths: igniter-lang-persistence.md, igniter-lang-implementation.md
first_seen_layer: A05
current_status: richer_than_canon
concept: Store[T] as contract-level persistent object; type determines storage shape, access pattern, partitioning, and consistency.
why_it_matters: It extends "everything is contract" into persistence and backend selection.
current_canonical_home: none as language canon; adjacent pressure exists in runtime/ledger/package work.
missing_formal_home: Store/Backend/RuntimeContract bridge.
proof_candidate: Type-to-backend lowering proof for History, BiHistory, OLAPPoint, entity, await, cache.
bridge_candidate: Bridge Agent should own the first lowering map.
risk_if_lost: Persistence becomes infrastructure config again, outside the epistemic contract.
```

### Signal S17

```text
id: S17-history-segment-distributed-history
source_paths: igniter-lang-olap.md, igniter-lang-persistence.md
first_seen_layer: A05
current_status: bridge_candidate
concept: HistorySegment, sealed append-only segments, content addressing, partition maps, O(log n) reads, scatter-gather rollups.
why_it_matters: This is the physical lowering pressure hidden under high-level temporal types.
current_canonical_home: not source-language canon.
missing_formal_home: Ledger/Store implementation bridge, not grammar.
proof_candidate: Lowering invariant: logical History operations preserve results across segmented/distributed storage.
bridge_candidate: Bridge Agent and platform package owners.
risk_if_lost: Stage 2 types prove syntax but leave no path to scalable execution.
```

### Signal S18

```text
id: S18-ambient-current-time-warning
source_paths: igniter-lang-temporal.md, PROP-022-history-type-constructor-v0.md
first_seen_layer: A05
current_status: parked_or_rejected
concept: Historical convenience aliases such as current price resolving through ambient DateTime.now.
why_it_matters: It records why the current canon avoids ambient time.
current_canonical_home: PROP-022 rejects ambient Time.now direction.
missing_formal_home: none unless a future ergonomics layer can preserve explicit as_of semantics.
proof_candidate: none now.
bridge_candidate: Diagnostics could suggest explicit as_of when users ask for current.
risk_if_lost: Convenience syntax may reintroduce nondeterminism under a friendly name.
```

---

## Covered by Stage 2 Proofs

Recovered ideas already covered by current Stage 2 proof work:

- `History[T]` and `BiHistory[T]` type constructors, including bitemporal axes
  and the four canonical query shapes.
- Temporal access lowering is partially covered: runtime lib and hook smoke exist,
  while the full RuntimeMachine hook proof remains open.
- `stream T` as ESCAPE and bounded `fold_stream` as the CORE bridge.
- `History[T] == OLAPPoint[T, {time: DateTime}]` as a cross-PROP unification.
- `OLAPPoint[T, Dims]` as a first-class primitive with slice/rollup/drill/compare/
  transform/resolve and `source:` bridge.

These should not be reauthored as new proposals. They should be protected during
implementation.

---

## Richer Than Current Canon

Recovered ideas richer than the current Stage 2 canon:

- SIR as a measurable language-quality metric.
- Five formal identities as a construct-review doctrine.
- Backend interface as a formal LanguageContract/RuntimeContract/BackendContract
  composition, not only a runtime engineering intention.
- Full early construct inventory, especially `effect` and `await` language
  pressure.
- Temporal rules, rule algebra, RDG, causal-cycle diagnostics.
- Temporal synthesis and reverse planning from goals to contracts/rules.
- Distributed time, logical clocks, causal `as_of`, and consistency parameters.
- `time_machine` and `Forecast[T]`.
- `Store[T]`, type-directed persistence, materialization-as-contract, and
  `ExecutionCheckpoints == History[ExecutionState]`.
- HistorySegment/DistributedHistory physical lowering.

Recommendation: do not open all of these as PROP docs now. The useful next move
is one more archaeology slice that tests whether this Signal format survives a
different source layer, especially runtime/ledger/mesh pressure. After that, a
living signal ledger can be created with less risk of encoding this first slice's
biases as permanent taxonomy.

---

## Rejected or Parked Signals

Parked/rejected does not mean useless. It means the historical signal should not
be reintroduced without a proof-level reason.

- Ambient current-time access remains parked/rejected in favor of explicit
  `as_of` / hook semantics.
- Mutable History remains rejected by PROP-022 direction.
- `stream T` as CORE remains rejected by PROP-023.
- Implicit stream windows remain rejected by PROP-023.
- OLAPPoint as a library-only helper remains rejected by PROP-024.

---

## Handoff

Card: `S2-AF-R1-C1-S`
Role: `[Igniter-Lang Archive/Form Expert]`
Track: `archaeology-round1-origin-concordance-v0`
Status: proposal

[D] Delivered first compact A01/A05 origin-to-current-canon concordance with
18 Signal records and a routing table.

[S] Current Stage 2 already covers History/BiHistory, stream bounded fold, and
OLAPPoint as proof-backed language constructs. Temporal access still needs the
current RuntimeMachine hook proof closure noted in status.

[T] The highest-value richer-than-canon signals are SIR, five-identity review
doctrine, temporal rule/RDG algebra, temporal synthesis, distributed time,
Forecast/time_machine, and Store/History lowering.

[R] Do not create the living signal ledger yet. Run one more archaeology slice
first, preferably runtime/ledger/mesh pressure, then freeze the ledger schema.

[Next] Bridge Agent should eventually receive S16/S17 as Store/History lowering
pressure. Compiler/Grammar Expert should protect S12/S13/S14 during current
Stage 2 implementation and keep S03 as the grammar gate.
