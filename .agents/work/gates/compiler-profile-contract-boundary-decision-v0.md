# Compiler Profile Contract Boundary Decision v0

Card: S3-R57-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: compiler-profile-contract-boundary-decision-v0
Route: UPDATE
Status: accepted-design-proof-next
Date: 2026-05-16

---

## Decision

Accept `compiler-profile-contract-boundary-v0` as the design record for the
compiler-profile contract boundary.

Authorize the next bounded track as a proof-local experiment:

```text
compiler-profile-contract-proof-v0
```

No implementation is authorized.

---

## Evidence Read

- `igniter-lang/docs/tracks/compiler-profile-contract-boundary-v0.md`
- `igniter-lang/docs/tracks/compiler-profile-contract-bridge-surface-review-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-contract-boundary-pressure-v0.md`
- `igniter-lang/docs/gates/compiler-profile-obligation-coverage-proof-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round56-status-curation-v0.md`
- `igniter-lang/docs/proposals/PROP-036-compiler-profile-manifest-identity-v0.md`

---

## Accepted Boundary Decisions

### Lifecycle Placement

Obligation coverage belongs at the design-only:

```text
SemanticIR profile-obligation checkpoint
```

Placement:

```text
after SemanticIR emit
before assembly
```

This is accepted as a **proposed future design position**, not current
implementation.

No compiler pass is implemented by this decision.

### Vocabulary Namespace Policy

Four vocabularies remain separate:

```text
compiler_profile_source.*       -> finalized source transport validity
compiler_profile_obligation.*   -> surface/slot coverage report
compiler_profile_contract.*     -> future contract object validation
loader/report status vocabulary -> manifest/load/report interpretation
```

Design rule:

```text
missing_slot != missing_required_slot != missing_required
```

Meaning:

- `compiler_profile_obligation.missing_slot` means a program surface requires a
  slot not supplied by the profile.
- `compiler_profile_contract.missing_required_slot` means the contract object
  itself lacks a schema-required slot.
- loader/report `missing_required` means the manifest lacks
  `compiler_profile_id` under a future `profile_required` rollout policy.

### `profile_not_supplied.missing_slots`

Future design decision:

```text
status: profile_not_supplied
required_slots: populated
missing_slots: []
```

Rationale:

- `required_slots` remains useful evidence derived from the program surfaces.
- `missing_slots` is reserved for profile-present comparison failures.
- no supplied profile means there is no supplied slot set to compare against.

This does not rewrite the accepted R56 proof output. It constrains the future
design/proof direction.

### PROP-037 Progression Slot

For this boundary:

```text
progression_descriptor remains under pipeline
```

No dedicated `progression` slot is authorized.

Whether PROP-037 later needs a dedicated `progression` slot remains a future
Architect decision. It must not be silently introduced by contract proof or
obligation coverage.

### Loader/Report And CompatibilityReport

Loader/report and CompatibilityReport remain closed.

The bridge review is accepted only as design pressure. It does not create a
schema, adapter, report section, or implementation.

Accepted invariant:

```text
present_verified
  != obligation covered
  != compiler_profile_contract valid
  != runtime_evaluation_readiness.ready
```

---

## Execution Ordering For The Next Proof

The next proof must use this conceptual execution/order relationship:

```text
compiler_profile_contract validated
  -> finalizes to compiler_profile_id_source
  -> source transported / validated by compiler_profile_source.*
  -> SemanticIR emitted
  -> obligation checkpoint runs over emitted surfaces
  -> assembly may carry manifest compiler_profile_id
  -> future loader/report may interpret manifest/profile status
```

The boundary diagram in C1-P1 is accepted as a **layer/authority map**, not as
a temporal execution order.

The proof scope must explicitly state this distinction.

---

## Authorized Next Card Boundary

The next allowed card is:

```text
Card: S3-R58-C1-P1
Agent: [Igniter-Lang Research Agent]
Role: research-agent
Track: compiler-profile-contract-proof-v0
```

Allowed proof-local scope:

- Validate a canonical `compiler_profile_contract` object.
- Include at least:
  - descriptor digest;
  - finalization payload digest;
  - required slot schema;
  - strict registries / one-owner checks;
  - ordered rule graph references;
  - ordered rule cycle detection;
  - non-authority flags:
    - `runtime_authority_granted: false`;
    - `dispatch_migration_authorized: false`.
- Prove `compiler_profile_contract.missing_required_slot` is distinct from
  `compiler_profile_obligation.missing_slot`.
- Prove `profile_not_supplied` design behavior:

  ```text
  required_slots: populated
  missing_slots: []
  ```

- Prove loader/report terms do not appear as compiler contract diagnostics.
- Emit proof output only under its own experiment directory.
- Do not touch live compiler dispatch or persisted artifacts.
- Include the disclaimer:

  ```text
  SemanticIR profile-obligation checkpoint is a proposed future design position,
  not current implementation.
  ```

Deliver:

- track doc in `igniter-lang/docs/tracks/`;
- executable proof under `igniter-lang/experiments/`;
- summary JSON;
- compact table of contract cases and diagnostic results;
- remaining blockers before any implementation authorization.

---

## Governance Route

If `compiler-profile-contract-proof-v0` stabilizes a canonical object shape and
validation order, the promotion vehicle should be:

```text
new PROP
```

not a direct PROP-036 errata.

Reason:

PROP-036 owns manifest identity and source transport. A compiler-profile
contract spans descriptor validity, slot schema, strict registries, ordered
rules, pack refs, non-authority flags, and future validation order. That is
broader than a small PROP-036 amendment.

A future PROP-036 addendum may cross-reference the contract only after the
contract route is accepted.

---

## Held / Not Authorized

This decision does not authorize:

- implementation in production compiler paths;
- compile refusal based on obligation coverage;
- `.igapp` emission changes;
- CLI/API widening;
- inline JSON, named/generated lookup, env/config/sidecar lookup;
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

## Blockers Before Implementation Authorization

Implementation remains blocked until at least:

1. `compiler-profile-contract-proof-v0` lands and is pressure reviewed.
2. The canonical `compiler_profile_contract` object shape is proof-stable.
3. Contract diagnostic vocabulary is stable and separate from:
   - `compiler_profile_source.*`;
   - `compiler_profile_obligation.*`;
   - loader/report vocabulary.
4. The future execution order is proof-validated:

   ```text
   contract -> source -> obligation checkpoint -> manifest/report
   ```

5. PROP-037 progression slot disposition is either kept under `pipeline` or
   separately authorized.
6. Architect issues a separate implementation authorization with exact write
   scope.

---

## Compact Summary

R57 accepts the compiler-profile contract boundary design. Obligation coverage
belongs after SemanticIR emit and before assembly as a future design position.
The vocabulary namespaces stay separate. `profile_not_supplied` should keep
`required_slots` populated and `missing_slots` empty in future design. PROP-037
progression remains under `pipeline`.

The next track is proof-local `compiler-profile-contract-proof-v0`. No
implementation, loader/report, CompatibilityReport, dispatch, runtime, CLI, or
production authority is opened.
