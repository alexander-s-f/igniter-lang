# LANG-STDLIB-COLLECTION-MAP-FILTER-P3: Ruby Canon Implementation Proof

**Track:** lang / stdlib / collection  
**Route:** BOUNDED RUBY IMPLEMENTATION / PROOF  
**Authority:** bounded Ruby `igniter-lang` TypeChecker canon only  
**Date:** 2026-06-12  
**Status:** CLOSED / PROVED — 61/61 PASS  
**Predecessors:** LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P2 (planning), LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1 (proposal), LAB-STDLIB-COLLECTION-P1 (64/64 PASS)

---

## 1. Authority Boundary

P3 implements the accepted `stdlib.collection.map`, `stdlib.collection.filter`, and
`stdlib.collection.count` helpers in the Ruby canon TypeChecker. It is implementation
authority only for the bounded internal Ruby compiler pipeline.

Closed in P3:

- no Rust implementation (P4 parity track)
- no VM or runtime changes
- no app fixture edits
- no fold dispatch (`when "fold"` not added)
- no sum dispatch
- no predicate-count (2-arg count form)
- no named function references beyond inline lambdas
- no lambda type-system expansion beyond minimal inline body binding
- no stdlib-inventory.json edits (deferred to P4+)
- no public or stable API widening

---

## 2. Implemented Surface

P3 adds `stdlib.collection.map`, `stdlib.collection.filter`, and `stdlib.collection.count`
dispatch through the Ruby TypeChecker via **three insertions** into `typechecker.rb` only.

### 2.1 COLLECTION_HOF_FNS Constant

Inserted after `OUTCOME_STDLIB_FNS.freeze`:

```ruby
COLLECTION_HOF_FNS = {
  "map"    => { qualified_name: "stdlib.collection.map",    arity: 2, has_lambda: true  },
  "filter" => { qualified_name: "stdlib.collection.filter", arity: 2, has_lambda: true  },
  "count"  => { qualified_name: "stdlib.collection.count",  arity: 1, has_lambda: false },
}.freeze
```

Each entry carries `qualified_name` (the canonical SemanticIR name), `arity`, and
`has_lambda` (false for count, true for map/filter).

### 2.2 Dispatch Arm in `infer_call`

Inserted after the `when *OUTCOME_STDLIB_FNS.keys` arm:

```ruby
when *COLLECTION_HOF_FNS.keys
  infer_collection_hof_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

### 2.3 Private Methods

**`infer_collection_hof_call`** — dispatches map/filter/count with full type checking:

1. OOF-COL1: arity check (args.length != expected_arity)
2. Infer collection argument; OOF-COL2: first arg must be Collection or Unknown
3. count (no lambda): return `type_ir("Integer")` immediately
4. map/filter: validate lambda node (kind == "lambda"), OOF-COL1 if non-lambda
5. Bind lambda params to element type via `element_type_from_collection`
6. Infer lambda body via `infer_lambda_body`
7. OOF-COL3 for filter: body type must be Bool or Unknown
8. Build output type: map → `collection_type_ir_from(body_type)`, filter → `collection_type_ir_from(elem_type)`

**`infer_lambda_body`** — handles two body shapes:

- Single-expression body: delegates directly to `infer_expr`
- Block body (`kind == "block"`): processes `let`/`expr_stmt` stmts in a duped scope,
  then infers `return_expr` (returns Unknown if absent)

---

## 3. Canonical Names and SIR

| Source alias | Qualified SemanticIR name |
|---|---|
| `map` | `stdlib.collection.map` |
| `filter` | `stdlib.collection.filter` |
| `count` | `stdlib.collection.count` |

**Zero emitter changes.** `typed_expr("call", ..., "fn" => qualified_name)` is passed
to `semantic_expr` in `semanticir_emitter.rb`, which preserves the `fn` field verbatim.
`semantic_ir_name == canonical_name` is satisfied automatically.

---

## 4. Type Signatures

| Helper | Input | Output |
|--------|-------|--------|
| `stdlib.collection.map` | `Collection[T] × (T→U)` | `Collection[U]` |
| `stdlib.collection.filter` | `Collection[T] × (T→Bool)` | `Collection[T]` |
| `stdlib.collection.count` | `Collection[T]` | `Integer` |

Element type `T` is extracted from the collection argument via the existing
`element_type_from_collection` method. Lambda param is bound to `T` in an augmented
`symbol_types` hash before body inference.

---

## 5. OOF Codes Active in P3

| Code | Trigger |
|------|---------|
| OOF-COL1 | `map`/`filter`/`count` arity mismatch; `map`/`filter` second arg not a lambda |
| OOF-COL2 | First argument is not a Collection or Unknown type |
| OOF-COL3 | `filter` predicate body returns a type that is neither Bool nor Unknown |

---

## 6. Pre-existing Gap: `==` Operator

`operator_type` in the Ruby TypeChecker has no `==` case. `==` emits OOF-TY0
"Unsupported operator: ==" and returns `type_ir("Unknown")`.

This is a **pre-existing gap, not P3 scope**. `Unknown` passes OOF-COL3 (permissive),
so filter calls using `==` predicates dispatch correctly — they just also emit OOF-TY0
from the operator itself. P3 fixtures use Bool field predicates to avoid triggering
the pre-existing OOF-TY0.

---

## 7. count T3 Coexistence

The T3 `count` path (decreases count(items)) goes through `handle_t3_variant` →
`NUMERIC_MEASURE_BUILTINS`. It never reaches `infer_call`. The new
`when *COLLECTION_HOF_FNS.keys` arm in `infer_call` is not reachable from the T3 path.
B-08 confirms: T3 count compiles clean with zero regression.

---

## 8. igapp Directory Architecture

The `.igapp` output is a **directory** (not a flat file). SemanticIR is at
`igapp/semantic_ir_program.json`. Critically, the igapp directory is only written
when `status == "ok"`. When `status == "oof"`, no igapp directory is created and
`r.dig("result", "igapp_path")` is `nil`. The proof runner reads SIR from
`File.join(igapp_path, "semantic_ir_program.json")` with a `File.exist?` guard.

OOF-producing negative checks use diagnostic code/message inspection rather than SIR
inspection, since no SIR is emitted on `status == "oof"`.

---

## 9. Proof Matrix (61 checks, 8 sections)

### A — Regression (7 checks)

| Check | What |
|-------|------|
| A-01 | `COLLECTION_HOF_FNS` constant defined |
| A-02 | Inserted after `OUTCOME_STDLIB_FNS` (order preserved) |
| A-03 | `infer_collection_hof_call` defined |
| A-04 | `infer_lambda_body` defined |
| A-05 | `string_core_proof` runner passes (TEXT_STDLIB_FNS unaffected) |
| A-06 | `stdlib_outcome_p3` runner passes (OUTCOME_STDLIB_FNS unaffected) |
| A-07 | `typed_contract_ref_p5` runner passes (cross-module resolution unaffected) |

### B — count dispatch (8 checks)

| Check | What |
|-------|------|
| B-01 | `count(items)` compiles clean |
| B-02 | `count` SIR fn == `'stdlib.collection.count'` |
| B-03 | `count()` 0 args → OOF-COL1 |
| B-04 | OOF-COL1 message mentions `stdlib.collection.count` |
| B-05 | `count(items, items)` 2 args → OOF-COL1 |
| B-06 | `count(n)` where `n:Integer` → OOF-COL2 |
| B-07 | OOF-COL2 message mentions `stdlib.collection.count` and `Collection[T]` |
| B-08 | T3 count (`decreases count(items)`) compiles clean (T3 path unaffected) |

### C — filter dispatch (9 checks)

| Check | What |
|-------|------|
| C-01 | `filter(postings, p -> p.active)` compiles clean (Bool field predicate) |
| C-02 | `filter` SIR fn == `'stdlib.collection.filter'` (qualified) |
| C-03 | Bare `'filter'` NOT in SIR fn values |
| C-04 | `filter(items)` 1 arg → OOF-COL1 |
| C-05 | `filter` non-Collection first arg → OOF-COL2 |
| C-06 | `filter` predicate returns Integer (non-Bool/non-Unknown) → OOF-COL3 |
| C-07 | OOF-COL3 message mentions `stdlib.collection.filter` and `Bool` |
| C-08 | `filter` lambda param bound to element type (Bool field access works) |
| C-09 | `filter + count` chain compiles clean |

### D — map dispatch (9 checks)

| Check | What |
|-------|------|
| D-01 | `map(postings, p -> p.amount)` compiles clean |
| D-02 | `map` SIR fn == `'stdlib.collection.map'` (qualified) |
| D-03 | Bare `'map'` NOT in SIR fn values |
| D-04 | `map(items)` 1 arg → OOF-COL1 |
| D-05 | OOF-COL1 message mentions `stdlib.collection.map` |
| D-06 | `map(n, x -> x)` where `n:Integer` → OOF-COL2 |
| D-07 | `map` lambda param bound to element type (field access works) |
| D-08 | `map(items, x -> x.value)` on `Collection[Item]` — SIR fn qualified |
| D-09 | `map` does not emit OOF-COL3 (only filter checks predicate Bool) |

### E — SIR qualified names (7 checks)

| Check | What |
|-------|------|
| E-01 | `map` SIR fn == `'stdlib.collection.map'` |
| E-02 | `filter` SIR fn == `'stdlib.collection.filter'` |
| E-03 | `count` SIR fn == `'stdlib.collection.count'` |
| E-04 | Bare `'map'` not emitted in SIR for map call |
| E-05 | Bare `'filter'` not emitted in SIR for filter call |
| E-06 | Bare `'count'` not emitted in SIR for count call |
| E-07 | TC source uses all three qualified names (semantic_ir_name == canonical_name) |

### F — Type inference correctness (8 checks)

| Check | What |
|-------|------|
| F-01 | `count` on `Collection[Decimal[2]]` — SIR fn present |
| F-02 | `count` on `Collection[Unknown]` — no OOF-COL2 (Unknown-compat) |
| F-03 | `filter` returns `Collection[T]` passthrough — SIR present, no COL3 on Bool |
| F-04 | `map` output wraps lambda body type — SIR present, no errors |
| F-05 | `map` on `Collection[Unknown]` — OOF-COL2 not emitted (collection shape accepted) |
| F-06 | `filter + map + count` chain — all three qualified fns in SIR |
| F-07 | `filter` with Bool field predicate — no OOF-COL3 |
| F-08 | OOF-COL1 is emitted for arity errors (not an OOF-TY0 unknown-function) |

### G — App fixture integration (6 checks)

| Check | What |
|-------|------|
| G-01 | `bookkeeping/ledger.ig` — `filter`/`map` no longer "Unknown function" |
| G-02 | `bookkeeping/ledger.ig` — filter dispatched (no OOF-COL1/COL2 for filter) |
| G-03 | `bookkeeping/ledger.ig` — map dispatched (no OOF-COL1/COL2 for map) |
| G-04 | `erp_logistics/optimizer.ig` — filter no longer "Unknown function" |
| G-05 | `erp_logistics/optimizer.ig` — filter dispatched (no OOF-COL1/COL2) |
| G-06 | Inline full-chain fixture (Bool predicate) — zero collection errors |

### H — Authority closed (7 checks)

| Check | What |
|-------|------|
| H-01 | `fold` → OOF-TY0 "Unknown function: fold" (not dispatched in P3) |
| H-02 | `sum` → OOF-TY0 "Unknown function: sum" (not dispatched in P3) |
| H-03 | `COLLECTION_HOF_FNS` does not include `'fold'` |
| H-04 | `COLLECTION_HOF_FNS` does not include `'sum'` |
| H-05 | `stdlib.collection.map` not in stdlib-inventory.json (proof-local in P3) |
| H-06 | `stdlib.collection.filter` not in stdlib-inventory.json (proof-local in P3) |
| H-07 | Predicate-count (2-arg count) → OOF-COL1 (not a new dispatch path) |

---

## 10. Regression Results

| Runner | Result |
|--------|--------|
| `string_core_proof` | PASS (unaffected) |
| `stdlib_outcome_p3` | 60/60 PASS (unaffected) |
| `typed_contract_ref_p5` | 71/71 PASS (unaffected) |

---

## 11. Files Changed

| File | Change |
|------|--------|
| `igniter-lang/lib/igniter_lang/typechecker.rb` | Three insertions (~100 lines): `COLLECTION_HOF_FNS` constant, dispatch arm, `infer_collection_hof_call` + `infer_lambda_body` private methods |
| `igniter-lang/experiments/stdlib_collection_proof/verify_stdlib_collection_map_filter_p3.rb` | New proof runner (61 checks, 8 sections) |

---

## 12. Next Route

**LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P4** — Rust parity / canonical SIR names
(Rust TC currently dispatches all three but emits bare names and has a lambda-param gap;
P4 closes both gaps and adds stdlib-inventory.json entries for map/filter/count).
