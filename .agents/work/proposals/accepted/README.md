# proposals/accepted/ — Stage 1 Frozen Decisions

All files in this directory are **read-only** Stage 1 accepted PROPs.

- Frozen effective: 2026-05-06
- Authorized by: META-EXPERT-007-stage1-close-governance-v0

No amendments except errata. Errata files may be added alongside the original.
Do not rename or delete files in this directory.

## Naming Convention Note

Files `PROP-022A` and `PROP-023A` use an `-A` suffix because their number-space
collides with active Stage 2 design PROPs:

| Accepted file | Meaning | Active Stage 2 PROP |
|---------------|---------|---------------------|
| `PROP-022A-igapp-assembler-contract-v0.md` | Stage 1 assembler contract | `PROP-022` = History[T] |
| `PROP-023A-classified-expr-boundary-v0.md` | Stage 1 ClassifiedExpr boundary | `PROP-023` = stream T |

When citing these accepted PROPs, always use the full filename or the `-A` number.
Bare `PROP-022` always refers to the Stage 2 History[T] design.
See `META-EXPERT-008.1-prop-numbering-audit-v0.md` for full canonical map.


## Contents

| File | Stage | Topic |
|------|-------|-------|
| PROP-001 | 1 | Semantic domain and identity model |
| PROP-003 | 1 | Grammar fragment classification (CORE/ESCAPE/OOF) |
| PROP-004 | 1 | Type system v0 |
| PROP-004b | 1 | Axiom layer type signatures (errata) |
| PROP-006 | 1 | Runtime contract specification |
| PROP-009 | 1 | Semantic image resume compatibility |
| PROP-009.1 | 1 | Resume ordering errata |
| PROP-011 | 1 | RuntimeMachine lifecycle |
| PROP-012 | 1 | Compilation artifact deployment model |
| PROP-013 | 1 | Stdlib fold/aggregate |
| PROP-014 | 1 | Source syntax and SemanticIR boundary |
| PROP-015 | 1 | Grammar module system |
| PROP-018 | 1 | Source-to-SemanticIR minimal pipeline |
| PROP-019 | 1 | Canonical SemanticIR envelope |
| PROP-019.1 | 1 | SemanticIR envelope errata (CompilationReport split) |
| PROP-020 | 1 | Classifier pass v0 formalization |
| PROP-021 | 1 | TypeChecker pass v0 formalization |
| PROP-022A | 1 | .igapp assembler contract and RuntimeMachine load gate |
| PROP-023A | 1 | Classified expression boundary formalization |
| META-001 | 1 | Compiler/Grammar expert entry protocol |
