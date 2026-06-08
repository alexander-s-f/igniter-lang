# Syntax Density Human-Agent Research v0

Role: `[Igniter-Lang Archive/Form Expert]`
Track: `syntax-density-human-agent-research-v0`
Status: research-note
Date: 2026-05-07

---

## Purpose

This is an off-track research note on Igniter-Lang source syntax.

It is not a PROP, not final grammar, and not canon. It collects design pressure
around:

- compactness
- expressiveness
- human <-> agent symmetry
- high semantic density with readable syntax
- data structures / DTO-like boundaries

The core question:

```text
How can Igniter-Lang pack more meaning per line without becoming cryptic,
ambiguous, or hostile to agents and diagnostics?
```

---

## Current Constraints

Existing canon already gives several hard constraints:

1. Syntax must map directly to SemanticIR node types.
2. Every construct must expose observable semantic properties.
3. Source must be human-writable.
4. Source must be agent-readable.
5. ParsedProgram JSON is the stable tool boundary.
6. Grammar comes after semantics are proven.

So the target is not "short syntax". The target is:

```text
maximum semantic compression that remains mechanically round-trippable.
```

---

## Working Thesis

[D] Igniter-Lang syntax should optimize for **semantic information density**,
not minimal character count.

Dense syntax is good only when one visible phrase carries multiple legitimate
semantic claims:

```text
input order: OrderRef
```

This line says:

- there is an input node
- its stable name is `order`
- it has type `OrderRef`
- downstream nodes may depend on it
- the compiler can typecheck references to it

By contrast, syntax is bad density when it hides semantic claims:

```text
price.current
```

This is compact, but it hides time. It compresses away `as_of`, which is exactly
the semantic claim the language needs to preserve.

---

## Syntax Design Laws

### Law 1: Dense, Not Clever

Use short forms only when they are obvious in both directions:

```text
source -> ParsedProgram -> source
```

If an agent cannot round-trip the form without guessing, the form is too clever.

### Law 2: Names Carry Contracts

Important semantic objects deserve names:

```text
as_of
knowledge_as_of
source
window
receipt
severity
consistency
```

Avoid positional meaning for important claims.

Good:

```text
read price: History[Money] from "prices" as_of order.created_at
```

Risky:

```text
price @ order.created_at
```

The second form is compact, but less auditable.

### Law 3: Human Skimmability Beats Symbolic Compression

Operators are welcome only when their meaning is stable:

```text
a + b
price[t]
History[Money]
```

But domain claims should prefer words:

```text
fold_stream orders window daily by total
```

instead of dense symbolic spellings that require a private mental parser.

### Law 4: Agent-Friendly Means Stable Structure

Every source form should have a predictable structural counterpart:

```text
contract -> contracts[]
input    -> input_decl
compute  -> compute_decl
type     -> type_decl
packet   -> packet_decl
view     -> view_decl
```

Agent-friendly does not mean verbose. It means:

- low ambiguity
- explicit names
- stable ordering
- stable formatting
- structured diagnostics

### Law 5: Defaults Must Be Named Profiles

Implicit defaults are dangerous. Named profiles are safer:

```text
profile local_core {
  lifecycle: :session
  backend: :memory
}

contract Add using local_core { ... }
```

This lets source stay compact while preserving the hidden choices as a named
contract.

### Law 6: Data Shape Before Procedure

Data structures should be declared close to the domain, before computation:

```text
type OrderLine {
  sku: String
  qty: Integer
  price: Money
}

type Order {
  id: OrderId
  lines: Collection[OrderLine]
  placed_at: Timestamp
}
```

This preserves human readability and gives agents a stable schema before they
inspect flows.

---

## Syntax Layer Model

Igniter-Lang likely needs three source layers, all lowering to the same
ParsedProgram/SemanticIR path.

### Layer A: Canonical Block Syntax

Best for proofs, diagnostics, examples, and agent rewrites:

```text
contract Add {
  input a: Integer
  input b: Integer

  compute sum = a + b

  output result: Integer = sum
}
```

Properties:

- explicit
- easy to diff
- stable for diagnostics
- close to current grammar kernel

### Layer B: Dense Signature Syntax

Best for small pure contracts:

```text
contract Add(a: Integer, b: Integer) -> result: Integer {
  result = a + b
}
```

This is acceptable because it preserves the same claims:

- inputs remain typed
- output remains named and typed
- body still exposes the result equation

Potential rule:

```text
dense signatures are allowed only when all inputs/outputs are pure CORE.
```

### Layer C: Evidence-Rich Syntax

Best for OSINT, runtime, ledger, and agent handoff:

```text
contract VendorRisk(vendor: VendorRef, as_of: Timestamp) -> risk: RiskScore {
  read profile: VendorProfile from "vendors" as_of as_of
  read alerts: History[Alert] from "alerts" window last_90_days

  compute risk = score(profile, alerts)

  output risk: RiskScore = risk
    evidence alerts
    lifecycle :audit
}
```

This syntax is less compact than Layer B but denser semantically because it
keeps evidence, time, and lifecycle visible.

---

## DTO / Data Structure Direction

[D] Igniter-Lang probably should not treat DTO as a separate object-system idea.

DTO-like shapes are better modeled as **structural data profiles**:

```text
type        -- domain shape
packet      -- transport / boundary shape
event       -- append-only historical fact
view        -- projection / read model
receipt     -- evidence record
snapshot    -- checkpoint or semantic image shape
```

These are not classes. They are named structural contracts over data.

### Domain Type

```text
type Order {
  id: OrderId
  customer: CustomerRef
  lines: Collection[OrderLine]
  placed_at: Timestamp
}
```

### Packet Shape

```text
packet OrderCreate {
  customer: CustomerRef
  lines: Collection[OrderLine]
}
```

`packet` says:

- this crosses a boundary
- it must serialize
- it may need versioning
- it may produce receipt evidence

### Event Shape

```text
event OrderPlaced {
  order: OrderId
  at: Timestamp
  payload: OrderCreate
}
```

`event` says:

- append-only
- replayable
- belongs naturally to `History[OrderPlaced]`

### View Shape

```text
view OrderSummary {
  id: OrderId
  status: Symbol
  total: Money
}
```

`view` says:

- derived or projected
- can be stale unless freshness is declared
- may map to `Projection[T, horizon]`

### Receipt Shape

```text
receipt PriceDecision {
  subject: OrderId
  decision: Money
  caused_by: Collection[ObsId]
  produced_at: Timestamp
}
```

`receipt` says:

- evidence-bearing
- audit-oriented
- can be persisted into Ledger facts

### Snapshot Shape

```text
snapshot DispatchState {
  open_jobs: Collection[JobRef]
  technicians: Collection[TechnicianRef]
  as_of: Timestamp
}
```

`snapshot` says:

- point-in-time state
- resumable or comparable
- candidate for SemanticImage/Projection linkage

---

## Proposed Data Shape Rule

[R] Keep `type` as the only fundamental shape constructor, then add profiles
only when they carry real semantics.

Possible lowering:

```text
packet X  -> type X + boundary_profile: :packet
event X   -> type X + boundary_profile: :event + append_only
view X    -> type X + boundary_profile: :view + projection
receipt X -> type X + boundary_profile: :receipt + evidence_required
```

This gives users compact vocabulary while keeping the compiler model small.

---

## Meaning Density Patterns

### Pattern 1: Result-First Contract

For human/agent reading, the result should be visible early.

Candidate:

```text
contract PriceQuote(order: OrderRef, as_of: Timestamp) -> quote: Money {
  product = read Product from "products" by order.product as_of as_of
  price   = product.price[as_of]
  quote   = apply_discounts(order, price)
}
```

This is compact because the result is declared in the signature and defined in
the body once.

### Pattern 2: Evidence Line Folding

Evidence should be compact but explicit:

```text
output risk: RiskScore = risk evidence [profile, alerts] lifecycle :audit
```

This may be acceptable if formatter can split it:

```text
output risk: RiskScore = risk
  evidence [profile, alerts]
  lifecycle :audit
```

### Pattern 3: Temporal Access Is Always Visible

Good:

```text
price = product.price[as_of]
```

Better when source matters:

```text
read price: History[Money] from "prices" as_of as_of
```

Avoid:

```text
price = product.price.current
```

### Pattern 4: Structural Literals Are Fine For Local Data

```text
compute receipt = {
  subject: order.id,
  decision: quote,
  caused_by: [profile.obs, price.obs]
}
```

But repeated shapes should become named `type`/`receipt`.

---

## Compactness Budget

Each syntax feature should be judged by a budget:

```text
semantic claims added
---------------------  = density score
surface complexity added
```

High-density examples:

- `History[Money]`
- `stream OrderEvent window daily`
- `output risk evidence alerts lifecycle :audit`
- `packet OrderCreate`

Low-density examples:

- symbolic aliases for rare constructs
- punctuation-heavy temporal shortcuts
- multiple ways to spell the same node kind
- hidden defaults not named by profile

---

## Open Questions

[Q] Should `packet`, `event`, `view`, `receipt`, and `snapshot` be separate
top-level declarations, or profile annotations on `type`?

[Q] Should dense signature syntax be allowed for all contracts, or only pure
CORE contracts?

[Q] Should source support canonical auto-formatting as part of the language
contract, so agents and humans share one stable form?

[Q] Should DTO-like shapes carry version/migration declarations at the shape
level, or should schema evolution remain contract-level only?

[Q] What is the first SIR benchmark corpus: Spark CRM, home-lab mesh, or a small
standard suite?

---

## Recommendations

[R1] Treat syntax design as a **density discipline**, not a grammar sprint.

[R2] Create a future syntax benchmark with three implementations for each case:

```text
Ruby DSL + executors
current canonical .ig
dense candidate .ig
```

[R3] Add data-shape profiles as research candidates:

```text
packet | event | view | receipt | snapshot
```

but lower them to structural `type` plus profile metadata until their semantics
prove they deserve first-class grammar.

[R4] Make human-agent symmetry a hard gate:

```text
Every syntax feature must be:
  human skimmable
  agent round-trippable
  diagnostic-addressable
  SemanticIR-mappable
```

[R5] Prefer one canonical formatter over multiple stylistic dialects. Humans
and agents need to read the same shape.

---

## Handoff

[D] Syntax research frame created around semantic density, not terseness.

[S] DTO should likely become a family of structural data profiles, not an
object-system feature.

[T] Existing grammar constraints already support the human-writable /
agent-readable requirement; the next research gap is measurable density.

[R] Next useful slice: build a small SIR syntax benchmark using 3-5 contracts
and compare Ruby DSL, current canonical `.ig`, and dense candidate `.ig`.
