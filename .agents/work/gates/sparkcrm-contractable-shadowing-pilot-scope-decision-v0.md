# Spark CRM Contractable Shadowing Pilot Scope Decision v0

Card: S3-R87-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: sparkcrm-contractable-shadowing-pilot-scope-decision-v0
Route: UPDATE
Status: accepted-scope-letter-next-implementation-held
Date: 2026-05-20

---

## Decision

Accept the R87 Spark CRM contractable shadowing pilot scope.

Accepted first pilot target:

```text
AvailabilityLedger::SlotMap
```

Accepted pilot theme:

```text
why-not availability diagnostics
```

This decision does not authorize implementation.

---

## Evidence Read

- `igniter-lang/docs/org/tracks/sparkcrm-pilot-cross-lane-reporting-and-letter-boundary-v0.md`
- `igniter-lang/docs/tracks/sparkcrm-contractable-shadowing-pilot-scope-v0.md`
- `igniter-lang/docs/discussions/sparkcrm-contractable-shadowing-pilot-scope-pressure-v0.md`
- `igniter-lang/docs/gates/r86-spec-sync-and-spark-applicability-routing-decision-v0.md`
- `igniter-lang/docs/tracks/sparkcrm-igniter-adoption-readiness-map-v0.md`

---

## Accepted Scope

Architect accepts the C1 pilot scope as design/scope material only.

Accepted first mode:

```text
primary_observed_only
```

Accepted optional later mode:

```text
primary_observed_plus_shadow_candidate
```

The optional shadow candidate is not authorized now. It requires separate
implementation authorization.

Accepted design properties:

- primary Spark service remains the only authoritative decision source;
- shadowing is observation/diagnostics only;
- pilot remains design/scope unless a separate implementation gate opens;
- no production output or user-visible behavior changes are authorized;
- receipt data must use redacted refs and digests;
- raw customer, provider, technician, company, user-like, schedule, phone/email,
  endpoint, credential, and infrastructure payloads are forbidden in public docs,
  fixtures, sidecar examples, and cross-lane report material;
- receipt construction failures, receipt sink failures, missing receipts, and
  shadow candidate failures must be fail-open;
- missing receipt is an observability gap, not a business error;
- sampling must be default-off, opt-in, low-volume, and rate-limited;
- durable adapter readiness gates high-volume or production-adjacent rollout;
- Igniter Ledger sidecar remains optional/later and sandbox-only unless
  separately authorized;
- Igniter-Lang may receive only sanitized synthetic fixture/spec pressure.

---

## Target Selection

Architect accepts `AvailabilityLedger::SlotMap` over `OrderPriceLedger::Finder`
for the first pilot scope.

Rationale:

- availability why-not diagnostics have bounded user-facing explanation value;
- the initial receipt can reduce output to reason counts, digests, and redacted
  evidence refs;
- the target pressures existing availability fixture semantics without requiring
  pricing or order/customer context;
- `OrderPriceLedger::Finder` carries more commercial, scope-chain, and
  customer/order sensitivity and should remain later.

`OrderPriceLedger::Finder` remains a later candidate only. It is not authorized
as the first pilot by this decision.

---

## Implementation Preconditions

Any future implementation authorization card must satisfy the C1 17-item
checklist in full.

Architect also adds these pre-implementation requirements from C2 pressure notes:

1. Define the `service_ref` abstraction convention. It must not be a Ruby class
   name, file path, raw model name, or data-derived identifier. A stable abstract
   identifier such as `availability_slotmap_v0` is acceptable.
2. Define idempotency key generation and low-volume storage behavior before
   implementation. If no durable adapter exists, the implementation card must say
   where the key lives and whether collision detection is required.
3. Obtain Spark CRM lane confirmation before any implementation authorization.
   The pilot scope may be accepted now, but Spark operational acceptance gates
   implementation.
4. Keep `sparkcrm-availability-ledger-why-not-fixture-v0` as a recommended future
   Igniter-Lang fixture candidate only. It is not authorized by this decision.

---

## Cross-Lane Letter

Architect accepts that a cross-lane letter packet should be prepared and sent as
communication / handoff / request material.

Accepted letter path:

```text
igniter-lang/docs/org/letters/sparkcrm-contractable-shadowing-pilot-scope-letter-v0.md
```

The letter may ask:

- Spark CRM lane to confirm whether `AvailabilityLedger::SlotMap` is acceptable
  for a low-volume, fail-open, primary-observed-only pilot;
- Igniter Ruby Framework lane to review future package support for contractable
  observed wrappers, redaction defaults, digest helpers, sampling gates,
  fail-open receipts, and durable observation adapter;
- Igniter Ledger sidecar lane to treat receipt sink work as optional/later and
  not source-of-truth;
- Igniter-Lang lane to use only sanitized synthetic fixture/spec pressure.

Letter boundary:

```text
letter = communication / handoff / request
letter != decision
letter != Portfolio close report
letter != implementation authorization
letter != canon
```

The letter must not authorize code work or cross-lane commitments by itself.

---

## Pressure Result

R87-C2-X verdict:

```text
proceed
checks: 11/11 PASS
blockers: none
non-blocking notes: 4
```

Architect accepts the pressure result.

Accepted disposition of non-blocking notes:

1. `service_ref` abstraction convention: required in future implementation card.
2. idempotency key details without durable adapter: required in future
   implementation card.
3. Spark lane confirmation: not required for design acceptance; required before
   implementation authorization.
4. `sparkcrm-availability-ledger-why-not-fixture-v0`: recommendation only; it
   requires a separate round/card before any fixture work opens.

---

## Preserved Closed Surfaces

This decision does not authorize:

- pilot implementation;
- Spark CRM code inspection;
- Spark CRM code edits;
- Spark production integration;
- Spark production behavior changes;
- Spark primary-ledger replacement;
- real Spark data, endpoints, credentials, provider payloads, customer records,
  technician/user raw records, phone/email data, or infrastructure details in
  docs, fixtures, receipts, reports, or sidecar examples;
- Igniter Ruby Framework code edits;
- Igniter Ledger code edits;
- Igniter Ledger as primary Spark database;
- production TBackend/Ledger binding for Spark;
- automatic Spark-to-Igniter migration;
- Igniter-Lang compiler/runtime code edits;
- Igniter-Lang runtime execution of Spark decisions;
- public `.igapp` operational policy deployment for Spark;
- public API or CLI widening;
- loader/report behavior;
- CompatibilityReport behavior;
- parser, TypeChecker, SemanticIR, assembler, `.igapp`, `.ilk`, signing,
  dispatch, RuntimeMachine/Gate 3, stream/OLAP, cache, or production widening;
- treating a cross-lane letter as a decision, report packet, canon, or
  implementation authorization.

---

## Next Route

Immediate required next card:

```text
S3-R87-C4-S
```

Status Curator must close R87 for Portfolio with:

```text
igniter-lang/docs/tracks/stage3-round87-status-curation-v0.md
```

Fallback report packet, only if the status-curation track cannot satisfy the
active Portfolio reporting protocol:

```text
igniter-lang/docs/reports/s3-r87-round-report.md
```

Authorized follow-up route after R87 status curation:

```text
sparkcrm-contractable-shadowing-pilot-scope-letter-v0
```

Boundary:

- communication/request letter only;
- no implementation;
- no Spark code access or edits;
- no Ruby Framework implementation;
- no Ledger sidecar implementation;
- no Igniter-Lang fixture/spec implementation;
- no production behavior.

Future implementation authorization may be considered only after the letter path
or equivalent cross-lane confirmation establishes Spark lane acceptance and the
future implementation card satisfies the accepted checklist and preconditions.
