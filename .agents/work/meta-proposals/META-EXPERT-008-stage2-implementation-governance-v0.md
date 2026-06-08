# META-EXPERT-008: Stage 2 Implementation Governance v0

Role: `[Igniter-Lang Meta Expert]`
Status: active
Date: 2026-05-06
Supersedes: META-EXPERT-003 (Stage 1 governance — complete)
Prerequisite: META-EXPERT-007 (Stage 1 close decision — CLOSED)
Numbering audit: META-EXPERT-008.1 (canonical PROP map — no file moves needed)

> **PROP numbering note**: `PROP-022` = History[T] (Stage 2 design).
> `PROP-022A` = .igapp assembler contract (Stage 1, frozen in accepted/).
> `PROP-023` = stream T (Stage 2). `PROP-023A` = ClassifiedExpr boundary (Stage 1, frozen).
> `PROP-026` = parser OOF hardening (Stage 2, authored).
> New Stage 2 proposals start from PROP-028.
Authored: PROP-026 (parser OOF hardening ✅ PASS), PROP-027 (production compiler diagnostics).

---

## Purpose

Open Stage 2 implementation governance.
Stage 1 is closed. This document defines the Stage 2 scoreboard,
agent routing, allowed/blocked work, and done criteria for each pass.

---

## Stage 2 Starting Conditions

Inherited from Stage 1 close (META-EXPERT-007 + stage1_close_candidate.json):

```text
Proven and frozen (do not re-implement):
  ✅ Parser (partial — 61 specs, OOF gap deferred)
  ✅ Classifier (CORE/ESCAPE/OOF — PASS)
  ✅ TypeChecker (annotation-driven, boundary fixture — PASS)
  ✅ SemanticIR Emitter (PROP-019.1 envelope — PASS, golden check)
  ✅ .igapp/ Assembler (A1-A6 — PASS)
  ✅ RuntimeMachine load/evaluate/checkpoint/resume (PASS)
  ✅ Stdlib kernel: integer/float/decimal.add, fold, map, filter, count, or_else

Deferred from Stage 1:
  ✅ Parser OOF rejection hardening: ✅ PASS (PROP-026 + parser_oof_hardening_stage2_proof)
  ⏳ Production compiler package (CLI + gem packaging)
  ✅ Runtime eval surface: closed_in_proof (igapp_assembler_proof evaluates all 3 contracts)
```

---

## Stage 2 Scoreboard

```text
Pass/Feature           PROP(s)             Experiment                        Status
─────────────────────────────────────────────────────────────────────────────────────────
Parser OOF hardening   PROP-026            parser_oof_hardening_             ✅ PASS
                                            stage2_proof/                      syntax-owned OOF

Production compiler    PROP-027            no package yet                    ⏳ deferred gap
                       (diagnostics contract  (contract authored; no CLI yet)    (Tier 0 Gap B)
package                (assembler contract)                                   (from Stage 1)

Runtime eval surface   —                   igapp_assembler_proof/            ✅ closed_in_proof
                                            Add, ClaimEvidenceBundle,          all 3 contracts
                                            EvidenceLinkedAlertGate → trusted

History[T]             PROP-022            no experiment yet                 🔵 authored
                       Depends: PROP-004,                                     pending proof
                       PROP-013, PROP-016

stream T               PROP-023            no experiment yet                 🔵 authored
                       Depends: PROP-003,                                     pending proof
                       PROP-013

OLAPPoint[T, Dims]     PROP-024            no experiment yet                 🔵 authored
                       Depends: PROP-022,                                     pending proof
                       PROP-015, PROP-016

Invariant severity     PROP-025            no experiment yet                 🔵 authored
                       Depends: PROP-007,                                     pending proof
                       PROP-022
─────────────────────────────────────────────────────────────────────────────────────────
STAGE 2 CLOSED:   NO
Active priority:  Production compiler package → Stage 2 design PROPs
```

---

## Dependency Order

```
Stage 2 implementation order (strict):

  Tier 0 (deferred gaps — address first):
    [A. Parser OOF hardening — closed by PROP-026 proof ✅]
    B. Production compiler package foundation
    [C. Runtime eval surface — closed_in_proof ✅]

  Tier 1 (independent from each other, depend on Stage 1):
    D. History[T] (PROP-022) — depends on PROP-004/013/016 (all frozen ✅)
    E. Invariant severity (PROP-025) — depends on PROP-007 (active), PROP-022

  Tier 2 (depend on Tier 1):
    F. stream T (PROP-023) — depends on PROP-003/013 (frozen ✅) + PROP-022 errata
    G. OLAPPoint (PROP-024) — depends on PROP-022 + PROP-015/016 (frozen ✅)

  New intake: PROP-028+ (not yet authored)
```

---

## Done Criteria Per Pass

### ~~Deferred Gap A — Parser OOF hardening~~ ✅ CLOSED

```text
Closed by:
  - PROP-026-parser-oof-hardening-spec-v0
  - experiments/parser_oof_hardening_stage2_proof/ PASS
  - syntax-owned OOF rejects at parser
  - semantic OOF remains owned by Classifier / TypeChecker
```

### Deferred Gap B — Production compiler package

```text
Done when:
  - `igniter-lang compile <source.ig>` CLI command exists
  - Produces .igapp/ directory from source.ig end-to-end
  - Wraps: parser → classifier → typechecker → semanticir emitter → assembler
  - RuntimeMachine.load(output) → trusted CompatibilityReport
  - Packaged as Ruby gem or standalone executable
```

### ~~Deferred Gap C — Runtime eval surface~~ ✅ CLOSED

```text
Closed by: igapp_assembler_proof closed_candidate_signals.runtime_eval_surface
  evaluates: Add, ClaimEvidenceBundle, EvidenceLinkedAlertGate → trusted
  field_access, integer.gt, bool.and: implemented in assembler proof evaluator
```

### Stage 2 PROP D — History[T] (PROP-022)

```text
Done when:
  - ClassifiedProgram recognizes History[T] / BiHistory[T] type constructors
  - TypeChecker accepts: x: History[Integer] — resolves temporal window bounds
  - SemanticIR emits: history_ref node with window_bound, step_type
  - Assembler writes: .igapp/ with history_access semanticir node
  - RuntimeMachine evaluates: history_access(n) → last N values
  - Proof: experiments/history_type_proof/ PASS
```

### Stage 2 PROP E — Invariant severity (PROP-025)

```text
Done when:
  - Classifier recognizes: invariant severity :error | :warn | :soft | :metric
  - TypeChecker validates: severity escalation rules
  - CompilationReport includes: invariant_severity_summary
  - Proof: experiments/invariant_severity_proof/ PASS
```

### Stage 2 PROP F — stream T (PROP-023)

```text
Done when:
  - Parser accepts: stream T as ESCAPE input surface form
  - Classifier marks stream inputs as ESCAPE (not CORE or OOF)
  - fold_stream bounded reduction compiles to SemanticIR
  - Proof: experiments/stream_input_proof/ PASS
  Prerequisite: PROP-022 History[T] accepted
```

### Stage 2 PROP G — OLAPPoint[T, Dims] (PROP-024)

```text
Done when:
  - OLAPPoint[T, Dims] declared and resolved by TypeChecker
  - olap_point declaration maps to SemanticIR projection node
  - Cluster scatter-gather pattern provable in RuntimeMachine
  - Proof: experiments/olap_point_proof/ PASS
  Prerequisite: PROP-022 History[T] accepted
```

---

## Agent Routing

```text
[Research Agent]            → Deferred Gap B (production compiler package foundation)
                            → Tier 1 proofs: history_type_proof, invariant_severity_proof
                            → Tier 2 proofs: stream_input_proof, olap_point_proof

[Compiler/Grammar Expert]  → PROP-028+ new design proposals
                            → Amendments/errata to PROP-022..025

[Igniter-Lang Meta Expert] → This file + current-status.md updates
                            → Stage 2 scoreboard sync after each proof
                            → Stage 2 close governance (META-EXPERT-009)

Do not start:
  ❌ PROP-028+ implementation before authoring the matching PROP
  ❌ History[T] implementation before PROP-022 verification pass
  ❌ Breaking changes to Stage 1 accepted PROPs (proposals/accepted/)

Do start:
  ✅ Deferred Gap B — production compiler package foundation
  ✅ Tier 1 proofs: history_type_proof, invariant_severity_proof (parallel)
```

---

## Allowed vs Blocked Research

```text
ALLOWED:
  Implementing remaining Tier 0 deferred gaps
  Authoring experiments for PROP-022..025
  Authoring PROP-028+ new proposals
  Expanding stdlib kernel for Stage 2 operators
  Planning production compiler package

BLOCKED:
  Modifying proposals/accepted/ (Stage 1 frozen)
  Implementing Stage 3+ PROPs (PROP-028+) before Stage 2 closes
  Breaking SemanticIR envelope shape (PROP-019.1 accepted — read-only)
  Breaking .igapp/ format (PROP-022A accepted — read-only)
  New speculation tracks without a PROP
```

---

## Stage 2 Close Criteria

Stage 2 closes when:

```text
1. Deferred gaps A, B, C: all addressed (A and C already closed)
2. PROP-022 (History[T]): experiments/history_type_proof/ PASS
3. PROP-023 (stream T): experiments/stream_input_proof/ PASS
4. PROP-024 (OLAPPoint): experiments/olap_point_proof/ PASS
5. PROP-025 (severity): experiments/invariant_severity_proof/ PASS
6. A stage2_close_candidate runner exists and PASS
```

Stage 2 close governed by META-EXPERT-009 (not yet written).

---

## New Proposal Intake

New Stage 2+ proposals start from **PROP-028**.

Before authoring a new PROP:
- Check that it does not duplicate accepted Stage 1 PROPs
- Specify Stage (2 / 3+), dependencies, and experiment path
- Author in `proposals/` with standard header format

---

## References

```
META-EXPERT-007   Stage 1 close verdict
META-EXPERT-003   Stage 1 governance (complete — historical reference)
proposals/accepted/README.md       Frozen Stage 1 PROP inventory
experiments/stage1_close_candidate/stage1_close_candidate.json   Close evidence
docs/current-status.md             Live scoreboard
```
