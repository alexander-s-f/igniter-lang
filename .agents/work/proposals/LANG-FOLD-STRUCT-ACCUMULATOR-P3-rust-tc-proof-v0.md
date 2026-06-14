# LANG-FOLD-STRUCT-ACCUMULATOR-P3: Rust TC Proof

**Status:** CLOSED -- IMPLEMENTED -- PROOF 83/83 PASS
**Date:** 2026-06-14
**Route:** LANG IMPLEMENTATION / Rust TypeChecker fold record accumulator
**Authority:** bounded Rust TypeChecker implementation only
**Card:** `LANG-FOLD-STRUCT-ACCUMULATOR-P3`

---

## Summary

P3 implements the Rust TypeChecker lift for:

```igniter
fold(Collection[T], Acc, (Acc, T) -> Acc)
```

where `Acc` is a named record/struct type.

The implementation is scoped to:

- contextual inline record seed typing from output or compute annotation context;
- `acc: Acc` and `elem: T` lambda binding;
- lambda body inference;
- structural body-to-`Acc` validation;
- `OOF-COL4` for fold-specific shape/type/arity failures;
- scalar fold regression safety.

No parser, Rust emitter, Ruby, app, IO, runtime, capability, or new OOF-code
surface is introduced.

---

## Implementation

Changed file:

```text
/Users/alex/dev/projects/igniter-workspace/igniter-lab/igniter-compiler/src/typechecker.rs
```

Key insertion points:

- `typechecker.rs:1121` -- compute-phase contextual fold upgrade. When a compute
  expression is `fold(...)` and the compute/output context names a record type,
  the fold seed/lambda are rechecked with that expected `Acc`.
- `typechecker.rs:2161` -- `check_record_literal_shape_col4`, which reuses the
  existing record-literal shape checker and maps fold-specific failures to
  `OOF-COL4`.
- `typechecker.rs:2328` -- `infer_fold_call_type`, the Rust fold TC helper.
- `typechecker.rs:4014` -- the `"fold" =>` arm now delegates to
  `infer_fold_call_type`.

The helper preserves the old scalar path when `Acc` is scalar and adds the
record path when `Acc` is concrete. Inline record seed contextualization is
bounded: without a named record output or compute annotation, bare record
literals still remain `Unknown` by the existing Rust rule.

---

## Semantics Proven

Positive behavior:

- scalar fold still compiles with zero diagnostics;
- named record seed compiles;
- inline record seed is contextualized by output type and compiles;
- inline record seed is contextualized by compute annotation and compiles;
- lambda params are bound as `acc: Acc` and `elem: T`;
- lambda body may return an inline record literal structurally assignable to
  `Acc`;
- lambda body may return a same-module `call_contract(...)` result assignable to
  `Acc`.

Negative behavior:

- bad record field type emits `OOF-COL4`;
- missing record field emits `OOF-COL4`;
- extra record field emits `OOF-COL4`;
- scalar/non-record body returned for record `Acc` emits `OOF-COL4`;
- wrong fold arity emits `OOF-COL4`;
- wrong lambda parameter count emits `OOF-COL4`;
- non-collection first argument emits `OOF-COL4`;
- non-lambda third argument emits `OOF-COL4`;
- malformed inline record seed emits `OOF-COL4` before an output mismatch
  cascade.

---

## Proof

Runner:

```text
/Users/alex/dev/projects/igniter-workspace/igniter-lab/igniter-compiler/verify_fold_struct_accumulator_p3.rb
```

Command:

```bash
ruby verify_fold_struct_accumulator_p3.rb
```

Result:

```text
TOTAL: 83/83 PASS
```

Sections:

- A source guards and gates: 10/10
- B positive fold behavior: 14/14
- C negative fold behavior: 18/18
- D app pressure fixtures: 12/12
- E collection regressions: 11/11
- F Rust emitter / SIR guards: 10/10
- G closed surfaces: 8/8

The runner builds the Rust compiler with `cargo build --release` before running
fixtures.

---

## Regression Proof

`LANG-FOLD-STRUCT-ACCUMULATOR-P2` proof was updated from broken-state assertions
to fixed-state assertions, as allowed by the P3 acceptance criteria.

Command:

```bash
ruby experiments/fold_struct_accumulator_proof/verify_fold_struct_accumulator_p2.rb
```

Result:

```text
Result: 64/64 PASS
```

---

## App Pressure Covered

The proof includes app-pressure evidence and fixtures from:

- `air_combat`: Kalman track fold-to-struct pressure and swarm centroid record
  fold pressure; the full air_combat baseline still compiles clean.
- `trade_robot`: RunBacktest portfolio fold and RSI record fold pressure.
- `sim_framework`: rule-chain state fold pressure.

No app source files were changed.

---

## Emitter / P4 Note

P2 correctly routed lowering parity to P4, but its wording overstated the live
Rust artifact shape. The Rust emitter source contains a structured fold helper
with `kind: "fold"`, `param_acc`, `param_val`, `init`, and `body`, but ordinary
single-step `fold(...)` artifacts are still accepted through the existing generic
call/apply lowering path.

P3 therefore leaves Rust emitter code unchanged and records this as a P4/parity
concern. P4 should handle Ruby fold-node parity and may revisit ordinary Rust
artifact fold-node emission if the cross-toolchain SIR diff requires it.

---

## Closed Surfaces

- No parser changes.
- No `-> { ... }` parser ergonomics.
- No Ruby TypeChecker or Ruby emitter changes in P3.
- No Rust emitter changes in P3.
- No app migrations.
- No `group_by`, join, `flat_map`, or reduce-all expansion.
- No IO/runtime/capability authority.
- No new OOF code family.

---

## Next Route

Route to `LANG-FOLD-STRUCT-ACCUMULATOR-P4` for lowering parity:

- Ruby emitter canonical fold node;
- cross-toolchain fold SIR diff;
- optional Ruby TC structural hardening if needed;
- explicit decision on whether the Rust ordinary fold artifact should emit the
  structured fold helper for single-step fold calls.
