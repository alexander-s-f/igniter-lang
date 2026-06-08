# PROP-038 Strict Refusal Canon Sync Acceptance Decision v0

Card: S3-R85-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-strict-refusal-canon-sync-acceptance-decision-v0
Route: UPDATE
Status: accepted-canon-sync-docs-spec-sync-next
Date: 2026-05-20

---

## Decision

Accept the R85 PROP-038 strict-refusal canon sync and regression/canon map.

The sync correctly records the R84 accepted live internal foundation without
creating new implementation authority, public exposure, runtime authority, or
production authority.

This decision does not authorize new implementation.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-strict-refusal-canon-sync-v0.md`
- `igniter-lang/docs/tracks/prop038-strict-refusal-regression-and-canon-map-v0.md`
- `igniter-lang/docs/discussions/prop038-strict-refusal-canon-sync-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-strict-refusal-live-implementation-acceptance-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round84-status-curation-v0.md`

---

## Accepted Sync Scope

Architect accepts the C1-P1 canon sync.

Synchronized docs and indexes:

| Path | Accepted status |
| --- | --- |
| `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md` | Accepted. PROP-038 now records the R84 live internal foundation and replaces stale absolute "compile refusal remains closed" language with the internal-only/public-closed split. |
| `igniter-lang/docs/current-status.md` | Accepted. Current status now points to R84 and R85 without widening behavior. |
| `igniter-lang/docs/tracks/README.md` | Accepted. Track navigation now exposes R85 canon sync and regression/canon map. |
| `igniter-lang/docs/tracks/prop038-strict-refusal-canon-sync-v0.md` | Accepted. |

`igniter-lang/docs/gates/README.md` was correctly left unchanged by C1-P1
because it already recorded R84 accurately.

---

## PROP-038 Canon Status

Architect accepts that PROP-038 now reflects R84 correctly:

```text
internal strict requirement source
  -> orchestrator-level strict requirement decision path
  -> report-only compiler_profile_contract_validation evidence
  -> non-persisting strict terminal CompilerResult when selected
```

Accepted canon points:

- R84 accepts bounded internal-only strict refusal as a live internal foundation;
- strict source is an internal constructor/test seam only;
- orchestrator-level strict requirement decision path is authority;
- validator output remains evidence, not authority;
- nested `compile_refusal_authorized: false` remains a report-only marker;
- `report.pass_result == "ok"` remains invariant for strict terminal paths;
- `refused` and `configuration_error` share the exact accepted 13-key public
  key-set;
- strict terminal paths are non-persisting: no sidecar, no report write, no
  `.igapp`, and no assembler call;
- public API/CLI, loader/report, CompatibilityReport, RuntimeMachine/Gate 3,
  runtime, and production remain closed.

The stale absolute statement "compile refusal remains closed" is replaced by the
accepted more precise boundary:

```text
internal-only strict refusal foundation accepted;
public/runtime/production refusal remains closed.
```

---

## Accepted Regression / Canon Map

Architect accepts C2-P1 as the compact regression/canon reference for the
accepted internal-only strict-refusal foundation.

Accepted map contents:

- accepted behavior surface;
- proof command matrix summary;
- `16 cases / 46 checks / 0 failed` proof summary;
- protected closed surfaces;
- regression anchors;
- expansion risks;
- future expansion guard checklist.

C2-P1 is accepted as a map, not as a fresh proof rerun and not as
implementation authorization.

---

## Pressure Result

R85-C3-X verdict:

```text
proceed
blockers: none
checks: 8/8 PASS
non-blocking notes: 3
```

Architect accepts the pressure result.

Non-blocking notes are correctly scoped:

1. Ch5/Ch7 spec wording was not synced. This is a valid future docs/spec sync
   target, not a blocker for R85.
2. C2-P1 did not rerun proof commands. This is correct for a read-only canon
   map.
3. `production_compiler_cli_proof` and `igapp_assembler_proof` were not rerun.
   This is correct for R85, and those anchors must be included if future public
   CLI or assembler surfaces open.

---

## Preserved Closed Surfaces

This decision does not authorize:

- new implementation;
- public API or CLI widening;
- `IgniterLang.compile` signature changes;
- env/config/manifest/default/generated strict source lookup;
- loader/report strict source or status;
- CompatibilityReport strict source or status;
- persisted refusal reports;
- sidecars;
- `.igapp` mutation or golden migration;
- parser changes;
- TypeChecker changes;
- SemanticIR changes;
- assembler changes;
- `CompilationReport` changes;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`;
- receipts;
- signing;
- dispatch migration;
- RuntimeMachine or Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

---

## Next Strategic Route

Choose docs/spec sync continuation as the next strategic route.

Reason:

- R85 closed the main PROP/current-status/index drift.
- The only pressure-identified remaining canon gap is Ch5/Ch7 spec wording.
- Opening public API/CLI, loader/report, CompatibilityReport, or runtime
  surfaces before spec wording sync would increase drift risk.

Authorized next route:

```text
prop038-strict-refusal-spec-chapter-sync-v0
```

Allowed next boundary:

```text
Card: S3-R86-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: prop038-strict-refusal-spec-chapter-sync-v0

Goal:
Synchronize Ch5/Ch7 or equivalent spec chapters with the R84 accepted
internal-only strict-refusal foundation, without adding new semantics or
implementation authority.

Scope:
- Read the R85 acceptance decision and R84 gate.
- Identify the exact spec/chapter docs that still imply strict refusal is only
  proof-local or fully closed.
- Update only spec/docs language needed to reflect:
  - internal-only live foundation accepted;
  - public/runtime/production refusal remains closed;
  - validator remains evidence, not authority;
  - non-persisting/no-sidecar/no-report/no-.igapp behavior.
- Do not edit code.
- Do not authorize public API/CLI, loader/report, CompatibilityReport,
  RuntimeMachine/Gate 3, runtime, or production behavior.

Deliver:
- Track doc in `igniter-lang/docs/tracks/`
- Exact changed docs
- Remaining spec gaps, if any
```

No implementation or public-surface route is authorized by this decision.
