# Compiler Mainline Strategic Vector Decision

Status: adapter-lane-paused-compiler-profile-architecture-reentry-next
Date: 2026-05-23
Card: S3-R150-C1-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: compiler-mainline-strategic-vector-decision-v0
Depends on: S3-R149-C3-A, S3-R149-C4-S

---

## Decision

Pause the fragment registry adapter lane.

Do not open classifier wiring, live classifier dispatch, SemanticIR/report/
`.igapp` parity work, Spark fixture/spec work, or demo work next.

Return the compiler-mainline lane to compiler/profile architecture with a
design/report-only reentry map:

```text
compiler-profile-architecture-reentry-map-v0
```

This route should map the next compiler/profile architecture axis after the
adapter helper reached accepted implementation and accepted proof hygiene. It
must not implement anything.

---

## Evidence Read

- `igniter-lang/docs/gates/fragment-registry-compatibility-adapter-helper-proof-hygiene-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/fragment-registry-compatibility-adapter-helper-implementation-acceptance-decision-v0.md`
- `igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-helper-proof-hygiene-v0.md`
- `igniter-lang/docs/tracks/stage3-round149-status-curation-v0.md`
- `igniter-lang/docs/current-status.md`
- `/Users/alex/dev/projects/sparkcrm/.agents/spark-app/reports/PORT-2026-05-23-SPARK-SC-LEDGER-L3B.md`

---

## Route Choice

Selected next route:

```text
pause adapter lane and return to compiler/profile architecture
```

Reason:

- R147/R148/R149 completed the bounded helper path: implementation accepted,
  proof hygiene accepted, root require and classifier wiring still closed.
- Continuing directly into classifier wiring would be a semantic authority
  jump: the helper is ready as an internal direct-require utility, but no live
  dispatch owner, carrier, report/artifact exposure, or acceptance policy has
  been selected.
- SemanticIR/report/`.igapp` parity design is also premature until the lane
  decides whether adapter semantics should ever become compiler-carried state,
  or remain a proof/internal utility.
- The broader Stage 3 compiler-mainline backlog still has compiler/profile
  architecture pressure: profile discovery/defaulting/finalization, static data
  and source-mode surfaces, loader/report, CompatibilityReport, dispatch,
  runtime, production, receipts, signing, and golden migration remain blocked.

The next route should therefore re-map the compiler/profile architecture axis
before choosing any adapter continuation.

---

## Explicit Answers

### Should The Fragment Registry Adapter Lane Continue Now?

No. Pause it now.

The adapter lane has reached a natural bounded closure:

```text
helper boundary proof accepted
helper implementation accepted
proof hygiene accepted
root require closed
classifier wiring closed
live dispatch closed
```

Any further adapter work would require a new design-level authority decision,
not another incremental proof/implementation slice.

### If Continuing, Why The Chosen Route Is Next?

The adapter lane is not continuing immediately.

The chosen route is next because compiler/profile architecture is the higher
order decision layer that can decide whether later work should be:

- classifier-wiring design-only;
- SemanticIR/report/`.igapp` parity design-only;
- source-mode/static-data continuation;
- compiler/profile contract or source-finalization work;
- applied-pressure intake;
- or a hold.

This prevents helper implementation momentum from silently becoming live
compiler authority.

### Does Spark L3B Change Priority?

No. Spark L3B remains external applied pressure only.

Accepted interpretation:

- base service-call parity is expected-match pressure;
- override divergences are semantic-pressure candidates;
- concentrated Zone/Service override differences are business-design signals,
  not automatic compiler requirements;
- one suspected bug and one missing-data/modeling signal remain Spark-side
  follow-up pressure;
- the report supports the future Igniter story of a candidate evidence layer
  before authority switch, but does not create a Lang implementation route.

No Spark code/data access, Spark fixture creation, Lang spec/proposal mutation,
compiler work, production integration, or Spark production behavior is
authorized.

### Does Demo-Shadow Change Anything Now?

No.

Demo-shadow remains a note only. No demo lane, demo fixture, demo artifact,
Spark demo, production-facing scenario, or public narrative artifact is opened
by this decision.

### Which Implementation Surfaces Remain Closed?

Closed:

- implementation;
- root require from `igniter-lang/lib/igniter_lang.rb`;
- classifier wiring or live classifier dispatch;
- direct `contract_fragment_for` replacement;
- parser, TypeChecker, SemanticIR, assembler, or `.igapp` edits;
- `ClassifiedProgram` schema changes;
- public API/CLI widening;
- loader/report;
- `CompilationReport`, `CompilerResult`, or CompatibilityReport changes;
- `.igapp`, `.ilk`, manifest, sidecar, artifact hash, or golden mutation;
- PROP-036 or PROP-038 mutation;
- runtime, Spark, production;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, signing, or deployment
  behavior;
- demo work.

---

## Next Allowed Boundary

Card: S3-R151-C1-D

Track:

```text
compiler-profile-architecture-reentry-map-v0
```

Route: UPDATE

Mode: design/report only

Goal:

Create a compact compiler/profile architecture reentry map after the fragment
registry adapter helper closure, choosing what architecture axis should be
prepared next without authorizing implementation.

Required read set:

- `igniter-lang/docs/tracks/stage3-round149-status-curation-v0.md`
- `igniter-lang/docs/current-status.md`
- latest compiler/profile gates around PROP-036 and PROP-038;
- latest internal profile assembly/source packet gates and tracks;
- latest OOF/fragment registry helper closure gates;
- Spark L3B report as applied pressure only.

Required output:

- map open compiler/profile architecture axes;
- identify which are adapter-continuation candidates and which are profile/
  source-mode/static-data candidates;
- recommend one next bounded route: design-only, proof-only, docs-only, or
  authorization-review;
- preserve closed-surface list;
- explicitly state whether Portfolio review is needed before any implementation
  or public/report/artifact route.

Allowed write scope:

```text
igniter-lang/docs/tracks/compiler-profile-architecture-reentry-map-v0.md
```

Optional status/index updates may be performed by a later status-curation card,
not by this route unless separately authorized.

Not authorized:

- implementation;
- root require;
- classifier wiring or live classifier dispatch;
- parser, TypeChecker, SemanticIR, assembler, report, `.igapp`, public API/CLI,
  loader/report, CompatibilityReport;
- Spark fixture/spec/compiler work;
- runtime, production, demo work, Ledger/TBackend, BiHistory, stream/OLAP,
  cache, signing, deployment;
- spec/proposal/canon mutation.

---

## Not Selected

Classifier-wiring design-only route:

```text
not selected now
```

Reason: wiring would be a live compiler authority question and should be judged
against the broader profile/source/report architecture first.

SemanticIR/report/`.igapp` parity design route:

```text
not selected now
```

Reason: parity design is premature until the lane decides whether selected
fragment projection should ever become compiler-carried state.

Source-mode/static-data axis continuation:

```text
not selected directly
```

Reason: it is a likely candidate inside the reentry map, but should be compared
against profile architecture and adapter-continuation options before being
opened.

Applied Spark fixture/spec-pressure route:

```text
not selected now
```

Reason: Spark L3B is external applied pressure, not a Lang fixture/spec
authorization. Override divergences are semantic candidates requiring Spark-side
business classification before Lang can responsibly model them.

Portfolio hold:

```text
not required
```

Reason: no cross-lane conflict or implementation/public surface is opened by
this decision. Portfolio review may be required later if the reentry map
recommends implementation, public/report/artifact exposure, or Spark-derived
fixture/spec work.

---

## Compact Summary

PAUSE the adapter lane.

Spark L3B strengthens the evidence-layer framing but remains applied pressure
only. The next compiler-mainline route is design/report-only:
`compiler-profile-architecture-reentry-map-v0`.

No implementation, root require, classifier wiring, live dispatch, public
surface, report/artifact route, runtime, Spark, production, or demo work is
authorized.
