# Compiler Profile Contract Validator Coverage Decision v0

Card: S3-R60-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: compiler-profile-contract-validator-coverage-decision-v0
Route: UPDATE
Status: accepted-prop-authoring-next
Date: 2026-05-16

---

## Decision

Accept `compiler-profile-contract-validator-coverage-proof-v0`.

Lift the R59 PROP-authoring hold.

Authorize new PROP authoring for:

```text
PROP-038-compiler-profile-contract-v0
```

This is authoring-only.

No implementation is authorized.

---

## Evidence Read

- `igniter-lang/docs/tracks/compiler-profile-contract-validator-coverage-proof-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-contract-validator-coverage-pressure-v0.md`
- `igniter-lang/experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json`
- `igniter-lang/docs/gates/compiler-profile-contract-prop-authoring-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round59-status-curation-v0.md`
- `igniter-lang/docs/proposals/README.md`

---

## Accepted Coverage

R60 closes the five R59 validator coverage blockers:

```text
compiler_profile_contract.missing_rule_reference
compiler_profile_contract.wrong_kind
compiler_profile_contract.unsupported_format_version
compiler_profile_contract.descriptor_digest_invalid
compiler_profile_contract.finalization_payload_digest_invalid
```

The proof reports:

```text
status: PASS
checks: 22/22 PASS
required validator paths: 5/5 covered
R58 regressions: 0
```

The accepted case matrix includes:

- `valid_contract`;
- `missing_required_slot`;
- `duplicate_strict_key`;
- `duplicate_fragment_class_owner`;
- `rule_cycle`;
- `missing_rule_reference`;
- `wrong_kind`;
- `unsupported_format_version`;
- `descriptor_digest_invalid`;
- `finalization_payload_digest_invalid`;
- `runtime_authority_forbidden`;
- `dispatch_migration_forbidden`.

R60 also closes two optional proof debts:

- positional `profile_not_supplied.required_slots` lookup is replaced with
  named/status selection;
- `fragment_class_owners` duplicate coverage is added for registry-general
  one-owner confidence.

---

## Pressure Verdict

The pressure review verdict is:

```text
proceed
blockers: none
```

The review confirms:

- all five required validator paths are machine-asserted;
- `missing_rule_reference` is precise enough for ordered-rule graph
  referential-integrity semantics;
- R58 object shape and all R58 diagnostics remain preserved;
- namespace separation remains intact;
- optional positional lookup cleanup landed;
- optional `fragment_class_owners` duplicate coverage landed;
- ordered-rule `stage` status remains correctly deferred to PROP scope;
- no wording implies implementation, dispatch, runtime, or production authority.

---

## PROP Number Assignment

Assign:

```text
PROP-038 = compiler_profile_contract
```

Rationale:

- PROP-033, PROP-034, and PROP-035 are already queued/reserved.
- PROP-036 is accepted for `compiler_profile_id` manifest identity and source
  transport.
- PROP-037 is accepted for external progression/service liveness.
- `PROP-038+` currently marks only an unassigned managed local recursion /
  loop-class placeholder.

Required index sync in the authoring card:

```text
managed local recursion / loop-class extensions placeholder -> PROP-039+ or later
```

No managed recursion, loop-class, or progression semantics are authorized by
this reassignment.

---

## Authorized Next Card Boundary

The next allowed card is:

```text
Card: S3-R61-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: prop038-compiler-profile-contract-authoring-v0
```

Allowed scope:

- author `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`;
- update `igniter-lang/docs/proposals/README.md` to index PROP-038;
- move the managed local recursion / loop-class placeholder to `PROP-039+` or
  later;
- cite the accepted evidence:
  - `compiler-profile-contract-proof-v0`;
  - `compiler-profile-contract-proof-pressure-v0`;
  - `compiler-profile-contract-proof-decision-v0`;
  - `compiler-profile-contract-schema-and-rule-ownership-pressure-v0`;
  - `compiler-profile-contract-schema-ownership-pressure-v0`;
  - `compiler-profile-contract-prop-authoring-decision-v0`;
  - `compiler-profile-contract-validator-coverage-proof-v0`;
  - `compiler-profile-contract-validator-coverage-pressure-v0`;
  - this decision record;
- do not edit code or experiments.

---

## Required PROP Sections

PROP-038 must include at least:

1. Status and scope.
2. Relationship to PROP-036 and PROP-037.
3. Contract object schema:
   - `kind`;
   - `format_version`;
   - `descriptor_digest`;
   - `finalization_payload_digest`;
   - `required_slot_schema`;
   - `slot_order`;
   - `slot_assignments`;
   - `strict_registries`;
   - `ordered_rule_graph`;
   - `non_authority`;
   - `contract_digest`.
4. Required and optional slot vocabulary.
5. Slot assignment semantics:

   ```text
   slot assignment = declared compiler-understanding ownership
   slot assignment != handler execution
   slot assignment != dispatch authority
   slot assignment != runtime authority
   ```

6. Strict registry one-owner invariant.
7. Ordered-rule graph semantics:
   - rule ids;
   - `before` / `after` referential integrity;
   - acyclicity;
   - owner slot validity;
   - rule reference diagnostics.
8. Decision on ordered-rule `stage`:
   - either normative validated vocabulary;
   - or informational metadata.
9. Digest semantics:
   - descriptor digest format;
   - finalization payload digest format;
   - what each digest is computed over.
10. Diagnostic vocabulary:
    - `compiler_profile_contract.*`;
    - separation from `compiler_profile_source.*`;
    - separation from `compiler_profile_obligation.*`;
    - separation from loader/report vocabulary.
11. Future `profile_not_supplied` shape:

    ```text
    required_slots: populated
    missing_slots: []
    ```

12. Progression handling:
    - v0 keeps progression metadata under `pipeline`;
    - no dedicated `progression` slot unless separately authorized.
13. Non-authority section.
14. OOF / refusal rules.
15. Proof evidence links.
16. Explicit excluded surfaces.
17. Open questions / deferred implementation gates.

---

## Required Non-Authority Language

PROP-038 must explicitly state:

```text
compiler_profile_contract grants no runtime authority.
compiler_profile_contract grants no dispatch migration authority.
compiler_profile_contract does not authorize dynamic pack loading.
compiler_profile_contract does not authorize loader/report behavior.
compiler_profile_contract does not authorize CompatibilityReport behavior.
compiler_profile_contract does not authorize production behavior.
```

It must also state:

```text
valid compiler_profile_contract != runtime evaluation readiness
valid compiler_profile_contract != loader/report present_verified
valid compiler_profile_contract != obligation coverage success
valid compiler_profile_contract != dispatch binding
```

---

## Required Proof References

PROP-038 may cite the R60 proof as evidence that:

- all current validator branches are proof-covered;
- R58 object shape is preserved;
- R58 namespace separation remains intact;
- `missing_rule_reference` establishes the referential-integrity invariant;
- both strict registries have duplicate-key coverage;
- positional `required_slots` proof debt is closed.

PROP-038 must not cite the proof as evidence of implementation readiness.

---

## Non-Blocking Follow-Ups

The following are not blockers to PROP authoring, but must remain visible:

- add a future missing-`after` direction proof or implementation test for
  `missing_rule_reference`;
- implementation authorization must define exact write scope;
- if contract validation becomes persisted, a golden/artifact mutation policy
  must be authorized separately;
- loader/report and CompatibilityReport surfaces require separate decisions.

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
- pack loading;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP production execution;
- cache;
- production behavior.

---

## Blockers Before Implementation

Implementation remains blocked until:

1. PROP-038 is authored.
2. PROP-038 is reviewed and accepted by a separate Architect/governance
   decision.
3. An implementation authorization decision names exact write scope.
4. Fixture/golden mutation policy is explicitly authorized if needed.
5. Loader/report, CompatibilityReport, dispatch, RuntimeMachine, and production
   surfaces remain closed unless separately authorized.

---

## Compact Summary

R60 accepts validator coverage for `compiler_profile_contract`. The five R59
validator gaps are closed, both optional proof debts landed, and pressure found
no blockers. The R59 hold is lifted for authoring only: R61 may author
`PROP-038-compiler-profile-contract-v0.md` and update the proposal index.

Implementation and all runtime/production surfaces remain closed.
