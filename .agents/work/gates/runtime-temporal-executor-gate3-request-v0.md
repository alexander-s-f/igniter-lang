# Gate 3 Opening Request: Runtime TEMPORAL Executor (Restricted Scope) v0

Card: S3-R11-C1-G (revised: S3-R12-C1-S)
Agent: [Igniter-Lang Meta Expert]
Role: meta-expert
Mode: Gate Request Author
Track: `igniter-lang/runtime-temporal-executor-gate3-request-v0`
Date: 2026-05-08 (revised: 2026-05-09)
Status: request — S3-R11-X1 HOLD resolved — ready for Architect review

**This document is a formal request to the Architect Supervisor. It does not
open Gate 3. Only the Architect Supervisor can open Gate 3.**

---

## I. What Is Being Requested

A restricted Gate 3 opening for **live TEMPORAL History[T] evaluation over
valid_time only**.

This means:

- A `TemporalExecutor` may be implemented and bound to `RuntimeMachine`.
- A `TBackend` adapter may be called for `history_read` reads against a
  `read_as_of` time coordinate.
- `CompatibilityReport` transitions from `report_only: true` to a production
  report with `runtime_enforced: true` for the TEMPORAL execution path.
- `ExecutorApprovalToken` must be validated before any live TBackend call is
  attempted.
- Production `RuntimeMachine` checks Gate 3 state, approval token, and
  TEMPORAL cache-key schema independently before evaluating.

Nothing in this request authorizes BiHistory, stream evaluation, OLAP
evaluation, Ledger write/append/replay/compact, production memoization, or
self-issued approval tokens.

---

## II. Evidence Summary (S3-R7 → S3-R10)

All evidence below is proof-local. It demonstrates the required boundary
semantics without enabling live operations.

### S3-R7: Load Boundary Established

| Track | Verdict | Signal |
|-------|---------|--------|
| `runtime-compatibility-report-temporal-load-check-v0` | PASS | `load_accept_evaluate_refuse` proven; load is inspection-only; evaluate is blocked |

Evaluation readiness depends on: required capabilities present + live TBackend
binding + temporal executor + explicit approval + Gate 3 authorized + artifact
`guard_policy` allows evaluation.

### S3-R8: Positive Executor Flags Are Insufficient

| Track | Verdict | Signal |
|-------|---------|--------|
| `runtime-compatibility-report-executor-boundary-v0` | PASS | Runtime profiles with `temporal_executor: true` + `live_tbackend_binding: true` still block; missing explicit approval blocks before executor, TBackend, or cache |

Key proof: even a claimed executor + live binding still produces
`executor_approval_missing` without an explicit `ExecutorApprovalToken`.

### S3-R9: Approval Token Shape + Cache Key Contract

| Track | Verdict | Signal |
|-------|---------|--------|
| `prop-030-executor-approval-token-contract-v0` | docs-only | `ExecutorApprovalToken` shape formalized; PROP-030 authored; Gate 3 still closed |
| `executor-boundary-cache-key-contract-v0` | PASS | CORE-shaped key for TEMPORAL refused with L-T5; silent staleness prevented |

Key proof: History `same inputs + different as_of` produces different TEMPORAL
keys and identical CORE keys. CORE key for TEMPORAL is semantic corruption, not
a cache detail.

### S3-R10: Validation Matrix + Enforcement Proof

| Track | Verdict | Signal |
|-------|---------|--------|
| `executor-approval-token-report-proof-v0` | PASS | 13-case token validation matrix PASS; valid token with Gate 3 closed = `temporal_gate3_closed` not approval error |
| `guarded-runtime-executor-approval-enforcement-v0` | PASS | `GuardedRuntimeMachine` enforces missing token, Gate 3 closed, bad TEMPORAL cache key; History and BiHistory load-for-inspection preserved; no live ops attempted |

Key proofs:
- Approval is necessary but insufficient: valid token + Gate 3 closed → still
  blocked at `temporal_gate3_closed`.
- Gate 3 and approval are independent checks; both must pass.
- CORE-shaped cache key refusal (L-T5) is enforced at the executor boundary
  before any cache lookup or TBackend access.

---

## III. Decision Table

### Authorize (if Architect approves Gate 3)

| Item | Scope | Condition |
|------|-------|-----------|
| `TemporalExecutor` implementation | History[T] valid_time read only | Production code; proof-local executor also acceptable as first implementation |
| TBackend `read_as_of(as_of: DateTime)` call | History[T] only | `history_read` capability; Architect-trusted TBackend adapter only |
| `runtime_enforced: true` in CompatibilityReport | TEMPORAL History path only | Must not be set for paths not authorized by this gate |
| `ExecutorApprovalToken` production validation | Architect-signed token required | Cannot use proof-local deterministic hash in production |
| Gate 3 state check in `RuntimeMachine` | Independent of token presence | Token presence does not replace Gate 3 check |
| TEMPORAL cache-key enforcement at executor boundary | L-T5 before cache/TBackend | Must precede every cache lookup and TBackend call |

### Exclude (not authorized by this request)

| Item | Reason |
|------|--------|
| `BiHistory[T]` / bitemporal evaluation | Physical `at(vt:, tt:)` serving proof has not landed; cannot authorize two-axis live eval |
| Stream executor | No stream executor proof; ESCAPE/stream surface separate from TEMPORAL lane |
| OLAP executor | No executor proof; OLAP is separate language surface |
| Ledger `append` / `write` / `replay` / `compact` | Gate 3 has never authorized Ledger write operations; separate gate decision required |
| Production RuntimeMachine memoization / cache | Proof-local only (S3-R3-C3, S3-R4-C5); production cache is a separate authorization |
| Self-issued `ExecutorApprovalToken` | Tokens not backed by Architect recorded decision are invalid; authority registry must be Architect-controlled |
| Ledger-backed TBackend adapter (real Ledger reads — Phase 2) | `history_read` via the **abstract** TBackend interface is authorized (Q3 scope). A real Ledger-backed adapter requires a Phase 2 Architect addendum to the gate decision record before binding. The abstract interface authorization does not implicitly authorize any concrete adapter. |

### Scope Boundary

Gate 3 approval authorizes only the items listed in **Authorize** above. All
items listed in **Exclude** remain closed after gate opening. A separate gate
request (or a named Architect addendum to the gate decision record, where
explicitly permitted by this document) is required for each excluded surface.
This approval does not create a precedent for adjacent scope. "Gate 3 is
open" does not mean TEMPORAL evaluation as a whole is live — it means
exactly the authorized items above are live, under exactly the conditions
stated in **Require** and **AT-1 through AT-12**.

### Require (before any live eval is attempted)

| Condition | Where checked | Evidence reference |
|-----------|--------------|-------------------|
| `runtime_enforced: true` set explicitly | CompatibilityReport | R7 load check; R8 executor boundary |
| CompatibilityReport is a single composed production report | CompatibilityReport | R8 boundary; must not split report/enforcement. Reference shape: pending track `compatibility-report-composition-v0` (not yet landed; must land before any live eval proceeds) |
| `RuntimeMachine` checks readiness before executor/cache/TBackend | Production RuntimeMachine | R10 guarded enforcement proof |
| `ExecutorApprovalToken` validated (all PROP-030 fields) | RuntimeMachine / CompatibilityReport | R10 token proof; 13-case matrix |
| Gate 3 state checked independently of token | RuntimeMachine | PROP-030 §7; R10 proof |
| TEMPORAL cache-key schema checked before any cache or backend | Executor boundary | R9 cache key contract; L-T5 |
| Trusted authority registry defined by Architect | ExecutorApprovalToken | PROP-030 §3; Q1 below — must be recorded in gate decision document |
| Audit observation emitted per live read (unconditional) | TemporalExecutor | AT-10; Q5 is closed (required, not optional) |

### Defer (not in this request; future gate or separate decision)

| Item | Defer to |
|------|----------|
| BiHistory[T] live evaluation | Separate gate request after physical `at(vt:, tt:)` serving proof |
| Production RuntimeMachine cache | Separate production cache gate decision |
| Ledger write/append/replay | Separate gate decision; write is a higher-risk boundary than read |
| Stream / OLAP / invariant executor | Respective language surface gates |
| MCP / mesh temporal routing | Future mesh gate |
| Parser coordinate syntax for temporal reads | Future PROP-029+ proposal |
| CompatibilityReport persistence and audit receipts | `compatibility-report-persistence-audit-v0` track (not yet landed) |

---

## IV. Open Decisions — Architect Must Approve or Reject

These questions cannot be resolved by agents. Each requires an explicit
Architect decision before production executor work begins.

**Q1 — Token authority registry**

PROP-030 specifies `authority_ref` pointing to a recorded Architect decision.
Who owns the trust anchor? Is it:

- A specific key or hash recorded in `docs/gates/` alongside this document?
- A runtime config field that carries the authority ref at startup?
- A per-deployment policy file baked into the `.igapp/` requirements?

Decision required: authority source, format, and revocation mechanism.

**Q2 — BiHistory exclusion scope**

Is BiHistory[T] excluded from this Gate 3 opening permanently (requires new
gate) or temporarily (included once `at(vt:, tt:)` serving proof lands, within
this gate)?

Decision required: permanent exclusion requiring a separate gate, or deferred
inclusion within Gate 3.

**Q3 — TBackend adapter scope** *(recommendation: Option C)*

The requested authorization is `history_read` reads only via the abstract
TBackend interface. Acceptable TBackend adapters for a first implementation:

- Option A: proof-local `MemoryBackend` with `read_as_of` (minimal; no network)
- Option B: real external TBackend adapter for target store (maximum; requires
  integration and a Phase 2 addendum — see below)
- Option C (recommended): two-phase binding
  - **Phase 1:** `runtime_enforced: true` with proof-local `MemoryBackend`.
    Satisfies AT-1 through AT-12 on the proof surface. Authorized on gate
    opening; no additional approval required.
  - **Phase 2:** real adapter binding (e.g. Igniter-Ledger TBackend). Requires
    a named Architect addendum to the gate decision record before binding. The
    addendum must record: adapter identity, audit trail mechanism, and
    observation persistence plan. A new gate is not required, but Phase 2
    does not begin without the addendum.

Decision required: minimum viable adapter for Gate 3 initial implementation.

**Q4 — Production cache scope**

Is production memoization of TEMPORAL History reads in scope for this opening
or deferred?

Arguments for in-scope: cache key contract is proven (R9); freshness states
are defined; TEMPORAL key schema prevents silent staleness.

Arguments for deferral: no production cache store is implemented; cache
invalidation on TBackend state change is unproven; separate gate is cleaner.

Decision required: include production cache in Gate 3 or keep deferred.

**Q5 — Audit observation per live read** *(closed)*

Closed decision: every authorized `read_as_of` call must emit a structured
observation record. This is not optional. Observation emission is an
unconditional production requirement (AT-10). Observation persistence is
proof-local until the invariant persistence gap closes; the emission
requirement is not conditional on persistence readiness. The observation
kind for a live temporal read is not yet formally registered; the
implementer must use the closest available PROP-005 envelope kind and note
the gap in the implementation record.

**Q6 — Executor refusal for CORE contracts** *(closed as AT-12)*

Closed decision: the TEMPORAL executor must check `fragment_class` on every
incoming artifact and refuse CORE artifacts before evaluation. This is
unconditional and is captured as a production acceptance condition AT-12.
No open decision remains.

---

## V. Production Acceptance Checklist

When Architect approves Gate 3 (restricted), the implementation must satisfy
all of the following conditions before any live TEMPORAL read is attempted.
AT-1 through AT-12 are the complete acceptance surface; none may be deferred:

```text
AT-1  CompatibilityReport transitions from report_only:true to runtime_enforced:true
      for the TEMPORAL execution path. This must be set explicitly, not inferred.

AT-2  CompatibilityReport is composed as a single production report, not as two
      separate report-only and enforcement objects.

AT-3  RuntimeMachine checks evaluation_readiness from CompatibilityReport before
      executor, cache, or TBackend entry. Runtime does not call executor when
      evaluation_readiness is blocked.

AT-4  ExecutorApprovalToken is validated against all PROP-030 fields:
        kind, version, gate, scope, artifact_ref, contract_ref,
        required_capability, authority_ref, expiry, revocation, evidence_ref.
      Malformed, missing, expired, revoked, wrong-gate, wrong-scope, or
      wrong-artifact tokens refuse before any TBackend call.

AT-5  Gate 3 state is checked independently of token presence. A valid token
      with Gate 3 closed must still refuse with runtime.temporal_gate3_closed.

AT-6  TEMPORAL cache-key schema is checked at the executor boundary before any
      cache lookup or TBackend access. A CORE-shaped key for a TEMPORAL contract
      is refused with L-T5 (runtime.temporal_cache_schema_mismatch) before the
      read is attempted.

AT-7  No live BiHistory[T] evaluation is performed. If a BiHistory artifact
      reaches the executor, it must be refused with a gate-scope-exclusion refusal.

AT-8  No Ledger write, append, replay, or compact operation is called from the
      TEMPORAL executor path.

AT-9  The trusted authority for ExecutorApprovalToken is recorded in the
      Architect decision document. Proof-local deterministic hash signatures must
      not be used in production token validation.

AT-10 Every authorized live History[T] read emits a structured observation
      record. Runtime does not silently consume TBackend reads. Observation
      emission is unconditional; it is not gated on any separate Architect
      decision. (Q5 is closed: audit observation is required for every live
      temporal read. Observation persistence is proof-local until the
      invariant persistence gap closes; persistence readiness does not
      affect the emission requirement.)

AT-11 Stage 1 regression PASS. Stage 2 regression PASS. All existing proofs
      pass after executor implementation lands. Gate 3 regression surface:
      the S3-R7 through S3-R10 proof chain must remain PASS after any
      executor implementation change:
        - runtime-compatibility-report-temporal-load-check-v0 (S3-R7)
        - runtime-compatibility-report-executor-boundary-v0 (S3-R8)
        - prop-030-executor-approval-token-contract-v0 (S3-R9)
        - executor-boundary-cache-key-contract-v0 (S3-R9)
        - executor-approval-token-report-proof-v0 (S3-R10)
        - guarded-runtime-executor-approval-enforcement-v0 (S3-R10)

AT-12 TEMPORAL executor checks `fragment_class` on every incoming artifact
      and refuses CORE artifacts with a gate-scope-exclusion refusal before
      any evaluation. A CORE contract reaching the executor with Gate 3 open
      must not be evaluated; it must be refused with a named refusal reason.
```

---

## VI. Recommendation

**Approve restricted Gate 3** with the following conditions:

1. **Authority ref must be present in the gate decision record.** Gate 3 is
   not open until the decision document exists and includes: the trusted
   authority ref for `ExecutorApprovalToken`, the authority format (key, hash,
   or config binding), the issuance process, and the revocation mechanism. A
   gate decision that defers the authority ref to a subsequent PROP-030 errata
   document does not open Gate 3.
2. BiHistory is explicitly deferred (Q2 = separate gate required).
3. TBackend adapter scope defaults to Option C:
   - **Phase 1:** `runtime_enforced: true` with proof-local `MemoryBackend`
     and `read_as_of`. Satisfies AT-1 through AT-12 on the proof surface.
     May proceed immediately on gate opening.
   - **Phase 2:** real adapter binding (e.g., Igniter-Ledger TBackend).
     Requires a named Architect sign-off — a short addendum to the gate
     decision record is sufficient; a new gate is not required. Phase 2
     does not begin before that addendum is recorded.
4. Production cache is deferred (Q4 = not in this opening).
5. Every live read must emit a structured observation record (Q5 = required,
   not optional). Observation persistence is proof-local until the invariant
   persistence gap closes; the observation emission requirement is not
   conditional on persistence readiness.
6. CORE-contracts are refused by the TEMPORAL executor (Q6 = confirmed; see
   AT-12).
7. AT-1 through AT-12 are verified before any live read is executed.
8. After gate opening, route `spec-ch7-gate3-approval-sync` to
   Compiler/Grammar Expert to close the lag between Ch7 baseline semantics
   and the approved PROP-030 enforcement ordering. This is a post-gate
   obligation, not a gate-opening precondition.

**Hold** if any of the following is unresolved:

- The gate decision document cannot record an authority ref (format,
  issuance process, revocation mechanism) at the time of signing. Gate 3
  must not be opened without a recorded authority source.
- The Architect determines that observation emission (AT-10) creates a
  blocking dependency that cannot be satisfied before live eval proceeds.

**Redirect** if:

- BiHistory must be included in the first Gate 3 implementation (go back to
  proof, then file a new request covering both axes).
- The Architect prefers to open a full Gate 3 (not restricted) — in that case
  this request document should be superseded by a broader scope request.

---

## VII. Not In This Request

```text
❌ Gate 3 authorization                    — only the Architect opens Gate 3
❌ ExecutorApprovalToken implementation   — requires Architect authority record first
❌ TemporalExecutor implementation        — follows gate opening
❌ Any live TBackend/Ledger call          — no live operations in this document
❌ Parser coordinate syntax               — not a gate concern
❌ BiHistory evaluation                   — explicitly excluded
❌ Stream / OLAP executor                 — separate lane
❌ Production cache                       — deferred
```

---

## Handoff

```text
Card: S3-R11-C1-G (revised S3-R12-C1-S)
Agent: [Igniter-Lang Meta Expert]
Role: meta-expert
Track: igniter-lang/runtime-temporal-executor-gate3-request-v0
Status: done — request revised; S3-R11-X1 HOLD resolved; ready for Architect review

[D] Decisions made in this document:
- Default proposed scope: live TEMPORAL History[T] valid_time only.
- BiHistory explicitly excluded until physical at(vt:, tt:) serving proof lands.
- Stream/OLAP/Ledger write/production cache excluded.
- 12 production acceptance conditions (AT-1..AT-12) defined.
  AT-10 is unconditional (no Q5 qualifier). AT-12 is new (CORE refusal).
- Q5 closed: audit observation required for every live temporal read.
- Q6 closed: CORE artifact refusal by TEMPORAL executor (now AT-12).
- Authority ref is a precondition of gate opening, not a post-approval action.
- Q3 Option C two-phase binding formally described.
- Scope-does-not-expand statement added (Section III).

[S] Shipped:
- docs/gates/runtime-temporal-executor-gate3-request-v0.md (S3-R11-C1-G, revised S3-R12-C1-S)
- docs/tracks/runtime-temporal-executor-gate3-request-revision-v0.md (this card)
- tracks/README.md updated with R12-C1-S entry.

[R] Risks:
- Gate 3 must not be opened before authority ref is recorded (Q1).
  A missing authority source means tokens cannot be validated in production.
  The gate decision document must contain the authority ref, format, issuance,
  and revocation mechanism before Gate 3 is considered open.
- AT-10 observation emission is unconditional. An implementer must not treat
  the absence of a persistence store as a license to skip observation emission.
- BiHistory exclusion must be explicit in the Architect decision document.
- AT-6 (TEMPORAL cache-key check before cache/TBackend) must be verified
  in the executor implementation before any read. Silent staleness is the
  primary correctness risk for TEMPORAL evaluation.

[Next]:
- Architect Supervisor: review, and either:
  (a) open Gate 3 via docs/gates/gate3-decision-record-v0.md; or
  (b) redirect with scope changes.
- Gate decision must include: authority ref + format + issuance + revocation;
  BiHistory exclusion (permanent or temporary); Q3 Option C phase approval.
- If approved: Research Agent implements executor with AT-1..AT-12 as acceptance.
- If approved: Compiler/Grammar Expert records authority format in PROP-030 errata.
- Post-gate (not blocking): route spec-ch7-gate3-approval-sync to
  Compiler/Grammar Expert to close Ch7 lag on PROP-030 enforcement ordering.
- Post-gate (not blocking): route compatibility-report-composition-v0 track
  to produce the reference shape for AT-2 before any live eval proceeds.
```
