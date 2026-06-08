# External Syntax Monotony Review Signal v0

Agent: `[Igniter-Lang Archive/Form Expert]`
Role: archive-form-expert
Date: 2026-05-08
Status: research-signal
Source: off-track external agent review of current syntax pressure

---

## Boundary

This document records an external syntax-comprehension signal. It is not canon,
not a PROP, not a parser task, and not a SemanticIR change request.

The value is form pressure: the reviewer independently names the same problem
already visible in internal syntax work - Igniter-Lang has a strong semantic
kernel, but the source surface can still read as a flat list of declarations.

---

## TL;DR

[D] The review confirms the "monotone surface" pressure: `input` / `compute` /
`output` is excellent for SemanticIR, but too flat for humans and Ruby-oriented
readers once examples become realistic.

[S] The strongest low-risk signal is organizational relief: `section` / `phase`
as visible grouping without changing graph semantics.

[T] The riskiest signals are controlled mutation inside `compute {}` and
pipeline/do-notation. They can improve readability, but must prove graph-node
identity, determinism, evidence flow, and lowering to SSA-like form.

---

## Review Signals

| Signal | External suggestion | Archive/Form interpretation |
|--------|---------------------|-----------------------------|
| Flat contract plane | Add phases/sections inside contracts | Repeated pressure; route with existing `section` and entrypoint work |
| Narrative readability | Make contracts read as preparation, calculation, validation, output | Good fit for human-agent symbiosis; should be tested on business examples |
| Block compute | `compute total { let ... if ... observe ... final_expr }` | Useful specimen candidate, but not ready for PROP until mutation/scoping rules are explicit |
| Controlled mutation | Allow local reassignment inside compute block | High risk; may be sugar over SSA only if local, typed, deterministic, and observable |
| Do-notation | `<-` binding over reads/effects | Strong academic/FP ergonomics, but may make the surface less Ruby-like |
| Pipeline style | `order |> read_price |> add_tax` | Familiar to Ruby/Elixir readers; must not hide evidence edges or node identities |
| Grouped declarations | `inputs {}`, `reads {}`, `computes {}`, `outputs {}` | Good alternative to per-line keywords; compare with `section` before grammar work |
| Short assignment | `:=` for short compute | Compactness pressure; must avoid confusing `let`, `compute`, and mutation |
| Validation block | `validate { ... }` | Mature pressure; pairs with invariant/check semantics and better human readability |
| Observation keyword | `observe` / `emit` as contract-level visible action | Strong audit/readability pressure; must distinguish observation, event, receipt, and output |
| Match/case | Replace nested `if` with `match` / `case` | General-purpose language pressure; already aligned with ADT/variant work |
| `with` / `where` | Guards/refinements | Useful but should wait for type/refinement proposal lanes |

---

## Construct Routing

| Construct / style | Status | Suggested next handling |
|-------------------|--------|--------------------------|
| `section` / `phase` | route to proposal candidate | Combine with existing entrypoint/section pressure; constrain as non-namespace grouping first |
| `validate {}` | needs specimen | Test as readable sugar over invariant/check before proposal |
| `observe` / `emit` | needs specimen | Test in evidence/receipt/provenance fixture, not in pricing-only fixture |
| grouped `inputs {}` / `reads {}` / `computes {}` / `outputs {}` | keep pressure | Compare against `section`/`phase`; avoid adding two grouping systems too early |
| block `compute name { ... }` | needs another specimen | Must specify final expression, local binding scope, no ambient effects, and graph lowering |
| local reassignment inside compute | reject/defer for now | Too easy to blur SSA and mutation; preserve as pressure only |
| `do { x <- read ... }` | keep pressure | Useful for effect sequencing, but may fight least-surprise Ruby-facing surface |
| pipeline `|>` | needs another specimen | Test with collection and stream examples; prove evidence edges remain visible |
| `:=` | keep pressure | Compact, but may conflict with `let` and compute identity |
| `match` / `case` | keep pressure | Route through ADT/variant/general-purpose language work |
| `where` / `with` | parked | Needs refinement/type semantics before surface design |

No construct here is promoted to canon.

---

## Recommended Stage 3 Syntax Experiments

### 1. Structured Contract Fixture

Create a compact business fixture using:

```text
section/phase
validate {}
observe
named thresholds/constants
ordinary operators
```

Goal: test whether visible grouping solves monotony without changing SemanticIR
shape.

### 2. Compute Block Lowering Fixture

Create a deliberately small fixture with:

```text
compute result {
  let a = ...
  let b = ...
  if condition { ... }
  final_expression
}
```

Goal: prove whether block syntax can lower to existing compute nodes plus
SSA-like locals without local mutation first.

### 3. Pipeline Versus Section Comparison

Use the same pricing or fulfillment logic in two variants:

```text
phase calculation { ... }
```

and:

```text
value |> step1 |> step2
```

Goal: check which form agents and humans explain more accurately, and whether
the pipeline hides evidence/provenance edges.

### 4. Validation And Observation Fixture

Separate `validate`, `observe`, `emit`, `receipt`, and `output` in one small
domain example.

Goal: prevent observation/event/receipt/output vocabulary from collapsing into
one overloaded effect concept.

---

## Design Pressure Statement

The language should keep the contract graph as the semantic ground truth, but it
should not force every human-facing source file to look like raw graph assembly.

Visible abstraction layers are not decoration. They are part of the
human-agent contract: a reader should be able to see preparation, calculation,
validation, observation, and output as distinct intentions before reading the
exact dependency graph.

---

## Handoff

[D] External syntax monotony review captured as a research signal.

[S] Main pressure reinforced: break the flat declaration plane while preserving
DAG semantics, determinism, evidence, and SemanticIR stability.

[T] Best immediate experiment: `section/phase` + `validate` + `observe` on a
pricing/order/compliance specimen.

[R] Defer controlled mutation. Treat it as possible SSA sugar only after a block
compute fixture proves the non-mutating version.

[Next] Route into the Syntax Pressure Registry when a future syntax-curation
slice updates construct statuses.
