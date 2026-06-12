# LANG-STDLIB-COLLECTION-MAP-FILTER P2 — Implementation Planning

**Track:** lang / stdlib / collection  
**Status:** implementation-planning-only — READY FOR P3  
**Date:** 2026-06-12  
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE  
**Predecessor:** LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1 (authored)  
**Proof base:** LAB-STDLIB-COLLECTION-P1 (64/64 PASS)

---

## Planning Decision: READY FOR P3

All three helpers — `map`, `filter`, `count` — are implementable in a single P3 slice.
No SPLIT required. No callable-typing prerequisite. All app fixtures use single-expression
inline lambdas; the mechanism is verified end-to-end.

**Rationale against SPLIT:**

- `count` has no lambda — it is the simplest of the three
- `filter` uses lambda binding but only needs the passthrough element type — no output
  type inference from the lambda body is required
- `map` requires lambda body type inference, but the mechanism is already proven:
  `element_type_from_collection` (line ~1825) extracts `T`; augmenting `symbol_types`
  with `param → T` and calling `infer_expr(body, ...)` is the same pattern the TC uses
  for every other expression
- All app fixture lambdas (`p -> p.amount`, `p -> p.direction == "Debit"`, etc.) are
  single-expression bodies — no block lambda traversal needed for the regression fixtures
- The Rust TC already implements all three correctly (modulo the Integer placeholder gap),
  demonstrating the pattern is sound

---

## 1. Authorized File

**One file only:** `igniter-lang/lib/igniter_lang/typechecker.rb`

No parser changes. No classifier changes. No SemanticIR emitter changes. No assembler
changes. No VM changes. No `stdlib-inventory.json` edits in P3.

The generic `semantic_expr` in `semanticir_emitter.rb` preserves the `fn` field verbatim
(confirmed from LANG-STDLIB-OUTCOME-P3 §E evidence). Since the new dispatch sets
`"fn" => "stdlib.collection.#{fn}"`, `semantic_ir_name == canonical_name` is satisfied
automatically — zero emitter changes needed.

---

## 2. 13 Questions Answered

### Q1. Exact TypeChecker insertion points?

Three insertions to `typechecker.rb`, in order:

**Insertion 1** — after `OUTCOME_STDLIB_FNS` constant (~line 84):
```ruby
# LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1: stdlib.collection HOF registry (v0 — exhaustive).
# Source aliases → qualified SemanticIR names. all pure/core/authority_surface:none.
# map/filter: 2-arg (collection, lambda). count: 1-arg (collection). No predicate-count in v0.
# SemanticIR fn is always the qualified_name. Source alias never appears in SIR.
# Adding entries requires PROP amendment + P4+ authorization.
COLLECTION_HOF_FNS = {
  "map"    => { qualified_name: "stdlib.collection.map",    arity: 2, has_lambda: true  },
  "filter" => { qualified_name: "stdlib.collection.filter", arity: 2, has_lambda: true  },
  "count"  => { qualified_name: "stdlib.collection.count",  arity: 1, has_lambda: false },
}.freeze
```

**Insertion 2** — in `infer_call`, after the `when *OUTCOME_STDLIB_FNS.keys` arm (~line 879):
```ruby
when *COLLECTION_HOF_FNS.keys
  # LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1: Collection HOF — map/filter/count
  infer_collection_hof_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

**Insertion 3** — new private method `infer_collection_hof_call`, added after `infer_outcome_call`
(~line 2270). Full method body specified in §5.

### Q2. Shape of `COLLECTION_HOF_FNS` map?

```ruby
COLLECTION_HOF_FNS = {
  "map"    => { qualified_name: "stdlib.collection.map",    arity: 2, has_lambda: true  },
  "filter" => { qualified_name: "stdlib.collection.filter", arity: 2, has_lambda: true  },
  "count"  => { qualified_name: "stdlib.collection.count",  arity: 1, has_lambda: false },
}.freeze
```

Each entry: `qualified_name` (SIR emission name), `arity` (expected arg count),
`has_lambda` (whether second arg is a lambda). This is richer than `OUTCOME_STDLIB_FNS`
because collection HOF ops have different arity and structural shapes.

### Q3. How to infer `count(collection)`?

`count` is the simplest case — no lambda, one collection argument:

1. Check `args.length == 1`; emit `OOF-COL1` on mismatch
2. Infer `args[0]` via `infer_expr` → get `collection_arg` with resolved_type
3. Validate `type_name(collection_arg["resolved_type"]) == "Collection" || "Unknown"`; emit `OOF-COL2` on non-Collection, non-Unknown
4. Return `typed_expr("call", type_ir("Integer"), deps, "fn" => "stdlib.collection.count", "args" => [collection_arg])`

No element type extraction needed. No lambda.

### Q4. How to infer `filter(collection, lambda)`?

`filter` passthrough: output element type is the **same** as input element type:

1. Check `args.length == 2`; emit `OOF-COL1` on mismatch
2. Infer `args[0]` → `collection_arg`; validate Collection/Unknown; emit `OOF-COL2` on non-Collection
3. Extract `elem_type = element_type_from_collection(collection_arg["resolved_type"])`
4. Check `args[1]["kind"] == "lambda"`; emit `OOF-COL1` if not a lambda
5. Extract lambda params and body; bind `params[0]` to `elem_type` in local symbols
6. Infer lambda body to get `pred_type`; optionally validate `pred_type` is Bool/Unknown
7. Build output type: `collection_type_ir_from(elem_type)` — same element type as input
8. Return `typed_expr("call", output_type, deps, "fn" => "stdlib.collection.filter", "args" => ...)`

The output type (`Collection[T]`) does NOT depend on the lambda body type — it is the input
`Collection[T]` type. The lambda is inferred only for its Bool predicate (and side-effect of
emitting OOF-P1 if field accesses are wrong). This simplifies `filter` relative to `map`.

### Q5. How to infer `map(collection, lambda)`?

`map` projection: output element type is the **lambda body return type**:

1. Check `args.length == 2`; emit `OOF-COL1` on mismatch
2. Infer `args[0]` → `collection_arg`; validate Collection/Unknown; emit `OOF-COL2` on non-Collection
3. Extract `elem_type = element_type_from_collection(collection_arg["resolved_type"])`
4. Check `args[1]["kind"] == "lambda"`; emit `OOF-COL1` if not a lambda
5. Extract lambda params and body; bind `params[0]` to `elem_type` in local symbols
6. Infer lambda body to get `lambda_body_typed`; extract `result_elem_type = lambda_body_typed["resolved_type"]`
7. Build output type: `collection_type_ir_from(result_elem_type)` — Collection of the lambda output type
8. Return `typed_expr("call", output_type, deps, "fn" => "stdlib.collection.map", "args" => ...)`

The output type `U` is the return type of the lambda body expression. For
`map(postings, p -> p.amount)`, `p` is typed as the element type of the postings
collection, and `p.amount` gets the field type from `@type_shapes["Posting"]["amount"]`.

### Q6. How to bind inline lambda parameter type from `Collection[T]`?

```ruby
# Already exists in TypeChecker — exact tool needed:
elem_type = element_type_from_collection(collection_arg.fetch("resolved_type"))
# Returns type_ir("Unknown") for non-Collection or unparameterised Collection

# Bind lambda param to elem_type in local scope:
lambda_node = args[1]
params = lambda_node.fetch("params", [])
local_symbols = symbol_types.merge(params[0] => elem_type)  # single-param lambda

# Infer lambda body with augmented scope:
body = lambda_node.fetch("body")
body_typed = infer_lambda_body(body, local_symbols, type_errors, type_warnings, node_name)
```

`symbol_types.merge(...)` creates a new hash (does not mutate the outer scope).
The lambda parameter binding is strictly local to this call.

Multi-param lambdas: not expected in v0. In v0, all app fixtures use exactly one param.
If the lambda has no params (`[]`), `params[0]` is nil → `local_symbols.merge(nil => elem_type)`
which is a no-op in Ruby hash merge (nil key). This is harmless for the type inference —
the body is still inferred, just without a bound param name.

### Q7. What lambda shapes are accepted in v0?

**Accepted:**
- Single-expression body: `p -> p.amount` → `{ "kind" => "lambda", "params" => ["p"], "body" => expr }`
- Block body with `return_expr`: `p -> { result }` → `{ "kind" => "lambda", "params" => ["p"], "body" => { "kind" => "block", "stmts" => [], "return_expr" => expr } }`
- Single-param lambda (all app fixtures)
- Multi-param lambda: params beyond the first are ignored (no element type binding for params[1+]); this is correct for v0 since no app fixture uses multi-param collection lambdas

**Note on block bodies:** `parse_lambda_block` produces `{ "kind" => "block", "stmts" => stmts, "return_expr" => expr }`. The helper method `infer_lambda_body` handles this by:
1. Iterating stmts (for `let` bindings, extending local_symbols; for `expr_stmt`, inferring and discarding)
2. Returning the type of `return_expr` if present, else `type_ir("Unknown")`

All current app fixtures use single-expression lambda bodies (no blocks), so this is
belt-and-suspenders for v0 correctness.

### Q8. What lambda shapes are rejected/deferred?

**Rejected / OOF-COL1:**
- Wrong arity (0 or 3+ args for map/filter; 0 or 2+ args for count)
- Non-lambda second arg for map/filter (e.g., a symbol ref to a named function)

**Named function references** — not accepted. The Igniter source surface has no mechanism
to pass a named function as a value in v0. The source `map(col, some_fn)` would parse
`some_fn` as a ref (kind: "ref"), not a lambda, and `infer_collection_hof_call` will
treat a non-lambda second arg as an arity/shape error (OOF-COL1).

**No first-class Fn type** — confirmed closed. This is not a gap; it is a design decision.

### Q9. How to emit canonical SIR names with generic call lowering?

The generic `semantic_expr` in `semanticir_emitter.rb` (lines 338–368) preserves the
`fn` field from the typed expression hash verbatim. Ruby TC sets `"fn" => qualified_name`
in the `typed_expr(...)` call. No emitter changes are needed.

Pattern established by TEXT/MAP/OUTCOME — `infer_outcome_call` line 2256:
```ruby
typed_expr("call", type_ir("Unknown"), [], "fn" => qualified_name, "args" => [])
```

The new `infer_collection_hof_call` follows the same pattern:
```ruby
typed_expr("call", output_type, deps, "fn" => spec[:qualified_name], "args" => typed_args)
```

`semantic_ir_name == canonical_name` is satisfied automatically. Zero emitter changes.

### Q10. Exact OOF-COL1/COL2 triggers?

**OOF-COL1 — arity/shape mismatch:**
- `map` or `filter` called with != 2 arguments
- `count` called with != 1 argument
- `map` or `filter` second argument is not a lambda node (`kind != "lambda"`)

**OOF-COL2 — non-Collection first argument:**
- First argument resolves to a type other than `Collection` or `Unknown`
- Examples: `map("hello", x -> x)` → OOF-COL2 (first arg is Text)
- `Unknown` is accepted permissively (consistent with TEXT/MAP/OUTCOME pattern)

**OOF-COL3 (filter predicate non-Bool) — P3 decision:**
- Whether to emit OOF-COL3 when the lambda body type is non-Bool/non-Unknown for `filter`
- Recommendation: validate and emit OOF-COL3 for non-Bool, non-Unknown body types
- If implementing OOF-COL3 adds complexity, it can be deferred to a P4 amendment with a
  type_warning instead — this is the final decision for the P3 implementation author

### Q11. Does `count` require a special case because the T3 path exists?

**No.** The T3 path and the regular-call path are completely separate code paths:

- **T3 path**: entered from `handle_t3_variant` → `t3_call_site_check` → matches
  `NUMERIC_MEASURE_BUILTINS["count"]`. This path processes the `decreases count(items)`
  evidence form in contract headers.
- **Regular-call path**: entered from `typecheck_contract` (compute declarations) →
  `infer_expr` → `infer_call` → `when *COLLECTION_HOF_FNS.keys` (new arm).

These two paths never share a call site. The new `when "count"` arm in `infer_call`
(via `COLLECTION_HOF_FNS`) is only reached for regular `compute n = count(items)` nodes.
The T3 `handle_t3_variant` is only reached for `decreases count(...)` headers.

No conflict, no guard needed, no modification to the T3 path.

**One invariant to confirm (P3 regression check):** after adding `COLLECTION_HOF_FNS`
with `"count"`, the `when *COLLECTION_HOF_FNS.keys` arm in `infer_call` will intercept
any call to `count(...)` that reaches `infer_call`. This is correct — T3 calls never
reach `infer_call` (they go through `handle_t3_variant`). The P3 regression suite must
include a T3 count fixture to confirm the T3 path is unaffected.

### Q12. What regression matrix is required?

Minimum regressions required before P3 passes:

1. **String core proof** — existing runner must remain PASS (TEXT_STDLIB_FNS unchanged)
2. **Typed contract ref P5** — 71/71 PASS (cross-module resolution unchanged)
3. **Stdlib outcome P3** — 60/60 PASS (OUTCOME_STDLIB_FNS unchanged)
4. **Recursion P2** — 42/42 PASS (if available, confirms SCC path unchanged)

These cover the four dispatch tables above COLLECTION_HOF_FNS in `infer_call`. Since the
new arm is inserted **after** `when *OUTCOME_STDLIB_FNS.keys`, none of the existing arms
are perturbed.

In addition, the P3 proof runner itself serves as the regression fixture for P4.

### Q13. What proof target is sufficient for P3?

**≥50 checks, 8 sections.** Distribution:

| Section | Count | Focus |
|---------|-------|-------|
| A — Regression | 7 | string_core/typed_ref/outcome existing runners pass |
| B — count dispatch | 8 | Integer return; OOF-COL1 arity errors; OOF-COL2 non-Collection; T3 coexistence |
| C — filter dispatch | 8 | passthrough Collection[T] type; OOF-COL1/COL2; lambda param binding; field access on param |
| D — map dispatch | 8 | Collection[U] return; lambda body type propagation; OOF-COL1/COL2; field access on param → typed field |
| E — SIR qualified names | 6 | SIR fn == "stdlib.collection.{map,filter,count}" for all three; never bare name |
| F — type inference correctness | 7 | map output elem = lambda body type; filter returns same Collection type; count Integer in all cases including empty |
| G — app fixture integration | 6 | bookkeeping filter/map; spreadsheet map; ERP filter; all produce no OOF-TY0 for collection calls |
| H — authority closed | 6 | fold/sum not registered → OOF-TY0; predicate-count → OOF-COL1; named fn ref → OOF-COL1; or_else unchanged; OUTCOME_STDLIB_FNS unchanged |

**Minimum total: 56 checks.** Recommended target: 56–64 checks.

---

## 3. Implementation Method Body

The full body of `infer_collection_hof_call` to guide P3 implementation:

```ruby
# LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1: Collection HOF dispatch.
# Handles: map(Collection[T], (T→U)) → Collection[U]
#          filter(Collection[T], (T→Bool)) → Collection[T]
#          count(Collection[T]) → Integer
def infer_collection_hof_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  spec          = COLLECTION_HOF_FNS.fetch(fn)
  qualified     = spec[:qualified_name]
  expected_arity = spec[:arity]
  has_lambda    = spec[:has_lambda]

  # ── OOF-COL1: arity check ────────────────────────────────────────────────
  unless args.length == expected_arity
    type_errors << oof("OOF-COL1",
      "#{qualified}: expected #{expected_arity} argument(s), got #{args.length}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
  end

  # ── Infer collection argument ─────────────────────────────────────────────
  collection_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  col_type_name  = type_name(collection_arg.fetch("resolved_type"))

  # ── OOF-COL2: first arg must be Collection or Unknown ────────────────────
  unless col_type_name == "Collection" || col_type_name == "Unknown"
    type_errors << oof("OOF-COL2",
      "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                      "fn" => qualified, "args" => [collection_arg])
  end

  # ── count: no lambda, return Integer ─────────────────────────────────────
  unless has_lambda
    return typed_expr("call", type_ir("Integer"), collection_arg.fetch("deps", []),
                      "fn" => qualified, "args" => [collection_arg])
  end

  # ── map / filter: validate lambda argument ────────────────────────────────
  lambda_node = args[1]
  unless lambda_node.is_a?(Hash) && lambda_node.fetch("kind", nil) == "lambda"
    type_errors << oof("OOF-COL1",
      "#{qualified}: second argument must be a lambda, got #{lambda_node.fetch("kind", "non-lambda")}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                      "fn" => qualified, "args" => [collection_arg])
  end

  # ── Bind lambda parameter to element type ─────────────────────────────────
  elem_type    = element_type_from_collection(collection_arg.fetch("resolved_type"))
  lambda_params = lambda_node.fetch("params", [])
  local_symbols = lambda_params.each_with_object(symbol_types.dup) do |param, acc|
    acc[param] = elem_type
  end

  # ── Infer lambda body ─────────────────────────────────────────────────────
  lambda_body = lambda_node.fetch("body")
  body_typed  = infer_lambda_body(lambda_body, local_symbols, type_errors, type_warnings, node_name)
  body_type   = body_typed.fetch("resolved_type")

  lambda_deps  = body_typed.fetch("deps", [])
  all_deps     = (collection_arg.fetch("deps", []) + lambda_deps).uniq

  # ── Build output type ─────────────────────────────────────────────────────
  output_type = case fn
  when "map"
    collection_type_ir_from(body_type)     # Collection[U] where U = lambda body return type
  when "filter"
    collection_type_ir_from(elem_type)     # Collection[T] — passthrough element type
  end

  typed_expr("call", output_type, all_deps,
             "fn" => qualified, "args" => [collection_arg])
end

# Infer the return type of a lambda body.
# Handles both single-expression bodies and block-form bodies.
# Returns a typed_expr hash with "resolved_type" and "deps".
def infer_lambda_body(body, local_symbols, type_errors, type_warnings, node_name)
  if body.is_a?(Hash) && body.fetch("kind", nil) == "block"
    # Block form: { stmts... return_expr }
    stmts       = body.fetch("stmts", [])
    return_expr = body.fetch("return_expr", nil)
    block_syms  = local_symbols.dup
    stmts.each do |stmt|
      case stmt.fetch("kind", nil)
      when "let"
        val_typed = infer_expr(stmt.fetch("expr"), block_syms, type_errors, type_warnings, node_name)
        block_syms[stmt.fetch("name")] = val_typed.fetch("resolved_type")
      when "expr_stmt"
        infer_expr(stmt.fetch("expr"), block_syms, type_errors, type_warnings, node_name)
      end
    end
    return_expr ? infer_expr(return_expr, block_syms, type_errors, type_warnings, node_name)
                : typed_expr("literal", type_ir("Unknown"), [], "value" => nil, "literal_type" => "nil")
  else
    # Single-expression body (the common case for all app fixtures)
    infer_expr(body, local_symbols, type_errors, type_warnings, node_name)
  end
end
```

**Note on `collection_type_ir_from`:** This helper already exists in the Ruby TC (used by
`infer_array_literal` at line 2301). It builds a `Collection[T]` type IR from an element
type IR. No new helper required.

**Approximate line count:** ~75 lines across both new private methods.

---

## 4. Proof Runner Location

`igniter-lang/experiments/stdlib_collection_proof/verify_stdlib_collection_map_filter_p3.rb`

Following the pattern:
- `experiments/stdlib_outcome_proof/verify_stdlib_outcome_p3.rb`
- `experiments/typed_contract_ref_proof/verify_typed_contract_ref_p3.rb`

The proof runner uses the Ruby `CompilerOrchestrator` or `TypeChecker` directly (not the
Rust lab compiler). It loads the canon pipeline from `igniter-lang/lib/`.

---

## 5. stdlib-inventory.json Update (P3 scope)

The inventory file is NOT to be edited in P3. However, the P3 proof runner must assert
the entry contract invariants against the **existing** inventory to confirm nothing
conflicts. Specifically:

- `stdlib.collection.count` entry exists with correct `semantic_ir_name` ✓
- `stdlib.collection.map` and `stdlib.collection.filter` are absent from inventory (correct;
  they are proof-local in P3)
- After P3 passes, a P4 card adds the two new entries to `stdlib-inventory.json` and
  updates the count entry (proof_lineage and compatibility_note)

This matches the LANG-STDLIB-ENTRY-CONTRACT-P3 pattern (inventory is updated after
implementation is proved, not before).

---

## 6. Implementation Surface Summary

| Item | Detail |
|------|--------|
| Authorized file | `igniter-lang/lib/igniter_lang/typechecker.rb` only |
| New constant | `COLLECTION_HOF_FNS` (~6 lines) after `OUTCOME_STDLIB_FNS` |
| New infer_call arm | `when *COLLECTION_HOF_FNS.keys` (~2 lines) after `when *OUTCOME_STDLIB_FNS.keys` |
| New private methods | `infer_collection_hof_call` (~55 lines) + `infer_lambda_body` (~20 lines) |
| Reused methods | `element_type_from_collection` (line ~1825), `collection_type_ir_from` (line ~2301), `infer_expr` (line ~776) |
| Total new lines | ~80–90 lines in one file |
| Emitter changes | Zero (generic `semantic_expr` preserves `fn` field) |
| Parser changes | Zero (lambda AST already produced by `parse_lambda`) |
| Proof runner | `experiments/stdlib_collection_proof/verify_stdlib_collection_map_filter_p3.rb` |
| Regression suites | string_core + typed_contract_ref_p5 + stdlib_outcome_p3 (3 existing runners) |

---

## 7. Fixtures Required for P3

Three inline source fixtures (no new `.ig` files needed):

```ruby
# Bookkeeping-style map fixture
MAP_FIXTURE = <<~IG
  module CollectionMapTest
  record Posting { amount : Decimal, direction : Text }
  contract TestMap {
    input postings : Collection[Posting]
    compute amounts = map(postings, p -> p.amount)
    output amounts : Collection[Decimal]
  }
IG

# Bookkeeping-style filter fixture
FILTER_FIXTURE = <<~IG
  module CollectionFilterTest
  record Posting { amount : Decimal, direction : Text }
  contract TestFilter {
    input postings : Collection[Posting]
    compute debits = filter(postings, p -> p.direction == "Debit")
    output debits : Collection[Posting]
  }
IG

# Count fixture (regular compute call, not T3)
COUNT_FIXTURE = <<~IG
  module CollectionCountTest
  contract TestCount {
    input items : Collection[Integer]
    compute n = count(items)
    output n : Integer
  }
IG
```

These are the exact patterns from the app fixtures. The proof runner compiles each and
asserts: (a) zero type errors; (b) SIR `fn` field equals the qualified canonical name.

For OOF-COL diagnostics, inline fixtures with wrong arities:

```ruby
COUNT_ARITY_FIXTURE = "... compute n = count() ..."   # OOF-COL1
FILTER_NO_LAMBDA    = "... compute d = filter(items) ..."  # OOF-COL1
MAP_NON_COLLECTION  = "... compute r = map(\"hello\", x -> x) ..."  # OOF-COL2
```

---

## 8. Open Question: OOF-COL3 for filter predicates

**Decision deferred to P3 implementation author.**

Two options:
- **A (strict):** Emit `OOF-COL3 "filter predicate must return Bool, got X"` when the
  lambda body resolves to a non-Bool, non-Unknown type. This is the correct behavior and
  matches the RFC intent.
- **B (permissive):** Accept any lambda body type for `filter` in v0. Emit only `OOF-COL1`
  and `OOF-COL2`. Add a `type_warning` for non-Bool body types. Consistent with the
  Unknown-permissive pattern in TEXT/MAP/OUTCOME.

**Recommendation: Option A (strict).** The filter predicate is semantically required to
return Bool. Permissive behavior would allow `filter(items, x -> x.name)` to compile
without error, which is incorrect. Option A is honesty-aligned.

If Option A adds significant complexity (e.g., the `type_name` check has edge cases with
Unknown propagation through complex expressions), fall back to Option B with a `type_warning`
and document as a known gap for P4 hardening.

---

## 9. Authority Closed

No TypeChecker implementation in this planning doc. No Rust implementation. No VM changes.
No app fixture changes. No `fold`. No `sum`. No predicate-count. No named function refs
unless already proven available (none are in v0). No public API claim.

---

## 10. Next Route

**If P3 PASS (expected):**  
`LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P3` — Ruby canon implementation proof  
Proof runner: `experiments/stdlib_collection_proof/verify_stdlib_collection_map_filter_p3.rb`  
Target: ≥56 checks, 8 sections.

**Parallel tracks (unblocked by P3):**  
- `LAB-STDLIB-FOLD-P1` — fold readiness proof  
- `LAB-STDLIB-SUM-P1` — sum readiness proof  

**After P3 PASS:**  
- Inventory update card (add map/filter entries; amend count entry)  
- Rust parity card (fix map lambda Integer placeholder; fix SIR qualified name emission)
