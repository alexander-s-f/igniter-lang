# OOF/Fragment Registry Profile/Pack Source Acceptance Authorization Review

Status: authorized-bounded-profile-pack-source-acceptance-helper-slice
Date: 2026-05-21
Card: LANG-R121-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: oof-fragment-registry-profile-pack-source-acceptance-authorization-review-v0
Depends on: LANG-R120-X, LANG-R119-D1, LANG-R118-A

---

## Decision

Authorize the smallest coherent bounded live-helper implementation slice for
profile/pack source acceptance.

The authorized mode transition is exact:

```text
Move from SOURCE_HELD_MODES to SOURCE_ACCEPTED_MODES:
  profile_candidate
  pack_descriptor_candidate

Remain accepted:
  proof_fixture
  caller_supplied
```

Both modes are authorized together because the accepted R118 authority model is
paired: pack descriptors own row provenance, while profiles own selected pack
set, order, and conflict policy. Authorizing only `pack_descriptor_candidate`
would not prove aggregate profile authority, and authorizing only
`profile_candidate` would require pack-descriptor semantics implicitly. This
decision keeps the slice small by limiting all work to the existing internal
helper boundary.

Implementation is authorized only for the card boundary below. No compiler,
public, report, loader, CompatibilityReport, `.igapp`, PROP, runtime,
production, or Spark surface is opened.

---

## Evidence Read

- `igniter-lang/docs/gates/oof-fragment-registry-source-authority-model-acceptance-decision-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-profile-pack-source-acceptance-preconditions-design-v0.md`
- `igniter-lang/docs/discussions/oof-fragment-registry-profile-pack-source-acceptance-bridge-pressure-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-source-authority-precedence-proof-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-source-authority-design-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-profile-pack-source-mode-proof-v0.md`
- `igniter-lang/lib/igniter_lang/oof_fragment_registry.rb`

Pre-authorization invariant was checked locally:

```text
SOURCE_ACCEPTED_MODES = proof_fixture caller_supplied
SOURCE_HELD_MODES     = profile_candidate pack_descriptor_candidate
```

---

## Basis

R118 accepted the profile/pack source-authority model as proof/design
foundation, with implementation held.

R119 defined the blocker checklist for future live-helper acceptance:

- exact mode transition must be named by Architect gate;
- result shape must remain internal-only;
- pack descriptor and profile candidate schemas must be proof-covered;
- authority limits must remain bounded;
- PROP-036 and PROP-038 surfaces must not mutate;
- Bridge review is required before public/report/compatibility surfaces move
  beyond closed future candidates;
- parity matrix must pass before acceptance.

R120 pressure found no blockers and returned:

```text
proceed-with-nonblockers
```

R120 NB-1 and NB-2 are accepted as wording requirements inside this decision.

NB-1 wording clarification:

```text
If this Architect gate accepts `profile_candidate` or
`pack_descriptor_candidate`, that acceptance does not require a new public helper
result family.
```

NB-2 wording clarification:

```text
Pre-authorization review assertion:
SOURCE_ACCEPTED_MODES remains unchanged.

Post-authorization implementation proof assertion:
SOURCE_ACCEPTED_MODES changed only inside the named authorized implementation
card and only for the modes named by that gate.
```

---

## Exact Implementation Card Boundary

Card: LANG-R122-I1

Agent: `[Igniter-Lang Compiler/Grammar Expert]`

Role: compiler-grammar-expert

Route: UPDATE

Track:

```text
oof-fragment-registry-profile-pack-source-acceptance-proof-v0
```

Goal:

Implement and prove internal-only live-helper acceptance for
`profile_candidate` and `pack_descriptor_candidate` source envelopes inside
`IgniterLang::OOFFragmentRegistry`.

Allowed write scope:

```text
igniter-lang/lib/igniter_lang/oof_fragment_registry.rb
igniter-lang/experiments/oof_fragment_registry_profile_pack_source_acceptance_proof/**
igniter-lang/docs/tracks/oof-fragment-registry-profile-pack-source-acceptance-proof-v0.md
```

No other files may be edited by the implementation card.

---

## Implementation Requirements

The implementation must:

- move exactly `profile_candidate` and `pack_descriptor_candidate` from
  `SOURCE_HELD_MODES` to `SOURCE_ACCEPTED_MODES`;
- keep `proof_fixture` and `caller_supplied` accepted;
- keep all helper behavior internal to `OOFFragmentRegistry`;
- validate source authority before nested registry validation;
- preserve pack-row authority as primary for row identity and provenance;
- preserve profile-level authority for selected pack set, selected pack order,
  and aggregate conflict policy;
- reject duplicate OOF descriptor, fragment row, support marker, and alias
  ownership before aggregate registry validation;
- reject missing selected pack refs;
- reject excluded namespace claims;
- reject profile attempts to override pack-row ownership conflicts;
- keep all closed-surface assertions false.

The implementation must not load profile or pack sources from disk, manifests,
CLI args, public API inputs, loader/report data, or runtime state. All accepted
candidate envelopes are internal caller-supplied hashes handled by direct helper
calls only.

---

## Internal-Only Result Shape

No new public helper result family is authorized.

The result family remains:

```text
kind: oof_fragment_registry_source_validation
```

For `profile_candidate` and `pack_descriptor_candidate`, the helper may add only
internal fields under the existing source validation result, such as:

```text
source_authority
source_diagnostics
registry_validation
closed_surface_assertions
```

Rules:

- diagnostics stay under the source-envelope helper result;
- no top-level compiler/report diagnostics;
- no public API/CLI result keys;
- no `.igapp`, sidecar, loader report, or CompatibilityReport writes;
- `registry_validation` is null when source authority or aggregation fails;
- for `profile_candidate`, nested registry validation runs only after selected
  pack aggregation passes;
- for `pack_descriptor_candidate`, nested registry validation may remain null
  unless the proof explicitly supplies a complete registry-shaped envelope.

---

## Authority Limits

Accepted authority values for this slice:

| Field | Allowed | Forbidden |
| --- | --- | --- |
| `authority_kind` | `proof_only`, `design_accepted` | `runtime`, `loader`, `public_api`, `manifest`, `canon`, `production` |
| `canon_status` | `non_canon`, `accepted_design` | `canon`, `implemented_canon`, `production_canon` |

`accepted_design` is still internal design status only. It is not spec canon,
not public authority, not manifest authority, not loader/report authority, and
not runtime/production authority.

---

## Proof Matrix

The implementation card must record PASS for:

| Command | Required Result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/oof_fragment_registry.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_profile_pack_source_acceptance_proof/oof_fragment_registry_profile_pack_source_acceptance_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_source_authority_precedence_proof/oof_fragment_registry_source_authority_precedence_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_profile_pack_source_mode_proof/oof_fragment_registry_profile_pack_source_mode_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/oof_fragment_registry_source_envelope_helper_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb` | PASS |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS |
| `ruby igniter-lang/experiments/typechecker_proof/typechecker_proof.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |

Required implementation proof assertions:

- pre-authorization invariant recorded:
  `SOURCE_ACCEPTED_MODES` was unchanged before LANG-R121-A;
- post-authorization assertion:
  `SOURCE_ACCEPTED_MODES` changed only inside LANG-R122-I1 and only for
  `profile_candidate` and `pack_descriptor_candidate`;
- `SOURCE_HELD_MODES` no longer contains those two modes after implementation;
- no other source mode is accepted;
- public/report/runtime/compatibility/manifest/PROP surfaces remain closed;
- helper result shape remains internal-only;
- no compiler pass uses the helper.

---

## Not Authorized

This decision does not authorize:

- public API/CLI;
- loader/report behavior;
- `CompatibilityReport` behavior;
- `.igapp`, `.ilk`, manifest, sidecar, or golden mutation;
- PROP-036 mutation;
- PROP-038 mutation;
- compiler integration;
- parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator,
  `CompilationReport`, `CompilerResult`, diagnostics, or CLI changes;
- `oof_fragment_registry_data.rb`;
- static registry constants;
- `lib/igniter_lang.rb` require changes;
- separate helper/source files;
- runtime, production, cache, signing, Ledger/TBackend, Gate 3, or Spark
  behavior.

---

## Acceptance Conditions

The LANG-R122-I1 implementation slice may be accepted only if:

- all writes stay inside the authorized scope;
- both and only the named modes move from held to accepted;
- R120 NB-1/NB-2 wording is reflected in the proof track;
- authority-kind and canon-status limits are enforced;
- R118 pack/profile authority precedence is machine-proven after implementation;
- the full proof matrix passes;
- no protected surface opens.

---

## Compact Summary

AUTHORIZED: bounded internal helper implementation for both
`profile_candidate` and `pack_descriptor_candidate`.

Exact write scope is limited to `oof_fragment_registry.rb`, one new proof
experiment folder, and one proof track.

No public API/CLI, loader/report, CompatibilityReport, `.igapp`, PROP-036,
PROP-038, compiler integration, runtime, production, or Spark behavior is
authorized.
