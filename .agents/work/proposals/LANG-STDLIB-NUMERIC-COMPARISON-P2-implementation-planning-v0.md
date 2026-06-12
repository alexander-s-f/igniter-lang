# LANG-STDLIB-NUMERIC-COMPARISON-P2 — Numeric Comparison Operators Implementation Planning

**Track:** lang / stdlib / numeric / comparison  
**Route:** IMPLEMENTATION PLANNING / NO IMPLEMENTATION  
**Date:** 2026-06-12  
**Predecessor:** LANG-STDLIB-NUMERIC-COMPARISON-P1 (37/37 PASS)  
**Grounding:** fixed-point proof (LAB-STDLIB-NUMERIC-FIXED-POINT-P1), app recheck (arch_patterns, neural_net, vector_math)

---

## 1. Scope

### Operators in scope (v0)

| Operator | SIR fn name | Status |
|----------|-------------|--------|
| `>` | `stdlib.integer.gt` | ✓ already works (Ruby + Rust) — REGRESSION SURFACE ONLY |
| `<` | `stdlib.integer.lt` | ✗ Ruby gap / ✓ Rust ok — Ruby only in P3 |
| `<=` | `stdlib.integer.lte` | ✗ both TCs — add in P3 |
| `>=` | `stdlib.integer.gte` | ✗ both TCs — add in P3 |

### Closed surfaces

No arithmetic operators. No Decimal/Float. No unary operators. No parser changes. No VM/assembler changes. No new OOF codes. No `==` changes.

---

## 2. Decision: Ruby + Rust in P3

Ruby and Rust gaps are small enough for a single implementation card. Rust is missing only `<=` and `>=` (2 arms); Ruby is missing `<`, `<=`, and `>=` (3 arms). Both fit cleanly in P3 with no split.

---

## 3. Ruby TC — `typechecker.rb`

### Insertion point

**File:** `igniter-lang/lib/igniter_lang/typechecker.rb`  
**Method:** `def operator_type` (line 1189)  
**After line:** 1207 — `["stdlib.integer.gt", type_ir("Bool")]`  
**Before line:** 1208 — `when "&&"`

### Code to insert (~9 lines)

```ruby
      when "<"
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}<#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.lt", type_ir("Bool")]
      when "<="
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}<=#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.lte", type_ir("Bool")]
      when ">="
        type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}>=#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
        ["stdlib.integer.gte", type_ir("Bool")]
```

**Pattern:** identical to `when ">"` arm. `unknown?` helper checks both operands. Error pushes only when neither operand is Unknown AND not both Integer. Returns Bool result type on all paths.

---

## 4. Ruby SIR Emitter — `semanticir_emitter.rb`

### Typed path (`semantic_expr`)

NO CHANGE. The TC already converts `binary_op { op: "<" }` → `call { fn: "stdlib.integer.lt", args: [...] }` before the emitter sees it. `semantic_expr` passes through call nodes via its generic hash traversal (strips `deps`). SIR output: `call { fn: "stdlib.integer.lt", resolved_type: Bool, args: [...] }`.

### Pre-TC path (`operator_for`)

**File:** `igniter-lang/lib/igniter_lang/semanticir_emitter.rb`  
**Method:** `def operator_for` (line 978)  
**After line:** 1004 — `["stdlib.integer.gt", "Bool"]`  
**Before line:** 1005 — `when "&&"`

```ruby
      when "<"
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer comparison requires Integer operands", node_name)
        end
        ["stdlib.integer.lt", "Bool"]
      when "<="
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer comparison requires Integer operands", node_name)
        end
        ["stdlib.integer.lte", "Bool"]
      when ">="
        unless unknown_type?(left_type, right_type) || (left_type == "Integer" && right_type == "Integer")
          diagnostics << oof("OOF-TY0", "Integer comparison requires Integer operands", node_name)
        end
        ["stdlib.integer.gte", "Bool"]
```

**Pattern:** identical to `when ">"`. Returns `["stdlib.integer.lte", "Bool"]` etc. on all paths (including OOF path).

---

## 5. Rust TC — `typechecker.rs`

### Insertion point

**File:** `igniter-lab/igniter-compiler/src/typechecker.rs`  
**Method:** `fn operator_type` (line ~4001)  
**After line:** 4183 — closing `}` of `"<"` arm  
**Before line:** 4184 — `_ =>`

### Code to insert (~24 lines)

```rust
            "<=" => {
                if (left_name != "Integer" || right_name != "Integer")
                    && left_name != "Unknown"
                    && right_name != "Unknown"
                {
                    type_errors.push(ClassifierDiagnostic {
                        rule: "OOF-TY0".to_string(),
                        message: format!("Type mismatch for <=: expected Integer on both sides, got {} <= {}", left_name, right_name),
                        node: node_name.to_string(),
                        line: None,
                    });
                }
                ("stdlib.integer.lte".to_string(), self.type_ir(&serde_json::Value::String("Bool".to_string())))
            }
            ">=" => {
                if (left_name != "Integer" || right_name != "Integer")
                    && left_name != "Unknown"
                    && right_name != "Unknown"
                {
                    type_errors.push(ClassifierDiagnostic {
                        rule: "OOF-TY0".to_string(),
                        message: format!("Type mismatch for >=: expected Integer on both sides, got {} >= {}", left_name, right_name),
                        node: node_name.to_string(),
                        line: None,
                    });
                }
                ("stdlib.integer.gte".to_string(), self.type_ir(&serde_json::Value::String("Bool".to_string())))
            }
```

**Pattern:** matches the `"<"` arm exactly (lines 4170–4183). Unknown guard: `left_name != "Unknown" && right_name != "Unknown"`. No Decimal pre-check interference — the pre-check block (lines 4009–4041) only fires for `+`, `-`, `*`.

---

## 6. Rust SIR Qualification Gap — DEFERRED

**Finding (from P1):** Rust emitter outputs `binary_op { "op": "<=" }` (raw symbol). Ruby emitter outputs `call { "fn": "stdlib.integer.lte", ... }` (qualified name, via TC call node conversion). This asymmetry exists today for `>` (already proved in P1 D-03/D-04).

**Decision:** DEFER. The gap is not a TC correctness blocker. Rust TC correctly resolves the operator type and emits diagnostics. The `resolved_op` in the Rust TC `BinaryOp` arm (`annotated_expr: None`) does not propagate qualified names to the emitter. This is a separate SIR emitter qualification card.

**P3 proof scope:** Ruby SIR `call { fn: "stdlib.integer.lt" }` checked. Rust SIR `binary_op { op: "<" }` noted and explicitly not checked as a gap (same as baseline `>`).

---

## 7. Inventory Plan

**File:** `igniter-lang/docs/spec/stdlib-inventory.json`

### Promote `stdlib.integer.gt`

Current state: `lifecycle_status: "orphaned"`, `semantic_stability: "sketch"`, `lowering_status: "dual-toolchain"`, `diagnostics: []`.

After P3:
- `lifecycle_status`: `"lab-implemented"`
- `semantic_stability`: `"stable"`
- `diagnostics`: `["OOF-TY0"]`
- `proof_lineage`: add `"LANG-STDLIB-NUMERIC-COMPARISON-P3 (promotion)"`
- `compatibility_note`: update to reflect promotion from orphaned

### Add `stdlib.integer.lt`

```json
{
  "canonical_name": "stdlib.integer.lt",
  "display_name": "Integer Less-Than",
  "category": "numeric/comparison",
  "signature": "(Integer, Integer) -> Bool",
  "lifecycle_status": "lab-implemented",
  "semantic_stability": "stable",
  "lowering_status": "dual-toolchain",
  "source_alias": "<",
  "diagnostics": ["OOF-TY0"],
  "proof_lineage": ["LANG-STDLIB-NUMERIC-COMPARISON-P3"],
  "compatibility_note": "Integer-only v0; Decimal/Float deferred"
}
```

Note: Rust TC already has `stdlib.integer.lt` live (line 4170). Ruby TC gets it in P3. `lowering_status: "dual-toolchain"` from day one.

### Add `stdlib.integer.lte`

```json
{
  "canonical_name": "stdlib.integer.lte",
  "source_alias": "<=",
  "lifecycle_status": "lab-implemented",
  "lowering_status": "dual-toolchain",
  "diagnostics": ["OOF-TY0"],
  ...
}
```

### Add `stdlib.integer.gte`

```json
{
  "canonical_name": "stdlib.integer.gte",
  "source_alias": ">=",
  "lifecycle_status": "lab-implemented",
  "lowering_status": "dual-toolchain",
  "diagnostics": ["OOF-TY0"],
  ...
}
```

---

## 8. App Pressure Resolved

| App | File | Operator | Ruby pre-P3 | Ruby post-P3 |
|-----|------|----------|-------------|--------------|
| `arch_patterns` | `pipeline.ig:30` | `amount < 1` | OOF-TY0 | ✓ ok |
| `arch_patterns` | `pipeline.ig:108` | `balance < amount` | OOF-TY0 | ✓ ok |
| `neural_net` | `activations.ig:26` | `x < (0 - 2500)` | OOF-TY0 | ✓ ok |
| `vector_math` | `geometry.ig:38-41` | nested `<`/`>` workaround for `>=` | workaround compiles | workaround continues to compile + real `>=` available |

`vector_math/geometry.ig` line 38: explicit comment "Using NOT-less-than instead of >= (unsupported operator)" — workaround confirmed. P3 unblocks native `>=` for a future cleanup card.

---

## 9. Proof Matrix for P3

**Target:** ≥40 checks / 9 sections

| Section | Label | Checks | Content |
|---------|-------|--------|---------|
| A | REGRESSION | 5 | Ruby `>` baseline unchanged; `==`, `&&`, arithmetic unchanged; no OOF regression |
| B | RUBY-LT-HAPPY | 5 | `x < y` ok; `x < 100` ok; SIR has `call { fn: "stdlib.integer.lt" }`; Bool result; no OOF |
| C | RUBY-LTE-GTE-HAPPY | 5 | `x <= y` ok; `x >= y` ok; correct SIR fn names; Bool result |
| D | RUST-LTE-GTE-HAPPY | 5 | `x <= y` status=ok; `x >= y` status=ok; Rust `<` regression (D-04 from P1) still ok |
| E | OOF-TY0-GUARDS | 5 | All four operators reject non-Integer (Text/Bool/mixed) with OOF-TY0 in both TCs |
| F | UNKNOWN-PERMISSIVE | 4 | `Unknown < Integer`, `Integer <= Unknown`, both TCs: ok, no OOF |
| G | SIR-SHAPE | 4 | Ruby SIR: `call { fn: "stdlib.integer.lt" }` nodes; Rust SIR: `binary_op { op: "<=" }` (gap noted, not a failure) |
| H | APP-FIXTURES | 5 | `arch_patterns/pipeline.ig` `amount < 1` compiles; `neural_net/activations.ig` `x < (0-2500)` compiles; vector_math `>=` workaround still ok |
| I | INVENTORY | 4 | `lt`/`lte`/`gte` entries present; `gt` promoted from orphaned → lab-implemented |

Total: **≥42 checks**

---

## 10. Authorized Files (P3)

| File | Change |
|------|--------|
| `igniter-lang/lib/igniter_lang/typechecker.rb` | 3 new `when` arms in `operator_type` (~9 lines) |
| `igniter-lang/lib/igniter_lang/semanticir_emitter.rb` | 3 new `when` arms in `operator_for` (~12 lines) |
| `igniter-lab/igniter-compiler/src/typechecker.rs` | 2 new match arms in `operator_type` (~24 lines) |
| `igniter-lang/docs/spec/stdlib-inventory.json` | Promote `gt` + add `lt`/`lte`/`gte` entries |

No parser changes. No Rust emitter changes. No new OOF codes. No VM/assembler.
