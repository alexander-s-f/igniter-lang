# Stage 2 Proposal Numbering Audit

Role: `[Igniter-Lang Meta Expert]`
Status: decision
Date: 2026-05-07
Track: stage2-prop-renumbering-and-active-intake-audit-v0

---

## Problem Statement

Two PROP number collisions exist from Stage 1 close:

| Number | Stage 1 file (accepted/) | Stage 2 file (proposals/) |
|--------|--------------------------|---------------------------|
| PROP-022 | `PROP-022A-igapp-assembler-contract-v0.md` | `PROP-022-history-type-constructor-v0.md` |
| PROP-023 | `PROP-023A-classified-expr-boundary-v0.md` | `PROP-023-stream-input-surface-v0.md` |

The `-A` suffix was applied at Stage 1 close as a quick collision resolution.
No doc currently references both meanings of the same bare number ambiguously —
all cross-references already use the correct file or clear context —
but the suffix convention is non-standard and will confuse Stage 2 authors.

---

## Audit: Where PROP-022 / PROP-023 Are Referenced

### Bare `PROP-022` (all = History[T]) ✅ unambiguous
```
META-EXPERT-008        lines 56, 65, 70, 89–90, 93–94, 132, 162, 173, 186, 195, 211, 220, 232
current-status.md      lines 187, 265
proposals/README.md    line 33, 46, 50
docs/README.md         lines 16, 71
spec/ch9-stage2-reserved.md  §9.1
spec/README.md         line 49
spec/ch8-stdlib.md     line 166
language-spec.md       line 24
```

### `PROP-022A` (all = assembler contract) ✅ unambiguous
```
META-EXPERT-008        lines 49, 220
current-status.md      line 261
proposals/accepted/README.md  table row
```

### Bare `PROP-023` (all = stream T) ✅ unambiguous
```
META-EXPERT-008        lines 60, 93, 154, 162, 233
current-status.md      lines 188, 266
proposals/README.md    line 34
docs/README.md         line 72
spec/ch9-stage2-reserved.md  §9.2
spec/README.md         line 50
spec/ch8-stdlib.md     line 165
```

### `PROP-023A` (all = classified expr boundary) ✅ unambiguous
```
proposals/accepted/README.md  table row
```

**Finding: no actual ambiguity in any document.** The collision was structural
(two files with same number) but all textual references are already clean.

---

## Decision

```
DECISION: Keep current naming. Do not move files. Establish canonical map below.
```

Rationale:
1. All 40+ cross-references are already unambiguous.
2. Moving accepted/ files breaks git history traceability.
3. The `-A` suffix, while non-standard, is self-documenting in context:
   "PROP-022A = the Stage 1 implementation variant of 022 space."
4. Stage 2 authors receive PROP-028+ after parser hardening claimed PROP-026
   and compiler diagnostics claimed PROP-027 — they never need to author a
   PROP-022x.

---

## Canonical Numbering Map

```
Number    File                                    Stage   Status    Meaning
────────────────────────────────────────────────────────────────────────────────────
PROP-022  PROP-022-history-type-constructor-v0.md   2    authored  History[T]/BiHistory[T]
PROP-022A PROP-022A-igapp-assembler-contract-v0.md  1    accepted  .igapp assembler contract
PROP-023  PROP-023-stream-input-surface-v0.md       2    authored  stream T / fold_stream
PROP-023A PROP-023A-classified-expr-boundary-v0.md  1    accepted  ClassifiedExpr boundary
PROP-024  PROP-024-olap-point-primitive-v0.md       2    authored  OLAPPoint[T,Dims]
PROP-025  PROP-025-invariant-severity-levels-v0.md  2    authored  invariant severity
PROP-026  PROP-026-parser-oof-hardening-spec-v0.md  2    authored  parser OOF hardening
PROP-027  PROP-027-production-compiler-diagnostics-contract-v0.md  2  authored  compiler diagnostics
PROP-028+ (not yet authored)                        2+   queued    new intake
────────────────────────────────────────────────────────────────────────────────────
Convention:
  PROP-NNN       = active or Stage 2 design PROP (no suffix = canonical Stage N design)
  PROP-NNNA      = Stage 1 implementation PROP sharing number-space with a Stage 2 design
  PROP-NNN.M     = errata/patch on PROP-NNN (e.g. PROP-019.1, PROP-009.1)
  New proposals  = PROP-028, PROP-029 ... (no suffix needed — no collisions going forward)
```

---

## Required Doc Updates

Only one update needed: `proposals/accepted/README.md` — clarify the `-A` convention.
All other docs are already correct.

| Doc | Action |
|-----|--------|
| `proposals/accepted/README.md` | Add convention note explaining `-A` suffix |
| `META-EXPERT-008` | Add one-line canonical map note |
| Everything else | No change needed |

---

## Stage 2 Author Instructions

When authoring a new PROP:

```
Start from PROP-028. Use bare numbers only (no suffix).
PROP-022A and PROP-023A are frozen Stage 1 artifacts — do not reference them
in Stage 2 implementation unless citing a specific accepted decision.
When citing History[T] design, always use "PROP-022" (not PROP-022A).
When citing ClassifiedExpr boundary, always use "PROP-023A" (frozen) or
describe by name to avoid ambiguity.
```
