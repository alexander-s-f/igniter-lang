# LANG-STDLIB-TEXT-EQUALITY-P2 — Implementation Planning v0

**Track:** lang / stdlib / primitive / equality  
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE  
**Status:** CLOSED — READY FOR P3  
**Date:** 2026-06-12  
**Predecessors:** LANG-STDLIB-TEXT-EQUALITY-P1 (46/46 PASS), LAB-RACK-P6 (Rust `stdlib.primitive.eq` live), LANG-STDLIB-SUM-PROP-P3 (51/51 PASS; operator_type arm precedent)

---

## Goal

Plan the implementation for `==` equality in the Ruby TypeChecker.  
Answer all required questions. Confirm READY FOR P3 or identify blocking conditions.

---

## Planning Decision: READY FOR P3

One insertion. One arm. Two new lines (arm header + logic). One guard push. One return.  
All questions answered. No SPLIT. No HOLD.

---

## Q1 — Exact insertion point in `operator_type`?

**One insertion in `lib/igniter_lang/typechecker.rb` — `operator_type` method.**

Current method structure (lines 1181–1207):

```ruby
def operator_type(op, left, right, type_errors, node_name)  # line 1181
  left_name = type_name(left)
  right_name = type_name(right)
  case op
  when "+"    # line 1185 → stdlib.integer.add, Integer
  when "-"    # line 1188 → stdlib.integer.sub, Integer
  when "*"    # line 1191 → stdlib.integer.mul, Integer
  when "/"    # line 1194 → stdlib.integer.div, Integer
  when ">"    # line 1197 → stdlib.integer.gt, Bool
  when "&&"   # line 1200 → stdlib.bool.and, Bool
  #           ← INSERT here (after line 1202, before line 1203 'else')
  else        # line 1203 → OOF-TY0 "Unsupported operator:", Unknown
  end
end           # line 1207
```

**Insert after line 1202** (`["stdlib.bool.and", type_ir("Bool")]`), **before line 1203** (`else`):

```ruby
      when "=="
        compatible = unknown?(left, right) ||
                     %w[Text String].include?(left_name) && %w[Text String].include?(right_name) ||
                     left_name == right_name && %w[Integer Bool].include?(left_name)
        type_errors << oof("OOF-TY0", "Type mismatch for ==: cannot compare #{left_name} with #{right_name}", node_name) unless compatible
        ["stdlib.primitive.eq", type_ir("Bool")]
```

**Total: 5 new lines in `typechecker.rb`. No other files.**

---

## Q2 — Which pairs are accepted?

**All of:**

| Left | Right | Accepted? |
|------|-------|-----------|
| Text | Text | ✓ |
| String | String | ✓ |
| Text | String | ✓ (cross-compat, matches Rust + `text_arg_compatible?` precedent) |
| String | Text | ✓ (cross-compat) |
| Integer | Integer | ✓ |
| Bool | Bool | ✓ |
| Unknown | any | ✓ (permissive passthrough) |
| any | Unknown | ✓ (permissive passthrough) |
| Decimal | Decimal | ✗ (BK-P02 separate) |
| Integer | Bool | ✗ |
| Text | Integer | ✗ |
| any other concrete pair | — | ✗ |

**Logic:**

```ruby
compatible = unknown?(left, right) ||
             %w[Text String].include?(left_name) && %w[Text String].include?(right_name) ||
             left_name == right_name && %w[Integer Bool].include?(left_name)
```

- First clause: `unknown?` — passes if either operand is `Unknown` (existing helper, line 1367).
- Second clause: Text/String cross-compat — covers Text×Text, String×String, Text×String, String×Text.
- Third clause: same-type primitive — covers Integer×Integer, Bool×Bool. Decimal is excluded because `"Decimal"` is not in `%w[Integer Bool]`.

**Why Integer and Bool in the same arm?** Rust LAB-RACK-P6 defines all six pairs in a single `"==" =>` arm. Ruby mirrors this: `stdlib.primitive.eq` is the canonical SIR name regardless of the operand type. Splitting into separate arms would diverge from Rust parity and add unnecessary structure for three lines of logic.

---

## Q3 — What diagnostic for incompatible types?

**OOF-TY0.** No new diagnostic code. The existing `else` arm already emits OOF-TY0 for all unknown operators. The `==` arm uses the same code with a more specific message:

```ruby
type_errors << oof("OOF-TY0", "Type mismatch for ==: cannot compare #{left_name} with #{right_name}", node_name) unless compatible
```

**Return type on error:** `["stdlib.primitive.eq", type_ir("Bool")]` — Bool is always returned, even when the error is pushed. This matches Rust parity (Rust returns `Bool` unconditionally from the `==` arm) and avoids cascading downstream errors when `output m : Bool` is declared.

**Why not `type_mismatch` helper?** The `type_mismatch` helper emits `"Type mismatch: expected X, got Y"` — that format suits single-expected-type arms (+, -, *, /, >, &&). For `==`, there is no single expected type: the constraint is a compatible-pair relation. The custom message "cannot compare X with Y" is clearer and matches Rust's format.

---

## Q4 — SIR name?

`"stdlib.primitive.eq"` — the fully qualified canonical name, matching Rust LAB-RACK-P6.

`operator_type` returns `["stdlib.primitive.eq", type_ir("Bool")]`. The return flows through `infer_binary` (line 1171) into `typed_expr` at line 1176: `"fn" => operator`. The generic `semantic_expr` in `semanticir_emitter.rb` carries the `fn` field verbatim — confirmed by the same path used for `stdlib.integer.gt`, `stdlib.bool.and`, and every other operator. Zero emitter changes.

---

## Q5 — Decimal exclusion confirmed?

**Confirmed.** `"Decimal"` is not in `%w[Text String]` and not in `%w[Integer Bool]`. A fixture with `Decimal == Decimal` does not satisfy `unknown?` and does not match either clause — the guard fires OOF-TY0.

This follows Rust parity: the Rust compatible-pairs list has no `("Decimal", _)` or `(_, "Decimal")` entry. BK-P02 owns Decimal equality independently.

---

## Q6 — Does `==` affect ordering?

**No.** The `when ">"` arm at line 1197 is unchanged. The `when "=="` arm inserts between `when "&&"` and `else` — it has no structural coupling to any other arm. Adding `==` does not require `<` (`Text.<` is not in scope). The Rust TC has independent `"==" =>` and `"<" =>` arms — this Ruby arm is equally independent.

---

## Q7 — Does it require an emitter change?

**No.** Zero emitter changes. The `SemanticIREmitter#semantic_expr` carries the `fn` field verbatim from whatever `operator_type` returns. This is the same path as `stdlib.integer.gt` → `semantic_expr` → SIR node with `fn: "stdlib.integer.gt"`. The emitter does not inspect or transform operator names — it is a structural pass-through.

Confirmed: `semanticir_emitter.rb` has no operator-specific rewriting. The `fn` key in `typed_expr` flows directly into the SIR `compute` node's `fn` field.

---

## Q8 — Does it require a parser change?

**No.** The parser already produces `{ "kind" => "binary_op", "op" => "==" }` for `a == b`. This is confirmed by P1 Section A (all six app fixture patterns produced OOF-TY0 from `infer_binary` → `operator_type` → `else` arm — meaning the parser DID parse them and DID route them to `operator_type`; the gap was only the missing arm). No grammar change needed.

---

## Q9 — Does it require a VM change?

**No.** The VM `binary_op` handler already dispatches on `op == "=="` using Rust `Value` equality — no VM-side change was needed when LAB-RACK-P6 landed (confirmed by LAB-RACK-P6 comment). Ruby implementation changes only what the TypeChecker emits; the runtime path is unchanged.

---

## Q10 — `text_arg_compatible?` precedent — do we need a new helper?

**No new helper.** The `text_arg_compatible?` helper at line 1712 (`%w[Text String].include?(actual)`) handles Text ≡ String for stdlib text function arguments. The `==` arm reuses the same compatibility semantics inline — `%w[Text String].include?(left_name) && %w[Text String].include?(right_name)` — without needing to call `text_arg_compatible?` directly, because the second operand check is also a Text/String inclusion, not an argument validation. The helper is for text stdlib function arg checks; the operator arm is structurally different.

---

## Q11 — Filter predicate improvement?

**Yes, as a side-effect.** Today, `filter(rows, p -> p.dir == "Debit")` hits OOF-TY0 inside the predicate body (because `==` is unsupported), which pushes the predicate body type to `Unknown`, which passes OOF-COL3 permissively. After P3, the predicate body correctly resolves to `Bool`, and OOF-COL3 passes cleanly (no `Unknown` permissive bypass needed). This is not a new feature — it is a correct downstream consequence of `==` returning `Bool`.

---

## Q12 — Proof matrix for P3?

**10 sections / 50 checks. Proof runner: `igniter-lang/experiments/text_equality_proof/verify_text_equality_p3.rb`**

### Section A — Regression: existing operators unaffected (8)

| ID | Fixture | Expected |
|----|---------|----------|
| A-01 | `Integer + Integer` | stdlib.integer.add, Integer, no error |
| A-02 | `Integer - Integer` | stdlib.integer.sub, Integer, no error |
| A-03 | `Integer * Integer` | stdlib.integer.mul, Integer, no error |
| A-04 | `Integer / Integer` | stdlib.integer.div, Integer, no error |
| A-05 | `Integer > Integer` | stdlib.integer.gt, Bool, no error |
| A-06 | `Bool && Bool` | stdlib.bool.and, Bool, no error |
| A-07 | `String + String` | OOF-TY0 still fires (non-Integer + guard unchanged) |
| A-08 | `a %%% b` (unknown operator) | OOF-TY0 "Unsupported operator: %%%" (else arm unchanged) |

### Section B — Text/String happy paths (6)

| ID | Fixture | Expected |
|----|---------|----------|
| B-01 | `Text == Text` | no OOF-TY0; fn = stdlib.primitive.eq; return Bool |
| B-02 | `String == String` | no OOF-TY0; fn = stdlib.primitive.eq; return Bool |
| B-03 | `Text == String` | no OOF-TY0 (cross-compat) |
| B-04 | `String == Text` | no OOF-TY0 (cross-compat) |
| B-05 | `String field == String literal "leaf"` | no OOF-TY0 |
| B-06 | `String field == String ref` (two String inputs) | no OOF-TY0 |

### Section C — Integer/Bool equality (4)

| ID | Fixture | Expected |
|----|---------|----------|
| C-01 | `Integer == Integer` | no OOF-TY0; fn = stdlib.primitive.eq |
| C-02 | `Bool == Bool` | no OOF-TY0; fn = stdlib.primitive.eq |
| C-03 | `Integer == Integer` return type | Bool |
| C-04 | `Bool == Bool` return type | Bool |

### Section D — Unknown passthrough (4)

| ID | Fixture | Expected |
|----|---------|----------|
| D-01 | Unknown input == Text input | no OOF-TY0 (Unknown permissive) |
| D-02 | Text input == Unknown input | no OOF-TY0 (Unknown permissive) |
| D-03 | Unknown == Unknown | no OOF-TY0 |
| D-04 | Unknown == Integer | no OOF-TY0 |

### Section E — Incompatible pairs → OOF-TY0 (6)

| ID | Fixture | Expected |
|----|---------|----------|
| E-01 | `Text == Integer` | OOF-TY0 |
| E-02 | `String == Bool` | OOF-TY0 |
| E-03 | `Integer == Text` | OOF-TY0 |
| E-04 | `Bool == String` | OOF-TY0 |
| E-05 | `Integer == Bool` | OOF-TY0 |
| E-06 | OOF-TY0 message includes operand names | "cannot compare X with Y" |

### Section F — Decimal excluded (3)

| ID | Fixture | Expected |
|----|---------|----------|
| F-01 | `Decimal[2] == Decimal[2]` | OOF-TY0 (Decimal not in compatible pairs) |
| F-02 | `Decimal[2] == Integer` | OOF-TY0 |
| F-03 | OOF-TY0 message mentions "Decimal" | confirmed |

### Section G — SIR name and return type (5)

| ID | Check | Expected |
|----|-------|----------|
| G-01 | fn field for Text == Text | "stdlib.primitive.eq" |
| G-02 | fn field for Integer == Integer | "stdlib.primitive.eq" |
| G-03 | return type for all compatible pairs | Bool |
| G-04 | return type even for incompatible pairs | Bool (error pushed, Bool returned — Rust parity) |
| G-05 | "stdlib.primitive.eq" absent from TEXT_STDLIB_FNS | confirmed (source check) |

### Section H — App fixture patterns (6)

| ID | Pattern | Expected |
|----|---------|----------|
| H-01 | `state.active_tool == "draw_rect"` (vector_editor) | no OOF-TY0 |
| H-02 | `layer.id == target_layer_id` (vector_editor) | no OOF-TY0 |
| H-03 | `node.id == target_id` (decision_tree) | no OOF-TY0 |
| H-04 | `node.kind == "leaf"` (decision_tree) | no OOF-TY0 |
| H-05 | `event.kind == "Deposited"` (arch_patterns) | no OOF-TY0 |
| H-06 | `balance == required_min` (arch_patterns Integer) | no OOF-TY0 |

### Section I — Filter predicate integration (3)

| ID | Fixture | Expected |
|----|---------|----------|
| I-01 | `filter(rows, p -> p.dir == "Debit")` | no OOF-TY0 in predicate (clean dispatch) |
| I-02 | filter result type | Collection[Row] (correctly typed, not Unknown) |
| I-03 | predicate body type | Bool (OOF-COL3 gate now passes cleanly — no Unknown bypass) |

### Section J — Authority closed (5)

| ID | Check | Expected |
|----|-------|----------|
| J-01 | No emitter change — `semantic_expr` carries fn verbatim | confirmed (source check) |
| J-02 | No parser change — `when "binary_op"` → `infer_binary` already routes `==` | confirmed (source check) |
| J-03 | No VM change — LAB-RACK-P6 comment confirms VM already handles == | confirmed (Rust source) |
| J-04 | One insertion point only — `when "=="` arm in `operator_type` | confirmed (source check) |
| J-05 | OOF-TY0 is the right code — no new diagnostic namespace | confirmed |

**Total: 50 checks across 10 sections.**

---

## Q13 — Regression matrix?

| Suite | Expected count | Notes |
|-------|---------------|-------|
| string_core_proof | PASS | standard smoke |
| verify_stdlib_collection_map_filter_p3.rb | 61/61 | HOF dispatch unaffected |
| verify_stdlib_outcome_p3.rb | 60/60 | outcome helpers unaffected |
| verify_stdlib_sum_p3.rb | 51/51 | sum dispatch unaffected |
| verify_stdlib_fold_p3.rb | 52/52 | fold dispatch unaffected |
| verify_typed_contract_ref_p5.rb | 71/71 | cross-module refs unaffected |

Note: `verify_text_equality_p1.rb` (46/46) is a **GAP proof** — it tests the current broken state. After P3 adds `==` support, Sections A and B of the P1 proof (which assert `OOF-TY0` is present) will fail by design. The P1 proof is NOT in the regression suite. The new `verify_text_equality_p3.rb` is its replacement.

---

## Summary: One-Point Implementation Plan

| Point | Location | Change |
|-------|----------|--------|
| 1 | `operator_type` in `typechecker.rb` line ~1203 | Insert `when "=="` arm (5 lines) after `when "&&"`, before `else` |

**Authorized file for P3:** `lib/igniter_lang/typechecker.rb` only.

---

## Data Flow

```
a == b
  → Parser: { kind: "binary_op", op: "==" }
  → infer_binary (line 1168): infers left + right types
  → operator_type("==", left_type, right_type, ...)  [line 1181]
    ├─ compatible? (unknown? || Text/String || same Integer/Bool) → ["stdlib.primitive.eq", Bool]
    └─ incompatible → OOF-TY0 + ["stdlib.primitive.eq", Bool]
  → typed_expr("call", Bool, deps, "fn" => "stdlib.primitive.eq")  [line 1172]
  → semantic_expr in SemanticIREmitter: fn = "stdlib.primitive.eq" (verbatim)
```

---

## Full Insertion (5 lines)

```ruby
      when "=="
        compatible = unknown?(left, right) ||
                     %w[Text String].include?(left_name) && %w[Text String].include?(right_name) ||
                     left_name == right_name && %w[Integer Bool].include?(left_name)
        type_errors << oof("OOF-TY0", "Type mismatch for ==: cannot compare #{left_name} with #{right_name}", node_name) unless compatible
        ["stdlib.primitive.eq", type_ir("Bool")]
```

Insert between line 1202 (`["stdlib.bool.and", type_ir("Bool")]`) and line 1203 (`else`).

---

## Authority Closed

No Ruby TC implementation in this doc.  
No Decimal == Decimal (BK-P02 separate).  
No Text ordering (`<`, `<=`, `>=`).  
No emitter / no parser / no VM / no assembler changes.  
No new OOF codes. No TEXT_STDLIB_FNS changes.  
No normalization, no locale, no Unicode algorithm dependency.

---

## Open (P3+)

1. Ruby implementation — P3 proof runner `verify_text_equality_p3.rb` (50 checks / 10 sections)
2. Inventory entry for `stdlib.primitive.eq` — deferred to stdlib entry contract track
3. Decimal == Decimal — BK-P02 separate card
4. Text ordering (`<`) — separate future card
5. Rust SIR name already `stdlib.primitive.eq` — no Rust parity gap to close
