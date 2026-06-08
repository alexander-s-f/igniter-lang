# PROP-038 Contract Digest Live Validator Implementation Acceptance Decision v0

Card: S3-R74-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-contract-digest-live-validator-implementation-acceptance-decision-v0
Route: UPDATE
Status: accepted-live-validator-implementation-closure
Date: 2026-05-18

---

## Decision

Accept the bounded PROP-038 `contract_digest` live validator implementation.

The R73 implementation authorization is satisfied:

```text
prop038-contract-digest-live-validator-implementation-v0
```

The implementation is accepted only as internal validator behavior inside:

```text
IgniterLang::CompilerProfileContractValidator
```

This decision does not authorize compiler/orchestrator integration changes,
compile refusal, public API/CLI widening, `CompilerResult` changes, persisted
reports or sidecars, parser/TypeChecker/SemanticIR changes, assembler or
`.igapp` mutation, loader/report behavior, CompatibilityReport behavior,
diagnostics centralization, dispatch migration, RuntimeMachine behavior, Gate 3
widening, Ledger/TBackend behavior, BiHistory, stream/OLAP, cache, or production
behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-contract-digest-live-validator-implementation-v0.md`
- `igniter-lang/docs/discussions/prop038-contract-digest-live-validator-implementation-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-live-implementation-design-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-errata-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-report-only-integration-proof-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round73-status-curation-v0.md`
- `igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb`
- updated proof summaries under the authorized experiment directories.

---

## Accepted Changed Files

Accepted changed files are inside the R73 authorized write scope:

```text
igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb
igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb
igniter-lang/experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json
igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb
igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/out/prop038_contract_digest_shape_policy_proof_summary.json
igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/prop038_contract_digest_recompute_match_proof.rb
igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/out/prop038_contract_digest_recompute_match_proof_summary.json
igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/prop038_contract_digest_report_only_integration_proof.rb
igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/out/prop038_contract_digest_report_only_integration_proof_summary.json
igniter-lang/docs/tracks/prop038-contract-digest-live-validator-implementation-v0.md
```

No disallowed file is accepted as changed by this decision.

---

## Validator API And Result Shape

Accepted validator API remains unchanged:

```ruby
validate(contract, digest_reference_policy: :prop038_24_plus)
```

Accepted validator result keys remain exactly:

```text
compile_refusal_authorized
compiler_integrated
diagnostic_codes
diagnostics
digest_reference_policy
format_version
kind
valid
```

Accepted fixed flags remain:

```text
compiler_integrated=false
compile_refusal_authorized=false
```

No new public validator methods or top-level validator result fields are
accepted.

---

## Diagnostic Vocabulary Status

Accepted: all four PROP-038 `contract_digest_*` diagnostics are live in the
internal validator:

```text
compiler_profile_contract.contract_digest_invalid
compiler_profile_contract.contract_digest_policy_unsupported
compiler_profile_contract.contract_digest_mismatch
compiler_profile_contract.contract_digest_recompute_unavailable
```

Diagnostics remain local to the validator result and flow through the existing
private `diagnostic` helper.

Diagnostics are not centralized in:

```text
IgniterLang::Diagnostics
```

---

## Canonicalization Status

Accepted: live validator canonicalization matches R70/R72.

Accepted behavior:

- canonical material is built from the 13 accepted PROP-038 fields;
- `contract_digest` is excluded by construction;
- `descriptor_digest` is included as a string field value;
- descriptor material is not fetched or recomputed;
- `slot_order` remains order-sensitive;
- object keys are order-insensitive;
- strict registry names and entries are order-insensitive;
- ordered-rule list order is order-insensitive;
- `before` and `after` edge arrays are sorted unique sets;
- missing `before` / `after` arrays normalize to empty arrays;
- validator input contracts are not mutated.

Private helper names remain implementation details and are not authority.

---

## Proof Matrix Result

Accepted proof summary state:

| Summary | Result |
| --- | --- |
| `compiler_profile_contract_proof_summary.json` | PASS, 13 cases, 30 checks, 0 failures |
| `prop038_contract_digest_shape_policy_proof_summary.json` | PASS, 8 cases, 20 checks, 0 failures |
| `prop038_contract_digest_recompute_match_proof_summary.json` | PASS, 14 cases, 16 checks, 0 failures |
| `prop038_contract_digest_report_only_integration_proof_summary.json` | PASS, 12 cases, 21 checks, 0 failures |

Accepted proof coverage:

- existing 13-case validator parity remains PASS;
- shape-policy cases pass;
- recompute full/prefix match and mismatch cases pass;
- recompute-unavailable case passes;
- canonicalization sensitivity cases pass;
- mutation guard passes;
- result-shape guard passes;
- all report-only integration invariants pass.

---

## Command Matrix

Commands rerun by Architect Supervisor:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb` | PASS |
| `ruby -c igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb` | PASS |
| `ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb` | PASS |
| `ruby -c igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb` | PASS |
| `ruby -c igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/prop038_contract_digest_recompute_match_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/prop038_contract_digest_recompute_match_proof.rb` | PASS |
| `ruby -c igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/prop038_contract_digest_report_only_integration_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/prop038_contract_digest_report_only_integration_proof.rb` | PASS |

Additional Architect scan:

```text
no contract_digest matches in compiler_orchestrator.rb, igniter_lang.rb, cli.rb,
compiler_result.rb, assembler.rb, parser.rb, typechecker.rb, semanticir_emitter.rb
```

Accepted requires in the validator:

```ruby
require "digest"
require "json"
require "set"
```

No non-stdlib require is accepted.

---

## Report-Only And No-Refusal Status

Accepted:

- digest diagnostics remain nested under
  `compiler_profile_contract_validation.diagnostics` when report-only compiler
  integration is exercised;
- top-level `report["diagnostics"]` remains unchanged;
- compile status remains `ok` when source compiles;
- `pass_result` remains unchanged;
- stages remain unchanged;
- public result remains unchanged;
- assembler execution remains unchanged;
- `.igapp` manifest remains unchanged;
- refusal report is not written;
- nil/non-Hash/provider-error paths remain no-field/no-refusal.

Compile refusal remains closed.

---

## Pressure Verdict

R74-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: none
```

Architect accepts the pressure result.

---

## Next Allowed Route

Authorize only a design/precondition route for possible future compile-refusal
discussion:

```text
prop038-contract-digest-compile-refusal-preconditions-design-v0
```

This route may ask whether and under what conditions digest validation should
ever become compile-refusal behavior.

It must not implement compile refusal.

Allowed next card boundary:

```text
Card: S3-R75-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: prop038-contract-digest-compile-refusal-preconditions-design-v0

Goal:
Design and evaluate preconditions for any future PROP-038 contract_digest
compile-refusal gate, using the accepted live validator implementation and
report-only invariants as inputs.

Allowed:
- define possible refusal preconditions;
- identify proof requirements before refusal can ever open;
- distinguish contract-object refusal from compiler refusal;
- preserve report-only behavior as current live behavior;
- list risks and blocker questions.

Not allowed:
- code implementation;
- enabling compile refusal;
- compiler/orchestrator changes;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted reports or sidecars;
- parser, TypeChecker, SemanticIR, assembler, `.igapp`, loader/report,
  CompatibilityReport, RuntimeMachine, Gate 3, Ledger/TBackend, BiHistory,
  stream/OLAP, cache, or production behavior.
```

---

## Preserved Closed Surfaces

This decision preserves closure of:

- compiler/orchestrator integration;
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

