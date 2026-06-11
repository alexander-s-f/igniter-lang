# LANG-TYPED-CONTRACT-REF-P3: Ruby Canon Implementation Proof

**Track:** typed-contract-reference-ruby-implementation-v0  
**Route:** IMPLEMENTATION / BOUNDED RUBY CANON  
**Authority:** bounded Ruby `igniter-lang` canon pipeline only  
**Date:** 2026-06-11  
**Status:** CLOSED / PROVED — 67/67 PASS  
**Predecessors:** LANG-TYPED-CONTRACT-REF-PROP-P1 (proposal), LANG-TYPED-CONTRACT-REF-PROP-P2 (planning), LAB-TYPED-CONTRACT-REF-P1 (58/58 PASS)

---

## 1. Authority Boundary

P3 implements the accepted `uses ContractName` proposal in the Ruby canon pipeline.
It is implementation authority only for the bounded internal Ruby compiler pipeline.

Closed in P3:

- no VM / runtime changes
- no cross-module typed refs (OOF-REF2 fires; deferred to import module table gate)
- no `call_contract` behavior changes — unchanged
- no forms vocabulary or form lowering
- no macro or composition system
- no capability or profile authority
- no public or stable API widening
- no Rust lab pipeline changes (parity deferred)
- no fragment classification change for any declaring contract

---

## 2. Implemented Surface

P3 adds `uses ContractName` as a contract body declaration through all five Ruby pipeline stages:

**Parser** (`lib/igniter_lang/parser.rb` — `parse_uses_decl`):
- 1-token lookahead: `uses assumptions NAME` → existing path; `uses ContractName` → new `uses_contract` branch
- Dotted target (`uses Mod.Contract`) parsed into `"Mod.Contract"` string; typechecker emits OOF-REF2
- Parse error OOF-P0 for blank `uses` (no token after keyword) — unchanged behavior

**Classifier** (`lib/igniter_lang/classifier.rb` — `classify_contract`):
- `when "uses_contract"`: `"metadata"` fragment; `target` field preserved; collected in `contract_ref_declarations` array
- `contract_fragment_for`: `behavior_decls` filter excludes "metadata" declarations — fragment classification of declaring contract is unaffected
- `contract_ref_declarations` propagated in contract result hash

**TypeChecker** (`lib/igniter_lang/typechecker.rb`):
- `build_same_module_registry`: builds `{ contract_name → { modifier, input_count, input_names, output_names } }` from classified program contracts
- `typecheck_uses_contract`: resolves same-module targets; emits OOF-REF1 (unknown), OOF-REF2 (dotted/cross-module), OOF-REF4 (self-reference)
- Does NOT enter `symbol_types` — not a local typed symbol
- `contract_ref_declarations` propagated to typed contract result

**SemanticIR Emitter** (`lib/igniter_lang/semanticir_emitter.rb`):
- `typed_contract_ir`: `contract_refs` per-contract field emitted from `contract_ref_declarations`
- `typed_nodes`: `when "uses_contract" then nil` — no VM node emitted
- `contract_refs` enters `contract_ref` content hash (structural identity)

**Assembler** (`lib/igniter_lang/assembler.rb`):
- `dependency_edges` helper: flat array of `{ from, to, kind: "typed_contract_ref", execution_dependency: false, resolution }` entries
- Added to manifest when non-empty; omitted when no refs present
- Enters `artifact_hash` automatically via manifest material

---

## 3. Diagnostic Codes

| Code | Trigger | Severity |
|------|---------|---------|
| OOF-REF1 | Unqualified target not found in same-module registry | blocking type_error |
| OOF-REF2 | Dotted/qualified target (cross-module, deferred in v0) | blocking type_error |
| OOF-REF4 | `target == current_contract_name` (self-reference) | blocking type_error |

All three produce `resolution_status: "unresolved"` in the typed decl.

---

## 4. Proof Result

**Proof runner:** `experiments/typed_contract_ref_proof/verify_typed_contract_ref_p3.rb`

```
LANG-TYPED-CONTRACT-REF-PROP-P3 PASS (67/67)
```

| Section | Checks | All PASS |
|---------|--------|---------|
| A — PARSE | 10 | ✅ |
| B — TYPECHECK POSITIVE | 12 | ✅ |
| C — TYPECHECK NEGATIVE | 10 | ✅ |
| D — SEMANTICIR | 11 | ✅ |
| E — MANIFEST | 8 | ✅ |
| F — AUTHORITY | 8 | ✅ |
| G — REGRESSION | 8 | ✅ |
| **Total** | **67** | ✅ |

---

## 5. Regression Results

| Proof | Result |
|-------|--------|
| PROP-ENTRYPOINT-P3 | 53/53 PASS |
| PROP-IMPORT-RESOLUTION-P5 | 99/99 PASS |
| LAB-TYPED-CONTRACT-REF-P1 | 58/58 PASS (unchanged; no lab files modified) |

---

## 6. Key Proof Findings

| Finding | Proven |
|---------|--------|
| `uses ContractName` parses as `{ kind: "uses_contract", target: name }` | A-02/03 |
| `uses assumptions NAME` behavior is unchanged | A-04/05 |
| Dotted `uses Mod.Contract` parses without crash, fires OOF-REF2 | A-07/08, C-06/07 |
| Blank `uses` fires OOF-P0 | A-09 |
| Same-module ref resolves; resolved_ref carries modifier/input_names | B-02/03/04 |
| Effect target resolves; modifier "effect" preserved in resolved_ref | B-05/06 |
| `uses_contract` does NOT create a symbol binding | B-07 |
| Fragment class of declaring contract is unchanged | B-12, F-01 |
| OOF-REF1 fires and references the unknown name | C-01/02 |
| OOF-REF4 fires for self-reference | C-04/05 |
| `contract_refs` present in SemanticIR; resolved entry carries modifier/input_count | D-01..05 |
| `uses_contract` NOT in `typed_nodes` (no VM node) | D-06 |
| `contract_refs` enters `contract_ref` content hash (structural identity) | D-11 |
| `dependency_edges` present in manifest with `execution_dependency: false` | E-02..05 |
| `artifact_hash` differs when refs present vs absent | E-07 |
| No execute/invoke/dispatch on contract_ref | F-03 |
| No profile_binding or profile_authority on contract_ref | F-04 |
| `call_contract` nodes unchanged alongside `uses_contract` | F-05 |
| `uses_assumptions` coexists with `uses_contract` without errors | F-06 |

---

## 7. Fixtures

| Fixture | Purpose |
|---------|---------|
| `basic_uses.ig` | Core case: Validator + Processor using Validator |
| `effect_target.ig` | Pure contract using effect-modifier target |
| `multi_uses.ig` | Multiple uses in one contract |
| `with_uses_assumptions.ig` | Coexistence: both uses_assumptions + uses_contract |
| `unknown_target.ig` | OOF-REF1 trigger |
| `self_reference.ig` | OOF-REF4 trigger |
| `dotted_target.ig` | OOF-REF2 trigger (cross-module deferred) |
| `no_uses.ig` | Baseline without any uses_contract |
| `with_call_contract.ig` | call_contract coexistence |
| `blank_uses.ig` | OOF-P0 parse error trigger |
| `chain_uses.ig` | Chained A→B→C dependency edges |

---

## 8. Known Limits

Still not implemented (deliberately deferred):

- Cross-module `uses Mod.Contract` resolution (requires import module table gate)
- Cycle detection beyond direct self-reference (requires DAG traversal)
- Visibility/export gating on typed refs (PROP-MODULE-VISIBILITY-P1)
- OOF-REF3 (effect/boundary) and OOF-REF5 (signature mismatch) — reserved
- Rust lab pipeline parity (separate lab parity card)
- Forms lowering over contract_refs (LAB-CONTRACT-FORMS-P2 substrate ready)

---

## 9. Decision

**CLOSED / PROVED.**

P3 closes the bounded Ruby canon implementation of `uses ContractName`. The same-module
typed reference declaration is source-visible, statically inspectable, and preserved
through all five pipeline stages. No closed surface was opened. All regressions remain
green.

---

## 10. Next Route

```
LAB-CONTRACT-FORMS-P2             — PROP-Forms lineage reconciliation (TH-1 substrate
                                    now implemented in canon pipeline)

LAB-FORM-CONSTRUCTOR-P1           — Gap-I (Covenant P27/P28, independent clock)

LANG-TYPED-CONTRACT-REF-PROP-P4   — cross-module uses resolution (after import module
                                    table gate from PROP-IMPORT-RESOLUTION-P3/P5)
```
