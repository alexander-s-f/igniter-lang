# PROP-038 Contract Digest Report-Only Integration Proof Decision v0

Card: S3-R71-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-contract-digest-report-only-integration-proof-decision-v0
Route: UPDATE
Status: accepted-proof-local-report-only-integration-closure
Date: 2026-05-18

---

## Decision

Accept the proof-local PROP-038 `contract_digest` report-only integration proof.

The R70-authorized proof-local route is satisfied:

```text
prop038-contract-digest-report-only-integration-proof-v0
```

Authorize the next route only as PROP-038 errata/design authoring:

```text
prop038-contract-digest-errata-authoring-v0
```

The next route may document the accepted `contract_digest_*` diagnostic
vocabulary, report-only placement, and canonicalization/recompute policy in
PROP-038. It must not implement validator/compiler behavior.

This decision does not authorize live validator implementation, compiler
integration changes, compile refusal, public API/CLI widening, `CompilerResult`
changes, persisted reports or sidecars, parser/TypeChecker/SemanticIR changes,
assembler or `.igapp` mutation, loader/report behavior, CompatibilityReport
behavior, diagnostics centralization, dispatch migration, RuntimeMachine
behavior, Gate 3 widening, Ledger/TBackend behavior, BiHistory, stream/OLAP,
cache, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-contract-digest-report-only-integration-proof-v0.md`
- `igniter-lang/docs/discussions/prop038-contract-digest-report-only-integration-proof-pressure-v0.md`
- `igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/out/prop038_contract_digest_report_only_integration_proof_summary.json`
- `igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/prop038_contract_digest_report_only_integration_proof.rb`
- `igniter-lang/docs/gates/prop038-contract-digest-recompute-match-proof-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-shape-policy-proof-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-validation-policy-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round70-status-curation-v0.md`

---

## Proof Result

Accepted proof summary:

```text
kind=prop038_contract_digest_report_only_integration_proof_summary
status=PASS
cases=12
checks=21
failed_checks=[]
```

Accepted regression status:

```text
shape_policy_proof_status=PASS
recompute_match_proof_status=PASS
report_only_integration_status=PASS
```

Accepted non-authorization flags:

```text
live_validator_changed=false
compiler_integration_changed=false
digest_report_only_live_implemented=false
compile_refusal_authorized=false
implementation_authorized=false
```

---

## Accepted Case Matrix

All required report-only integration cases are accepted:

| Case | Expected | Status |
| --- | --- | --- |
| `valid_digest_report_only_valid_true` | valid nested report-only validation | PASS |
| `shape_invalid_report_only_valid_false` | `compiler_profile_contract.contract_digest_invalid` nested | PASS |
| `unsupported_policy_report_only_valid_false` | `compiler_profile_contract.contract_digest_policy_unsupported` nested | PASS |
| `recompute_mismatch_report_only_valid_false` | `compiler_profile_contract.contract_digest_mismatch` nested | PASS |
| `recompute_unavailable_report_only_valid_false` | `compiler_profile_contract.contract_digest_recompute_unavailable` nested | PASS |
| `combined_shape_and_recompute_diagnostics_stay_nested` | multiple digest diagnostics stay nested | PASS |
| `mismatch_compile_status_ok` | compile status remains `ok` | PASS |
| `mismatch_public_result_unchanged` | public result unchanged | PASS |
| `mismatch_igapp_manifest_unchanged` | `.igapp` manifest unchanged | PASS |
| `mismatch_no_refusal_report_written` | no refusal report written | PASS |
| `provider_nil_preserves_legacy_behavior` | no validation report and baseline outcome | PASS |
| `provider_exception_preserves_legacy_behavior` | no validation report and baseline outcome | PASS |

---

## Accepted Diagnostic Vocabulary

The full four-code `contract_digest_*` vocabulary is accepted as stable enough
for PROP-038 errata/design text:

```text
compiler_profile_contract.contract_digest_invalid
compiler_profile_contract.contract_digest_policy_unsupported
compiler_profile_contract.contract_digest_mismatch
compiler_profile_contract.contract_digest_recompute_unavailable
```

These diagnostics are accepted only for proof/design vocabulary at this point.
They are not yet accepted for live validator implementation.

If implemented later, these diagnostics must remain nested under:

```text
report["compiler_profile_contract_validation"]["diagnostics"]
```

They must not be appended to top-level:

```text
report["diagnostics"]
```

They must not be centralized in `IgniterLang::Diagnostics` without a separate
Architect decision.

---

## Accepted Report-Only Invariants

The proof accepts the following invariants:

- digest diagnostics live under
  `compiler_profile_contract_validation.diagnostics`;
- top-level `report["diagnostics"]` remains unchanged;
- `pass_result` remains unchanged;
- `stages` remain unchanged;
- compile status remains `ok` when the source otherwise compiles;
- public result remains unchanged;
- assembler execution remains unchanged;
- `.igapp` manifest remains unchanged;
- no refusal report is written.

Nil provider and provider exception paths preserve legacy/no-field behavior.

R70 NB-1 is closed: the R71 summary includes a structured
`non_authorizations_preserved` block.

---

## Three-Phase Digest Proof Chain

The proof-local `contract_digest` chain is now accepted as complete for design
purposes:

| Phase | Round | Result |
| --- | --- | --- |
| Shape policy | R69 | 8 cases / 19 checks PASS |
| Recompute and canonicalization | R70 | 14 cases / 15 checks PASS |
| Report-only integration | R71 | 12 cases / 21 checks PASS |

This chain is sufficient to open PROP-038 errata/design authoring.

This chain is not implementation authorization.

---

## Command Matrix

Commands rerun by Architect Supervisor:

| Command | Result |
| --- | --- |
| `ruby igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/prop038_contract_digest_report_only_integration_proof.rb` | PASS |
| `ruby -c igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/prop038_contract_digest_report_only_integration_proof.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb` | PASS |

---

## Pressure Verdict

R71-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: none
```

Architect accepts the pressure result.

---

## Status Answers

### Is the report-only integration proof accepted?

Yes. R71-C1-P1 is accepted as proof-local Phase 3 closure.

### Is the four-code digest vocabulary stable enough for PROP-038 errata design?

Yes. The vocabulary is stable enough for PROP-038 errata/design authoring.

No. The vocabulary is not yet live implementation authority.

### Is report-only behavior stable enough to consider later live validator implementation design?

Yes. The behavior is stable enough to consider a later design-only live
implementation route.

No live implementation design is opened by this decision. The next route should
first synchronize PROP-038 errata/design text.

### Does live validator implementation remain held?

Yes.

### Does compile refusal remain closed?

Yes.

Compile refusal remains subject to a separate future gate after any live
implementation is designed, implemented, and proven stable.

### May PROP-038 errata open next?

Yes.

Allowed next card boundary:

```text
Card: S3-R72-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: prop038-contract-digest-errata-authoring-v0

Goal:
Author PROP-038 errata/design text for accepted contract_digest vocabulary,
report-only diagnostic placement, canonicalization material, and proof-chain
references.

Allowed:
- update or draft PROP-038 errata/design text;
- cite R69/R70/R71 proof summaries and gate decisions;
- define diagnostic vocabulary and report-only placement;
- describe canonicalization/recompute policy as design language.

Not allowed:
- code implementation;
- live validator/compiler behavior;
- compile refusal;
- public API/CLI widening;
- `.igapp` mutation;
- loader/report or CompatibilityReport behavior;
- RuntimeMachine, Gate 3, Ledger/TBackend, BiHistory, stream/OLAP, cache, or
  production behavior.
```

### May live implementation design open next?

Not yet.

It may be considered after PROP-038 errata/design text is authored and reviewed.

---

## Preserved Closed Surfaces

This decision preserves closure of:

- live validator/compiler implementation;
- compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted success reports or sidecars;
- parser, TypeChecker, SemanticIR changes;
- assembler or `.igapp` mutation;
- loader/report behavior;
- CompatibilityReport behavior;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`, receipts, signing;
- dispatch migration;
- RuntimeMachine and Gate 3 widening;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, and production behavior.

