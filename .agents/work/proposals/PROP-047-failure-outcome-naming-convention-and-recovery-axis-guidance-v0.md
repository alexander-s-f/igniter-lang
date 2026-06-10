# PROP-047 — Failure Outcome Naming Convention and Recovery-Axis Guidance

**Track:** failure-outcome-naming-convention-and-recovery-axis-guidance-v0  
**Route:** PROPOSAL AUTHORING ONLY  
**Authority:** governance / proposal text only  
**Date:** 2026-06-10  
**Predecessor:** LAB-FAILURE-TAXONOMY-P3 (Decision A — open narrow naming-convention PROP now)  
**Status:** DRAFT

---

## Purpose

This proposal names the stable cross-domain failure/outcome vocabulary for Igniter lab and canon guidance. It defines five stable cross-domain terms, documents ten recovery axes, states forbidden-collapse rules, and gives guidance on when to use KDR vs. variant and how to name what is observed vs. unknown.

**This proposal does NOT:**
- Define a global `FailureKind` enum
- Implement `Outcome[T,E]`
- Add OOF diagnostic codes
- Change compiler, parser, VM, or runtime behavior
- Make public or production-stable API claims
- Grant serialization ABI authority for any term

The evidence base is nine lab proof tracks (51+ checks each, cross-domain) and five Canon documents. The stable terms named here are already in use in lab fixtures; this proposal names them officially for guidance purposes.

---

## NAMING-EVIDENCE — Evidence Base

### Proof tracks surveyed

| Source | Domain | Stable terms confirmed |
|--------|--------|----------------------|
| Ch12 (`ch12-effect-surface.md`) | Canon | 7 outcome kinds: `succeeded`, `failed`, `partial`, `timed_out`, `unknown_external_state`, `compensated`, `cancelled` |
| Covenant P11/P13/P15/P16/P17 | Canon | Timeout ≠ failure; uncertainty non-discardable; evidence-kind load-bearing; idempotency gate |
| LAB-EPISTEMIC-OUTCOME-P2/P4 | Storage write / commit-ack / reconciliation | `unknown_external_state`, `timed_out`, `denied`, `partial` (as `partly_confirmed`) |
| LAB-FAILURE-TAXONOMY-P2 | HTTP client / upstream call | `unknown_external_state`, `upstream_unavailable`, `denied` — POST-DISPATCH TIMEOUT → `unknown_external_state` proven in a second independent domain |
| LAB-EXECUTE-QUERY-P1/P2/P3 | Storage query | `denied`, `query_error`, `system_error`, `rows`, `empty` |
| LAB-FILTER-EVAL-P1 | Query filter | `rows`, `empty`, `query_error` |
| LAB-RESULT-ENVELOPE-P1/P2 | Validation / HTTP | `valid`, `invalid`, `unauthorized` (denial), `system_error` |
| LAB-STDLIB-NET-P8/P9 | HTTP transport / ContractResult | `ok`, `denied`, `error`, `not_found`, `upstream_unavailable`, `capability_denied` |
| PROP-044-P8/P9 + LAB-OUTCOME-VARIANT-P1..P3 | Path B lowering | OOF-KIND1..6; variant/match Path B locked |

### Cross-domain invariant

The `denial-as-data` pattern is confirmed in 7+ independent domains with zero contradictions. It is the strongest cross-domain invariant in the lab corpus.

---

## NAMING-AXES — Ten Recovery Axes

These axes are orthogonal. Do not conflate them. Each has a distinct recovery path.

| Axis | Name | Recovery directive |
|------|------|--------------------|
| 1 | **capability_denial** | Authority refused before attempt; deterministic; fix the plan or obtain authority; do not retry the same plan |
| 2 | **malformed_plan** | Input structurally or semantically invalid; fix the input before retrying; not access denial |
| 3 | **external_unavailable** | Infrastructure-level failure; the endpoint or store is not reachable; retry with backoff after interval |
| 4 | **timeout** | Time limit elapsed; the outcome is unknown, not failed (Covenant P15); route to reconciliation, not retry |
| 5 | **unknown_external_state** | Request was sent; no confirmed receipt; must reconcile with an idempotency key before any retry; never route to success or failure directly |
| 6 | **partial_success** | Some sub-effects confirmed; some unconfirmed; not the same as unknown; **DEFERRED — see NAMING-DEFERRED** |
| 7 | **validation_invalid** | Domain constraint violated by data; fix the data; not access denial, not infrastructure |
| 8 | **compensation** | Irreversible effect completed; a named compensation contract is required (Covenant P17); pattern only — no stable cross-domain term assigned here |
| 9 | **retryable_vs_not** | Cross-cutting axis; whether automatic retry is permitted depends on idempotency gate (Covenant P16) and the specific outcome kind; arm names are domain-local |
| 10 | **type_error_vs_domain_outcome** | Compiler diagnostic (OOF-KIND) is not a runtime outcome; a type error at compile time is not an instance of any outcome kind; keep these namespaces separate |

**All ten axes are acknowledged here.** Axis 6 is explicitly deferred per NAMING-DEFERRED.

---

## NAMING-TERMS — Five Stable Cross-Domain Terms

These five terms have been confirmed independently in two or more non-overlapping proof domains. Contract authors may use them as stable `kind` string values in KDR records.

---

### Term 1: `denied`

**Definition:** A capability check, authority check, or policy gate evaluated the request and refused it before any effect began. The outcome is deterministic: the same request under the same policy will receive the same denial. No resource modification occurred; no idempotency key is required.

**Recovery:** Do not retry with the same plan. Either obtain the required authority, change the plan to request what is permitted, or surface the denial to the caller as data.

**Evidence:** 7+ independent domains — storage query (×4), HTTP transport, validation, Rack, Sidekiq, epistemic write (LAB-EPISTEMIC-OUTCOME-P2), HTTP client (LAB-FAILURE-TAXONOMY-P2). Zero contradictions. Strongest invariant in the corpus.

**Do not collapse with:** `query_error` (malformed input, not a policy decision), `system_error` (infrastructure failure, not a policy decision), `upstream_unavailable` (infrastructure, not policy).

**Pattern:** `denial-as-data` — the denial is carried as a typed outcome value, never raised as an exception or thrown as an error. The consumer must handle denial as a first-class outcome.

---

### Term 2: `unknown_external_state`

**Definition:** A request was dispatched (at least partially sent) to an external system, and no acknowledgement was received. The caller cannot determine whether the effect occurred. The request may have succeeded, may have partially succeeded, or may not have been processed at all.

**Recovery:** Do NOT route to success or failure. DO route to reconciliation. Carry the `idempotency_key`, `request_id`, and any available metadata into the reconciliation record. Retry is only permitted after reconciliation confirms the prior request did not succeed (Covenant P16).

**Evidence:** LAB-EPISTEMIC-OUTCOME-P2/P4 (storage/reconciliation domain) + LAB-FAILURE-TAXONOMY-P2 (HTTP client domain). Two independent domains. Covenant P15 states the rule as canon.

**Do not collapse with:** `timed_out` (a clock signal, not an epistemic state — see Term 3 and NAMING-COLLAPSE rule FC-2), `system_error` (a known infrastructure fault — different recovery path), `upstream_unavailable` (pre-dispatch, no ambiguity about whether the effect occurred).

**Epistemic note:** The term names a state of the caller's knowledge, not a state of the external system. The external system may have succeeded. This distinction drives the recovery strategy.

---

### Term 3: `timed_out`

**Definition:** A time limit elapsed before a response was received. This is a clock event, not an outcome classification. A timeout observation must be further classified: did the request reach the external system before the timeout? If yes, the outcome is `unknown_external_state`. If no, the outcome may be `upstream_unavailable` or another pre-dispatch kind.

**Recovery:** Do not use `timed_out` as a terminal outcome kind in a routing contract. Use it as a transport-layer observation that requires further epistemic classification via the `dispatch_started` / `ack_received` discriminant pair.

**Evidence:** Ch12, Covenant P15, LAB-FAILURE-TAXONOMY-P2 (HTTP client). The discriminant-pair pattern is proven across two domains.

**Key result from LAB-FAILURE-TAXONOMY-P2:**

```
dispatch_started == true  AND  ack_received == false
  => kind: "unknown_external_state"   (Covenant P15)

dispatch_started == false  (timeout before dispatch)
  => kind: "upstream_unavailable"     (NOT unknown)
```

`transport_kind: "timeout"` **alone** is not sufficient to classify the outcome. The same `transport_kind` value has two distinct epistemic meanings depending on whether dispatch was started.

**Do not collapse with:** `unknown_external_state` (timed_out is the clock signal; unknown_external_state is the epistemic conclusion for the post-dispatch case — Covenant P15 names them as separate concepts).

---

### Term 4: `system_error`

**Definition:** An infrastructure-level fault occurred: the store, service, or network layer is known to have failed in a way that did not process the request. This is a known failure, not an unknown state. The request was not processed; no idempotency concern arises.

**Recovery:** Retry with backoff after an interval. No reconciliation is required; the request is known not to have been processed.

**Evidence:** LAB-EXECUTE-QUERY-P1/P2/P3 (storage query), LAB-RESULT-ENVELOPE-P2 (validation). At least two independent domains.

**Do not collapse with:** `unknown_external_state` (system_error is a known non-processing fault; unknown_external_state is an uncertain post-dispatch state — these require different recovery paths). See NAMING-COLLAPSE rule FC-3.

---

### Term 5: `query_error`

**Definition:** A request was well-formed structurally but violated a domain constraint or semantic rule. The operation was attempted and the constraint was detected. Examples: a missing required field in a query plan, an invalid filter operator, an empty field list in a projection where `include_all` is false.

**Recovery:** Fix the query plan or input data and retry. This is not an infrastructure problem and not an access denial. Retrying with the same malformed input will produce the same error.

**Evidence:** LAB-EXECUTE-QUERY-P1/P2/P3, LAB-FILTER-EVAL-P1, LAB-QUERY-MULTI-ORDER-P1 (storage query, at least three proofs). Domain-local to the query pipeline but confirmed stable.

**Do not collapse with:** `denied` (query_error is a malformed plan, not a policy decision; the system attempted to process the request and found it semantically invalid — see NAMING-COLLAPSE rule FC-1).

---

## NAMING-COLLAPSE — Forbidden-Collapse Rules

These collapses are FORBIDDEN. Each pair names distinct axes with distinct recovery paths. Collapsing them erases the recovery distinction.

**FC-1: `denied` vs `query_error`**  
Do not produce `denied` when the request was received and found semantically invalid. Do not produce `query_error` when authority was refused before any processing attempt. The distinction: `denied` = policy evaluation decided no; `query_error` = semantic validation decided malformed.

**FC-2: `timed_out` vs `unknown_external_state`**  
Do not use `timed_out` as a final routing kind when the post-dispatch case applies. Covenant P15 states that a timeout after dispatch is `UnknownExternalOutcome`, not `ObservedFailure`. These require different recovery: `timed_out` is a transport observation; `unknown_external_state` is the epistemic conclusion requiring reconciliation.

**FC-3: `unknown_external_state` vs `system_error`**  
`unknown_external_state` requires reconciliation before any retry. `system_error` permits retry with backoff directly (no reconciliation needed). Collapsing them forces one recovery path on the other and may result in either double-effects (if unknown is retried as system_error) or missed reconciliation (if system_error is treated as unknown).

**FC-4: `partial_success` vs `unknown_external_state`**  
A partial outcome has some confirmed resource handles; an unknown outcome has none confirmed. Partial requires reconciliation of the unconfirmed sub-effects; unknown requires reconciliation of the whole. Routing partial to unknown loses the confirmed handles. (Axis 6 is deferred for stable term assignment, but this forbidden collapse is active now — see NAMING-DEFERRED.)

**FC-5: `validation_invalid` vs `capability_denied`**  
`validation_invalid` (or `invalid`) names a data constraint failure; `capability_denied` (or `denied`) names an authority gate failure. The former invites the caller to fix their data; the latter invites the caller to obtain authority or change their plan. Collapsing them gives misleading recovery guidance.

**FC-6: `retry_budget_exhausted` vs `upstream_failure`**  
Exhausting a retry budget is a caller-side budget event. An upstream failure is a state of the remote service. These must not be conflated: a caller who exhausts its budget does not thereby know the upstream failed; the upstream state is still unknown. If the upstream genuinely failed on every attempt, that is upstream-failure evidence (confirmed); if the upstream is unreachable but might be processing requests, the state is unknown.

**FC-7: Observation types `real`, `model`, `human`**  
Covenant P13 names these as distinct evidence kinds. A model-confirmed outcome is not the same as a real-observation outcome. Do not coerce `evidence_kind: "model"` to `evidence_kind: "real"` without an explicit human verification step. (No-Upward-Coercion rule.)

---

## NAMING-KDR — KDR / Variant Usage Boundary

Both KDR (kind-discriminated record) and variant/match are valid tools in Igniter. This section states when each is appropriate. **This PROP does not require variant grammar and does not obsolete KDR.**

### When KDR is appropriate

- Proof-local fixtures that need a stable, readable output shape
- Interop boundaries, serialization, and external consumers that need a portable, language-neutral discriminant
- Boundary contracts that emit outcomes to external systems
- Any contract that does not need exhaustiveness enforcement at the type level

KDR uses a `kind: String` field as the discriminant. The consumer dispatches by reading the `kind` field and matching it in code. The compiler does not enforce exhaustiveness; the contract author is responsible for covering all cases.

### When variant/match is appropriate

- Contracts where exhaustive arm coverage is a correctness requirement
- Contracts where the vocabulary is known, sealed, and domain-internal
- Routing contracts that must not silently produce `nil` on an unrecognized arm (OOF-KIND fail-closed behavior)
- Contracts whose arms carry structurally distinct payloads (different fields per arm)

Variant/match uses Path B lowering (PROP-044-P8): `variant_construct → OP_PUSH_RECORD` with `__arm`/`__variant` compiler-owned fields. The `__arm` and `__variant` fields are compiler-internal; they must not appear as user-authored contract field names.

### The boundary rule

**Neither form is universally correct.** Use KDR at boundaries and for interop. Use variant/match when exhaustiveness enforcement in the type system matters. A contract may use KDR output for its external surface and variant/match internally for its routing logic.

**This PROP does not create a global `Outcome[T,E]` type.** The five stable terms apply to `kind: String` KDR values. Variant arms may use these names or domain-local names; the stable terms are naming guidance, not a sealed enum.

---

## NAMING-OBSERVATION — Observation and Epistemic-State Guidance

### Name what is known, not what is unknown

When classifying an outcome, name the epistemic state accurately:

| Situation | Correct kind | Incorrect kind |
|-----------|-------------|----------------|
| Policy gate refused the request | `denied` | `system_error`, `upstream_unavailable` |
| Request sent, no acknowledgement | `unknown_external_state` | `system_error`, `timed_out` (as terminal) |
| Infrastructure fault, request not processed | `system_error` | `unknown_external_state` |
| Input was semantically invalid | `query_error` or `invalid` | `denied` |
| Clock expired, post-dispatch | `unknown_external_state` | `timed_out` (as terminal kind) |
| Clock expired, pre-dispatch | `upstream_unavailable` | `timed_out` (as terminal kind), `unknown_external_state` |

### Do not infer epistemic state from transport shape alone

A `transport_kind: "timeout"` signal is a transport observation, not a classification. The classifier must inspect the epistemic discriminant pair (`dispatch_started`, `ack_received`) to determine whether the outcome is `unknown_external_state` or `upstream_unavailable`. Two transport events with the same `transport_kind` value may require different outcome kinds.

### No-Upward-Coercion (Covenant P13)

An outcome with `evidence_kind: "model"` must not be promoted to `evidence_kind: "real"` without an explicit human verification step. A model-inferred confirmation is not the same as a real observation. Route `evidence_kind: "model"` outcomes to human review rather than to the same acceptance path as `evidence_kind: "real"`.

### Reconciliation data is not optional

An `unknown_external_state` outcome must carry:
- `request_id` — for correlation with the external system
- `idempotency_key` — for retry gating after reconciliation (Covenant P16)
- `metadata: Map[String, String]` — for context (resource path, sent_at, attempt count, etc.)

These fields must not be dropped when routing `unknown_external_state` outcomes. Dropping them makes reconciliation impossible.

---

## NAMING-DEFERRED — Explicitly Deferred Terms

The following terms are acknowledged as real axes but are **not promoted to stable cross-domain terms** in this proposal. They are explicitly deferred, not absent by oversight.

### Axis 6: `partial_success`

**Status:** Single-domain evidence only (reconciliation domain: `partly_confirmed` in LAB-EPISTEMIC-OUTCOME-P4, `PartiallyConfirmed` variant in LAB-OUTCOME-VARIANT-P1, `partial` in Ch12).

**Why deferred:** Ch12 names `partial` as one of seven canonical outcome kinds. The epistemic domain proves it as a distinct KDR kind and variant arm. However, no cross-domain proof has yet confirmed that `partial_success` arises as a distinct kind in a non-reconciliation domain (e.g., storage query, HTTP client, validation). Naming it as a stable cross-domain term before that evidence exists would be premature.

**What IS active now:** The forbidden-collapse rule FC-4 (`partial_success` ≠ `unknown_external_state`) is active. Contract authors must not collapse partial and unknown even while the stable term for partial is deferred. A partial outcome has some confirmed resource handles; an unknown outcome has none confirmed. The distinction in recovery strategy is epistemic and does not require a stable term name to be enforced.

**Next route:** `LAB-FAILURE-TAXONOMY-P4` — partial_success cross-domain proof. If that proof passes, this PROP can be amended to add `partial` (or `partial_success`) as a sixth stable term.

### `compensation`

**Status:** Ch12 names `compensated` as one of seven outcome kinds. LAB-OUTCOME-VARIANT-P1 proves `ConfirmedFailedCompensatable` as a distinct variant arm. Covenant P17 requires a named compensation contract.

**Why deferred:** The `compensation` pattern requires understanding of the specific compensation contract. It is not a generic term applicable across domains without knowing which irreversible effect is being compensated. Named as a **pattern** only; compensation contracts are domain-local.

### `retryable` / `non_retryable`

**Status:** Cross-cutting pattern confirmed across multiple domains. Covenant P16 defines the idempotency gate as the retry authority.

**Why deferred:** Whether a given outcome is retryable depends on the outcome kind AND the specific contract's idempotency guarantees. Arm names (`non_retryable`, `retry_with_backoff`, etc.) are domain-local. The pattern is stable; the cross-domain term is not.

---

## NAMING-CLOSED — Permanently Closed Surfaces

The following surfaces are closed by this proposal and may not be opened by subsequent cards in this track without explicit authority:

| Surface | Status | Reason |
|---------|--------|--------|
| Global `FailureKind` enum | **CLOSED** | Flattening 10 axes into one enum erases recovery distinctions. Each axis has a distinct recovery path; a single enum cannot encode them without collapsing the axes. |
| `Outcome[T,E]` generic sealed type | **CLOSED** | Three unsatisfied preconditions remain: generic type parameters, a sealed variant across domains, and cross-domain vocabulary consensus. This PROP does not satisfy the third precondition for all axes. |
| New OOF diagnostic codes | **CLOSED** | OOF codes are compiler diagnostics, not runtime outcome names. Axis 10 explicitly keeps these namespaces separate. |
| Compiler / parser / VM / runtime changes | **CLOSED** | This is a naming-convention proposal only. No implementation authority is created. |
| Serialization ABI | **CLOSED** | Stable KDR string values are named for guidance; their wire encoding is not specified or locked here. |
| Production / public-stable API claims | **CLOSED** | Lab evidence only. |

---

## NAMING-SUMMARY — Summary Table

| Term | Axis | Evidence strength | Stable? | Recovery |
|------|------|------------------|---------|----------|
| `denied` | 1 (capability_denial) | Very strong (7+ domains) | ✓ | Fix plan or obtain authority; never retry same plan |
| `query_error` | 2 (malformed_plan) | Strong (3+ proofs) | ✓ | Fix input; retry |
| `system_error` | 3 (external_unavailable) | Strong (2+ domains) | ✓ | Retry with backoff; no reconciliation |
| `timed_out` | 4 (timeout) | Cross-domain (Ch12 + 2 domains) | ✓ (transport observation; classify further) | Route to `unknown_external_state` (post-dispatch) or `upstream_unavailable` (pre-dispatch) |
| `unknown_external_state` | 5 (unknown_external_state) | Cross-domain (2 domains) | ✓ | Reconcile; do not retry before reconciliation |
| `partial` / `partial_success` | 6 (partial_success) | Single-domain | **DEFERRED** | Reconcile unconfirmed sub-effects (guidance active; stable term pending P4) |
| `invalid` | 7 (validation_invalid) | Strong (2+ domains) | ✓ (domain-local surface term) | Fix data; retry |
| `compensated` | 8 (compensation) | Partial (canon + 1 domain) | Pattern only | Named compensation contract required (P17) |
| retryable/non-retryable | 9 (retryable_vs_not) | Cross-domain (pattern) | Pattern only | Idempotency gate (P16); arm names domain-local |
| OOF-KIND1..6 | 10 (type_error_vs_domain_outcome) | Very strong (all compiler tracks) | Compiler namespace | Not a runtime outcome; do not mix namespaces |

---

## NAMING-NEXT — Recommended Next Routes

1. **LAB-FAILURE-TAXONOMY-P4** — partial_success cross-domain proof. If this passes, amend this PROP to add `partial` as the sixth stable term.

2. **Canon amendment card** — if the full PROP is approved, a subsequent card should amend Ch12 to mark the five stable terms as guidance-approved (not just Canon-named). This is a separate authority action.

3. **Lab fixture alignment** — lab fixtures may use domain-local terms (`upstream_unavailable`, `not_found`, `rows`, `empty`, etc.) that are not in the stable cross-domain set. This is correct behavior. The stable set is for cross-domain guidance only; domain-local names remain valid.

---

## NAMING-DECISIONS — Locked Decisions

| # | Decision |
|---|----------|
| D1 | Five stable cross-domain terms: `denied`, `unknown_external_state`, `timed_out`, `system_error`, `query_error` |
| D2 | `transport_kind: "timeout"` alone is NOT sufficient to classify an outcome; the `dispatch_started`/`ack_received` Bool pair is required |
| D3 | FC-1 through FC-7 forbidden-collapse rules are ACTIVE |
| D4 | Axis 6 (`partial_success`) is explicitly deferred; FC-4 is active regardless |
| D5 | KDR is valid for boundary, interop, and proof-local use; variant/match is preferred where exhaustiveness enforcement matters |
| D6 | `__arm`/`__variant` are compiler-owned fields; must not appear as user-authored contract field names |
| D7 | No-Upward-Coercion: `evidence_kind: "model"` must not be promoted to `evidence_kind: "real"` without explicit human verification |
| D8 | `unknown_external_state` outcomes must carry `request_id`, `idempotency_key`, and `metadata` |
| D9 | Global `FailureKind` enum is permanently closed |
| D10 | `Outcome[T,E]` is permanently closed until all three preconditions are satisfied |
| D11 | OOF-KIND codes are compiler diagnostics; they are not runtime outcome kinds |
| D12 | Compensation is a pattern (Covenant P17); no stable cross-domain term is assigned |

---

*Authorized by: LAB-FAILURE-TAXONOMY-P3, Decision A (2026-06-10)*
