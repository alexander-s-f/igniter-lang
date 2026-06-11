# PROP-ENTRYPOINT-P2 - Parser and Manifest Implementation Planning

**Track:** explicit-entrypoint-parser-manifest-planning-v0
**Route:** IMPLEMENTATION PLANNING ONLY
**Authority:** planning document only
**Date:** 2026-06-11
**Status:** CLOSED - READY FOR P3 IMPLEMENTATION
**Predecessor:** PROP-ENTRYPOINT-P1

---

## 1. Authority Boundary

This is planning only. It authorizes no implementation.

Closed in P2:

- no parser/source changes;
- no classifier/source changes;
- no typechecker/source changes;
- no SemanticIR/source changes;
- no `.igapp` assembler/source changes;
- no CLI behavior changes;
- no VM changes;
- no app framework;
- no scheduler/main loop;
- no service/daemon model;
- no public/internal visibility;
- no package system;
- no capability authority;
- no public/stable API.

Entrypoint remains a metadata selector over an existing contract. It is not a
contract modifier, runtime authority, capability grant, app route, hidden graph
root, service loop, or debugger execution protocol.

---

## 2. Current State Inventory

| Surface | Current behavior | Needed P3 change | File path | Risk |
|---------|------------------|------------------|-----------|------|
| Ruby parser TopDecl dispatch | `parse_top_decl` dispatches by token value for `contract`, `type`, `variant`, `profile`, `size_relation`, etc.; `entrypoint` is currently unexpected | Add `entrypoint` top-level declaration parser, produce one optional program-level node | `igniter-lang/lib/igniter_lang/parser.rb` | Medium: keyword collision and malformed-line recovery |
| Ruby AST/program hash shape | `ParsedProgram#to_h` emits module, imports, contracts, types, variants, assumptions, profiles, size_relations, intent_text | Add `"entrypoint" => nil | object`; keep absent source serialized as `nil` for stable shape | `igniter-lang/lib/igniter_lang/parser.rb` | Low: JSON shape churn affects expected fixtures |
| Ruby classifier propagation | `Classifier#classify` copies module/type/variant/intent metadata and classifies contracts | Pass `entrypoint` through unchanged after parser validation; no fragment effect | `igniter-lang/lib/igniter_lang/classifier.rb` | Low: accidental classification semantics |
| Ruby typechecker validation | Typechecker builds contract/type registries and emits `type_errors`; no program-level entrypoint validation | Validate zero/one already parser-level; validate unknown target as `OOF-EP2`; keep unsupported runner target out of language diagnostics | `igniter-lang/lib/igniter_lang/typechecker.rb` | Medium: avoid making runner policy type policy |
| Ruby SemanticIR propagation | Program IR carries module, source_hash, contracts, variant_declarations, intent_text | Copy resolved `entrypoint` metadata into program IR if valid | `igniter-lang/lib/igniter_lang/semanticir_emitter.rb` | Low: preserve fragment classification |
| Ruby `.igapp` manifest emission | Manifest has `contracts`, `contract_refs`, `fragment_summary`, `contract_index`; no entrypoint field | Add top-level `entrypoint` field only when SemanticIR has one; include in artifact hash material before hash | `igniter-lang/lib/igniter_lang/assembler.rb` | Medium: artifact_hash ordering and source/manifest drift |
| Ruby compiler orchestrator | Runs parse -> classify -> typecheck -> emit -> assemble; no special entrypoint behavior | No orchestration policy change; just transports enriched program data | `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb` | Low |
| Ruby CLI `igc compile/run` | Compile has no source entrypoint handling; run uses passport output contract, not manifest entrypoint | No P3 CLI behavior change; future runner may inspect manifest separately | `igniter-lang/lib/igniter_lang/cli.rb`, `experimental_igc_run.rb` | Medium: override confusion if changed too early |
| VM named entry behavior | Lab VM has `--entry`/`--entrypoint` selector from LAB-RACK-P7; default still `contracts[0]` | No VM change in P3; keep LAB-RACK-P7 green as regression evidence | `igniter-lab/igniter-vm`, `igniter-view-engine/proofs/verify_p7_vm_entrypoint_selector.rb` | Medium: source entrypoint must not imply VM auto-run |
| Rust lab parser | `SourceFile` has module/import/contracts/types/etc.; `TopDecl` has no EntryPoint | Optional parity follow-up only if P3 explicitly includes Rust lab symmetry | `igniter-lab/igniter-compiler/src/parser.rs` | Medium: lab/canon drift |
| Rust lab classifier/typechecker/emitter | Rust pipeline has no entrypoint field in classified/typed/program IR | Maybe mirror Ruby after canonical P3 lands; not required for Ruby-first P3 | `igniter-lab/igniter-compiler/src/classifier.rs`, `typechecker.rs`, `emitter.rs` | Medium |
| Rust lab assembler | Manifest has `contracts`, `contract_refs`, `fragment_summary`, `contract_index`; no entrypoint | Maybe mirror Ruby after canonical P3 or in separate lab parity card | `igniter-lab/igniter-compiler/src/assembler.rs` | Medium |
| IDE/debugger usage | Lab trace docs use explicit `--entry` flag; no source manifest entrypoint | Display `manifest.entrypoint` as start-target metadata only in future tooling | `igniter-lab/lab-docs/ide/*`, viewer docs | Low: accidental live-debugger claim |

---

## 3. Syntax Planning

Parser target:

```igniter
entrypoint ContractName
```

Qualified target accepted as a string path:

```igniter
entrypoint Billing.Invoice.RunInvoice
```

P3 recommendation:

- implement a contextual top-level declaration;
- do not add hard reservation pressure beyond top-level dispatch;
- do not add block syntax;
- do not add `entrypoint name: ContractName`;
- do not add `args`, `output`, `default`, `section`, or `component`.

Malformed line behavior:

- `entrypoint` with no following name: parse error with candidate `OOF-EP2` or
  parser-local malformed declaration rule;
- `entrypoint { ... }`: parse error, not a block declaration;
- `entrypoint A B`: parse error for unexpected extra token after target;
- `entrypoint A, B`: parse error; named/multiple entrypoints are deferred.

The implementation may parse the target with the same name/path helper as
module paths, but it must store the original declared target string.

---

## 4. AST Shape

Recommended parsed shape:

```json
{
  "entrypoint": {
    "kind": "entrypoint_decl",
    "target": "RunInvoice",
    "qualified": false,
    "source_span": {
      "line": 3,
      "col": 1
    }
  }
}
```

For a qualified target:

```json
{
  "entrypoint": {
    "kind": "entrypoint_decl",
    "target": "Billing.Invoice.RunInvoice",
    "qualified": true,
    "source_span": {
      "line": 3,
      "col": 1
    }
  }
}
```

Rationale:

- singular field matches zero-or-one v0 cardinality;
- `target` preserves declared text;
- `qualified` lets validators distinguish single-file and multi-file cases;
- `source_span` is enough for diagnostics without opening full sourcemap work;
- no `args`, `output`, `profile`, `default`, or runner policy fields.

Recommended pass-through shape after typecheck:

```json
{
  "kind": "entrypoint_decl",
  "target": "RunInvoice",
  "qualified": false,
  "resolved_contract": "RunInvoice",
  "contract_ref": "contract/RunInvoice/sha256:<prefix24>",
  "source_span": { "line": 3, "col": 1 }
}
```

For P3 single-file implementation, `resolved_contract` may be the contract name.
For future multi-file implementation, `resolved_contract` should become the
module-qualified contract identity once import-resolution naming is stable.

---

## 5. Validation Plan

Validation rules:

- zero entrypoint allowed;
- exactly one entrypoint accepted when target resolves to a contract;
- duplicate entrypoint declarations -> `OOF-EP1`;
- unknown target -> `OOF-EP2`;
- ambiguous unqualified target in multi-file -> `OOF-EP4` when multi-file
  resolver exists;
- unsupported runner target -> runner/tool diagnostic, not language diagnostic,
  unless a future accepted proposal narrows valid language targets.

Where to validate:

- Parser: cardinality and malformed declaration shape.
- TypeChecker: target exists and is a contract in the current resolved contract
  universe.
- Runner/CLI: target can be executed by that runner mode.

Do not require an entrypoint for all modules. Library modules compile without
entrypoint.

---

## 6. Manifest Binding Plan

Recommended manifest field:

```json
{
  "entrypoint": {
    "kind": "default_entrypoint",
    "declared_target": "RunInvoice",
    "resolved_contract": "RunInvoice",
    "contract_ref": "contract/RunInvoice/sha256:<prefix24>",
    "contract_path": "contracts/run_invoice.json",
    "source_span": {
      "source_path": "source/invoice.ig",
      "line": 3,
      "col": 1
    }
  }
}
```

Absent entrypoint:

- P3 recommendation: omit `manifest.entrypoint`.
- Rationale: preserves legacy manifests unless a source declaration exists.
- Alternative `null` is acceptable only if the P3 proof explicitly verifies
  all existing loader/manifest readers tolerate it.

Hash implications:

- `source_hash` changes because source text changes.
- `artifact_hash` changes because manifest/artifact material changes.
- `contract_ref` should not change solely because a separate entrypoint line
  names the contract, unless the implementation includes whole-source hash in
  per-contract refs.
- behavior hash, if separately defined, should not change solely due to start
  target selection.

Ordering rule:

- Include entrypoint metadata in artifact hash material before computing
  `artifact_hash`.
- Do not add entrypoint after hash computation.

Authority rule:

- `manifest.entrypoint` is evidence of the source declaration.
- It does not authorize runtime execution, capability use, profile binding, or
  debugger stepping.

---

## 7. CLI / Runner Relationship

No P3 CLI behavior change.

Existing or future runner policy may use this order later:

1. Explicit CLI/tool override, for example `--entry Name`.
2. Source-declared `manifest.entrypoint`.
3. Compatibility fallback, for example `contracts[0]`, only when runner mode
   allows fallback.

P3 should only make the declaration available to tooling. It must not make
`igc run` automatically execute manifest entrypoints unless a separate card
authorizes runner behavior.

LAB-RACK-P7 remains relevant evidence:

- `--entry` selects named contracts in the lab VM;
- no flag preserves `contracts[0]` compatibility behavior;
- unknown named entry fails closed;
- the flag is a debugging aid, not stable CLI semantics.

---

## 8. Debugger / IDE Relationship

Entrypoint helps session setup:

- IDE can display the intended start contract;
- trace viewer can preselect a start target;
- `.igapp` consumers can show declared target without guessing;
- source span links can jump from manifest metadata to the declaration line.

P3 does not authorize:

- live stepping;
- breakpoint protocol;
- watch expressions;
- debugger transport;
- runtime launch;
- host IO;
- capability grants.

The graph remains visible. Entrypoint points at a contract whose inputs,
computes, effects, outputs, and call edges remain explicit.

---

## 9. Multi-File Interaction

Single-file P3 can land before import resolution.

Rules for P3:

- unqualified target resolves against the current file/program contract list;
- qualified target may parse as a string path, but validation can be deferred
  unless the implementation has a resolved multi-file contract universe;
- no implicit sibling-module lookup;
- no package lookup;
- no stdlib-as-import lookup.

Rules after import resolution:

- module-qualified target resolves exactly;
- unqualified target is valid only if exactly one contract of that name exists
  in the compilation unit;
- duplicate same-name contracts across modules make unqualified entrypoint
  ambiguous -> `OOF-EP4`;
- duplicate entrypoint declarations across files -> `OOF-EP1`.

P3 should not block on PROP-IMPORT-RESOLUTION as long as it stays single-file
for validation and records qualified targets conservatively.

---

## 10. Diagnostics Plan

Reserved diagnostics:

| Code | Classification | Trigger | P3 status |
|------|----------------|---------|-----------|
| OOF-EP1 | language diagnostic | Duplicate entrypoint declaration in one compilation unit | Implement for single-file duplicate; extend across files later |
| OOF-EP2 | language diagnostic | Entrypoint target does not resolve to a contract | Implement for single-file/current contract universe |
| OOF-EP3 | tool-mode diagnostic | Tool/runner requires entrypoint but none exists | Defer; not ordinary compile failure |
| OOF-EP4 | language diagnostic | Ambiguous unqualified target in multi-file context | Defer until multi-file resolver |
| OOF-EP5 | language diagnostic | Entrypoint target is not a contract | Implement if same-name type/function collision can be detected; otherwise reserve |
| OOF-EP6 | tool-mode diagnostic | Selected runner cannot execute target fragment/kind | Defer to runner/tool mode |

Diagnostic payload should include:

- code;
- message;
- source_path;
- line/col when available;
- declared target;
- candidate contract names for unknown/ambiguous target when safe.

---

## 11. Proof Matrix

Target: 42 checks.

| Section | Planned checks |
|---------|----------------|
| EP-PARSE | valid unqualified entrypoint parses; valid qualified target parses; malformed missing target fails; block syntax rejected; duplicate lines rejected |
| EP-AST | parsed shape has `kind`, `target`, `qualified`, `source_span`; absent entrypoint serializes as nil/omitted per chosen P3 rule |
| EP-VALIDATE | zero entrypoint accepted; single valid target accepted; unknown target `OOF-EP2`; duplicate `OOF-EP1`; target type/function `OOF-EP5` if implemented |
| EP-PROPAGATE | classifier/typechecker/SemanticIR preserve entrypoint; no fragment classification change; no type_env mutation |
| EP-MANIFEST | manifest emits entrypoint when present; omits field when absent; includes resolved target/ref/path; artifact_hash changes when entrypoint changes; no post-hash injection |
| EP-CLI-VM | compile CLI unchanged; `igc run` unchanged; LAB-RACK-P7 named `--entry` proof remains green or is cited as unchanged |
| EP-CLOSED | no `section`; no `component`; no args/profile/output narrowing; no scheduler; no capability authority; no public API claim |

Minimum acceptance for P3:

- no-entrypoint source still compiles;
- valid entrypoint source compiles;
- invalid entrypoint target refuses;
- manifest binding exists only when declared;
- all closed-surface scans pass.

---

## 12. Diff Plan

### Must edit in P3

| File | Rough size | Purpose |
|------|------------|---------|
| `lib/igniter_lang/parser.rb` | 40-70 lines | Add parse shape, cardinality, ParsedProgram field |
| `lib/igniter_lang/classifier.rb` | 3-8 lines | Pass entrypoint metadata through |
| `lib/igniter_lang/typechecker.rb` | 35-70 lines | Resolve target, emit OOF-EP1/2/5 as applicable |
| `lib/igniter_lang/semanticir_emitter.rb` | 8-20 lines | Carry resolved entrypoint into SemanticIR |
| `lib/igniter_lang/assembler.rb` | 20-45 lines | Add manifest field and hash material ordering |
| `source/*entrypoint*.ig` or proof fixtures | 4-8 files | Valid, absent, duplicate, unknown, closed-surface fixtures |
| `proofs/verify_prop_entrypoint_p3.rb` or matching local proof path | 180-260 lines | 35-50 checks |

### Maybe edit in P3

| File | Reason |
|------|--------|
| `docs/spec/ch2-source-surface.md` | Only if P3 is accepted as docs sync scope |
| `docs/spec/ch6-semanticir.md` | Only if manifest schema sync is authorized |
| `lib/igniter_lang/compilation_report.rb` | Only if program-level type errors need report shaping |
| `source/*.parsed_program.expected.json` | Only if fixture expected JSON needs entrypoint nil |

### Must not edit in P3

| File / area | Reason |
|-------------|--------|
| `lib/igniter_lang/cli.rb` | No CLI behavior changes in P3 |
| `lib/igniter_lang/experimental_igc_run.rb` | No runner behavior changes |
| `lib/igniter_lang/runtime_smoke.rb` | No runtime behavior changes |
| VM sources | VM closed |
| package/registry code | Package system closed |
| profile/capability authority code | Entrypoint grants no authority |
| `section` or grouping grammar | Explicitly closed |

### Rust lab parity

Rust lab parity is useful, but should be a separate optional route unless P3
explicitly authorizes symmetry:

- `igniter-lab/igniter-compiler/src/lexer.rs`
- `igniter-lab/igniter-compiler/src/parser.rs`
- `igniter-lab/igniter-compiler/src/classifier.rs`
- `igniter-lab/igniter-compiler/src/typechecker.rs`
- `igniter-lab/igniter-compiler/src/emitter.rs`
- `igniter-lab/igniter-compiler/src/assembler.rs`

Do not smuggle Rust lab implementation into P3 unless the P3 card names it.

---

## 13. Risk Register

| Risk | Mitigation |
|------|------------|
| Entrypoint becomes app framework | Keep syntax singular target selector; no args/output/routes/service model |
| CLI override conflict | P3 makes metadata only; runner precedence deferred |
| Multi-file qualified-name ambiguity | Single-file P3; defer full ambiguity until import resolver |
| Duplicate source declarations across files | Reserve `OOF-EP1`; implement cross-file check with multi-file unit |
| Manifest/source drift | Manifest entrypoint derived only from source/typed program |
| Accidental behavior-hash changes | State artifact hash changes; behavior hash should not unless separately defined |
| Parser keyword conflicts | Contextual top-level dispatch; no hard identifier reservation required |
| Runner treats effect entrypoint as authorized | Manifest field is evidence only; capabilities still required |
| Library modules blocked | Zero entrypoint remains accepted |
| `contracts[0]` silently treated as language semantics | Label fallback as compatibility runner policy only |

---

## 14. Decision

**READY FOR P3 IMPLEMENTATION.**

Scope of readiness:

- Ruby `igniter-lang` single-file/current-pipeline parser -> typechecker ->
  SemanticIR -> assembler manifest implementation;
- no CLI or VM behavior change;
- qualified target parsing allowed, but multi-file resolution and ambiguity can
  remain deferred until import-resolution implementation.

P3 must keep entrypoint as metadata/selector and must not open runtime,
capability, scheduler, visibility, package, or app-framework authority.

---

## 15. Exact Next Route

```text
PROP-ENTRYPOINT-P3 - bounded parser/typechecker/SemanticIR/manifest implementation
```

P3 should target 35-50 checks and explicitly keep CLI/VM unchanged.

Alternative if governance wants import-first sequencing:

```text
Defer P3 until PROP-IMPORT-RESOLUTION-P2/P3 settles qualified-name semantics.
```

That deferral is not technically required for the single-file implementation.
