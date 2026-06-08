# OOF/Fragment Registry Implementation Authorization Review v0

Card: LANG-R102-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: oof-fragment-registry-implementation-authorization-review-v0
Status: authorized-bounded-internal-validator-proof-slice
Date: 2026-05-21

---

## Decision

Authorize the first bounded OOF/Fragment Registry implementation slice:

```text
authorized-bounded-internal-validator-proof-slice
```

This authorization is limited to an isolated internal registry validator and
proof-local boundary/parity harness.

This decision does not authorize compiler integration, public registry
behavior, spec/canon mutation, public API/CLI, reports, `.igapp`, runtime,
production, or Spark surfaces.

---

## Evidence Read

- `igniter-lang/docs/tracks/oof-fragment-registry-implementation-boundary-design-v0.md`
- `igniter-lang/docs/discussions/oof-fragment-registry-implementation-boundary-pressure-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-authorization-blocker-closure-design-v0.md`
- `igniter-lang/docs/gates/pinv-tinv-lifecycle-classification-acceptance-decision-v0.md`

---

## Authorization Basis

R99 designed a first implementation boundary but held implementation.

R100 pressure passed the R99 boundary and left 9 blockers before authorization
review.

R101 closed or routed those blockers enough for this exact first slice:

- exact first-slice write scope is pinned;
- `oof_fragment_registry_data.rb` is explicitly out;
- `support_markers.invariant_support_markers` are in the first-slice schema;
- R92 historical JSON is not migrated or rewritten;
- validation result shape is internal-only;
- absent-owner inactive-row proof case is required;
- source-authority rules are restated for gate acceptance;
- `OOF registry service` remains kernel/support vocabulary;
- exact 8-command minimum proof matrix is pinned.

Architect accepts those R101 closure decisions for this first slice.

---

## Authorized Write Scope

Only these paths are authorized:

```text
lib/igniter_lang/oof_fragment_registry.rb
experiments/oof_fragment_registry_implementation_boundary_proof/**
docs/tracks/oof-fragment-registry-implementation-boundary-proof-v0.md
```

Authorized purposes:

| Path | Authorized purpose |
| --- | --- |
| `lib/igniter_lang/oof_fragment_registry.rb` | Internal pure validator for supplied registry hashes. |
| `experiments/oof_fragment_registry_implementation_boundary_proof/**` | Proof-local fixtures, proof runner, proof outputs, inactive-row proof, and closed-surface assertions. |
| `docs/tracks/oof-fragment-registry-implementation-boundary-proof-v0.md` | Implementation/proof handoff and command matrix results. |

No other file path is authorized.

---

## Explicitly Out Of Scope

The following path is explicitly out of this first slice:

```text
lib/igniter_lang/oof_fragment_registry_data.rb
```

Do not create it, edit it, require it, or simulate it as part of this first
slice.

Also out of scope:

- `lib/igniter_lang.rb`;
- parser, classifier, TypeChecker, SemanticIR emitter, assembler, orchestrator,
  compilation report, compiler result, CLI;
- `docs/spec/`;
- `docs/proposals/`;
- existing `.igapp` outputs or goldens;
- loader/report, CompatibilityReport, RuntimeMachine, production code;
- Spark fixture/spec/data/code surfaces.

---

## Required Implementation Boundary

The first slice must remain:

```text
isolated internal validator library
+ proof-local boundary/parity harness
+ proof track
```

It must not:

- require the validator from `lib/igniter_lang.rb`;
- integrate with compiler passes;
- emit public diagnostics;
- write top-level `report["diagnostics"]`;
- add a `CompilerResult` field;
- expose public API/CLI;
- add loader/report or CompatibilityReport fields;
- mutate `.igapp`, `.ilk`, goldens, specs, proposals, or canon;
- call runtime, Ledger/TBackend, Gate 3, cache, signing, deployment, or
  production behavior.

---

## Required Registry Shape

The proof-local first slice must validate the R101 forward bucket shape:

```json
{
  "kind": "oof_fragment_registry",
  "format_version": "0.1.0",
  "source_authority": {},
  "oof_descriptors": [],
  "fragment_rows": [],
  "support_markers": {
    "invariant_support_markers": []
  },
  "excluded_namespaces": []
}
```

Binding constraints:

- `PINV-*` / `TINV-*` may appear only under
  `support_markers.invariant_support_markers`;
- support markers must not appear in `oof_descriptors`;
- support markers must not be OOF aliases;
- support markers must be non-public and non-emitted;
- support marker codes must not collide with public OOF descriptor codes;
- `compiler_profile_contract.*` and
  `compiler_profile_contract_refusal.*` remain excluded namespaces;
- `olap` and `progression` remain guarded non-fragment surfaces;
- `oof` remains status-primary / secondary fragment projection, blocked,
  non-loadable, status-only, and capability-free;
- implementation code cannot promote lifecycle state by itself.

---

## R92 Historical JSON

R92 historical JSON must not be migrated or rewritten.

The first slice may read it as historical comparison evidence, but the forward
shape must live in new proof-local fixtures under:

```text
experiments/oof_fragment_registry_implementation_boundary_proof/
```

The proof must state that R92's older placement of `PINV-*` / `TINV-*` in
`oof_descriptors.shadow_registry.json` is historical proof evidence only, not
the forward live-registry shape.

---

## Required Proof Cases

The proof-local harness must include at minimum:

- valid forward-shape registry;
- duplicate OOF descriptor code rejection;
- alias collision / missing replacement / candidate replacement rejection;
- `PINV-*` / `TINV-*` support marker separation;
- support marker public/emitted rejection;
- excluded namespace descriptor/alias rejection;
- `oof` projection loadable/capability/status-primary guard cases;
- `olap` / `progression` guarded non-fragment rejection cases;
- absent-owner inactive-row case covering:
  - OOF descriptors;
  - fragment rows;
  - support markers;
- closed-surface assertions for compiler integration, public API/CLI,
  report diagnostics, CompilerResult field, loader/report,
  CompatibilityReport, runtime behavior, and `.igapp` mutation.

The absent-owner case must assert inactive rows are recorded, not silently
skipped.

---

## Pinned Proof Matrix

The implementation card must run and record all 8 commands exactly:

| Command | Required reason |
| --- | --- |
| `ruby -c lib/igniter_lang/oof_fragment_registry.rb` | Syntax check isolated internal library. |
| `ruby experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb` | Registry validation, support-marker separation, inactive-row, and closed-surface proof. |
| `ruby experiments/classifier_pass_proof/classifier_pass_proof.rb` | Classifier parity; no OOF classification drift. |
| `ruby experiments/typechecker_proof/typechecker_proof.rb --check-golden` | TypeChecker golden parity. |
| `ruby experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | Source-to-SemanticIR and CompilationReport golden parity. |
| `ruby experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | `.igapp` assembler parity. |
| `ruby experiments/invariant_severity_proof/invariant_severity_proof.rb` | Invariant OOF parity and `PINV-*` / `TINV-*` non-emission. |
| `ruby experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PROP-038 diagnostic separation and report-only nested field parity. |

This matrix is a floor. If the implementation touches any file outside the
authorized write scope, the implementation is out of scope and must stop unless
a new Architect decision widens the boundary.

---

## Exact Implementation Card Boundary

```text
Card: LANG-R103-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Route: UPDATE
Track: oof-fragment-registry-implementation-boundary-proof-v0

Goal:
Implement the first bounded OOF/Fragment Registry slice as an isolated internal
validator plus proof-local boundary/parity harness.

Authorized write scope:
- lib/igniter_lang/oof_fragment_registry.rb
- experiments/oof_fragment_registry_implementation_boundary_proof/**
- docs/tracks/oof-fragment-registry-implementation-boundary-proof-v0.md

Explicitly forbidden:
- lib/igniter_lang/oof_fragment_registry_data.rb
- lib/igniter_lang.rb
- parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator/report/result/CLI
- docs/spec/
- docs/proposals/
- existing `.igapp` outputs or goldens
- loader/report, CompatibilityReport, runtime, Gate 3, Ledger/TBackend, cache,
  signing, production, Spark fixture/spec/data/code surfaces

Requirements:
- internal pure validator only;
- no compiler integration;
- no public API/CLI;
- no public diagnostics;
- no report/CompilerResult/CompatibilityReport fields;
- support_markers.invariant_support_markers in the proof shape;
- PINV/TINV support metadata separation;
- R92 JSON non-migration note;
- absent-owner inactive-row proof case;
- run and record the pinned 8-command proof matrix.

Deliver:
- implementation track at
  igniter-lang/docs/tracks/oof-fragment-registry-implementation-boundary-proof-v0.md
- proof summary under
  igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/out/
- command matrix results
- changed-files list
- closed-surface assertions
```

---

## Preserved Closed Surfaces

This decision does not authorize:

- `oof_fragment_registry_data.rb`;
- compiler integration;
- specs, proposals, or canon edits;
- parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator,
  report, `CompilerResult`, or CLI behavior changes;
- public diagnostic renames, promotions, aliases, or wording changes;
- public API/CLI widening;
- loader/report or CompatibilityReport changes;
- `.igapp`, `.ilk`, or golden mutation;
- live pack registry or dispatch;
- RuntimeMachine or Gate 3 widening;
- Ledger/TBackend, BiHistory, stream/OLAP production executors;
- cache, signing, deployment, or production behavior;
- Spark fixture/spec/data/code work or Spark production integration.

---

## Compact Summary

```text
Decision: authorize first bounded implementation slice.
Scope: lib/igniter_lang/oof_fragment_registry.rb +
  experiments/oof_fragment_registry_implementation_boundary_proof/** +
  docs/tracks/oof-fragment-registry-implementation-boundary-proof-v0.md.
Explicitly out: lib/igniter_lang/oof_fragment_registry_data.rb.
Required: pinned 8-command proof matrix.
Closed: compiler integration, specs/canon, public API/CLI, reports, `.igapp`,
  runtime, production, Spark surfaces.
```

