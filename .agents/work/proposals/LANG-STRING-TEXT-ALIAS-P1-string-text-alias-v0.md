# LANG-STRING-TEXT-ALIAS-P1: String/Text Alias Readiness

**Track:** lang / type-system / stdlib  
**Route:** PROPOSAL + READINESS PROOF ONLY — no implementation  
**Date:** 2026-06-13  
**Status:** authored — pending review  
**Lineage:** LANG-STDLIB-STRING-SURFACE-P1 (deferred here explicitly); APP-RECHECK-WAVE-P7 (sim_framework SIM-P10/P11 ACTIVE)  
**Proof:** 47/47 PASS — `igniter-lang/experiments/string_text_alias_proof/verify_string_text_alias_p1.rb`

---

## Problem Statement

`sim_framework` is blocked in the Ruby toolchain at Wave P7 with two ACTIVE diagnostics:

- **SIM-P10** — `OOF-TY0: record literal field 'rule_name': expected String, got Text`
- **SIM-P11** — `OOF-TY1: Output type mismatch: expected SimEvent, got Unknown` (cascade from SIM-P10)

Root location: `sim_framework/constraints.ig`, `DecideAction` contract:

```ig
compute corrective_event = {
  tick:      0,
  rule_name: concat("AutoCorrect:", violation.constraint_name)
}
output corrective_event : SimEvent
```

- `violation.constraint_name : String` (declared in `ConstraintViolation`)
- `"AutoCorrect:"` is a String literal
- `concat(String, String)` → `Text` (both TCs; v0 compat accepts String args, but return is always Text)
- `SimEvent.rule_name : String` (declared in `types.ig`)
- Record literal field check is **strict**: `type_name(Text) != type_name(String)` → OOF-TY0
- Field error causes record literal to resolve to Unknown → OOF-TY1 at output boundary

This card answers the 7 required questions and specifies the narrowest P2 fix.

---

## 7 Questions Answered

### Q1 — Are String and Text meant to be distinct semantic types?

**Yes. String and Text are distinct nominal types. They are NOT aliases.**

Evidence:
- Both toolchains have separate `type_name()` paths: `structurally_assignable?` uses strict `type_name(actual) != type_name(expected)` equality — no cross-type leniency.
- Separate stdlib namespaces: `stdlib.text.*` (14 entries, all `Text`-typed) vs `stdlib.string.*` (new, `String`-typed). LANG-STDLIB-STRING-SURFACE-P1 explicitly established them as parallel namespaces.
- `sim_framework` SIM-P10 is live evidence: `expected String, got Text` is an actual OOF-TY0, not a known-false alarm.

Both toolchains have **three distinct string-related compat rules** that are orthogonal to each other:
1. `text_arg_compatible?` — one-way compat for stdlib.text.* argument positions only
2. Equality operator (`==`) — cross-pair compat (String/Text pairs accepted)
3. `structurally_assignable?` / record literal field check — strict, no cross-type compat

The existence of special compat rules for specific contexts confirms they are distinct types — if they were true aliases, no special rules would be needed.

### Q2 — Which one is canonical for human text?

**`Text` is canonical for human text.**

`stdlib.text.*` provides 14 production-implemented Unicode-aware operations:
- `grapheme_length(Text) -> Integer` — grapheme cluster count
- `rune_length(Text) -> Integer` — Unicode codepoint count
- `grapheme_slice(Text, Integer, Integer) -> Text` — grapheme-indexed slice
- `rune_slice(Text, Integer, Integer) -> Text` — codepoint-indexed slice
- `split(Text, Text) -> Collection[Text]` — Unicode-aware split
- `concat`, `trim`, `replace`, `replace_all`, `starts_with`, `ends_with`, `contains`, `byte_length`, `byte_slice`

These are localized, Unicode-aware operations. Human text belongs in `Text`.

### Q3 — Which one is canonical for byte/lexer strings?

**`String` is canonical for byte/lexer strings.**

All app type declarations that name identifiers, labels, tags, or machine-readable strings use `String`:

| App | Field | Type |
|---|---|---|
| sim_framework | `SimEvent.rule_name` | `String` |
| sim_framework | `ConstraintViolation.constraint_name` | `String` |
| sim_framework | `Entity.entity_type`, `Entity.name` | `String` |
| sim_framework | `ProofEntry.rule_name` | `String` |
| igniter_parser | `LexerState.source` | `String` |
| igniter_parser | `Token.text`, `Token.kind` | `String` |

`stdlib.string.char_at(String, Integer) -> String` (LANG-STDLIB-STRING-SURFACE-P1) explicitly positions `String` as the byte-level string type for parser/lexer operations.

### Q4 — Where do current TCs treat String/Text compatibly or incompatibly?

**Compatibly (both TCs):**

| Context | Rule | Direction |
|---|---|---|
| `stdlib.text.*` argument positions | `text_arg_compatible?` | String → Text (one-way) |
| `==` operator | cross-pair inclusion | String/Text bidirectional |

**Incompatibly (both TCs):**

| Context | Rule | Effect |
|---|---|---|
| `structurally_assignable?` | strict `type_name` equality | Text ≠ String → false |
| Record literal field check | strict `type_name` equality | Text value in String field → OOF-TY0 |
| stdlib.text.* return types | always return Text | concat(String,String) → Text always |
| Output boundary check | uses `structurally_assignable?` | Text ≠ String → OOF-TY1 |
| Structural candidate matching (P3 inference) | uses `structurally_assignable?` | Text ≠ String → no candidate match |

### Q5 — Is this assignability-only, stdlib-return-type-only, or parser/type alias issue?

**Primarily a stdlib-return-type issue. Specifically: `concat`'s return type does not adapt to input types.**

The call site is silent: `text_arg_compatible?` accepts String args where Text expected, so `concat("prefix", x)` where `x : String` resolves without error at the call site. The gap is in what comes back: concat always returns `Text` regardless of whether both inputs were String.

- **NOT an assignability issue**: `structurally_assignable?` and record literal field checks are working correctly — they correctly distinguish String and Text. The P2 fix does NOT touch these.
- **NOT a parser issue**: both types parse as type annotations identically; the parser has nothing to do here.
- **NOT a full type alias**: we do NOT want String = Text. They have distinct stdlib namespaces and distinct Unicode vs byte semantics. A full alias would collapse those.
- **IS a return-type gap**: `concat(String, String)` should be understood as string concatenation returning String, but today routes to `stdlib.text.concat` which always returns Text.

### Q6 — What exact sim_framework diagnostics are caused by this?

**SIM-P10** — `OOF-TY0: record literal field 'rule_name': expected String, got Text`

- File: `sim_framework/constraints.ig`, line 101
- Contract: `DecideAction`
- Expression: `rule_name: concat("AutoCorrect:", violation.constraint_name)`
- `violation.constraint_name : String` (from `ConstraintViolation.constraint_name : String`)
- `concat` call accepted at call site (both args are String, `text_arg_compatible?` allows it)
- `concat` returns `Text` (always, current behavior)
- `SimEvent.rule_name : String` — field check is strict — `Text ≠ String` → OOF-TY0

**SIM-P11** — `OOF-TY1: Output type mismatch: expected SimEvent, got Unknown`

- Cascade from SIM-P10
- When a field in a record literal has a type error, the record literal resolves to Unknown
- `output corrective_event : SimEvent` boundary check: `structurally_assignable?(Unknown, SimEvent)` → false (D2 Unknown reject rule from LANG-OUTPUT-TYPE-ASSIGNABILITY-P3)
- Emits OOF-TY1

Both fire only in the Ruby TC. The Rust TC is clean on sim_framework (Wave P7 confirmed: `ok/0 Rust` for sim_framework).

### Q7 — What is the narrowest P2 route?

**Input-type-driven return type for `concat`.**

When both arguments to `concat` are `String` (or `String` and Unknown), return `String`. Otherwise (any `Text` arg, or Unknown-only), return `Text` (existing behavior).

Concretely:

```
concat(String, String)  → String   ← new behavior
concat(String, Unknown) → Text     ← existing (permissive)
concat(Text,   Text)    → Text     ← existing
concat(Text,   String)  → Text     ← existing
concat(Unknown, *)      → Text     ← existing (permissive)
```

Implementation scope:
- **Ruby TC**: ~5 lines in `infer_concat_call` (or at the head of `infer_text_call`). When both resolved arg types are String, return `type_ir("String")` instead of delegating to `TEXT_STDLIB_FNS["concat"][:return_type]`.
- **Rust TC**: ~5 lines in `infer_call`'s `concat` arm, before the existing Text path. Rust already has `stdlib.string.concat` returning String for the `++` operator when both sides are String (typechecker.rs:4215–4217). The `concat` function form needs the same branch.

**No changes needed to:**
- `structurally_assignable?` — already correct
- Record literal field check — already correct
- `text_arg_compatible?` — already correct
- OOF codes — no new codes
- `stdlib-inventory.json` — no inventory change
- Parser, emitter, assembler, VM, runtime

---

## Exact Diagnostic Chain (SIM-P10 Fixture)

```ig
module SimTest

type SimEvent {
  tick      : Integer
  rule_name : String
}

type ConstraintViolation {
  constraint_name : String
}

contract DecideAction {
  input violation : ConstraintViolation

  compute corrective_event = {
    tick:      0,
    rule_name: concat("AutoCorrect:", violation.constraint_name)
  }

  output corrective_event : SimEvent
}
```

**Current output (Ruby TC):**
```
OOF-TY0: record literal field 'rule_name': expected String, got Text
OOF-TY1: Output type mismatch: expected SimEvent, got Unknown
```

**After P2 fix:**
- `concat("AutoCorrect:", violation.constraint_name)` — both args String → returns String
- `rule_name: <String>` — field check: `type_name(String) == type_name(String)` → passes
- Record literal resolves to SimEvent → output boundary passes
- Expected output: `ok/0` (no diagnostics)

---

## P2 Implementation Plan

### Ruby TC

**Insertion point:** `infer_concat_call` (or immediately before the `TEXT_STDLIB_FNS["concat"]` delegation in `infer_text_call`).

**Logic (~5 lines):**

```ruby
# If both args resolve to String, this is stdlib.string.concat → String
if type_name(left_type) == "String" && type_name(right_type) == "String"
  return typed_expr("call", type_ir("String"), [left_expr, right_expr],
                    fn: "stdlib.string.concat")
end
# Existing Text path: accepts Text or String (v0 compat)
```

**Files authorized:** `typechecker.rb` only.

### Rust TC

**Insertion point:** In the `"concat"` function dispatch arm, before the existing Text path.

**Logic (~5 lines):**
```rust
// If both args are String → route to stdlib.string.concat
if left_name == "String" && right_name == "String" {
    return Ok(infer_result("call", "String", "stdlib.string.concat", deps));
}
// Existing Text path (v0 compat: String or Text args accepted)
```

**Files authorized:** `typechecker.rs` only.

**Note:** Rust already uses this pattern at lines 4215–4217 for the `++` operator. P2 brings the `concat` function form to parity.

---

## Design Decisions

### Not a full String/Text alias

A full alias would mean `structurally_assignable?(String, Text)` and `structurally_assignable?(Text, String)` both return true. We deliberately do NOT do this. Reasons:
1. `stdlib.text.*` and `stdlib.string.*` are parallel namespaces for distinct types. An alias collapses the distinction.
2. App types use String for byte-level fields. Making Text = String everywhere would allow Text values anywhere a String is expected — too broad.
3. The equality operator and `text_arg_compatible?` already provide the cross-type leniency that is intentionally desired. Those are the right scope.

### Not a record literal field check change

The record literal field check correctly rejects `Text` in a `String` field. If `concat` returned the right type, the field check would pass. The field check is correct; the concat return type is wrong.

### Not a new OOF code

No diagnostic needed. When P2 is implemented, `concat(String, String)` just returns String, and everything that was broken passes silently (correctly). No new diagnostic surface needed.

### stdlib.string.concat is already in the Rust TC (for ++ operator)

The Rust TC dispatch at lines 4215–4217 handles `String ++ String → stdlib.string.concat → String`. P2 extends this to the explicit `concat(...)` call form, achieving parity and consistency.

---

## Non-Goals (P1 scope)

- No TC changes in P1
- No `stdlib-inventory.json` changes in P1
- No new OOF codes
- No parser changes
- No full String/Text type alias
- No changes to `structurally_assignable?`
- No changes to record literal field check
- No changes to `text_arg_compatible?`
- No `stdlib.text.*` changes
- No VM or runtime changes

---

## Decision Summary

| Question | Answer |
|---|---|
| String and Text distinct? | Yes — distinct nominal types, separate stdlib namespaces |
| Canonical for human text | `Text` — Unicode operations in `stdlib.text.*` |
| Canonical for byte/lexer | `String` — app fields, `stdlib.string.*` |
| Current compat contexts | `text_arg_compatible?` (one-way arg positions) + `==` (cross-pair) |
| Current incompat contexts | `structurally_assignable?` + record literal fields + return types |
| Gap nature | stdlib-return-type: `concat(String,String) → Text` (should return String) |
| Diagnostics caused | SIM-P10 (OOF-TY0 field mismatch) + SIM-P11 (OOF-TY1 Unknown cascade) |
| Narrowest P2 route | input-type-driven `concat` return; ~5 lines Ruby + ~5 lines Rust |
| P2 files | `typechecker.rb` + `typechecker.rs` only |
| P2 OOF impact | None — no new codes, no diagnostic changes |
| P1 scope | Proposal + readiness proof only — zero implementation |

---

## Next Routes

| Priority | Card | Unlocks |
|---|---|---|
| 1 | `LANG-STRING-TEXT-ALIAS-P2` | Ruby TC: input-type-driven `concat` return; ~5 lines in `infer_concat_call` |
| 2 | `LANG-STRING-TEXT-ALIAS-P3` | Rust TC: same pattern for `concat` function form; Rust already has `++` path |
| after P2 | SIM-P10 RESOLVED | `sim_framework` DUAL-CLEAN (pending SIM-P14 separately) |
