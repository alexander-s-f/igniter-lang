# PROP-038 Library Validator Extraction Design Decision v0

Card: S3-R64-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-library-validator-extraction-design-decision-v0
Route: UPDATE
Status: accepted-authorized-bounded-option-b-implementation
Date: 2026-05-17

---

## Decision

Accept the R64 Option B library validator extraction design.

Authorize the next bounded implementation card for an internal,
non-integrated, non-refusal PROP-038 library validator extraction.

This authorization is proof-parity only. It does not authorize compiler
integration, report-only compiler behavior, compile refusal, public API/CLI
widening, persistence, runtime behavior, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-library-validator-extraction-design-v0.md`
- `igniter-lang/docs/discussions/prop038-library-validator-extraction-design-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-proof-local-missing-after-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-compiler-profile-contract-implementation-authorization-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round63-status-curation-v0.md`

---

## Acceptance Basis

R64-C1-P1 provides an exact design boundary:

- one new internal file path;
- one module/function API;
- one string-key result shape;
- local validator diagnostics;
- proof-local parity as the only output;
- no top-level public facade require;
- no compiler, report, runtime, or production integration.

R64-C2-X pressure verdict:

```text
proceed
blockers: none
non-blocking notes: 1
```

The non-blocking note is accepted and recorded below: first extraction does not
validate `contract_digest` format or digest mismatch.

---

## Blocker Closure

| Blocker | Status | Decision |
| --- | --- | --- |
| B1 create validator file | closed | Authorized for the exact file path named below. |
| B2 proof-parity vs expanded diagnostics | closed | Proof-parity only; no new diagnostic vocabulary. |
| B3 descriptor digest behavior | closed | Shape validation only; no descriptor material recomputation. |
| B4 digest reference policy | closed | `:prop038_24_plus` for non-persisted internal validation. |
| B5 diagnostic placement | closed | Local to validator; not `IgniterLang::Diagnostics`. |
| B6 contract input ownership | closed | Caller supplies already-materialized Hash. |
| B7 proof parity | closed | Same 13 cases, same codes, same non-authorization flags. |
| B8 integration/refusal boundary | closed | No compiler integration and no compile refusal. |

---

## Authorized Implementation Scope

The next implementation card may edit only:

```text
igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb
igniter-lang/experiments/compiler_profile_contract_proof/
igniter-lang/docs/tracks/<future-implementation-track>.md
```

The implementation must:

- create `IgniterLang::CompilerProfileContractValidator`;
- expose only:

```ruby
validate(contract, digest_reference_policy: :prop038_24_plus)
```

- accept an already-materialized contract Hash;
- return a string-key Hash shaped as:

```json
{
  "kind": "compiler_profile_contract_validation_result",
  "format_version": "0.1.0",
  "valid": false,
  "diagnostics": [],
  "diagnostic_codes": [],
  "digest_reference_policy": "prop038_24_plus",
  "compiler_integrated": false,
  "compile_refusal_authorized": false
}
```

- extract proof-local validation behavior from the current proof script;
- keep diagnostics local to the validator;
- update the proof script to call the library validator;
- keep the proof summary under the existing experiment `out/` directory;
- preserve the same 13-case parity matrix and PASS result.

No top-level require may be added to:

```text
igniter-lang/lib/igniter_lang.rb
```

The first caller remains the proof experiment.

---

## Digest Policy

For this bounded implementation:

```text
digest_reference_policy: :prop038_24_plus
```

Meaning:

- `descriptor_digest` shape accepts
  `compiler_profile_descriptor/sha256:<24+ lowercase hex>`;
- `finalization_payload_digest` remains `sha256:<64 lowercase hex>`;
- `contract_digest` format and mismatch validation are deferred.

The validator must not recompute descriptor digest material.

The validator must not introduce `contract_digest_invalid`,
`contract_digest_mismatch`, or equivalent new diagnostic vocabulary in this
slice.

If contract digest validation is desired later, a separate gate must authorize:

- exact canonicalization rules;
- exact match or prefix-match policy;
- diagnostic code;
- proof case.

---

## Diagnostic Vocabulary And Placement

Authorized diagnostics are the current proof-parity diagnostics only:

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

Diagnostics remain local to:

```text
IgniterLang::CompilerProfileContractValidator
```

Do not centralize them in:

```text
IgniterLang::Diagnostics
```

This implementation does not authorize adding currently unproven PROP-038
diagnostics such as `unknown_owner_slot` or `unknown_rule_owner_slot`.

---

## Proof Requirements

Required proof parity:

```text
same 13 cases
same expected diagnostic codes
same PASS status
same non-authorization flags
```

Required command matrix:

```text
ruby -c igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb
ruby -c igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb
ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb
```

Expected proof summary:

```text
status=PASS
cases=13
checks>=23
compiler_integrated=false
compile_refusal_authorized=false
```

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
- public Ruby facade input widening;
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

## Exact Next Allowed Card Boundary

```text
Card: S3-R65-C1-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop038-library-validator-extraction-implementation-v0

Route: UPDATE
Authority ref:
- igniter-lang/docs/gates/prop038-library-validator-extraction-design-decision-v0.md

Goal:
Implement the bounded Option B internal PROP-038 library validator extraction
with proof parity only.

Scope:
- Edit only:
  - igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb
  - igniter-lang/experiments/compiler_profile_contract_proof/
  - igniter-lang/docs/tracks/prop038-library-validator-extraction-implementation-v0.md
- Create `IgniterLang::CompilerProfileContractValidator`.
- Expose only:
  - `validate(contract, digest_reference_policy: :prop038_24_plus)`
- Accept only an already-materialized contract Hash.
- Return a string-key validation result Hash with:
  - `compiler_integrated: false`
  - `compile_refusal_authorized: false`
- Move proof-local validation constants/helpers/logic into the validator.
- Update the proof script to call the validator.
- Preserve the existing 13-case proof matrix and diagnostic codes.
- Keep diagnostics local to the validator.
- Keep descriptor digest behavior shape-only.
- Keep `contract_digest` format/mismatch validation deferred.
- Do not add top-level require in `igniter-lang/lib/igniter_lang.rb`.
- Do not add new diagnostic vocabulary.
- Do not change compiler behavior.

Proof:
- `ruby -c igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb`
- `ruby -c igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb`
- `ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb`

Deliver:
- New internal validator file
- Updated proof experiment and summary
- Track doc with exact command matrix and PASS/FAIL
- Recommendation for next route: accept extraction / hold / design report-only integration

Non-authorizations:
- No compiler integration.
- No report-only compiler behavior.
- No compile refusal.
- No parser, TypeChecker, SemanticIR, assembler, `.igapp`, CLI/API,
  loader/report, CompatibilityReport, dispatch, RuntimeMachine, Gate 3,
  Ledger/TBackend, BiHistory, stream/OLAP, cache, or production behavior.
```

---

## Compact Summary

R64 accepts the PROP-038 Option B library validator extraction design and
authorizes a bounded implementation card next. The authorized slice is internal,
non-integrated, non-refusal, and proof-parity only. It may create
`IgniterLang::CompilerProfileContractValidator`, update the existing proof to
call it, and preserve the 13-case matrix. It may not add compiler integration,
report-only behavior, compile refusal, public API/CLI input, new diagnostics,
digest recomputation, runtime behavior, or production behavior.
