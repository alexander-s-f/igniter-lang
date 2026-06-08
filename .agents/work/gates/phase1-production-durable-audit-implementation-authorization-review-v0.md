# Phase 1 Production Durable Audit Implementation Authorization Review v0

Card: S3-R27-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: `phase1-production-durable-audit-implementation-authorization-review-v0`
Date: 2026-05-10
Status: hold-before-implementation-authorization

---

## Decision

Decision: **hold implementation authorization**.

`phase1-production-durable-audit-v0` is specific enough for implementation
authorization review, but implementation must not begin yet. The design is
accepted as a strong candidate surface; the authorization gate remains closed
until the blockers below are satisfied and reviewed.

This decision does not authorize production durable audit implementation,
production deployment, production signing execution, Ledger, Phase 2, BiHistory,
stream/OLAP, production cache, writes, replay, compact, or subscribe.

Safe status phrase:

```text
Phase 1 production durable audit implementation authorization is held.
The design is review-ready, but implementation remains closed until the
pre-authorization blockers are closed and a later Architect decision explicitly
authorizes a bounded implementation track.
```

---

## Reviewed Inputs

- `igniter-lang/docs/tracks/phase1-production-durable-audit-v0.md`
- `igniter-lang/docs/gates/phase1-production-registry-ownership-decision-v0.md`
- `igniter-lang/docs/tracks/deterministic-regression-artifact-policy-v0.md`
- `igniter-lang/docs/discussions/phase1-production-durable-audit-design-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round26-status-curation-v0.md`

Evidence summary:

- durable audit design is complete enough to review: record schema, signing
  model, restart rebuild, version rules, audit traversal, storage identity,
  audit reader, compliance boundaries, refusal codes, blockers, proof plan;
- registry ownership is decided for design: gate document store is source of
  truth; generated content-addressed index is query artifact; package/runtime
  are cache/validator only;
- deterministic artifact policy exists, but `_volatile_fields` enforcement and
  full artifact survey are not yet closed;
- pressure review says **PROCEED** for design with non-blocking items, but those
  items must become blockers before implementation authorization.

---

## R26 Pressure Non-Blocker Evaluation

### 1. `compliance_posture` Store Binding

Status: **not closed**.

The design defines:

```json
"compliance_posture": {
  "audit_ready": true,
  "production_durable_audit": true,
  "production_compliance_claim": false,
  "compliance_regimes": []
}
```

The implementation authorization package must prove that
`production_durable_audit: true` is derived from approved production audit store
identity and successful chain/signature validation, not freely asserted by a
caller.

Required closure signal:

```text
compliance_posture.production_durable_audit is store-bound and verification-bound.
Proof-local stores cannot emit or accept production_durable_audit: true.
Production stores cannot accept production_durable_audit: false for a successful
production append without an explicit refusal/error.
```

### 2. Signer Injection / No-Op Rejection

Status: **not closed**.

The design recommends an injectable HSM/KMS-backed signer abstraction. That is a
good boundary, but production configuration must not silently accept a no-op,
stub, local-test, or unsigned signer.

Required closure signal:

```text
production signer configuration rejects nil/no-op/stub/local-test signers and
requires a trusted signing_key_id, signing_key_version, signing_authority_ref,
and verification metadata source.
```

The implementation authorization package must include a signer-validation proof.

### 3. Startup-Time Freshness Bound

Status: **not closed**.

The registry ownership decision permits `release_time` and `startup_time`
freshness modes. For long-running processes, `startup_time` needs a maximum
staleness bound.

Required closure signal:

```text
startup_time registry index freshness has a maximum staleness bound and fails
closed when the bundled/generated index is older than that bound or lacks a
valid immutable anchor.
```

This does not authorize per-invocation online lookup.

### 4. `_volatile_fields` Lint / Enforcement

Status: **not closed** at this review point.

The deterministic artifact policy defines `_volatile_fields`, but enforcement
must prevent critical proof fields from being marked volatile.

Required closure signal:

```text
lint rejects _volatile_fields containing status, checks, verdict, or boolean
check fields in committed experiments/*/out/*.json artifacts.
```

The lint should be included in the regression matrix or an equivalent
pre-authorization command set.

---

## Additional Pre-Authorization Requirements

These are not new runtime scopes; they are evidence required before a later
implementation authorization decision.

1. **Full artifact stability survey** across committed
   `experiments/*/out/*.json` and `.jsonl` artifacts not already verified by
   `deterministic-regression-artifact-policy-v0`.

2. **Post-R26 regression rerun** after deterministic artifact lint/survey and
   any design amendments land.

3. **Design amendment or addendum** to `phase1-production-durable-audit-v0`
   capturing the four pressure-derived blockers above so implementation agents
   do not need to infer them from discussions.

4. **Updated pressure review** confirming the blocker package is closed and that
   implementation scope remains non-Ledger, non-Phase-2, non-BiHistory,
   non-stream/OLAP, non-cache, and non-write/replay/compact/subscribe.

---

## Held Implementation Scope

If a later decision authorizes implementation, the likely bounded implementation
surface will be limited to:

- production audit record schema validation;
- signer abstraction contract and validation proof;
- append-only audit store interface proof;
- restart rebuild proof;
- format-version enforcement proof;
- audit traversal proof;
- audit reader/appender role boundary proof;
- excluded-surface regression proof;
- regression matrix rerun.

This list is a planning hint, not authorization.

---

## Explicit Non-Authorization

This decision does not authorize:

- implementation of production durable audit;
- production deployment;
- production signing execution or key management;
- selecting or onboarding a concrete HSM/KMS provider;
- registry implementation;
- RuntimeMachine binding;
- Ledger adapter or package binding;
- Phase 2;
- Ledger reads, writes, replay, compact, subscribe;
- BiHistory or transaction-time reads;
- stream / OLAP production executors;
- production cache;
- broadening `gate3_authorized: true`.

The signed Gate 3 Phase 1 live-read addendum remains unchanged.

---

## Handoff

```text
Card: S3-R27-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: phase1-production-durable-audit-implementation-authorization-review-v0
Status: hold-before-implementation-authorization

[D] Decision
- Hold implementation authorization.
- phase1-production-durable-audit-v0 is review-ready as design, not authorized
  for implementation.
- Gate 3 signed Phase 1 scope remains unchanged.

[Blockers before authorization]
1. compliance_posture.production_durable_audit bound to approved production
   store identity and verification, not caller assertion.
2. production signer injection rejects nil/no-op/stub/local-test signers and
   requires trusted key identity + verification metadata.
3. startup_time registry freshness has a maximum staleness bound and fail-closed
   behavior.
4. _volatile_fields lint rejects status/checks/verdict/boolean check fields.
5. full artifact stability survey completed.
6. post-R26 regression rerun completed after blocker fixes.
7. design amendment records these requirements in the durable audit track.
8. pressure review confirms no scope widening.

[X] Still closed
- implementation, production deploy, production signing execution/key
  management, concrete HSM/KMS onboarding, registry implementation,
  RuntimeMachine binding, Ledger, Phase 2, BiHistory, stream/OLAP, production
  cache, writes/replay/compact/subscribe.
```
