# LAB-UNARY-MINUS-P1 — Unary Minus Readiness Proof

**Track:** lang / parser / expression-surface
**Route:** READINESS PROOF
**Status:** CLOSED — PROVED 34/34
**Date:** 2026-06-12

---

## Summary

Proves the parser unary minus gap in both Ruby and Rust Igniter compilers.
`-500`, `-x`, `{ a: -300 }`, `[-1, 2]`, and `else { -1 }` all fail at parse time.
The workaround `0 - X` works today and is semantically correct for Integer.
Two apps (neural_net, vector_math) have confirmed pressure using the workaround.
A downstream TC gap also exists — `unary_op` AST nodes are not dispatched in `infer_expr`.
No implementation in this card.

---

## Files Created

| File | Role |
|------|------|
| `igniter-lang/experiments/unary_minus_proof/verify_unary_minus_p1.rb` | Proof runner |
| `igniter-lang/.agents/work/cards/lang/LAB-UNARY-MINUS-P1.md` | Card |
| This file | Proof packet |

---

## Gap Analysis

### Parser gap (Ruby and Rust, identical)

The lexer tokenizes `-` as `:op` type (not `:minus`). The `parse_unary` function handles
only `:bang` (`!`) as a prefix operator:

**Ruby** (`parser.rb`, ~line 1716):
```ruby
def parse_unary
  if peek_type?(:bang)
    op = advance.value
    expr = parse_postfix
    return { "kind" => "unary_op", "op" => op, "operand" => expr }
  end
  parse_postfix
end
```

**Rust** (`src/parser.rs`, ~line 2725):
```rust
fn parse_unary(&mut self) -> Result<Expr, String> {
    if self.peek_type(TokenType::Bang) {
        let op = self.advance().unwrap().value.clone();
        let operand = self.parse_postfix()?;
        return Ok(Expr::UnaryOp { op, operand: Box::new(operand) });
    }
    self.parse_postfix()
}
```

No minus case in either. When `-` is encountered as an expression prefix, `parse_primary`
is eventually called. `parse_primary` has no `:op` case — it falls through to the else branch:

```ruby
else
  @errors << { "message" => "Unexpected token in expression: #{tok.type}(#{tok.value})", ... }
```

This produces `parse=error` with message `"Unexpected token in expression: op(-)"` for most
forms. The record field `{ a: -300 }` produces a harder `ParseError` exception because after
consuming `-` as unexpected, `300` appears where a field name (identifier) is expected.

### TC gap (Ruby; downstream of parser)

Even if the parser emitted `{ "kind" => "unary_op", "op" => "-", "operand" => ... }`,
`infer_expr` in `typechecker.rb` has no `when "unary_op"` dispatch case:

```ruby
def infer_expr(expr, ...)
  case expr.fetch("kind")
  when "literal"    then ...
  when "symbol"     then ...
  when "ref"        then ...
  when "binary_op"  then infer_binary(...)
  when "call"       then infer_call(...)
  # ... other cases ...
  else
    type_errors << oof("OOF-TY0", "Unsupported expression kind: #{expr.fetch("kind")}", ...)
  end
end
```

This is confirmed by the `!x` case: bang parses successfully (Section E-01), but TC emits
`OOF-TY0 "Unsupported expression kind: unary_op"` (Section E-02/E-03).

Both gaps must be fixed in P2. Fixing the parser alone would shift the failure from parse-time
to typecheck-time.

---

## Proof Matrix Detail

### Section A — Ruby parse gap (6 checks)
A-01: `-500` integer literal → parse=error "Unexpected token in expression: op(-)"
A-02: `-x` variable negation → parse=error
A-03: `{ a: -300 }` record field → parse fails (ParseError: Expected name, got int_lit(300))
A-04: `[-1, 2, -3]` array literal → parse=error
A-05: `else { -1 }` if-branch → parse=error
A-06: `-(x + 1)` parenthesised form → parse=error

### Section B — Rust parse parity (3 checks)
B-01..B-03: same three forms produce parse=error "Unexpected token in expression: Op" in Rust

### Section C — Workaround (5 checks)
C-01..C-05: `0 - 500`, `0 - x`, `{ a: 0 - 300 }`, `else { 0 - 1 }`, multi-step bindings all parse=ok

### Section D — App pressure (7 checks)
D-01: neural_net/network.ig has ≥3 occurrences of `0 - N` pattern (weights: -0.5, -0.4, -0.2, -0.8, -0.1)
D-02: Comments explicitly show negative intent (`-- -0.5`, etc.)
D-03: neural_net/activations.ig uses `0 - 2500` for sigmoid threshold
D-04: vector_math/vec2.ig Vec2Negate: `x: 0 - v.x, y: 0 - v.y`
D-05: vector_math/vec2.ig Vec2Perp: `x: 0 - v.y, y: v.x`
D-06: No app file contains a bare `-N` literal (all already use workaround)
D-07: neural_net/network.ig confirmed clean of `= -N` patterns

### Section E — TC downstream gap (5 checks)
E-01: `!x` parses ok (bang in parse_unary)
E-02: `!x` TC emits OOF-TY0 mentioning "unary_op"
E-03: exact message: "Unsupported expression kind: unary_op"
E-04: bang/minus asymmetry confirmed (bang=parse ok, minus=parse error)
E-05: `infer_expr` method text contains no `when "unary_op"` arm

### Section F — Source text guards (5 checks)
F-01: `def parse_unary` defined in parser.rb
F-02: `parse_unary` function body has only bang case, no minus
F-03: lexer produces `Token.new(:op, "-", l, c)` — no :minus token type
F-04: BINARY_OPS includes `"-" => 5` (precedence at additive level)
F-05: parse_primary contains "Unexpected token in expression" error path

### Section G — Authority closed (3 checks)
G-01: Decimal/Float unary minus not in scope (no app pressure; Integer-only)
G-02: No numeric suffix system exists in Igniter lexer
G-03: `parse_unary` body unchanged — readiness proof only

---

## Workaround Equivalence

For Integer arithmetic, `0 - x` is exactly equivalent to `-x`:
- Additive inverse: `0 - x = -x` for all integers
- No precision loss (integers are exact)
- The workaround is semantically correct today

For negative literal constants like `-500`, `0 - 500` evaluates to `-500` at compile time
(the TC constant-fold path handles this). The workaround is semantically transparent.

---

## Implementation Plan for P2

### File 1: `parser.rb`

**Insertion in `parse_unary`** — add minus case after bang check:

```ruby
def parse_unary
  if peek_type?(:bang)
    op = advance.value
    expr = parse_postfix
    return { "kind" => "unary_op", "op" => op, "operand" => expr }
  end
  if peek_type?(:op) && peek&.value == "-"
    op = advance.value
    expr = parse_unary
    return { "kind" => "unary_op", "op" => op, "operand" => expr }
  end
  parse_postfix
end
```

Note: `parse_unary` recursion allows `--x` to be parsed (as double negation). If double
negation should be rejected, an explicit check can be added, but this is not required in P2.

### File 2: `typechecker.rb`

**Insertion in `infer_expr`** — add `when "unary_op"` case before `else`:

```ruby
when "unary_op"
  infer_unary(expr, symbol_types, type_errors, type_warnings, node_name)
```

**New private method `infer_unary`:**

```ruby
def infer_unary(expr, symbol_types, type_errors, type_warnings, node_name)
  op      = expr.fetch("op")
  operand = infer_expr(expr.fetch("operand"), symbol_types, type_errors, type_warnings, node_name)
  op_type = type_name(operand.fetch("resolved_type"))
  case op
  when "!"
    unless op_type == "Bool" || op_type == "Unknown"
      type_errors << oof("OOF-TY0", "Type mismatch for !: expected Bool, got #{op_type}", node_name)
    end
    typed_expr("unary_op", type_ir("Bool"), operand.fetch("deps"),
               "op" => op, "operand" => operand)
  when "-"
    unless op_type == "Integer" || op_type == "Unknown"
      type_errors << oof("OOF-TY0", "Type mismatch for -: expected Integer, got #{op_type}", node_name)
    end
    result_type = op_type == "Unknown" ? type_ir("Unknown") : type_ir("Integer")
    typed_expr("unary_op", result_type, operand.fetch("deps"),
               "op" => op, "operand" => operand)
  else
    type_errors << oof("OOF-TY0", "Unknown unary operator: #{op}", node_name)
    typed_expr("unary_op", type_ir("Unknown"), operand.fetch("deps"),
               "op" => op, "operand" => operand)
  end
end
```

**No other files.** No emitter, no assembler, no VM, no Rust, no stdlib, no inventory.

---

## P2 Proof Matrix Outline (≥40 checks / 8 sections)

| Section | Coverage |
|---------|----------|
| A — Regression | existing OOF codes and workaround behavior unchanged |
| B — Negative integer literals | `-500`, `-0`, record, array, if-branch, complex expr |
| C — Negative variable refs | `-x`, `-rec.field`, `-call(args)` |
| D — Type checking | Bool `!`, Integer `-`, type errors for wrong operand type |
| E — SIR | unary_op SIR node shape; fn field absent; type propagation |
| F — App fixtures | neural_net, vector_math compile with unary minus syntax |
| G — Workaround parity | `0 - 500` and `-500` produce equivalent results |
| H — Authority | no VM/Rust/emitter/stdlib/assembler changes |

---

## Authority Boundary Summary

Unary minus is parser-only syntax sugar for `0 - X` (Integer scope only).
No new capability, no runtime change, no new OOF code beyond reuse of OOF-TY0.
Implementation touches two files: `parser.rb` and `typechecker.rb`.
Scope is strictly Integer unary `-`; Decimal/Float are explicitly deferred.
The `!` operator TC fix is bundled because it shares the same `infer_unary` dispatch.
