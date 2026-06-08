# PROP-038 Live Refusal Implementation Boundary Design Decision v0

Card: S3-R78-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-live-refusal-implementation-boundary-design-decision-v0
Route: UPDATE
Status: accepted-boundary-design-implementation-held
Date: 2026-05-19

---

## Decision

Accept the PROP-038 live-refusal implementation boundary design.

Authorize only a narrower design route next:

```text
internal-orchestrator-strict-source-and-status-design-v0
```

This decision does not authorize implementation. Live compile refusal remains
closed. Report-only remains the current live behavior.

This decision does not authorize live compiler/orchestrator behavior changes,
public API/CLI widening, `CompilerResult` changes, persisted reports or
sidecars, parser/TypeChecker/SemanticIR changes, assembler or `.igapp` mutation,
loader/report behavior, CompatibilityReport behavior, diagnostics
centralization, dispatch migration, RuntimeMachine behavior, Gate 3 widening,
Ledger/TBackend behavior, BiHistory, stream/OLAP, cache, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/org/indexes/prop038-live-refusal-boundary-design-orientation-map-v0.md`
- `igniter-lang/docs/tracks/prop038-live-refusal-implementation-boundary-design-v0.md`
- `igniter-lang/docs/tracks/prop038-live-refusal-current-pipeline-surface-survey-v0.md`
- `igniter-lang/docs/discussions/prop038-live-refusal-boundary-design-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-strict-mode-refusal-trigger-proof-local-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-strict-mode-refusal-trigger-design-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-live-validator-implementation-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round77-status-curation-v0.md`

---

## Accepted Boundary Design

Architect accepts the remaining live-refusal blocker map.

The following blockers remain open before any live implementation authorization:

| Blocker | Status |
| --- | --- |
| Production/compiler strict source | Open |
| Live compiler/orchestrator implementation boundary | Open |
| Ruby API source shape | Open / deferred |
| CLI source shape | Open / deferred |
| Manifest/profile policy source shape | Open / deferred |
| `CompilerResult` / status model | Open |
| Refusal report behavior | Open |
| Fail-closed policy for recompute unavailable | Open / not first |
| `.igapp` / assembly strict-mode boundary | Open |
| Loader/report boundary | Closed / not authorized |
| CompatibilityReport boundary | Closed / not authorized |
| Diagnostics centralization | Closed / not authorized |
| Runtime/production readiness | Closed / not authorized |

Minimum rule accepted:

```text
R77 would_refuse may graduate to live refused only behind a separate live
implementation gate that closes source, status, result, report, and assembly
boundaries.
```

---

## Live Strict Source Decision

No live strict source is implemented or fully chosen by this decision.

Architect accepts the internal orchestrator option as the first source candidate
to design next:

```text
internal orchestrator option
```

Accepted source table:

| Source option | C4-A status |
| --- | --- |
| Internal orchestrator option | First candidate for next design route only. Not implemented. |
| Ruby facade/API option | Deferred. Public API remains closed. |
| CLI flag | Deferred. CLI remains closed. |
| Manifest/profile policy | Deferred. `.igapp`, loader/report, and profile policy remain closed. |
| Gate-controlled profile requirement | Remains proof/design source only. Not a production/compiler source. |

Reason:

- internal orchestrator option is the narrowest live source candidate;
- it can be designed without committing public API/CLI semantics;
- it can preserve legacy no-source/no-field/no-refusal behavior;
- it keeps manifest/profile policy, loader/report, CompatibilityReport, runtime,
  and production closed.

---

## Pipeline Placement

Architect accepts the proposed future placement as design guidance:

```text
post-validation, pre-assembly compiler gate
```

Accepted design stance:

- report-only validation remains current live behavior;
- a future strict trigger, if later authorized, would evaluate after contract
  validation evidence exists;
- if the decision is `allow`, current success/report-only behavior may continue;
- if a later gate authorizes live `refused`, assembly should not run for that
  refused compile;
- `.igapp` must not be mutated by refusal behavior unless a separate artifact
  policy explicitly authorizes it;
- `report_for_assembly` remains a protected boundary for the next design route.

This placement is design guidance only. It is not implementation authorization.

---

## `CompilerResult`, Status, And Refusal Report Stance

Architect accepts the design direction that future live refusal likely needs a
new explicit status:

```text
refused
```

But this status remains design-only. It is not live behavior.

Accepted stance:

- proof-local `would_refuse` may graduate to live `refused` only in a later card;
- `CompilerResult` schema remains unchanged now;
- public result shape remains unchanged now;
- no persisted refusal report or sidecar is authorized now;
- `IgniterLang::Diagnostics` centralization remains closed.

The future wrapper evidence shape shown in C1-P1 is accepted only as design
vocabulary:

```json
{
  "status": "refused",
  "reason_code": "compiler_profile_contract_refusal.contract_digest_mismatch",
  "evidence_code": "compiler_profile_contract.contract_digest_mismatch",
  "strict_validation_source": "internal_orchestrator_option",
  "compile_refusal_authorized": true
}
```

This is not accepted as `CompilerResult` schema.

---

## Fail-Open / Fail-Closed Stance

Accepted current stance:

```text
contract_digest_recompute_unavailable => fail_open_report_only
```

Fail-closed remains held. Any future fail-closed policy requires a separate
operational recovery design and explicit Architect authorization.

---

## Pressure Verdict

R78-C3-X verdict:

```text
proceed
blockers: none
non-blocking notes: 2
```

Architect accepts the pressure result.

NB-1 resolution:

- The first appearance of `compile_refusal_authorized: true` is accepted only as
  a design sketch for the terminal state of a future live refused result.
- Current code emits no `compile_refusal_authorized: true`.
- Current live validator, proof-local trigger, and report-only integration keep
  `compile_refusal_authorized=false`.
- The flag may become true only after a separate implementation gate explicitly
  authorizes live refused compile behavior.

NB-2 resolution:

- There is a real design tension between "no persisted report" and the existing
  `CompilerOrchestrator#refusal` path, which writes a compilation report.
- This does not block R78 acceptance.
- The next design route must resolve this tension explicitly before any
  implementation authorization.

Accepted options for the next design route to evaluate:

| Option | Meaning |
| --- | --- |
| Reuse existing `#refusal` | Accept compilation report write and design its shape/semantics. |
| New non-persisting refusal path | Return a refusal result without writing a report; requires explicit new path design. |
| Distinct PROP-038 refusal report | Write a separate schema artifact; requires separate report/artifact policy. |

---

## Proof And Regression Requirements

Architect accepts the proof categories from C1-P1 as sufficient design basis for
the next design route:

- existing proof chain remains PASS;
- live strict source proof;
- legacy/error path proof;
- assembly and artifact proof;
- result/report proof;
- boundary guard proof.

The next design route must refine these into an implementation-ready command
matrix, including syntax checks for any new proof scripts if implementation is
later requested.

---

## Current Live Behavior

Report-only remains current live behavior.

Live compile refusal remains closed.

Loader/report and CompatibilityReport remain closed.

Runtime and production behavior remain closed.

---

## Next Allowed Route

Authorize only a design route:

```text
internal-orchestrator-strict-source-and-status-design-v0
```

Allowed next card boundary:

```text
Card: S3-R79-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: internal-orchestrator-strict-source-and-status-design-v0

Goal:
Design the internal orchestrator strict source and status boundary for a
possible future PROP-038 live refusal implementation, resolving the existing
`#refusal` report-write tension before any implementation can be considered.

Allowed:
- design the internal orchestrator strict source shape;
- decide where the source is supplied and validated inside the orchestrator;
- design status/result vocabulary for a possible live refused compile;
- decide whether a future live refusal should reuse `CompilerOrchestrator#refusal`,
  use a new non-persisting refusal path, or require a distinct PROP-038 refusal
  report policy;
- preserve report-only behavior as current live behavior;
- preserve `report_for_assembly` and `.igapp` boundaries unless explicitly
  designing a future refused path that skips assembly;
- refine implementation proof/regression requirements;
- list exact blockers before implementation authorization.

Not allowed:
- code implementation;
- live compile refusal;
- compiler/orchestrator behavior changes;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted reports or sidecars;
- parser, TypeChecker, SemanticIR, assembler, `.igapp`, loader/report,
  CompatibilityReport, diagnostics centralization, RuntimeMachine, Gate 3,
  Ledger/TBackend, BiHistory, stream/OLAP, cache, or production behavior.
```

No implementation card may open directly from R78.

---

## Preserved Closed Surfaces

This decision preserves closure of:

- live compiler/orchestrator behavior changes;
- live compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
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
