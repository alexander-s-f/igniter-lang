# Syntax Pressure Review Results v0

Role: `[Igniter-Lang Archive/Form Expert]`
Card: `S3-R4-C7-P`
Track: `syntax-pressure-review-results-v0`
Status: research-review
Date: 2026-05-08

Related:
- [Syntax Pressure Registry](syntax-pressure-registry-v0.md)
- [Syntax Pressure Specimens](syntax-pressure-specimens-v0.md)
- `experiments/human_agent_syntax_comprehension_fixture/field_supply_watch_v3.ig`
- `experiments/human_agent_syntax_comprehension_fixture/field_supply_watch_v3_evaluator_guide.md`
- `experiments/human_agent_syntax_comprehension_fixture/primitive_surface_fixture.ig`
- `experiments/human_agent_syntax_comprehension_fixture/primitive_surface_evaluator_guide.md`

---

## Purpose

Review the S3-R3 syntax pressure specimens and route useful signals back to the
syntax registry.

This document does not promote syntax to canon. It does not modify parser, spec,
or runtime behavior.

---

## Review Summary

[D] `field_supply_watch_v3.ig` succeeds as a verifiability specimen. It makes the
program more reviewable by naming thresholds, declaring helper signatures, and
making receipt identity more intentional.

[D] `primitive_surface_fixture.ig` succeeds as an abstraction-layering specimen.
It makes the "ordinary surface over contract substrate" pressure concrete, but
it also combines several unsettled ideas: `entity`, fixture data, entrypoint,
map/set literals, collection chains, and assertions.

[S] The most mature signals are `threshold`, `external pure`, and explicit
`entrypoint`/`section` organization.

[T] The riskiest signals are `entity`, method-chain collection lowering, and
map/set literal spelling. They are useful, but need narrower specimens before
proposal work.

---

## Construct Routing

| Construct | Route | Rationale |
|-----------|-------|-----------|
| `threshold name: T = value` | route to proposal | Directly fixes magic-number verifiability without requiring runtime semantics beyond typed constants/policies |
| `external pure fn(...) -> T` | route to proposal | Existing `external LangId` kernel is too coarse for helper/FFI reasoning; purity/effect/evidence annotations need formalization |
| declarative receipt identity `id ... by content_hash(...)` | needs another specimen | Good direction, but should wait for evidence/receipt/proof/hash/signature separation |
| `accumulate` alias over `fold_stream` | keep pressure | Reads better than `fold_stream`, but should be compared against stream method chains before grammar work |
| `await_review` | keep pressure | Strong lifecycle signal; needs suspend/resume/timeout/receipt model before syntax proposal |
| `delegate ... capability` | keep pressure | Readable, but belongs with mesh/agent/tool/model vocabulary and Bridge Agent review |
| `metric` alias over `olap_point` | keep pressure | Friendly, but OLAPPoint is already canon; alias should wait for broader surface naming pass |
| `profile` | keep pressure | Useful for runtime/proof/evidence mode, but too broad for syntax proposal now |
| `packet`, `event`, `receipt`, `view` | keep pressure | Strong data-role surface; needs profile taxonomy and materialization semantics |
| `EvidenceRef`, `evidence_refs(...)`, `evidence [...]` | needs another specimen | Needs a dedicated provenance/evidence specimen, especially OSINT-style traceability |
| `entrypoint` | route to proposal | Clear start surface; already a Stage 3 review lane and repeatedly reinforced by fixtures |
| `section` | route to proposal | Low-risk if defined as organizational grouping only; pairs naturally with entrypoint specimen |
| `entity` | needs another specimen | Current fixture shows identity, but not enough lifecycle/history semantics to justify proposal |
| `[a, b]` arrays / `Array[T]` | keep pressure | Array literal is kernel; `Array[T]` as user-facing alias over `Collection[T]` needs type naming decision |
| `HashMap[K,V]`, `{ k => v }` | needs another specimen | Map literal spelling needs comparison against record literal and JSON-like alternatives |
| `Set[T]`, `#{ ... }`, `in` | needs another specimen | Reads compactly but may be Ruby-flavored; needs comparison and lowering rules |
| collection method chains | needs another specimen | Familiar and readable, but may hide graph node identity and evidence/proof edges |
| fixture-level `let` | keep pressure | Useful in examples; may belong in `fixture`/`sample` surface rather than top-level language |
| `assert` section | reject/defer | Keep as evaluator/test fixture syntax for now, not language surface |
| `let` as contract-body `compute` replacement | keep pressure | Readability win; must be proven against graph node identity before proposal |

---

## Registry Updates

The syntax registry now includes an S3-R4 routing snapshot with four route
classes:

```text
route_to_proposal
keep_pressure
needs_another_specimen
reject_defer
```

No construct was promoted to canon.

---

## Recommended Next Syntax PROP Candidates

Max 3:

1. **Named Thresholds And Constants**
   - Scope: `threshold` vs `const`, typed value, policy/domain metadata, diagnostic
     display.
   - Why first: small, high verifiability gain, low runtime risk.

2. **External Pure Helper Signatures**
   - Scope: `external pure`, argument/return types, purity/effect annotations,
     evidence behavior, relation to existing `external LangId`.
   - Why second: FFI/interoperability and agent verifiability both need this.

3. **Entrypoint And Section Surface**
   - Scope: explicit start declarations and non-semantic grouping.
   - Why third: improves human-agent navigation without changing core contract
     semantics if constrained carefully.

[R] `entity` should not be a next PROP until a narrower identity-over-time
specimen shows how it relates to `History[T]`, `BiHistory[T]`, lifecycle, and
storage.

---

## Next Specimen Recommendations

1. **Entity Lifecycle Fixture**
   - Isolate `entity` from map/set/method-chain pressure.
   - Include identity, lifecycle, History/BiHistory, and ownership.

2. **Primitive Literal Alternatives Fixture**
   - Compare map literal alternatives:
     `{ "k" => v }`, `{ "k": v }`, `Map { "k": v }`.
   - Compare set literal alternatives:
     `#{ ... }`, `set { ... }`, `Set[...]`.

3. **Evidence And Receipt Fixture**
   - Separate `evidence`, `EvidenceRef`, `receipt`, `proof`, `hash`, and
     `signature`.

---

## Handoff

```text
Card: S3-R4-C7-P
Agent: [Igniter-Lang Archive/Form Expert]
Role: archive-form-expert
Track: syntax-pressure-review-results-v0
Status: done

[D] Reviewed Field Supply Watch v3, Primitive Surface fixture, and both guides.
[S] Mature route-to-proposal signals: threshold, external pure, entrypoint/section.
[T] No parser/spec/runtime modifications. No syntax promoted to canon.
[R] Next specimens: Entity Lifecycle, Primitive Literal Alternatives,
    Evidence And Receipt.
```
