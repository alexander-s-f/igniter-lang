# PROP-030: Executor Approval Token Contract v0

Status: proposal
Date: 2026-05-08
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Depends on: PROP-008, PROP-022, PROP-022A, PROP-028
Stage: 3
Source: `docs/discussions/stage3-round8-pre-gate3-pressure-v0.md`,
`docs/tracks/runtime-compatibility-report-executor-boundary-v0.md`,
`docs/spec/ch7-runtime.md`

Implementation state:
  - No executor is implemented by this PROP.
  - Gate 3 remains closed.
  - No parser syntax changes are introduced.
  - CompatibilityReport remains report-only until a future runtime proof binds
    the report decision to RuntimeMachine enforcement.

---

## 1. Purpose

S3-R8 proved that positive executor/runtime flags are insufficient for TEMPORAL
evaluation. The proof added report profiles where capability metadata, executor
presence, and live-binding claims all still refuse evaluation.

The remaining undefined term is:

```text
explicit executor approval
```

PROP-030 defines that term as a machine-readable approval object backed by an
authority decision and scoped to a specific artifact/contract/capability set.

This is a Gate 3 prerequisite. It is not a Gate 3 authorization.

---

## 2. Decision: Where Approval Lives

| Candidate location | v0 Decision | Reason |
|--------------------|-------------|--------|
| Runtime config only | carrier only | Runtime config may pass a token or token ref, but config flags are not authority. |
| CompatibilityReport | report only | CompatibilityReport may validate and explain approval state, but it must not be the approval source. |
| `.igapp` metadata | requirement only | A portable artifact may declare required capabilities/approval requirements, but must not self-authorize execution. |
| Signed/recorded Architect decision | authority source | The authority to cross Gate 3 must come from an explicit recorded decision. |
| Dedicated ApprovalToken object | canonical runtime contract | RuntimeMachine needs a stable object to validate scope, expiry, revocation, artifact binding, and signature/hash. |

v0 recommendation:

```text
ExecutorApprovalToken = canonical machine-readable approval object
authority_ref/evidence_ref = recorded Architect decision or delegated authority
runtime config = delivery mechanism
CompatibilityReport = validation/reporting layer
.igapp = approval requirement declaration, not approval authority
```

---

## 3. Token Semantics

An `ExecutorApprovalToken` authorizes a runtime to attempt a specific class of
executor operation for a specific artifact and bounded scope, provided all
other gates also pass.

It does not:

- authorize Gate 3 by itself;
- authorize Ledger read/write/replay unless explicitly scoped;
- override `.igapp` `guard_policy`;
- override missing TBackend capabilities;
- override TEMPORAL cache-key requirements;
- authorize execution after expiry or revocation;
- authorize parser/source-language behavior.

Runtime evaluation of a TEMPORAL contract requires:

```text
required temporal capabilities present
live TBackend binding present
temporal executor present
valid ExecutorApprovalToken present
Gate 3 open for the token gate/scope
artifact guard_policy allows evaluation
TEMPORAL cache key schema validated before cache use
```

If any condition fails, RuntimeMachine must refuse before any executor, Ledger,
or live TBackend operation is attempted.

---

## 4. Minimum Token Shape

Canonical JSON shape:

```json
{
  "kind": "executor_approval_token",
  "version": "executor-approval-token-v1",
  "token_id": "approval/2026-05-08/gate3/<short-id>",
  "authority_ref": "architect-supervisor/<id-or-key-ref>",
  "gate": "tbackend_gate3",
  "scope": {
    "operation": "temporal_evaluate",
    "environment": "staging|production|proof",
    "max_fragment_class": "TEMPORAL"
  },
  "artifact_ref": "igapp/sha256:<artifact-hash>",
  "contract_refs": [
    "contract/HistoryAxesTest/sha256:<contract-hash>"
  ],
  "capability_refs": [
    "history_read"
  ],
  "issued_at": "2026-05-08T12:00:00Z",
  "expires_at": "2026-05-15T12:00:00Z",
  "revocation": {
    "status": "active",
    "revocation_ref": null
  },
  "evidence_ref": "decision/gate3/record/<id>",
  "token_hash": "sha256:<canonical-token-body>",
  "signature": {
    "alg": "ed25519|recorded-decision-hash",
    "key_ref": "architect-supervisor/<key-id>",
    "value": "sig:<signature-or-record-hash>"
  }
}
```

Field requirements:

- `authority_ref` identifies who is allowed to issue the token.
- `gate` names the gate this token is scoped to; Gate 3 tokens must use
  `tbackend_gate3`.
- `scope.operation` names the operation class, such as `temporal_evaluate`.
- `artifact_ref` binds approval to an assembled `.igapp` artifact identity.
- `contract_refs` bind approval to one or more contracts inside that artifact.
- `capability_refs` bind approval to exact required capabilities.
- `issued_at` and `expires_at` bound token lifetime.
- `revocation` allows refusal before expiry.
- `evidence_ref` points to the recorded human/Architect decision.
- `token_hash` is always required.
- `signature` or an immutable recorded-decision hash is required for production
  tokens. Proof-local fixtures may use deterministic hashes, but must mark the
  token as non-production.

---

## 5. `.igapp` and CompatibilityReport Interaction

`.igapp` artifacts may declare requirements:

```json
{
  "approval_requirements": {
    "executor_approval_required": true,
    "required_gate": "tbackend_gate3",
    "required_operations": ["temporal_evaluate"],
    "required_capabilities": ["history_read"]
  }
}
```

`.igapp` artifacts must not embed a self-authorizing token.

Runtime config may supply:

```json
{
  "executor_approval_token_ref": "approval/2026-05-08/gate3/<short-id>"
}
```

CompatibilityReport should add an approval dimension:

```json
{
  "executor_approval_check": {
    "decision": "ok|blocked",
    "reason_code": "runtime.executor_approval_missing",
    "token_ref": null,
    "runtime_enforced": false
  }
}
```

The report may say `ok`, but RuntimeMachine must still enforce the same check
before evaluation. Report-only `ok` is not execution permission.

---

## 6. Refusal Rules

These are runtime/load refusal cases, not parser OOFs.

Load-time approval requirement refusals:

```text
L-AT1  malformed approval_requirements metadata
L-AT2  approval requirement references unknown capability
L-AT3  approval requirement gate conflicts with artifact guard_policy
```

Runtime approval refusals:

```text
runtime.executor_approval_missing
runtime.executor_approval_malformed
runtime.executor_approval_signature_invalid
runtime.executor_approval_authority_untrusted
runtime.executor_approval_expired
runtime.executor_approval_revoked
runtime.executor_approval_wrong_gate
runtime.executor_approval_wrong_scope
runtime.executor_approval_artifact_mismatch
runtime.executor_approval_contract_mismatch
runtime.executor_approval_capability_mismatch
runtime.executor_approval_evidence_missing
runtime.temporal_gate3_closed
runtime.temporal_cache_schema_mismatch
```

Ordering rule:

```text
missing/invalid approval must refuse before any executor call;
Gate 3 closed must refuse even when approval token shape is otherwise valid;
TEMPORAL cache schema mismatch must refuse before cache read/write.
```

---

## 7. Gate 3 Invariant

PROP-030 does not open Gate 3.

Gate 3 opening requires a separate Architect decision. Even with a valid token,
RuntimeMachine must refuse while Gate 3 is closed:

```text
valid token + Gate 3 closed -> runtime.temporal_gate3_closed
```

A future Gate 3 implementation must prove:

- RuntimeMachine checks approval before attempting execution.
- RuntimeMachine checks Gate 3 state independently of token presence.
- RuntimeMachine checks TEMPORAL cache key schema before cache use.
- CompatibilityReport and RuntimeMachine return consistent approval decisions.

---

## 8. Recommended Runtime Proof Slices

### C3: executor-approval-token-report-proof-v0

Goal: extend the CompatibilityReport proof with a token validation matrix.

Cases:

- missing token -> `runtime.executor_approval_missing`
- malformed token -> `runtime.executor_approval_malformed`
- invalid signature/hash -> `runtime.executor_approval_signature_invalid`
- untrusted authority -> `runtime.executor_approval_authority_untrusted`
- expired token -> `runtime.executor_approval_expired`
- revoked token -> `runtime.executor_approval_revoked`
- wrong gate/scope/artifact/contract/capability -> matching refusal code
- valid token while Gate 3 closed -> `runtime.temporal_gate3_closed`

Required invariant:

```text
operation_check.temporal_executor_call_attempted == false
operation_check.live_tbackend_call_attempted == false
operation_check.ledger_call_attempted == false
```

### C4: guarded-runtime-executor-approval-enforcement-v0

Goal: prove GuardedRuntimeMachine enforces the same approval decision before
executor dispatch.

Cases:

- C2 `claimed_executor_live_binding` profile refuses before executor call.
- C2 `approved_executor_placeholder` profile refuses with Gate 3 closed.
- Valid proof-local token still refuses while Gate 3 is closed.
- TEMPORAL executor boundary simulates cache key construction and rejects a
  CORE-shaped key for a TEMPORAL contract with
  `runtime.temporal_cache_schema_mismatch`.

Required invariant:

```text
CompatibilityReport decision == GuardedRuntimeMachine decision
```

---

## 9. Status

Proposal status: `proposal`.

Recommended disposition:

- accept `ExecutorApprovalToken` as the canonical approval contract;
- keep `.igapp` metadata as requirement declaration only;
- keep CompatibilityReport as validation/reporting only;
- require RuntimeMachine enforcement before any live executor operation;
- keep Gate 3 closed until a separate Architect decision opens it.
