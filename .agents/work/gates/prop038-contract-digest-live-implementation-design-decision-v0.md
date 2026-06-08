# PROP-038 Contract Digest Live Implementation Design Decision v0

Card: S3-R73-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-contract-digest-live-implementation-design-decision-v0
Route: UPDATE
Status: accepted-design-authorized-one-slice-validator-implementation
Date: 2026-05-18

---

## Decision

Accept the PROP-038 `contract_digest` live validator implementation design.

Authorize the next route as one bounded internal validator implementation card:

```text
prop038-contract-digest-live-validator-implementation-v0
```

This authorization is narrow. It permits implementation of the four accepted
`contract_digest_*` diagnostics inside `IgniterLang::CompilerProfileContractValidator`
only, plus proof updates needed to verify live parity and report-only invariants.

This decision does not authorize compiler/orchestrator integration changes,
compile refusal, public API/CLI widening, `CompilerResult` changes, persisted
reports or sidecars, parser/TypeChecker/SemanticIR changes, assembler or
`.igapp` mutation, loader/report behavior, CompatibilityReport behavior,
diagnostics centralization, dispatch migration, RuntimeMachine behavior, Gate 3
widening, Ledger/TBackend behavior, BiHistory, stream/OLAP, cache, or production
behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-contract-digest-live-implementation-design-v0.md`
- `igniter-lang/docs/tracks/prop038-contract-digest-live-implementation-surface-survey-v0.md`
- `igniter-lang/docs/discussions/prop038-contract-digest-live-implementation-design-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-errata-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-report-only-integration-proof-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round72-status-curation-v0.md`

---

## Accepted Design Shape

Accepted implementation shape:

```text
one bounded internal validator slice
```

Reason:

- R69 shape-policy proof is accepted;
- R70 recompute/canonicalization proof is accepted;
- R71 report-only integration proof is accepted;
- R72 canon-sync/errata is accepted;
- splitting shape-only first would create a temporary live half-policy where
  `contract_digest` shape is required but contract identity is not checked.

Accepted implementation owner:

```text
IgniterLang::CompilerProfileContractValidator
```

Accepted public validator API:

```ruby
validate(contract, digest_reference_policy: :prop038_24_plus)
```

No validator API change is authorized.

Accepted validator result shape:

```text
existing result fields only
```

No new top-level result fields are authorized.

---

## Authorized Write Scope

The next implementation card may edit only:

```text
igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb
igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb
igniter-lang/experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json
igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/
igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/
igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/
igniter-lang/docs/tracks/prop038-contract-digest-live-validator-implementation-v0.md
```

The three digest proof directories are explicitly included to close R73-C3-X
NB-2 and enable stronger live-parity proof updates.

The implementation must stop and request a widened Architect decision if it
needs any file outside this list.

---

## Authorized Implementation Behavior

Allowed inside the validator only:

- add `contract_digest` shape validation;
- support exactly `digest_reference_policy: :prop038_24_plus`;
- recompute canonical contract digest under the accepted R70/R72
  canonicalization rules;
- compare declared digest prefix against recomputed full SHA-256 hex;
- emit the four accepted diagnostics:

```text
compiler_profile_contract.contract_digest_invalid
compiler_profile_contract.contract_digest_policy_unsupported
compiler_profile_contract.contract_digest_mismatch
compiler_profile_contract.contract_digest_recompute_unavailable
```

Allowed standard-library requires:

```ruby
require "digest"
require "json"
```

These are Ruby standard library only and must not create gem dependencies.

---

## Canonicalization Boundary

Canonicalization helpers must remain private implementation details inside
`IgniterLang::CompilerProfileContractValidator`.

Helper names are not authority. R73-C1-P1 and R73-C2-P1 proposed different
private helper vocabularies; the implementation card may choose names consistent
with existing validator style. This closes R73-C3-X NB-1.

Required canonicalization behavior:

- canonical material is the contract object excluding `contract_digest`;
- include the 13 accepted fields from PROP-038/R72;
- exclude validation result fields, report-only/compiler-integration flags,
  provider metadata, source/out paths, parsed program, and
  `compiler_profile_source`;
- object keys sort recursively;
- `slot_order` remains order-sensitive;
- strict registry names and entries are order-insensitive;
- ordered-rule list order is order-insensitive;
- `before` and `after` edge arrays are sorted unique sets;
- `descriptor_digest` is included as a string field value;
- descriptor material is not fetched or recomputed.

The validator must not mutate caller-supplied contract material.

---

## Proof Matrix Required

The next implementation card must prove at least:

### Validator Proof

- existing 13-case validator parity remains PASS;
- shape-policy coverage:
  - `valid_short_contract_digest`;
  - `valid_full_contract_digest`;
  - `missing_contract_digest`;
  - `contract_digest_wrong_namespace`;
  - `contract_digest_too_short`;
  - `contract_digest_non_hex`;
  - `contract_digest_uppercase_hex`;
  - `unsupported_digest_policy`;
- recompute coverage:
  - `recompute_full_match`;
  - `recompute_prefix_match`;
  - `recompute_full_mismatch`;
  - `recompute_prefix_mismatch`;
  - `recompute_unavailable`;
- canonicalization coverage:
  - `canonical_excludes_contract_digest`;
  - `canonical_includes_descriptor_digest_string`;
  - `canonical_does_not_recompute_descriptor_material`;
  - `canonical_slot_order_order_sensitive`;
  - `canonical_object_key_order_insensitive`;
  - `canonical_strict_registry_order_insensitive`;
  - `canonical_rule_list_order_insensitive`;
  - `canonical_rule_edge_set_order_insensitive`;
  - `canonical_rule_reference_still_validated`;
- mutation guard: validation does not mutate caller contract material;
- result-shape guard: no new top-level validator result fields;
- flags remain:

```text
compiler_integrated=false
compile_refusal_authorized=false
```

### Report-Only Integration Proof

- digest diagnostics appear only under
  `compiler_profile_contract_validation.diagnostics`;
- digest diagnostics do not append to top-level `report["diagnostics"]`;
- compile status, `pass_result`, stages, public result, assembler execution,
  `.igapp`, and refusal-report behavior remain unchanged;
- nil/non-Hash/provider-error paths remain no-field/no-refusal;
- `CompilerResult` remains unchanged.

### Command Matrix

Required commands:

```bash
ruby -c igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb
ruby -c igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb
ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb
ruby -c igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb
ruby igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb
ruby -c igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/prop038_contract_digest_recompute_match_proof.rb
ruby igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/prop038_contract_digest_recompute_match_proof.rb
ruby -c igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/prop038_contract_digest_report_only_integration_proof.rb
ruby igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/prop038_contract_digest_report_only_integration_proof.rb
```

Optional broader proof commands may be run only as confidence checks. They are
not required unless the implementation touches a disallowed compiler path, which
would require stopping for new authorization.

---

## Fixture And Golden Policy

Allowed:

- update proof-local summaries inside the authorized experiment directories;
- update proof-local expected matrices needed for validator parity.

Not allowed:

- mutate `.igapp` manifests or golden artifacts;
- migrate existing compiler goldens;
- create persisted success reports or sidecars;
- alter loader/report or CompatibilityReport fixtures.

---

## Status Answers

### Should implementation be shape-only first or all four codes?

Implement all four accepted codes in one bounded internal validator slice.

### Is recompute/canonicalization stable enough for live validator code?

Yes, for the internal validator-only implementation boundary authorized here.

No, not for public API, persisted artifacts, loader/report, CompatibilityReport,
runtime, or production surfaces.

### Is report-only/no-refusal behavior mandatory?

Yes.

### Does compiler/orchestrator integration remain unchanged?

Yes.

No edits to `compiler_orchestrator.rb` or `compilation_report.rb` are
authorized.

### Does compile refusal remain closed?

Yes.

Compile refusal remains behind a separate future gate after live validator
implementation and report-only behavior are proven stable.

---

## Next Allowed Card Boundary

```text
Card: S3-R74-C1-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop038-contract-digest-live-validator-implementation-v0

Goal:
Implement all four accepted PROP-038 contract_digest diagnostics inside
IgniterLang::CompilerProfileContractValidator only, with proof parity and
report-only/no-refusal invariants preserved.

Allowed:
- edit only the authorized write scope named in this decision;
- keep validator API unchanged;
- keep validator result shape unchanged;
- add private canonicalization helpers;
- add `require "digest"` and `require "json"` if needed;
- update authorized proof scripts and summaries;
- produce a track doc and command matrix.

Not allowed:
- compiler/orchestrator integration;
- compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted success reports or sidecars;
- parser, TypeChecker, SemanticIR, assembler, or `.igapp` mutation;
- loader/report or CompatibilityReport;
- `IgniterLang::Diagnostics` centralization;
- RuntimeMachine, Gate 3, Ledger/TBackend, BiHistory, stream/OLAP, cache, or
  production behavior.
```

---

## Pressure Verdict

R73-C3-X verdict:

```text
proceed
blockers: none
non-blocking notes:
  NB-1 helper naming divergence
  NB-2 proof-script write scope gap
```

Architect accepts the pressure result and closes both notes in this decision:

- NB-1: helper names are private implementation detail, not authority;
- NB-2: all three digest proof directories are explicitly included in the
  implementation write scope.

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

