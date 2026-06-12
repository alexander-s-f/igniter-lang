# LANG-OUTPUT-TYPE-ASSIGNABILITY-P3: Ruby Implementation Proof

**Status:** CLOSED — 70/70 PASS
**Track:** lang / typechecker / output-boundary
**Route:** IMPLEMENTATION PROOF
**Date:** 2026-06-12
**Grounding:**
- LAB-UNKNOWN-OUTPUT-COERCION-P1 (36/36 PASS — HOLD/SAFETY-HIGH)
- LAB-OUTPUT-TYPE-PARAMETER-CHECK-P1 (38/38 PASS)
- LANG-OUTPUT-TYPE-ASSIGNABILITY-P1 (design decisions D1–D6)
- LANG-OUTPUT-TYPE-ASSIGNABILITY-P2 (implementation planning)

---

## 1. Problem Statement

The Ruby TypeChecker's output boundary check used `type_name()` — a shallow one-field read —
to compare actual vs expected output types. This caused:

- `Collection[Unknown] → Collection[RuleDecision]` SILENT
- `Collection[Integer] → Collection[Text]` SILENT
- `Map[String,T1] → Map[String,T2]` SILENT
- Any nested parametric mismatch SILENT

Root cause (LAB-OUTPUT-TYPE-PARAMETER-CHECK-P1): `type_name()` reads only `{"name": "Collection"}`.
Params are never compared. Any container type with a matching outer name passed the check silently.

---

## 2. Implementation

### 2a. Output boundary — `typechecker.rb` line ~413

```ruby
# BEFORE:
if type_name(actual) != type_name(expected) && !blocking_rule_present?(type_errors)
  type_errors << type_mismatch(expected, actual, decl.fetch("name"))
end

# AFTER:
unless structurally_assignable?(actual, expected) || blocking_rule_present?(type_errors)
  type_errors << structural_mismatch(expected, actual, decl.fetch("name"))
end
```

### 2b. New methods — inserted after `type_mismatch`

```ruby
def structurally_assignable?(actual, expected)
  return true  if type_name(expected) == "Unknown"   # D3: expected Unknown accepts any
  return false if type_name(actual)   == "Unknown"   # D2: actual Unknown always rejected
  return false if type_name(actual)   != type_name(expected)
  actual_params   = actual.fetch("params",   [])
  expected_params = expected.fetch("params", [])
  return false if actual_params.length != expected_params.length
  actual_params.zip(expected_params).all? { |a, e| structurally_assignable?(a, e) }
end

def structural_mismatch(expected, actual, node)
  oof("OOF-TY1",
      "Output type mismatch: expected #{type_display(expected)}, got #{type_display(actual)}",
      node)
end
```

No other methods modified. `type_display` (line ~1353) already renders params correctly:
`Collection[RuleDecision]`, `Map[String,Integer]`, `Collection[Collection[Text]]`.

---

## 3. OOF-TY1 Diagnostic

**Code:** `OOF-TY1`
**Message format:** `Output type mismatch: expected <type_display(expected)>, got <type_display(actual)>`

**Examples:**
```
OOF-TY1  Output type mismatch: expected Collection[RuleDecision], got Collection[Unknown]
OOF-TY1  Output type mismatch: expected Collection[Text], got Collection[Integer]
OOF-TY1  Output type mismatch: expected Map[String,Integer], got Map[String,Text]
OOF-TY1  Output type mismatch: expected Collection[Collection[Integer]], got Collection[Collection[Text]]
```

`OOF-TY1` is NOT added to `blocking_rule_present?` — it is a terminal output diagnostic, not
an upstream blocker. `blocking_rule_present?` list is unchanged.

`OOF-TY0` removed from output boundary (D5). `type_mismatch()` method retained — still used
by inline type checks elsewhere in the TC.

---

## 4. Algorithm: Unknown Policy

| Actual | Expected | structurally_assignable? | Rule |
|--------|----------|--------------------------|------|
| `Unknown` | `Integer` | false | D2: actual Unknown |
| `Collection[Unknown]` | `Collection[T]` | false | D2 at depth-1 |
| `Collection[Collection[Unknown]]` | `Collection[Collection[T]]` | false | D2 at depth-2 |
| `Integer` | `Unknown` | true | D3: expected Unknown |
| `Collection[T]` | `Unknown` | true | D3: expected Unknown |
| `Unknown` | `Unknown` | true | D3 fires first |
| `Collection[T]` | `Collection[Unknown]` | true | D3 at depth-1 |

---

## 5. Proof Matrix

**Runner:** `igniter-lang/experiments/output_type_assignability_proof/verify_output_type_assignability_p3.rb`
**Result:** 70/70 PASS

| Section | Topic | Checks | Result |
|---------|-------|--------|--------|
| A | `structurally_assignable?` unit — direct invocation | 10 | 10 PASS |
| C | OOF-TY1: outer name mismatch | 6 | 6 PASS |
| D | OOF-TY1: actual Unknown scalar + Collection depth | 8 | 8 PASS |
| E | OOF-TY1: param mismatch, same outer container | 7 | 7 PASS |
| F | OOF-TY1: nested parametric types | 6 | 6 PASS |
| G | Permissive PASS — concrete→concrete, no OOF-TY1 | 8 | 8 PASS |
| H | expected Unknown permissive at all depths | 4 | 4 PASS |
| I | rule_engine Collection[Unknown]→Collection[RuleDecision] blocked | 6 | 6 PASS |
| J | Regression — prior-PASS contracts unaffected | 7 | 7 PASS |
| K | OOF-TY0 NOT fired as output boundary diagnostic | 5 | 5 PASS |
| L | type_display includes params | 3 | 3 PASS |

---

## 6. Safety-Positive Evidence

`rule_engine ExecuteRules` (`active_decisions : Collection[RuleDecision]` where actual is
`Collection[Unknown]` from `map(rules, r -> call_contract(r, t))`) now emits:

```
OOF-TY1  Output type mismatch: expected Collection[RuleDecision], got Collection[Unknown]
  at: active_decisions
```

Previously SILENT. Root cause chain:
1. `call_contract(r, t)` where `r` is a Collection element → result type `Unknown`
2. `map(rules, r -> call_contract(r, t))` → `Collection[Unknown]`
3. Output declares `active_decisions : Collection[RuleDecision]`
4. `structurally_assignable?`: outer `Collection==Collection` ✓; depth-1: D2 fires (`Unknown` vs `RuleDecision`) → false
5. `OOF-TY1` fires

**Note:** the full rule_engine fixture with `filter(raw_decisions, d -> d.action == "SKIP" ...)` 
triggers `OOF-P1` (field access on Unknown is an unresolved symbol — blocking error), which
suppresses the output check via `blocking_rule_present?`. The map-only fixture is sufficient to
prove the output boundary claim. The full fixture requires `LAB-DYNAMIC-CONTRACT-DISPATCH-P1`
to resolve the Unknown flow before OOF-TY1 can surface there.

`RE-P04` remains HOLD/SAFETY-HIGH. Blocked until `LAB-DYNAMIC-CONTRACT-DISPATCH-P1` or
quarantine semantics are available.

---

## 7. Decisions Confirmed

| ID | Decision | Implemented |
|----|----------|-------------|
| D2 | actual Unknown → false at all depths | ✓ |
| D3 | expected Unknown → true at all depths | ✓ |
| D4 | OOF-TY1 new code for output structural failures | ✓ |
| D5 | OOF-TY0 removed from output boundary | ✓ |

D6 (LAB-RACK-P9 guard removal from Rust TC): deferred to P4.

---

## 8. Non-Goals (this card)

- No Rust TC changes (→ P4)
- No dynamic dispatch feature
- No validation receipt design
- No VM or runtime changes
- No parser / emitter / assembler changes
