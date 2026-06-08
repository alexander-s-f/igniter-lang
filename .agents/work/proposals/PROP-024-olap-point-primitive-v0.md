# PROP-024: OLAPPoint[T, Dims] as First-Class Language Primitive v0

Status: closed
Closed: 2026-05-07 (Stage 2 — experiment PASS, META-EXPERT-009.1)
Date: 2026-05-06
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: PROP-022 (History[T]), PROP-015 (module system), PROP-016 (traits)
Stage: 2
Source: META-EXPERT-005 §4.2; META-EXPERT-006 §2.1, §2.3; playgrounds/docs/experts/igniter-lang/igniter-lang-olap.md (full)

---

## § 1. Motivation

Enterprise, scientific, and IoT data is inherently **multi-dimensional**:

```
Price     = f(time, product, customer_tier, region)
Revenue   = f(time, product, channel, region)
Inventory = f(time, warehouse, product, sku)
Sensor    = f(time, sensor_id, location)
```

`History[T]` captures one dimension (time). But a pricing model that varies
by product AND region AND time cannot be expressed as `History[Money]` without
losing structural information. The result is ad-hoc `fold`/`filter` combinations
that are untyped, untestable, and opaque.

The solution is `OLAPPoint[T, Dims]` — a **multi-dimensional generalisation of
`History[T]`** that emerges directly from the observation that
`History[T] ≡ OLAPPoint[T, {time: DateTime}]`.

This is not an analytics bolt-on. It is the type-level expression of a
truth that was always in the spec: temporal data is 1D analytical data.

**Design principle** (Q3 from META-EXPERT-006 resolved):
- `olap_point Name { ... }` is a top-level declaration (like `contract`, `type`)
- `OLAPPoint[T, Dims]` is the type expression in contract nodes

---

## § 2. The Unification

```
History[T]  ≡  OLAPPoint[T, {time: DateTime}]

-- All History operations are special cases of OLAP operations:
h[t]              ≡  OLAPPoint_slice(olap, time: t)    -- slice to scalar
h[t1..t2]         ≡  OLAPPoint_range(olap, time: t1..t2)
h.avg[period]     ≡  olap_rollup(olap, :time, fn: :avg)[time: period]
h.rollup(:month)  ≡  olap_rollup(olap, :time, grain: :monthly)
```

This unification means:
1. `History[T]` stdlib is implemented as a specialisation of the OLAP stdlib
2. The cluster distribution model for History (sealed segments, content-addressing)
   applies uniformly to all OLAP points
3. Promoting a `History[T]` to multi-dimensional OLAP does not break existing code —
   it adds new access patterns

---

## § 3. olap_point Declaration

### § 3.1 Syntax

```ebnf
olap_decl ::= 'olap_point' IDENT '{'
                'dimensions:' '{' {dim_decl ','} '}'
                'measure:'    type_expr ','
                ['granularity:' '{' {grain_decl ','} '}']
                ['source:'    expr]
                ['indexed:'   '[' {SYMBOL ','} ']']
              '}'

dim_decl  ::= IDENT ':' type_expr
grain_decl ::= IDENT ':' SYMBOL    -- e.g. time: :daily
```

### § 3.2 Examples

```
-- Multi-dimensional revenue
olap_point Revenue {
  dimensions: {
    time:    DateTime
    product: Product
    region:  Region
    channel: Enum[:online, :retail, :wholesale]
  }
  measure:   Money

  granularity: {
    time:   :daily      -- default aggregation unit
    region: :country    -- default roll-up level
  }

  source: fn(t, product, region, channel) -> Money =
    FulfilledOrders {
      period:  t.day
      product: product
      region:  region
      channel: channel
    }.total

  indexed: [:time, :product]   -- cluster shard keys
}

-- IoT sensor data
olap_point SensorReading {
  dimensions: {
    time:      DateTime
    sensor_id: String
    location:  GeoPoint
  }
  measure: Float

  granularity: { time: :second }

  source: fn(t, sensor_id, location) -> Option[Float] =
    sensor_registry[sensor_id].reading_at(t)

  indexed: [:time, :sensor_id]
}

-- History[T] as a 1D OLAP Point (the unification, explicit)
olap_point ProductPriceHistory {
  dimensions: { time: DateTime }
  measure:    Money
  source:     fn(t) -> Option[Money] = product.price_at(t)
  indexed:    [:time]
}
-- Equivalent to: History[Money] for product.price
```

---

## § 4. Type Expression

```
OLAPPoint[T, Dims]

-- where:
--   T    = the measure type (Integer, Float, Money, etc.)
--   Dims = a record type describing the dimension names and their types
--          e.g. {time: DateTime, product: Product, region: Region}
```

**Type rules**:

```
-- Slice: fix one dimension, reduce dimensionality by 1
OLAPPoint[T, {d₁: D₁, d₂: D₂, d₃: D₃}][ d₁: v ]
  →  OLAPPoint[T, {d₂: D₂, d₃: D₃}]      -- v must be of type D₁

-- Rollup: aggregate over a dimension, eliminate it
olap_rollup(OLAPPoint[T, {d₁: D₁, d₂: D₂}], :d₁)
  →  OLAPPoint[T, {d₂: D₂}]

-- Fully resolved: no dimensions left = scalar
OLAPPoint[T, {}]  →  T

-- History is 1D OLAP:
History[T]  ≡  OLAPPoint[T, {time: DateTime}]
```

---

## § 5. OLAP Operations

### § 5.1 Slice — fix a dimension (reduces dimensionality)

```
-- Fix time dimension:
Revenue[time: :q4_2026]
  →  OLAPPoint[Money, {product: Product, region: Region, channel: Enum[...]}]

-- Fix product dimension:
Revenue[product: laptop]
  →  OLAPPoint[Money, {time: DateTime, region: Region, channel: Enum[...]}]

-- Chain slices (dice):
Revenue[time: :q4_2026][region: :west]
  →  OLAPPoint[Money, {product: Product, channel: Enum[...]}]
```

### § 5.2 Rollup — aggregate over a dimension

```
Revenue.rollup(:region)                   -- sum across all regions (default: sum)
Revenue.rollup(:region, fn: :avg)         -- average instead of sum
Revenue.rollup(:time, grain: :monthly)    -- monthly totals
Revenue.rollup(:time, grain: :quarterly)  -- quarterly totals
```

**Cluster semantics**: `rollup` over an `indexed:` dimension generates a
**scatter-gather** execution plan automatically:

```
1. SCATTER   find all partitions covering the rollup dimension
2. PARALLEL  for each partition: local rollup (map step)
3. GATHER    collect partial results
4. REDUCE    merge into final OLAPPoint (reduce step)
```

The programmer declares WHAT. The compiler generates the distributed execution.

### § 5.3 Drill — increase granularity

```
Revenue.drill(:time, :hourly)    -- from daily to hourly
Revenue.drill(:region, :city)    -- from country to city level
```

### § 5.4 Compare — compute deltas

```
Revenue[time: :q4_2026].compare(Revenue[time: :q3_2026])
-- Returns: OLAPPoint[Money, {product, region, channel}]
--          where cells are signed deltas (positive = growth)
```

### § 5.5 Transform — apply function to each cell

```
Revenue.transform { |v| v * 1.15 }    -- 15% uplift scenario
Revenue.transform { |v| ~v }           -- lift to approximate (~Money)
```

### § 5.6 Resolve — extract scalar from 0-dim OLAP

```
Revenue[time: :q4_2026][product: laptop][region: :west][channel: :online]
  →  OLAPPoint[Money, {}]  (zero-dimensional)
  |> olap_resolve           →  Money
```

---

## § 6. OLAP Point in Contracts

An `OLAPPoint` declared in a module or system is a **global analytical node**
accessible by name in any contract:

```
contract RegionalReport {
  in period: DateRange
  in region: Region

  -- Revenue is a named OLAPPoint declared globally
  compute monthly_revenue: OLAPPoint[Money, {time: DateTime}] =
    Revenue[time: period, region: region]
    .rollup(:time, grain: :monthly)

  compute top_products: Collection[{product: Product, revenue: Money}] =
    Revenue[time: period, region: region]
    .rollup(:time)                          -- total for period
    .slice_to_list(:product)               -- convert to list
    |> sort_by { .measure }
    |> take(10)

  compute yoy_delta: OLAPPoint[Money, {time: DateTime}] =
    monthly_revenue.compare(
      Revenue[time: period.shift(-1.year), region: region]
      .rollup(:time, grain: :monthly)
    )

  out report: RegionalReport = {
    monthly:     monthly_revenue,
    top_10:      top_products,
    yoy_compare: yoy_delta
  }
}
```

---

## § 7. Operational → Analytical Bridge

The `source:` function is the bridge between the operational contract system
and the OLAP engine:

```
olap_point Revenue {
  source: fn(t, product, region, channel) -> Money =
    FulfilledOrders {          -- operational: contract execution
      period:  t.day
      product: product
      region:  region
      channel: channel
    }.total                   -- OLAP engine materialises the result
}
```

The OLAP engine calls the source contract at each unique input combination
and stores the result. Subsequent reads come from the content-addressed
segment cache — the source contract is called only once per unique key.

**Result**: contract correctness for individual facts + OLAP performance
for aggregate queries.

---

## § 8. Cluster Distribution

### § 8.1 Partition strategy

```
olap_point Revenue {
  indexed: [:time, :product]   -- shard by (time × product)
}
```

The cluster assigns each `(time_range, product_range)` block to a node.
- Queries specifying both indexed dimensions → single node (hot path)
- Queries scanning many products → parallel fan-out (scatter-gather)

### § 8.2 Segment cache hierarchy

```
L1: In-process    -- sealed segments on local node (immutable, no TTL needed)
L2: Node-local    -- recently fetched remote segments (content-addressed)
L3: Cluster gossip -- segments replicated across replication_factor nodes
L4: Cold storage  -- archived segments (object storage, S3-compatible)
```

Sealed segments are content-addressed: `segment_id = SHA256(segment_content)`.
A cache hit is always correct — no cache invalidation ever needed for sealed segments.
Only the head segment (unsealed, mutable) requires coordination.

---

## § 9. SemanticIR Shape

### § 9.1 olap_point declaration node

```json
{
  "kind": "olap_point_decl",
  "name": "Revenue",
  "dimensions": {
    "time":    "DateTime",
    "product": "Product",
    "region":  "Region",
    "channel": "Enum[online,retail,wholesale]"
  },
  "measure_type": "Money",
  "granularity": { "time": "daily", "region": "country" },
  "source_ref": "revenue_source_fn",
  "indexed": ["time", "product"]
}
```

### § 9.2 OLAP access node

```json
{
  "kind": "olap_access_node",
  "name": "monthly_revenue",
  "olap_ref": "Revenue",
  "slices": [
    { "dim": "time",   "value_ref": "period" },
    { "dim": "region", "value_ref": "region" }
  ],
  "operation": "rollup",
  "rollup_dim": "time",
  "rollup_grain": "monthly",
  "result_type": { "constructor": "OLAPPoint", "measure": "Money", "dims": { "time": "DateTime" } }
}
```

---

## § 10. OOF Rules for OLAPPoint

```
OOF-O1: OLAPPoint type expression in a Stage 1 compiler
         → "OLAPPoint is a Stage 2 construct — not supported in Stage 1"

OOF-O2: olap_rollup over a non-indexed dimension without explicit scatter-gather flag
         → warning (not OOF): "rollup over non-indexed dimension may be slow; add to indexed:"

OOF-O3: OLAPPoint with no source: and no data (empty OLAP point)
         → OOF: "OLAPPoint must declare a source function or be populated via stream snapshot"

OOF-O4: Direct mutation of an OLAPPoint outside of a source: function
         → OOF: "OLAPPoint cells are immutable; write only via source or stream snapshot"
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: PROP-024-olap-point-primitive-v0
Status: proposal

[D] Decisions:
- OLAPPoint[T, Dims] is a first-class type constructor (Stage 2).
- olap_point Name { ... } is a top-level declaration alongside contract/type/fn.
- History[T] ≡ OLAPPoint[T, {time: DateTime}] — formal unification, stdlib reuse.
- Rollup over indexed: dimensions → automatic scatter-gather execution plan.
- Sealed segments are content-addressed: no cache invalidation ever needed.
- source: fn is the operational→analytical bridge (called once per unique key).
- Stage 1 compilers reject OLAPPoint type expressions as OOF-O1.

[R] Recommendations:
- Update language-spec.md § 3.3, § 5 after PROP-022..025 are accepted
- PROP-026 (future): ~T probabilistic lift + approximate OLAPPoint cells
- Connect stream snapshot (PROP-023 on_close: :snapshot) to OLAPPoint population:
  a stream snapshot writes to an OLAPPoint cell → the unification is operational,
  not just theoretical

[X] Rejected:
- OLAPPoint as a library type only (must be top-level decl for cluster indexing)
- Mutable OLAP cells (always append-only/sealed)
- OLAP query language separate from contract language (operations are contract nodes)
```
