# LANG-FOLD-STRUCT-ACCUMULATOR-P4: Lowering Parity Proof

**Status:** CLOSED -- IMPLEMENTED -- PROOF 83/83 PASS
**Date:** 2026-06-14
**Route:** LANG IMPLEMENTATION / Ruby emitter fold lowering parity
**Authority:** bounded SemanticIR lowering parity only
**Card:** `LANG-FOLD-STRUCT-ACCUMULATOR-P4`

---

## Summary

P4 brings ordinary `fold(...)` SemanticIR lowering to the structured fold stage
shape established by the Rust emitter helper:

```json
{ "kind": "fold", "param_acc": "...", "param_val": "...", "init": ..., "body": ... }
```

The stage is emitted inside a `map_reduce_aggregate` envelope so the collection
source is preserved.

## Implementation

Changed canon files:

```text
/Users/alex/dev/projects/igniter-workspace/igniter-lang/lib/igniter_lang/typechecker.rb
/Users/alex/dev/projects/igniter-workspace/igniter-lang/lib/igniter_lang/semanticir_emitter.rb
```

Changed lab parity file:

```text
/Users/alex/dev/projects/igniter-workspace/igniter-lab/igniter-compiler/src/emitter.rs
```

Key points:

- Ruby TypeChecker now preserves the already typechecked lambda as the third
  typed fold argument. This is metadata preservation for the emitter, not a new
  typing rule.
- Ruby SemanticIR emitter recognizes `fold` / `stdlib.collection.fold` and
  lowers it to `map_reduce_aggregate` with a structured `fold` pipeline stage.
- Rust lab emitter now delegates ordinary `fold` compute expressions to the
  existing map/reduce optimizer and returns the existing structured fold stage
  for single-step fold calls.

No Rust TypeChecker work was done in P4.

## Semantics Proven

- Ruby scalar fold compiles cleanly and emits a structured fold stage.
- Ruby record fold compiles cleanly and emits the same aggregate/stage envelope.
- Rust scalar and record fold compile cleanly and emit the same normalized
  aggregate/stage envelope as Ruby.
- Generic `fold` / `stdlib.collection.fold` calls are absent from emitted fold
  SIR.
- Ruby `fold_stream` remains separate and green.
- `LANG-FOLD-STRUCT-ACCUMULATOR-P3` remains green.

## Proof

Runner:

```text
/Users/alex/dev/projects/igniter-workspace/igniter-lang/experiments/fold_struct_accumulator_proof/verify_fold_struct_accumulator_p4.rb
```

Command:

```bash
cd /Users/alex/dev/projects/igniter-workspace/igniter-lang
ruby experiments/fold_struct_accumulator_proof/verify_fold_struct_accumulator_p4.rb
```

Result:

```text
TOTAL: 83/83 PASS
```

The runner builds the Rust compiler with `cargo build --release` and also runs
the P3 runner.

## P3 Note Resolved

P3 recorded that Rust emitter source already contained the structured fold helper
but ordinary single-step `fold(...)` artifacts still lowered as generic calls.
P4 resolves that artifact parity gap with emitter-only alignment. This does not
retroactively make P3 a Rust emitter slice; P3 remains a Rust TypeChecker slice,
and P4 owns the lowering/artifact parity.

## Closed Surfaces

- No parser changes.
- No Rust TypeChecker changes in P4.
- No app migrations.
- No `group_by`, join, `flat_map`, scan, or reduce-all expansion.
- No parser ergonomics for `-> { ... }`.
- No runtime, IO, capability, persistence, queue, file, network, or app
  authority.
- Lab proof/evidence remains evidence only; canon authority remains in
  `igniter-lang`.
