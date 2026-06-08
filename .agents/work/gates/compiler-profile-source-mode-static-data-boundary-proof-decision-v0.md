# Compiler Profile Source-Mode Static-Data Boundary Proof Decision v0

Card: S3-R153-C3-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: compiler-profile-source-mode-static-data-boundary-proof-decision-v0
Depends on: S3-R153-C1-P1, S3-R153-C2-X
Status: accepted-implementation-authorization-review-next
Date: 2026-05-23

---

## Decision

Accept the source-mode/static-data boundary proof.

The S3-R153-C1-P1 proof is accepted because it demonstrates the accepted
source-mode/static-data boundary with synthetic proof-local data, preserves the
profile/pack authority split, proves duplicate ownership rejection, keeps
`finalized_internal` internal-only, and preserves the protected compiler,
public, report/artifact, Spark, runtime, production, and demo surfaces.

The S3-R153-C2-X pressure review returned:

```text
proceed
scope checks: 10/10 PASS
blockers: none
```

No implementation is authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-boundary-proof-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-source-mode-static-data-boundary-proof-pressure-v0.md`
- `igniter-lang/docs/gates/compiler-profile-source-mode-static-data-boundary-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round152-status-curation-v0.md`
- `igniter-lang/experiments/compiler_profile_source_mode_static_data_boundary_proof/out/compiler_profile_source_mode_static_data_boundary_proof_summary.json`
- `igniter-lang/experiments/compiler_profile_source_mode_static_data_boundary_proof/out/synthetic_static_data_fixture.json`
- `igniter-lang/experiments/compiler_profile_source_mode_static_data_boundary_proof/out/source_packet.helper_envelopes.json`
- `igniter-lang/experiments/compiler_profile_source_mode_static_data_boundary_proof/out/duplicate_ownership_rejection.json`

---

## Acceptance Findings

| Required status | Accepted result |
| --- | --- |
| Synthetic proof-local data | Accepted. Static data was modeled only inside the proof experiment. No shared fixtures, `lib/` data, generated index, spec/canon example, Spark-derived data, product data, runtime data, production data, or demo data was created. |
| Minimal non-trivial shape | Accepted. The proof includes one synthetic pack descriptor candidate, one OOF descriptor row, one fragment row, one profile candidate selecting the pack, and a duplicate ownership negative case. |
| Source-mode mapping | Accepted. `profile_candidate` and `pack_descriptor_candidate` map into internal profile-assembly source packet semantics and helper envelopes without public carrier leakage. |
| Pack/profile authority preservation | Accepted. Pack descriptors own row identity, provenance, and row-local claims. Profile candidates own selected pack set, selected pack order, and aggregate conflict policy. |
| Duplicate ownership/conflict rejection | Accepted. Duplicate OOF descriptor row and fragment row ownership both produce `oof_registry.source.validation.duplicate_row_ownership`, and aggregate assembly is rejected before `finalized_internal`. |
| `finalized_internal` lifecycle | Accepted. Positive assembly reaches `finalized_internal` only as an internal lifecycle state. The proof records forbidden meanings as false: PROP-036 identity, manifest identity, public finalization, loader/report status, runtime readiness, production readiness, Spark readiness, and demo readiness. |
| PROP-036 negative scan | Accepted with explicit scoping note below. The required 9-token set records zero hits in the forbidden payload. |
| PROP-038 preservation | Accepted. `compiler_profile_contract` and `compiler_profile_contract_refusal` excluded namespaces are preserved, and strict-refusal/report/runtime authority is not widened. |
| Adapter helper boundary | Accepted. Adapter evidence remains proof-local/direct-require evidence only. Root require, classifier adapter reference, live dispatch, `ClassifiedProgram` projection, and `contract_fragment_for` replacement remain closed. |
| Closed-surface scan | Accepted. The proof records 24 closed-surface entries with key compiler pipeline files live-scanned and semantic surfaces stated closed. |
| Command matrix | Accepted. Track records syntax OK and runner PASS. Summary records 16/16 checks PASS, 0 failures. |

---

## Pressure Notes Disposition

### NB-1: Lifecycle Matrix Static Values

Accepted as non-blocking.

The lifecycle matrix declares forbidden meanings as `false` by construction and
checks that the positive assembly reached `finalized_internal`. This is
acceptable for this proof slice because PROP-036 negative scan and
closed-surface checks also guard the boundary.

Future proofs that expand assembly result fields should derive lifecycle
forbidden-meaning assertions from the actual result object, not only from static
declarations.

### NB-2: PROP-036 Scan Scope

Accepted with explicit acknowledgement.

The PROP-036 scan targets the dedicated
`forbidden_prop036_scan_payload`, not the full proof summary. The full summary
contains the internal field name `profile_source_mode`, which includes the
substring `profile_source`.

That is acceptable here because `profile_source_mode` is internal proof
vocabulary describing source-mode mapping. It is not PROP-036 authority, not
public CLI/API vocabulary, not profile discovery/defaulting/finalization, not
manifest identity, and not loader/report output.

The accepted claim is therefore:

```text
PROP-036 authority tokens are absent from forbidden result fields and
closed-surface outputs.
```

The proof does not claim:

```text
PROP-036 substrings are absent from every field name in the full summary.
```

### NB-3: Stated Closed-Surface Assertions

Accepted as non-blocking.

The proof live-scans key compiler pipeline files and records semantic surfaces
that do not have dedicated scannable files as stated `open: false` assertions.
That is acceptable for this boundary proof.

Any future route involving loader/report, CompatibilityReport, manifest,
sidecar, artifact hash, runtime, production, Spark, or demo behavior must
replace stated assertions with live or artifact-specific checks before
acceptance.

---

## Exact Next Allowed Boundary

Open exactly one next route:

```text
Card: S3-R154-C1-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Track: compiler-profile-source-mode-static-data-internal-carrier-implementation-authorization-review-v0
Route: UPDATE
Mode: implementation-authorization review only
```

Goal:

Decide whether a smallest bounded internal-only implementation slice may open
for a source-mode/static-data internal carrier or test seam, based on the
accepted R152 design and R153 proof.

The next route is a review route only. It must not implement code, create
fixtures, create generated indexes, edit `lib/`, edit specs/proposals/canon, or
mutate compiler/runtime/report/artifact surfaces.

Allowed write scope for the review route:

```text
igniter-lang/docs/gates/compiler-profile-source-mode-static-data-internal-carrier-implementation-authorization-review-v0.md
```

The review route must decide:

- authorize bounded implementation;
- authorize a narrower proof/design follow-up;
- hold pending more proof;
- redirect.

If the review route authorizes future implementation, it must define the exact
future implementation write scope, internal-only class/module/file shape,
constructor/test seam, proof matrix, live closed-surface checks, and Portfolio
review status. It must also explicitly preserve all closed surfaces listed
below.

---

## Required Inputs For The Next Review

S3-R154-C1-A must read:

- this decision;
- `igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-boundary-proof-v0.md`;
- `igniter-lang/docs/discussions/compiler-profile-source-mode-static-data-boundary-proof-pressure-v0.md`;
- `igniter-lang/docs/gates/compiler-profile-source-mode-static-data-boundary-decision-v0.md`;
- `igniter-lang/experiments/compiler_profile_source_mode_static_data_boundary_proof/out/compiler_profile_source_mode_static_data_boundary_proof_summary.json`;
- `igniter-lang/lib/igniter_lang/internal_profile_assembly_source_packet.rb`;
- `igniter-lang/lib/igniter_lang/internal_profile_assembly.rb`;
- `igniter-lang/lib/igniter_lang/oof_fragment_registry.rb`.

The review must explicitly answer whether the accepted proof is sufficient to
consider a bounded implementation slice, or whether another proof/design pass is
needed first.

---

## Not Authorized

This decision does not authorize:

- implementation;
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
- internal library static data;
- PROP-036 or PROP-038 mutation;
- Spark access, fixtures, specs, integration, or production pressure;
- runtime, production, Ledger/TBackend, BiHistory, stream/OLAP, cache, signing,
  deployment, or demo work.

---

## Portfolio Review Requirement

Portfolio review is required before any implementation card opens.

S3-R154-C1-A is allowed only as an implementation-authorization review. It does
not itself satisfy approval for code changes unless that review explicitly
records the Portfolio/Lang authority basis and exact future write scope.

Portfolio review is also required before any later route opens:

- public API/CLI widening;
- loader/report or CompatibilityReport;
- manifest, sidecar, artifact hash, `.igapp`, `.ilk`, or golden migration;
- PROP-036 or PROP-038 mutation;
- Spark-derived fixtures/specs or Spark integration;
- runtime, production, Ledger/TBackend, BiHistory, stream/OLAP, cache, signing,
  deployment, or demo behavior.

---

## Compact Summary

[D] Accept the source-mode/static-data boundary proof.

[S] Proof PASS 16/16. Synthetic proof-local data status accepted. Minimal shape,
source-mode mapping, authority split, duplicate ownership rejection,
`finalized_internal` internal-only lifecycle, PROP-036 scoped negative scan,
PROP-038 preservation, adapter helper boundary, closed-surface scans, and
command matrix are accepted.

[T] Gate decision doc only. No implementation is authorized.

[R] Next route is exactly S3-R154-C1-A
`compiler-profile-source-mode-static-data-internal-carrier-implementation-authorization-review-v0`,
implementation-authorization review only.
