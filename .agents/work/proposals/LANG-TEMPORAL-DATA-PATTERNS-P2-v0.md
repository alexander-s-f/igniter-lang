# LANG-TEMPORAL-DATA-PATTERNS-P2 - Pure Temporal Data Patterns

**Status:** CLOSED - DOCS PATTERN PROVED 59/59  
**Date:** 2026-06-14  
**Route:** LANG DOCS / TEMPORAL DATA PATTERN NOTE  
**Authority:** documentation vocabulary only; no new canon language semantics, no implementation
**Card:** `LANG-TEMPORAL-DATA-PATTERNS-P2`
**Proof:** `experiments/temporal_state_proof/verify_temporal_data_patterns_p2.rb`

---

## 0. Summary

This note blesses a compact vocabulary for pure temporal data modeling:

- `Temporal[T]` - a current value plus explicit prior values, usually as an
  app-defined fixed-depth window record.
- `Snapshot[T]` - an app-defined state slice captured at an explicit tick.
- `Trajectory[T]` - an app-defined sequence of snapshots or values, usually a
  `Collection[Snapshot[T]]` or a domain-specific collection record.

These names are **documentation vocabulary only**. They are not reserved
language identifiers, not built-in type constructors, not keywords, and not a
compiler/runtime feature. In short: `Temporal[T]`, `Snapshot[T]`, and
`Trajectory[T]` are not a compiler/runtime feature.

The pattern is for pure data. It uses explicit `Integer` ticks supplied by the
caller. It does not authorize `now()`, `DateTime`, clock capability, storage,
schedulers, TBackend, IO, or runtime time reads.

---

## 1. Boundary

This P2 is the docs-pattern successor to
`LANG-TEMPORAL-STATE-P1-temporal-state-readiness-v0.md`.

All in-scope examples are ordinary records and collections; this note is only a
records/collections pattern guide.

| Axis | In scope: pure temporal data | Out of scope: temporal reads |
| --- | --- | --- |
| Shape | ordinary records and collections | `History[T]` / `BiHistory[T]` |
| Time source | explicit caller-supplied `tick : Integer` | `DateTime`, `now()`, read coordinates |
| Authority | CORE/pure app data | TEMPORAL / TBackend side |
| Runtime | none | executor/cache/backend concerns |
| Status here | docs vocabulary | owned by PROP-022 / PROP-028 |

The lab apps are evidence only. `sim_framework` and `trade_robot` show why the
vocabulary is useful, but they do not create canon language authority by
themselves.

---

## 2. Vocabulary

### `Temporal[T]`

Use `Temporal[T]` in docs to mean "a value with explicit prior values carried as
ordinary data." A concrete app should name its real record:

```igniter
type PriceWindow {
  current : Integer
  prev_t1 : Integer
  prev_t2 : Integer
  prev_t3 : Integer
}
```

`sim_framework` already uses this pattern as `TemporalInteger` with `current`,
`prev_t1`, `prev_t2`, and `prev_t3`.

### `Snapshot[T]`

Use `Snapshot[T]` in docs to mean "a pure state slice at an explicit tick." A
concrete app should define a domain record:

```igniter
type SimSnapshot {
  tick : Integer
  entity_count : Integer
  event_count : Integer
  total_population : Integer
}
```

`sim_framework` already demonstrates this through `TakeSnapshot` returning
`SnapshotSummary`.

### `Trajectory[T]`

Use `Trajectory[T]` in docs to mean "an explicit sequence of snapshots or
temporal values." A concrete app should define a collection-bearing type or use
a collection directly:

```igniter
type SimTrajectory {
  snapshots : Collection[SimSnapshot]
}
```

Trajectory append is ordinary collection append and ordinary collection
construction/append behavior. If the
current app does not have ergonomic append/fold support for its shape, the route
is a collection/fold card, not a temporal primitive.

---

## 3. Blessed Minimal Examples

These are the minimal examples this note blesses as pure data patterns.

### Fixed-depth window

Represent history depth explicitly in a record:

```igniter
type TemporalInteger {
  current : Integer
  prev_t1 : Integer
  prev_t2 : Integer
  prev_t3 : Integer
}
```

The update is a pure field shift:

```igniter
compute next = {
  current: new_value,
  prev_t1: old.current,
  prev_t2: old.prev_t1,
  prev_t3: old.prev_t2
}
```

### Rewind

Rewind is also a pure field shuffle:

```igniter
compute rewound = {
  current: window.prev_t1,
  prev_t1: window.prev_t2,
  prev_t2: window.prev_t3,
  prev_t3: 0
}
```

There is no clock read. The chosen depth is visible in the record shape.

### Snapshot

Snapshot means "summarize this input state into a record":

```igniter
compute snapshot = {
  tick: state.tick,
  entity_count: entity_count,
  event_count: event_count,
  total_population: total_pop
}
```

The `tick` is a field in the input state, not `now()`.

### Trajectory append

A trajectory is a collection-bearing value. Append is an ordinary data update:

```igniter
type SnapshotTrajectory {
  snapshots : Collection[SimSnapshot]
}
```

When `append` is available in the local stdlib surface, use it as collection
append. When it is not, a fixed set of fields or an app-specific constructor is
still a valid pure pattern. Missing append ergonomics are collection/std-lib
pressure, not temporal language pressure.

### Explicit tick compare

Compare ticks as ordinary values:

```igniter
compute is_newer = if candidate.tick > baseline.tick { true } else { false }
```

Tick comparison does not imply a scheduler, a runtime clock, or wall-clock time.

---

## 4. How This Points Forward

This note should point at the two real future levers instead of absorbing them.
It does not absorb either lever.

`LANG-FOLD-STRUCT-ACCUMULATOR-P1/P2` owns history aggregation over records:
`trade_robot` wants a fold accumulator like
`{sum_gain, sum_loss, prev_close, count}` for RSI/MACD history. That is a
fold-to-struct problem, not a missing temporal primitive.

`LANG-COMPOSE-ENTITY-P1` and the follow-up entity PROP own manual state-threading
and lens/update verbosity. `sim_framework` window updates copy a lot of fields;
entity/state sugar or record-with-update can reduce that boilerplate without
creating a temporal runtime.

Neither route authorizes clocks, storage, TBackend reads, schedulers, dynamic
dispatch, app migrations, or IO.

---

## 5. Answers To The P2 Questions

1. Blessed examples: fixed-depth window, rewind, snapshot, trajectory append,
   and explicit tick compare.
2. `Temporal[T]`, `Snapshot[T]`, and `Trajectory[T]` are docs vocabulary only.
   They are not reserved identifiers, built-ins, keywords, primitives, or type
   constructors in this card.
3. Fold-to-struct owns record-accumulator history. Compose/entity owns
   state-threading and update verbosity. This note links to them and does not
   absorb them.
4. Pure temporal docs must warn against `now()`, `DateTime`, clock capability,
   scheduler authority, storage, TBackend, and IO. Those belong to PROP-022 /
   PROP-028 or later runtime cards, not this pattern.
5. This lives in canon proposals as a documentation/pattern note. Lab docs may
   reference it later, but lab evidence remains evidence, not authority.

---

## 6. Non-Goals

- No parser, classifier, typechecker, emitter, assembler, VM, or runtime change.
- No new keyword, primitive, generic constructor, reserved identifier, or stdlib
  type.
- No `now()`, `DateTime`, runtime clock, scheduler, storage, TBackend, backend
  adapter, file/network/process IO, database, queue, Rack, or production runtime
  claim.
- No app source migration.
- No replacement for PROP-022 / PROP-028 temporal read authority.
- No claim that old Ruby framework surfaces define language authority.

---

## 7. Evidence

- `LANG-TEMPORAL-STATE-P1` closed the route as docs pattern, 48/48 PASS.
- `LAB-IGNITER-LANG-IO-RUNTIME-P5` keeps IO runtime consolidation proof-local,
  145/145 PASS, with no new runtime surface.
- `sim_framework` provides positive evidence for `TemporalInteger`,
  `EvolveTemporal`, `Rewind1`, `TakeSnapshot`, `TimeTravel`, and
  `SnapshotSummary`.
- `trade_robot` provides pressure evidence for fold-to-struct and temporal
  indicator history, especially TR-P08. It does not require a clock.

---

## 8. Proof

```text
runner: experiments/temporal_state_proof/verify_temporal_data_patterns_p2.rb
result: 59/59 PASS
scope: source/doc guard only
```

The proof guards that the vocabulary remains documentation-only, the closed
clock/IO surfaces stay excluded, the lab apps are cited as evidence only, and
the note links forward to fold-to-struct and compose/entity without absorbing
their authority.
