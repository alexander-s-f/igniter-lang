# Stage 1 Close: Snapshot and Stage 2 Opening Plan

Role: `[Igniter-Lang Meta Expert]`
Status: plan (not yet executed)
Date: 2026-05-06
Authorized by: META-EXPERT-007-stage1-close-governance-v0
Track: stage1-close-snapshot-and-stage2-opening-plan-v0

> **DO NOT EXECUTE** any file moves or renames until the user explicitly approves.
> This document is preparation only.

---

## 1. Close Evidence

`experiments/stage1_close_candidate/stage1_close_candidate.json` is the official
close evidence artifact. No additional action needed — it is already in the repo.

Reference in any future review:
```
Close evidence: igniter-lang/experiments/stage1_close_candidate/stage1_close_candidate.json
  status: PASS
  close signals: direct_prop0191_runtime_loader, typechecker_self_contained_boundary,
                 stdlib_stage1_kernel, runtime_eval_surface
  open gaps: parser_oof_rejection_gap, production_compiler_assembly
```

---

## 2. Archive Snapshot

### Path

```
igniter-lang/docs/archive/snapshots/2026-05-06-stage1-close/
```

### What to snapshot (copy, do not move)

```
igniter-lang/docs/proposals/              → archive/snapshots/2026-05-06-stage1-close/proposals/
igniter-lang/docs/spec/                   → archive/snapshots/2026-05-06-stage1-close/spec/
igniter-lang/docs/meta-proposals/         → archive/snapshots/2026-05-06-stage1-close/meta-proposals/
igniter-lang/docs/current-status.md       → archive/snapshots/2026-05-06-stage1-close/current-status.md
igniter-lang/docs/language-spec.md        → archive/snapshots/2026-05-06-stage1-close/language-spec.md
igniter-lang/docs/README.md               → archive/snapshots/2026-05-06-stage1-close/README.md
```

### Snapshot README content

```markdown
# Snapshot: 2026-05-06 Stage 1 Close

Captured: 2026-05-06
Status: Stage 1 CLOSED WITH DEFERRED GAP (META-EXPERT-007)

This snapshot preserves the documentation state at Stage 1 close.
It is the authoritative historical record of what was proven and what was deferred.

Close evidence: experiments/stage1_close_candidate/stage1_close_candidate.json
Verdict doc:    meta-proposals/META-EXPERT-007-stage1-close-governance-v0.md
```

---

## 3. PROP Freeze List

### PROP naming collision — must resolve first

Two pairs of files share the same PROP number. Before freezing, rename one from each pair:

| Current filename | Rename to |
|------------------|-----------|
| `PROP-022-igapp-assembler-contract-v0.md` | `PROP-022A-igapp-assembler-contract-v0.md` |
| `PROP-023-classified-expr-boundary-v0.md` | `PROP-023A-classified-expr-boundary-v0.md` |

Rationale:
- `PROP-022-history-type-constructor-v0.md` → Stage 2 design PROP (keep as-is)
- `PROP-022A-igapp-assembler-contract-v0.md` → Stage 1 implementation PROP (freeze)
- `PROP-023-stream-input-surface-v0.md` → Stage 2 design PROP (keep as-is)
- `PROP-023A-classified-expr-boundary-v0.md` → Stage 1 late addition (freeze)

### Stage 1 PROPs → freeze (move to `proposals/accepted/`)

These are implementation PROPs directly proven in Stage 1 experiments:

```
PROP-001-semantic-domain-v0.md                  (identity model)
PROP-003-grammar-fragment-classification-v0.md  (classifier spec)
PROP-004-type-system-v0.md                      (type grammar)
PROP-004b-axiom-layer-type-signatures-v0.md     (type errata)
PROP-006-runtime-contract-specification-v0.md   (runtime model)
PROP-009-semantic-image-resume-compatibility-v0.md
PROP-009.1-resume-ordering-errata.md
PROP-011-runtime-machine-lifecycle-v0.md
PROP-012-compilation-artifact-deployment-model-v0.md
PROP-013-stdlib-fold-aggregate-v0.md
PROP-014-source-syntax-semanticir-boundary-v0.md
PROP-015-grammar-module-system-v0.md
PROP-018-source-to-semanticir-minimal-pipeline-v0.md
PROP-019-canonical-semanticir-envelope-v0.md
PROP-019.1-semanticir-envelope-errata-v0.md
PROP-020-classifier-pass-v0-formalization.md
PROP-021-typechecker-pass-v0-formalization.md
PROP-022A-igapp-assembler-contract-v0.md        (after rename)
PROP-023A-classified-expr-boundary-v0.md        (after rename)
META-001-compiler-grammar-expert-entry.md
```

### PROPs to defer / leave active (NOT moved to accepted/)

These are design PROPs not implemented in Stage 1:

```
PROP-002-contract-composition-algebra-v0.md     (algebra — not yet proven)
PROP-005-bridge-observation-envelope-v0.md      (bridge/IoT — Stage 2+)
PROP-005.1-obspacket-patch-lifecycle-v0.md      (bridge errata — Stage 2+)
PROP-007-conformance-verification-v0.md         (conformance — Stage 2+)
PROP-008-tbackend-contract-v0.md               (tbackend — Stage 2+)
PROP-010-temporal-lifecycle-retention-v0.md    (temporal semantics — Stage 2+)
PROP-016-polymorphism-traits-v0.md             (traits/polymorphism — Stage 2+)
PROP-017-schema-evolution-migration-v0.md      (schema evolution — Stage 2+)
PROP-022-history-type-constructor-v0.md        (Stage 2 design)
PROP-023-stream-input-surface-v0.md            (Stage 2 design)
PROP-024-olap-point-primitive-v0.md            (Stage 2 design)
PROP-025-invariant-severity-levels-v0.md       (Stage 2 design)
```

These stay in `proposals/` as the Stage 2 active intake baseline.

---

## 4. File Move Plan (execute only after approval)

```bash
# Step 0: Take snapshot (copy, not move)
cp -r igniter-lang/docs/proposals  igniter-lang/docs/archive/snapshots/2026-05-06-stage1-close/
cp -r igniter-lang/docs/spec       igniter-lang/docs/archive/snapshots/2026-05-06-stage1-close/
cp -r igniter-lang/docs/meta-proposals igniter-lang/docs/archive/snapshots/2026-05-06-stage1-close/
cp igniter-lang/docs/current-status.md igniter-lang/docs/archive/snapshots/2026-05-06-stage1-close/
cp igniter-lang/docs/language-spec.md  igniter-lang/docs/archive/snapshots/2026-05-06-stage1-close/
cp igniter-lang/docs/README.md         igniter-lang/docs/archive/snapshots/2026-05-06-stage1-close/
# (write snapshot README separately)

# Step 1: Resolve naming collisions (rename before move)
git mv igniter-lang/docs/proposals/PROP-022-igapp-assembler-contract-v0.md \
       igniter-lang/docs/proposals/PROP-022A-igapp-assembler-contract-v0.md
git mv igniter-lang/docs/proposals/PROP-023-classified-expr-boundary-v0.md \
       igniter-lang/docs/proposals/PROP-023A-classified-expr-boundary-v0.md

# Step 2: Create accepted/ directory
mkdir -p igniter-lang/docs/proposals/accepted

# Step 3: Move Stage 1 PROPs to accepted/
# (list from §3 freeze list — 20 files after rename)
for f in PROP-001 PROP-003 PROP-004 PROP-004b PROP-006 PROP-009 PROP-009.1 \
         PROP-011 PROP-012 PROP-013 PROP-014 PROP-015 PROP-018 PROP-019 \
         PROP-019.1 PROP-020 PROP-021 PROP-022A PROP-023A META-001; do
  git mv igniter-lang/docs/proposals/${f}*.md \
         igniter-lang/docs/proposals/accepted/
done

# Step 4: Update proposals/README.md — split into Accepted / Active sections
```

---

## 5. Stage 2 Governance Opening Document Skeleton

**Path**: `igniter-lang/docs/meta-proposals/META-EXPERT-008-stage2-implementation-governance-v0.md`

**Do not write yet.** Write when user approves Stage 2 opening.

Content skeleton when written:

```markdown
# META-EXPERT-008: Stage 2 Implementation Governance v0

## Stage 2 Scoreboard

| Pass | PROP | Experiment | Status |
|------|------|-----------|--------|
| Parser OOF hardening | PROP-014/015 | experiments/parser/ | open gap |
| History[T] type | PROP-022 | — | pending |
| stream T input | PROP-023 | — | pending |
| OLAPPoint | PROP-024 | — | pending |
| Invariant severity | PROP-025 | — | pending |
| runtime eval surface | — | runtime eval expansion | deferred from Stage 1 |
| Production compiler pkg | — | — | deferred from Stage 1 |

## New PROP intake: PROP-028+ after reserved post-close PROP-026 and PROP-027
## Agent routing: [Research Agent] | [Compiler Expert] | [Meta Expert]
## Allowed: implementation of PROP-022..025
## Blocked: breaking changes to Stage 1 accepted PROPs
```

---

## 6. proposals/README.md Update Plan

After freeze, `proposals/README.md` should be structured as:

```markdown
## Active Intake (Stage 2+)

PROPs 002, 005, 005.1, 007, 008, 010, 016, 017, 022, 023, 024, 025

## Accepted (Stage 1 — frozen)

→ See proposals/accepted/ directory.
All accepted PROPs are read-only. No amendments except errata.

## New proposals: start from PROP-028
```

---

## 7. Execution Order (when approved)

```
1. Take snapshot (cp -r)               ← safe, additive
2. Write snapshot README               ← safe, additive
3. Resolve PROP-022/023 naming         ← git mv (requires approval)
4. Create accepted/ and move freeze list ← git mv (requires approval)
5. Update proposals/README.md          ← edit (requires approval)
6. Update docs/README.md to note Stage 1 closed
7. Write META-EXPERT-008 skeleton      ← only when user approves Stage 2 opening
```

---

## 8. What This Plan Does NOT Do

```
✗ Does not start Stage 2 implementation
✗ Does not write META-EXPERT-008 body (only skeleton defined here)
✗ Does not move proposals yet (plan only)
✗ Does not change any experiment golden files
✗ Does not change language semantics
```
