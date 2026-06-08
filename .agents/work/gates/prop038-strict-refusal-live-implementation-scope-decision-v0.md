# PROP-038 Strict Refusal Live Implementation Scope Decision v0

Card: S3-R82-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-strict-refusal-live-implementation-scope-decision-v0
Route: UPDATE
Status: accepted-scope-review-implementation-held
Date: 2026-05-19

---

## Decision

Accept the PROP-038 strict-refusal live implementation scope review.

Authorize only a bounded implementation authorization review route next:

```text
prop038-strict-refusal-live-implementation-authorization-review-v0
```

This decision does not authorize implementation. Live compile refusal remains
closed. Report-only remains the current live PROP-038 behavior.

This decision does not authorize live compiler/orchestrator behavior changes,
`CompilerResult` changes, public API/CLI widening, persisted reports or
sidecars, parser/TypeChecker/SemanticIR changes, assembler or `.igapp` mutation,
loader/report behavior, CompatibilityReport behavior, diagnostics
centralization, dispatch migration, RuntimeMachine behavior, Gate 3 widening,
Ledger/TBackend behavior, BiHistory, stream/OLAP, cache, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/org/indexes/prop038-strict-refusal-live-scope-orientation-map-v0.md`
- `igniter-lang/docs/tracks/prop038-strict-refusal-live-implementation-scope-review-v0.md`
- `igniter-lang/docs/tracks/prop038-live-implementation-touchpoint-survey-v0.md`
- `igniter-lang/docs/discussions/prop038-live-implementation-scope-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-strict-refusal-result-shape-proof-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-strict-refusal-result-shape-decision-v0.md`
- `igniter-lang/docs/gates/prop038-internal-orchestrator-strict-source-status-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round81-status-curation-v0.md`

---

## Accepted Candidate Write Scope

Architect accepts the candidate write scope as implementation-review-ready.

Candidate live write scope for a future implementation authorization:

| Path | C4-A status |
| --- | --- |
| `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb` | Candidate live scope only. Requires later implementation authorization. |
| `igniter-lang/lib/igniter_lang/compiler_result.rb` | Candidate live scope only. Requires later implementation authorization. |
| `igniter-lang/experiments/prop038_strict_refusal_live_implementation_proof/` | Candidate proof scope only. Requires later implementation authorization. |
| `igniter-lang/docs/tracks/prop038-strict-refusal-live-implementation-v0.md` | Candidate implementation track only. Requires later implementation authorization. |

Conditional rerun output may be produced only if the future authorized proof
matrix explicitly reruns and updates an existing summary.

Non-candidate write scope remains closed for the first live implementation:

- `igniter-lang/lib/igniter_lang.rb`;
- `igniter-lang/lib/igniter_lang/cli.rb`;
- `igniter-lang/bin/igc`;
- `igniter-lang/lib/igniter_lang/assembler.rb`;
- `igniter-lang/lib/igniter_lang/compilation_report.rb`;
- `igniter-lang/lib/igniter_lang/diagnostics.rb`;
- `.igapp` artifacts or goldens;
- loader/report surfaces;
- CompatibilityReport surfaces.

If a future implementation card needs any non-candidate path, it must stop and
return for Architect authorization.

---

## Authority Stance

Accepted authority requirements for a future implementation request:

| Authority | C4-A stance |
| --- | --- |
| `CompilerOrchestrator` | Required for internal strict source, trigger evaluation point, non-persisting terminal branch, and assembly skip. Not authorized yet. |
| `CompilerResult` | Required for future `refused` and `configuration_error` result construction/public key-set behavior. Not authorized yet. |
| Report / persisted artifact policy | Not required if non-persisting path remains selected. Persisted reports remain closed. |
| Public API / CLI | Not required and remains closed for the first live boundary. |
| Diagnostics centralization | Not required and remains closed. |
| Assembler / `.igapp` | Not required and remains closed. |
| Loader/report | Not required and remains closed. |
| CompatibilityReport | Not required and remains closed. |
| Runtime/production | Not required and remains closed. |

Implementation may not open directly from R82. A later implementation
authorization review must explicitly decide whether to authorize the
`CompilerOrchestrator` and `CompilerResult` candidate scope.

---

## Live Authority Source

Architect resolves R82-C3-X NB-1:

```text
live strict-refusal authority comes from the orchestrator-level strict
requirement decision path, not from the validator result field.
```

Accepted stance:

- `CompilerProfileContractValidator` remains a validation/evidence producer;
- `compile_refusal_authorized: false` in the validator result remains a nested
  read-only report-only marker;
- a future implementation must not treat `validation["valid"] == false` alone
  as permission to refuse;
- a future implementation must require an explicit internal strict requirement
  source plus an accepted orchestrator decision path;
- raw invalid validator output remains report-only evidence unless the
  orchestrator strict layer decides otherwise under a later implementation gate.

The next authorization-review route must make this authority chain mechanically
testable.

---

## Public API / Facade Stance

Architect resolves R82-C3-X NB-2:

```text
the first live implementation candidate must be internal-only and must not add
or depend on public Ruby facade, CLI, env, config, manifest, loader/report, or
CompatibilityReport strict-source exposure.
```

Accepted stance:

- `IgniterLang.compile(...)` signature remains closed;
- CLI and `bin/igc` remain closed;
- no strict flag, env/config lookup, manifest lookup, generated/defaulted strict
  source, or loader/report source is authorized;
- first implementation authorization review must require proof that strict
  behavior is reachable only through the explicitly authorized internal
  `CompilerOrchestrator` construction/test seam;
- if a future card argues that direct `IgniterLang.compile` callers may observe
  `refused` or `configuration_error`, that is a public-surface question and
  must be routed back before implementation.

Public API/CLI remains closed.

---

## `report.pass_result` Policy

Architect accepts the live policy from C1-P1:

```text
report.pass_result: "ok" remains invariant for all PROP-038 strict terminal
paths in this route.
```

Applies to:

- strict digest mismatch terminal path;
- malformed strict requirement `configuration_error`;
- strict terminal paths evaluated only after baseline report enrichment with
  `pass_result == "ok"`.

Does not apply to:

- ordinary parse/type/OOF failures;
- assembler failures;
- runtime smoke failures;
- future strict sources evaluated before baseline report exists.

Strict terminal status belongs to orchestration/result status, not to
`report["pass_result"]`.

---

## `configuration_error` Public Surface

Architect accepts the C1-P1 recommendation:

```text
configuration_error shares the strict terminal public key-set allowlist.
```

Accepted public key-set:

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

Differences between `refused` and `configuration_error` are values and
diagnostics, not keys.

No raw strict source payload, `strict_requirement` object, nested validation
object, or internal wrapper evidence object may appear as a public top-level
field.

---

## Non-Persisting / No-Sidecar Stance

Architect accepts the non-persisting first-slice stance:

- do not call `CompilerOrchestrator#refusal` for PROP-038 strict terminal paths;
- do not write `.compilation_report.json`;
- do not write a distinct PROP-038 report;
- do not create or mutate `.igapp`;
- do not call `Assembler.assemble_artifacts` on strict terminal paths;
- do not append nested validation diagnostics to top-level report diagnostics;
- preserve ordinary parse, OOF, assembler, runtime-smoke, and internal-error
  refusal behavior unchanged.

Persisted refusal report behavior remains closed.

---

## Proof And Regression Requirements

The next implementation authorization review must require an exact command
matrix covering at least:

- syntax checks for any live Ruby files requested in write scope;
- a new live implementation proof script, if implementation is authorized;
- the existing PROP-038 proof chain;
- the R81 strict-refusal result-shape proof;
- report-only invalid validation still compiles and assembles unchanged;
- no strict source / nil strict source keeps current behavior;
- malformed strict requirement yields `configuration_error` target shape under
  internal strict source only;
- strict digest mismatch yields `refused` target shape under internal strict
  source only;
- no sidecar, report, produced path, or `.igapp` for strict terminal paths;
- `CompilerOrchestrator#refusal` not called for strict terminal paths;
- public key-set exact allowlist;
- nested diagnostics isolation;
- no public API/CLI widening;
- ordinary parse, OOF, assembler, and runtime-smoke refusal behavior unchanged.

---

## Pressure Verdict

R82-C3-X verdict:

```text
proceed
blockers: none
non-blocking notes: 2
```

Architect accepts the pressure result.

NB-1 resolved by naming the orchestrator-level strict requirement decision path
as the live authority source.

NB-2 resolved by requiring the first live implementation candidate to remain
internal-only and not exposed through public Ruby facade or CLI.

---

## Remaining Blockers Before Implementation

The following blockers remain open before any implementation card can run:

1. Explicit implementation authorization decision.
2. Exact live write scope confirmed in that authorization.
3. Explicit authorization for `CompilerOrchestrator` changes.
4. Explicit authorization for `CompilerResult` changes.
5. Exact implementation proof command matrix.
6. Proof that strict source is internal-only and not public API/CLI reachable.
7. Proof that validator `compile_refusal_authorized: false` remains nested
   evidence and is not treated as authority.
8. Proof that `report.pass_result: "ok"` remains invariant for strict terminal
   paths.
9. Proof that `configuration_error` shares the strict terminal public key-set.
10. Proof that no sidecar/report/`.igapp` is produced for strict terminal paths.
11. Proof that ordinary refusal/report behavior remains unchanged.
12. Confirmation that fail-closed recompute-unavailable remains out of scope.

No implementation card may open directly from R82.

---

## Next Allowed Route

Authorize only an implementation authorization review route:

```text
prop038-strict-refusal-live-implementation-authorization-review-v0
```

Allowed next card boundary:

```text
Card: S3-R83-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-strict-refusal-live-implementation-authorization-review-v0

Goal:
Decide whether a bounded internal-only PROP-038 strict-refusal live
implementation may begin, using the accepted R82 scope review and R81
proof-local evidence.

Scope:
- Read:
  - igniter-lang/docs/gates/prop038-strict-refusal-live-implementation-scope-decision-v0.md
  - igniter-lang/docs/tracks/prop038-strict-refusal-live-implementation-scope-review-v0.md
  - igniter-lang/docs/tracks/prop038-live-implementation-touchpoint-survey-v0.md
  - igniter-lang/docs/discussions/prop038-live-implementation-scope-pressure-v0.md
  - igniter-lang/docs/gates/prop038-strict-refusal-result-shape-proof-acceptance-decision-v0.md
  - igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md
- Decide: authorize bounded internal-only implementation / hold / redirect /
  reject.
- If authorizing, define exact implementation boundary:
  - write scope;
  - `CompilerOrchestrator` changes allowed;
  - `CompilerResult` changes allowed;
  - internal-only strict source/test seam;
  - non-persisting/no-sidecar/no-report behavior;
  - proof/regression matrix;
  - excluded surfaces.
- Do not authorize public API/CLI widening, persisted reports, `.igapp`,
  loader/report, CompatibilityReport, diagnostics centralization, runtime, or
  production behavior.

Deliver:
- Decision doc in `igniter-lang/docs/gates/`
- Compact decision summary
- Exact implementation card boundary or hold reasons
```

No implementation card may open directly from this decision.

---

## Preserved Closed Surfaces

This decision preserves closure of:

- live compile refusal implementation;
- public API/CLI widening;
- persisted reports or sidecars;
- parser, TypeChecker, SemanticIR changes;
- assembler or `.igapp` mutation;
- loader/report behavior;
- CompatibilityReport behavior;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`, receipts, signing;
- dispatch migration;
- RuntimeMachine and Gate 3 widening;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, and production behavior.
