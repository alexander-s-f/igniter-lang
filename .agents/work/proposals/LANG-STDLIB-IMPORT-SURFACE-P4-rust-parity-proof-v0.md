# LANG-STDLIB-IMPORT-SURFACE-P4 — Rust Parity Proof Packet

**Track:** lang / stdlib / import-surface
**Route:** RUST PARITY PROOF
**Status:** CLOSED / PROVED — 57/57 PASS
**Date:** 2026-06-12

---

## Summary

Bounded Rust lab parity implementation of stdlib import validation in `MultifileResolver`
(`igniter-lab/igniter-compiler/src/multifile.rs`). Mirrors Ruby P3 behavior against the
current stdlib inventory — including `append`, which was added after P3 was written.

`import stdlib.collection.{ map, filter, count, append }` now compiles cleanly. Unknown
stdlib module paths emit OOF-IMP2. Known stdlib module with unknown alias name emits
OOF-IMP3. User source files declaring `module stdlib.*` emit OOF-IMP6. All changes are
in `multifile.rs` only — no TypeChecker, SemanticIR, assembler, VM, parser, or inventory
changes. Stdlib table loaded at compile time via `include_str!`.

---

## Files Modified

| File | Change |
|------|--------|
| `igniter-lab/igniter-compiler/src/multifile.rs` | 3 insertions: OOF-IMP6 guard in `compile_units`, stdlib intercept in `validate_imports`, `stdlib_module_table()` fn |

## Files Created

| File | Role |
|------|------|
| `igniter-lab/igniter-compiler/verify_import_stdlib_surface_p4.rb` | Proof runner |
| `igniter-lang/.agents/work/cards/lang/LANG-STDLIB-IMPORT-SURFACE-P4.md` | Card |
| This file | Proof packet |

---

## Implementation

### `multifile.rs` Changes

**Insertion 1 — OOF-IMP6 guard in `compile_units`** (after duplicate module diagnostic, before `by_module` construction):

```rust
if let Some(unit) = sorted.iter().find(|u| u.module_path.starts_with("stdlib.")) {
    let mut diag = MultifileDiagnostic::new(
        "OOF-IMP6",
        format!(
            "user source file declares stdlib namespace path '{}' -- stdlib.* is reserved",
            unit.module_path
        ),
        format!("module:{}", unit.module_path),
    );
    diag.source_path = Some(unit.source_path.clone());
    diag.module_path = Some(unit.module_path.clone());
    return Ok(Err(vec![diag]));
}
```

**Insertion 2 — stdlib intercept in `validate_imports`** (before `let Some(target) = by_module.get(...)`):

```rust
if import.module_path.starts_with("stdlib.") {
    let table = stdlib_module_table();
    if !table.contains_key(&import.module_path) {
        let mut diag = MultifileDiagnostic::new(
            "OOF-IMP2",
            format!(
                "unknown stdlib module path '{}' from module '{}'",
                import.module_path, unit.module_path
            ),
            format!("import:{}", import.module_path),
        );
        diag.source_path = Some(unit.source_path.clone());
        diag.module_path = Some(unit.module_path.clone());
        diag.import_path = Some(import.module_path.clone());
        diagnostics.push(diag);
        continue;
    }
    if let Some(names) = import.names.as_ref() {
        let known = table
            .get(&import.module_path)
            .cloned()
            .unwrap_or_default();
        let mut missing: Vec<String> = names
            .iter()
            .filter(|n| !known.contains(*n))
            .cloned()
            .collect();
        missing.sort();
        for name in missing {
            let mut diag = MultifileDiagnostic::new(
                "OOF-IMP3",
                format!(
                    "unknown name '{}' in stdlib module '{}'",
                    name, import.module_path
                ),
                format!("import:{}.{{{}}}", import.module_path, name),
            );
            diag.source_path = Some(unit.source_path.clone());
            diag.module_path = Some(unit.module_path.clone());
            diag.import_path = Some(import.module_path.clone());
            diag.missing_name = Some(name);
            diagnostics.push(diag);
        }
    }
    continue;
}
```

**Insertion 3 — `stdlib_module_table()` at bottom of file:**

```rust
fn stdlib_module_table() -> HashMap<String, Vec<String>> {
    const JSON_STR: &str =
        include_str!("../../../igniter-lang/docs/spec/stdlib-inventory.json");
    let inventory: serde_json::Value =
        serde_json::from_str(JSON_STR).unwrap_or_else(|_| json!({"entries": []}));
    let mut table: HashMap<String, Vec<String>> = HashMap::new();
    if let Some(entries) = inventory["entries"].as_array() {
        for entry in entries {
            if let Some(canon) = entry["canonical_name"].as_str() {
                let parts: Vec<&str> = canon.split('.').collect();
                if parts.len() >= 3 && parts[0] == "stdlib" {
                    let module_path = parts[..parts.len() - 1].join(".");
                    let names = table.entry(module_path).or_insert_with(Vec::new);
                    if let Some(aliases) = entry["aliases"].as_array() {
                        for alias in aliases {
                            if alias["kind"].as_str() == Some("source_alias") {
                                if let Some(name) = alias["name"].as_str() {
                                    let owned = name.to_string();
                                    if !names.contains(&owned) {
                                        names.push(owned);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    table
}
```

---

## Diagnostic Inventory

| Code | Trigger | P4 Status |
|------|---------|-----------|
| OOF-IMP2 | Unknown stdlib module path (user OR stdlib) | Existing for user; NEW for stdlib path |
| OOF-IMP3 | Known stdlib module, unknown alias name | Existing for user; NEW for stdlib path |
| OOF-IMP6 | User source declares `module stdlib.*` | NEW (parity with Ruby P3) |

---

## Key Engineering Notes

**`include_str!` path.** Relative to `src/multifile.rs`:
`../../../igniter-lang/docs/spec/stdlib-inventory.json` resolves as:
`src/` → `igniter-compiler/` → `igniter-lab/` → `igniter-workspace/` → `igniter-lang/docs/spec/stdlib-inventory.json`.
Verified correct at `cargo build --release`.

**OOF-IMP6 message uses ASCII `--`.** Ruby P3 used an em dash `—` in the message string.
Rust uses `--` to avoid any potential UTF-8 encoding edge cases in output consumers.

**`append` is now importable.** `LANG-STDLIB-COLLECTION-APPEND-PROP-P2` added `append`
to the inventory after P3 was written. P4 uses the current inventory, so
`import stdlib.collection.{ append }` compiles cleanly (B-04).

**Rust parser does not treat `label` as a keyword.** Ruby P3's F-05/F-06 adapted for
`decision_tree` being blocked at parse (DT-P02). In Rust, `label` is a valid identifier;
`decision_tree` reaches OOF-TY0 instead.

**`stdlib_module_table()` called per `validate_imports` invocation.** The function
re-parses JSON each call. Acceptable given `include_str!` is a static string (no I/O);
a memoization refactor is a separate concern.

---

## Proof Matrix Detail

### Section A — Regression (12 checks)
A-01..A-09: two-file compile success, SIR, OOF-IMP2/3/1/4 still fire correctly
A-10..A-12: OOF-DECL-DUP-CONTRACT/TYPE diagnostics, missing_name payload

### Section B — Stdlib happy path (10 checks)
B-01..B-05: stdlib.collection map/filter/count/append individually and combined
B-06..B-09: text.trim, text.contains+split, map.map_get, option.or_else
B-10: two stdlib imports in same module — both compile ok

### Section C — OOF-IMP2 + OOF-IMP6 (7 checks)
C-01..C-04: bogus/crypto unknown module → OOF-IMP2 with correct payload + message
C-05..C-07: stdlib.collection and stdlib.text shadow → OOF-IMP6 with payload

### Section D — OOF-IMP3 (8 checks)
D-01..D-05: fold, sum, bool.logical_not, option.some, integer.add → OOF-IMP3
D-06: { fold, map } → OOF-IMP3 for fold only (map passes)
D-07: OOF-IMP3 carries all four payload fields
D-08: { fold, sum } → two OOF-IMP3 diagnostics

### Section E — Authority closed (6 checks)
E-01..E-04: no capability_import/package_trust/runtime_loader/profile_binding
E-05: contract count unchanged with vs without stdlib import
E-06: no stdlib source in source_units

### Section F — App fixtures (9 checks)
F-01..F-02: advanced_logistics — no OOF-IMP2/3 for stdlib.collection (ok)
F-03..F-04: vector_editor — no OOF-IMP2; append now passes (F-04)
F-05..F-06: arch_patterns — no OOF-IMP2; append now passes
F-07..F-08: decision_tree — no OOF-IMP2; append passes; advances to OOF-TY0 in Rust
F-09: no app emits OOF-IMP2 for a known stdlib module path

### Section G — Source text guards (5 checks)
G-01..G-05: OOF-IMP2/3/6 present in source; stdlib_module_table fn present; include_str! + path present

---

## Authority Boundary Summary

Import resolution happens at compile time only. The stdlib module table is an internal
data structure embedded via `include_str!`; it is never emitted to any output artifact.
No field named `capability_import`, `package_trust`, `runtime_loader`, `profile_binding`,
or `stdlib_module_table` appears anywhere in compiler output. The `source_units` evidence
array records only user-supplied source files. The `imports` field is cleared before the
TypeChecker runs (existing behavior; proven unchanged in Section A and Section E).

---

## Predecessor Boundary

LANG-STDLIB-IMPORT-SURFACE-P3 (62/62 PASS) Ruby behavior mirrored in Section A–F.
All prior Rust regression behaviors confirmed unchanged.
