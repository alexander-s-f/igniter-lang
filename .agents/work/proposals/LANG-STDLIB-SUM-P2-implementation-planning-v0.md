# LANG-STDLIB-SUM-P2 — Implementation Planning v0

**Track:** lang / stdlib / collection / numeric-boundary  
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE  
**Status:** CLOSED — READY FOR P3  
**Date:** 2026-06-12  
**Predecessors:** LAB-STDLIB-SUM-P1 (46/46 PASS, SPLIT-NUMERIC), LANG-STDLIB-SUM-PROP-P1 (proposal authored), LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P3 (61/61 PASS), LANG-STDLIB-ENTRY-CONTRACT-P3 (76/76 PASS)

---

## Goal

Plan the implementation for `stdlib.collection.sum(collection, :field)` in the Ruby TypeChecker.  
Answer all 13 required questions. Confirm READY FOR P3 or identify blocking split/hold conditions.

---

## Planning Decision: READY FOR P3

Single authorized file. One dispatch arm. One private method (~40 lines). No new constants required.  
All 13 questions answered. No numeric-field validation gate. No record-only constraint gate.

---

## Q1 — Exact Ruby TypeChecker insertion points?

**Two insertions in `lib/igniter_lang/typechecker.rb` only.**

### Insertion 1: Dispatch arm in `infer_call` (line ~893)

After the `when *COLLECTION_HOF_FNS.keys` arm (line 891–893), before the `when "or_else"` arm (line 894):

```ruby
when "sum"
  # LANG-STDLIB-SUM-PROP-P3: stdlib.collection.sum two-arg field-projection form
  infer_sum_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

### Insertion 2: Private method `infer_sum_call` (line ~2366)

After the closing `end` of `infer_collection_hof_call` (~line 2365), before `infer_lambda_body`:

```ruby
# LANG-STDLIB-SUM-PROP-P3: stdlib.collection.sum two-arg field-projection form.
# sum(Collection[T], Symbol) → F where F = @type_shapes[T][field_name]
# Scale-preserving for Decimal[N]: F is the raw declared type_ir, not an arithmetic result.
# OOF-COL1: arity != 2 | OOF-COL2: non-Collection first arg | OOF-COL5: non-Symbol second arg
# or field not found in type_shapes (unless element type Unknown).
def infer_sum_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  qualified = "stdlib.collection.sum"

  # ── OOF-COL1: arity must be 2 ────────────────────────────────────────────────
  unless args.length == 2
    type_errors << oof("OOF-COL1",
      "#{qualified}: expected 2 arguments (collection, :field), got #{args.length}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
  end

  # ── Infer collection argument ─────────────────────────────────────────────────
  collection_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  col_type_name  = type_name(collection_arg.fetch("resolved_type"))

  # ── OOF-COL2: first arg must be Collection or Unknown ────────────────────────
  unless col_type_name == "Collection" || col_type_name == "Unknown"
    type_errors << oof("OOF-COL2",
      "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                      "fn" => qualified, "args" => [collection_arg])
  end

  # ── OOF-COL5: second arg must be a Symbol literal ────────────────────────────
  sym_node = args[1]
  unless sym_node.is_a?(Hash) && sym_node.fetch("kind", nil) == "symbol"
    got = sym_node.is_a?(Hash) ? sym_node.fetch("kind", "non-symbol") : "non-symbol"
    type_errors << oof("OOF-COL5",
      "#{qualified}: second argument must be a Symbol field name (:field), got #{got}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                      "fn" => qualified, "args" => [collection_arg])
  end
  field_name = sym_node.fetch("value")

  # ── Field type lookup from @type_shapes ──────────────────────────────────────
  elem_type      = element_type_from_collection(collection_arg.fetch("resolved_type"))
  elem_type_name = type_name(elem_type)
  field_type     = @type_shapes.fetch(elem_type_name, {})[field_name]

  # ── OOF-COL5: missing field (unless element type Unknown) ────────────────────
  if field_type.nil?
    unless elem_type_name == "Unknown"
      type_errors << oof("OOF-COL5",
        "#{qualified}: field ':#{field_name}' not found in type #{elem_type_name}",
        node_name)
    end
    field_type = type_ir("Unknown")
  end

  typed_expr("call", field_type, collection_arg.fetch("deps", []),
             "fn" => qualified, "args" => [collection_arg])
end
```

**Total: ~45 lines in `typechecker.rb`. No other files.**

---

## Q2 — Should sum join COLLECTION_HOF_FNS or have a separate scalar helper?

**Separate dispatch — `COLLECTION_HOF_FNS` is NOT extended.**

Reason: `COLLECTION_HOF_FNS` drives a homogeneous lambda-dispatch pattern. All three entries (map/filter/count) use `arity` + `has_lambda` flags, and `infer_collection_hof_call` assumes the second arg (when arity == 2) is a lambda. Sum's second arg is a Symbol, not a lambda — a fundamentally different shape.

Adding `has_symbol: true` to HOF_FNS would add a second branching flag to an already-clean method, producing asymmetric logic that only applies to sum. The cleaner precedent (matching `or_else`/`infer_outcome_call`) is a dedicated `when "sum"` arm + dedicated `infer_sum_call` method.

This also avoids adding `"sum"` to `COLLECTION_HOF_FNS.keys`, which would accidentally register it as a HOF and create confusion for future readers.

---

## Q3 — How to validate arity == 2?

```ruby
unless args.length == 2
  type_errors << oof("OOF-COL1",
    "#{qualified}: expected 2 arguments (collection, :field), got #{args.length}",
    node_name)
  return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
end
```

Fires for zero args, one arg (bare `sum(coll)`), and three or more args. Message includes the qualified canonical name (matching the OOF-COL1 pattern from `infer_collection_hof_call`).

---

## Q4 — How to validate first arg is Collection[Record]?

Infer the first arg, check the resolved type name for `"Collection"` or `"Unknown"`:

```ruby
collection_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
col_type_name  = type_name(collection_arg.fetch("resolved_type"))
unless col_type_name == "Collection" || col_type_name == "Unknown"
  type_errors << oof("OOF-COL2",
    "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
    node_name)
  return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                    "fn" => qualified, "args" => [collection_arg])
end
```

No constraint that T is a user-declared Record type. If T is a primitive (e.g., `Collection[Integer]`) that isn't in `@type_shapes`, the field lookup will return `nil` → OOF-COL5 "field not found". The type need only be a `Collection` — record-membership is checked implicitly via the field lookup.

---

## Q5 — How to validate second arg is Symbol field name?

Check the raw AST node directly — do NOT call `infer_expr` on it:

```ruby
sym_node = args[1]
unless sym_node.is_a?(Hash) && sym_node.fetch("kind", nil) == "symbol"
  got = sym_node.is_a?(Hash) ? sym_node.fetch("kind", "non-symbol") : "non-symbol"
  type_errors << oof("OOF-COL5",
    "#{qualified}: second argument must be a Symbol field name (:field), got #{got}",
    node_name)
  return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                    "fn" => qualified, "args" => [collection_arg])
end
field_name = sym_node.fetch("value")
```

The parser produces `{ "kind" => "symbol", "value" => "bid_decimal" }` for `:bid_decimal` (confirmed: `typechecker.rb:792-793`, `parser.rb:1871`). Checking `args[1]` directly gives us `field_name` as a plain string without an `infer_expr` round-trip. Symbol literals don't benefit from type inference — their value is static.

---

## Q6 — How to lookup field type from record shape?

```ruby
elem_type      = element_type_from_collection(collection_arg.fetch("resolved_type"))
elem_type_name = type_name(elem_type)
field_type     = @type_shapes.fetch(elem_type_name, {})[field_name]
```

`element_type_from_collection` (line 1839): extracts the first type param from `Collection[T]`. Returns `type_ir("Unknown")` if no params or non-Hash.

`@type_shapes` (built at line 215-221): maps type_name → {field_name → type_ir}. Populated once per `typecheck` call from `classified_program["type_declarations"]`. Each field's type_ir was produced by `type_ir(field.fetch("type_annotation"))` — preserving full params (scale for `Decimal[N]`, key/value for `Map[K,V]`, etc.).

`@type_shapes.fetch(elem_type_name, {})` returns `{}` if the element type is not a declared record (e.g., primitive, Unknown, Collection nesting). `[field_name]` then returns `nil` → OOF-COL5.

---

## Q7 — How to reject missing field?

```ruby
if field_type.nil?
  unless elem_type_name == "Unknown"
    type_errors << oof("OOF-COL5",
      "#{qualified}: field ':#{field_name}' not found in type #{elem_type_name}",
      node_name)
  end
  field_type = type_ir("Unknown")
end
```

**Unknown carveout:** if `elem_type_name == "Unknown"` (e.g., `Collection[Unknown]` or bare `Collection`), we cannot look up the field — the element type is not resolved. Return Unknown permissively without error. This preserves the Unknown-propagates-permissively invariant used throughout the TC.

The Rust TC also silently returns `Unknown` when the element type is unresolved (falls through to `let resolved = type_ir("Decimal")` default, but since the two-arg path requires a field match, it returns `resolved` = Unknown when the field lookup misses). Ruby matches this behavior while also emitting OOF-COL5 for the non-Unknown case, which is an improvement over the Rust TC.

---

## Q8 — How to reject non-numeric field, or deferred?

**Deferred to P4+. No numeric constraint in v0.**

The TC returns the declared field type as-is. A field declared `label: Text` would be accepted: `sum(items, :label)` → resolved type `Text`. Runtime behavior is undefined and would error, but that is outside TC scope in v0.

This matches the Rust TC (no numeric validation on the field type). The proposal explicitly locks this: "no numeric constraint on field type in v0" (LANG-STDLIB-SUM-PROP-P1, Design Decision 8).

---

## Q9 — How to preserve Decimal[N] scale?

**Preservation is automatic — zero special handling required.**

`@type_shapes` stores full `type_ir` hashes. For a field declared `bid_decimal: Decimal[2]`, `type_ir("Decimal[2]")` produces `{ "name" => "Decimal", "params" => [{ "name" => "2", "params" => [] }] }` (confirmed via `type_ir` at line 1204-1210). Returning `field_type` directly returns the complete hash including the scale param `"2"`.

This is the structural field lookup insight from the proposal: scale preservation is a free property of the implementation, not an arithmetic computation.

---

## Q10 — Empty collection semantics: implementation value or type-only planning?

**Type-only in P3.** The return type is `F` (the declared field type). No `Option[F]` wrapper. No identity element.

The TC declares what the type OF `sum(coll, :field)` IS — not what the runtime VALUE would be on an empty collection. A bookkeeping invariant (ledger entries always exist before contract execution) makes this safe in the primary use case. Runtime empty-collection behavior is deferred to P4+.

P3 scope: TypeChecker returns `field_type`. P4+ scope: runtime identity element (0 for Integer/Decimal) or explicit `Option[F]` wrapping if spec changes.

---

## Q11 — Canonical SIR name?

`"stdlib.collection.sum"` — the fully qualified canonical name.

`infer_sum_call` emits `"fn" => "stdlib.collection.sum"` in every `typed_expr` return. The generic `semantic_expr` in `semanticir_emitter.rb` preserves the `fn` field verbatim (confirmed pattern from map/filter/count/outcome implementations) — zero emitter changes required.

This closes the Rust parity gap: Rust TC currently emits bare `"sum"` (documented in LAB-STDLIB-SUM-P1 D-06). Ruby TC will emit the qualified name from day one.

---

## Q12 — OOF-COL5 exact triggers?

| Trigger | Message |
|---------|---------|
| Second arg is not a Symbol node | `"stdlib.collection.sum: second argument must be a Symbol field name (:field), got <kind>"` |
| Symbol arg but field not in @type_shapes | `"stdlib.collection.sum: field ':<field_name>' not found in type <TypeName>"` |

**Note:** OOF-COL5 does NOT fire when `elem_type_name == "Unknown"` (element type unresolved). In that case, Unknown is returned permissively.

OOF-COL1 and OOF-COL2 are shared (same codes as map/filter/count, matching messages with the qualified name prefix).

---

## Q13 — Proof matrix for P3?

**8 sections / 51 checks. Proof runner: `igniter-lang/experiments/stdlib_sum_proof/verify_stdlib_sum_p3.rb`**

### Section A — Regression (6)

| ID | Fixture | Expected |
|----|---------|----------|
| A-01 | string_core proof (smoke) | prior PASS count unchanged |
| A-02 | typed_contract_ref_p5 proof (smoke) | prior PASS count unchanged |
| A-03 | `map(leads, l -> l.bid_decimal)` | no OOF-TY0 — HOF dispatch unaffected |
| A-04 | `filter(leads, l -> l.bid_amount > 0)` | no OOF-TY0 — HOF dispatch unaffected |
| A-05 | `count(leads)` | Integer return — count dispatch unaffected |
| A-06 | `fold(leads, 0, (acc, l) -> acc)` | OOF-TY0 "Unknown function: fold" — fold not accidentally added |

### Section B — Dispatch registration (6)

| ID | Check |
|----|-------|
| B-01 | `"sum"` NOT a key in `COLLECTION_HOF_FNS` (source text check) |
| B-02 | `when "sum"` arm present in `infer_call` method body (source text check) |
| B-03 | `infer_sum_call` method defined in TC source (source text check) |
| B-04 | `infer_sum_call` returns qualified name `"stdlib.collection.sum"` (source text check) |
| B-05 | `sumBy` → OOF-TY0 (not dispatched) |
| B-06 | `"sum"` absent from `OUTCOME_STDLIB_FNS` keys (source text check) |

### Section C — Arity validation (6)

| ID | Call | Expected |
|----|------|----------|
| C-01 | `sum()` | OOF-COL1 |
| C-02 | `sum(leads)` | OOF-COL1 |
| C-03 | `sum(leads, :field, :extra)` | OOF-COL1 |
| C-04 | `sum(leads, :bid_decimal)` (valid) | no OOF-COL1 |
| C-05 | OOF-COL1 message contains `"stdlib.collection.sum"` | confirmed |
| C-06 | `sum(leads)` one-arg → OOF-COL1 (not OOF-TY0) | OOF-TY0 absent |

### Section D — Collection arg validation (6)

| ID | First arg | Expected |
|----|-----------|----------|
| D-01 | `sum(42, :field)` integer literal | OOF-COL2 |
| D-02 | `sum("text", :field)` string literal | OOF-COL2 |
| D-03 | OOF-COL2 message contains `"stdlib.collection.sum"` | confirmed |
| D-04 | `sum(leads, :bid_decimal)` Collection[Lead] | no OOF-COL2 |
| D-05 | `sum(unknown_sym, :field)` where unknown_sym is Unknown | no OOF-COL2 (Unknown permissive) |
| D-06 | Unknown first arg produces Unknown return type | resolved_type name = "Unknown" |

### Section E — Symbol arg validation (6)

| ID | Second arg | Expected |
|----|------------|----------|
| E-01 | `sum(leads, "bid_decimal")` string literal | OOF-COL5 |
| E-02 | `sum(leads, 42)` integer literal | OOF-COL5 |
| E-03 | `sum(leads, :bid_decimal)` symbol | no OOF-COL5 |
| E-04 | OOF-COL5 non-Symbol message contains `"Symbol field name"` | confirmed |
| E-05 | Non-Symbol check fires before field lookup (no second OOF-COL5) | only one error |
| E-06 | OOF-COL5 rule code present in diagnostics | confirmed |

### Section F — Field lookup and return type (8)

| ID | Call | Expected |
|----|------|----------|
| F-01 | `sum(leads, :bid_decimal)` where `bid_decimal: Decimal[2]` | resolved_type = `Decimal[2]` |
| F-02 | `sum(items, :quantity)` where `quantity: Integer` | resolved_type = `Integer` |
| F-03 | `Decimal[2]` scale preserved — params[0].name = `"2"` | confirmed |
| F-04 | `sum(leads, :nonexistent)` | OOF-COL5 |
| F-05 | OOF-COL5 missing field message contains field name | confirmed |
| F-06 | `sum(Collection[Unknown], :any_field)` | no OOF-COL5, Unknown return |
| F-07 | SIR `fn` field = `"stdlib.collection.sum"` (qualified) | confirmed via typed result |
| F-08 | `sum(leads, :bid_decimal)` — no OOF-TY0 fired | confirmed (sum now dispatched) |

### Section G — OOF codes (7)

| ID | Code | Trigger | Expected |
|----|------|---------|----------|
| G-01 | OOF-COL1 | arity != 2 | confirmed |
| G-02 | OOF-COL2 | non-Collection first arg | confirmed |
| G-03 | OOF-COL5 | non-Symbol second arg | confirmed |
| G-04 | OOF-COL5 | field not found in type_shapes | confirmed |
| G-05 | no OOF-COL5 | valid field found | no OOF-COL5 |
| G-06 | no OOF-TY0 | valid sum call | OOF-TY0 absent |
| G-07 | no OOF-COL5 | element type is Unknown | no error |

### Section H — Authority closed (6)

| ID | Check | Expected |
|----|-------|----------|
| H-01 | `sum(amounts)` one-arg where `amounts: Collection[Decimal[2]]` | OOF-COL1 (not dispatched as one-arg form) |
| H-02 | `sumBy(leads, :bid_decimal)` | OOF-TY0 (not registered) |
| H-03 | `COLLECTION_HOF_FNS` unchanged — no "sum" key | confirmed (source check) |
| H-04 | No numeric constraint: `sum(items, :label)` where `label: Text` | no error — returns Text type |
| H-05 | No fold added — fold still OOF-TY0 | confirmed |
| H-06 | No VM/emitter changes — zero files changed other than `typechecker.rb` | confirmed |

**Total: 51 checks across 8 sections.**

---

## Summary: Three-Point Implementation Plan

| Point | Location | Change |
|-------|----------|--------|
| 1 | `infer_call` ~line 893 | Add `when "sum"` dispatch arm after `when *COLLECTION_HOF_FNS.keys` |
| 2 | After `infer_collection_hof_call` ~line 2366 | Add `infer_sum_call` private method (~45 lines) |
| 3 | No other changes | No constants / no emitter / no assembler / no parser / no VM |

**Authorized file for P3:** `lib/igniter_lang/typechecker.rb` only.

---

## Data Flow Summary

```
sum(leads, :bid_decimal)
  → when "sum" arm in infer_call
  → infer_sum_call(fn, args, ...)
    ├─ arity check (args.length == 2) or OOF-COL1
    ├─ infer_expr(args[0]) → collection_arg  [Collection[Lead]]
    ├─ type_name check (== "Collection" or "Unknown") or OOF-COL2
    ├─ args[1].kind == "symbol" check or OOF-COL5
    ├─ field_name = args[1]["value"]  →  "bid_decimal"
    ├─ element_type_from_collection → Lead
    ├─ @type_shapes["Lead"]["bid_decimal"]  →  Decimal[2] type_ir
    └─ typed_expr("call", Decimal[2], deps, "fn" => "stdlib.collection.sum")
```

---

## Regressions Required in P3

| Suite | Expected count | Notes |
|-------|---------------|-------|
| string_core_proof | PASS | standard smoke |
| verify_typed_contract_ref_p5 | 71/71 | cross-module typed refs |
| verify_stdlib_collection_map_filter_p3 | 61/61 | HOF dispatch unaffected |
| verify_stdlib_outcome_p3 | 60/60 | outcome helpers unaffected |

---

## Open Design Points (P4+)

1. **Numeric constraint on field type** — no constraint in v0; deferred to P4+ or LAB-STDLIB-NUMERIC-P1
2. **Empty-collection runtime value** — TC returns declared field type; runtime identity element (0 for numeric) or `Option[F]` deferred to P4+
3. **Rust SIR parity** — Rust emits bare `"sum"` (not `"stdlib.collection.sum"`); Ruby will emit qualified; Rust parity fix is a separate card post-P3
4. **One-arg sum** — permanently blocked until LAB-STDLIB-NUMERIC-P1 + STAB-P4-OPERATOR-PARITY close

---

## Authority Closed

No Ruby TC implementation in this doc.  
No one-arg sum. No sumBy. No Decimal operator/literal. No fold implementation.  
No Rust parity work. No VM/runtime changes. No app fixture edits.  
No inventory edits (deferred to LANG-STDLIB-ENTRY-CONTRACT-P4+).
