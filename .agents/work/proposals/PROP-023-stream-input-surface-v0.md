# PROP-023: Stream Input Surface Form v0

Status: closed
Closed: 2026-05-07 (Stage 2 — experiment PASS, META-EXPERT-009.1)
Date: 2026-05-06
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: PROP-003 (fragment classification, errata v0.1), PROP-013 (stdlib, errata v0.1)
Stage: 2
Source: META-EXPERT-005 §4.1; META-EXPERT-006 §2.2, §2.4; playgrounds/docs/experts/igniter-lang/igniter-lang.md §5.3

---

## § 1. Motivation

Igniter-Lang's original research identified three paths to Turing completeness:
- Path A: recursive contracts
- Path B: explicit `iterate` node
- **Path C: streaming / coinductive contracts** (the IoT/sensor path)

Path C was never formalized into a PROP. The archaeology (META-EXPERT-005)
identified this as the most significant missing piece for the IoT, sensor,
event-driven agents, and reactive pipeline use cases.

This PROP formalises Path C's surface form: `stream name: Type`.

**Design invariant** (from META-EXPERT-006, Q2 resolved):
`stream T` is always ESCAPE. Unbounded access to an external data source
cannot be CORE. The ESCAPE → CORE bridge is `fold_stream` with an explicit
bound annotation.

---

## § 2. Surface Syntax

### § 2.1 Stream input declaration

```ebnf
stream_decl ::= 'stream' IDENT ':' type_expr
```

Example:
```
contract SensorAggregation {
  in     device_id: String
  stream readings:  SensorReading      ← stream input declaration
  ...
}
```

**Position**: `stream` declarations appear after `in` declarations and before
`read`, `compute`, `branch`, `compose`, `out`, `effect` nodes.

Multiple streams are permitted:
```
stream telemetry: TelemetryFrame
stream commands:  GroundCommand
```

### § 2.2 Window declaration

Every `stream` input must have an associated `window` declaration.
Without a window, the contract is OOF (OOF-S2 below).

```ebnf
window_decl ::= 'window' STRING_KEY '{'
                  'kind:' window_kind ','
                  window_size_spec ','
                  'on_close:' on_close_action
                '}'

window_kind     ::= ':count' | ':calendar' | ':session'
window_size_spec ::=
    'size:'   INTEGER             -- for :count
  | 'period:' duration_expr      -- for :calendar
  | 'idle:'   duration_expr      -- for :session (closes on inactivity)

on_close_action ::= ':snapshot' | ':emit' | ':discard'
```

Examples:
```
-- Count-based window: process every 100 readings
window "sensor/{device_id}" {
  kind:     :count
  size:     100
  on_close: :snapshot
}

-- Calendar window: process each minute of data
window "telemetry/{spacecraft_id}" {
  kind:     :calendar
  period:   1.minute
  on_close: :emit
}

-- Session window: close after 30s of inactivity
window "user_session/{user_id}" {
  kind:     :session
  idle:     30.seconds
  on_close: :snapshot
}
```

**on_close semantics**:
- `:snapshot` — write the contract output to a `lifecycle :durable` store
- `:emit` — deliver the output as an event to subscribers
- `:discard` — evaluate but do not persist (useful for real-time displays)

---

## § 3. Classification

### § 3.1 Stream input node

```
stream readings: SensorReading    →  ESCAPE
```

Classification: ESCAPE. The runtime must hold a stream handle
(the `stream_input` ESCAPE capability from PROP-003 errata v0.1).

ESCAPE propagation: a contract containing any `stream` declaration is
classified ESCAPE at the contract level, even if all other nodes are CORE.

### § 3.2 `fold_stream` — the ESCAPE → CORE bridge

```
fold_stream(s, init, fn) @window_bounded   →  CORE (A)
fold_stream(s, init, fn) @count_bounded(n) →  CORE (A)
```

The result of `fold_stream` is a CORE value — it can feed into CORE nodes
without propagating ESCAPE further.

```
contract SensorAggregation {
  in     device_id: String
  stream readings:  SensorReading       ← ESCAPE

  window "sensor/{device_id}" {
    kind: :count, size: 100, on_close: :snapshot
  }

  -- fold_stream is ESCAPE at the call site (it reads from a stream)
  -- but the result (avg_temp) is a CORE Float
  compute avg_temp: Float =
    fold_stream(                        ← ESCAPE call
      readings,
      { sum: 0.0, count: 0 },
      (acc, r) -> { sum: acc.sum + r.temperature, count: acc.count + 1 }
    ) @window_bounded
    |> (acc -> acc.sum / acc.count)    ← CORE: pure arithmetic on the result

  out snapshot: SensorSnapshot = {
    device_id: device_id,
    avg_temp:  avg_temp,
    window:    "100-reading count window"
  }
    lifecycle :durable
}
```

### § 3.3 Lambda inside fold_stream

The accumulator function `fn: (A, T) -> A` must be CORE:
- No `stream` references inside `fn`
- No TBackend reads inside `fn`
- No ESCAPE constructs inside `fn`

A non-CORE lambda inside `fold_stream` → OOF-S3.

---

## § 4. OOF Rules

```
OOF-S1: fold_stream without @window_bounded or @count_bounded(n)
         → "unbounded stream fold — must declare @window_bounded or @count_bounded"

OOF-S2: stream declaration without a matching window declaration
         → "stream '{name}' has no window — every stream must declare a window"

OOF-S3: ESCAPE construct inside fold_stream accumulator function
         → "fold_stream accumulator must be CORE — found ESCAPE: {construct}"

OOF-S4: stream value used outside fold_stream
         → "stream '{name}' must be consumed via fold_stream — direct access is OOF"

OOF-S5: @count_bounded(n) where n is not a statically-known Integer literal
         → "count bound must be a static Integer literal, not a variable"
```

---

## § 5. SemanticIR Shape

### § 5.1 Stream input node

```json
{
  "kind": "stream_input_node",
  "name": "readings",
  "type": "SensorReading",
  "window_ref": "sensor_device_window",
  "escape_capability": "stream_input"
}
```

### § 5.2 Window declaration node

```json
{
  "kind": "window_decl_node",
  "ref": "sensor_device_window",
  "key": "sensor/{device_id}",
  "window_kind": "count",
  "size": 100,
  "on_close": "snapshot"
}
```

### § 5.3 fold_stream node

```json
{
  "kind": "fold_stream_node",
  "name": "raw_aggregate",
  "stream_ref": "readings",
  "init": { "kind": "record_literal", "fields": { "sum": 0.0, "count": 0 } },
  "fn_ref": "anonymous_lambda_0",
  "bound": { "kind": "window_bounded", "window_ref": "sensor_device_window" },
  "result_type": { "constructor": "Record", "fields": { "sum": "Float", "count": "Integer" } },
  "escape_capability": "stream_input"
}
```

---

## § 6. Runtime Semantics

The stream capability handler:

1. Receives events from the external source (network, message queue, file tail, etc.)
2. Buffers events in the window
3. When the window close condition is satisfied:
   - Delivers the buffered events as an ordered sequence to `fold_stream`
   - `fold_stream` executes as a bounded fold (CORE evaluation)
   - The result feeds into the remaining CORE nodes of the contract
   - `on_close` action is executed (snapshot / emit / discard)
4. Clears the window buffer and begins the next window

The RuntimeMachine sees `fold_stream` as a `fold_node` over a
`Collection[T]` — the stream window has already been materialised into
a bounded collection by the capability handler. The RuntimeMachine does
not need a streaming-specific evaluation mode.

---

## § 7. Theoretical Grounding

### § 7.1 ω-transducer view

A streaming contract is an **ω-transducer**: it processes an infinite input
sequence (the stream) and produces an infinite output sequence (one output
per window). Each window closure is one step of the transducer.

Inside each window, the evaluation is a **deterministic acyclic transducer**
(DAT, from the CORE classification) — finite, bounded, PTIME.

### § 7.2 Kahn Process Networks (KPN)

The contract graph with streaming inputs is a **Kahn Process Network**:
- Each CORE contract node = a single-shot KPN process
- Streams = KPN channels
- Window boundaries = synchronisation points (analogous to Lustre clock ticks)

The window-sampled model preserves the KPN determinism property:
the output of a window evaluation is determined solely by the events in that
window. No global state, no race conditions.

### § 7.3 Continuous Datalog

From the Datalog identity (PROP-001 / META-EXPERT-005 §3):
streaming contracts are **Continuous Datalog** — the EDB (extensional database)
is updated by the stream; the IDB (intensional, derived facts) is recomputed
at each window boundary. The window boundary is the "stratum trigger."

---

## § 8. Example — IoT Sensor Pipeline

```
contract ThermalMonitor {
  in  device_id: String
  stream readings: SensorReading

  window "thermal/{device_id}" {
    kind:     :count
    size:     60                    -- 60-reading window (e.g., 1 per second = 1 min)
    on_close: :snapshot
  }

  compute stats: ThermalStats =
    fold_stream(
      readings,
      { min: Float.max, max: Float.min, sum: 0.0, count: 0 },
      (acc, r) -> {
        min:   min(acc.min, r.temperature),
        max:   max(acc.max, r.temperature),
        sum:   acc.sum + r.temperature,
        count: acc.count + 1
      }
    ) @window_bounded

  compute avg_temp: Float = stats.sum / stats.count

  invariant "stats.max <= THERMAL_LIMIT"
    severity: :error
    label:    "THERM-01"
    message:  "Thermal limit exceeded in window"

  invariant "stats.max - stats.min < THERMAL_DELTA_LIMIT"
    severity: :warn
    label:    "THERM-02"
    message:  "Unusual thermal gradient in window"

  out snapshot: ThermalSnapshot = {
    device_id: device_id,
    avg:       avg_temp,
    min:       stats.min,
    max:       stats.max,
    reading_count: stats.count
  }
    lifecycle :durable
}
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: PROP-023-stream-input-surface-v0
Status: proposal

[D] Decisions:
- stream T is always ESCAPE (Q2 from META-EXPERT-006 confirmed).
- Every stream must have a window declaration (OOF-S2 if missing).
- fold_stream with @window_bounded or @count_bounded(n) produces a CORE value.
- The accumulator function inside fold_stream must be CORE (OOF-S3 if not).
- Direct use of stream value outside fold_stream is OOF-S4.
- RuntimeMachine sees fold_stream as fold over a materialised Collection[T].
- Theoretical grounding: ω-transducer / KPN / Continuous Datalog.

[R] Recommendations:
- PROP-024: OLAPPoint[T, Dims] — stream snapshots naturally populate OLAP cells
- PROP-025: Invariant severity levels — essential for safety-critical streaming
- Runtime capability handler for stream_input should be designed as ESCAPE adapter

[X] Rejected:
- stream T as a CORE fragment (unbounded = cannot be CORE by definition)
- Implicit window (every stream must explicitly declare its window)
- Non-CORE lambdas inside fold_stream
- @count_bounded(n) with variable n (must be static literal)
```
