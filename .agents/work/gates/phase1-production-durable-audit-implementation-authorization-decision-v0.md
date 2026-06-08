# Phase 1 Production Durable Audit Implementation Authorization Decision v0

Card: S3-R30-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: `production-durable-audit-implementation-authorization-decision-v0`
Date: 2026-05-10
Status: approved-bounded-implementation

---

## Decision

Decision: **authorize a bounded Phase 1 production durable audit implementation
track**.

The R28/R29 evidence package closes the blockers from
`phase1-production-durable-audit-implementation-authorization-review-v0`.
Implementation may now begin only inside the bounded surface defined in this
document.

This decision authorizes implementation of production-durable-audit mechanics
and conformance proofs. It does **not** authorize production deployment, concrete
HSM/KMS onboarding, Ledger binding, Phase 2, BiHistory, stream/OLAP production
executors, production cache, broad RuntimeMachine binding, or any write/replay/
compact/subscribe surface outside the audit append scope below.

Safe status phrase:

```text
Phase 1 production durable audit implementation is authorized as a bounded
implementation track. Production deployment and all excluded surfaces remain
closed until a later Architect decision explicitly opens them.
```

Authority ref:

```text
architect-supervisor://igniter-lang/gates/phase1-production-durable-audit/bounded-implementation-v0/2026-05-10
```

---

## Reviewed Inputs

- `igniter-lang/docs/gates/phase1-production-durable-audit-implementation-authorization-review-v0.md`
- `igniter-lang/docs/tracks/production-durable-audit-blocker-amendment-and-validation-proofs-v0.md`
- `igniter-lang/docs/tracks/post-r27-regression-matrix-with-volatile-lint-v0.md`
- `igniter-lang/docs/tracks/startup-time-freshness-override-interface-v0.md`
- `igniter-lang/docs/discussions/r29-authorization-and-canon-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round29-status-curation-v0.md`

---

## Blocker Closure Review

| Prior blocker | Closure evidence | Decision |
|---------------|------------------|----------|
| 1. `compliance_posture.production_durable_audit` store-bound and verification-bound | R28 compliance posture proof `14/14 PASS`; evaluator is sole source; caller claims ignored; proof-local stores blocked | Closed |
| 2. Production signer rejects nil/no-op/stub/local-test signers | R28 signer validation proof `18/18 PASS`; reason-coded refusals; valid KMS-like identity accepted in proof | Closed |
| 3. `startup_time` freshness bound + fail-closed | R28 24h bound + fail-closed amendment; R29 authority-signed override design removes ambient env/config value leak | Closed for authorization; R30 proof-local validator remains required inside implementation track |
| 4. `_volatile_fields` lint | R27 lint PASS; R28 matrix runs lint first | Closed |
| 5. Full artifact stability survey | R27 survey complete; R28 matrix confirms volatile handling | Closed |
| 6. Post-R27/R28 regression rerun | R28 final sequential matrix `29/29 PASS` | Closed |
| 7. Design amendment records blockers 1-3 | R28 blocker amendment track landed | Closed |
| 8. Updated pressure review confirms closure and scope containment | R29 pressure review: PROCEED; no scope widening; no new blocking condition visible | Closed |

All pre-authorization blockers are closed enough to authorize the bounded
implementation track.

---

## Authorized Implementation Scope

The implementation track may implement and prove only the following surfaces.

### 1. Audit record schema validation

Authorized:

- canonical production durable audit record schema;
- required `format_version` enforcement;
- required identity fields: `storage_identity`, `sequence`, `previous_hash`,
  `record_hash`, timestamp fields, signing metadata, compliance posture;
- refusal when required fields are missing, malformed, or version-incompatible.

Required proof:

```text
valid record accepted;
missing required field refused;
unknown format_version refused;
record_hash recomputation mismatch refused;
volatile or caller-injected compliance posture refused.
```

### 2. Signer abstraction contract proof

Authorized:

- signer interface/abstraction;
- production configuration validation against nil/no-op/stub/local/test/dev
  identities;
- verification metadata shape;
- proof-local signer implementation for conformance only.

Not authorized:

- real HSM/KMS provider onboarding;
- production key issuance;
- production signing execution.

Required proof:

```text
nil/no-op/stub/local/test signer refused;
valid proof-local production-shaped signer accepted only with trusted metadata;
all refusals carry audit.signer.* reason codes.
```

### 3. Append-only production audit store interface proof

Authorized:

- append-only audit store interface;
- production audit store identity shape;
- non-Ledger storage interface for audit records;
- sequence monotonicity and previous-hash chaining;
- refusal on mutation, overwrite, missing predecessor, or hash mismatch.

Not authorized:

- Ledger adapter;
- Ledger writes/replay/compact/subscribe;
- general-purpose persistence API.

Required proof:

```text
append produces sequence and hash chain;
overwrite/update/delete refused;
out-of-order append refused;
Ledger-bound storage_identity refused in Phase 1.
```

### 4. Restart rebuild proof

Authorized:

- replay/rebuild of audit state from the append-only audit log only;
- recomputation of chain verification and compliance posture;
- detection of truncation, tampering, missing sequence, and bad hash.

Not authorized:

- Ledger replay;
- general runtime event replay;
- production recovery daemon.

Required proof:

```text
clean restart rebuild succeeds;
tampered record fails;
missing sequence fails;
truncated chain reports bounded status;
recomputed compliance posture matches source identity and verification status.
```

### 5. Startup freshness policy validator

Authorized:

- proof-local validator for the R29 authority-signed startup freshness override
  interface;
- default 24h bound;
- manifest policy ref + content hash;
- bundled signed policy document;
- refusal codes from R29 design.

Required design tightening before or during implementation:

- decide whether all non-default freshness policies require `expires_at`, not
  only policies looser than 24h;
- define accepted/rejected proof-local authority fixture patterns.

Not authorized:

- online lookup;
- production authority registry implementation;
- mutable env/config freshness seconds.

Required proof:

```text
default accepted;
valid signed tighter policy accepted;
valid signed looser policy accepted only within range and with required reason/expiry;
hash mismatch, missing signature, invalid authority, expired policy, non-integer bound,
out-of-range bound, stale registry, invalid anchor refused.
```

### 6. Audit traversal / reader proof

Authorized:

- read-only audit traversal interface;
- filtered traversal by sequence range, record kind, and verification status;
- reader role separation from appender role.

Not authorized:

- broad query engine;
- production analytics/OLAP;
- stream subscription.

Required proof:

```text
reader can traverse verified append-only audit chain;
reader cannot append;
appender cannot bypass validation;
invalid role receives explicit refusal.
```

### 7. Appender / reader role boundary proof

Authorized:

- role boundary model for audit appender and audit reader;
- proof-local permission checks;
- reason-coded refusals.

Required proof:

```text
appender-only operation succeeds for append;
reader append refused;
appender traversal beyond allowed surface refused or explicitly constrained;
unknown role refused.
```

### 8. Excluded-surface regression proof

Authorized:

- regression fixture proving excluded surfaces remain closed after the durable
  audit implementation lands.

Must prove closed:

- Ledger adapter;
- Phase 2;
- BiHistory;
- stream/OLAP production executor;
- production cache;
- broad RuntimeMachine binding;
- production deployment;
- concrete HSM/KMS onboarding;
- writes/replay/compact/subscribe outside the audit append interface.

### 9. Post-implementation regression matrix

Authorized:

- full regression rerun after implementation;
- `volatile_fields_lint` first;
- include all new durable-audit implementation proofs.

Required result before any later deployment decision:

```text
all existing matrix commands PASS;
all new durable-audit proofs PASS;
no unclassified generated artifact drift.
```

---

## Required Implementation Rules

1. **Fail closed by default.** Any missing, malformed, unsigned, untrusted,
   stale, or unverifiable production-audit input refuses the production audit
   surface.

2. **Proof-local does not mean production-deployed.** Proof-local signers,
   authority fixtures, and audit stores may exist only to prove the interface
   contract. They must not be represented as production deployment.

3. **No caller assertion of compliance posture.** `production_durable_audit`
   remains derived from storage identity + chain verification + signature
   verification.

4. **No silent fallback to weaker policy.** Invalid freshness override policy
   never falls back to a looser bound.

5. **Every refusal is observable.** Refusals must carry stable reason codes
   suitable for audit and regression proofs.

6. **Keep implementation surfaces narrow.** Any need for Ledger, real key
   management, production registry, RuntimeMachine binding, or broader query
   behavior must route back to Architect review.

---

## Explicit Non-Authorization

This decision does not authorize:

- production deployment;
- production signing execution or key management;
- selecting or onboarding a concrete HSM/KMS provider;
- production authority registry implementation;
- broad RuntimeMachine binding;
- Ledger adapter or package binding;
- Phase 2;
- Ledger reads, writes, replay, compact, subscribe;
- BiHistory or transaction-time reads;
- stream / OLAP production executors;
- production cache;
- general-purpose write/replay/compact/subscribe APIs;
- broadening `gate3_authorized: true`;
- changing the signed Gate 3 Phase 1 live-read scope.

---

## Review After Implementation

After the bounded implementation track lands, a follow-up Architect review is
required before production deployment or broader binding.

That review must read:

- the implementation track document;
- all new proof outputs;
- the post-implementation regression matrix;
- an External Pressure Reviewer discussion confirming no excluded surface opened.

Only that later decision may authorize production deployment or any broader
production integration.

---

## Handoff

```text
Card: S3-R30-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: production-durable-audit-implementation-authorization-decision-v0
Status: approved-bounded-implementation

[D] Decision
- Authorize bounded Phase 1 production durable audit implementation track.
- Prior blockers 1-8 are closed enough for implementation authorization.
- Authorization is proof-first and implementation-bounded; deployment remains closed.

[Authorized]
- audit record schema validation
- signer abstraction contract proof
- append-only production audit store interface proof
- restart rebuild proof
- startup freshness policy validator
- format_version enforcement proof
- audit traversal/reader proof
- appender/reader role boundary proof
- excluded-surface regression proof
- post-implementation regression matrix

[Required tightening]
- decide whether all non-default freshness policies require expires_at
- define accepted/rejected proof-local freshness authority fixture patterns

[Still closed]
- production deployment
- concrete HSM/KMS onboarding
- production signing execution/key management
- production authority registry implementation
- broad RuntimeMachine binding
- Ledger adapter / Phase 2
- BiHistory
- stream/OLAP production executor
- production cache
- general write/replay/compact/subscribe
- broader gate3_authorized surface
```
