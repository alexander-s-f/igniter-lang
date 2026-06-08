# PROP-038 Internal Orchestrator Strict Source Status Decision v0

Card: S3-R79-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-internal-orchestrator-strict-source-status-decision-v0
Route: UPDATE
Status: accepted-design-implementation-held
Date: 2026-05-19

---

## Decision

Accept the R79 internal orchestrator strict-source/status design.

Authorize only the next narrower design route:

```text
strict-refusal-result-shape-and-nonpersisting-path-design-v0
```

This decision does not authorize implementation. Live compile refusal remains
closed. Report-only remains the current live PROP-038 behavior.

This decision does not authorize live compiler/orchestrator behavior changes,
public API/CLI widening, `CompilerResult` changes, persisted reports or
sidecars, parser/TypeChecker/SemanticIR changes, assembler or `.igapp` mutation,
loader/report behavior, CompatibilityReport behavior, diagnostics
centralization, dispatch migration, RuntimeMachine behavior, Gate 3 widening,
Ledger/TBackend behavior, BiHistory, stream/OLAP, cache, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/org/indexes/prop038-internal-strict-source-status-orientation-map-v0.md`
- `igniter-lang/docs/tracks/internal-orchestrator-strict-source-and-status-design-v0.md`
- `igniter-lang/docs/tracks/prop038-refusal-report-and-result-surface-survey-v0.md`
- `igniter-lang/docs/discussions/prop038-internal-strict-source-status-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-live-refusal-implementation-boundary-design-decision-v0.md`
- `igniter-lang/docs/gates/prop038-strict-mode-refusal-trigger-proof-local-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round78-status-curation-v0.md`

---

## Accepted Design

Architect accepts the internal strict source direction as a design candidate:

```text
internal orchestrator constructor option only
```

Accepted design stance:

- the source is internal to `CompilerOrchestrator`;
- the first design shape is constructor-only;
- it is not exposed through `IgniterLang.compile(...)`;
- it is not exposed through CLI or `bin/igc`;
- it is not read from `.igapp`, manifest, loader/report, CompatibilityReport,
  environment, config, or defaults;
- absence of the strict source preserves current report-only behavior;
- malformed strict source behavior remains open and must not be left to
  implementation discretion.

The proposed internal source vocabulary is accepted as design vocabulary only:

```text
compiler_profile_contract_strict_requirement
```

This is not accepted as a live constructor API, public API, CLI input, manifest
field, or runtime capability.

---

## Status And Result Stance

Architect accepts the layered vocabulary distinction:

| Vocabulary | Accepted status |
| --- | --- |
| `not_evaluated`, `allow`, `would_refuse`, `configuration_error` | Proof-local trigger model from R77. |
| `refused` | Future live compiler status candidate only. |
| `compiler_profile_contract_refusal.*` | Design/proof-local wrapper namespace only. |

`would_refuse` may graduate to live `refused` only behind a later live
implementation gate after result shape, public visibility, report behavior, and
assembly boundaries are accepted.

`CompilerResult` remains unchanged. Public result shape remains unchanged.

No top-level result fields, wrapper evidence fields, diagnostics exposure rules,
or public JSON shape changes are authorized by this decision.

---

## Refusal Report Strategy

Architect accepts the C1/C2 finding that the existing
`CompilerOrchestrator#refusal` path always writes a compilation report sidecar.

Therefore, the first future design candidate is:

```text
new non-persisting strict refusal path
```

This is a design candidate, not implementation authorization.

Accepted comparison:

| Strategy | C4-A status |
| --- | --- |
| Reuse existing `CompilerOrchestrator#refusal` | Deferred. It implies existing `.compilation_report.json` write behavior unless separately authorized. |
| New non-persisting strict refusal path | Accepted as the next design candidate. Not implemented. |
| Distinct PROP-038 refusal report policy | Deferred. Requires separate artifact/report policy. |

Do not modify `CompilerOrchestrator#refusal` unless a later gate explicitly
authorizes either reuse with persisted report behavior or a new no-write mode.

Persisted refusal reports and sidecars remain closed.

---

## Assembly And Artifact Stance

Architect preserves the current boundary:

```text
report_for_assembly = report
```

Accepted stance:

- current report-only path keeps current assembly behavior;
- strict source absent means current behavior unchanged;
- strict source with future `allow` means current assembly behavior unchanged;
- future live `refused`, if ever authorized, must skip assembly before
  `.igapp` artifacts are produced;
- no strict/refusal fields are authorized in `.igapp`;
- no assembler vocabulary changes are authorized;
- PROP-036 `compiler_profile_source.*` vocabulary must not be reused for
  PROP-038 strict refusal.

---

## Fail-Open / Fail-Closed Stance

Current accepted behavior remains:

```text
contract_digest_recompute_unavailable => fail_open_report_only
```

Fail-closed remains held.

Provider nil, provider non-Hash, provider exception, and validator exception
remain no-field/no-refusal unless a later Architect decision explicitly opens a
different policy.

Malformed strict requirement behavior is not yet closed. The next design route
must decide whether malformed strict requirement is ignored, treated as
configuration error, or handled by another explicitly named status.

---

## Pressure Verdict

R79-C3-X verdict:

```text
proceed
blockers: none
non-blocking notes: 1
```

Architect accepts the pressure result.

NB-1 resolution:

- The next design route must add a `public_result` key-set assertion.
- The next design route must add a nested-diagnostics isolation assertion.
- These are proof-matrix requirements for the next route, not blockers for R79.

Additional required carry-forward from pressure:

- C1 blocker #2 remains open: malformed strict requirement policy must be
  resolved before any implementation authorization.
- It must not be left to the implementation card to invent.

---

## Blockers Before Implementation Authorization

The following blockers remain open before any live implementation can be
authorized:

1. Accepted internal strict source shape and validation behavior.
2. Accepted malformed strict requirement policy.
3. Accepted strict-refusal result shape.
4. Explicit `CompilerResult` authority if result shape changes.
5. Accepted non-persisting strict refusal path or accepted persisted report
   policy.
6. Accepted public result visibility model and key-set behavior.
7. Accepted nested vs public diagnostic exposure rule.
8. Accepted assembly skip behavior and `report_for_assembly` invariants.
9. Accepted public API/CLI non-widening proof or explicit widening decision.
10. Accepted legacy/no-field/no-refusal behavior for provider and validator
    errors.
11. Accepted fail-open policy for recompute unavailable, or a separate
    fail-closed recovery design.
12. Accepted proof-local-to-live graduation rule:
    `would_refuse` may become `refused` only for mismatch.
13. Exact authorized write scope.
14. Updated proof/regression command matrix with syntax checks for any future
    proof scripts or live files.

No implementation card may open directly from R79.

---

## Next Allowed Route

Authorize only a design route:

```text
strict-refusal-result-shape-and-nonpersisting-path-design-v0
```

Allowed next card boundary:

```text
Card: S3-R80-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: strict-refusal-result-shape-and-nonpersisting-path-design-v0

Goal:
Design the strict-refusal result shape and non-persisting orchestrator path for
a possible future PROP-038 live refusal implementation, without authorizing
implementation.

Allowed:
- design strict-refusal result/status shape;
- design the non-persisting orchestrator refusal path as a future candidate;
- decide malformed strict requirement policy;
- define public result key-set behavior;
- define nested vs public diagnostic exposure;
- preserve current report-only behavior;
- preserve legacy/no-source/no-refusal behavior;
- preserve `report_for_assembly` and `.igapp` boundaries;
- refine proof/regression requirements, including:
  - public_result key-set assertion;
  - nested-diagnostics isolation assertion;
  - existing proof chain;
  - no persisted report/sidecar assertion if non-persisting path remains
    preferred;
  - no public API/CLI widening assertion;
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

No implementation card may open directly from this decision.

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
