# LANG-STDLIB-COLLECTION-FIRST-LAST-P2 — Ruby Parity Proof

**Status:** closed / proved — 62/62 PASS  
**Date:** 2026-06-14  
**Route:** lang / stdlib.collection / first-last Ruby parity  
**Authority:** bounded Ruby typechecker + inventory implementation only

## Verdict

`first(Collection[T]) -> Option[T]` and `last(Collection[T]) -> Option[T]`
now compile cleanly in Ruby and remain clean in Rust.

This closes the P1 Track 1 gap. It does not close Track 2: `Option[T]`
is still not source-matchable. Until `LANG-SUMTYPE-CONSTRUCT-MATCH-P3+`,
callers can read the result ergonomically only with the dual-clean
`or_else(option, default)` path.

## Implementation

Changed:

- `lib/igniter_lang/typechecker.rb`
  - added `COLLECTION_FIRST_LAST_FNS`
  - added `infer_collection_first_last_call`
  - added `infer_call` dispatch for `first` and `last`
- `docs/spec/stdlib-inventory.json`
  - added `stdlib.collection.first`
  - added `stdlib.collection.last`
  - recomputed `stdlib_surface_digest`

Not changed:

- Ruby parser
- Ruby SemanticIR emitter
- Rust lab typechecker/emitter
- app sources
- Option/Result construction or matchability
- sort/order_by/query APIs

## Behavior

Ruby now mirrors the current Rust type behavior:

| Source | Result |
|--------|--------|
| `first(xs : Collection[Integer])` | `Option[Integer]` |
| `last(xs : Collection[String])` | `Option[String]` |
| `or_else(first(xs), 0)` | `Integer` |
| `or_else(last(xs), "")` | `String` |
| `first()` | `Option[Unknown]` |
| `first(x : String)` | `Option[Unknown]` |
| `last(xs, extra)` | no `OOF-COL1`; result follows first argument |

The permissive `Option[Unknown]` cases are intentional Rust parity for this
slice. The proof does not add new collection diagnostics to `first`/`last`.

## SIR

Ruby emits ordinary call nodes with canonical qualified names:

- `stdlib.collection.first`
- `stdlib.collection.last`

No special SemanticIR node was added.

Rust remains unchanged. The current Rust lab artifact still emits bare
`first`/`last` call names in its SemanticIR, which is recorded as existing
lab behavior rather than canonical authority.

## Caveat

`match first(xs) { Some { value } => ... None { } => ... }` still fails with
`OOF-KIND4` because `Option` is not yet admitted as a sealed built-in variant.

That work remains routed through `LANG-SUMTYPE-CONSTRUCT-MATCH-P3+`.

## Proof

Runner:

`experiments/stdlib_collection_first_last_option_proof/verify_stdlib_collection_first_last_p2.rb`

| Section | Checks |
|---------|--------|
| A — Gates + source structure | 9/9 |
| B — Ruby behavior | 12/12 |
| C — Ruby SIR + inventory | 11/11 |
| D — Rust baseline unchanged | 8/8 |
| E — Option caveat preserved | 8/8 |
| F — Regressions + closed surfaces | 8/8 |
| G — Closure docs | 6/6 |
| **Total** | **62/62 PASS** |

Regression runner updated:

`experiments/stdlib_collection_first_last_option_proof/verify_stdlib_collection_first_last_option_p1.rb`

The P1 runner is now fixed-state: first/last parity is expected to be clean,
while Option matchability remains the live gap.

## Closed Surfaces

- No Option/Result matchability.
- No `some`/`none` constructor implementation.
- No parser changes.
- No runtime or VM authority.
- No app migration.
- No sort/order_by/query API.
- No dynamic dispatch widening.
