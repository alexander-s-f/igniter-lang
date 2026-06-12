# Proposal: LANG-UNARY-OPERATORS — Unary Operators (! and -)

**Card:** LANG-UNARY-OPERATORS-P1  
**Status:** authored — pending review  
**Date authored:** 2026-06-12  
**Next route:** LANG-UNARY-OPERATORS-P2 — implementation planning

---

## 1. Summary

Defines canonical contracts for two unary prefix operators — `!` (logical not) and `-` (integer negation) — covering their type contracts, SIR function names, error behavior, parser forms, and current implementation gap state. No typechecker or parser changes are authorized in this card.

---

## 2. Motivation

### App pressure

Both app clusters document active workaround pressure from the absence of unary `-`:

| App | Site | Pattern |
|-----|------|---------|
| neural_net/network.ig | 6+ negative weights | `0 - X` workaround (e.g. `0 - 500`, `0 - 300`) |
| neural_net/activations.ig | SigmoidApprox threshold | `0 - 2500` workaround |
| vector_math/vec2.ig | Vec2Negate | `0 - v.x` workaround |
| vector_math/vec2.ig | Vec2Perp | `0 - v.y` workaround |

All app files use the `0 - X` workaround exclusively — no bare `-\d+` literal appears in source (confirmed by LAB-UNARY-MINUS-P1 D-06).

For `!` (bang), the existing gap is documented by:
- `LANG-STDLIB-IS-EMPTY-PROP-P1`: `non_empty` added as a first-class sibling precisely because `!is_empty(x)` produces OOF-TY0
- `LANG-STDLIB-IS-EMPTY-PROP-P3` J-04: confirmed `infer_expr` still has no `when "unary_op"` arm after is_empty implementation

### Evidence baseline

LAB-UNARY-MINUS-P1: **34/34 PASS** — confirmed parse gap for `-`, workaround correctness, app pressure, TC downstream gap.

---

## 3. Canonical Contracts

### D1: `!` — Logical Not

| Field | Value |
|-------|-------|
| Source alias | `!` (prefix unary operator) |
| Canonical SIR name | `stdlib.primitive.not` |
| Type contract | `Bool → Bool` |
| Placement | `stdlib.primitive` (consistent with `stdlib.primitive.eq`) |
| Unknown permissive | Yes — `!Unknown` → Bool |
| Wrong operand | OOF-TY0 |

`!` is valid only on Bool. Integer, Text, Collection, and other concrete types all produce OOF-TY0. The result type is always Bool — even on the error path (mirrors `stdlib.primitive.eq` Bool-on-all-paths pattern).

### D2: `-` — Integer Negation

| Field | Value |
|-------|-------|
| Source alias | `-` (prefix unary operator) |
| Canonical SIR name | `stdlib.integer.neg` |
| Type contract | `Integer → Integer` |
| Unknown permissive | Yes — `-Unknown` → Integer |
| Wrong operand | OOF-TY0 |

`-` (unary) is valid only on Integer in v0. Decimal and Float operands are deferred (see D5). The result type is always Integer.

### D3: OOF Coverage

| Code | Trigger | New/Reuse |
|------|---------|-----------|
| OOF-TY0 | Wrong operand type for `!` or `-`; or unsupported unary op | Reuse |

No new OOF codes. OOF-TY0 message SHOULD be descriptive:
- `"stdlib.primitive.not: expected Bool operand, got X"` (wrong type for `!`)
- `"stdlib.integer.neg: expected Integer operand, got X"` (wrong type for `-`)
- `"Unsupported unary operator: X"` (any other unary op not in scope)

### D4: Unknown permissive

Both operators apply Unknown-permissive semantics, consistent with the append/is_empty/fold patterns:

| Operator | Operand type | Result type | Rationale |
|----------|--------------|-------------|-----------|
| `!` | Unknown | Bool | `!` always produces Bool regardless of operand |
| `-` | Unknown | Integer | `-` always produces Integer in v0; Unknown = unresolved, not wrong |

### D5: Decimal/Float deferred

Decimal and Float negation are not in scope for this proposal. The `0 - x` workaround compiles for Integer today; Decimal negation depends on LAB-STDLIB-NUMERIC-FIXED-POINT-P1. No future timeline is implied by this proposal.

---

## 4. Parser Forms

Both `!` and `-` must be valid as prefix operators in these syntactic positions:

| Form | Example (`!`) | Example (`-`) |
|------|--------------|--------------|
| Bool/Integer literal | `!true`, `!false` | `-500`, `-1` |
| Variable | `!x` | `-x` |
| Record field access | `!r.active` | `-r.value` |
| Array literal element | `[!a, !b]` | `[-1, 2, -3]` |
| If-branch result | `if c { !x } else { x }` | `if c { -x } else { x }` |
| Parenthesized | `!(x)`, `!(a && b)` | `-(x + 1)` |

Record field access `r.active` is a postfix form — the unary prefix operator binds outside it, so `!r.active` parses as `!(r.active)`. This is already the natural result of `parse_unary → parse_postfix` ordering.

---

## 5. Current Gap State

### Parser

| Toolchain | `!x` | `-x` |
|-----------|------|------|
| Ruby | **PARSE OK** — `parse_unary` handles `:bang` | **PARSE ERROR** — "Unexpected token in expression: op(-)" |
| Rust | **PARSE OK** — `parse_unary` handles `TokenType::Bang` | **PARSE ERROR** — same gap |

Ruby `parse_unary` handles only `:bang` then falls to `parse_postfix`. Rust `parse_unary` handles only `TokenType::Bang` then calls `parse_postfix`. Neither has a `-` case.

#### D6: Lexer note — `-` token type in Ruby

The Ruby lexer tokenizes `-` as `:op` (not `:minus` or a dedicated token). To add unary `-`, `parse_unary` must check `peek_type?(:op)` AND `current.value == "-"`, not a dedicated token type. This is the only non-obvious parser detail for P2 planning.

### Typechecker

| Toolchain | `!x` (Bool) | `-x` (Integer) |
|-----------|------------|----------------|
| Ruby TC | **OOF-TY0** — no `when "unary_op"` arm in `infer_expr` | Not reached (parse fails first) |
| Rust TC | **OOF-TY0** — no `Expr::UnaryOp` arm in `infer_expr` | Not reached (parse fails first) |

Confirmed:
- Ruby: `infer_expr` dispatch goes through `when "binary_op"`, `when "call"`, `when "if_expr"`, etc. — no `when "unary_op"` arm; falls to `else` → OOF-TY0 "Unsupported expression kind: unary_op"
- Rust: same — wildcard `_` arm → OOF-TY0 "Unsupported expression kind: \"unary_op\""
- `unary_op` IS handled in graph traversal helpers (`fn_expr_has_call?`, liveness) but not in type inference
- Rust runtime confirmation: `!x` where x:Bool compiles to parse=ok, then TC OOF-TY0

### Summary table

| | Ruby | Rust |
|---|------|------|
| `!` parser | ✓ ok | ✓ ok |
| `-` parser | ✗ parse error | ✗ parse error |
| `!` TC | ✗ OOF-TY0 | ✗ OOF-TY0 |
| `-` TC | n/a (blocked at parse) | n/a (blocked at parse) |

---

## 6. Proposed Implementation Shape (for P2 planning reference)

This section is informational — no implementation is authorized in P1.

### D7: Parser changes (both toolchains)

Add a `-` case to `parse_unary` immediately after the `!` case:
- Ruby: `if peek_type?(:op) && current_token.value == "-"` → advance, recurse into `parse_postfix`, return `unary_op` node with `op: "-"`
- Rust: analogous check for `TokenType::Op` with value `"-"` (or `TokenType::Minus` if that token type exists)

### D8: TC change shape

Ruby — new `when "unary_op"` arm in `infer_expr`. Delegates to a new private `infer_unary_op(expr, contract_name, symbol_types, type_shapes)`:
1. Infer operand type via `infer_expr`
2. Match on `expr["op"]`: `"!"` → expect Bool; `"-"` → expect Integer
3. Unknown-permissive on both
4. Wrong type → push OOF-TY0 (descriptive message); still return the declared result type (Bool / Integer) — no Unknown propagation
5. Other op → OOF-TY0 "Unsupported unary operator: X"

Rust — new `Expr::UnaryOp { op, operand }` arm in `infer_expr` before the wildcard `_`. Same logic.

### D9: SIR function name

TC annotates the `unary_op` node with the canonical SIR fn name:
- `op == "!"` → `fn: "stdlib.primitive.not"`
- `op == "-"` → `fn: "stdlib.integer.neg"`

This follows the binary_op precedent (`operator_type` returns qualified fn name). The SIR emitter uses this fn name in its output.

### D10: Emitter path

The Rust emitter already has a `unary_op` dispatch path in `lower_expr_for_targets` (emitter.rs) that rewrites `unary_op { op, operand }` → `lowered_form_call(target, [operand])` via a targets table lookup. This is the natural P4 Rust emitter slot. The Ruby emitter currently has no `unary_op` handling — to be added alongside Ruby TC in P3.

### D11: Operand chaining

`!-x` (not of neg) and `-!x` (neg of not, type-invalid) are not in scope for P1 or P2. If the parser eventually supports chaining (e.g. `!!x`), that is a separate proposal.

---

## 7. Inventory

`stdlib.primitive.not` and `stdlib.integer.neg` require inventory entries. Inventory integration follows the append / is_empty pattern:

| Phase | Deliverable |
|-------|-------------|
| P2 | Implementation planning |
| P3 | Ruby TC + inventory entries (lifecycle=lab-implemented, lowering=ruby-only) |
| P4 | Rust TC + emitter + inventory `lowering_status` → dual-toolchain |

No inventory entries are added in P1.

---

## 8. Closed Surfaces

- No parser changes in this card
- No typechecker changes in this card
- No emitter changes in this card
- No inventory entries in this card
- No VM / runtime authority
- No binary operator parity
- No Decimal / Float negation
- No operand chaining (`!!x`, `!-x`)
- No new OOF codes

---

## 9. Next Route

**LANG-UNARY-OPERATORS-P2** — implementation planning:
- Select authorized files: `parser.rb`, `typechecker.rb`, `parser.rs`, `typechecker.rs`, `emitter.rs`, `stdlib-inventory.json`, proof runner
- Plan `parse_unary` `-` case (Ruby + Rust)
- Plan `infer_unary_op` helper signature and OOF-TY0 message exact text
- Decide parser split (Ruby P3 / Rust P4) vs dual-toolchain in P3
- Proof matrix ≥60 checks / 9+ sections (parser gap / `!` happy / `-` happy / OOF / Unknown / SIR names / app fixtures / regression / authority)
