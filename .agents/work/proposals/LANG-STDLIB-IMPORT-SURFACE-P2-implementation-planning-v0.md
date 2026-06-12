# LANG-STDLIB-IMPORT-SURFACE-P2 — Implementation Planning

**Track:** lang / stdlib / import-surface
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE
**Authority:** planning text only — no implementation
**Date:** 2026-06-12
**Status:** CLOSED / READY FOR P3
**Predecessor:** LANG-STDLIB-IMPORT-SURFACE-P1 (6 boundary questions answered / boundary decisions made)

---

## Planning Decision: READY FOR P3

No structural blockers. All 10 questions answered. One file in Ruby, one function
in Rust; structurally parallel changes. P3 implements Ruby only; Rust parity in P4.

---

## 1. Exact Insertion Point — Ruby MultifileResolver

**File:** `igniter-lang/lib/igniter_lang/multifile_resolver.rb`

**Calling site (no change needed):** `resolve` method, line 26:
```ruby
import_diagnostics = validate_imports(sorted, by_module)
```
The call is unchanged. The stdlib check lives entirely inside `validate_imports`
and the new private helpers.

**Modification: `validate_imports` method (line 129)**

Insert a stdlib guard immediately after `import_path = import.fetch("module_path")`
(line 132), before `target = by_module[import_path]` (line 133):

```ruby
def validate_imports(units, by_module)
  units.flat_map do |unit|
    unit.fetch("imports").flat_map do |import|
      import_path = import.fetch("module_path")

      # NEW: stdlib path intercept — before user module table
      if stdlib_path?(import_path)
        unless stdlib_module_known?(import_path)
          next [diagnostic(
            "OOF-IMP2",
            "unknown stdlib module path '#{import_path}' from module '#{unit.fetch("module")}'",
            "import:#{import_path}",
            source_path: unit.fetch("source_path"),
            module_path: unit.fetch("module"),
            import_path: import_path
          )]
        end
        names = import.fetch("names", nil)
        next [] unless names
        next names.reject { |name| stdlib_name_known?(import_path, name) }.map do |name|
          diagnostic(
            "OOF-IMP3",
            "unknown name '#{name}' in stdlib module '#{import_path}'",
            "import:#{import_path}.{#{name}}",
            source_path: unit.fetch("source_path"),
            module_path: unit.fetch("module"),
            import_path: import_path,
            missing_name: name
          )
        end
      end

      # existing user module resolution unchanged below
      target = by_module[import_path]
      # ... rest of existing code
    end
  end
end
```

**New private methods (added after `validate_imports`, before `import_cycle`):**

```ruby
def stdlib_path?(import_path)
  import_path.start_with?("stdlib.")
end

def stdlib_module_known?(import_path)
  stdlib_module_table.key?(import_path)
end

def stdlib_name_known?(import_path, name)
  stdlib_module_table.fetch(import_path, Set.new).include?(name)
end

def stdlib_module_table
  @stdlib_module_table ||= begin
    inventory_path = File.expand_path("../../docs/spec/stdlib-inventory.json", __dir__)
    inventory = JSON.parse(File.read(inventory_path))
    table = Hash.new { |h, k| h[k] = Set.new }
    inventory.fetch("entries", []).each do |entry|
      canon = entry.fetch("canonical_name")
      parts = canon.split(".")
      next unless parts.length >= 3 && parts[0] == "stdlib"
      module_path = parts[0...-1].join(".")
      table[module_path]  # ensure module_path key exists even if no aliases
      entry.fetch("aliases", []).each do |al|
        table[module_path].add(al.fetch("name")) if al.fetch("kind") == "source_alias"
      end
    end
    table.transform_values { |set| set.freeze }.freeze
  end
end
```

**Namespace shadow guard (OOF-IMP6 — see §6):** add to `resolve` after sorting,
before building `by_module`:
```ruby
stdlib_shadow = sorted.find { |unit| unit.fetch("module").to_s.start_with?("stdlib.") }
return failure(sorted, [stdlib_shadow_diagnostic(stdlib_shadow)]) if stdlib_shadow
```

**Total Ruby change: ~50 lines in one file. Two insertions:
(1) guard inside `validate_imports`; (2) four private helper methods.**

---

## 2. Exact Insertion Point — Rust Multifile Resolver

**File:** `igniter-lab/igniter-compiler/src/multifile.rs`

**Modification: `validate_imports` function (line 205)**

The `let Some(target) = by_module.get(&import.module_path) else { ... }` block
(line 214) must be preceded by a stdlib intercept:

```rust
fn validate_imports(
    units: &[SourceUnit],
    by_module: &HashMap<String, SourceUnit>,
) -> Vec<MultifileDiagnostic> {
    let stdlib_table = build_stdlib_table();
    let mut diagnostics = Vec::new();
    for unit in units {
        for import in &unit.imports {
            // NEW: stdlib path intercept
            if import.module_path.starts_with("stdlib.") {
                if !stdlib_table.contains_key(&import.module_path) {
                    let mut diag = MultifileDiagnostic::new(
                        "OOF-IMP2",
                        format!("unknown stdlib module path '{}' from module '{}'",
                                import.module_path, unit.module_path),
                        format!("import:{}", import.module_path),
                    );
                    diag.source_path = Some(unit.source_path.clone());
                    diag.module_path = Some(unit.module_path.clone());
                    diag.import_path = Some(import.module_path.clone());
                    diagnostics.push(diag);
                    continue;
                }
                if let Some(names) = import.names.as_ref() {
                    let known = stdlib_table.get(&import.module_path)
                        .map(|s| s.as_ref())
                        .unwrap_or(&[] as &[String]);
                    let mut missing: Vec<String> = names.iter()
                        .filter(|name| !known.contains(name))
                        .cloned()
                        .collect();
                    missing.sort();
                    for name in missing {
                        let mut diag = MultifileDiagnostic::new(
                            "OOF-IMP3",
                            format!("unknown name '{}' in stdlib module '{}'",
                                    name, import.module_path),
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

            // existing user module resolution unchanged below
            let Some(target) = by_module.get(&import.module_path) else { ... };
            // ... rest of existing code
        }
    }
    diagnostics
}
```

**New function `build_stdlib_table` (added in `multifile.rs`):**

```rust
fn build_stdlib_table() -> HashMap<String, Vec<String>> {
    let inventory_json = include_str!("../../../igniter-lang/docs/spec/stdlib-inventory.json");
    let inventory: Value = serde_json::from_str(inventory_json).unwrap_or_default();
    let mut table: HashMap<String, Vec<String>> = HashMap::new();
    if let Some(entries) = inventory.get("entries").and_then(|e| e.as_array()) {
        for entry in entries {
            if let Some(canon) = entry.get("canonical_name").and_then(|v| v.as_str()) {
                let parts: Vec<&str> = canon.split('.').collect();
                if parts.len() >= 3 && parts[0] == "stdlib" {
                    let module_path = parts[..parts.len()-1].join(".");
                    table.entry(module_path.clone()).or_default();
                    if let Some(aliases) = entry.get("aliases").and_then(|a| a.as_array()) {
                        for al in aliases {
                            if al.get("kind").and_then(|k| k.as_str()) == Some("source_alias") {
                                if let Some(name) = al.get("name").and_then(|n| n.as_str()) {
                                    table.entry(module_path.clone()).or_default()
                                         .push(name.to_string());
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

`include_str!` path relative to `multifile.rs` (`igniter-lab/igniter-compiler/src/`):
```
"../../../igniter-lang/docs/spec/stdlib-inventory.json"
```
Resolves: `igniter-lab/igniter-compiler/src/` → `../../../` = `igniter-workspace/` →
`igniter-workspace/igniter-lang/docs/spec/stdlib-inventory.json`. Correct.

**Namespace shadow guard:** in `compile_units`, after sorting, check
`unit.module_path.starts_with("stdlib.")` — emit OOF-IMP6 and return early.

**Total Rust change: ~60 lines in one file. Two insertions:
(1) stdlib intercept inside `validate_imports`; (2) `build_stdlib_table` free function.**

---

## 3. Built-in Stdlib Module Table Shape

**Logical shape (both Ruby and Rust):**

```text
module_path → Set[importable_source_alias]
```

- Key: stdlib module path prefix, e.g., `"stdlib.collection"`, `"stdlib.text"`
- Value: set of `source_alias` names importable from that module

A module path key exists for every inventory entry with `canonical_name` matching
`stdlib.<category>.<fn>`. The value is empty for modules with no `source_alias` entries.

**Current table derived from inventory (26 entries as of LANG-STDLIB-ENTRY-CONTRACT-P3):**

| Module path | Importable names (source_aliases) | Note |
|-------------|-----------------------------------|------|
| `stdlib.text` | byte_length, byte_slice, concat, contains, ends_with, grapheme_length, grapheme_slice, replace, replace_all, rune_length, rune_slice, split, starts_with, trim | 14 names |
| `stdlib.map` | map_empty, map_from_pairs, map_get, map_has_key | 4 names |
| `stdlib.option` | or_else | 1 name; `wrap` has no source_alias (orphan) |
| `stdlib.collection` | count, filter, map | 3 names; `concat` has no source_alias (orphan) |
| `stdlib.bool` | _(empty)_ | `bool.and` is orphaned with no source_alias |
| `stdlib.numeric` | _(empty)_ | `integer.gt` is orphaned with no source_alias |

**Gaps (not importable today — inventory entries needed):**
- `stdlib.collection.fold` — dispatched by TC but not in inventory (LANG-STDLIB-FOLD-PROP-P4 will add it)
- `stdlib.collection.sum` — dispatched by TC but not in inventory (LANG-STDLIB-SUM-PROP-P4 will add it)
- `stdlib.collection.append` — not in inventory, not in TC (LANG-STDLIB-COLLECTION-APPEND-P1)
- `stdlib.outcome.*` — not in inventory (outcome P4 inventory track)

**App impact after P3 fix:**
- `advanced_logistics/router.ig`: `import stdlib.collection.{ filter }` → OK (filter is importable)
- `vector_editor/document.ig`: `import stdlib.collection.{ append, map }` → map OK; append → OOF-IMP3 (not in inventory)
- `decision_tree/builder.ig`, `example.ig`: `import stdlib.collection.{ append }` → OOF-IMP3
- `decision_tree/evaluator.ig`: `import stdlib.collection.{ filter }` → OK

---

## 4. How to Derive Module/Name Membership from Inventory

**Ruby (load at runtime, memoized):**

Inventory path: `File.expand_path("../../docs/spec/stdlib-inventory.json", __dir__)`
(`__dir__` = `igniter-lang/lib/igniter_lang/`; `../../` = `igniter-lang/`)

Derivation algorithm:
1. Parse JSON from inventory file
2. For each entry in `entries`:
   - Split `canonical_name` on `.`; skip if fewer than 3 parts or first part ≠ `"stdlib"`
   - `module_path` = `parts[0...-1].join(".")` (all but last part)
   - Ensure `module_path` key exists in table (even if no aliases)
   - For each alias with `kind == "source_alias"`: add `alias.name` to the set for `module_path`
3. Freeze both sets and the outer hash

`@stdlib_module_table` is memoized on the `MultifileResolver` instance — computed once
per resolver lifetime, never reloaded mid-compilation.

**Rust (embed at compile time via `include_str!`):**

```rust
const STDLIB_INVENTORY: &str = include_str!("../../../igniter-lang/docs/spec/stdlib-inventory.json");
```

`build_stdlib_table()` parses `STDLIB_INVENTORY` using `serde_json` (already a dependency).
Same algorithm as Ruby. Called once at the top of `validate_imports`.

**Proof verification of table correctness (Section G in proof runner):**
- Load inventory in proof script
- Build expected table by the same derivation algorithm
- Assert `BUILT_TABLE == EXPECTED_TABLE` for each module path
- Assert `stdlib.collection` importable names = `{"map", "filter", "count"}`
- Assert `stdlib.text` has exactly 14 names
- Assert `stdlib.map` has exactly 4 names
- Assert `stdlib.option` = `{"or_else"}`
- Assert `stdlib.collection` does NOT contain `"fold"`, `"sum"`, `"append"`, `"concat"`

---

## 5. Whether P3 Implements Ruby, Rust, or Both

**Decision: Ruby only in P3. Rust parity in P4.**

Rationale: follows the established pattern across all stdlib cards
(map/filter/count P3/P4, sum P3/P4-not-yet, fold P3/P4-not-yet). The Ruby canon
is the primary proof target; Rust parity is separately authorized.

However, the Rust changes are structurally parallel and well-scoped (~60 lines,
one function + one helper). If the Rust implementation is included in P3, the
scope increase is bounded and the proof would include both toolchains. The choice
is a governance decision; P2 presents Ruby-only as the canonical pattern while
noting Rust is viable in the same P3.

**P3 authorized files:**
- `igniter-lang/lib/igniter_lang/multifile_resolver.rb` — primary
- `igniter-lang/experiments/import_stdlib_surface_proof/verify_import_stdlib_surface_p3.rb` — proof runner

**P4 authorized files (Rust parity):**
- `igniter-lab/igniter-compiler/src/multifile.rs` — Rust implementation

---

## 6. OOF-IMP2 Trigger for Unknown `stdlib.*` Module

**Trigger condition:**
`import_path.start_with?("stdlib.")` AND `!stdlib_module_table.key?(import_path)`

**Examples:**
- `import stdlib.bogus.{ foo }` → `stdlib.bogus` not in table → OOF-IMP2
- `import stdlib.crypto.{ hash }` → `stdlib.crypto` not in table → OOF-IMP2
- `import stdlib.queue.{ push }` → `stdlib.queue` not in table → OOF-IMP2
- `import stdlib.bool.{ not }` → `stdlib.bool` IS in table (empty set) → OOF-IMP3 for `not` (see §7)
- `import stdlib.collection.{ filter }` → `stdlib.collection` in table, `filter` in set → OK (no diagnostic)

**Message format:** `"unknown stdlib module path '#{import_path}' from module '#{unit.fetch("module")}'"`

**Payload fields:** source_path, module_path, import_path

**Critical: stdlib check intercepts ALL `stdlib.*` paths before the user module table.**
A user who declares `module stdlib.bogus` in their source does NOT cause OOF-IMP2
to fall through to a false-positive resolution — the stdlib guard intercepts first.

---

## 7. OOF-IMP3 Trigger for Known Stdlib Module, Unknown Name

**Trigger condition:**
`import_path.start_with?("stdlib.")` AND `stdlib_module_table.key?(import_path)`
AND `!stdlib_module_table[import_path].include?(name)`

**Examples (selective imports only — whole-module has no name to check):**
- `import stdlib.collection.{ append }` → `stdlib.collection` known, `append` NOT in {count, filter, map} → OOF-IMP3
- `import stdlib.collection.{ fold }` → `fold` not in inventory set → OOF-IMP3 (until LANG-STDLIB-FOLD-PROP-P4 adds it)
- `import stdlib.collection.{ sum }` → `sum` not in inventory set → OOF-IMP3 (until LANG-STDLIB-SUM-PROP-P4 adds it)
- `import stdlib.bool.{ and }` → `stdlib.bool` known (empty set), `and` not a source_alias → OOF-IMP3
- `import stdlib.option.{ some }` → `stdlib.option` known, `some` not a source_alias → OOF-IMP3

**Message format:** `"unknown name '#{name}' in stdlib module '#{import_path}'"`

**Payload fields:** source_path, module_path, import_path, missing_name

**Note:** per-name, not per-import. `import stdlib.collection.{ append, map }` produces:
- OOF-IMP3 for `append` (not importable)
- no error for `map` (importable)
This matches the existing user-module OOF-IMP3 behavior.

---

## 8. Whether Import Clears Before TypeChecker

**Answer: already the case — no implementation change needed.**

Ruby `MultifileResolver#merge_units` (line ~162):
```ruby
"imports" => [],    # explicit clear
```
The merged parsed program has `imports: []`. The TypeChecker never sees import
declarations regardless of whether they are stdlib or user-module.

Rust `merged_source` function strips `import ` lines from the merged source:
```rust
if trimmed.starts_with("module ") || trimmed.starts_with("import ") {
    continue;
}
```
The merged source passed to the Rust TypeChecker contains no import declarations.

**Consequence for the proof:** P3 proof must verify that a fixture with
`import stdlib.collection.{ map }` produces a SIR result identical in shape to
a fixture without the import. The import leaves no trace in SIR, manifest, or
TypeChecker output.

---

## 9. How to Prove No Capability/Profile/Package/Runtime Authority

**Section E of proof runner — authority-closed checks:**

E-01: Compile a fixture with `import stdlib.collection.{ map }` + map call.
  Assert: `result[:status] == "ok"`.
  Assert: no field named `"capability"`, `"authority"`, `"profile_binding"`, or
  `"package"` anywhere in the SIR (deep key scan).

E-02: Assert: `result[:sir]` contains `fn: "stdlib.collection.map"` (canonical name
  unchanged — import does not rewrite it to `"map"`).

E-03: Compare SIR shape of identical contract compiled (a) with `import stdlib.collection.{ map }` and
  (b) without. Assert: SIR shapes are equal. Import leaves no trace.

E-04: Assert: `result[:manifest].fetch("source_units")` does NOT contain any entry
  with `module` starting with `"stdlib."`. Stdlib is not a source unit.

E-05: Assert: compiling the same fixture with `import stdlib.collection.{ filter }`
  (whole-module-not-opened; selective valid) produces `status: "ok"` with no
  `"capability"` or `"authority"` fields.

E-06: Assert: MultifileResolver result does NOT expose any `"stdlib_module_table"`
  field in its return hash. The table is internal implementation detail, not
  emitted to the caller.

E-07: Assert: `result[:manifest].fetch("dependency_edges", [])` contains no edge
  with `to_module` starting with `"stdlib."`. Stdlib modules are not declaration
  targets in the typed-ref dependency graph.

---

## 10. Regression Matrix for Normal User Imports

**Section A of proof runner — P5 behavior preserved:**

All normal user-module import behavior must continue unchanged. P3 must not break:

A-01: Two-file user import (happy path) → status ok, resolved types cross-module
A-02: Whole-module user import → status ok
A-03: Selective user import → status ok, imported names resolved
A-04: OOF-IMP1 circular user import → still fires, same payload
A-05: OOF-IMP2 unknown user module (non-stdlib) → still fires, same payload
A-06: OOF-IMP3 unknown name from user module → still fires, same payload
A-07: OOF-IMP4 duplicate module declaration → still fires
A-08: OOF-IMP5 missing module declaration → still fires
A-09: OOF-DECL-DUP-CONTRACT across files → still fires
A-10: OOF-DECL-DUP-TYPE across files → still fires
A-11: Import of `AdvancedLogisticsTypes` module (real cross-module user import) → still ok
A-12: Determinism — same sources → same source_hash, artifact_hash
A-13: `source_units` evidence present in report
A-14: Entrypoint coexistence still correct
A-15: Proof runner P5 99/99 still passes (or a representative 15-check subset of it)

Full regression: run `experiments/import_resolution_proof/verify_prop_import_resolution_p5.rb`
(99/99) and assert it still passes in full.

---

## 11. Namespace Shadow Guard (OOF-IMP6)

**Condition:** a user source file declares `module stdlib.X` (any `stdlib.`-prefixed
module name).

**Code:** `OOF-IMP6` — "user module declares stdlib.* namespace path"

**Diagnostic message:** `"user source file declares reserved stdlib.* module path '#{module_path}'"`

**Trigger:** in `resolve`, after `sorted = units.sort_by { ... }`, before
`by_module = sorted.to_h { ... }`:
```ruby
stdlib_shadow = sorted.find { |u| u.fetch("module").to_s.start_with?("stdlib.") }
return failure(sorted, [stdlib_shadow_diagnostic(stdlib_shadow)]) if stdlib_shadow
```

**Payload:** source_path, module_path

**Negative test:** proof Section C includes one fixture where user declares
`module stdlib.collection` — must produce OOF-IMP6, not OOF-IMP2/3.

---

## 12. Proof Matrix

**Proof runner:** `igniter-lang/experiments/import_stdlib_surface_proof/verify_import_stdlib_surface_p3.rb`

| Section | Checks | Description |
|---------|--------|-------------|
| A — Regression | 15 | P5 user-module behavior unchanged; full P5 suite passes |
| B — Stdlib happy path | 10 | stdlib.collection/text/map/option — selective + whole-module compile ok |
| C — OOF-IMP2 unknown module | 7 | stdlib.bogus, stdlib.crypto, stdlib.queue; namespace shadow (OOF-IMP6) |
| D — OOF-IMP3 known module unknown name | 8 | stdlib.collection.{append,fold,sum}; stdlib.bool.{and}; stdlib.option.{some} |
| E — Authority closed | 7 | No capability/profile fields; SIR shape unchanged by import; no stdlib source_units |
| F — App fixtures | 9 | advanced_logistics filter OK; vector_editor map OK + append OOF-IMP3; decision_tree filter OK + append OOF-IMP3 |
| G — Table derivation | 5 | Table matches inventory; exact name sets; fold/sum/append/concat NOT importable |
| **Total** | **≥61** | |

---

## 13. Authorized Files

**P3 authorized:**
| File | Change |
|------|--------|
| `igniter-lang/lib/igniter_lang/multifile_resolver.rb` | Guard in `validate_imports` + 4 private helpers + OOF-IMP6 guard in `resolve` |
| `igniter-lang/experiments/import_stdlib_surface_proof/verify_import_stdlib_surface_p3.rb` | Proof runner (new) |
| `igniter-lang/.agents/work/cards/lang/LANG-STDLIB-IMPORT-SURFACE-P3.md` | Card |
| `igniter-lang/.agents/work/proposals/README.md` | Row update |
| `igniter-lab/.agents/portfolio-index.md` | Entry prepend |

**P3 closed (not authorized):**
- No TypeChecker changes (dispatch tables are unchanged)
- No SemanticIR / assembler changes
- No inventory edits (fold/sum/append entries are future P4 work)
- No stdlib-inventory.json write path (loaded read-only)
- No OOF codes other than OOF-IMP2, OOF-IMP3, OOF-IMP6
- No Rust implementation (P4)
- No VM / runtime / parser / classifier changes
- No capability/profile/package authority widening

---

## 14. Key Design Decisions Summary

| Question | Decision |
|----------|----------|
| Ruby insertion point | `validate_imports` guard before `by_module` lookup; 4 private helpers; OOF-IMP6 guard in `resolve` |
| Rust insertion point | `validate_imports` function before `let Some(target)` guard; `build_stdlib_table()` free function; `include_str!` embed |
| Table shape | `Hash[String → Set[String]]` (Ruby) / `HashMap<String, Vec<String>>` (Rust); key=module path, value=source_alias names |
| Derivation | Ruby: load JSON from `../../docs/spec/stdlib-inventory.json` relative to `__dir__`, memoized; Rust: `include_str!` compile-time embed |
| P3 scope | Ruby only; Rust in P4 |
| OOF-IMP2 trigger | `stdlib.*` path + module path not in table |
| OOF-IMP3 trigger | `stdlib.*` path + module known + name not in module's alias set |
| Import clears before TC | Already the case — `merge_units` sets `imports: []`; `merged_source` strips `import` lines |
| Authority proof | SIR unchanged; no capability/profile fields; no stdlib source_units in manifest; E-01..E-07 checks |
| Regression | Section A: 15 checks; P5 99/99 full suite re-run |

---

## 15. Next Route

**LANG-STDLIB-IMPORT-SURFACE-P3** — bounded Ruby canon implementation proof.
Goal: implement stdlib import resolution in `MultifileResolver`; prove all 61 checks.
