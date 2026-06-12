# LANG-STDLIB-COLLECTION-MAP-FILTER v0 — collection.map, collection.filter, collection.count

**Track:** stdlib / collection / map-filter-count  
**Status:** authored-pending-review  
**Date:** 2026-06-12  
**Route:** PROPOSAL AUTHORING ONLY / NO IMPLEMENTATION  
**Predecessor proof:** LAB-STDLIB-COLLECTION-P1 (64/64 PASS — SPLIT verdict)  
**Predecessor governance:** LANG-STDLIB-ENTRY-CONTRACT-P1/P2/P3, LAB-STDLIB-FOUNDATION-P1

---

## 1. Context and Evidence Base

`LAB-STDLIB-COLLECTION-P1` (64/64 PASS) mapped collection stdlib pressure across
bookkeeping, spreadsheet, and ERP logistics. All three apps use bare `map` and/or
`filter`. Bookkeeping uses all four HOF ops plus `count`. None produce type errors in
the Ruby canon pipeline — all produce `OOF-TY0: Unknown function: X`.

The proof returned a SPLIT verdict:

- **Group A (ready together):** `map`, `filter`, `count` regular-call parity
- **Group B (separate):** `fold` — 3-arg accumulator form
- **Group C (separate):** `sum` — scalar reduction, Option/nullable arithmetic intersection

This proposal authors the governance boundary for Group A only.

`LANG-STDLIB-ENTRY-CONTRACT-P1/P2` defines the schema every stdlib entry must satisfy,
including the critical invariant: `semantic_ir_name == canonical_name`.

`LAB-STDLIB-FOUNDATION-P1` confirmed `map`, `filter`, `fold`, and `sum` belong to the
Ch8 §8.4 collection kernel — canonical language-owned operations, not domain-local helpers.

---

## 2. Core Principle

**Collection HOF helpers are pure, element-wise transformations over finite ordered sequences.**

They do not:
- Execute queries or access storage
- Grant authority or consume capabilities
- Mutate their input
- Evaluate lazily or stream
- Guarantee any specific traversal order beyond what the source collection defines

A helper that transforms or counts a collection never commits, routes, retries, or signals.
The caller owns all downstream decisions. The helper only transforms or measures.

---

## 3. Scope of v0

**Accepted (this proposal):**

1. `stdlib.collection.map` — element-wise projection: `Collection[T] × (T → U) → Collection[U]`
2. `stdlib.collection.filter` — element-wise predicate selection: `Collection[T] × (T → Bool) → Collection[T]`
3. `stdlib.collection.count` — cardinality measure: `Collection[T] → Integer`

**Explicitly excluded from v0:**

- `stdlib.collection.fold` — deferred to `LAB-STDLIB-FOLD-P1` (3-arg form, accumulator semantics)
- `stdlib.collection.sum` — deferred to `LAB-STDLIB-SUM-P1` (scalar reduction, Option/nullable arithmetic)
- `count(collection, predicate)` — deferred; predicate-count is `filter` then `count` at source level
- `reduce` — not a distinct operation; fold covers it
- `groupBy`, sorting, streaming — out of scope
- Mutable collections — out of scope
- SQL/query execution semantics — out of scope
- App-specific helpers — out of scope

---

## 4. Input Collection Type

All three operations accept `Collection[T]` as their first argument. `T` is a type
parameter that is resolved from the input at the call site.

### Collection[T] resolution (inline lambda binding)

For `map` and `filter`, the lambda parameter is bound to `T`, the element type extracted
from `Collection[T]`. This does not require a general `Fn[T,U]` type.

The inline lambda evaluation pattern (confirmed in LAB-STDLIB-COLLECTION-P1):

1. Extract element type `T` from `Collection[T]` using `element_type_from_collection`
2. Bind lambda parameter(s) to type `T` in local symbol scope
3. Infer lambda body return type `U` in that local scope
4. Use `U` as the output element type

`element_type_from_collection(collection_type)` already exists in the Ruby TC at
`typechecker.rb` line ~1825. No new type-system primitive is required.

For `count`, no lambda is involved — the type parameter `T` is not needed at all.

### Unknown / permissive behavior

When the first argument type is `Unknown`, the helper should accept it (permissive) and
return the appropriate output type with `Unknown` element type where applicable. This
matches the TEXT/MAP/OUTCOME pattern.

---

## 5. Callable Argument Shape

All lambda arguments in v0 are **inline lambdas at the call site**. Named function
references are not required and are not supported in v0.

**Inline lambda shapes:**

| Helper | Lambda shape | Example |
|--------|-------------|---------|
| `map` | `x -> expr` or `x -> body_block` | `map(postings, p -> p.amount)` |
| `filter` | `x -> bool_expr` | `filter(postings, p -> p.direction == "Debit")` |
| `count` | _(no lambda)_ | `count(items)` |

The lambda parameter `x` is bound to element type `T` at inference time. No general
`Fn[T,U]` type is needed and none is introduced.

---

## 6. count Semantics Decision

`stdlib.collection.count` is defined as **count-all-elements only**:

```
count(Collection[T]) → Integer
```

The **predicate form** `count(collection, predicate)` is **deferred**. Rationale:

- Predicate-count can always be expressed as `count(filter(col, pred))` at source level
- Introducing a 2-argument form before `filter` is independently stable adds complexity
- The element type binding for count-predicate is the same pattern as `filter`; it should
  be added as an amendment after `filter` is proven
- The predicate-count deferred form is NOT a separate named entry — it would be an arity
  variant of `stdlib.collection.count` if adopted. Until then, it is out of scope.

### count and the Ruby T3 dispatch gap

`stdlib.collection.count` already appears in `stdlib-inventory.json` as
`production-implemented, dual-toolchain`. However, as established in LAB-STDLIB-COLLECTION-P1,
the Ruby TC dispatches `count` **only** from `handle_t3_variant` — i.e., in the
`decreases count(items)` header form (PROP-042 T3 decreases evidence). A regular compute
call `compute n = count(items)` in a contract body produces `OOF-TY0 Unknown function: count`
in Ruby.

This proposal clarifies the **regular-call** semantics of `count` and authorizes adding
a `when "count"` arm to `infer_call` in the Ruby TC in P2, following the same pattern
as `map` and `filter` dispatch. The T3 dispatch path is unaffected.

The existing inventory entry for `stdlib.collection.count` requires a
`proof_lineage` amendment and a `compatibility_note` update to reflect the regular-call
dispatch gap. These inventory changes are part of P2 scope, not this proposal.

---

## 7. Accepted Entries

### 7.1 stdlib.collection.map

**Canonical name:** `stdlib.collection.map`  
**Source aliases accepted:** `map` (bare, unqualified)  
**Type parameters:** `T`, `U`  
**Signature:** `Collection[T] × (T → U) → Collection[U]`  
**Fragment class:** core  
**Purity:** pure  
**Authority surface:** none  
**Deterministic:** true  
**Totality:** total (empty input → empty output)  
**Semantics:** Returns a new collection where each element is the result of applying
the lambda to the corresponding element of the input. Element order preserved.
Output collection length equals input collection length.

**Application fixture evidence:**
- `bookkeeping/ledger.ig`: `compute debit_amounts = map(debits, p -> p.amount)` —
  maps `Collection[Posting]` to `Collection[Decimal]` (or whatever `p.amount` type is)
- `spreadsheet/engine.ig`: `map(grid.cells, cell -> eval_expr(cell.ast, grid))` —
  maps `Collection[Cell]` to `Collection[ExprValue]`

### 7.2 stdlib.collection.filter

**Canonical name:** `stdlib.collection.filter`  
**Source aliases accepted:** `filter` (bare, unqualified)  
**Type parameters:** `T`  
**Signature:** `Collection[T] × (T → Bool) → Collection[T]`  
**Fragment class:** core  
**Purity:** pure  
**Authority surface:** none  
**Deterministic:** true  
**Totality:** total (empty input → empty output; no-match → empty output)  
**Semantics:** Returns a new collection containing only elements for which the predicate
returns true. Element order preserved (relative order of matching elements is stable).
Output collection length is ≤ input collection length.

**Application fixture evidence:**
- `bookkeeping/ledger.ig`: `compute debits = filter(tx.postings, p -> p.direction == "Debit")`
- `erp_logistics/optimizer.ig`: `compute matching_routes = filter(routes, r -> ...)`

### 7.3 stdlib.collection.count

**Canonical name:** `stdlib.collection.count`  
**Source aliases accepted:** `count` (bare, unqualified)  
**Type parameters:** `T`  
**Signature:** `Collection[T] → Integer`  
**Fragment class:** core  
**Purity:** pure  
**Authority surface:** none  
**Deterministic:** true  
**Totality:** total (empty input → 0)  
**Semantics:** Returns the number of elements in the collection. No predicate form in v0.

**Note on T3 coexistence:** `count` already serves as a T3 numeric measure expression
(PROP-042, `decreases count(items)` form). This proposal governs the regular compute-call
form. Both forms share the same canonical name and entry contract. The T3 dispatch path
in `handle_t3_variant` is unaffected. The P2 implementation adds a `when "count"` arm
in `infer_call` that handles `count(collection)` as a regular compute expression.

---

## 8. Entry Contracts

### 8.1 stdlib.collection.map

```json
{
  "canonical_name": "stdlib.collection.map",
  "semantic_ir_name": "stdlib.collection.map",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "map" }],
  "category": "collection",
  "lifecycle_status": "proof-local",
  "semantic_stability": "experiment-pass",
  "lowering_status": "single-toolchain-partial",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total: empty input → empty output",
  "type_params": ["T", "U"],
  "input_signature": ["Collection[T]", "(T -> U)"],
  "output_signature": "Collection[U]",
  "diagnostics": ["OOF-COL1", "OOF-COL2"],
  "failure_behavior": "none; both arguments required; arity mismatch → OOF-COL1; non-Collection first arg → OOF-COL2",
  "authority_surface": "none",
  "proof_lineage": [
    "Ch8 §8.4 collection kernel",
    "LAB-STDLIB-COLLECTION-P1 (64/64 PASS)",
    "bookkeeping filter×2/map×2/sum×2/fold fixture",
    "spreadsheet CalculateGrid map fixture",
    "Rust lab typechecker dispatch (lambda param gap noted)"
  ],
  "examples": [
    "map([1, 2, 3], x -> x * 2) -> [2, 4, 6]",
    "map(postings, p -> p.amount) -> Collection[Decimal]"
  ],
  "compatibility_note": "Bare source alias 'map' accepted. Inline lambda only; no named-fn reference form in v0. Rust TC currently uses Integer placeholder for lambda params — parity fix in Rust implementation pass.",
  "owner_surface": "Ch8 §8.4",
  "entry_digest": null
}
```

**Critical invariant check:** `semantic_ir_name == canonical_name` → `"stdlib.collection.map" == "stdlib.collection.map"` ✓  
**No legacy_sir:** Ruby TC currently emits OOF-TY0 (not a SIR name). No prior stable bare-name SIR emission from canon Ruby pipeline.

### 8.2 stdlib.collection.filter

```json
{
  "canonical_name": "stdlib.collection.filter",
  "semantic_ir_name": "stdlib.collection.filter",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "filter" }],
  "category": "collection",
  "lifecycle_status": "proof-local",
  "semantic_stability": "experiment-pass",
  "lowering_status": "single-toolchain-partial",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total: empty input → empty output; no match → empty output",
  "type_params": ["T"],
  "input_signature": ["Collection[T]", "(T -> Bool)"],
  "output_signature": "Collection[T]",
  "diagnostics": ["OOF-COL1", "OOF-COL2"],
  "failure_behavior": "none; both arguments required; arity mismatch → OOF-COL1; non-Collection first arg → OOF-COL2",
  "authority_surface": "none",
  "proof_lineage": [
    "Ch8 §8.4 collection kernel",
    "LAB-STDLIB-COLLECTION-P1 (64/64 PASS)",
    "bookkeeping PostTransaction filter fixture",
    "erp_logistics DispatchShipment filter fixture",
    "Rust lab typechecker 'filter' | 'take' => typed_args[0].resolved_type dispatch"
  ],
  "examples": [
    "filter([1, 2, 3, 4], x -> x > 2) -> [3, 4]",
    "filter(postings, p -> p.direction == \"Debit\") -> Collection[Posting]"
  ],
  "compatibility_note": "Bare source alias 'filter' accepted. Inline lambda only; no named-fn reference form in v0. Return type is same Collection[T] as first argument — passthrough element type.",
  "owner_surface": "Ch8 §8.4",
  "entry_digest": null
}
```

**Critical invariant check:** `semantic_ir_name == canonical_name` → `"stdlib.collection.filter" == "stdlib.collection.filter"` ✓  
**No legacy_sir:** Ruby TC currently emits OOF-TY0. No prior stable SIR name from canon Ruby pipeline.

### 8.3 stdlib.collection.count (amended entry)

The existing inventory entry for `stdlib.collection.count` is amended to reflect
this proposal's clarification of the regular-call semantics and the T3-only gap:

```json
{
  "canonical_name": "stdlib.collection.count",
  "semantic_ir_name": "stdlib.collection.count",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "count" }],
  "category": "collection",
  "lifecycle_status": "production-implemented",
  "semantic_stability": "experiment-pass",
  "lowering_status": "dual-toolchain",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total: empty input → 0",
  "type_params": ["T"],
  "input_signature": ["Collection[T]"],
  "output_signature": "Integer",
  "diagnostics": ["OOF-COL1", "OOF-COL2"],
  "failure_behavior": "none; arity mismatch → OOF-COL1; non-Collection arg → OOF-COL2",
  "authority_surface": "none",
  "proof_lineage": [
    "Ch8 §8.4 collection kernel",
    "NUMERIC_MEASURE_BUILTINS ruby dispatch (T3 decreases form only — PROP-042)",
    "T3 decreases form (PROP-042)",
    "Rust VM stdlib.collection.count (regular-call dispatch)",
    "LAB-STDLIB-COLLECTION-P1 I-05: Ruby regular-call OOF-TY0 gap documented",
    "LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1 clarification"
  ],
  "examples": ["count([1, 2, 3]) -> 3", "count(postings) -> 5"],
  "compatibility_note": "Ruby TC dispatches count only in T3 decreases context (NUMERIC_MEASURE_BUILTINS in handle_t3_variant). Regular compute call count(items) currently produces OOF-TY0 in Ruby. This proposal authorizes adding regular-call dispatch to infer_call in P2. Dual-toolchain status reflects Rust regular-call support; Ruby regular-call parity is P2 scope. inventory entry updated by LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1.",
  "owner_surface": "PROP-042 §T3 + Ch8 §8.4",
  "entry_digest": null
}
```

**Note:** `lowering_status` remains `"dual-toolchain"` because Rust accepts `count(col)` as
a regular call. Ruby T3 dispatch is intact. The gap is specifically Ruby **infer_call** path
for regular compute statements — a bounded addition, not a new lowering.

---

## 9. Toolchain Status

### Ruby TypeChecker (canon — `igniter-lang/lib/igniter_lang/typechecker.rb`)

| Operation | Current State | P2 Action |
|-----------|--------------|-----------|
| `map` | OOF-TY0 Unknown function | Add `COLLECTION_HOF_FNS` constant + `when *COLLECTION_HOF_FNS.keys` dispatch arm + `infer_collection_hof_call` private method |
| `filter` | OOF-TY0 Unknown function | Same dispatch arm; same private method |
| `count` (regular call) | OOF-TY0 Unknown function | Add `when "count"` arm OR fold into COLLECTION_HOF_FNS dispatch |

**Readiness precondition confirmed:** `element_type_from_collection(collection_type)` exists
at `typechecker.rb` line ~1825. No new type-system primitive required.

**Inline lambda evaluation pattern (P2 implementation):**
```ruby
def infer_collection_hof_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  # 1. Infer collection argument → get element type T
  collection_arg = infer_expr(args[0], ...)
  elem_type = element_type_from_collection(collection_arg.fetch("resolved_type"))

  # 2. For map/filter: infer lambda with T bound to lambda param
  if fn == "map" || fn == "filter"
    lambda_arg = args[1]  # Lambda AST node
    local_symbols = symbol_types.merge(lambda_arg["params"][0] => elem_type)
    lambda_body_type = infer_expr(lambda_arg["body"], local_symbols, ...)
    # ...
  end

  # 3. Build return type per operation
  # map  → Collection[lambda_body_type]
  # filter → Collection[elem_type]  (passthrough)
  # count  → Integer
end
```

**SIR fn emission:** Ruby TC will emit `"fn" => "stdlib.collection.#{fn}"` (qualified name)
following the `TEXT_STDLIB_FNS` / `MAP_STDLIB_FNS` / `OUTCOME_STDLIB_FNS` pattern.
`semantic_ir_name == canonical_name` is satisfied automatically.

### Rust TypeChecker (lab — `igniter-lab/igniter-compiler/src/typechecker.rs`)

| Operation | Current Dispatch | Gap |
|-----------|-----------------|-----|
| `count` | line 2644: returns Integer | SIR emits bare `count` (not qualified name) |
| `filter` / `take` | line 2742: returns `typed_args[0].resolved_type` | SIR emits bare `filter`; lambda param binding not needed (passthrough type) |
| `map` | line 2750: lambda body inferred with Integer placeholder for params | Lambda params typed as `Integer` instead of element type `T`; SIR emits bare `map` |

**Rust implementation gaps (P2+ scope):**

1. **map lambda param typing**: Replace `Integer` placeholder (line 2764) with
   `element_type_from_collection`-equivalent: extract `Collection.params[0]` from
   `typed_args[0].resolved_type` and use that as the lambda param type.
2. **SIR qualified name emission**: All three ops currently emit the bare source name in
   the SIR `fn` field. Rust TC should emit `stdlib.collection.{map,filter,count}` to
   match the `semantic_ir_name`. This is the Rust SIR parity gap.

Neither gap is a blocker for the Ruby TC implementation. Ruby TC is the canon pipeline.

---

## 10. Questions Answered

### Q1. What are the canonical names?

`stdlib.collection.map`, `stdlib.collection.filter`, `stdlib.collection.count`.
All follow the `stdlib.<category>.<fn>` schema from LANG-STDLIB-ENTRY-CONTRACT-P1.

### Q2. What source aliases are allowed, if any?

Each entry has exactly one source alias: the bare unqualified name (`map`, `filter`, `count`).
No method-call aliases (`col.map(...)`) — Igniter does not support method syntax.
No category-prefixed aliases (`collection_map`) — these would be confusion without benefit.

The alias list is append-only per entry contract schema. No aliases are rejected at this time.

### Q3. Are bare `map`, `filter`, `count` accepted as source aliases?

**Yes.** All three apps use bare names and no app uses qualified names. Bare names are the
actual source surface. Not accepting bare names would break every existing app fixture.

The entry contract schema distinguishes `source_alias` (what source code may write) from
`canonical_name` (what the SIR and inventory use). Bare source names are the correct alias
kind here. This follows the exact same pattern as `byte_length` → `stdlib.text.byte_length`,
`map_get` → `stdlib.map.get`, `or_else` → `stdlib.option.or_else`.

### Q4. What is the required input collection type?

`Collection[T]` — parameterized generic with element type `T`. The type parameter `T` is
resolved from the actual argument type at the call site. Unknown inputs are accepted
(permissive fallback), as with all existing stdlib helpers.

### Q5. What is the callable/function argument shape?

Inline lambda at the call site. `(param -> expr)` or `(param -> block)`. The parameter is
bound to element type `T` at inference time. No named function references.
No general `Fn[T,U]` type is introduced. This is a constraint, not a deficiency — all
current app fixtures use inline lambdas, and the inline evaluation pattern is sufficient.

### Q6. What are the result types?

| Helper | Result type |
|--------|------------|
| `map(Collection[T], T → U)` | `Collection[U]` |
| `filter(Collection[T], T → Bool)` | `Collection[T]` |
| `count(Collection[T])` | `Integer` |

### Q7. Does `count` mean count-all, count-matching-predicate, or both?

**Count-all-elements only** in v0. `count(collection)` → `Integer`.

`count(collection, predicate)` is deferred. It is expressible as `count(filter(col, pred))`
at source level. When predicate-count is adopted, it should be an arity variant of
`stdlib.collection.count`, not a new entry name.

### Q8. How does this relate to current Rust behavior?

Rust TC (`igniter-lab/igniter-compiler/src/typechecker.rs`) already dispatches all three:
- `count` at line 2644 → Integer (correct return type)
- `filter | take` at line 2742 → `typed_args[0].resolved_type` (correct passthrough)
- `map` at line 2750 → `Collection[lambda_body_type]` (correct output container, but lambda
  params typed as Integer placeholder at line 2764 instead of element type T)

Two gaps: (1) map element-type binding incorrect; (2) all three emit bare SIR fn names
(not qualified `stdlib.collection.*` names). Both gaps are Rust parity scope, not blockers
for Ruby TC implementation.

### Q9. How does this relate to current Ruby gaps?

Ruby TC has zero dispatch for `map` and `filter` — both fall through to `infer_call else`
(OOF-TY0). `count` is dispatched only via `NUMERIC_MEASURE_BUILTINS` in `handle_t3_variant`,
which is only entered from the PROP-042 T3 decreases evidence path, not from regular
`infer_call`. A regular `compute n = count(items)` also produces OOF-TY0 in Ruby.

P2 scope: add `COLLECTION_HOF_FNS` constant and `infer_collection_hof_call` to `typechecker.rb`,
following the `OUTCOME_STDLIB_FNS` / `infer_outcome_call` insertion pattern.

### Q10. How do these entries appear in `stdlib-inventory.json`?

Three entries in the `collection` category. `stdlib.collection.map` and
`stdlib.collection.filter` are new. `stdlib.collection.count` is an amendment to the
existing entry (proof_lineage and compatibility_note updated).

All three share:
- `lifecycle_status`: map/filter = `"proof-local"` (not yet implemented in canon Ruby);
  count = `"production-implemented"` (T3 dispatch exists)
- `semantic_stability`: `"experiment-pass"` (grounded by LAB-STDLIB-COLLECTION-P1)
- `fragment_class`: `"core"`
- `purity`: `"pure"`
- `authority_surface`: `"none"`
- `semantic_ir_name == canonical_name` (no legacy_sir)

Actual inventory file edits are P2 scope (after Ruby TC implementation proof).

### Q11. Are these helpers pure CORE only?

**Yes.** All three:
- Take no capability parameters
- Emit no effects
- Access no storage
- Have `authority_surface: "none"` and `fragment_class: "core"`
- Are deterministic and total

No ESCAPE tier involvement. No profile binding required.

### Q12. What OOF namespace/errors are reserved?

**OOF-COL namespace reserved** for collection HOF diagnostics.

| Code | Candidate trigger | Active? |
|------|------------------|---------|
| `OOF-COL1` | Arity mismatch (wrong number of arguments) | P2 |
| `OOF-COL2` | Non-Collection first argument to map/filter/count | P2 |
| `OOF-COL3` | Lambda predicate returns non-Bool (filter) | P2 |
| `OOF-COL4` | Reserved for fold/accumulator errors (deferred) | Deferred |
| `OOF-COL5` | Reserved for sum numeric constraint errors (deferred) | Deferred |

`OOF-TY0` continues to handle unknown function for unregistered calls. `OOF-COL*` codes
are the specialized diagnostics for collection HOF calls where the function is recognized
but the arguments are wrong.

Note: `OOF-COL3` (predicate non-Bool) is a candidate for P2 but may be omitted if the
implementation accepts Unknown-type lambda bodies permissively (consistent with the
`Unknown`-permissive pattern in TEXT/MAP/OUTCOME). Decision deferred to P2 planning.

### Q13. What remains deferred to fold/sum tracks?

| Item | Deferred to |
|------|------------|
| `stdlib.collection.fold` | `LAB-STDLIB-FOLD-P1` |
| `stdlib.collection.sum` | `LAB-STDLIB-SUM-P1` |
| `count(collection, predicate)` | Amendment to this track after filter is stable |
| Rust lambda param element-type fix | Rust parity pass (P2+ scope) |
| Rust SIR qualified name emission | Rust parity pass (P2+ scope) |
| `stdlib-inventory.json` edits | P2 implementation planning scope |
| Predicate-count `OOF-COL3` finalization | P2 planning decision |

---

## 11. Design Decisions Locked

1. **Bare source aliases accepted** — `map`, `filter`, `count` are the source surface;
   no qualified-only policy
2. **Inline lambda only** — no named-function-reference form in v0; no `Fn[T,U]` type
3. **count-all-elements only** — predicate form deferred; expressible via `filter` + `count`
4. **element_type_from_collection primitive reuse** — no new primitive needed; existing
   Ruby TC method at ~line 1825 is the correct building block
5. **No OOF-COL3 decision yet** — OOF-COL1/COL2 are definite; COL3 is a P2 planning call
6. **semantic_ir_name == canonical_name** — no legacy_sir for any of the three entries
7. **count amendment, not new entry** — existing inventory entry is amended, not replaced;
   `lifecycle_status` remains `"production-implemented"` (T3 dispatch still counts)
8. **OOF-COL namespace reserved** — OOF-COL1..COL5 candidate codes defined; COL1/COL2
   are active; COL3..COL5 are deferred or reserved
9. **COLLECTION_HOF_FNS insertion point** — following `OUTCOME_STDLIB_FNS` pattern in
   `infer_call`; exact line TBD in P2 planning
10. **filter passthrough type** — `filter` return type is always the same `Collection[T]`
    as the input; the lambda body type is not used in the output type (only for Bool validation)

---

## 12. Authority Closed

- No Ruby TypeChecker implementation (P2 scope)
- No Rust TypeChecker changes
- No VM/runtime changes
- No `stdlib-inventory.json` file edits (P2 scope)
- No `fold` or `sum` entry contracts
- No lambda/function type-system additions
- No query/storage semantics
- No public compatibility promise beyond this proposal
- No app fixture changes

---

## 13. Next Routes

**Primary:**
`LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P2`  
Implementation planning for Ruby TC `infer_collection_hof_call` dispatch.
Authorized files: `typechecker.rb` + proof runner.
Proof matrix: ≥50 checks — A regression / B dispatch-map / C dispatch-filter /
D dispatch-count-regular / E type inference / F SIR naming / G diagnostics / H authority.

**Parallel tracks:**
- `LAB-STDLIB-FOLD-P1` — fold readiness proof and entry contract
- `LAB-STDLIB-SUM-P1` — sum readiness proof (after Option/nullable arithmetic clarity)

**Rust parity (separate, after Ruby TC stable):**
- Fix map lambda param typing (Integer → element type T)
- Fix SIR qualified name emission for all collection HOF ops
