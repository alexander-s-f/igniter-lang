# Durable Audit B-E Deployment Review Decision v0

Card: S3-R36-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: durable-audit-b-e-deployment-review-decision-v0
Status: approved-restricted-phase1-production-durable-audit-deployment-scope
Date: 2026-05-11

---

## Decision

Authorize a **restricted Phase 1 production durable audit deployment scope**.

This decision opens only the bounded production-facing durable audit surface
proven by B-A, B-B, B-C, and B-D. It does not authorize Ledger binding, Phase 2,
BiHistory, stream/OLAP production execution, production cache, broad
RuntimeMachine binding, or any general-purpose persistence API.

Safe status phrase:

```text
Phase 1 production durable audit deployment scope is approved for the bounded
audit append/read/rebuild surface. All excluded runtime, Ledger, Phase 2,
BiHistory, stream/OLAP, cache, and broad RuntimeMachine surfaces remain closed.
```

---

## Readiness Evidence

| Surface | Evidence | Decision |
|---------|----------|----------|
| B-A restart rebuild | `durable-audit-restart-rebuild-proof-v0.md` | Closed |
| B-B audit traversal / reader | `durable-audit-reader-traversal-proof-v0.md` | Closed |
| B-C appender / reader role boundary | `durable-audit-append-reader-role-boundary-proof-v0.md` | Closed |
| P-43 clean rebuild append gate | `audit.writer.rebuild_not_clean` proof cases | Closed |
| B-D post-implementation regression matrix | `durable-audit-post-implementation-regression-matrix-v0.md` | Closed: 9/9 commands PASS, 97/97 durable audit cases PASS |
| External runtime pressure | `r35-durable-audit-prop036-progression-prop032-pressure-v0.md` | PROCEED, non-blockers only |

The proof chain demonstrates that the bounded durable audit surface can:

- validate canonical audit record schema and `format_version`;
- validate append-only sequence and hash chain;
- reject mutation/overwrite/delete behavior;
- rebuild audit state from the audit log;
- stop appends when rebuild status is not clean;
- re-derive `compliance_posture`;
- separate appender and reader roles;
- keep excluded surfaces closed.

---

## Authorized Production Deployment Scope

### 1. Production Storage Identity Boundary

Authorized:

- a dedicated Phase 1 durable audit storage identity;
- non-Ledger, off-process or local-process append-only audit storage;
- storage identity validation against an expected configured audit-storage
  identity;
- startup/rebuild refusal when stored records do not match the expected
  identity.

Required:

```text
storage_identity must be explicit, stable, and audit-specific.
Ledger storage identities are refused in Phase 1.
```

Not authorized:

- Ledger adapter;
- general-purpose persistence store;
- sharing storage identity with runtime/TBackend/Ledger stores;
- treating proof-local storage as production storage without deployment config.

### 2. Signing / HSM / KMS Status

Authorized:

- signing abstraction boundary;
- production-shaped signer configuration validation;
- production deployment with a configured signer abstraction only if it rejects
  nil/no-op/stub/local-test identities and emits reason-coded refusals;
- signed audit record metadata through the approved abstraction.

Not authorized:

- selecting or onboarding a concrete HSM/KMS provider by this decision;
- direct vendor-specific key-management integration;
- production key issuance ceremony;
- mutable or environment-only signer trust.

If a concrete HSM/KMS provider is required, it needs a separate provider
onboarding card or addendum.

### 3. Audit Append Role

Authorized role:

```text
phase1_audit_appender
```

May:

- append canonical audit records;
- receive sequence and hash-chain assignment;
- receive reason-coded refusal when rebuild status is not clean.

Must not:

- read beyond explicitly approved append result metadata;
- mutate, overwrite, delete, replay, compact, or subscribe;
- bypass signer, storage identity, schema, hash, or rebuild gates.

### 4. Audit Reader Role

Authorized role:

```text
phase1_audit_reader
```

May:

- traverse the append-only audit chain;
- filter returned verified records by approved filter dimensions such as
  sequence range and record kind;
- report integrity failures and posture mismatches;
- re-derive `compliance_posture` for returned records.

Must not:

- append, mutate, delete, authorize Gate 3, sign, replay, compact, subscribe,
  or query Ledger/runtime stores;
- act as broad analytics, OLAP, or stream subscription interface.

### 5. Rebuild-Clean Append Gate

Authorized and required:

```text
audit append MUST refuse when last rebuild status is not clean.
```

Required refusal code:

```text
audit.writer.rebuild_not_clean
```

This is a production deployment requirement, not a proof-local suggestion.

### 6. Restart / Rebuild Startup Requirement

Authorized and required:

- startup must run audit-log rebuild or verify a fresh rebuild result before
  accepting appends;
- rebuild must full-scan records, collect all errors, and set cursor to the
  first failure point;
- append surface must remain closed unless rebuild status is clean;
- stored records must never be auto-repaired, truncated, compacted, or modified
  by rebuild.

### 7. Compliance Posture Re-Derivation

Authorized and required:

- `compliance_posture.production_durable_audit` must be derived from storage
  identity, chain verification, signature verification, and authorization
  status;
- caller-provided compliance posture is not trusted;
- reader traversal must compare stored vs re-derived posture;
- mismatch must produce a stable observation/refusal code and exclude the
  mismatched record from verified export.

Required code:

```text
audit.record.compliance_posture_mismatch
```

### 8. Observability / Refusal Codes

Deployment must preserve stable reason codes for:

```text
audit.record.format_version_missing
audit.record.format_version_unrecognized
audit.record.kind_unrecognized
audit.chain.sequence_gap
audit.record.storage_identity_mismatch
audit.chain.previous_hash_mismatch
audit.chain.record_hash_mismatch
audit.record.compliance_posture_mismatch
audit.writer.unauthorized
audit.reader.unauthorized
audit.writer.rebuild_not_clean
audit.signer.*
```

Additional codes may be added only if they do not collapse or hide the existing
ones.

---

## Explicit Exclusions Still Closed

This decision does not authorize:

- Ledger adapter;
- Ledger reads/writes/replay/compact/subscribe;
- Phase 2;
- BiHistory or transaction-time reads;
- stream/OLAP production executor;
- production cache;
- broad RuntimeMachine binding;
- broad query/analytics engine;
- production authority registry implementation;
- general-purpose write/replay/compact/subscribe APIs outside the audit append
  scope;
- concrete HSM/KMS provider onboarding;
- `.igapp` / `.ilk` changes;
- Gate 3 widening;
- TBackend binding.

---

## Required Follow-Up Before Operational Rollout

The deployment implementation/card that cites this decision must provide:

1. exact production audit storage identity configuration;
2. signer abstraction configuration and refusal behavior;
3. startup rebuild verification behavior;
4. appender/reader role wiring;
5. observability/refusal-code export;
6. rollback/disable procedure for the audit surface;
7. a post-deployment smoke proof or checklist showing append, read, rebuild,
   and refusal paths.

If any of these cannot be provided, rollout must hold.

---

## Compact Summary

Decision: **authorize restricted Phase 1 production durable audit deployment
scope**.

The audit append/read/rebuild surface may move from proof-only toward bounded
production deployment, provided it uses explicit audit storage identity, signer
abstraction validation, appender/reader roles, rebuild-clean append gating,
startup rebuild verification, compliance posture re-derivation, and stable
refusal codes. Ledger, Phase 2, BiHistory, stream/OLAP, production cache, broad
RuntimeMachine binding, concrete HSM/KMS onboarding, and all general persistence
surfaces remain closed.
