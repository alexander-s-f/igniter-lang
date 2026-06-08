# PROP-038 Contract Digest Errata Acceptance Decision v0

Card: S3-R72-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-contract-digest-errata-acceptance-decision-v0
Route: UPDATE
Status: accepted-errata-design-closure
Date: 2026-05-18

---

## Decision

Accept the PROP-038 `contract_digest` errata/design text.

The R71-authorized canon-sync route is satisfied:

```text
prop038-contract-digest-errata-authoring-v0
```

Authorize the next route only as design-only live validator implementation
planning:

```text
prop038-contract-digest-live-implementation-design-v0
```

This next route may design the exact bounded implementation slice for adding
`contract_digest` validation to the live internal validator. It must not
implement code.

This decision does not authorize live validator implementation, compiler
integration changes, compile refusal, public API/CLI widening, `CompilerResult`
changes, persisted reports or sidecars, parser/TypeChecker/SemanticIR changes,
assembler or `.igapp` mutation, loader/report behavior, CompatibilityReport
behavior, diagnostics centralization, dispatch migration, RuntimeMachine
behavior, Gate 3 widening, Ledger/TBackend behavior, BiHistory, stream/OLAP,
cache, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-contract-digest-errata-authoring-v0.md`
- `igniter-lang/docs/discussions/prop038-contract-digest-errata-pressure-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-report-only-integration-proof-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-recompute-match-proof-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-shape-policy-proof-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-validation-policy-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round71-status-curation-v0.md`

---

## Accepted Errata Content

PROP-038 now records the accepted digest proof chain:

```text
R69 shape policy proof
R70 recompute/canonicalization proof
R71 report-only integration proof
```

The four-code `contract_digest_*` vocabulary is now canon in PROP-038:

```text
compiler_profile_contract.contract_digest_invalid
compiler_profile_contract.contract_digest_policy_unsupported
compiler_profile_contract.contract_digest_mismatch
compiler_profile_contract.contract_digest_recompute_unavailable
```

The codes are accepted as PROP-038 design vocabulary. They are not live
implementation authority.

---

## Canonicalization Status

Accepted: PROP-038 canonicalization wording matches R70.

Canonical material is:

```text
contract object excluding contract_digest
```

Accepted included fields:

```text
kind
format_version
profile_namespace
profile_kind
compiler_profile_id
descriptor_digest
finalization_payload_digest
required_slot_schema
slot_order
slot_assignments
strict_registries
ordered_rule_graph
non_authority
```

Accepted excluded fields:

```text
contract_digest
validation result fields
report_only
compiler_integrated
compile_refusal_authorized
provider metadata
source_path / out_path
parsed_program
compiler_profile_source
```

Accepted canonicalization rules:

- object keys sort recursively;
- `slot_order` remains order-sensitive;
- strict registry names and entries are order-insensitive;
- ordered-rule list order is order-insensitive;
- `before` and `after` edge arrays are treated as sorted unique sets;
- `descriptor_digest` is included as a string field value;
- descriptor material is not fetched or recomputed.

The text correctly keeps `descriptor_digest` and `contract_digest` as separate
identities.

---

## Report-Only Placement Status

Accepted: PROP-038 report-only placement matches R71.

If implemented later, digest diagnostics belong under:

```text
report["compiler_profile_contract_validation"]["diagnostics"]
```

They must not be appended to:

```text
report["diagnostics"]
```

They must not be centralized in:

```text
IgniterLang::Diagnostics
```

without a separate Architect decision.

Accepted report-only invariants:

- compile status unchanged;
- `pass_result` unchanged;
- stages unchanged;
- public result unchanged;
- assembler execution unchanged;
- `.igapp` manifest unchanged;
- refusal-report behavior unchanged.

---

## Pressure Verdict

R72-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: none
```

Architect accepts the pressure result.

---

## Status Answers

### Is the four-code digest vocabulary now canon in PROP-038?

Yes.

The vocabulary is canon as PROP-038 design vocabulary. It is not live validator
implementation authority.

### Does canonicalization/recompute wording match R70?

Yes.

The included field list, excluded field list, order-sensitivity rules, and
`descriptor_digest` string-value rule match the accepted R70 proof and decision.

### Does report-only placement match R71?

Yes.

The errata preserves nested placement under
`compiler_profile_contract_validation.diagnostics` and explicitly blocks
top-level diagnostics, diagnostics centralization, and compile-outcome changes.

### Does live validator implementation remain held?

Yes.

### Does compile refusal remain closed?

Yes.

Compile refusal remains behind a separate future gate after live implementation
and report-only behavior are designed, implemented, and proven stable.

### May live implementation design open next?

Yes, design-only.

Allowed next card boundary:

```text
Card: S3-R73-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: prop038-contract-digest-live-implementation-design-v0

Goal:
Design the exact bounded live validator implementation slice for PROP-038
contract_digest validation, without implementing code.

Allowed:
- propose whether implementation should be split into shape-only first and
  recompute-match later, or implemented as one bounded internal validator slice;
- define exact write scope candidates;
- define validator API/result-shape changes, if any;
- define diagnostic vocabulary usage;
- define canonicalization helper boundaries;
- define proof matrix and regression requirements;
- preserve report-only/no-refusal behavior.

Not allowed:
- code implementation;
- compiler/orchestrator implementation;
- compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted reports or sidecars;
- parser, TypeChecker, SemanticIR, assembler, or `.igapp` mutation;
- loader/report or CompatibilityReport behavior;
- `IgniterLang::Diagnostics` centralization;
- RuntimeMachine, Gate 3, Ledger/TBackend, BiHistory, stream/OLAP, cache, or
  production behavior.
```

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

