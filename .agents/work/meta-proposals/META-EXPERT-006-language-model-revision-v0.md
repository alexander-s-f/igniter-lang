# META-EXPERT-006: Language Model Revision v0 — Clean Slate

Role: `[Igniter-Lang Meta Expert]`
Status: proposal
Date: 2026-05-06
Track: `igniter-lang/docs/meta-proposals/META-EXPERT-006-language-model-revision-v0`
Depends on: META-EXPERT-005 (archaeology), META-EXPERT-002 (compiler frontier)
Policy: Pre-v1. No backward compatibility. Prefer target architecture.

---

## Why Now

Stage 1 pipeline is 2–3 slices from closing. The spec is still fluid. The
archaeology (META-EXPERT-005) surfaced 12 buried ideas and 5 formal identities
that were never incorporated into the current PROP sequence. This is the window
to revise the language model before the compiler hardens.

**The core question**: given full freedom, what does the language look like?

---

## Part 1: What the Archaeology Tells Us About the Current Model

### 1.1 Current model gaps (structural)

The current spec (`igniter-lang/docs/proposals/`) defines:

```text
CORE fragment  → statically-typed acyclic DAG, bounded fold/map/filter
ESCAPE         → capability-gated effects with typed receipts
OOF            → trust boundary violations → compile error
```

This is correct and should be preserved. But it is **incomplete** in three
structural ways that affect everything built on top:

**Gap A — No stream input surface**

The spec has no way to declare a contract whose input is an unbounded stream.
`fold`, `map`, `filter` operate over `Collection[T]` — a finite, in-memory
collection. There is no primitive for "process events as they arrive."

This directly blocks: IoT sensors, event-driven agents, reactive pipelines,
distributed mesh event correlation.

**Gap B — `History[T]` is not a first-class type constructor**

The temporal model (`lifecycle :window`, `snapshot`) exists at the DSL level
but `History[T]` is not a language type. You cannot write:

```
in price_history: History[Money]
compute avg = price_history.avg[last_quarter]
```

as a typed expression. The type system does not understand `History` as a
polymorphic container with temporal operations.

**Gap C — No multi-dimensional value type**

Enterprise data is multi-dimensional (price × product × region × time).
The current spec has no way to declare or operate on this structure.
Every multi-dimensional query requires ad-hoc `fold`/`filter` combinations.

### 1.2 What the five formal identities change

From META-EXPERT-005 §3:

> A contract is a Stratified Datalog program.

This is not a metaphor. If we accept it formally, the language design consequences are:

1. **Types flow along edges** (attribute grammar typing) — not just at boundaries
2. **Composition is the primary operation** (category theory) — `compose` must be free
3. **Constraints are uniform** (CCP) — guards, types, caches are all constraints
4. **The extension pathway is Datalog extensions** — not ad-hoc features:
   - Streaming → Continuous Datalog
   - Probabilistic → ProbLog
   - Temporal → Temporal Datalog
   - Distributed → partitioned Datalog evaluation

This should inform every PROP going forward.

---

## Part 2: Revised Core Primitives

No backward compatibility. Prefer the target architecture.

### 2.1 Four kinds of values (revised type hierarchy)

```text
Current:           Integer, Float, String, Boolean, Collection[T], Option[T]
Revised (add):     History[T], BiHistory[T], OLAPPoint[T, Dims], ~T

T ⊑ History[T] ⊑ BiHistory[T]
T ⊑ ~T  (probabilistic lift)
History[T] ≡ OLAPPoint[T, {time: DateTime}]  (unification)
```

**`History[T]`** is the first-class temporal container:

```
in price_history: History[Money]
compute avg_last_quarter = price_history.avg[last_quarter]
compute trend = price_history.rollup(:month)
```

**`~T`** is the probabilistic lift:

```
compute risk_score: ~Float = assess_risk(signals)
  @confidence(0.85)
```

**`OLAPPoint[T, Dims]`** is the multi-dimensional generalization:

```
olap_point Revenue {
  dimensions: { time: DateTime, product: Product, region: Region }
  measure: Money
}

compute q4_by_region: OLAPPoint[Money, {region: Region}] =
  Revenue[time: :q4_2026].rollup(:time)
```

### 2.2 Four kinds of input (revised input surface)

```text
Current:  in name: Type, read name: Type from "path" lifecycle :...
Revised (add): stream name: Type  ← unbounded input stream
```

`stream` is an ESCAPE-gated input. The contract receives events one at a time
from a capability-managed source. Inside the contract, a `stream` is processed
via `fold_stream` (bounded by window or count):

```
contract SensorAggregation {
  stream readings: SensorReading           ← ESCAPE: stream capability

  window "sensor[device_id]" {
    kind:     :count
    size:     100                          ← 100 readings per window
    on_close: :snapshot
  }

  compute avg_temp: Float =
    fold_stream(readings, 0.0, (acc, r) -> acc + r.temperature / 100.0)
    @window_bounded                        ← guarantees termination

  out snapshot = { avg_temp: avg_temp, device: device_id }
    lifecycle :durable
}
```

**Typing rule**: `stream T` is ESCAPE. `fold_stream(stream, init, fn)` with
`@window_bounded` or `@count_bounded(n)` returns `T` — provably terminating.

### 2.3 Three fragment classes (revised, formalized)

The existing CORE/ESCAPE/OOF classification is correct. Formalize it against
the Datalog identity:

```text
CORE  = Stratified Datalog (PTIME, confluent, deterministic)
        + History[T] reads (temporal Datalog)
        + ~T values (ProbLog subset)
        → provably terminating, auditable, reproducible

ESCAPE = Continuation-gated effects (declared capability required)
        + stream inputs (ESCAPE source, fold_stream bounded → CORE result)
        + external reads (network, DB, filesystem)
        → effect-typed, receipt-producing, auditable

OOF   = ambient IO, undeclared rebind, unresolved type variables
        → compile error, not emitted to SemanticIR
```

### 2.4 Invariants with severity (revised)

Current: invariants are binary (holds or exception).

Revised: four severity levels:

```
invariant "velocity <= MAX_VEL"
  severity: :error      ← raises InvariantViolation, blocks execution
  label: "REQ-SAFE-01"  ← traceable to requirements doc

invariant "response_time < 100ms"
  severity: :warn        ← logs + sets warning flag on output, does not raise
  overridable_with: :documented_justification

invariant "confidence >= 0.80"
  severity: :soft        ← advisory; output tagged with :uncertain if violated

invariant "p95_latency < 500ms"
  severity: :metric      ← records to ObsPacket only; no execution effect
```

Overrides are typed and audit-trailed via `BiHistory`.

### 2.5 Unit types as refinement types

```
type Kelvin  = Float where value >= 0.0
type Meter   = Float
type Second  = Float where value >= 0.0
type MeterPerSecond = Meter / Second     ← unit algebra
type Newton  = KiloGram * MeterPerSecond * MeterPerSecond

-- Compiler rejects:
compute velocity: MeterPerSecond = Kelvin.new(300)  -- type error
```

Unit algebra is dimensional analysis: the compiler tracks physical dimensions
as type-level information. Wrong unit → compile error, not runtime crash.

This is a refinement type expressed via the existing invariant system, elevated
to first-class status for dimensional values.

### 2.6 Deadline contracts

```
contract NavigationStep
  deadline: 10.milliseconds
{
  compute obstacle_map: ObstacleMap = ..., wcet: 3ms
  compute path:        Path         = ..., wcet: 4ms
  compute command:     VelocityCmd  = ..., wcet: 2ms

  -- Compiler computes critical path: 3 + 4 + 2 = 9ms ≤ 10ms → OK
  -- If critical path > deadline → compile error (not runtime failure)
}
```

The DAG structure makes WCET analysis tractable: critical path = max path length
through the dependency graph. `wcet:` annotations are declared by the implementer,
verified statically.

---

## Part 3: Revised Type System Shape

### 3.1 Type expression grammar (extended)

```ebnf
type_expr =
    primitive_type                      -- Integer, Float, String, Boolean
  | "Collection" "[" type_expr "]"
  | "Option"     "[" type_expr "]"
  | "Result"     "[" type_expr "," type_expr "]"
  | "History"    "[" type_expr "]"      -- NEW: temporal container
  | "BiHistory"  "[" type_expr "]"      -- NEW: bitemporal container
  | "OLAPPoint"  "[" type_expr "," dims_expr "]"  -- NEW: multi-dimensional
  | "~" type_expr                       -- NEW: probabilistic lift
  | unit_type                           -- NEW: Kelvin, Meter, Newton...
  | record_type                         -- { field: Type, ... }
  | generic_type                        -- T where T: Trait
```

### 3.2 Trait system (minimal, not full Haskell)

Required for monomorphization and stdlib resolution:

```
trait Numeric { add, sub, mul, div, compare }
trait Temporal { as_of, history, rollup }
trait Foldable { fold, map, filter, count, first }
trait Observable { to_obs_packet }

impl Numeric for Integer
impl Numeric for Float
impl Numeric for Decimal[N]
impl Temporal for History[T]
impl Temporal for BiHistory[T]
impl Foldable for Collection[T]
impl Foldable for History[T]    -- History is Foldable over time
impl Foldable for OLAPPoint[T, Dims]  -- OLAP is Foldable over any dimension
```

`impl Foldable for History[T]` is the bridge: temporal reasoning reuses
the same fold/map/filter primitives as collection reasoning.

### 3.3 Type rules for new constructs

```text
stream T                    → ESCAPE, requires stream capability
fold_stream(s: stream T, init: A, fn: (A, T) -> A) @window_bounded
                            → A  (provably terminating)

history[T].avg[period]      → T  (requires Numeric[T])
history[T].rollup(:month)   → History[T]
history[T][t]               → T  (point access at time t)

OLAPPoint[T, D].slice(d: v) → OLAPPoint[T, D - {d}]  (reduces dims by 1)
OLAPPoint[T, {}]            → T  (fully resolved = scalar)
OLAPPoint[T, D].rollup(d)   → OLAPPoint[T, D - {d}]  (aggregate over d)

~T + ~T → ~T                (uncertainty propagates)
~T -> T requires: @exact or @best_effort(fallback)
```

---

## Part 4: Revised Fragment Grammar (source surface)

The current source surface already has `contract`, `fn`, `type`, `module`.
Revised additions (backwards compatible within v0 — these are new surfaces):

```
-- New top-level declarations
olap_point <Name> { dimensions: {...}, measure: Type, source: fn }
trait <Name> { <method_names> }
impl <Trait> for <Type> { ... }

-- New input kinds
stream <name>: <Type>          -- ESCAPE-gated unbounded input

-- New compute annotations
@window_bounded                -- fold_stream is bounded by declared window
@count_bounded(n)              -- fold_stream bounded by count n
@deadline(duration)            -- node-level WCET annotation (wcet:)
@confidence(f)                 -- probabilistic node confidence
@bitemporal                    -- field tracking BiHistory
@temporal                      -- field tracking History

-- New invariant parameters
severity: :error | :warn | :soft | :metric
label: "REQ-SAFE-01"
overridable_with: :documented_justification

-- New contract parameters
deadline: <Duration>           -- contract-level WCET constraint
```

---

## Part 5: Validation — What Each Buried Idea Proves

### Architecture fit table

| Buried idea | Primitive required | Stage | Evidence it fits |
|------------|-------------------|-------|-----------------|
| Streaming contracts / IoT sensors | `stream T` + `fold_stream` + `@window_bounded` | 2 | Path C from igniter-lang.md §5.3; KPN identity from theory.md |
| OLAPPoint for sensor data | `OLAPPoint[T, {time, sensor, location}]` | 2 | History≡OLAPPoint from olap.md §4; cluster scatter-gather from olap.md §6 |
| BiHistory for calibration corrections | `BiHistory[T]` with `[vt: t, tt: t]` queries | 2 | temporal-deep.md §1; science-critical.md §1 |
| Robot safety invariants | `invariant ... severity: :error label: "REQ-SAFE-01"` | 2 | science-critical.md §2.3 |
| Space mission rules uplink | `rule` as serializable data | 3 | science-critical.md §6.4 |
| Agent goal-directed planning | `temporal synthesis` via LP | 4 | temporal-deep.md §2 |
| Unit type safety | `type Kelvin = Float where value >= 0.0` | 2 | science-critical.md §6.1 |
| Deadline contracts | `contract C, deadline: 10ms` | 3 | science-critical.md §6.3 |
| Plastic Runtime Cells | `cell` concept | 3 | plastic-runtime-cells.md |
| Graph canvas / Igniter Plane | visualization layer | 3 | igniter-plane.md |

### Domains opened by the revised model

| Domain | Key primitive | What becomes possible |
|--------|-------------|----------------------|
| IoT / sensors | `stream T` + `OLAPPoint` | Typed event pipelines, bounded aggregation, multi-dimensional sensor queries |
| Robotics | `deadline:` + `invariant severity:` + `label:` | Safety requirements = compiler errors; WCET proofs; cert artifacts |
| Space / telemetry | `BiHistory[T]` + causal `as_of` | "What did we know and when?" query; telemetry re-calibration without overwrite |
| Science / reproducibility | `BiHistory[T]` + `as_of` on all reads | Reproducibility as language property; `as_of: original_date` = exact rerun |
| Medicine | `BiHistory[T]` + `invariant label:` + `as_of` on protocols | Guideline → compiler invariant; audit by construction; protocol versioning free |
| Distributed agents | `stream T` + `cell` + ESCAPE mesh capability | Typed agent-to-agent communication; ownership transfer with audit trail |
| OSINT / intelligence | `History[T]` + `~T` + rule synthesis | Evidence chains typed; confidence tracked; goal-directed synthesis |
| ERP / business | `OLAPPoint` + temporal rules + `BiHistory[T]` | Multi-dim reporting; rule feedback cycle detection; bitemporal corrections |

---

## Part 6: What Does NOT Change

The following are confirmed correct and must not be revised:

```text
✅  CORE/ESCAPE/OOF classification
✅  SemanticIR as stable compiler boundary (PROP-019.1)
✅  CompilationReport + SemanticIRProgram separation
✅  Classifier pass (PROP-020)
✅  TypeChecker narrow (PROP-021)
✅  .igapp/ assembler acceptance criteria (PROP-019.1 §Part 7)
✅  RuntimeMachine load/evaluate/checkpoint/resume
✅  ObsPacket + CompatibilityReport shape
✅  Stage 1 pipeline (do not touch until closed)
```

The revision adds type-level primitives and surface forms. It does not
change the pipeline architecture or the compilation model.

---

## Part 7: Open Questions for Revision

### Q1 — `History[T]` in Stage 1 or Stage 2?

Current Stage 1 includes `lifecycle :window` and `snapshot` at DSL level.
Should `History[T]` as a typed value be Stage 1 (closes the type gap now)
or Stage 2 (adds after the assembler works)?

**Recommendation**: Stage 2. Keep Stage 1 focused on the assembler pipeline.
`History[T]` as a type constructor can be added without changing the pipeline.

### Q2 — `stream T` surface: ESCAPE or new fragment?

Option A: `stream T` is a variant of `read ... lifecycle :stream` — ESCAPE,
typed, capability-gated.

Option B: `stream T` is a new fourth fragment class alongside CORE/ESCAPE/OOF.

**Recommendation**: Option A. `stream T` is ESCAPE by definition (unbounded
external source). The fragment class is determined by the trust boundary, not
by the input surface kind.

### Q3 — `OLAPPoint` as language primitive vs. library type?

Option A: `olap_point` is a top-level declaration (like `contract`, `fn`, `type`).
Option B: `OLAPPoint[T, Dims]` is a type alias over `History` with extra methods.

**Recommendation**: Option A for declarations, B for the type expression.
`olap_point Revenue { ... }` declares it; `OLAPPoint[Money, {time, region}]`
is its type in expressions.

### Q4 — Unit types: built-in or stdlib?

Option A: Built-in unit algebra in the type checker.
Option B: `type Kelvin = Float where value >= 0.0` as user-defined refinement
types (already possible via invariants, just needs first-class syntax).

**Recommendation**: Option B first (uses existing invariant machinery).
Option A (full unit algebra with dimensional checking) is Stage 3.

### Q5 — Invariant `severity:` in Stage 1 TypeChecker or later?

`severity:` is purely syntactic and semantic at the language level —
it does not affect the classifier or SemanticIR shape (an invariant with
`severity: :warn` emits the same IR node, just with a severity field).

**Recommendation**: Stage 2 surface form, no Stage 1 impact.

---

## Handoff

```text
[Igniter-Lang Meta Expert]
Track: META-EXPERT-006-language-model-revision-v0
Status: proposal — requires review and decision on Q1..Q5

[D] Decisions made:
- History[T], BiHistory[T], OLAPPoint[T,Dims], ~T are correct additions
- stream T is ESCAPE, bounded by @window_bounded or @count_bounded
- Invariant severity levels (:error/:warn/:soft/:metric) are correct additions
- Unit types as refinement types (not full unit algebra) for Stage 2
- Deadline contracts with compile-time WCET analysis for Stage 3
- CORE/ESCAPE/OOF classification is confirmed correct, not changed

[R] Recommendations:
- Stage 1: closed without touching any of this. Assemble first.
- Stage 2: History[T], OLAPPoint, stream T, invariant severity
- Stage 3: BiHistory, deadline contracts, unit algebra, Plastic Cells
- Validate: write one source.ig file that uses stream T + OLAPPoint to
  process sensor data — this is the Stage 2 acceptance fixture

[Q] Open questions: Q1..Q5 above require user decision

[X] Rejected:
- Changing Stage 1 pipeline for any of this
- Full Haskell-style type classes (only Numeric/Temporal/Foldable/Observable)
- Turing-complete core (CORE remains provably terminating)
- Automatic cycle resolution in rule system (must be explicit)

[Next]:
- User review of Q1..Q5
- [Compiler/Grammar Expert]: extend grammar for stream T surface form (Stage 2 PROP)
- [Compiler/Grammar Expert]: History[T] as type constructor in type system (Stage 2 PROP)
- [Research Agent]: Stage 1 first (assembler, typechecker, stdlib)
```
