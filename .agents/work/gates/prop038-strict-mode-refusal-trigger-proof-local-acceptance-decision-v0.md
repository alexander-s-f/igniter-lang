# PROP-038 Strict Mode Refusal Trigger Proof-Local Acceptance Decision v0

Card: S3-R77-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-strict-mode-refusal-trigger-proof-local-acceptance-decision-v0
Route: UPDATE
Status: accepted-proof-local-trigger-closure
Date: 2026-05-19

---

## Decision

Accept the bounded PROP-038 strict-mode refusal trigger proof-local experiment.

The S3-R76-C4-A proof-local authorization is satisfied:

```text
prop038-strict-mode-refusal-trigger-proof-local-v0
```

This acceptance closes only the proof-local trigger model. It does not authorize
live compiler/orchestrator behavior changes, live compile refusal, public
API/CLI widening, `CompilerResult` changes, persisted reports or sidecars
outside proof-local experiment output, parser/TypeChecker/SemanticIR changes,
assembler or `.igapp` mutation, loader/report behavior, CompatibilityReport
behavior, diagnostics centralization, dispatch migration, RuntimeMachine
behavior, Gate 3 widening, Ledger/TBackend behavior, BiHistory, stream/OLAP,
cache, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-strict-mode-refusal-trigger-proof-local-v0.md`
- `igniter-lang/docs/discussions/prop038-strict-mode-refusal-trigger-proof-local-pressure-v0.md`
- `igniter-lang/experiments/prop038_strict_mode_refusal_trigger_proof/out/prop038_strict_mode_refusal_trigger_proof_summary.json`
- `igniter-lang/docs/gates/prop038-strict-mode-refusal-trigger-design-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round76-status-curation-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-live-validator-implementation-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`

---

## Accepted Changed Files

Accepted primary proof-local artifacts:

```text
igniter-lang/experiments/prop038_strict_mode_refusal_trigger_proof/prop038_strict_mode_refusal_trigger_proof.rb
igniter-lang/experiments/prop038_strict_mode_refusal_trigger_proof/out/prop038_strict_mode_refusal_trigger_proof_summary.json
igniter-lang/docs/tracks/prop038-strict-mode-refusal-trigger-proof-local-v0.md
```

Accepted refreshed regression artifact:

```text
igniter-lang/experiments/prop038_report_only_compiler_integration/out/prop038_report_only_compiler_integration_summary.json
```

The refreshed regression artifact is accepted only as the natural output of the
S3-R76-C4-A required rerun command. The observed semantic delta is the accepted
R74 live validator behavior: the invalid-contract report-only integration case
can now record `compiler_profile_contract.contract_digest_mismatch` alongside
existing validator diagnostics. No R67 code edit or behavior widening is
accepted by this decision.

No `igniter-lang/lib` files are accepted as changed by this card.

---

## Proof-Local Source Shape

Accepted proof-local strict requirement object:

```json
{
  "kind": "compiler_profile_contract_strict_requirement",
  "format_version": "0.1.0",
  "mode": "strict_contract_digest",
  "source": "proof_local_gate",
  "refusal_candidates": [
    "compiler_profile_contract.contract_digest_mismatch"
  ],
  "recompute_unavailable_policy": "fail_open_report_only",
  "compile_refusal_authorized": false
}
```

This shape remains proof-local. It is not a public API, CLI flag, `.igapp`
field, loader/report field, CompatibilityReport field, runtime object, or
production policy.

---

## Decision Vocabulary Status

Accepted proof-local decision vocabulary:

```text
not_evaluated
allow
would_refuse
configuration_error
```

Accepted boundary:

- `would_refuse` is proof-local model vocabulary only;
- `refused` is not introduced;
- `compiler_refusal_authorized=false` is preserved across all proof cases;
- no live compile refusal behavior is accepted.

---

## Wrapper Code Status

Accepted proof-local wrapper code:

```text
compiler_profile_contract_refusal.contract_digest_mismatch
```

It cites evidence:

```text
compiler_profile_contract.contract_digest_mismatch
```

Wrapper codes remain proof-local trigger-evaluation vocabulary only. They are
not accepted as:

- `IgniterLang::Diagnostics` entries;
- top-level report diagnostics;
- public API/CLI output;
- live compiler status;
- loader/report vocabulary;
- CompatibilityReport vocabulary.

---

## Proof Matrix Result

Accepted proof summary:

```text
kind=prop038_strict_mode_refusal_trigger_proof_summary
status=PASS
cases=12
checks=15
failed_checks=0
```

Accepted cases:

| Case | Decision | Status |
| --- | --- | --- |
| `report_only_valid_contract` | `not_evaluated` | PASS |
| `report_only_digest_mismatch_nested_only` | `not_evaluated` | PASS |
| `no_strict_source_not_evaluated` | `not_evaluated` | PASS |
| `strict_source_valid_contract_allow` | `allow` | PASS |
| `strict_source_digest_mismatch_would_refuse` | `would_refuse` | PASS |
| `strict_source_invalid_digest_held_control` | `allow` | PASS |
| `strict_source_unsupported_policy_configuration_error` | `configuration_error` | PASS |
| `strict_source_recompute_unavailable_fail_open` | `allow` | PASS |
| `nil_provider_no_field_no_refusal` | `not_evaluated` | PASS |
| `non_hash_provider_no_field_no_refusal` | `not_evaluated` | PASS |
| `provider_error_no_field_no_refusal` | `not_evaluated` | PASS |
| `validator_error_no_field_no_refusal` | `not_evaluated` | PASS |

Accepted candidate behavior:

| Diagnostic | Accepted proof-local behavior |
| --- | --- |
| `compiler_profile_contract.contract_digest_mismatch` | Only diagnostic that maps to `would_refuse`. |
| `compiler_profile_contract.contract_digest_invalid` | Held/control; does not map to `would_refuse`. |
| `compiler_profile_contract.contract_digest_policy_unsupported` | `configuration_error`; not refusal. |
| `compiler_profile_contract.contract_digest_recompute_unavailable` | `fail_open_report_only`; does not map to `would_refuse`. |

Accepted boundary checks:

- top-level diagnostics unchanged;
- public result unchanged;
- `CompilerResult` unchanged;
- `.igapp` not mutated;
- loader/report untouched;
- CompatibilityReport untouched;
- runtime untouched;
- production untouched;
- wrapper codes appear only in proof-local trigger evaluation.

---

## Command Matrix

Accepted command matrix:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/experiments/prop038_strict_mode_refusal_trigger_proof/prop038_strict_mode_refusal_trigger_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_strict_mode_refusal_trigger_proof/prop038_strict_mode_refusal_trigger_proof.rb` | PASS |
| `ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |

Accepted regression summaries after rerun:

```text
compiler_profile_contract_proof_summary.json
  status=PASS cases=13 checks=30 failed=0

prop038_report_only_compiler_integration_summary.json
  status=PASS cases=5 checks=20 failed=0
```

---

## Pressure Verdict

R77-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: 1
```

Architect accepts the pressure result.

NB-1 resolution:

- The refreshed
  `prop038_report_only_compiler_integration_summary.json` artifact is accepted
  as expected output of the required regression command.
- This does not widen the C1-I implementation scope.
- This does not authorize code changes or behavior changes in the R67 report-only
  integration path.

---

## Current Live Behavior

Report-only remains current live behavior.

Live compile refusal remains closed.

The following remain closed:

- live compiler/orchestrator behavior changes;
- public API/CLI strict mode;
- `CompilerResult` strict/refusal fields;
- persisted refusal reports or sidecars;
- `.igapp` strict/refusal mutation;
- loader/report or CompatibilityReport interpretation;
- RuntimeMachine, Gate 3, runtime, and production behavior.

---

## Next Allowed Route

Authorize only a design route:

```text
prop038-live-refusal-implementation-boundary-design-v0
```

Allowed next card boundary:

```text
Card: S3-R78-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: prop038-live-refusal-implementation-boundary-design-v0

Goal:
Design the remaining boundary conditions before any live PROP-038 strict-mode
compile-refusal implementation can be considered, using the accepted R77
proof-local trigger experiment as evidence.

Allowed:
- map remaining blockers for live refusal implementation;
- compare possible live strict sources:
  internal orchestrator option, Ruby facade/API option, CLI flag,
  manifest/profile policy, and gate-controlled profile requirement;
- design where a future live refusal decision would occur relative to
  report-only validation, `pass_result`, assembly, and public result shaping;
- design `CompilerResult`/status/refusal-report options without implementing
  them;
- decide whether `would_refuse` can graduate to a future live `refused` status
  only behind a separate implementation gate;
- define proof and regression requirements for any later implementation review.

Not allowed:
- code implementation;
- live compile refusal;
- proof-local code changes;
- compiler/orchestrator behavior changes;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted reports or sidecars;
- parser, TypeChecker, SemanticIR, assembler, `.igapp`, loader/report,
  CompatibilityReport, diagnostics centralization, RuntimeMachine, Gate 3,
  Ledger/TBackend, BiHistory, stream/OLAP, cache, or production behavior.
```

No live refusal implementation card may open directly from R77.

---

## Blockers Before Live Refusal Implementation

The following blockers remain open before any live refusal implementation
authorization:

| Blocker | Status |
| --- | --- |
| Production/compiler strict source | Open |
| Live compiler/orchestrator implementation boundary | Open |
| Ruby API / CLI source shape | Open |
| `CompilerResult`/status model | Open |
| Refusal report behavior | Open |
| Fail-closed policy for recompute unavailable | Open |
| `.igapp` / assembly strict-mode boundary | Open |
| Loader/report and CompatibilityReport semantics | Closed / not authorized |
| Runtime and production readiness semantics | Closed / not authorized |

---

## Preserved Closed Surfaces

This decision preserves closure of:

- live compiler/orchestrator behavior changes;
- live compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted reports or sidecars outside proof-local experiment output;
- parser, TypeChecker, SemanticIR changes;
- assembler or `.igapp` mutation;
- loader/report behavior;
- CompatibilityReport behavior;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`, receipts, signing;
- dispatch migration;
- RuntimeMachine and Gate 3 widening;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, and production behavior.
