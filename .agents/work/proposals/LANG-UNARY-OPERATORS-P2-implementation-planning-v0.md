# LANG-UNARY-OPERATORS-P2 — Implementation Planning

**Card:** LANG-UNARY-OPERATORS-P2  
**Status:** authored — pending review  
**Date authored:** 2026-06-12  
**Predecessor:** LANG-UNARY-OPERATORS-P1 (proposal authored; contracts frozen)  
**Next routes:** LANG-UNARY-OPERATORS-P3 (Ruby), LANG-UNARY-OPERATORS-P4 (Rust)

---

## 1. Purpose

Produce a concrete, file-specific implementation plan for unary `!` and unary `-`:
- Parser changes (both toolchains)
- TypeChecker changes (both toolchains)
- SIR emitter changes (both toolchains)
- Ruby-first split decision
- Proof matrix for P3 and P4

No implementation is authorized in P2.

---

## 2. Authorized Files

| File | Phase | Change |
|------|-------|--------|
| `igniter-lang/lib/igniter_lang/parser.rb` | P3 | Add unary `-` to `parse_unary` |
| `igniter-lang/lib/igniter_lang/typechecker.rb` | P3 | Add `when "unary_op"` arm + `infer_unary_op` helper |
| `igniter-lang/lib/igniter_lang/semanticir_emitter.rb` | P3 | Add `when "unary_op"` to `lower_expr` (pre-TC path) |
| `igniter-lab/igniter-compiler/src/parser.rs` | P4 | Add unary `-` to `parse_unary` |
| `igniter-lab/igniter-compiler/src/typechecker.rs` | P4 | Add `Expr::UnaryOp` arm to `infer_expr` |
| `igniter-lab/igniter-compiler/src/emitter.rs` | P4 | Add `unary_op` → stdlib call conversion in `semantic_expr_for_compute` |
| Stdlib inventory (JSON or equivalent) | P3/P4 | Two new entries: `stdlib.primitive.not`, `stdlib.integer.neg` |

**Not authorized:**
- `assembler.rb` / `assembler.rs`
- `classifier.rb` / `classifier.rs`
- Any VM arithmetic semantics beyond existing lowering
- Any new OOF codes
- Decimal/Float negation

---

## 3. Pipeline Context

### Ruby pipeline

```
Parser → Classifier → TypeChecker → SIR Emitter
```

- `typed_nodes` (emitter) calls `semantic_expr(decl.fetch("expr"))` on TC output.
- TC converts `unary_op` → `typed_expr("call", ...)` with qualified fn name.
- `semantic_expr` passes through generic hash traversal.
- **SIR output**: `{ kind: "call", fn: "stdlib.primitive.not", args: [operand], resolved_type: Bool }`

The Ruby SIR emitter's main typed path needs **no change** for `semantic_expr` / `typed_nodes`.
The only emitter change is in `lower_expr` (line 867, pre-TC path): add `when "unary_op"` for completeness.

### Rust pipeline

```
Parser → Classifier → TypeChecker → SIR Emitter
```

- TC annotates `TypedDecl.type_info` with resolved type but preserves original `Expr::UnaryOp`.
- `semantic_expr_for_compute` (emitter) receives the serialized `Expr::UnaryOp` as JSON.
- **Without emitter change**: SIR output would be `{ kind: "unary_op", op: "!", operand: {...} }` (no fn annotation).
- **With emitter change**: SIR output is `{ kind: "call", fn: "stdlib.primitive.not", args: [operand], resolved_type: Bool }`.

**Decision: Rust emitter SHOULD emit stdlib call nodes for parity with Ruby SIR.**
This is consistent with the existing `stdlib.text.*` and `stdlib.collection.*` rewrites in `semantic_expr`.
Change is in `semantic_expr_for_compute` (line 816): add `unary_op` delegation to `semantic_expr`.
Change is in `semantic_expr` (line 603): add a `unary_op` → `call` conversion block before the generic traversal.

---

## 4. Parser Plan

### 4.1 Lexer invariant (both toolchains)

`-` is tokenized as `TokenType::Op` (Rust, line 158) / `:op` (Ruby, line 129), not a dedicated Minus token.
A unary `-` at parse time is identified by position (prefix), not token type.

There is **no lexer change** in either toolchain.

### 4.2 Expression hierarchy

```
parse_expr
  └── parse_binary_or(0)
        └── parse_unary           ← add unary minus here
              └── parse_postfix
                    └── parse_primary
```

`parse_unary` is called as the LEFT operand of any binary expression. A `-` token seen at the start of `parse_unary` is necessarily a unary prefix — binary minus is consumed in the `parse_binary_or` loop AFTER `parse_unary` returns.

### 4.3 Ruby change — `parser.rb` line 1716

```ruby
def parse_unary
  if peek_type?(:bang)
    op = advance.value
    expr = parse_postfix
    return { "kind" => "unary_op", "op" => op, "operand" => expr }
  end
  # ADD:
  if peek_type?(:op) && peek&.value == "-"
    op = advance.value
    expr = parse_postfix
    return { "kind" => "unary_op", "op" => op, "operand" => expr }
  end
  parse_postfix
end
```

**Operand is `parse_postfix`, not `parse_unary`.** This is consistent with the `!` case and excludes unary chaining (`--x`) which is out of scope.

### 4.4 Rust change — `parser.rs` line 2725

```rust
fn parse_unary(&mut self) -> Result<Expr, String> {
    if self.peek_type(TokenType::Bang) {
        let op = self.advance().unwrap().value.clone();
        let operand = self.parse_postfix()?;
        return Ok(Expr::UnaryOp { op, operand: Box::new(operand) });
    }
    // ADD:
    let is_unary_minus = self.current()
        .map(|t| t.token_type == TokenType::Op && t.value == "-")
        .unwrap_or(false);
    if is_unary_minus {
        let op = self.advance().unwrap().value.clone();
        let operand = self.parse_postfix()?;
        return Ok(Expr::UnaryOp { op, operand: Box::new(operand) });
    }
    self.parse_postfix()
}
```

### 4.5 Parsed forms and expected AST nodes

| Source form | Expected AST |
|-------------|-------------|
| `-500` | `{ kind: unary_op, op: "-", operand: { kind: literal, value: 500, type_tag: Integer } }` |
| `-x` | `{ kind: unary_op, op: "-", operand: { kind: ref, name: "x" } }` |
| `{ a: -300 }` | record literal; field `a` expr = `unary_op{ op: "-", operand: literal(300) }` |
| `[-1, 2]` | array_literal; items[0] = `unary_op{ op: "-", operand: literal(1) }` |
| `else { -1 }` | else block return_expr = `unary_op{ op: "-", operand: literal(1) }` |
| `-(x+1)` | `unary_op{ op: "-", operand: binary_op{ op: "+", left: ref(x), right: literal(1) } }` |
| `!flag` | `{ kind: unary_op, op: "!", operand: { kind: ref, name: "flag" } }` |
| `!(x == y)` | `unary_op{ op: "!", operand: binary_op{ op: "==", left: ref(x), right: ref(y) } }` |

Record literal fields, array literal items, else-branch bodies all parse each element via `parse_expr` → `parse_binary_or` → `parse_unary`. The `-` case in `parse_unary` activates naturally in each context.

---

## 5. TypeChecker Plan

### 5.1 Ruby — `typechecker.rb`

#### 5.1.1 Add `when "unary_op"` to `infer_expr` dispatch (line ~864)

```ruby
when "unary_op"
  infer_unary_op(expr, symbol_types, type_errors, type_warnings, node_name)
```

Insert after `when "match_expr"`, before the `else` fallthrough.

#### 5.1.2 New private method `infer_unary_op`

```ruby
def infer_unary_op(expr, symbol_types, type_errors, type_warnings, node_name)
  op = expr.fetch("op")
  operand = infer_expr(expr.fetch("operand"), symbol_types, type_errors, type_warnings, node_name)
  operand_type = type_name(operand.fetch("resolved_type"))

  case op
  when "!"
    unless operand_type == "Unknown" || operand_type == "Bool"
      type_errors << oof("OOF-TY0",
        "stdlib.primitive.not: expected Bool operand, got #{operand_type}", node_name)
    end
    result_type = type_ir("Bool")
    fn_name     = "stdlib.primitive.not"
  when "-"
    unless operand_type == "Unknown" || operand_type == "Integer"
      type_errors << oof("OOF-TY0",
        "stdlib.integer.neg: expected Integer operand, got #{operand_type}", node_name)
    end
    result_type = type_ir("Integer")
    fn_name     = "stdlib.integer.neg"
  else
    type_errors << oof("OOF-TY0", "Unsupported unary operator: #{op}", node_name)
    result_type = type_ir("Unknown")
    fn_name     = "stdlib.unsupported.#{op}"
  end

  typed_expr("call", result_type, operand.fetch("deps"),
             "fn"   => fn_name,
             "args" => [operand])
end
```

**Key decisions:**
- `typed_expr("call", ...)` — consistent with `infer_binary` pattern; TC converts `unary_op` → `call`.
- Result type is always returned even on OOF-TY0 (Bool / Integer). No Unknown propagation on error. Mirrors `stdlib.primitive.eq` Bool-on-all-paths pattern.
- Unknown-permissive: `operand_type == "Unknown"` passes without error. Consistent with `!` / `-` on call_contract results.
- `infer_expr(operand)` is called BEFORE the op check — operand type errors (OOF-P1) still fire.

#### 5.1.3 OOF-TY0 message format

| Trigger | Message |
|---------|---------|
| `!Integer` | `stdlib.primitive.not: expected Bool operand, got Integer` |
| `!Text` | `stdlib.primitive.not: expected Bool operand, got Text` |
| `-Bool` | `stdlib.integer.neg: expected Integer operand, got Bool` |
| `-Text` | `stdlib.integer.neg: expected Integer operand, got Text` |
| `~x` (unsupported) | `Unsupported unary operator: ~` |

### 5.2 Rust — `typechecker.rs`

#### 5.2.1 Add `Expr::UnaryOp` arm to `infer_expr` (before `_ =>` wildcard)

Insert before the `_ =>` arm (~line 3964):

```rust
Expr::UnaryOp { op, operand } => {
    let operand_typed = self.infer_expr(
        operand, symbol_types, olap_env, type_shapes,
        type_errors, type_warnings, node_name,
        functions, contract_registry, current_contract_name,
    );
    let operand_type_name = self.type_name(&operand_typed.resolved_type);

    let (fn_name, result_type_name) = match op.as_str() {
        "!" => {
            if operand_type_name != "Unknown" && operand_type_name != "Bool" {
                type_errors.push(ClassifierDiagnostic {
                    rule: "OOF-TY0".to_string(),
                    message: format!(
                        "stdlib.primitive.not: expected Bool operand, got {}",
                        operand_type_name
                    ),
                    node: node_name.to_string(),
                    line: None,
                });
            }
            ("stdlib.primitive.not", "Bool")
        }
        "-" => {
            if operand_type_name != "Unknown" && operand_type_name != "Integer" {
                type_errors.push(ClassifierDiagnostic {
                    rule: "OOF-TY0".to_string(),
                    message: format!(
                        "stdlib.integer.neg: expected Integer operand, got {}",
                        operand_type_name
                    ),
                    node: node_name.to_string(),
                    line: None,
                });
            }
            ("stdlib.integer.neg", "Integer")
        }
        _ => {
            type_errors.push(ClassifierDiagnostic {
                rule: "OOF-TY0".to_string(),
                message: format!("Unsupported unary operator: {}", op),
                node: node_name.to_string(),
                line: None,
            });
            ("stdlib.unsupported", "Unknown")
        }
    };

    TypedExpression {
        resolved_type: self.type_ir(&serde_json::Value::String(result_type_name.to_string())),
        deps: operand_typed.deps,
        annotated_expr: None,
    }
}
```

**Note:** `annotated_expr: None` — consistent with `BinaryOp` arm. The original `Expr::UnaryOp` is preserved for the emitter. The Rust emitter's `semantic_expr` will handle the SIR conversion.

---

## 6. SIR Emitter Plan

### 6.1 Ruby emitter — pre-TC path (`lower_expr`, line 867)

The main typed pipeline (`semantic_expr`) requires **no change**: the TC has already converted `unary_op` → `call`.

The `lower_expr` pre-TC path (called from `emit()`) needs a `when "unary_op"` arm for completeness:

```ruby
# add after when "binary_op"
when "unary_op"
  lower_unary(expr, type_env, diagnostics, node_name)
```

New private method:

```ruby
def lower_unary(expr, type_env, diagnostics, node_name)
  operand = lower_expr(expr.fetch("operand"), type_env, diagnostics, node_name)
  op = expr.fetch("op")
  fn_name, result_type = unary_operator_for(op, operand.fetch("type"), diagnostics, node_name)
  {
    "expr" => {
      "kind" => "call",
      "fn"   => fn_name,
      "args" => [operand.fetch("expr")],
      "resolved_type" => type_ir(result_type)
    },
    "type" => result_type,
    "deps" => operand.fetch("deps")
  }
end

def unary_operator_for(op, operand_type, diagnostics, node_name)
  case op
  when "!"
    unless operand_type == "Unknown" || operand_type == "Bool"
      diagnostics << oof("OOF-TY0", "stdlib.primitive.not: expected Bool operand, got #{operand_type}", node_name)
    end
    ["stdlib.primitive.not", "Bool"]
  when "-"
    unless operand_type == "Unknown" || operand_type == "Integer"
      diagnostics << oof("OOF-TY0", "stdlib.integer.neg: expected Integer operand, got #{operand_type}", node_name)
    end
    ["stdlib.integer.neg", "Integer"]
  else
    diagnostics << oof("OOF-P0", "Unsupported unary operator: #{op}", node_name)
    ["stdlib.unsupported.#{op}", "Unknown"]
  end
end
```

### 6.2 Ruby SIR output shape

The Ruby SIR emitter produces `call` nodes from `unary_op` (same as binary ops):

```json
{
  "kind": "call",
  "fn": "stdlib.primitive.not",
  "args": [
    { "kind": "ref", "name": "flag", "resolved_type": { "name": "Bool", "params": [] } }
  ],
  "resolved_type": { "name": "Bool", "params": [] }
}
```

### 6.3 Rust emitter — `semantic_expr_for_compute` (line 816)

In `semantic_expr_for_compute`, add a delegation block before the generic `new_map` traversal:

```rust
if map.get("kind").and_then(|k| k.as_str()) == Some("unary_op") {
    return self.semantic_expr(val);
}
```

In `semantic_expr` (line 603), add a `unary_op` → stdlib call conversion block before the generic object traversal. This is analogous to the `stdlib.text.*` rewrite block:

```rust
// unary_op → stdlib qualified call
if map.get("kind").and_then(|k| k.as_str()) == Some("unary_op") {
    let op = map.get("op").and_then(|v| v.as_str()).unwrap_or("");
    let operand_val = map.get("operand").cloned().unwrap_or(Value::Null);
    let lowered_operand = self.semantic_expr(&operand_val);
    let (fn_name, result_type_name) = match op {
        "!" => ("stdlib.primitive.not", "Bool"),
        "-" => ("stdlib.integer.neg", "Integer"),
        _   => ("stdlib.unsupported", "Unknown"),
    };
    let mut m = serde_json::Map::new();
    m.insert("kind".to_string(), Value::String("call".to_string()));
    m.insert("fn".to_string(), Value::String(fn_name.to_string()));
    m.insert("args".to_string(), Value::Array(vec![lowered_operand]));
    let mut rt = serde_json::Map::new();
    rt.insert("name".to_string(), Value::String(result_type_name.to_string()));
    rt.insert("params".to_string(), Value::Array(Vec::new()));
    m.insert("resolved_type".to_string(), Value::Object(rt));
    return Value::Object(m);
}
```

### 6.4 Rust SIR output shape (after P4 emitter change)

```json
{
  "kind": "call",
  "fn": "stdlib.primitive.not",
  "args": [
    { "kind": "ref", "name": "flag" }
  ],
  "resolved_type": { "name": "Bool", "params": [] }
}
```

Parity with Ruby SIR: both emit `call { fn: "stdlib.primitive.not" }`.

---

## 7. Inventory Entries

Two entries follow the `stdlib.collection.is_empty` / `stdlib.collection.non_empty` pattern:

### `stdlib.primitive.not`

```json
{
  "name": "stdlib.primitive.not",
  "source_alias": "!",
  "kind": "unary_op",
  "input": "Bool",
  "output": "Bool",
  "diagnostics": ["OOF-TY0"],
  "unknown_permissive": true,
  "lifecycle": "lab-implemented",
  "lowering_status": "ruby-only"
}
```

Lifecycle upgrades to `dual-toolchain` in P4.

### `stdlib.integer.neg`

```json
{
  "name": "stdlib.integer.neg",
  "source_alias": "-",
  "kind": "unary_op",
  "input": "Integer",
  "output": "Integer",
  "diagnostics": ["OOF-TY0"],
  "unknown_permissive": true,
  "lifecycle": "lab-implemented",
  "lowering_status": "ruby-only"
}
```

---

## 8. Ruby-First vs Dual-Toolchain Decision

**Decision: Ruby first (P3), Rust parity (P4).**

Rationale:
1. Ruby proof fixtures run faster and inline — faster iteration on type contract and OOF message text.
2. Parser change is structurally identical in both toolchains; the Rust proof can reuse the same logical matrix.
3. App pressure (neural_net, vector_math) is on Rust baselines — but both baselines already PASS with `0-X` workarounds. The urgency is low enough to validate Ruby correctness first.
4. Rust TC change shape is clear from P3 proof: the P4 proof runner can be derived from P3's section structure.

**P3 scope:** Ruby parser + Ruby TC + Ruby emitter (lower_expr) + inventory entries (ruby-only)  
**P4 scope:** Rust parser + Rust TC + Rust emitter unary_op→call + inventory upgrade to dual-toolchain

---

## 9. Proof Matrix

### P3 (Ruby) — target ≥ 50 checks / 10 sections

| Section | Topic | Target checks |
|---------|-------|--------------|
| A | Parser: unary minus forms (`-500`, `-x`, `{a:-300}`, `[-1,2]`, `else{-1}`, `-(x+1)`) | 6 |
| B | Parser: `!` forms (`!flag`, `!(x==y)`) + AST shape | 4 |
| C | TC happy path: `!` — Bool result, `stdlib.primitive.not`, no OOF | 5 |
| D | TC happy path: `-` — Integer result, `stdlib.integer.neg`, no OOF | 5 |
| E | Unknown permissive: `!` on Unknown, `-` on Unknown | 4 |
| F | OOF-TY0: wrong operand type (`!Integer`, `!Text`, `-Bool`, `-Text`); result type on error path | 6 |
| G | SIR output: call nodes, fn names, resolved_type, no raw unary_op in SIR | 6 |
| H | App fixtures: neural_net negative weights / vector_math negate contracts | 6 |
| I | Regression: binary operators, is_empty/non_empty, if_expr, append unaffected | 6 |
| J | Authority closed: no Decimal/Float, no VM arithmetic, no new OOF codes | 2 |

**Total P3 target: ~50 checks**

### P4 (Rust) — target ≥ 45 checks / 9 sections

| Section | Topic | Target checks |
|---------|-------|--------------|
| A | Parser: same 6 forms compile without parse error | 6 |
| B | Parser: `!` forms; `Expr::UnaryOp` SIR node produced by parser | 4 |
| C | TC happy path: `!` — Bool result, no OOF-TY0 | 4 |
| D | TC happy path: `-` — Integer result, no OOF-TY0 | 4 |
| E | Unknown permissive | 3 |
| F | OOF-TY0: wrong operand | 5 |
| G | Rust SIR output: `call { fn: "stdlib.primitive.not" }` nodes (post-emitter rewrite) | 6 |
| H | App fixtures: neural_net + vector_math baselines pass; negative literals compile | 7 |
| I | Regression: existing baselines (DSA/neural_net/vector_math) still pass 81/81, 85/85, N/N | 6 |

**Total P4 target: ~45 checks**

---

## 10. App Fixture Test Cases

### P3 (Ruby) — proof-local fixtures

```igniter
-- H-01: neural_net workaround (regression — must still compile)
compute w12 = 0 - 500

-- H-02: neural_net with unary minus (new form)
compute w12 = -500

-- H-03: vector_math workaround (regression)
compute nx = 0 - v_x

-- H-04: vector_math Vec2Negate (new form)
compute nx = -v_x
compute ny = -v_y

-- H-05: !is_empty(items) composes
compute empty_check = !is_empty(items)

-- H-06: non_empty regression
compute ne = non_empty(items)
```

### P4 (Rust) — same fixtures via Rust compiler

The P4 proof runner should also verify:
- H-07: neural_net multi-file baseline hash unchanged (0-X workarounds compile to same SIR)
- H-08: unary minus in a real neural_net-like fixture produces expected SIR

---

## 11. What P3/P4 Do NOT Include

| Surface | Status |
|---------|--------|
| Decimal/Float unary minus | Deferred — depends on LAB-STDLIB-NUMERIC-FIXED-POINT-P1 |
| Binary comparison changes | Out of scope |
| Unary chaining (`--x`, `!!x`) | Out of scope |
| VM arithmetic beyond existing lowering | Out of scope |
| New OOF codes | Out of scope — OOF-TY0 reused with descriptive messages |
| `unary_op` liveness instrumentation | No change — existing liveness guards already walk operand |
| Parser `source_hash` change | Yes — any parser change changes artifact; baseline proof runners must re-derive hashes |

---

## 12. Hash Stability Note

Adding unary minus to the parser changes the source_hash for any file that is recompiled with new unary minus syntax. The existing neural_net and vector_math baselines use `0-X` workarounds — **their hashes do not change unless the source files are updated**. Proof runners for LAB-DSA-BASELINE-P1, LAB-NEURAL-NET-BASELINE-P1, and LAB-VECTOR-MATH-BASELINE-P1 remain valid through P3 and P4 (no source edits to app files).

If a future P5+ card migrates app source from `0-X` to `-X`, those baselines need new hash derivations and new proof runners.

---

## 13. Next Routes

| Card | Scope |
|------|-------|
| **LANG-UNARY-OPERATORS-P3** | Ruby: parser.rb + typechecker.rb + semanticir_emitter.rb (lower_expr) + inventory; proof ≥ 50/50 PASS |
| **LANG-UNARY-OPERATORS-P4** | Rust: parser.rs + typechecker.rs + emitter.rs (semantic_expr); inventory → dual-toolchain; proof ≥ 45/45 PASS |
| (future) **LANG-UNARY-OPERATORS-P5** | Migrate app source files from `0-X` to `-X`; re-derive baseline hashes |

---

## 14. Closed Surfaces

- No parser changes in this card
- No typechecker changes in this card
- No emitter changes in this card
- No new OOF codes
- No inventory entries
- No VM / runtime changes
- No Decimal / Float negation
- No operand chaining
