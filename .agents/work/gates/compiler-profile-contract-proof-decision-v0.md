# Compiler Profile Contract Proof Decision v0

Card: S3-R58-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: compiler-profile-contract-proof-decision-v0
Route: UPDATE
Status: accepted-proof-formal-pressure-next
Date: 2026-05-16

---

## Decision

Accept `compiler-profile-contract-proof-v0` as the R58 proof record.

The proof is accepted as:

```text
proof-local
behavioral
report-only
non-authorizing
```

Do not open new PROP authoring yet.

Open one formal Compiler/Grammar pressure track before PROP authoring:

```text
compiler-profile-contract-schema-and-rule-ownership-pressure-v0
```

No implementation is authorized.

---

## Evidence Read

- `igniter-lang/docs/tracks/compiler-profile-contract-proof-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-contract-proof-pressure-v0.md`
- `igniter-lang/experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json`
- `igniter-lang/docs/gates/compiler-profile-contract-boundary-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round57-status-curation-v0.md`

---

## Accepted Proof Findings

The R58 proof validates a canonical object:

```text
kind: compiler_profile_contract
format_version: 0.1.0
```

The accepted proof object includes:

- descriptor digest;
- finalization payload digest;
- required slot schema;
- slot order;
- slot assignments;
- strict registries;
- ordered rule graph;
- non-authority flags;
- contract digest.

The proof summary reports:

```text
status: PASS
```

Accepted checks include:

- `valid_contract.accepted`;
- `source_projection.matches_profile_source`;
- `missing_required_slot.diagnostic`;
- `duplicate_strict_key.diagnostic`;
- `rule_cycle.diagnostic`;
- `runtime_authority.diagnostic`;
- `dispatch_migration.diagnostic`;
- `separation.obligation_missing_slot_present`;
- `separation.contract_missing_required_slot_distinct`;
- `separation.loader_terms_absent`;
- `separation.source_terms_absent`;
- `future_profile_not_supplied.required_slots_populated`;
- `future_profile_not_supplied.missing_slots_empty`;
- `ordering.contract_before_source`;
- `ordering.obligation_after_semanticir`;
- `disclaimer.present`.

The pressure review verdict is:

```text
proceed
blockers: none
```

---

## Explicit Answers

### Contract Object Shape

The contract object shape is stable enough to become the input to formal
Compiler/Grammar pressure.

It is not yet authorized for PROP authoring because the formal owner of slot
schema and ordered-rule graph semantics has not closed the grammar/formal
questions.

### Validation Order

The validation order is stable enough for the current proof:

```text
compiler_profile_contract_validated
  -> finalizes_to_compiler_profile_id_source
  -> source_transported_and_validated_by_compiler_profile_source
  -> semantic_ir_emitted
  -> semanticir_profile_obligation_checkpoint
  -> manifest_report_interpretation_later
```

This is accepted as a proof-local design ordering.

Before PROP authoring, Compiler/Grammar pressure must decide whether this order
needs to be expressed as:

- formal lifecycle rule;
- contract validation rule;
- profile descriptor rule;
- or non-normative implementation guidance.

### Diagnostics

Diagnostics are clean enough to accept the proof.

The following namespace separation is accepted:

```text
compiler_profile_contract.missing_required_slot
  != compiler_profile_obligation.missing_slot
  != loader/report missing_required
```

The proof also establishes that loader/report terms and
`compiler_profile_source.*` terms do not appear as contract diagnostics.

Before PROP authoring, Compiler/Grammar pressure must decide whether the
currently unexercised validator branches require proof cases or belong in the
formalization card:

- `compiler_profile_contract.wrong_kind`;
- `compiler_profile_contract.unsupported_format_version`;
- `compiler_profile_contract.descriptor_digest_invalid`;
- `compiler_profile_contract.finalization_payload_digest_invalid`;
- `compiler_profile_contract.missing_rule_reference`.

### Implementation

Implementation remains held.

This decision does not authorize:

- compile refusal based on obligation coverage;
- `.igapp` emission changes;
- CLI/API widening;
- profile discovery/defaulting/finalization in public surfaces;
- golden migration;
- loader/report;
- CompatibilityReport;
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

## Non-Blocking Notes Accepted

### NB-1: Positional Required-Slots Derivation

The proof derives future `profile_not_supplied.required_slots` through a
positional reference into the R56 obligation summary.

This is accepted for the current proof, but a future proof evolution must select
the source case by name/status instead of positional index.

### NB-2: Untested Validator Paths

The pressure review identified untested validator branches. This does not block
proof acceptance, but it blocks PROP authoring until Compiler/Grammar pressure
decides whether these branches need:

- additional proof cases;
- grammar/schema formalization;
- or explicit deferral.

---

## Authorized Next Card Boundary

The next allowed card is:

```text
Card: S3-R59-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: compiler-profile-contract-schema-and-rule-ownership-pressure-v0
```

Allowed scope:

- read R58 proof and pressure outputs;
- read R57 contract boundary decision;
- evaluate formal ownership of:
  - required slot schema;
  - slot order;
  - slot assignments;
  - strict registries;
  - one-owner registry semantics;
  - ordered rule graph;
  - rule cycle semantics;
  - rule reference semantics;
- decide whether untested validator paths must receive proof cases before PROP
  authoring;
- decide whether `profile_not_supplied.required_slots` source selection must be
  fixed before PROP authoring or may be tracked as proof-evolution debt;
- confirm whether the next governance vehicle should be a new PROP after this
  pressure lands;
- produce a compact blocker/clearance table for PROP authoring.

Forbidden scope:

- no parser implementation;
- no TypeChecker/SemanticIR implementation;
- no assembler or `.igapp` mutation;
- no CLI/API widening;
- no loader/report or CompatibilityReport schema;
- no compiler dispatch migration;
- no RuntimeMachine / Gate 3 widening;
- no Ledger/TBackend;
- no BiHistory;
- no stream/OLAP;
- no cache;
- no production behavior.

---

## Blockers Before PROP Authoring

New PROP authoring for compiler-profile contract remains blocked until:

1. `compiler-profile-contract-schema-and-rule-ownership-pressure-v0` lands.
2. Formal slot schema ownership is explicitly assigned or deferred.
3. Ordered-rule graph semantics are either formalized enough for PROP text or
   explicitly scoped out.
4. Strict registry one-owner semantics are stabilized.
5. Untested validator paths are covered, deferred, or assigned to a formal
   grammar/schema card.
6. Positional `required_slots` derivation is resolved or explicitly accepted as
   proof-only debt.
7. Architect Supervisor issues a separate PROP-authoring authorization.

---

## Blockers Before Implementation

Implementation remains blocked until:

1. A new PROP is authored and accepted, or Architect explicitly chooses a
   different governance route.
2. The implementation write scope is separately authorized.
3. Fixture/golden mutation policy is named.
4. Loader/report and CompatibilityReport boundaries are separately decided if
   touched.
5. Public surfaces remain closed unless separately authorized.

---

## Compact Summary

R58 accepts the compiler-profile contract proof. The canonical contract object,
diagnostic namespace separation, source projection, future
`profile_not_supplied` shape, and execution ordering are proof-stable. Pressure
found no blockers, but identified two non-blocking issues that must be routed
before PROP authoring: positional required-slots derivation and untested
validator branches.

Next route: Compiler/Grammar Expert pressure on formal slot schema,
one-owner registry semantics, and ordered-rule graph semantics. PROP authoring
and implementation remain held.
