# Compiler Profile Source-Mode Static-Data Boundary Decision v0

Card: S3-R152-C3-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: compiler-profile-source-mode-static-data-boundary-decision-v0
Depends on: S3-R152-C1-D, S3-R152-C2-X
Status: accepted-proof-only-next
Date: 2026-05-23

---

## Decision

Accept the source-mode/static-data boundary design.

The S3-R152-C1-D design is accepted because it clarifies the compiler/profile
architecture boundary without promoting static data to compiler authority,
public/profile discovery, loader/report state, artifact state, runtime
behavior, Spark fixture/spec authority, or production behavior.

The S3-R152-C2-X pressure review returned:

```text
proceed
scope checks: 7/7 PASS
blockers: none
```

No implementation is authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-boundary-design-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-source-mode-static-data-boundary-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round151-status-curation-v0.md`
- `igniter-lang/docs/current-status.md`

---

## Accepted Status Answers

| Question | Accepted status |
| --- | --- |
| Static-data authority | Static data is design/proof candidate only. It is not internal library data, not a generated index, not compiler authority, not public/default discovery, not manifest identity, not report/artifact state, and not runtime authority. |
| Profile/pack source-mode authority | Profile/pack source-mode authority remains internal. Pack descriptor candidates own row identity, provenance, and row-local claims. Profile candidates own selected pack set, selected pack order, and aggregate conflict policy. |
| `finalized_internal` status | `finalized_internal` remains internal assembly state only. It is not PROP-036 finalization, not `compiler_profile_id`, not `compiler_profile_id_source`, not manifest/profile identity, not loader/report status, and not runtime/production readiness. |
| `profile_candidate` / `pack_descriptor_candidate` status | Both remain accepted internal OOF/Fragment Registry source modes. They do not create a public carrier and do not make static data public. |
| Adapter helper evidence status | Adapter helper evidence may be referenced as prior compatibility evidence or proof-local direct-require evidence only. It is not classifier authority. Adapter continuation remains paused. |
| PROP-036 input status | PROP-036 `compiler_profile_source` remains bounded input transport for an already-finalized `compiler_profile_id_source` object. This decision does not widen CLI/API behavior, discovery, defaulting, finalization, or named profile lookup. |
| PROP-038 input status | PROP-038 `compiler_profile_contract` remains internal strict-refusal/contract evidence input. This decision does not widen public refusal, runtime authority, persisted report behavior, or production behavior. |
| Spark pressure status | Spark remains external applied pressure only. No Spark access, fixture creation, spec/proposal mutation, compiler changes, production integration, or demo work is authorized. |
| Portfolio review before next route | Portfolio review is not required before the selected proof-only route if it stays inside the exact boundary below. Portfolio review is required before any later implementation, public/report/artifact, Spark fixture/spec, runtime, production, or demo route. |

---

## Pressure Notes Accepted Into Next Boundary

S3-R152-C2-X raised three non-blocking notes. They do not block acceptance, but
two become required instructions for the next proof route.

### NB-1: Minimal Non-Trivial Synthetic Shape

The proof route must not use only an empty or trivial static-data object.

The proof must commit to a minimal synthetic static-data shape that exercises at
least:

- one pack descriptor row;
- one profile candidate reference to the selected pack;
- one pack-row ownership conflict or duplicate ownership rejection case.

The shape must remain synthetic and proof-local. It must not become shared
fixtures, spec/canon examples, Spark-derived data, or product data.

### NB-2: Prior Gate Inheritance

The proof route may inherit accepted internal profile assembly and
profile/pack source-mode vocabulary, but it must restate the relevant
closed-surface assertions explicitly instead of relying only on cross-document
references.

### NB-3: PROP-036 Vocabulary Negative Scan

The proof route must name exact PROP-036 vocabulary tokens for negative scans
across proof result fields and closed-surface outputs.

Minimum token set:

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

The proof may include additional related tokens if the proof shape introduces
more candidate vocabulary.

---

## Exact Next Allowed Boundary

Open exactly one next route:

```text
Card: S3-R153-C1-P1
Agent: [Igniter-Lang Compiler/Profile Architect]
Role: compiler-profile-architect
Track: compiler-profile-source-mode-static-data-boundary-proof-v0
Route: UPDATE
Mode: proof-only
```

Goal:

Prove the accepted source-mode/static-data boundary with synthetic proof-local
data, without creating shared fixtures, `lib/` data, generated indexes,
compiler integration, public/report carriers, artifacts, runtime behavior, or
Spark fixtures/specs.

Allowed write scope:

```text
igniter-lang/experiments/compiler_profile_source_mode_static_data_boundary_proof/**
igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-boundary-proof-v0.md
```

No other files may be edited by the proof route.

---

## Required Proof Matrix

The S3-R153-C1-P1 proof must record PASS for:

| Proof area | Required result |
| --- | --- |
| Static-data status matrix | Proof fixture is accepted as proof-local only; internal library data, generated index, public/default discovery, loader/report, CompatibilityReport, manifest/artifact, runtime, Spark, production, and demo statuses are rejected. |
| Minimal synthetic shape | Proof uses a non-trivial synthetic shape with at least one pack descriptor row, one profile candidate reference, and one pack-row conflict or duplicate ownership rejection case. |
| Source-mode mapping | `profile_candidate` and `pack_descriptor_candidate` map to internal profile-assembly source packet semantics without public carrier leakage. |
| Authority preservation | Pack-row authority and profile-level authority preserve the accepted split; duplicate ownership rejects aggregate assembly. |
| Lifecycle preservation | `finalized_internal` remains internal-only and never becomes PROP-036 identity, manifest identity, public finalization, loader/report status, runtime readiness, production readiness, Spark readiness, or demo readiness. |
| PROP-036 negative scan | Exact PROP-036 vocabulary tokens named in this decision are absent from forbidden result fields and closed-surface outputs except where explicitly listed as negative-scan tokens. |
| PROP-038 preservation | Static-data/source-mode proof does not mutate or widen `compiler_profile_contract`, strict-refusal behavior, persisted report behavior, or runtime/refusal authority. |
| Adapter evidence | Any adapter helper reference is proof-local, direct-require-only, and does not create root require, classifier wiring, live dispatch, `ClassifiedProgram` fields, report/artifact projection, or `contract_fragment_for` replacement. |
| Closed-surface scans | Root require, classifier wiring, live dispatch, parser, TypeChecker, SemanticIR, assembler, report, `.igapp`, public API/CLI, loader/report, CompatibilityReport, manifest, sidecar, artifact hash, golden migration, Spark, runtime, production, and demo surfaces remain closed. |

The proof route must not request implementation acceptance. It may recommend a
later decision card only after proof results are recorded.

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

Portfolio review is not required before S3-R153-C1-P1 if the proof stays inside
the exact proof-only boundary and write scope above.

Portfolio review is required before any later route opens:

- implementation;
- internal library static data;
- generated indexes;
- root require;
- classifier wiring or live dispatch;
- public API/CLI widening;
- loader/report or CompatibilityReport;
- manifest, sidecar, artifact hash, `.igapp`, `.ilk`, or golden migration;
- PROP-036 or PROP-038 mutation;
- Spark-derived fixtures/specs or Spark integration;
- runtime, production, Ledger/TBackend, BiHistory, stream/OLAP, cache, signing,
  deployment, or demo behavior.

---

## Compact Summary

[D] Accept the source-mode/static-data boundary design.

[S] Static data remains design/proof candidate only. Profile/pack source-mode
authority remains internal. `finalized_internal` remains internal-only.
PROP-036/PROP-038 remain inputs, not widened authority. Spark remains external
pressure only.

[T] Gate decision doc only. No implementation is authorized.

[R] Next route is exactly S3-R153-C1-P1
`compiler-profile-source-mode-static-data-boundary-proof-v0`, proof-only, with
NB-1/NB-3 requirements carried into the proof boundary.
