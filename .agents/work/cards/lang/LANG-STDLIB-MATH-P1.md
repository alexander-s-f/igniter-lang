# LANG-STDLIB-MATH-P1

**Status:** CLOSED — ROUTED  
**Route:** LANG STDLIB / MATH READINESS  
**Date:** 2026-06-14  
**Authority:** proposal/readiness only; no implementation

## Goal

Classify the stdlib math pressure exposed by `air_combat` AC-P07 and decide whether a bounded integer math surface (`sqrt`, `hypot`, maybe `abs`) should be proposed.

`air_combat` currently uses squared distances (`VMag2`, `VDist2`) and gain-scaled steering because there is no `sqrt` / vector normalization. This is acceptable for a proof app but not for better guidance fidelity.

## Required Reads

- `/Users/alex/dev/projects/igniter-workspace/igniter-lab/igniter-apps/air_combat/PRESSURE_REGISTRY.md`
- `/Users/alex/dev/projects/igniter-workspace/igniter-lab/igniter-apps/air_combat/report.md`
- `/Users/alex/dev/projects/igniter-workspace/igniter-lab/igniter-apps/air_combat/vec.ig`
- `/Users/alex/dev/projects/igniter-workspace/igniter-lab/igniter-apps/air_combat/guidance.ig`
- Existing numeric/fixed-point cards: `LAB-STDLIB-NUMERIC-FIXED-POINT-P1`, `LANG-STDLIB-NUMERIC-COMPARISON-P3/P4`.
- `/Users/alex/dev/projects/igniter-workspace/igniter-lang/docs/spec/stdlib-inventory.json`

## Questions

1. Is the immediate surface `sqrt(Integer)->Integer`, `hypot(Integer,Integer)->Integer`, `abs(Integer)->Integer`, or something narrower?
2. Should math functions be fixed-point-aware or strictly integer operations?
3. What totality/rounding policy is acceptable for `sqrt`?
4. Should negative input be OOF, runtime failure, clamp, or undefined? Is this compile-time decidable only for literals?
5. Do current apps besides `air_combat` need this surface?
6. Is this stdlib-only, or does it require VM/runtime semantics later?
7. What proof matrix and OOF namespace should P2/P3 use?

## Deliverables

- Proposal/readiness doc: `/Users/alex/dev/projects/igniter-workspace/igniter-lang/.agents/work/proposals/LANG-STDLIB-MATH-P1-readiness-v0.md`.
- Proof/survey runner: `/Users/alex/dev/projects/igniter-workspace/igniter-lang/experiments/stdlib_math_proof/verify_stdlib_math_p1.rb`, target at least 45 checks.
- Update this card with closure summary.
- Proposals README and portfolio update after closure.

## Acceptance

- AC-P07 is grounded in real source evidence.
- The card chooses route: reject, docs pattern, `abs` only, `sqrt/hypot` proposal, or hold.
- No implementation occurs.
- Numeric totality/rounding risks are named.

## Results

- **Kinematics Grounding**: AC-P07 confirmed in `vec.ig` (VMag2/VDist2 squared workarounds) and `guidance.ig` (proportional steering limitations).
- **Decided Route**: Bounded integer math proposal (`abs`, `sqrt`, `hypot`).
- **Totality & Domain**: `sqrt(x)` returns `0` for `x < 0` at runtime to protect sim loops; negative literals are compile-time `OOF-MTH1`.
- **Rounding**: Floor truncation (integer square root).
- **Fixed-Point**: Neutral integer functions; scaling stays at the app level.
- **VM/Runtime**: Stdlib-only bindings.
- **Proof Coverage**: 47/47 PASS verified by the survey runner.

## Closed Surfaces

- No floating-point type.
- No trigonometry/general math package.
- No runtime/VM implementation.
- No app source migration.
- No IO.
