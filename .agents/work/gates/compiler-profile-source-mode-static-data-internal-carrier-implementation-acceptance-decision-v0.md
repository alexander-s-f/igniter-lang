# Compiler Profile Source-Mode Static-Data Internal Carrier Implementation Acceptance Decision v0

Card: S3-R155-C2-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: compiler-profile-source-mode-static-data-internal-carrier-implementation-acceptance-decision-v0
Depends on: S3-R155-C1-X
Status: accepted-implementation-closure-pause-next
Date: 2026-05-23

---

## Decision

Accept the bounded internal static-data carrier implementation closure.

The S3-R154-C2-I implementation is accepted because it stays inside the
S3-R154-C1-A write scope, implements the exact authorized direct-require-only
internal carrier class, preserves root require and compiler pipeline closure,
maps valid data to `IgniterLang::InternalProfileAssemblySourcePacket` without
producing `finalized_internal`, rejects the required invalid cases, and keeps
public/report/artifact, Spark, runtime, production, and demo surfaces closed.

No new implementation is authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/discussions/compiler-profile-source-mode-static-data-internal-carrier-implementation-pressure-v0.md`
- `igniter-lang/docs/gates/compiler-profile-source-mode-static-data-internal-carrier-implementation-authorization-review-v0.md`
- `igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-internal-carrier-implementation-v0.md`
- `igniter-lang/docs/tracks/stage3-round154-status-curation-v0.md`
- `igniter-lang/lib/igniter_lang/internal_profile_static_data_carrier.rb`
- `igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/out/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof_summary.json`

---

## Exact Changed Files

Accepted implementation commit cited by C1-X:

```text
8fa97a60
```

Changed files:

```text
igniter-lang/lib/igniter_lang/internal_profile_static_data_carrier.rb
igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof.rb
igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/out/assembly_evidence.sanitized.json
igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/out/carrier_output.invalid_cases.sanitized.json
igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/out/carrier_output.valid.sanitized.json
igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/out/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof_summary.json
igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-internal-carrier-implementation-v0.md
```

All implementation files are inside the S3-R154-C1-A authorized write scope.

C1-X also notes adjacent admin commit `717c4946`, which modified:

```text
igniter-lang/docs/cards/S3/S3-R154.md
```

That dispatch document is outside the strict implementation write scope, but it
is an administrative round record, not implementation content, not a gated
language surface, and not a blocker for accepting the implementation commit.

---

## Acceptance Findings

| Required status | Accepted result |
| --- | --- |
| API / class / file status | Accepted. File is `igniter-lang/lib/igniter_lang/internal_profile_static_data_carrier.rb`; class is `IgniterLang::InternalProfileStaticDataCarrier`; constants, constructor, methods, and diagnostic vocabulary match authorization. |
| Direct-require-only status | Accepted. Carrier requires only Ruby stdlib `digest`/`json` and `require_relative "internal_profile_assembly_source_packet"`. It does not require parser, classifier, TypeChecker, SemanticIR, assembler, CLI, report, runtime, Spark, adapter, or production files. |
| Root require status | Accepted closed. Proof live-checks `lib/igniter_lang.rb`; `internal_profile_static_data_carrier` is not required from root. |
| Validation policy status | Accepted. Required invalid cases are rejected: invalid status, invalid authority, missing profile candidate, missing pack descriptor candidates, forbidden fields, and open closed-surface assertion. Invalid carriers return no source packet. |
| Output constraint status | Accepted. `#to_h` has fixed internal keys and excludes PROP-036 identity/source fields, public/report/runtime readiness fields, manifest identity, compatibility status, Spark/demo readiness, and `finalized_internal`. |
| `to_source_packet` / `finalized_internal` boundary | Accepted. `#to_source_packet` returns `InternalProfileAssemblySourcePacket` with `implementation_candidate` lifecycle for valid carriers and nil for invalid carriers. The carrier does not produce `finalized_internal`; only `InternalProfileAssembly` can produce that internal lifecycle state. |
| Proof matrix result | Accepted. Summary records 9/9 checks PASS, 0 failures. |
| Command matrix result | Accepted. All 5 required commands report PASS. |
| Live closed-surface checks | Accepted. Root require, pipeline files, adapter helper, `ClassifiedProgram`, and `contract_fragment_for` checks pass. |
| Pressure verdict | Accepted. C1-X verdict is `proceed`; 12/12 scope checks PASS; no blockers. |

---

## Command Matrix

Accepted command matrix:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_static_data_carrier.rb` | PASS |
| `ruby igniter-lang/experiments/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof/compiler_profile_source_mode_static_data_internal_carrier_implementation_proof.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_assembly_source_packet.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/internal_profile_assembly.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/oof_fragment_registry.rb` | PASS |

Proof summary:

```text
status: PASS
checks_total: 9
checks_pass: 9
checks_fail: 0
recommendation: accept closure
```

---

## Pressure Notes Disposition

### NB-1: Broadened `FORBIDDEN_FIELDS`

Accepted as non-blocking.

The implementation includes stricter exact-key forbidden fields than the gate
minimum, including broad keys such as `report`, `runtime`, `spark`, and `demo`.
This is conservative and correct for the current internal-only carrier scope.
Any future trusted internal data shape that needs such keys must reopen design
or authorization review before changing the policy.

### NB-2: Validation Paths Not Named As Proof Cases

Accepted as non-blocking.

The implementation code covers non-Hash static data, unsupported kind,
unsupported format version, and non-Hash closed-surface assertions, but those
paths were not named as standalone proof cases. The accepted proof covers the
highest-risk required rejection paths for this slice.

If this carrier is later expanded or refactored, those paths should become
named proof cases before acceptance.

### NB-3: Adjacent Admin Commit

Accepted as non-blocking.

The adjacent `docs/cards/S3/S3-R154.md` update is administrative dispatch
tracking. It does not introduce implementation content or open a language,
compiler, public, report, artifact, Spark, runtime, production, or demo surface.

---

## Remaining Closed Surfaces

This decision does not authorize:

- new implementation;
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

## Exact Next Allowed Boundary

Choose:

```text
no immediate follow-up / pause
```

Immediate administrative closure route:

```text
Card: S3-R155-C3-S
Agent: [Igniter-Lang Status Curator]
Role: status-curator
Track: stage3-round155-status-curation-v0
Route: UPDATE
Mode: status curation only
```

Allowed write scope:

```text
igniter-lang/docs/tracks/stage3-round155-status-curation-v0.md
```

After status curation, the source-mode/static-data internal-carrier lane should
pause. No additional proof, design, implementation-authorization review, public
surface, report/artifact, Spark, runtime, production, or demo route is opened by
this acceptance decision.

Any later widening must start from a fresh Portfolio-visible review.

---

## Compact Summary

[D] Accept the bounded internal carrier implementation closure.

[S] `IgniterLang::InternalProfileStaticDataCarrier` is accepted as a
direct-require-only internal carrier/test seam. It validates internal static
data, rejects invalid/public-surface inputs, maps valid data to
`InternalProfileAssemblySourcePacket`, and does not itself produce
`finalized_internal`.

[T] Gate decision doc only. No new implementation is authorized.

[R] Next route is S3-R155-C3-S status curation only, then pause this carrier
lane.
