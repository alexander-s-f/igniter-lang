# PROP-039: Managed Local Recursion and Loop Classes v0

Status: experiment-pass compiler surface
Date: 2026-06-05
Accepted: 2026-06-07 (Portfolio Architect Supervisor)
Gates closed: 1+3+4+5+6+7 (2026-06-07) · Gate 8 pending (2026-06-08)
Acceptance receipt: proposals/accepted/PROP-039-acceptance-receipt-2026-06-07.md
Author: `[Igniter-Lang Compiler / Grammar Expert]`
Stage: 3 — experiment-pass
Authoring card: S3-R251-C2-I

Surface open: parse → classify → typecheck → SemanticIR; OOF-L1/R2/R4 active
Surface closed: runtime, recur(), igc run, public/stable/production
Surface pending (gate 8): loop body semantics — TypeChecker scope rules, lead/compute body IR, SemanticIR typed body nodes
Depends on:
- PROP-037 external progression and service liveness semantics
- Chapter 13 managed recursion draft
- Chapter 8 stdlib `now()` / `OOF-L6` wording
- Language Covenant Postulates 14 and 28
- R248 proof-local loops/recursion fixture packet

---

## Authority Boundary

PROP-039 authors proposal text for managed local recursion and local loop
classes. It does not authorize implementation.

Closed by this proposal:

- parser support;
- TypeChecker support;
- SemanticIR support;
- runtime support;
- API, CLI, and package changes;
- `igc run` widening;
- `.igapp` or `.igbin` execution;
- compiler passport emission;
- RuntimeSmoke productization;
- public runtime support;
- Reference Runtime support;
- stable API or production readiness;
- Spark integration;
- release or public demo evidence;
- public performance claims;
- official/reference status;
- alternative certification;
- portability guarantees;
- lab behavior or R248 fixture grammar as canon.

This proposal may be accepted as language-design authority only after governance
review. Any parser, TypeChecker, SemanticIR, runtime, conformance, or alternate
implementation work requires a separate authorization route.

---

## Purpose

Igniter-Lang requires every repetition to be managed. Postulate 14 states that
repetition must be finite by collection size, finite by structural variant,
finite by fuel, convergent by metric, or alive by liveness. The current accepted
language already separates service liveness from local repetition:

- PROP-037 owns external progression and service liveness.
- PROP-039 owns managed local loops and recursion.

This proposal fills the managed local side. It gives future proof and
implementation cards a bounded vocabulary for local loop classes, recursive
forms, budgets, naming, and candidate diagnostics.

---

## Non-Goals

PROP-039 v0 does not define or authorize:

- service-loop progression descriptors, materialization, checkpoint,
  cancellation, backpressure, scheduler, or receipts;
- a `PROGRESSION` fragment class;
- live recursion execution;
- arbitrary unbounded loops;
- source-level `break`;
- dynamic budget expressions as accepted source form;
- general side-effectful loop bodies;
- public runtime, Reference Runtime, stable API, production, release,
  performance, certification, or portability claims.

---

## Loop-Class Vocabulary

PROP-039 v0 defines the managed local loop-class vocabulary:

| Class | Ownership | v0 stance |
| --- | --- | --- |
| `FiniteLoop` | PROP-039 | Local iteration over finite `Collection[T]`; termination follows from collection boundedness. |
| `BudgetedLocalLoop` | PROP-039 | Local loop with explicit static `max_steps` budget. |
| `StructuralRecursion` | PROP-039 | Recursive contract where a structural variant decreases at every `recur()` site. |
| `FuelBoundedRecursion` | PROP-039 | Recursive contract bounded by static fuel / `max_steps`. |
| `ConvergentLoop` | PROP-039, deferred proof | Local iterative form with metric, threshold, and static budget; included as vocabulary, but later proof must own detailed rules. |
| `ServiceLoop` | PROP-037 | Excluded from PROP-039 except for boundary references. |

`BudgetedLocalLoop` is named separately from Ch13's
`FuelBoundedRecursion` so local loop budgets and recursive fuel do not collapse
into one syntax too early.

---

## Finite Local Loops

The conservative v0 finite-loop stance is:

```igniter
for ClaimLoop claim in claims {
  ...
}
```

where:

- `ClaimLoop` is a stable loop name;
- `claims` must be a finite `Collection[T]`;
- the loop terminates by exhausting the collection;
- the first v0 `for` form does not carry `max_steps`;
- the loop is local repetition, not `fold_stream`;
- body semantics remain future proof work.

The R248 fixture form:

```igniter
for ClaimLoop claim in claims max_steps: claims.count { ... }
```

is accepted as pressure evidence only. PROP-039 v0 does not make `for ...
max_steps` canonical.

---

## Budgeted Local Loops

The conservative v0 budgeted-loop stance is:

```igniter
loop SearchLoop item in candidates max_steps: 1000 {
  ...
}
```

where:

- `SearchLoop` is a stable loop name;
- `max_steps` is a static integer literal in the first accepted design;
- exhausting the budget must be observable in a future proof/runtime model;
- dynamic budget expressions are deferred;
- `break` remains unsupported in v0;
- the loop remains local repetition, not service liveness.

The first implementation proof, if later authorized, should reject or hold
dynamic forms such as:

```igniter
loop SearchLoop item in candidates max_steps: candidates.count { ... }
```

until a separate type/audit rule proves that dynamic budget sources are bounded,
accountable, and not hidden runtime authority.

---

## Structural Recursion

Structural recursion is the class for recursive local computation whose variant
strictly decreases at every `recur()` site:

```igniter
recursive contract SumList(items: Collection[Integer], acc: Integer) -> total: Integer
  decreases items.remaining
{
  ...
}
```

v0 obligations:

- the contract must declare a structural `decreases` expression;
- every `recur()` site must preserve type shape and decrease the variant;
- `recur()` is a language primitive, not an arbitrary self-call;
- `recur()` outside a recursive or fuel-bounded context is a candidate OOF;
- proof of the decreases relation is future TypeChecker work.

PROP-039 v0 does not authorize recursive execution.

---

## Fuel-Bounded Recursion

Fuel-bounded recursion is distinct from structural recursion:

```igniter
fuel_bounded contract SearchOptimal(state: SearchState) -> best: Route
  max_steps 10000
{
  ...
}
```

v0 obligations:

- `max_steps` must be a static integer literal;
- each recursive step consumes one unit of fuel;
- exhaustion behavior must be explicit in a later proof route;
- structural decreases proof is not required for this class;
- fuel is not hidden runtime authority.

`FuelBoundedRecursion` may later support explicit exhaustion policy such as
`:error`, `:suspend`, or `:return_partial`, but v0 treats the policy surface as
deferred unless a later route accepts it.

---

## `decreases fuel` Shorthand Candidate

`decreases fuel` is accepted here as a proposal candidate only:

```igniter
recursive contract FactorialFuel(n: Integer, acc: Integer) -> result: Integer
  decreases fuel
  max_steps 100
{
  ...
}
```

Meaning candidate:

```text
decreases fuel =
  this recursive form is fuel-bounded
  + it requires an explicit static max_steps budget
  + each recur() consumes one fuel unit
```

This does not merge structural and fuel-bounded recursion by default. It is a
shorthand candidate whose final parser shape, TypeChecker obligations,
SemanticIR fields, and diagnostics remain future work.

The R248 fixture using `recursive contract ... decreases fuel max_steps 100` is
evidence for this candidate, not canonical grammar by itself.

---

## `for` / `loop` Split

PROP-039 v0 recommends this conservative split for future proof work:

| Surface | First meaning | Budget stance |
| --- | --- | --- |
| `for Name item in collection { ... }` | Finite collection iteration | No explicit `max_steps` in first v0 form |
| `loop Name item in collection max_steps: N { ... }` | Budgeted local loop | Static integer literal `max_steps` required |

Open questions:

- whether `for` may later carry a budget as a defensive cap;
- whether `loop` must always consume a collection source;
- whether local loops may produce accumulated values directly or only through
  named compute/output nodes;
- how loop-body dependency and evidence identity lower into later compiler
  phases.

---

## Static-First `max_steps`

`max_steps` is static-first in v0.

Accepted for first proof planning:

```igniter
max_steps 1000
max_steps: 1000
```

Held / deferred:

```igniter
max_steps: claims.count
max_steps: budget_input
max_steps: computed_limit()
```

Rationale:

- static budgets are auditable at source review time;
- dynamic budgets need type, provenance, and upper-bound rules;
- dynamic expressions can hide unbounded behavior if accepted too early.

---

## Local Loop Body Semantics (Gate 8 Design)

**Gate 8 authorization:** pending (Meta-Architect, 2026-06-08)

```text
Gate 8 = loop body is no longer opaque syntax.
Gate 8 ≠ loop execution.
```

### Core Formula

Canon currently sees loop body as opaque (`body=[]` in SemanticIR). Gate 8 closes
the local semantic surface: the TypeChecker gains lexical scope awareness for loop
bodies, `lead` becomes a first-class body declaration, and SemanticIR emits typed
body nodes instead of an empty array.

**What gate 8 accepts:**
- `item` receives type `T` from `Collection[T]` source.
- Loop body has its own lexical scope.
- Outer contract symbols are accessible read-only; mutation of outer state is
  rejected.
- Loop-carried state is explicit — it is never inferred from outer variables.
- SemanticIR stops writing `body=[]` and stores typed `lead_node` + `compute_node`.
- v0 body surface is minimal: only `compute` + explicit `lead`.

### Body Grammar (v0)

Two declaration kinds are accepted in a loop body in v0:

**`lead` — explicit loop-carried binding:**

```igniter
for ProcessAll item in items {
  lead total: Integer = 0
  compute total = total + item
}
```

```igniter
loop Accumulate item in items max_steps: 1000 {
  lead total: Integer = 0
  compute total = total + item
}
```

`lead` rules:
- Must be declared before any `compute` that references it.
- Type annotation is required; type is not inferred.
- Initial value must be a static literal in v0.
- Multiple `lead` bindings are permitted in one body.
- A `lead` name must not shadow any outer contract symbol.

**`compute` — body-local assignment:**

```igniter
compute total = total + item
```

`compute` rules (body scope):
- May read: `item`, declared `lead` bindings, outer contract `input` and `compute`
  symbols (read-only).
- May write: only a `lead` binding declared in this body (rebind).
- May NOT: assign to outer contract symbols, shadow outer names, invoke `recur()`,
  use `break`, emit effects or escape operations.

### Scope Access Table

| Symbol kind | Readable in body | Writable in body |
|-------------|-----------------|-----------------|
| `item` (loop variable) | ✅ yes | ❌ no |
| `lead` binding | ✅ yes | ✅ yes (rebind only) |
| Outer contract `input` | ✅ read-only | ❌ no |
| Outer contract `compute` | ✅ read-only | ❌ no |
| Outer contract `output` | ❌ not in body | ❌ no |
| Nested loop, `recur()`, `break` | ❌ not in v0 | ❌ no |
| Effects / escape operations | ❌ not in v0 | ❌ no |

Shadowing any outer contract name inside a loop body is a gate 8 scope error.

### SemanticIR Body Shape (v0)

Gate 8 replaces `body=[]` with a non-empty array of typed body nodes. Two node
kinds only:

```json
"body": [
  {
    "kind": "lead_node",
    "name": "total",
    "type": "Integer",
    "initial": { "kind": "literal", "value": 0 }
  },
  {
    "kind": "compute_node",
    "name": "total",
    "expr": { "kind": "binary_op", "op": "+",
              "left": { "kind": "ref", "name": "total" },
              "right": { "kind": "ref", "name": "item" } }
  }
]
```

`lead_node` required fields: `name`, `type`, `initial`.
`compute_node` required fields: `name`, `expr` (typed expression IR).

No other body node kinds are accepted in v0. The gate 8 parser/typechecker proof
must reject unsupported forms via a scope/body diagnostic (OOF-L5 or successor).

### Gate 8 Closed Surface

The following forms are closed in gate 8 and require separate authorization:

| Form | Status |
|------|--------|
| Nested loops in body | closed — not in v0 |
| `recur()` in loop body | closed — separate gate (G5) |
| `break` in body | closed — deferred (OOF-L4) |
| Effects / escape operations | closed |
| Implicit accumulator inferred from outer compute | closed |
| `lead` initial = non-literal expression | closed in v0 |
| `lead` type inferred (no annotation) | closed — explicit type required |
| Lab VM conformance update | closed — separate conformance pass after gate 8 |
| Runtime execution semantics | closed |
| `recur()` body validation | closed — G5, depends on body semantics gate |

### Candidate Diagnostics (gate 8)

These codes are candidates for gate 8. They require an OOF registry review step
before being promoted to experiment-pass — same pattern as gate 6.

| Code | Condition | Status |
|------|-----------|--------|
| `OOF-L5` | Loop body contains unsupported form (nested loop, `recur`, `break`, effect, call) | candidate → experiment-pass at gate 8 |
| _gate 8 scope codes_ | `compute` in body targets outer contract symbol; `lead` shadows outer name | candidates — numbers assigned at gate 8 OOF registry step |

OOF-L6 is Ch8 authority (`now()` prohibition). PROP-039 gate 8 scope codes are
assigned after L5, skipping L6. Final numbering is gate 8 OOF registry work.

---

## Service-Loop / PROP-037 Exclusion

Service-loop liveness is excluded from PROP-039 authority.

PROP-037 owns:

- `Progression`;
- `ProgressionSource`;
- `ProgressionEvent`;
- materialization;
- checkpoint, cancellation, backpressure, and receipt obligations;
- service-loop source binding such as `clock.every`.

PROP-039 may mention service loops only to preserve the boundary:

```text
local managed repetition -> PROP-039
service liveness -> PROP-037 progression descriptors
```

`clock.every` is therefore not a `Stream[DateTime]` and is not a local loop
source under PROP-039.

---

## `tick.time` And `tick.event_id`

`tick.time` remains accepted as a PROP-037 event-time binding from a materialized
progression event. It is not ambient time and it is not managed local loop
syntax.

`tick.event_id` remains pressure-only. PROP-039 does not accept a structured
`tick` accessor object. If the language needs stable event identity fields, a
later PROP-037 companion/accessor route should own them.

---

## `now()` And OOF-L6

Source-level `now()` remains prohibited through Chapter 8 `OOF-L6`.

PROP-039 does not mint a replacement ambient-clock diagnostic. Local loops,
recursion, and service-loop design examples must receive time through explicit
inputs or accepted event-time bindings, such as:

- `TemporalCtx.as_of`;
- an explicit `as_of: DateTime` parameter;
- PROP-037-owned `tick.time`.

---

## Postulate 28 Loop Naming

Semantic loop blocks must have stable names.

Rationale:

- diagnostics need a stable location and semantic identity;
- future receipts or traces need a loop identity if they ever become
  authorized;
- unnamed repetition hides accountability.

Candidate future source:

```igniter
for ClaimLoop claim in claims { ... }
loop SearchLoop item in candidates max_steps: 1000 { ... }
```

Held / future diagnostic pressure:

```igniter
for claim in claims { ... }
loop item in candidates max_steps: 1000 { ... }
```

This proposal does not claim parser enforcement exists.

---

## `break` Deferral

`break` is deferred from PROP-039 v0.

Reasons:

- `break` changes loop evidence and termination explanation;
- fuel accounting and partial results need explicit rules;
- future receipts or traces need a precise distinction between exhaustion,
  natural completion, and early exit;
- lab VM pressure does not create language authority.

A future `break` route must specify evidence, fuel, naming, and lowering rules
before implementation can be considered.

---

## Candidate Diagnostics

The following diagnostics are proposal candidates only. They do not create OOF
registry authority.

**Gate 6 update (2026-06-07):** codes marked `experiment-pass` are active in the
canon compiler pipeline. Codes marked `candidate` remain proposal text only.

### Local Loop Diagnostics

| Code | Condition | Severity | Status (gate 6) |
| --- | --- | --- | --- |
| `OOF-L1` | `for_loop` source is not `Collection[T]` | error | **experiment-pass** — typechecker.rb; loop_typechecker_proof 49/49 |
| `OOF-L2` | `max_steps` is dynamic where v0 requires a static literal | error | candidate |
| `OOF-L3` | Semantic loop block is unnamed (Postulate 28) | error | candidate |
| `OOF-L4` | `break` appears in a PROP-039 v0 loop | error | candidate — break deferred |
| `OOF-L5` | Loop body contains unsupported form (nested loop, `recur`, `break`, effect, call in body scope) | error | candidate → experiment-pass at gate 8 |

OOF-L1..L5 do not collide with OOF-L6 (Ch8 `now()` prohibition; Ch8 authority only).

### Recursion Diagnostics

| Code | Condition | Severity | Status (gate 6) |
| --- | --- | --- | --- |
| `OOF-R1` | `recur()` appears outside recursive or fuel_bounded context | error | candidate — recur() not in v0 |
| `OOF-R2` | `recursive` contract missing a `decreases` declaration | error | **experiment-pass** — classifier.rb; loop_typechecker_proof 49/49 |
| `OOF-R3` | Structural variant not proven to decrease at a `recur()` site | error | candidate — future TypeChecker proof |
| `OOF-R4` | `fuel_bounded` (or `recursive + decreases fuel`) missing static `max_steps` | error | **experiment-pass** — classifier.rb; loop_typechecker_proof 49/49 |
| `OOF-R5` | Recursive step changes output/parameter shape incompatibly | error | candidate — future type proof |

**Namespace conflict resolved (gate 6):** Ch13 §13.7 previously listed deferred
service-loop vocabulary under OOF-R2/R4 codes. Those are PROP-037 territory and
will migrate to OOF-SL* when PROP-037 service liveness is authorized. PROP-039
experiment-pass surface takes precedence over Ch13 deferred vocabulary.

### Service-Loop Names

`OOF-SL*` names remain PROP-037 companion territory, not PROP-039 authority.
Service-loop diagnostics must not be accepted under PROP-039.

---

## Fragment And Cache Stance

PROP-039 v0 does not add a fragment class.

Managed local loops and recursion should preserve the surrounding contract's
fragment classification unless a future proof demonstrates a specific reason to
escalate. Service liveness remains PROP-037-owned and does not become a
PROP-039 fragment.

PROP-039 v0 does not define runtime cache behavior, dynamic dependency tracking,
or path-sensitive invalidation.

---

## Evidence And Non-Authority

R248 proof fixtures are accepted only as proof-local specification fixture
evidence. Their grammar is not canonical.

The igniter-lab pressure package and Rust implementation experiments are useful
frontier evidence. They are not the source of truth for Igniter-Lang grammar,
diagnostics, runtime behavior, Reference Runtime behavior, certification, or
portability.

Future Rust or alternate implementation work should consume accepted proposal
text and conformance fixtures after governance accepts them. It should not set
the language contract by implementation inertia.

---

## Future Gates

Before implementation authorization can be considered, the following gates
should close:

1. Governance acceptance or redirect of PROP-039. ✅ DONE (2026-06-07)
2. Proof-local source semantics fixture for `FiniteLoop`,
   `BudgetedLocalLoop`, `StructuralRecursion`, and `FuelBoundedRecursion`. ✅ DONE (2026-06-07)
   Evidence: experiments/loop_class_semantics_proof/ — 66/66 PASS
3. Parser boundary proof, if source syntax is authorized. ✅ DONE (2026-06-07)
   Evidence: experiments/loop_class_parser_proof/ — 60/60 PASS
   Added: keywords for/loop/recursive/fuel_bounded/decreases; CONTRACT_MODIFIERS recursive/fuel_bounded;
   body decls for_loop/budgeted_loop/decreases/max_steps; grammar_version "loop-v0"
4. TypeChecker proof for finite collection, static budget, and recursive
   decreases/fuel obligations. ✅ DONE (2026-06-07)
   Evidence: experiments/loop_typechecker_proof/ — 49/49 PASS
   Added: Classifier for_loop/budgeted_loop pass-through with source deps;
   decreases/max_steps as structural meta-nodes (OOF checks only);
   OOF-R2 for recursive missing decreases; OOF-R4 for fuel_bounded missing max_steps
   and recursive+decreases-fuel missing max_steps; TypeChecker OOF-L1 for for_loop
   source that is not Collection[T]; budgeted_loop typed as Unit pass-through.
5. SemanticIR lowering design/proof, only after parser/typechecker boundaries
   are accepted. ✅ DONE (2026-06-07)
   Evidence: experiments/loop_semanticir_proof/ — 49/49 PASS
   Added: for_loop → loop_node(loop_class="finite", termination="collection_exhaustion");
   budgeted_loop → loop_node(loop_class="budgeted", termination="budget_exhaustion", max_steps);
   body=[] in v0 (body semantics deferred); fragment from classified declaration;
   TypeChecker updated to pass item/source/max_steps through to typed_decl for IR lowering;
   grammar_version="loop-v0" propagates through all four stages; OOF-blocking contracts
   produce nil semantic_ir as expected.
6. OOF registry / diagnostic namespace review if candidate diagnostics need
   canonical authority. ✅ DONE (2026-06-07)
   Evidence: igniter-lang/.agents/work/gates/PROP-039-gate6-oof-registry-review.md
   Resolved: OOF-R2/R4 conflict with Ch13 §13.7 deferred vocabulary.
   Active: OOF-L1 (typechecker), OOF-R2/R4 (classifier) → experiment-pass compiler surface.
   Ch13 service-loop R codes migrate to OOF-SL* when PROP-037 authorized.
   Governance shim: "experiment-pass compiler surface; runtime closed."
   Lab conformance: G1+G2 closed (verify_loops.rb PASS).
7. Alternate implementation conformance consumer route, after canonical proof
   fixtures exist. ✅ DONE (2026-06-07)
   Evidence: igniter-lang/.agents/work/conformance/PROP-039-managed-repetition-conformance-package-v0.md
   Canonical conformance spine: grammar forms, OOF codes, SemanticIR shapes, lab consumption
   contract, PROP-039/PROP-037 boundary, runtime hold.

8. Loop body semantics — TypeChecker scope rules, `lead`/`compute` body declarations,
   SemanticIR typed body nodes. **PENDING** (Meta-Architect authorization: 2026-06-08)

   Design decisions locked (2026-06-08):
   - `lead` is explicit (not inferred from first outer `compute`).
   - Body scope: `item` + `lead` + outer read-only; no outer mutation; no shadowing.
   - SemanticIR v0 body kinds: `lead_node` + `compute_node` only.
   - `recur()` in body, nested loops, break, effects: all closed in v0.
   - Lab VM conformance update: separate pass after canon gate 8 proof.

   Proof plan: experiments/loop_body_semantics_proof/ — Ruby proof, ~100 checks.
   Route: canon TypeChecker + SemanticIR emitter update; OOF-L5 + scope codes to
   experiment-pass via gate 8 OOF registry sub-step.

Runtime execution, `igc run`, `.igbin`, RuntimeSmoke, Reference Runtime,
production, release, performance, certification, and portability gates remain
closed until separately opened.

---

## Open Questions

- Should `ConvergentLoop` remain in PROP-039 v0 vocabulary but wait for a
  separate detailed proposal/proof?
- Should future `for` accept an optional defensive static cap, or should
  budgeted behavior remain exclusively `loop`?
- Should `decreases fuel` be accepted as syntax, replaced by `fuel_bounded`,
  or held as explanatory shorthand?
- What exhaustion policies are allowed for fuel-bounded recursion and budgeted
  local loops?
- ~~How should loop-local compute nodes expose evidence or accumulated values in
  later SemanticIR work?~~ **Resolved (gate 8, 2026-06-08):** `lead_node` +
  `compute_node` in typed body array; `lead` is the only loop-carried value;
  outer read-only access is via ref, not mutation.
- Does `OOF-L*` belong in the same registry namespace as existing Ch8 `OOF-L6`,
  or should local-loop candidates be renumbered during registry review?
