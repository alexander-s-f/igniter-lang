# PROP-038 Library Validator Extraction Acceptance Decision v0

Card: S3-R65-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-library-validator-extraction-acceptance-decision-v0
Route: UPDATE
Status: accepted-extraction-closure
Date: 2026-05-17

---

## Decision

Accept the bounded PROP-038 internal library validator extraction.

The R64 implementation authorization is satisfied and closed.

This decision does not authorize compiler integration, report-only compiler
behavior, compile refusal, public API/CLI widening, persisted outputs, runtime
behavior, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-library-validator-extraction-implementation-v0.md`
- `igniter-lang/docs/discussions/prop038-library-validator-extraction-implementation-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-design-decision-v0.md`
- `igniter-lang/docs/tracks/prop038-library-validator-extraction-design-v0.md`
- `igniter-lang/docs/discussions/prop038-library-validator-extraction-design-pressure-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round64-status-curation-v0.md`
- `igniter-lang/experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json`
- `igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb`
- `igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb`

---

## Changed Files Accepted

R65-C1-I changed exactly these files:

```text
igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb
igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb
igniter-lang/experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json
igniter-lang/docs/tracks/prop038-library-validator-extraction-implementation-v0.md
```

All four are inside the R64 authorized boundary.

No top-level require was added to:

```text
igniter-lang/lib/igniter_lang.rb
```

---

## Validator API And Result Shape

Accepted internal validator:

```text
IgniterLang::CompilerProfileContractValidator
```

Accepted public method:

```ruby
validate(contract, digest_reference_policy: :prop038_24_plus)
```

The validator accepts only an already-materialized contract Hash.

Accepted result shape:

```json
{
  "kind": "compiler_profile_contract_validation_result",
  "format_version": "0.1.0",
  "valid": true,
  "diagnostics": [],
  "diagnostic_codes": [],
  "digest_reference_policy": "prop038_24_plus",
  "compiler_integrated": false,
  "compile_refusal_authorized": false
}
```

The pressure review confirms `validate` is the only public method. The validator
exposes slot constants for the proof-local caller, which is acceptable in this
scope and does not widen the public facade.

---

## Command Matrix

Architect verification:

| Command | Result | Output |
| --- | --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb` | PASS | `Syntax OK` |
| `ruby -c igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb` | PASS | `Syntax OK` |
| `ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb` | PASS | `PASS compiler_profile_contract_proof` |

---

## Proof Status

Accepted proof summary:

```text
track=prop038-library-validator-extraction-implementation-v0
extends_track=prop038-proof-local-missing-after-implementation-v0
status=PASS
cases=13
validator_case_matrix=13
checks=27
```

The 13-case parity matrix remains intact:

- `valid_contract`
- `missing_required_slot`
- `duplicate_strict_key`
- `duplicate_fragment_class_owner`
- `rule_cycle`
- `missing_rule_reference`
- `missing_after_rule_reference`
- `wrong_kind`
- `unsupported_format_version`
- `descriptor_digest_invalid`
- `finalization_payload_digest_invalid`
- `runtime_authority_forbidden`
- `dispatch_migration_forbidden`

R63 had 23 checks. R65 has 27 checks because it adds four validator result shape
assertions:

- `validator_result.kind`
- `validator_result.digest_reference_policy`
- `validator_result.compiler_integrated_false`
- `validator_result.compile_refusal_authorized_false`

This is accepted as strengthened proof coverage, not a behavior widening.

---

## Diagnostic Vocabulary Status

Accepted diagnostic vocabulary remains proof-parity only:

- `compiler_profile_contract.wrong_kind`
- `compiler_profile_contract.unsupported_format_version`
- `compiler_profile_contract.descriptor_digest_invalid`
- `compiler_profile_contract.finalization_payload_digest_invalid`
- `compiler_profile_contract.missing_required_slot`
- `compiler_profile_contract.duplicate_strict_key`
- `compiler_profile_contract.rule_cycle`
- `compiler_profile_contract.missing_rule_reference`
- `compiler_profile_contract.runtime_authority_forbidden`
- `compiler_profile_contract.dispatch_migration_forbidden`

No new diagnostic vocabulary is accepted in R65.

Still not authorized:

- `compiler_profile_contract.unknown_owner_slot`
- `compiler_profile_contract.unknown_rule_owner_slot`
- `compiler_profile_contract.contract_digest_invalid`
- `compiler_profile_contract.contract_digest_mismatch`

Diagnostics remain local to:

```text
IgniterLang::CompilerProfileContractValidator
```

They are not centralized in:

```text
IgniterLang::Diagnostics
```

---

## Digest Policy Status

Accepted for this internal validator:

```text
digest_reference_policy: :prop038_24_plus
```

Descriptor digest remains shape-only:

```text
compiler_profile_descriptor/sha256:<24+ lowercase hex>
```

Finalization payload digest remains:

```text
sha256:<64 lowercase hex>
```

`contract_digest` format and mismatch validation remain intentionally deferred.
No contract digest recomputation or canonicalization enforcement is accepted by
this decision.

---

## Non-Integration And Non-Refusal Status

Accepted.

The validator result hardcodes:

```text
compiler_integrated=false
compile_refusal_authorized=false
```

The proof summary machine-asserts those fields, and all 15
`non_authorizations_preserved` flags remain false.

Invalid contracts return validation results. They do not refuse compilation.

---

## Pressure Verdict

R65-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: none
```

Pressure confirms:

- write scope stayed inside the authorized paths;
- no top-level facade require was added;
- validator API matches the authorized shape;
- 13-case parity matrix remains intact;
- diagnostic vocabulary did not expand;
- `contract_digest` validation remains deferred;
- descriptor digest remains shape-only;
- no compiler integration, report behavior, refusal behavior, public API/CLI,
  runtime, or production surface opened.

---

## Next Allowed Route

Immediate next card:

```text
Card: S3-R65-C4-S
Agent: [Igniter-Lang Status Curator]
Role: status-curator
Track: stage3-round65-status-curation-v0
```

After R65 curation, the next meaningful compiler/profile lane may be design-only
report integration planning. That lane is not authorized by this decision, but a
future card may ask whether to open:

```text
prop038-report-only-compiler-integration-design-v0
```

Such a future design card must resolve before any implementation:

- contract input ownership without public API/CLI widening;
- report/output location;
- orchestrator insertion point;
- fixture/golden policy;
- descriptor digest input material and canonicalization for integrated or
  persisted behavior;
- `contract_digest` format/mismatch diagnostics if enforced;
- explicit separation between report-only behavior and compile refusal.

---

## Non-Authorizations Preserved

This decision does not authorize:

- compiler integration;
- report-only compiler behavior;
- compile refusal;
- parser changes;
- TypeChecker changes;
- SemanticIR changes;
- assembler or `.igapp` changes;
- CLI/API widening;
- profile discovery/defaulting/finalization in public surfaces;
- path loading;
- inline JSON parsing;
- public Ruby facade widening;
- golden migration;
- loader/report;
- CompatibilityReport;
- `IgniterLang::Diagnostics` centralization;
- `CompilerOrchestrator`, `CompilationReport`, or `CompilerResult` changes;
- `.ilk`;
- receipts;
- signing;
- dispatch migration;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

---

## Compact Summary

R65 accepts the bounded PROP-038 internal library validator extraction. The
validator exists at the authorized path, exposes `validate`, returns the
authorized string-key result shape, preserves all 13 proof cases, raises proof
coverage to 27 checks, keeps diagnostics local and proof-parity only, keeps
descriptor digest shape-only, keeps `contract_digest` validation deferred, and
preserves non-integration/non-refusal. R64 implementation authorization is
satisfied and closed. The next immediate route is R65 status curation; any
report-only compiler integration must start as a separate design-only lane.
