# Compiler Pack Boundary Report Decision v0

Card: S3-R90-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: compiler-pack-boundary-report-decision-v0
Route: UPDATE
Status: accepted-proof-only-shadow-profile-next-implementation-held
Date: 2026-05-20

---

## Decision

Accept the R90 compiler pack boundary report as a design map:

```text
accepted as design/report evidence
implementation remains held
```

Accepted report path:

```text
igniter-lang/docs/tracks/compiler-pack-boundary-report-v0.md
```

Accepted file-boundary disposition:

```text
Option A accepted: keep the R90 addendum in compiler-pack-boundary-report-v0.md
and preserve the S3-R31 body as historical foundation.
```

The report satisfies the R89 acceptance bar: it is descriptive, no-code,
accurate against current compiler/profile evidence, explicit about Spark lane
separation, clear about pass/fragment/OOF/proof/report responsibilities, and
protects the closed surfaces.

No implementation is authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/org/tracks/compiler-pack-boundary-report-r90-file-boundary-v0.md`
- `igniter-lang/docs/tracks/compiler-pack-boundary-report-v0.md`
- `igniter-lang/docs/tracks/compiler-pack-boundary-proof-fixture-and-oof-survey-v0.md`
- `igniter-lang/docs/discussions/compiler-pack-boundary-report-pressure-v0.md`
- `igniter-lang/docs/gates/compiler-mainline-next-axis-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round89-status-curation-v0.md`
- `igniter-lang/docs/cards/S3/S3-R90.md`
- `igniter-lang/docs/current-status.md`
- `igniter-lang/docs/org/portfolio-guidance-log-v0.md`

---

## Accepted Report Disposition

R90 C0-O selected:

```text
Option A: update compiler-pack-boundary-report-v0.md with a clearly marked R90
addendum section.
```

Architect accepts that disposition for R90.

Reason:

- R89 authorized the route name `compiler-pack-boundary-report-v0`.
- C1 landed a clearly marked `R90 Update` section at that exact path.
- The S3-R31 body remains visible as historical foundation.
- C2 explicitly records stale S3-R31 assumptions so they are not mistaken for
  current canon.
- C3 pressure confirms the file-boundary handling is clear enough for this
  round.

Non-blocking clarity notes from C3 are accepted as non-blocking:

1. The old S3-R31 migration-order text about not adding
   `compiler_profile_id` to `.igapp` is stale in isolation. Current R90 state is
   more precise: bounded optional PROP-036 source transport may emit
   `compiler_profile_id`, while mandatory transition, discovery/defaulting, and
   golden migration remain closed.
2. The S3-R31 handoff section at the bottom of the file is historical. The
   current authoritative section is the R90 addendum at the top.

No immediate cleanup card is required for those notes because C2 and this
decision record the distinction.

---

## Ch6 Disposition

Ch6 / CompilationReport spec-lag remains deferred.

Do not open Ch6 edits as the immediate next route.

Accepted Ch6 posture:

```text
recorded as spec-lag in R90 report
docs/spec edit deferred until after the next proof-only shadow-profile slice
```

Future candidate route, not opened now:

```text
ch6-compilation-report-profile-evidence-sync-v0
```

That future docs/spec route should stay docs-only and must not alter report
behavior, compiler output, public result shape, loader/report status, or
CompatibilityReport behavior.

---

## Authorized Next Route

Authorize only the next proof-only route:

```text
compiler-pack-shadow-profile-proof-v1
```

Route type:

```text
proof-only
no implementation
no live dispatch
no pack registry implementation
no `.igapp` mutation
```

Recommended owner:

```text
[Igniter-Lang Research Agent]
```

Goal:

```text
Refresh the existing shadow compiler profile proof against the current R90
boundary map, accepted PROP-032 assumptions state, PROP-036 bounded optional
profile source transport, and R84/R86 PROP-038 strict-terminal/spec-sync state,
without dispatching compiler passes through packs.
```

Allowed proof shape:

- define or update proof-local pack/profile metadata for the current monolithic
  compiler;
- include candidate pack entries for current R90 boundaries;
- represent OOF and fragment ownership as data only;
- represent current optional `compiler_profile_id` behavior accurately;
- prove or summarize that generated shadow profile data does not change parser,
  classifier, typechecker, SemanticIR, assembler, `.igapp`, CLI, loader/report,
  CompatibilityReport, runtime, or production behavior;
- produce a track doc and proof summary if the proof is executable.

---

## Exact Next Card Boundary

Immediate required next R90 card:

```text
Card: S3-R90-C5-S
Agent: [Igniter-Lang Status Curator]
Role: status-curator
Track: stage3-round90-status-curation-v0
Route: UPDATE

Goal:
Close R90 for Portfolio using the accepted C4-A decision and all R90 evidence.

Deliver:
- status-curation packet at
  igniter-lang/docs/tracks/stage3-round90-status-curation-v0.md
- compact executive summary
- completed card list
- changed files / evidence links
- risks and drift notes
- cross-lane requests, if any
- exact next route recommendation
```

Next allowed compiler card after R90 closes:

```text
Card: S3-R91-C1-P1
Agent: [Igniter-Lang Research Agent]
Role: research-agent
Track: compiler-pack-shadow-profile-proof-v1
Route: UPDATE

Goal:
Run the proof-only shadow compiler profile refresh authorized by
compiler-pack-boundary-report-decision-v0.

Scope:
- Read R90 C0/C1/C2/C3/C4 outputs.
- Read current compiler/profile architecture direction and accepted PROP-032,
  PROP-036, and PROP-038 decisions.
- Use current compiler files as read-only evidence.
- Define proof-local pack/profile metadata for the current monolithic compiler.
- Do not route compiler passes through packs.
- Do not implement `CompilerKernel`, pack registry, live dispatcher, or
  profile-assembled compiler.
- Do not mutate `.igapp`, goldens, public API/CLI, loader/report,
  CompatibilityReport, runtime, or production behavior.

Deliver:
- track doc in `igniter-lang/docs/tracks/`
- proof-local shadow profile map
- pack/profile metadata table
- OOF and fragment registry data sketch
- parity / non-mutation evidence
- stale S3-R31 assumption handling
- blockers before any implementation authorization
- closed-surface list
```

---

## Required Proof / Pressure Before Implementation

Implementation remains blocked until a later Architect decision sees:

1. `compiler-pack-shadow-profile-proof-v1` completed and pressure-reviewed.
2. Evidence that shadow profile data does not mutate compiler outputs, `.igapp`,
   public API/CLI, loader/report, CompatibilityReport, runtime, or production
   behavior.
3. A resolved OOF/fragment registry model or a deliberately deferred registry
   boundary.
4. A named implementation candidate with one bounded write scope.
5. Explicit preservation or replacement of accepted PROP-038 strict-terminal
   invariants.
6. A separate implementation authorization decision.

No implementation may be inferred from proof-local metadata.

---

## Portfolio Review

Portfolio review is required through normal R90 closure reporting:

```text
igniter-lang/docs/tracks/stage3-round90-status-curation-v0.md
```

No extra Portfolio decision is required before opening the proof-only
`compiler-pack-shadow-profile-proof-v1` route, provided C5-S closes R90 with
summary, evidence, risks, cross-lane requests, and next route.

If C5-S cannot satisfy Portfolio reporting fields, create:

```text
igniter-lang/docs/reports/s3-r90-round-report.md
```

---

## Preserved Closed Surfaces

This decision does not authorize:

- code implementation;
- compiler implementation;
- `CompilerKernel` implementation;
- pack registry implementation;
- live pack dispatch;
- profile-assembled compiler migration;
- parser rewrites;
- classifier rewrites;
- TypeChecker rewrites;
- SemanticIR rewrites;
- assembler rewrites;
- orchestrator rewrites;
- public API/CLI widening;
- public strict source;
- `IgniterLang.compile` signature changes;
- profile discovery/defaulting/finalization in public surfaces;
- mandatory `compiler_profile_id` transition;
- `.igapp` golden or manifest migration;
- `.ilk` profile references;
- CompilationReceipt links;
- loader/report compiler-profile status;
- CompatibilityReport compiler-profile section;
- compile refusal beyond the accepted internal-only strict terminal foundation;
- persisted strict terminal reports or sidecars;
- `CompilerResult` public shape changes;
- Ch6 or other spec edits in the immediate next route;
- RuntimeMachine or Gate 3 widening;
- Ledger/TBackend binding;
- BiHistory production evaluation;
- stream/OLAP production executors;
- production cache;
- signing or production verification;
- production deployment;
- progression scheduler/materializer/durable queue/checkpoint;
- Spark fixture/spec work;
- Spark production integration;
- treating Spark applied pressure as compiler authority.

---

## Compact Summary

R90 accepts the compiler pack boundary report as the current design map and
keeps the S3-R31 body as historical foundation. C3 pressure passes 7/7 with no
blockers. Ch6 sync remains deferred; the next route is not docs/spec work.

The exact next route after R90 closure is `compiler-pack-shadow-profile-proof-v1`
as proof-only work. It may define proof-local shadow profile metadata, but it
must not implement pack dispatch, mutate `.igapp`, widen public API/CLI, open
loader/report or CompatibilityReport, touch runtime, or authorize production.
