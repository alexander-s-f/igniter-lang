# Meta Proposal: Compiler Frontier Prioritization v0

Role: `[Igniter-Lang Meta Expert]`
Track: `igniter-lang/docs/meta-proposals/META-EXPERT-002-compiler-frontier-prioritization-v0.md`
Status: done
Date: 2026-05-06
Supervisor: `[Architect Supervisor / Codex]`
Affected neighbors:
  `[Igniter-Lang Compiler/Grammar Expert]`,
  `[Igniter-Lang Research Agent]`

---

## Claim

[D] Igniter-Lang has a specification that outruns its implementation by 6-12
months. This is acceptable and intentional. It is not acceptable indefinitely.

The current risk:

```text
Theory gap: 17 PROP documents, 65 tracks, rich semantics.
Implementation gap: partial parser, no classifier, no typechecker,
  no SemanticIR emitter, no stdlib execution, no full compiler path.

Risk: the language remains a convincing fiction, not a proof.
```

This proposal defines the **minimal compiler frontier** that closes that risk —
the smallest executable spine that proves Igniter-Lang is a real language, not
a research document.

---

## The Target: Language Proof vs Fixture Proof

The existing work proves the **runtime** and **semantic shape** of artifacts:

```text
hand-authored .igapp/ → RuntimeMachine → SemanticImage ✅ proven
```

It does not prove the **language** can produce those artifacts:

```text
source .ig → compiler → .igapp/ → RuntimeMachine  ← NOT proven end-to-end
```

[D] **Language proof** = a source `.ig` file passes through a real compiler
pipeline and produces a loadable, RuntimeMachine-verified artifact.

This is the milestone that transforms Igniter-Lang from "specification with
proofs of runtime semantics" into "a real language."

---

## The Minimal Compiler Path

```text
Stage 0 (current):
  hand-authored .igapp/ → RuntimeMachine ✅

Stage 1 (TARGET for this frontier):
  source.ig
    → Parser         (ParsedProgram JSON)       [partial ✅]
    → Classifier     (ClassifiedProgram)         [not started]
    → Type Checker   (TypedProgram)              [not started]
    → SemanticIR     (ContractIR JSON)           [not started]
    → .igapp/        (loadable artifact)         [hand-authored only]
    → RuntimeMachine (evaluate + receipt)        [proven ✅]

Stage 1 Success Criterion:
  add.ig → compiler → add.igapp/ == fixtures/add.igapp/ (byte-equivalent contracts)
  and RuntimeMachine.load(compiler_output) produces trusted CompatibilityReport.
```

Everything else is Stage 2+. Do not build Stage 2 until Stage 1 is done.

---

## Top 5 Implementation Priorities

### P-1: Classifier (CORE/ESCAPE/OOF) — Critical

**Why first**: Every downstream stage depends on it. TypeChecker, SemanticIR
emitter, and OOF rejection all require a classified AST.

**Scope**: Pass over ParsedProgram AST. Annotate each node:
- `CORE` if: pure computation, no TBackend reads, no effects, no ambient time
- `ESCAPE` if: declared `read`, `call`, `escape` nodes with explicit capability
- `OOF` if: ambient IO, undeclared effects, mutable rebinding, unresolved imports

**Acceptance criteria**:
- `add.ig` → all nodes classified CORE
- `availability_projection.ig` → read/escape nodes classified ESCAPE
- OOF node → compile error with reason_code (not silent pass)
- Produces `ClassifiedProgram` JSON shape matching PROP-003

**Formal request to `[Igniter-Lang Compiler/Grammar Expert]`**:
> `PROP-018: Classifier Pass Formal Specification v0` — define the exact
> classification rules for each ParsedProgram node kind, including ESCAPE
> surface forms, OOF rejection rules, and ClassifiedProgram JSON shape.

---

### P-2: Structural Type Checker — Critical

**Why second**: Cannot emit SemanticIR without typed nodes. Cannot enforce
trait coherence, generic substitution, or lifecycle rules without types.

**Scope** (v0, not full PROP-004):
- Resolve type annotations on input/output/compute nodes
- Check structural conformance (record fields, Collection[T] element types)
- Verify trait constraints: `T: Additive` → impl exists
- Monomorphize generic contracts: `Add[T: Additive]` → `Add[Integer]`, `Add[Float]`
- Reject unresolved type variables before SemanticIR emission

**Out of scope for v0**:
- Higher-kinded types
- Associated types
- Full subtyping lattice
- Inference beyond annotation-driven resolution

**Acceptance criteria**:
- `add.ig` → TypedProgram with typed Integer inputs/output
- `polymorphic_add.ig` → TypedProgram with `Add[Integer]`, `Add[Float]` specializations
- `Add[String]` → OOF-TY1 compile error (already proven in classifier proof)
- Produces `TypedProgram` JSON, no unresolved `T` variables

**Formal request to `[Igniter-Lang Compiler/Grammar Expert]`**:
> `PROP-019: Type Checker Pass v0` — narrow PROP-004 to the annotation-driven
> subset needed for add + availability + polymorphic_add. Define TypedProgram
> shape, trait resolution rules, and monomorphization output contract.

---

### P-3: SemanticIR Emitter — Critical

**Why third**: SemanticIR is the stable compiler boundary (per current-status.md).
Everything downstream — `.igapp/`, RuntimeMachine, native backend — reads from it.

**Scope**:
- Lower TypedProgram to ContractIR JSON shapes
- Emit one ContractIR per monomorphic specialization
- Inline `def` bodies (non-recursive, per PROP-015)
- Preserve lifecycle annotations on compute/snapshot/output nodes
- Emit capability requirements from ESCAPE nodes
- Emit dependency graph edges

**Acceptance criteria**:
- `add.ig` → `ContractIR` matches `fixtures/add.igapp/` contract shape
- `polymorphic_add.ig` → two ContractIRs: `Add[Integer]`, `Add[Float]`
- Generic `Add` template preserved as inspection metadata only (not loadable)
- No unresolved trait calls survive into emitted ContractIR

**Research fixture request to `[Igniter-Lang Research Agent]`**:
> Implement `compiler_semanticir_emission_proof_v0` —
> standalone Ruby proof that drives TypedProgram → ContractIR emission for
> `add.ig` and compares output to `fixtures/add.igapp/`.
> This closes the open gap noted in `current-status.md` (no parsed-source-to-.igapp
> surface checker).

---

### P-4: .igapp/ Artifact Assembler — High

**Why fourth**: Once SemanticIR is emitted, assembling a valid `.igapp/` is
mechanical. This closes Stage 1 end-to-end.

**Scope**:
- Produce `program.json`, `contracts/`, `specialization_manifest.json`
- Compute `artifact_hash` and `source_hash`
- Embed `schema_descriptor` (required for RuntimeMachine schema_check)
- Emit `diagnostics.json` if any OOF/type errors exist

**Acceptance criteria**:
- `add.ig` → `add.igapp/` byte-structurally equivalent to `fixtures/add.igapp/`
- `RuntimeMachine.load(assembled_add.igapp)` → trusted CompatibilityReport
- `RuntimeMachine.evaluate(add.igapp, {a:1, b:2})` → result + ObsPacket

**This closes Stage 1 success criterion.**

---

### P-5: Stdlib Execution (numeric.add, fold, filter, map) — High

**Why fifth**: Without runtime implementations of stdlib primitives, even
a correctly compiled `add.igapp` cannot evaluate. This is the final blocker
for end-to-end execution.

**Scope** (v0 stdlib kernel):
- `stdlib.numeric.add`, `stdlib.numeric.sub`, `stdlib.numeric.mul`
- `stdlib.collection.fold`, `stdlib.collection.map`, `stdlib.collection.filter`
- `stdlib.collection.count`, `stdlib.collection.first`, `stdlib.option.or_else`
- `Decimal[scale:S]` arithmetic operators

**Out of scope for v0**:
- String operations (needed only for Stage 2)
- IO (ESCAPE, needed for Stage 2)
- Date/time arithmetic beyond `TemporalCtx` comparisons

**Acceptance criteria**:
- `add.igapp` evaluates `add(1, 2) == 3` via RuntimeMachine
- `availability_projection.igapp` evaluates fold/filter/map chain
- All stdlib calls produce ObsPackets with correct lifecycle class

---

## "Do Not Expand Yet" List

[X] Do not formalize `CompensationContract` before Stage 1 is done.
    Reason: Saga semantics require ESCAPE composition algebra first.
    Block: after P-5.

[X] Do not formalize distributed SemanticImage handoff.
    Reason: single-node proof must be complete before multi-node.
    Block: after Stage 1 + stable TBackend file adapter.

[X] Do not write new OSINT pressure tracks.
    Reason: OSINT vocabulary is rich (Claim, Evidence, Confidence, etc.).
    The language needs to be able to execute a contract first.
    Block: after P-4.

[X] Do not formalize InferenceContract / Datalog inference.
    Reason: bounded proof search requires fold_until + pattern matching
    which are themselves post-Stage-1 features.
    Block: after P-5 + pattern matching (Stage 2).

[X] Do not formalize WorldModel / simulation engine.
    Reason: discrete event simulation requires a bounded step operator
    that is distinct from fold. Premature to specify before stdlib is proven.
    Block: after Stage 1.

[X] Do not add new source syntax forms to the parser.
    Reason: the parser is already ahead of the classifier.
    No new syntax until the classifier catches up to what the parser accepts.

[X] Do not begin LLVM/native backend work.
    Reason: Semantic IR must be stable before any backend targets it.
    Block: after Stage 1 + stable SemanticIR v1.

---

## Reconciling OSINT/Product Ambitions with Compiler-First Focus

[D] OSINT and product work must wait for compiler Stage 1 to complete.
This is not a rejection — it is a sequencing constraint.

The reconciliation logic:

```text
OSINT product (Watchlist → Claims → Alerts → Reports)
  requires: Claim, EvidenceLink, ConfidenceAssessment contracts
  requires: fold/filter/map over Collection[Claim]
  requires: lifecycle annotations on reports (:audit, :durable)
  requires: ESCAPE source collection calls

All of the above require: working classifier + typechecker + SemanticIR.

Therefore: OSINT product cannot be proven executable until Stage 1 is done.
```

[R] OSINT tracks should produce **one more pressure fixture** that fixes the
desired vocabulary (Claim, EvidenceLink, ContradictionReport), then **stop
producing new tracks** until the compiler catches up.

[R] The existing OSINT fixture (`osint_fractal_traceability_fixture.rb`) is
the correct target. The Research Agent should make it compile through the
Stage 1 pipeline — not write new fixtures.

---

## Formal Requests Summary

| To | Request | Urgency |
|----|---------|---------|
| `[Igniter-Lang Compiler/Grammar Expert]` | `PROP-018`: Classifier Pass formal spec | Critical |
| `[Igniter-Lang Compiler/Grammar Expert]` | `PROP-019`: TypeChecker Pass v0 (narrow) | Critical |
| `[Igniter-Lang Research Agent]` | `compiler_semanticir_emission_proof_v0` fixture | High |
| `[Igniter-Lang Research Agent]` | Extend parser acceptance harness to cover ClassifiedProgram output | High |

---

## Handoff

```text
[Igniter-Lang Meta Expert]
Track: igniter-lang/docs/meta-proposals/META-EXPERT-002-compiler-frontier-prioritization-v0.md
Status: done

[D] Decisions:
- Stage 1 milestone defined: source.ig → .igapp/ → RuntimeMachine trusted.
- P-1..P-5 are the only implementation priorities until Stage 1 closes.
- All OSINT, simulation, distributed, and inference work is deferred until
  Stage 1 is complete.
- No new source syntax before classifier catches up to parser.

[R] Recommendations:
- [Igniter-Lang Compiler/Grammar Expert] → write PROP-018 (Classifier) next.
- [Igniter-Lang Compiler/Grammar Expert] → write PROP-019 (TypeChecker) after.
- [Igniter-Lang Research Agent] → implement compiler_semanticir_emission_proof_v0.
- [Igniter-Lang Research Agent] → freeze new OSINT tracks; make existing
  OSINT fixture compilable through Stage 1 pipeline instead.

[S] Signals:
- The parser is already ahead of the classifier. The gap is not in parsing.
- The SemanticIR emitter proof already exists for polymorphic Add — extend it.
- RuntimeMachine is proven. The missing link is everything between .ig and .igapp/.
- OSINT ambitions are valid but are blocked by compiler reality, not theory.

[Q] Open Questions:
- Should PROP-018 (Classifier) be a standalone PROP or a section of a revised
  PROP-014 (Source Syntax → SemanticIR Boundary)?
- Should the stdlib kernel (P-5) be part of PROP-013 revision or a new PROP-020?

[X] Rejected:
- Expanding OSINT/simulation/inference tracks before Stage 1.
- New source syntax before classifier is current.
- Distributed semantics before single-node Stage 1.
- Native backend before stable SemanticIR v1.

[Next] Proposed next slices:
- [Igniter-Lang Compiler/Grammar Expert]: PROP-018 Classifier Pass.
- [Igniter-Lang Compiler/Grammar Expert]: PROP-019 TypeChecker v0.
- [Igniter-Lang Research Agent]: compiler_semanticir_emission_proof_v0.
```
