# Meta Proposal: Stage 1 Scoreboard Reconciliation v0

Role: `[Igniter-Lang Meta Expert]`
Track: `igniter-lang/docs/meta-proposals/META-EXPERT-004-stage1-scoreboard-reconciliation-v0.md`
Status: done
Date: 2026-05-06
Depends on: META-EXPERT-003, PROP-019.1
Affected neighbors: `[Igniter-Lang Research Agent]`, `[Igniter-Lang Compiler/Grammar Expert]`

---

## What Changed Since META-EXPERT-003

PROP-019.1 (SemanticIR Envelope Errata) landed after the Stage 1 scoreboard
in META-EXPERT-003 was written. It amends the canonical SemanticIR shape in
ways that affect the assembler gate.

Key decisions from PROP-019.1:

```text
[D] oof_log is REMOVED from SemanticIRProgram (top-level and ContractIR).
[D] OOF diagnostics live in CompilationReport only.
[D] CompilationReport is always written; SemanticIRProgram only on success.
[D] Assembler reads CompilationReport.semantic_ir_ref to locate artifact.
[D] Negative case fixtures must NOT have *.semantic_ir.json — only
    *.compilation_report.json with pass_result: "oof".
[D] stdlib.numeric.add is a pre-resolution name. SemanticIR must contain
    stdlib.integer.add (or float/decimal/etc). Unresolved overload → OOF-P1.
```

These decisions mean the existing `source_to_semanticir_fixture` golden files
are out-of-date. The SemanticIR Emitter status remains PASS, but the golden
files it validates against are not yet at the PROP-019.1 shape.

---

## Blocker Chain

```text
source_to_semanticir_fixture golden files → need PROP-019.1 migration
  ↓
source_to_semanticir_fixture.rb PASS on migrated files (gate)
  ↓
igapp_assembler_proof can begin (Slice A)
  ↓
RuntimeMachine.load(assembled.igapp) → trusted (Stage 1 closed)
```

The assembler is blocked on golden file migration, not on missing spec.
PROP-019.1 gives exact migration instructions (§Part 6 + §Part 7).

---

## Revised Scoreboard (compact)

Full scoreboard lives in `docs/current-status.md § Stage 1 Progress`.
Reconciled summary:

```text
Parser          ✅ partial  [gap] OOF rejection at parse time
Classifier      ✅ PASS
SemanticIR      ✅ PASS     ⚠️  golden files need PROP-019.1 migration
TypeChecker     🟡          annotation-driven structural ok; traits/mono missing
.igapp Assembler 🔴 blocked  BLOCKED: wait for golden file migration + PASS gate
RuntimeMachine  ✅ proven
Stdlib          🔴 not started
```

---

## Agent Constraints (no change from META-EXPERT-003)

All agents remain on compiler-path work only.

The routing policy from META-EXPERT-003 stands unchanged.
No new tracks, no new pressure lanes, no bridge profiles until Stage 1 closes.

---

## Handoff

```text
[Igniter-Lang Meta Expert]
Track: META-EXPERT-004-stage1-scoreboard-reconciliation-v0
Status: done

[D] Decisions:
- SemanticIR Emitter is PASS but golden files need PROP-019.1 migration.
- .igapp/ Assembler is blocked until migration gate passes.
- Blocker chain: golden migration → fixture PASS → assembler → Stage 1 closed.
- Full scoreboard lives in current-status.md § Stage 1 Progress.

[R] Recommendations:
- Research Agent: execute Slice 0 (golden file migration) immediately.
  It is the only active unblock path for the assembler.
- Compiler/Grammar Expert: begin PROP-021 (narrow TypeChecker) in parallel.

[S] Signals:
- Spec → proof velocity is healthy. PROP-019.1 is a precision correction,
  not a design reversal. The pipeline shape is stable.
- The migration scope is bounded: 3 positive fixtures + 3 negative fixtures.
  Slice 0 is small.

[X] Rejected:
- Starting the assembler experiment before Slice 0 gate passes.
- Treating PROP-019.1 as a blocker for TypeChecker or Stdlib work.

[Next]:
- Research Agent: Slice 0 → golden migration → source_to_semanticir PASS.
- Compiler/Grammar Expert: PROP-021 narrow TypeChecker.
- Research Agent: Slice C (stdlib_execution_proof) independently, in parallel.
```
