# PROP-IMPORT-RESOLUTION-P2A: Diagnostic Namespace Decision

**Track:** import-resolution-diagnostic-namespace-cleanup-v0
**Route:** DIAGNOSTIC NAMESPACE DECISION / NO IMPLEMENTATION
**Authority:** proposal-local diagnostic decision
**Date:** 2026-06-11
**Status:** CLOSED - ACCEPT
**Predecessors:** PROP-IMPORT-RESOLUTION-P1; PROP-IMPORT-RESOLUTION-P2

---

## 1. Authority Boundary

This packet decides diagnostic naming for import/module resolution only.

It authorizes no implementation:

- no parser changes
- no compiler driver changes
- no classifier changes
- no typechecker changes
- no SemanticIR or assembler changes
- no VM changes
- no import-resolution P3 work
- no package registry
- no visibility/export system
- no stdlib-as-import promotion
- no public/stable API claim
- no broad OOF taxonomy rewrite

Existing lab proof output is evidence. Existing proposal and implementation
diagnostics remain their own authority surfaces unless a separate cleanup card
migrates them.

---

## 2. Collision Inventory

| Code | Observed meaning | Source/proposal/doc path | Implementation status | Proof/status | Active or historical | Migration risk |
|---|---|---|---|---|---|---|
| `OOF-M1` | `pure` contract body contains escape declaration | `igniter-lang/.agents/work/proposals/PROP-031-contract-modifiers-v0.md`; `igniter-lang/docs/spec/ch10-contract-modifiers.md`; `igniter-lang/docs/concepts/canonical-semantic-model.md` | Ruby classifier active; Rust classifier active | PROP-031 experiment-pass | Active | High: accepted proof fixtures and docs rely on the code |
| `OOF-M1` | observed contract attempts write; irreversible contract defines compensation | `igniter-lab/igniter-compiler/src/classifier.rs` | Rust classifier active | Lab/compiler implementation surface | Active | Medium/high: Rust lab compiler already emits this rule for modifier/authority errors |
| `OOF-M1` | privileged contract requires matching capability token in manifest | `igniter-lab/igniter-compiler/src/assembler.rs` | Rust assembler string active | Lab/compiler implementation surface | Active | Medium: message-level use should not be overloaded further |
| `OOF-M1` | circular import | `igniter-lang/docs/spec/ch2-source-surface.md`; PROP-IMPORT-RESOLUTION-P1/P2 planning; `igniter-lab/lab-docs/lang/lab-multifile-compilation-import-resolution-proof-v0.md` | Not implemented in canon/Rust lab import resolver | Proposal/lab candidate | Candidate/historical lab evidence | Low if renamed before P3; high if implemented as-is |
| `OOF-M2` | pure contract declares IO capability | `igniter-lang/.agents/work/proposals/PROP-035-effect-surface-io-capability-v0.md`; `igniter-lang/lib/igniter_lang/classifier.rb`; `igniter-lab/lab-docs/lang/lab-igniter-lang-io-capability-grammar-v0.md` | Ruby classifier active | PROP-035 experiment-pass | Active | High: active capability/effect grammar diagnostic |
| `OOF-M2` | effect/privileged/irreversible missing Effect Surface fields | `igniter-lang/docs/spec/ch10-contract-modifiers.md`; `igniter-lang/docs/spec/ch12-effect-surface.md` | Spec/proposal surface; broader fields deferred | Proposed/deferred within Effect Surface | Historical/proposed | Medium: still belongs to effect/modifier lineage |
| `OOF-M2` | unknown import path / missing selective import name | `igniter-lang/docs/spec/ch2-source-surface.md`; PROP-IMPORT-RESOLUTION-P1/P2 planning; `igniter-lab/lab-docs/lang/lab-multifile-compilation-import-resolution-proof-v0.md` | Not implemented in canon/Rust lab import resolver | Proposal/lab candidate | Candidate/historical lab evidence | Low if renamed before P3; high if implemented as-is |
| `OOF-M3` | irreversible without compensation or no_compensation | `igniter-lang/docs/spec/ch10-contract-modifiers.md`; `igniter-lang/docs/spec/ch12-effect-surface.md`; PROP-031/PROP-035 notes | Spec/proposal warning surface | Deferred/proposed | Historical/proposed | Medium |
| `OOF-M3` | duplicate module declaration | PROP-IMPORT-RESOLUTION-P1/P2 planning; `igniter-lab/lab-docs/lang/lab-multifile-compilation-import-resolution-proof-v0.md` | Not implemented in canon/Rust lab import resolver | Proposal/lab candidate | Candidate/historical lab evidence | Low if renamed before P3 |
| `OOF-M4` | effect binding references undeclared capability; idempotency/profile effect-surface rule in older spec wording | `igniter-lang/.agents/work/proposals/PROP-035-effect-surface-io-capability-v0.md`; `igniter-lang/lib/igniter_lang/classifier.rb`; `igniter-lang/docs/spec/ch12-effect-surface.md` | Ruby classifier active for undeclared capability | PROP-035 experiment-pass | Active/mixed historical | Medium/high |
| `OOF-M5` | capability declared but no effect binding; reversibility/profile effect-surface rule in older spec wording | `igniter-lang/.agents/work/proposals/PROP-035-effect-surface-io-capability-v0.md`; `igniter-lang/lib/igniter_lang/classifier.rb`; `igniter-lang/docs/spec/ch12-effect-surface.md` | Ruby classifier active for unbound capability warning | PROP-035 experiment-pass | Active/mixed historical | Medium/high |
| `OOF-M7` | contract modifier authority below profile declared authority | `igniter-lang/lib/igniter_lang/classifier.rb`; PROP-040/profile docs | Ruby classifier active | PROP-040 experiment-pass | Active | Medium |
| `OOF-M8` | unknown profile binding | `igniter-lang/lib/igniter_lang/classifier.rb`; PROP-040/profile docs | Ruby classifier active | PROP-040 experiment-pass | Active | Medium |
| `OOF-M9` | pure contract declares output evidence refs | `igniter-lang/lib/igniter_lang/classifier.rb`; PROP-034 notes | Ruby classifier active | PROP-034 experiment-pass | Active | Medium |

Conclusion: `OOF-M*` is already occupied by modifier/effect/profile/evidence
diagnostics. Import/module diagnostics must not claim `OOF-M1/M2/M3` in P3.

---

## 3. Namespace Options

### Option A: Keep `OOF-M1/M2/M3` for import/module diagnostics

Rejected.

This would require migrating active modifier/effect diagnostics away from
`OOF-M*`. That creates avoidable churn across PROP-031, PROP-035, PROP-040,
Ruby classifier output, Rust lab classifier output, docs, fixtures, and proof
expectations.

### Option B: Keep existing `OOF-M*`; assign imports/modules to `OOF-IMP*`

Accepted.

This preserves current active diagnostic behavior and gives import/module
resolution a unique, searchable namespace before any implementation begins.

### Option C: Split all namespaces now into `OOF-MOD*`, `OOF-EFF*`, `OOF-IMP*`

Rejected for this card, but retained as a possible future cleanup.

The end-state is attractive, but this card is not a broad diagnostic taxonomy
rewrite. Migrating active modifier/effect/profile codes should be separate,
evidence-backed governance work if it is ever needed.

### Option D: Allow overloaded codes with message disambiguation

Rejected.

Overloaded diagnostic codes weaken grepability, proof expectations, user
comprehension, and machine-readable compiler reports. They also conflict with
Igniter's honesty goal: diagnostics should name the failure surface directly,
not require message parsing to recover meaning.

---

## 4. Decision Criteria

| Criterion | Result |
|---|---|
| Diagnostic uniqueness | `OOF-IMP*` creates one owner for import/module diagnostics |
| Grep/searchability | Import diagnostics become directly searchable without matching modifier/effect proofs |
| Backwards compatibility | Existing active `OOF-M*` outputs remain untouched |
| Implementation complexity | P3 only needs new expected codes; no migration layer |
| Proof churn | Only import/multifile proof expectations change |
| User comprehension | `IMP` names the import/module boundary clearly |
| Future package/module visibility extension | `OOF-IMP*` can grow for import resolution while package and visibility get separate namespaces later if needed |
| Igniter honesty alignment | Avoids overloading one code with multiple causes |

---

## 5. Recommended Decision

Decision: **reserve `OOF-IMP*` for import/module diagnostics**.

Existing `OOF-M*` meanings remain untouched. `OOF-M*` should be treated as the
historical and active modifier/effect/profile/evidence diagnostic family for now,
not as the import/module family.

No aliasing is authorized for compiler output. A future doc cleanup may mention
that older lab/proposal text used `OOF-M1/M2/M3` as candidate names, but P3
must emit the final `OOF-IMP*` names.

---

## 6. Final Mapping

| Import/module condition | Final code | Notes |
|---|---|---|
| circular import | `OOF-IMP1` | Include deterministic `cycle_path` in diagnostic payload |
| unknown module import | `OOF-IMP2` | Module path does not exist in the compilation unit module table |
| missing selective import name | `OOF-IMP3` | Imported module exists, selected top-level type/contract does not |
| duplicate module declaration | `OOF-IMP4` | Same module path declared by more than one source unit |
| missing module declaration in multi-file unit | `OOF-IMP5` | Applies only when N>1 source units require explicit module labels |
| duplicate contract across universe | `OOF-DECL-DUP-CONTRACT` | Declaration collision, not import-edge failure |
| duplicate type across universe | `OOF-DECL-DUP-TYPE` | Declaration collision, not import-edge failure |
| ambiguous unqualified imported name | `OOF-IMP6` candidate | Future-only unless P3 explicitly scopes ambiguity checks |

Required payload fields for `OOF-IMP*`:

- `source_path`
- `module_path`
- `import_path` when an import edge is involved
- `module_paths` or `source_paths` when the failure involves duplicates
- `cycle_path` for circular imports
- `missing_name` for selective import misses

---

## 7. Compatibility Notes

Later wording cleanup should update:

- `igniter-lang/docs/spec/ch2-source-surface.md`
- PROP-IMPORT-RESOLUTION-P1 wording where it lists `OOF-M1/M2/M3`
- PROP-IMPORT-RESOLUTION-P2 planning examples that used `OOF-M1/M2`
- `igniter-lab/lab-docs/lang/lab-multifile-compilation-import-resolution-proof-v0.md`
- portfolio/index notes that describe lab proof candidate codes

No active compiler output should alias old import candidate names:

- `OOF-M1` must not alias circular import.
- `OOF-M2` must not alias unknown import.
- `OOF-M3` must not alias duplicate module.

Reason: aliases would preserve ambiguity in machine-readable reports and make
proof expectations less honest.

Existing active diagnostics remain as-is:

- modifier/effect/profile/evidence `OOF-M*` codes remain untouched;
- no Ruby classifier migration;
- no Rust classifier migration;
- no Rust assembler migration;
- no proof fixture rewrite outside import-resolution work.

---

## 8. P3 Impact

PROP-IMPORT-RESOLUTION-P3 is unblocked from the diagnostic-name perspective.

P3 must implement or proof-expect:

- `OOF-IMP1` circular import;
- `OOF-IMP2` unknown module import;
- `OOF-IMP3` missing selective import name;
- `OOF-IMP4` duplicate module declaration;
- `OOF-IMP5` missing module declaration in multi-file unit, if P3 requires
  explicit modules for N>1 sources;
- `OOF-DECL-DUP-CONTRACT` duplicate contract across the merged universe;
- `OOF-DECL-DUP-TYPE` duplicate type across the merged universe.

Likely P3 files remain the same as P2 planned:

- `igniter-lab/igniter-compiler/src/multifile.rs`
- `igniter-lab/igniter-compiler/src/lib.rs`
- `igniter-lab/igniter-compiler/src/main.rs`
- `igniter-lab/igniter-compiler/src/emitter.rs`
- `igniter-lab/igniter-compiler/src/assembler.rs`
- `igniter-lab/igniter-view-engine/fixtures/multifile_compilation_p3/...`
- `igniter-lab/igniter-view-engine/proofs/verify_prop_import_resolution_p3.rb`

P3 remains bounded implementation work only if separately authorized. This P2A
does not itself edit source code.

---

## 9. Decision Output

**ACCEPT.**

Namespace decided. Import/module diagnostics use `OOF-IMP*`; existing
modifier/effect/profile/evidence `OOF-M*` diagnostics remain untouched.

---

## 10. Exact Next Route

Recommended next route:

```text
PROP-IMPORT-RESOLUTION-P3 - bounded Rust-lab implementation
```

P3 should cite this P2A packet and use the `OOF-IMP*` mapping above. If
governance wants to clean the broader `OOF-M*` family later, that should be a
separate diagnostic-taxonomy cleanup card, not part of import-resolution P3.
