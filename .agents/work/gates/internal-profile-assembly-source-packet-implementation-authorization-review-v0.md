# Internal Profile-Assembly Source Packet Implementation Authorization Review

Status: authorized-bounded-internal-profile-assembly-source-packet
Date: 2026-05-21
Card: LANG-R128-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: internal-profile-assembly-source-packet-implementation-authorization-review-v0
Depends on: LANG-R127-X, LANG-R126-D1, LANG-R125-P1

---

## Decision

Authorize a bounded internal-only implementation for an internal
profile-assembly source packet based on the R125 proof model.

This authorization opens only an internal constructor/test seam. It does not
make the packet a compiler input, public API/CLI input, loader/report carrier,
CompatibilityReport carrier, `.igapp`/manifest field, PROP-036 identity source,
PROP-038 authority, runtime input, production behavior, or Spark surface.

Use this wording for carrier scope:

```text
internal profile-assembly source packet
```

Reserve `compiler_profile_oof_registry_source_input` for the exact packet kind
inside internal code/proofs only.

---

## Evidence Read

- `igniter-lang/docs/tracks/oof-fragment-registry-compiler-profile-source-input-proof-v0.md`
- `igniter-lang/docs/tracks/compiler-profile-source-input-lifecycle-owner-design-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-source-input-lifecycle-bridge-pressure-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-compiler-profile-source-input-design-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-profile-pack-source-proof-refresh-v0.md`

Local verification:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/experiments/oof_fragment_registry_compiler_profile_source_input_proof/oof_fragment_registry_compiler_profile_source_input_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_compiler_profile_source_input_proof/oof_fragment_registry_compiler_profile_source_input_proof.rb` | PASS: 9/9 cases, 6/6 checks |

---

## Basis

R125 proves a proof-only source packet:

```text
compiler_profile_oof_registry_source_input
  -> profile_candidate helper envelope
  -> pack_descriptor_candidate helper envelopes
  -> IgniterLang::OOFFragmentRegistry#validate_source_envelope
```

R125 result:

```text
PASS
cases: 9/9
checks: 6/6
recommendation: SOURCE_INPUT_MODEL_ACCEPTED
```

R126 selects the lifecycle owner model:

```text
hybrid profile assembly owner
```

Meaning:

- CompilerPack descriptor finalization owns row provenance and pack-local row
  claims.
- CompilerProfile candidate finalization owns selected pack set, pack order,
  and aggregate conflict policy.
- Hybrid profile assembly owns the internal profile-assembly source packet that
  binds those authorities and maps them to helper envelopes.

R127 pressure returns:

```text
proceed-with-nonblockers
```

No blocker amendments are required. R127 NB-1 and NB-2 are accepted as wording
requirements in this authorization.

---

## R127 Wording Amendments

NB-1:

Use "internal profile-assembly source packet" when discussing carrier scope.
Avoid "source input" as public-facing shorthand.

NB-2:

`finalized_internal` is an internal profile-assembly lifecycle state only.

Definition:

```text
finalized_internal = internal profile-assembly object accepted by a future
implementation gate; it is not compiler_profile_id_source, does not produce
compiler_profile_id, and is not manifest/profile identity finalization.
```

`finalized_internal` is not PROP-036 profile finalization, not manifest identity,
not public profile finalization, not loader/report status, and not runtime or
production readiness.

---

## Exact Implementation Card Boundary

Card: LANG-R129-I1

Agent: `[Igniter-Lang Compiler/Grammar Expert]`

Role: compiler-grammar-expert

Route: UPDATE

Track:

```text
internal-profile-assembly-source-packet-implementation-v0
```

Goal:

Implement and prove an internal profile-assembly source packet object that can
carry the R125 packet model, map it to OOF/Fragment Registry helper envelopes,
and validate through `IgniterLang::OOFFragmentRegistry` from a proof harness.

Allowed write scope:

```text
igniter-lang/lib/igniter_lang/internal_profile_assembly_source_packet.rb
igniter-lang/experiments/internal_profile_assembly_source_packet_proof/**
igniter-lang/docs/tracks/internal-profile-assembly-source-packet-implementation-v0.md
```

No other files may be edited.

---

## Internal Constructor/Test Seam Shape

The implementation may introduce an internal class or module under
`IgniterLang`, with a name matching the file, for example:

```ruby
IgniterLang::InternalProfileAssemblySourcePacket
```

Allowed internal constructor shape:

```ruby
IgniterLang::InternalProfileAssemblySourcePacket.build(
  authority:,
  profile_candidate:,
  pack_descriptor_candidates:,
  lifecycle_state: "implementation_candidate",
  closed_surface_assertions: {}
)
```

Allowed internal instance methods:

```ruby
#to_h
#to_helper_envelopes
#validate_with(registry_validator:)
#lifecycle_state
```

Rules:

- proof harnesses may direct-require the new internal file;
- the new file must not be required from `igniter-lang/lib/igniter_lang.rb`;
- parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator must not use
  the packet;
- no public caller-facing constructor is authorized;
- no path loading, manifest reading, loader/report reading, or runtime state
  lookup is authorized.

---

## Lifecycle State Wording

Allowed lifecycle states for this slice:

| State | Meaning |
| --- | --- |
| `implementation_candidate` | Internal packet object under the LANG-R129-I1 proof/implementation boundary. |
| `finalized_internal` | Internal profile-assembly validation result after the packet maps to helper envelopes and passes internal validation. |

Forbidden interpretations:

- not PROP-036 `compiler_profile_id_source`;
- not `compiler_profile_id`;
- not `.igapp/manifest.json`;
- not public profile identity;
- not profile discovery/defaulting/finalization;
- not loader/report status;
- not CompatibilityReport readiness;
- not runtime or production readiness.

---

## No Public Carrier Stance

The internal profile-assembly source packet has no public carrier.

Closed carriers:

- public API/Ruby facade;
- CLI;
- loader/report;
- CompatibilityReport;
- `.igapp`, `.ilk`, manifest, sidecar, or golden artifacts;
- PROP-036 profile identity or manifest carrier;
- PROP-038 validator/report/refusal carrier;
- parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator;
- runtime, production, Spark, Ledger/TBackend, Gate 3, cache, signing.

---

## Proof Matrix

The implementation card must record PASS for:

| Command | Required Result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_assembly_source_packet.rb` | PASS |
| `ruby igniter-lang/experiments/internal_profile_assembly_source_packet_proof/internal_profile_assembly_source_packet_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_compiler_profile_source_input_proof/oof_fragment_registry_compiler_profile_source_input_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_profile_pack_source_acceptance_proof/oof_fragment_registry_profile_pack_source_acceptance_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_profile_pack_source_mode_proof/oof_fragment_registry_profile_pack_source_mode_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_source_authority_precedence_proof/oof_fragment_registry_source_authority_precedence_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/oof_fragment_registry_source_envelope_helper_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/oof_fragment_registry.rb` | PASS |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS |
| `ruby igniter-lang/experiments/typechecker_proof/typechecker_proof.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |

Required proof assertions:

- packet kind maps deterministically to helper envelopes;
- constructor/test seam is internal-only;
- `finalized_internal` is internal assembly state only;
- `igniter-lang/lib/igniter_lang.rb` does not require the new file;
- current compiler pipeline files do not require or reference the packet;
- no public API/CLI, loader/report, CompatibilityReport, `.igapp`, PROP-036,
  PROP-038, runtime, production, or Spark surface changes.

---

## Not Authorized

This decision does not authorize:

- public API/CLI;
- loader/report;
- CompatibilityReport;
- `.igapp`, `.ilk`, manifest, sidecar, or golden mutation;
- PROP-036 mutation;
- PROP-038 mutation;
- parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator usage;
- `CompilationReport`, `CompilerResult`, diagnostics, or CLI changes;
- `igniter-lang/lib/igniter_lang.rb` edits;
- `oof_fragment_registry_data.rb`;
- runtime, production, Spark, Ledger/TBackend, Gate 3, cache, or signing.

---

## Acceptance Conditions

The LANG-R129-I1 implementation may be accepted only if:

- all writes stay inside the authorized scope;
- R127 NB-1/NB-2 wording is used in the proof track;
- lifecycle states remain internal profile-assembly states only;
- proof matrix passes;
- no public carrier appears;
- no compiler pipeline file consumes the packet;
- protected surfaces remain closed.

---

## Compact Summary

AUTHORIZED: bounded internal-only implementation for an internal
profile-assembly source packet.

Exact write scope is one internal lib file, one proof experiment folder, and one
track file.

No public API/CLI, loader/report, CompatibilityReport, `.igapp`, PROP-036,
PROP-038, compiler-pipeline, runtime, production, Spark, Ledger/TBackend, or
Gate 3 behavior is authorized.
