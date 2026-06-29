# Proposal: stdlib.collection.flat_map
## LANG-STDLIB-COLLECTION-FLATMAP-P1

**Lane:** lang / stdlib / collection / flat_map
**Status:** authored-pending-review
**Date:** 2026-06-28
**Card:** `igniter-lab/.agents/work/cards/lang/LANG-STDLIB-COLLECTION-FLATMAP-PROP-P1.md`
**Readiness packet:** `igniter-lab/lab-docs/lang/lang-stdlib-collection-flatmap-prop-p1-v0.md`
**Predecessor:** `LAB-STDLIB-COLLECTION-FLATMAP-OR-CONCAT-P1` (flat_map chosen as the smallest
primitive); parks `flatten`/`flat_map` from the CONCAT proposal's D12.

---

## Summary

Admit `flat_map` as a public collection HOF source alias, emitting `stdlib.collection.flat_map`. It is
the smallest primitive that turns one element into many and assembles them flat — directly unblocking
3D mesh/triangle descriptor emission, ViewArtifact list assembly, report/table section assembly, and
science list transforms. The VM runtime already implements it (array per-element lambda, results
flattened one level; commit `d2ed524`). This proposal admits the **canon compiler surface**, which is
intentionally gated (`COLLECTION_HOF_FNS` requires PROP amendment + P4+ authorization).

## Canonical Contract

| Field | Value |
| --- | --- |
| Source alias | `flat_map(collection, item -> collection)` |
| SemanticIR name | `stdlib.collection.flat_map` (only name emitted) |
| Signature | `flat_map(Collection[A], A -> Collection[B]) -> Collection[B]` |
| Arity / lambda | 2, `has_lambda: true` |
| Purity | `pure`, deterministic, total, `authority_surface: none` |
| Result-type rule | **one-level unwrap** — result element type = lambda body's collection element type; `A -> Collection[B]` ⇒ `Collection[B]`, never `Collection[Collection[B]]` |
| Unknown | permissive (as `map`/`filter`/`concat`): `Collection[Unknown]` in ⇒ `Collection[Unknown]` out, no error |

## Relationship to `map` and `and_then`

- `map(Collection[A], A -> B) -> Collection[B]` (no flattening).
- `flat_map(Collection[A], A -> Collection[B]) -> Collection[B]` (one-level flatten).
- `and_then` stays **Result-monadic only** (`typechecker.rb:1277`). Collections expose `flat_map`
  only; `and_then` is NOT overloaded for collections (no canon monadic-naming policy to lean on, and
  it would collide with the Result op).

## OOF Namespace

| Code | When |
| --- | --- |
| `OOF-COL1` | wrong arity / second arg not a lambda (reuse) |
| `OOF-COL2` | first arg not `Collection`/`Unknown` (reuse) |
| **`OOF-COL9`** | **NEW** — lambda body type is not a `Collection` (and not `Unknown`) |

`OOF-COL9` is the next free code (COL1–COL8 are in use). A dedicated code is chosen over an `OOF-COL2`
variant because body-not-collection is a semantically distinct failure and `flat_map` is the first
HOF whose lambda body must itself be a collection.

## Current Toolchain State (evidence, not authority)

- **Canon Ruby:** `COLLECTION_HOF_FNS` = `map`/`filter`/`count` only; `flat_map` unregistered.
- **Canon inventory:** no `stdlib.collection.flat_map` entry.
- **Lab Rust:** placeholder only — `stdlib_calls.rs:1519` rides the Result `and_then` path with an
  "Integer placeholder"; it does NOT implement the collection one-level-unwrap. P4 replaces it.
- **Lab VM:** runtime implemented and proven (`vm.rs:1020`, `d2ed524`).

## Design Decisions

- **D1** Public source alias `flat_map`; SIR `stdlib.collection.flat_map` only.
- **D2** One-level unwrap is the crucial type rule (no double-wrap).
- **D3** `and_then` not exposed for collections (Result-only).
- **D4** `OOF-COL9` is the new lambda-body-not-collection diagnostic.
- **D5** Unknown permissive, consistent with sibling HOFs.
- **D6** `flatten(Collection[Collection[T]])` and comprehensions are OUT of v0.

## Implementation Cards

- **`LANG-STDLIB-COLLECTION-FLATMAP-P3`** — canon Ruby `igc`: add to `COLLECTION_HOF_FNS` +
  one-level-unwrap typing + `OOF-COL9` in `typechecker.rb` (one file; no parser/SIR/inventory edit).
- **`LANG-STDLIB-COLLECTION-FLATMAP-P4`** — lab Rust parity: replace the `stdlib_calls.rs` placeholder
  with the collection contract; emitter emits `stdlib.collection.flat_map`; byte-parity with Ruby; VM
  unchanged. Inventory entry + digest recompute follow (P5-style) with the proof lineage above.

## App / Domain Evidence

P7 mesh emission needs `body -> [tri, tri, …]` assembled flat; with only `map` this is nested
`Collection[Collection[Tri]]` and the language has no flatten. The same row→many-elements shape recurs
in ViewArtifact list assembly, report/table sections, and science list transforms. `flat_map` covers
all with one primitive.
