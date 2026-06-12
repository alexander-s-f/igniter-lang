# LANG-STDLIB-TEXT-EQUALITY-P1 — Readiness Proof v0

**Track:** lang / stdlib / primitive / equality  
**Route:** READINESS PROOF / PLANNING — NO CODE  
**Status:** CLOSED — PROVED 46/46  
**Date:** 2026-06-12  
**Predecessors:** LAB-RACK-P6 (Rust `==` implementation, `stdlib.primitive.eq` active), LANG-STDLIB-SUM-PROP-P3 (61/51 PASS pattern; operator_type precedent), LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P3 (61/61 PASS)

---

## Goal

Define deterministic Text/String equality across Ruby and Rust TypeCheckers.  
Prove the gap, confirm implementation scope, and document all boundary decisions.  
Accept or reject the implementation planning prerequisites for P2.

---

## Readiness Decision: ACCEPT — READY FOR P2 IMPLEMENTATION PLANNING

Single operator arm. ~10 lines in `typechecker.rb`. No new constants required.  
All questions answered. Rust parity proof confirmed. No SPLIT/HOLD conditions.

---

## Evidence: App Fixture Survey

Six app patterns block on Ruby's `Unsupported operator: ==` today:

| Pattern | App | Types |
|---------|-----|-------|
| `state.active_tool == "draw_rect"` | vector_editor/tools.ig | String == String literal |
| `layer.id == target_layer_id` | vector_editor/document.ig | String == String ref |
| `n.id == target_id`, `f.name == name`, `node.kind == "leaf"` | decision_tree/evaluator.ig | String == String |
| `event.kind == "Deposited"` / `"Withdrawn"` etc. | arch_patterns/event_sourcing.ig | String == String literal |
| `t.from_status == current_status`, `t.event_kind == event_kind` | arch_patterns/state_machine.ig | String == String |
| `balance == required_min` | arch_patterns/state_machine.ig | Integer == Integer |

All six hit `OOF-TY0 "Unsupported operator: =="` — confirmed by 46/46 proof (Section A).

---

## Q1 — Is `==` canonical for Text?

**Yes.** `==` is the canonical equality operator for `Text`, `String`, `Integer`, and `Bool`.  
It is operator syntax (`binary` AST kind, `op: "=="`) — not a function call. No stdlib function named `==` exists or should be created.

---

## Q2 — Type signature?

```
Text × Text -> Bool
String × String -> Bool
Text × String -> Bool     (compat)
String × Text -> Bool     (compat)
Integer × Integer -> Bool
Bool × Bool -> Bool
Unknown × _ -> Bool       (permissive, Unknown passthrough)
_ × Unknown -> Bool       (permissive, Unknown passthrough)
```

Decimal × Decimal: **excluded** (BK-P02 — separate card).

---

## Q3 — Unicode/normalization stance?

**Byte/value-exact. No locale. No Unicode normalization.**

The VM `binary_op` handler uses Rust `Value` equality directly — no locale, no case-folding, no Unicode normalization algorithm. This is confirmed by LAB-RACK-P6 comment in `typechecker.rs`:

> "The VM binary_op handler dispatches on op=="==" using Rust Value equality — no VM-side change needed; the TypeChecker gap was the sole blocker."

The Ch8 spec defines byte/rune/grapheme units for the 14 text stdlib functions (length, slicing). These models apply to those functions, not to `==`. Ch8 explicitly defers locale case-folding. No normalization contract for `==` required.

---

## Q4 — Cross-toolchain parity?

**Confirmed closed (LAB-RACK-P6).** Rust TypeChecker has a `when "==" =>` arm emitting `stdlib.primitive.eq` and returning `Bool`. Ruby TC has no `==` arm — that is the single gap this card closes.

Compatible pairs in Rust (confirmed from source):

```rust
("String",  "String")  |
("Text",    "Text")    |
("String",  "Text")    |
("Text",    "String")  |
("Integer", "Integer") |
("Bool",    "Bool")    |
("Unknown", _)         |
(_,         "Unknown")
```

Ruby implementation must match this exactly.

---

## Q5 — OOF-TY0 cases?

OOF-TY0 fires for incompatible concrete pairs: e.g., `Text == Integer`, `String == Bool`, `Integer == Text`.  
Unknown-paired operands pass permissively (no error) — matching the Unknown-propagates-permissively invariant throughout the TC.

---

## Q6 — Does equality imply ordering?

**No.** `>` is already live as `stdlib.integer.gt` (Integer-only). Text ordering (`<`, `<=`, `>=`) is not in scope. Adding `==` does not require `<` or any ordering arm. The Rust TC has separate independent `"==" =>` and `"<" =>` arms — they are orthogonal.

---

## Q7 — Relationship to stdlib text helpers?

`==` is operator syntax dispatched through `infer_binary` → `operator_type`. It is **not** a text stdlib function and must not be added to `TEXT_STDLIB_FNS`. The 14 text helpers (byte_length, grapheme_length, contains, starts_with, ends_with, etc.) remain unchanged. `contains`/`starts_with`/`ends_with` handle equality-adjacent semantics but are distinct function calls.

---

## Q8 — SIR/operator name?

`"stdlib.primitive.eq"` — matches Rust LAB-RACK-P6.

This is produced by `operator_type` and carried verbatim through `semantic_expr` in the emitter. Zero emitter changes required (same pattern as `stdlib.integer.gt` → emitter carries `fn` field verbatim).

---

## Q9 — Does it affect numeric equality? Keep scoped?

**Scoped to the compatible-pairs list above.** The `when "=="` arm handles Text/String/Integer/Bool/Unknown pairs as a unified operator. This is correct: Integer equality (`balance == required_min`) uses the same `stdlib.primitive.eq` SIR name and same `Bool` return type. Decimal is excluded by design (BK-P02).

No effect on `>` (Integer), `&&` (Bool), or any other existing operator arm.

---

## Q10 — Decimal == Decimal?

**Excluded from scope.** Decimal equality is tracked as BK-P02 (separate card, driven by `bookkeeping/PRESSURE_REGISTRY.md`). The Rust TC compatible-pairs list does not include `("Decimal", "Decimal")`. Ruby must follow suit.

---

## Q11 — Exact Ruby TypeChecker insertion point?

**One insertion in `lib/igniter_lang/typechecker.rb` — `operator_type` method (~line 1178).**

After the `when "&&"` arm, before the `else` arm:

```ruby
when "=="
  compatible = [
    ["Text",    "Text"],    ["String", "String"],
    ["Text",    "String"],  ["String", "Text"],
    ["Integer", "Integer"], ["Bool",   "Bool"]
  ]
  if left_name == "Unknown" || right_name == "Unknown" ||
     compatible.include?([left_name, right_name])
    ["stdlib.primitive.eq", type_ir("Bool")]
  else
    type_errors << oof("OOF-TY0",
      "Type mismatch for ==: cannot compare #{left_name} with #{right_name}",
      node_name)
    ["stdlib.unsupported.==", type_ir("Unknown")]
  end
```

**Total: ~10 lines. No other insertions. No other files.**

---

## Q12 — No VM change needed?

**Confirmed.** The VM `binary_op` handler already evaluates `op == "=="` using Rust `Value` equality. The TypeChecker was the sole blocker (LAB-RACK-P6 comment). No parser change needed — the parser already produces `{ "kind" => "binary", "op" => "==" }` AST nodes. No emitter change needed — `semantic_expr` carries `fn` from `operator_type` verbatim.

---

## Q13 — Proof matrix for P1?

**8 sections / 46 checks. Proof runner: `igniter-lang/experiments/text_equality_proof/verify_text_equality_p1.rb`**

| Section | Checks | Result |
|---------|--------|--------|
| A — App fixture survey (6 patterns block on ==) | 6 | 6/6 PASS |
| B — Ruby TC gap (all == forms → OOF-TY0; no arm in source) | 7 | 7/7 PASS |
| C — Rust TC parity (LAB-RACK-P6; stdlib.primitive.eq; compatible pairs) | 7 | 7/7 PASS |
| D — Type semantics (Text/String compat rule; Integer/Bool; Decimal out) | 6 | 6/6 PASS |
| E — Normalization (byte-exact / value-exact; no locale; no Unicode norm) | 5 | 5/5 PASS |
| F — Ordering orthogonality (== does not imply <; > for Integer already live) | 4 | 4/4 PASS |
| G — Stdlib relation (operator not function; TEXT_STDLIB_FNS has no ==) | 5 | 5/5 PASS |
| H — Authority closed (Decimal out; no VM change; no parser change; BK-P02) | 6 | 6/6 PASS |

---

## Summary: One-Point Implementation Plan

| Point | Location | Change |
|-------|----------|--------|
| 1 | `operator_type` in `typechecker.rb` | Add `when "=="` arm (~10 lines) after `when "&&"`, before `else` |

**Authorized file for P2:** `lib/igniter_lang/typechecker.rb` only.

---

## Data Flow

```
a == b
  → Parser: { kind: "binary", op: "==", left: a, right: b }
  → infer_binary in TypeChecker
  → operator_type("==", left_type, right_type, ...)
    ├─ compatible pair or Unknown? → ["stdlib.primitive.eq", Bool]
    └─ incompatible concrete pair → OOF-TY0 + ["stdlib.unsupported.==", Unknown]
  → semantic_expr in SemanticIREmitter: fn = "stdlib.primitive.eq" (verbatim)
```

---

## Authority Closed

No implementation in this doc.  
No VM/emitter/parser/assembler changes.  
No Decimal == Decimal (BK-P02 separate).  
No Text ordering (`<`, `<=`, `>=`).  
No new OOF codes beyond OOF-TY0.  
No new stdlib function entries.  
No normalization, no locale, no Unicode algorithm dependency.
