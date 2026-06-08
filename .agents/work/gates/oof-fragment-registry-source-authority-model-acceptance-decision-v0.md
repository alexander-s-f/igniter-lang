# OOF/Fragment Registry Source Authority Model Acceptance Decision

Status: accepted-proof-design-foundation-implementation-held-preconditions-design-next
Date: 2026-05-21
Card: LANG-R118-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: oof-fragment-registry-source-authority-model-acceptance-decision-v0
Depends on: LANG-R117-P1, LANG-R116-D1, LANG-R115-P1

---

## Decision

Accept the profile/pack source-authority model as a proof/design foundation.

Implementation remains held.

Accepted authority rules:

- pack-row authority is primary for row identity and row provenance;
- profile-level authority owns the selected pack set, pack order, and aggregate
  conflict policy;
- duplicate row ownership rejects the aggregate;
- profile-level authority cannot silently override pack-row conflicts;
- live helper behavior remains held for `profile_candidate` and
  `pack_descriptor_candidate`;
- `SOURCE_ACCEPTED_MODES` remains unchanged:

```text
proof_fixture caller_supplied
```

This decision accepts the model for design/proof use only. It does not authorize
live helper acceptance, profile/pack loading, compiler integration, public
surface exposure, report behavior, runtime behavior, specs, canon, or PROP
mutation.

---

## Evidence Read

- `igniter-lang/docs/tracks/oof-fragment-registry-profile-pack-source-mode-proof-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-source-authority-design-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-source-authority-precedence-proof-v0.md`
- `igniter-lang/experiments/oof_fragment_registry_profile_pack_source_mode_proof/out/oof_fragment_registry_profile_pack_source_mode_proof_summary.json`
- `igniter-lang/experiments/oof_fragment_registry_source_authority_precedence_proof/out/oof_fragment_registry_source_authority_precedence_proof_summary.json`

---

## Basis

R115 proves the proof-only profile/pack source-mode model:

- 9/9 cases PASS;
- 7/7 checks PASS;
- synthetic `profile_candidate` and `pack_descriptor_candidate` models are
  non-canon/proof-only;
- derived registry validates through the existing internal registry validator;
- duplicate OOF/fragment row ownership is rejected;
- `compiler_profile_contract.*` and
  `compiler_profile_contract_refusal.*` remain excluded from OOF rows/aliases;
- live helper still returns `held_source_mode` for both candidate modes.

R116 designs the correct authority split:

- pack-row authority owns row provenance and row identity;
- profile-level authority owns selection, ordering, aggregation, and conflict
  policy;
- profile-only authority is rejected because it hides row provenance;
- pack-row-only authority is rejected because it omits profile selection and
  aggregation.

R117 proves the precedence model:

- 9/9 cases PASS;
- 9/9 checks PASS;
- duplicate row ownership rejects the aggregate;
- profile override cannot hide pack-row conflict;
- missing selected pack refs reject aggregate;
- excluded namespaces remain rejected;
- live helper still holds both profile/pack candidate modes;
- `SOURCE_ACCEPTED_MODES` remains unchanged.

Local rerun of the R117 command chain also passed:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/experiments/oof_fragment_registry_source_authority_precedence_proof/oof_fragment_registry_source_authority_precedence_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_source_authority_precedence_proof/oof_fragment_registry_source_authority_precedence_proof.rb` | PASS: 9/9 cases, 9/9 checks |
| `ruby igniter-lang/experiments/oof_fragment_registry_profile_pack_source_mode_proof/oof_fragment_registry_profile_pack_source_mode_proof.rb` | PASS: 9/9 cases, 7/7 checks |
| `ruby igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/oof_fragment_registry_source_envelope_helper_proof.rb` | PASS: 9/9 cases, 10/10 checks |
| `ruby igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb` | PASS: 27/27 checks |

---

## Not Authorized

This decision does not authorize:

- implementation;
- changing `SOURCE_ACCEPTED_MODES`;
- accepting `profile_candidate` or `pack_descriptor_candidate` in the live
  helper;
- loader/report behavior;
- public API/CLI input or output;
- compiler integration;
- specs, canon, or proposals mutation;
- PROP-036 manifest/profile identity mutation;
- PROP-038 validator/report behavior mutation;
- `oof_fragment_registry_data.rb`;
- static registry constants;
- `lib/igniter_lang.rb` require changes;
- parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator,
  `CompilationReport`, `CompilerResult`, `CompatibilityReport`, diagnostics,
  or CLI changes;
- `.igapp`, `.ilk`, or golden mutation;
- runtime, production, cache, signing, Ledger/TBackend, Gate 3, or Spark
  behavior.

---

## Next Allowed Boundary

Card: LANG-R119-D1

Track:

```text
oof-fragment-registry-profile-pack-source-acceptance-preconditions-design-v0
```

Route: UPDATE

Mode: design-only

Goal:

Define the exact preconditions and blocker checklist for any future consideration
of accepting `profile_candidate` and `pack_descriptor_candidate` in the live
source-envelope helper.

Allowed write scope:

```text
igniter-lang/docs/tracks/oof-fragment-registry-profile-pack-source-acceptance-preconditions-design-v0.md
```

Required design questions:

- exact blockers before any future `SOURCE_ACCEPTED_MODES` change;
- whether candidate source acceptance would require a new helper result shape;
- minimum proof/design fields for pack descriptor schema;
- minimum proof/design fields for profile selected-pack order and conflict
  policy;
- authority-kind and canon-status limits for any future accepted modes;
- PROP-036 non-mutation conditions for profile identity and `.igapp`;
- PROP-038 non-mutation conditions for profile-contract validator/report
  behavior;
- Bridge review requirements before loader/report, public API/CLI, or
  CompatibilityReport are mentioned as anything beyond closed future candidates;
- parity matrix required before any implementation authorization review.

Forbidden actions for R119:

- no implementation;
- no changes to `SOURCE_ACCEPTED_MODES`;
- no edits to `igniter-lang/lib/`;
- no compiler integration;
- no profile/pack source loading;
- no public API/CLI;
- no loader/report or `CompatibilityReport`;
- no specs/canon/proposals or PROP mutation;
- no `.igapp`, runtime, production, or Spark behavior.

---

## Compact Summary

ACCEPT the source-authority model as proof/design foundation.

Pack rows own row identity/provenance. Profiles own selected pack set, order,
and conflict policy. Duplicate pack row ownership rejects the aggregate, and
profile-level policy cannot override that conflict.

Implementation remains held. The live helper still holds profile/pack candidate
modes, and `SOURCE_ACCEPTED_MODES` remains `proof_fixture caller_supplied`.

Next route is design-only:
`oof-fragment-registry-profile-pack-source-acceptance-preconditions-design-v0`.
