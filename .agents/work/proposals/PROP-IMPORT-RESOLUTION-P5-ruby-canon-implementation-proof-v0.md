# PROP-IMPORT-RESOLUTION-P5: Ruby Canon Multi-File Import Implementation Proof

**Track:** ruby-canon-multifile-import-resolution-v0  
**Route:** IMPLEMENTATION / BOUNDED CANON PARITY  
**Authority:** bounded Ruby `igniter-lang` implementation only  
**Date:** 2026-06-11  
**Status:** CLOSED / PROVED  
**Predecessors:** PROP-IMPORT-RESOLUTION-P1/P2/P2A/P4; Rust-lab P3 evidence; PROP-ENTRYPOINT-P3

---

## 1. Authority Boundary

P5 implements the accepted import-resolution proposal chain in the Ruby canon
language repo. It is implementation authority only for the bounded internal Ruby
compiler pipeline.

Closed in P5:

- no VM changes;
- no runtime loading or dynamic imports;
- no package registry, package trust, distribution, semver, or trust store;
- no public/internal visibility system;
- no stdlib-as-import promotion;
- no Ruby `call_contract`;
- no capability/profile authority through import;
- no multi-source CLI behavior;
- no public/stable API claim.

Rust P3 remains lab evidence. P5 is the Ruby canon implementation proof.

---

## 2. Implemented Surface

P5 adds:

- `IgniterLang::MultifileResolver`
- internal `CompilerOrchestrator#compile_sources(source_paths:, out_path:, ...)`
- `source_units` propagation into SemanticIR, compilation report, and `.igapp`
  manifest
- `source_units` inclusion in artifact hash material when present
- bounded proof runner under `experiments/import_resolution_proof/`

P5 does not change:

- parser grammar;
- classifier/typechecker core behavior;
- SemanticIR emitter core shape;
- `IgniterLang.compile`;
- CLI `igc compile SOURCE --out OUT.igapp`;
- VM/runtime behavior.

---

## 3. Resolver Semantics

The resolver treats N `.ig` files as one logical compilation universe.

For each source unit it records:

- `source_path`
- `source_hash`
- module name
- declared imports
- declared type names
- declared contract names

Then it:

- requires module declarations in multi-file mode;
- builds a module table;
- validates whole-module imports;
- validates selective import names against target module declarations;
- detects import cycles;
- rejects duplicate module declarations;
- rejects duplicate contract/type declarations across the universe;
- computes a deterministic composite `source_hash`;
- merges declarations into a synthetic parsed program;
- clears imports after resolution.

The merged program uses:

```text
module: Igniter.Multifile.Universe
source_path: multifile:<source_hash_prefix16>
source_hash: sha256:<composite>
```

Import is compile-time name resolution only. It is not runtime loading, package
trust, execution permission, dependency injection, profile binding, or
capability authority.

---

## 4. Diagnostics

P5 uses the P2A namespace exactly:

| Code | Meaning |
|---|---|
| `OOF-IMP1` | circular import |
| `OOF-IMP2` | unknown module import |
| `OOF-IMP3` | missing selective import name |
| `OOF-IMP4` | duplicate module declaration |
| `OOF-IMP5` | missing module declaration in multi-file unit |
| `OOF-DECL-DUP-CONTRACT` | duplicate contract declaration |
| `OOF-DECL-DUP-TYPE` | duplicate type declaration |

The proof verifies that import diagnostics do not use old `OOF-M*` candidates.

Failure reports carry:

- `pass_result: "oof"`
- `stages.multifile_resolve: "oof"`
- skipped classify/typecheck/emit stages
- `source_units` evidence
- nil `semantic_ir_ref`

---

## 5. Identity Rules

Composite multi-file source identity is:

```text
sha256(canonical_json([
  { module, source_path, source_hash, source },
  ...
] sorted by module then source_path))
```

The proof verifies:

- file input order does not affect identity for the same source paths;
- replay with identical source paths produces identical `source_hash`,
  `artifact_hash`, and `source_units`;
- `source_units` are sorted deterministically by module;
- module label is not artifact identity;
- `artifact_hash` remains the final artifact identity.

Raw-source identity remains raw-source identity. Comment-only changes still
affect source identity unless a future semantic hash is separately authorized.

---

## 6. Entrypoint Coexistence

P5 coexists with PROP-ENTRYPOINT-P3.

The proof verifies:

- a multi-file universe may contain zero or one entrypoint;
- provider/library files may omit entrypoint;
- the entrypoint target resolves within the merged logical universe;
- manifest and SemanticIR entrypoint metadata are emitted;
- duplicate entrypoint declarations across the universe fail before classify.

Entrypoint remains metadata/evidence only. P5 adds no VM auto-run, CLI launch,
app framework, scheduler, or runtime selection behavior.

---

## 7. Proof Result

Proof runner:

```text
igniter-lang/experiments/import_resolution_proof/verify_prop_import_resolution_p5.rb
```

Result:

```text
PROP-IMPORT-RESOLUTION-P5 PASS (99/99)
```

Proof sections:

- `HAPPY` - 20 checks
- `IDENTITY` - 12 checks
- `DIAGNOSTICS` - 40 checks
- `ENTRYPOINT` - 6 checks
- `AUTHORITY` - 8 checks
- `SURFACE` - 13 checks

Regression proof:

```text
igniter-lang/experiments/entrypoint_descriptor_proof/verify_entrypoint_p3.rb
PROP-ENTRYPOINT-P3 PASS (53/53)
```

Additional available PROP-044 regressions:

```text
experiments/prop044_variant_match_parser_proof/verify_prop044_p3_parser.rb
50/50 PASS

experiments/prop044_variant_match_typechecker_proof/verify_prop044_p5_typechecker.rb
75/75 PASS

experiments/prop044_variant_match_semanticir_proof/verify_prop044_p6_semanticir.rb
50/50 PASS
```

---

## 8. Evidence Summary

P5 proves:

- two-file and three-file multi-source compilation;
- whole-module and selective import resolution;
- final `OOF-IMP*` diagnostics;
- duplicate declaration guards;
- deterministic replay;
- `source_units` in report, SemanticIR, and manifest;
- entrypoint coexistence;
- no import-derived capability/profile/package/runtime authority;
- no CLI/public facade widening.

Single-file behavior remains routed through the existing
`CompilerOrchestrator#compile(source_path:, out_path:, ...)` path.

---

## 9. Known Limits

Still not implemented:

- CLI multi-source input;
- public multi-file API;
- visibility/export rules;
- package registry/distribution;
- stdlib-as-import;
- qualified ambiguity policy beyond the current merged universe;
- Ruby `call_contract`;
- VM/runtime loading.

These are deliberately future routes, not P5 gaps.

---

## 10. Decision

**CLOSED / PROVED.**

P5 closes the Ruby canon import-resolution parity gap for bounded compiler
pipeline use. It does not open runtime, CLI, package, visibility, stdlib,
capability, profile, or public API authority.

Recommended next route:

```text
PROP-IMPORT-RESOLUTION-P6 - bounded CLI or driver policy decision
```

Alternative route:

```text
PROP-MODULE-VISIBILITY-P1 - visibility/export semantics on top of import substrate
```
