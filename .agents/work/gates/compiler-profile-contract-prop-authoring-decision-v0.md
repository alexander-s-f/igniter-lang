# Compiler Profile Contract PROP Authoring Decision v0

Card: S3-R59-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: compiler-profile-contract-prop-authoring-decision-v0
Route: UPDATE
Status: hold-validator-coverage-proof-next
Date: 2026-05-16

---

## Decision

Hold new PROP authoring for `compiler_profile_contract`.

Accept `compiler-profile-contract-schema-and-rule-ownership-pressure-v0` as the
R59 formal ownership record.

Authorize only the next proof-local track:

```text
compiler-profile-contract-validator-coverage-proof-v0
```

No PROP authoring is authorized yet.

No implementation is authorized.

---

## Evidence Read

- `igniter-lang/docs/tracks/compiler-profile-contract-schema-and-rule-ownership-pressure-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-contract-schema-ownership-pressure-v0.md`
- `igniter-lang/docs/gates/compiler-profile-contract-proof-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round58-status-curation-v0.md`
- `igniter-lang/experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json`

---

## Accepted Formal Ownership Record

The R59 Compiler/Grammar pressure record is accepted.

Compiler/Grammar owns the formal semantics for:

- required slot schema;
- slot order;
- slot assignments as declared compiler-understanding ownership;
- strict registries;
- one-owner registry semantics;
- ordered rule graph well-formedness;
- rule cycle semantics;
- rule reference semantics;
- diagnostic vocabulary under `compiler_profile_contract.*`;
- future `profile_not_supplied` semantic shape.

The key accepted distinction is:

```text
slot assignment = declared compiler-understanding ownership
slot assignment != handler execution
slot assignment != dispatch authority
slot assignment != runtime authority
```

This closes the R58 need for formal ownership pressure, but it does not close
validator coverage.

---

## Reason For Hold

PROP authoring remains held because five validator branches are part of the
contract validator surface but do not yet have proof cases:

- `compiler_profile_contract.missing_rule_reference`;
- `compiler_profile_contract.wrong_kind`;
- `compiler_profile_contract.unsupported_format_version`;
- `compiler_profile_contract.descriptor_digest_invalid`;
- `compiler_profile_contract.finalization_payload_digest_invalid`.

The highest-priority blocker is:

```text
compiler_profile_contract.missing_rule_reference
```

Reason: a PROP that defines ordered-rule graph semantics must prove that every
`before` / `after` rule reference resolves to a declared rule id.

The four front-door validator paths are also required before PROP authoring
because they define object identity and version validity.

---

## Explicit Answers

### May New PROP Authoring Open?

No.

New PROP authoring may open only after
`compiler-profile-contract-validator-coverage-proof-v0` lands, is reviewed, and
a later Architect decision explicitly authorizes authoring.

### Is The Governance Route Still A New PROP?

Yes.

The future route remains a new PROP, not a PROP-036 errata.

Scope distinction:

```text
PROP-036:
  compiler_profile_id
  manifest identity
  finalized source transport
  bounded CLI source transport

future compiler_profile_contract PROP:
  contract object schema
  strict registries
  one-owner invariant
  ordered rule graph
  validation order
  non-authority boundaries
```

### Is The R58 Contract Shape Still Accepted?

Yes.

The R58 object shape remains accepted as proof-local canonical evidence. The
next proof must add coverage without changing the accepted object shape unless
it reports an explicit regression or conflict.

### Is The R59 Formal Ownership Record Accepted?

Yes.

The ownership record is precise enough to guide the next proof and later PROP
scope. It does not itself authorize authoring.

### Does Positional `required_slots` Derivation Block PROP Authoring?

Not by itself.

It is accepted as proof-only debt. The next proof may fix it by selecting
`profile_not_supplied` evidence by named case/status instead of array position.
If not fixed in the next proof, it must remain tracked before implementation
authorization.

### Must `stage` Field Semantics Be Decided Before PROP Authoring?

Yes, but not in the validator-coverage proof.

The pressure review identified that ordered rules include `stage` fields
(`parse`, `classify`, `typecheck`, `emit`) but the current proof does not decide
whether `stage` is normative validated vocabulary or informational metadata.

This must be answered in the later PROP authoring/scope decision.

### Is `fragment_class_owners` Duplicate Coverage Required?

Not required before PROP authoring, but allowed in the next proof.

The current one-owner invariant is registry-general by validator structure and
is proof-covered through `oof_descriptors`. Adding a duplicate
`fragment_class_owners` case would strengthen evidence without changing
semantics.

---

## Authorized Next Card Boundary

The next allowed card is:

```text
Card: S3-R60-C1-P1
Agent: [Igniter-Lang Research Agent]
Role: research-agent
Track: compiler-profile-contract-validator-coverage-proof-v0
```

Allowed scope:

- add proof cases for:
  - `missing_rule_reference`;
  - `wrong_kind`;
  - `unsupported_format_version`;
  - `descriptor_digest_invalid`;
  - `finalization_payload_digest_invalid`;
- preserve existing R58 accepted cases and diagnostics;
- preserve diagnostic namespace separation;
- preserve source projection behavior;
- preserve future `profile_not_supplied` shape;
- optionally replace positional `required_slots` lookup with named/status
  selection;
- optionally add duplicate `fragment_class_owners` coverage for registry-general
  one-owner confidence;
- emit proof output only under the proof experiment directory;
- produce a compact summary JSON.

Forbidden scope:

- no PROP authoring;
- no implementation;
- no parser changes;
- no TypeChecker or SemanticIR changes;
- no assembler or `.igapp` changes;
- no CLI/API widening;
- no profile discovery/defaulting/finalization in public surfaces;
- no golden migration;
- no loader/report schema or behavior;
- no CompatibilityReport section;
- no `.ilk`;
- no receipts;
- no signing;
- no compiler dispatch migration;
- no RuntimeMachine / Gate 3 widening;
- no Ledger/TBackend;
- no BiHistory;
- no stream/OLAP;
- no cache;
- no production behavior.

---

## Required Future Pressure

After the validator coverage proof lands, it should receive pressure review
before any PROP authoring authorization.

Expected review questions:

- Did all five validator paths receive proof cases?
- Did the proof preserve the accepted R58 object shape and namespace separation?
- Did optional `fragment_class_owners` coverage land or remain explicitly
  optional?
- Did positional `required_slots` proof debt improve or remain tracked?
- Did any wording imply implementation or runtime authority?

---

## Blockers Before PROP Authoring

New PROP authoring remains blocked until:

1. `compiler-profile-contract-validator-coverage-proof-v0` lands.
2. The proof covers `missing_rule_reference`.
3. The proof covers `wrong_kind`.
4. The proof covers `unsupported_format_version`.
5. The proof covers `descriptor_digest_invalid`.
6. The proof covers `finalization_payload_digest_invalid`.
7. Pressure review confirms the coverage without implementation widening.
8. Architect Supervisor issues a separate PROP-authoring authorization.

The later PROP authoring/scope decision must also answer:

```text
Is ordered-rule `stage` normative validated vocabulary or informational metadata?
```

---

## Non-Authorizations Preserved

This decision does not authorize:

- implementation in production compiler paths;
- compile refusal based on obligation coverage or contract validation;
- `.igapp` emission changes;
- CLI or Ruby API widening;
- profile discovery/defaulting/finalization in public surfaces;
- golden migration;
- loader/report implementation or schema;
- CompatibilityReport implementation or schema;
- `.ilk`;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- pack loading;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP production execution;
- cache;
- production behavior.

---

## Compact Summary

R59 accepts the Compiler/Grammar ownership record for the
`compiler_profile_contract` lane, but holds PROP authoring. The remaining
problem is narrow and concrete: five existing validator branches need proof
cases before the contract object becomes PROP-ready. The next route is a
proof-local validator coverage card. Implementation and all production/runtime
surfaces remain closed.
