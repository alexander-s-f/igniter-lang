# LANG-STDLIB-STRING-SUBSTRING-P2 — Implementation Proof

**Track:** lang / stdlib / string
**Status:** CLOSED / PROVED — 75/75 PASS
**Proof runner:** `igniter-lang/experiments/stdlib_string_surface_proof/verify_stdlib_string_substring_p2.rb`
**Date:** 2026-06-13

---

## Summary

Dual-toolchain implementation of `stdlib.string.substring(String, Integer, Integer) -> String`.

`(source, start, length)` byte-based, 0-based. Follows P1 design exactly: OOF-TY0 only,
String returned all TC paths, Unknown permissive on all 3 argument positions.

---

## Production Files Changed (4)

### 1. `igniter-lang/docs/spec/stdlib-inventory.json`

- **Added** `stdlib.string.substring` entry (37 entries total, was 36)
- `lifecycle_status: "lab-implemented"`, `lowering_status: "dual-toolchain"`
- `input_signature: ["String", "Integer", "Integer"]`, `output_signature: "String"`
- `totality: "partial"`, `authority_surface: "none"`, `diagnostics: ["OOF-TY0"]`
- **Recomputed** `stdlib_surface_digest`: `160999932e9e1dde0a4aa37bdee8969cecd3969db7a11c97879f017cd776b52c`

### 2. `igniter-lang/lib/igniter_lang/typechecker.rb`

Two insertions:

**Dispatch arm** (after `when "char_at"`, ~line 1042):
```ruby
when "substring"
  # LANG-STDLIB-STRING-SUBSTRING-P2: substring(String, Integer, Integer) -> String
  infer_substring_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

**Private method** `infer_substring_call` (after `infer_char_at_call`):
- Arity guard: `args.length != 3` → OOF-TY0, early-return String
- Arg 1 guard: not String/Unknown → OOF-TY0
- Arg 2 guard: not Integer/Unknown → OOF-TY0
- Arg 3 guard: not Integer/Unknown → OOF-TY0
- `fn` set to `"stdlib.string.substring"` inline → **zero Ruby emitter changes**

### 3. `igniter-lab/igniter-compiler/src/typechecker.rs`

**New arm** after `"char_at"` arm:
```rust
// LANG-STDLIB-STRING-SUBSTRING-P2: substring(String, Integer, Integer) -> String
"substring" => {
    is_resolved = true;
    resolved_type = self.type_ir(&serde_json::Value::String("String".to_string()));
    if args.len() != 3 { /* OOF-TY0 */ }
    else {
        // arg1: String/Unknown; arg2: Integer/Unknown; arg3: Integer/Unknown
    }
}
```

### 4. `igniter-lab/igniter-compiler/src/emitter.rs`

Two insertions:

**`STRING_STDLIB_OPS`** — add `"substring"` entry:
```rust
const STRING_STDLIB_OPS: &[(&str, &str)] = &[
    ("char_at", "stdlib.string.char_at"),
    ("substring", "stdlib.string.substring"),  // LANG-STDLIB-STRING-SUBSTRING-P2
];
```

**`semantic_expr_for_compute` delegation guard** — add `substring`:
```rust
|| fn_val == "char_at"
|| fn_val == "substring"  // LANG-STDLIB-STRING-SUBSTRING-P2
```

---

## Files NOT Changed

| File | Reason |
|---|---|
| `semanticir_emitter.rb` | Ruby TC emits qualified fn inline — emitter passthrough |
| `multifile_resolver.rb` | Inventory-derived — no code change needed |
| `multifile.rs` | Inventory-derived via `include_str!` — no code change needed |
| `parser.rb` | No new syntax; `substring` is a function call |
| Any app source | No call sites yet |

---

## Proof Results — 75/75 PASS

| Section | Checks | Topic |
|---|---|---|
| A | 13 | Inventory entry, digest determinism, 37 entries |
| B | 5 | Ruby import surface (`import stdlib.string.{ substring }`) |
| C | 5 | Rust import surface (inventory-derived) |
| D | 5 | Ruby TC happy path — `substring(src, 1, 3)` → ok/0, String |
| E | 5 | Rust TC happy path — same fixture |
| F | 5 | Ruby SIR fn = `stdlib.string.substring` (bare `substring` absent) |
| G | 5 | Rust SIR fn = `stdlib.string.substring` (bare `substring` absent) |
| H | 5 | Arity != 3 → OOF-TY0 in both toolchains |
| I | 4 | Non-String arg1 → OOF-TY0 in both toolchains |
| J | 4 | Non-Integer arg2 → OOF-TY0 in both toolchains |
| K | 4 | Non-Integer arg3 → OOF-TY0 in both toolchains (new: 3rd arg) |
| L | 5 | Unknown permissive — concrete inputs clean, all 3 positions |
| M | 4 | char_at regression — P3 still ok/0 both toolchains |
| N | 3 | stdlib.text unchanged — 14 entries, byte_slice intact |
| O | 3 | Authority closure — no parser/resolver/emitter changes |
| **Total** | **75** | |

---

## Diagnostic Spec

| Condition | Code | Return | Early? |
|---|---|---|---|
| `args.length != 3` | OOF-TY0 "expected 3 argument(s), got N" | String | Yes |
| arg1 not String/Unknown | OOF-TY0 "arg 1: expected String, got T" | String | No |
| arg2 not Integer/Unknown | OOF-TY0 "arg 2: expected Integer, got T" | String | No |
| arg3 not Integer/Unknown | OOF-TY0 "arg 3: expected Integer, got T" | String | No |

---

## Key Invariants

- `import stdlib.string.{ char_at, substring }` — both aliases importable simultaneously
- `stdlib.string` module now has 2 entries: `char_at` + `substring`
- SIR fn is always `stdlib.string.substring` in output of both toolchains
- Rust emitter rewrite path requires `semantic_expr_for_compute` delegation guard (same pattern as char_at P3 — KEY DISCOVERY confirmed)
- No new OOF codes introduced

---

## IP-P05 Status

`igniter_parser` IP-P05 was PENDING-BEHIND-P01 (char_at import blocked). With P3 closed (char_at) and now P2 closed (substring), both prerequisites for the lexer's token accumulation pattern are satisfied at the TC level. The igniter_parser source files themselves have not been modified — that is a separate migration step.
