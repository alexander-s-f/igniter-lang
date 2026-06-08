# Compiler Mainline Next Axis Decision v0

Card: S3-R89-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: compiler-mainline-next-axis-decision-v0
Route: UPDATE
Status: accepted-design-report-next-implementation-held
Date: 2026-05-20

---

## Decision

Accept the recommended compiler mainline route:

```text
compiler-pack-boundary-report-v0
```

Route type:

```text
design/report-only
no implementation
no proof-local behavior unless a later card explicitly opens it
```

This route is accepted because R89 C0-O, C1-P1, C2-P1, and C3-X converge on the
same conservative next move: map the current proof compiler and accepted
compiler/profile foundations into candidate Profile/Baseline/Pack boundaries
before any dispatch, loader/report, CompatibilityReport, public API/CLI, or
runtime-facing route is scoped.

Implementation remains held.

---

## Evidence Read

- `igniter-lang/docs/org/tracks/compiler-mainline-reentry-boundary-map-v0.md`
- `igniter-lang/docs/tracks/compiler-mainline-next-axis-options-v0.md`
- `igniter-lang/docs/tracks/compiler-mainline-touchpoint-and-proof-gap-survey-v0.md`
- `igniter-lang/docs/discussions/compiler-mainline-next-axis-pressure-v0.md`
- `igniter-lang/docs/org/portfolio-guidance-log-v0.md`
- `igniter-lang/docs/cards/S3/S3-R89.md`
- `igniter-lang/docs/cards/S3/S3.md`
- `igniter-lang/docs/current-status.md`

---

## Findings

R89 confirms that the compiler mainline can proceed independently from the
Spark applied-pressure lane.

Spark remains relevant as pressure and future sanitized fixture vocabulary only.
It does not provide compiler authority, fixture authorization, runtime
authority, or implementation authorization for this decision.

Accepted compiler/profile foundation before this decision:

```text
PROP-036 compiler_profile_id/source transport
PROP-038 compiler_profile_contract vocabulary
internal validator and report-only evidence
contract_digest policy and live internal validator coverage
bounded internal-only strict terminal foundation
PROP-038 canon/spec sync through Ch5/Ch7/language-spec
```

Still missing before larger compiler architecture moves:

```text
pack boundary map
profile slot and pass ownership map
OOF / fragment / proof fixture ownership map
explicit migration risk table
must-not-migrate-yet list
later proof slice recommendations
```

The recommended route fills that mapping gap without code movement.

---

## Authorized Next Route

The next route after R89 closure is:

```text
compiler-pack-boundary-report-v0
```

Allowed route type:

```text
design/report-only
```

Allowed owner:

```text
[Igniter-Lang Compiler/Grammar Expert]
```

Allowed goal:

```text
Map the current proof compiler, accepted PROPs, OOF registries, fragment
classes, pass responsibilities, SemanticIR/assembler surfaces, proof fixtures,
and known report/strict-refusal evidence into candidate Profile/Baseline/Pack
boundaries without moving code.
```

Allowed deliverables:

- pack boundary table, including candidate packs such as:
  `CoreLanguagePack`, `TemporalPack`, `StreamPack`, `OLAPPack`,
  `InvariantPack`, `ContractModifiersPack`, `AssumptionsPack`,
  `EvidenceObservationPack`, and `Pipeline/ProfilePack`;
- owner map for parser, classifier, TypeChecker, SemanticIR, assembler, report,
  and strict-refusal responsibilities;
- OOF ownership map aligned with accepted PROP-038 strict registries;
- fragment-class owner map;
- proof/golden fixture map per candidate pack;
- migration risk table;
- explicit `must_not_migrate_yet` list;
- later proof-slice recommendations;
- Ch6 / CompilationReport spec-lag disposition section.

The Ch6 / CompilationReport item is resolved as follows:

```text
include Ch6 sync disposition inside the pack boundary report as a spec-lag
section; do not edit Ch6 in this route.
```

The report should say what Ch6 likely needs later, especially around nested
`compiler_profile_contract_validation`, report-only invariants, assembler report
isolation, and non-persisting strict terminal results. Actual Ch6 edits require
a separate later docs/spec card.

---

## Exact Card Boundary

Immediate required next R89 card:

```text
Card: S3-R89-C5-S
Agent: [Igniter-Lang Status Curator]
Role: status-curator
Track: stage3-round89-status-curation-v0
Route: UPDATE

Goal:
Close R89 for Portfolio using the accepted C4-A decision and R89 evidence.

Deliver:
- status-curation packet at
  igniter-lang/docs/tracks/stage3-round89-status-curation-v0.md
- compact executive summary
- completed card list
- changed files / evidence links
- risks and drift notes
- cross-lane requests, if any
- exact next route recommendation
```

Next allowed compiler mainline card after R89 closes:

```text
Card: S3-R90-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: compiler-pack-boundary-report-v0
Route: UPDATE

Goal:
Produce the no-code compiler pack boundary report authorized by
compiler-mainline-next-axis-decision-v0.

Scope:
- Read R89 C0/C1/C2/C3/C4 outputs.
- Read current compiler/profile architecture direction and accepted PROP-036 /
  PROP-038 decisions.
- Map current compiler files, proof fixtures, OOF registries, fragment classes,
  report-only evidence, and strict terminal behavior into candidate
  Profile/Baseline/Pack boundaries.
- Include a Ch6 / CompilationReport spec-lag disposition section.
- Do not edit code.
- Do not edit Ch6 or other specs.
- Do not authorize implementation.

Deliver:
- track doc in igniter-lang/docs/tracks/
- pack boundary table
- pass/owner map
- OOF and fragment ownership map
- proof fixture map
- migration risk table
- must-not-migrate-yet list
- recommended later proof/design slices
- closed-surface list
```

No parallel backup route is opened by this decision.

The backup route remains visible only:

```text
prop038-strict-terminal-regression-hardening-v0
```

It may open later only if specific pressure requires closing the R83/R84
ordinary success-path instrumentation asymmetry before or after the pack
boundary report.

---

## Acceptance Bar For The Next Route

Proceed if the report:

- remains descriptive and no-code;
- maps current evidence accurately;
- preserves Spark/compiler lane separation;
- names pass, fragment, OOF, proof, and report responsibilities clearly;
- includes migration risks and a strong `must_not_migrate_yet` list;
- preserves all closed surfaces.

Hold if the report implies or starts:

- live pack dispatch;
- pack registry implementation;
- parser/classifier/TypeChecker/SemanticIR/assembler rewrites;
- public profile input;
- public API/CLI widening;
- `.igapp` or golden migration;
- loader/report or CompatibilityReport authority;
- RuntimeMachine/Gate 3 or runtime authority;
- Ledger/TBackend, cache, signing, or production behavior;
- Spark fixture/spec work.

---

## Required Proof / Pressure Before Implementation

No implementation may be authorized from this decision.

Before any implementation route can open, a later Architect decision must see:

1. `compiler-pack-boundary-report-v0` completed as a no-code map.
2. External pressure review confirming no hidden public/runtime/report/dispatch
   widening.
3. A named implementation candidate with one bounded write scope.
4. Proof or design evidence showing why that slice should come before public
   API/CLI, loader/report, CompatibilityReport, dispatch migration, or runtime
   work.
5. Explicit preservation or replacement of accepted PROP-038 strict terminal
   invariants.
6. A separate card boundary and gate decision for any code edits.

---

## Portfolio Review

Portfolio review is required through normal R89 closure reporting:

```text
igniter-lang/docs/tracks/stage3-round89-status-curation-v0.md
```

No extra Portfolio decision is required before opening the design/report-only
`compiler-pack-boundary-report-v0` route, provided C5-S closes R89 with summary,
evidence, risks, cross-lane requests, and next route.

If C5-S cannot satisfy Portfolio reporting fields, create:

```text
igniter-lang/docs/reports/s3-r89-round-report.md
```

---

## Preserved Closed Surfaces

This decision does not authorize:

- code edits;
- implementation;
- compiler dispatch migration;
- profile-assembled compiler rewrite;
- pack registry implementation;
- parser rewrites;
- classifier rewrites;
- TypeChecker rewrites;
- SemanticIR rewrites;
- assembler rewrites;
- public API/CLI widening;
- `IgniterLang.compile` signature changes;
- strict source outside internal constructor/test seam;
- profile discovery/defaulting/finalization in public surfaces;
- loader/report compiler-profile status;
- CompatibilityReport compiler-profile section;
- obligation-coverage enforcement beyond accepted internal strict paths;
- compile refusal beyond the accepted internal-only strict terminal foundation;
- persisted reports or sidecars;
- `.igapp` golden migration;
- `.ilk` profile references;
- CompilationReceipt links;
- signing or production verification;
- RuntimeMachine or Gate 3 widening;
- Ledger/TBackend binding;
- BiHistory;
- stream/OLAP production executors;
- production cache;
- production deployment;
- Spark fixture/spec work;
- Spark implementation;
- Spark production integration;
- treating Spark applied pressure as compiler authority.

---

## Compact Summary

R89 accepts `compiler-pack-boundary-report-v0` as the next compiler mainline
route. The route is design/report-only and exists to map the current proof
compiler into candidate Profile/Baseline/Pack boundaries before any larger
compiler architecture move. Ch6 CompilationReport sync is not opened as a docs
edit now; the next report must include a Ch6 spec-lag disposition section.

The immediate next card is R89 status curation for Portfolio. After R89 closes,
the next compiler card may open as S3-R90-C1-P1 for the no-code pack boundary
report. Implementation and all protected public/runtime/report/dispatch/Spark
surfaces remain closed.
