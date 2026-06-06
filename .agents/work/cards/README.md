# Igniter-Lang Cards

Status: active
Owner: [Architect Supervisor / Codex]
Started: 2026-05-14

---

## Purpose

Cards are the dispatch layer for supervisor planning.

They answer:

```text
What did we plan to do, in what order, and under what authority?
```

Tracks remain the evidence layer. They answer:

```text
What did an agent actually do, prove, decide, or discover?
```

Cards do not replace `.agents/work/tracks/`, `.agents/work/gates/`,
`.agents/work/discussions/`, or `.agents/current-status.md`.

---

## Structure

```text
cards/
  S<n>/
    S<n>.md            stage entry point: horizon, decisions, round index
    S<n>-R<n>.md       round file: status, lineup, dispatch, card texts, receipt
```

Igniter-Lang starts this structure at Stage 3 Round 44. Earlier rounds remain
available through `.agents/current-status.md`, `.agents/work/tracks/README.md`,
gates, discussions, and source track files. Do not backfill R1-R43 unless
explicitly requested.

---

## Round File Header

```text
# S<n>-R<n>

Status: open | closed
Date: YYYY-MM-DD
Closed: YYYY-MM-DD | -
Lineup: one line summary

Dispatch:
R<n> = [[C1-P1, C2-P1], C3-S]

---
```

---

## Suffix Legend

- `-P` / `-P1` / `-P2`: parallel-safe; cards with the same `P` series may run together
- `-B`: blocked/ordered; check `Depends on` before starting
- `-S`: serial, supervisor-only, or round-close work
- `-A`: Architect authority decision; no code is authorized unless this says so
- `-I`: implementation/code-writing slice
- `-X`: external pressure/review slice
- `-O`: organization/orchestration sidecar; not on the compiler critical path
- `-QA`: verification slice

---

## Lifecycle

1. Supervisor opens a round file with planned card texts.
2. User dispatches cards to agents.
3. Agents write work artifacts to their assigned destination:
   - `.agents/work/tracks/` for work/evidence;
   - `.agents/work/gates/` for Architect decisions;
   - `.agents/work/discussions/` for pressure/review;
   - `.agents/work/lineups/` or `.agents/docs/` for compact historical summaries.
4. Round file card text remains a planning record.
5. At close, Supervisor appends a Round Receipt with links to actual outputs.

Do not rewrite completed card text to match what happened. Put actual results in
the Round Receipt and the track/discussion/gate files.

---

## Drift Self-Healing Protocol

Use this protocol when chat, cards, tracks, gates, discussions, or status maps
drift apart.

Trigger examples:

- a supervisor posts cards in chat but the round file is missing;
- an agent completes a track that is not present in the round file;
- `S<n>.md` omits an open or closed round;
- a gate/discussion/track exists but the owning round receipt does not cite it;
- a card depends on an artifact whose path or status changed in a parallel
  slice.

Rules:

1. Prefer repair over blame. Create the smallest map/card/index fix that restores
   dispatch truth.
2. Do not change the original scope, authority, or implementation permission
   while repairing drift.
3. If reconstructing from chat, mark the round/card text as reconstructed only
   when exact card text is unavailable.
4. If exact card text is available from chat or user handoff, copy it into the
   round file unchanged.
5. Record actual outcomes only in receipts, tracks, gates, discussions, and
   status maps.
6. Status Curator must check at round close:
   - round file exists;
   - stage index links the round;
   - every delivered track/gate/discussion is cited by the round receipt;
   - dependency order matches the dispatch pattern;
   - implementation authority did not widen during repair.

Allowed self-healing edits:

- missing round file creation;
- stage card index update;
- round receipt/index link repair;
- status-map link correction;
- explicit note that a track-level claim was superseded by a gate decision.

Not allowed during self-healing:

- authorizing implementation;
- changing gate decisions;
- changing completed card scope;
- silently deleting historical evidence;
- rewriting tracks to fit the map.

---

## Current Stage

- [Stage 3](S3/S3.md)
- [Stage 3 Round 44](S3/S3-R44.md)
