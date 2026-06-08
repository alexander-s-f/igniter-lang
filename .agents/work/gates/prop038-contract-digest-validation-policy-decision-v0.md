# PROP-038 Contract Digest Validation Policy Decision v0

Card: S3-R68-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-contract-digest-validation-policy-decision-v0
Route: UPDATE
Status: accepted-authorized-proof-local-shape-policy
Date: 2026-05-17

---

## Decision

Accept the R68 `contract_digest` validation policy design.

Authorize the next route only as proof-local:

```text
prop038-contract-digest-shape-policy-proof-v0
```

This decision does not authorize implementation in the compiler, validator,
orchestrator, public API/CLI, loader/report, CompatibilityReport, RuntimeMachine,
Gate 3, runtime, or production surfaces.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-contract-digest-validation-policy-design-v0.md`
- `igniter-lang/docs/discussions/prop038-contract-digest-validation-policy-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round67-status-curation-v0.md`

---

## Accepted Policy

Accepted policy:

```text
hybrid
```

Meaning:

```text
Current validator remains prop038_24_plus and report-only.
No contract_digest validation is added now.
Future contract_digest validation proceeds through two proof phases:
  1. shape-only proof
  2. recompute-match proof
Implementation remains held until a later Architect decision explicitly opens it.
```

This accepts the design distinction between:

- `descriptor_digest` as compiler profile descriptor identity;
- `contract_digest` as whole compiler profile contract identity;
- digest reference shape validation;
- canonical recomputation;
- declared-vs-recomputed mismatch;
- report-only diagnostics;
- compile-refusal authority.

These are separate concerns and must not be collapsed into one implementation
step.

---

## Answers

### V0 Digest Policy

V0 policy is accepted as:

```text
hybrid design, current behavior deferred/no contract_digest check
```

The current validator remains:

```ruby
digest_reference_policy: :prop038_24_plus
```

but does not yet validate `contract_digest` format, recompute the digest, or
compare declared and recomputed values.

### Diagnostic Stability

The diagnostic vocabulary is stable enough for a proof-local shape-policy route,
but not yet stable enough for implementation.

Accepted future diagnostic candidates:

```text
compiler_profile_contract.contract_digest_invalid
compiler_profile_contract.contract_digest_policy_unsupported
compiler_profile_contract.contract_digest_recompute_unavailable
compiler_profile_contract.contract_digest_mismatch
```

Placement remains local:

```text
report["compiler_profile_contract_validation"]["diagnostics"]
```

These diagnostics must not be appended to top-level `report["diagnostics"]` and
must not be centralized in `IgniterLang::Diagnostics` without a separate
decision.

### Report-Only Status

`contract_digest` validation remains report-only.

Even after a future digest implementation, digest diagnostics must not change:

- compile status;
- `pass_result`;
- stages;
- compiler diagnostics;
- public result;
- assembler execution;
- `.igapp` manifest;
- refusal report creation.

### Compile Refusal Status

Compile refusal remains closed.

Compile refusal may be considered only after a separate chain:

1. accepted digest policy / PROP-038 errata as needed;
2. shape-only proof passes;
3. recompute-match proof passes;
4. report-only integration proves digest diagnostics are stable;
5. a separate explicit compile-refusal gate authorizes exact refusal behavior
   and write scope.

This decision does not open that path.

### Implementation Status

Implementation remains held.

No code may be changed from this decision. The next route may only create a
proof-local experiment and documentation.

---

## Accepted Proof Direction

The next allowed proof-local route is:

```text
prop038-contract-digest-shape-policy-proof-v0
```

Allowed scope:

- exercise Phase 1 shape-only matrix;
- use proof-local experiment files only;
- produce summary JSON under an experiment directory;
- prove diagnostics and policy behavior without changing live compiler behavior;
- preserve current validator/compiler behavior unless a later gate authorizes
  implementation.

Required Phase 1 proof cases:

| Case | Expected result |
| --- | --- |
| `valid_short_contract_digest` | valid under `prop038_24_plus` |
| `valid_full_contract_digest` | valid under `prop038_24_plus` |
| `missing_contract_digest` | `compiler_profile_contract.contract_digest_invalid` |
| `contract_digest_wrong_namespace` | `compiler_profile_contract.contract_digest_invalid` |
| `contract_digest_too_short` | `compiler_profile_contract.contract_digest_invalid` |
| `contract_digest_non_hex` | `compiler_profile_contract.contract_digest_invalid` |
| `contract_digest_uppercase_hex` | `compiler_profile_contract.contract_digest_invalid` |
| `unsupported_digest_policy` | `compiler_profile_contract.contract_digest_policy_unsupported` |

Required regression checks:

- existing 13-case validator matrix remains PASS;
- R67 report-only integration remains unchanged;
- public result remains unchanged;
- `compile_refusal_authorized=false`;
- no `.igapp` mutation;
- no refusal report creation.

---

## Recompute-Match Status

Recompute-match is accepted only as a design target, not as implementation.

The canonicalization input material proposed by C1 is directionally accepted for
future proof work:

```text
contract object excluding contract_digest
```

However, recomputation remains held until after the shape-only proof is accepted
and a separate recompute/canonicalization proof route is authorized.

---

## PROP-038 Errata Status

Do not amend PROP-038 yet.

If the shape-only and recompute-match proofs stabilize the diagnostic vocabulary
and canonicalization model, a separate PROP-038 errata card may add the
`contract_digest_*` vocabulary and policy text.

---

## Pressure Verdict

R68-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: none
```

Architect accepts the pressure result.

---

## Preserved Closed Surfaces

This decision does not authorize:

- implementation;
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

## Exact Next Allowed Boundary

Allowed next card:

```text
Card: S3-R69-C1-P1
Agent: [Igniter-Lang Research Agent]
Role: research-agent
Track: prop038-contract-digest-shape-policy-proof-v0
```

Boundary:

- proof-local experiment only;
- no live validator implementation;
- no compiler/orchestrator integration edits;
- no public API/CLI;
- no persisted report/sidebar/loader/report/CompatibilityReport;
- no `.igapp` mutation beyond proof-local generated output;
- no compile refusal;
- no runtime or production behavior.

Recommended follow-up pressure:

```text
S3-R69-C2-X: pressure-review proof-local shape policy
S3-R69-C3-A: Architect decision on proof acceptance
```

---

## Compact Summary

R68 accepts a hybrid `contract_digest` policy: current live behavior stays
deferred/no-check, while future digest validation must pass a two-phase proof
route. The next allowed step is proof-local shape-policy only. Recompute-match,
implementation, compile refusal, public surfaces, persisted reports,
loader/report, CompatibilityReport, runtime, Gate 3, and production all remain
closed.
