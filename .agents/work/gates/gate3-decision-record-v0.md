# Gate 3 Decision Record: Runtime TEMPORAL Executor v0

Card: S3-R13-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: `gate3-architect-decision-record-v0`
Date: 2026-05-09
Status: approved-restricted-phase1

---

## Decision

The revised restricted Gate 3 request is **approved with restrictions**.

This decision opens Gate 3 only for the Phase 1 surface described below:

```text
TEMPORAL History[T] valid_time evaluation
via the abstract TBackend read interface
using a proof-local or non-Ledger adapter
with no Ledger package binding
```

This decision does not authorize immediate live reads. Phase 1 implementation
may begin, but any read attempt remains blocked until the pre-live conditions
in this document are satisfied.

Safe status phrase:

```text
Gate 3 is approved-restricted for Phase 1 implementation.
Gate 3 is not open for Ledger, BiHistory, stream, OLAP, writes, replay,
compact, subscribe, production cache, or concrete adapter binding.
```

---

## Reviewed Inputs

- `docs/gates/runtime-temporal-executor-gate3-request-v0.md`
- `docs/tracks/runtime-temporal-executor-gate3-request-revision-v0.md`
- `docs/tracks/gate3-request-revision-spec-review-v0.md`
- `docs/tracks/gate3-regression-proof-chain-index-v0.md`
- `docs/tracks/gate3-tbackend-adapter-phase-plan-v0.md`
- `docs/tracks/stage3-round12-status-curation-v0.md`
- `docs/discussions/gate3-request-revision-safety-pressure-v0.md`

The S3-R12 request revision closed the S3-R11-X1 HOLD conditions:

- authority ref is a gate-opening precondition;
- AT-10 live-read observation emission is unconditional;
- AT-12 CORE artifact refusal is explicit;
- Q3 Phase 1 / Phase 2 boundary is explicit;
- proof-chain index exists;
- review and pressure docs say the request is ready for Architect review.

---

## Authorized Scope

This decision authorizes:

| Surface | Authorization |
|---------|---------------|
| `TemporalExecutor` implementation | Allowed for `History[T]` valid_time only |
| RuntimeMachine binding | Allowed only for the restricted TEMPORAL Phase 1 path |
| Abstract TBackend call | Allowed only through a proof-local/non-Ledger adapter |
| `read_as_of` / `history_read` | Allowed only for one valid_time coordinate |
| `runtime_enforced: true` | Allowed only for the authorized Phase 1 CompatibilityReport path |
| ExecutorApprovalToken validation | Required before any executor/backend/cache path |
| TEMPORAL cache-key schema validation | Required before any cache or backend path |
| Observation emission | Required for every authorized read attempt |

The implementation must preserve the existing load-for-inspection behavior:
valid TEMPORAL artifacts may load for inspection, but evaluation stays blocked
unless the Phase 1 pre-live conditions are satisfied.

---

## Explicit Exclusions

This decision does not authorize:

| Surface | State |
|---------|-------|
| Real Ledger-backed TBackend adapter | Closed until Phase 2 Architect addendum |
| Any Ledger package read through package code | Closed until Phase 2 Architect addendum |
| Ledger write / append / replay / compact | Closed; separate gate required |
| Ledger subscribe / changefeed / stream binding | Closed; separate gate required |
| `BiHistory[T]` live evaluation | Closed; separate gate required |
| `bihistory_at`, transaction-time read, `at(vt:, tt:)` | Closed; separate gate required |
| Stream executor | Closed; separate gate required |
| OLAP executor | Closed; separate gate required |
| Invariant executor persistence | Closed; separate gate/track required |
| Production RuntimeMachine memoization/cache | Closed; separate gate required |
| Parser coordinate syntax | Not a gate concern; proposal/proof required |
| MCP or mesh temporal routing | Closed; future mesh gate |

No excluded surface may be inferred from the words "Gate 3 approved".

---

## Authority Registry

### Authority Ref

The trusted authority ref for Phase 1 ExecutorApprovalToken validation is:

```text
authority_ref: architect-supervisor://igniter-lang/gates/gate3/runtime-temporal-executor/restricted-history-valid-time-v0/2026-05-09
```

### Authority Format

The authority format is a gate-decision URI with these components:

```text
scheme: architect-supervisor
domain: igniter-lang
gate: gate3
subject: runtime-temporal-executor
scope: restricted-history-valid-time-v0
issued_on: 2026-05-09
```

For Phase 1, a token is trusted only when:

- `authority_ref` exactly matches the URI above;
- `gate` is `gate3`;
- `required_capability` is `history_read`;
- `scope` is restricted to `History[T] valid_time`;
- `artifact_ref` and `contract_ref` match the artifact being evaluated;
- the token is not expired or revoked;
- the runtime also verifies Gate 3 state and scope before any read.

Proof-local deterministic signatures may be used only in proof fixtures. They
must not be treated as a production signing scheme.

### Issuance Rule

Phase 1 tokens may be issued only by an implementation or proof harness that
explicitly references this decision record and the exact `authority_ref` above.
Tokens are not self-issued by `.igapp` artifacts, contracts, RuntimeMachine, or
TBackend adapters.

For Phase 1 proof-local and MemoryBackend implementations, the trusted
authority URI may be embedded as a constant in the executor implementation,
referencing this document directly. This is a Phase 1 convenience, not a
production signing system.

Any later production signing key, hash registry, or deployment policy file
requires a named follow-up record or addendum.

### Revocation Rule

The authority ref is active until one of the following exists:

- a later gate decision record supersedes this decision;
- a `gate3-revocation-*` document names this `authority_ref`;
- the runtime authority registry marks the ref as revoked;
- the token itself is expired or revoked.

Runtime validation must treat revocation as an independent refusal condition.

The runtime authority registry is not yet defined. For Phase 1, the active
revocation paths are:

- a later gate decision record superseding this decision;
- a `gate3-revocation-*` document naming this `authority_ref`;
- token expiry or token-local revocation.

A runtime authority registry requires a separate definition track before Phase
2 or production authority-revocation work.

---

## Architect Decisions On Open Questions

### Q1: Token Authority Registry

Decision: use the authority ref recorded in this document as the Phase 1 trust
anchor.

This is sufficient for restricted Phase 1 implementation and proof-local
runtime enforcement. It is not a general production signing system.

### Q2: BiHistory Exclusion Scope

Decision: `BiHistory[T]` is excluded from this Gate 3 opening.

BiHistory requires a separate gate request after physical `at(vt:, tt:)`
serving proof lands. It cannot be added to Phase 1 or Phase 2 by quiet addendum.

### Q3: TBackend Adapter Scope

Decision: approve Option C.

```text
Phase 1: proof-local or non-Ledger adapter only.
Phase 2: real Ledger-backed adapter only after explicit Architect addendum.
```

The Phase 2 addendum must name:

- adapter identity and package/class boundary;
- descriptor hash or registry hash expected at binding time;
- operation scope: `History[T] valid_time read only`;
- approval token scope;
- observation emission shape;
- persistence gap handling;
- refusal cases for writes/replay/compact/subscribe/stream/BiHistory.

### Q4: Production Cache Scope

Decision: production cache is deferred.

Gate 3 Phase 1 may validate TEMPORAL cache-key schema and refuse CORE-shaped
keys, but it must not introduce production RuntimeMachine memoization or a
production cache store.

### Q5: Audit Observation Per Live Read

Decision: required.

Every authorized Phase 1 read attempt must emit a structured observation.
Observation emission is unconditional. Observation persistence remains
proof-local until a later persistence/audit track closes that gap.

### Q6: Executor Refusal For CORE Contracts

Decision: required.

The TEMPORAL executor must inspect `fragment_class` for every artifact. CORE,
STREAM, OLAP, BiHistory, or unknown/out-of-scope artifacts must refuse before
evaluation or backend access.

---

## Pre-Live Conditions

Phase 1 implementation may begin after this decision. However, no Phase 1 read
may execute until all of these conditions are satisfied:

1. `compatibility-report-composition-v0` lands and defines a single composed
   production CompatibilityReport path.
2. `prop-005-temporal-read-observation-v0` lands and defines the minimum
   temporal read observation envelope.
3. `prop-030-temporal-scope-exclusion-errata-v0` lands and defines the
   canonical refusal reason for out-of-scope temporal artifacts.
4. AT-1 through AT-12 from the Gate 3 request are implemented and verified.
5. The S3-R7 through S3-R10 regression proof chain remains PASS after
   implementation changes.

Until these conditions are true, RuntimeMachine must continue to refuse
TEMPORAL evaluation.

---

## Acceptance Surface

The production implementation must satisfy AT-1 through AT-12 from the Gate 3
request without weakening them.

Additional Architect clarifications:

- `runtime_enforced: true` is allowed only for this restricted Phase 1 path.
- `runtime_enforced: true` must not imply Ledger authorization.
- Gate state, token validity, scope, and cache-key schema are separate checks.
- A valid token with wrong gate, wrong scope, wrong artifact, wrong contract,
  expired state, revoked state, missing evidence, or out-of-scope fragment must
  refuse before executor/cache/backend work.
- Observation emission is part of the read boundary, not an optional logging
  feature.

---

## Decision Result

```text
Gate 3 request: approved-restricted
Gate 3 phase: Phase 1 implementation authorized
Phase 1 live reads: blocked until pre-live conditions pass
Phase 2 Ledger adapter: closed until Architect addendum
BiHistory: closed; separate gate required
Production cache: closed; separate gate required
```

---

## Handoff

```text
Card: S3-R13-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: gate3-architect-decision-record-v0
Status: done

[D] Decisions
- Approved restricted Gate 3 for Phase 1 implementation only.
- Authority ref recorded:
  architect-supervisor://igniter-lang/gates/gate3/runtime-temporal-executor/restricted-history-valid-time-v0/2026-05-09
- Q2: BiHistory excluded; separate gate required.
- Q3: Option C approved.
- Q4: production cache deferred.
- Q5: observation emission required.
- Q6: out-of-scope artifact refusal required.

[S] Scope
- Phase 1 may implement TemporalExecutor + abstract TBackend History[T]
  valid_time path against proof-local/non-Ledger adapter.
- No Phase 1 read may execute until pre-live conditions land.
- Phase 2 Ledger adapter requires explicit Architect addendum.

[T] Verification
- Decision record only; no code/proof executed.

[R] Risks / Required next work
- S3-R14-C1-A amendment clarified Phase 1 authority URI embedding and Phase 1
  active revocation paths.
- Run S3-R7..S3-R10 proof chain after implementation changes.
- Define runtime authority registry before Phase 2 / production authority
  revocation work.
- Update gates/status maps in Status Curator mode.
```
