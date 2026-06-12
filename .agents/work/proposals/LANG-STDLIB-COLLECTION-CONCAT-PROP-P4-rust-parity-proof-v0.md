# LANG-STDLIB-COLLECTION-CONCAT-PROP-P4 — Rust Parity Proof for stdlib.collection.concat

**Status:** PROVED — 32/32 PASS
**Date:** 2026-06-12
**Proof runner:** `igniter-lab/igniter-compiler/verify_stdlib_collection_concat_p4.rb`

---

## Scope

Implement Rust TC parity for `stdlib.collection.concat`. Three files changed:

1. `igniter-lab/igniter-compiler/src/typechecker.rs` — `"concat"` arm + `rewrite_concat_calls` DSA-P03 fix
2. `igniter-lab/igniter-compiler/src/emitter.rs` — element type erasure fix
3. `igniter-lang/docs/spec/stdlib-inventory.json` — `lowering_status` promoted to `dual-toolchain`

No Ruby changes. No VM/runtime. No new OOF codes.

---

## Background

**CONCAT-P3** implemented Ruby TC support. The Rust TC had a broken `"concat"` arm:
- OOF-TY0 for arity errors instead of OOF-COL1
- No OOF-COL2 (second arg non-Collection)
- No OOF-COL7 (element type mismatch)
- Unknown first arg routed to text path (DSA-P03)
- Element type T erased in emitted SIR (`Collection{params: []}`)

---

## Implementation Details

### 1. `"concat"` arm in `infer_expr` (typechecker.rs)

Ruby P3 reference (`infer_concat_call`, typechecker.rb lines 2630–2689) ported to Rust:

```
first_arg type:
  - empty args         → OOF-COL1 (Unknown return)
  - Collection/Unknown → collection path
  - Text/other         → text path

collection path:
  - arity != 2         → OOF-COL1 (Unknown return)
  - second not Col/Unk → OOF-COL2 (Unknown return)
  - both concrete elems differ → OOF-COL7 (non-early-return)
  - result elem: first arg elem unless Unknown, then second's
  - result type: Collection[elem]
```

### 2. DSA-P03 fix in `rewrite_concat_calls` (typechecker.rs)

`quick_arg_type` returns `"Unknown"` for `Expr::FieldAccess` (the `_` arm). The old
routing sent Unknown → `stdlib.text.concat`. Fixed:

```rust
// Before
if first_type == "Collection" {
// After  
if first_type == "Collection" || first_type == "Unknown" {
```

This matches Ruby P3: unknown surface type → assume collection path (permissive).

### 3. Element type erasure fix (emitter.rs)

**Root cause:** `rewrite_concat_calls` operates on the raw `Expr` AST before any type
annotation. The `Expr::Call` node has no `resolved_type`. When `json!(decl.expr)` is
serialized, the call JSON lacks `resolved_type`. The emitter fallback at line 706–714:

```rust
if fn_val == "stdlib.collection.concat" {
    // builds Collection{params: []} — T erased
}
```

**Fix:** At the compute node build site (emitter.rs line ~544), inject `decl.type_info`
(which carries full `Collection[T]` from `infer_expr`) as `resolved_type` before the
call to `semantic_expr_for_compute`. The existing `!map.contains_key("resolved_type")`
guard then skips the erasure fallback.

```rust
let decl_expr_json = {
    let mut j = json!(decl.expr);
    if j.get("fn").and_then(|f| f.as_str()) == Some("stdlib.collection.concat") {
        if let Some(m) = j.as_object_mut() {
            m.entry("resolved_type".to_string())
                .or_insert_with(|| decl.type_info.clone());
        }
    }
    j
};
self.semantic_expr_for_compute(&decl_expr_json, &return_type_str)
```

---

## Mismatch Table (before → after)

| Behaviour | Ruby P3 | Rust before P4 | Rust after P4 |
|-----------|---------|----------------|---------------|
| Happy path | ✓ ok | ✓ ok (Collection arm) | ✓ ok |
| OOF arity error | OOF-COL1 | OOF-TY0 | OOF-COL1 ✓ |
| Second not Collection | OOF-COL2 | none (passes) | OOF-COL2 ✓ |
| Elem type mismatch | OOF-COL7 | none | OOF-COL7 ✓ |
| Unknown first arg → collection | ✓ | ✗ (text path) | ✓ |
| FieldAccess first arg | ✓ col | ✗ text (DSA-P03) | ✓ col |
| SIR elem type T | ✓ | ✗ `params:[]` | ✓ |

---

## SIR Parity

For `concat(xs: Collection[Integer], ys: Collection[Integer])`:

```json
{
  "kind": "call",
  "fn": "stdlib.collection.concat",
  "args": [...],
  "resolved_type": {
    "name": "Collection",
    "params": [{"name": "Integer", "params": []}]
  }
}
```

Both Ruby (via SIR emit) and Rust (after P4 fix) produce equivalent `resolved_type`
structure. G-04 confirms `params[0].name == "Integer"` in Rust SIR output.

---

## Proof Matrix

| Section | Count | Coverage |
|---------|-------|----------|
| A — Happy path | 5 | Int concat, Text concat, SIR fn name, no OOF, Ruby parity |
| B — OOF-COL1 | 3 | 0/1/3 args → OOF-COL1 |
| C — OOF-COL2 | 3 | Text, Integer second arg; Ruby parity |
| D — OOF-COL7 | 3 | Col[Int]+Col[Text]; diagnostic message; Ruby parity |
| E — Unknown permissive | 4 | Chained concat, no OOF-TY0 |
| F — DSA-P03 | 4 | Field-access `s.elements`, record field `p.left` |
| G — Elem type | 4 | `resolved_type` present, name=Collection, params non-empty, params[0]=Integer |
| H — Text unaffected | 4 | Text still routes to stdlib.text.concat, no col codes, Ruby regression |
| I — Inventory | 2 | `lowering_status=dual-toolchain`, lineage updated |
| **Total** | **32** | |

---

## Authority Boundary

- No Ruby changes
- No `flat_map`/`join`/`group_by`/`count` changes
- No VM runtime lowering (VM lowering for concat was already present via `++` operator path)
- No new OOF codes (OOF-COL1/COL2/COL7 already in Ruby P3 inventory)
- No parser changes
