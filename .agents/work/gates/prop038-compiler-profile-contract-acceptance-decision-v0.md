# PROP-038 Compiler Profile Contract Acceptance Decision v0

Card: S3-R61-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-compiler-profile-contract-acceptance-decision-v0
Route: UPDATE
Status: accepted-proposal-only-implementation-held
Date: 2026-05-16

---

## Decision

Accept `PROP-038-compiler-profile-contract-v0.md` as proposal-only.

Implementation remains held.

Authorize only a follow-up implementation scope survey / authorization prep
track. No code changes are authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-compiler-profile-contract-authoring-v0.md`
- `igniter-lang/docs/discussions/prop038-compiler-profile-contract-pressure-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/gates/compiler-profile-contract-validator-coverage-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round60-status-curation-v0.md`

---

## Acceptance Basis

PROP-038 satisfies the R60 authoring boundary:

- defines the `compiler_profile_contract` object schema;
- distinguishes itself from PROP-036 and PROP-037;
- defines required and optional slot vocabulary;
- defines slot assignment as declared compiler-understanding ownership;
- defines strict registry one-owner semantics;
- defines ordered-rule graph validity;
- decides `stage` is informational metadata in v0;
- defines digest semantics;
- defines `compiler_profile_contract.*` diagnostics;
- separates contract, source, obligation, and loader/report vocabularies;
- preserves future `profile_not_supplied` shape;
- keeps progression metadata under `pipeline` for v0;
- includes non-authority language;
- names proof evidence;
- preserves excluded surfaces and deferred implementation gates.

The pressure review verdict is:

```text
proceed
blockers: none
```

All ten pressure scope checks pass.

---

## Explicit Answers

### Separation From PROP-036 / PROP-037

Accepted.

PROP-038 correctly separates:

```text
PROP-036 -> compiler_profile_id, manifest identity, finalized source transport
PROP-037 -> external progression and service liveness
PROP-038 -> compiler_profile_contract schema, registries, ordered rules, diagnostics
```

PROP-038 does not inline the full contract object into `.igapp/manifest.json`.

PROP-038 does not introduce a dedicated `progression` slot. For v0,
progression metadata remains under `pipeline`.

### Ordered-Rule `stage`

Accepted.

PROP-038 chooses:

```text
stage is informational metadata in PROP-038 v0
```

Unknown `stage` values must not be used as a contract-refusal basis under
PROP-038 v0.

Future promotion of `stage` to normative validated vocabulary requires a
separate proof or implementation gate.

### Digest Semantics

Accepted for proposal-only scope.

PROP-038 defines:

```text
descriptor_digest: compiler_profile_descriptor/sha256:<24+ lowercase hex>
contract_digest:   compiler_profile_contract/sha256:<24+ lowercase hex>
finalization_payload_digest: sha256:<64 lowercase hex>
```

The pressure review identifies two non-blocking digest follow-ups:

- §9.1 descriptor digest should later state exactly what material the hash is
  computed over;
- implementation/storage work must decide whether descriptor and contract
  digests continue accepting short `24+` references or require full
  64-character references.

These do not block proposal acceptance. They must be addressed before any
implementation writes digest comparison or persistence behavior.

### Non-Authority Language

Accepted.

PROP-038 includes the required non-authority language:

```text
compiler_profile_contract grants no runtime authority.
compiler_profile_contract grants no dispatch migration authority.
compiler_profile_contract does not authorize dynamic pack loading.
compiler_profile_contract does not authorize loader/report behavior.
compiler_profile_contract does not authorize CompatibilityReport behavior.
compiler_profile_contract does not authorize production behavior.
```

It also preserves:

```text
valid compiler_profile_contract != runtime evaluation readiness
valid compiler_profile_contract != loader/report present_verified
valid compiler_profile_contract != obligation coverage success
valid compiler_profile_contract != dispatch binding
```

### Implementation

Implementation remains held.

This decision accepts proposal text only. It does not authorize any compiler
behavior change.

---

## Accepted Non-Blocking Notes

The following are accepted as non-blocking but must remain visible:

1. Descriptor digest input material should be specified before implementation.
2. Descriptor/contract digest short-vs-full reference policy must be decided
   before persistence or durable validation.
3. A future missing-`after` direction test for `missing_rule_reference` is useful
   but not required for proposal acceptance.
4. PROP-037 dedicated `progression` slot remains a future decision.

---

## Authorized Next Card Boundary

The next allowed card is:

```text
Card: S3-R62-C1-P1
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop038-compiler-profile-contract-implementation-scope-survey-v0
```

Allowed scope:

- read PROP-038 and this decision;
- inspect current compiler/profile code surfaces;
- identify exact candidate write surfaces for a future implementation;
- decide whether the first implementation should be:
  - proof-local only;
  - report-only compiler integration;
  - compile-refusal capable;
  - or held for more design;
- propose exact implementation phases;
- propose fixture/golden policy if any persisted artifact would change;
- address before any implementation authorization:
  - descriptor digest input material;
  - short-vs-full digest reference policy;
  - report-only versus compile-refusal behavior;
  - where contract validation output would live, if persisted;
  - whether missing-`after` coverage belongs in proof or implementation tests;
- do not edit production code;
- do not edit parser/TypeChecker/SemanticIR/assembler behavior;
- do not authorize implementation.

Deliver:

- track doc in `igniter-lang/docs/tracks/`;
- exact write-surface options table;
- recommended first implementation boundary or hold reasons;
- blocker list before any implementation authorization.

---

## Forbidden Next Scope

The next card may not:

- implement PROP-038;
- add compile refusal;
- mutate `.igapp` output;
- migrate goldens;
- widen CLI/API;
- add loader/report or CompatibilityReport behavior;
- add `.ilk`, receipts, or signing behavior;
- migrate compiler dispatch;
- bind RuntimeMachine / Gate 3;
- touch Ledger/TBackend;
- add BiHistory behavior;
- add stream/OLAP production behavior;
- add cache or production behavior.

---

## Non-Authorizations Preserved

This decision does not authorize:

- implementation in production compiler paths;
- compile refusal based on obligation coverage or contract validation;
- parser changes;
- TypeChecker changes;
- SemanticIR changes;
- assembler or `.igapp` changes;
- CLI or Ruby API widening;
- profile discovery/defaulting/finalization in public surfaces;
- golden migration;
- loader/report implementation or schema;
- CompatibilityReport implementation or schema;
- `.ilk`;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- dynamic pack loading;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP production execution;
- cache;
- production behavior.

---

## Compact Summary

PROP-038 is accepted as proposal-only. It cleanly defines
`compiler_profile_contract` as the canonical compiler-profile contract object
and preserves the critical non-authority boundary: a valid contract is not
runtime readiness, loader/report readiness, obligation coverage success, or
dispatch binding.

Implementation remains held. The next route is a narrow implementation scope
survey to identify exact write surfaces and unresolved implementation policy
questions before any code authorization.
