# Fragment Registry Adapter Implementation Boundary Decision

Status: accepted-design-proof-route-next-implementation-held
Date: 2026-05-22
Card: S3-R145-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Route: UPDATE
Track: fragment-registry-adapter-implementation-boundary-decision-v0
Depends on: S3-R145-C1-P1, S3-R145-C2-P1, S3-R145-C3-X

---

## Decision

Accept the fragment registry adapter implementation boundary design as
design/proof evidence.

Implementation remains held.

Authorize only the next proof/design route:

```text
fragment-registry-compatibility-adapter-internal-helper-boundary-proof-v0
```

No live classifier dispatch, classifier wiring, parser, TypeChecker,
SemanticIR, assembler, `.igapp`, public API/CLI, loader/report,
CompatibilityReport, runtime, Spark, production, Ledger/TBackend, BiHistory,
stream/OLAP, cache, or signing behavior opens from this decision.

---

## Evidence Read

- `igniter-lang/docs/tracks/fragment-registry-adapter-implementation-boundary-design-v0.md`
- `igniter-lang/docs/tracks/fragment-registry-adapter-evidence-and-risk-map-v0.md`
- `igniter-lang/docs/discussions/fragment-registry-adapter-boundary-pressure-v0.md`
- `igniter-lang/docs/tracks/fragment-precedence-compatibility-adapter-proof-v0.md`
- `igniter-lang/experiments/fragment_precedence_compatibility_adapter_proof/out/fragment_precedence_compatibility_adapter_summary.json`

Local verification:

| Command | Result |
| --- | --- |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS |

---

## Answers

### Adapter Ownership

Selected-fragment compatibility semantics are classifier-local.

More precisely:

- declaration-fragment vocabulary and rows may be owned by pack-as-owner
  vocabulary and/or the fragment registry service;
- the service identity wording should be "fragment registry service", not
  `FragmentRegistryPack`;
- `FragmentRegistryPack`, if used at all, means pack-as-owner vocabulary rows,
  not a new optional language pack or service identity;
- registry data can provide rows and presence vocabulary, but selected-fragment
  compatibility is semantic adapter logic, not plain registry data;
- profile/pack metadata may reference proof evidence or digests, but must not
  execute selected-fragment dispatch;
- report-local ownership is rejected.

### Live Classifier Dispatch

Live classifier dispatch remains held.

No `Classifier` wiring, no `contract_fragment_for` replacement, and no
`classified_contract` schema changes are authorized.

### Selected-Fragment Compatibility Invariants

The selected-fragment compatibility invariants are sufficient as proof/design
foundation:

- stream presence may be recorded while selected fragment remains `escape`;
- epistemic plus escape may record epistemic presence while selected fragment
  remains `escape`;
- epistemic-only remains `epistemic`;
- temporal plus escape remains `temporal`;
- OOF remains status-primary, blocked, non-loadable, and non-capability;
- `olap` and `progression` remain guarded non-fragments;
- 23/23 observed classifier goldens preserve current selected `fragment_class`.

They are not sufficient to authorize implementation or live dispatch yet.

### SemanticIR / Report / `.igapp` Parity

SemanticIR/report/`.igapp` parity work may not open next as a mutation route.

Those surfaces remain closed. Future implementation authorization, if ever
opened, may require SemanticIR/report/`.igapp` parity as negative regression
evidence or as an explicit delta proof, but no SemanticIR/report/`.igapp`
carrier or artifact mutation is authorized by this decision.

### Implementation

Implementation must wait.

The next route is proof/design only and must resolve the helper boundary and
proof matrix before any implementation authorization can be considered.

---

## R145 Pressure Notes Resolved

### NB-1: `FragmentRegistryPack` Vocabulary

Resolved as:

```text
pack-as-owner vocabulary rows: allowed wording
fragment registry service identity: use "fragment registry service"
optional language pack named FragmentRegistryPack: not authorized
```

### NB-2: First-Slice Surface Divergence

Resolved for the next route as:

```text
proof/design-only internal helper boundary
```

This is not registry-data-only implementation and not classifier-adjacent live
implementation. It models the direct-require-only helper boundary and result in
an experiment before any lib file can be opened.

### NB-3: Classifier-Parity Scope For Non-Wired Helpers

The next route and any later implementation review must include classifier
regression even if the helper remains unwired. The purpose is to prove no
load-path side effect, shared state, or accidental require changes classifier
behavior.

---

## Next Allowed Boundary

Card: S3-R146-P1

Track:

```text
fragment-registry-compatibility-adapter-internal-helper-boundary-proof-v0
```

Route: UPDATE

Mode: proof/design only

Goal:

Model the direct-require-only internal helper API/result boundary for the
fragment registry compatibility adapter without creating a lib helper file or
wiring the classifier.

Allowed write scope:

```text
igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/**
igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-internal-helper-boundary-proof-v0.md
```

Required proof/design questions:

- exact proof-only helper input shape;
- exact proof-only helper result shape;
- declaration-fragment presence representation;
- selected-fragment compatibility projection preserving R144;
- explicit statement that helper is direct-require-only if later implemented;
- explicit statement that classifier wiring is forbidden for the next
  implementation candidate unless a later gate opens it;
- negative scans for root require, classifier wiring, report, `.igapp`, public,
  runtime, and Spark surfaces;
- full classifier regression even though no live helper is wired.

Required proof commands:

| Command | Required Result |
| --- | --- |
| `ruby igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/fragment_registry_compatibility_adapter_internal_helper_boundary_proof.rb` | PASS |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS |
| `ruby igniter-lang/experiments/contract_modifiers_proof/contract_modifiers_proof.rb` | PASS |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS |

No lib, classifier, parser, TypeChecker, SemanticIR, assembler, report, `.igapp`,
or public files may be edited in this route.

---

## Not Authorized

This decision does not authorize:

- implementation;
- live classifier dispatch;
- `Classifier` edits or `contract_fragment_for` replacement;
- parser, TypeChecker, SemanticIR, assembler, or `.igapp` edits;
- `classified_contract` schema changes;
- declaration-fragment presence in `ClassifiedProgram`;
- public diagnostics;
- public API/CLI widening;
- loader/report;
- `CompilationReport`, `CompilerResult`, or CompatibilityReport changes;
- `.igapp`, `.ilk`, manifest, sidecar, artifact hash, or golden mutation;
- PROP-036 or PROP-038 mutation;
- runtime, Spark, production, Ledger/TBackend, BiHistory, stream/OLAP, cache,
  signing, or deployment behavior.

---

## Compact Summary

ACCEPT design as proof/design foundation.

Ownership: selected-fragment compatibility is classifier-local; registry data
owns vocabulary/presence rows, profile/pack may reference proof evidence, and
reports do not own adapter semantics.

Implementation remains held. Next route is proof/design only:
`fragment-registry-compatibility-adapter-internal-helper-boundary-proof-v0`.
