# PROP-038 Strict Refusal Result Shape Decision v0

Card: S3-R80-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-strict-refusal-result-shape-decision-v0
Route: UPDATE
Status: accepted-design-proof-local-next-implementation-held
Date: 2026-05-19

---

## Decision

Accept the R80 strict-refusal result-shape and non-persisting path design.

Authorize only a proof-local route next:

```text
prop038-strict-refusal-result-shape-proof-local-v0
```

This decision does not authorize live implementation. Live compile refusal
remains closed. Report-only remains the current live PROP-038 behavior.

This decision does not authorize live compiler/orchestrator behavior changes,
public API/CLI widening, `CompilerResult` changes, persisted reports or
sidecars, parser/TypeChecker/SemanticIR changes, assembler or `.igapp` mutation,
loader/report behavior, CompatibilityReport behavior, diagnostics
centralization, dispatch migration, RuntimeMachine behavior, Gate 3 widening,
Ledger/TBackend behavior, BiHistory, stream/OLAP, cache, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/org/indexes/prop038-strict-refusal-result-shape-orientation-map-v0.md`
- `igniter-lang/docs/tracks/strict-refusal-result-shape-and-nonpersisting-path-design-v0.md`
- `igniter-lang/docs/tracks/prop038-public-result-and-diagnostics-proof-surface-survey-v0.md`
- `igniter-lang/docs/discussions/prop038-strict-refusal-result-shape-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-internal-orchestrator-strict-source-status-decision-v0.md`
- `igniter-lang/docs/gates/prop038-live-refusal-implementation-boundary-design-decision-v0.md`
- `igniter-lang/docs/gates/prop038-strict-mode-refusal-trigger-proof-local-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round79-status-curation-v0.md`

---

## Accepted Status And Result Design

Architect accepts `refused` as the future design status for strict digest
refusal.

Accepted layering:

| Layer | C4-A decision |
| --- | --- |
| Orchestration status | Future design value: `refused`. Not live. |
| `CompilerResult["status"]` | Future design value: `refused`. Requires later authority. |
| `report["pass_result"]` | Preserve baseline `ok`; do not encode strict refusal by mutating `pass_result`. |
| Trigger decision | `would_refuse` remains proof-local until a later live gate. |
| CLI exit/output | Closed. Requires separate public surface authority. |

`refused` is not accepted as live behavior. It is accepted only as future design
vocabulary and proof-local target shape.

`CompilerResult` remains unchanged by this decision.

---

## Public Result Key-Set Decision

Architect accepts the strict-refusal public key-set allowlist as design
vocabulary:

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

This is not a live public result schema. It is the target shape for the next
proof-local route.

Required negative assertions:

- no `report` key;
- no `compiler_profile_contract_validation` key;
- no `strict_refusal` key;
- no `wrapper_evidence` key;
- no `compile_refusal_authorized` key;
- no raw nested validator diagnostic objects as top-level fields.

R80-C3-X NB-1 resolution:

- the future strict-refusal proof is the canonical owner of the strict-refusal
  public key-set assertion;
- `production_compiler_cli_proof` remains the regression anchor for current
  success, OOF, error, and ordinary refusal public shapes;
- the two proofs must not compete for the same future strict-refusal surface.

---

## `compilation_report_path` Decision

Architect accepts the null-present convention for the future non-persisting
strict-refusal shape:

```json
{
  "compilation_report_path": null
}
```

R80-C3-X NB-2 resolution:

- the field is present with `null` in the target strict-refusal result shape;
- `null` means no sidecar compilation report was written;
- this is design/proof-local vocabulary only;
- no persisted report path, sidecar, or report schema is authorized.

The next proof-local route must assert this field is present and null for the
strict-refusal target shape.

---

## Diagnostics Decision

Architect accepts the nested diagnostics isolation policy.

Accepted design stance:

- nested validator diagnostics remain under the internal report:
  `report["compiler_profile_contract_validation"]["diagnostics"]`;
- nested validator diagnostics are not appended to top-level
  `report["diagnostics"]`;
- nested validator diagnostics are not consumed directly by
  `Diagnostics.errors` or `Diagnostics.warnings`;
- public result may contain one wrapper diagnostic in the target shape;
- raw validator diagnostic code such as
  `compiler_profile_contract.contract_digest_mismatch` must not appear as a
  public top-level diagnostic unless a later decision explicitly authorizes it;
- `IgniterLang::Diagnostics` centralization remains closed.

Accepted design-only wrapper code:

```text
compiler_profile_contract_refusal.contract_digest_mismatch
```

The next proof-local route must assert both public wrapper behavior and nested
diagnostics isolation.

---

## Malformed Strict Requirement Policy

Architect accepts the malformed strict requirement policy:

```text
malformed strict requirement => configuration_error
```

This closes the R79 malformed-policy design blocker, but only at the design and
proof-local level.

Accepted stance:

- malformed strict requirement is not ignored;
- malformed strict requirement is not digest mismatch;
- malformed strict requirement is not validator failure;
- malformed strict requirement must not be produced when no strict source
  exists;
- malformed strict requirement must not become live compiler behavior without a
  later implementation gate;
- if later live, it must stop before assembly and use a distinct reason from
  contract digest mismatch.

Accepted design-only reason code:

```text
compiler_profile_contract_refusal.strict_requirement_malformed
```

The next proof-local route must sketch and verify a configuration-error target
shape with the same level of precision as the `refused` target shape.

---

## Non-Persisting Path Decision

Architect accepts the non-persisting path as the first future implementation
candidate, but does not authorize implementation.

Accepted design stance:

- strict refusal must not call existing `CompilerOrchestrator#refusal`;
- strict refusal must not write `.compilation_report.json`;
- strict refusal must not write a distinct PROP-038 report;
- strict refusal must not create or mutate `.igapp`;
- strict refusal must not call `Assembler.assemble_artifacts`;
- existing parse, OOF, assembler, runtime-smoke, and ordinary compiler refusal
  paths remain unchanged.

Persisted refusal report behavior remains closed.

---

## Assembly And Artifact Stance

Architect preserves the current report-only assembly boundary:

```text
report_for_assembly = report
```

Accepted stance:

- report-only invalid digest continues to compile and assemble unchanged;
- strict valid, if later live, continues current assembly behavior;
- strict mismatch refused, if later live, skips assembly before `.igapp`
  artifacts;
- malformed strict requirement, if later live as terminal configuration error,
  skips assembly before `.igapp` artifacts;
- no strict/refusal fields are authorized in `.igapp`;
- no assembler vocabulary changes are authorized.

---

## Pressure Verdict

R80-C3-X verdict:

```text
proceed
blockers: none
non-blocking notes: 2
```

Architect accepts the pressure result.

NB-1 resolved by assigning canonical strict-refusal public key-set ownership to
the future strict-refusal proof.

NB-2 resolved by accepting `compilation_report_path: null` as the target
non-persisting shape convention.

Additional pressure carry-forward:

- the malformed `configuration_error` internal target shape must be specified as
  concretely as the `refused` target shape before any live implementation
  authorization;
- this is required in the next proof-local route.

---

## Blockers Before Live Implementation Authorization

The following blockers remain open before any live implementation can be
authorized:

1. Proof-local strict-refusal target shape accepted.
2. Proof-local malformed configuration-error target shape accepted.
3. Explicit `CompilerResult` authority for `status: "refused"` and public
   result key-set behavior.
4. Explicit acceptance of non-persisting orchestrator path and exact write
   scope.
5. Explicit decision that existing `CompilerOrchestrator#refusal` is not reused
   for the first strict-refusal path, or explicit persisted-report policy if
   reused.
6. Accepted nested diagnostics exposure policy under proof.
7. Accepted public wrapper diagnostic shape under proof.
8. Accepted no-report/no-sidecar behavior under proof.
9. Accepted assembly skip and `.igapp` non-mutation behavior under proof.
10. Accepted legacy/no-source/no-refusal preservation under proof.
11. Accepted no public API/CLI widening proof.
12. Accepted fail-open recompute-unavailable behavior, or separate fail-closed
    recovery design.
13. Exact proof command matrix, including syntax checks for any new proof script
    and any future authorized live files.
14. Exact live write scope, if live implementation is ever requested.

No live implementation card may open directly from R80.

---

## Next Allowed Route

Authorize only a proof-local route:

```text
prop038-strict-refusal-result-shape-proof-local-v0
```

Allowed next card boundary:

```text
Card: S3-R81-C1-P1
Agent: [Igniter-Lang Research Agent]
Role: research-agent
Track: prop038-strict-refusal-result-shape-proof-local-v0

Goal:
Build a proof-local strict-refusal result-shape experiment that verifies the
accepted R80 target shape without changing live compiler/orchestrator behavior.

Allowed:
- work only under a new proof-local experiment directory;
- model strict-refusal target result shape;
- model malformed strict requirement configuration-error target shape;
- assert strict-refusal public key-set allowlist;
- assert `compilation_report_path` is present and null for the non-persisting
  target shape;
- assert nested diagnostics isolation;
- assert public wrapper diagnostic shape;
- assert no sidecar/report/artifact path is produced by the proof-local target;
- assert legacy/report-only current proof anchors remain referenced and not
  contradicted;
- produce a JSON summary with pass/fail, cases, and command matrix.

Not allowed:
- live compiler/orchestrator code changes;
- live compile refusal;
- `CompilerResult` code changes;
- public API/CLI widening;
- persisted reports or sidecars;
- parser, TypeChecker, SemanticIR, assembler, `.igapp`, loader/report,
  CompatibilityReport, diagnostics centralization, RuntimeMachine, Gate 3,
  Ledger/TBackend, BiHistory, stream/OLAP, cache, or production behavior.
```

No live implementation card may open directly from this decision.

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
