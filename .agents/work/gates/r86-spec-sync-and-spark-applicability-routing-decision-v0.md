# R86 Spec Sync And Spark Applicability Routing Decision v0

Card: S3-R86-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: r86-spec-sync-and-spark-applicability-routing-decision-v0
Route: UPDATE
Status: accepted-spec-sync-spark-routed
Date: 2026-05-20

---

## Decision

Accept the R86 PROP-038 spec sync.

Route the Spark CRM Ledger x Igniter applicability report as an active
applied-pressure source for Igniter Ruby framework, Igniter Ledger sidecar
research, and Igniter-Lang fixture/spec work.

This decision does not authorize new implementation.

---

## Evidence Read

- `igniter-lang/docs/org/tracks/sparkcrm-inbox-disposition-and-pressure-routing-v0.md`
- `igniter-lang/docs/tracks/prop038-strict-refusal-spec-chapter-sync-v0.md`
- `igniter-lang/docs/tracks/sparkcrm-igniter-adoption-readiness-map-v0.md`
- `igniter-lang/docs/discussions/r86-spec-sync-and-spark-applicability-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-strict-refusal-canon-sync-acceptance-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round85-status-curation-v0.md`
- `igniter-lang/docs/inbox/sparkcrm-ledger-igniter-applicability-analysis-2026-05-20.md`

---

## PROP-038 Spec Sync

Architect accepts `prop038-strict-refusal-spec-chapter-sync-v0`.

Accepted changed docs:

| Path | Accepted status |
| --- | --- |
| `igniter-lang/docs/spec/ch5-compiler-pipeline.md` | Accepted. Ch5 now records the R84 internal compiler/orchestrator strict terminal path and no longer implies every strict terminal writes a report or assembles. |
| `igniter-lang/docs/spec/ch7-runtime.md` | Accepted. Ch7 now records that PROP-038 strict refusal is not a RuntimeMachine surface. |
| `igniter-lang/docs/language-spec.md` | Accepted. The index now reflects PROP-038 strict refusal as an internal compiler foundation and non-runtime boundary. |
| `igniter-lang/docs/tracks/prop038-strict-refusal-spec-chapter-sync-v0.md` | Accepted. |

Accepted canon after sync:

```text
internal strict requirement source
  -> orchestrator-level strict requirement decision path
  -> report-only compiler_profile_contract_validation evidence
  -> non-persisting strict terminal CompilerResult when selected
```

The sync preserves:

- strict source remains internal constructor/test seam only;
- validator output remains evidence, not refusal authority;
- nested `compile_refusal_authorized: false` remains report-only evidence;
- `report.pass_result == "ok"` remains invariant for strict terminal paths;
- strict terminal paths write no sidecar, no report artifact, no `.igapp`, and
  do not call assembler;
- public API/CLI, loader/report, CompatibilityReport, RuntimeMachine/Gate 3,
  runtime, and production remain closed.

Optional future gap:

```text
Ch6 SemanticIR / CompilationReport may later mention nested
compiler_profile_contract_validation evidence.
```

This is not required for R86 because strict terminal authority is
orchestrator/result-level, not SemanticIR-level.

---

## Spark CRM Disposition

Architect accepts the Spark CRM report routing as:

```text
active applied-pressure source
Ruby framework adoption pressure
Igniter Ledger sidecar pressure
Igniter-Lang fixture/spec pressure
not canon
not implementation authority
not Spark CRM production authority
```

Accepted lifecycle status:

```text
promoted-track / active applied-pressure source
```

The source may remain in inbox while it actively feeds the readiness map and
pilot scoping work. After those close, it should be archived as source material
with links preserved from the owning tracks.

---

## Spark Readiness Map

Architect accepts `sparkcrm-igniter-adoption-readiness-map-v0` as a roadmap and
pressure map, not as implementation authority.

Accepted near-term Spark posture:

```text
observe existing Spark services
  -> shadow/compare candidate contracts
  -> emit redacted receipts
  -> optionally sink receipts to sidecar Ledger
  -> use Igniter-Lang fixtures to formalize semantics
```

Accepted "now" lane:

- contractable shadowing of existing Spark ledger finders/services;
- observed wrappers around recorder/finder flows;
- redacted receipt vocabulary;
- synthetic Igniter-Lang fixtures/spec pressure.

Accepted "next" lane:

- Rails-first contractable adoption kit;
- Sidekiq/ActiveJob durable observation adapter;
- optional sidecar `ContractableReceiptSink`;
- fractal price ledger fixture;
- effective-interval / active-at fixture and spec delta.

Accepted "later" lane:

- sanitized mirror of selected ledger facts into Igniter Ledger;
- `.igapp` as reviewable policy artifact only after production runtime/TBackend
  readiness is separately established.

---

## Spark First Pilot Boundary

Architect accepts `sparkcrm-contractable-shadowing-pilot-v0` as the next
candidate route, but does not authorize implementation in this decision.

Allowed next route:

```text
sparkcrm-contractable-shadowing-pilot-scope-v0
```

Allowed next card boundary:

```text
Card: S3-R87-C1-P1
Agent: [Igniter-Lang Bridge Agent]
Role: bridge-agent
Track: sparkcrm-contractable-shadowing-pilot-scope-v0

Goal:
Design the first bounded Spark CRM contractable shadowing pilot without
implementing it.

Scope:
- Read the R86 decision and readiness map.
- Choose or compare the first pilot target:
  - Option A: AvailabilityLedger::SlotMap for why-not availability reasons;
  - Option B: OrderPriceLedger::Finder for chain winner explanation.
- Define:
  - primary service remains authoritative;
  - redacted receipt shape;
  - input/output digest policy;
  - no raw customer/provider payload policy;
  - sampling gate;
  - missing-receipt fail-open behavior;
  - durable adapter dependency before high-volume rollout;
  - optional Igniter Ledger sidecar boundary;
  - proof/parity evidence required before implementation.
- Do not inspect private Spark CRM code unless separately authorized.
- Do not edit Spark CRM code.
- Do not edit Igniter Ruby framework code.
- Do not authorize production behavior changes.

Deliver:
- Track doc in `igniter-lang/docs/tracks/`
- Recommended pilot target and rationale
- Exact implementation authorization checklist
- Closed-surface list
```

Suggested pressure follow-up:

```text
Card: S3-R87-C2-X
Agent: [Igniter-Lang External Pressure Reviewer]
Role: external-pressure-reviewer
Borrowed lens: product-pressure
Track: sparkcrm-contractable-shadowing-pilot-scope-pressure-v0
```

---

## Pressure Result

R86-C3-X verdict:

```text
proceed
checks: 12/12 PASS
blockers: none
non-blocking notes: 4
```

Architect accepts the pressure result.

Accepted non-blocking notes:

1. `sparkcrm-contractable-shadowing-pilot-v0` is a recommendation, not an
   authorization. This decision preserves that boundary by routing only pilot
   scope/design work next.
2. Ch6 spec sync may be useful later, but is optional and not required for R86.
3. Spark class/service names in the readiness map are internal applied-pressure
   material. If any document is shared externally, those names must be abstracted
   or removed.
4. Durable observation adapter is required before production-adjacent receipt
   volume. Very-low-volume/sampled pilot design may proceed, but expansion must
   gate on durable adapter readiness.

---

## Preserved Closed Surfaces

This decision does not authorize:

- new compiler implementation;
- Spark CRM code edits;
- Spark production integration;
- Spark primary-ledger replacement;
- real Spark data, endpoints, credentials, provider payloads, customer records,
  phone/email data, or infrastructure details in public docs/fixtures;
- Igniter-Lang runtime execution of Spark decisions;
- Igniter Ledger as primary Spark DB;
- production TBackend/Ledger binding for Spark;
- public `.igapp` operational policy deployment for Spark;
- automatic migration of Spark ledgers to Igniter Ledger;
- public API or CLI widening;
- `IgniterLang.compile` signature changes;
- env/config/manifest/default/generated strict source lookup;
- loader/report strict source or status;
- CompatibilityReport strict source or status;
- persisted refusal reports;
- sidecars from PROP-038 strict terminal paths;
- `.igapp` mutation or golden migration;
- parser changes;
- TypeChecker changes;
- SemanticIR changes;
- assembler changes;
- `CompilationReport` changes;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`;
- receipts beyond a separately authorized Spark pilot design/implementation;
- signing;
- dispatch migration;
- RuntimeMachine or Gate 3 widening;
- BiHistory production binding;
- stream/OLAP;
- cache;
- production behavior.

---

## Next Strategic Route

Immediate required next card:

```text
S3-R86-C5-S
```

Status Curator should update the R86 status map and preserve the Spark inbox
disposition.

Authorized follow-up route, if the next round chooses to pursue Spark pressure:

```text
sparkcrm-contractable-shadowing-pilot-scope-v0
```

This is design/scope only. Implementation remains held pending a separate
Architect authorization decision.
