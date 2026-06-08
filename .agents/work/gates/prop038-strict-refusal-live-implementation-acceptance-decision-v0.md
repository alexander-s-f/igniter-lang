# PROP-038 Strict Refusal Live Implementation Acceptance Decision v0

Card: S3-R84-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-strict-refusal-live-implementation-acceptance-decision-v0
Route: UPDATE
Status: accepted-live-internal-foundation
Date: 2026-05-19

---

## Decision

Accept the R83 bounded internal-only PROP-038 strict-refusal live implementation
as the live internal foundation.

This acceptance closes only the R83 internal implementation slice. It does not
authorize any new implementation or any public/runtime expansion.

Immediate next route:

```text
stage3-round84-status-curation-v0
```

No implementation card is opened by this decision.

---

## Evidence Read

- `igniter-lang/docs/gates/prop038-strict-refusal-live-implementation-authorization-review-v0.md`
- `igniter-lang/docs/tracks/prop038-strict-refusal-live-implementation-v0.md`
- `igniter-lang/docs/discussions/prop038-strict-refusal-live-implementation-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round83-status-curation-v0.md`
- `igniter-lang/docs/gates/prop038-strict-refusal-live-implementation-scope-decision-v0.md`
- `igniter-lang/docs/gates/prop038-strict-refusal-result-shape-proof-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb`
- `igniter-lang/lib/igniter_lang/compiler_result.rb`
- `igniter-lang/experiments/prop038_strict_refusal_live_implementation_proof/prop038_strict_refusal_live_implementation_proof.rb`
- `igniter-lang/experiments/prop038_strict_refusal_live_implementation_proof/out/prop038_strict_refusal_live_implementation_proof_summary.json`

---

## Accepted Changed Files

Architect accepts the changed files as inside the R83 authorization boundary:

| Surface | Accepted files |
| --- | --- |
| Code | `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb` |
| Code | `igniter-lang/lib/igniter_lang/compiler_result.rb` |
| Proof | `igniter-lang/experiments/prop038_strict_refusal_live_implementation_proof/prop038_strict_refusal_live_implementation_proof.rb` |
| Proof output | `igniter-lang/experiments/prop038_strict_refusal_live_implementation_proof/out/prop038_strict_refusal_live_implementation_proof_summary.json` |
| Track | `igniter-lang/docs/tracks/prop038-strict-refusal-live-implementation-v0.md` |

No public API/CLI files are accepted as changed.

---

## Command And Proof Result

Accepted command matrix:

```text
11/11 PASS
```

Accepted proof summary:

```text
kind=prop038_strict_refusal_live_implementation_proof_summary
status=PASS
cases=16
checks=46
failed_checks=0
```

Accepted pressure result:

```text
verdict=proceed
scope_checks=10/10 PASS
blockers=none
non_blocking_notes=1
```

The non-blocking note is accepted as non-blocking:

- non-strict success paths do not expose an explicit `assembler_calls` counter;
- assembly is confirmed indirectly by `igapp_written: true` and
  `manifest_written: true`;
- strict terminal paths do assert `assembler_calls: 0`;
- this is an instrumentation asymmetry, not an acceptance blocker.

---

## Accepted Implementation Properties

Architect accepts the following implementation properties as proven:

| Property | Acceptance |
| --- | --- |
| Internal-only strict source | Accepted. Strict source is constructor/test-seam only. |
| `CompilerOrchestrator` authority | Accepted only for internal strict requirement decision path. |
| `CompilerResult` authority | Accepted only for non-persisting strict terminal result construction. |
| Validator non-authority | Accepted. Validator output remains evidence, not authority. |
| `compile_refusal_authorized: false` marker | Accepted as nested report-only evidence. |
| `report.pass_result == "ok"` | Accepted as invariant for strict terminal paths in this slice. |
| `refused` public key-set | Accepted exact 13-key allowlist. |
| `configuration_error` public key-set | Accepted exact same 13-key allowlist. |
| Non-persisting terminal behavior | Accepted. No sidecar, no report, no `.igapp`. |
| `CompilerOrchestrator#refusal` usage | Accepted absent for PROP-038 strict terminal paths. |
| Assembly skip | Accepted for strict terminal paths. |
| Ordinary path preservation | Accepted for parse, OOF, assembler, runtime-smoke, and internal-error paths. |
| Public API/CLI closure | Accepted preserved. |

Accepted strict terminal public key-set:

```text
kind
format_version
status
program_id
source_path
source_hash
grammar_version
stages
igapp_path
contracts
compilation_report_path
diagnostics
warnings
```

Accepted public wrapper diagnostics:

```text
compiler_profile_contract_refusal.contract_digest_mismatch
compiler_profile_contract_refusal.strict_requirement_malformed
```

Raw validator diagnostics remain nested and are not public top-level diagnostics.

---

## Accepted Live Internal Foundation

The accepted live internal foundation is:

```text
Internal strict requirement source
  -> orchestrator-level strict decision path
  -> report-only PROP-038 validation evidence
  -> non-persisting strict terminal result when selected
```

Accepted terminal statuses:

- `refused` for strict digest mismatch under explicit internal strict source;
- `configuration_error` for malformed internal strict requirement.

Accepted non-terminal behavior:

- no strict source: report-only behavior unchanged;
- nil strict source: report-only behavior unchanged;
- valid strict source + valid contract: assembly/success unchanged;
- invalid validator result without strict authority: no refusal, report-only
  behavior unchanged;
- provider nil, non-Hash, or exception: no-field/no-refusal unchanged.

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

## Next Allowed Boundary

Authorize only status curation next:

```text
Card: S3-R84-C2-S
Agent: [Igniter-Lang Status Curator]
Role: status-curator
Track: stage3-round84-status-curation-v0
```

After status curation, the next strategic route must be chosen separately. Valid
future candidates include:

- docs/spec sync for PROP-038 strict refusal;
- public API/CLI design route;
- loader/report or CompatibilityReport design route;
- additional proof/regression hardening;
- another compiler/profile axis.

No future candidate is authorized by this decision.
