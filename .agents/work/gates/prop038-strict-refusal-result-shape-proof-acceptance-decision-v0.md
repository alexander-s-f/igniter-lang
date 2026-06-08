# PROP-038 Strict Refusal Result Shape Proof Acceptance Decision v0

Card: S3-R81-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-strict-refusal-result-shape-proof-acceptance-decision-v0
Route: UPDATE
Status: accepted-proof-local-closure-implementation-held
Date: 2026-05-19

---

## Decision

Accept the proof-local PROP-038 strict-refusal result-shape experiment.

The R80 proof-local authorization is satisfied.

This decision does not authorize live implementation. Live compile refusal
remains closed. Report-only remains the current live PROP-038 behavior.

This decision does not authorize live compiler/orchestrator behavior changes,
`CompilerResult` changes, public API/CLI widening, persisted reports or
sidecars, parser/TypeChecker/SemanticIR changes, assembler or `.igapp` mutation,
loader/report behavior, CompatibilityReport behavior, diagnostics
centralization, dispatch migration, RuntimeMachine behavior, Gate 3 widening,
Ledger/TBackend behavior, BiHistory, stream/OLAP, cache, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-strict-refusal-result-shape-proof-local-v0.md`
- `igniter-lang/docs/discussions/prop038-strict-refusal-result-shape-proof-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-strict-refusal-result-shape-decision-v0.md`
- `igniter-lang/docs/gates/prop038-internal-orchestrator-strict-source-status-decision-v0.md`
- `igniter-lang/docs/gates/prop038-strict-mode-refusal-trigger-proof-local-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round80-status-curation-v0.md`
- `igniter-lang/experiments/prop038_strict_refusal_result_shape_proof/out/prop038_strict_refusal_result_shape_proof_summary.json`

---

## Proof-Local Files

Accepted proof-local files:

- `igniter-lang/experiments/prop038_strict_refusal_result_shape_proof/prop038_strict_refusal_result_shape_proof.rb`
- `igniter-lang/experiments/prop038_strict_refusal_result_shape_proof/out/prop038_strict_refusal_result_shape_proof_summary.json`
- `igniter-lang/docs/tracks/prop038-strict-refusal-result-shape-proof-local-v0.md`
- `igniter-lang/docs/discussions/prop038-strict-refusal-result-shape-proof-pressure-v0.md`

Org-sidecar orientation was present for the round, but it is non-authority and
not part of the compiler/profile proof surface.

No `igniter-lang/lib/` or `igniter-lang/bin/` files are authorized by this
decision.

---

## Command Matrix

Accepted command matrix:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/experiments/prop038_strict_refusal_result_shape_proof/prop038_strict_refusal_result_shape_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_strict_refusal_result_shape_proof/prop038_strict_refusal_result_shape_proof.rb` | PASS |

Proof result:

```text
status: PASS
cases: 3
checks: 44
failed_checks: 0
```

Pressure reviewer independently re-ran both commands and confirmed the same
results.

---

## Accepted Proof Coverage

Architect accepts the following proof-local coverage:

| Surface | C3-A status |
| --- | --- |
| Strict-refusal target shape | Accepted proof-local. |
| Malformed strict requirement `configuration_error` target shape | Accepted proof-local. |
| Strict-refusal public key-set allowlist | Accepted proof-local. |
| `compilation_report_path: null` | Accepted proof-local. |
| Nested diagnostics isolation | Accepted proof-local. |
| Public wrapper diagnostic shape | Accepted proof-local. |
| No sidecar / no report / no artifact target behavior | Accepted proof-local. |
| No `.igapp` target artifact | Accepted proof-local. |
| Legacy/report-only anchors referenced and not contradicted | Accepted proof-local. |
| No live implementation | Confirmed. |

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

Accepted proof-local diagnostic codes:

```text
compiler_profile_contract_refusal.contract_digest_mismatch
compiler_profile_contract_refusal.strict_requirement_malformed
```

Raw validator diagnostic remains nested:

```text
compiler_profile_contract.contract_digest_mismatch
```

---

## Pressure Verdict

R81-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: 1
```

Architect accepts the pressure result.

NB-1 resolution:

- `report.pass_result: "ok"` is accepted as the proof-local target invariant for
  the strict digest-mismatch and malformed strict-requirement target shapes
  proven in R81.
- Before any live implementation authorization, a later design/review must
  explicitly decide whether this invariant applies to all future strict-refusal
  paths or only to digest-validation strict refusal paths.
- The proof-local `configuration_error` target shares the accepted proof-local
  public key-set. Before any live implementation authorization, a later
  design/review must explicitly decide whether `configuration_error` permanently
  shares that public surface or receives a smaller configuration-error-specific
  surface.

These are not blockers for R81 proof-local closure. They are blockers before
live implementation authorization.

---

## Remaining Blockers Before Live Implementation

The following blockers remain open before any live implementation can be
authorized:

1. Explicit `CompilerResult` authority for `status: "refused"` and
   `status: "configuration_error"` public result behavior.
2. Exact live write scope for the non-persisting orchestrator path.
3. Exact decision that `CompilerOrchestrator#refusal` remains unused for the
   first strict-refusal path, or an explicit persisted-report policy if reused.
4. Live policy for `report.pass_result: "ok"` across strict-refusal paths.
5. Live public-surface policy for `configuration_error`.
6. Accepted live public wrapper diagnostic placement.
7. Accepted live nested diagnostics isolation.
8. Accepted no-report/no-sidecar behavior under live proof.
9. Accepted assembly skip and `.igapp` non-mutation behavior under live proof.
10. Accepted legacy/no-source/no-refusal preservation under live proof.
11. Accepted no public API/CLI widening proof.
12. Accepted fail-open recompute-unavailable behavior, or separate fail-closed
    recovery design.
13. Exact proof command matrix, including syntax checks for any future live
    files.

No live implementation card may open directly from R81.

---

## Next Allowed Route

Authorize only an implementation-scope design/review route:

```text
prop038-strict-refusal-live-implementation-scope-review-v0
```

Allowed next card boundary:

```text
Card: S3-R82-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: prop038-strict-refusal-live-implementation-scope-review-v0

Goal:
Design and review the exact live implementation boundary for PROP-038 strict
refusal using the accepted R81 proof-local result-shape evidence, without
authorizing implementation.

Allowed:
- name exact candidate live write scope;
- decide whether a future implementation would need `CompilerResult` authority;
- decide whether a future implementation would need `CompilerOrchestrator`
  authority;
- decide whether `configuration_error` shares the strict-refusal public key-set
  or needs a smaller public surface;
- decide whether `report.pass_result: "ok"` remains invariant for all strict
  terminal paths or only digest-validation strict refusal;
- preserve non-persisting/no-sidecar/no-report stance unless explicitly routing
  a separate persisted-report policy question;
- preserve report-only current live behavior;
- preserve public API/CLI closure;
- produce exact blockers before any implementation authorization card.

Not allowed:
- code implementation;
- live compile refusal;
- live compiler/orchestrator behavior changes;
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
- `CompilerResult` changes;
- public API/CLI widening;
- persisted reports or sidecars from live code;
- parser, TypeChecker, SemanticIR changes;
- assembler or `.igapp` mutation;
- loader/report behavior;
- CompatibilityReport behavior;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`, receipts, signing;
- dispatch migration;
- RuntimeMachine and Gate 3 widening;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, and production behavior.
