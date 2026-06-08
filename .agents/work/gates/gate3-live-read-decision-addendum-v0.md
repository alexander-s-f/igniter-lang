# Gate 3 Live-Read Decision Addendum v0

Card: S3-R20-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: `gate3-live-read-addendum-signature-review-v0`
Date: 2026-05-09
Status: signed-approved-restricted-phase1-live-read

Original draft: S3-R18-C1-A / `gate3-live-read-decision-addendum-v0`

---

## Decision State

This document is a **signed addendum** for the first restricted Phase 1
non-proof read path.

This addendum authorizes callers to pass `gate3_authorized: true` only for the
restricted Phase 1 surface defined below, and only when the caller references
this signed addendum in invocation evidence.

It does not authorize Ledger, BiHistory, production cache, stream/OLAP, writes,
replay, compact, subscribe, production signing/registry, or durable audit.

Safe status phrase:

```text
Gate 3 live-read addendum is signed-approved for restricted Phase 1 only.
Phase 1 non-proof reads are authorized only within this addendum scope.
Phase 2, Ledger, BiHistory, stream/OLAP, production cache, writes/replay/
compact/subscribe, production signing/registry, and durable audit remain closed.
```

---

## Signature Decision

Decision: **sign / approve restricted Phase 1 live-read addendum**.

Signed by: `[Architect Supervisor / Codex]`

Signed on: `2026-05-09`

Signature review card:

```text
Card: S3-R20-C1-A
Track: gate3-live-read-addendum-signature-review-v0
```

Evidence cited:

- `S3-R19-C1-P`: post-R18 regression rerun **PASS 15/15**;
- `S3-R19-X1-S`: **PROCEED to Architect signature review**;
- `S3-R18-X1-S PS-2`: guard-order amendment applied before signature.

First caller-visible change:

```text
A caller may pass gate3_authorized: true only when the invocation evidence
references this signed addendum and the call remains inside the restricted
Phase 1 scope.
```

The executor behavior is not changed by this signature. The signature changes
the authorization policy boundary only.

---

## Reviewed Inputs

- `docs/gates/gate3-decision-record-v0.md`
- `docs/tracks/stage3-round17-status-curation-v0.md`
- `docs/discussions/runtime-temporal-executor-lib-prep-safety-pressure-v0.md`
- `docs/tracks/phase1-lib-prep-regression-chain-rerun-v0.md`
- `docs/tracks/phase1-r18-cleanup-regression-rerun-v0.md`
- `docs/discussions/gate3-live-read-addendum-pre-signature-pressure-v0.md`
- `docs/tracks/stage3-round19-status-curation-v0.md`

R17 evidence says the lib-prep boundary is green for proof-local Phase 1:

```text
post-C1 regression: PASS 14/14
spec sync: done
safety pressure: PROCEED for proof-local Phase 1
live-read addendum: draftable, not opened
```

R19 evidence closes the pre-signing repair:

```text
post-R18 regression: PASS 15/15
observation.backend_identity_emitted: ok
safety pressure: PROCEED to Architect signature review
guard order: approval_token -> gate_state -> backend_identity -> scope -> cache_key -> executor_backend
```

---

## Signed Authorization Target

This addendum authorizes only this first non-proof Phase 1 surface:

```text
IgniterLang::TemporalExecutor::Phase1
History[T] valid_time read
single explicit as_of coordinate
abstract non-Ledger backend
no durable side effects
no production cache
no Ledger package binding
```

The authorized runtime shape would remain:

```text
approval_token -> gate_state -> backend_identity -> scope -> cache_key -> executor_backend
```

The backend identity guard runs after approval-token and gate-state checks, and
before scope, cache-key, execution kernel, or backend `read_as_of`. All checks
must refuse before backend access when they fail.

---

## Exact Authorization Conditions

This addendum is signed because the conditions below were satisfied and
recorded by evidence tracks. They remain runtime/caller obligations after
signature.

### 1. Allowed Backend Class / Identity

The first non-proof Phase 1 read may use only:

```text
IgniterLang::TemporalExecutor::Phase1::MemoryBackend
```

or a separately named Phase 1 non-Ledger backend identity that satisfies all of
these fields:

```text
gate: gate3
phase: phase1
capability: history_read
history_axis: valid_time
adapter_family: non_ledger
ledger_package: false
durable_storage: false
supports_bihistory: false
supports_stream: false
supports_writes: false
supports_replay: false
supports_compact: false
supports_subscribe: false
```

For this signed addendum, `MemoryBackend` is the preferred and expected allowed
backend. Any other backend identity must be named explicitly in a follow-up
amendment before use.

The executor has a backend identity guard before scope, cache-key, execution
kernel, and backend `read_as_of`. Passing an arbitrary object that responds to
`read_as_of` is not an acceptable non-proof authorization boundary.

### 2. `gate3_authorized` Source

`gate3_authorized: true` may be passed only by a caller that directly references
this signed addendum and records the signed document path or authority event in
its invocation evidence.

The `Phase1` class does not self-authorize. The caller owns the policy step
that decides whether this addendum exists and applies.

For every call outside this signed scope, the only valid default remains:

```ruby
gate3_authorized: false
```

### 3. Authority Ref / Token Handling

The authority ref remains the Gate 3 Phase 1 authority URI from the original
decision record:

```text
architect-supervisor://igniter-lang/gates/gate3/runtime-temporal-executor/restricted-history-valid-time-v0/2026-05-09
```

A token is acceptable only when:

- `authority_ref` exactly matches the URI above;
- `gate` is `gate3`;
- `required_capability` is `history_read`;
- scope is `History[T] valid_time`;
- `artifact_ref` and `contract_ref` match the evaluated artifact and contract;
- the token is not expired or token-revoked;
- the addendum has been signed and not superseded or revoked;
- validation happens before gate state, scope, cache key, and backend access.

This remains a Phase 1 source-code-parity check, not production cryptographic
authorization. Production signing, key rotation, and runtime authority registry
remain closed until separate approval.

### 4. Observation Emission

Every authorized read attempt must emit an observation before returning control
to the caller.

Minimum required observation intent:

```text
event: temporal_live_read_observation
gate: gate3
phase: phase1
capability: history_read
history_axis: valid_time
artifact_ref
contract_ref
authority_ref
as_of
backend_identity
result: allowed | refused
reason
generated_at
```

The current `Phase1#observations` surface is in-memory only. It is not durable,
not an audit receipt, and not proof of long-term compliance. Durable observation
persistence requires a later persistence/audit track.

### 5. Composed CompatibilityReport Requirement

Every evaluation path must produce or consume a composed CompatibilityReport
shape before backend access.

The report must include at minimum:

- artifact identity;
- contract identity;
- `fragment_class`;
- required capability;
- Gate 3 state;
- approval-token validation result;
- scope validation result;
- TEMPORAL cache-key schema validation result;
- backend identity validation result;
- final readiness/refusal status.

The report may be proof-local/minimal for Phase 1, but it must be a single
composed boundary, not scattered boolean checks.

### 6. Regression Requirements

The following proof chain remained green after the R18 cleanup tracks:

```text
S3-R7..S3-R10 base runtime/executor/descriptor chain
S3-R13 CompatibilityReport composition
S3-R13 temporal read observation
S3-R14 runtime report enforcement preflight
S3-R14 temporal scope exclusion fixture
S3-R15 authority_ref proof
S3-R16 Phase1 lib-prep targeted proof
S3-R17 post-C1 regression chain equivalent
Stage 1 close candidate
Stage 2 close candidate
```

The signing evidence is the R19 signal:

```text
S3-R19-C1-P: 15/15 PASS
```

Any follow-up change that touches this boundary must rerun an equivalent proof
chain before widening authorization.

### 7. Reason Code Consistency

Before signing, operator-facing refusal codes for excluded temporal surfaces
must resolve to the canonical code:

```text
runtime.temporal_scope_exclusion
```

Narrow proof-local codes may remain only as internal aliases when they are
mapped to the canonical reason before surfacing to reports, observations, or
operator tooling.

---

## Explicit Exclusions

This signed addendum does not authorize:

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
| Production signing / runtime authority registry | Closed; separate gate or addendum required |
| Durable observation persistence | Closed; separate persistence/audit track required |
| Parser coordinate syntax | Not authorized by this addendum |
| MCP or mesh temporal routing | Closed; future mesh gate |

No excluded surface may be inferred from "live-read addendum signed".

---

## Signature Closure

The pre-signature blockers are closed as follows:

1. `phase1-backend-identity-guard-v0` lands and proves arbitrary
   `read_as_of` objects cannot become authorized backends: **closed by
   S3-R18-C4-P**.
2. `runtime-temporal-scope-exclusion-reason-alias-v0` lands or equivalent
   evidence proves canonical operator-facing reason codes: **closed by
   S3-R18-C3-P**.
3. Proof-local docstrings land for `GATE3_AUTHORITY_REF` and `observations`,
   clarifying source-code-parity authorization and in-memory-only observation:
   **closed by S3-R18-C2-P**.
4. A post-cleanup regression rerun records the current proof chain PASS:
   **closed by S3-R19-C1-P, PASS 15/15**.
5. A safety-pressure review of this addendum returns `PROCEED` or routes only
   non-blocking wording amendments: **closed by S3-R19-X1-S, PROCEED to
   Architect signature review**.
6. `[Architect Supervisor / Codex]` issues an explicit signed addendum or
   updates this document status from `draft-not-signed` to an approved status:
   **closed by S3-R20-C1-A**.

---

## Continuing Non-Authorization

This document opens only the restricted Phase 1 live-read policy boundary named
above. All other surfaces remain closed.

```text
Phase 1 non-proof live reads: authorized only inside signed addendum scope
gate3_authorized: true: allowed only with signed-addendum invocation evidence
Ledger adapter: closed
BiHistory: closed
production cache: closed
production signing: closed
durable audit: closed
```

---

## Handoff

```text
Card: S3-R20-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: gate3-live-read-addendum-signature-review-v0
Status: signed-approved-restricted-phase1-live-read

[D] Decisions
- Signed the first Gate 3 live-read addendum for restricted Phase 1 only.
- The first caller-visible change is policy-only: callers may pass
  `gate3_authorized: true` only when invocation evidence references this signed
  addendum and the call remains inside scope.
- Executor behavior was not changed by this signature.

[S] Scope
- Authorized surface: `IgniterLang::TemporalExecutor::Phase1`,
  `History[T]` valid_time, explicit `as_of`, abstract non-Ledger backend.
- Preferred first allowed backend: `Phase1::MemoryBackend`; arbitrary
  `read_as_of` objects are blocked by identity guard evidence.

[T] Verification
- S3-R19-C1-P: PASS 15/15.
- S3-R19-X1-S: PROCEED to Architect signature review.
- No runtime code changed by S3-R20-C1-A.

[R] Blockers
- Run first post-signature fixture to prove signing changes policy state only,
  not executor behavior.
- Phase 2 Ledger adapter, BiHistory, stream/OLAP, production cache, production
  signing/registry, and durable audit remain separate.
```
