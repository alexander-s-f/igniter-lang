# PROP-001: Semantic Domain for Igniter-Lang v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `tracks/observable-contract-language-v0.md`,
             `tracks/observable-spine-v0.md`

---

## Purpose

The three completed research slices establish a rich informal theory.
Before the language can have a compiler, a verifier, or even a grammar sketch,
it needs a **semantic domain**: the mathematical universe inside which
contracts, observations, values, and failures live.

This proposal defines the minimal v0 semantic domain. It is not wire syntax.
It is not implementation. It is the mathematical target that all future
compiler and grammar work must inhabit.

---

## Core Intuition

Igniter-Lang contracts are **typed, demand-driven, temporally-parameterized
relations** over named inputs and outputs, subject to constraints and equipped
with an observation protocol.

A contract is not a function in the lambda-calculus sense. It is closer to:

```text
a finite, stratified Datalog rule set
  parameterized over an explicit temporal context
  producing typed observations
  with a structured failure domain
```

This is close to **Dedalus** (temporal Datalog) with a typed, observation-
aware output model. It is intentionally narrow: decidability is a first-class
requirement.

---

## Semantic Domains

### 1. Values (V)

```text
V ::= base values (Int, Float, String, Bool, Symbol, nil)
     | Record { label1: V, ..., labelN: V }     -- structural product
     | Variant tag V                              -- structural sum
     | Collection [V]                             -- ordered, finite
     | Ref r                                      -- stable reference/id
     | bottom (undefined / not-yet-resolved)
     | Redacted (privacy-sealed value)
```

**Design decision:** Values are structural, not nominal. Two records with the
same field names and value types are the same type. Nominal identity enters
only through `Ref r` (a stable handle to a contract, store, or fact).

`bottom` and `Redacted` are distinct:

- `bottom` means "not yet resolved" (valid in partial evaluation)
- `Redacted` means "present but sealed by privacy policy" (fully resolved)

---

### 2. Types (T)

```text
T ::= Int | Float | String | Bool | Symbol | Unit | Any
     | Record { label1: T, ..., labelN: T }
     | Variant { tag1: T, ..., tagN: T }
     | Collection[T]
     | Ref[T]                      -- reference to a contract of type T
     | Store[T]                    -- durable point store
     | History[T]                  -- append-only event log
     | BiHistory[T]                -- bitemporal history (descriptor only in v0)
     | T where guard               -- refinement type (guard is a predicate)
```

**Subtyping** (minimal):

```text
T where guard  <:  T          -- refinement strips constraint downward
Store[T]       <:  Ref[T]     -- a store is a reference
```

No implicit coercions. All narrowings through explicit adapters.

**Higher-order contracts** (`T1 -> T2`) are **deferred** from v0 to preserve
decidability: if contracts cannot pass contracts as values, the dependency
graph stays finite and stratifiable.

---

### 3. Temporal Context (Tt)

```text
Tt = {
  as_of        : TimeRef | top    -- top = "current moment"
  rule_version : Version | top
  replay       : ReplayCursor | bottom  -- bottom = "not a replay"
  causal_clock : ClockRef | bottom
}
```

**Key property:** `Tt` is a **parameter** to evaluation, not ambient state.
Every evaluation is indexed by a fixed `Tt`. Different `Tt` values produce
independent closed computations over the same graph.

This resolves the tension between Law 3 (Closed Graph) and Law 6 (Temporal
Explicitness): the graph is closed at any fixed `Tt`; temporal variation is
explicit in the parameter.

**Formal statement:**

```text
eval(G, Tt, inputs) : Outputs ∪ Failures

where:
  G      is a finite, stratified dependency graph
  Tt     is a temporal context
  inputs : InputNode -> V
  Outputs: OutputNode -> V
  Failures: OutputNode -> FailureObs
```

The evaluation function is **deterministic** given (G, Tt, inputs). If the
same triple produces different results, the difference must be explained by
an observable: changed input, changed Tt, or changed store fact accessed
through Tt.

This is the formal statement of **Law 5 (Observation Conservation)**.

---

### 4. Contracts (C)

A contract is a named, typed, demand-driven computation:

```text
Contract = {
  name     : ContractRef
  inputs   : Map[InputName, T]
  outputs  : Map[OutputName, T]
  nodes    : Map[NodeName, ComputeNode]
  deps     : DepGraph(nodes ∪ inputs -> outputs)   -- must be a DAG
  guards   : [Guard]             -- typed constraints on values
  effects  : [EffectDecl]        -- declared effect shapes
  temporal : TemporalPolicy      -- as_of policy, freshness, lag SLA
}
```

A `ComputeNode` is:

```text
ComputeNode = {
  name        : NodeName
  depends_on  : [NodeName | InputName]
  return_type : T
  body        : Expr
  constraints : [Guard]
}
```

**Key property:** `deps` must form a **DAG** for the default closed
fragment. Cycles trigger a `compile.cycle_detected` failure before
evaluation.

**Key property:** Stratification. Guards are evaluated after all nodes
they reference are computed. No guard may recursively depend on its own
node's output (this would require fixed-point semantics — out-of-fragment
in v0).

---

### 5. Expressions (Expr)

v0 expressions are intentionally minimal:

```text
Expr ::=
  Literal V
  | Var NodeName | InputName
  | FieldAccess Expr label
  | Apply built_in [Expr]         -- built-in functions only
  | Case Expr { tag1 -> Expr, ..., tagN -> Expr }
  | Temporal (as_of: TimeRef, body: Expr)  -- explicit time annotation
```

**Intentionally absent from v0:**

- Lambda abstractions (functions are named contracts, not closures)
- Recursion (forces fixed-point, out-of-fragment)
- Arbitrary external function calls (only declared built-ins)
- Mutable state (state goes through store references + temporal context)

This keeps the expression language in a decidable, strongly-normalizing
fragment. Every expression has a normal form under demand-driven evaluation.

---

### 6. Observations (O)

The observation domain is the semantic range of the observation spine:

```text
O = {
  kind         : PacketKind          -- closed v0 family
  id           : ObservationId       -- local stable identity
  subject      : SubjectRef
  space        : ObservationSpace
  status       : ObservationStatus
  content_hash : Hash
  provenance   : Provenance          -- producer, observed_at
  policy       : PolicySummary       -- privacy, capabilities
  links        : [TypedLink]
  payload      : V | Hash | Redacted -- optional semantic payload
  temporal     : Tt | bottom         -- temporal context when relevant
  diagnostics  : [Diagnostic]        -- compact, structured
}
```

**Key design choice:** Observations are **values in the semantic domain**.
They can be inputs to contracts (via store/history references), outputs of
contracts (compiler findings, receipts), and the communication medium between
the language and the outside world.

This makes the observation spine a **first-class semantic layer**, not a
logging side-channel.

**Required fields separation** (correction to `observable-spine-v0`):

| Group | Fields | Formal role |
|-------|--------|-------------|
| Identity | `id`, `space`, `kind`, `subject` | Determines equivalence |
| Provenance | `producer`, `observed_at`, `content_hash` | Determines lineage |
| Policy | `privacy`, `links` | Determines what consumers may do |

Two packets are the "same observation" iff their identity fields agree.
Same identity + different provenance = re-emission. Different identity =
different observation even if payload is identical.

---

### 7. Failures (F)

Failures are a subset of O with `kind: :failure_observation`:

```text
F ⊆ O   where:
  kind        = :failure_observation
  diagnostics ≠ []
  links contains at least one :violates link
  status ∈ computation_status × service_level
```

**Two-dimensional failure status** (correction to `failure-observation-v0`):

The prior track uses a flat status vocabulary: `failed`, `rejected`,
`blocked`, `degraded`. This conflates two orthogonal dimensions.

Proposed model:

```text
computation_status : :ok | :failed | :rejected | :blocked
service_level      : :nominal | :degraded
```

Valid combinations:

| computation_status | service_level | Meaning |
|--------------------|---------------|---------|
| :ok | :nominal | healthy |
| :ok | :degraded | live but SLA drift |
| :failed | :nominal | computation failure, system healthy |
| :failed | :degraded | computation failure + SLA drift |
| :rejected | :nominal | compile/protocol rejection |
| :blocked | :nominal | intentionally not attempted |

`degraded` is not "less than failed" — they are orthogonal. A system
can be live (service_level: :degraded) while individual computations
fail (computation_status: :failed) or succeed (computation_status: :ok).

---

## Semantic Equivalence

Two contracts are **semantically equivalent** if:

```text
for all Tt, for all inputs : eval(C1, Tt, inputs) = eval(C2, Tt, inputs)
```

This is extensional (observational) equivalence: results are the ground
truth; internal structure is invisible from the outside.

This is the formal version of **Law 1 (Result-orientation)**.

---

## Formal Restatement of the Ten Laws

| Law | Formal restatement |
|-----|--------------------|
| 1 Result-orientation | `eval` is demand-driven over the DAG from declared outputs back to inputs |
| 2 Contract boundary | Every ContractRef exposes a typed descriptor: `(inputs, outputs, effects, guards)` |
| 3 Closed graph | `deps` is a DAG; no free variables; recursion is out-of-fragment in v0 |
| 4 Uniform constraint | Guards, invariants, temporal policies, privacy policies are all elements of `[Guard]` over the same eval domain |
| 5 Observation conservation | `eval` is deterministic; changed result requires changed `(G, Tt, inputs)` triple |
| 6 Temporal explicitness | `Tt` is an explicit parameter; `eval` is deterministic at fixed `Tt` |
| 7 Materialization | A materializer is a Contract whose outputs are artifact refs and receipts |
| 8 Agent participation | An agent run is a Contract with declared capability inputs and receipt outputs |
| 9 Thin axiom | Built-in functions in `Apply` are the axiom layer; named and versioned |
| 10 Decidability-first | Core fragment = stratified DAG + typed values + explicit Tt — near temporal Datalog |

---

## Fragment Classification (Preview)

| Fragment | Description | Decidability | v0 Status |
|----------|-------------|-------------|-----------|
| Core closed | DAG deps, no recursion, no higher-order | decidable | in-fragment |
| Temporal | as_of parameter, stratified reads | decidable at fixed Tt | in-fragment |
| Refinement | guards as simple predicates | decidable (linear arithmetic) | in-fragment, restricted |
| Effectful | declared effects with receipts | decidable if effects are atomic | in-fragment |
| Recursive | fixed-point contracts | undecidable in general | out-of-fragment v0 |
| Higher-order | contracts as values | undecidable in general | deferred |
| Probabilistic | stochastic outputs | undecidable in general | research track only |

Full classification: proposed as `PROP-003`.

---

## Open Questions

[Q] Should `BiHistory[T]` be a full v0 semantic construct or a type
descriptor only? Recommend: descriptor only in v0 (like current
`Igniter::Lang::BiHistory`); defer its bitemporal semantic model.

[Q] What is the minimal built-in function set (axiom layer)?
Recommend: arithmetic, comparison, string operations, structural access,
collection primitives. Cryptographic, IO, and platform primitives are
`platform_observation` anchors, not built-ins.

[Q] Should refinement guards be restricted to decidable predicates
(linear arithmetic, structural comparison) or allow arbitrary predicates?
Recommend: restrict to decidable predicates in v0 core; allow arbitrary
predicates only as an explicit escape with `out_of_fragment` annotation.

---

## Rejected Paths

[X] Category theory as the primary presentation language. Useful internally
but the proposal must remain accessible without a category theory background.

[X] Full dependent types in v0. Breaks decidability of type checking.

[X] Denotational semantics with CPO/Scott domains. Overkill for a
stratified, demand-driven, finite-domain contract graph. Operational
semantics or attribute grammar semantics are more appropriate.

[X] Observations as a side-channel. The semantic domain must include
observations as values; otherwise the spine is just logging.

[X] Single-dimensional failure status. `degraded` and `failed` are
orthogonal; collapsing them loses semantic precision.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-001
Status: done

[D] Decisions:
- Semantic domain for v0: V (values), T (types, structural + refinement),
  Tt (temporal context as explicit parameter), C (contracts as named DAGs),
  Expr (decidable expression subset), O (observations as values), F (failures).
- eval(G, Tt, inputs) is the canonical evaluation function signature.
- Contracts are NOT first-class values in v0 (no higher-order).
- Failure status is two-dimensional: computation_status x service_level.
- Core fragment is stratified DAG + typed values + explicit Tt, formally
  near temporal Datalog (Dedalus). This is a well-studied decidable fragment.
- Observation required fields separate into three groups: Identity /
  Provenance / Policy. This matters for equivalence, re-emission, and audit.

[R] Recommendations:
- Accept the two-dimensional failure status model; update failure-observation-v0.
- Restate the ten laws using the formal eval definition in the research index.
- Proceed to PROP-002 (Contract Composition Algebra).
- Proceed to PROP-003 (Grammar Fragment Classification).

[S] Signals:
- The semantic domain is in the neighborhood of Dedalus / temporal Datalog,
  with well-studied decidability results and implementation experience
  (Bloom, Bud, Overlog). This is a strength: we inherit a body of theory.
- The observation-as-value design connects naturally to provenance semirings
  (database theory for tracking data lineage). Future research vector.
- The two-dimensional failure status aligns with SRE/SLO vocabulary:
  service_level maps to SLO breach; computation_status maps to error rate.

[Q] Open Questions:
- Is BiHistory[T] a v0 semantic construct or descriptor-only?
- What is the minimal built-in/axiom function set?
- Are refinement guards decidable-only or arbitrary?

[Next] Proposed next slices:
- PROP-002: Contract Composition Algebra
- PROP-003: Grammar Fragment Classification
```
