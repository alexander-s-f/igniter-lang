# Syntax Pressure Specimens v0

Role: `[Igniter-Lang Archive/Form Expert]`
Card: `S3-R3-C6-P`
Track: `syntax-pressure-specimens-v0`
Status: research-fixtures
Date: 2026-05-08

Related:
- [Syntax Pressure Registry](syntax-pressure-registry-v0.md)
- [Human-Agent Comprehension Synthesis](human-agent-comprehension-synthesis-v0.md)
- [Comprehension Results 002](human-agent-comprehension-results-002-field-supply-watch-v2.md)
- [Comprehension Results 004](human-agent-comprehension-results-004-surface-layering-from-spec-review-v0.md)

---

## Purpose

Create the next pressure specimens from the Syntax Pressure Registry without
promoting syntax to canon.

No parser, spec, proposal, or runtime file was modified.

---

## Delivered Specimens

| Specimen | Guide | Purpose |
|----------|-------|---------|
| `experiments/human_agent_syntax_comprehension_fixture/field_supply_watch_v3.ig` | `field_supply_watch_v3_evaluator_guide.md` | Verifiability layer: thresholds, external pure signatures, declarative receipt identity, stream accumulation alias |
| `experiments/human_agent_syntax_comprehension_fixture/primitive_surface_fixture.ig` | `primitive_surface_evaluator_guide.md` | Primitive surface: arrays, maps, sets, operators, entities, entrypoint, collection chains |

---

## Construct Status Summary

| Construct family | Status | Tested in |
|------------------|--------|-----------|
| `module`, `type`, `contract`, `read`, `output` | canon | both |
| ordinary operators | canon | both |
| `History[T]`, `BiHistory[T]`, `stream`, invariant severity | canon | Field Supply Watch v3 |
| `[a, b]` array literal | canon / pressure boundary | Primitive Surface |
| `Array[T]` as user-facing collection | pressure | Primitive Surface |
| `HashMap[K,V]`, `{ k => v }` | pressure | Primitive Surface |
| `Set[T]`, `#{ ... }`, `in` | pressure | Primitive Surface |
| `profile`, `packet`, `event`, `receipt`, `view` | pressure | Field Supply Watch v3 |
| `metric` | pressure | Field Supply Watch v3 |
| `mesh`, `delegate`, trust/admission | pressure | Field Supply Watch v3 |
| `await_review` | pressure | Field Supply Watch v3 |
| `threshold` | pressure | Field Supply Watch v3 |
| `external pure fn(...) -> T` | pressure | Field Supply Watch v3 |
| `id ... by content_hash(...)` | pressure | Field Supply Watch v3 |
| `accumulate` | pressure | Field Supply Watch v3 |
| `let` as contract-body `compute` replacement | pressure | both |
| `section` | pressure | Primitive Surface |
| `entity` | proposal / pressure | Primitive Surface |
| `entrypoint` | proposal / pressure | Primitive Surface |
| collection method chains | pressure | Primitive Surface |
| `assert` section | non-canon experiment | Primitive Surface |

---

## Short Recommendation

Next review should focus on the constructs that most affect human-agent
verifiability and abstraction layering:

1. `threshold`
2. `external pure`
3. declarative receipt identity
4. `entity`
5. map/set literal spelling

[R] Route successful results back into the Syntax Pressure Registry before any
PROP work. These specimens are pressure artifacts only.

---

## Handoff

```text
Card: S3-R3-C6-P
Agent: [Igniter-Lang Archive/Form Expert]
Role: archive-form-expert
Track: syntax-pressure-specimens-v0
Status: done

[D] Created two pressure specimens and evaluator guides.
[S] Field Supply Watch v3 tests verifiability syntax; Primitive Surface tests
    familiar data structure syntax over contract substrate.
[T] No parser, spec, proposal, or runtime changes.
[R] Next review should prioritize threshold, external pure, receipt identity,
    entity, and map/set literal spelling.
```
