# META-EXPERT-007: Stage 1 Close Governance v0

Role: `[Igniter-Lang Meta Expert]`
Status: decision
Date: 2026-05-06
Track: stage1-governance-close-review-v0

---

## Purpose

Formal governance review of Stage 1 close candidate.
Authorizes Stage 1 to be marked closed (with explicit deferred gaps)
and defines conditions for opening Stage 2 governance.

---

## Evidence

Close candidate runner: `experiments/stage1_close_candidate/stage1_close_candidate.rb`
Result: **PASS** — all 5 proof suites pass.

```text
classifier          PASS   experiments/classifier_pass_proof/
typechecker         PASS   experiments/typechecker_proof/           (incl. boundary fixture)
semanticir          PASS   experiments/source_to_semanticir_fixture/ --check-golden
stdlib_kernel       PASS   experiments/stdlib_execution_kernel_stage1/
igapp_assembler     PASS   experiments/igapp_assembler_proof/
  incl. runtime.load_direct_prop0191:        ok
  incl. runtime.load_assembled_add:          ok
  incl. runtime.evaluate_assembled_add:      ok
  incl. runtime.compatibility_report_trusted: ok
  incl. assembler.no_legacy_semantic_ir_json: ok
```

Closed candidate signals (from `stage1_close_candidate.json`):

```text
direct_prop0191_runtime_loader        closed_in_proof
typechecker_self_contained_boundary   closed_in_proof
stdlib_stage1_kernel                  closed_in_proof
```

---

## Remaining Known Gaps (from close candidate)

Three gaps reported. Assessed below.

### Gap 1: `parser_oof_rejection_gap`

```
Parser OOF rejection is not fully hardened;
OOF is currently caught by classifier/typechecker proofs.
```

**Assessment**: Not a Stage 1 correctness blocker.

- The pipeline has two OOF catch layers: classifier (Pass 0) and typechecker (Pass 1).
- All OOF proof cases (unresolved_symbol, evidence_less_alert, confidence_bool) are
  rejected by classifier or typechecker — none reach the assembler.
- The assembler negative cases confirm: OOF inputs refuse with exit != 0.
- Parser OOF hardening is a UX improvement (earlier error messages), not a trust
  boundary violation. The trust boundary is classifier → assembler, which is proven.

**Verdict**: Acceptable for close. Deferred to Stage 2 / grammar hardening.

---

### Gap 2: `production_compiler_assembly`

```
Assembler and RuntimeMachine loading are proof-local experiments,
not a production compiler package.
```

**Assessment**: Deliberate Stage 1 scope.

Stage 1 was defined as "executable proof, not production compiler package."
The goal was `source.ig → parser → classifier → typechecker → SemanticIR → .igapp/ → RuntimeMachine trusted`
as a verified proof chain, not a released CLI tool. This gap is expected by design.

**Verdict**: Not a gap — this is the Stage 1 definition. Stage 2 will address the
production compiler package question. Close is not blocked.

---

### Gap 3: `runtime_eval_surface`

```
Assembled Add evaluates end-to-end; non-add Stage 1 fixtures still need
direct runtime eval support for field_access, integer.gt, and bool.and.
```

**Assessment**: Acceptable for close with deferred action.

- The core proof `source.ig → .igapp/ → RuntimeMachine.evaluate → correct output` is
  complete for the Add contract (integer arithmetic, pure CORE).
- claim_evidence and evidence_linked_alert load correctly but their full evaluate path
  requires field_access, integer.gt, and bool.and operators in the runtime kernel.
- These are stdlib operators, not semantic model gaps. The model is proven; the kernel
  surface is incomplete.

**Verdict**: Acceptable for close. Deferred to Stage 2 stdlib surface expansion.
The close criterion is `evaluate → trusted CompatibilityReport`, which is met for Add.

---

## Verdict

```
VERDICT: CLOSE WITH DEFERRED GAP
```

Stage 1 is closed effective 2026-05-06.

**Closed by**: `stage1_close_candidate` PASS on all 5 proof suites.

**Deferred gaps** (do not block close, must be tracked in Stage 2 intake):

| Gap | Deferred to |
|-----|------------|
| Parser OOF rejection hardening | Stage 2 grammar hardening pass |
| Production compiler package | Stage 2 compiler packaging |
| runtime eval surface (field_access, integer.gt, bool.and) | Stage 2 stdlib surface expansion |

**Not deferred** (confirmed closed by proof):

| Signal | Status |
|--------|--------|
| ClassifiedProgram → TypedProgram standalone boundary | closed_in_proof |
| PROP-019.1 direct runtime loader | closed_in_proof |
| Stdlib Stage 1 kernel (add, fold, map, filter, count, or_else) | closed_in_proof |
| .igapp/ assembler A1-A6 + no_legacy_semantic_ir_json | closed_in_proof |
| assembled_add.igapp → evaluate → trusted CompatibilityReport | closed_in_proof |

---

## Stage 1 Close Criteria (formally satisfied)

The Stage 1 close criteria defined in `META-EXPERT-003` was:

```
source.ig → parser → classifier → typechecker → SemanticIR → .igapp/ → RuntimeMachine trusted
```

Mapping to proof evidence:

```
source.ig → parser          experiments/parser/ (61 specs, PASS partial)
parser → classifier         experiments/classifier_pass_proof/ PASS
classifier → typechecker    experiments/typechecker_proof/ PASS (boundary fixture closed)
typechecker → SemanticIR    experiments/source_to_semanticir_fixture/ PASS (golden check)
SemanticIR → .igapp/        experiments/igapp_assembler_proof/ PASS (A1-A6)
.igapp/ → RuntimeMachine    igapp_assembler_proof runtime.load + evaluate PASS
trusted                     runtime.compatibility_report_trusted: ok ✓
```

OOF trust boundary criterion:
```
OOF contracts never reach .igapp/   assembler.no_legacy_semantic_ir_json: ok ✓
                                    assembler.negative.*_refused: ok ✓
```

All criteria met. Parser OOF hardening gap does not invalidate any criterion —
the trust boundary is enforced at classifier + assembler, not parser.

---

## Required Post-Close Actions

### Immediate (before Stage 2 opens)

```
1. Update current-status.md: STAGE 1 CLOSED: YES
2. Update docs/README.md: Stage 1 status → closed
3. Tag: git tag stage1-close-2026-05-06 (optional)
4. Take Stage 1 close snapshot:
   docs/archive/snapshots/YYYY-MM-DD-stage1-close/
   (per docs reset plan in current-status.md §After Stage 1)
```

### Stage 2 Intake (do not start yet)

```
5. Author META-EXPERT-008: Stage 2 implementation governance
   Scoreboard: History[T], stream T, OLAPPoint, invariant severity, runtime eval surface
6. Activate PROP-022..025 as Stage 2 active intake
   (move from "deferred" to "active" in proposals/README.md)
7. New intake directory for Stage 2 PROPs starting from PROP-026+
8. Freeze Stage 1 PROPs:
   Move PROP-001..023 + errata to docs/proposals/accepted/
```

### Deferred gap tracking (Stage 2 backlog)

```
9.  Parser OOF rejection hardening (grammar hardening pass)
10. Production compiler package (CLI + gem packaging)
11. Runtime eval surface: field_access, integer.gt, bool.and operators
```

---

## PROP-023 Note

PROP-023 (Classified Expression Boundary Formalization) was authored and
partially observed in the user's active documents. It amends PROP-020/021
with a formal ClassifiedExpr boundary table. This PROP should be:

- Registered in `proposals/README.md` as authored (Stage 1 late addition)
- Reviewed before Stage 2 PROP-024+ are authored (it clarifies the TC/Emitter contract)
- Not required for Stage 1 close (TypeChecker boundary already closed_in_proof)

---

## References

```
META-EXPERT-003  Stage 1 implementation governance
META-EXPERT-004  Stage 1 scoreboard reconciliation (PROP-019.1 errata)
experiments/stage1_close_candidate/stage1_close_candidate.json
docs/current-status.md  (scoreboard)
docs/spec/README.md     (coverage matrix)
```
