# LANG-STDLIB-STRING-SUBSTRING-P1 — Proposal: stdlib.string.substring

**Track:** lang / stdlib / string
**Status:** CLOSED / PROVED — 49/49 PASS
**Scope:** Proposal + readiness proof only. No compiler changes.
**Proof runner:** `igniter-lang/experiments/stdlib_string_surface_proof/verify_stdlib_string_substring_p1.rb`

---

## Summary

Proposes `stdlib.string.substring(String, Integer, Integer) -> String` as the second entry
in the `stdlib.string` namespace. The function extracts a contiguous byte range from a
String and returns a String. It is the natural successor to `char_at` (LANG-STDLIB-STRING-SURFACE-P3)
and the immediate enabler for IP-P05 (igniter_parser byte-range token accumulation).

No inventory edit, no compiler change, no runtime change in P1.
Implementation (P2 = dual-toolchain) follows the same shape as char_at P3.

---

## Questions and Answers

### Q1: What is the proposed canonical name?

**`stdlib.string.substring`**

Rationale: consistent with the `stdlib.string.*` namespace established by char_at (P3).
The function lives in `stdlib.string`, not `stdlib.text` — String and Text are distinct
nominal types; `stdlib.text.byte_slice` is the Text analog (same 3-arg shape, Text domain).
No canonical name collision exists.

### Q2: What is the source alias?

**`substring`**

The source alias is the unqualified name used in `.ig` source files.
`import stdlib.string.{ char_at, substring }` binds both.
Source alias `"substring"` follows the same `kind: "source_alias"` convention as all
other entries in stdlib-inventory.json.

### Q3: What is the full type signature?

**`substring(String, Integer, Integer) -> String`**

- Input: `["String", "Integer", "Integer"]`
- Output: `"String"`

The function takes a source string and two integer parameters and returns a String.
The output is String (same namespace), not Text. This is not a type conversion.

### Q4: What are the argument semantics — `(source, start, stop)` or `(source, start, length)`?

**`(source, start, length)` — start position + byte count, NOT stop position.**

DECISION: `length` (byte count), not `stop` (exclusive end index).

Rationale:
- Ruby `String#byteslice(start, length)` uses length form — directly maps to
  `source.byteslice(start, length)` in the Ruby emitter with zero translation.
- Lexer use case is "extract N bytes starting at position P" — length reads naturally
  for token accumulation (e.g. `substring(src, token_start, token_len)`).
- `stop` form requires arithmetic at call sites: `substring(src, p, p + n)` vs
  `substring(src, p, n)`.
- `byte_slice` in `stdlib.text` uses `(Text, Integer, Integer)` as `(source, start, length)`.
  This P1 adopts the same convention for `stdlib.string`.

Alternative `(source, start, stop)` is REJECTED. Stop form forces every lexer call site
to compute the end index explicitly; no canon usage prefers it.

### Q5: What is the indexing model?

**Byte-based, 0-based start index.**

Consistent with:
- `char_at` (byte-based, 0-based — established in P3)
- igniter_parser/report.md: "byte-level access mandatory for self-hosting"
- Ruby `String#byteslice` (0-based byte start + byte length)
- Rust `&str` slice operations (0-based byte index)

Grapheme / rune indexing belongs to the `stdlib.text.*` namespace.

### Q6: What is the out-of-bounds behavior?

**Unspecified v0; `totality: "partial"`.**

Out-of-bounds slice behavior is not defined in this proposal:
- No panic guarantee
- No empty-string guarantee
- No nil/null guarantee

The implementation may return empty string, panic, or truncate — behavior is deferred
to the first runtime proof card. This matches the `byte_slice` (stdlib.text) pattern:
`"failure_behavior": "out-of-bounds slice is a runtime error"`.

The TC returns String on all paths regardless. No runtime check in TC.

### Q7: What is the authority surface and purity?

**`authority_surface: "none"`, `purity: "pure"`, `deterministic: true`.**

Byte slicing on a String value is:
- Locale-free (no system locale, no encoding negotiation)
- Time-free
- IO-free
- Deterministic (same input → same output always)

No runtime authority required. This is a pure structural operation on the value's bytes.

### Q8: Does this proposal interact with the String/Text alias gap?

**No. This proposal is entirely within `stdlib.string → String`.**

- Input arg 1 is `String`; output is `String`.
- No Text involvement at any position.
- The String/Text alias reconciliation (concat return type, LANG-STRING-TEXT-ALIAS-P1) is
  orthogonal — it concerns operations that cross the String/Text boundary. substring does not.
- No `text_arg_compatible?` usage; no structural assignability concern.

### Q9: What diagnostic codes are proposed?

**OOF-TY0 only. No new codes.**

Error paths (all fire OOF-TY0, all return String, no cascades):

| Condition | Diagnostic | Return |
|---|---|---|
| `args.length != 3` | OOF-TY0 "expected 3 argument(s), got N" | String (early return) |
| arg 1 not String/Unknown | OOF-TY0 "arg 1: expected String, got T" | String |
| arg 2 not Integer/Unknown | OOF-TY0 "arg 2: expected Integer, got T" | String |
| arg 3 not Integer/Unknown | OOF-TY0 "arg 3: expected Integer, got T" | String |

Unknown is permissive on all 3 positions (consistent with char_at).
String is returned on all TC paths including OOF.
No OOF-TY1 cascade (return type is always String, not dependent on args).

### Q10: Should the P2 implementation be split (Ruby-only P2 + Rust P3) or combined (dual-toolchain P2)?

**Combined — dual-toolchain in one P2 card. No split.**

Decision mirrors char_at (LANG-STDLIB-STRING-SURFACE-P3: dual-toolchain in one card).

Rationale:
- Ruby and Rust changes are symmetric and narrow (~15 lines each)
- Splitting leaves stranded TC state: Ruby TC dispatch without Rust parity creates
  divergent diagnostic output until Rust closes
- The emitter pattern is already established (STRING_STDLIB_OPS + semantic_expr_for_compute
  delegation guard) — substring just adds one entry to the existing constant
- No new architectural discovery expected; pattern is proven

---

## Proposed Inventory Entry (DRAFT — not yet added)

```json
{
  "canonical_name": "stdlib.string.substring",
  "semantic_ir_name": "stdlib.string.substring",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "substring" }],
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
  "input_signature": ["String", "Integer", "Integer"],
  "output_signature": "String",
  "diagnostics": ["OOF-TY0"],
  "failure_behavior": "out-of-bounds: unspecified v0; runtime behavior deferred",
  "authority_surface": "none",
  "proof_lineage": [
    "LANG-STDLIB-STRING-SURFACE-P1 char_at readiness 55/55",
    "LANG-STDLIB-STRING-SURFACE-P3 char_at dual-toolchain 70/70",
    "LANG-STDLIB-STRING-SUBSTRING-P1 substring readiness proof 49/49"
  ],
  "examples": [
    "substring(\"module\", 0, 6) -> \"module\"",
    "substring(\"module\", 2, 3) -> \"dul\""
  ],
  "compatibility_note": "byte-indexed, 0-based start, length in bytes; (source, start, length) not (source, start, stop); out-of-bounds unspecified v0; String returned on all TC paths including OOF.",
  "owner_surface": "LANG-STDLIB-STRING-SUBSTRING-P1"
}
```

---

## Implementation Sketch for P2

**P2 scope:** dual-toolchain (Ruby TC + Rust TC + Rust emitter + inventory). No split.

### Ruby TC (`typechecker.rb`)

Dispatch arm after `when "char_at"`:
```ruby
when "char_at"
  infer_char_at_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
when "substring"
  infer_substring_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

New private method `infer_substring_call`:
```ruby
def infer_substring_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  if args.length != 3
    type_errors << build_error("OOF-TY0", "expected 3 argument(s), got #{args.length}", ...)
    return typed_expr("call", type_ir("String"), "stdlib.string.substring", args)
  end
  source_type = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  source_name = type_name(source_type.fetch("resolved_type", {}))
  unless source_name == "Unknown" || source_name == "String"
    type_errors << build_error("OOF-TY0", "arg 1: expected String, got #{source_name}", ...)
  end
  start_type = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
  start_name = type_name(start_type.fetch("resolved_type", {}))
  unless start_name == "Unknown" || start_name == "Integer"
    type_errors << build_error("OOF-TY0", "arg 2: expected Integer, got #{start_name}", ...)
  end
  length_type = infer_expr(args[2], symbol_types, type_errors, type_warnings, node_name)
  length_name = type_name(length_type.fetch("resolved_type", {}))
  unless length_name == "Unknown" || length_name == "Integer"
    type_errors << build_error("OOF-TY0", "arg 3: expected Integer, got #{length_name}", ...)
  end
  typed_expr("call", type_ir("String"), "stdlib.string.substring", args)
end
```

Ruby emitter: **zero changes**. `fn` is set to `"stdlib.string.substring"` inline in the TC,
so `semanticir_emitter.rb` passes it through unchanged (same as char_at).

### Rust TC (`typechecker.rs`)

After `"char_at"` arm:
```rust
"substring" => {
    is_resolved = true;
    resolved_type = self.type_ir("String");
    if args.len() != 3 {
        type_errors.push(self.build_error("OOF-TY0", ...));
    } else {
        // arg1: String/Unknown, arg2: Integer/Unknown, arg3: Integer/Unknown
        // ... (same pattern as char_at with 3 positions)
    }
}
```

### Rust emitter (`emitter.rs`)

Add `"substring"` to `STRING_STDLIB_OPS`:
```rust
const STRING_STDLIB_OPS: &[(&str, &str)] = &[
    ("char_at", "stdlib.string.char_at"),
    ("substring", "stdlib.string.substring"),
];
```

Add delegation guard in `semantic_expr_for_compute`:
```rust
|| fn_val == "char_at"
|| fn_val == "substring"
```

No other emitter change needed.

---

## Evidence Chain

| Source | Relevance |
|---|---|
| `PRESSURE_REGISTRY.md` IP-P05 | PENDING-BEHIND-P01; substring needed for lexer token accumulation |
| `igniter_parser/report.md` | "asserting the future existence of char_at and substring" |
| `igniter_parser/lexer.ig` | No substring import/call today (gap confirmed) |
| `stdlib-inventory.json` C-01 | 1 stdlib.string entry (char_at); substring absent |
| `stdlib.text.byte_slice` | 3-arg Text analog; (Text,Integer,Integer)→Text; byte-based |
| char_at P3 70/70 PASS | Established dual-toolchain pattern; insertion points known |

---

## Authority Boundary

This card: proposal + readiness proof only.

**Changes NOT authorized in P1:**
- No `stdlib-inventory.json` edit
- No `typechecker.rb` edit
- No `typechecker.rs` edit
- No `emitter.rs` edit
- No `semanticir_emitter.rb` edit
- No `igniter_parser` source edit

All production changes belong to the P2 card.

---

## Proof Result

**49/49 PASS — `verify_stdlib_string_substring_p1.rb`**

| Section | Checks | Topic |
|---|---|---|
| A | 8 | Parser app pressure — IP-P05, lexer.ig, report.md |
| B | 7 | char_at P3 boundary — established; gap confirmed |
| C | 7 | Inventory census — 1 stdlib.string, 14 stdlib.text, byte_slice analog |
| D | 8 | API shape — canonical name, alias, signature, semantics |
| E | 5 | Authority closure — none / pure / deterministic / no Text |
| F | 7 | Diagnostics proposal — OOF-TY0 only, arity/arg1/arg2/arg3, Unknown permissive |
| G | 7 | Implementation matrix — P1 scope, P2 dual-toolchain, insertion points |
| **Total** | **49** | |
