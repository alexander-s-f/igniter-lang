# Fragment Registry Compatibility Adapter Helper Implementation Authorization Review

Status: authorized-bounded-direct-require-helper-implementation
Date: 2026-05-22
Card: S3-R147-C1-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: fragment-registry-compatibility-adapter-helper-implementation-authorization-review-v0
Depends on: S3-R146-C3-A

---

## Decision

Authorize a bounded implementation card for a direct-require-only internal
fragment registry compatibility adapter helper.

This authorization opens only the next implementation/proof route:

```text
fragment-registry-compatibility-adapter-helper-implementation-proof-v0
```

No implementation is performed by this decision.

The authorized implementation must create only an internal helper and proof
harness. It must not wire the helper into the live classifier, root require, any
compiler pass, report, artifact, public API, runtime, Spark, or production path.

---

## Evidence Read

- `igniter-lang/docs/gates/fragment-registry-adapter-implementation-boundary-decision-v0.md`
- `igniter-lang/docs/gates/fragment-registry-compatibility-adapter-helper-boundary-proof-decision-v0.md`
- `igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-internal-helper-boundary-proof-v0.md`
- `igniter-lang/docs/discussions/fragment-registry-compatibility-adapter-helper-boundary-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round146-status-curation-v0.md`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/helper_input_shape.json`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/helper_result_shape.json`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/fragment_registry_compatibility_adapter_internal_helper_boundary_summary.json`

---

## Authorization Basis

R146 provides enough proof evidence for a narrow implementation slice:

- proof runner status: PASS;
- check count: 19;
- failed checks: none;
- helper input digest: `47e938fdea0e46e067a2c88b`;
- helper result digest: `ae26685d3afd77a2e2cc35c5`;
- source R144 matrix digest: `65e876f5ae23ce761c16b704`;
- observed contract count: 23;
- selected-fragment mismatches: none;
- C2 pressure checks: 7/7 PASS;
- no `lib/`, root require, classifier wiring, report, artifact, runtime, Spark,
  or production drift was accepted.

C2's two implementation-review notes are accepted as mandatory implementation
proof requirements:

- closed-surface assertions must become dynamic checks for the created helper
  file and root require state;
- `assumptions_proof` must be included in the regression matrix.

---

## Exact Implementation Boundary

Card: S3-R147-C2-I

Track:

```text
fragment-registry-compatibility-adapter-helper-implementation-proof-v0
```

Route: UPDATE

Mode: bounded implementation plus proof

Goal:

Create a direct-require-only internal helper for fragment registry compatibility
adapter projection, with proof that it preserves R144 selected-fragment
compatibility while remaining unwired from live classifier dispatch and all
public/report/artifact/runtime surfaces.

Authorized write scope:

```text
igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/**
igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-helper-implementation-proof-v0.md
```

No other files may be edited.

The helper file may be created:

```text
igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb
```

The helper must be direct-require-only. It must not be required from
`igniter-lang/lib/igniter_lang.rb`.

---

## Helper API Shape

The implementation must preserve the R146 C1 helper shape as the exact first
slice API. It may not refine field names or result structure during this
implementation card.

Input shape:

```text
kind: fragment_registry_compatibility_adapter_helper_input
format_version: 0.1.0
contracts[].contract_ref
contracts[].declaration_fragment_presence
contracts[].current_selected_fragment
guarded_non_fragments[]
oof_projection_policy
classifier_wiring_authorized: false
```

Result shape:

```text
kind: fragment_registry_compatibility_adapter_helper_result
format_version: 0.1.0
selected_fragment_projection.rows[]
selected_fragment_projection.mismatches[]
guarded_non_fragments[]
oof_projection_policy
r144_parity
held_live_dispatch: true
classifier_wiring_authorized: false
```

Allowed Ruby API form:

```text
IgniterLang::FragmentRegistryCompatibilityAdapter.project(input_hash) -> result_hash
```

The method name may be `project` only. Any different method name, class/module
name, field name, or return shape requires a separate explicit delta review
before code is written.

The helper result remains internal-only. It must not become:

- a `ClassifiedProgram` field;
- compiler input;
- report output;
- CLI/API output;
- `.igapp`, manifest, sidecar, or artifact metadata.

---

## Selection Rules

The helper must implement only the R146 proof selection order:

```text
if oof present:       selected = oof
elsif temporal:       selected = temporal
elsif escape:         selected = escape
elsif stream:         selected = escape
elsif epistemic:      selected = epistemic
else:                 selected = core
```

Required compatibility cases:

- stream presence still selects `escape`;
- epistemic plus escape still selects `escape`;
- epistemic-only still selects `epistemic`;
- temporal plus escape still selects `temporal`;
- OOF remains status-primary, blocked, non-loadable, and non-capability;
- `olap` and `progression` remain guarded non-fragments;
- 23/23 R144 observed contracts preserve current selected fragment;
- selected-fragment mismatches remain empty.

---

## Dynamic Closed-Surface Checks

The implementation proof must dynamically assert:

- helper file exists at the authorized path;
- `igniter-lang/lib/igniter_lang.rb` does not require the helper;
- `igniter-lang/lib/igniter_lang/classifier.rb` does not reference the helper;
- no classifier wiring exists;
- no live classifier dispatch exists;
- no parser, TypeChecker, SemanticIR, assembler, report, `.igapp`, public
  API/CLI, runtime, Spark, or production file changed;
- no `ClassifiedProgram` schema field was added;
- no `CompilationReport`, `CompilerResult`, loader/report, or
  CompatibilityReport output was changed;
- no PROP-036 or PROP-038 mutation occurred.

The proof may not hardcode these closed-surface checks as static `false` values
when a filesystem or content scan can verify them.

---

## Regression Matrix

The implementation card must run and record this matrix:

| Command | Required Result |
| --- | --- |
| `ruby igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/fragment_registry_compatibility_adapter_helper_implementation_proof.rb` | PASS; implementation proof check count pinned by the card |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS; 21 named checks |
| `ruby igniter-lang/experiments/contract_modifiers_proof/contract_modifiers_proof.rb` | PASS; 20 named checks |
| `ruby igniter-lang/experiments/assumptions_proof/assumptions_proof.rb` | PASS; 39 named checks |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS; 31 named checks |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS; 17 named checks |
| TypeChecker proof, if applicable to touched paths | PASS; pinned count required if run |
| `ruby igniter-lang/experiments/invariant_severity_proof/invariant_severity_proof.rb` | PASS; 34 named checks |

The implementation proof must also record byte-for-byte parity evidence for
classifier, contract-modifier, assumptions, SemanticIR, and `.igapp` artifacts.
If any listed proof command only regenerates outputs in its default mode, the
implementation proof harness must perform the byte-for-byte comparison itself
and record the compared paths and digests.

---

## Broad Negative Vocabulary Scan

The implementation proof must scan every file matching:

```text
igniter-lang/lib/igniter_lang/*.rb
```

Required forbidden terms outside the authorized helper file:

```text
fragment_registry_compatibility_adapter
FragmentRegistryCompatibilityAdapter
declaration_fragment_presence
selected_fragment_projection
```

Expected result:

```text
no hits outside igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb
```

Additional targeted negative scans must cover:

- `igniter-lang/lib/igniter_lang.rb`;
- `igniter-lang/lib/igniter_lang/classifier.rb`;
- `igniter-lang/lib/igniter_lang/compilation_report.rb`;
- `igniter-lang/lib/igniter_lang/assembler.rb`;
- `igniter-lang/lib/igniter_lang/cli.rb`;
- runtime-facing files under `igniter-lang/lib/igniter_lang/`;
- Spark-facing experiments.

---

## Proof Artifact Policy

The implementation card may create proof artifacts only under:

```text
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/**
```

The proof track must record:

- helper input fixture used by the proof;
- helper result output;
- summary JSON;
- digests for input, result, and summary;
- command matrix output;
- dynamic closed-surface checks;
- broad negative scan result;
- byte-for-byte parity evidence.

Golden mutation policy:

- no existing golden may be changed;
- no `.igapp` golden may be changed;
- no source-to-SemanticIR golden may be changed;
- no classifier/contract-modifier/assumptions golden may be changed;
- proof-local generated outputs may be new only inside the authorized
  implementation proof experiment directory.

---

## Not Authorized

This decision does not authorize:

- any edit outside the exact write scope;
- root require from `igniter-lang/lib/igniter_lang.rb`;
- classifier wiring or live classifier dispatch;
- `contract_fragment_for` replacement;
- parser, classifier, TypeChecker, SemanticIR, assembler, report, or `.igapp`
  edits;
- `ClassifiedProgram` schema changes;
- public API/CLI widening;
- loader/report;
- `CompilationReport`, `CompilerResult`, or CompatibilityReport changes;
- `.igapp`, `.ilk`, manifest, sidecar, artifact hash, or golden mutation;
- PROP-036 or PROP-038 mutation;
- runtime, Spark, production, Ledger/TBackend, BiHistory, stream/OLAP, cache,
  signing, or deployment behavior.

Classifier wiring and live classifier dispatch remain explicitly forbidden for
the first implementation slice. A separate later gate is required to consider
any classifier wiring.

---

## Compact Summary

AUTHORIZE bounded implementation next.

The next card may create only
`igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb`,
the implementation proof experiment, and the proof track. The helper is
direct-require-only, root-require forbidden, classifier wiring forbidden, and
the R146 C1 API shape is exact for this slice.

All public, compiler-pipeline, report, artifact, runtime, Spark, production,
PROP-036, and PROP-038 surfaces remain closed.
