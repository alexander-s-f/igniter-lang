# LANG-STDLIB-OUTCOME v0 — Outcome Helper Predicates and Kind Accessor

**Track:** stdlib-outcome-helper-predicates-and-kind-accessor-v0
**Status:** authored-pending-review
**Date:** 2026-06-11
**Route:** PROPOSAL AUTHORING ONLY / NO IMPLEMENTATION
**Predecessor proofs:** LAB-STDLIB-OUTCOME-P1 (66/66 PASS), LAB-FAILURE-TAXONOMY-P4 (54/54), LAB-EPISTEMIC-OUTCOME-P2 (54/54), LAB-OUTCOME-VARIANT-P1..P3
**Predecessor governance:** PROP-047-P2, LANG-STDLIB-ENTRY-CONTRACT-P1/P2, LAB-STDLIB-FOUNDATION-P1

---

## 1. Context and Evidence Base

`LAB-STDLIB-FOUNDATION-P1` identified the outcome category as the largest stdlib blind spot:
Canon Ch12 and Covenant P15 define the unknown-state model; lab proofs flatten every
outcome to ad-hoc `kind: String` comparisons; stdlib offers zero combinators.

`LAB-STDLIB-OUTCOME-P1` (66/66 PASS) established that helpers can reduce this stringly
handling without collapsing domain-specific outcomes or granting runtime authority.

`PROP-047-P2` defines six cross-domain stable outcome terms — the vocabulary this proposal
operationalizes as predicate helpers.

`LANG-STDLIB-ENTRY-CONTRACT-P1/P2` defines the schema every stdlib entry must satisfy.

This proposal authors the governance boundary for `stdlib.outcome` v0.

---

## 2. Core Principle

**Outcome helpers classify observed outcome data.**
They do not decide recovery, schedule retries, execute routes, or grant authority.

A helper that says "this outcome is denied" does not retry, reschedule, or compensate.
The caller owns all policy. The helper only reads and classifies.

---

## 3. Scope of v0

**In scope:**
- One kind accessor: `stdlib.outcome.kind`
- Six stable-term predicates corresponding to PROP-047 §2 vocabulary
- KDR-like input shape (`Map[String, String]`)
- Pure Bool/String outputs

**Explicitly excluded from v0:**
- `stdlib.outcome.is_retryable` — deferred (requires dispatch context; see §5)
- `stdlib.outcome.route` — rejected (see §6)
- Any generic `Outcome[T,E]` sealed type
- Variant enforcement or exhaustiveness
- Domain-local predicates (`is_found`, `is_created`, `is_rows`, etc.)
- Retry scheduler, routing policy, capability grants
- Public compatibility promise beyond this proposal text

---

## 4. Input Shape

### Accepted Shape (v0)

`Map[String, String]` — the KDR convention from LAB-EPISTEMIC-OUTCOME-P2.

Every helper reads exactly the `"kind"` key from the record. No other field is inspected
except `dispatch_started` for `is_retryable` (deferred to P2).

```
{ "kind" => "denied", "message" => "auth_failed", ... }
```

The `...` is open. Helpers are indifferent to additional fields.

### Typed Record (future)

Named Records with a `kind: String` field are a candidate extension for P2/P3.
In v0 the accepted shape is `Map[String, String]` only.

### Missing Kind Key

Callers are responsible for providing a well-formed record. A missing `"kind"` key is
a programming error. In v0 behavior is implementation-defined; P2 (implementation
planning) decides whether to raise an error, emit OOF-OUT1, or return a sentinel.
This proposal does not silently return `false` for a missing key — that would mask bugs.

### Non-String Kind Value

Behavior undefined in v0. P2 decides. Callers must not pass non-String kind values.

### No Generic Outcome[T,E]

Helpers do not require, accept, or produce `Outcome[T,E]`. No sealed generic wrapper
is introduced. Domain callers use their own record types and read the `"kind"` field.

---

## 5. Accepted Entries (v0)

### 5.1 Entry Contract Sketch Template

All entries use LANG-STDLIB-ENTRY-CONTRACT-P1 schema. Three invariants hold for every
entry in this table:
- `purity: "pure"` — no side effects
- `deterministic: true` — same input always produces same output
- `authority_surface: "none"` — no capability grant, no recovery execution
- `semantic_ir_name` equals `canonical_name` (LANG-STDLIB-ENTRY-CONTRACT-P1 §4 constraint)

### 5.2 kind accessor

```
canonical_name:    stdlib.outcome.kind
category:          outcome
status:            proof-local
stability:
  semantic:        convention
  lowering:        none
  compatibility:   pre-v1-none
fragment_class:    core
purity:            pure
deterministic:     true
totality:          total (raises on absent 'kind' key — programming error)
input_signature:   [Map[String, String]]
output_signature:  String
authority_surface: none
failure_behavior:  absent 'kind' key → implementation-defined error (P2 decides)
semantic_ir_name:  stdlib.outcome.kind
proof_lineage:     [LAB-STDLIB-OUTCOME-P1 B-04/D-08 PASS, PROP-047-P2]
notes:             Opaque passthrough. Returns the kind string verbatim regardless
                   of whether it is a stable term or a domain-local kind.
                   Does NOT normalize, alias, or transform.
```

### 5.3 is_denied

```
canonical_name:    stdlib.outcome.is_denied
category:          outcome
status:            proof-local
stability:
  semantic:        experiment-pass
  lowering:        none
  compatibility:   pre-v1-none
fragment_class:    core
purity:            pure
deterministic:     true
totality:          total (false for all non-denied kinds including domain-local)
input_signature:   [Map[String, String]]
output_signature:  Bool
authority_surface: none
failure_behavior:  absent 'kind' key → implementation-defined error (P2 decides)
semantic_ir_name:  stdlib.outcome.is_denied
proof_lineage:     [LAB-STDLIB-OUTCOME-P1 C-01 PASS, PROP-047-P2 §2.1, LAB-FAILURE-TAXONOMY-P1]
notes:             PROP-047: denied = capability/authority refused before operation;
                   deterministic; do NOT retry. FC-1: denied ≠ query_error.
```

### 5.4 is_unknown_external_state

```
canonical_name:    stdlib.outcome.is_unknown_external_state
category:          outcome
status:            proof-local
stability:
  semantic:        experiment-pass
  lowering:        none
  compatibility:   pre-v1-none
fragment_class:    core
purity:            pure
deterministic:     true
totality:          total
input_signature:   [Map[String, String]]
output_signature:  Bool
authority_surface: none
failure_behavior:  absent 'kind' key → implementation-defined error
semantic_ir_name:  stdlib.outcome.is_unknown_external_state
proof_lineage:     [LAB-STDLIB-OUTCOME-P1 C-02 PASS, PROP-047-P2 §2.5,
                    LAB-EPISTEMIC-OUTCOME-P2 (54/54), LAB-FAILURE-TAXONOMY-P2 (51/51)]
notes:             PROP-047: request sent, no acknowledgement; must reconcile.
                   Covenant P15: timeout ≠ failure; unknown_external_state is epistemic
                   state, not a failure. FC-2: timed_out ≠ unknown_external_state.
                   FC-3: unknown_external_state ≠ system_error.
                   Recovery: reconcile. NOT a retry signal.
```

### 5.5 is_timed_out

```
canonical_name:    stdlib.outcome.is_timed_out
category:          outcome
status:            proof-local
stability:
  semantic:        experiment-pass
  lowering:        none
  compatibility:   pre-v1-none
fragment_class:    core
purity:            pure
deterministic:     true
totality:          total
input_signature:   [Map[String, String]]
output_signature:  Bool
authority_surface: none
failure_behavior:  absent 'kind' key → implementation-defined error
semantic_ir_name:  stdlib.outcome.is_timed_out
proof_lineage:     [LAB-STDLIB-OUTCOME-P1 C-03 PASS, PROP-047-P2 §2.3,
                    LAB-FAILURE-TAXONOMY-P2 (51/51)]
notes:             This helper does NOT distinguish pre- vs post-dispatch timeout.
                   Both have kind "timed_out". Retry safety requires dispatch context
                   (see is_retryable, §5 deferred). Callers must read dispatch_started
                   from the record directly if they need that distinction.
                   FC-2: timed_out ≠ unknown_external_state (clock vs epistemic).
```

### 5.6 is_system_error

```
canonical_name:    stdlib.outcome.is_system_error
category:          outcome
status:            proof-local
stability:
  semantic:        experiment-pass
  lowering:        none
  compatibility:   pre-v1-none
fragment_class:    core
purity:            pure
deterministic:     true
totality:          total
input_signature:   [Map[String, String]]
output_signature:  Bool
authority_surface: none
failure_behavior:  absent 'kind' key → implementation-defined error
semantic_ir_name:  stdlib.outcome.is_system_error
proof_lineage:     [LAB-STDLIB-OUTCOME-P1 C-04 PASS, PROP-047-P2 §2.4]
notes:             PROP-047: infrastructure-level fault; retry with backoff.
                   FC-3: system_error ≠ unknown_external_state.
                   This helper returns true for infrastructure failures regardless
                   of domain (network, storage, state-store, etc.).
```

### 5.7 is_query_error

```
canonical_name:    stdlib.outcome.is_query_error
category:          outcome
status:            proof-local
stability:
  semantic:        experiment-pass
  lowering:        none
  compatibility:   pre-v1-none
fragment_class:    core
purity:            pure
deterministic:     true
totality:          total
input_signature:   [Map[String, String]]
output_signature:  Bool
authority_surface: none
failure_behavior:  absent 'kind' key → implementation-defined error
semantic_ir_name:  stdlib.outcome.is_query_error
proof_lineage:     [LAB-STDLIB-OUTCOME-P1 C-05 PASS, PROP-047-P2 §2.6]
notes:             PROP-047: structurally or semantically invalid input.
                   FC-1: query_error ≠ denied (malformed vs policy refusal).
                   Do NOT retry a query_error — the input must change first.
```

### 5.8 is_partial_success

```
canonical_name:    stdlib.outcome.is_partial_success
category:          outcome
status:            proof-local
stability:
  semantic:        experiment-pass
  lowering:        none
  compatibility:   pre-v1-none
fragment_class:    core
purity:            pure
deterministic:     true
totality:          total
input_signature:   [Map[String, String]]
output_signature:  Bool
authority_surface: none
failure_behavior:  absent 'kind' key → implementation-defined error
semantic_ir_name:  stdlib.outcome.is_partial_success
proof_lineage:     [LAB-STDLIB-OUTCOME-P1 C-06 PASS, PROP-047-P2 §2.7,
                    LAB-FAILURE-TAXONOMY-P4 (54/54)]
notes:             partial_success promoted to sixth stable term by PROP-047-P2
                   after LAB-FAILURE-TAXONOMY-P4 proved cross-domain evidence
                   (batch processing + multi-upstream HTTP; 54/54 PASS).
                   PROP-047: bounded operation with confirmed successes AND failures;
                   per-item evidence required (FC-4..FC-7).
                   is_partial_success returning true DOES NOT mean the operation
                   fully succeeded. Callers must inspect per-item evidence separately.
```

---

## 6. Conditional Entry: is_retryable

**Status: DESIGN CANDIDATE — deferred to LAB-STDLIB-OUTCOME-P2 / LANG-STDLIB-OUTCOME-PROP-P2**

### Why deferred

`is_retryable` cannot be a kind-only predicate. `timed_out` maps to two different retry
decisions depending on dispatch context:

- `timed_out` + `dispatch_started = false` → retryable (clock elapsed before dispatch)
- `timed_out` + `dispatch_started = true` → NOT retryable (post-dispatch = unknown state;
  Covenant P15; reconcile, not retry)

A kind-only helper cannot make this distinction safely. Returning `true` for all
`timed_out` outcomes would silently give false guidance for post-dispatch timeout.

### Axis-9 semantics (PROP-047 §3.9)

| Kind | is_retryable (proposed) | Rationale |
|------|------------------------|-----------|
| `denied` | false | Deterministic; PROP-047 FC-1 |
| `query_error` | false | Malformed input; input must change |
| `unknown_external_state` | false | Reconcile not retry; Covenant P15 |
| `timed_out` (pre-dispatch) | true | Clock elapsed before send; safe to retry |
| `timed_out` (post-dispatch) | false | Unknown state path; reconcile first |
| `system_error` | true | Retry with backoff |
| `partial_success` | false | Not a retry signal; per-item evidence required |
| domain-local kinds | false | Generic helper cannot know domain retry semantics |

### Design options for P2

P2 must choose one:

**Option A — Context field in same record:**
`is_retryable(outcome)` reads both `"kind"` and `"dispatch_started"` from the same
KDR record. Absent `dispatch_started` defaults to `false` (pre-dispatch assumption).
Simpler call site; requires record convention to be documented.

**Option B — Context parameter:**
`is_retryable(outcome, dispatch_context)` with a second `Map[String, String]` parameter
carrying `dispatch_started`. Explicit; more verbose; avoids hidden field convention.

**Option C — Split helpers:**
`is_retryable_pre_dispatch(outcome)` and `is_retryable_post_dispatch(outcome)`.
Most explicit; no context needed; call site disambiguates. Increases helper count.

LAB-STDLIB-OUTCOME-P1 used Option A. This proposal does not lock the choice.

### Provisional entry sketch (not binding)

```
canonical_name:    stdlib.outcome.is_retryable
category:          outcome
status:            proof-local (design candidate)
stability:
  semantic:        sketch
  lowering:        none
totality:          partial: axis-9 stable terms; domain-local always false;
                   timed_out requires dispatch context (Option A/B/C unresolved)
authority_surface: none
proof_lineage:     [LAB-STDLIB-OUTCOME-P1 E-01..E-07 PASS, PROP-047-P2 §3.9]
```

---

## 7. Rejected Entry: route()

**`stdlib.outcome.route(outcome, policy)` — REJECTED**

A `route(outcome, policy)` helper encodes a routing policy as a data parameter passed to
a stdlib function. This is a form of policy delegation to the stdlib layer, which violates
the authority boundary.

- The stdlib may classify. It may not decide.
- Recovery, retry scheduling, and routing are caller responsibilities.
- Encoding `{ "denied" => "block", "system_error" => "retry" }` as a stdlib parameter
  is effectively delegating control-flow decisions to a generic function.
  This is incompatible with Igniter's honesty requirement: authority must be explicit and
  traceable, not delegated through a data parameter.

**No `route` helper is defined in this proposal or any successor.**
Callers must express their routing logic directly using `kind()` or `is_*` predicates
combined with their own match or conditional logic.

---

## 8. Domain-Local Preservation

Helpers must not collapse domain-local outcome kinds. This is a non-negotiable rule.

### Rule: Unknown kinds return false

For all `is_*` predicates: if `outcome["kind"]` does not exactly match the helper's stable
term string, the helper returns `false`. There is no fallback, approximation, or fuzzy
match.

### Rule: kind() is always a passthrough

`stdlib.outcome.kind(outcome)` returns `outcome["kind"]` verbatim. It does not normalize,
canonicalize, or substitute. If the caller has `{ "kind" => "found" }`, kind() returns
`"found"` — unchanged.

### Preserved domain-local kinds (examples, not exhaustive)

| Domain | Domain-local kinds |
|--------|--------------------|
| Storage / Query | `rows`, `empty`, `found`, `created`, `conflict` |
| Network / HTTP | `ok`, `redirect`, `rate_limited` |
| Epistemic | `confirmed_succeeded`, `confirmed_failed`, `still_unknown`, `reconciliation_denied`, `reconciliation_error` |
| Batch / job | `processing`, `queued`, `cancelled` |

Callers routing on domain-local kinds MUST use `stdlib.outcome.kind(outcome)` directly
and write their own matching logic. No stdlib helper exists or will exist for domain-local
terms in v0.

### Why this matters (FC-rules)

PROP-047 FC-4..FC-7 establish that `partial_success` requires per-item evidence and
cannot be confused with total success or total failure. FC-8..FC-10 establish validation,
capability, and observation-type distinctions. A helper that absorbed domain-local kinds
would silently erase these distinctions. The open-world false-return is the mechanism
that enforces the boundary.

---

## 9. KDR / Variant Boundary

### KDR helpers (this proposal)

These helpers operate on KDR records — `Map[String, String]`-shaped hashes with a
`"kind"` field. They are intentionally lightweight and require no sealed type.

### Variant form (separate)

LAB-OUTCOME-VARIANT-P1..P3 proved a variant/match form for epistemic outcomes:
```
variant ReconciliationOutcome { ConfirmedSucceededReal { ... } ... }
```
Variant arm names (PascalCase like `ConfirmedSucceededReal`) are NOT stable PROP-047
terms. They are distinct linguistic constructs serving different purposes:
- KDR: boundary interop, proof-local, external consumers, open-world
- variant/match: exhaustiveness enforcement, sealed vocabulary, distinct typed payloads

### Helpers do not obsolete variants

These helpers reduce stringly `kind: String` handling. They do not replace variants.
Callers who want exhaustiveness guarantees should use `variant`/`match`. Callers
who need open-world KDR interop should use these helpers.

### Variant helpers are future work

Typed predicates over variant arms (`is_ConfirmedSucceededReal(arm)`) are a
separate future track. They are not blocked by this proposal but also not opened.

---

## 10. Failure Behavior and Diagnostics

### Missing kind key

`outcome["kind"]` being absent is a programming error — not a domain outcome. The
caller failed to provide a well-formed record.

**v0 behavior: implementation-defined.** P2 (implementation planning) must decide
between:
- Raise: `KeyError` (explicit; fails loudly; preferred)
- OOF diagnostic at call site: `OOF-OUT1` (requires TypeChecker integration; see below)
- Return sentinel String (e.g. `""`) — NOT RECOMMENDED (silent, hides bugs)

### Non-String kind value

Undefined in v0. P2 decides whether the type system prevents this or a runtime error
handles it.

### OOF Namespace

**OOF-OUT1..OOF-OUT4 are reserved** by this proposal for outcome helper diagnostics.
Exact trigger conditions and message templates are deferred to P2.

| Code | Candidate trigger |
|------|------------------|
| OOF-OUT1 | Missing `kind` field in input record |
| OOF-OUT2 | Non-String `kind` value |
| OOF-OUT3 | (reserved) |
| OOF-OUT4 | (reserved) |

Whether OOF-OUT codes require TypeChecker integration or are runtime-only errors is
a P2 implementation decision. No OOF-OUT code fires in this proposal — proposal only.

---

## 11. Stdlib Entry Contract Alignment

All entries satisfy LANG-STDLIB-ENTRY-CONTRACT-P1 invariants:

| Constraint | Value | Verified |
|-----------|-------|---------|
| `canonical_name` always qualified `stdlib.outcome.*` | Yes (all 7 entries) | ✓ |
| `semantic_ir_name` == `canonical_name` | Yes | ✓ |
| No bare name in SIR | N/A (no SIR emission in P1) | — |
| `authority_surface` = `"none"` | Yes | ✓ |
| Proof bar for claimed `status` level | `proof-local`: LAB-STDLIB-OUTCOME-P1 66/66 | ✓ |
| `fragment_class: "core"` (no capability) | Yes | ✓ |
| `stability.compatibility: "pre-v1-none"` | Yes | ✓ |
| Cross-domain demand (≥2 domains) | Yes: HTTP + Storage + Epistemic (3 domains) | ✓ |
| No domain leakage | Yes: helpers return false for domain-local kinds | ✓ |

### Canonical Name Summary

| canonical_name | semantic_ir_name |
|---------------|-----------------|
| `stdlib.outcome.kind` | `stdlib.outcome.kind` |
| `stdlib.outcome.is_denied` | `stdlib.outcome.is_denied` |
| `stdlib.outcome.is_unknown_external_state` | `stdlib.outcome.is_unknown_external_state` |
| `stdlib.outcome.is_timed_out` | `stdlib.outcome.is_timed_out` |
| `stdlib.outcome.is_system_error` | `stdlib.outcome.is_system_error` |
| `stdlib.outcome.is_query_error` | `stdlib.outcome.is_query_error` |
| `stdlib.outcome.is_partial_success` | `stdlib.outcome.is_partial_success` |

No short-name aliases are defined in v0. If needed, aliases are `source_alias` entries
per LANG-STDLIB-ENTRY-CONTRACT-P1 §4 (append-only, never in SIR).

---

## 12. Authority Boundary

The following are explicitly closed and must not be opened by any implementation
of this proposal:

| Surface | Status |
|---------|--------|
| Stdlib implementation (compiler/TC/SIR/VM) | CLOSED |
| Parser / typechecker changes | CLOSED |
| SemanticIR emission | CLOSED |
| VM / runtime | CLOSED |
| Generic `Outcome[T,E]` sealed type | CLOSED |
| Global `FailureKind` enum | CLOSED |
| Variant enforcement changes | CLOSED |
| Retry execution / scheduling | CLOSED |
| Routing helper (`route`) | CLOSED (rejected permanently) |
| Policy decisions in stdlib layer | CLOSED |
| Capability grants | CLOSED |
| External observation or mutation | CLOSED |
| Public compatibility promise | CLOSED (pre-v1-none) |
| OOF-OUT implementation | CLOSED (reserved; P2) |
| is_retryable final form | CLOSED (P2) |

---

## 13. Relationship to PROP-047

Each accepted helper maps to a PROP-047 stable term:

| Helper | PROP-047 Term | Section | Recovery axis | Forbidden-collapse rules |
|--------|--------------|---------|--------------|-------------------------|
| `is_denied` | `denied` | §2.1 | Axis-1 (capability_denial) | FC-1 (≠ query_error) |
| `is_unknown_external_state` | `unknown_external_state` | §2.5 | Axis-5 | FC-2 (≠ timed_out), FC-3 (≠ system_error) |
| `is_timed_out` | `timed_out` | §2.3 | Axis-4 | FC-2 (≠ unknown_external_state) |
| `is_system_error` | `system_error` | §2.4 | Axis-3 (external_unavailable) | FC-3 (≠ unknown_external_state) |
| `is_query_error` | `query_error` | §2.6 | Axis-2 (malformed_plan) | FC-1 (≠ denied) |
| `is_partial_success` | `partial_success` | §2.7 | Axis-6 | FC-4..FC-7 |
| `kind` | (accessor; all terms) | — | — | — |

### partial_success provenance

`partial_success` was promoted from axis-6 pattern to stable term by PROP-047-P2, after
LAB-FAILURE-TAXONOMY-P4 (54/54 PASS) proved cross-domain evidence in:
- Batch job processing (some items succeeded, some failed; per-item evidence)
- Multi-upstream HTTP (upstream-A ok, upstream-B error)

`is_partial_success` returning `true` does NOT mean the caller succeeded. It means
a bounded set of items was attempted with observed mixed results. Per-item evidence
must be inspected separately.

### PROP-047 axes not in v0

Axis-6 (partial_success) has a predicate. Axis-8 (compensation) and Axis-9 (retryable)
do not have v0 predicates. is_retryable (Axis-9) is deferred (§5 above). No compensation
helper is proposed.

---

## 14. Required Explicit Answers

| Question | Answer |
|---------|--------|
| Does v0 require generic `Outcome[T,E]`? | **No.** Input is `Map[String, String]` (KDR-like). No sealed wrapper. |
| Does v0 require variants? | **No.** Variants are separate (LAB-OUTCOME-VARIANT-P1..P3). Helpers work on KDR hashes. |
| Does `kind()` normalize or only read? | **Read only / passthrough.** Returns `outcome["kind"]` verbatim. No normalization. |
| Are domain-local kinds preserved? | **Yes.** All `is_*` helpers return `false` for non-matching kinds. `kind()` passes through unchanged. |
| Is `is_retryable` accepted now? | **Conditional / deferred.** Design candidate; context-record design required; deferred to P2. |
| Is `route` accepted? | **No.** Permanently rejected. Encodes policy = runtime authority. |
| Is `authority_surface` always `"none"`? | **Yes.** All v0 entries. |
| Are helpers pure? | **Yes.** No side effects, no state, no IO. |
| Does this open implementation? | **No.** Proposal only. Implementation planning requires LANG-STDLIB-OUTCOME-PROP-P2. |

---

## 15. Next Route

### P2 Gate Conditions

This proposal closes with PROPOSAL AUTHORED if:
- 7 accepted entries defined with full entry contract sketches ✓
- Conditional entry (is_retryable) clearly separated with P2 design options ✓
- Rejected entry (route) explicitly refused with rationale ✓
- Domain-local preservation rule stated ✓
- KDR/variant boundary established ✓
- Authority boundary closed ✓
- All 9 required explicit answers given ✓

### Recommended Next Route

**LANG-STDLIB-OUTCOME-PROP-P2** — Implementation Planning

Gates required before P2:
1. This proposal closes as PROPOSAL AUTHORED ✓ (this document)
2. LANG-STDLIB-ENTRY-CONTRACT-P2 (stdlib inventory planning) is closed ✓

P2 scope:
- Choose implementation form (pattern-match dispatch vs stdlib-inventory dispatch table)
- Resolve is_retryable context design (Option A/B/C from §6)
- Finalize OOF-OUT1..OOF-OUT4 trigger conditions
- Resolve missing-kind behavior (raise vs OOF-OUT1)
- Resolve input-type precision (Map[String,String] vs named record)
- Author entry contract records for `igniter-lang/docs/spec/stdlib-inventory.json`
- Proof matrix (≥50 checks targeting compiler + TypeChecker + SIR emission)
- Authorized files: typechecker.rb, semanticir_emitter.rb, stdlib-inventory.json

**Parallel optional track:** LAB-STDLIB-OUTCOME-P2 — retryability context proof,
if is_retryable context design (Option A/B/C) needs additional evidence before P2 locks.
