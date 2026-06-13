# LANG-STDLIB-STRING-SURFACE-P1: Minimal String Stdlib Surface

**Track:** lang / stdlib / import-surface / string  
**Route:** PROPOSAL + READINESS PROOF ONLY — no implementation  
**Date:** 2026-06-13  
**Status:** authored — pending review  
**Lineage:** LANG-STDLIB-IMPORT-SURFACE-P1–P4 (import mechanism established); APP-RECHECK-WAVE-P7 (igniter_parser blocked by OOF-IMP2 stdlib.string); LAB-STDLIB-STRINGLY-CALL-CONTRACT-MIGRATION-P3 (cumulative stdlib surface work)  
**Proof:** 55/55 PASS — `igniter-lang/experiments/stdlib_string_surface_proof/verify_stdlib_string_surface_p1.rb`

---

## Problem Statement

`igniter_parser` (`ParserLexer` module) is blocked in both toolchains at import resolution by:

```
OOF-IMP2: unknown stdlib module path 'stdlib.string' from module 'ParserLexer'
```

Source: `igniter-lab/igniter-apps/igniter_parser/lexer.ig`:

```ig
import stdlib.string.{ char_at }
```

The stdlib module table (derived from `stdlib-inventory.json` by both Rust and Ruby) has no `stdlib.string` entry. `stdlib.text` exists with 14 production-implemented functions, but all operate on the `Text` type. `LexerState.source` is typed as `String`. These are distinct types.

The import surface mechanism already works for `stdlib.text` and `stdlib.collection`. Adding `stdlib.string.char_at` to the inventory is the sole change needed to clear OOF-IMP2. The typechecker implementation (`char_at` dispatch) is deferred to P2 (Ruby) and P3 (Rust).

---

## 13 Questions Answered

### Q1 — `stdlib.string` or reuse `stdlib.text`?

**Decision: define `stdlib.string` as the canonical module path for String-type operations.**

Do NOT reuse `stdlib.text`. Reason:

- `LexerState.source : String`, `Token.text : String`, `Token.kind : String` — all parser types use `String`.
- All 14 existing `stdlib.text.*` entries accept `Text` as first argument and return `Text`.
- `String` and `Text` are distinct types in both toolchains — sim_framework SIM-P10 confirms this: `record literal field 'rule_name': expected String, got Text` (OOF-TY0).
- If `char_at` were added under `stdlib.text`, calling `char_at(state.source, state.pos)` where `source : String` would cause a type mismatch.
- `stdlib.string` cleanly owns String-type character operations. `stdlib.text` cleanly owns Text-type operations. These are parallel namespaces for different types.
- Source requires no migration: `import stdlib.string.{ char_at }` in `lexer.ig` is the correct import.

### Q2 — Canonical name for `char_at`?

**`stdlib.string.char_at`** — canonical name.  
**`char_at`** — source alias (the importable short name).

The app already uses `char_at(state.source, state.pos)` after importing `stdlib.string.{ char_at }`. The source alias `char_at` is correct and matches exactly.

### Q3 — Is `substring` in P1 scope?

**No. `substring` is deferred.**

- `lexer.ig` does NOT import or call `substring`.
- `report.md` names it as a *future* requirement: "asserting the **future** existence of `char_at` and `substring`."
- PRESSURE_REGISTRY IP-P05 explicitly marks substring as `PENDING-BEHIND-P01`.
- Deferred to `LANG-STDLIB-STRING-SLICE-P1` after `char_at` is implemented.

### Q4 — Exact types?

| Function | Signature | Notes |
|---|---|---|
| `char_at` | `(String, Integer) -> String` | Byte-indexed; 0-based; returns 1-byte String |
| `substring` | `(String, Integer, Integer) -> String` | **Deferred — not in P1 scope** |

### Q5 — Indexing semantics?

**Byte-indexed, 0-based — explicitly specified.**

`report.md` is explicit: "a robust `stdlib.string` package with **byte-level access** is absolutely mandatory." For a parser of Igniter source (which is ASCII), byte indexing is the correct choice. The semantics: `char_at(s, i)` returns the byte at 0-based offset `i` as a single-byte String.

Indexing is NOT:
- grapheme cluster-based (too heavyweight for a parser)
- Unicode codepoint-based (unnecessary for ASCII source processing)
- unspecified (byte access must be specified precisely)

### Q6 — Out-of-bounds behavior?

**Unspecified in v0.** The inventory entry marks `totality: "partial"` with `failure_behavior: "out-of-bounds: unspecified v0; implementation must define in P2"`. P2 will specify fail-closed behavior (likely: return empty string `""`  or error code — to be decided at implementation time).

### Q7 — Does `char_at` require runtime/locale authority?

**No.** Byte indexing is purely structural — no locale lookup, no Unicode normalization, no time, no IO. The entry has `authority_surface: "none"`, `purity: "pure"`, `deterministic: true`. This matches the `stdlib.text.*` pattern.

### Q8 — Source aliases imported through stdlib inventory only?

**Yes.** The existing mechanism (LANG-STDLIB-IMPORT-SURFACE-P1–P4) already handles this. Both Rust (`multifile.rs` `fn stdlib_module_table()`) and Ruby (`multifile_resolver.rb` `def stdlib_module_table`) derive the module table from `stdlib-inventory.json` at compile time. Adding an entry to the inventory is the canonical mechanism — no resolver code changes are needed.

### Q9 — OOF codes?

No new OOF codes. The existing codes apply:

| Failure | Code | Message shape |
|---|---|---|
| Module path not in table | `OOF-IMP2` | `unknown stdlib module path 'stdlib.string' from module 'X'` |
| Module known, name unknown | `OOF-IMP3` | `unknown name 'Y' in stdlib module 'stdlib.string'` |

After adding `stdlib.string.char_at` to the inventory, neither fires for `import stdlib.string.{ char_at }`.

### Q10 — String/Text alias: deferred or scoped here?

**Explicitly deferred to `LANG-STRING-TEXT-ALIAS-P1`.**

This proposal does NOT attempt to reconcile `String` and `Text`. The position:
- `stdlib.string` → operations on `String` type
- `stdlib.text` → operations on `Text` type
- These are parallel namespaces for distinct types

Whether `String` and `Text` should be aliased is a separate question with broader implications (see SIM-P10 evidence). It must not be resolved as a side effect of this proposal.

### Q11 — Existing text functions in inventory and dispatch?

14 entries under `stdlib.text.*`, all `production-implemented`, all with `Text` first argument:

`byte_length`, `byte_slice`, `concat`, `contains`, `ends_with`, `grapheme_length`, `grapheme_slice`, `replace`, `replace_all`, `rune_length`, `rune_slice`, `split`, `starts_with`, `trim`

None of these accepts `String`. None named `char_at`. The closest is `byte_slice(Text, Integer, Integer) -> Text` — similar semantics but different type and different arity.

### Q12 — What exact import-surface changes would P2/P3 require?

| Phase | Change | Who |
|---|---|---|
| **P1 (this proposal)** | Add `stdlib.string.char_at` entry to `stdlib-inventory.json` | Inventory edit only |
| **P2 (Ruby)** | Add `"char_at"` dispatch arm in Ruby TC; implement byte-index logic | Ruby TC + runtime |
| **P3 (Rust)** | Add `char_at` dispatch arm in Rust TC; implement in VM | Rust TC + VM |

No changes to `multifile.rs` or `multifile_resolver.rb` for any phase — both derive the module table from inventory automatically.

### Q13 — Proof target that unblocks igniter_parser import?

**Target:** OOF-IMP2 clears; `import stdlib.string.{ char_at }` resolves.

Proof mechanism (Section J of runner):
1. Baseline table: `stdlib.string` absent → OOF-IMP2 fires ✓
2. Probe entry added to inventory → `build_probe_module_table` populates `stdlib.string => {"char_at"}` ✓
3. Proposed entry is sole change needed → OOF-IMP2 would not fire ✓
4. Next blocker after P1 inventory change: TC dispatch (P2 work), not OOF-IMP2 ✓

The proof does NOT claim full parser execution — only that the import surface blocker is cleared by the inventory addition.

---

## Proposed Inventory Entry

```json
{
  "canonical_name": "stdlib.string.char_at",
  "semantic_ir_name": "stdlib.string.char_at",
  "category": "string",
  "lifecycle_status": "lab-proposed",
  "semantic_stability": "proposal-only",
  "lowering_status": "not-implemented",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "partial",
  "authority_surface": "none",
  "type_params": [],
  "input_signature": ["String", "Integer"],
  "output_signature": "String",
  "failure_behavior": "out-of-bounds: unspecified v0; implementation must define in P2",
  "aliases": [
    { "kind": "source_alias", "name": "char_at" }
  ],
  "examples": [
    "char_at(\"module\", 0) -> \"m\"",
    "char_at(\"module\", 1) -> \"o\""
  ],
  "proof_lineage": ["LANG-STDLIB-STRING-SURFACE-P1"],
  "compatibility_note": "byte-indexed, 0-based; semantics of out-of-bounds access defined in P2"
}
```

---

## Why Not Other Options

**Option: add `stdlib.string` as alias module for `stdlib.text`.**  
Rejected. The current mechanism has no concept of module-path aliases — only per-entry source aliases. More importantly, `Text` ≠ `String` in the type system. Aliasing the module would create a dispatch path that passes `String` to `Text`-typed functions.

**Option: migrate `lexer.ig` source to `import stdlib.text.{ char_at }`.**  
Rejected for P1. Even if we added `char_at` under `stdlib.text`, the type mismatch (`state.source : String` vs `char_at(Text, Integer) -> Text`) would produce a different blocker. The app would need to retype `LexerState.source` as `Text`, cascading through all 4 types files.

**Option: define `stdlib.string` as the new canonical and deprecate `stdlib.text` later.**  
The choice here is parallel namespaces, not deprecation. `stdlib.text` is production-implemented with 14 functions and active app usage. It is NOT deprecated. Both exist, for their respective types.

---

## Decision Summary

| Question | Decision |
|---|---|
| Module path | `stdlib.string` (new; canonical for String-type ops) |
| Function name | `stdlib.string.char_at`; source alias `char_at` |
| `substring` | Deferred — not P1 scope |
| Type signature | `char_at(String, Integer) -> String` |
| Index semantics | Byte-indexed, 0-based, explicitly specified |
| Out of bounds | Unspecified v0; defined in P2 |
| Authority | None — pure, deterministic, locale-free |
| String/Text boundary | Explicitly deferred to `LANG-STRING-TEXT-ALIAS-P1` |
| OOF codes | OOF-IMP2 / OOF-IMP3 — no new codes |
| P1 change | Inventory-only (add one entry to stdlib-inventory.json) |
| Code changes | None in P1 — both resolvers derive from inventory automatically |

---

## Implementation Phase Plan

| Phase | Card | Change | Outcome |
|---|---|---|---|
| P1 | `LANG-STDLIB-STRING-SURFACE-P1` | Add `stdlib.string.char_at` to inventory | OOF-IMP2 clears; import resolves |
| P2 | `LANG-STDLIB-STRING-CHAR-AT-P2` | Ruby TC dispatch + runtime implementation | Ruby TC types `char_at(String, Integer) -> String` |
| P3 | `LANG-STDLIB-STRING-CHAR-AT-P3` | Rust TC + VM implementation | Rust TC types + VM executes `char_at` |

After P1 + P2: Ruby becomes clean on `char_at` usage. After P1 + P2 + P3: igniter_parser clears to next pressure (stringly call_contract migration — IP-P06).

---

## Non-Goals

- No `stdlib.text` changes
- No `stdlib.string.substring` in P1
- No String/Text alias semantics decided here
- No parser contracts implemented or executed
- No app source changes (`lexer.ig` import is already correct)
- No `multifile.rs` or `multifile_resolver.rb` code changes
- No new OOF codes
- No runtime or VM changes in P1
