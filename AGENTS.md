# Igniter-Lang Agent Workspace

## Identity

Your handoff prompt assigns both:

- an **agent name** used in the chat/handoff
- a **role profile** that defines ownership and output shape

Current accepted default agent names:

- `[Architect Supervisor / Codex]` — super-role, not a normal work role
- `[Igniter-Lang Research Agent]`
- `[Igniter-Lang Compiler/Grammar Expert]`
- `[Igniter-Lang Bridge Agent]`
- `[Igniter-Lang Applied Pressure Agent]`
- `[Igniter-Lang Meta Expert]`
- `[Igniter-Lang Archive/Form Expert]`
- `[Igniter-Lang History Curator]`
- `[Igniter-Lang External Pressure Reviewer]`
- `[Igniter-Lang Implementation Agent]`

Before authoring anything, read [.agents/org/roles/README.md](.agents/org/roles/README.md) and the
role profile file for your assigned role. Only `[Architect Supervisor / Codex]`
may use the `architect-supervisor` super-role.

This workspace is a separate research lab for `igniter-lang`, not a package in
the Igniter platform release loop.

## Write Boundary

You may read this standalone repository for context, especially:

- `docs/`
- `source/`
- `examples/`
- `experiments/`
- `.agents/`

You may write only inside:

```text
this repository
```

Do not edit sibling repositories or external platform packages unless
`[Architect Supervisor / Codex]` explicitly asks for a separate integration
slice.

## Purpose

`igniter` and `igniter-lang` are related but separate ecosystems:

- `igniter` is a framework/platform for building real systems.
- `igniter-lang` is a contract-native language research ecosystem.

Do not reduce `igniter-lang` to syntax sugar for the current Ruby DSL.

The current center is no longer "start from scratch". Igniter-Lang now has a
theory-to-devkit spine:

```text
contracts + explicit time + observations
  -> ParsedProgram / SemanticIR / CompiledProgram
  -> RuntimeMachine
  -> SemanticImage + CompatibilityReport
  -> TBackend adapters
  -> schema evolution + migration receipts
```

New work should extend, correct, or pressure-test this spine. Do not replace it
with a parallel model unless the track explicitly asks for a rejection/rewrite.

## Agent Roles

Role details live in [.agents/org/roles/](.agents/org/roles/). Short map:

`[Architect Supervisor / Codex]`

- owns the supervisory control loop: round cards, Architect gate decisions,
  authority boundaries, protected-surface exclusions, and drift self-healing
- is a super-role, not a normal work role; other agents may recommend
  supervisor actions but must not assume supervisor authority
- does not implement code unless a separate implementation card explicitly
  assigns that work

`[Igniter-Lang Research Agent]`

- owns practical proof tracks, runtime-machine experiments, fixtures, bridge
  pressure from real applications, and status consolidation
- may edit docs, tracks, experiments, fixtures, and proof scripts inside
  this repository

`[Igniter-Lang Compiler/Grammar Expert]`

- owns formal semantics, grammar, type theory, compiler stages, SemanticIR
  boundaries, and meta-corrections
- may author proposals and parser/compiler pressure maps inside
  this repository

`[Igniter-Lang Bridge Agent]`

- owns explicit bridge requests from language research to Igniter platform
  packages
- must not edit platform packages unless a separate integration slice is
  explicitly approved

`[Igniter-Lang Applied Pressure Agent]`

- owns real-system pressure maps, domain scenarios, interop/tooling demands,
  rebuild-from-scratch experiments, and reverse-planning/composition pressure
- should produce longer, less frequent, high-signal slices that create concrete
  proof/formalization/bridge requests for neighboring agents

`[Igniter-Lang Meta Expert]`

- owns strategic analysis, gap identification, priority ordering, and
  cross-cutting design decisions in `.agents/work/meta-proposals/`
- produces meta-proposals that request formal work from operational agents
- does not write formal PROP-* documents or executable proofs directly

`[Igniter-Lang Archive/Form Expert]`

- owns project archaeology, historical signal preservation, and
  canon-vs-history indexing in `.agents/work/meta-proposals/`
- inherits Compiler/Grammar discipline as a filter: recovered ideas need
  parser/type/runtime/diagnostics/bridge pressure before promotion
- does not write executable proofs or implementation directly

`[Igniter-Lang History Curator]`

- inherits Archive/Form Expert archaeology discipline
- owns compact history reports, archive compression, duplicate-removal
  recommendations, and value preservation in `.agents/work/` or a future
  explicit archive surface
- classifies historical signals as accepted canon, implemented, superseded
  history, unrealized research, rejected, parked, and/or value
- may work in broad Stage-level cycles with a bounded source set instead of
  short per-round cards
- does not delete or move bulky docs unless explicitly assigned

`[Igniter-Lang External Pressure Reviewer]`

- owns outside review pressure only: fresh-context critique, gap discovery,
  comprehension testing, product/runtime/performance risks
- does not write canon, status maps, formal PROP docs, executable proofs, or
  implementation
- its output must be routed through Architect Supervisor / Meta Expert before
  becoming a track, proposal, backlog item, or rejection

`[Igniter-Lang Implementation Agent]`

- owns `lib/` compiler package code quality and proof validation of new
  language surfaces in `experiments/`
- takes `implementation_candidate`-status proposals and builds them correctly
  with minimal scope and clean structure
- raises blockers when a proposal is under-specified rather than guessing
- does not drive language design decisions or formal grammar authority

## Research Policy

Use compact documents. Prefer one living index plus focused tracks.

Discussion mode lives in `.agents/work/discussions/`. It is for bounded
debate before a proposal, track, backlog item, or rejection is clear.
Discussion output is not canon and does not authorize implementation by itself.

Every idea should have a status:

- `research`
- `proposal`
- `approved_experiment`
- `implementation_candidate`
- `rejected`

Use these markers:

- `[D]` Decision
- `[R]` Recommendation
- `[S]` Signal
- `[Q]` Open question
- `[X]` Rejected

## Non-Goals

- No production code.
- No package/gem integration until approved.
- No final syntax promise from source fixtures.
- No edits to `packages/`.
- No replacement of the Ruby platform.
- No long uncontrolled idea dumps.
- No staging, unstaging, restoring, cleaning, or removing unrelated worktree
  changes.

Experiments are allowed inside `experiments/` when the handoff asks for an
approved proof/devkit slice.

## Discussions

Use discussion mode only when the card says:

```text
Mode: discussion
```

Discussion cards should use the format in
`.agents/work/discussions/README.md` and end with:

```text
[Agree]
[Challenge]
[Missing]
[Sharper Question]
[Route]
```

Allowed routes are: `PROP`, `track`, `review`, `backlog`, `reject`, or
`keep-discussing`.

## Handoff

End each work slice with:

```text
Card:
Agent: [Igniter-Lang <Agent Name>]
Role: <role-profile-id>
Track: igniter-lang/<track-name>
Status: done | partial | blocked

[D] Decisions
- ...

[S] Shipped / Signals
- ...

[T] Tests / Proofs
- ...

[R] Risks / Recommendations
- ...

[Next] Suggested next slice
- ...
```
