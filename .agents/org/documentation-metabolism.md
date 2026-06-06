# Igniter-Lang Documentation Metabolism

Status: active process proposal
Owner: `[Architect Supervisor / Codex]`
Last updated: 2026-05-12

---

## Purpose

Igniter-Lang documentation must preserve evidence without forcing every agent
to carry the whole history in context.

This process separates three concerns:

```text
fate decision     -> Archive/Form Expert
movement/linking  -> History Curator
compact memory    -> Line Up Summarizer
```

The aim is not to erase history. The aim is to keep hot context compact and make
archaeology explicit.

---

## Pipeline

```text
Raw docs / tracks / discussions / pressure specimens
  -> Archive/Form Expert
       classify source and decide fate recommendation
  -> History Curator
       plan movement, link rewrites, archive indexes, no-zombie state
  -> Line Up Summarizer
       create compact Line Up summary and update lineups index
  -> Archive/Form Expert
       final verification: source protected, links redirected, fate clear
```

This can run in parallel by source set, but each source should have one owner per
phase.

---

## Roles

### Archive/Form Expert

Owns:

- canon/history/research/value classification;
- public/private/archive/delete recommendation;
- decision on whether a source is safe to fully detach from hot docs;
- verification that the Line Up preserves the important signal.

Does not own:

- moving files unless explicitly assigned;
- writing compact summaries as the primary output;
- current-status/spec updates unless assigned.

### History Curator

Owns:

- movement plan;
- archive index updates;
- link redirection plan;
- no-zombie state for processed documents;
- cold-storage recommendations.

Does not own:

- canon promotion;
- deleting/moving without explicit approval;
- rewriting active spec unless assigned.

### Line Up Summarizer

Owns:

- compact memory cards in `.agents/work/lineups/` or `.agents/docs/`;
- index rows from summary to source evidence;
- short "why keep / why archive / why route" notes.

Does not own:

- final fate decision;
- file movement;
- canon decisions.

---

## Document Fate Labels

```text
hot_current
  Needed by current agents by default.

active_reference
  Not read by default, but active cards may name it.

public_archive
  Safe to keep in public repository as archaeology.

private_archive
  Should move out of public repo when approved.

external_archive
  Should move to external/cold archive with index pointer.

delete_candidate
  Safe to remove after evidence is preserved and links are redirected.

do_not_move
  Evidence anchor or active source; movement would break current work.

needs_archaeology
  Fate unclear; Archive/Form Expert must inspect deeper.

needs_canon_decision
  Contains a claim that may affect spec/governance.
```

---

## Context Capsule Layers

```text
Layer 0: static canon
  AGENTS.md, roles, spec, accepted gates/proposals

Layer 1: dynamic map
  .agents/agent-context.md, .agents/current-status.md,
  .agents/work/gates/README.md, .agents/work/proposals/README.md

Layer 2: active work
  current cards, current tracks, active discussions

Layer 3: compact memory
  .agents/work/lineups/, .agents/docs/, archive/history reports

Layer 4: cold archaeology
  archive snapshots, old tracks, raw pressure docs
```

Default agent reads should stop at Layer 2 unless the card asks for Layer 3 or
Layer 4.

---

## Safety Rules

1. Snapshot before major movement.
2. Hoist value before archive.
3. Summarize before unlinking.
4. Redirect links before moving.
5. Never treat old docs as canon just because they are public.
6. Never delete/move broad source sets without explicit Architect approval.
7. Mark public/private risk before putting compact summaries in public docs.
8. If a source describes something unrealized, label it `research_unrealized`,
   `pressure`, or `spec_candidate`, not `accepted`.

---

## Batch Shape

Each documentation metabolism batch should have:

```text
Batch id:
Source set:
Archive/Form owner:
History Curator owner:
Line Up Summarizer owner:
Fate labels:
Line Ups created:
Links/indexes updated:
Do-not-move anchors:
Approval needed:
```

---

## First Recommended Stage Packet

Start with docs that create high hallucination risk:

1. old Stage 1/2 tracks that already have archive snapshots;
2. completed discussions older than current Stage 3 horizon;
3. pressure specimens that are useful but non-canonical;
4. meta-proposals superseded by current operating model;
5. root docs with overlapping guidance.

Do not start by moving proposals, gates, spec, current-status, agent-context, or
role profiles.
