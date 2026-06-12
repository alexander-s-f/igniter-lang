# LANG-STDLIB-SUM v0 — stdlib.collection.sum (field-projection form)

**Track:** stdlib / collection / numeric-boundary  
**Status:** authored-pending-review  
**Date:** 2026-06-12  
**Route:** PROPOSAL AUTHORING ONLY / NO IMPLEMENTATION  
**Predecessor proof:** LAB-STDLIB-SUM-P1 (46/46 PASS — SPLIT-NUMERIC)  
**Predecessor governance:** LAB-STDLIB-COLLECTION-P1 (64/64 PASS), LANG-STDLIB-ENTRY-CONTRACT-P1/P2/P3, LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P1

---

## 1. Context and Evidence Base

`LAB-STDLIB-SUM-P1` (46/46 PASS) determined a SPLIT-NUMERIC verdict for `stdlib.collection.sum`:

- **Split A (accepted, this proposal):** `sum(Collection[T], Symbol) -> DeclaredFieldType` — two-arg field-projection form
- **Split B (blocked):** `sum(Collection[T]) -> T` — one-arg bare form; requires LAB-STDLIB-NUMERIC-P1

This proposal governs Split A only.

The two-arg form is grounded by:
- `stdlib/collections.ig` spec: only defines the two-arg form `sum(Collection[T], Symbol) -> Decimal[S]`
- `stdlib_extension.ig` conformance fixture: `sum(leads, :bid_decimal)` where `bid_decimal: Decimal[2]`
- Rust TC dispatch (line 2667–2685): extracts field type via `type_shapes` — scale-preserving for declared `Decimal[N]` fields
- `LAB-STDLIB-COLLECTION-P1` (Group C sum classification) + `LAB-STDLIB-FOUNDATION-P1` (Ch8 §8.4 kernel)

**Core insight** (from LAB-STDLIB-SUM-P1): The two-arg form is scale-preserving because the return type comes from the *declared record field type in type_shapes*, not from arithmetic type inference. `sum(leads, :bid_decimal)` returns `Decimal[2]` because `Lead.bid_decimal` is declared `Decimal[2]` — not because of any numeric sum-of-Decimal[2] rule. This decouples the proposal from STAB-P4-OPERATOR-PARITY.

---

## 2. Core Principle

**`stdlib.collection.sum` (two-arg form) is a field-projection aggregation — not a numeric-type function.**

It projects a named field from each element of a collection and declares the output type to be the declared type of that field. The type inference is purely structural: look up the field name in the element type's type shape, return the declared type.

The function does not:
- Execute arithmetic at type-checking time
- Depend on numeric operator parity between toolchains
- Grant authority or consume capabilities
- Mutate its input
- Access storage or external state

The caller owns all downstream use of the result. The helper only projects and declares the output type.

---

## 3. Scope of v0

**Accepted (this proposal):**

`stdlib.collection.sum(Collection[T], Symbol) -> F` where F is the declared type of the Symbol-named field in T.

**Explicitly excluded from v0:**

- One-arg bare form `sum(Collection[T]) -> T` — blocked by spec absence + Rust scale-stripping bug + numeric constraint requirement; route: LAB-STDLIB-NUMERIC-P1
- `sumBy` as a separate function name — not in any fixture or spec; two-arg sum IS sum-by-field under the `sum` name
- `sum(Collection[T], predicate)` predicate-sum — not defined, not pressured, not scoped
- Fold-derived sum specification — noted as derivation relationship only; implementation is independent
- Decimal literal/operator semantics — not affected; return type is purely structural
- Identity element for empty collection — deferred to implementation planning (P2)
- `avg`, `min`, `max` field-projection variants — separate future entries

---

## 4. Call Shape and Input Types

`sum(collection, :field_name)` — arity 2.

| Argument | Type | Notes |
|----------|------|-------|
| First | `Collection[T]` | T must be a record type with named fields |
| Second | `Symbol` (`:field_name`) | Field name to project; must be a literal Symbol at call site |

No lambda argument. This is a departure from the `map`/`filter`/`fold` HOF pattern. The second argument is a Symbol field selector, not a callable.

**Permissive on Unknown:** If first argument type is `Unknown`, return `Unknown` (consistent with all existing stdlib helpers).

---

## 5. Questions To Answer

### Q1. Canonical name?

`stdlib.collection.sum`

Follows the `stdlib.<category>.<fn>` schema. The category is `collection` (not `numeric`), because the primary argument is a `Collection` and the operation is a collection aggregation. The numeric nature of the result is context-dependent (the field type may be Integer, Decimal[N], or other).

### Q2. Source alias: is bare `sum` accepted?

**Yes.** All app fixtures use bare `sum`. The stdlib spec (`collections.ig`) uses `sum`. The Rust TC dispatches `sum`. The alias list contains exactly one entry: `{ "kind": "source_alias", "name": "sum" }`.

No method-call form (`collection.sum(:field)`) — Igniter does not support method syntax.  
No category-prefixed form (`collection_sum`) — unnecessary and not used anywhere.

### Q3. Exact input shape?

Two arguments:
1. `Collection[T]` — collection of record elements with named fields
2. `Symbol` — field name literal (e.g., `:bid_decimal`, `:quantity`)

Arity is exactly 2. Not 1 (the one-arg form is blocked). Not 3+ (no such form defined).

### Q4. Must second argument be a Symbol field name?

**Yes — for type-checking purposes.** The second argument must be a Symbol literal (AST kind `"symbol"`, or `"atom"` depending on parser representation). Non-Symbol second arguments (e.g., a Text string, an Integer, a variable reference) should produce OOF-COL5.

In v0, the field name must be statically known at the call site — it cannot be dynamically computed. This is consistent with the existing `map_get` pattern and with the Rust TC's Symbol extraction: `if let Expr::Symbol { value } = &args[1]`.

### Q5. What if field is missing from the element type?

If the field name from the Symbol does not exist in the element type T's type shape, the implementation should produce OOF-COL5 (sum-specific error: missing field).

**Permissive fallback considered but rejected for P2:** The Rust TC silently falls back to bare `Decimal` when the field is not found in type_shapes (it initializes the default to `Decimal` before attempting field lookup). This silent fallback produces a misleading return type. The Ruby TC should produce OOF-COL5 instead — honest behavior is preferred over silent fallback.

However, the P2 planning doc may choose strict (OOF-COL5) or permissive (return Unknown) depending on what is implementable. The proposal recommends strict.

### Q6. What if the field type is non-numeric?

For v0 type-checking purposes, the return type is the declared field type, regardless of whether that type is numeric. `sum(items, :label)` where `label: Text` would return `Text` at type-checking time.

**Rationale:** Adding a numeric-type constraint requires defining what counts as "numeric" in the type system — Integer only? Integer and Decimal[N]? This is the same question that blocks the one-arg form. For the field-projection two-arg form, the scale-preserving value is in returning the *declared type*, which for all current fixtures is `Decimal[2]` or `Integer`. Requiring the field to be numeric forces a numeric type constraint that is not yet defined.

**Open item for P2:** The implementation author may choose to add a numeric-type validation that warns (non-error) on non-numeric field types. This proposal does not require it.

### Q7. Is return type exactly the declared field type?

**Yes.** The return type is `F` = the type of the Symbol-named field in T's type shape.

For `sum(leads, :bid_decimal)` where `Lead.bid_decimal: Decimal[2]` → return type is `Decimal[2]`.  
For `sum(items, :quantity)` where `Item.quantity: Integer` → return type is `Integer`.  
For `sum(records, :value)` where `Record.value: Text` → return type is `Text` (v0, no numeric constraint).

If T is Unknown (collection element type not determined) → return type is Unknown.  
If field is not found in T's type shape → OOF-COL5, return type is Unknown.

### Q8. What does this imply for Decimal[2] scale preservation?

Scale is fully preserved with no numeric-arithmetic reasoning required. The scale `[2]` in `Decimal[2]` comes from the field's declared type in the type shape — it is a stored declaration, not a computed result. The type checker retrieves it via `@type_shapes[type_name][field_name]` and returns it verbatim.

This is the core reason Split A is unblocked while Split B remains blocked: the two-arg form bypasses numeric arithmetic type inference entirely. There is no sum-of-Decimal[2]-is-Decimal[2] rule in play; it is a field lookup that returns `Decimal[2]` because that was declared.

### Q9. Empty collection behavior: result value or deferred?

**Deferred to P2 (implementation planning).** The return *type* is the declared field type (not `Option[F]`). What *value* the runtime returns for `sum` over an empty collection is implementation-defined in v0.

Options for P2 to decide:
- Return 0 of the appropriate type (identity element convention — requires knowing what "0" means for the field type)
- Return runtime error (OOF-SUM1 at execution time, not type-checking time)
- Defer until runtime identity element is defined via a separate language feature

The proposal records the return type as non-Option `F`. The totality status is `"partial"` — type is defined, empty-collection runtime behavior is open.

### Q10. How does this relate to Rust current behavior?

**Rust TC (line 2667–2685):**
- Two-arg form: working correctly. Extracts field name from Symbol arg, looks up in `type_shapes`, returns declared field type. Scale-preserving.
- One-arg form: working but returning bare `Decimal` (scale-stripping bug — not governed by this proposal)
- SIR fn name: bare `"sum"` (not qualified `"stdlib.collection.sum"`) — parity gap

**This proposal:**
- Aligns with Rust two-arg behavior for the accepted form
- Ruby TC will emit `"fn" => "stdlib.collection.sum"` (qualified), closing the SIR name gap on the canon side
- Rust SIR parity (emitting `stdlib.collection.sum` instead of bare `sum`) is a separate Rust parity card after Ruby implementation is proved

### Q11. How does this relate to the Ruby TC gap?

Ruby TC currently: no dispatch for any sum call → OOF-TY0 for both forms.

P2 (implementation planning) will add:
- A new dispatch constant (separate from `COLLECTION_HOF_FNS` — sum's second argument is a Symbol, not a lambda)
- An `infer_sum_call` private method (or extension to `infer_collection_hof_call`) that performs:
  1. Arity check (must be 2): OOF-COL1 if not
  2. First arg type check (must be Collection[T] or Unknown): OOF-COL2 if non-Collection
  3. Second arg check (must be Symbol literal): OOF-COL5 if non-Symbol
  4. Extract element type T via `element_type_from_collection`
  5. Extract type name from T's type IR
  6. Look up `@type_shapes[type_name][field_name]`: OOF-COL5 if not found
  7. Return field type as output, emit `"fn" => "stdlib.collection.sum"`

The P2 planning doc will specify whether sum is bundled into `COLLECTION_HOF_FNS` (with a `has_symbol: true` flag) or handled via a separate `COLLECTION_SUM_FNS` constant or a direct dispatch. The proposal leaves this to P2.

### Q12. What OOF-COL codes are reserved?

OOF-COL5 is reserved for sum-specific errors (confirmed by LAB-STDLIB-COLLECTION-P1 and LAB-STDLIB-FOLD-P1 which reserved OOF-COL4 for fold).

| Code | Trigger | Active? |
|------|---------|---------|
| OOF-COL1 | Arity mismatch (not 2 args) | P2 — shared with HOF namespace |
| OOF-COL2 | Non-Collection first argument | P2 — shared with HOF namespace |
| OOF-COL5 | Sum-specific errors: non-Symbol second arg; field name not found in type shape | P2 |

OOF-COL3 (filter predicate non-Bool) and OOF-COL4 (fold-family errors) are reserved for their respective operations.

### Q13. What remains blocked behind LAB-STDLIB-NUMERIC-P1?

| Item | Blocked by |
|------|-----------|
| One-arg `sum(Collection[T]) -> T` | Absent from stdlib spec; Rust scale-stripping bug; numeric type constraint undefined |
| Numeric type constraint (T: Numeric) | STAB-P4-OPERATOR-PARITY — dual-toolchain numeric operator parity unsettled |
| Scale propagation arithmetic rules | Same — `Decimal[2] + Decimal[2] = Decimal[2]` is not dual-toolchain confirmed |
| Identity element specification (sum of empty collection returns 0) | Numeric constraint + type-dependent zero definition |
| `sumBy` as a separate function | No demand; two-arg `sum` IS sum-by-field under the `sum` name |
| `sum` with predicate (sumBy-where) | No demand; not pressured |

---

## 6. Entry Contract

### stdlib.collection.sum

```json
{
  "canonical_name": "stdlib.collection.sum",
  "semantic_ir_name": "stdlib.collection.sum",
  "legacy_sir": null,
  "aliases": [
    { "kind": "source_alias", "name": "sum" }
  ],
  "category": "collection",
  "lifecycle_status": "proof-local",
  "semantic_stability": "experiment-pass",
  "lowering_status": "single-toolchain-partial",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "partial: return type defined; empty-collection runtime behavior deferred to P2",
  "type_params": ["T", "F"],
  "input_signature": ["Collection[T]", "Symbol"],
  "output_signature": "F",
  "notes": "T = record element type of Collection; F = declared type of the Symbol-named field in T; F is determined by type-shape field lookup, not by arithmetic inference; scale-preserving for Decimal[N] fields; arity != 2 → OOF-COL1; non-Collection first arg → OOF-COL2; non-Symbol second arg → OOF-COL5; field name not found in T → OOF-COL5; T = Unknown → return Unknown (permissive)",
  "diagnostics": ["OOF-COL1", "OOF-COL2", "OOF-COL5"],
  "failure_behavior": "arity mismatch → OOF-COL1; non-Collection first arg → OOF-COL2; non-Symbol second arg → OOF-COL5; missing field in type shape → OOF-COL5",
  "authority_surface": "none",
  "proof_lineage": [
    "Ch8 §8.4 collection kernel",
    "LAB-STDLIB-COLLECTION-P1 (64/64 PASS — Group C sum classification)",
    "LAB-STDLIB-SUM-P1 (46/46 PASS — SPLIT-NUMERIC Split A accepted)",
    "stdlib/collections.ig: def sum(coll: Collection[T], field: Symbol) -> Decimal[S]",
    "stdlib_extension.ig conformance fixture: sum(leads, :bid_decimal) / sum(filter(leads,...), :bid_decimal)",
    "Rust TC dispatch (typechecker.rs line 2667-2685): two-arg scale-preserving via type_shapes"
  ],
  "examples": [
    "sum(leads, :bid_decimal) -> Decimal[2]  -- where Lead.bid_decimal: Decimal[2]",
    "sum(items, :quantity) -> Integer         -- where Item.quantity: Integer",
    "sum(filter(leads, l -> l.bid_amount > threshold), :bid_decimal) -> Decimal[2]"
  ],
  "compatibility_note": "This proposal covers ONLY the two-arg field-projection form: sum(Collection[T], Symbol) -> F. The one-arg bare form sum(Collection[T]) -> T is BLOCKED: absent from stdlib spec; Rust TC has scale-stripping bug (returns bare Decimal for Collection[Decimal[2]]); requires LAB-STDLIB-NUMERIC-P1 and STAB-P4-OPERATOR-PARITY. No legacy_sir: Ruby TC currently emits OOF-TY0 (no prior stable SIR name from canon Ruby pipeline). Rust TC emits bare 'sum' (parity gap — separate Rust parity card after Ruby implementation proved). sumBy is explicitly deferred — not a separate function name; no app fixture or spec uses sumBy.",
  "owner_surface": "Ch8 §8.4",
  "entry_digest": null
}
```

**Critical invariant check:** `semantic_ir_name == canonical_name` → `"stdlib.collection.sum" == "stdlib.collection.sum"` ✓  
**No legacy_sir:** Ruby TC emits OOF-TY0 for sum — no prior stable SIR name from the canon Ruby pipeline.

---

## 7. Signature Comparison: This Proposal vs Current Spec vs Blocked Form

| | This proposal (Split A) | `stdlib/collections.ig` spec | Split B (blocked) |
|-|------------------------|------------------------------|-------------------|
| Form | `sum(Collection[T], Symbol)` | `sum(Collection[T], Symbol)` | `sum(Collection[T])` |
| Return | `F` (declared field type) | `Decimal[S]` | `T` |
| Scale | Preserving (F is declared type) | `Decimal[S]` hardcoded | Requires arithmetic rule |
| Integer field | `Integer` (field type) | Not expressed | `Integer` (if T: Integer) |
| Text field | `Text` (v0, no numeric constraint) | Not expressed | Out of scope |
| Empty collection | Deferred (type is F, value TBD) | Implicit — no Option wrapper | Requires identity element |

**Note on spec return type `Decimal[S]`:** The `stdlib/collections.ig` spec declares the return as `Decimal[S]`, suggesting a scale-parameterized Decimal. This proposal generalizes to `F` (declared field type) to accommodate Integer fields and future record shapes. The spec's `Decimal[S]` is consistent with the all-Decimal[2] fixture evidence but is more restrictive than the entry contract's `F`. The P2 planning doc may choose to stay aligned with the spec by requiring a numeric field type, or accept the more general `F` approach of this proposal. This is explicitly marked as an **open design point for P2**.

---

## 8. Toolchain Status

### Ruby TypeChecker (canon — `igniter-lang/lib/igniter_lang/typechecker.rb`)

| Form | Current State | P2 Action |
|------|-------------|-----------|
| Two-arg `sum(coll, :field)` | OOF-TY0 Unknown function | Add dispatch + `infer_sum_call` private method |
| One-arg `sum(coll)` | OOF-TY0 Unknown function | NOT authorized in this card (Split B blocked) |

**Implementation note for P2 (informational — not a P1 decision):**

The two-arg sum requires a different dispatch pattern from `COLLECTION_HOF_FNS` (which is for lambda-based HOF operations). Sum's second argument is a Symbol, not a lambda. The P2 planning doc should specify one of:

- **Option A:** Extend `COLLECTION_HOF_FNS` with a `has_symbol: true` flag for sum; handle Symbol lookup in `infer_collection_hof_call`
- **Option B:** Separate `COLLECTION_SUM_FNS` constant + `infer_sum_call` private method

Either way, the field type lookup uses:
1. `element_type_from_collection(collection_type)` to extract T (already exists at ~line 1825)
2. Extract type name from T's type IR
3. `@type_shapes.fetch(type_name, {}).fetch(field_name, nil)` to get F

SIR emission: `typed_expr("call", F, ..., "fn" => "stdlib.collection.sum", "args" => [...])`  
`semantic_ir_name == canonical_name` is satisfied automatically via the qualified `fn` field.

### Rust TypeChecker (lab — `igniter-lab/igniter-compiler/src/typechecker.rs`)

| | Two-arg `sum(coll, :field)` | One-arg `sum(coll)` |
|-|-----------------------------|---------------------|
| **Dispatch** | Present (line 2667) | Present (line 2667, same arm) |
| **Return type** | Declared field type (scale-preserving) | Bare `Decimal` (scale-stripping gap) |
| **SIR fn name** | Bare `"sum"` (parity gap) | Bare `"sum"` (parity gap) |

**Rust parity gaps (post-P2 scope):**
1. SIR fn name: emit `"stdlib.collection.sum"` not bare `"sum"`
2. One-arg form: fix scale-stripping (not authorized here — Split B blocked)

---

## 9. Design Decisions Locked

1. **Bare source alias `sum` accepted** — all fixtures use bare `sum`; qualified-only policy not applied
2. **Two-arg field-projection form only** — one-arg form is BLOCKED and excluded from this proposal
3. **sumBy explicitly deferred** — no fixture or spec uses `sumBy`; two-arg `sum` IS the sumBy form under the `sum` name
4. **Return type = declared field type F** — structural type lookup, not arithmetic inference; scale-preserving for Decimal[N]
5. **Non-Symbol second arg → OOF-COL5** — non-Symbol is semantically invalid; strict validation recommended for P2
6. **Missing field → OOF-COL5** — honest behavior; no silent Decimal fallback (unlike current Rust TC)
7. **Unknown first arg → permissive** — return Unknown (consistent with TEXT/MAP/OUTCOME pattern)
8. **No numeric constraint on field type in v0** — field may be Integer, Decimal[N], or other; numeric validation deferred
9. **Empty collection: type is F, runtime value deferred** — return type is non-Option; runtime behavior is P2 decision
10. **semantic_ir_name == canonical_name** — `"stdlib.collection.sum"` for both; no legacy_sir
11. **OOF-COL5 active for sum-specific errors** — non-Symbol second arg + missing field; OOF-COL1 for arity, OOF-COL2 for non-Collection first arg (shared HOF namespace)
12. **fold-derivation noted but implementation is independent** — sum is fold-derivable at the semantic level; Ruby TC implementation does not depend on fold being implemented first

---

## 10. OOF Namespace Summary

| Code | Trigger | Active? |
|------|---------|---------|
| OOF-COL1 | Arity mismatch (not 2 args) | P2 — shared with map/filter/count/fold |
| OOF-COL2 | Non-Collection first argument | P2 — shared |
| OOF-COL3 | Filter predicate returns non-Bool | P2 planning decision (filter only) |
| OOF-COL4 | Fold-family errors | Deferred — reserved for fold |
| OOF-COL5 | Sum errors: non-Symbol second arg; field not found in type shape | P2 — sum only |

---

## 11. Relationship to fold

Both sum forms are fold-derivable:
- `sum(coll) = fold(coll, 0, (acc, x) -> acc + x)` (one-arg)
- `sum(coll, :field) = fold(coll, 0, (acc, x) -> acc + x.field)` (two-arg)

LAB-STDLIB-FOLD-P1 is ACCEPT (fold ready for proposal). However, fold is not yet implemented in Ruby TC, and requiring sum to derive from fold would create a dependency.

The Rust TC treats sum and fold as independent dispatch arms. This proposal specifies sum independently. The derivation relationship is informational; it informs future consistency requirements (if fold and sum diverge semantically, this should be surfaced in the fold proposal).

---

## 12. Authority Closed

- No Ruby TypeChecker implementation (P2 scope)
- No Rust TypeChecker changes
- No VM/runtime changes
- No `stdlib-inventory.json` file edits (P2 scope)
- No one-arg sum (Split B blocked)
- No `sumBy` function
- No Decimal operator/literal implementation
- No fold implementation
- No numeric type constraint system
- No identity element semantics
- No query/storage semantics
- No app fixture changes
- No public compatibility promise beyond this proposal

---

## 13. Next Routes

**Primary:**
`LANG-STDLIB-SUM-PROP-P2`  
Implementation planning for Ruby TC `infer_sum_call` dispatch.  
Key questions for P2: dispatch constant structure (extend COLLECTION_HOF_FNS vs separate COLLECTION_SUM_FNS); strict vs permissive field validation; OOF-COL5 exact triggers; empty-collection runtime behavior decision; proof matrix (recommend ≥40 checks: regression / sum-two-arg / SIR names / OOF diagnostics / app fixtures / authority).

**Separate blocked track:**
`LAB-STDLIB-NUMERIC-P1` → One-arg `sum(Collection[T]) -> T` + numeric type constraint.

**Rust parity (after Ruby TC P2 proved):**
Rust TC: emit `stdlib.collection.sum` as qualified SIR fn name (not bare `"sum"`).  
Rust TC: fix one-arg scale-stripping (`sum(Collection[Decimal[2]])` should return `Decimal[2]`, not `Decimal`).
