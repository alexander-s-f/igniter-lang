# LANG-STDLIB-COLLECTION-APPEND v0 — collection.append

**Track:** stdlib / collection / append  
**Status:** authored-pending-review  
**Date:** 2026-06-12  
**Route:** PROPOSAL AUTHORING ONLY / NO IMPLEMENTATION  
**Predecessor proof:** LAB-STDLIB-COLLECTION-P1 (64/64 PASS)  
**Predecessor governance:** LANG-STDLIB-COLLECTION-MAP-FILTER (P1–P5), LANG-STDLIB-ENTRY-CONTRACT-P1/P2/P3  
**Card:** LANG-STDLIB-COLLECTION-APPEND-P1

---

## 1. Context and Evidence Base

`stdlib.collection.append` adds a single item to the end of a collection, returning a
new collection. It is the canonical collection-construction primitive for sequential,
order-preserving accumulation in Igniter.

**Application fixture evidence (6+ surfaces):**

| App / file | Usage pattern | First arg type | Second arg type |
|------------|---------------|---------------|-----------------|
| `vector_editor/document.ig` | `call_contract("append", layer.objects, obj)` | `Collection[GraphicObject]` | `GraphicObject` |
| `decision_tree/builder.ig` | `call_contract("append", tree.nodes, node)` | `Collection[TreeNode]` | `TreeNode` |
| `igniter_parser/lexer.ig` | `call_contract("append", state.tokens, new_token)` | `Collection[Token]` | `Token` |
| `igniter_parser/parser.ig` | `call_contract("append", state.nodes, module_node)` | `Collection[Node]` | `Node` |
| `bloom_filter/example.ig` | `call_contract("append", b0, s2)` (chained) | `Collection[Slot]` | `Slot` |
| `bloom_filter/example.ig` | `call_contract("append", s0, s1)` (bootstrap) | `Slot` | `Slot` |
| `arch_patterns/pipeline.ig` | `call_contract("append", ctx.audit_trail, "mw:…")` | `Collection[Text]` | `Text` |
| `decision_tree/example.ig` | `call_contract("append", feat_income_high, feat_credit_good)` (bootstrap) | `Feature` | `Feature` |

Every fixture uses `call_contract("append", ...)` — not a direct function call — because no
stdlib `append` function dispatch exists yet. All apps that import `append` do so with
`import stdlib.collection.{ append }`, which is the correct import form this proposal makes normative.

**Bootstrap pattern:** Several fixtures use `call_contract("append", item_a, item_b)` where
neither argument is a Collection. This is the only way to build an initial collection in the
absence of collection literals or an `empty()` constructor. See §6 for the canonical treatment.

**Relationship to `stdlib.collection.concat`:** `stdlib.collection.concat` (currently orphaned,
inventory status: `orphaned/sketch`) merges two Collections: `Collection[T] × Collection[T] → Collection[T]`.
`append` is a distinct operation: it adds a single item, not a second collection. `append` and
`concat` are not aliases and this proposal does not affect the orphan status of `concat`.

---

## 2. Core Principle

**`stdlib.collection.append` is a pure, order-preserving, single-item collection constructor.**

It does not:
- Execute queries or access storage
- Grant authority or consume capabilities
- Mutate its input (Igniter collections are immutable structural values)
- Require runtime allocation authority (value construction, not heap mutation)
- Merge two collections (`concat` handles that)
- Accept a second-argument collection (only a single item)

`append` is the simplest possible collection-growth primitive. Its sole purpose is to return
a new collection that is identical to its input except for one additional element at the end.

---

## 3. Scope of v0

**Accepted (this proposal):**

1. `stdlib.collection.append` — single-item append:
   `Collection[T] × T → Collection[T]`

**Explicitly excluded from v0:**

- `append(item_a, item_b)` bootstrap form (T × T → Collection[T]) — not the canonical type;
  see §6. Existing `call_contract("append", ...)` bootstrap usage continues via contract dispatch.
- Append-many / variadic append — out of scope; use chained append or concat
- In-place mutation — no mutation semantics in Igniter
- `stdlib.collection.concat` promotion/triage — separate track; no changes to orphan status
- Named function reference form (HOF pointer to append) — deferred
- `import` enforcement machinery — declaration form is normative; runtime enforcement deferred
- Collection type conversions or coercions — out of scope
- Rust parity implementation — P2+ scope; Ruby TC is canon

---

## 4. Type Signature and Semantics

### 4.1 Canonical type

```
append(Collection[T], T) → Collection[T]
```

- **First argument**: `Collection[T]` — the source collection. `Unknown` is permissive.
- **Second argument**: `T` — a single item whose type must match the collection element type.
  `Unknown` item type is permissive.
- **Result**: A new `Collection[T]` identical to the first argument except the second
  argument is appended as the last element.

### 4.2 Order semantics

- **Order-preserving**: The result contains all elements of the input in the same order.
- **Item at end**: The new item appears as the last element of the result.
- **Length**: `count(append(col, item)) == count(col) + 1` (always).

### 4.3 Totality

- Total: `append(Collection[T]{}, item)` → `Collection[T]` with one element.
- Empty input is accepted. No failure mode exists for valid inputs.

### 4.4 Type parameter resolution

`T` is resolved from the collection argument at the call site. For concrete `Collection[T]`,
the item must be type-compatible with `T`. Unknown is permissive in both positions.

---

## 5. Questions Answered

### Q1. Source alias: `append(collection, item)` or other?

**`append`** — bare, unqualified. Direct call form: `append(collection, item)`.

Same pattern as `map`, `filter`, `count`, `byte_length`. No category-prefix alias
(`collection_append`) and no method-syntax alias (`collection.append(...)`).

The `import stdlib.collection.{ append }` form used in existing fixtures is confirmed as
the correct import declaration. This is the only supported import path.

### Q2. Canonical name?

**`stdlib.collection.append`** — satisfying the `stdlib.<category>.<fn>` schema.

`semantic_ir_name == canonical_name` — no `legacy_sir`. Current app fixtures use
`call_contract("append", ...)` (not a direct function call), so no prior stable
SIR emission of the bare name `append` exists from the canon Ruby pipeline.

### Q3. Type?

**`Collection[T] × T → Collection[T]`** — confirmed. Single-item append only.

This is distinct from `concat` (`Collection[T] × Collection[T] → Collection[T]`).
The second argument is always a single item, never a collection.

### Q4. Should item type equality be strict?

**Yes, with Unknown permissive.** 

When both the collection element type and the item type are concrete and known, they must
match. Mismatch triggers `OOF-COL6` (see §7).

Permissive cases (no OOF-COL6):
- `Collection[Unknown]` — element type unknown; any item accepted
- Item type `Unknown` — item type cannot be determined; accepted permissively
- Either side `Unknown` — symmetric permissiveness

This matches the OOF-COL3 pattern for filter: concrete type mismatch is strict; Unknown
is always permissive.

**Rationale:** Strict type enforcement at append sites catches category errors at development
time (e.g., appending a `Node` to a `Collection[Token]`). Unknown permissiveness preserves
the existing behavior in partially-typed programs.

### Q5. Does append preserve order?

**Yes. New item appears at the end.** The result is defined as:
`[e₀, e₁, …, eₙ₋₁] ++ [item]` where `++` is sequence concatenation.

Order-preservation is a semantic guarantee, not an implementation detail. Any implementation
that does not preserve order and place the item at the end is incorrect.

### Q6. Is append pure/deterministic?

**Yes.** Pure, deterministic, no side effects. Same inputs always produce the same output.
No capabilities required. No effects emitted.

### Q7. Does append require runtime allocation authority?

**No.** Collections in Igniter are immutable structural values. `append` returns a new
structural value. This does not require any authority surface or capability.

`authority_surface: "none"` — same as all other collection HOF operations.

### Q8. OOF-COL code — reuse existing or reserve OOF-COL6?

**Reserve OOF-COL6** for item type mismatch.

Existing codes that apply to `append`:

| Code | Trigger for append |
|------|-------------------|
| `OOF-COL1` | Arity ≠ 2 (wrong number of arguments) |
| `OOF-COL2` | First arg is not `Collection` or `Unknown` |
| `OOF-COL6` (new) | Second arg concrete type does not match Collection element type |

`OOF-COL6` is a new reservation in the OOF-COL namespace. It is specific to `append`
(and potentially future single-item operations). `OOF-COL4` is fold-family;
`OOF-COL5` is sum field constraint. `OOF-COL6` is item-type mismatch for append.

Full OOF-COL namespace after this proposal:

| Code | Owner | Active? |
|------|-------|---------|
| OOF-COL1 | arity mismatch (map/filter/count/append) | active |
| OOF-COL2 | non-Collection first arg (map/filter/count/append) | active |
| OOF-COL3 | filter predicate non-Bool | active |
| OOF-COL4 | fold errors (arity/type/return-mismatch) | active |
| OOF-COL5 | sum non-Symbol or missing field | active |
| OOF-COL6 | append item type mismatch | P2 (this proposal) |

### Q9. SIR lowering name?

**`stdlib.collection.append`** — same as canonical name.

`semantic_ir_name == canonical_name` is the entry contract invariant. No legacy SIR name.
The SIR `fn` field emits `"stdlib.collection.append"` in both Ruby and Rust pipelines.

### Q10. Relationship to import surface?

`import stdlib.collection.{ append }` is the normative import declaration confirmed by this
proposal. Current app fixtures that already use this import form are correct.

**Import enforcement:** The import declaration is syntactically valid and semantically
meaningful. Whether the compiler requires an explicit import before the bare alias `append`
is usable — or whether bare aliases are always available — is a separate import governance
question deferred to the import machinery track. This proposal does not gate P2 on import
enforcement changes.

### Q11. Negative cases?

| Case | OOF code | Message form |
|------|----------|-------------|
| `append()` or `append(col)` | OOF-COL1 | "stdlib.collection.append: expected 2 arguments, got N" |
| `append(n, item)` where n:Integer | OOF-COL2 | "stdlib.collection.append: first argument must be Collection[T], got Integer" |
| `append(Collection[Integer], "hello")` | OOF-COL6 | "stdlib.collection.append: item type Text does not match Collection element type Integer" |
| `append(Collection[Unknown], item)` | none | permissive |
| `append(collection, unknown_item)` | none | permissive |

### Q12. Bootstrap pattern — what is the status of `T × T → Collection[T]`?

Several app fixtures use `call_contract("append", item_a, item_b)` where both arguments are
items, not collections. This is a **bootstrap pattern** — the only way to build an initial
collection when no collection literal or `empty()` constructor exists.

**Decision:** The bootstrap form is **outside the canonical type** of `stdlib.collection.append`.
The canonical type is `Collection[T] × T → Collection[T]`. A direct call
`append(item_a, item_b)` where `item_a` is not a Collection would produce `OOF-COL2`.

**Why this is acceptable:**
1. All bootstrap usage is via `call_contract("append", ...)` — which goes through the
   contract dispatch mechanism (not stdlib function dispatch). `call_contract` bypasses
   stdlib TC validation.
2. A proper solution is `stdlib.collection.empty` (a 0-argument collection constructor)
   or collection literal syntax — both deferred to future tracks.
3. Constraining the canonical type to the well-typed form is correct. The bootstrap
   workaround is explicitly recognized as a workaround.

**Recommendation:** App fixtures that use the bootstrap pattern should continue via
`call_contract` until `stdlib.collection.empty` is available. This is not a blocker for
`stdlib.collection.append` implementation.

---

## 6. Bootstrap Pattern — Detailed Analysis

The bootstrap pattern arises because Igniter has no collection literal syntax
(`[a, b, c]` is not defined) and no `empty()` constructor for collections.

Current workaround: `call_contract("append", item_a, item_b)` creates a pseudo-collection
where the app relies on the runtime treating two non-Collection values as a 2-element
collection. This is not type-safe but is the only option available.

The canonical path forward:

**Option A (recommended):** Add `stdlib.collection.empty` — a 0-arity constructor that
returns `Collection[Unknown]` (or `Collection[T]` in a typed context). Then:

```igniter
compute items = stdlib.collection.empty()
compute items_1 = append(items, item_a)
compute items_2 = append(items_1, item_b)
```

**Option B:** Collection literal syntax (e.g., `[a, b]`) — a parser/language change,
higher effort.

Both options are deferred to separate tracks. `stdlib.collection.append` P2 implementation
does not depend on either option.

---

## 7. Accepted Entry Contract

### 7.1 `stdlib.collection.append`

**Canonical name:** `stdlib.collection.append`  
**Source aliases accepted:** `append` (bare, unqualified)  
**Type parameters:** `T`  
**Signature:** `Collection[T] × T → Collection[T]`  
**Fragment class:** core  
**Purity:** pure  
**Authority surface:** none  
**Deterministic:** true  
**Totality:** total (`append(empty_collection, item)` → single-element collection)  
**Semantics:** Returns a new collection identical to the first argument with the second
argument appended as the last element. Order preserved. Length = input length + 1.

**Entry contract JSON:**

```json
{
  "canonical_name": "stdlib.collection.append",
  "semantic_ir_name": "stdlib.collection.append",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "append" }],
  "category": "collection",
  "lifecycle_status": "proof-local",
  "semantic_stability": "experiment-pass",
  "lowering_status": "none",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total: empty input → single-element output",
  "type_params": ["T"],
  "input_signature": ["Collection[T]", "T"],
  "output_signature": "Collection[T]",
  "diagnostics": ["OOF-COL1", "OOF-COL2", "OOF-COL6"],
  "failure_behavior": "none; arity mismatch → OOF-COL1; non-Collection first arg → OOF-COL2; item type concrete mismatch → OOF-COL6",
  "authority_surface": "none",
  "proof_lineage": [
    "app pressure: vector_editor AppendObjectToLayer",
    "app pressure: decision_tree/builder.ig AddNode",
    "app pressure: igniter_parser/lexer.ig LexNextToken",
    "app pressure: igniter_parser/parser.ig ParseModuleDecl",
    "app pressure: bloom_filter/example.ig InitFilter16",
    "app pressure: arch_patterns/pipeline.ig audit trail construction",
    "LANG-STDLIB-COLLECTION-APPEND-P1 proposal (this document)"
  ],
  "examples": [
    "append([1, 2, 3], 4) -> [1, 2, 3, 4]",
    "append(layer.objects, new_obj) -> Collection[GraphicObject]"
  ],
  "compatibility_note": "Canonical type is Collection[T] × T → Collection[T]. Bootstrap pattern (T × T via call_contract) is outside canonical type; accepted only through call_contract mechanism. Item type T must match Collection element type for concrete types; Unknown is permissive on both sides. OOF-COL6 reserved for item type mismatch.",
  "owner_surface": "LANG-STDLIB-COLLECTION-APPEND-P1",
  "entry_digest": null
}
```

**Critical invariant check:** `semantic_ir_name == canonical_name` →
`"stdlib.collection.append" == "stdlib.collection.append"` ✓  
**No legacy_sir:** No prior stable SIR emission of bare `append` from the canon Ruby pipeline.
All existing app usage goes via `call_contract`, which does not emit a stdlib SIR fn node.

---

## 8. Toolchain Status

### Ruby TypeChecker (canon — `igniter-lang/lib/igniter_lang/typechecker.rb`)

| Operation | Current State | P2 Action |
|-----------|--------------|-----------|
| `append` (regular call) | OOF-TY0 "Unknown function: append" | Add `when "append"` arm in `infer_call` + `infer_append_call` private method |

**Implementation sketch for P2:**

```ruby
def infer_append_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  # OOF-COL1: arity must be exactly 2
  if args.length != 2
    type_errors << oof("OOF-COL1", "stdlib.collection.append: expected 2 arguments, got #{args.length}", node_name)
    return type_ir("Collection")  # safe fallback
  end

  collection_arg = infer_expr(args[0], symbol_types, ...)
  item_arg       = infer_expr(args[1], symbol_types, ...)

  col_type  = collection_arg.fetch("resolved_type")
  col_name  = type_name(col_type)

  # OOF-COL2: first arg must be Collection or Unknown
  unless col_name == "Collection" || col_name == "Unknown"
    type_errors << oof("OOF-COL2", "stdlib.collection.append: first argument must be Collection[T], got #{col_name}", node_name)
    return type_ir("Collection")
  end

  elem_type  = element_type_from_collection(col_type)
  elem_name  = type_name(elem_type)
  item_type  = item_arg.fetch("resolved_type")
  item_name  = type_name(item_type)

  # OOF-COL6: concrete item type must match element type
  if elem_name != "Unknown" && item_name != "Unknown" && elem_name != item_name
    type_errors << oof("OOF-COL6",
      "stdlib.collection.append: item type #{item_name} does not match Collection element type #{elem_name}",
      node_name)
  end

  # Return type: same Collection[T] (element type unchanged)
  # If elem_type is Unknown, return Collection (bare); otherwise Collection[elem_type]
  collection_type_ir_from(elem_type)
end
```

**Dispatch arm insertion:** After the `when *COLLECTION_HOF_FNS.keys` arm and the `when "fold"` arm:

```ruby
when "append"
  infer_append_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

**SIR fn emission:** Ruby TC emits `"fn" => "stdlib.collection.append"` (qualified).
`semantic_ir_name == canonical_name` satisfied automatically.

**Note on `call_contract` usage:** The existing `call_contract("append", ...)` pattern
in app fixtures does NOT go through `infer_call`. It goes through `infer_call_contract_expr`
(or equivalent). P2 adds direct function dispatch only. `call_contract` dispatch is unchanged.

### Rust TypeChecker (`igniter-lab/igniter-compiler/src/typechecker.rs`)

`append` is not currently dispatched in the Rust TC. The `match fn_name.as_str()` block
has no `"append"` arm. A direct `append(collection, item)` call in Rust would fall through
to the `is_resolved = false` path (Unknown function behavior).

**Rust parity scope (P3 or separate card):**
- Add `"append"` arm in the Rust match block
- Emit `stdlib.collection.append` via `COLLECTION_HOF_OPS` in `emitter.rs`
- Bind collection/item type arguments; check OOF-COL1/COL2/COL6
- Return `Collection[T]` with element type unchanged

Rust parity is a separate track after Ruby TC proof. It follows the exact P4-style pattern
established for map/filter/count.

---

## 9. Design Decisions Locked

1. **Canonical type is `Collection[T] × T → Collection[T]`** — single-item append only;
   not a pair constructor, not a concat alias
2. **Bare source alias `append`** — direct call form; no method syntax, no prefixed alias
3. **Item type strict for concrete types; Unknown permissive** — OOF-COL6 for concrete mismatch
4. **Order-preserving; item at end** — semantic guarantee, not implementation hint
5. **Pure, deterministic, no authority** — same authority surface as all other collection HOFs
6. **OOF-COL6 reserved** for item type mismatch; extends the existing OOF-COL namespace
7. **Bootstrap pattern is outside canonical type** — stays via `call_contract` until
   `stdlib.collection.empty` or collection literals are available
8. **`concat` is not `append`** — `stdlib.collection.concat` (orphaned) handles
   `Collection[T] × Collection[T]`; no convergence with this proposal
9. **`semantic_ir_name == canonical_name`** — no legacy_sir; no prior stable SIR emission
10. **`import stdlib.collection.{ append }` is normative** — this is the correct import form;
    no import enforcement changes required for P2

---

## 10. Relationship to Existing Collection Helpers

| Helper | Signature | OOF codes | Status after P5 |
|--------|-----------|-----------|-----------------|
| `stdlib.collection.count` | `Collection[T] → Integer` | COL1, COL2 | lab-implemented/dual-toolchain |
| `stdlib.collection.filter` | `Collection[T] × (T→Bool) → Collection[T]` | COL1, COL2, COL3 | lab-implemented/dual-toolchain |
| `stdlib.collection.map` | `Collection[T] × (T→U) → Collection[U]` | COL1, COL2 | lab-implemented/dual-toolchain |
| `stdlib.collection.fold` | `Collection[T] × Acc × ((Acc,T)→Acc) → Acc` | COL4 | lab-implemented/single-toolchain |
| `stdlib.collection.sum` | `Collection[T] × :field → Decimal` | COL1, COL2, COL5 | lab-implemented/single-toolchain |
| **`stdlib.collection.append`** | **`Collection[T] × T → Collection[T]`** | **COL1, COL2, COL6** | **proof-local (this proposal)** |
| `stdlib.collection.concat` | `Collection[T] × Collection[T] → Collection[T]` | — | orphaned |

`append` fits naturally after `fold` and `sum` as the collection construction primitive.
All existing HOF operations transform existing collections; `append` is the first
primitive that grows a collection.

---

## 11. Authority Closed

- No Ruby TypeChecker implementation (P2 scope)
- No Rust TypeChecker changes
- No VM / runtime changes
- No `stdlib-inventory.json` file edits (P2 scope)
- No changes to `stdlib.collection.concat` or other existing entries
- No collection literal syntax
- No `stdlib.collection.empty` implementation
- No import enforcement machinery changes
- No app fixture changes
- No other collection operations (sort, slice, indexOf, etc.)

---

## 12. Next Routes

**Primary — P2 implementation planning:**

`LANG-STDLIB-COLLECTION-APPEND-PROP-P2`  
Bounded Ruby TC implementation planning.  
Authorized files: `typechecker.rb` + proof runner.  
Proof matrix: ≥50 checks — A regression / B dispatch basics / C type inference / D OOF-COL1 / E OOF-COL2 / F OOF-COL6 / G app fixtures / H authority.  
Implementation: `when "append"` dispatch arm + `infer_append_call` private method (~40 lines).

**Parallel — OOF-COL6 proof:**

OOF-COL6 can be proved alongside P2 since it only requires the same Ruby TC method.
No separate lab proof needed.

**Deferred — Rust parity:**

After Ruby TC proof passes. Follows P4-style pattern from map/filter/count.
Add `"append"` arm in Rust TC + `COLLECTION_HOF_OPS` emitter entry.

**Deferred — bootstrap resolution:**

`stdlib.collection.empty` proposal or collection literal syntax track.
Unblocks migration of bootstrap `call_contract` patterns to typed direct calls.
