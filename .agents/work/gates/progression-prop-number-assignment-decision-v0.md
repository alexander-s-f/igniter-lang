# Progression PROP Number Assignment Decision v0

Card: S3-R35-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: progression-prop-number-assignment-decision-v0
Status: approved-numbering-only
Date: 2026-05-11

---

## Decision

Assign **PROP-037** to external progression semantics.

Title:

```text
PROP-037 — External Progression and Service Liveness Semantics
```

This decision is **numbering and routing only**. It does not author the proposal
text, does not accept the proposal, and does not authorize implementation.

---

## Rationale

The external progression scope draft is ready to enter the formal proposal
lifecycle. Leaving it as `PROP-037+` would create the same floating-design
assumption that was just closed for `compiler_profile_id`.

The accepted route is narrow:

```text
progression = runtime-managed event potential + bounded materialization
              + service step lifecycle + receipts/checkpoint/backpressure
```

Progression is distinct from:

```text
Stream[T] / fold_stream      -> data flow and bounded window folding
managed local loops          -> finite, structural, fuel-bounded, convergent repetition
Runtime scheduler            -> concrete execution mechanism, not language identity
```

The key architectural sentence remains:

```text
service loop is the surface; progression is the semantic substrate.
```

---

## Scope Of PROP-037

PROP-037 may define:

- `Progression` as a named semantic entity distinct from `Stream[T]` and local
  managed loops;
- service liveness as a progression-backed surface, not eager repeated body
  execution;
- initial runtime capability / manifest metadata shape;
- minimum `ProgressionEvent` fields;
- minimum `ProgressionStepReceipt` fields;
- bounded materialization invariant;
- cancellation requirement;
- checkpoint/resume obligation for resumable or infinite progressions;
- backpressure as structured materialization state;
- source descriptor vocabulary, initially:

```text
clock.every
queue
external_event
```

- OOF/refusal categories for hidden, unbounded, or improperly nested
  progression-like behavior.

---

## Required Boundaries

PROP-037 must preserve:

```text
Stream[T] remains data flow.
fold_stream remains bounded window folding.
Progression remains execution/event lifecycle.
```

PROP-037 must preserve Chapter 13 local loop classes:

```text
FiniteLoop
StructuralRecursion
FuelBoundedRecursion
ConvergentLoop
```

The first PROP must use:

```text
runtime capability / manifest metadata first
```

It must not introduce a new `PROGRESSION` fragment class unless a later
accepted proposal proves capability/manifest metadata is insufficient.

---

## Non-Authorizations

This decision does not authorize:

- authoring the PROP-037 text;
- parser syntax;
- TypeChecker implementation;
- SemanticIR implementation;
- assembler or `.igapp` changes;
- RuntimeMachine scheduler;
- live service execution;
- Ledger / TBackend binding;
- durable queues;
- durable checkpoints;
- receipt sink implementation;
- production cache;
- production execution;
- `ProgressionPack` migration or compiler dispatch changes;
- a new `PROGRESSION` fragment class.

---

## Follow-Up Docs To Sync

1. `docs/proposals/README.md`
   - Add `PROP-037` as the assigned external progression proposal slot.
   - Remove `PROP-037+` as the generic progression placeholder.
   - Move any remaining managed local recursion / loop-class extension
     placeholder to `PROP-038+` or later.

2. Future PROP-037 authoring card
   - Must use this decision as numbering authority.
   - Must preserve all non-authorizations above.
   - Must explicitly answer whether `external_event` is a closed initial
     vocabulary item or an open extension point.

3. `docs/tracks/README.md` and `docs/current-status.md`
   - Record this decision during the next status curation pass.

---

## Compact Summary

Decision: **PROP-037 is assigned to External Progression and Service Liveness
Semantics**.

The feature now has a formal lifecycle slot. The proposal may be authored next,
but no syntax, TypeChecker, SemanticIR, RuntimeMachine scheduler, Ledger/TBackend
binding, durable queue, production execution, ProgressionPack migration, or new
fragment class is authorized by this decision.
