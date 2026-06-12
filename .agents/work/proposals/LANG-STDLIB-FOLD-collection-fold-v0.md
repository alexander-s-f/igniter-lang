# LANG-STDLIB-FOLD v0 — stdlib.collection.fold

**Track:** stdlib / collection / fold  
**Status:** authored-pending-review  
**Date:** 2026-06-12  
**Route:** PROPOSAL AUTHORING ONLY / NO IMPLEMENTATION  
**Predecessor proof:** LAB-STDLIB-FOLD-P1 (50/50 PASS — ACCEPT verdict)  
**Predecessor governance:** LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1 (map/filter/count authored), LANG-STDLIB-ENTRY-CONTRACT-P1/P2/P3, LAB-STDLIB-COLLECTION-P1

---

## 1. Context and Evidence Base

`LAB-STDLIB-FOLD-P1` (50/50 PASS) confirmed that `stdlib.collection.fold` is ready for
proposal authoring with an ACCEPT verdict. No HOLD blockers. No SPLIT required.

The readiness proof established:

- **App pressure confirmed** — 2 fixtures in 2 independent apps:
  - `bookkeeping/ledger.ig`: `fold(txs, 0.00, (acc, tx) -> acc + 0.00)` — Decimal seed
  - `erp_logistics/optimizer.ig`: `fold(matching_routes, 999999.0, (acc, r) -> if r.cost_per_kg < acc { r.cost_per_kg } else { acc })` — Float seed, block-body lambda
- **Ruby TC:** `fold` → `OOF-TY0 "Unknown function: fold"` (no dispatch in `infer_call`)
- **Rust TC:** dispatched at line 3233; result = seed type; no lambda body inference
- **Accumulator typing:** seed-literal bootstrap is the correct approach — `fold_stream_result_type` (line 1622) already uses this exact pattern in the Ruby TC
- **Lambda shape:** both fixtures use 2-param inline lambdas `(acc, elem)`; single-expression and block-body variants both present

`LAB-STDLIB-COLLECTION-P1` (64/64 PASS) split fold out of the map/filter/count group specifically because of its 3-arg accumulator form. That split is now answered: fold is separate and ready.

`LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1` defines the OOF-COL namespace and reserves
OOF-COL4 for fold-family errors and OOF-COL5 for sum-family errors.

---

## 2. Core Principle

**`stdlib.collection.fold` is a pure left-fold over a finite ordered collection.**

It does not:
- Execute queries or access storage
- Grant authority or consume capabilities
- Mutate its input collection
- Evaluate lazily or stream
- Produce side effects of any kind
- Derive or replace `sum` — sum is a separate entry with numeric type constraints

The accumulator function is CORE: it must not escape to stream symbols, storage refs,
or capability parameters. This mirrors the `fold_stream` accumulator CORE constraint
(OOF-S3, `check_fold_stream_body`) which already enforces this for the stream T3 path.

---

## 3. Scope of v0

**Accepted (this proposal):**

- `stdlib.collection.fold` — left-fold with seed accumulator:
  `Collection[T] × Acc × ((Acc, T) → Acc) → Acc`

**Explicitly excluded from v0:**

- `fold_stream` — entirely separate; streams T3 path; already in `fold_stream_result_type`
- `stdlib.collection.sum` — deferred; separate LAB-STDLIB-SUM-P1 track
- `reduce` — fold covers reduce semantics; no separate entry
- `scan` — produces intermediate accumulators; out of scope
- `groupBy`, sorting, zip, flat_map — out of scope
- Mutable fold / foldLeft vs foldRight distinction — not applicable in v0
- Named function reference form — inline lambda only in v0; no `Fn[Acc,T,Acc]` type
- Predicate-count, aggregate-count — separate from fold
- SQL/query/streaming execution semantics — out of scope

---

## 4. Canonical Name and Source Alias

**Canonical name:** `stdlib.collection.fold`

**Source aliases accepted:** `fold` (bare, unqualified)

Both app fixtures use bare `fold` — no qualified names, no method syntax. This follows
the exact same pattern as `map`, `filter`, and `count`.

No other aliases are introduced. The alias `fold_stream` is NOT an alias for this entry
(it is a separate, unrelated stream-T3 builtin).

---

## 5. Signature

```
stdlib.collection.fold : Collection[T] × Acc × ((Acc, T) → Acc) → Acc
```

| Parameter | Position | Type | Description |
|-----------|----------|------|-------------|
| collection | arg[0] | `Collection[T]` | Input collection |
| seed | arg[1] | `Acc` | Initial accumulator value; determines `Acc` type |
| lambda | arg[2] | `(Acc, T) → Acc` | Accumulator function; 2-param inline lambda |
| **result** | — | `Acc` | Final accumulated value |

**Result type is `Acc` (scalar), not `Collection[Acc]`.**
This distinguishes fold from map/filter: fold reduces a collection to a single value.
The result is of the same type as the seed.

---

## 6. Accumulator Type Determination

**The accumulator type `Acc` is inferred from the seed literal (arg[1]).**

The seed carries a `type_tag` field set by the parser. The accumulator type is:
```ruby
type_ir(seed_literal.fetch("type_tag", "Unknown"))
```

This is the identical pattern used by `fold_stream_result_type` in the Ruby TC (line 1622):
```ruby
def fold_stream_result_type(decl)
  args = expr.fetch("args", [])
  init_arg = args[1]  # args[0]=stream_ref, args[1]=init, args[2]=lambda
  return type_ir("Unknown") unless init_arg&.fetch("kind", nil) == "literal"
  type_ir(init_arg.fetch("type_tag", "Unknown"))
end
```

**Seed type examples:**

| Seed literal | `type_tag` | Acc type |
|-------------|-----------|---------|
| `0.00` | `"Decimal"` | `Decimal` |
| `999999.0` | `"Float"` | `Float` |
| `0` | `"Integer"` | `Integer` |
| `""` | `"Text"` | `Text` |

**Non-literal seed:** If the seed expression is not a literal (e.g. a ref or function call),
Acc = `Unknown`. The fold result type is `Unknown`. No OOF is emitted — Unknown propagates
permissively, consistent with the TEXT/MAP/OUTCOME pattern.

**No circular dependency:** Acc must be known before the lambda can be typechecked (the
acc param needs a type to bind). Seed-literal bootstrap breaks this circularity. Output
annotation cannot break it (annotation is not always present). Lambda return type cannot
break it (we must know Acc to evaluate the lambda).

---

## 7. Lambda Shape

### v0 constraint: inline lambda at the call site only

Named function references are not accepted in v0. Non-lambda third arg → OOF-COL4.
This is the same constraint as `map` and `filter`.

### Lambda parameter count

The lambda must have exactly 2 parameters:
```
(acc, elem) -> body
```

- `acc` (params[0]) — bound to `Acc` type (from seed)
- `elem` (params[1]) — bound to `T` type (from `element_type_from_collection(collection_arg_type)`)

Lambda with fewer or more than 2 params → OOF-COL4.

### Lambda body forms

Both app fixtures are supported:

**Single-expression body** (bookkeeping fixture):
```
fold(txs, 0.00, (acc, tx) -> acc + 0.00)
```

**Block-body** (ERP fixture):
```
fold(matching_routes, 999999.0, (acc, r) ->
  if r.cost_per_kg < acc {
    r.cost_per_kg
  } else {
    acc
  }
)
```

The `infer_lambda_body` helper (being added in LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P3)
handles both forms. Fold uses the same helper with 2-param binding instead of 1-param.

### Lambda binding mechanism

```ruby
acc_type  = type_ir(seed_literal.fetch("type_tag", "Unknown"))
elem_type = element_type_from_collection(collection_arg_type)
local_symbols = symbol_types.merge(acc_param => acc_type, elem_param => elem_type)
lambda_body_type = infer_lambda_body(lambda_node, local_symbols, ...)
```

No new type-system constructs. No `Fn[Acc, T, Acc]` type. Pure local scope extension.

---

## 8. Lambda Return Type and Diagnostics

### Q7: Must the lambda return type equal the accumulator type?

**Yes — the lambda return type must equal `Acc`.** This is a correctness requirement, not
a style preference. If the lambda returns a different type, the fold is ill-typed: the
accumulator passed to the next iteration would have the wrong type.

**Diagnostic:** OOF-COL4 is emitted when the inferred lambda body type is neither equal
to `Acc` nor `Unknown`.

Permissive cases (no diagnostic):
- Lambda body type == Acc type: correct
- Lambda body type == Unknown: Unknown propagates (permissive)
- Acc type == Unknown (seed not a literal): Unknown propagates (permissive)

Strict case (OOF-COL4 emitted):
- Lambda body type != Acc type AND neither is Unknown

This is stricter than map (which does not require lambda return type == collection element
type) and similar to filter's predicate check. The strictness is justified: a fold with
mismatched accumulator type would accumulate incorrectly on every iteration.

---

## 9. Difference from `fold_stream`

`fold_stream` and `stdlib.collection.fold` are **entirely separate** — different paths,
different semantics, different contexts.

| Property | `stdlib.collection.fold` | `fold_stream` |
|----------|--------------------------|---------------|
| Input | `Collection[T]` | Stream reference (T3 context) |
| Path | `infer_call` (regular compute) | `handle_t3_variant` (PROP-042 T3 decreases evidence) |
| Context | Any contract body | `decreases fold_stream(...)` evidence only |
| OOF codes | OOF-COL4 | OOF-S3 |
| CORE check | Implicit (fold is CORE-only) | Explicit (OOF-S3 via `check_fold_stream_body`) |
| Entry contract | `stdlib.collection.fold` | Not an stdlib entry; fold_stream is a T3 primitive |
| In inventory | This proposal | No |

Adding `when "fold"` to `infer_call` (P2 scope) does not touch `handle_t3_variant`.
The two paths are structurally separate.

---

## 10. Entry Contract

### stdlib.collection.fold

```json
{
  "canonical_name": "stdlib.collection.fold",
  "semantic_ir_name": "stdlib.collection.fold",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "fold" }],
  "category": "collection",
  "lifecycle_status": "proof-local",
  "semantic_stability": "experiment-pass",
  "lowering_status": "single-toolchain-partial",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total: empty collection → seed value returned unchanged",
  "type_params": ["T", "Acc"],
  "input_signature": ["Collection[T]", "Acc", "(Acc, T) -> Acc"],
  "output_signature": "Acc",
  "diagnostics": ["OOF-COL4"],
  "failure_behavior": "none; arity mismatch → OOF-COL4; non-lambda third arg → OOF-COL4; non-Collection first arg → OOF-COL4; lambda param count != 2 → OOF-COL4; lambda return type mismatch vs Acc → OOF-COL4",
  "authority_surface": "none",
  "proof_lineage": [
    "Ch8 §8.4 collection kernel",
    "LAB-STDLIB-COLLECTION-P1 (64/64 PASS — SPLIT verdict, fold to Group B)",
    "LAB-STDLIB-FOLD-P1 (50/50 PASS — ACCEPT verdict)",
    "bookkeeping/ledger.ig fold(txs, 0.00, (acc,tx)->acc+0.00) fixture",
    "erp_logistics/optimizer.ig fold(matching_routes, 999999.0, (acc,r)->if...) fixture",
    "fold_stream_result_type seed-type-tag pattern (typechecker.rb:1622)",
    "Rust lab typechecker fold dispatch (line 3233; seed type return; no lambda inference)"
  ],
  "examples": [
    "fold([1, 2, 3], 0, (acc, x) -> acc + x) -> 6",
    "fold(routes, 999999.0, (acc, r) -> if r.cost < acc { r.cost } else { acc }) -> Float",
    "fold(txs, 0.00, (acc, tx) -> acc + tx.amount) -> Decimal"
  ],
  "compatibility_note": "Bare source alias 'fold' accepted. Inline lambda only; no named-fn reference form in v0. 2-param lambda required: (acc, elem) — acc bound to Acc type from seed, elem bound to element type T from collection. Rust TC dispatches fold but does not infer lambda body type — seed-type result only. Ruby TC currently emits OOF-TY0; P2 adds regular-call dispatch. fold_stream (T3 path) is entirely separate and unaffected.",
  "owner_surface": "Ch8 §8.4",
  "entry_digest": null
}
```

**Critical invariant check:** `semantic_ir_name == canonical_name` → `"stdlib.collection.fold" == "stdlib.collection.fold"` ✓  
**No legacy_sir:** Ruby TC currently emits `OOF-TY0 "Unknown function: fold"` — no prior stable SIR name from canon Ruby pipeline. Rust TC emits bare `fold` but this is a Rust lab gap (same `annotated_expr: None` pattern as map/filter/count), not a canon SIR name.

---

## 11. Questions Answered

### Q1. Canonical name?

`stdlib.collection.fold`. Follows the `stdlib.<category>.<fn>` schema.

### Q2. Is bare `fold` accepted as source alias?

**Yes.** Both app fixtures use bare `fold`. The alias kind is `source_alias`. This is
the same pattern as `map`, `filter`, `count`, `map_get`, `or_else`.

### Q3. Exact input types?

Three arguments:
1. `Collection[T]` — input collection (first arg)
2. `Acc` — seed value; determines accumulator type from literal `type_tag` (second arg)
3. `(Acc, T) → Acc` — accumulator function; must be an inline lambda with 2 params (third arg)

Arity = 3. Wrong arity → OOF-COL4. Non-lambda third arg → OOF-COL4.

### Q4. How is accumulator type determined?

From the **seed literal's `type_tag`** (arg[1]). This reuses the `fold_stream_result_type`
pattern already in the Ruby TC at line 1622. If the seed is not a literal, `Acc` = Unknown
(permissive degradation). No new mechanism is needed.

### Q5. Required lambda shape?

Inline lambda `(acc, elem) -> body` at the call site. Exactly 2 params required.
`acc` is bound to `Acc` type; `elem` is bound to element type `T` from `element_type_from_collection`.
Both single-expression and block-body lambdas are supported.

### Q6. Are inline lambdas the only v0 callable?

**Yes.** Named function references are not supported in v0. Non-lambda third arg → OOF-COL4.
This is the same constraint as map/filter. Named fn refs are deferred to a future extension
when `Fn[Acc,T,Acc]` types or equivalent are available.

### Q7. Does lambda return type have to equal accumulator type?

**Yes.** Lambda return type must equal `Acc` (or be `Unknown` for permissive propagation).
Mismatch → OOF-COL4. This is stricter than map but correct: a fold with mismatched
accumulator type would be structurally ill-typed.

### Q8. What happens if lambda params mismatch?

Lambda param count != 2 → OOF-COL4. The message should indicate expected 2 params.
Non-lambda third arg → OOF-COL4. Named function ref as third arg → OOF-COL4 (same code).

### Q9. How does this differ from `fold_stream`?

`fold_stream` is a T3 decreases-evidence primitive operating on stream references via
`handle_t3_variant` (PROP-042). `stdlib.collection.fold` is a regular compute-call
collection helper dispatched via `infer_call`. The two paths are completely separate.
Adding `when "fold"` to `infer_call` does not touch `handle_t3_variant`. See §9 above.

### Q10. What OOF-COL code(s) are reserved?

**OOF-COL4** covers all fold-family errors. Reserved in `LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1`.

| Trigger | Code |
|---------|------|
| Arity mismatch (not exactly 3 args) | OOF-COL4 |
| Non-lambda third argument | OOF-COL4 |
| Non-Collection, non-Unknown first argument | OOF-COL4 |
| Lambda param count != 2 | OOF-COL4 |
| Lambda return type != Acc (strict check) | OOF-COL4 |

OOF-COL5 remains reserved for sum-family errors. OOF-COL4 covers all fold-family errors.
Sub-codes (OOF-COL4a, OOF-COL4b, etc.) may be defined in P2 if distinct message taxonomy
is warranted. The P2 implementation author decides whether to use a single OOF-COL4 with
varied messages or sub-codes.

### Q11. Does fold enter `stdlib-inventory.json` immediately or after implementation?

**After implementation.** The entry contract above (§10) defines the canonical record.
Actual inventory file edits are **P2 scope** (after Ruby TC implementation proof), following
the same pattern as map/filter/count:

- Proposal authoring (this card) → entry contract defined, reserved, governed
- P2 implementation planning → implementation plan + proof matrix
- P3 Ruby canon implementation proof → inventory amendment authorized as part of P3 scope
- Inventory `lifecycle_status` begins as `"proof-local"` and is amended to
  `"production-implemented"` after P3 PASS

This is the correct sequencing: the inventory records proof lineage and implementation
status, so it should only be updated once implementation is verified.

---

## 12. Toolchain Status

### Ruby TypeChecker (canon — `igniter-lang/lib/igniter_lang/typechecker.rb`)

| Operation | Current State | P2 Action |
|-----------|--------------|-----------|
| `fold` (regular call) | OOF-TY0 "Unknown function: fold" | Add `COLLECTION_FOLD_FN` / `infer_fold_call` dispatch; OR extend `COLLECTION_HOF_FNS` from P3 |
| `fold_stream` (T3) | Dispatched correctly via `handle_t3_variant` | Unaffected |

**Readiness preconditions confirmed:**
- `element_type_from_collection` at ~line 1825 (extracts T from Collection[T])
- Seed type from `type_tag` field at ~line 1628 (proven pattern: `fold_stream_result_type`)
- `infer_lambda_body` (P3 addition: handles both single-expression and block-body forms)
- `collection_type_ir_from` at ~line 2301 (not needed for fold — result is Acc, not Collection[Acc])

**Insertion point:** After `infer_collection_hof_call` (P3 map/filter/count) in the
`infer_call` dispatch and private methods section. Exact line TBD in P2 planning.

**Implementation sketch (P2 scope):**
```ruby
def infer_fold_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  # Arity check: must be exactly 3 args
  unless args.length == 3
    type_errors << oof("OOF-COL4", "fold requires 3 arguments (collection, seed, lambda), got #{args.length}", node_name)
    return typed_expr("call", type_ir("Unknown"), [], "fn" => "stdlib.collection.fold", "args" => [])
  end

  # Infer collection arg (arg[0])
  collection_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  collection_type = collection_arg.fetch("result_type")

  # Non-Collection first arg check
  unless type_name(collection_type) == "Collection" || type_name(collection_type) == "Unknown"
    type_errors << oof("OOF-COL4", "fold first argument must be Collection, got #{type_name(collection_type)}", node_name)
    return typed_expr("call", type_ir("Unknown"), [], "fn" => "stdlib.collection.fold", "args" => [])
  end

  # Accumulator type from seed literal (arg[1])
  seed_node = args[1]
  acc_type = if seed_node.fetch("kind", nil) == "literal"
    type_ir(seed_node.fetch("type_tag", "Unknown"))
  else
    infer_expr(seed_node, symbol_types, type_errors, type_warnings, node_name).fetch("result_type")
  end

  # Lambda arg (arg[2]): must be a lambda
  lambda_node = args[2]
  unless lambda_node.fetch("kind", nil) == "lambda"
    type_errors << oof("OOF-COL4", "fold third argument must be a lambda, got #{lambda_node.fetch("kind", "unknown")}", node_name)
    return typed_expr("call", acc_type, [], "fn" => "stdlib.collection.fold", "args" => [])
  end

  # Lambda must have exactly 2 params
  params = lambda_node.fetch("params", [])
  unless params.length == 2
    type_errors << oof("OOF-COL4", "fold lambda must have exactly 2 parameters (acc, elem), got #{params.length}", node_name)
    return typed_expr("call", acc_type, [], "fn" => "stdlib.collection.fold", "args" => [])
  end

  # Bind params: acc → Acc, elem → T
  elem_type = element_type_from_collection(collection_type)
  local_symbols = symbol_types.merge(params[0] => acc_type, params[1] => elem_type)
  lambda_body_type = infer_lambda_body(lambda_node, local_symbols, type_errors, type_warnings, node_name)

  # Lambda return type must match Acc
  unless type_name(lambda_body_type) == type_name(acc_type) ||
         type_name(lambda_body_type) == "Unknown" ||
         type_name(acc_type) == "Unknown"
    type_errors << oof("OOF-COL4",
      "fold lambda return type #{type_name(lambda_body_type)} does not match accumulator type #{type_name(acc_type)}",
      node_name)
  end

  # Result type = Acc
  typed_expr("call", acc_type, [], "fn" => "stdlib.collection.fold", "args" => [])
end
```

**SIR fn emission:** `"fn" => "stdlib.collection.fold"` (qualified canonical name).
The generic `semantic_expr` in `semanticir_emitter.rb` preserves the `fn` field verbatim.
`semantic_ir_name == canonical_name` is satisfied automatically. Zero emitter changes.

### Rust TypeChecker (lab — `igniter-lab/igniter-compiler/src/typechecker.rs`)

| Current dispatch (line 3233) | Status |
|-----------------------------|--------|
| Accepts `fold`; returns `typed_args[1].resolved_type` (seed type) | Correct result type |
| No arity check | Gap — `fold(col, seed)` silently accepted |
| Lambda params not bound to Acc/T | Gap — no element type or acc type binding |
| Lambda body not inferred | Gap — no return type check |
| SIR emits bare `fold` (not `stdlib.collection.fold`) | Gap — same `annotated_expr: None` pattern as map/filter/count |

All four gaps are Rust parity scope, not blockers for Ruby TC implementation.

---

## 13. Design Decisions Locked

1. **Canonical name:** `stdlib.collection.fold` — follows `stdlib.<category>.<fn>` schema
2. **Source alias:** bare `fold` — both app fixtures use bare names; no qualified-only policy
3. **3-arg signature** — `Collection[T] × Acc × ((Acc, T) → Acc) → Acc`; arity = 3 is mandatory
4. **Acc from seed literal** — seed type_tag bootstrap; reuses `fold_stream_result_type` pattern
5. **Inline lambda only** — 2 params required; no named fn refs; no `Fn[Acc,T,Acc]` type
6. **Lambda return type == Acc** — OOF-COL4 on mismatch (strict); Unknown propagates permissively
7. **Result type = Acc (scalar)** — NOT `Collection[Acc]`; distinguishes fold from map
8. **OOF-COL4 covers all fold errors** — single code (sub-codes optional in P2)
9. **OOF-COL5 reserved for sum** — fold does not claim it
10. **fold_stream unaffected** — separate T3 path; no changes to `handle_t3_variant`
11. **Inventory edits deferred to P2/P3** — entry contract defined here, file edit after implementation proof
12. **`semantic_ir_name == canonical_name`** — no `legacy_sir`; Ruby TC currently emits OOF-TY0 (not a stable SIR name)
13. **sum stays separate** — fold does not derive or replace sum; LAB-STDLIB-SUM-P1 is independent

---

## 14. Authority Closed

- No Ruby TypeChecker implementation (P2 scope)
- No `fold_stream` changes (T3 path is unaffected)
- No `stdlib.collection.sum` (separate card)
- No Rust TypeChecker changes
- No VM/runtime changes
- No `stdlib-inventory.json` file edits (P2/P3 scope)
- No lambda/function type-system additions (no Fn type)
- No app fixture changes
- No public compatibility promise beyond this proposal
- No `reduce`, `scan`, `groupBy`, `flat_map`, or other collection operations

---

## 15. Next Routes

**Primary:**  
`LANG-STDLIB-FOLD-PROP-P2` — Implementation planning for Ruby TC `infer_fold_call` dispatch.  
Authorized file: `typechecker.rb` only.  
Proof matrix target: ≥45 checks across sections:
- A: regression (string_core + typed_ref_p5 + stdlib_outcome_p3 + collection_map_filter_p3)
- B: fold basics (Integer, Decimal, Float seeds; correct Acc return type)
- C: type inference (lambda body type propagation; 2-param binding)
- D: diagnostics (OOF-COL4 arity / non-lambda / non-Collection / lambda mismatch)
- E: SIR names (`fn == "stdlib.collection.fold"` in SIR)
- F: app fixtures (bookkeeping fold; ERP fold; zero OOF-TY0)
- G: fold_stream coexistence (T3 path unaffected)
- H: authority closed (sum / map/filter/count unaffected; no VM)

**Parallel tracks (unblocked):**
- `LAB-STDLIB-SUM-P1` — sum readiness proof
- `LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P3` — Ruby canon implementation (map/filter/count)

**After P3 PASS (map/filter/count) and P2 PASS (fold planning):**
- `LANG-STDLIB-FOLD-PROP-P3` — Ruby canon implementation proof for fold
  - Proof runner: `experiments/stdlib_collection_proof/verify_stdlib_fold_p3.rb`
  - After P3 PASS: inventory amendment for `stdlib.collection.fold`
