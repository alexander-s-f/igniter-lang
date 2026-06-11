# PROP-IMPORT-RESOLUTION-P4: Ruby Canon Parity Decision

**Track:** ruby-canon-import-resolution-parity-decision-v0
**Route:** CANON PARITY DECISION / IMPLEMENTATION PLANNING
**Authority:** planning/decision only
**Date:** 2026-06-11
**Status:** CLOSED - READY FOR P5 IMPLEMENTATION
**Predecessors:** PROP-IMPORT-RESOLUTION-P1/P2/P2A/P3; PROP-ENTRYPOINT-P3

---

## 1. Authority Boundary

This packet decides the Ruby canon parity route for import resolution. It
authorizes no implementation.

Closed here:

- no Ruby source edits
- no Rust source edits
- no VM changes
- no package registry / distribution / semver / trust store
- no public/internal visibility
- no stdlib-as-import promotion
- no runtime loading or dynamic imports
- no capability/profile import
- no public/stable API claim
- no broad module-system redesign
- no CLI behavior change in this card

Rust P3 is evidence, not canon authority by itself. Ruby `igniter-lang` remains
the canon language repo.

---

## 2. Current Ruby Pipeline Inventory

| Surface | Current behavior | Required change for Ruby parity | File path | Risk |
|---|---|---|---|---|
| Parser import AST | `module` and `import` parse into program hash; imports have `module_path` and optional `names`; imports are not resolved | No grammar change needed for P5; optionally add import source span only if cheap and bounded | `lib/igniter_lang/parser.rb` | Low for grammar; medium if source spans are added |
| Parsed source identity | `ParsedProgram` computes single raw-source SHA256 and carries one `source_path` | P5 resolver must compute composite multi-file `source_hash` and synthetic `source_path` before classifier | `lib/igniter_lang/parser.rb`; new resolver | Medium: must not disturb single-source identity |
| Classifier | Classifies one parsed program; copies `module`, `source_hash`, `source_path`, entrypoint, types, contracts; ignores imports | Prefer no classifier change: feed classifier a merged parsed program after resolver validation | `lib/igniter_lang/classifier.rb` | Low if unchanged; medium if source_units are propagated through classifier |
| Typechecker | Typechecks one classified program; type env is built from declarations in that program; entrypoint target validation is active | Prefer no typechecker change for P5; merged universe gives type env all imported declarations; entrypoint validation runs over merged contracts | `lib/igniter_lang/typechecker.rb` | Medium: over-merged universe must be gated by resolver first |
| `call_contract` support | Ruby typechecker does not expose the Rust lab literal `call_contract` registry surface used by P3 | Do not add Ruby `call_contract` in P5; classify as explicit parity gap unless separately authorized | `lib/igniter_lang/typechecker.rb` | High if attempted; out of P5 scope |
| SemanticIR | Emits one `semantic_ir_program` with one `source_hash`, one `source_path`, module, contracts, and optional entrypoint | Add or inject `source_units` evidence for multi-file compile; preserve entrypoint | `lib/igniter_lang/semanticir_emitter.rb` or orchestrator injection | Medium |
| Assembler manifest | Emits manifest with source identity, contract refs, entrypoint if present; no `source_units` | Copy `source_units` from SemanticIR into manifest and include it in artifact material | `lib/igniter_lang/assembler.rb` | Medium: artifact hash material must stay honest |
| Compiler orchestrator | `compile(source_path:, out_path:)` reads one file and runs parse -> classify -> typecheck -> emit -> assemble | Add bounded internal `compile_sources(source_paths:, out_path:)` or equivalent pre-pass path; keep existing `compile` unchanged | `lib/igniter_lang/compiler_orchestrator.rb` | Medium: must preserve all existing single-source behavior |
| Public module facade | `IgniterLang.compile(source_path:, ...)` exposes one source path | Do not widen public facade in P5 unless explicitly authorized | `lib/igniter_lang.rb` | Medium/high: avoid public API claim |
| CLI compile | `igc compile SOURCE --out OUT.igapp`; one source only | Keep CLI unchanged in P5 unless supervisor explicitly adds CLI scope | `lib/igniter_lang/cli.rb` | Medium/high: CLI behavior can look public/stable |
| Diagnostics framework | OOF diagnostics are hashes with rule/message/node/line; no import resolver diagnostics yet | P5 resolver emits P2A final `OOF-IMP*` and declaration duplicate diagnostics with source/module/import facts | `lib/igniter_lang/diagnostics.rb`; resolver-local helper | Low/medium |
| Entrypoint | PROP-ENTRYPOINT-P3 is live in Ruby single-file path; manifest entrypoint is metadata/evidence and enters artifact hash material | P5 must preserve entrypoint; multi-file target resolution uses merged universe after duplicate-contract gate | `parser.rb`, `typechecker.rb`, `semanticir_emitter.rb`, `assembler.rb` | Medium |

---

## 3. Rust P3 Reference Summary

Rust P3 should be ported as architecture, not blindly copied as authority.

Useful P3 elements:

- `SourceUnit` inventory
- module table
- import graph validation
- duplicate module/contract/type gates
- composite multi-file `source_hash`
- deterministic merged logical universe
- `source_units` evidence in manifest/report
- final P2A diagnostics: `OOF-IMP1..5`
- declaration duplicate diagnostics
- no-authority boundary

Do not port:

- Rust compiler CLI authority as Ruby public API
- Rust lab `call_contract` behavior as Ruby canon behavior
- any package/visibility/stdlib/import-runtime assumptions

---

## 4. Parity Decision Options

### Option A: Implement Ruby canon parity now

Accepted.

Ruby already has the necessary parser substrate, single-file entrypoint pipeline,
manifest assembly, and type environment behavior. Rust P3 has proven the
multi-file resolver boundary with final diagnostics. The remaining Ruby work is
bounded if implemented as an orchestrator pre-pass.

### Option B: Keep Rust-lab as reference and defer Ruby canon

Rejected.

Deferring would keep `import` semantically inert in the canon repo after the
proposal, diagnostic, and Rust-lab evidence chain is already coherent.

### Option C: Implement Ruby proof-local parity driver only

Rejected as the main route.

LAB-MULTIFILE-COMPILATION-P1 already covered proof-local driver evidence. The
next useful step is canon Ruby pipeline parity, not another proof-local shim.

### Option D: Skip Ruby parity and make Rust compiler canonical

Rejected.

No governance decision has moved canon language authority from `igniter-lang` to
the Rust lab compiler. Rust P3 remains lab evidence.

---

## 5. Decision Criteria

| Criterion | Assessment |
|---|---|
| User value | High: ends canon `import` inertness and reduces copy-paste type redefinition |
| Proof maturity | High: P1/P2/P2A/P3 chain is coherent; Rust P3 83/83 PASS |
| Implementation size | Medium: new resolver plus narrow orchestrator/manifest changes |
| Risk to existing Ruby experiments | Manageable if single-source path remains unchanged |
| Canon authority implications | Acceptable because import semantics are proposal-authored and P5 can stay bounded |
| Need before stdlib/visibility/app form | High: import is the substrate before stdlib-as-import and visibility |
| Diagnostic readiness | Ready after P2A final `OOF-IMP*` mapping |
| Relationship to EntryPoint P3 | Compatible; P5 must preserve manifest `entrypoint` and defer qualified/ambiguous policy unless necessary |

---

## 6. Recommended Decision

**READY FOR RUBY P5 IMPLEMENTATION.**

Bounded P5 scope:

- implement Ruby canon multi-file import resolution as an internal compiler
  pipeline path;
- preserve existing single-source `compile(source_path:, ...)`;
- avoid public CLI widening unless separately authorized;
- avoid Ruby `call_contract` implementation unless separately authorized;
- emit final `OOF-IMP*` diagnostics;
- attach `source_units` evidence to SemanticIR/report/manifest for multi-file
  compiles;
- prove entrypoint metadata still works when multi-file and entrypoint coexist.

---

## 7. Ruby Architecture Plan

Recommended architecture:

```text
N source paths
-> MultifileResolver
-> SourceUnit inventory
-> module table
-> import graph validation
-> duplicate declaration validation
-> deterministic merged parsed program
-> existing classifier/typechecker/emitter/assembler
```

New internal class:

```text
IgniterLang::MultifileResolver
```

Recommended resolver output:

```ruby
{
  "parsed_program" => merged_parsed_program,
  "source_units" => [...],
  "source_hash" => "sha256:<64hex>",
  "source_path" => "multifile:<prefix16>"
}
```

The merged parsed program should:

- set `module` to a synthetic label, e.g. `Lab.Multifile.Universe` or
  `Igniter.Multifile.Universe`;
- clear `imports` after validation;
- concatenate top-level declarations in sorted source-unit order;
- carry the composite `source_hash`;
- carry synthetic `source_path`;
- carry exactly one valid entrypoint or no entrypoint.

Single-source behavior:

- `CompilerOrchestrator#compile` remains unchanged;
- P5 adds a separate internal method such as `compile_sources(source_paths:,
  out_path:, ...)`;
- proof runner may call the internal method directly;
- CLI multi-source support remains deferred unless explicitly scoped.

---

## 8. Ruby Identity Plan

Composite multi-file `source_hash`:

```text
sha256(canonical_json([
  { module, source_path, source_hash, source },
  ...
] sorted by module path then source_path))
```

Rules:

- file input order must not affect identity;
- source edits must affect identity;
- comment-only edits affect identity under raw-source identity;
- module name is a routing label, not content identity;
- `contract_ref` remains per-contract;
- `artifact_hash` remains final artifact identity and must differ from
  `source_hash`;
- `source_units` evidence does not create package or trust authority.

Recommended evidence shape:

```json
{
  "module": "Example.Module",
  "source_path": "path/to/file.ig",
  "source_hash": "sha256:<64hex>",
  "types": ["TypeName"],
  "contracts": ["ContractName"]
}
```

---

## 9. Ruby Diagnostics Plan

Use final P2A codes:

| Case | Code |
|---|---|
| circular import | `OOF-IMP1` |
| unknown module import | `OOF-IMP2` |
| missing selective import name | `OOF-IMP3` |
| duplicate module declaration | `OOF-IMP4` |
| missing module declaration in N>1 unit | `OOF-IMP5` |
| duplicate contract across universe | `OOF-DECL-DUP-CONTRACT` |
| duplicate type across universe | `OOF-DECL-DUP-TYPE` |

Payload fields:

- `rule`
- `severity: "error"`
- `message`
- `node`
- `source_path`
- `module_path`
- `import_path` when an import edge is involved
- `missing_name` for selective import misses
- `source_paths` for duplicate declarations
- `module_paths` for duplicate declarations
- `cycle_path` for circular imports
- `line` / `col` when available

Current Ruby import AST does not carry import spans. P5 may either add a small
parser span for import declarations or leave `line` nil while still providing
`source_path`, `module_path`, and `import_path`. It must not open full sourcemap
work.

---

## 10. Manifest / EntryPoint Interaction

Ruby PROP-ENTRYPOINT-P3 is already live.

When multi-file and entrypoint coexist:

- `manifest.source_units` appears as multi-file evidence;
- `manifest.entrypoint` remains top-level evidence metadata;
- both fields enter artifact material before `artifact_hash`;
- `entrypoint.resolved_contract` resolves against the merged universe after
  duplicate-contract validation;
- zero-entrypoint library modules remain valid;
- no CLI/VM run behavior changes;
- manifest entrypoint does not imply runtime execution permission.

Qualified entrypoint:

- If current Ruby parser accepts qualified targets, P5 may carry them as declared
  target strings.
- Cross-module qualified entrypoint semantics should be minimal: resolve only if
  the final merged universe contains exactly one matching contract identity.
- Ambiguous target diagnostics can remain deferred because duplicate contract
  names are failed closed in P5; `OOF-EP4` should be reserved for a later
  visibility/qualified-name route if needed.

---

## 11. Proof Matrix for Future P5

Target: **70+ checks**.

Required sections:

- Ruby valid two-file compile;
- Ruby valid three-file compile;
- selective import;
- whole-module import;
- cross-file record type;
- cross-file imported contract visibility in resolver metadata;
- cross-file literal `call_contract` only if already supported; otherwise mark
  explicit gap without implementing it;
- file order determinism;
- import order determinism;
- `OOF-IMP1` circular import;
- `OOF-IMP2` unknown module;
- `OOF-IMP3` missing selective name;
- `OOF-IMP4` duplicate module;
- `OOF-IMP5` missing module;
- `OOF-DECL-DUP-CONTRACT`;
- `OOF-DECL-DUP-TYPE`;
- diagnostics include source/module/import facts;
- no old import `OOF-M1/M2/M3`;
- `source_units` SemanticIR/report/manifest evidence;
- artifact hash/source hash distinction;
- `contract_ref` remains per-contract;
- comment-only change affects raw source identity;
- entrypoint in multi-file manifest;
- zero-entrypoint multi-file library valid;
- existing PROP-ENTRYPOINT-P3 proof remains green;
- import does not grant capability/profile/package/runtime authority;
- single-source compiler regressions remain green;
- existing relevant Ruby test/proof suite remains green.

---

## 12. Diff Plan

Must edit for P5:

- `lib/igniter_lang/multifile_resolver.rb` - new resolver, about 220-320 LOC,
  medium risk.
- `lib/igniter_lang/compiler_orchestrator.rb` - add internal multi-source path
  and report/refusal handling, about 60-120 LOC, medium risk.
- `lib/igniter_lang/assembler.rb` - copy `source_units` into manifest/artifact
  material when present, about 10-25 LOC, medium risk.
- `lib/igniter_lang.rb` - require resolver only if needed, about 1-5 LOC, low
  risk.
- proof fixtures under `.agents/work` or a bounded proof fixture directory,
  medium volume, low risk.
- proof runner for P5, about 250-400 LOC, medium risk.
- lab/proposal/portfolio docs, low risk.

Maybe edit:

- `lib/igniter_lang/semanticir_emitter.rb` - only if `source_units` should be
  emitted there instead of orchestrator injection.
- `lib/igniter_lang/parser.rb` - only for small import source-span support.
- `lib/igniter_lang/compilation_report.rb` - only if shared report helpers need
  source_units.
- `lib/igniter_lang/cli.rb` - only if supervisor explicitly authorizes
  multi-source CLI; otherwise do not edit.

Must not edit:

- Rust compiler
- VM/runtime
- package registry/distribution
- visibility/public/internal/export system
- stdlib module contents
- capability/profile authority model
- runtime loader
- public/stable API docs

---

## 13. Risk Register

| Risk | Mitigation |
|---|---|
| Ruby/Rust drift | Treat Rust P3 as reference evidence; P5 proof must assert same diagnostics/identity invariants |
| Rust-lab semantics become canon too early | Port only semantics already proposal-authored in P1/P2A |
| Single-source experiments break | Keep `compile(source_path:)` unchanged and prove regressions |
| Over-merged namespace leaks names | Validate import graph and duplicates before merging; keep visibility deferred |
| CLI behavior ambiguity | Do not widen CLI in P5 unless separately authorized |
| Manifest/schema drift | Mark `source_units` evidence; no Ch6 stable schema claim beyond bounded proof |
| Import grants authority accidentally | Prove no capability/profile/package/runtime authority fields appear |
| Proof-local differs from production Ruby path | Use `CompilerOrchestrator` path for P5 proof, not a standalone proof-local driver |
| EntryPoint ambiguity | Duplicate contract names fail closed before entrypoint validation; defer `OOF-EP4` unless a real ambiguity remains |
| `call_contract` pressure | Do not implement as part of import parity; mark as gap if Ruby lacks support |

---

## 14. Decision Output

**READY FOR P5 IMPLEMENTATION.**

Ruby canon parity is ready as a bounded implementation card, provided P5 keeps
the scope to compiler-orchestrator pre-pass, diagnostics, identity, manifest
evidence, and regressions.

---

## 15. Exact Next Route

Recommended:

```text
PROP-IMPORT-RESOLUTION-P5 - Ruby canon multi-file import implementation
```

P5 should be Ruby `igniter-lang` only and must not open CLI/public API,
package/visibility/stdlib-as-import/runtime loading, VM, or capability authority.
