# META-EXPERT-008.2: Fresh Language Model Report v0

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Track: `igniter-lang/docs/meta-proposals/META-EXPERT-008.2-fresh-language-model-report-v0.md`
Status: proposal
Date: 2026-05-07
Scope: fresh strategic report requested as a Meta Expert extension of the
Compiler/Grammar Expert role

Affected neighbors:
- `[Igniter-Lang Research Agent]`
- `[Igniter-Lang Bridge Agent]`
- `[Igniter-Lang Applied Pressure Agent]`

---

## Entry Claim

[D] Igniter-Lang is now past the "convincing fiction" risk for Stage 1.
The language has a proven spine:

```text
source.ig
  -> ParsedProgram
  -> ClassifiedProgram
  -> TypedProgram
  -> SemanticIRProgram + CompilationReport
  -> .igapp/
  -> RuntimeMachine
```

Stage 2 should therefore stop arguing for the language's existence and start
making its paradigm composable at larger scales: applications, domains,
runtime environments, agent handoff, FFI, distributed mesh, and eventually
self-hosting.

[D] The fixed point remains correct:

```text
Igniter-Lang = Epistemic Contract Language
contract + explicit time + observation + lifecycle + capability
  -> reproducible meaning
```

The new pressure is sharper:

```text
if every computation is a contract,
then the language is a contract,
the runtime is a contract,
the environment is a contract,
and a cluster of environments is a composition of contracts.
```

This is not just a slogan. It should become a formal design lane.

---

## Current Reading Of The System

### What Is Already Strong

[S] The current core has unusually good shape:

- `CORE / ESCAPE / OOF` is a real trust calculus, not a cosmetic effect tag.
- Explicit `TemporalCtx` makes time a semantic input, not infrastructure.
- `ObsPacket`, `CompilationReport`, `SemanticImage`, and
  `CompatibilityReport` create an agent-readable evidence chain.
- `History[T]`, `BiHistory[T]`, `stream T`, `OLAPPoint[T,Dims]`, and invariant
  severity are the right Stage 2 primitives. They are not random features;
  they are consequences of the ECL thesis.
- The `.igapp/` artifact is becoming a deployable knowledge unit: inspectable
  before execution, loadable by RuntimeMachine, and suitable for registries.

### What Is Still Fragile

[S] The largest remaining risk is not "more syntax." It is semantic span:

```text
single contract proof     -> strong
single runtime proof      -> strong
compiler package surface  -> improving
multi-contract app model  -> weakly crystallized
distributed runtime mesh  -> mostly deferred
general-purpose profile   -> not yet bounded
human-agent review loop   -> rich tracks, not yet core vocabulary
```

[R] Stage 2 should preserve the current extraction priority
(`typechecker.rb` next), but it should also open one cross-cutting meta lane:
**Contractual General-Purpose Profile**.

---

## Main Insight: General Purpose Without Losing Decidability

Igniter-Lang should not become a general-purpose language by weakening CORE.
It should become general-purpose by separating three profiles:

```text
CORE Profile
  finite, typed, stratified, terminating, reproducible

CONTRACT Profile
  CORE + declared ESCAPE + receipts + capability policy

SYSTEM Profile
  composition of contracts, runtimes, FFI adapters, cells, and TBackends
```

[D] "General-purpose" in Igniter-Lang should mean:

```text
able to build real systems
without making ambient state, ambient time, undeclared effects,
or unverifiable runtime behavior part of the language core.
```

That implies these compiler-visible capabilities:

- bounded control: `fold`, `fold_stream`, later `iterate(max_steps)` or
  `fold_until` with explicit bound/witness
- closed choice: ADT / variants / pattern matching over statically known arms
- interop: `external` declarations as typed capability contracts, never raw FFI
- system composition: RuntimeContract and LanguageContract treated like normal
  contract surfaces
- diagnostics: every compiler and runtime boundary emits structured evidence

[X] Rejected: Turing-complete CORE as a goal.

Reason: it would destroy the strongest differentiator: reproducible, auditable,
decidable computation by construction.

---

## Recommended New Meta Lane: Language-As-Contract

[R] Author a formal proposal after the current typechecker extraction:

```text
PROP-028 candidate:
LanguageContract + RuntimeContract Composition
```

Purpose:

```text
LanguageContract = Record {
  grammar_version,
  semanticir_version,
  stdlib_profile,
  accepted_fragment_classes,
  oof_rule_set,
  diagnostic_contract,
  compatibility_rules
}

RuntimeContract = Record {
  runtime_version,
  backend_contract,
  execution_environment,
  capability_executor,
  cache_policy,
  temporal_clock_policy,
  receipt_profile
}

EvaluationContract =
  LanguageContract
  + RuntimeContract
  + ProgramContract
  + UserContract
  + TemporalCtx
```

The output is not only `result`; it is:

```text
result | observations | failures | receipts | meaning_status
```

[D] This gives a formal answer to the user's meta-thesis:

```text
if the language is a contract,
then evaluating a program is contract composition.
if the runtime is a contract,
then moving between runtimes is compatibility-checked composition.
if many runtimes run in parallel,
then the cluster is a contract over RuntimeContracts.
```

Compiler implications:

- `CompilationReport` should eventually cite `LanguageContract`.
- `.igapp/manifest.json` should carry or reference the `LanguageContract`
  fingerprint used to compile it.
- `CompatibilityReport` should compare `LanguageContract` and
  `RuntimeContract`, not only schema/runtime/backend dimensions.

---

## Fractal Traceability: OSINT As Native Projection

[D] OSINT-like systems are not an add-on vertical. They are the most obvious
projection of the ECL model.

The same structure repeats:

```text
language axiom
  -> grammar rule
  -> classifier/typechecker decision
  -> SemanticIR node
  -> runtime evaluation
  -> observation
  -> domain claim
  -> evidence link
  -> contradiction/correction
  -> user-facing report
```

[R] Define a minimal "traceability spine" that every layer can share:

```text
TraceRef = Record {
  subject_ref,
  layer: :axiom | :grammar | :compiler | :runtime | :domain | :application,
  rule_ref,
  source_span?,
  artifact_hash?,
  observation_ref?,
  parent_refs
}
```

This would let an OSINT product explain:

```text
why this claim exists
which source produced it
which contract transformed it
which language rule allowed that transformation
which runtime executed it
which policy permits acting on it
```

[R] Do not start a large OSINT product track yet. Start with one vertical
fixture after typechecker extraction:

```text
Claim -> EvidenceLink -> ContradictionReport -> EvidenceLinkedAlert
```

Acceptance:

- compiles through production CLI
- emits `CompilationReport`
- produces `.igapp/`
- RuntimeMachine evaluates one deterministic synthetic case
- every output has `aggregated_from` or explicit reason why not

---

## Mesh And Distributed Agent Systems

The existing model already has the seed:

```text
SemanticImage + CompatibilityReport = typed agent handoff
RuntimeMachine = execution owner
TBackend = temporal substrate
Capability = declared ESCAPE right
```

But distributed semantics are still too implicit. Treating all distribution as
generic ESCAPE is safe, but it is not enough for mesh clusters.

[R] Sequence distributed work in four layers:

```text
Layer 1: compatible handoff
  Runtime A checkpoints -> Runtime B verifies -> Runtime B resumes

Layer 2: replicated substrate
  one logical TBackend profile, multiple adapters/nodes

Layer 3: causal mesh
  CausalCtx / vector clock / partition observation / freshness policy

Layer 4: proactive agent cluster
  WatchContract + ActionPolicy + HumanReview + ExecutionReceipt
```

[R] Formal primitives should be added only when each layer needs them:

```text
CausalCtx
MeshTopology
RuntimeCell
CapabilityGrant
PartitionObservation
ConsensusReceipt
EventualConsistencyWindow
```

[D] The first distributed rule should be negative:

```text
OOF-MESH1:
remote runtime evidence used for mutation-grade action
without RuntimeContract compatibility + causal context + freshness policy
```

This preserves safety while allowing research to advance.

---

## ERP/CRM, Planning, Logistics, Business Processes

Spark CRM remains the best applied pressure lane because it stresses:

- tenant scope
- idempotency
- policy freshness
- action visibility vs action executability
- Decimal correctness
- audit receipts
- human approval
- operation lifecycle

[R] The next high-value business primitive is still:

```text
CompensationContract
```

Why:

```text
real business processes are not single successful DAGs;
they are partial successes, retries, cancellations, reversals,
and audit-preserving no-ops.
```

Suggested shape:

```text
CompensationContract = Record {
  compensates: ContractRef,
  trigger: :failure | :timeout | :cancel | :policy_revoked,
  reverses: Collection[ReceiptRef],
  emits: CompensationReceipt,
  idempotency_key,
  audit_lifecycle: :audit
}
```

[R] Pair it with a smaller `ApprovalWorkflow` surface:

```text
ActionCandidate
  -> ReviewProjection
  -> HumanReview
  -> ApprovedAction | RejectedAction
  -> ExecutionReceipt
```

OOF direction:

```text
OOF-ACT1:
execution uses stale ReviewProjection instead of fresh ExecutableActionCheck
```

This connects directly to existing operation-action tracks.

---

## Modeling Out Of The Box

[D] Modeling is a first-class consequence of ECL because simulations are just
contracts whose observations are explicitly synthetic, counterfactual, forecast,
or calibrated.

The minimum modeling vocabulary should be:

```text
WorldModel
AssumptionSet
ParameterSet
Intervention
ScenarioRun
SyntheticObservation
CounterfactualObservation
ForecastObservation
CalibrationContract
ModelValidityReport
```

[R] Keep one invariant absolute:

```text
simulation_success != production truth
counterfactual_improvement != authorized action
```

Compiler/type implications:

- synthetic observations must not satisfy factual evidence requirements
  without explicit calibration
- seeded randomness is ESCAPE unless the seed and generator profile are part
  of the contract
- optimization solvers are ESCAPE with `SolverReceipt`
- `~T` should be a typed uncertainty lift, not a float confidence comment

---

## FFI And Interlanguage Boundary

The grammar already reserves:

```text
external ruby | rust | js | wasm
```

This is strategically important. To become a high-integration language,
Igniter-Lang needs FFI at the language level, not as runtime glue.

[R] Future FFI proposal should define:

```text
ExternalContract = Record {
  lang,
  symbol,
  abi_profile,
  input_schema,
  output_schema,
  purity_claim: :pure | :reads | :writes | :unknown,
  determinism_claim: :deterministic | :seeded | :nondeterministic,
  capability_required,
  sandbox_profile,
  receipt_kind,
  idempotency_policy
}
```

Classifier rule:

```text
external pure deterministic with no ambient reads -> CORE candidate
external with IO, network, filesystem, clock, randomness -> ESCAPE
external undeclared side effects -> OOF
```

[D] FFI is where Igniter-Lang can cover general-purpose needs without
poisoning CORE.

---

## Reverse Planning And Contract Composition

Reverse planning should not mean "an LLM writes code until it works." In ECL,
it should mean:

```text
GoalContract + available ContractRegistry + constraints
  -> PlanCandidate
  -> ProofObligations
  -> HumanReview / SolverReceipt
  -> CompiledContractComposition
```

[R] Introduce typed holes only as planning artifacts:

```text
Hole[T] = unresolved value of type T with obligation set O
```

Rules:

- `Hole[T]` never enters SemanticIR as executable runtime code.
- A plan with holes may produce a diagnostic/proposal artifact.
- A hole is discharged only by a contract, literal, FFI capability, or human
  acceptance receipt.

This gives agents a safe way to compose ideas in the language while humans
read and review the plan.

---

## Human-Agent Symbiosis

[D] The strongest human-agent affordance is not natural language. It is
reviewable semantic structure.

The agent writes:

```text
contract, observation, evidence, failure, receipt, diff
```

The human reads:

```text
what changed, why it changed, what it depends on,
what can be trusted, what requires review,
and what action is allowed.
```

[R] Treat `MeaningDiff` as central to the developer experience:

```text
source diff
  -> ParsedProgram diff
  -> SemanticIR diff
  -> Observation/evidence impact diff
  -> Runtime compatibility diff
```

This is how the language becomes agent-friendly without becoming opaque.

---

## Documentation And Governance Drift

[S] Fresh-read issues found:

1. `docs/language-spec.md` is stale relative to `docs/spec/README.md`.
   It still says version 0.3 and contains old blocked/pending wording.
2. `docs/spec/ch6-semanticir.md` still contains an older note that the
   assembler experiment is "not yet implemented", while current status and
   Stage 1 close mark assembler A1-A6 PASS.
3. `docs/spec/ch7-runtime.md` still says stdlib operator evaluation is not
   yet proven in a way that conflicts with current Stage 1/Stage 2 evidence.
4. `docs/spec/ch9-stage2-reserved.md` has stale queued numbering
   (`PROP-026` etc.) while the canonical queue now starts new Stage 2 work
   at `PROP-028`.

[R] Add a small documentation sync slice:

```text
spec-entrypoint-sync-v0
```

Scope:

- update `docs/language-spec.md` to point to spec v0.8 and current status
- remove stale "assembler not yet implemented" wording from Ch6
- align Ch7 proof caveats with Stage 2 R6 evidence
- align Ch9 queued numbering with META-EXPERT-008.1

Do not change semantics in that slice.

---

## Priority Ordering

### Tier 0: Keep The Compiler Extraction Moving

[R] Do next:

```text
extract-typechecker-module-v0
```

Reason: many higher-level OOF rules need a production TypeChecker boundary.

### Tier 1: Close Small Stage 2 Implementation Gaps

[R] Then:

```text
stream-oof-s2-classifier-v0
olap-point-parser-implementation-v0
runtime-machine-temporal-access-hook-proof-v0
spec-entrypoint-sync-v0
```

### Tier 2: Open One Cross-Cutting Formal Lane

[R] After typechecker extraction:

```text
PROP-028 candidate: LanguageContract + RuntimeContract Composition
```

This should be formal, small, and compiler-visible.

### Tier 3: Applied Proof Verticals

[R] Then add one vertical fixture each:

```text
OSINT minimum traceability vertical
Spark CRM compensation/approval vertical
Simulation calibration vertical
FFI external contract vertical
```

One fixture per domain. No broad essay expansion.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/meta-proposals/META-EXPERT-008.2-fresh-language-model-report-v0.md
Status: done

[D] Decisions:
- The ECL fixed point is correct and should be extended as LanguageContract +
  RuntimeContract + ProgramContract + UserContract + TemporalCtx composition.
- General-purpose coverage should be achieved through CORE / CONTRACT / SYSTEM
  profiles, not through Turing-complete CORE.
- OSINT is a native projection of the traceability model, but should advance
  through one executable vertical fixture after compiler extraction.
- Distributed work should begin with negative OOF safety rules and compatible
  RuntimeMachine handoff, not full consensus semantics.
- FFI should be a typed ExternalContract surface with purity/determinism/capability
  claims, receipts, and classifier rules.

[R] Recommendations:
- Continue with extract-typechecker-module-v0 as the immediate Tier 0 move.
- Add spec-entrypoint-sync-v0 to remove stale entrypoint/spec wording.
- Prepare PROP-028 candidate for LanguageContract + RuntimeContract Composition
  after typechecker extraction.
- Formalize CompensationContract and ApprovalWorkflow as the next ERP/CRM
  semantics after Stage 2 compiler gaps shrink.
- Treat MeaningDiff as central to human-agent symbiosis.

[S] Signals:
- Stage 1 proof spine is strong enough to support strategic expansion.
- The highest risk is semantic span across systems, not lack of local syntax.
- Current docs contain stale entrypoint/spec lines that can mislead new agents.
- OLAPPoint, History, streams, and invariants are coherent as one temporal
  analytical model.

[T] Tests / Proofs:
- No executable tests run in this slice. This is a document-only meta report.

[Q] Open Questions:
- Should LanguageContract be a new PROP-028, or an errata/extension to PROP-006
  RuntimeContract plus PROP-019.1 SemanticIR envelope?
- Should `RuntimeCell` be modeled as a language-level construct or remain an
  ecosystem/deployment concept until distributed proof exists?
- Should FFI pure deterministic externals be eligible for CORE, or should all
  externals remain ESCAPE in v0 for safety?

[X] Rejected:
- Turing-complete CORE.
- Large new OSINT/product essay tracks before the compiler package catches up.
- Distributed consensus semantics before compatible handoff and causal context
  are proven.
- Raw FFI without typed capability, purity, determinism, and receipt declarations.

[Next] Proposed next slice:
- extract-typechecker-module-v0 [Research Agent]
- spec-entrypoint-sync-v0 [Meta Expert or Compiler/Grammar Expert]
- stream-oof-s2-classifier-v0 [Compiler/Grammar Expert]
- olap-point-parser-implementation-v0 [Research Agent or Compiler/Grammar Expert]
- LanguageContract + RuntimeContract Composition PROP candidate [Compiler/Grammar Expert]
```
