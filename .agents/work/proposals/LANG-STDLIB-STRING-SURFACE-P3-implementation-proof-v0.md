LANG-STDLIB-STRING-SURFACE-P3 — Dual-Toolchain Implementation Proof

Status: CLOSED / PROVED — 70/70 PASS
Proof runner: igniter-lang/experiments/stdlib_string_surface_proof/verify_stdlib_string_surface_p3.rb
Sections: A–O (15 sections)
Gate: LANG-STDLIB-STRING-SURFACE-P2 CLOSED + LANG-STDLIB-STRING-SURFACE-P1 CLOSED (55/55)

---

## What Was Implemented

`stdlib.string.char_at(String, Integer) -> String` — byte-indexed, 0-based character accessor.
Dual-toolchain: Ruby canon typechecker + Rust lab typechecker + Rust emitter SIR qualification.

---

## Production Files Changed (4 files)

### 1. `igniter-lang/docs/spec/stdlib-inventory.json`

New entry added for `stdlib.string.char_at`:

```json
{
  "canonical_name": "stdlib.string.char_at",
  "semantic_ir_name": "stdlib.string.char_at",
  "legacy_sir": null,
  "aliases": [{"kind": "source_alias", "name": "char_at"}],
  "category": "string",
  "lifecycle_status": "lab-implemented",
  "semantic_stability": "proposal-only",
  "lowering_status": "dual-toolchain",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "partial",
  "type_params": [],
  "input_signature": ["String", "Integer"],
  "output_signature": "String",
  "diagnostics": ["OOF-TY0"],
  "failure_behavior": "out-of-bounds: unspecified v0; runtime behavior deferred",
  "authority_surface": "none",
  "proof_lineage": [
    "LANG-STDLIB-STRING-SURFACE-P1 readiness proof 55/55 PASS",
    "LANG-STDLIB-STRING-SURFACE-P2 implementation planning closed",
    "LANG-STDLIB-STRING-SURFACE-P3 dual-toolchain implementation"
  ],
  "examples": ["char_at(\"module\", 0) -> \"m\"", "char_at(\"module\", 1) -> \"o\""],
  "compatibility_note": "byte-indexed, 0-based; out-of-bounds behavior unspecified v0. String returned on all TC paths including OOF error paths. Dual-toolchain (Ruby + Rust P3).",
  "owner_surface": "LANG-STDLIB-STRING-SURFACE-P1",
  "entry_digest": null
}
```

Entry count: 35 → 36 (concurrent LANG-STDLIB-COLLECTION-RANGE-P2 added `stdlib.collection.range`).
`stdlib_surface_digest` recomputed: `cfe520dc02138b5cd0cb2d7e78096c2e908187efed5da6e5be773543b803a3f2`
(canonical_json algorithm: sort by canonical_name, strip entry_digest, SHA256 of key-sorted JSON)

### 2. `igniter-lang/lib/igniter_lang/typechecker.rb` — Ruby Canon TC

**Insertion 1**: dispatch arm in `infer_call` after `when "is_empty", "non_empty"`:

```ruby
when "char_at"
  # LANG-STDLIB-STRING-SURFACE-P3: char_at(String, Integer) -> String
  infer_char_at_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

**Insertion 2**: `infer_char_at_call` private method after `infer_is_empty_call`:

```ruby
def infer_char_at_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  qualified = "stdlib.string.char_at"
  unless args.length == 2
    type_errors << oof("OOF-TY0",
      "#{qualified}: expected 2 argument(s), got #{args.length}", node_name)
    return typed_expr("call", type_ir("String"), [], "fn" => qualified, "args" => [])
  end
  source_arg  = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  source_name = type_name(source_arg.fetch("resolved_type"))
  unless source_name == "Unknown" || source_name == "String"
    type_errors << oof("OOF-TY0",
      "#{qualified} arg 1: expected String, got #{source_name}", node_name)
  end
  index_arg  = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
  index_name = type_name(index_arg.fetch("resolved_type"))
  unless index_name == "Unknown" || index_name == "Integer"
    type_errors << oof("OOF-TY0",
      "#{qualified} arg 2: expected Integer, got #{index_name}", node_name)
  end
  deps = (source_arg.fetch("deps", []) + index_arg.fetch("deps", [])).uniq
  typed_expr("call", type_ir("String"), deps,
             "fn" => qualified, "args" => [source_arg, index_arg])
end
```

Key design: `fn` is set to `"stdlib.string.char_at"` inline → zero Ruby emitter changes.

### 3. `igniter-lab/igniter-compiler/src/typechecker.rs` — Rust Lab TC

`"char_at"` arm added after `"is_empty" | "non_empty"` arm:

```rust
"char_at" => {
    is_resolved = true;
    resolved_type = self.type_ir(&serde_json::Value::String("String".to_string()));
    if args.len() != 2 {
        type_errors.push(ClassifierDiagnostic {
            rule: "OOF-TY0".to_string(),
            message: format!("stdlib.string.char_at: expected 2 argument(s), got {}", args.len()),
            node: node_name.to_string(), line: None,
        });
    } else {
        if !typed_args.is_empty() {
            let source_name = self.type_name(&typed_args[0].resolved_type);
            if source_name != "Unknown" && source_name != "String" {
                type_errors.push(ClassifierDiagnostic {
                    rule: "OOF-TY0".to_string(),
                    message: format!("stdlib.string.char_at arg 1: expected String, got {}", source_name),
                    node: node_name.to_string(), line: None,
                });
            }
        }
        if typed_args.len() >= 2 {
            let index_name = self.type_name(&typed_args[1].resolved_type);
            if index_name != "Unknown" && index_name != "Integer" {
                type_errors.push(ClassifierDiagnostic {
                    rule: "OOF-TY0".to_string(),
                    message: format!("stdlib.string.char_at arg 2: expected Integer, got {}", index_name),
                    node: node_name.to_string(), line: None,
                });
            }
        }
    }
}
```

The Rust TC leaves the fn value as bare `"char_at"` — the emitter qualifies it.

### 4. `igniter-lab/igniter-compiler/src/emitter.rs` — Rust Lab Emitter

Two insertions:

**Insertion A** — `STRING_STDLIB_OPS` rewrite block in `semantic_expr` after `COLLECTION_HOF_OPS`:

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

**Insertion B** — delegation guard in `semantic_expr_for_compute` (KEY DISCOVERY — see below):

```rust
// LANG-STDLIB-STRING-SURFACE-P3: delegate string stdlib to semantic_expr
|| fn_val == "char_at"
```

Added to the `TEXT_STDLIB_OPS_C` delegation block so that compute nodes containing `char_at` calls delegate to `semantic_expr` (which applies the `STRING_STDLIB_OPS` rewrite) rather than recursing via `semantic_expr_for_compute`.

---

## Key Discoveries

### Discovery 1: `semantic_expr_for_compute` delegation requirement

The Rust emitter has two expression processing paths:
- `semantic_expr` — applied to expressions in non-compute contexts
- `semantic_expr_for_compute` — applied to the expression inside a `kind:"compute"` node

`semantic_expr_for_compute` explicitly delegates collection HOF ops (`map`, `filter`, `count`, `append`, `is_empty`, `non_empty`) to `semantic_expr` so they hit the `STRING_STDLIB_OPS`/`COLLECTION_HOF_OPS` rewrite blocks. `char_at` was missing from this delegation list, so the `STRING_STDLIB_OPS` rewrite in `semantic_expr` was never reached for compute-bound calls. Adding `|| fn_val == "char_at"` to the delegation guard fixed this.

This same architectural discovery was originally documented in LANG-STDLIB-COLLECTION-MAP-FILTER-P4.

### Discovery 2: `.igapp` is a directory package

The Ruby `compile_sources` API writes to a `.igapp` directory (not a flat file). The proof runner sections F and G that read SIR output must read `semantic_ir_program.json` inside the directory:
```ruby
sir_file = "/tmp/igniter_p3_inline_ruby.igapp/semantic_ir_program.json"
```

### Discovery 3: Canonical digest algorithm uses key-sorted JSON

The `stdlib_surface_digest` is computed with `canonical_json` (keys sorted alphabetically at all depths), not plain `JSON.generate`. This matches the algorithm used by all other proof runners (e.g. `verify_unary_operators_p3.rb`). A concurrent linter stored the correct `cfe520dc...` value; an intermediate incorrect value was briefly set by this card and then superseded.

### Discovery 4: `compute` must precede `output` in contract bodies

Igniter contract semantics require `compute` declarations to appear before `output` declarations. Reversing the order causes `OOF-P1: Unresolved output source`. All happy-path fixtures in this proof use the correct ordering:
```
compute result = char_at(s, idx)
output result : String
```

### Discovery 5: Single-file compilation bypasses MultifileResolver

`OOF-IMP2`/`OOF-IMP3` only fire for multi-file compilations (MultifileResolver validates import surface). Section L (substring still deferred) was tested via inventory inspection (`stdlib.string.substring` absent from inventory) and TC behavior (`substring` fires `OOF-TY0 "Unknown function"`) rather than import validation.

---

## Proof Sections (70/70 PASS)

| Section | Label | Checks | Result |
|---------|-------|--------|--------|
| A | Inventory Entry | 12 | 12/12 |
| B | Ruby Import Surface | 4 | 4/4 |
| C | Rust Import Surface | 4 | 4/4 |
| D | Ruby TC Happy Path | 4 | 4/4 |
| E | Rust TC Happy Path | 4 | 4/4 |
| F | Ruby SIR fn Canonical | 4 | 4/4 |
| G | Rust SIR fn Canonical | 4 | 4/4 |
| H | Arity Diagnostics | 6 | 6/6 |
| I | Non-String First Arg | 4 | 4/4 |
| J | Non-Integer Second Arg | 4 | 4/4 |
| K | igniter_parser Advances Past OOF-IMP2 | 4 | 4/4 |
| L | substring Still Deferred | 3 | 3/3 |
| M | stdlib.text Namespace Unchanged | 5 | 5/5 |
| N | Authority Closure | 4 | 4/4 |
| O | No Parser/Runtime/OOB Semantics | 4 | 4/4 |

---

## Diagnostic Specification

**Only `OOF-TY0` — no new codes introduced.**

| Trigger | Message |
|---------|---------|
| arity ≠ 2 | `stdlib.string.char_at: expected 2 argument(s), got N` |
| arg 1 not String/Unknown | `stdlib.string.char_at arg 1: expected String, got T` |
| arg 2 not Integer/Unknown | `stdlib.string.char_at arg 2: expected Integer, got T` |

Unknown is permissive in both arg positions (no error, no cascade).
String is returned on ALL paths including OOF error paths.
Arity check is early-return (args not inferred if arity wrong).

---

## Authority Closure

- `authority_surface: "none"` — no capability grant
- `purity: "pure"`, `deterministic: true`
- No parser changes
- No emitter changes in Ruby (`semanticir_emitter.rb` unchanged — fn set inline)
- No multifile_resolver changes (inventory-derived import surface)
- No multifile.rs changes (inventory-derived via `include_str!`)
- No runtime/VM/OOB semantics added
- Out-of-bounds behavior: unspecified v0 / runtime behavior deferred
- `stdlib.text` namespace and all 14 text entries unchanged (M section proves)
- `substring` permanently deferred to `LANG-STDLIB-STRING-SLICE-P1`

---

## Concurrent Agent Note

LANG-STDLIB-COLLECTION-RANGE-P2 ran in parallel and added `stdlib.collection.range` to the inventory (35→36 entries) and updated `stdlib_surface_digest`. This is correct per the concurrency protocol: the digest was recomputed from the current file state including both new entries.

---

## Regressions

Not explicitly run in this proof runner, but:
- Section M proves `stdlib.text` namespace unchanged (14 entries, first-arg Text invariant holds)
- Section K proves `igniter_parser` types.ig + lexer.ig no longer blocked by `OOF-IMP2`
- The Rust build succeeded with no new errors (pre-existing warnings only)

---

## Next Routes

- `LANG-STDLIB-STRING-SLICE-P1` — `substring` deferred surface
- `LANG-STRING-TEXT-ALIAS-P1` — fix `concat(String,String) → String` (currently returns Text)
- `LANG-STDLIB-STRING-SURFACE-P4` — Rust runtime/VM implementation (when authorized)
