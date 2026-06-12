# LANG-STDLIB-IS-EMPTY-PROP-P4 — Rust Parity for is_empty / non_empty

**Track:** lang / stdlib / collection / predicates
**Route:** RUST PARITY PROOF
**Status:** CLOSED — PROVED 50/50 PASS
**Date:** 2026-06-12
**Predecessors:** LANG-STDLIB-IS-EMPTY-PROP-P3 (Ruby 60/60), LANG-STDLIB-COLLECTION-APPEND-P4 (Rust HOF parity precedent)

---

## Summary

Closes the Rust parity gap for `stdlib.collection.is_empty` and `stdlib.collection.non_empty`.
Both functions are now dispatched, type-checked, and SIR-qualified in the Rust compiler, matching
Ruby P3 semantics. The inventory `lowering_status` is upgraded to `dual-toolchain` for both entries.

---

## Files Changed

| File | Change |
|------|--------|
| `igniter-lab/igniter-compiler/src/typechecker.rs` | Added `"is_empty" \| "non_empty"` arm |
| `igniter-lab/igniter-compiler/src/emitter.rs` | Added entries to `COLLECTION_HOF_OPS` + `matches!` guard |
| `igniter-lang/docs/spec/stdlib-inventory.json` | `lowering_status` `ruby-only` → `dual-toolchain` (×2) |
| `igniter-lab/igniter-compiler/verify_stdlib_is_empty_p4.rb` | Proof runner (50/50 PASS) |
| `igniter-lang/.agents/work/cards/lang/LANG-STDLIB-IS-EMPTY-PROP-P4.md` | Card |

---

## Implementation

### 1. `typechecker.rs` — new match arm

**Location:** inside `match fn_name.as_str()` at line ~2672, after `"count"` arm, before `"first" | "last"`.

**Full arm text:**

```rust
// LANG-STDLIB-IS-EMPTY-PROP-P4: Rust parity for is_empty + non_empty.
// is_empty(Collection[T]) -> Bool  — true iff zero elements
// non_empty(Collection[T]) -> Bool — true iff one or more elements
// OOF-COL1: arity != 1; OOF-COL2: non-Collection / non-Unknown first arg.
// Bool returned on ALL paths including error paths (no Unknown propagation).
"is_empty" | "non_empty" => {
    is_resolved = true;
    resolved_type = self.type_ir(&serde_json::Value::String("Bool".to_string()));
    if args.len() != 1 {
        let qualified = if fn_name == "is_empty" {
            "stdlib.collection.is_empty"
        } else {
            "stdlib.collection.non_empty"
        };
        type_errors.push(ClassifierDiagnostic {
            rule: "OOF-COL1".to_string(),
            message: format!(
                "{}: expected 1 argument (collection), got {}",
                qualified,
                args.len()
            ),
            node: node_name.to_string(),
            line: None,
        });
    } else if !typed_args.is_empty() {
        let col_arg_name = self.type_name(&typed_args[0].resolved_type);
        if col_arg_name != "Collection" && col_arg_name != "Unknown" {
            let qualified = if fn_name == "is_empty" {
                "stdlib.collection.is_empty"
            } else {
                "stdlib.collection.non_empty"
            };
            type_errors.push(ClassifierDiagnostic {
                rule: "OOF-COL2".to_string(),
                message: format!(
                    "{}: first argument must be Collection[T], got {}",
                    qualified,
                    col_arg_name
                ),
                node: node_name.to_string(),
                line: None,
            });
        }
    }
}
```

**Key design decisions:**

- `is_resolved = true` → prevents fall-through to `OOF-TY0 "Unknown stdlib function"`.
- `resolved_type = Bool` set before branching → Bool returned on ALL paths including error paths. Matches Ruby P3 precedent and `count` arm pattern.
- OOF-COL1 (arity) fires on `args.len() != 1`, early-return path.
- OOF-COL2 (non-Collection) fires only when `typed_args` is non-empty AND first arg type is neither `Collection` nor `Unknown`. Unknown → permissive (no error).
- The `qualified` local recomputes inside each branch (pattern inherited from `count` arm).

### 2. `emitter.rs` — two additions

**`COLLECTION_HOF_OPS` array** (located at `semantic_expr_for_compute`, routes bare names to qualified SIR `fn` values):

```rust
// LANG-STDLIB-IS-EMPTY-PROP-P4: is_empty + non_empty added.
const COLLECTION_HOF_OPS: &[(&str, &str)] = &[
    ("map",       "stdlib.collection.map"),
    ("filter",    "stdlib.collection.filter"),
    ("count",     "stdlib.collection.count"),
    ("append",    "stdlib.collection.append"),
    ("is_empty",  "stdlib.collection.is_empty"),
    ("non_empty", "stdlib.collection.non_empty"),
];
```

**`matches!` guard** in `semantic_expr_for_compute` (routes collection HOF bare names through `semantic_expr` for qualification):

```rust
// LANG-STDLIB-IS-EMPTY-PROP-P4: is_empty + non_empty added.
|| matches!(fn_val, "map" | "filter" | "count" | "append" | "is_empty" | "non_empty")
```

**Why the emitter change is required:** The emitter's `semantic_expr_for_compute` dispatches HOF calls to `semantic_expr` (which rewrites bare names to qualified SIR names) only when the function name matches the guard. Without adding `is_empty`/`non_empty` to the guard, SIR `fn` would remain bare `"is_empty"` instead of the canonical `"stdlib.collection.is_empty"`. This was the same architectural gap closed in P4 for `map`/`filter`/`count`/`append`.

### 3. `stdlib-inventory.json` — `lowering_status` upgrade

Both inventory entries updated via Python script (to avoid re-read/edit race conditions):

```python
import json, re

path = "igniter-lang/docs/spec/stdlib-inventory.json"
with open(path, encoding="utf-8") as f:
    data = json.load(f)

for entry in data["entries"]:
    if entry["canonical_name"] in (
        "stdlib.collection.is_empty",
        "stdlib.collection.non_empty",
    ):
        entry["lowering_status"] = "dual-toolchain"

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
```

The `stdlib_surface_digest` field was not recomputed in this card (digest computation is a separate
P5+ concern once the inventory stabilizes further). The `lowering_status` change is the only
semantically significant update — it records that both toolchains now implement these entries.

---

## Proof Matrix

| Section | Description | Checks | Result |
|---------|-------------|--------|--------|
| A | Regression — map/filter/count/append/fold/sum | 8 | PASS |
| B | is_empty happy path (Collection[T] → Bool, various element types) | 7 | PASS |
| C | non_empty happy path | 5 | PASS |
| D | OOF-COL1 arity (0 args, 2 args, 3 args for each fn) | 6 | PASS |
| E | OOF-COL2 non-Collection argument | 5 | PASS |
| F | Unknown permissive (Unknown first arg → no error) | 4 | PASS |
| G | SIR canonical names (`stdlib.collection.is_empty`, `stdlib.collection.non_empty`) | 4 | PASS |
| H | Source text guards (arm present, COLLECTION_HOF_OPS entries, matches! guard) | 4 | PASS |
| I | Inventory (`lowering_status` = `dual-toolchain` for both entries) | 4 | PASS |
| J | Authority closed (no unary_op / no head / no find_one / no VM) | 3 | PASS |
| **Total** | | **50** | **PASS** |

---

## Parity Table

| Aspect | Ruby P3 | Rust P4 |
|--------|---------|---------|
| `is_empty(Collection[T])` → Bool | ✓ | ✓ |
| `non_empty(Collection[T])` → Bool | ✓ | ✓ |
| OOF-COL1: arity != 1 | ✓ | ✓ |
| OOF-COL2: non-Collection first arg | ✓ | ✓ |
| Unknown arg → permissive | ✓ | ✓ |
| Bool returned on all paths (incl. error) | ✓ | ✓ |
| SIR `fn` = `stdlib.collection.is_empty` | ✓ | ✓ |
| SIR `fn` = `stdlib.collection.non_empty` | ✓ | ✓ |
| `non_empty` independent (not `!is_empty`) | ✓ | ✓ |
| Inventory `lowering_status` = `dual-toolchain` | ✓ (after P3) | ✓ (this card) |

---

## Proof Runner Diagnostics (50/50)

```
LANG-STDLIB-IS-EMPTY-PROP-P4 PASS (50/50)
```

No section failures. No errors at first run after:
- I-03/I-04 inventory `lowering_status` update (initial value was `ruby-only`)
- J-01 false-match fix: the `non_empty.*unary` regex with `/m` matched across comment text;
  rewritten to extract the arm body text, filter comment lines, and check only code lines for
  `unary_op`/`Bang`/`UnaryOp` references.

---

## Authority Boundary

- No parser changes.
- No Ruby TypeChecker changes.
- No unary `!` or `!is_empty(x)` equivalence (unary_op TC gap is a separate card — LAB-UNARY-MINUS-P1 / LANG-UNARY-OPERATORS).
- No `head`, `find_one`, `last`, or other collection predicates.
- No VM runtime semantics.
- No new OOF codes (OOF-COL1/OOF-COL2 reused from count, append precedent).
- No assembler changes.
- Inventory `lowering_status` upgrade only — no new entries, no digest recomputation.
