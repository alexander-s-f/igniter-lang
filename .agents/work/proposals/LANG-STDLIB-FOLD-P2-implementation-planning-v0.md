# LANG-STDLIB-FOLD-P2 — Implementation Planning

**Track:** lang / stdlib / collection / fold  
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE  
**Status:** CLOSED — implementation-planning-only / READY FOR P3  
**Date:** 2026-06-12  
**Predecessors:**  
- LANG-STDLIB-FOLD-PROP-P1 (authored)  
- LAB-STDLIB-FOLD-P1 (50/50 PASS — ACCEPT)  
- LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P3 (map/filter/count Ruby implementation — P3 runner exists)

---

## Planning Decision: READY FOR P3

`stdlib.collection.fold` is implementable in a single P3 slice. No SPLIT required.

**Basis:**
- `infer_lambda_body` (added in map/filter/count P3) already handles both single-expression and block-body lambdas. Both app fixture lambda shapes are covered without any new code.
- `element_type_from_collection` (line ~1839) extracts `T` from `Collection[T]` — the elem param binding is identical to map/filter.
- Seed type via `infer_expr` is clean: literals resolve through `type_ir(type_tag)`, refs resolve through `symbol_types`, calls resolve through normal inference. No special-casing.
- 2-param lambda binding is a trivial `symbol_types.merge(acc_param => acc_type, elem_param => elem_type)` — the exact same mechanism as 1-param, with one extra key.
- No HOLD: accumulator typing is fully specified and grounded.

---

## Authorized File

**One file only:** `igniter-lang/lib/igniter_lang/typechecker.rb`

Zero emitter / parser / classifier / assembler / VM changes.
The generic `semantic_expr` in `semanticir_emitter.rb` preserves the `fn` field verbatim —
`semantic_ir_name == canonical_name` is automatic.

---

## Q1 — Exact TypeChecker insertion points

### Insertion 1 — `infer_call` dispatch arm (~line 891, after `COLLECTION_HOF_FNS` arm)

```ruby
when "fold"
  # LANG-STDLIB-FOLD-PROP-P1: stdlib.collection.fold — accumulator HOF
  infer_fold_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

**Location:** after line 893 (`infer_collection_hof_call(...)` call), before line 894 (`when "or_else"`).

### Insertion 2 — `infer_fold_call` private method (~line 2389, after `infer_lambda_body`)

New private method `infer_fold_call` inserted immediately after the closing `end` of
`infer_lambda_body` (line 2388), before the `infer_or_else` method (line 2390).

**Method size: ~50–60 lines.**

No constant insertion required (see Q2).

---

## Q2 — Fold in existing COLLECTION_HOF_FNS or separate constant?

**Separate `when "fold"` arm with no new constant.**

`COLLECTION_HOF_FNS` is wrong abstraction for fold for three structural reasons:

| Property | COLLECTION_HOF_FNS entries | fold |
|----------|---------------------------|------|
| Arity | 1 or 2 | 3 |
| Lambda param count | 0 or 1 | 2 |
| Output type | `Collection[U]`, `Collection[T]`, or `Integer` | `Acc` (scalar) |
| Acc type source | — | Seed expression (args[1]) |

Extending `COLLECTION_HOF_FNS` with fold would require adding `lambda_param_count`,
`has_seed`, and `result_from` fields and converting `infer_collection_hof_call` into a
large branching dispatch — defeating the purpose of a uniform constant. A dedicated
`infer_fold_call` method is cleaner and follows the same self-contained pattern as
`infer_outcome_call`.

The qualified name `"stdlib.collection.fold"` is emitted inline (no constant needed for
a single entry). If a future fold family grows, a `COLLECTION_FOLD_FNS` constant can be
added at that time.

---

## Q3 — Infer seed expression type as Acc

**Use `infer_expr(args[1], symbol_types, ...)` directly.**

This is strictly better than the literal-only `fold_stream_result_type` pattern because:

1. **Literals** (the common case): `infer_expr` on a literal calls `type_ir(type_tag)` internally — equivalent to the fold_stream pattern but using the standard inference path
2. **Refs** (e.g., `compute seed = 0.00; fold(col, seed, ...)`) — `infer_expr` resolves via `symbol_types`, returning the correct type
3. **Calls** (e.g., `fold(col, get_seed(), ...)`) — `infer_expr` resolves via the normal call dispatch, returning the return type

The `fold_stream_result_type` is limited to literals because it operates on a raw decl
node outside the `infer_expr` context. `infer_fold_call` has full `infer_expr` access —
no reason to use the more restricted pattern.

```ruby
seed_typed = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
acc_type   = seed_typed.fetch("resolved_type")
# acc_type is now the Acc type; Unknown if seed is Unknown
```

---

## Q4 — Bind lambda params: acc → Acc, elem → T

```ruby
lambda_params = lambda_node.fetch("params", [])
# lambda_params[0] = acc param name (e.g. "acc")
# lambda_params[1] = elem param name (e.g. "tx", "r")

elem_type     = element_type_from_collection(collection_typed.fetch("resolved_type"))
local_symbols = symbol_types.merge(
  lambda_params[0] => acc_type,
  lambda_params[1] => elem_type
)
```

Exactly the same mechanism as `infer_collection_hof_call` for map/filter, extended to 2
params. The `symbol_types.merge(...)` call is non-destructive — outer scope is unaffected.

---

## Q5 — Infer lambda body type

**Use `infer_lambda_body` unchanged.** The method already handles both body forms:

```ruby
lambda_body     = lambda_node.fetch("body")
body_typed      = infer_lambda_body(lambda_body, local_symbols, type_errors, type_warnings, node_name)
body_type       = body_typed.fetch("resolved_type")
```

`infer_lambda_body` was added in map/filter/count P3 (lines 2369–2388). It handles:
- Single-expression bodies: `infer_expr(body, local_symbols, ...)`
- Block-form bodies: processes `stmts` (let bindings) then `infer_expr(return_expr, ...)`

Both app fixture lambda shapes are covered:
- bookkeeping: `acc + 0.00` → single-expression
- ERP: `if r.cost_per_kg < acc { ... } else { acc }` → block-form with if-else

No changes to `infer_lambda_body`. Zero new code for this step.

---

## Q6 — Enforce body type == Acc (OOF-COL4)

```ruby
body_name = type_name(body_type)
acc_name  = type_name(acc_type)

unless body_name == acc_name || body_name == "Unknown" || acc_name == "Unknown"
  type_errors << oof("OOF-COL4",
    "stdlib.collection.fold: lambda return type #{body_name} does not match accumulator type #{acc_name}",
    node_name)
end
```

**Permissive cases (no OOF emitted):**
- `body_name == acc_name` — types match exactly
- `body_name == "Unknown"` — Unknown propagates (lambda body unresolvable)
- `acc_name == "Unknown"` — Unknown propagates (seed unresolvable)

**Strict case (OOF-COL4 emitted):**
- Both types known AND they differ (e.g., body = `Integer`, acc = `Float`)

This matches the PROP-P1 design: strict check, Unknown-permissive. OOF is emitted but
type inference continues — result type is still `acc_type` (graceful degradation).

---

## Q7 — Exact OOF-COL4 triggers

All fold-family errors use `OOF-COL4`.

| Trigger | Condition | Return |
|---------|-----------|--------|
| Arity mismatch | `args.length != 3` | `typed_expr(..., Unknown)` + early return |
| Non-Collection first arg | `col_type_name != "Collection" && != "Unknown"` | `typed_expr(..., Unknown)` + early return |
| Non-lambda third arg | `lambda_node["kind"] != "lambda"` | `typed_expr(..., acc_type)` + early return |
| Lambda param count ≠ 2 | `lambda_params.length != 2` | `typed_expr(..., acc_type)` + early return |
| Lambda return ≠ Acc | types known and differ | `typed_expr(..., acc_type)` — NO early return |

The last trigger (`return ≠ Acc`) does not cause early return: the error is recorded but
inference continues and the result type is still `acc_type`. This is consistent with how
`OOF-COL3` (filter predicate non-Bool) works in `infer_collection_hof_call`.

---

## Q8 — Block-body lambda support in v0?

**Yes — already available. No new work needed.**

`infer_lambda_body` (lines 2369–2388) handles block-form bodies:
```ruby
if body.is_a?(Hash) && body.fetch("kind", nil) == "block"
  stmts       = body.fetch("stmts", [])
  return_expr = body.fetch("return_expr", nil)
  block_syms  = local_symbols.dup
  stmts.each { ... }
  return_expr ? infer_expr(return_expr, block_syms, ...) : ...
else
  infer_expr(body, local_symbols, ...)
end
```

The ERP fixture uses a block-form lambda (if-else body). P3 will prove this directly
in the app-fixture section — this is the key regression that confirms block-body
lambda support works end-to-end for fold.

No SPLIT is required for block-body lambda support. It is already proven working in P3
for filter and map.

---

## Q9 — Preserve fold_stream separation

**No changes to `fold_stream` path.** The separation is structural:

```ruby
# handle_t3_variant (~line 375) — fold_stream path:
when "fold_stream"
  check_fold_stream_body(decl, stream_symbols, type_errors)
  result_type = fold_stream_result_type(decl)

# infer_call (~line 891) — regular fold path (NEW):
when "fold"
  infer_fold_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

`handle_t3_variant` is entered only from the T3 `decreases fold_stream(...)` evidence
path. `infer_call` is entered for all regular compute expressions. The string `"fold"`
never appears in `handle_t3_variant`; `"fold_stream"` never appears in `infer_call`.
Adding `when "fold"` to `infer_call` does not touch or risk the fold_stream path.

The regression section (Section A, Section G) will explicitly verify `fold_stream` is
unaffected by running existing tests and checking the T3 source path.

---

## Q10 — SIR canonical name emitted

**`"stdlib.collection.fold"`** — the qualified canonical name.

```ruby
typed_expr("call", acc_type, all_deps, "fn" => "stdlib.collection.fold", "args" => [...])
```

The generic `semantic_expr` in `semanticir_emitter.rb` preserves the `fn` field verbatim.
`semantic_ir_name == canonical_name` is satisfied automatically. Zero emitter changes.

This follows the identical pattern as `infer_collection_hof_call` (which emits
`spec[:qualified_name]`) and `infer_outcome_call` (which emits `spec[:qualified_name]`).

---

## Q11 — Regression matrix required

Four existing proof runners must be embedded as regressions in the P3 proof runner:

| Runner | Expected | Note |
|--------|----------|------|
| `verify_lab_stdlib_collection_p1.rb` (P1 runner) | All PASS | Baseline: fold was OOF-TY0 in P1 |
| Existing string_core proof runner | All PASS | Confirms no text stdlib regression |
| Existing stdlib_outcome_p3 runner | All PASS | Confirms no outcome regression |
| Existing typed_contract_ref_p5 runner | All PASS | Confirms no typed-ref regression |

Additionally, Section G specifically tests fold_stream coexistence — 5 checks confirming
`handle_t3_variant` still dispatches fold_stream correctly and `fold` in regular compute
context dispatches via infer_call (not OOF-TY0).

---

## Full `infer_fold_call` Method (~55 lines)

This is the complete implementation spec for P3. P3 must implement this exactly.

```ruby
# LANG-STDLIB-FOLD-PROP-P1/P3: stdlib.collection.fold
# Signature: Collection[T] × Acc × ((Acc, T) -> Acc) -> Acc
# Acc type inferred from seed expression (args[1]).
# Lambda must have exactly 2 params: (acc, elem).
# OOF-COL4 for all fold-family errors.
def infer_fold_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  qualified = "stdlib.collection.fold"

  # ── OOF-COL4: arity check — must be exactly 3 args ──────────────────────────
  unless args.length == 3
    type_errors << oof("OOF-COL4",
      "#{qualified}: expected 3 arguments (collection, seed, lambda), got #{args.length}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
  end

  # ── Infer collection argument (arg[0]) ───────────────────────────────────────
  collection_typed = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  col_type_name    = type_name(collection_typed.fetch("resolved_type"))

  # ── OOF-COL4: first arg must be Collection or Unknown ───────────────────────
  unless col_type_name == "Collection" || col_type_name == "Unknown"
    type_errors << oof("OOF-COL4",
      "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), collection_typed.fetch("deps", []),
                      "fn" => qualified, "args" => [collection_typed])
  end

  # ── Infer seed / accumulator type (arg[1]) ───────────────────────────────────
  seed_typed = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
  acc_type   = seed_typed.fetch("resolved_type")

  # ── OOF-COL4: third arg must be a lambda ─────────────────────────────────────
  lambda_node = args[2]
  unless lambda_node.is_a?(Hash) && lambda_node.fetch("kind", nil) == "lambda"
    type_errors << oof("OOF-COL4",
      "#{qualified}: third argument must be a lambda, got #{lambda_node.fetch("kind", "non-lambda") rescue "non-lambda"}",
      node_name)
    return typed_expr("call", acc_type, (collection_typed.fetch("deps", []) + seed_typed.fetch("deps", [])).uniq,
                      "fn" => qualified, "args" => [collection_typed, seed_typed])
  end

  # ── OOF-COL4: lambda must have exactly 2 params ──────────────────────────────
  lambda_params = lambda_node.fetch("params", [])
  unless lambda_params.length == 2
    type_errors << oof("OOF-COL4",
      "#{qualified}: lambda must have exactly 2 parameters (acc, elem), got #{lambda_params.length}",
      node_name)
    return typed_expr("call", acc_type, (collection_typed.fetch("deps", []) + seed_typed.fetch("deps", [])).uniq,
                      "fn" => qualified, "args" => [collection_typed, seed_typed])
  end

  # ── Bind lambda params: acc → Acc, elem → T ──────────────────────────────────
  elem_type     = element_type_from_collection(collection_typed.fetch("resolved_type"))
  local_symbols = symbol_types.merge(lambda_params[0] => acc_type, lambda_params[1] => elem_type)

  # ── Infer lambda body ─────────────────────────────────────────────────────────
  lambda_body = lambda_node.fetch("body")
  body_typed  = infer_lambda_body(lambda_body, local_symbols, type_errors, type_warnings, node_name)
  body_type   = body_typed.fetch("resolved_type")

  # ── OOF-COL4: lambda return type must match Acc ───────────────────────────────
  body_name = type_name(body_type)
  acc_name  = type_name(acc_type)
  unless body_name == acc_name || body_name == "Unknown" || acc_name == "Unknown"
    type_errors << oof("OOF-COL4",
      "#{qualified}: lambda return type #{body_name} does not match accumulator type #{acc_name}",
      node_name)
  end

  # ── Result type = Acc (scalar) ────────────────────────────────────────────────
  all_deps = (collection_typed.fetch("deps", []) + seed_typed.fetch("deps", []) + body_typed.fetch("deps", [])).uniq
  typed_expr("call", acc_type, all_deps, "fn" => qualified, "args" => [collection_typed, seed_typed])
end
```

**Total new lines: ~55.** One file only (`typechecker.rb`). Zero other changes.

---

## Insertions Summary

| # | What | Where | Lines |
|---|------|-------|-------|
| 1 | `when "fold"` dispatch arm | After line 893 (after `infer_collection_hof_call` call), before `when "or_else"` | 3 |
| 2 | `infer_fold_call` private method | After line 2388 (after `infer_lambda_body` end), before `infer_or_else` | ~55 |

**Total: ~58 new lines. One file.**

---

## Proof Matrix

**Proof runner:** `experiments/stdlib_collection_proof/verify_stdlib_fold_p3.rb`  
**Total checks: ≥52 (target 52–60)**

| Section | Checks | Focus |
|---------|--------|-------|
| A — Regression | 7 | string_core + typed_ref_p5 + stdlib_outcome_p3 + collection_map_filter_p3 runners |
| B — Fold basics | 8 | Integer / Decimal / Float seeds; correct Acc result type; scalar not Collection |
| C — Lambda type inference | 7 | acc param bound; elem param bound; single-expr; block-body; body type propagation |
| D — OOF-COL4 diagnostics | 8 | arity<3; arity>3; non-lambda; non-Collection; 1 param; 3 params; return mismatch; Unknown-permissive |
| E — SIR names | 5 | fn="stdlib.collection.fold"; not bare "fold"; map/filter SIR unaffected |
| F — App fixtures | 6 | bookkeeping Decimal fold; ERP Float+block-body fold; zero OOF-TY0 |
| G — fold_stream coexistence | 5 | T3 path unaffected; fold in compute body dispatched; fold_stream source unchanged |
| H — Authority closed | 6 | sum OOF-TY0; no inventory entry; no VM; map/filter/count unaffected |

**Total: 52 checks minimum. Target: 52–60.**

---

## Fixtures Required (inline in proof runner)

```ruby
FOLD_INTEGER = <<~IG
  module FoldInt
  type Item { value : Integer }
  contract SumItems {
    input items : Collection[Item]
    compute total = fold(items, 0, (acc, x) -> acc + x.value)
    output total : Integer
  }
IG

FOLD_DECIMAL = <<~IG
  module FoldDecimal
  type Tx { amount : Decimal[2] }
  contract SumAmounts {
    input txs : Collection[Tx]
    compute total = fold(txs, 0.00, (acc, tx) -> acc + tx.amount)
    output total : Decimal[2]
  }
IG

FOLD_FLOAT_BLOCK = <<~IG
  module FoldFloat
  type Route { cost : Float }
  contract MinCost {
    input routes : Collection[Route]
    compute best = fold(routes, 999999.0, (acc, r) -> if r.cost < acc { r.cost } else { acc })
    output best : Float
  }
IG

FOLD_ARITY_BAD    = "module X contract Bad { input c : Collection[Integer] compute r = fold(c, 0) output r : Integer }"
FOLD_NON_COL      = "module X contract Bad { input n : Integer compute r = fold(n, 0, (acc, x) -> acc + x) output r : Integer }"
FOLD_NON_LAMBDA   = "module X contract Bad { input c : Collection[Integer] compute r = fold(c, 0, 99) output r : Integer }"
FOLD_ONE_PARAM    = "module X contract Bad { input c : Collection[Integer] compute r = fold(c, 0, (acc) -> acc) output r : Integer }"
FOLD_TYPE_MISMATCH = "module X contract Bad { input c : Collection[Integer] compute r = fold(c, 0, (acc, x) -> \"hello\") output r : Integer }"
```

App fixture paths (no edits — read as-is):
- `igniter-lab/igniter-apps/bookkeeping/types.ig` + `bookkeeping/ledger.ig`
- `igniter-lab/igniter-apps/erp_logistics/types.ig` + `erp_logistics/optimizer.ig`

---

## Key Design Points

| Point | Decision |
|-------|----------|
| Dispatch approach | Separate `when "fold"` arm + `infer_fold_call` method (not in COLLECTION_HOF_FNS) |
| Constant | None — single entry, qualified name inline in method |
| Seed type | `infer_expr(args[1], ...)` — handles literals, refs, calls |
| fold_stream | Completely separate; `handle_t3_variant` unaffected; no regression risk |
| Result type | `acc_type` (scalar) — never `collection_type_ir_from(acc_type)` |
| OOF-COL4 on return mismatch | Non-early-return: error recorded, acc_type returned (graceful) |
| Block-body lambda | Handled by existing `infer_lambda_body` — no new code |
| SIR name | `"stdlib.collection.fold"` inline — zero emitter changes |
| `infer_lambda_body` | Used unchanged — fold is a client, not a modifier |
| Insertion order | `infer_fold_call` after `infer_lambda_body`, before `infer_or_else` |
| Inventory edits | Deferred to P3 PASS — no inventory file changes in P3 |

---

## Authority Closed

No implementation (P3 scope) / No Rust parity / No `sum` / No `fold_stream` changes /
No VM/runtime changes / No app fixture edits / No `stdlib-inventory.json` edits /
No new OOF codes beyond OOF-COL4.
