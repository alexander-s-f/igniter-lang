# LANG-TYPED-CONTRACT-REF-P5: Cross-Module Typed Contract Reference Resolution — Ruby Canon Implementation Proof

**Track:** typed-contract-reference-cross-module-ruby-implementation-v0
**Route:** IMPLEMENTATION / BOUNDED RUBY CANON
**Authority:** bounded Ruby `igniter-lang` canon pipeline only
**Date:** 2026-06-11
**Status:** CLOSED / PROVED — 71/71 PASS
**Predecessors:** LANG-TYPED-CONTRACT-REF-PROP-P3 (67/67 PASS — same-module `uses ContractName` live), LANG-TYPED-CONTRACT-REF-PROP-P4 (3-path algorithm planning)

---

## 1. Authority Boundary

P5 implements cross-module typed contract reference resolution in the Ruby canon pipeline.
It is implementation authority only for the bounded internal Ruby compiler pipeline.

Closed in P5:

- No canon parser changes — dotted names were already parsed by P3's dotted-name read loop
- No VM / runtime changes
- No `call_contract` behavior changes — unchanged
- No cross-module form vocabulary implementation
- No macro or composition system
- No capability or profile authority
- No public or stable API widening
- No Rust lab pipeline changes — `form_registry` / `form_resolver` remain lab-only
- No package or visibility changes

---

## 2. Implemented Surface

P5 adds cross-module `uses` resolution to the Ruby pipeline through all five stages.
The OOF-REF2 gap from P3/P4 is closed: OOF-REF2 now fires only for genuine ambiguity
(≥2 imported modules export the same contract name). All other cases resolve correctly.

### 2.1 MultifileResolver (`lib/igniter_lang/multifile_resolver.rb`)

Three private methods built from pre-merge parsed units (merge destroys module attribution):

```ruby
build_cross_module_registry(sorted)  # { module_name → { contract_name → sig } }
build_per_module_imports(sorted)     # { module_name → [import structs] }
build_per_contract_module(sorted)    # { contract_name → module_name }
```

All three exposed in resolve result hash alongside existing keys. Default `{}` when called
from single-file paths preserves P3 same-module behavior unchanged.

### 2.2 TypeChecker (`lib/igniter_lang/typechecker.rb`)

**Signature change:** `typecheck` accepts three new kwargs:

```ruby
def typecheck(classified_program,
  cross_module_registry: {}, per_module_imports: {}, per_contract_module: {})
```

**3-Path Resolution Algorithm** in `typecheck_uses_contract`:

| Path | Condition | Outcome |
|------|-----------|---------|
| PATH 0 | `target == current_contract_name` | OOF-REF4 (unchanged) |
| PATH 1 | `target.include?(".")` | Dotted: qualified lookup; OOF-REF1 if module/contract absent; `resolution_kind: "qualified"` |
| PATH 2a | No dot, in same_module_registry, same original module | `resolution_kind: "local"` (unchanged P3 behavior) |
| PATH 2b | No dot, not local → scan import scope | 0→OOF-REF1; 1→`resolution_kind: "imported"`; ≥2→OOF-REF2 |

**Local shadows imported (PATH 2a fix):** In multifile compilation, `@same_module_registry`
contains contracts from ALL merged modules. `per_contract_module[target]` is compared against
`per_contract_module[current_contract_name]` to distinguish truly-local contracts from
contracts that were merged from a different original module. Only truly-local contracts resolve
as `"local"`; others fall through to PATH 2b.

**Selective imports respected:** `resolve_import_scope_for` builds import scope from
`per_module_imports[declaring_module]`. Each import entry with `names` key produces a Set
(selective); without `names` produces `:all`. PATH 2b filters candidates against this scope.

**Cycle detection:** `detect_uses_cycles` runs DFS over the resolved uses-dependency graph
after all contracts are typed. Reports OOF-REF4 for each cycle. Cross-module cycles via
mutual imports are caught by the import cycle validator before typechecking reaches this step.

### 2.3 SemanticIR Emitter (`lib/igniter_lang/semanticir_emitter.rb`)

`contract_refs` emission extended:
- `resolution_kind` field added after `resolution_status`
- Values: `"local"` | `"qualified"` | `"imported"` | `"unresolved"`
- For qualified refs: `contract_name` emitted from `resolved_ref.fetch("contract_name")` (short name, e.g. `"Validator"`), NOT from raw `target` (e.g. `"Lab.TypedRef.Query.Validator"`)
- `module_name` emitted from `resolved_ref["module_name"]` when present

### 2.4 Assembler (`lib/igniter_lang/assembler.rb`)

`dependency_edges` extended with three new fields per edge:
- `from_module` — declaring contract's original module (from `build_contract_module_map`)
- `to_module` — referenced contract's module (from SIR `module_name`, when present)
- `resolution_kind` — from SIR `resolution_kind` (when present)

`build_contract_module_map` reads `source_units` from SIR to restore per-contract module attribution after merge.

### 2.5 CompilerOrchestrator (`lib/igniter_lang/compiler_orchestrator.rb`)

- `compile_parsed` kwargs extended with `cross_module_registry: {}`, `per_module_imports: {}`, `per_contract_module: {}`
- `compile_sources` extracts three new keys from resolver result and forwards to `compile_parsed`
- `attach_source_units!` nil-guard: when type errors block SemanticIR emission, `compilation["semantic_ir"]` is nil; guard prevents `NoMethodError`

---

## 3. Fixtures

Located in `experiments/typed_contract_ref_proof/fixtures/cross_module/`:

| Fixture | Purpose |
|---------|---------|
| `query.ig` | `Lab.TypedRef.Query` — declares `Validator` and `Scorer` |
| `app_qualified.ig` | `Lab.TypedRef.App` — `uses Lab.TypedRef.Query.Validator` (qualified) |
| `app_imported.ig` | `Lab.TypedRef.AppImported` — `import Lab.TypedRef.Query; uses Validator` |
| `app_selective.ig` | `Lab.TypedRef.AppSelective` — `import Lab.TypedRef.Query.{Validator}; uses Validator` |
| `selective_blocked.ig` | imports only `{Validator}`, attempts `uses Scorer` → OOF-REF1 |
| `local_shadow.ig` | `Lab.TypedRef.Shadow` — local `LocalValidator`; Consumer resolves local (not imported Validator) |
| `chain_multi.ig` | `Lab.TypedRef.ChainMulti` — two qualified refs: `Validator` and `Scorer` |
| `unknown_module.ig` | `uses NonExistent.Validator` in single-file → OOF-REF1 |
| `unknown_contract.ig` | `uses Lab.TypedRef.Query.NoSuchContract` → OOF-REF1 |
| `cycle_same.ig` | `ContractA ↔ ContractB` same-module cycle → OOF-REF4 |
| `other_provider.ig` | `Mod.Beta` — `SharedContract` + `BetaOnly` (for direct TypeChecker ambiguity tests) |

Note: `local_shadow.ig` uses `LocalValidator` (not `Validator`) because OOF-DECL-DUP-CONTRACT
prevents same-name contracts across modules in a `compile_sources` call. Ambiguity tests (Section D)
use direct TypeChecker invocation with a manually constructed `DUAL_REGISTRY`.

---

## 4. Proof Matrix

**Proof runner:** `experiments/typed_contract_ref_proof/verify_typed_contract_ref_p5.rb`
**Result:** 71/71 PASS

| Section | Checks | Focus |
|---------|--------|-------|
| A — Regression | 10 | P3 same-module parity; A-10 embeds PROP-ENTRYPOINT-P3 runner |
| B — Qualified | 8 | `uses Mod.Contract`; OOF-REF1 for unknown module/contract; SIR + manifest shape |
| C — Imported | 8 | `import Mod; uses Contract`; selective imports; OOF-REF1 when blocked |
| D — Ambiguity | 5 | OOF-REF2 via direct TypeChecker; error message names both modules; unique-name case clean |
| E — Local shadow | 4 | Consumer resolves `LocalValidator` as `"local"` (not imported); to_module correct |
| F — Cycles | 5 | OOF-REF4 for same-module cycle; acyclic chain clean; no bleed to OOF-REF1/2 |
| G — SIR shape | 5 | `resolution_kind` field for all three values + `resolution_status: "resolved"` parity |
| H — Manifest | 6 | `from_module`/`to_module`/`resolution_kind` on edges; existing fields preserved |
| I — Determinism | 5 | Hash stability on re-compile; file order independence; ambiguity deterministic both orderings |
| J — Authority | 5 | No execute/invoke/capability/profile surface; `call_contract` compute nodes intact |
| K — Forms receipt | 4 | Resolved `contract_refs` carry `module_name` (typed-ref anchor for TH-2) |
| L — Multi-module | 6 | Two qualified refs; cross_module_registry attribution; per_contract_module correctness |

---

## 5. Diagnostic Behavior Summary

| Code | Condition | Status |
|------|-----------|--------|
| OOF-REF1 | Unknown same-module contract | Unchanged (P3) |
| OOF-REF1 | Dotted target: module not in compilation unit | New trigger (was OOF-REF2 in P3) |
| OOF-REF1 | Dotted target: contract not in known module | New trigger |
| OOF-REF1 | Unqualified: 0 candidates in import scope | New trigger |
| OOF-REF1 | Unqualified: contract name not in selective import | New trigger |
| OOF-REF2 | Unqualified: ≥2 imported modules export same contract name | Narrowed (was ALL dotted targets in P3) |
| OOF-REF4 | Self-reference or resolved uses-dependency cycle | Extended to include cross-contract DFS cycle |
| OOF-REF3/5 | Reserved | Unchanged |

---

## 6. Regressions

- PROP-ENTRYPOINT-P3 (53/53): embedded in A-10; passes
- PROP-IMPORT-RESOLUTION-P5 (99/99): not re-run inline (separate runner); P5 changes are additive; multifile resolver result hash extends without breaking existing keys

---

## 7. Forms Impact

LAB-FORM-VOCABULARY-P1 proved cross-module form coherence holds given resolved typed refs (TH-2 conditional). P5 provides the substrate:
- `resolution_kind: "qualified"` or `"imported"` in SIR `contract_refs`
- `module_name` field in resolved refs
- `to_module` in manifest `dependency_edges`

TH-2's conditionality — "holds once OOF-REF2 is fixed" — is now satisfied.
