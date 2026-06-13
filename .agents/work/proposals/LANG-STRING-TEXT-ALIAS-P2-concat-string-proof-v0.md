# LANG-STRING-TEXT-ALIAS-P2: concat String+String → String

**Track:** lang / type-system / stdlib  
**Route:** NARROW IMPLEMENTATION + PROOF  
**Date:** 2026-06-13  
**Status:** authored — proved  
**Lineage:** LANG-STRING-TEXT-ALIAS-P1 (47/47 PASS; P2 route specified)  
**Proof:** 52/52 PASS — `igniter-lang/experiments/string_text_alias_proof/verify_string_text_alias_p2.rb`

---

## Problem

`sim_framework` (Ruby toolchain) had two ACTIVE diagnostics at Wave P7:

- **SIM-P10** — `OOF-TY0: record literal field 'rule_name': expected String, got Text`
- **SIM-P11** — `OOF-TY1: Output type mismatch: expected SimEvent, got Unknown` (cascade from SIM-P10)

Root cause: `concat("AutoCorrect:", violation.constraint_name)` — both args String — but `stdlib.text.concat` always returns `Text`. The `SimEvent.rule_name : String` field check is strict (`type_name` equality); Text ≠ String → OOF-TY0 → record literal Unknown → OOF-TY1.

LANG-STRING-TEXT-ALIAS-P1 identified the narrowest P2 route: input-type-driven concat return. When both inputs are String → return String. All other cases preserve existing behavior.

---

## Implementation

**Three files changed. No new OOF codes. No new inventory entries. No alias introduced.**

### Ruby TC — `igniter-lang/lib/igniter_lang/typechecker.rb`

**Changed:** `infer_concat_call`, in the text routing block (after first-arg type check, before delegation to `infer_text_call`).

```ruby
# LANG-STRING-TEXT-ALIAS-P2: String+String → stdlib.string.concat → String.
unless first_type_name == "Collection" || first_type_name == "Unknown"
  if first_type_name == "String" && args.length == 2
    second_arg       = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
    second_type_name = type_name(second_arg.fetch("resolved_type"))
    if second_type_name == "String"
      deps = (first_arg.fetch("deps", []) + second_arg.fetch("deps", [])).uniq
      return typed_expr("call", type_ir("String"), deps,
                        "fn" => "stdlib.string.concat", "args" => [first_arg, second_arg])
    end
  end
  return infer_text_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
end
```

**Logic:**
- If first arg type is String and 2 args present: infer second arg
- If second arg is also String → return String with fn `stdlib.string.concat` (early return)
- If second arg is not String (Text, Unknown, etc.) → fall through to existing `infer_text_call`

**Invariants preserved:**
- Collection routing (line above this block) untouched
- `infer_text_call` still handles all non-String-first-arg cases
- `TEXT_STDLIB_FNS["concat"][:return_type]` still "Text" — unchanged
- `text_arg_compatible?` still one-way — unchanged
- SIR fn name is `stdlib.string.concat` (matching Rust `++` operator precedent)

### Rust TC — `igniter-lab/igniter-compiler/src/typechecker.rs`

**Change 1:** In `infer_expr`, concat text path (`else` clause of Collection/Unknown check):

```rust
} else {
    // LANG-STRING-TEXT-ALIAS-P2: String+String → stdlib.string.concat → String.
    let both_string = typed_args.len() == 2
        && self.type_name(&typed_args[0].resolved_type) == "String"
        && self.type_name(&typed_args[1].resolved_type) == "String";
    if both_string {
        resolved_type = self.type_ir(&serde_json::Value::String("String".to_string()));
    } else {
        resolved_type = self.check_text_stdlib_call(
            "concat", &typed_args, &["Text", "Text"],
            type_errors, node_name,
        );
    }
}
```

**Change 2:** In `rewrite_concat_calls`, add String+String → `stdlib.string.concat`:

```rust
} else if first_type == "String" {
    // LANG-STRING-TEXT-ALIAS-P2: String+String → stdlib.string.concat
    let second_type = args.get(1)
        .map(|a| self.quick_arg_type(a, symbol_types))
        .unwrap_or_else(|| "Unknown".to_string());
    if second_type == "String" {
        "stdlib.string.concat".to_string()
    } else {
        "stdlib.text.concat".to_string()
    }
}
```

`quick_arg_type` returns `type_tag.clone()` for `Expr::Literal` — String literals have `type_tag = "String"`. Returns `symbol_types.get(name)` for `Expr::Ref` — String-typed refs return "String". Both cases correctly detected.

### Rust Emitter — `igniter-lab/igniter-compiler/src/emitter.rs`

**Changed:** block (B) — already-qualified names — extended to cover `stdlib.string.concat`:

```rust
if fn_val.starts_with("stdlib.text.") || fn_val == "stdlib.collection.concat" || fn_val == "stdlib.string.concat" {
    if !map.contains_key("resolved_type") {
        let resolved_type = if fn_val == "stdlib.collection.concat" {
            // Collection[Unknown]
        } else if fn_val == "stdlib.string.concat" {
            // LANG-STRING-TEXT-ALIAS-P2: String return type
            let mut m = serde_json::Map::new();
            m.insert("name".to_string(), serde_json::Value::String("String".to_string()));
            m.insert("params".to_string(), serde_json::Value::Array(Vec::new()));
            serde_json::Value::Object(m)
        } else {
            text_return_type(base)
        };
        ...
    }
}
```

---

## Behavior Table

| Call form | Before P2 | After P2 |
|---|---|---|
| `concat(String, String)` | Text | **String** ← changed |
| `concat(Text, Text)` | Text | Text (unchanged) |
| `concat(Text, String)` | Text | Text (unchanged) |
| `concat(String, Text)` | Text | Text (unchanged) |
| `concat(String, Unknown)` | Text | Text (unchanged) |
| `concat(Unknown, *)` | Text | Text (unchanged) |
| `concat(Collection[T], Collection[T])` | Collection[T] | Collection[T] (unchanged) |

---

## Diagnostics Fixed

**SIM-P10:** `record literal field 'rule_name': expected String, got Text`
- `concat("AutoCorrect:", violation.constraint_name)` — both String → now returns String
- Field check: `type_name(String) == type_name(String)` → passes
- OOF-TY0 eliminated

**SIM-P11:** `Output type mismatch: expected SimEvent, got Unknown`
- Record literal now resolves to `SimEvent` (field check passes)
- Output boundary: `structurally_assignable?(SimEvent, SimEvent)` → true
- OOF-TY1 cascade eliminated

**sim_framework result after P2:** Ruby clean ok/0 (all SIM-P10/P11/P12/P13/P14 RESOLVED)

---

## What Did NOT Change

- `TEXT_STDLIB_FNS["concat"][:return_type]` — still "Text" (text path unchanged)
- `text_arg_compatible?` — still one-way (String→Text, not reverse)
- `structurally_assignable?` — still strict equality
- Record literal field check — still strict `type_name` equality
- `stdlib-inventory.json` — no changes (stdlib.string.concat has no inventory entry in P2; consistent with Rust `++` path precedent)
- Parser — no changes
- OOF codes — none added

---

## Regression Evidence

| Suite | Before P2 | After P2 |
|---|---|---|
| `string_core_proof` (60 checks) | 60/60 PASS | 60/60 PASS |
| `concat_trim.ig` (Text+Text) | clean | clean |
| `literal_compat.ig` (Text+String) | clean | clean |
| SIM-P10 minimal fixture | OOF-TY0 + OOF-TY1 | **0 errors** |
| Rust build | clean | clean |

---

## Proof Sections

- **A** — String and Text remain distinct (structurally_assignable? unchanged; no alias)
- **B** — concat(String,String) returns String in Ruby TC (6 checks including inline fixtures)
- **C** — concat(Text,Text) still returns Text (4 checks, no regression)
- **D** — Mixed arg behavior documented (String+Text→Text; Text+String→Text; Unknown fallthrough)
- **E** — Rust TC infer_expr: both_string branch verified in source and behavior
- **F** — Rust TC rewrite_concat_calls: String+String → stdlib.string.concat
- **G** — Rust emitter: stdlib.string.concat handled in qualified-name block
- **H** — sim_framework SIM-P10/P11 RESOLVED (minimal fixture + PRESSURE_REGISTRY evidence)
- **I** — SIR fn name is stdlib.string.concat (Ruby TC typed_expr + inline SIR check)
- **J** — No global assignability relaxation (4 negative checks + text_arg_compatible? unchanged)
- **K** — Regression assertions: string_core patterns + Collection concat unaffected

---

## Non-Goals

- No full String/Text alias — they remain distinct types
- No `stdlib-inventory.json` entry for concat in P2 (deferred to P3 if needed)
- No `stdlib.text.*` changes
- No changes to other stdlib.text.* return types
- No parser, assembler, or VM changes
- No OOF code additions

---

## Next Routes

| Priority | Card | Scope |
|---|---|---|
| 1 | `LANG-STRING-TEXT-ALIAS-P3` | Rust TC parity verification (Rust already has string+string path via this P2) |
| 2 | sim_framework recheck | Confirm ok/0 Ruby + ok/0 Rust in full Wave P8 recheck |
