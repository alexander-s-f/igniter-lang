# Fragment Registry Compatibility Adapter Helper Boundary Proof Decision

Status: accepted-proof-implementation-authorization-review-next-implementation-held
Date: 2026-05-22
Card: S3-R146-C3-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: fragment-registry-compatibility-adapter-helper-boundary-proof-decision-v0
Depends on: S3-R146-C1-P1, S3-R146-C2-X

---

## Decision

Accept the proof-only internal helper boundary proof.

Authorize only an implementation-authorization review next:

```text
fragment-registry-compatibility-adapter-helper-implementation-authorization-review-v0
```

Implementation is not authorized by this decision.

The review may decide whether a later direct-require-only internal helper slice
is warranted, but must not write the helper itself. All compiler, artifact,
public, runtime, Spark, and production surfaces remain closed unless a later
gate explicitly and narrowly opens them.

---

## Evidence Read

- `igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-internal-helper-boundary-proof-v0.md`
- `igniter-lang/docs/discussions/fragment-registry-compatibility-adapter-helper-boundary-pressure-v0.md`
- `igniter-lang/docs/gates/fragment-registry-adapter-implementation-boundary-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round145-status-curation-v0.md`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/helper_input_shape.json`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/helper_result_shape.json`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/fragment_registry_compatibility_adapter_internal_helper_boundary_summary.json`

---

## Acceptance Findings

### Proof-Local Files Created

The accepted proof created only the proof-local files allowed by R145:

```text
igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-internal-helper-boundary-proof-v0.md
igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/fragment_registry_compatibility_adapter_internal_helper_boundary_proof.rb
igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/helper_input_shape.json
igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/helper_result_shape.json
igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/fragment_registry_compatibility_adapter_internal_helper_boundary_summary.json
```

C2 pressure review verified all five files are inside the R145 authorized write
scope. No `lib/` file was created or edited.

### Helper Input And Result Shape

The helper boundary shape is accepted as proof/design evidence only.

Input status:

- `kind`: `fragment_registry_compatibility_adapter_helper_input`
- `format_version`: `0.1.0`
- `boundary_mode`: `proof_only_internal_helper`
- `direct_require_only_if_later_implemented`: `true`
- `classifier_wiring_authorized`: `false`
- contract rows carry `contract_ref`, `declaration_fragment_presence`, and
  `current_selected_fragment`;
- `olap` and `progression` remain guarded non-fragment classes;
- OOF projection remains status-primary, blocked, non-loadable, and
  non-capability.

Result status:

- `kind`: `fragment_registry_compatibility_adapter_helper_result`
- `format_version`: `0.1.0`
- `boundary_mode`: `proof_only_internal_helper`
- `held_live_dispatch`: `true`
- `classifier_wiring_authorized`: `false`
- `selected_fragment_projection.rows` is internal proof evidence only;
- `selected_fragment_projection.mismatches` is empty.

This shape is not a `ClassifiedProgram` schema change, not report output, not
artifact metadata, and not compiler input.

### R144 Compatibility Preservation

R144 compatibility preservation is accepted.

Evidence:

- source R144 matrix digest:
  `65e876f5ae23ce761c16b704`;
- observed contract count: 23;
- selected-fragment mismatches: none;
- stream presence still selects `escape`;
- epistemic plus escape still selects `escape`;
- epistemic-only still selects `epistemic`;
- temporal plus escape still selects `temporal`;
- OOF remains status-primary, blocked, non-loadable, and non-capability;
- `olap` and `progression` remain guarded non-fragments.

C2 verified the proof re-derived selected fragments from presence data rather
than copying R144 output by reference.

### Negative Scan Status

Negative scans are accepted as sufficient for this proof-only boundary.

All C1 scans passed with no hits for helper vocabulary or
`declaration_fragment_presence` in:

- `igniter-lang/lib/igniter_lang.rb`;
- `igniter-lang/lib/igniter_lang/classifier.rb`;
- `igniter-lang/lib/igniter_lang/compilation_report.rb`;
- `igniter-lang/lib/igniter_lang/assembler.rb`;
- `igniter-lang/lib/igniter_lang/cli.rb`;
- `igniter-lang/lib/igniter_lang/temporal_executor.rb`;
- `igniter-lang/experiments/sparkcrm_bihistory_fixture/sparkcrm_bihistory_fixture.rb`.

Future implementation review must broaden this scan across all
`igniter-lang/lib/igniter_lang/*.rb` files for `declaration_fragment_presence`
and helper vocabulary.

### Command Matrix Result

Accepted command matrix:

| Command | Result |
| --- | --- |
| `ruby igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/fragment_registry_compatibility_adapter_internal_helper_boundary_proof.rb` | PASS |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS |
| `ruby igniter-lang/experiments/contract_modifiers_proof/contract_modifiers_proof.rb` | PASS |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS |
| `ruby -c igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/fragment_registry_compatibility_adapter_internal_helper_boundary_proof.rb` | Syntax OK |

Proof runner summary:

```text
status: PASS
check_count: 19
failed_checks: []
helper_input_digest: 47e938fdea0e46e067a2c88b
helper_result_digest: ae26685d3afd77a2e2cc35c5
recommendation: ACCEPT_PROOF_ONLY_HELPER_BOUNDARY_HOLD_IMPLEMENTATION
```

### No-Lib / No-Root-Require / No-Classifier-Wiring Status

Accepted as preserved:

- no `lib/` helper file exists from this proof;
- no root require was added;
- no classifier wiring was added;
- no live classifier dispatch was opened;
- no `contract_fragment_for` replacement was made;
- no `ClassifiedProgram` schema change was made.

---

## C2 Pressure Notes Carried Forward

The pressure review has no blockers for accepting C1, but it adds two
requirements for any implementation-authorization review:

- closed-surface assertions must become dynamic filesystem checks if a future
  card writes a `lib/` helper file;
- `assumptions_proof` must be added to the future regression matrix because it
  is the living golden anchor for the epistemic plus escape case.

The implementation-authorization review must also answer whether the C1
`helper_result_shape.json` is the exact API surface to implement or whether
field names/shape may be refined. If refinement is allowed, the review must
require an explicit delta-from-C1 step before code is written.

---

## Next Allowed Boundary

Card: S3-R147-C1-A

Track:

```text
fragment-registry-compatibility-adapter-helper-implementation-authorization-review-v0
```

Route: UPDATE

Mode: authorization review only

Goal:

Decide whether to authorize a later bounded direct-require-only internal helper
implementation for the fragment registry compatibility adapter.

The review may authorize, hold, redirect, or reject a later implementation
card. It may not implement the helper.

Required read set:

- `igniter-lang/docs/gates/fragment-registry-adapter-implementation-boundary-decision-v0.md`
- `igniter-lang/docs/gates/fragment-registry-compatibility-adapter-helper-boundary-proof-decision-v0.md`
- `igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-internal-helper-boundary-proof-v0.md`
- `igniter-lang/docs/discussions/fragment-registry-compatibility-adapter-helper-boundary-pressure-v0.md`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/helper_input_shape.json`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/helper_result_shape.json`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_internal_helper_boundary_proof/out/fragment_registry_compatibility_adapter_internal_helper_boundary_summary.json`

Required review decisions:

- exact write scope for any later implementation card;
- whether a `lib/igniter_lang/fragment_registry_compatibility_adapter.rb`
  helper file may be created;
- direct-require-only stance, with no root require from `lib/igniter_lang.rb`;
- explicit prohibition on classifier wiring for the first implementation slice;
- internal-only helper result shape and whether C1 shape is exact or may be
  refined;
- dynamic closed-surface checks for `lib/` helper existence;
- byte-for-byte classifier parity assertion counts;
- expanded regression matrix including `assumptions_proof`;
- broad negative vocabulary scan across `igniter-lang/lib/igniter_lang/*.rb`;
- PROP-036 and PROP-038 non-mutation assertions.

Candidate implementation write scope, if later authorized by that review:

```text
igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/**
igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-helper-implementation-proof-v0.md
```

The authorization review may narrow this scope further. It may not broaden into
root require, classifier wiring, reports, artifacts, runtime, Spark, or
production.

Required future implementation proof matrix, if authorized:

| Command | Required Result |
| --- | --- |
| `ruby igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/fragment_registry_compatibility_adapter_helper_implementation_proof.rb` | PASS |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS with pinned assertion count |
| `ruby igniter-lang/experiments/contract_modifiers_proof/contract_modifiers_proof.rb` | PASS with pinned assertion count |
| `ruby igniter-lang/experiments/assumptions_proof/assumptions_proof.rb` | PASS with pinned assertion count |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS |
| TypeChecker proof, if applicable to touched paths | PASS |
| `ruby igniter-lang/experiments/invariant_severity_proof/invariant_severity_proof.rb` | PASS |

---

## Closed Surfaces

This decision does not authorize:

- implementation;
- `lib/` helper file creation;
- root require;
- classifier wiring or live classifier dispatch;
- `contract_fragment_for` replacement;
- parser, TypeChecker, SemanticIR, assembler, or `.igapp` edits;
- `ClassifiedProgram` schema changes;
- public API/CLI widening;
- loader/report;
- `CompilationReport`, `CompilerResult`, or CompatibilityReport changes;
- `.igapp`, `.ilk`, manifest, sidecar, artifact hash, or golden mutation;
- PROP-036 or PROP-038 mutation;
- runtime, Spark, production, Ledger/TBackend, BiHistory, stream/OLAP, cache,
  signing, or deployment behavior.

---

## Compact Summary

ACCEPT the proof-only internal helper boundary.

R146 proves the helper input/result boundary with 19 checks, preserves R144
selected-fragment compatibility across 23 contracts, passes the required
regression matrix, and keeps `lib/`, root require, classifier wiring, reports,
artifacts, runtime, Spark, and production closed.

Next route is authorization-review only:
`fragment-registry-compatibility-adapter-helper-implementation-authorization-review-v0`.
