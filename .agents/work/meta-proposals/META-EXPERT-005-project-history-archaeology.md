# META-EXPERT-005: Project History Archaeology & Buried Ideas Report

Role: `[Igniter-Lang Meta Expert]`
Status: done
Date: 2026-05-06
Track: `igniter-lang/docs/meta-proposals/META-EXPERT-005-project-history-archaeology`
Depends on: META-EXPERT-001 (strategic analysis)
Scope: Full project corpus — Ruby gem, legacy packages, playground expert docs, igniter-lang

---

## 1. Origin Story — Where The Language Actually Started

The project started as **a Ruby gem for declaring business logic as validated
dependency graphs** (`lib/igniter/`, `packages/`). The original insight was not
a language — it was an observation about density mismatch:

> `compute :vendor, depends_on: :vendor_id, call: FetchVendor, cache_ttl: 60`
> → declares 4 semantic claims in one line, but requires 5 lines of Ruby class overhead
> to implement.

The contract model was always there. The language emerged from asking:
*"what if the computation inside each node spoke the same language as the graph topology?"*

First research document: `playgrounds/docs/experts/igniter-lang/igniter-lang.md` (2026-04-26)
— already identified the SIR (Semantic Information Ratio) hypothesis and the Turing
completeness paths (Path A: recursive contracts, Path B: iterate, Path C: streaming).

The IoT / mesh cluster origin is confirmed by:
- `playgrounds/legacy/packages/igniter-cluster/` — full cluster/mesh/trust/replication layer
- `playgrounds/legacy/packages/igniter-agents/` — actor runtime + agent libraries
- The cluster came **before** the language. The language is the cluster's missing interface.

---

## 2. The Legacy Package Map (What Was Built But Is Now Legacy)

```
playgrounds/legacy/packages/
  igniter-core/           ← The original Igniter gem (contracts, compiler, runtime)
  igniter-agents/         ← Actor runtime: Igniter::Agent, Registry, Supervisor, AI::Agents
  igniter-cluster/        ← Cluster/mesh/trust/replication layer
  igniter-ai/             ← AI integration layer
  igniter-app/            ← Application capsule layer
  igniter-frontend/       ← Frontend (Arbre + Tailwind path)
  igniter-rails/          ← Rails integration
  igniter-schema-rendering/ ← Schema rendering
  igniter-sdk/            ← SDK layer
  igniter-server/         ← Server layer
  igniter-extensions-legacy/ ← Legacy extensions
```

**Key insight**: The cluster, agents, and AI layers were already built — they are not
future plans. The missing piece was always a formal **interface language** to
declare what agents compute and how data flows through the cluster.

Igniter-Lang is that missing piece. It retroactively becomes the specification
language for what `igniter-cluster` and `igniter-agents` already implement.

---

## 3. Theoretical Foundations — The Five Identities

From `igniter-lang-theory.md` (the most important buried document):

A contract is simultaneously (these are formal identities, not analogies):

| Perspective | Identity |
|------------|---------|
| **Anokhin TFS** | Result-oriented functional system — outputs define structure |
| **Attribute Grammars** (Knuth 1968) | `compute` = synthesized attr, `input` = inherited attr, `resolution_order` = AG evaluation schedule |
| **CCP** (Saraswat 1989) | `tell(c)` = compute node write, `ask(c)` = guard, confluence = determinism despite concurrency |
| **Stratified Datalog** | Decidable, PTIME, confluent — `resolution_order` IS the Datalog stratification |
| **Category Theory** | Contracts form a monoidal category; `compose` = morphism composition |

**Critical implication for the language**: every well-studied extension of Datalog
is a candidate for a well-founded extension of the contract language:

```
Recursive Datalog       → recursive contracts (Path A)
Probabilistic Datalog   → ~T probabilistic nodes
Temporal Datalog        → History[T], as_of, temporal rules
Continuous Datalog      → streaming contracts (Path C)
Constraint Logic Prog.  → guards as constraints
```

The research was done. It's buried in playgrounds.

---

## 4. Buried Ideas That Deserve Formalization

### 4.1 Streaming Contracts (Path C) — Direct Answer to IoT / Event Loop

From `igniter-lang.md` §5.3:

```
contract LivePricing {
  in vendor_id: Id
  stream events: PriceEvent           ← unbounded stream input

  compute quote = fold(events, initial_quote) { |state, event|
    update_quote(state, event)
  }

  out quote = quote
}
```

This is the missing primitive for sensor/IoT use cases. The language already
specified this as "Path C to Turing completeness" via corecursion — but it was
never formalized into a PROP.

**Gap**: No PROP for `stream` surface form. Not in the classifier, type checker,
or SemanticIR emitter. This is Stage 2+ work but the foundation is theoretically
clear.

**Theoretical grounding**: ω-transducer / Büchi automata for streaming contracts.
Connection to Kahn Process Networks (KPN) — the contract graph becomes a KPN
where each node is a single-shot process fed by a bounded window of a stream.

### 4.2 OLAPPoint — The Most Powerful Buried Primitive

From `igniter-lang-olap.md`:

```
History[T] ≡ OLAPPoint[T, {time: DateTime}]
```

The unification: `History` is a 1D OLAP structure. The generalization gives:

```
olap_point Revenue {
  dimensions: { time: DateTime, product: Product, region: Region, channel: Channel }
  measure:    Money
  source:     fn(t, product, region, channel) -> Money = ...
}

Revenue[time: :q4_2026].rollup(:region)   -- parallel scatter-gather across cluster
```

This is **not an analytics bolt-on** — it is the natural generalization of
`History[T]` that emerges from the observation that enterprise data is multi-
dimensional. And the cluster distribution is free: sealed OLAP segments are
content-addressed, so any node can cache without coordination.

**Why this matters for IoT**: sensor data IS an OLAPPoint:
```
olap_point SensorReading {
  dimensions: { time: DateTime, sensor_id: SensorId, location: GeoPoint }
  measure:    Float
}
```

Time-series sensor data + multi-dimensional queries = OLAPPoint.
The "event loop" problem dissolves: the stream fills OLAPPoint cells,
CORE contracts query bounded windows over them.

### 4.3 BiHistory[T] — The Time Machine

From `igniter-lang-temporal-deep.md`:

```
T  ⊑  History[T]  ⊑  BiHistory[T]  ⊑  ~BiHistory[T]
```

Four canonical queries:
1. `price[vt: now, tt: now]` — current, current knowledge (live display)
2. `price[vt: order.created_at, tt: order.created_at]` — frozen order total
3. `price[vt: order.created_at, tt: now]` — retroactive audit
4. `price[vt: past_date, tt: report_date]` — regulatory report

**Why this is buried gold**: it solves the replication crisis in science (§1),
telemetry corrections in space (§3), medical record corrections (§4), and
sensor data re-calibration in IoT — all with the same primitive.

The implementation plan was already sketched:
- ~400 LOC in compiler + ~150 in DSL + ~200 in runtime
- "One concentrated sprint — not a multi-month project"

### 4.4 Rule System with Causal Cycle Detection

From `igniter-lang-temporal-deep.md` §3:

The Rule Dependency Graph (RDG) catches hidden feedback loops:

```
SeasonalDiscount → Product.effective_price → Order.total → VolumeDiscount.applies
VolumeDiscount   → Order.effective_total   → Order.total   (FEEDBACK — caught)
```

Resolution strategies:
- Explicit order (`>>` composition)
- Snapshot (`@snapshot` — freeze pre-rule value)
- Convergence (`@converge(max_iterations: 3, tolerance: 0.01)`)

**For distributed agents**: rule evaluation cycles map directly to agent feedback loops.
The cycle detection mechanism could be the foundation for a "safe agent coordination"
guarantee — agents that form feedback loops are caught at compile time.

### 4.5 Temporal Synthesis — Goal-Directed Rule Generation

From `igniter-lang-temporal-deep.md` §2:

```
synthesize rule for OrderManagement {
  goal: PeriodReport { period: december }.actual_revenue >= 1.15 * november_revenue

  template: rule SynthesizedPromotion : Product {
    applies: { months: [:december] }
    compute: fn(product) -> Float = ?rate    ← synthesis target
    priority: 60
    combines: :override
  }

  constraints: [PriceFloor, CustomerFairness, MaxDiscountRate(0.30)]
}
```

Reduces to **linear programming** (PTIME via simplex). The system finds the
smallest change that achieves the goal while respecting constraints.

**For OSINT / intelligence**: this is goal-directed evidence synthesis. Given
an intelligence goal, find the minimum evidence queries that confirm/deny it.
The "synthesis target" is the evidence collection strategy, not a pricing rate.

### 4.6 Plastic Runtime Cells — The Missing Ownership Primitive

From `plastic-runtime-cells.md`:

```
RuntimeCell {
  identity:   CellIdentity       ← stable content-addressed fingerprint
  contracts:  [CompiledGraph]    ← what it computes
  interfaces: CellInterface      ← declared inputs/outputs
  capsule:    ApplicationCapsule ← portability envelope
  surface:    SurfaceManifest    ← human interaction layer
  policy:     CellPolicy         ← credentials + capabilities
  health:     CellHealth         ← current vitality
  mutations:  [CellMutation]     ← history of structural changes
}
```

Plasticity operations: Move, Replicate, Split, Merge, Hand Off, Retire.

**Why this is buried**: it's the missing concept between "contract" and "distributed
agent". A contract is a computation unit. A cell is the ownership unit. An agent
can say "I own cell:auth-workflow on node-4, I will replicate it to node-7."

For mesh cluster IoT: a Cell is the natural unit of deployment for a sensor
processing pipeline. The Cell migrates with its data locality policy intact.

### 4.7 Igniter Plane — Spatial Graph Navigation

From `igniter-plane.md` (38KB, fully detailed):

A living graph canvas where every process, agent, contract, data artifact,
and session is a navigable node. Seven interaction modes:
- Navigate (pan/zoom), Query (`/type:agent status:waiting`),
- Natural Language (`?what is blocking the auth refactor?`),
- Command (`Coordinator > plan auth_refactor budget:8h`),
- Pin, Trace (show path between two nodes), Compose (sketch new contracts)

**The compose mode**: drag connections between nodes → generates DSL:
```ruby
# Generated from canvas composition:
compute :plan_result, depends_on: :auth_scope, call: Agents::Coordinator
compose :auth_workflow, imports: { scope: :auth_scope }
```

This connects the canvas to the DSL REPL — **the canvas IS the REPL**.

For distributed agents: the Plane is the observability layer. Cluster peers
appear as diamond nodes with capability badges. Decision nodes pulse amber.
Agent-annotated highlights tell operators what requires attention.

### 4.8 Physical Unit Types (Insight 1 from science-critical)

```
type Kelvin = Float where value >= 0.0
type Meter  = Float
# Algebra: Meter * (1 / Second^2) → Acceleration
# Compiler rejects: compute :force → Kelvin (wrong units)
```

This is a **refinement type** expressed via invariants. Mars Climate Orbiter
was lost to a unit mismatch. Patients die from mg vs mcg confusion.
The invariant system already supports this structurally — unit algebra just
needs first-class compiler support.

### 4.9 Deadline Contracts (Insight 3 from science-critical)

```
contract :navigation_step, deadline: 10.milliseconds do
  compute :path_planning, with: [...], call: PathPlanner,
    wcet: 3.milliseconds    ← worst-case declared by implementer
end
```

The DAG structure makes WCET analysis more tractable than for arbitrary programs —
the critical path is exactly computable at compile time.

For IoT: sensor processing deadlines, actuator response windows, telemetry
processing budgets. This is what separates "interesting experiment" from
"certifiable embedded system."

### 4.10 Uplink-Able Rule Declarations (Insight 4 from science-critical)

```json
{
  "rule": "eclipse_heater",
  "applies_to": "heater_power_command",
  "applies": { "op": "and", "args": [
    { "field": "spacecraft_state.in_eclipse", "eq": true },
    { "field": "temperature.value", "lt": 250.0 }
  ]},
  "compute": { "type": "constant", "value": { "power_watts": 50 } },
  "priority": 20
}
```

Rules as **serializable data** — transmittable over radio, injected without
software deployment. This is directly relevant to: spacecraft, medical devices,
industrial control, IoT firmware.

The rule DSL restricts to field comparisons + arithmetic + constants.
A safe evaluator on the device applies them without code changes.

---

## 5. Domain Validation — What the Science Doc Confirmed

From `igniter-science-critical.md` — four domains validated:

| Domain | Key Igniter primitive | Unique advantage |
|--------|----------------------|-----------------|
| **Science** | `BiHistory[T]` + `as_of` | Reproducibility as language property, not process discipline |
| **Robotics** | `invariant` with `label:` | Safety requirements become executable + traceable |
| **Space** | `BiHistory[T]` + causal `as_of` | "What did we know, and when?" query impossible in standard DBs |
| **Medicine** | `invariant` with `label:` + `BiHistory[T]` | Guideline → compiler error; protocol versioning free |

**Cross-domain synthesis**: the pattern is universal:
```
Physical/digital world data
  → Typed sensor/input nodes
    → Typed computation graph (validated at compile time)
      → Safety invariants (verified before execution)
        → Typed output / actuation / recommendation
```

This is exactly a contract graph. **Igniter is a computation model, not an
enterprise tool.** The enterprise use case is just the domain where the
consequence of failure is financial loss, not death.

---

## 6. The Distributed Agent Connection

The legacy packages reveal the original vision:

```
igniter-agents/   ← actors + supervisors + AI agents
igniter-cluster/  ← mesh network, trust, peer routing
igniter-ai/       ← AI integration
```

These were built **before** the language. The language's ESCAPE boundary
(capability-gated external effects) is the natural interface to these packages:

```
contract SensorFusion {
  escape read_sensor_stream           ← igniter-cluster peer read
  escape submit_to_agent              ← igniter-agents actor message

  read current_readings: Collection[SensorReading]
    from "sensors/{device_id}/{window}"
    lifecycle :window

  compute fused = fuse_readings(current_readings)
    @cache(30s)

  effect send_to_coordinator,
    depends_on: fused,
    call: AgentSubmitter,   ← ESCAPE: routes to igniter-agents cluster peer
    idempotent: true

  out fused_state = fused
}
```

The language formalizes what the cluster already does. The cluster becomes a
typed, observable, auditable mesh — not a collection of ad-hoc message passes.

---

## 7. What The Event Loop Question Actually Reveals

Your question about event loops is not a language gap — it is a design pattern question.

The Igniter-Lang answer is the **Window-Sampled Reactive** model:

```
Unbounded sensor stream (real world)
  ↓ ESCAPE boundary (stream_collection capability)
  ↓ OLAPPoint cells filled by stream
  ↓ Temporal window closes (calendar/session/count-based)
  ↓ CORE processes bounded OLAPPoint[time: window]
  ↓ snapshot at window close (durable observation)
  ↓ next window = fresh CORE invocation
```

The theoretical grounding:
- **Kahn Process Networks**: each CORE contract = single-shot KPN node
- **Lustre**: window boundary = synchronous clock tick
- **CSP/Actor**: ESCAPE boundary = process receive + send

The language already has all the pieces. What's missing is:
1. `stream` surface form (Path C) — not yet a PROP
2. `OLAPPoint` as first-class language construct — not yet a PROP
3. Formal `deadline:` parameter — not yet a PROP

---

## 8. Priority Map — What to Formalize Next (Beyond Stage 1)

```text
Stage 1 (current focus):
  Parser → Classifier → TypeChecker → SemanticIR → .igapp/ → RuntimeMachine
  [Do not touch until closed]

Stage 2 (streaming + reactive foundation):
  PROP-Stream: stream surface form (Path C)
    - OLAPPoint as first-class construct
    - Window-Sampled Reactive model formal spec
    - Connects legacy igniter-cluster to language

  PROP-Unit: physical unit types as refinement types
    - Kelvin, Meter, Newton, Pascal etc.
    - Unit algebra in compiler (dimensional analysis)
    - Directly enables IoT, robotics, space, medicine

Stage 3 (distributed cells):
  PROP-Cell: RuntimeCell as language-level concept
    - CellIdentity, CellInterface, CellPolicy, CellMutation
    - Connects to legacy igniter-agents + igniter-cluster
    - Makes "I own this computation on this node" a typed statement

Stage 4 (temporal + synthesis):
  PROP-BiHistory: BiHistory[T] implementation
    - ~400 LOC compiler + ~150 DSL + ~200 runtime (one sprint)
    - Unlocks science, space, medicine validation
  PROP-RuleSynthesis: goal-directed rule synthesis via LP
    - OSINT application: evidence collection strategy synthesis

Deferred (but theoretically grounded, not speculative):
  PROP-Deadline: deadline contracts + WCET analysis
  PROP-Uplink: serializable rule declarations
  PROP-Probability: ~T probabilistic types with Bayesian semantics
  PROP-OLAPPoint: full multi-dimensional OLAP construct
```

---

## 9. The Most Important Buried Insight

From `igniter-lang-theory.md` §9.1:

> These [five identities] are not different theories describing different aspects —
> they are different languages describing the same mathematical object. Their
> convergence on the contract structure is what makes that structure fundamental,
> not accidental.

The contract model is **a rediscovery of Stratified Datalog**. Every optimization
from 40 years of Datalog research is applicable. Every extension of Datalog is a
principled extension of the contract language.

**The IoT/mesh/agent vision is a Continuous Datalog system** where:
- Sensors are EDB (extensional database) facts
- Contracts are IDB (intensional, derived) rules
- The cluster is the evaluation engine
- The ESCAPE boundary is the interface to the external world
- The RuntimeMachine is the bottom-up evaluation engine

The language just needs to say this clearly.

---

## 10. Summary Table — Buried Ideas by Priority

| Idea | Document | Priority | Stage |
|------|----------|---------|-------|
| Streaming contracts (`stream` surface) | igniter-lang.md §5.3 | HIGH | 2 |
| OLAPPoint as language primitive | igniter-lang-olap.md | HIGH | 2 |
| Physical unit types | igniter-science-critical.md §6.1 | HIGH | 2 |
| BiHistory[T] with causal as_of | igniter-lang-temporal-deep.md | HIGH | 2 |
| Plastic Runtime Cells | plastic-runtime-cells.md | MEDIUM | 3 |
| Rule synthesis via LP | igniter-lang-temporal-deep.md §2 | MEDIUM | 4 |
| Deadline contracts | igniter-science-critical.md §6.3 | MEDIUM | 3 |
| Uplink-able rule declarations | igniter-science-critical.md §6.4 | MEDIUM | 3 |
| Igniter Plane (graph canvas) | igniter-plane.md | MEDIUM | 3 |
| Probabilistic types (~T Bayesian) | igniter-lang-theory.md §6 | LOW | 4 |
| Formal denotational semantics | igniter-lang-theory.md §10.1 | LOW | 4 |
| Certified graph export (AADL/SysML) | igniter-science-critical.md §6.5 | LOW | 4 |
