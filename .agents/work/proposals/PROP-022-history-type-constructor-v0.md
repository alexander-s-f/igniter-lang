# PROP-022: History[T] as First-Class Type Constructor v0

Status: closed
Closed: 2026-05-07 (Stage 2 — experiment PASS, META-EXPERT-009.1)
Date: 2026-05-06
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: PROP-004 (type system), PROP-013 (stdlib), PROP-016 (traits)
Stage: 2
Stage 3 extensions: PROP-028 (TEMPORAL fragment), PROP-022A (temporal manifest errata)
Source: META-EXPERT-005 §4.2, §4.3; META-EXPERT-006 §2.1; playgrounds/docs/experts/igniter-lang/igniter-lang-olap.md; igniter-lang-temporal-deep.md

---

## § 1. Motivation

PROP-004 v0 introduces `History[T]` and `BiHistory[T]` as **storage type
markers** on `Store`. They signal that a stored value has temporal tracking,
but they carry no operations and cannot be used as type expressions in
contract nodes.

Stage 2 promotes them to **first-class type constructors**:
- A contract node can declare `in price_history: History[Money]`
- Temporal operations are typed and compiler-checked
- The unification `History[T] ≡ OLAPPoint[T, {time: DateTime}]` is a
  formal theorem, not an analogy

This closes the "temporal gap" identified in the archaeology (META-EXPERT-005):
the language spec described temporal data but had no way to express operations
on it at the type level.

---

## § 2. Type Hierarchy

```
T  ⊑  History[T]  ⊑  BiHistory[T]

-- Meaning:
-- T is a point value (no temporal dimension)
-- History[T] is a sequence of T values indexed by DateTime (valid time only)
-- BiHistory[T] is a sequence of T values indexed by (DateTime × DateTime)
--   (valid time × transaction time — the bitemporal plane)
```

**Subtyping rules**:
- A `T` can be used where `History[T]` is expected (a constant value is a
  degenerate History with one interval covering all time)
- A `History[T]` can be used where `BiHistory[T]` is expected (single-axis
  is a degenerate bitemporal where transaction time = valid time)
- `BiHistory[T]` cannot be used where `History[T]` is expected without
  an explicit axis projection (which axis to use as the single dimension)

---

## § 3. The Unification Theorem

```
History[T]  ≡  OLAPPoint[T, {time: DateTime}]
```

This is not an analogy. A `History[T]` IS a 1D OLAP Point whose single
dimension is time. All OLAP operations defined in PROP-024 apply to
`History[T]` as the special case with `Dims = {time: DateTime}`.

Practical consequence: `History[T]` stdlib operations are implemented as
special cases of the OLAP stdlib. The codebase does not duplicate logic.

---

## § 4. History[T] Operations

### § 4.1 Point access

```
h[t]                -- T?    point access at DateTime t (None if gap at t)
h.at(t)             -- T?    same as h[t]
h.nearest(t)        -- T?    nearest recorded value to t
h.last_change_before(t)  -- ChangeEvent[T]?  last change before t
```

**Type rule**: `h: History[T]`, `t: DateTime` → `h[t]: Option[T]`

**Classification**: CORE if `h` is from a `Store` with `@temporal` annotation
and `t` is a CORE-available expression. ESCAPE if `h` requires a TBackend read.

### § 4.2 Range access

```
h[t1..t2]              -- History[T]  sub-sequence over interval
h.history_until(t)     -- History[T]  all intervals up to and including t
h.changes              -- Collection[ChangeEvent[T]]  all value changes
h.changes_in(period)   -- Collection[ChangeEvent[T]]  changes within period
```

### § 4.3 Aggregate operations (requires Numeric[T])

```
h.avg[period]          -- Option[T]   average over period
h.sum[period]          -- Option[T]   sum over period
h.min[period]          -- Option[T]   minimum over period
h.max[period]          -- Option[T]   maximum over period
h.rollup(:month)       -- History[T]  monthly aggregated history
h.rollup(:quarter)     -- History[T]  quarterly aggregated history
h.rollup(:year)        -- History[T]  annual aggregated history
```

### § 4.4 Structural queries

```
h.covered?             -- Boolean  is the full time domain covered?
h.gap_at(t)            -- Boolean  is time t in a gap?
h.gaps                 -- Collection[DateRange]  uncovered intervals
h.first_recorded       -- Option[ChangeEvent[T]]  earliest change
h.last_recorded        -- Option[ChangeEvent[T]]  most recent change
h.count_changes_in(p)  -- Integer  count of changes in period
h.volatility(period)   -- Float    std dev of changes (requires Numeric[T])
```

### § 4.5 Comparison and annotation

```
h.compare(other: History[T])   -- History[T]  signed deltas at each change point
h.with(annotation)             -- History[T]  attach metadata to the history
```

---

## § 5. BiHistory[T] — Bitemporal Operations

### § 5.1 The two time axes

```
valid_time (vt):       when the fact was true in business reality
transaction_time (tt): when the system recorded / corrected the knowledge
```

### § 5.2 The four canonical queries

| Query | Meaning | Use case |
|-------|---------|----------|
| `h[vt: now, tt: now]` | Current value, current knowledge | Live display |
| `h[vt: order.created_at, tt: order.created_at]` | Value at creation, knowledge at creation | Frozen legal value |
| `h[vt: order.created_at, tt: now]` | Value at creation, corrected knowledge | Retroactive audit |
| `h[vt: past_date, tt: report_date]` | Past value as known at reporting time | Regulatory report |

### § 5.3 Access syntax

```
-- Point access (both axes)
h[vt: t1, tt: t2]          -- Option[T]

-- Named shortcuts
h.current                   -- Option[T]   [vt: now, tt: now]
h.at(t)                     -- Option[T]   [vt: t, tt: now]
h.as_known_at(t)            -- Option[T]   [vt: now, tt: t]
h.as_known_when_valid(t)    -- Option[T]   [vt: t, tt: t]   ← frozen value

-- Slice over one axis (returns BiHistory[T])
h[vt: period, tt: now]      -- BiHistory[T]  historical values as currently known
h[vt: now, tt: past_year]   -- BiHistory[T]  how knowledge evolved over past year
```

### § 5.4 Corrections (ESCAPE — produces audit trail)

```
correct(
  h:          BiHistory[T],
  value:      T,
  valid_from: DateTime,
  valid_until: DateTime?,
  reason:     String
)  →  BiHistory[T]   -- ESCAPE: appends new tt record; original preserved
```

The correction never overwrites. It appends a new record with
`recorded_from = now`. All queries with `tt: before_correction` see the
original. All queries with `tt: now` see the correction.

---

## § 6. Annotations

```
@temporal    -- field/node tracking History[T] (single-axis)
@bitemporal  -- field/node tracking BiHistory[T] (two-axis)
```

These annotations appear on:
- Entity field declarations: `price: Money @temporal`
- Store declarations: `store :prices, History[Money] @temporal`
- Contract node declarations: `compute trend: History[Float] @temporal`

**Annotation semantics**: the compiler injects the appropriate `as_of`
parameter into the contract for every `@temporal` or `@bitemporal` node.
Without explicit `as_of`, the compiler uses `TemporalCtx.as_of` (from PROP-004).

---

## § 7. SemanticIR Shape

### § 7.1 Temporal input node

```json
{
  "kind": "temporal_input_node",
  "name": "price_history",
  "type": { "constructor": "History", "element_type": "Money" },
  "axis": "single",
  "store_ref": "prices",
  "as_of_ref": "as_of"
}
```

### § 7.2 Temporal access node

```json
{
  "kind": "temporal_access_node",
  "name": "current_price",
  "source_ref": "price_history",
  "access": "point",
  "time_ref": "as_of",
  "result_type": { "constructor": "Option", "element_type": "Money" }
}
```

### § 7.3 Temporal aggregate node

```json
{
  "kind": "temporal_aggregate_node",
  "name": "avg_price",
  "source_ref": "price_history",
  "operation": "avg",
  "period_ref": "last_quarter",
  "result_type": { "constructor": "Option", "element_type": "Money" }
}
```

---

## § 8. Example — Contract Using History[T]

```
contract PriceAnalysis {
  in product: Product
  in as_of:   DateTime = now()

  -- History[T] as first-class input
  read price_history: History[Money]
    from "products/{product.id}/price"
    lifecycle :durable
    @temporal

  -- Operations are typed and compiler-checked
  compute current_price: Option[Money]  = price_history.at(as_of)
  compute avg_last_90d:  Option[Money]  = price_history.avg[last_90_days(as_of)]
  compute monthly_trend: History[Money] = price_history.rollup(:month)

  compute volatility: Float =
    price_history.volatility(last_quarter(as_of))
    @requires Numeric[Money]

  invariant "current_price.some?"
    severity: :error
    message:  "No price recorded for product at as_of"

  out analysis: PriceAnalysisResult = {
    current:         current_price,
    avg_90d:         avg_last_90d,
    monthly_trend:   monthly_trend,
    volatility:      volatility
  }
}
```

---

## § 9. Example — BiHistory[T] for Medical Records

```
contract MedicationAudit {
  in patient_id:  String
  in decision_at: DateTime    -- when the clinical decision was made
  in report_at:   DateTime = now()

  -- BiHistory: read haemoglobin as the system understood it at decision time
  read hgb_history: BiHistory[LabValue]
    from "patients/{patient_id}/haemoglobin"
    lifecycle :durable
    @bitemporal

  -- "What did we know when we made the decision?"
  compute hgb_at_decision: Option[LabValue] =
    hgb_history[vt: decision_at, tt: decision_at]

  -- "What is the corrected value for that draw?"
  compute hgb_corrected: Option[LabValue] =
    hgb_history[vt: decision_at, tt: report_at]

  out audit: AuditRecord = {
    hgb_known_at_decision: hgb_at_decision,
    hgb_corrected_value:   hgb_corrected,
    correction_occurred:   hgb_at_decision != hgb_corrected
  }
}
```

---

## § 10. OOF Rules for History[T]

```
OOF-H1: History[T] access without as_of context
         → OOF if the contract has no TemporalCtx parameter

OOF-H2: BiHistory[T] access without explicit (vt, tt) axes
         → OOF: ambiguous — which axis is the "current" value?

OOF-H3: bi_history_correct inside a CORE contract
         → OOF: corrections are ESCAPE (external write + audit trail)

OOF-H4: History[T].avg or .sum without Numeric[T] impl
         → OOF: no Numeric implementation for element type
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: PROP-022-history-type-constructor-v0
Status: proposal

[D] Decisions:
- History[T] and BiHistory[T] are first-class type constructors in Stage 2.
- Subtyping: T ⊑ History[T] ⊑ BiHistory[T].
- History[T] ≡ OLAPPoint[T, {time: DateTime}] — formal unification.
- BiHistory[T] has four canonical queries; the compiler enforces axis disambiguation.
- Corrections are ESCAPE (produce audit trail via BiHistory append).
- @temporal and @bitemporal annotations trigger as_of parameter injection.
- Stage 1 compilers reject History[T] type expressions as OOF (via PROP-004 errata).

[R] Recommendations:
- PROP-023: stream T surface form (ESCAPE → fold_stream → CORE)
- PROP-024: OLAPPoint[T, Dims] (generalises History[T] to multi-dim)
- Update language-spec.md §3 with the full type hierarchy after PROP-022..025

[X] Rejected:
- History[T] as a mutable collection (it is append-only)
- Ambient Time.now inside History operations (as_of is always explicit)
- BiHistory corrections as CORE (corrections touch external storage)
```
