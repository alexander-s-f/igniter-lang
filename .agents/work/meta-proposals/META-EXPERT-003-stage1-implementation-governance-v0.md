# Meta Proposal: Stage 1 Implementation Governance v0

Role: `[Igniter-Lang Meta Expert]`
Track: `igniter-lang/docs/meta-proposals/META-EXPERT-003-stage1-implementation-governance-v0.md`
Status: done
Date: 2026-05-06
Supervisor: `[Architect Supervisor / Codex]`
Depends on: META-EXPERT-002-compiler-frontier-prioritization-v0
Affected neighbors:
  `[Igniter-Lang Compiler/Grammar Expert]`,
  `[Igniter-Lang Research Agent]`

---

## Stage 1 Scoreboard (as of 2026-05-06)

Stage 1 goal: `source.ig → compiler → .igapp/ → RuntimeMachine trusted`

```text
Pass                  Spec (PROP)         Experiment / Proof           Status
────────────────────────────────────────────────────────────────────────────────
Parser                PROP-014/015        experiments/parser/           ✅ partial
                                          add.ig, availability.ig,
                                          polymorphic_add.ig parsed ok
                                          grammar_version emitted
                                          [gap] pipeline/OSINT surface
                                          not yet accepted

Classifier            PROP-018/020        experiments/classifier_pass_  ✅ proven
(CORE/ESCAPE/OOF)                         proof/
                                          add, claim_evidence,
                                          evidence_linked_alert → PASS
                                          OOF negatives → PASS

SemanticIR Emitter    PROP-019            experiments/source_to_        ✅ proven
(Canonical envelope)                      semanticir_fixture/
                                          add, claim_evidence,
                                          evidence_linked_alert → PASS
                                          golden AST + SemanticIR → PASS

.igapp/ Assembler     PROP-012            hand-authored only             🔴 not started
                                          fixtures/add.igapp/ exists
                                          but no compiler produces it

Type Checker          PROP-004 / needed   partial in classifier proof    🟡 partial
                                          structural types annotated
                                          no trait resolution yet
                                          no Projection[T,h] checking
                                          no lifecycle type enforcement

RuntimeMachine Load   PROP-011            experiments/runtime_machine_   ✅ proven
                                          memory_proof/
                                          load → evaluate → checkpoint
                                          → resume → trusted report

Stdlib execution      PROP-013            no runtime operators yet       🔴 not started
                                          stdlib.numeric.add missing
                                          fold/map/filter not executable
────────────────────────────────────────────────────────────────────────────────
STAGE 1 CLOSED:       NO
Blocker:              .igapp/ Assembler + Stdlib execution
```

---

## Revised Gap Map

From META-EXPERT-002, three passes were listed as "not started":
Classifier, TypeChecker, SemanticIR Emitter. Since that was written, the
Compiler/Grammar Expert landed PROP-018, PROP-019, PROP-020 and the
Research Agent proved Classifier + SemanticIR emission experimentally.

[D] **The real remaining gap is narrower than META-EXPERT-002 estimated:**

```text
Closed since META-EXPERT-002:
  ✅ PROP-018: Source-to-SemanticIR Minimal Pipeline
  ✅ PROP-019: Canonical SemanticIR Envelope v0
  ✅ PROP-020: Classifier Pass v0 Formalization
  ✅ experiments/classifier_pass_proof/ — PASS
  ✅ experiments/source_to_semanticir_fixture/ — PASS

Still open for Stage 1:
  🔴 .igapp/ Assembler (source compiler path → .igapp/)
  🔴 Stdlib execution (numeric.add, fold, map, filter runtime operators)
  🟡 TypeChecker (structural ok; trait resolution and lifecycle types pending)
```

---

## "Done" Criteria Per Pass

### Parser — Stage 1 criterion

```text
DONE when:
  - add.ig, availability_projection.ig, polymorphic_add.ig
    all parse with parse_errors: []
  - grammar_version field present in ParsedProgram
  - parser rejection test: OOF surface forms are rejected at parse time
    (ambient IO, undeclared rebind) → parse_errors non-empty

NOT required for Stage 1:
  - pipeline/step/scoped_by surface (Spark-specific, Stage 2)
  - trait/impl surface (already parsing; classifier/type check is the gate)
```

### Classifier — ✅ Stage 1 criterion already met

```text
DONE when:
  - CORE contracts → all nodes annotated :core, no escape/oof nodes
  - ESCAPE contracts → read/call/escape nodes annotated :escape with cap ref
  - OOF nodes → compile error emitted, node not forwarded to SemanticIR
  - ClassifiedProgram JSON shape matches PROP-020

STATUS: PASS (classifier_pass_proof.rb)
```

### SemanticIR Emitter — ✅ Stage 1 criterion already met

```text
DONE when:
  - kind: "semantic_ir_program" with format_version: "0.1.0"
  - ContractIR per monomorphic contract, no unresolved type vars
  - fragment_class emitted per contract (:core/:escape)
  - oof_log populated for rejected nodes
  - source_hash and program_id stable across recompiles of same source

STATUS: PASS (source_to_semanticir_fixture.rb)
```

### TypeChecker — 🟡 Partial

```text
DONE (Stage 1 minimum) when:
  - Annotation-driven type resolution: Integer, Float, String, Boolean,
    Collection[T], Option[T] resolved from declared annotations
  - Structural record conformance: record field access type-checked
  - Trait constraint check: T: Additive → impl Additive[T] exists
  - Monomorphization: Add[T] → Add[Integer], Add[Float], not Add[String]
  - No unresolved type variables survive into ContractIR nodes

NOT required for Stage 1 (defer):
  - Full Projection[T,horizon] constraint checking
  - Lifecycle type enforcement at type level
  - Higher-kinded / associated types
  - Inference (annotation-driven only for Stage 1)
```

### .igapp/ Assembler — 🔴 Critical blocker

```text
DONE when:
  - Given SemanticIR output, produces a valid .igapp/ directory
  - program.json matches PROP-012 CompiledProgram shape
  - contracts/ directory contains one JSON per monomorphic ContractIR
  - specialization_manifest.json present (generic contracts metadata only)
  - schema_descriptor.json present (required for RuntimeMachine schema_check)
  - artifact_hash computed and stable
  - RuntimeMachine.load(assembled_output) → LoadReceipt without error
  - CompatibilityReport.schema_check: :trusted

Acceptance test (Stage 1 closed):
  ruby compile(source/add.ig) → assembled_add.igapp/
  diff assembled_add.igapp/program.json fixtures/add.igapp/program.json → pass
  ruby RuntimeMachine.load(assembled_add.igapp) → trusted
```

### Stdlib Execution — 🔴 Blocker for evaluate

```text
DONE (Stage 1 minimum) when:
  - stdlib.numeric.add, .sub, .mul callable from RuntimeMachine evaluator
  - stdlib.collection.fold, .map, .filter operative over Collection[T]
  - stdlib.collection.count, .first operative
  - stdlib.option.or_else operative
  - Decimal[scale:S] add/sub/mul/div/compare operative

Acceptance test:
  RuntimeMachine.evaluate(add.igapp, {a: 1, b: 2}) → {sum: 3}
    + ObsPacket with fragment_class: :core, lifecycle: :local
```

---

## Agent Routing Policy During Stage 1

### What each agent should do right now

**`[Igniter-Lang Research Agent]`**
```text
ALLOWED:
  - .igapp/ Assembler proof (implement assembler, acceptance test vs fixtures)
  - TypeChecker proof (trait resolution, monomorphization, negative tests)
  - Stdlib execution proof (numeric + collection operators in RuntimeMachine)
  - Fix parser gaps: OOF rejection at parse time

NOT ALLOWED until Stage 1 closes:
  - New OSINT fixtures
  - Simulation fixtures
  - Distributed / mesh experiments
  - Any experiment that does not advance the compiler path
```

**`[Igniter-Lang Compiler/Grammar Expert]`**
```text
ALLOWED:
  - PROP for TypeChecker narrow spec (trait resolution + monomorphization)
  - PROP for .igapp/ Assembler contract (what the assembler must produce)
  - Errata / corrections to PROP-018/019/020 if proof finds divergence

NOT ALLOWED until Stage 1 closes:
  - New PROP-* for CompensationContract, distributed, inference, simulation
  - Grammar extensions (no new syntax until classifier is current with parser)
  - Any PROP that does not advance the compiler path
```

**`[Igniter-Lang Bridge Agent]`**
```text
BLOCKED during Stage 1.
  No new bridge profiles until assembled .igapp/ passes RuntimeMachine.
  Existing bridge profiles remain as-is.
```

**`[Igniter-Lang Applied Pressure Agent]`**
```text
ONE permitted pressure slice: freeze the OSINT vocabulary.
  Write ONE compact fixture .ig source file that exercises:
    Claim, EvidenceLink, ConfidenceAssessment, ContradictionReport
  This becomes a compiler acceptance target for Stage 1 (not a new fixture loop).

Otherwise: blocked until Stage 1 closes.
```

---

## Progress Reporting Policy

[D] Agents must not generate new theory tracks while the compiler is blocked.

Report format (compact, in existing docs — not a new document):

```text
[Stage 1 Status Update]
Date: YYYY-MM-DD
Agent: [Role Name]
Completed: <pass name> — <experiment or PROP reference>
Evidence: <experiment PASS line or PROP section>
Blocker: <if blocked, what is missing>
Next: <one next action>
```

Updates go into `docs/current-status.md` under a `## Stage 1 Progress` section.
Do NOT create a new track document for a progress update.

---

## Next 3 Implementation Slices

### Slice A: .igapp/ Assembler Proof
```text
Owner:    [Igniter-Lang Research Agent]
Scope:    experiments/igapp_assembler_proof/
          igapp_assembler_proof.rb
          Inputs: source_to_semanticir_fixture golden SemanticIR JSON
          Outputs: assembled add.igapp/ directory
          Checker: diff vs fixtures/add.igapp/ + RuntimeMachine.load → trusted
Done:     RuntimeMachine.load(assembled_add.igapp) → trusted CompatibilityReport
PROP dep: PROP-012 (CompiledProgram shape) — already formalized
```

### Slice B: TypeChecker Narrow Proof
```text
Owner:    [Igniter-Lang Research Agent]
Scope:    experiments/typechecker_proof/
          typechecker_proof.rb
          Inputs: classifier_pass_proof golden ClassifiedProgram JSON
          Outputs: TypedProgram JSON (typed nodes, resolved traits,
                   monomorphic specializations, no unresolved T)
          Negatives: Add[String] → OOF-TY1, unresolved symbol → error
Done:     TypedProgram JSON matches expected shape, negatives blocked
PROP dep: Compiler/Grammar Expert to deliver narrow TypeChecker PROP
          (annotation-driven, trait resolution, monomorphization only)
```

### Slice C: Stdlib Execution Kernel
```text
Owner:    [Igniter-Lang Research Agent]
Scope:    Extend experiments/runtime_machine_memory_proof/ OR new
          experiments/stdlib_execution_proof/
          stdlib_execution_proof.rb
          Implements: numeric.add, fold, map, filter, count, first, or_else
          in RuntimeMachine evaluator (standalone, not gem integration)
Done:     RuntimeMachine.evaluate(add.igapp, {a:1, b:2}) → {sum:3}
          + valid ObsPacket, lifecycle :local
PROP dep: PROP-013 (stdlib types already formalized — just implement operators)
```

---

## Handoff

```text
[Igniter-Lang Meta Expert]
Track: igniter-lang/docs/meta-proposals/META-EXPERT-003-stage1-implementation-governance-v0.md
Status: done

[D] Decisions:
- Classifier and SemanticIR Emitter are proven. Gap is narrower than estimated.
- .igapp/ Assembler and Stdlib execution are the two remaining Stage 1 blockers.
- TypeChecker is partial; trait resolution + monomorphization is the next type gap.
- All agents are restricted to compiler-path work until Stage 1 closes.
- Progress reported via current-status.md, not new track documents.

[R] Recommendations:
- Research Agent: prioritize Slice A (.igapp/ Assembler) first.
  It closes Stage 1 without waiting for TypeChecker or Stdlib.
- Compiler/Grammar Expert: deliver narrow TypeChecker PROP (annotation-driven).
- Research Agent: Stdlib Execution Kernel (Slice C) unblocks evaluate,
  closes Stage 1 end-to-end.
- Applied Pressure Agent: write ONE .ig source file for OSINT Claim vocabulary,
  then stop until Stage 1 is done.

[S] Signals:
- PROP-018/019/020 + classifier + SemanticIR emitter landed faster than estimated.
  The gap between spec and implementation is closing.
- The assembler and stdlib are the last mechanical steps, not design questions.
  Stage 1 is 2-3 focused slices away.

[Q] Open Questions:
- Should the narrow TypeChecker PROP be PROP-021, or a revision of PROP-004?
- Should Stdlib execution kernel live in runtime_machine_memory_proof/ (extend)
  or a new experiments/stdlib_execution_proof/?

[X] Rejected:
- New OSINT/simulation/inference/distributed tracks before Stage 1.
- New PROP-* not on the compiler path.
- Progress reported via new theory documents.

[Next] Proposed next slices:
- [Research Agent]: Slice A — igapp_assembler_proof.
- [Compiler/Grammar Expert]: narrow TypeChecker PROP (PROP-021 candidate).
- [Research Agent]: Slice C — stdlib_execution_proof.
```
