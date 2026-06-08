# Human-Agent Comprehension Synthesis v0

Role: `[Igniter-Lang Archive/Form Expert]`
Card: `S2-R15-C3-P`
Track: `human-agent-comprehension-synthesis-v0`
Status: research-synthesis
Date: 2026-05-07

Related:
- [Human-Agent Comprehension Testing](human-agent-comprehension-testing-v0.md)
- [Comprehension Results 001](human-agent-comprehension-results-001-field-supply-watch-v0.md)
- [Comprehension Results 002](human-agent-comprehension-results-002-field-supply-watch-v2.md)
- [Comprehension Results 003](human-agent-comprehension-results-003-academic-sorting-structures-v0.md)
- [Comprehension Results 004](human-agent-comprehension-results-004-surface-layering-from-spec-review-v0.md)
- `igniter-lang/experiments/human_agent_syntax_comprehension_fixture/field_supply_watch.ig`
- `igniter-lang/experiments/human_agent_syntax_comprehension_fixture/field_supply_watch_v2.ig`
- `igniter-lang/experiments/human_agent_syntax_comprehension_fixture/academic_sorting_structures.ig`

---

## Purpose

Synthesize syntax comprehension pressure from the current blind-review fixtures.

This document does not promote fixture syntax to canon. It preserves repeated
ambiguity classes and routes them into future syntax experiments.

---

## Executive Synthesis

[D] Field Supply Watch v0 and v2 are both highly understandable to agents without
context. The v2 changes improved several high-value surfaces: `delegate`,
`await_review`, `metric`, explicit trust phrasing, `EvidenceRef`, `let`, explicit
stream seed, and type/view separation.

[D] The remaining problem is no longer basic readability. It is verifiability:
agents can explain the program, but still cannot verify thresholds, external
helpers, hash identity, proof meaning, or some lifecycle semantics without
additional source-level declarations.

[D] Academic sorting exposed a different pressure class. General-purpose and
proof-heavy code is readable, but the current audit vocabulary (`evidence`,
`receipt`) becomes semantically overloaded when used for mathematical proof or
ordinary data-structure examples.

[S] The strongest shared conclusion: Igniter-Lang needs visible surface layers.
Uniform contract substrate is powerful, but human-agent readability improves
when the source distinguishes type, view, receipt, proof, entity, entrypoint,
section, stream pipeline, mesh delegation, and primitive literals.

---

## Fixture Comparison

| Fixture | What worked | What remained ambiguous |
|---------|-------------|-------------------------|
| `field_supply_watch.ig` | Domain flow, temporal stores, evidence near outputs, lifecycle, invariants, high-level mesh/review intent | `agent mesh`, trust ordering, `ObsId`, `obs_refs`, view materialization, `human_review` sync/async, `fold_stream` seed, `compute` density, `olap_point` friendliness |
| `field_supply_watch_v2.ig` | `delegate`, `await_review`, `metric`, `EvidenceRef`, `trust all`, `peer.trust at_least`, explicit stream seed, `let`, `Decimal[scale: n]`, type/view split | inline thresholds, helper functions without signatures, `content_hash` as normal function, `fold_stream` still technical, evidence/hash/signature boundary still implicit |
| `academic_sorting_structures.ig` | ADTs, traits, generics, match, invariants, decreases, algorithm intent | audit evidence vs proof evidence, `receipt SortProof`, structural vs metric recursion, constructor resolution, generic constraints, magic cutoff, duplicated recursive work |

[S] v2 is a better syntax specimen than v0, but it also raises the bar: once the
surface is clearer, reviewers notice semantic gaps more sharply.

---

## Repeated Ambiguity Classes

### C1: Evidence / Receipt / Hash / Signature

Observed in:
- Field Supply Watch v0/v2
- Academic sorting

Pressure:

```text
evidence, receipt, proof, witness, hash, signature, and source provenance need
separate source-level roles.
```

Current issue:
- `evidence [x]` works well for provenance-bearing operational systems.
- `evidence [xs]` in sorting is mostly a tautological pointer to an argument.
- `content_hash(...)` inside a receipt hides identity semantics inside a normal
  function call.
- `receipt SortProof` weakens both receipt and proof meanings.

Candidate directions:
- `evidence` for provenance and observation references.
- `receipt` for durable operational/audit artifacts.
- `proof` or `witness` for theorem/check obligations.
- `id decision_id by content_hash(...)` for declarative receipt identity.
- `signature` only when cryptographic signing is explicitly present.

### C2: Mesh / Agent / Tool / Model

Observed in:
- Field Supply Watch v0
- Field Supply Watch v2

Pressure:

```text
distributed execution, agent identity, LLM/model use, tool invocation, and mesh
placement are related but not the same construct.
```

v2 improvement:

```text
delegate route_options to SupplyAnalysisMesh capability :route_plan
admit peer.trust at_least :regional_operator
```

Remaining issue:
- `mesh` capability syntax is now readable, but the language still needs a
  clean vocabulary boundary between peer, agent, model, tool, capability,
  admission, and trust lattice.

### C3: View / Type / Materialized Projection

Observed in:
- Field Supply Watch v0
- Field Supply Watch v2

Pressure:

```text
structural shape and materialized projection should not share one declaration.
```

v2 improvement:

```text
type RegionalSupplyPosture { ... }

view regional_supply_posture: RegionalSupplyPosture {
  from BuildRegionalPosture
  lifecycle :audit
}
```

Remaining issue:
- The review pressure now shifts from "what is a view?" to "when is this view
  materialized, cached, audited, refreshed, or queryable?"

### C4: `let` / `compute`

Observed in:
- Field Supply Watch v0/v2
- Academic sorting

Pressure:

```text
`compute` is semantically honest but visually heavy; `let` is readable but must
not erase graph node identity.
```

v2 improvement:
- `let` reduced visual noise.

Invariant to preserve:
- If `let` lowers to a compute node, diagnostics must preserve source identity,
  dependency edges, and evidence/proof obligations.

### C5: Review Sync / Async

Observed in:
- Field Supply Watch v0/v2

Pressure:

```text
human review is lifecycle/suspension semantics, not a generic function call.
```

v2 improvement:

```text
await_review dispatch_override when ...
```

Remaining issue:
- `await_review` reads correctly, but future grammar must clarify whether the
  contract suspends, times out, resumes with evidence, records a receipt, or
  supports async continuation.

### C6: Generic / Trait / Variant / Constructor Resolution

Observed in:
- Academic sorting

Pressure:

```text
general-purpose language support needs explicit rules for generic constraints,
trait methods, variant constructors, and bare constructor names.
```

Examples:

```text
trait Ordered[T] { compare(left: T, right: T) -> Ordering }
variant List[T] { nil: Unit, cons: ConsCell[T] }
cons(ConsCell[T] { head: x, tail: xs })
compare(x, cell.head)
```

Ambiguities:
- Is `compare` a trait function, imported function, or method?
- Is `cons` a variant constructor in scope?
- How does `nil` resolve across generic variants?
- How are constructor names namespaced in diagnostics?

[T] These are not urgent for Stage 2 canon, but they matter for Stage 3
general-purpose credibility.

### C7: Primitive Surface / Contract Substrate

Observed in:
- Academic sorting
- Spec review follow-up

Pressure:

```text
users should write arrays, maps, sets, records, ordinary operators, and
entrypoints without seeing the full contract implementation of every primitive.
```

Candidate surfaces:

```text
entrypoint watch_supply { ... }
section Domain { ... }
entity alice: Employee { ... }
let xs = [1, 2, 3]
let lookup = { "kyiv" => :ua_kv }
let tags = #{ :urgent, :medical }
```

[S] This is the main antidote to language monotonicity.

---

## Pressure Routing By Role

| Class | Primary role | Neighbor roles | Next action |
|-------|--------------|----------------|-------------|
| C1 evidence/receipt/proof/hash/signature | Compiler/Grammar Expert | Bridge Agent, Archive/Form Expert | Split audit provenance, receipt identity, cryptographic signature, and proof/witness vocabulary |
| C2 mesh/agent/tool/model | Bridge Agent | Compiler/Grammar Expert, Research Agent | Define vocabulary boundary for mesh peer, agent, model, tool, capability, trust, admission |
| C3 view/type/projection | Compiler/Grammar Expert | Research Agent | Specify type vs view vs materialized projection lifecycle without overloading `type` |
| C4 let/compute | Compiler/Grammar Expert | Archive/Form Expert | Decide source sugar and SemanticIR lowering rules that preserve diagnostic node identity |
| C5 review sync/async | Research Agent | Compiler/Grammar Expert, Bridge Agent | Model `await_review` as suspend/resume/evidence lifecycle semantics |
| C6 generics/traits/variants | Compiler/Grammar Expert | Research Agent | Design constructor resolution, trait call resolution, and generic constraint diagnostics |
| C7 primitive surface | Archive/Form Expert | Compiler/Grammar Expert, Research Agent | Build Stage 3 specimens for entrypoint, section, entity, literals, operators, and stream pipelines |

---

## Recommended Stage 3 Syntax Experiments

### E1: Field Supply Watch v3: Verifiability Layer

Test only the remaining v2 gaps:

- named `threshold` or `const` declarations
- `external pure` helper signatures
- declarative receipt identity
- `accumulate` or stream-chain alias over `fold_stream`
- explicit `signature` only if crypto is present

Success criterion:

```text
reviewers can explain both what the program does and what they would need to
verify it.
```

### E2: Proof Profile Sorting v1

Rewrite the sorting specimen with:

- `proof` or `witness` instead of `receipt SortProof`
- `proof: required`, `evidence: optional`
- shared `MergeSort` intermediates
- named strategy cutoff
- explicit recursion mode: `structural` vs `well_founded`

Success criterion:

```text
reviewers no longer confuse audit evidence with mathematical proof.
```

### E3: Primitive Surface / Contract Lowering Specimen

Create a small program using:

- `[1, 2, 3]`
- `{ key => value }` or a tested map alternative
- `#{ ... }`
- ordinary operators
- `Array`, `HashMap`, `Set`, `Option`, `Result`
- a visible lowering explanation in evaluator guide only, not in the specimen

Success criterion:

```text
humans read it as ordinary code; agents infer typed contract substrate.
```

### E4: Entry / Section / Entity Business Fixture

Create a compact CRM/ERP-style specimen with:

- `section Domain`, `section Storage`, `section Contracts`, `section Entry`
- `entrypoint`
- `entity alice: Employee`
- History/BiHistory for identity over time

Success criterion:

```text
reviewers identify start point, grouping, durable identity, and lifecycle without
external explanation.
```

### E5: Mesh Capability Vocabulary Fixture

Create a minimal distributed workflow that separates:

- mesh peer
- agent policy
- model/tool invocation
- capability
- trust/admission
- retry/timeout
- evidence of delegation

Success criterion:

```text
reviewers do not collapse mesh into "AI model" or tool call into peer execution.
```

---

## Handoff

[D] Synthesized current human-agent comprehension pressure across Field Supply
Watch v0/v2, academic sorting, and the spec-review follow-up.

[S] v2 successfully fixed first-order readability issues; remaining pressure is
mostly semantic/verifiability layering.

[T] Academic and business examples need different profile vocabularies:
audit/evidence/receipt for operational systems, proof/witness/theorem for
academic verification.

[R] Stage 3 should start with bounded syntax experiments, not canon promotion:
Field Supply Watch v3, Proof Sorting v1, Primitive Surface, Entry/Entity, and
Mesh Vocabulary.
