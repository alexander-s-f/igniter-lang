# Igniter-Lang Language Specification (Index)

Version: 0.3 — crystallized from Stage 1 PROPs
Maintained by: `[Igniter-Lang Meta Expert]`
Last updated: 2026-05-20

> **The spec is now structured as chapters in `docs/spec/`.**
> This file is the entry-point index.

---

## Chapters

| # | Chapter | PROP Sources | Status |
|---|---------|-------------|--------|
| [Ch1](spec/ch1-identity.md) | Identity and Semantic Model | PROP-001 | accepted |
| [Ch2](spec/ch2-source-surface.md) | Source Surface and Grammar | PROP-014, 015 | accepted / OOF gap |
| [Ch3](spec/ch3-type-system.md) | Type System | PROP-004, 021 | ✅ PASS ✅ boundary CLOSED |
| [Ch4](spec/ch4-fragment-classification.md) | Fragment Classification | PROP-003, 020 | ✅ PASS |
| [Ch5](spec/ch5-compiler-pipeline.md) | Compiler Pipeline | PROP-018, 019.1, 038 | accepted / R84 strict-refusal internal foundation synced |
| [Ch6](spec/ch6-semanticir.md) | SemanticIR and CompilationReport | PROP-019.1 | ✅ PASS ✅ assembler PASS |
| [Ch7](spec/ch7-runtime.md) | RuntimeMachine | PROP-006, 009, 011, 038 | accepted + proven ✅ / PROP-038 strict refusal is non-runtime |
| [Ch8](spec/ch8-stdlib.md) | Stdlib | PROP-013 | accepted / proof pending |
| [Ch9](spec/ch9-stage2-reserved.md) | Stage 2 Reserved Primitives | PROP-022–025 | deferred |

---

## Coverage Summary

```
accepted + PASS   Ch3 (TypeChecker + boundary), Ch4 (classifier), Ch5 (pipeline + assembler),
                  Ch6 (SemanticIR + assembler), Ch7 (RuntimeMachine), Ch8 (stdlib kernel)
accepted partial  Ch2 (OOF parse gap — non-blocking; §2.2.3 if_expr v0 source shape R190)
deferred          Ch9 (Stage 2)
compiler-profile  PROP-038 strict refusal is accepted only as an internal compiler
                  foundation; public/runtime/production refusal remains closed
R190 internal     Expression-level if_expr v0: TypeChecker (OOF-IF1..IF4) + typed
                  SemanticIR lowering (flat condition/then_branch/else_branch). 28/28
                  proof PASS. Runtime/evaluator closed. Release evidence unchanged.
                  See Ch2 §2.2.3, Ch3 §3.3 Rule IF-v0, Ch5 §5.6.1, Ch6 §6.10.
```

---

## Stage 1 Implementation Gaps

```
1.  OOF rejection at parse time (Ch2) — non-blocking; caught at Classify/TypeCheck.
    Will be addressed in grammar hardening pass.
    All other Stage 1 proofs: PASS.
```

→ See `docs/current-status.md` for scoreboard and next slices.
→ See `docs/proposals/` for canonical PROP decision records.
→ See `docs/archive/snapshots/2026-05-06-stage1-pre-crystallization/` for full history.
