# Human-Agent Comprehension Results 003: Academic Sorting Structures v0

Role: `[Igniter-Lang Archive/Form Expert]`
Track: `human-agent-comprehension-results-003-academic-sorting-structures-v0`
Status: research-results
Date: 2026-05-07

Related:
- [Human-Agent Comprehension Testing](human-agent-comprehension-testing-v0.md)
- [Data Structures as Contract Surface Pressure](data-structures-as-contract-surface-pressure-v0.md)
- [Rust Comparison Pressure](rust-comparison-language-pressure-v0.md)
- [Abstraction Layering Pressure](abstraction-layering-primitive-sugar-pressure-v0.md)
- `igniter-lang/experiments/human_agent_syntax_comprehension_fixture/academic_sorting_structures.ig`

---

## Purpose

This document records a blind agent review of the academic sorting/data
structures specimen.

It does not promote the specimen to canon. It preserves the signal that the file
is understandable, but that its academic/proof intent conflicts with some
operational audit vocabulary.

---

## Result Summary

| Review | Estimated score | Summary |
|--------|-----------------|---------|
| Agent Review 1 | 16/20 | Fully understood the program as insertion sort, merge sort, adaptive strategy, and correctness checks; identified a real duplicated-computation bug candidate and a deeper profile mismatch between academic proof semantics and audit/evidence/receipt semantics. |

[D] The program's purpose was understood completely. The problem is not basic
comprehension.

[D] The specimen is valuable because it exposes where "everything is contract"
can become surface monotony or semantic overloading.

---

## What The Reviewer Understood

The reviewer recovered:

- an academic sorting library
- `List[T]`, `Ordering`, and `Ordered[T]`
- insertion sort and merge sort
- adaptive strategy with `n <= 16`
- termination declarations via `decreases`
- correctness checks for sortedness and permutation
- `SortProof` as an attempted proof artifact

[S] ADTs, generics, match, traits, and invariants are readable enough for an
agent without external context.

---

## Pressure Signals

### A1: `evidence: required` Conflicts With Academic Core

In Field Supply Watch, evidence points to source reports, temporal stores,
supplier offers, and audit provenance.

In the sorting specimen:

```text
evidence [xs]
```

mostly points to the function argument itself.

Pressure:

```text
academic proof evidence and operational audit evidence are not the same surface.
```

Possible direction:

```text
profile academic_core {
  proof: required
  evidence: optional
}
```

or:

```text
output sorted = sorted
  proof [output_sorted, output_permutation]
```

[R] Separate proof witnesses from audit provenance before using academic
examples as primary language demos.

### A2: `MergeSort` Duplicates Recursive Work

The specimen computes the same split/sort/merge path for `sorted` and again for
`stats`.

Pressure:

```text
contract syntax should make shared intermediate computations natural and should
help agents detect accidental duplicated contract invocation.
```

The current specimen has a bug candidate:

```text
let sorted = ...
let stats = ...
```

where both branches repeat:

```text
let halves = Split(xs).halves
let left_sorted = MergeSort(halves.first)
let right_sorted = MergeSort(halves.second)
```

[T] If contract calls are pure and memoized, runtime may deduplicate them, but
the source still communicates two computations. If stats/effects/counters are
observable, the distinction matters.

Possible direction:

```text
let halves = Split(xs).halves
let left = MergeSort(halves.first)
let right = MergeSort(halves.second)
let merged = Merge(left.sorted, right.sorted)

let sorted = merged.result
let stats = ...
```

### A3: `SortProof` Is A Receipt Without Receipt Semantics

`DispatchDecisionReceipt` in the supply specimen records a durable decision,
causality, risk, and human override.

`SortProof` records:

```text
sorted_check: Bool
permutation_check: Bool
```

but these checks duplicate invariants:

```text
invariant output_sorted
invariant output_permutation
```

Pressure:

```text
receipt should mean operational/audit artifact; proof should mean theorem,
witness, derivation, or compiler-checkable obligation.
```

Possible direction:

```text
proof SortProof[T] {
  theorem sorted: is_sorted(result)
  theorem permutation: same_multiset(input, result)
}
```

or:

```text
witness SortWitness[T] {
  algorithm: Symbol
  obligations [output_sorted, output_permutation]
}
```

[S] Reusing `receipt` for mathematical proof weakens both meanings.

### A4: `recursion: structural` vs `decreases Length(xs).n`

The profile says:

```text
recursion: structural
termination: required
```

but the contracts use:

```text
decreases Length(xs).n
```

This reads as metric/well-founded recursion rather than purely structural
recursion.

Pressure:

```text
termination mode should distinguish structural recursion from metric decreases.
```

Candidate:

```text
recursion: well_founded
decreases Length(xs).n
```

or:

```text
recursion: structural
decreases xs.tail
```

[R] Align profile names with proof theory vocabulary before formalizing
termination syntax.

### A5: Adaptive Strategy Uses A Magic Constant

The strategy:

```text
n <= 16
```

is recognizable, but unmotivated inside an academic proof specimen.

Pressure:

```text
heuristics need names and rationale, especially in proof-heavy files.
```

Candidate:

```text
threshold insertion_sort_cutoff: Integer = 16
  rationale "small-list insertion sort cutoff"
```

[S] Magic constants are more harmful in academic examples than in business
examples because the reader expects formal motivation.

---

## Deeper Finding

The sorting specimen tries to be three things at once:

1. an academic proof example
2. a general-purpose data structure example
3. an audit/evidence contract example

That combination blurs the language levels.

[D] This supports the abstraction-layering pressure already recorded: Igniter-Lang
needs visible profiles/layers so ordinary programs, academic proofs, business
workflows, and audited distributed systems do not all appear in the same flat
syntax register.

---

## Recommendations

[R1] Add a future `proof`/`witness`/`theorem` vocabulary lane separate from
`receipt`.

[R2] Let academic examples use `proof: required` and `evidence: optional` unless
they intentionally include provenance.

[R3] Fix the sorting specimen before using it in further blind tests: share
`Split`, `MergeSort`, and `Merge` intermediates inside `MergeSort`.

[R4] Name the strategy cutoff and record why it exists.

[R5] Use academic specimens as compiler/proof stress tests, not as first-screen
human examples.

---

## Handoff

[D] Academic sorting review is recorded.

[S] The specimen is readable but semantically overloaded.

[T] Main pressure: split audit evidence, mathematical proof, and general-purpose
data-structure syntax into visible language layers.

[R] Next academic specimen should use primitive arrays/lists on the surface and
reserve contract/proof detail for the layer being tested.
