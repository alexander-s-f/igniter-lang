# LANG-TYPED-CONTRACT-REF-P4 — Cross-Module Typed Refs Planning

**Track:** lang-typed-contract-ref-cross-module-resolution
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE
**Date:** 2026-06-11
**Status:** planning-complete — ready for P5
**Predecessor:** LANG-TYPED-CONTRACT-REF-P3 (67/67 PASS — same-module `uses ContractName` live)
**OOF-REF2 gap:** P3 deferred all dotted/cross-module targets with this error; P4 plans the fix

---

## Context

LANG-TYPED-CONTRACT-REF-P3 proved the complete same-module pipeline for `uses ContractName`:
parser 1-token lookahead, classifier `"metadata"` fragment, typechecker same-module registry,
SemanticIR `contract_refs`, assembler `dependency_edges`. The one deliberate gap:
`typecheck_uses_contract` (typechecker.rb:524) fires `OOF-REF2` for ANY target that contains
a dot (`target.include?(".")`). This is the only line P5 must change.

LAB-FORM-VOCABULARY-P1 (61/61 PASS) proved the cross-module form coherence model is sound
given resolved typed refs. TH-2 was accepted conditionally: it holds once OOF-REF2 is fixed.

This document answers all 10 planning questions and specifies the exact insertion points,
resolution algorithm, diagnostic behavior, data shape changes, and proof matrix for P5.

---

## Q1 — Source Forms

Three forms of `uses` declaration cover the cross-module surface:

| Form | Surface syntax | AST output (existing) | Notes |
|------|---------------|----------------------|-------|
| Same-module (P3 live) | `uses Validator` | `{ kind: "uses_contract", target: "Validator" }` | No change — already resolved by P3 |
| Qualified cross-module | `uses Query.Validator` | `{ kind: "uses_contract", target: "Query.Validator" }` | Dot in target; P3 fires OOF-REF2 — P5 resolves |
| Imported unqualified | `import Query` + `uses Validator` | `{ kind: "uses_contract", target: "Validator" }` | Same AST as same-module; distinguishable only at resolution time via import scope |

**Parser: no changes required.** The existing 1-token lookahead branch already handles dotted
targets via its dotted-name read loop. No new parser surface needed.

The `import Mod.{ ContractName }` selective form (from PROP-IMPORT-RESOLUTION-P5) must be
respected: a selective import of `Query.{ Validator }` makes only `Validator` visible for
unqualified import resolution, not other contracts from `Query`.

---

## Q2 — Module Table Input to TypeChecker

### Current state

`TypeChecker` currently receives only the `classified_program` for the single module being
compiled. It does not know about other modules' contracts.

### P5 design

`MultifileResolver#resolve` already produces `source_units_evidence`:

```ruby
[{
  "module" => "Lab.Query",
  "source_path" => "/path/to/query.ig",
  "source_hash" => "sha256:...",
  "types" => [],
  "contracts" => ["Validator", "Processor"]   # string list only
}]
```

This is insufficient: the typechecker needs `modifier`, `input_count`, `input_names`,
`output_names` for each contract to populate `contract_refs` in SIR.

### Solution: richer cross-module registry from MultifileResolver

**File: `multifile_resolver.rb`** — add one private method `build_cross_module_registry(units)`:

```
cross_module_registry[module_name][contract_name] = {
  modifier:      <string>,
  input_count:   <integer>,
  input_names:   <array of strings>,
  output_names:  <array of strings>,
  source_hash:   <string>,
  source_path:   <string>
}
```

Built by running `Classifier.new.classify(parsed_unit)` on each individually-parsed source
unit before the merge step, then extracting contract signatures from the classified contracts.
This reuses the existing classifier — no new parsing machinery.

The result is exposed as `"cross_module_registry"` in the `resolve` success hash.

**File: `compiler_orchestrator.rb`** — in `compile_sources` (multifile path), after
`MultifileResolver.new.resolve(source_paths)`, pass `cross_module_registry` to
`TypeChecker.new` or the `typecheck` call for each module.

**TypeChecker constructor addition:**

```ruby
def initialize(classified_program, cross_module_registry: {})
  @cross_module_registry = cross_module_registry   # { module_name → { contract_name → sig } }
  # ... existing initialization
end
```

The `@import_scope` is derived from `classified_program.fetch("imports", [])` — no new input
needed; it's already in the classified program.

For single-file compilation, `cross_module_registry:` defaults to `{}`, preserving P3
backward-compatibility exactly.

---

## Q3 — Resolution Algorithm

`typecheck_uses_contract(decl, current_contract_name, type_errors)` — replace the
`target.include?(".")` → OOF-REF2 branch with the following 3-path algorithm:

```
target = decl["target"]

PATH 0 — Self-reference (unchanged from P3)
  if target == current_contract_name
    → OOF-REF4 ("uses itself — self-reference not allowed")
    return

PATH 1 — Qualified cross-module (dotted target)
  if target.include?(".")
    module_path, contract_name = split_at_last_dot(target)
    mod_registry = @cross_module_registry[module_path]
    if mod_registry.nil?
      → OOF-REF1 (module '#{module_path}' is not known in the compilation unit)
      return
    unless imported_module?(module_path)
      → OOF-REF1 (module '#{module_path}' is not imported in this module)
      return
    sig = mod_registry[contract_name]
    if sig.nil?
      → OOF-REF1 (module '#{module_path}' does not export contract '#{contract_name}')
      return
    → resolved: resolution_kind: "qualified", module_name: module_path, sig fields
    return

PATH 2 — Unqualified target (no dot)
  Step 2a — same-module first (unchanged)
    sig = @same_module_registry[target]
    if sig
      → resolved: resolution_kind: "local", module_name: @classified_module
      return
  Step 2b — scan imported modules
    candidates = []
    imported_modules.each do |mod_name|
      next unless @cross_module_registry.key?(mod_name)
      next unless module_exports?(mod_name, target)   # respects selective imports
      candidates << { module_name: mod_name, sig: @cross_module_registry[mod_name][target] }
    end
    case candidates.size
    when 0 → OOF-REF1 ("no contract '#{target}' in this module or any imported module")
    when 1 → resolved: resolution_kind: "imported", module_name: candidates[0][:module_name]
    else   → OOF-REF2 (ambiguous: same contract name in modules #{candidates.map { _1[:module_name] }.join(", ")} — qualify: uses A.#{target} or uses B.#{target})
    end
```

**Key invariant: local shadows imported.**
Same-module lookup (Step 2a) runs before imported-module scan (Step 2b). If `Validator`
exists in the current module AND in an imported module, the same-module version wins silently.
No diagnostic for local-vs-import shadowing (expected behavior, user-controlled).

**Selective import enforcement.**
`module_exports?(mod_name, target)` checks whether target is visible given the import clause:
- `import Query` (wildcard): all contracts in `Query` are visible.
- `import Query.{ Validator }` (selective): only `Validator` is visible from `Query`.

The import clause shape is available from `classified_program["imports"]`:
`[{ "module_path" => "Query", "names" => nil }]` (wildcard) or
`[{ "module_path" => "Query", "names" => ["Validator"] }]` (selective).

---

## Q4 — Diagnostics

### Full diagnostic table

| Code | Trigger | Message template |
|------|---------|-----------------|
| OOF-REF1 | Unknown same-module contract | `"contract '#{c}' uses unknown contract '#{t}' — no contract '#{t}' in this module or any imported module"` |
| OOF-REF1 | Unknown module in qualified ref | `"contract '#{c}' uses '#{mod}.#{t}' — module '#{mod}' is not imported in this compilation unit"` |
| OOF-REF1 | Unknown contract in known module | `"contract '#{c}' uses '#{mod}.#{t}' — module '#{mod}' does not export contract '#{t}'"` |
| OOF-REF2 | Ambiguous unqualified import | `"contract '#{c}' uses '#{t}' — ambiguous: exported by modules #{mods.join(', ')} — qualify: uses #{mods[0]}.#{t} or uses #{mods[1]}.#{t}"` |
| OOF-REF4 | Self-reference | `"contract '#{c}' uses itself — self-reference is not allowed"` (unchanged from P3) |

### OOF-REF2 narrowing

In P3, OOF-REF2 covered ALL dotted targets (safe conservative deferred). In P5, OOF-REF2
fires ONLY for the ambiguous unqualified import case. Qualified targets that fail instead
produce OOF-REF1 (unknown module or unknown contract). This is a narrowing, not a change —
the P3 description already said "dotted ref with no cross-module resolver" was provisional.

No new diagnostic codes introduced. OOF-REF3 and OOF-REF5 remain reserved.

---

## Q5 — SemanticIR Shape Changes

**File: `semanticir_emitter.rb`**

Add `resolution_kind` to the `contract_refs` per-contract entry. Current shape (P3):

```json
{
  "contract_name": "Validator",
  "resolution_status": "resolved",
  "module_name": "Lab.Query",
  "modifier": "pure",
  "input_count": 1,
  "input_names": ["value"],
  "output_names": ["result"]
}
```

P5 addition — add `resolution_kind` immediately after `resolution_status`:

```json
{
  "contract_name": "Validator",
  "resolution_status": "resolved",
  "resolution_kind": "qualified",
  "module_name": "Lab.Query",
  "modifier": "pure",
  "input_count": 1,
  "input_names": ["value"],
  "output_names": ["result"]
}
```

`resolution_kind` values: `"local"` | `"qualified"` | `"imported"` | `"unresolved"`

For same-module refs (P3 regressions): `resolution_kind: "local"`, `module_name` =
`@classified_module` (unchanged — was already set to the declaring module in P3).

For unresolved refs: `resolution_kind: "unresolved"`, `module_name` absent (same as P3
existing unresolved shape).

**Emission point:** `semanticir_emitter.rb:860` — the hash built from `contract_ref_declarations`.
The `resolution_kind` field comes from the typechecker's resolved ref, which the P5 typechecker
will now include: `{ "resolution_kind" => "qualified", ... }`.

**Artifact hash impact:** `contract_refs` already enters the `contract_ref` content hash
(P3 established this). Adding `resolution_kind` to the emitted shape means it enters the
content hash automatically — no extra wiring needed.

---

## Q6 — Manifest Shape Changes

**File: `assembler.rb`**

`dependency_edges` currently emits (P3):

```json
{
  "from": "Processor",
  "to": "Validator",
  "kind": "typed_contract_ref",
  "execution_dependency": false,
  "resolution": "resolved"
}
```

P5 additions for cross-module edges:

```json
{
  "from": "Processor",
  "to": "Validator",
  "from_module": "Lab.App.Processor",
  "to_module": "Lab.Query",
  "kind": "typed_contract_ref",
  "execution_dependency": false,
  "resolution": "resolved",
  "resolution_kind": "qualified"
}
```

**Fields added:**
- `from_module` — module name of the declaring contract (same as `@classified_module` at
  emit time); populated for ALL edges (same-module: both fields are the same module name)
- `to_module` — module name of the referenced contract; comes from `contract_refs[].module_name`
  in the SIR
- `resolution_kind` — copied directly from SIR `contract_refs[].resolution_kind`

**Backward compatibility:** `from_module` and `to_module` are new fields — existing consumers
that don't read them are unaffected. `from` / `to` / `kind` / `execution_dependency` /
`resolution` are unchanged.

**Emission point:** `assembler.rb:502-514` (`dependency_edges` method). Each edge is built
from a `contract_ref` SIR entry. The `module_name` field in the SIR entry becomes `to_module`.
`from_module` is the assembler's current module context (`@manifest_module` or equivalent).

---

## Q7 — Import / Entrypoint Coexistence

**P3 regressions that must stay green in P5:**

| Suite | Checks | Key surface |
|-------|--------|-------------|
| PROP-ENTRYPOINT-P3 | 53/53 | `entrypoint ContractName` in single-file; OOF-EP1/EP2/EP5 |
| PROP-IMPORT-RESOLUTION-P5 | 99/99 | `import Mod` multifile; OOF-IMP2/IMP3; `source_units` evidence |
| LAB-TYPED-CONTRACT-REF-P1 | 58/58 | Proof-local typed ref model |

**Coexistence plan:**

1. Single-file path (`compile` with `source_path:`) — no `cross_module_registry` passed,
   defaults to `{}`. All P3 same-module resolution runs unchanged. OOF-REF2 for dotted targets
   is preserved: with no cross-module registry, `@cross_module_registry[module_path]` is `nil`
   → OOF-REF1 diagnostic fires. This is correct: a single-file compile cannot resolve
   cross-module refs.

2. Multi-file path (`compile_sources`) — `cross_module_registry` is built and passed.
   Cross-module resolution runs. Single-file fixtures still compile correctly because
   they contain no `uses Mod.Contract` declarations.

3. `MultifileResolver#validate_imports` (existing, P5): already checks that imported modules
   exist in the compilation universe (OOF-IMP2) and that selective names exist (OOF-IMP3).
   This guard runs BEFORE typechecking. If a module is not in the compilation universe,
   `validate_imports` rejects it, so the typechecker never sees an import for an unknown module.
   P5's `typecheck_uses_contract` OOF-REF1 "module not imported" is thus a redundant safety
   net, not the primary guard — but it must still fire to cover the single-file path.

4. `entrypoint` metadata: carried separately in `classified_program["entrypoint"]`. It has
   no interaction with `uses` resolution. The entrypoint contract must exist in the same
   module's `contract_names` — checked by existing OOF-EP1/EP2 rules, which are unaffected.

---

## Q8 — Forms Impact

LAB-FORM-VOCABULARY-P1 (61/61 PASS) confirmed: once OOF-REF2 is fixed, the vocabulary
model's TH-2 conditional proof becomes unconditional. The forms layer itself needs no P5
changes — it remains entirely lab-only.

**What P5 unblocks for future lab work:**

- The `ProofLocalContractRef.cross_module = true` flag in the vocabulary proof can be retired
  in a subsequent lab proof refresh — cross-module refs will be real canon refs.
- LAB-FORM-VOCABULARY-P1's G-04 (Section G, OOF-REF2 gap explicit) transitions from
  "conditional" to "satisfied" after P5.

**What stays closed (unchanged from P3):**

- `form_registry` / `form_resolver` (Rust lab) — remain lab-only divergence
- No public form syntax
- No form vocabulary implementation in canon
- No `call_contract` behavior changes

---

## Q9 — Cycle / Self-Reference

### Same-contract self-reference (OOF-REF4)

Unchanged from P3: `uses Validator` inside `contract Validator { ... }` → OOF-REF4.
Detected at typechecker time, no graph traversal needed.

### Cross-module cycle detection decision

A `uses` cycle across modules (`A.X uses B.Y` and `B.Y uses A.X`) is detectable at
compile time but requires a graph traversal over the resolved dependency edges.

**P5 decision: detect and reject cross-module uses-cycles at manifest assembly time.**

Rationale: `uses` is metadata-only. A cycle in metadata-only refs is not dangerous at runtime,
but it signals a design error and can confuse future tooling (DAG traversal). Early detection
is cheap (topological sort over `dependency_edges`).

**Diagnostic:** OOF-REF4 extended — its description already says "cycle"; the existing code
reserves it for this purpose. The error message for cross-module cycles:

```
OOF-REF4: typed-ref cycle detected involving contracts: A (in Module.X) → B (in Module.Y) → A (in Module.X)
```

**Cycle detection insertion point:** `assembler.rb`, in the `compile` path after
`dependency_edges` is fully built. Topological sort on the directed graph; if a cycle is
found, push an OOF-REF4 diagnostic into the manifest diagnostics and mark the build failed.

**Scope:** cross-module cycles only at P5. Within-module cycles already cannot occur because
P3 already rejects `uses X` if X doesn't exist in the same-module registry before the
referring contract is processed. True within-module cycles (A and B in same module, A uses B
and B uses A) require two separate `contract_refs` that refer to each other — this can only
happen if both contracts have been classified, which is the case. P5 cycle detection covers
the full `dependency_edges` graph, so within-module cycles are caught as a side-effect.

---

## Q10 — Proof Matrix for P5

Target: ≥70 checks. Sections below with check counts.

### Section A — Same-Module Regression (P3 parity) — 10 checks

| ID | Check |
|----|-------|
| A-01 | P3 basic fixture compiles; `contract_refs` unchanged; `resolution_kind: "local"` |
| A-02 | P3 OOF-REF1 still fires for unknown same-module contract |
| A-03 | P3 OOF-REF4 still fires for self-reference |
| A-04 | `dependency_edges` gains `from_module`/`to_module`/`resolution_kind` for same-module edge |
| A-05 | `from_module == to_module` for same-module edge |
| A-06 | PROP-ENTRYPOINT-P3 regression: 53/53 PASS |
| A-07 | PROP-IMPORT-RESOLUTION-P5 regression: 99/99 PASS |
| A-08 | LAB-TYPED-CONTRACT-REF-P1 regression: 58/58 PASS |
| A-09 | Single-file compile with no `uses` still emits empty `contract_refs` and `dependency_edges` |
| A-10 | Artifact hash changes when `resolution_kind` field added (non-regression: expected) |

### Section B — Qualified Cross-Module Resolution — 8 checks

| ID | Check |
|----|-------|
| B-01 | `uses Query.Validator` resolves; `resolution_kind: "qualified"`; `module_name: "Lab.Query"` |
| B-02 | `contract_refs` entry has correct `modifier`, `input_count`, `input_names`, `output_names` from target |
| B-03 | `dependency_edges` has `from_module`, `to_module: "Lab.Query"`, `resolution_kind: "qualified"` |
| B-04 | `uses Query.Validator` with wrong module (`uses Unknown.Validator`) → OOF-REF1 (unknown module) |
| B-05 | `uses Query.Validator` where `Validator` not in `Query` → OOF-REF1 (unknown contract in known module) |
| B-06 | Qualified ref to non-imported module (module in universe but not imported) → OOF-REF1 |
| B-07 | Two contracts in same module, each with qualified refs to different modules — both resolve |
| B-08 | Qualified ref preserves `execution_dependency: false` |

### Section C — Imported Unqualified Resolution — 8 checks

| ID | Check |
|----|-------|
| C-01 | `import Query` + `uses Validator` → resolves; `resolution_kind: "imported"` |
| C-02 | `contract_refs` has `module_name: "Lab.Query"`, correct signature fields |
| C-03 | `dependency_edges` has `to_module: "Lab.Query"`, `resolution_kind: "imported"` |
| C-04 | Wildcard `import Query` makes all contracts visible |
| C-05 | Selective `import Query.{ Validator }` — `uses Validator` resolves |
| C-06 | Selective `import Query.{ Validator }` — `uses Processor` (not named) → OOF-REF1 |
| C-07 | Imported unqualified does not shadow same-module contract (local wins — no diagnostic) |
| C-08 | `execution_dependency: false` preserved for imported ref |

### Section D — Ambiguity (OOF-REF2) — 5 checks

| ID | Check |
|----|-------|
| D-01 | `import Alpha` + `import Beta` + `uses Filter` (both export `Filter`) → OOF-REF2 |
| D-02 | OOF-REF2 message names both modules |
| D-03 | Suggest qualification in OOF-REF2 message |
| D-04 | Using qualified form `uses Alpha.Filter` resolves when unqualified would be ambiguous |
| D-05 | Three imports all exporting same name → OOF-REF2 names all three |

### Section E — Local Shadows Imported — 4 checks

| ID | Check |
|----|-------|
| E-01 | Same contract name in current module and imported module → local wins; `resolution_kind: "local"` |
| E-02 | No diagnostic for local-vs-import shadowing |
| E-03 | Shadowed contract name in two imported modules + local copy → local wins (not OOF-REF2) |
| E-04 | Removing local contract exposes imported one via OOF-REF2 when two imports also have it |

### Section F — Cross-Module Cycle Detection — 5 checks

| ID | Check |
|----|-------|
| F-01 | A uses B, B uses A (cross-module) → OOF-REF4; build fails |
| F-02 | OOF-REF4 message names both contracts and their modules |
| F-03 | A uses B uses C uses A (3-cycle) → OOF-REF4; full cycle listed |
| F-04 | A uses B uses C (no cycle, chain) → no diagnostic |
| F-05 | Same-contract self-ref still fires OOF-REF4 (unchanged; PATH 0 guard) |

### Section G — SIR Shape: resolution_kind Field — 5 checks

| ID | Check |
|----|-------|
| G-01 | `resolution_kind: "local"` for same-module refs |
| G-02 | `resolution_kind: "qualified"` for dotted cross-module refs |
| G-03 | `resolution_kind: "imported"` for unqualified imported refs |
| G-04 | `resolution_kind: "unresolved"` for failed resolution (OOF-REF1 case) |
| G-05 | `resolution_kind` absent from unresolved entries that emit no sig fields (consistent with P3 unresolved shape) |

### Section H — Manifest dependency_edges Fields — 6 checks

| ID | Check |
|----|-------|
| H-01 | `from_module` present for all edges |
| H-02 | `to_module` present for all edges |
| H-03 | `from_module == to_module` for same-module edge |
| H-04 | `from_module != to_module` for cross-module edge |
| H-05 | `resolution_kind` matches SIR entry |
| H-06 | `execution_dependency: false` unchanged for all edge types |

### Section I — Determinism / Hash — 5 checks

| ID | Check |
|----|-------|
| I-01 | Artifact hash is stable across identical compilations (deterministic) |
| I-02 | File order permutation in `compile_sources` does not change artifact hash |
| I-03 | Adding `resolution_kind` to SIR changes artifact hash vs P3 baseline (expected) |
| I-04 | `source_units_evidence` unchanged (no regression on multifile resolver output) |
| I-05 | Cross-module registry is built deterministically (sorted by module name) |

### Section J — Authority Closed — 5 checks

| ID | Check |
|----|-------|
| J-01 | No `execute` or `runtime_dispatch` on any `uses` resolution path |
| J-02 | No capability grant from cross-module `uses` |
| J-03 | No `call_contract` behavior changes |
| J-04 | No VM bytecode nodes for `uses` |
| J-05 | No parser changes (dotted names already parsed) |

### Section K — Forms Impact / Lab Receipt — 4 checks

| ID | Check |
|----|-------|
| K-01 | A cross-module `uses Mod.Contract` resolves; the resolved ref is valid as a form anchor (C-1 satisfied) |
| K-02 | `execution_dependency: false` holds; no form invocation authority added |
| K-03 | `form_registry` / `form_resolver` Rust lab files unchanged |
| K-04 | No public form syntax or `speaks` keyword introduced |

### Total: 10 + 8 + 8 + 5 + 4 + 5 + 5 + 6 + 5 + 5 + 4 = **65 checks minimum across unique IDs**

Plus the embedded P3 regression runs (A-06: 53, A-07: 99, A-08: 58) bring the total evidence
count well above 70. If the proof runner counts embedded regression suites, total ≥ 225.
If only top-level P5 checks are counted: **65**, which is just below the gate.

**To reach ≥70 top-level P5 checks, add Section L — Multi-Contract Multi-Module Scenarios (6 checks):**

### Section L — Multi-Contract Multi-Module — 6 checks

| ID | Check |
|----|-------|
| L-01 | Module A imports B and C; A.X uses B.Foo; A.Y uses C.Bar — both resolve independently |
| L-02 | Mixed: A.X uses local Validator (local), A.Y uses B.Processor (imported) — both correct kinds |
| L-03 | Module A imports B; A uses B.Foo; B has no imports — B still compiled correctly solo |
| L-04 | Three-module chain A→B→C where A uses B.X and B uses C.Y — A compilation resolves B.X |
| L-05 | `source_units_evidence` lists all three modules with their contract arrays |
| L-06 | `dependency_edges` for A contains two edges: one to B.X, one indirect through B to C.Y (B's edge) |

**Grand total: 71 top-level P5 checks + 3 embedded regression suites** ✓

---

## Authorized Files for P5

| File | Change authorized |
|------|-----------------|
| `igniter-lang/lib/igniter_lang/multifile_resolver.rb` | Add `build_cross_module_registry(units)` private method; expose as `"cross_module_registry"` in result |
| `igniter-lang/lib/igniter_lang/typechecker.rb` | Add `cross_module_registry:` kwarg to constructor; add `@import_scope` helper; extend `typecheck_uses_contract` with 3-path algorithm |
| `igniter-lang/lib/igniter_lang/semanticir_emitter.rb` | Add `resolution_kind` field to `contract_refs` emission |
| `igniter-lang/lib/igniter_lang/assembler.rb` | Add `from_module`, `to_module`, `resolution_kind` to `dependency_edges`; add cycle detection after graph build |
| `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb` | Pass `cross_module_registry` to TypeChecker in multifile path |

### Files closed (no changes)

| File | Reason |
|------|--------|
| Parser | Already parses dotted names; no new surface |
| SemanticIR shape (beyond `resolution_kind`) | All other fields unchanged |
| VM / runtime | `uses` is metadata-only, no VM node |
| `call_contract` | Unchanged |
| Form registry / form resolver | Lab-only, no canon |
| `form_registry.rs` / `form_resolver.rs` | Rust lab, closed |
| Package / visibility | No authority change |
| Capability / profile | Closed |
| Public API / CLI | Not yet |

---

## Proof Runner

**Path:** `igniter-lang/experiments/typed_contract_ref_proof/verify_typed_contract_ref_p5.rb`

Sections: A (regression), B (qualified), C (imported), D (ambiguity), E (local shadows),
F (cycle), G (SIR shape), H (manifest), I (determinism), J (authority), K (forms receipt), L (multi-module).

Fixtures needed (new):

| Fixture | Module | `uses` declarations |
|---------|--------|---------------------|
| `cross_module_qualified.ig` | `Lab.App` | `uses Lab.Query.Validator` |
| `cross_module_query.ig` | `Lab.Query` | exports `Validator`, `Processor` |
| `cross_module_imported.ig` | `Lab.App` | `import Lab.Query` + `uses Validator` |
| `cross_module_selective.ig` | `Lab.App` | `import Lab.Query.{ Validator }` + `uses Validator` |
| `cross_module_ambig_alpha.ig` | `Lab.Alpha` | exports `Filter` |
| `cross_module_ambig_beta.ig` | `Lab.Beta` | exports `Filter` |
| `cross_module_ambig_consumer.ig` | `Lab.Consumer` | `import Lab.Alpha` + `import Lab.Beta` + `uses Filter` |
| `cross_module_cycle_a.ig` | `Lab.CycleA` | `uses Lab.CycleB.X` |
| `cross_module_cycle_b.ig` | `Lab.CycleB` | `uses Lab.CycleA.Y` |

Plus existing P3 fixtures for regression sections.

---

## Open Gaps Not Addressed by P5

1. **`import Mod.{ Contract }` as the declaring statement for `uses Mod.Contract` resolution**:
   PROP-IMPORT-RESOLUTION-P5's selective import support. P5 builds on this; if the
   classifier does not fully model selective imports, P5 inherits that gap.

2. **Diamond imports**: Module A imports B and C; B and C both import D; D exports Foo.
   `uses Foo` in A — one candidate (D.Foo), resolved via two import paths. P5 treats this as
   unambiguous if there is only one contract named Foo across all directly-imported modules.
   Transitive imports are NOT scanned — only direct imports of A. This is the conservative
   decision; transitive import resolution is a separate proposal.

3. **`from_module` in single-file path**: In single-file compilation,
   `@classified_module` is the declaring module; `from_module` = `to_module` for all edges.
   This is correct. No gap.

4. **Form vocabulary `speaks` syntax**: Not introduced by P5. The vocabulary proof (LAB-FORM-VOCABULARY-P1)
   is satisfied by P5's OOF-REF2 fix, but `speaks` syntax requires a separate proposal.

---

## Summary

| Item | Decision |
|------|----------|
| Parser changes | None — dotted names already parsed |
| Resolution paths | 3: local, qualified, imported |
| OOF-REF2 narrowed to | Ambiguous unqualified import only |
| OOF-REF1 extended to cover | Unknown module in qualified ref; unknown contract in known module; no import match |
| OOF-REF4 extended to cover | Cross-module uses-cycles (detected at manifest time) |
| New SIR field | `resolution_kind: "local" | "qualified" | "imported" | "unresolved"` |
| New manifest fields | `from_module`, `to_module`, `resolution_kind` in each `dependency_edge` |
| Cross-module registry source | `MultifileResolver` classifies each unit; builds registry before merge |
| TypeChecker input | New optional `cross_module_registry:` kwarg; defaults `{}` |
| Single-file backward compat | Preserved — default empty registry; same-module path unchanged |
| Proof path | `experiments/typed_contract_ref_proof/verify_typed_contract_ref_p5.rb` |
| Proof target | ≥71 top-level checks + 3 embedded regression suites |
| Authorized files | 5 (multifile_resolver, typechecker, semanticir_emitter, assembler, compiler_orchestrator) |
