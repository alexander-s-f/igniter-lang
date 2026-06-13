# LANG-STDLIB-STRING-SURFACE-P2: Implementation Planning

**Track:** lang / stdlib / string / implementation-planning  
**Route:** IMPLEMENTATION PLANNING ONLY — no implementation in P2  
**Date:** 2026-06-13  
**Status:** authored — pending review  
**Lineage:** LANG-STDLIB-STRING-SURFACE-P1 CLOSED (55/55 PASS); P1 decided stdlib.string is a new parallel namespace, char_at(String, Integer) -> String, inventory-only change clears OOF-IMP2 in both toolchains  
**Prior planning pattern:** LANG-STDLIB-COLLECTION-APPEND-P2; LANG-STDLIB-IS-EMPTY-P2; LANG-STDLIB-NUMERIC-COMPARISON-P2

---

## Planning Decision

**READY FOR P3 — DUAL-TOOLCHAIN IN ONE CARD**

Ruby and Rust changes are both narrow (one dispatch arm + one helper each). The full unblock of igniter_parser's OOF-IMP2 blocker requires the inventory entry; TC dispatch is the next step. Splitting introduces an intermediate state where both toolchains still fail at TC, so dual-toolchain P3 is preferred. No implementation-blocking unknowns remain.

---

## 13 Questions Answered

### Q1 — What exact inventory entries are needed for P3?

**One entry**, appended to `stdlib-inventory.json`:

```json
{
  "canonical_name": "stdlib.string.char_at",
  "semantic_ir_name": "stdlib.string.char_at",
  "legacy_sir": null,
  "aliases": [
    { "kind": "source_alias", "name": "char_at" }
  ],
  "category": "string",
  "lifecycle_status": "lab-proposed",
  "semantic_stability": "proposal-only",
  "lowering_status": "not-implemented",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "partial",
  "type_params": [],
  "input_signature": ["String", "Integer"],
  "output_signature": "String",
  "diagnostics": ["OOF-TY0"],
  "failure_behavior": "out-of-bounds: unspecified v0; implementation must define in P3",
  "authority_surface": "none",
  "proof_lineage": ["LANG-STDLIB-STRING-SURFACE-P1", "LANG-STDLIB-STRING-SURFACE-P2"],
  "examples": [
    "char_at(\"module\", 0) -> \"m\"",
    "char_at(\"module\", 1) -> \"o\""
  ],
  "compatibility_note": "byte-indexed, 0-based; out-of-bounds behavior defined in P3",
  "owner_surface": "LANG-STDLIB-STRING-SURFACE-P1"
}
```

`lowering_status: "not-implemented"` until P3 closes. P3 upgrades it to `"lab-implemented"` / `"dual-toolchain"`. `stdlib_surface_digest` must be recomputed after adding the entry (projected: `3e51bf952eb26eb711fcec6b3a3b7257ced6b1c50cd5096e242c920241ffafae`; current before P3: `59f6cee45360243270d2634a84804f7676b88335c098df5c3cc44a006ee79e4d`).

**Entry count:** 34 → 35.

### Q2 — Should P3 update `stdlib-inventory.json` only, or also hand-coded dispatch?

**Both.** Inventory alone clears OOF-IMP2 (import resolution) but leaves OOF-IMP3 or OOF-TY0 when the TC dispatch arm is missing. P3 must:

1. Add the inventory entry (import surface — both toolchains derive from it automatically)
2. Add Ruby TC dispatch arm + method (TC validates types, emits qualified SIR fn)
3. Add Rust TC dispatch arm (TC validates types; emitter rewrites bare `char_at` → qualified)
4. Add Rust emitter rewrite entry (STRING_STDLIB_OPS)

After P3, `import stdlib.string.{ char_at }` resolves AND `char_at(state.source, state.pos)` typechecks to `String` in both toolchains.

### Q3 — Does import surface derive from inventory in both toolchains today?

**Yes — both toolchains derive the stdlib module table from `stdlib-inventory.json` at runtime.**

- **Ruby:** `multifile_resolver.rb` `def stdlib_module_table` — reads `../../docs/spec/stdlib-inventory.json` via `File.expand_path`; memoized. No code change needed.
- **Rust:** `multifile.rs` `fn stdlib_module_table()` — embeds via `include_str!("../../../igniter-lang/docs/spec/stdlib-inventory.json")`; re-parsed at each compilation. No code change needed.

Adding the inventory entry is sufficient to enable `import stdlib.string.{ char_at }` in both toolchains. Confirmed by Section J of the P1 proof runner.

### Q4 — Where does Ruby accept/reject `import stdlib.string.{ char_at }`?

`igniter-lang/lib/igniter_lang/multifile_resolver.rb`, method `validate_imports`:

```ruby
def stdlib_module_table
  @stdlib_module_table ||= begin
    inventory_path = File.expand_path("../../docs/spec/stdlib-inventory.json", __dir__)
    ...
    # builds Hash: "stdlib.string" => Set["char_at"] once entry is present
  end
end
```

Currently: `"stdlib.string"` absent from table → OOF-IMP2.  
After adding inventory entry: `table["stdlib.string"] = Set["char_at"]` → import resolves, OOF-IMP2 gone.  
No code change to `multifile_resolver.rb` in P3.

### Q5 — Where does Rust accept/reject `import stdlib.string.{ char_at }`?

`igniter-lab/igniter-compiler/src/multifile.rs`, `fn stdlib_module_table()`:

```rust
const JSON_STR: &str = include_str!("../../../igniter-lang/docs/spec/stdlib-inventory.json");
// ... parse entries, build HashMap<String, Vec<String>>
```

OOF-IMP2 fires at line ~232 when `!table.contains_key(&import.module_path)`.  
After adding inventory entry: `table` contains `"stdlib.string"` → OOF-IMP2 gone.  
No code change to `multifile.rs` in P3.

### Q6 — What Ruby TC dispatch shape should `char_at(source, index)` use?

**New arm in `infer_call` + new private method `infer_char_at_call`.**

The pattern follows `infer_is_empty_call` / `infer_append_call` exactly (isolated method, not `TEXT_STDLIB_FNS` registry, since `char_at` takes `String` first arg not `Text`).

**Insertion 1 — `infer_call` case arm** (after `when "is_empty", "non_empty"`, before `when "or_else"`, ~line 1038):

```ruby
when "char_at"
  # LANG-STDLIB-STRING-SURFACE-P3: char_at(String, Integer) -> String
  infer_char_at_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

**Insertion 2 — `def infer_char_at_call` private method** (after `infer_is_empty_call` method body, ~line 2782):

```ruby
def infer_char_at_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  qualified = "stdlib.string.char_at"

  # OOF-TY0: arity must be exactly 2
  unless args.length == 2
    type_errors << oof("OOF-TY0",
      "#{qualified}: expected 2 argument(s), got #{args.length}",
      node_name)
    return typed_expr("call", type_ir("String"), [], "fn" => qualified, "args" => [])
  end

  # Infer and validate first arg — must be String or Unknown
  source_arg  = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  source_name = type_name(source_arg.fetch("resolved_type"))
  unless source_name == "Unknown" || source_name == "String"
    type_errors << oof("OOF-TY0",
      "#{qualified} arg 1: expected String, got #{source_name}",
      node_name)
  end

  # Infer and validate second arg — must be Integer or Unknown
  index_arg  = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
  index_name = type_name(index_arg.fetch("resolved_type"))
  unless index_name == "Unknown" || index_name == "Integer"
    type_errors << oof("OOF-TY0",
      "#{qualified} arg 2: expected Integer, got #{index_name}",
      node_name)
  end

  deps = (source_arg.fetch("deps", []) + index_arg.fetch("deps", [])).uniq
  typed_expr("call", type_ir("String"), deps,
             "fn" => qualified, "args" => [source_arg, index_arg])
end
```

**String returned on ALL paths** (including OOF error paths) — matches `is_empty_call` Bool-on-all-paths pattern.  
**Unknown permissive** on both arg positions.  
**No `text_arg_compatible?`** — this is `String` not `Text`.

### Q7 — What Rust TC dispatch shape should `char_at(source, index)` use?

**One new arm in the large `Expr::Call` match block** (after `"is_empty" | "non_empty"` arm, ~line 2780):

```rust
"char_at" => {
    // LANG-STDLIB-STRING-SURFACE-P3: char_at(String, Integer) -> String
    // OOF-TY0: arity / arg1 not String / arg2 not Integer (Unknown permissive on both)
    is_resolved = true;
    resolved_type = self.type_ir(&serde_json::Value::String("String".to_string()));
    if args.len() != 2 {
        type_errors.push(ClassifierDiagnostic {
            rule: "OOF-TY0".to_string(),
            message: format!(
                "stdlib.string.char_at: expected 2 argument(s), got {}",
                args.len()
            ),
            node: node_name.to_string(),
            line: None,
        });
    } else {
        if !typed_args.is_empty() {
            let source_name = self.type_name(&typed_args[0].resolved_type);
            if source_name != "Unknown" && source_name != "String" {
                type_errors.push(ClassifierDiagnostic {
                    rule: "OOF-TY0".to_string(),
                    message: format!(
                        "stdlib.string.char_at arg 1: expected String, got {}",
                        source_name
                    ),
                    node: node_name.to_string(),
                    line: None,
                });
            }
        }
        if typed_args.len() >= 2 {
            let index_name = self.type_name(&typed_args[1].resolved_type);
            if index_name != "Unknown" && index_name != "Integer" {
                type_errors.push(ClassifierDiagnostic {
                    rule: "OOF-TY0".to_string(),
                    message: format!(
                        "stdlib.string.char_at arg 2: expected Integer, got {}",
                        index_name
                    ),
                    node: node_name.to_string(),
                    line: None,
                });
            }
        }
    }
}
```

**`String` returned on all paths** (including OOF). **`is_resolved = true`** prevents fallthrough to unknown-callee handling.

### Q8 — Should `char_at` return `String`, `Text`, or a distinct `ByteChar`?

**`String`.** P1 decided:
- Module: `stdlib.string` (String-type namespace)
- Signature: `char_at(String, Integer) -> String`
- Semantics: returns 1-byte `String`

`Text` is rejected — it's from a different type family, and mixing would cause type errors at usage sites (`state.pos + 1` arithmetic, `current_char == "m"` literal comparison — both expect `String`).

`ByteChar` is rejected — introducing a new type is a larger scope change requiring a separate PROP. In v0, a 1-byte `String` is sufficient and avoids new type machinery.

### Q9 — What arity/type diagnostics should fire?

**All via OOF-TY0. No new OOF codes.**

| Failure | Code | Message |
|---|---|---|
| arity ≠ 2 | OOF-TY0 | `stdlib.string.char_at: expected 2 argument(s), got N` |
| arg1 not String/Unknown | OOF-TY0 | `stdlib.string.char_at arg 1: expected String, got T` |
| arg2 not Integer/Unknown | OOF-TY0 | `stdlib.string.char_at arg 2: expected Integer, got T` |

OOF-TY0 is reused (precedent: `infer_text_call`, `infer_append_call`, numeric comparisons). Arity mismatch is an early-return (returns `String` with empty args). Type mismatch is non-early-return (both args still inferred; `String` always returned).

**Out-of-bounds: TC-only.** No OOF code for out-of-bounds in P3 — that is runtime/VM semantics, deferred.

### Q10 — Does SIR need canonical `fn: "stdlib.string.char_at"` in both toolchains?

**Yes.** Both toolchains must emit `fn: "stdlib.string.char_at"` in the SIR call node.

**Ruby:** TC sets `fn` inline to `"stdlib.string.char_at"` in `typed_expr`. `semantic_expr` in `semanticir_emitter.rb` recursively passes through hash keys unchanged — **zero emitter changes needed in Ruby**.

**Rust:** TC leaves `fn: "char_at"` as the bare name (consistent with how `append`, `is_empty`, `trim` work). The emitter's `semantic_expr` must rewrite it. See Q7-Rust emitter.

### Q11 — What out-of-bounds semantics are specified in P2 versus deferred?

**All out-of-bounds semantics are deferred.** P3 implements TC-only dispatch. The inventory marks `totality: "partial"` and `failure_behavior: "out-of-bounds: unspecified v0; implementation must define in P3"`. This is correct: P3 proves the TC typing shape, not runtime execution. Out-of-bounds is a runtime/VM concern and cannot be specified without VM execution support.

### Q12 — How does P3 prove igniter_parser import clears without overclaiming full parser execution?

**Same approach as Section J in P1 — prove the import surface AND TC dispatch independently using fixture contracts.**

1. **Import surface** (Section B/C): compile a minimal fixture with `import stdlib.string.{ char_at }` and assert no OOF-IMP2 diagnostic — proves the inventory entry works.
2. **TC dispatch** (Section D/E): compile a fixture that calls `char_at(s, i)` where `s: String` and `i: Integer` — assert no OOF-TY0, resolved_type = String.
3. **Parser advance** (Section K): compile `igniter_parser/lexer.ig` + `types.ig` together — assert OOF-IMP2 is gone (next blocker may be OOF-IMP3 or TC-level, not import). Crucially: the proof does NOT claim the parser executes or that all 4 files compile cleanly.

**What the proof does NOT claim:**
- Full igniter_parser compilation clean
- `call_contract("append")` / `call_contract("empty")` in `api.ig` / `parser.ig` resolved (IP-P06)
- `LexNextToken` contract typechecks end-to-end (TC dispatch gaps beyond char_at not in scope)

### Q13 — Can P3 be one narrow dual-toolchain card, or should Ruby/Rust split?

**DUAL-TOOLCHAIN IN ONE CARD (no split).**

Reason:
- The Ruby and Rust changes are symmetric and small: one dispatch arm (~20 lines Ruby, ~25 lines Rust) + emitter entry (~6 lines Rust).
- Splitting creates an intermediate state where `igniter_parser` is blocked at TC in both toolchains after Ruby P3 and before Rust P4.
- The value of clearing IP-P01 at the import-surface level is already captured by the inventory entry in P3. Adding TC dispatch for both toolchains simultaneously completes the TC-level unblock without leaving a stranded half-state.
- Precedent for dual-toolchain in one card: LANG-STDLIB-NUMERIC-COMPARISON-P3 (Ruby + Rust in one card, no split).

Split **would** be appropriate if the Rust change were large or uncertain. Here it is neither.

---

## Authorized P3 File Edit List

| File | Change | Lines (approx) |
|---|---|---|
| `igniter-lang/docs/spec/stdlib-inventory.json` | Append 1 entry `stdlib.string.char_at`; update `stdlib_surface_digest` in `note` field | +35 lines |
| `igniter-lang/lib/igniter_lang/typechecker.rb` | (1) `when "char_at"` arm in `infer_call` after `when "is_empty", "non_empty"` (~line 1038); (2) `def infer_char_at_call` private method after `infer_is_empty_call` body (~line 2782) | +35 lines |
| `igniter-lab/igniter-compiler/src/typechecker.rs` | `"char_at" =>` arm in `Expr::Call` match block after `"is_empty" | "non_empty"` arm (~line 2780) | +25 lines |
| `igniter-lab/igniter-compiler/src/emitter.rs` | Add `STRING_STDLIB_OPS` constant + rewrite block after `COLLECTION_HOF_OPS` block (~line 810); rewrites bare `char_at` → `stdlib.string.char_at` | +15 lines |
| `igniter-lang/lib/igniter_lang/semanticir_emitter.rb` | **NO CHANGES** — `semantic_expr` generic recursion passes `fn: "stdlib.string.char_at"` through unchanged | 0 lines |
| `igniter-lab/igniter-compiler/src/multifile.rs` | **NO CHANGES** — derives from inventory automatically | 0 lines |
| `igniter-lang/lib/igniter_lang/multifile_resolver.rb` | **NO CHANGES** — derives from inventory automatically | 0 lines |
| `igniter-lang/experiments/stdlib_string_surface_proof/verify_stdlib_string_surface_p3.rb` | New proof runner — ≥60 checks / 14 sections A–N | new file |

**Authorized files total: 4 production files + 1 proof runner (new) = 5 files.**

---

## Rust Emitter Change Detail

The Rust emitter currently rewrites bare stdlib names in `semantic_expr` via:
- `TEXT_STDLIB_OPS`: bare text names → `stdlib.text.*` + attach resolved_type
- `COLLECTION_HOF_OPS`: bare collection names → `stdlib.collection.*` (fn-only rewrite; resolved_type from TC)

For `char_at`, follow the `COLLECTION_HOF_OPS` pattern (TC sets resolved_type; emitter only rewrites fn). Insert immediately after `COLLECTION_HOF_OPS` block (~line 810):

```rust
// LANG-STDLIB-STRING-SURFACE-P3: qualify string stdlib bare name to stdlib.string.*
const STRING_STDLIB_OPS: &[(&str, &str)] = &[
    ("char_at", "stdlib.string.char_at"),
];
if let Some((_, qualified)) = STRING_STDLIB_OPS.iter().find(|(bare, _)| *bare == fn_val) {
    let mut new_map = serde_json::Map::new();
    for (k, v) in map {
        if k == "fn" {
            new_map.insert(k.clone(), serde_json::Value::String(qualified.to_string()));
        } else if k != "deps" {
            new_map.insert(k.clone(), self.semantic_expr(v));
        }
    }
    return serde_json::Value::Object(new_map);
}
```

---

## P3 Proof Target

**Runner location:**
- Ruby-side: `igniter-lang/experiments/stdlib_string_surface_proof/verify_stdlib_string_surface_p3.rb`
- Rust-side: `igniter-lab/igniter-compiler/verify_stdlib_string_surface_p3.rb`
  (Or a single runner in `igniter-lang/experiments/` that invokes both toolchains — same pattern as other dual-toolchain proofs)

**Target: ≥60 checks across sections A–N.**

| Section | Focus | Checks |
|---|---|---|
| A | Inventory entry present; schema valid; digest stable after addition | 6 |
| B | Ruby import surface: `stdlib.string.{ char_at }` resolves (no OOF-IMP2) | 4 |
| C | Rust import surface: same — no OOF-IMP2 | 4 |
| D | Ruby TC happy path: `char_at(s, i)` where `s: String`, `i: Integer` → String | 4 |
| E | Rust TC happy path: same | 4 |
| F | Ruby SIR: `fn` = `"stdlib.string.char_at"` in emitted SIR | 4 |
| G | Rust SIR: `fn` = `"stdlib.string.char_at"` in emitted SIR | 4 |
| H | Arity diagnostics: OOF-TY0 on 0/1/3 args (Ruby + Rust) | 6 |
| I | Non-String first arg: OOF-TY0, String still returned (Ruby + Rust) | 4 |
| J | Non-Integer second arg: OOF-TY0, String still returned (Ruby + Rust) | 4 |
| K | igniter_parser lexer.ig + types.ig: OOF-IMP2 gone (import resolves); next blocker NOT OOF-IMP2 | 4 |
| L | `substring` still rejected/not dispatched (no OOF-IMP3 for char_at after P3; substring DEFERRED) | 3 |
| M | stdlib.text.* namespace unchanged: trim/concat/byte_length etc. still dispatch correctly | 5 |
| N | Authority closure: char_at carries no authority; stdlib.string not open to user declarations | 4 |

**Total: 60 checks.**

Regressions to include in the runner:
- P1 proof: `verify_stdlib_string_surface_p1.rb` 55/55 (or embedded regression section)
- stdlib.text regression: TEXT_STDLIB_FNS entries still work
- stdlib.collection regression: append/is_empty/concat still work
- Record literal inference regression (P3 typechecker.rb change must not break `infer_record_literal`)

---

## Diagnostic Policy Summary

```
char_at(String, Integer) -> String      ✓ happy path
char_at(Unknown, Integer) -> String     ✓ permissive (Unknown first arg)
char_at(String, Unknown) -> String      ✓ permissive (Unknown second arg)
char_at(Text, Integer) -> OOF-TY0      "stdlib.string.char_at arg 1: expected String, got Text"
char_at(String, Text) -> OOF-TY0       "stdlib.string.char_at arg 2: expected Integer, got Text"
char_at(String) -> OOF-TY0             "stdlib.string.char_at: expected 2 argument(s), got 1"
char_at(String, 0, 1) -> OOF-TY0       "stdlib.string.char_at: expected 2 argument(s), got 3"
```

String is returned on ALL paths (even OOF paths). No out-of-bounds diagnostic in TC — deferred to runtime.

---

## Non-Goals for P3

- No `stdlib.string.substring` (LANG-STDLIB-STRING-SLICE-P1)
- No String/Text alias reconciliation (LANG-STRING-TEXT-ALIAS-P1)
- No runtime out-of-bounds behavior (VM deferred)
- No runtime execution of `char_at` (TC-only in P3)
- No `text_arg_compatible?` reuse — char_at is strict String, not Text-compatible
- No new OOF codes
- No app source changes
- No `semanticir_emitter.rb` changes
- No `multifile.rs` or `multifile_resolver.rb` changes
