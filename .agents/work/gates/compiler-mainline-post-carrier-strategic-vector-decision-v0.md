# Compiler Mainline Post-Carrier Strategic Vector Decision v0

Card: S3-R156-C1-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: compiler-mainline-post-carrier-strategic-vector-decision-v0
Depends on: S3-R155-C2-A, S3-R155-C3-S
Status: docs-spec-sync-next
Date: 2026-05-23

---

## Decision

Pause compiler/profile implementation lanes and open a docs/spec sync route.

The bounded `IgniterLang::InternalProfileStaticDataCarrier` implementation is
accepted and the source-mode/static-data carrier lane is paused. The next safe
compiler-mainline route is not another implementation, not adapter continuation,
not report/artifact/CompatibilityReport design, not Spark fixture/spec work, and
not demo readiness.

The next route should synchronize the accepted internal-only carrier boundary
into the compiler/profile docs and status surfaces without adding semantics.

No implementation is authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/gates/compiler-profile-source-mode-static-data-internal-carrier-implementation-acceptance-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round155-status-curation-v0.md`
- `igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-internal-carrier-implementation-v0.md`
- `igniter-lang/docs/gates/compiler-mainline-strategic-vector-decision-v0.md`
- `igniter-lang/docs/tracks/compiler-profile-architecture-reentry-map-v0.md`
- `igniter-lang/docs/current-status.md`
- `/Users/alex/dev/projects/sparkcrm/.agents/spark-app/reports/PORT-2026-05-23-SPARK-ORDERS-ANALYTICS-MAP-P1.md`

---

## Route Assessment

| Candidate route | Decision | Reason |
| --- | --- | --- |
| Pause implementation lanes and open docs/spec sync | Selected. | R155 accepted a real internal helper class. Before any new axis widens authority, docs/spec/status should reflect the exact internal-only boundary and preserved closed surfaces. |
| Design-only next carrier/assembly boundary | Not selected. | The carrier lane reached bounded closure and should pause. A next carrier/assembly boundary would create momentum toward more implementation without a fresh need. |
| Adapter continuation design-only | Not selected. | Adapter lane remains paused. Classifier wiring/live dispatch/report parity remain semantic authority questions and should not reopen immediately after carrier closure. |
| Report/artifact/CompatibilityReport design-only | Not selected now. | Not mature enough. Internal carrier accepted, but no public/report carrier, loader/report ownership, artifact identity, or CompatibilityReport section is stable enough to design next without first syncing docs and drift. |
| Spark sanitized-pressure intake design-only | Not selected now. | Spark Orders Analytics is useful applied pressure, but vendor/bid/cancel evidence gaps make fixture/spec pressure premature. |
| Release/demo-readiness map without implementation | Not selected. | Demo-shadow remains held. No manager-facing narrative or demo artifact should open from internal carrier closure. |
| Hold for Portfolio review | Not selected. | Portfolio review is not required for docs/spec sync only. It is required before implementation or public/report/artifact/Spark/runtime/demo widening. |

---

## Explicit Answers

### Should The Source-Mode / Static-Data Internal Carrier Lane Remain Paused?

Yes.

The carrier lane is accepted and closed. `InternalProfileStaticDataCarrier`
should remain a bounded direct-require-only internal carrier/test seam. No
additional carrier implementation, proof hardening, or assembly boundary route
opens from this decision.

### Should `InternalProfileStaticDataCarrier` Stay Direct-Require-Only?

Yes.

It must remain outside `igniter-lang/lib/igniter_lang.rb`, public API/CLI,
compiler pipeline, reports, artifacts, runtime, Spark, production, and demo
surfaces.

### Is Any Public / Report / Artifact Route Mature Enough To Design Next?

No.

Report/artifact/CompatibilityReport work is not mature enough to lead next.
The accepted carrier is internal-only and intentionally excludes report,
loader, manifest, artifact hash, CompatibilityReport, and public discovery
authority. Opening report/artifact design now would force public-ish carrier
shape decisions before documentation and boundary language are stabilized.

### Should Spark Orders Analytics Pressure Become Sanitized Fixture / Spec Pressure?

No.

Spark Orders Analytics Map P1 remains external applied pressure only.

Accepted pressure reading:

- order/call/service-call coverage is strong enough for read-side exploration;
- TradeVendor coverage is incomplete;
- bid evidence is incomplete;
- cancellation reason coverage is historically sparse;
- the Spark surface is read-only and Spark authority remains unchanged.

This pressure may inform future evidence-layer questions, but it does not
authorize Spark access, raw vocabulary ingestion, fixture creation, spec
mutation, compiler changes, production integration, or demo work.

### Should Demo-Shadow Remain Held?

Yes.

No demo lane, demo fixture, demo artifact, Spark demo, production-facing
scenario, manager-facing narrative, release-readiness map, or public narrative
artifact is opened by this decision.

### Is Portfolio Review Needed Before The Next Route?

No, not for the selected docs/spec sync route if it stays docs-only and does
not add semantics.

Portfolio review is required before any later route opens:

- implementation;
- root require;
- compiler pipeline integration;
- public API/CLI widening;
- loader/report or CompatibilityReport;
- manifest, sidecar, artifact hash, `.igapp`, `.ilk`, or golden migration;
- shared fixtures or generated indexes;
- PROP-036 or PROP-038 mutation;
- Spark-derived fixtures/specs or Spark integration;
- runtime, production, deployment, signing, cache, Ledger/TBackend, BiHistory,
  stream/OLAP, or demo behavior.

---

## Exact Next Allowed Boundary

Open exactly one next route:

```text
Card: S3-R156-C2-P1
Agent: [Igniter-Lang Status Curator / Docs]
Role: status-curator
Track: compiler-profile-internal-carrier-docs-spec-sync-v0
Route: UPDATE
Mode: docs/spec sync only
```

Goal:

Synchronize docs/status language after accepted
`IgniterLang::InternalProfileStaticDataCarrier` closure, preserving the
internal-only boundary and closed-surface list without adding semantics or
authorizing new work.

Required read set:

- `igniter-lang/docs/gates/compiler-profile-source-mode-static-data-internal-carrier-implementation-acceptance-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round155-status-curation-v0.md`
- `igniter-lang/docs/tracks/compiler-profile-source-mode-static-data-internal-carrier-implementation-v0.md`
- `igniter-lang/docs/current-status.md`
- relevant docs/index pages that mention compiler/profile source-mode,
  static-data, internal profile assembly, report/artifact status, or Stage 3
  compiler internals.

Allowed write scope:

```text
igniter-lang/docs/current-status.md
igniter-lang/docs/tracks/README.md
igniter-lang/docs/gates/README.md
igniter-lang/docs/tracks/compiler-profile-internal-carrier-docs-spec-sync-v0.md
```

If the docs-sync agent finds a specific spec/chapter page that contains stale
language about source-mode/static-data, internal carrier status, or public
carrier closure, it may propose that page in the track but must not edit it
without a separate explicit route unless it is already clearly within a local
docs/spec sync convention.

Required output:

- exact docs changed;
- stale language found and corrected;
- stale language found but held;
- confirmation that no semantics, code, proposal/canon mutation, public/report
  carrier, artifact, Spark, runtime, production, or demo behavior was added;
- recommended next compiler-mainline route or pause.

Not authorized:

- code changes;
- implementation;
- root require;
- classifier wiring or live dispatch;
- parser, TypeChecker, SemanticIR, assembler, report, `.igapp`;
- public API/CLI;
- loader/report;
- CompatibilityReport;
- manifest, sidecar, artifact hash, golden migration;
- shared fixtures;
- generated indexes;
- embedded internal library static registry rows;
- PROP-036 or PROP-038 mutation;
- Spark access, fixtures, specs, integration, or production pressure;
- runtime, production, Ledger/TBackend, BiHistory, stream/OLAP, cache, signing,
  deployment, or demo work.

---

## Preserved Closed Surfaces

This decision preserves closed:

- root require;
- classifier wiring or live classifier dispatch;
- `contract_fragment_for` replacement;
- parser, TypeChecker, SemanticIR, assembler, report, `.igapp`;
- `ClassifiedProgram` schema changes;
- public API/CLI;
- loader/report;
- `CompilationReport`, `CompilerResult`, CompatibilityReport;
- manifest, sidecar, artifact hash, golden migration;
- shared fixtures;
- generated indexes;
- embedded internal library static registry rows;
- PROP-036 or PROP-038 mutation;
- Spark access, fixtures, specs, integration, or production pressure;
- runtime, production, Ledger/TBackend, BiHistory, stream/OLAP, cache, signing,
  deployment, demo work.

---

## Compact Summary

[D] Select docs/spec sync as the next compiler-mainline route.

[S] Carrier lane remains paused. `InternalProfileStaticDataCarrier` stays
direct-require-only and internal. Public/report/artifact routes are not mature
enough. Spark Orders Analytics remains external applied pressure. Demo-shadow
remains held.

[T] Gate decision doc only. No implementation authorized.

[R] Next route is exactly S3-R156-C2-P1
`compiler-profile-internal-carrier-docs-spec-sync-v0`, docs/spec sync only.
