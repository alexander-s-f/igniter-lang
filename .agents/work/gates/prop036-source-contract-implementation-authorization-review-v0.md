# PROP-036 Source Contract Implementation Authorization Review v0

Card: S3-R42-C6-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop036-source-contract-implementation-authorization-review-v0
Route: UPDATE
Status: approved-bounded-proof-implementation
Date: 2026-05-13

---

## Decision

**AUTHORIZE bounded proof-local implementation only.**

The next implementation may build a minimal CompilerProfile finalization proof
that produces a finalized `compiler_profile_id_source` object from frozen
descriptor material.

This decision does **not** authorize assembler field emission, `.igapp` manifest
mutation, loader/report status implementation, compiler dispatch migration,
RuntimeMachine binding, or production behavior.

---

## Evidence Read

- `docs/gates/prop036-assembler-field-implementation-authorization-review-v0.md`
- `docs/tracks/prop036-compiler-profile-id-source-contract-v0.md`
- `docs/tracks/prop036-source-contract-code-surface-survey-v0.md`
- `docs/proposals/PROP-036-compiler-profile-manifest-identity-v0.md`
- `docs/dev/compiler-profile-architecture-direction.md`
- `lib/igniter_lang/assembler.rb`
- `lib/igniter_lang/compiler_orchestrator.rb`

---

## Findings

### Closed By C4/C5

C4/C5 close the source-contract design gap enough to authorize a proof-local
implementation slice:

- the authoritative source is a frozen CompilerProfile descriptor followed by
  minimal finalization;
- a raw string or proof-local constant is not an authority source;
- keyword transport is allowed only after a finalized source object exists;
- the source object shape and refusal vocabulary are specified;
- finalization must preserve no compiler dispatch migration and no runtime
  authority;
- assembler code-surface risk is understood but still blocked until
  finalization is proven.

### Still Not Closed

The assembler field implementation remains blocked because the finalized source
object is not yet executable evidence.

C4/C5 both identify the same next blocker:

```text
minimal-compiler-profile-finalization-proof-v0
```

That proof must exist and pass before `assembler-compiler-profile-id-field-v0`
can be reconsidered.

---

## Authorized Implementation Boundary

The next allowed implementation card is:

```text
Card: S3-R42-C7-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: minimal-compiler-profile-finalization-proof-v0
```

Authorized scope:

- implement a proof-local finalization script under `igniter-lang/experiments/`;
- use frozen descriptor material as input;
- validate the descriptor shape needed for finalization;
- validate canonical `Stage3ProofCompilerProfileSpec` slot order;
- canonicalize finalization payload material with lexicographic object keys;
- derive `compiler_profile_unified/sha256:<24+ lowercase hex chars>`;
- emit a finalized `compiler_profile_id_source` object matching C4 shape;
- prove input-order independence;
- prove implementation identity changes change the derived id;
- prove the `compiler_profile_id` is not part of the payload it hashes;
- reject missing, malformed, wrong-kind, unfinalized, namespace, malformed-id,
  digest-mismatch, slot-order-mismatch, runtime-authority, and
  dispatch-migration cases;
- write a compact summary JSON under the experiment `out/` directory;
- write a track doc under `docs/tracks/`.

Required proof outputs:

```text
experiments/minimal_compiler_profile_finalization_proof/
  minimal_compiler_profile_finalization_proof.rb
  out/minimal_compiler_profile_finalization_summary.json
```

The proof may reuse existing proof-local profile experiments as references, but
it must produce its own C4-compatible `compiler_profile_id_source` object.

---

## Required Proof Matrix

The implementation card must include at least these cases:

| Case | Required result |
| --- | --- |
| valid frozen descriptor | produces finalized source object |
| permuted descriptor keys | produces the same id |
| implementation identity changed | produces a different id |
| payload contains `compiler_profile_id` | refuses |
| missing source material | refuses |
| malformed descriptor/object | refuses |
| wrong kind | refuses |
| unfinalized source status | refuses |
| unsupported namespace | refuses |
| malformed id | refuses |
| digest mismatch | refuses |
| slot order mismatch | refuses |
| `runtime_authority_granted: true` | refuses |
| `dispatch_migration_authorized: true` | refuses |

Reason codes should follow C4/C5 where applicable, especially:

```text
compiler_profile_source.missing
compiler_profile_source.malformed
compiler_profile_source.wrong_kind
compiler_profile_source.unfinalized
compiler_profile_source.unsupported_namespace
compiler_profile_source.malformed_id
compiler_profile_source.id_digest_mismatch
compiler_profile_source.slot_order_mismatch
compiler_profile_source.runtime_authority_forbidden
compiler_profile_source.dispatch_migration_forbidden
```

The implementation may add proof-local finalization-specific reason codes if
needed, but it must not use loader/report status values such as
`present_verified`, `mismatch`, `malformed`, or `missing_required`.

---

## Non-Authorizations

This decision does not authorize:

- assembler implementation;
- `.igapp` manifest mutation;
- `.igapp` golden migration;
- `.ilk` changes;
- loader/report/status implementation;
- CompatibilityReport production changes;
- CompilationReceipt links;
- signing;
- production signer/key/HSM/KMS behavior;
- compiler dispatch migration;
- parser syntax;
- TypeChecker or SemanticIR changes;
- RuntimeMachine binding;
- RuntimeMachine execution authority;
- Gate 3 widening;
- Ledger or TBackend binding;
- BiHistory live execution;
- stream or OLAP production executors;
- production cache;
- production deployment.

---

## Reconsideration Rule

After `minimal-compiler-profile-finalization-proof-v0` passes, the Architect may
reconsider a separate assembler-field implementation authorization.

That future decision must name exact scope for:

- assembler-only field placement;
- whether `compiler_profile_source:` is threaded through
  `Assembler#assemble_artifacts`;
- whether `CompilerOrchestrator` passes a finalized source object or remains
  unchanged for the first assembler slice;
- fixture/golden mutation policy;
- artifact hash churn expectations.

Until that future decision exists, `assembler-compiler-profile-id-field-v0`
remains closed.

---

## Compact Summary

C4/C5 are strong enough to authorize the next proof-local implementation:
`minimal-compiler-profile-finalization-proof-v0`.

The approved implementation must derive a real
`compiler_profile_unified/sha256:*` id from frozen descriptor/finalization
payload material and emit a finalized `compiler_profile_id_source` object. It
must prove refusals and preserve no dispatch migration and no runtime authority.

Assembler manifest emission remains blocked.
