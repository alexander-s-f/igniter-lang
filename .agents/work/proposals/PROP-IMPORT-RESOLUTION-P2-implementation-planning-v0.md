# PROP-IMPORT-RESOLUTION-P2: Implementation Planning

**Track:** import-resolution-multifile-compiler-driver-planning-v0
**Route:** IMPLEMENTATION PLANNING ONLY
**Authority:** planning document only
**Date:** 2026-06-11
**Status:** CLOSED - CONDITIONAL
**Predecessor:** PROP-IMPORT-RESOLUTION-P1
**Evidence:** LANG-MODULE-IDENTITY-P2; LAB-MULTIFILE-COMPILATION-P1

---

## 1. Authority Boundary

This packet is planning only.

No implementation is authorized here:

- no parser changes
- no compiler driver changes
- no classifier changes
- no typechecker changes
- no SemanticIR emitter changes
- no assembler or `.igapp` schema changes
- no VM changes
- no package registry
- no public/internal visibility
- no stdlib-as-import
- no runtime loading
- no capability/profile import
- no public/stable API claim

Lab proof evidence remains evidence. PROP-IMPORT-RESOLUTION-P1 is the semantic
proposal. This P2 only maps the implementation surface and risk.

---

## 2. Current Implementation Inventory

| Surface | Current behavior | Needed change | File path | Risk |
|---|---|---|---|---|
| Rust CLI / compiler driver | Accepts exactly one `SOURCE` before `--out`; computes `source_hash` from one raw source file; runs parse -> monomorphize -> classify -> typecheck -> form -> emit -> assemble once | Add bounded N-source input path while preserving one-source behavior; build source-unit inventory before classify | `igniter-lab/igniter-compiler/src/main.rs` | High: CLI parsing is simple positional code; must not break existing proofs |
| Rust parser import support | `SourceFile` has `module: Option<String>` and `imports: Vec<Import>`; `Import { module_path, names, hiding, overriding }` exists | No grammar change expected; resolver consumes existing AST shape | `igniter-lab/igniter-compiler/src/parser.rs` | Low for grammar; medium if optional `source_units` metadata is added to `SourceFile` |
| Rust AST shape | ParsedProgram is a single `SourceFile`; imports are stored but unused downstream | Introduce proof/compiler-driver `SourceUnit` outside parser; optionally add `source_units` pass-through field later | new `igniter-lab/igniter-compiler/src/multifile.rs`; maybe `parser.rs` | Medium: avoid turning file path into module authority |
| Rust classifier handling | Classifies one parsed program; ignores imports; carries one `module`; contract ids are `module.contract`; `OOF-M1` already used for modifier/authority errors | Prefer merged logical universe so classifier remains mostly unchanged; if source-unit facts need pass-through, add metadata only | `igniter-lab/igniter-compiler/src/classifier.rs` | High: `OOF-M1` collision with import-cycle meaning |
| Rust typechecker handling | Builds type shapes and literal `call_contract` registry from all contracts in one `ClassifiedProgram`; error says callee not found "in this module" | Merged universe should make cross-file record types and pure `call_contract` work; message may need "compilation unit"; duplicate names must be rejected before typecheck | `igniter-lab/igniter-compiler/src/typechecker.rs` | Medium: over-merging can leak unimported names if resolver does not police references |
| Rust SemanticIR handling | Emits one `SemanticIRProgram` with one `source_hash`, one `source_path`, one `module`, contracts array | Emit composite multi-file `source_hash`; optionally include `source_units` evidence; module may be synthetic universe label | `igniter-lab/igniter-compiler/src/emitter.rs` | Medium: manifest/SIR drift if source_units only appears in one artifact |
| Rust `.igapp` manifest handling | Manifest has one `source_hash` and one `source_path`; no `source_units`; `artifact_hash` is computed over artifact material | Add optional `source_units` to manifest and artifact material; preserve `artifact_hash` as final artifact identity | `igniter-lab/igniter-compiler/src/assembler.rs` | Medium: Ch6 schema requires `source_path`; additive field must not claim package schema authority |
| Rust diagnostics support | Diagnostics are `rule`, `severity`, `message`, `node`, `line`; parser reports line; compiler-result OOF path writes compilation report | Pre-pass diagnostics need `source_path`, `module_path`, `import_path`, and optional `cycle_path`; can be carried as additional JSON fields | `main.rs`; new `multifile.rs`; maybe `emitter.rs` report path helper | High: OOF-M1/M2 code collisions exist today |
| Ruby parser import support | Parses `module` and `import`; `ParsedProgram#to_h` includes `imports`; `source_hash` is raw single-source SHA256 | No parser change expected for P3; resolver can consume existing `imports` | `igniter-lang/lib/igniter_lang/parser.rb` | Low |
| Ruby classifier handling | Ignores imports; classifies one parsed program; carries one module and one source_hash | If Ruby parity is included, add Ruby `MultifileResolver` before `Classifier#classify` | `igniter-lang/lib/igniter_lang/classifier.rb`; new `lib/igniter_lang/multifile_resolver.rb` | Medium: canon Ruby path lacks Rust-style literal call_contract registry |
| Ruby typechecker handling | Builds type env from one classified program; no observed `call_contract` registry in current Ruby surface | Merged universe handles record types; cross-file literal `call_contract` parity may need separate Ruby support or be Rust-lab-only in P3 | `igniter-lang/lib/igniter_lang/typechecker.rb` | High if P3 claims Ruby/Rust parity |
| Ruby SemanticIR handling | Emits one `source_hash`, one `source_path`, one `module`; refs are source_hash-prefix | If Ruby parity is included, propagate composite source_hash/source_units | `igniter-lang/lib/igniter_lang/semanticir_emitter.rb` | Medium |
| Ruby orchestrator | `compile(source_path:, out_path:, ...)` reads one file and runs one parsed program | Add separate `compile_sources(source_paths:, out_path:, ...)` or keep Ruby out of P3 | `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb` | Medium: do not widen public/stable API claims |
| Ch2 source surface | Grammar kernel already includes `SourceFile := ModuleDecl? ImportDecl* TopDecl*`; ParsedProgram is downstream boundary | No spec edit in P2; P3 proof can cite existing shape | `igniter-lang/docs/spec/ch2-source-surface.md` | Low |
| Ch6 `.igapp` schema | Manifest requires one `source_hash` and `source_path`; no `source_units` required | P3 may add optional `source_units` evidence field but must not claim schema authority unless separately accepted | `igniter-lang/docs/spec/ch6-semanticir.md`; `docs/spec/ch6-appendix-igapp-schema.md` | Medium: additive manifest field must remain implementation evidence until Ch6 sync |

---

## 3. Architecture Decision

Decision: **compiler-driver pre-pass**.

The multi-file resolver should live before classifier/typechecker execution:

```text
N source paths
-> SourceUnit inventory
-> module table
-> import graph validation
-> duplicate declaration validation
-> deterministic merged logical universe
-> existing classifier/typechecker/emitter/assembler path
```

Rationale:

- The parser already emits enough module/import AST.
- The classifier and typechecker already work over a single program containing
  multiple contracts and type declarations.
- Rust typechecker literal `call_contract` registry already sees all contracts
  in one `ClassifiedProgram`.
- LAB-MULTIFILE-COMPILATION-P1 proved this shape with a proof-local pre-pass.

Rejected for P3:

- Parser aggregation layer: would make parser own cross-file semantics.
- Typechecker-only resolver: too late for module/import diagnostics and
  multi-file `source_hash`.
- Runtime loading: import is not runtime loading.
- Package resolver: package/distribution is closed.

Important caveat: the merged universe must be produced only after import graph
validation. It must not silently make every sibling module visible.

---

## 4. Module Table Design

### Input Structure

Implementation-owned structure:

```text
SourceUnit {
  source_path: String,
  source: String,
  source_hash: "sha256:<64hex>",
  parsed: SourceFile,
  module_path: String,
  imports: Vec<Import>,
  type_names: Vec<String>,
  contract_names: Vec<String>
}
```

### Module Path Extraction

Use `parsed.module`.

Policy:

- Single-file compile keeps existing behavior.
- Multi-file compile requires each source unit to declare `module`.
- Missing module declaration in a multi-file unit fails closed before import
  resolution.

Recommended diagnostic for missing module in N>1 unit:

```text
OOF-M2: missing module declaration in multi-file source unit '<source_path>'
```

This reuses OOF-M2 as module/import resolution failure only if the diagnostic
namespace collision is accepted. See Decision.

### Duplicate Module Detection

Build:

```text
HashMap<module_path, Vec<source_path>>
```

If any key has more than one source path, fail with duplicate module diagnostic.

### Output Shape

```text
ModuleTable {
  units: Vec<SourceUnit> sorted by module_path then source_path,
  by_module: HashMap<String, SourceUnit>,
  diagnostics: Vec<Diagnostic>
}
```

Do not use module path as content identity. It is a routing label.

---

## 5. Import Graph Design

### Whole-Module Import

`import A.B.C` requires `A.B.C` to exist in the module table.

The import grants compile-time name availability only. It does not inject
capabilities, profiles, runtime authority, package trust, or visibility.

### Selective Import

`import A.B.C.{ Name1, Name2 }` requires:

1. module `A.B.C` exists;
2. each selected name exists as a top-level contract or type in `A.B.C`.

Missing selected name fails closed.

### Unknown Module Path

Diagnostic payload:

```json
{
  "rule": "OOF-M2",
  "severity": "error",
  "message": "unknown import path '<import_path>' from module '<module_path>'",
  "node": "import:<import_path>",
  "source_path": "<consumer file>",
  "module_path": "<consumer module>",
  "import_path": "<import path>"
}
```

### Missing Selective Name

Diagnostic payload:

```json
{
  "rule": "OOF-M2",
  "severity": "error",
  "message": "unknown import name '<name>' from '<import_path>'",
  "node": "import:<import_path>.{<name>}",
  "source_path": "<consumer file>",
  "module_path": "<consumer module>",
  "import_path": "<import path>",
  "missing_name": "<name>"
}
```

### Circular Import

Build directed graph:

```text
consumer_module -> imported_module
```

Run deterministic DFS in sorted module order. On cycle, fail with `cycle_path`.

### Deterministic Ordering

- Sort source units by module path then source path.
- Sort imports by module path and selected names for graph validation.
- Preserve raw source for hashing; only validation/merge order is canonical.

---

## 6. Merged Universe Design

P3 should create one synthetic parsed source/universe after successful import
validation.

Recommended implementation:

1. Sort source units canonically.
2. Build a synthetic `SourceFile`.
3. Use synthetic module:

```text
__Igniter.Multifile.Universe
```

or another clearly internal label.

4. Concatenate top-level declarations into the synthetic parsed program:
   - `types`
   - `variants`
   - `functions`
   - `assumptions`
   - `profiles`
   - `size_relations`
   - `olap_points`
   - `contract_shapes`
   - `traits`
   - `impls`
   - `contracts`

5. Set synthetic `imports` to empty after validation.
6. Set `source_hash` to composite multi-file source hash.
7. Set `source_path` to an explicit synthetic label such as:

```text
multifile:<source_hash prefix16>
```

8. Preserve `source_units` as evidence metadata for emitter/manifest if P3
   chooses additive manifest support.

### Type Declarations

All imported and provider type declarations exist in the synthetic program so
the existing typechecker can build `type_shapes`.

Duplicate type names must fail before merge.

### Contracts

All contracts exist in the synthetic program so the Rust typechecker
`build_contract_registry` can resolve literal `call_contract("Name", ...)`.

Duplicate contract names must fail before merge.

### Contract Name Resolution

P3 v0 uses unqualified contract names after import validation. Qualified
contract references are not introduced.

Risk: two modules cannot both export `SharedName` in the same multi-file unit
until qualified names or visibility exist. This is acceptable for v0 and must
fail closed.

### Module Information Preservation

Each declaration should retain origin facts for diagnostics:

```text
declared_in_module
source_path
source_hash
```

If adding those fields to all declaration structs is too large for P3, the
resolver must at least keep an origin map used for diagnostics before merge and
include manifest `source_units`.

---

## 7. Identity Design

Composite multi-file `source_hash`:

```text
sha256(canonical_json([
  {
    "module": "<module path>",
    "source_path": "<source path>",
    "source_hash": "sha256:<single file hash>",
    "source": "<raw source text>"
  },
  ...
] sorted by module path then source path))
```

Rules:

- Input file order does not affect identity.
- Changing any source file changes identity.
- Comment-only changes affect raw-source identity.
- Module name is not content identity.
- Duplicate modules fail before hashing is accepted.
- `semanticir/<prefix16>` and `compilation_report/<prefix16>` derive from the
  composite `source_hash`.
- `contract_ref` remains per-contract.
- `artifact_hash` remains final assembled artifact identity.
- P2 `program_id` parity remains pass-local and does not become package,
  capability, or trust authority.

Recommended manifest evidence shape:

```json
"source_units": [
  {
    "module": "A.B",
    "source_path": "path/to/a.ig",
    "source_hash": "sha256:<64hex>",
    "types": ["QueryResult"],
    "contracts": ["BuildQueryResult"]
  }
]
```

`source_units` is evidence. It is not a package registry, visibility list, or
trust store.

---

## 8. Diagnostics Plan

### Namespace Finding

Planning found a blocker: `OOF-M1` and `OOF-M2` are already overloaded.

Observed current use:

- Rust classifier uses `OOF-M1` for pure/observed/irreversible modifier and
  authority-class errors.
- Rust assembler has an error string beginning `OOF-M1` for privileged
  contract/capability token mismatch.
- PROP-035 uses `OOF-M2/M4/M5` for capability/effect grammar.
- PROP-IMPORT-RESOLUTION-P1 wants `OOF-M1/M2/M3` for import/module diagnostics.

Therefore P3 must not add import diagnostics blindly under the same codes
without a supervisor decision.

### Planned Import Diagnostic Meanings

If governance accepts the P1 import diagnostic names as-is:

| Code | Meaning | Message template |
|---|---|---|
| `OOF-M1` | Circular import | `circular import detected: <cycle path>` |
| `OOF-M2` | Unknown module import | `unknown import path '<import_path>' from module '<module_path>'` |
| `OOF-M2` | Missing selective import name | `unknown import name '<name>' from '<import_path>'` |
| `OOF-M2` | Missing module declaration in multi-file unit | `missing module declaration in multi-file source unit '<source_path>'` |
| `OOF-M3` | Duplicate module declaration | `duplicate module declaration '<module_path>'` |

Required payload fields:

- `rule`
- `severity`
- `message`
- `node`
- `source_path`
- `module_path` when known
- `import_path` for import diagnostics
- `missing_name` for selective import failures
- `cycle_path` for cycles
- `conflict_paths` for duplicate modules

### Duplicate Declaration Candidate Codes

P2 recommends candidate codes that avoid further `OOF-M*` collision:

| Code | Meaning | Message template |
|---|---|---|
| `OOF-DECL-DUP-CONTRACT` | Duplicate contract name across compilation unit | `duplicate contract '<name>' across modules: <owners>` |
| `OOF-DECL-DUP-TYPE` | Duplicate type name across compilation unit | `duplicate type '<name>' across modules: <owners>` |
| `OOF-IMPORT-AMBIGUOUS-NAME` | Ambiguous unqualified name if qualified names are later introduced | `ambiguous imported name '<name>' from modules: <modules>` |

`OOF-IMPORT-AMBIGUOUS-NAME` is not needed if P3 rejects all duplicate names
globally before merge.

---

## 9. Authority / Capability Plan

Implementation must preserve:

```text
name availability != authority to execute
```

Required checks:

- Import validation only changes name availability.
- Imported declarations do not copy capability/profile bindings into consumer
  declarations.
- Pure consumer calling imported effect contract remains rejected by existing
  `call_contract` pure-callee gate.
- Fragment classification is derived from declaration contents, not import
  presence.
- Manifest `source_units` has no capability grants, package trust, or runtime
  authority fields.

Concrete Rust path:

- Merged universe includes imported effect contracts as normal declarations.
- Typechecker `call_contract` registry sees callee modifier.
- Existing non-pure callee check returns `OOF-TY0`.
- No resolver code should mutate contract modifiers or required capabilities.

---

## 10. Proof Matrix

P3 target: at least 65 checks, matching or exceeding LAB-MULTIFILE-COMPILATION-P1.

| Section | Planned checks |
|---|---:|
| P3-COMPILE | 8 |
| P3-IMPORT | 9 |
| P3-IDENTITY | 10 |
| P3-DIAGNOSTICS | 14 |
| P3-AUTHORITY | 8 |
| P3-MANIFEST | 6 |
| P3-REGRESSION | 10 |

Required cases:

- valid two-file compile;
- valid three-file compile;
- selective import;
- whole-module import;
- cross-file record type;
- cross-file literal `call_contract`;
- file order determinism;
- import order determinism;
- unknown import path;
- missing selective import name;
- circular import;
- duplicate module;
- duplicate contract;
- duplicate type;
- imported effect call from pure consumer;
- authority closed scan;
- single-file regression;
- existing compiler tests/regressions for classifier/typechecker/emitter;
- manifest contains composite `source_hash`;
- manifest `artifact_hash` remains distinct;
- `contract_ref` remains per-contract.

Proof runner options:

- Rust-first: `igniter-lab/igniter-view-engine/proofs/verify_prop_import_resolution_p3.rb`
  driving the Rust compiler binary.
- Ruby parity later: separate proof only if P3 scope explicitly includes Ruby
  `CompilerOrchestrator`.

---

## 11. Diff Plan

### Must Edit For Rust-Lab P3

| Path | Change | Rough size |
|---|---|---:|
| `igniter-lab/igniter-compiler/src/multifile.rs` | New source-unit inventory, module table, import graph, diagnostics, merge, composite hash | 250-450 LOC |
| `igniter-lab/igniter-compiler/src/lib.rs` | Export `multifile` module | 1-3 LOC |
| `igniter-lab/igniter-compiler/src/main.rs` | Parse N source inputs; call resolver; use composite source_hash/source_path; return pre-pass diagnostics | 80-180 LOC |
| `igniter-lab/igniter-compiler/src/emitter.rs` | Pass optional `source_units` into SemanticIR/report if chosen | 20-60 LOC |
| `igniter-lab/igniter-compiler/src/assembler.rs` | Add optional `source_units` to manifest/artifact material | 20-60 LOC |
| `igniter-lab/igniter-view-engine/fixtures/multifile_compilation_p3/` | Production-facing fixtures | 10-16 files |
| `igniter-lab/igniter-view-engine/proofs/verify_prop_import_resolution_p3.rb` | Proof matrix runner | 250-450 LOC |

### Maybe Edit

| Path | Reason |
|---|---|
| `igniter-lab/igniter-compiler/src/parser.rs` | Only if `SourceFile` carries `source_units`; otherwise keep parser unchanged |
| `igniter-lab/igniter-compiler/src/classifier.rs` | Only if origin facts need pass-through beyond existing `declared_in_module` patterns |
| `igniter-lab/igniter-compiler/src/typechecker.rs` | Message cleanup: "not found in compilation unit"; maybe origin facts in errors |
| `igniter-lab/igniter-compiler/src/form_registry.rs` | Only if form metadata needs per-source origin |
| `igniter-lang/lib/igniter_lang/multifile_resolver.rb` | Ruby parity implementation if explicitly scoped |
| `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb` | Ruby `compile_sources` if explicitly scoped |
| `igniter-lang/lib/igniter_lang/semanticir_emitter.rb` | Ruby source_units propagation if Ruby parity scoped |

### Must Not Edit In P3

- VM/runtime execution
- package registry/distribution
- visibility/public/internal/export semantics
- stdlib module contents
- capability/profile authority model
- loader trust model
- Ch2/Ch6 canon spec unless separately authorized as sync after proof

---

## 12. Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| OOF-M1/M2 namespace collision | Import diagnostics become ambiguous with existing modifier/effect diagnostics | Run P2a diagnostic namespace decision before P3 |
| Hidden global namespace leakage | Unimported sibling declarations become visible due to merge | Validate import graph and selected names before merge; add negative fixture for unimported sibling use |
| Order-dependent identity | Same source set hashes differently based on CLI order | Sort by module path then source path before hashing |
| Diagnostics without file/module facts | Multi-file failures become hard to debug | Require source_path/module_path/import_path/cycle_path/conflict_paths fields |
| Import grants accidental authority | Imported effect contract becomes callable from pure consumer | Preserve existing pure-callee gate; add authority negative proof |
| Over-merging modules into one flat namespace | Future visibility/qualified names get harder | Declare v0 global duplicate-name rejection; defer qualified names |
| `.igapp` manifest drift | `source_units` appears inconsistently or changes artifact hash unexpectedly | Add manifest checks and artifact hash distinction checks |
| Ruby/Rust divergence | Rust P3 works but Ruby canon path remains inert | Scope P3 Rust-lab-first or explicitly fund Ruby parity; do not claim parity without proof |
| CLI surface mistaken for stable API | N-file compile syntax treated as public | Label P3 CLI as experiment/proof surface until governance accepts public API |

---

## 13. Decision

Decision: **CONDITIONAL**.

Architecture is ready:

- parser shape is sufficient;
- compiler-driver pre-pass is the right location;
- merged logical universe can reuse existing classifier/typechecker paths;
- P1 proof runner already demonstrated the core behavior;
- identity and proof matrix are concrete.

Blocker before P3:

```text
OOF-M1 / OOF-M2 diagnostic namespace collision
```

P3 should not proceed until governance chooses one of:

1. accept overloaded `OOF-M1/M2` for import/module diagnostics;
2. rename import diagnostics to a non-colliding namespace;
3. reserve `OOF-M1/M2/M3` for import and migrate older modifier/effect uses.

Option 2 is the lowest-risk implementation path.

---

## 14. Exact Next Route

Recommended next route:

```text
PROP-IMPORT-RESOLUTION-P2A - diagnostic namespace cleanup / final code decision
```

Then:

```text
PROP-IMPORT-RESOLUTION-P3 - bounded Rust-lab implementation
```

P3 scope should be Rust-lab-first unless governance explicitly requires Ruby
canon parity in the same card.

Still deferred:

- package registry
- public/internal visibility
- stdlib-as-import
- runtime loading
- capability/profile import
- public/stable API

