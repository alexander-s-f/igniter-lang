# LANG-STDLIB-COLLECTION-CONCAT-PROP-P2 — Implementation Planning

**Track:** lang / stdlib / collection / concat  
**Route:** IMPLEMENTATION PLANNING  
**Status:** CLOSED — READY FOR P3  
**Date:** 2026-06-12  
**Predecessor:** LANG-STDLIB-COLLECTION-CONCAT-P1 (45/45 PASS, readiness proved)

---

## Planning Decision: READY FOR P3

No SPLIT. No HOLD. Ruby P3 first, Rust P4 second. Both are scoped and bounded. P3 implements Ruby TC only. P4 fixes two known Rust bugs (DSA-P03 mislabeling + element type erasure).

---

## Q1 — How to disambiguate `concat` text vs collection by first arg type

**Rule:** Inspect the first arg's `resolved_type` after full inference.

| First arg `resolved_type.name` | Route |
|-------------------------------|-------|
| `"Collection"` | `stdlib.collection.concat` path |
| `"Unknown"` | `stdlib.collection.concat` path (permissive — fixes DSA-P03) |
| `"Text"`, `"String"`, any other concrete | `stdlib.text.concat` path (delegate to `infer_text_call`) |

**Why infer first, then route (not pre-pass):**  
Pre-pass (`quick_arg_type` style) returns "Unknown" for field access — the DSA-P03 bug. Full inference resolves `s.elements` → `Collection[Integer]` via `@type_shapes` lookup. Routing after inference eliminates the false-text-path from unresolved field access.

**Text path delegation:** When first arg resolves to non-Collection, non-Unknown, `infer_concat_call` delegates to `infer_text_call("concat", args, ...)`. This re-infers first arg (double inference). The double inference is harmless because:
1. First arg is a concrete Text/String value — inference is pure and errorless.
2. No side effects in `infer_expr` for text literals or text-typed refs.

---

## Q2 — Where Ruby must intercept `concat` before `TEXT_STDLIB_FNS`

**Problem:** `TEXT_STDLIB_FNS.keys` includes `"concat"` (line 16). Ruby's `case/when` dispatches to the first matching arm. If `when *TEXT_STDLIB_FNS.keys` fires first, the collection path is never reached.

**Insertion: `when "concat"` arm BEFORE `when *TEXT_STDLIB_FNS.keys`.**

Current dispatch order (`infer_call`, lines 870–912):
```ruby
when "history_at"            ← line 874
when "bihistory_at"          ← line 876
when "olap_rollup"           ← line 878
when "recur"                 ← line 880
when *TEXT_STDLIB_FNS.keys   ← line 882  ← "concat" is here; MUST come AFTER new arm
when *MAP_STDLIB_FNS.keys    ← line 885
when *OUTCOME_STDLIB_FNS.keys
when *COLLECTION_HOF_FNS.keys
when "sum"
when "fold"
when "append"
when "is_empty", "non_empty"
when "or_else"
else
```

**After insertion:**
```ruby
when "recur"                 ← line 880 (unchanged)
  infer_recur_call(...)
when "concat"                ← NEW at line 882
  infer_concat_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
when *TEXT_STDLIB_FNS.keys   ← shifts to line 884 (text path now only reached when first arg is text)
  infer_text_call(...)
```

The `when *TEXT_STDLIB_FNS.keys` arm remains but `"concat"` is always intercepted before it. When `infer_concat_call` determines first arg is Text/String, it delegates to `infer_text_call("concat", args, ...)` — the same code path, just reached via delegation instead of arm dispatch.

**`infer_concat_call` method location:**  
After `infer_is_empty_call` (ends at line 2616), before `infer_or_else` (line 2618). Approximately 45 lines.

---

## Q3 — How Rust fixes DSA-P03 field-access mislabeling

**DSA-P03 root cause (confirmed by P1 proof):**

Flow for `concat(s.elements, [new_elem])` where `s.elements : Collection[Integer]`:
1. `infer_expr` processes bare `"concat"` call → `"concat"` arm (line 3141) fires → `typed_args[0].resolved_type` = `Collection[Integer]` (field access resolved via `@type_shapes`) → `first_name == "Collection"` → collection path → resolved_type set correctly.
2. After inference, `rewrite_concat_calls(decl.expr, &symbol_types)` rewrites the ORIGINAL AST expression. `quick_arg_type(Expr::FieldAccess { .. })` → `"Unknown"` → routes to `"stdlib.text.concat"`.
3. TypedDecl stored with fn = `"stdlib.text.concat"` (rewritten, wrong), resolved_type = Collection[Integer] (from step 1, correct).
4. Emitter sees fn = `"stdlib.text.concat"`, `!map.contains_key("resolved_type")` = true (rewritten AST has no resolved_type) → overwrites with resolved_type = Text. Both fn and resolved_type are wrong.

**Fix: Extend `quick_arg_type` for `Expr::FieldAccess { object, field }`.**

```rust
// In fn quick_arg_type():
Expr::FieldAccess { object, field } => {
    // Resolve object type from symbol_types, then look up field in type_shapes.
    // Handles the DSA-P03 pattern: s.elements where s is a bare Ref.
    if let Expr::Ref { name } = object.as_ref() {
        if let Some(obj_type) = symbol_types.get(name) {
            let obj_type_name = self.type_name(obj_type);
            if let Some(record_shape) = self.type_shapes.get(&obj_type_name) {
                if let Some(field_type) = record_shape.get(field.as_str()) {
                    return self.type_name(field_type);
                }
            }
        }
    }
    "Unknown".to_string()  // fallback: nested access, unresolved ref, etc.
}
```

This one-level FieldAccess lookup handles the DSA pattern (`s.elements` where s is a local Ref). Deeper nesting (`a.b.c`) still returns "Unknown" → routes to collection path permissively.

**Why not change the rewrite decision rule (Unknown → collection)?**  
Changing `rewrite_concat_calls` to route Unknown → `stdlib.collection.concat` (instead of `stdlib.text.concat`) would break existing Rust programs that use `concat(call_contract(...), "suffix")` — where Unknown-first-arg legitimately targets text concatenation. Ruby P3 uses Unknown → collection (new behavior, no prior text usage in Ruby). Rust P4 must be more conservative.

---

## Q4 — How to preserve `Collection[T]` params in SIR

**Bug 2 root cause (element type erasure):**

Current emitter (`emitter.rs`, lines 709–714):
```rust
if fn_val == "stdlib.collection.concat" {
    // BUG: params=[] — element type T is lost
    col.insert("params".to_string(), serde_json::Value::Array(Vec::new()));
}
```

The rewritten AST expression passed to the emitter is a bare Call node — no `resolved_type` field. The emitter can't recover element type T without inspecting the first arg.

**Fix: Extract element type from first arg's resolved_type params[0].**

```rust
// In emitter.rs, stdlib.collection.concat branch:
if fn_val == "stdlib.collection.concat" {
    // Build args first so we can inspect the first arg's resolved_type
    let processed_args: Vec<serde_json::Value> = map.get("args")
        .and_then(|a| a.as_array())
        .map(|arr| arr.iter().map(|a| self.semantic_expr(a)).collect())
        .unwrap_or_default();
    let elem_type = processed_args.first()
        .and_then(|a| a.get("resolved_type"))
        .and_then(|rt| rt.get("params"))
        .and_then(|p| p.as_array())
        .and_then(|arr| arr.first())
        .cloned()
        .unwrap_or_else(|| self.type_ir_unknown());
    let mut col = serde_json::Map::new();
    col.insert("name".to_string(), serde_json::Value::String("Collection".to_string()));
    col.insert("params".to_string(), serde_json::Value::Array(vec![elem_type]));
    // ... build full call node with processed_args and resolved_type = col
}
```

After the DSA-P03 fix (quick_arg_type returns "Collection" for field access), the first arg in the stored expression (bare ref or FieldAccess) may still not carry resolved_type. The emitter's `semantic_expr` for a Ref or FieldAccess expression doesn't embed resolved_type in the output node. So `processed_args.first().get("resolved_type")` may return None → `elem_type = Unknown` (Collection[Unknown] result).

For the bare-ref case (`concat(items, extra)` where `items: Collection[Item]`): the Ref expression doesn't carry resolved_type. Result: Collection[Unknown]. This is a limitation of the rewrite-based approach.

**Partial fix scope:** After P4 DSA-P03 fix + Bug 2 fix:
- Bare-ref case: fn = `stdlib.collection.concat`, resolved_type = `Collection[Unknown]` (params empty → Unknown)
- Field-access case: fn = `stdlib.collection.concat` (fixed), resolved_type = `Collection[Unknown]` (args don't carry resolved_type)

Full element type preservation in the rewrite-based Rust path requires deeper architectural change (embedding resolved_type from TypedExpr into the stored expression). This is P4 scope — the Bug 2 fix ensures params is not an empty vec but Unknown is acceptable for P4.

The Rust TC's `"concat"` arm (line 3141) ALREADY computes the correct resolved_type (`Collection[T]`) via `get_param(&typed_args[0].resolved_type, 0)`. This is stored in `typed_decl.type_info` (the declaration's type), which is used as the SIR node's `type` field. Downstream that depends on `node["type"]` (not `node["expr"]["resolved_type"]`) gets the correct type.

---

## Q5 — OOF-COL1 / OOF-COL2 / OOF-COL7 exact triggers

### Ruby P3 behavior

**OOF-COL1 (arity)**  
Trigger: `args.length != 2`  
Early-return: `type_ir("Unknown")`  
Message: `"stdlib.collection.concat: expected 2 arguments, got N"`  
Applied before any arg inference (pure arity check).

**OOF-COL2 (non-Collection argument)**  
Trigger A (first arg): `first_type_name` is not `"Collection"` or `"Unknown"` → route to text path, NOT OOF-COL2 from collection handler. The text handler fires its own OOF-TY0 for bad text args. OOF-COL2 is NOT fired by the collection path for a non-collection first arg — routing eliminates it.

Trigger B (second arg): When collection path is taken (first arg is Collection or Unknown), second arg is concrete non-Collection, non-Unknown.  
Early-return: `collection_type_ir_from(elem_type_first)` (return Collection[T] of first arg).  
Message: `"stdlib.collection.concat: second argument must be Collection[T], got X"`  
Note: Second arg is inferred before this check. If second arg itself produced type errors, they are already in type_errors.

**OOF-COL7 (element type mismatch)**  
Trigger: Both args are Collection[T1] and Collection[T2] where `T1 != T2` AND `T1 != "Unknown"` AND `T2 != "Unknown"`.  
NON-early-return: error recorded, inference continues.  
Return: `collection_type_ir_from(elem_type_first)` — first arg's element type preserved.  
Message: `"stdlib.collection.concat: element type mismatch — Collection[T1] vs Collection[T2]"`  
Unknown element type on EITHER side → skip OOF-COL7 (permissive).

**OOF-COL2 table:**

| First arg | Second arg | Result |
|-----------|------------|--------|
| Collection[T] | Collection[T] | ✓ Collection[T] |
| Collection[T1] | Collection[T2] | OOF-COL7 (non-early), Collection[T1] |
| Collection[T] | Unknown | ✓ Collection[T] (Unknown elem permissive) |
| Collection[T] | Integer | OOF-COL2 (early), Collection[T] |
| Collection[Unknown] | Collection[T] | ✓ Collection[Unknown] (Unknown elem permissive) |
| Unknown | Collection[T] | ✓ Collection[Unknown] |
| Unknown | Integer | OOF-COL2 (early), Unknown |
| Text (first) | any | → delegate to text path |

---

## Q6 — Unknown permissive behavior

**Unknown first arg → collection path (returns Collection[Unknown]).**  
Rationale: Unknown-first-arg arises from field access on Unknown-typed values (e.g., inside a `map` lambda where param is Unknown). Routing to collection path produces Collection[Unknown] — permissive, not false-positive OOF-TY0. Text path would fire OOF-TY0 for "expected Text, got Unknown".

**Unknown element type in Collection[Unknown] → skip OOF-COL7.**  
`elem_name == "Unknown"` OR `elem2_name == "Unknown"` → no COL7.

**Unknown second arg (when collection path) → skip OOF-COL2 for second arg.**  
Second arg "Unknown" is treated as compatible Collection argument — Collection[Unknown] is permissive.

**Bootstrap safety:** `call_contract("concat", a, b)` has fn = "call_contract" in the AST — never reaches `when "concat"` arm. No COL1/COL2/COL7 from bootstrap form.

---

## Q7 — Relation to `append` and array literals

| | `append` | `concat` |
|---|---|---|
| Signature | `Collection[T] × T → Collection[T]` | `Collection[T] × Collection[T] → Collection[T]` |
| Second arg | Single item T | Full Collection[T] |
| OOF mismatch | OOF-COL6 (item vs elem type) | OOF-COL7 (elem type of second collection) |
| In `COLLECTION_HOF_FNS`? | No (separate arm) | No (separate arm before TEXT_STDLIB_FNS) |
| Bootstrap safe | Yes | Yes |
| Disambiguation needed | No (no text sibling) | Yes (text.concat shares alias) |

**Array literals as second arg:** `concat(items, [new_item])` where `[new_item]` is an array literal. Array literals are inferred as `Collection[T]` where T = element type. After P3, `infer_concat_call` infers second arg as `Collection[T]`. If T matches first arg element type → no COL7. The DSA fixture `concat(s.elements, [new_elem])` uses this pattern.

**Relation to text concat after P3:**  
`concat("hello", " world")` → first arg = String → routes to `infer_text_call("concat", args, ...)` → OOF check against Text/Text spec → resolves correctly. Text regression is preserved.

---

## Full Ruby Implementation (P3)

### TWO INSERTIONS in `typechecker.rb`

**Insertion 1 — Dispatch arm (in `infer_call`, before `when *TEXT_STDLIB_FNS.keys`):**

```ruby
      when "concat"
        # LANG-STDLIB-COLLECTION-CONCAT-PROP-P3: collection or text disambiguation by first arg type.
        # Collection/Unknown first arg → stdlib.collection.concat (fixes DSA-P03: field access no longer
        # mislabels as text.concat). Text/other first arg → delegate to infer_text_call.
        infer_concat_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      when *TEXT_STDLIB_FNS.keys
```

**Insertion 2 — Private method `infer_concat_call` (after `infer_is_empty_call`, ~line 2617):**

```ruby
    def infer_concat_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.collection.concat"

      # ── OOF-COL1: arity ──────────────────────────────────────────────────────
      unless args.length == 2
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 2 arguments, got #{args.length}", node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
      end

      # ── Infer first arg to determine route ───────────────────────────────────
      first_arg      = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      first_type_name = type_name(first_arg.fetch("resolved_type"))

      # ── Text path: delegate to existing text handler ──────────────────────────
      unless %w[Collection Unknown].include?(first_type_name)
        return infer_text_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      end

      # ── Collection path ───────────────────────────────────────────────────────
      second_arg       = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      second_type_name = type_name(second_arg.fetch("resolved_type"))

      # ── OOF-COL2: second arg must be Collection or Unknown ────────────────────
      unless %w[Collection Unknown].include?(second_type_name)
        type_errors << oof("OOF-COL2",
          "#{qualified}: second argument must be Collection[T], got #{second_type_name}",
          node_name)
        all_deps = (first_arg.fetch("deps", []) + second_arg.fetch("deps", [])).uniq
        return typed_expr("call", type_ir("Unknown"), all_deps,
                          "fn" => qualified, "args" => [first_arg, second_arg])
      end

      # ── Extract element types ─────────────────────────────────────────────────
      elem_type  = element_type_from_collection(first_arg.fetch("resolved_type"))
      elem2_type = element_type_from_collection(second_arg.fetch("resolved_type"))
      elem_name  = type_name(elem_type)
      elem2_name = type_name(elem2_type)

      # ── OOF-COL7: element type mismatch (non-early-return) ───────────────────
      unless elem_name == "Unknown" || elem2_name == "Unknown" || elem_name == elem2_name
        type_errors << oof("OOF-COL7",
          "#{qualified}: element type mismatch — Collection[#{elem_name}] " \
          "vs Collection[#{elem2_name}]",
          node_name)
      end

      all_deps = (first_arg.fetch("deps", []) + second_arg.fetch("deps", [])).uniq
      typed_expr("call", collection_type_ir_from(elem_type), all_deps,
                 "fn" => qualified, "args" => [first_arg, second_arg])
    end
```

**Approximate size:** 48 lines.  
**Authorized files (P3):** `typechecker.rb` + `stdlib-inventory.json` + proof runner.

---

## Rust P4 Fix Plan

**Authorized files:** `typechecker.rs` + `emitter.rs`. No Ruby changes in P4.

### Fix 1 — DSA-P03: `quick_arg_type` FieldAccess lookup

In `fn quick_arg_type`, add arm before `_ => "Unknown"`:

```rust
Expr::FieldAccess { object, field } => {
    if let Expr::Ref { name } = object.as_ref() {
        if let Some(obj_type) = symbol_types.get(name) {
            let obj_type_name = self.type_name(obj_type);
            if let Some(record_shape) = self.type_shapes.get(&obj_type_name) {
                if let Some(field_type) = record_shape.get(field.as_str()) {
                    return self.type_name(field_type);
                }
            }
        }
    }
    "Unknown".to_string()
}
```

After this fix, `quick_arg_type(s.elements, symbol_types)` where `s: IntSet { elements: Collection[Integer] }` → `"Collection"` → `rewrite_concat_calls` rewrites fn to `"stdlib.collection.concat"`.

### Fix 2 — Element type erasure: emitter params=[T] not params=[]

In `emitter.rs`, inside the `fn_val == "stdlib.collection.concat"` branch, replace `Vec::new()` with element type extracted from the first processed arg:

```rust
if fn_val == "stdlib.collection.concat" {
    let processed_args: Vec<serde_json::Value> = map.get("args")
        .and_then(|a| a.as_array())
        .map(|arr| arr.iter().map(|a| self.semantic_expr(a)).collect())
        .unwrap_or_default();
    let elem_type = processed_args.first()
        .and_then(|a| a.get("resolved_type"))
        .and_then(|rt| rt.get("params"))
        .and_then(|p| p.as_array())
        .and_then(|arr| arr.first())
        .cloned()
        .unwrap_or_else(|| self.type_ir_unknown());
    let mut col = serde_json::Map::new();
    col.insert("name".to_string(),
               serde_json::Value::String("Collection".to_string()));
    col.insert("params".to_string(),
               serde_json::Value::Array(vec![elem_type]));
    let resolved_type = serde_json::Value::Object(col);
    // ... (rest of call node construction unchanged)
}
```

**Limitation (accepted for P4):** If the first processed arg (a bare Ref or FieldAccess expression) doesn't carry `resolved_type` in its semantic_expr output, `elem_type` falls back to Unknown → params=[Unknown]. This is better than params=[] but not fully typed. Full element-type preservation requires architectural change (embed TypedExpr resolved_type in rewritten expression) — deferred to P5+.

---

## Inventory Plan (P3)

Upgrade the `stdlib.collection.concat` entry:

```json
{
  "lifecycle_status": "lab-implemented",
  "semantic_stability": "experiment-pass",
  "lowering_status": "ruby-only",
  "aliases": [{ "kind": "source_alias", "name": "concat" }],
  "diagnostics": ["OOF-COL1", "OOF-COL2", "OOF-COL7"]
}
```

Fields unchanged: `canonical_name`, `semantic_ir_name`, `category`, `fragment_class`, `purity`, `type_params`, `input_signature`, `output_signature`, `authority_surface`.

Recompute `stdlib_surface_digest` after inventory update (P3 proof runner verifies determinism).

**Note on shared source_alias:** `stdlib.text.concat` and `stdlib.collection.concat` both have `source_alias: concat`. The import surface validates that the name exists in the module — it does not require disambiguation. `import stdlib.collection.{ concat }` → OOF-IMP3 today (not importable yet). After P3 adds `source_alias`, it becomes importable. The TC handles disambiguation at call site, not import resolution.

---

## Proof Matrix

### P3 (Ruby) — 65 checks / 10 sections

| Section | Checks | Content |
|---------|--------|---------|
| A — Source structure | 7 | `when "concat"` arm before TEXT_STDLIB_FNS; `infer_concat_call` method present; OOF-COL1/COL2/COL7 strings in source |
| B — OOF-COL1 arity | 6 | 0 args / 1 arg / 3 args each emit OOF-COL1 early-return |
| C — OOF-COL2 second arg | 6 | Collection+Integer / Collection+String / Unknown+Integer each emit OOF-COL2 |
| D — OOF-COL7 element mismatch | 6 | Collection[String]+Collection[Integer] / Collection[Bool]+Collection[String] emit OOF-COL7; Unknown element skips |
| E — Unknown permissive | 5 | Unknown first arg → collection; Unknown element → no COL7; both Unknown → Collection[Unknown] |
| F — Happy path | 8 | Collection[String]+Collection[String] → Collection[String]; SIR fn = stdlib.collection.concat; element type preserved; deps merged |
| G — Text.concat regression | 6 | "hello"+"world" still text path; Text+Text → stdlib.text.concat; Text OOF-TY0 preserved |
| H — DSA fixture (field access) | 6 | `concat(s.elements, [new_elem])` — first arg inferred as Collection → collection path; no OOF-TY0; SIR fn = stdlib.collection.concat |
| I — Inventory | 8 | lifecycle=lab-implemented; lowering=ruby-only; source_alias=concat; diagnostics=[COL1,COL2,COL7]; digest recomputed |
| J — Authority closed | 7 | No emitter changes (Ruby); no Rust changes; no VM; no new OOF codes beyond COL7; one arm / one method only |

### P4 (Rust) — 50 checks / 8 sections

| Section | Checks | Content |
|---------|--------|---------|
| A — DSA-P03 fix | 7 | quick_arg_type FieldAccess arm present; `s.elements` no longer routes to text.concat; fn = stdlib.collection.concat in SIR |
| B — Element type params | 6 | params no longer empty vec; params[0] propagated; Collection[T] result for bare-ref case |
| C — Rust TC source changes | 6 | quick_arg_type FieldAccess arm in source; emitter params fix in source |
| D — Text.concat Rust regression | 6 | Rust text concat still correct; OOF-TY0 on text mismatch; split/contains/trim unchanged |
| E — Unknown routing parity | 6 | Unknown first arg (non-FieldAccess) still routes correctly (call_contract etc) |
| F — Conformance fixture | 7 | collection_extension.ig: concat(items, extra) — fn + resolved_type correct in Rust SIR |
| G — DSA baseline regression | 7 | DSA sets.ig: SetInsert `concat(s.elements, [new_elem])` — fn correct / resolved_type Collection[T] |
| H — Authority closed | 5 | Two files only (typechecker.rs + emitter.rs); no Ruby changes; no VM; no new Rust OOF codes |

---

## Regression Matrix

### P3 regressions (Ruby proof runner must run)

| Suite | Expected |
|-------|---------|
| `verify_text_equality_p3.rb` (52/52) | 0 regressions — `concat` arm before TEXT_STDLIB_FNS must not affect `==` |
| `verify_stdlib_collection_append_p3.rb` (65/65) | 0 regressions — `when "append"` arm unaffected |
| `verify_stdlib_is_empty_p3.rb` (60/60) | 0 regressions |
| string_core_proof runner | `concat(Text, Text)` still clean |
| `verify_stdlib_sum_p3.rb` (51/51) | 0 regressions |
| `verify_stdlib_fold_p3.rb` (52/52) | 0 regressions |

### P4 regressions (Rust compiler binary)

| Suite / Fixture | Expected |
|----------------|---------|
| DSA baseline (sets.ig concat) | DSA-P03 fixed; fn = stdlib.collection.concat |
| Conformance collection_extension.ig | element type in params (Bug 2 partially fixed) |
| Rust text stdlib proofs | No regression in trim/contains/split/concat Text path |

---

## Authority Closed

| Surface | P3 | P4 |
|---------|----|----|
| `typechecker.rb` | YES — 2 insertions | No changes |
| `stdlib-inventory.json` | YES — 1 entry upgrade | No changes |
| `typechecker.rs` | No | YES — quick_arg_type fix |
| `emitter.rs` | No | YES — params fix |
| Parser | No | No |
| SemanticIR emitter (Ruby) | No | No |
| VM / runtime | No | No |
| flatten / flat_map / join | No | No |
| New OOF codes | OOF-COL7 activated | No |

---

## Next Route

**LANG-STDLIB-COLLECTION-CONCAT-PROP-P3** — Ruby TC implementation proof  
Authorized: `typechecker.rb` (2 insertions) + `stdlib-inventory.json` + proof runner  
Target: ≥65 checks / 10 sections  

**LANG-STDLIB-COLLECTION-CONCAT-PROP-P4** — Rust parity (DSA-P03 + Bug 2 fix)  
Authorized: `typechecker.rs` + `emitter.rs` + proof runner  
Target: ≥50 checks / 8 sections  
Prerequisite: P3 PASS
