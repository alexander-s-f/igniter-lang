# PROP-038 Contract Digest Shape Policy Proof Decision v0

Card: S3-R69-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-contract-digest-shape-policy-proof-decision-v0
Route: UPDATE
Status: accepted-proof-local-shape-policy-closure
Date: 2026-05-17

---

## Decision

Accept the proof-local PROP-038 `contract_digest` shape-policy proof.

Authorize the next route only as proof-local design/proof:

```text
prop038-contract-digest-recompute-match-proof-v0
```

This decision does not authorize live validator implementation, compiler
integration changes, recompute-match implementation in production code, compile
refusal, public API/CLI widening, persisted reports, loader/report behavior,
CompatibilityReport behavior, RuntimeMachine behavior, Gate 3 widening, or
production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-contract-digest-shape-policy-proof-v0.md`
- `igniter-lang/docs/discussions/prop038-contract-digest-shape-policy-proof-pressure-v0.md`
- `igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/out/prop038_contract_digest_shape_policy_proof_summary.json`
- `igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb`
- `igniter-lang/docs/gates/prop038-contract-digest-validation-policy-decision-v0.md`
- `igniter-lang/docs/tracks/prop038-contract-digest-validation-policy-design-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round68-status-curation-v0.md`

---

## Proof Result

Accepted proof summary:

```text
kind=prop038_contract_digest_shape_policy_proof_summary
status=PASS
failed_checks=[]
```

The proof is explicitly proof-local:

```text
live_validator_changed=false
compiler_integration_changed=false
recompute_match_implemented=false
compile_refusal_authorized=false
implementation_authorized=false
```

---

## Accepted 8-Case Shape Matrix

All required shape-policy cases are accepted:

| Case | Expected | Status |
| --- | --- | --- |
| `valid_short_contract_digest` | valid under `prop038_24_plus` | PASS |
| `valid_full_contract_digest` | valid under `prop038_24_plus` | PASS |
| `missing_contract_digest` | `compiler_profile_contract.contract_digest_invalid` | PASS |
| `contract_digest_wrong_namespace` | `compiler_profile_contract.contract_digest_invalid` | PASS |
| `contract_digest_too_short` | `compiler_profile_contract.contract_digest_invalid` | PASS |
| `contract_digest_non_hex` | `compiler_profile_contract.contract_digest_invalid` | PASS |
| `contract_digest_uppercase_hex` | `compiler_profile_contract.contract_digest_invalid` | PASS |
| `unsupported_digest_policy` | `compiler_profile_contract.contract_digest_policy_unsupported` | PASS |

Accepted shape:

```text
compiler_profile_contract/sha256:<24+ lowercase hex>
```

Accepted policy for this proof:

```text
prop038_24_plus
```

---

## Diagnostic Candidate Status

The two diagnostic candidates are accepted as stable enough for future
design/proof work:

```text
compiler_profile_contract.contract_digest_invalid
compiler_profile_contract.contract_digest_policy_unsupported
```

They are not yet accepted for live validator implementation.

They remain local to the proof-local model and, if implemented later, must remain
inside:

```text
report["compiler_profile_contract_validation"]["diagnostics"]
```

They must not be appended to top-level `report["diagnostics"]` and must not be
centralized in `IgniterLang::Diagnostics` without a separate decision.

---

## Shape vs Integrity Boundary

Accepted:

```text
shape-only proof != recompute-match proof
shape-only proof != integrity proof
```

This proof checks namespace, algorithm prefix, lowercase hex, and minimum
reference length. It does not canonicalize contract material, recompute SHA-256,
or compare declared and recomputed digest material.

Recompute/integrity work remains a separate proof-local phase.

---

## Regression And Non-Authorization Checks

Accepted regression signals:

- existing 13-case validator matrix remains PASS;
- R67 report-only integration remains PASS;
- public result remains unchanged in the integration summary;
- accepted live validator sample keeps `compile_refusal_authorized=false`;
- live validator still emits no `contract_digest_*` diagnostics;
- proof output contains no `.igapp` artifact;
- proof output contains no refusal report.

Accepted non-authorization block:

```text
live_validator_implementation=false
recompute_match_proof_implementation=false
compile_refusal=false
public_api_cli_widening=false
compiler_result_changes=false
persisted_success_reports_or_sidecars=false
parser_typechecker_semanticir_assembler_igapp=false
loader_report_or_compatibility_report=false
diagnostics_centralization=false
runtime_gate3_ledger_tbackend_bihistory_stream_olap_cache_production=false
```

---

## Command Matrix

Commands rerun by Architect Supervisor:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb` | PASS |
| `ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb` | PASS |

---

## Pressure Verdict

R69-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: none
```

Architect accepts the pressure result.

---

## Status Answers

### Is the 8-case shape-policy proof accepted?

Yes. The proof is accepted as proof-local Phase 1 closure.

### Are the two diagnostic candidates stable enough for future design?

Yes, for future design/proof work.

No, not yet for live implementation.

### Does shape-only remain distinct from integrity/recompute proof?

Yes. This distinction is required for all future cards.

### Does live validator implementation remain held?

Yes.

### Does compile refusal remain closed?

Yes.

### May recompute-match proof open next?

Yes, but only as proof-local design/proof.

Recompute-match implementation remains held.

---

## Exact Next Allowed Boundary

Allowed next route:

```text
Card: S3-R70-C1-P1
Agent: [Igniter-Lang Research Agent]
Role: research-agent
Track: prop038-contract-digest-recompute-match-proof-v0
```

Boundary:

- proof-local recompute/canonicalization model only;
- may exercise the Phase 2 recompute-match matrix from R68-C1-P1;
- may produce summary JSON under an experiment directory;
- must not edit live validator/compiler/orchestrator code;
- must not change report-only integration behavior;
- must not mutate `.igapp` outside proof-local generated output;
- must not create compile refusal;
- must not widen public API/CLI, `CompilerResult`, loader/report,
  CompatibilityReport, RuntimeMachine, Gate 3, runtime, or production behavior.

Recommended follow-up:

```text
S3-R70-C2-X: pressure-review recompute-match proof
S3-R70-C3-A: Architect decision on recompute proof acceptance
```

---

## Preserved Closed Surfaces

This decision does not authorize:

- live validator/compiler implementation;
- recompute-match implementation in production code;
- compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted success reports or sidecars;
- parser, TypeChecker, SemanticIR;
- assembler or `.igapp` mutation;
- loader/report behavior;
- CompatibilityReport behavior;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`, receipts, signing;
- dispatch migration;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

---

## Compact Summary

R69 accepts the proof-local `contract_digest` shape-policy proof. All 8 required
cases pass, the two diagnostic candidates are stable for future proof/design,
and shape-only remains explicitly separate from recompute/integrity proof. Live
validator implementation, compile refusal, public surfaces, loader/report,
CompatibilityReport, runtime, Gate 3, and production remain closed. The only
next allowed route is proof-local recompute-match proof.
