# LANG-OUTPUT-TYPE-ASSIGNABILITY-P2: Implementation Planning

**Status:** Implementation planning — READY FOR P3
**Grounding:**
- LAB-UNKNOWN-OUTPUT-COERCION-P1 (36/36 PASS — HOLD/SAFETY-HIGH)
- LAB-OUTPUT-TYPE-PARAMETER-CHECK-P1 (38/38 PASS — READY FOR IMPLEMENTATION PLANNING)
- LANG-OUTPUT-TYPE-ASSIGNABILITY-P1 (Proposal — decisions D1–D6 made)

---

## 1. Problem Statement

The output boundary check in both TCs uses `type_name()` — a shallow one-field read — to compare actual vs expected output types. This causes:

- `Collection[Unknown] → Collection[RuleDecision]` SILENT (no diagnostic)
- `Collection[Integer] → Collection[Text]` SILENT
- `Map[String,T1] → Map[String,T2]` SILENT
- Any nested param mismatch SILENT

Root cause: `type_name()` reads only `{"name": "Collection"}` — params are never compared.

The existing `OOF-TY0` fires only on outer-name mismatch (e.g. `Integer` where `Collection` expected). The params gap is entirely uncovered.

---

## 2. Decisions (from LANG-OUTPUT-TYPE-ASSIGNABILITY-P1)

| ID | Decision |
|----|----------|
| D2 | `actual Unknown → false` at all depths (unknown actual is rejected, never treated as compatible) |
| D3 | `expected Unknown → true` at all depths (explicit Unknown annotation accepts any actual) |
| D4 | New OOF code `OOF-TY1` for output structural failures |
| D5 | `OOF-TY0` removed from output boundary (still fired for inline type mismatches elsewhere) |
| D6 | LAB-RACK-P9 guard in Rust TC removed (`&& self.type_name(&actual) != "Unknown"`) — superseded by D2 in `structurally_assignable` |

---

## 3. Algorithm: `structurally_assignable?`

```ruby
# Ruby
def structurally_assignable?(actual, expected)
  return true  if type_name(expected) == "Unknown"   # D3: expected Unknown accepts any actual
  return false if type_name(actual)   == "Unknown"   # D2: actual Unknown rejected at any depth
  return false if type_name(actual)   != type_name(expected)
  actual_params   = actual.fetch("params",   [])
  expected_params = expected.fetch("params", [])
  return false if actual_params.length != expected_params.length
  actual_params.zip(expected_params).all? { |a, e| structurally_assignable?(a, e) }
end
```

```rust
// Rust
fn structurally_assignable(&self, actual: &serde_json::Value, expected: &serde_json::Value) -> bool {
    if self.type_name(expected) == "Unknown" { return true; }   // D3
    if self.type_name(actual) == "Unknown"   { return false; }  // D2
    if self.type_name(actual) != self.type_name(expected) { return false; }
    let actual_params = actual.get("params").and_then(|p| p.as_array()).cloned().unwrap_or_default();
    let expected_params = expected.get("params").and_then(|p| p.as_array()).cloned().unwrap_or_default();
    if actual_params.len() != expected_params.len() { return false; }
    actual_params.iter().zip(expected_params.iter()).all(|(a, e)| {
        self.structurally_assignable(&self.type_ir(a), &self.type_ir(e))
    })
}
```

**Unknown policy depth examples:**

| Actual | Expected | Result |
|--------|----------|--------|
| `Unknown` | `Collection[T]` | false — D2 fires at outer |
| `Collection[Unknown]` | `Collection[T]` | false — recursion hits D2 at depth-1 |
| `Collection[Collection[Unknown]]` | `Collection[Collection[T]]` | false — recursion hits D2 at depth-2 |
| `T` | `Unknown` | true — D3 fires at outer |
| `Collection[T]` | `Unknown` | true — D3 fires at outer |
| `Unknown` | `Unknown` | true — D3 fires first |
| `Collection[T]` | `Collection[Unknown]` | true — D3 fires at depth-1 |

---

## 4. New Diagnostic: OOF-TY1

```
OOF-TY1  Output type mismatch: expected <type_display(expected)>, got <type_display(actual)>
```

Example messages:
- `Output type mismatch: expected Collection[RuleDecision], got Collection[Unknown]`
- `Output type mismatch: expected Collection[Integer], got Collection[Text]`
- `Output type mismatch: expected Map[String,Integer], got Map[String,Unknown]`
- `Output type mismatch: expected Collection[Collection[Integer]], got Collection[Collection[Text]]`

**Helper methods:**

Ruby (new, after `type_mismatch` at line ~1385):
```ruby
def structural_mismatch(expected, actual, node)
  oof("OOF-TY1",
      "Output type mismatch: expected #{type_display(expected)}, got #{type_display(actual)}",
      node)
end
```

Ruby `type_display` already exists at line 1351 — no changes needed.

Rust (new, after `type_name` at line ~2045):
```rust
fn type_display(&self, type_info: &serde_json::Value) -> String {
    let name = self.type_name(type_info);
    let params = type_info.get("params").and_then(|p| p.as_array()).cloned().unwrap_or_default();
    if params.is_empty() { return name; }
    let rendered: Vec<String> = params.iter().map(|p| self.type_display(&self.type_ir(p))).collect();
    format!("{}[{}]", name, rendered.join(","))
}
```

---

## 5. Insertion Points

### 5a. Ruby TC — `igniter-lang/lib/igniter_lang/typechecker.rb`

**Output boundary (lines 413–415) — REPLACE:**

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

**New methods — INSERT after `type_mismatch` at line ~1385, before `def oof`:**

```ruby
def structurally_assignable?(actual, expected)
  return true  if type_name(expected) == "Unknown"
  return false if type_name(actual)   == "Unknown"
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

Total Ruby change: ~12 new lines + 2 lines modified. No other methods touched.

### 5b. Rust TC — `igniter-lab/igniter-compiler/src/typechecker.rs`

**Output boundary (lines 1236–1244) — REPLACE:**

```rust
// BEFORE:
if self.type_name(&actual) != self.type_name(&expected)
    && self.type_name(&actual) != "Unknown"   // LAB-RACK-P9
    && !self.blocking_rule_present(&type_errors) {
    type_errors.push(ClassifierDiagnostic {
        rule: "OOF-TY0".to_string(),
        message: format!("Type mismatch: expected {}, got {}",
                         self.type_name(&expected), self.type_name(&actual)),
        node: decl.name.clone(),
        line: None,
    });
}

// AFTER:
if !self.structurally_assignable(&actual, &expected)
    && !self.blocking_rule_present(&type_errors) {
    type_errors.push(ClassifierDiagnostic {
        rule: "OOF-TY1".to_string(),
        message: format!("Output type mismatch: expected {}, got {}",
                         self.type_display(&expected), self.type_display(&actual)),
        node: decl.name.clone(),
        line: None,
    });
}
```

LAB-RACK-P9 comment and guard removed (D6).

**New methods — INSERT after `type_name` at line ~2045:**

```rust
fn structurally_assignable(&self, actual: &serde_json::Value, expected: &serde_json::Value) -> bool {
    if self.type_name(expected) == "Unknown" { return true; }
    if self.type_name(actual) == "Unknown"   { return false; }
    if self.type_name(actual) != self.type_name(expected) { return false; }
    let actual_params = actual.get("params").and_then(|p| p.as_array()).cloned().unwrap_or_default();
    let expected_params = expected.get("params").and_then(|p| p.as_array()).cloned().unwrap_or_default();
    if actual_params.len() != expected_params.len() { return false; }
    actual_params.iter().zip(expected_params.iter()).all(|(a, e)| {
        self.structurally_assignable(&self.type_ir(a), &self.type_ir(e))
    })
}

fn type_display(&self, type_info: &serde_json::Value) -> String {
    let name = self.type_name(type_info);
    let params = type_info.get("params").and_then(|p| p.as_array()).cloned().unwrap_or_default();
    if params.is_empty() { return name; }
    let rendered: Vec<String> = params.iter().map(|p| self.type_display(&self.type_ir(p))).collect();
    format!("{}[{}]", name, rendered.join(","))
}
```

Total Rust change: ~18 new lines + 6 lines modified/removed.

---

## 6. `blocking_rule_present?` Interaction

The `blocking_rule_present?` guard is **preserved unchanged** in both TCs.

- Purpose: suppress output diagnostic when upstream structural errors (OOF-P1, OOF-CE4, etc.) are present to avoid cascading noise
- `OOF-TY1` is NOT added to the blocking list — it is a terminal output diagnostic, not an upstream indicator
- `OOF-TY0` stays in its current uses (inline type mismatches from `type_mismatch()`); only the output boundary call is replaced
- Blocking list unchanged: `OOF-P1, OOF-CE4, OOF-OS2, OOF-H1, OOF-BT1, OOF-BT2, OOF-BT3, OOF-BT4, OOF-TM1, OOF-TM3, OOF-TM4, OOF-TM5, OOF-TM6, OOF-S3, OOF-O3, OOF-O4, OOF-O5, OOF-IV3`

---

## 7. rule_engine Impact

After P3 Ruby implementation, `rule_engine/engine.ig` `ExecuteRules` will emit:

```
OOF-TY1 Output type mismatch: expected Collection[RuleDecision], got Collection[Unknown]
  at: active_decisions
```

**Root cause chain:**
1. `call_contract(r, tx)` where `r` is a variable → result type `Unknown` (dynamic dispatch, no static callee)
2. `map(rules, r -> call_contract(r, tx))` → `Collection[Unknown]`
3. `filter(results, ...)` → `Collection[Unknown]`
4. Output declares `active_decisions : Collection[RuleDecision]`
5. `structurally_assignable?` recursion: outer names match (`Collection==Collection`); param depth-1: `Unknown` vs `RuleDecision` → D2 fires → `false`
6. OOF-TY1 fires

**Blocked until:** `LAB-DYNAMIC-CONTRACT-DISPATCH-P1` or validation receipt / quarantine semantics resolves the Unknown flow.

`RE-P04` status remains HOLD/SAFETY-HIGH. The RE-P04 pressure registry entry should be updated after P3 to note that OOF-TY1 now fires (previously SILENT).

---

## 8. Proof Matrix (P3/P4/P5)

Target: ≥70 checks / 12 sections.

### P3 — Ruby implementation proof

| Section | Topic | Checks |
|---------|-------|--------|
| A | `structurally_assignable?` unit — Ruby | 8 |
| B | `structurally_assignable` unit — Rust stub (P4 preview) | 0 (P4) |
| C | OOF-TY1: outer name mismatch | 5 |
| D | OOF-TY1: Unknown actual → concrete expected | 6 |
| E | OOF-TY1: param mismatch, same outer name | 6 |
| F | OOF-TY1: nested params | 5 |
| G | Permissive cases PASS (concrete→concrete match, T→Unknown) | 7 |
| H | Unknown→Unknown permissive | 4 |
| I | rule_engine OOF-TY1 activation (Ruby) | 5 |
| J | Regression: prior PASS contracts unaffected (Ruby) | 7 |
| K | OOF-TY0 NOT fired at Ruby output boundary | 5 |
| L | Authority closed | 4 |

P3 total: **≥62/11 sections** (section B moves to P4)

### P4 — Rust parity proof

| Section | Topic | Checks |
|---------|-------|--------|
| B | `structurally_assignable` unit — Rust | 6 |
| C | OOF-TY1 Rust: outer name mismatch | 5 |
| D | OOF-TY1 Rust: Unknown→concrete | 5 |
| E | OOF-TY1 Rust: param mismatch | 5 |
| F | OOF-TY1 Rust: nested | 4 |
| G | Permissive PASS Rust | 5 |
| I | rule_engine Rust: OOF-TY1 fires (LAB-RACK-P9 gone) | 5 |
| J | Regression: prior PASS contracts Rust | 6 |
| K | OOF-TY0 NOT fired at Rust output boundary | 4 |

P4 total: **≥45/9 sections**

### P5 — Dual-toolchain regression (optional)

End-to-end: same contract suite in Ruby + Rust, all matching → 0 OOF-TY1; all mismatched → OOF-TY1 in both.

---

## 9. Authorized Files

### P3 (Ruby)
- `igniter-lang/lib/igniter_lang/typechecker.rb` — 2 method insertions + 1 output boundary change

### P4 (Rust)
- `igniter-lab/igniter-compiler/src/typechecker.rs` — 2 method additions + output boundary replacement + LAB-RACK-P9 removal

### Explicitly NOT authorized (both phases)
- No parser changes
- No semanticir_emitter changes
- No assembler changes
- No stdlib inventory changes
- No VM / runtime changes
- No dynamic dispatch feature
- No validation receipt design
- No new `OOF-TY0` uses at output boundary

---

## 10. Non-Goals

- Dynamic dispatch: `call_contract(r, tx)` flow type is still `Unknown` after this change. The goal is to DETECT the mismatch, not resolve it.
- Validation receipts: no receipt type, no runtime guarantee. The boundary fails at compile time.
- Unknown quarantine semantics: not in scope for P2/P3/P4.
- VM/runtime output coercion: no runtime validation added.
