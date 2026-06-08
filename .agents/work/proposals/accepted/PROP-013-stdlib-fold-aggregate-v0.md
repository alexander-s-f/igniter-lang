# PROP-013: Stdlib and Fold/Aggregate v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `PROP-001`, `PROP-004`, `PROP-004b`, `PROP-010`, `PROP-012`

---

## Purpose

The current formal model has a critical expressiveness gap: the computation
graph is a DAG over typed nodes, but there is no primitive for bounded
iteration, aggregation, or collection transformation. Every real business
contract — availability scoring, dispatch ranking, order aggregation —
requires these operations.

This proposal closes the gap with:

1. Core collection types: `Collection[T]`, `Option[T]`, `Result[T, E]`
2. Bounded higher-order primitives: `fold`, `map`, `filter`, `group_by`,
   `count`, `sum`, `avg`
3. Temporal/date primitives under explicit `TemporalCtx`
4. A termination rule for bounded collection operations in CORE
5. How aggregate observations preserve evidence links

[D] All new primitives are **CORE-safe** if their inputs are finite and
their operations are pure (no ambient IO, no recursion, no self-reference).
Termination is guaranteed by structural induction on bounded collections.

---

## Collection[T]

```text
Collection[T] = Record {
  items    : List[T]          -- finite, ordered sequence
  count    : Nat              -- bounded by source (TBackend read or input)
  type_tag : TypeTag          -- element type
}

-- Collection is always finite at classification time.
-- An unbounded stream is ESCAPE, not CORE.
-- Reading from a TBackend with a limit bound returns Collection[T].
-- Reading without a limit is an ESCAPE operation.
```

**Wellformedness:**

```text
WF-C1: Collection[T].count == length(Collection[T].items)
WF-C2: All items[i].type_tag == T
WF-C3: A Collection[T] from a TBackend read must carry an `as_of` bound.
        A Collection without as_of is OOF unless marked ESCAPE.
```

**Termination Rule (TR-1):**

```text
For any CORE operation f: Collection[T] -> A
  if Collection[T].count is bounded at classification time
  then f terminates unconditionally.

Proof obligation: The compiler must verify at Pass 1 (TypedProgram) that
any Collection used as input to a fold/map/filter carries a statically-known
or TBackend-bounded count. An unbounded source escalates the node to ESCAPE.
```

---

## Option[T]

```text
Option[T] = Some(value: T) | None

-- Option is CORE-safe. It does not perform IO.
-- TBackend.read returns Option[T]: Some when found at as_of, None otherwise.
-- Option propagates through contract composition without escalating to ESCAPE.
```

**Axioms:**

```text
map(Some(v), f)       = Some(f(v))
map(None, f)          = None
flat_map(Some(v), f)  = f(v)
flat_map(None, f)     = None
or_else(Some(v), d)   = v
or_else(None, d)      = d
get_or(Some(v), d)    = v
get_or(None, d)       = d
```

**Observation:**

```text
A TBackend.read returning None produces:
  Obs[:value_observation, None]
  payload:  null
  temporal: { as_of: <requested_as_of>, lifecycle: "local" }
  -- lifecycle is :local because a None result does not persist
  -- it is evidence of absence at a specific as_of
```

---

## Result[T, E]

```text
Result[T, E] = Ok(value: T) | Err(error: E)

-- Result is CORE-safe for pure operations.
-- An ESCAPE call that succeeds returns Ok; failure returns Err.
-- Err carries a FailureKind from the FFI or capability gate.
```

**Axioms:**

```text
map(Ok(v), f)       = Ok(f(v))
map(Err(e), f)      = Err(e)
flat_map(Ok(v), f)  = f(v)
flat_map(Err(e), f) = Err(e)
recover(Ok(v), f)   = Ok(v)
recover(Err(e), f)  = f(e)
```

**Fragment rule:**

```text
Result[T, E] from a CORE operation: CORE
Result[T, E] from an ESCAPE call:   ESCAPE
Result[T, E] from an OOF call:      OOF (blocked at Pass 0)
```

---

## Fold and Higher-Order Primitives

### fold

```text
fold[T, A](
  collection : Collection[T],
  init       : A,
  f          : (A, T) -> A
) -> A

-- f must be CORE: no ambient IO, no side effects, no self-reference.
-- Termination: structural induction on collection.count (TR-1).
-- Fragment: CORE if collection and f are CORE; ESCAPE if either is ESCAPE.
```

**Example:**

```text
fold(available_slots, 0, (count, slot) -> if slot.status == "available" then count + 1 else count)
-- produces: Integer (count of available hours)
-- CORE: no IO, collection is bounded
```

### map

```text
map[T, A](
  collection : Collection[T],
  f          : T -> A
) -> Collection[A]

-- Derived from fold:
-- map(c, f) = fold(c, [], (acc, item) -> acc ++ [f(item)])
-- CORE if f is CORE.
```

### filter

```text
filter[T](
  collection : Collection[T],
  predicate  : T -> Bool
) -> Collection[T]

-- Derived from fold.
-- filter(c, p) = fold(c, [], (acc, item) -> if p(item) then acc ++ [item] else acc)
-- CORE if predicate is CORE.
-- Result count <= source count (bounded by TR-1).
```

### group_by

```text
group_by[T, K](
  collection : Collection[T],
  key        : T -> K
) -> Map[K, Collection[T]]

-- Derived from fold.
-- Partitions a bounded collection into a Map of bounded sub-collections.
-- CORE if key function is CORE.
-- K must be a Hashable type (Integer, String, Symbol).
```

### Aggregate Operations

```text
count[T](collection: Collection[T]) -> Integer
  = fold(collection, 0, (acc, _) -> acc + 1)

sum(collection: Collection[Integer]) -> Integer
  = fold(collection, 0, (acc, x) -> acc + x)

sum(collection: Collection[Float]) -> Float
  = fold(collection, 0.0, (acc, x) -> acc + x)

avg(collection: Collection[Integer | Float]) -> Option[Float]
  = if collection.count == 0 then None
    else Some(sum(collection).to_f / collection.count)
  -- Returns None on empty collection; avoids division-by-zero OOF.

min[T: Ordered](collection: Collection[T]) -> Option[T]
  = if collection.count == 0 then None
    else Some(fold(collection.tail, collection.head, (acc, x) -> if x < acc then x else acc))

max[T: Ordered](collection: Collection[T]) -> Option[T]
  = if collection.count == 0 then None
    else Some(fold(collection.tail, collection.head, (acc, x) -> if x > acc then x else acc))
```

**[D]** `avg`, `min`, `max` return `Option[T]` on empty collections.
A division-by-zero in CORE is a compile error, not a runtime exception.
The compiler must reject `sum(c) / count(c)` without the zero-guard.

---

## Temporal / Date Primitives

All temporal primitives require an explicit `TemporalCtx` parameter.
There is no ambient clock in CORE.

```text
-- Date arithmetic
date_diff(
  a: Date,
  b: Date,
  unit: :days | :hours | :minutes
) -> Integer
-- Pure: deterministic given a and b. CORE-safe.

date_add(
  d: Date,
  n: Integer,
  unit: :days | :hours | :minutes
) -> Date
-- Pure. CORE-safe.

date_floor(
  t: Timestamp,
  unit: :day | :hour | :minute
) -> Timestamp
-- Truncates to unit boundary. CORE-safe.

date_ceil(
  t: Timestamp,
  unit: :day | :hour | :minute
) -> Timestamp
-- Rounds up to unit boundary. CORE-safe.

day_of_week(d: Date) -> :monday | :tuesday | ... | :sunday
-- Pure. CORE-safe.

is_business_day(d: Date, calendar: HolidayCalendar) -> Bool
-- CORE if calendar is a static/injected input.
-- ESCAPE if calendar is fetched from TBackend at evaluation time.

now(ctx: TemporalCtx) -> Timestamp
-- Returns ctx.as_of, NOT the system clock.
-- [D] There is no Timestamp.now() without TemporalCtx. That is OOF.

day_start(ctx: TemporalCtx) -> Timestamp
-- = date_floor(ctx.as_of, :day)

day_end(ctx: TemporalCtx) -> Timestamp
-- = date_ceil(ctx.as_of, :day) - 1 second
```

**[D]** `now(ctx)` is the canonical idiom for "current time" in Igniter-Lang.
`Time.now`, `DateTime.now`, or any ambient clock call is OOF and blocked at
Pass 0 (PROP-003 Law 6).

---

## How Aggregate Observations Preserve Evidence Links

When a CORE aggregate node produces an output observation, the evidence chain
must include links to all input collection observations:

```text
aggregate_obs = Obs[:value_observation, A] where:
  subject:   "contract://<contract_id>/<output_name>"
  payload:   <aggregate_result>
  temporal:  { as_of: ctx.as_of, lifecycle: node.lifecycle }
  links:
    { rel: "observed_under",  ref: axiom_descriptor_ref }
    { rel: "observed_under",  ref: runtime_contract_ref }
    { rel: "executed_by",     ref: runtime_contract_ref }
    { rel: "aggregated_from", ref: collection_obs.id }   -- for each source obs
    { rel: "produced_in",     ref: execution_env_ref }
```

**[D]** The `aggregated_from` link is mandatory for any aggregate node.
It connects the derived result to the source facts. Without it, the
aggregate observation cannot be reproduced or verified.

**Aggregate chain rule:**

```text
If aggregate_obs.payload = f(collection_obs.payload)
  and all collection_obs are present in TBackend at as_of
  then aggregate_obs is CORE-reproducible.

If any collection_obs is missing from TBackend at as_of,
  the aggregate cannot be reproduced: status = :provisional.
```

**Example — AvailabilitySnapshot:**

```text
available_slots_obs = Obs[:value_observation, Collection[TimeSlot]]
  links: [{ rel: "aggregated_from", ref: geo_signal_obs.id },
          { rel: "aggregated_from", ref: schedule_obs.id }]

snapshot_obs = Obs[:value_observation, AvailabilitySnapshot]
  links: [{ rel: "aggregated_from", ref: available_slots_obs.id }]
```

---

## Stdlib Module Map

```text
stdlib/
  core/
    collection.ig     -- Collection[T], map, filter, fold, group_by, count, sum, avg, min, max
    option.ig         -- Option[T], map, flat_map, or_else, get_or
    result.ig         -- Result[T, E], map, flat_map, recover
    numeric.ig        -- Integer, Float, arithmetic axioms (PROP-004b Tier 1)
    string.ig         -- String, length, concat, trim, upcase, downcase, contains
    boolean.ig        -- Bool, and, or, not, if/then/else
    comparable.ig     -- Ordered, Eq, min, max
    hashable.ig       -- Hashable (required for Map keys in group_by)
  temporal/
    ctx.ig            -- TemporalCtx, now, day_start, day_end
    date.ig           -- Date, date_diff, date_add, date_floor, date_ceil, day_of_week
    window.ig         -- TemporalWindow, BoundaryPolicy (from PROP-010)
    projection.ig     -- Projection[T, horizon], ProjectionDescriptor (from PROP-004)
```

**[D]** `stdlib/core/` is the Tier 1 axiom library (PROP-004b). It is
statically linked into every CompiledProgram. It has no TBackend reads,
no FFI calls, no ambient clock. It is fully CORE.

**[D]** `stdlib/temporal/` is CORE for pure arithmetic and ESCAPE for
any operation that reads TBackend state (e.g. fetching a calendar from
a fact store).

---

## Fragment Classification of Stdlib Operations

| Operation | Class | Condition |
|-----------|-------|-----------|
| `fold(c, init, f)` | CORE | c is bounded, f is CORE |
| `fold(c, init, f)` | ESCAPE | f contains TBackend read |
| `map(c, f)` | CORE | f is CORE |
| `filter(c, p)` | CORE | p is CORE |
| `group_by(c, k)` | CORE | k is CORE |
| `count`, `sum`, `avg` | CORE | input collection is CORE |
| `avg([])` | returns None | never OOF; zero-guard built in |
| `now(ctx)` | CORE | uses ctx.as_of only |
| `Time.now` (ambient) | OOF | Law 6 violation; blocked at Pass 0 |
| `date_diff`, `date_add` | CORE | pure arithmetic |
| `is_business_day(d, calendar)` | ESCAPE | if calendar from TBackend |

---

## SemanticIR Representation

Stdlib operations are represented in `SemanticIR` as `apply` nodes with
stdlib-qualified operators:

```json
{
  "kind": "apply",
  "operator": "stdlib.collection.fold",
  "operands": [
    { "kind": "ref", "name": "available_slots" },
    { "kind": "literal", "value": 0, "type_tag": "Integer" },
    {
      "kind": "lambda",
      "params": ["acc", "slot"],
      "body": {
        "kind": "apply",
        "operator": "stdlib.boolean.if",
        "operands": [
          { "kind": "apply", "operator": "stdlib.comparable.eq",
            "operands": [
              { "kind": "field", "ref": "slot", "field": "status" },
              { "kind": "literal", "value": "available", "type_tag": "String" }
            ]
          },
          { "kind": "apply", "operator": "stdlib.numeric.add",
            "operands": [
              { "kind": "ref", "name": "acc" },
              { "kind": "literal", "value": 1, "type_tag": "Integer" }
            ]
          },
          { "kind": "ref", "name": "acc" }
        ]
      }
    }
  ]
}
```

**[D]** Lambda nodes in SemanticIR are anonymous functions applied inline.
They do not create closures over mutable state (CORE constraint). They are
only valid inside bounded fold/map/filter operations.

---

## Open Questions

[Q-1] Should `group_by` produce `Map[K, Collection[T]]` or
`Collection[Pair[K, Collection[T]]]`? Map is more useful but requires
a formal `Map[K, V]` type. Recommendation: add `Map[K, V]` as a
stdlib type, but only as a derived type from `group_by` initially.

[Q-2] Should `fold` support early termination (`fold_until`)? This is
useful for `find_first`, `take_while`, etc. Recommendation: yes, add
`fold_until[T, A](c, init, f: (A, T) -> Result[A, A])` where `Err(a)`
signals early exit. This keeps termination guaranteed while enabling
short-circuit.

[Q-3] Should `Collection[T]` support lazy evaluation (generators)?
Recommendation: no in CORE. A lazy generator is ESCAPE (it may call
TBackend incrementally). CORE collections are eagerly bounded.

[Q-4] Are string primitives necessary in v0 stdlib, or can they be
deferred to v0.1? Recommendation: include `length`, `concat`, `trim`
as minimum. Pattern matching and regex are ESCAPE (may be non-terminating).

---

## Rejected Paths

[X] Unbounded recursion in CORE. Any recursive function that does not
terminate in finite steps is OOF. The compiler must reject it.

[X] Ambient `Time.now` or `Date.today` in any stdlib function.
All temporal primitives take explicit `TemporalCtx`.

[X] `avg([])` returning `0` or raising a runtime error. It must return
`None`. Division-by-zero in CORE is a compile-time error.

[X] Lazy/streaming collections in CORE. Bounded, eager evaluation only.
Streams are ESCAPE.

[X] Mutable accumulators or in-place update in fold/map. All combinators
are pure: they return new values, never mutate inputs.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-013-stdlib-fold-aggregate-v0.md
Status: done

[D] Decisions:
- Collection[T] is always finite and bounded at classification time.
  Unbounded streams are ESCAPE.
- Termination Rule TR-1: if Collection[T].count is statically bounded,
  any fold/map/filter terminates unconditionally (structural induction).
- fold is the primitive; map, filter, count, sum, avg, min, max are derived.
- avg([]) = None; never OOF; zero-guard is a language invariant.
- now(ctx) = ctx.as_of. No ambient clock. Time.now is OOF (Law 6).
- Aggregate observations carry aggregated_from links to all source obs.
  Without them, the aggregate is not CORE-reproducible.
- Lambda nodes in SemanticIR are anonymous, non-recursive, bounded.
- stdlib/core/ is Tier 1: no TBackend reads, no FFI, no ambient clock.
- stdlib/temporal/ arithmetic is CORE; TBackend reads are ESCAPE.

[R] Recommendations:
- Add fold_until for short-circuit patterns (find_first, take_while).
- Add Map[K, V] as a derived type from group_by.
- Defer regex and pattern matching to ESCAPE (non-termination risk).
- String primitives: include length, concat, trim in v0.

[S] Signals:
- The AvailabilityProjection fixture already uses compute_slots/build_snapshot
  which are exactly fold-over-geo_signals. PROP-013 formalises what the
  devkit experiment already implements.
- SemanticIR fold node representation is directly loadable into the
  CompiledProgram evaluator in compiled_program.rb. No new eval pass needed.
- aggregated_from links are a natural extension to evidence_links in
  the existing RuntimeMachine.evaluate_program method.

[Q] Open Questions:
- fold_until: include in v0 or defer?
- Map[K, V]: include with group_by or defer?
- String primitives: v0 minimum set?
- Lazy collections: confirm ESCAPE-only or add a bounded generator type?

[X] Rejected:
- Unbounded recursion in CORE.
- Ambient Time.now / Date.today.
- avg([]) = 0 or runtime error.
- Lazy/streaming collections in CORE.
- Mutable accumulators.

---

## Errata v0.1 — Stage 2 stdlib primitives reserved (2026-05-06)

_Source: META-EXPERT-006-language-model-revision-v0.md._

### E1 — `fold_stream` as stdlib primitive (Stage 2)

PROP-013 v0 states: "Lazy/streaming collections in CORE. Streams are ESCAPE."
This errata adds the explicit stdlib primitive that bridges ESCAPE → CORE:

```
-- stdlib/stream/fold_stream
fold_stream(
  s:    stream T,
  init: A,
  fn:   (A, T) -> A
) @window_bounded  →  A

fold_stream(
  s:    stream T,
  init: A,
  fn:   (A, T) -> A
) @count_bounded(n: Integer)  →  A
```

**Tier classification**: stdlib/stream/ — requires `stream_input` ESCAPE
capability at the contract level. The fold_stream result `A` is CORE.

**Termination rule (TR-2)**: if `@window_bounded` is present and the window
declaration specifies a finite size or period, `fold_stream` terminates
unconditionally (bounded by the window, not the stream length).

**SemanticIR representation**:

```json
{
  "kind": "fold_stream_node",
  "stream_ref": "readings",
  "init_ref": "initial_value",
  "fn_ref": "anonymous_lambda_0",
  "bound": { "kind": "window_bounded", "window_ref": "sensor_window" },
  "type": "Float"
}
```

### E2 — `History[T]` stdlib operations (Stage 2, specified in PROP-022)

The following stdlib operations are reserved for Stage 2.
Stage 1 compilers must treat them as OOF if encountered in source.

```
-- stdlib/temporal/ (Stage 2)
history_at(h: History[T], t: DateTime)            →  Option[T]
history_avg(h: History[T], p: DateRange)          →  Option[T]  -- requires Numeric[T]
history_rollup(h: History[T], grain: Symbol)      →  History[T]
history_until(h: History[T], t: DateTime)         →  History[T]
history_changes(h: History[T])                    →  Collection[ChangeEvent[T]]

-- BiHistory (Stage 2)
bi_history_at(h: BiHistory[T], vt: DateTime, tt: DateTime)  →  Option[T]
bi_history_correct(h: BiHistory[T], interval, reason)       →  BiHistory[T]  -- ESCAPE
```

### E3 — `OLAPPoint[T, Dims]` stdlib operations (Stage 2, specified in PROP-024)

```
-- stdlib/olap/ (Stage 2)
olap_slice(p: OLAPPoint[T, D], dim: Symbol, v: D[dim])  →  OLAPPoint[T, D - {dim}]
olap_rollup(p: OLAPPoint[T, D], dim: Symbol, fn: Symbol)  →  OLAPPoint[T, D - {dim}]
olap_drill(p: OLAPPoint[T, D], dim: Symbol, grain: Symbol) →  OLAPPoint[T, D]
olap_compare(a: OLAPPoint[T, D], b: OLAPPoint[T, D])      →  OLAPPoint[T, D]
olap_transform(p: OLAPPoint[T, D], fn: T -> T)            →  OLAPPoint[T, D]
olap_resolve(p: OLAPPoint[T, {}])                         →  T   -- fully resolved
```

**Cluster semantics**: `olap_rollup` over an `indexed:` dimension generates
a scatter-gather execution plan — parallel reads from partitioned nodes,
local reduce, final merge. This is generated by the compiler, not the
programmer.

[Next] Proposed next slice:
- PROP-014: Source Syntax to SemanticIR Boundary v0
  (see companion proposal in this round)
- Update CompiledProgram evaluator to handle stdlib.collection.fold
  as a named operator (extend apply_operator in compiled_program.rb)
- Add aggregated_from links to evaluate_program in compiled_program.rb
```
