# LANG-STDLIB-IMPORT-SURFACE-P3 — Ruby Implementation Proof Packet

**Track:** lang / stdlib / import-surface
**Route:** RUBY IMPLEMENTATION PROOF
**Status:** CLOSED / PROVED — 62/62 PASS
**Date:** 2026-06-12

---

## Summary

Bounded Ruby canon implementation of stdlib import validation in `MultifileResolver`.
`import stdlib.collection.{ map, filter, count }` now compiles cleanly. Unknown stdlib
module paths emit OOF-IMP2. Known stdlib module with unknown name emits OOF-IMP3.
User source files declaring `module stdlib.*` namespace paths emit OOF-IMP6.
All changes are in `multifile_resolver.rb` only — no TypeChecker, SemanticIR, assembler,
VM, parser, or inventory changes.

---

## Files Modified

| File | Change |
|------|--------|
| `igniter-lang/lib/igniter_lang/multifile_resolver.rb` | 4 insertions: `require "set"`, stdlib guard in `validate_imports`, 5 private helpers, OOF-IMP6 guard in `resolve` |

## Files Created

| File | Role |
|------|------|
| `igniter-lang/experiments/import_stdlib_surface_proof/verify_import_stdlib_surface_p3.rb` | Proof runner |
| `igniter-lang/.agents/work/cards/lang/LANG-STDLIB-IMPORT-SURFACE-P3.md` | Card |
| This file | Proof packet |

---

## Implementation

### `multifile_resolver.rb` Changes

**`require "set"`** added at top alongside existing requires.

**`resolve` method** — OOF-IMP6 guard after `sorted`, before `by_module` construction:

```ruby
stdlib_shadow = sorted.find { |u| u.fetch("module").to_s.start_with?("stdlib.") }
return failure(sorted, [stdlib_shadow_diagnostic(stdlib_shadow)]) if stdlib_shadow
```

**`validate_imports` method** — stdlib guard after `import_path = import.fetch("module_path")`,
before `target = by_module[import_path]`:

```ruby
if stdlib_path?(import_path)
  unless stdlib_module_known?(import_path)
    next [diagnostic("OOF-IMP2",
      "unknown stdlib module path '#{import_path}' from module '#{unit.fetch("module")}'",
      "import:#{import_path}", ...)]
  end
  names = import.fetch("names", nil)
  next [] unless names
  next names.reject { |name| stdlib_name_known?(import_path, name) }.map do |name|
    diagnostic("OOF-IMP3",
      "unknown name '#{name}' in stdlib module '#{import_path}'",
      "import:#{import_path}.{#{name}}", ...)
  end
end
```

**Private helpers** (after `validate_imports`, before `import_cycle`):

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
    inventory = JSON.parse(File.read(inventory_path, encoding: "utf-8"))
    table = Hash.new { |h, k| h[k] = Set.new }
    inventory.fetch("entries", []).each do |entry|
      canon = entry.fetch("canonical_name")
      parts = canon.split(".")
      next unless parts.length >= 3 && parts[0] == "stdlib"
      module_path = parts[0...-1].join(".")
      table[module_path]
      entry.fetch("aliases", []).each do |al|
        table[module_path].add(al.fetch("name")) if al.fetch("kind") == "source_alias"
      end
    end
    table.transform_values { |set| set.freeze }.freeze
  end
end

def stdlib_shadow_diagnostic(unit)
  diagnostic("OOF-IMP6",
    "user source file declares stdlib namespace path '#{unit.fetch("module")}' — stdlib.* is reserved",
    "module:#{unit.fetch("module")}",
    source_path: unit.fetch("source_path"),
    module_path: unit.fetch("module"))
end
```

---

## Diagnostic Inventory

| Code | Trigger | P3 Status |
|------|---------|-----------|
| OOF-IMP2 | Unknown stdlib module path (e.g. `stdlib.bogus`) | NEW for stdlib path |
| OOF-IMP3 | Known stdlib module, unknown alias name (e.g. `append`) | NEW for stdlib path |
| OOF-IMP6 | User source declares `module stdlib.*` | NEW |

Existing OOF-IMP2/3 for user module paths are unchanged.

---

## Key Engineering Notes

**UTF-8 inventory read required.** `stdlib-inventory.json` contains non-ASCII characters
(em dashes, accented characters). Ruby's default `File.read` uses the system encoding
(US-ASCII in this environment), which fails on those bytes. `encoding: "utf-8"` param required.

**Single-file compile bypasses MultifileResolver.** `CompilerOrchestrator#compile_sources`
routes single-file invocations directly (line 95-104); MultifileResolver is only called for
`source_paths.length > 1`. All proof fixtures use two files minimum.

**`and` is a parser keyword.** `import stdlib.bool.{ and }` fails at parse level —
`and` is a keyword token in the Igniter grammar. Use `logical_not` or any non-keyword name
for stdlib.bool OOF-IMP3 proof purposes.

**decision_tree blocked by DT-P02 before import validation.** The `label` field name in
builder.ig / types.ig causes a parse error (`Expected name, got keyword(label)`). The import
validation stage is never reached; no OOF-IMP3 diagnostics are emitted.

---

## Proof Matrix Detail

### Section A — Regression (15 checks)
P5 multi-file user module behaviour unchanged:
A-01..A-04: two-file compile success, synthetic module, imports cleared in SIR, source_units
A-05..A-12: OOF-IMP2/3/1/4/5/DECL-DUP-CONTRACT/DECL-DUP-TYPE/EP1 each fire as before
A-13..A-14: OOF-IMP2/3 diagnostic payloads carry expected fields
A-15: source_hash deterministic across replay runs

### Section B — Stdlib happy path (10 checks)
B-01..B-10: all known module imports compile with status:ok — collection/text/map/option
modules; selective import; whole-module import; multiple stdlib imports in one file.

### Section C — OOF-IMP2 + OOF-IMP6 (7 checks)
C-01..C-02: `stdlib.bogus` and `stdlib.crypto` → OOF-IMP2
C-03: OOF-IMP2 carries source_path, module_path, import_path
C-04..C-05: `module stdlib.collection` and `module stdlib.text` → OOF-IMP6
C-06: OOF-IMP6 carries source_path and module_path
C-07: OOF-IMP6 fires before import validation (status: oof, not ok)

### Section D — OOF-IMP3 (8 checks)
D-01..D-03: append, fold, sum → OOF-IMP3
D-04: `stdlib.bool.{ logical_not }` → OOF-IMP3 (bool module known, empty alias set)
D-05: `stdlib.option.{ some }` → OOF-IMP3
D-06: `{ append, map }` → OOF-IMP3 for append only (not map)
D-07: OOF-IMP3 carries source_path, module_path, import_path, missing_name
D-08: `stdlib.integer.{ add }` → OOF-IMP3 (integer module known, empty alias set)

### Section E — Authority closed (7 checks)
E-01..E-04: no capability_import/package_trust/runtime_loader/profile_binding in manifest
E-05: semantic_ir imports field nil/empty (cleared before TC)
E-06: no stdlib.* entry in source_units evidence
E-07: contract count identical with vs without stdlib import

### Section F — App fixtures (9 checks)
F-01..F-02: advanced_logistics — no OOF-IMP2 for stdlib.collection at all
F-03..F-04: vector_editor — OOF-IMP3 for append (not OOF-IMP2); missing_name = append
F-05..F-06: decision_tree — no OOF-IMP2; blocked at parse (DT-P02 label keyword)
F-07..F-08: arch_patterns — OOF-IMP3 for append only
F-09: no app has OOF-IMP2 for a known stdlib module path

### Section G — Table derivation (6 checks)
G-01..G-06: table has stdlib.collection/text/integer keys; collection includes map/filter/count
and NOT append; text includes trim/contains.

---

## Authority Boundary Summary

Import resolution happens at compile time only. The stdlib module table is a compiler-internal
data structure derived from the inventory; it is never emitted to the manifest or semantic IR.
No field named `capability_import`, `package_trust`, `runtime_loader`, `profile_binding`, or
`stdlib_module_table` appears anywhere in the compiler output. The `source_units` evidence
array records only user-supplied source files. The `imports` field is cleared before the
TypeChecker runs (existing behavior; proven unchanged in Section A and Section E).

---

## Predecessor Boundary

PROP-IMPORT-RESOLUTION-P5 (99/99 PASS) regression matrix embedded in Section A.
All P5 behaviors confirmed unchanged by proof.
