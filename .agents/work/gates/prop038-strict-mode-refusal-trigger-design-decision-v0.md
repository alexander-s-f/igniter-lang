# PROP-038 Strict Mode Refusal Trigger Design Decision v0

Card: S3-R76-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-strict-mode-refusal-trigger-design-decision-v0
Route: UPDATE
Status: accepted-design-authorized-proof-local-experiment
Date: 2026-05-19

---

## Decision

Accept the PROP-038 strict-mode/refusal trigger design.

Authorize only a bounded proof-local experiment next:

```text
prop038-strict-mode-refusal-trigger-proof-local-v0
```

The accepted design is not live compiler behavior. Compile refusal remains
closed in the live compiler. Report-only remains the current live behavior.

This decision does not authorize live compiler/orchestrator behavior changes,
live compile refusal, public API/CLI widening, `CompilerResult` changes,
persisted reports or sidecars, parser/TypeChecker/SemanticIR changes, assembler
or `.igapp` mutation, loader/report behavior, CompatibilityReport behavior,
diagnostics centralization, dispatch migration, RuntimeMachine behavior, Gate 3
widening, Ledger/TBackend behavior, BiHistory, stream/OLAP, cache, or production
behavior.

---

## Evidence Read

- `igniter-lang/docs/org/indexes/prop038-contract-digest-strict-mode-refusal-trigger-boundary-map-v0.md`
- `igniter-lang/docs/tracks/prop038-contract-digest-strict-mode-refusal-trigger-design-v0.md`
- `igniter-lang/docs/tracks/prop038-strict-mode-current-compiler-surface-survey-v0.md`
- `igniter-lang/docs/discussions/prop038-strict-mode-refusal-trigger-design-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-compile-refusal-preconditions-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-live-validator-implementation-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round75-status-curation-v0.md`

---

## Accepted Design

Accepted first strict-mode source for proof-local work:

```text
gate-controlled proof-local strict requirement object
```

Accepted source status:

| Source | Status |
| --- | --- |
| Gate-controlled proof-local source | Accepted for the next proof-local experiment only. |
| Internal orchestrator option | Open. Not authorized. |
| Public API option | Closed. Not authorized. |
| CLI flag | Closed. Not authorized. |
| Manifest/profile policy | Closed. Not authorized. |
| Loader/report interpretation | Closed. Not a strict source. |

Accepted proof-local source shape:

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

This object is proof-local design vocabulary. It is not a runtime object, public
API, CLI flag, `.igapp` field, loader/report status, or CompatibilityReport
field.

---

## Accepted Trigger Vocabulary

Architect accepts the layered trigger vocabulary:

| Vocabulary item | Accepted meaning |
| --- | --- |
| `report_only` | Current live behavior; validation may annotate nested in-memory report metadata and must not affect compile result. |
| `strict_validation_requested` | Future trigger input. For the next route, only proof-local gate source may set it. |
| `strict_validation_source` | The authority requesting strict validation. For the next route, only `proof_local_gate` is accepted. |
| `refusal_candidate_diagnostic` | Validator evidence; not itself a compiler decision. |
| `compiler_refusal_decision` | Proof-local compiler-level decision vocabulary. |
| `loader_report_status` | Separate loader/report layer. Closed. |
| `runtime_readiness` | Separate runtime layer. Closed. |

Accepted proof-local decision vocabulary:

| Decision | Status |
| --- | --- |
| `not_evaluated` | Accepted for report-only mode or no strict source. |
| `allow` | Accepted for proof-local strict source with no accepted candidate. |
| `would_refuse` | Accepted only as proof-local model vocabulary. It does not claim live refusal. |
| `configuration_error` | Accepted as proof-local policy vocabulary; not a live compiler status. |

Do not use:

```text
refused
```

until a later implementation gate explicitly authorizes live compile refusal.

---

## Wrapper Diagnostic Vocabulary

Architect accepts compiler-level wrapper codes as proof-local design vocabulary:

```text
compiler_profile_contract_refusal.*
```

Accepted first wrapper code for proof-local modeling:

```text
compiler_profile_contract_refusal.contract_digest_mismatch
```

It cites evidence:

```text
compiler_profile_contract.contract_digest_mismatch
```

Wrapper codes are not accepted as:

- `IgniterLang::Diagnostics` entries;
- top-level report diagnostics;
- public API/CLI output;
- live compiler status;
- loader/report or CompatibilityReport vocabulary.

---

## Candidate Status Answers

| Diagnostic | C4-A decision |
| --- | --- |
| `compiler_profile_contract.contract_digest_mismatch` | May be modeled in the next proof-local experiment as `would_refuse` through `compiler_profile_contract_refusal.contract_digest_mismatch`. |
| `compiler_profile_contract.contract_digest_invalid` | Held for the first proof-local experiment. It may appear as a control case but must not become `would_refuse` unless a later gate expands candidate scope. |
| `compiler_profile_contract.contract_digest_policy_unsupported` | Held for the first proof-local experiment. It may be modeled as `configuration_error` only if needed, not as compile refusal. |
| `compiler_profile_contract.contract_digest_recompute_unavailable` | Held by default; first proof-local policy is `fail_open_report_only`. |

Accepted first policy:

```text
contract_digest_recompute_unavailable => fail_open_report_only
```

Fail-closed remains open and requires a later operational recovery design.

---

## Pressure Verdict

R76-C3-X verdict:

```text
proceed
blockers: none
non-blocking notes: 2
```

Architect accepts the pressure result.

NB-1 resolution:

- C1-P1 satisfies the R75 blockers for proof-local design of trigger vocabulary,
  wording, fail-open/fail-closed stance, and proof matrix.
- C1-P1 does not satisfy production/compiler implementation source,
  live compiler/orchestrator write scope, public API/CLI source shape,
  `CompilerResult`, or persisted-report blockers.

NB-2 resolution:

- C2-P1 Q6, assembly boundary under strict mode, remains open for future
  decision. The next proof-local experiment must not mutate `.igapp` or change
  assembler behavior.
- C2-P1 Q7, CLI strict behavior, remains open and must not be inferred from
  this decision.

---

## Current Live Behavior

Report-only remains current live behavior.

Live compile refusal remains closed.

Loader/report and CompatibilityReport remain closed.

Current no-field/no-refusal paths remain unchanged:

- no provider;
- provider missing `call`;
- provider returns nil;
- provider returns non-Hash;
- provider raises;
- validator raises;
- compile fails before validation due to existing unrelated compiler paths.

Strict mode must not be inferred from:

- provider presence;
- `compiler_profile_contract_validation` report field;
- `validation["valid"] == false`;
- any `compiler_profile_contract.contract_digest_*` diagnostic;
- `report_only: true`;
- `compile_refusal_authorized=false`;
- `compiler_integrated=false`;
- `digest_reference_policy: "prop038_24_plus"`;
- `contract_digest_mismatch`;
- CLI `--compiler-profile-source`;
- assembler `compiler_profile_source.*` vocabulary;
- loader/report vocabulary;
- runtime smoke failure;
- `.igapp` manifest content.

---

## Next Allowed Route

Authorize only a proof-local experiment:

```text
prop038-strict-mode-refusal-trigger-proof-local-v0
```

Allowed next card boundary:

```text
Card: S3-R77-C1-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop038-strict-mode-refusal-trigger-proof-local-v0

Goal:
Implement a proof-local strict-mode refusal trigger experiment using the
gate-controlled proof-local source accepted by S3-R76-C4-A, without changing
live compiler/orchestrator behavior.

Allowed write scope:
- igniter-lang/experiments/prop038_strict_mode_refusal_trigger_proof/
- igniter-lang/docs/tracks/prop038-strict-mode-refusal-trigger-proof-local-v0.md

Allowed behavior:
- create proof-local trigger evaluation code outside `igniter-lang/lib`;
- consume existing `IgniterLang::CompilerProfileContractValidator` behavior;
- model `strict_validation_source: "proof_local_gate"`;
- model `compiler_refusal_decision` values:
  `not_evaluated`, `allow`, `would_refuse`, and optional
  `configuration_error`;
- model only `contract_digest_mismatch` as `would_refuse` through wrapper code
  `compiler_profile_contract_refusal.contract_digest_mismatch`;
- model `contract_digest_recompute_unavailable` as fail-open/report-only;
- include legacy/no-field/no-refusal cases;
- produce a JSON summary under the experiment `out/` directory.

Required proof matrix:
- report-only + valid contract => compile/result behavior unchanged;
- report-only + digest mismatch => nested diagnostic only;
- no strict source => `not_evaluated`;
- strict proof-local source + valid contract => `allow`;
- strict proof-local source + digest mismatch => `would_refuse` with wrapper
  evidence;
- strict proof-local source + invalid digest => not `would_refuse` in first
  model unless explicitly recorded as held/control behavior;
- strict proof-local source + unsupported policy => not refusal; optional
  `configuration_error`;
- strict proof-local source + recompute unavailable => fail-open/report-only;
- nil/non-Hash/provider-error/validator-error paths => no-field/no-refusal;
- top-level diagnostics, public result, `CompilerResult`, `.igapp`,
  loader/report, CompatibilityReport, runtime, and production behavior remain
  untouched.

Required command matrix:
- syntax check new proof script;
- run new proof script;
- rerun existing validator proof:
  `ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb`;
- rerun existing report-only integration proof:
  `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb`.

Not allowed:
- edits under `igniter-lang/lib`;
- live compiler/orchestrator behavior changes;
- live compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted reports or sidecars outside the proof-local experiment output;
- parser, TypeChecker, SemanticIR, assembler, `.igapp`, loader/report,
  CompatibilityReport, diagnostics centralization, RuntimeMachine, Gate 3,
  Ledger/TBackend, BiHistory, stream/OLAP, cache, or production behavior.
```

---

## Blockers Before Live Refusal Implementation

The following remain open before any live refusal implementation authorization:

| Blocker | Status |
| --- | --- |
| Production/compiler strict source | Open |
| Live compiler/orchestrator implementation boundary | Open |
| Public API/CLI source shape | Open |
| Manifest/profile policy source shape | Open |
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
