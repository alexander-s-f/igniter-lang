# Phase 1 Production Durable Audit Scope Decision v0

Card: S3-R25-C2-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: `phase1-production-durable-audit-scope-decision-v0`
Date: 2026-05-10
Status: approved-for-design-only

---

## Decision

Decision: **approve design-only work** for `phase1-production-durable-audit-v0`.

This decision allows the next track to design the production durable audit
surface for the already-signed restricted Gate 3 Phase 1 live-read path.

This decision does **not** authorize implementation, production deployment,
Ledger adapter binding, Phase 2, writes, replay, compact, subscribe, production
cache, BiHistory, stream/OLAP, or any new runtime capability.

Safe status phrase:

```text
Phase 1 production durable audit is approved for design only.
Implementation, production deployment, Ledger/Phase 2, BiHistory, stream/OLAP,
production cache, writes/replay/compact/subscribe, and production signing
execution remain closed until a later Architect decision.
```

---

## Reviewed Inputs

- `igniter-lang/docs/tracks/phase1-post-r23-regression-rerun-v0.md`
- `igniter-lang/docs/tracks/phase1-durable-observation-persistence-shape-v0.md`
- `igniter-lang/docs/tracks/phase1-observation-tamper-evidence-shape-v0.md`
- `igniter-lang/docs/discussions/phase1-post-r23-regression-and-durability-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round24-status-curation-v0.md`

The current evidence says:

- post-R23 regression rerun is green: **23/23 PASS**;
- proof-local observation persistence shape exists and keeps
  `production_durable_audit: false`;
- proof-local tamper-evidence shape exists and is explicitly content integrity,
  not cryptographic authorization;
- External Pressure Review says **PROCEED** with non-blockers only;
- Gate 3 signed Phase 1 scope remains restricted to `History[T]` valid_time
  reads with explicit `as_of` and safe non-Ledger backend identity.

---

## Approved Design-Only Scope

The next design track may specify the following production durable audit
surfaces. It may not implement them.

### 1. Signing Boundary

The design may compare and select a signing model:

- HSM/KMS signing per audit record;
- signing abstraction that can be backed by HSM/KMS later;
- verification key material and auditor verification rules;
- key identity fields in audit receipts.

The design must keep signing separate from `gate3_authorized` source-code parity
checks. Production signing is not enabled by this decision.

### 2. Restart Rebuild Algorithm

The design may define how an audit store rebuilds chain state after restart:

1. read persisted records in storage order;
2. validate `format_version`;
3. recompute canonical record hashes;
4. verify `sequence`, `previous_record_hash`, and signature continuity;
5. report gap, reorder, hash mismatch, signature mismatch, or truncation;
6. set the next append cursor only after full verification.

The design must define failure modes and recovery posture, but may not write a
production store.

### 3. `format_version` Enforcement

The design may define version rules for audit records:

- accepted versions;
- rejected versions;
- migration policy;
- mixed-version log behavior;
- error / refusal codes.

The current proof-local `0.2.0` tamper-evidence format is informational only.
Production design must make version validation explicit.

### 4. Retention and Replay Semantics

The design may define:

- retention policy fields;
- TTL / archival semantics;
- ordered audit replay;
- idempotent read-back verification;
- replay refusal when gaps or signature failures are detected.

This does not authorize runtime replay operations or Ledger replay. Replay here
means audit-reader verification of persisted audit records only.

### 5. Off-Process Persistence Identity

The design may define production storage identity:

- storage provider identity;
- deployment / region / shard identity;
- durability model;
- append-only guarantees;
- writer identity;
- auditor-visible identity.

The design must preserve the distinction between proof-local file-backed JSONL
and any production store.

### 6. Audit Reader Role

The design may define a read-only audit reader role:

- allowed queries;
- chain verification interface;
- export format;
- refusal/error surfaces;
- separation from executor write/append authority.

The audit reader must not be able to perform live reads, Ledger reads/writes,
replay, compact, subscribe, or policy authorization.

### 7. Compliance Language Boundaries

The design may define the vocabulary for compliance posture:

- what can be called `audit_ready`;
- what can be called `production_durable_audit`;
- what cannot yet be claimed;
- which compliance regimes are explicitly out of scope unless named later.

No GDPR/SOC2/PCI or similar claim is authorized by this decision.

---

## Explicit Non-Authorization

This decision does not authorize:

- implementation of production durable audit;
- production deployment;
- production signing execution or key management;
- Ledger adapter or package binding;
- Phase 2;
- Ledger reads, writes, replay, compact, subscribe;
- BiHistory or transaction-time reads;
- stream / OLAP production executors;
- production cache;
- runtime authority registry service implementation;
- broadening `gate3_authorized: true`;
- durable side effects in the current `TemporalExecutor::Phase1`.

The signed Gate 3 live-read addendum remains unchanged.

---

## Required Outputs From The Next Design Track

`phase1-production-durable-audit-v0` should deliver:

- production audit record schema;
- signing / verification model;
- restart rebuild algorithm;
- version enforcement rules;
- retention and audit replay semantics;
- storage identity model;
- audit reader role definition;
- compliance language boundaries;
- refusal/error code list;
- explicit list of implementation blockers;
- proof plan for a later implementation track.

The design track should also state whether it is ready for implementation
authorization review, not assume that authorization.

---

## Blockers Before Implementation Authorization

Implementation authorization requires a later Architect decision and at least:

1. post-R24 regression rerun expanded to the current matrix, expected **25
   commands** once R24 registry storage and tamper-evidence fixtures are added;
2. pressure review of the production durable audit design;
3. production registry ownership decision or explicit statement that audit
   persistence can proceed without registry ownership coupling;
4. selected signing boundary and key-identity model;
5. restart rebuild and failure-mode proof plan;
6. `format_version` enforcement proof plan;
7. explicit non-Ledger / non-Phase-2 statement preserved.

Until those blockers are closed, the only approved work is design.

---

## Handoff

```text
Card: S3-R25-C2-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: phase1-production-durable-audit-scope-decision-v0
Status: approved-for-design-only

[D] Decision
- Approve the next track to design production durable audit for restricted Gate 3
  Phase 1 live reads.
- Do not authorize implementation or production deployment.
- Keep Gate 3 signed Phase 1 live-read scope unchanged.

[Scope] Design may cover
- HSM/KMS signing or signing abstraction
- restart rebuild algorithm
- format_version enforcement
- retention/replay semantics for audit verification only
- off-process persistence identity
- audit reader role
- compliance language boundaries

[X] Still closed
- implementation, production deployment, Ledger adapter, Phase 2, BiHistory,
  stream/OLAP, production cache, writes/replay/compact/subscribe, production
  signing execution, runtime authority registry implementation.

[Blockers before implementation]
- 25-command regression rerun
- pressure review
- registry ownership decision or decoupling statement
- signing boundary selected
- rebuild/version proof plan
- non-Ledger/non-Phase-2 statement preserved
```
