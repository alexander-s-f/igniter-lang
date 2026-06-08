# Internal Profile Assembly Boundary Implementation Authorization Review

Status: authorized-bounded-internal-profile-assembly-boundary
Date: 2026-05-22
Card: LANG-R132-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: internal-profile-assembly-boundary-implementation-authorization-review-v0
Depends on: LANG-R131-P1, LANG-R130-D1, LANG-R129-I1

---

## Decision

Authorize a tiny internal-only implementation for an internal profile assembly
boundary object/result around `IgniterLang::InternalProfileAssemblySourcePacket`.

This opens only an internal object and proof harness. It does not connect the
packet or result to the current compiler pipeline, public carriers, reports,
artifacts, runtime, production, or Spark.

---

## Evidence Read

- `igniter-lang/docs/tracks/internal-profile-assembly-source-packet-implementation-v0.md`
- `igniter-lang/docs/tracks/internal-profile-assembly-boundary-design-v0.md`
- `igniter-lang/docs/tracks/internal-profile-assembly-boundary-proof-v0.md`
- `igniter-lang/lib/igniter_lang/internal_profile_assembly_source_packet.rb`
- `igniter-lang/experiments/internal_profile_assembly_boundary_proof/out/internal_profile_assembly_boundary_proof_summary.json`

Local verification:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/experiments/internal_profile_assembly_boundary_proof/internal_profile_assembly_boundary_proof.rb` | PASS |
| `ruby igniter-lang/experiments/internal_profile_assembly_boundary_proof/internal_profile_assembly_boundary_proof.rb` | PASS: 6/6 cases, 5/5 checks |
| `ruby igniter-lang/experiments/internal_profile_assembly_source_packet_proof/internal_profile_assembly_source_packet_proof.rb` | PASS: 6/6 cases, 5/5 checks |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_assembly_source_packet.rb` | PASS |

---

## Basis

R129 implemented `IgniterLang::InternalProfileAssemblySourcePacket` as an
internal constructor/test seam. It is not root-required and is not consumed by
parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator.

R130 designed a proof-only internal profile assembly boundary that consumes the
packet and `IgniterLang::OOFFragmentRegistry`, then returns an internal
`internal_profile_assembly_result`.

R131 proved that boundary/result shape:

- 6/6 cases PASS;
- 5/5 checks PASS;
- valid packet produces `finalized_internal`;
- invalid authority, missing selected pack, duplicate row ownership, and
  excluded namespace claims remain invalid and do not finalize;
- root require remains closed;
- no new lib assembly boundary file exists yet;
- public/report/runtime/manifest/PROP surfaces remain closed.

That is enough to implement the tiny internal boundary object, but not enough to
connect it to compiler passes, reports, artifacts, public APIs, runtime, or
production.

---

## Exact Implementation Card Boundary

Card: LANG-R133-I1

Agent: `[Igniter-Lang Compiler/Grammar Expert]`

Role: compiler-grammar-expert

Route: UPDATE

Track:

```text
internal-profile-assembly-boundary-implementation-v0
```

Goal:

Implement and prove an internal profile assembly boundary object/result around
`IgniterLang::InternalProfileAssemblySourcePacket`.

Allowed write scope:

```text
igniter-lang/lib/igniter_lang/internal_profile_assembly.rb
igniter-lang/experiments/internal_profile_assembly_boundary_implementation_proof/**
igniter-lang/docs/tracks/internal-profile-assembly-boundary-implementation-v0.md
```

No other files may be edited.

---

## Internal Class Name

Authorized internal class/module name:

```ruby
IgniterLang::InternalProfileAssembly
```

The implementation must not add a root require from:

```text
igniter-lang/lib/igniter_lang.rb
```

Proof harnesses may direct-require the new internal file.

---

## Constructor/Test Seam

Allowed constructor/test seam:

```ruby
IgniterLang::InternalProfileAssembly.assemble(
  source_packet:,
  registry_validator: IgniterLang::OOFFragmentRegistry.new
)
```

Alternative object form is allowed only if it preserves the same internal-only
inputs and result:

```ruby
IgniterLang::InternalProfileAssembly.new(
  source_packet:,
  registry_validator:
).assemble
```

Rules:

- `source_packet` must be an `InternalProfileAssemblySourcePacket`-compatible
  internal object;
- `registry_validator` must be supplied internally or default to
  `IgniterLang::OOFFragmentRegistry.new`;
- no file/path/manifest/loader/report/runtime lookup is authorized;
- no public caller-facing constructor is authorized.

---

## Result Shape

The implementation must return an internal hash or value object equivalent to:

```json
{
  "kind": "internal_profile_assembly_result",
  "format_version": "0.1.0",
  "valid": true,
  "lifecycle_state": "finalized_internal",
  "input_lifecycle_state": "implementation_candidate",
  "packet_kind": "compiler_profile_oof_registry_source_input",
  "packet_digest": "sha256-prefix",
  "helper_envelopes_digest": "sha256-prefix",
  "profile_validation": {},
  "pack_descriptor_validations": [],
  "diagnostics": [],
  "finalized_internal_meaning": "internal assembly state only; not PROP-036 finalization, not compiler_profile_id, and not manifest/profile identity",
  "closed_surface_assertions": {
    "root_require": false,
    "compiler_pipeline_usage": false,
    "public_api_cli": false,
    "loader_report": false,
    "compatibility_report": false,
    "igapp_mutation": false,
    "manifest_mutation": false,
    "prop036_mutation": false,
    "prop038_mutation": false,
    "runtime_behavior": false,
    "production_behavior": false,
    "spark_surface": false
  }
}
```

Result rules:

- `valid: true` only if packet mapping and helper validation pass;
- invalid packet/authority/conflict cases must not finalize;
- diagnostics remain internal assembly diagnostics only;
- packet and helper-envelope digests are determinism evidence only, not manifest
  identity;
- result must not be persisted, reported, assembled, or exposed publicly.

---

## Lifecycle States

Allowed lifecycle states:

| State | Meaning |
| --- | --- |
| `implementation_candidate` | Input packet lifecycle state before successful assembly. |
| `finalized_internal` | Internal assembly result state after packet mapping and helper validation pass. |

Forbidden meanings for `finalized_internal`:

- not PROP-036 finalization;
- not `compiler_profile_id`;
- not `compiler_profile_id_source`;
- not manifest/profile identity;
- not loader/report status;
- not CompatibilityReport readiness;
- not runtime or production readiness.

---

## Proof Matrix

The implementation card must record PASS for:

| Command | Required Result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_assembly.rb` | PASS |
| `ruby igniter-lang/experiments/internal_profile_assembly_boundary_implementation_proof/internal_profile_assembly_boundary_implementation_proof.rb` | PASS |
| `ruby igniter-lang/experiments/internal_profile_assembly_boundary_proof/internal_profile_assembly_boundary_proof.rb` | PASS |
| `ruby igniter-lang/experiments/internal_profile_assembly_source_packet_proof/internal_profile_assembly_source_packet_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_compiler_profile_source_input_proof/oof_fragment_registry_compiler_profile_source_input_proof.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_assembly_source_packet.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/oof_fragment_registry.rb` | PASS |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS |
| `ruby igniter-lang/experiments/typechecker_proof/typechecker_proof.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |

Required proof assertions:

- no root require from `igniter-lang/lib/igniter_lang.rb`;
- no parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator usage;
- no public API/CLI;
- no loader/report;
- no CompatibilityReport;
- no `.igapp`, manifest, sidecar, or golden mutation;
- no PROP-036 or PROP-038 mutation;
- no runtime, production, or Spark behavior.

---

## Not Authorized

This decision does not authorize:

- root require from `igniter-lang/lib/igniter_lang.rb`;
- parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator usage;
- `CompilationReport`, `CompilerResult`, diagnostics, or CLI changes;
- public API/CLI;
- loader/report;
- CompatibilityReport;
- `.igapp`, `.ilk`, manifest, sidecar, or golden mutation;
- PROP-036 mutation;
- PROP-038 mutation;
- `oof_fragment_registry_data.rb`;
- runtime, production, Spark, Ledger/TBackend, Gate 3, cache, or signing.

---

## Acceptance Conditions

The LANG-R133-I1 implementation may be accepted only if:

- all writes stay inside the authorized scope;
- class name is `IgniterLang::InternalProfileAssembly`;
- result shape matches the R131 internal result family;
- lifecycle states remain internal-only;
- proof matrix passes;
- protected surfaces remain closed.

---

## Compact Summary

AUTHORIZED: tiny internal profile assembly boundary implementation.

Exact write scope is one internal lib file, one proof experiment folder, and one
track file.

No root require, compiler pipeline usage, public API/CLI, loader/report,
CompatibilityReport, `.igapp`/manifest, PROP-036/PROP-038, runtime, production,
or Spark behavior is authorized.
