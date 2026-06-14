# LANG-TEMPORAL-STATE-P1 — Temporal State Readiness

**Status:** CLOSED — PROVED 48/48 — ROUTE: DOCS PATTERN (shared vocabulary; no canon change; no implementation)
**Track:** lang / design / temporal-state readiness
**Date:** 2026-06-14
**Authority:** proposal/readiness only — no implementation, no new primitive, no clock/IO surface, no canon claim
**Card:** LANG-TEMPORAL-STATE-P1
**Primary evidence:** LAB-TRADE-ROBOT-BASELINE-P1 (TR-P08); sim_framework SIM-P02/P06/P07

---

## 0. TL;DR

**Temporal state as pure data** — prior values, snapshots, trajectories modeled as
records and collections — is **already fully expressible today** and compiles
**dual-clean** in both toolchains. It needs **no new language primitive** and
introduces **no clock/IO**.

**Route: DOCS PATTERN.** Bless a shared, proof-local pattern vocabulary
(`Temporal[T]` / `Snapshot[T]` / `Trajectory[T]`) that `trade_robot` and
`sim_framework` can reference, defined as ordinary app/library types. No canon
change, no `now()`, no TBackend.

The two pains that *do* have a language lever are **separate, already-routed
cards**, not this one:
- **fold-to-struct accumulator** — folding history into a record fails today with
  `OOF-COL4`. Route: `LANG-FOLD-STRUCT-ACCUMULATOR-P1`.
- **window/lens verbosity** — manual field-shift on every evolve/rewind. Route:
  compose/entity (`LANG-COMPOSE-ENTITY`) + record-with-update.

The time-indexed temporal **read** surface (`History[T]` with `now()` / `DateTime`
/ TBackend) is owned by **PROP-022 / PROP-028** and is the **IO/clock side** —
explicitly **out of scope** and kept closed.

---

## 1. The hard boundary: pure data vs. clock reads

| Axis | This card (IN SCOPE) | PROP-022 / PROP-028 (OUT OF SCOPE) |
|------|----------------------|-------------------------------------|
| What | prior values, snapshots, trajectories as **records/collections** | time-indexed **reads** `h[t]`, `h.avg[period]` |
| Time source | explicit `tick : Integer` inputs (caller-supplied) | `as_of : DateTime = now()` |
| Capability | none — CORE/pure | **TBackend** read capability (ESCAPE/TEMPORAL) |
| Fragment | CORE | TEMPORAL (precedence over modifier) |
| Status | expressible today, dual-clean | accepted/partial canon, IO-bearing |

The two are **disjoint**. The apps under survey contain **zero** `now()`, `DateTime`,
`clock`, or `timestamp` references (proof E-01/E-02). Ticks are explicit integer
inputs threaded by the caller — never read from a runtime clock.

---

## 2. Survey — both apps

### sim_framework (the temporal fixture)

`type TemporalInteger { current; prev_t1; prev_t2; prev_t3 }` — a **fixed-depth
sliding window** as a pure record (`types.ig:14`). Operations are pure record
transforms:

- `EvolveTemporal` (`temporal.ig:13`) — window shift `current → prev_t1 → prev_t2 → prev_t3`, manual field copy.
- `Rewind1` (`temporal.ig:58`) — **time-travel** as a pure field shuffle (no clock).
- `TemporalDelta` / `TemporalTrend` (`temporal.ig:29,38`) — derived from prior values.
- `TakeSnapshot → SnapshotSummary` (`relation.ig:90`) — **snapshot** as a state-slice record.
- `TimeTravel` + `rewound_snapshot` (`example.ig:84`) — rewind-and-compare.

Registry: SIM-P02 "Temporal sliding window … **no built-in `Temporal[T]` yet**"
(positive app pattern); SIM-P07 snapshot/trajectory routed to a **separate** lab
card (`LAB-SIMULATION-SNAPSHOT-TRAJECTORY-P1`). The whole app compiles **dual-clean**.

### trade_robot (the indicator pain)

`indicators.ig` documents the limitation directly (`ComputeRSI`, ~L80-91):
*"fold state = {sum_gain, sum_loss, prev_close, count} … But we can only fold to a
single Integer! … REAL LIMITATION: fold() returns a single scalar. We need
fold-to-struct."* MACD's signal line needs EMA-of-history and is likewise blocked
by the scalar-fold limit. Registry: **TR-P08** routes to **both**
`LANG-FOLD-STRUCT-ACCUMULATOR-P1` and this card.

**Shared vocabulary is possible without canon change** (Q5): both apps already
model history as plain records/collections; a documented `Temporal[T]` /
`Snapshot[T]` / `Trajectory[T]` convention (app/library types) lets them share
shape names with zero compiler involvement.

---

## 3. The keystone — what actually fails

Proven empirically (Sections D/F):

```
pure sliding window  (evolve/rewind/delta)     → DUAL-CLEAN  (Ruby 0 / Rust ok 0)
trajectory as Collection[Snap] (concat append) → DUAL-CLEAN  (Ruby 0)
fold history INTO a record accumulator         → REJECTED    OOF-COL4
   "stdlib.collection.fold: lambda return type Integer does not match
    accumulator type Acc"
```

The only thing that does not work is **folding into a struct** — and that is an
`OOF-COL4` **fold** limitation, not a temporal one. Scalar fold works fine
(D-05). So temporal-state pain decomposes cleanly into:

1. *expressible already* (windows, snapshots, trajectories) → docs pattern;
2. *a fold limitation* → `LANG-FOLD-STRUCT-ACCUMULATOR-P1`;
3. *verbosity of manual window shifts* → compose/entity + record-with-update.

None of the three is a missing **history primitive**, and none needs a clock.

---

## 4. The seven questions

**Q1. Which temporal forms are already expressible as pure records and collections?**
All of the surveyed ones: fixed-depth sliding windows (`TemporalInteger`),
snapshots (`SnapshotSummary`), time-travel/rewind (field shuffle), delta/trend
(derived computes), and growing trajectories (`Collection[Snap]` via `concat`).
Proven dual-clean (B, C-03, F).

**Q2. Which pain is real — verbosity, fold accumulator, named helpers, or runtime time?**
Two real pains: **(a) fold accumulator limitation** (`OOF-COL4`, can't fold into a
struct — the dominant blocker for RSI/MACD history) and **(b) verbosity** of manual
window-shift/lens field copies. **Not** a missing runtime time source (no app needs
`now()`), and **not primarily** missing stdlib helpers (the shapes are trivial
records; a docs convention suffices).

**Q3. Should temporal state remain app-defined types rather than language primitives?**
**Yes.** `Temporal[T]` / `Snapshot[T]` / `Trajectory[T]` should stay **app/library
types** documented as a shared pattern. A built-in would add surface area for a
shape that is already a one-line record, and would risk drifting toward
compiler-managed history depth (explicitly a non-goal of sim_framework's registry).

**Q4. Does any proposed helper require real time/clock IO? If yes, reject or defer.**
**No helper in scope requires a clock.** Ticks are explicit integer inputs. Any
form that *would* need `now()`/`DateTime`/TBackend is the PROP-022/028 read surface
— **rejected from this card** and kept closed.

**Q5. Can trade_robot and sim_framework share a proof-local pattern vocabulary without canon changes?**
**Yes.** Both already model history as pure records/collections. A shared
documented vocabulary (`Temporal[T]` window, `Snapshot[T]` slice, `Trajectory[T]`
sequence) is purely app-level — no parser/typechecker/runtime involvement.

**Q6. Smallest P2 route: docs pattern, stdlib helper, or language proposal?**
**Docs pattern.** Author a shared "temporal data patterns" note (the vocabulary +
the window/snapshot/trajectory idioms that compile today). Defer any *helper* until
`LANG-FOLD-STRUCT-ACCUMULATOR-P1` lands, since the genuinely missing capability
lives there, not here. No language proposal for a temporal primitive.

**Q7. How does this interact with fold struct accumulator and compose/entity?**
- **fold-to-struct** (`LANG-FOLD-STRUCT-ACCUMULATOR-P1`): the actual language lever
  for history aggregation (RSI/MACD). Once folding into a record works, trajectories
  and rolling stats become concise without any temporal primitive.
- **compose/entity** (`LANG-COMPOSE-ENTITY-P1`): removes the manual window-shift /
  lens boilerplate (an entity's `state` auto-threads; temporal fields become record
  fields of the entity state). Temporal verbosity is a *facet* of the same
  state-threading pain, not a separate primitive.

---

## 5. Route decision & non-goals

**ROUTE = DOCS PATTERN** — a shared, proof-local `Temporal[T]` / `Snapshot[T]` /
`Trajectory[T]` vocabulary, app-defined, documented as the blessed idiom. **No
canon change. No implementation. No language primitive. No clock/IO.**

The next concrete step (a P2 if pursued) is a **documentation/pattern note**, not a
spec — and it should explicitly *point* at the two real levers rather than absorb
them.

### Non-goals (closed surfaces)

- No `now()`.
- No clock capability / TBackend read surface (that is PROP-022/028).
- No persistence, database, queue, file, or network IO.
- No runtime scheduler / tick source.
- No app source migration.
- No new keyword or built-in `Temporal`/`Snapshot`/`Trajectory` primitive.
- No compiler-managed history depth.

### Acceptance (card §Acceptance)

- ✅ Distinguishes pure temporal data from IO clock/runtime time (Sections 1, E).
- ✅ Surveys both `trade_robot` and `sim_framework` (Section 2).
- ✅ Produces a route decision with non-goals (this section).
- ✅ Does not reopen Rack/IO/storage authority (E-06; LAB-IGNITER-LANG-IO-RUNTIME-P5 boundary intact).

---

## 6. Proof

```
runner:   igniter-lang/experiments/temporal_state_proof/verify_temporal_state_p1.rb
result:   48/48 PASS
sections: A preconditions (6) / B pure-data expressible (7) / C snapshot-trajectory survey (6) /
          D fold-to-struct is the lever (6) / E clock/IO boundary (6) /
          F dual-clean fixtures (6) / G closed surfaces (6) / H route decision (5)
```

---

## 7. Open routes (successors)

| Card | Scope |
|------|-------|
| (P2, if pursued) temporal data patterns note | Document the shared `Temporal[T]`/`Snapshot[T]`/`Trajectory[T]` vocabulary + idioms that compile today |
| LANG-FOLD-STRUCT-ACCUMULATOR-P1 | The real language lever — folding history into a record accumulator (OOF-COL4) |
| LANG-COMPOSE-ENTITY-P1 → PROP | Removes manual window-shift / lens verbosity via entity state auto-threading |
| LAB-SIMULATION-SNAPSHOT-TRAJECTORY-P1 | App-level snapshot/trajectory concept evidence (lab) |
| (separate, IO) PROP-022 / PROP-028 | Time-indexed temporal reads with `now()`/TBackend — the clock side, untouched here |
