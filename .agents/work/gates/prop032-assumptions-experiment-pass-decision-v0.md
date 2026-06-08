# Gate Decision: PROP-032 Assumptions Experiment Pass v0

Card: S3-R36-C2-A
Agent: `[Architect Supervisor / Codex]`
Role: architect-supervisor
Track: `prop032-assumptions-experiment-pass-decision-v0`
Status: experiment-pass
Date: 2026-05-11

---

## Decision

PROP-032 is promoted to **experiment-pass** for the bounded compiler surface
proved by Phases 1-4.

This decision accepts the assumptions block as a proven compiler experiment. It
does not authorize PROP-033 evidence-list validation, runtime receipt behavior,
or any production behavior.

---

## Evidence Read

- `docs/proposals/PROP-032-assumptions-block-v0.md`
- `docs/tracks/prop032-assumptions-phase1-classifier-implementation-v0.md`
- `docs/tracks/prop032-assumptions-phase2-typechecker-v0.md`
- `docs/tracks/prop032-assumptions-phase3-semanticir-v0.md`
- `docs/tracks/prop032-assumptions-phase4-parser-proof-v0.md`
- `docs/discussions/r35-durable-audit-prop036-progression-prop032-pressure-v0.md`

---

## Accepted Compiler Surface

The accepted experiment-pass surface is:

- top-level `assumptions { assumption NAME { ... } }`;
- contract-body `uses assumptions NAME`;
- passive parse of `output ... evidence [name, ...]` as source syntax only;
- `assumption_registry` in parsed, classified, typed, and SemanticIR-facing
  artifacts;
- contract-level `assumption_refs`;
- `epistemic` fragment classification for assumptions-only contracts;
- report-only blocking behavior for invalid assumption programs.

Parser grammar status:

- `assumptions {}` and `uses assumptions NAME` are implemented in the parser;
- source fixtures now reach SemanticIR through Parser -> Classifier ->
  TypeChecker -> `emit_typed`;
- the assumptions source surface reports `grammar_version: "assumptions-v0"`
  when applicable.

---

## Required Behaviors

### OOF-A1

Using an undeclared assumption is OOF-A1.

Accepted behavior:

- Classifier records OOF-A1 for undeclared `uses assumptions NAME`;
- TypeChecker propagates OOF-A1 into `type_errors`;
- SemanticIR emission is suppressed through the report-only path.

### OOF-P28

Unnamed assumptions violate P28.

Accepted behavior:

- `assumption { ... }` inside `assumptions {}` is rejected at parser boundary;
- parser emits OOF-P28 and stops before the classifier path.

### TASSUMP-1

Assumption `strength` is a Decimal in `[0.0, 1.0]`.

Accepted behavior:

- invalid strength emits TASSUMP-1 at TypeChecker boundary;
- blocked programs produce CompilationReport diagnostics and no SemanticIR.

### SemanticIR Shape

Accepted SemanticIR shape:

- top-level `assumption_registry` entries lower as `kind:
  "assumption_ir"`;
- contract IR carries non-empty `assumption_refs`;
- typed `uses_assumptions NAME` lowers as an `assumption_ref_node` with
  `type: "Assumption"` and `fragment: "epistemic"`;
- blocked OOF-A1/TASSUMP-1 programs remain report-only.

---

## Explicit Exclusions

This decision does not authorize:

- PROP-033 evidence-list validation;
- treating parsed `evidence [...]` names as validated compiler evidence;
- runtime receipt propagation or receipt shape changes;
- runtime injection of assumption values;
- cross-module assumption sharing;
- `constraints {}` blocks;
- `form` constructors;
- Effect Surface behavior;
- ESM upward-coercion guard behavior;
- production RuntimeMachine behavior.

The parser may surface `evidence [...]` in the AST, but downstream agents must
treat that list as **present but unvalidated** until PROP-033 is separately
accepted and implemented.

---

## Pressure Review Disposition

The R35 pressure review raised two relevant non-blockers.

1. PROP-032 experiment-pass had no explicit governance route.
   - Closed by this decision.

2. Full Stage 3 language regression after parser Phase 4 was not explicitly
   proven as one combined matrix.
   - Non-blocking for this experiment-pass because Phase 1-4 evidence proves the
     PROP-032 compiler surface and related negative cases.
   - Follow-up: before any downstream implementation depends on PROP-032 beyond
     the assumptions experiment, rerun a broad Stage 3 regression matrix that
     includes temporal, stream, classifier, typechecker, SemanticIR, and
     assumptions fixtures together.

---

## Follow-Up Docs To Sync

- `docs/current-status.md`: update PROP-032 from Phase 4 done / decision
  pending to experiment-pass.
- `docs/tracks/README.md`: add the S3-R36-C2-A decision.
- `docs/dev/semantic-governance-heat-map.md`: update assumptions rows from
  partial/proof to experiment-pass where appropriate.
- `docs/spec/ch2-source-surface.md`: add bounded source grammar for
  `assumptions {}` and `uses assumptions NAME`.
- Any future PROP-033 card must explicitly inherit the warning that
  `evidence [...]` is currently parsed but not validated.

---

## Compact Summary

PROP-032 is accepted as experiment-pass for compiler behavior only. Parser,
Classifier, TypeChecker, and SemanticIR evidence all passed. OOF-A1, OOF-P28,
and TASSUMP-1 are accepted negative behaviors. PROP-033 evidence validation and
runtime receipt behavior remain closed.
