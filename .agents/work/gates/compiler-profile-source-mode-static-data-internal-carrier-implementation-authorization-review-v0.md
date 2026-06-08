# Compiler Profile Source-Mode Static-Data Internal Carrier Implementation Authorization Review v0

Card: S3-R154-C1-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: compiler-profile-source-mode-static-data-internal-carrier-implementation-authorization-review-v0
Depends on: S3-R153-C3-A, S3-R153-C4-S
Status: authorized-bounded-internal-carrier-implementation
Date: 2026-05-23

---

## Decision

Authorize a smallest bounded internal-only implementation slice for a
source-mode/static-data internal carrier test seam.

The implementation may create a direct-require-only internal carrier class that
wraps caller-supplied internal static-data hashes and maps them into the already
accepted `IgniterLang::InternalProfileAssemblySourcePacket` shape.

This authorization does not authorize compiler pipeline integration, shared
fixtures, generated indexes, embedded registry data, public discovery,
loader/report behavior, manifest/artifact behavior, runtime behavior, Spark
behavior, production behavior, or demo work.

---

## Evidence Read

- `igniter-lang/docs/gates/compiler-profile-source-mode-static-data-boundary-proof-decision-v0.md`
- `igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-boundary-proof-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-source-mode-static-data-boundary-proof-pressure-v0.md`
- `igniter-lang/docs/gates/compiler-profile-source-mode-static-data-boundary-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round153-status-curation-v0.md`
- `igniter-lang/experiments/compiler_profile_source_mode_static_data_boundary_proof/out/compiler_profile_source_mode_static_data_boundary_proof_summary.json`
- `igniter-lang/lib/igniter_lang/internal_profile_assembly_source_packet.rb`
- `igniter-lang/lib/igniter_lang/internal_profile_assembly.rb`
- `igniter-lang/lib/igniter_lang/oof_fragment_registry.rb`

---

## Authorization Basis

R153 is sufficient to consider a bounded implementation slice.

Accepted R153 evidence shows:

- synthetic proof-local data exercised a non-trivial shape;
- `profile_candidate` and `pack_descriptor_candidate` mapped to internal
  profile-assembly source packet semantics;
- pack-row and profile-level authority were preserved;
- duplicate ownership rejected aggregate assembly before `finalized_internal`;
- `finalized_internal` remained internal-only;
- PROP-036 negative scan was accepted for forbidden payload fields;
- PROP-038 and adapter helper boundaries remained preserved;
- key compiler pipeline files were live-scanned clean;
- proof runner passed 16/16 checks.

The missing implementation piece is not a compiler feature. It is only a small
internal carrier/test seam that removes proof-runner-only ad hoc construction of
static-data carrier hashes.

---

## Explicit Answers

| Question | Decision answer |
| --- | --- |
| Is R153 proof sufficient to consider a bounded implementation slice? | Yes, for the exact internal carrier/test seam below only. It is not sufficient for compiler integration, public/report/artifact surfaces, shared fixtures, generated indexes, runtime, Spark, production, or demo behavior. |
| What internal carrier/test seam is being considered? | `IgniterLang::InternalProfileStaticDataCarrier`, a direct-require-only internal class that accepts an internal static-data hash and can build an `InternalProfileAssemblySourcePacket`. |
| Is this compiler pipeline integration? | No. The future implementation is source-mode/static-data carrier behavior only. Parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator, reports, artifacts, runtime, and production remain closed. |
| Does static data remain synthetic/internal-only? | Yes. The class may carry caller-supplied internal data for tests/proofs only. It must not embed static registry rows, create shared fixtures, create generated indexes, read files, discover profiles, load manifests, write reports, or become runtime authority. |
| Does `finalized_internal` remain internal-only? | Yes. The carrier must not produce `finalized_internal` directly. Only existing internal assembly may produce that lifecycle state, and it remains not PROP-036 identity, not manifest identity, not public finalization, and not runtime/production readiness. |
| Do PROP-036/PROP-038 remain unmodified inputs? | Yes. No PROP-036 or PROP-038 docs, proposals, code paths, public surfaces, report behavior, strict-refusal behavior, or runtime authority may change. |
| Does adapter helper evidence remain proof-local/direct-require only? | Yes. Adapter helper evidence remains prior proof evidence only. The carrier must not require or call `FragmentRegistryCompatibilityAdapter`. |
| Is Portfolio review satisfied? | S3-R154-C1-A satisfies the Portfolio/Lang checkpoint for the exact future implementation card below only. Any widening beyond that boundary requires a fresh Portfolio-visible review. |

---

## Exact Future Implementation Boundary

Future implementation card:

```text
Card: S3-R154-C2-I
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: compiler-profile-source-mode-static-data-internal-carrier-implementation-v0
Route: UPDATE
Mode: bounded internal implementation
```

Goal:

Implement and prove a direct-require-only internal carrier/test seam for
source-mode/static-data hashes, mapping them into
`IgniterLang::InternalProfileAssemblySourcePacket` without compiler pipeline,
public/report/artifact, runtime, Spark, production, or demo integration.

Allowed write scope:

```text
igniter-lang/lib/igniter_lang/internal_profile_static_data_carrier.rb
igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/**
igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-internal-carrier-implementation-v0.md
```

No other files may be edited by S3-R154-C2-I.

---

## Internal Class / File Shape

Authorized file:

```text
igniter-lang/lib/igniter_lang/internal_profile_static_data_carrier.rb
```

Authorized class:

```ruby
IgniterLang::InternalProfileStaticDataCarrier
```

The file must not be required from:

```text
igniter-lang/lib/igniter_lang.rb
```

Proof harnesses may direct-require the file.

The implementation may require these already-internal files:

```ruby
require_relative "internal_profile_assembly_source_packet"
```

It must not require parser, classifier, TypeChecker, SemanticIR, assembler,
CLI, report, runtime, Spark, adapter helper, or production files.

---

## Constructor / Test Seam

Authorized constructor/test seam:

```ruby
IgniterLang::InternalProfileStaticDataCarrier.build(static_data:)
```

Allowed instance methods:

```ruby
#to_h
#valid_shape?
#diagnostics
#to_source_packet
#static_data_digest
```

Optional class constants are allowed only for internal shape validation:

```ruby
KIND = "internal_profile_static_data_carrier"
FORMAT_VERSION = "0.1.0"
STATIC_DATA_STATUSES = ["proof_local_only", "internal_test_seam_only"]
```

No method may read a file path, manifest, loader report, CompatibilityReport,
`.igapp`, sidecar, environment, runtime state, Spark data, or production state.

No method may write files, reports, artifacts, sidecars, goldens, manifests, or
diagnostics outside the implementation proof output directory.

---

## Accepted Input Shape

The constructor accepts an internal hash equivalent to:

```json
{
  "kind": "internal_profile_static_data_carrier",
  "format_version": "0.1.0",
  "static_data_status": "internal_test_seam_only",
  "authority": {
    "authority_ref": "proof://or/internal://...",
    "authority_kind": "proof_only",
    "canon_status": "non_canon"
  },
  "profile_candidate": {},
  "pack_descriptor_candidates": [],
  "excluded_namespaces": [],
  "closed_surface_assertions": {}
}
```

Accepted `static_data_status` values:

```text
proof_local_only
internal_test_seam_only
```

Accepted `authority.authority_kind` values:

```text
proof_only
design_accepted
```

Accepted `authority.canon_status` values:

```text
non_canon
accepted_design
```

The implementation must reject or mark invalid:

- missing `profile_candidate`;
- empty or missing `pack_descriptor_candidates`;
- unsupported `kind`;
- unsupported `format_version`;
- unsupported `static_data_status`;
- public/runtime/production/Spark authority kinds;
- canon or production canon statuses;
- any `closed_surface_assertions` value set to `true`;
- public/discovery/loader/report/manifest/artifact/runtime/Spark fields.

---

## Accepted Output Shape

`#to_h` may return an internal carrier hash:

```json
{
  "kind": "internal_profile_static_data_carrier",
  "format_version": "0.1.0",
  "valid": true,
  "static_data_status": "internal_test_seam_only",
  "authority": {},
  "profile_candidate": {},
  "pack_descriptor_candidates": [],
  "excluded_namespaces": [],
  "diagnostics": [],
  "static_data_digest": "sha256-prefix",
  "closed_surface_assertions": {}
}
```

`#to_source_packet` may return:

```ruby
IgniterLang::InternalProfileAssemblySourcePacket
```

The carrier must not return:

- `compiler_profile_id`;
- `compiler_profile_id_source`;
- `compiler_profile_source`;
- manifest identity;
- loader/report status;
- CompatibilityReport status;
- runtime readiness;
- production readiness;
- Spark readiness;
- demo readiness.

The carrier must not itself return `finalized_internal`. That remains the
responsibility of `IgniterLang::InternalProfileAssembly`.

---

## Diagnostic Vocabulary

Allowed internal diagnostic codes:

```text
internal_profile_static_data_carrier.invalid_shape
internal_profile_static_data_carrier.unsupported_kind
internal_profile_static_data_carrier.unsupported_format_version
internal_profile_static_data_carrier.unsupported_static_data_status
internal_profile_static_data_carrier.invalid_authority
internal_profile_static_data_carrier.missing_profile_candidate
internal_profile_static_data_carrier.missing_pack_descriptor_candidates
internal_profile_static_data_carrier.surface_open
internal_profile_static_data_carrier.forbidden_field
internal_profile_static_data_carrier.packet_build_failed
```

These diagnostics are internal only. They are not public language diagnostics,
not central `IgniterLang::Diagnostics`, not `CompilationReport` entries, not
`CompilerResult` entries, and not CompatibilityReport entries.

---

## Fixture / Output Policy

S3-R154-C2-I may create synthetic data only inside:

```text
igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/**
```

It must not create or edit:

- shared fixtures;
- `igniter-lang/fixtures/**`;
- `.igapp` files;
- `.ilk` files;
- manifests;
- sidecars;
- golden files;
- generated indexes;
- specs/canon/proposals;
- Spark-derived data;
- product data.

Proof outputs must be digest-addressed where useful and must remain inside the
authorized proof output directory.

---

## Required Proof Matrix

S3-R154-C2-I must record PASS for:

| Command | Required result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_static_data_carrier.rb` | Syntax OK |
| `ruby igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_assembly_source_packet.rb` | Syntax OK |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_assembly.rb` | Syntax OK |
| `ruby -c igniter-lang/lib/igniter_lang/oof_fragment_registry.rb` | Syntax OK |

The implementation proof runner must verify:

- valid synthetic/internal static data builds a carrier;
- carrier maps to `InternalProfileAssemblySourcePacket`;
- packet validates through `OOFFragmentRegistry`;
- assembly through `InternalProfileAssembly` can still reach
  `finalized_internal` only as internal lifecycle state;
- duplicate ownership remains rejected before `finalized_internal`;
- invalid status, invalid authority, public/discovery fields, and open
  closed-surface assertions are rejected;
- no carrier output includes forbidden PROP-036 or public/report/runtime/Spark
  fields;
- no existing R153 proof artifacts are required to be rewritten.

Broader proof commands that write outside the authorized proof directory are not
required for this slice.

---

## Required Live Closed-Surface Checks

The implementation proof must live-check:

- `igniter-lang/lib/igniter_lang.rb` does not require
  `internal_profile_static_data_carrier`;
- parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator, CLI,
  `CompilationReport`, and `CompilerResult` files do not reference
  `InternalProfileStaticDataCarrier` or `internal_profile_static_data_carrier`;
- `FragmentRegistryCompatibilityAdapter` is not required or called;
- no `ClassifiedProgram` field is added;
- `contract_fragment_for` is not replaced;
- no `.igapp`, `.ilk`, manifest, sidecar, artifact hash, or golden file is
  created or modified;
- no PROP-036 or PROP-038 proposal/doc/code file is modified;
- no Spark, runtime, production, deployment, signing, cache, Ledger/TBackend,
  BiHistory, stream/OLAP, or demo file/surface is touched.

---

## Forbidden Field / Vocabulary Scans

The implementation proof must scan carrier outputs, proof outputs, and
closed-surface payloads for forbidden authority vocabulary.

PROP-036 token set:

```text
compiler_profile_id
compiler_profile_id_source
compiler_profile_source
profile_source
profile finalization
manifest identity
default profile
named profile
profile discovery
```

Public/report/artifact/runtime tokens:

```text
igapp_path
compilation_report_path
loader_report
compatibility_report
compiler_result
manifest
sidecar
artifact_hash
runtime_ready
production_ready
spark_ready
demo_ready
```

Allowed exception:

The proof may list forbidden tokens inside an explicit negative-scan token list.
The tokens must not appear as active carrier output fields, authority fields, or
claimed status fields.

---

## Portfolio Review Status

Portfolio/Lang review is satisfied for this exact future implementation
boundary only:

```text
S3-R154-C2-I
compiler-profile-source-mode-static-data-internal-carrier-implementation-v0
```

No additional Portfolio checkpoint is required before S3-R154-C2-I if and only
if the implementation card stays inside the exact write scope and boundary
defined here.

Fresh Portfolio-visible review is required before any widening to:

- root require;
- compiler pipeline integration;
- public API/CLI;
- loader/report or CompatibilityReport;
- manifest/artifact/golden behavior;
- shared fixtures;
- generated indexes;
- PROP-036 or PROP-038 mutation;
- Spark fixture/spec/integration;
- runtime, production, deployment, signing, cache, Ledger/TBackend, BiHistory,
  stream/OLAP, or demo behavior.

---

## Not Authorized

This decision does not authorize:

- implementation outside S3-R154-C2-I;
- root require;
- classifier wiring or live classifier dispatch;
- `contract_fragment_for` replacement;
- parser, TypeChecker, SemanticIR, assembler, report, or `.igapp` edits;
- `ClassifiedProgram` schema changes;
- public API/CLI;
- loader/report;
- `CompilationReport`, `CompilerResult`, or CompatibilityReport changes;
- manifest, sidecar, artifact hash, or golden migration;
- shared fixtures;
- generated indexes;
- embedded internal library static registry rows;
- PROP-036 or PROP-038 mutation;
- Spark access, fixtures, specs, integration, or production pressure;
- runtime, production, Ledger/TBackend, BiHistory, stream/OLAP, cache, signing,
  deployment, or demo work.

---

## Compact Summary

[D] Authorize bounded internal-only implementation for
`IgniterLang::InternalProfileStaticDataCarrier`.

[S] R153 proof is sufficient for a smallest carrier/test seam only. Static data
remains synthetic/internal-only; the carrier may map to
`InternalProfileAssemblySourcePacket` but must not integrate with compiler
pipeline, public/report/artifact, runtime, Spark, production, or demo surfaces.

[T] Decision doc only. No code implemented by this card.

[R] Next route is exactly S3-R154-C2-I
`compiler-profile-source-mode-static-data-internal-carrier-implementation-v0`
inside the write scope listed above.
