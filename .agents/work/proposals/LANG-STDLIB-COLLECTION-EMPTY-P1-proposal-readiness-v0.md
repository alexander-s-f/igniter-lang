# LANG-STDLIB-COLLECTION-EMPTY-P1 — Proposal / Readiness

**Date:** 2026-06-12
**Status:** CLOSED — ROUTED
**Track:** lang / stdlib / collection / empty
**Predecessors:** append P3/P4, is_empty P3/P4, LANG-OUTPUT-TYPE-ASSIGNABILITY-P3/P4

---

## Question

What is the correct surface for `stdlib.collection.empty`, and does it need
to be a new stdlib function?

---

## Evidence Base

### `[]` — existing empty literal

Ruby TC (`typechecker.rb:2847`):
```ruby
# infer_array_literal — empty case
collection_type_ir_from(type_ir("Unknown"))  # → Collection[Unknown]
```

Rust TC (`typechecker.rs:698–709`, `1155–1186`):
- `[]` starts as `Unknown`
- `collection_output_hints` pre-scans output declarations; if `output x : Collection[T]`,
  upgrades `[]` assigned to `x` to `Collection[T]`
- No equivalent for `compute` bindings (only output + field contexts via LAB-TC-ARRAY-P2)

### `map_empty()` — existing precedent

```ruby
# typechecker.rb:2388–2397
def infer_map_empty_call(...)
  # map_empty() → Map[String, Unknown]
```

0-arg stdlib function returning a weakly typed Map. Same Unknown-element limitation.
Post-P3/P4 analysis: `Map[String, Unknown]` at a `Map[String, Integer]` output boundary
would fire OOF-TY1 for the same reason as `Collection[Unknown]`.

### Append bootstrap — failure mode

```ig
compute acc = []                          # acc : Collection[Unknown] (Ruby)
compute result = append(acc, transaction) # result : Collection[Unknown] (preserves)
output result : Collection[Transaction]   # OOF-TY1 — actual Collection[Unknown]
```

`infer_append_call` preserves the collection's element type — it does NOT widen
to the item type when the collection is `Collection[Unknown]`. The append contract
is `append(Collection[T], T) → Collection[T]`. With `T = Unknown` (from element
extraction), the result is `Collection[Unknown]`.

### `call_contract("empty")` — not a valid surface

Tests in `verify_lab_ruby_call_contract_parity_p3.rb:210` confirm: `call_contract("empty")`
is expected to produce an error (unresolved callee). There is no built-in contract named "empty".
This was a test for the error path, not a usable surface.

---

## Candidate Analysis

### Candidate A: `empty[T]()` — generic constructor

```ig
compute acc = empty[Transaction]()
```

**REJECTED.** The parser does not support generic type parameter syntax on function calls.
`parse_call_expr` has no `[TypeExpr]` arm. Accepting this surface would require:
- Parser: new `TypeParam` production on calls
- Typechecker: generic instantiation
- Scope far exceeds a stdlib entry card

### Candidate B: `empty_collection("TypeName")` — stringly typed

```ig
compute acc = empty_collection("Transaction")
```

**REJECTED.** String argument is not type-checked, breaks on rename, produces runtime
string-lookup semantics that contradict the static type model. No mechanism for parameterized
types (`"Collection[Transaction]"` — no parser for this at runtime).

### Candidate C: `collection_empty()` — 0-arg, returns `Collection[Unknown]`

```ig
compute acc = collection_empty()
```

**REJECTED.** Equivalent to `[]` in Ruby TC. Gives `Collection[Unknown]`, which:
1. Fails OOF-TY1 at output boundary (P3/P4)
2. Makes append bootstrap produce `Collection[Unknown]` result
3. Provides no improvement over the existing `[]` literal

Mirrors `map_empty()` — which is now itself questionable as a pattern.

### Candidate D: `empty_like(collection)` — derive type from existing collection

```ig
compute acc = empty_like(items)  # items : Collection[Transaction] → Collection[Transaction]
```

**HOLD.** Useful for fold/accumulator bootstrap where the input collection's type is the
desired accumulator type. Covers:
```ig
compute totals = empty_like(transactions)
compute totals = append(totals, transform(t))
output totals : Collection[Summary]  # fails if Summary != Transaction
```

Does NOT cover: bootstrap where element type is declared only in output, not derivable from input.

Routes to `LANG-STDLIB-COLLECTION-EMPTY-LIKE-P1` when DSA/app pressure confirms need.

### Candidate E: Typed compute binding — `compute acc : Collection[T] = []`

```ig
compute acc : Collection[Transaction] = []
```

**PRIMARY ROUTE.** The TC uses the annotation to type `[]` at the binding site:
- Ruby: `infer_array_literal` receives annotation context → returns `Collection[Transaction]`
- Rust: extend `collection_output_hints` / `LAB-TC-ARRAY-P2` mechanism to `compute` declarations

Append bootstrap becomes correct:
```ig
compute acc : Collection[Transaction] = []
compute result = append(acc, transaction)  # append(Collection[Transaction], Transaction)
output result : Collection[Transaction]    # no OOF-TY1 — actual == expected
```

`append` preserves `Collection[Transaction]`. OOF-TY1 does not fire.

### Candidate F: Backward output-annotation propagation

Propagate `output result : Collection[Transaction]` backwards through the `compute` chain
to type `acc` without an explicit annotation.

**HOLD.** Requires full dataflow analysis — tracking which `compute` nodes feed into the
output and back-propagating type constraints. Complex, affects the entire inference engine.
Out of scope for this card. Revisit if typed compute binding proves insufficient.

---

## Decision

| Question | Answer |
|----------|--------|
| Does the language need a new `empty()` or `collection_empty()` function? | **No.** `[]` is already the surface. |
| Is `empty[T]()` a viable surface? | **No.** No generics syntax. Reject. |
| Is `empty_collection("TypeName")` viable? | **No.** Stringly typed. Reject. |
| What is the primary fix for append bootstrap? | Typed compute binding: `compute acc : Collection[T] = []` |
| Is `empty_like(collection)` useful? | Yes, for the fold case. HOLD for now. |
| Does `map_empty()` justify a symmetric `collection_empty()`? | **No.** Same Unknown-element anti-pattern, now worse post-P3/P4. |

---

## Primary Child Card

**`LANG-TYPED-COMPUTE-BINDING-P1`**

Scope:
- Parser: extend compute declaration to support optional `: TypeExpr`
  `compute name : TypeExpr = expr` alongside existing `compute name = expr`
- Ruby TC: when array literal is the RHS of an annotated compute binding,
  use annotation to resolve element type instead of defaulting to Unknown
- Rust TC: extend `collection_output_hints` / compute-phase hint mechanism
  to cover annotated `compute` declarations, not just `output` declarations
- Proof: typed `compute acc : Collection[T] = []` flows through `append` correctly,
  no OOF-TY1 at output

This is a parser + type inference card, not a stdlib card.

---

## Secondary Child Card (HOLD)

**`LANG-STDLIB-COLLECTION-EMPTY-LIKE-P1`**

`empty_like(collection) → Collection[T]` where T is derived from the argument's element type.
Activate when there is confirmed app-level demand for the fold/accumulator bootstrap pattern
where the accumulator type matches the input collection.

---

## What Stays Unchanged

- `[]` literal — unchanged in both TCs
- `append`, `is_empty`, `non_empty` — unchanged
- `map_empty()` — unchanged (pre-existing; not in scope to fix here)
- No implementation work in this card
