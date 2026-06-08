# Syntax Pressure Registry v0

Role: `[Igniter-Lang Archive/Form Expert]`
Card: `S3-R2-C6-P`
Track: `syntax-pressure-registry-v0`
Status: research-registry
Date: 2026-05-08

Related:
- [Human-Agent Comprehension Testing](human-agent-comprehension-testing-v0.md)
- [Human-Agent Comprehension Synthesis](human-agent-comprehension-synthesis-v0.md)
- [Comprehension Results 001](human-agent-comprehension-results-001-field-supply-watch-v0.md)
- [Comprehension Results 002](human-agent-comprehension-results-002-field-supply-watch-v2.md)
- [Comprehension Results 003](human-agent-comprehension-results-003-academic-sorting-structures-v0.md)
- [Comprehension Results 004](human-agent-comprehension-results-004-surface-layering-from-spec-review-v0.md)
- [АИ/СОИ Design Lens](axiomatic-and-system-forming-ideas-lens-v0.md)

---

## Purpose

Create a registry for syntax and comprehension fixtures as **pressure artifacts
only**.

This registry prevents experimental syntax from being mistaken for canon while
preserving valuable human-agent readability signals for Stage 3.

---

## Status Legend

| Status | Meaning |
|--------|---------|
| `canon` | Closed in current spec/proofs or accepted Stage 2/Stage 3 proposal state |
| `proposal` | Authorized or expected PROP lane exists; not yet canon until accepted/proven |
| `pressure` | Useful design signal; needs specimen, proof, or PROP before canon |
| `non-canon experiment` | Fixture-only spelling used to test comprehension; do not copy as language syntax |

[D] A fixture can contain canon constructs and non-canon spellings at the same
time. The fixture itself is not canon.

---

## Fixture Index

| Fixture / Source | Status | Purpose | Main signals |
|------------------|--------|---------|--------------|
| `experiments/human_agent_syntax_comprehension_fixture/field_supply_watch.ig` | non-canon experiment | Blind comprehension specimen for audited temporal supply workflow | Strong domain readability; ambiguity around `agent mesh`, `ObsId`, `human_review`, `olap_point`, `compute`, view materialization |
| `experiments/human_agent_syntax_comprehension_fixture/field_supply_watch_v2.ig` | non-canon experiment | Revised supply specimen testing better surface spellings | `delegate`, `await_review`, `metric`, `EvidenceRef`, `let`, explicit trust, explicit stream seed improved comprehension |
| `experiments/human_agent_syntax_comprehension_fixture/field_supply_watch_v3.ig` | non-canon experiment | Verifiability layer specimen | `threshold`, `external pure`, declarative receipt identity, `accumulate`, evidence/hash/signature pressure |
| `experiments/human_agent_syntax_comprehension_fixture/academic_sorting_structures.ig` | non-canon experiment | General-purpose/proof pressure specimen | Generics/traits/variants readable; audit `evidence`/`receipt` conflicts with mathematical proof; constructor resolution needs work |
| `experiments/human_agent_syntax_comprehension_fixture/primitive_surface_fixture.ig` | non-canon experiment | Primitive surface specimen | Arrays, maps, sets, operators, `entity`, `entrypoint`, collection chains as contract-backed sugar pressure |
| Surface-layering spec review | pressure | External review after partial spec exposure | `entrypoint`, `section`, `entity`, primitive literals, stream chains, ordinary operators, record spread |

---

## Construct Status Table

| Construct / spelling | Status | Source | Registry note |
|----------------------|--------|--------|---------------|
| `module` | canon | spec ch2 | Accepted grammar kernel |
| `import` | canon | spec ch2 | Accepted grammar kernel |
| `contract` | canon | spec/current-status | Root computation boundary; do not reduce to function |
| `input`, `read`, `compute`, `output` | canon | spec ch2 | Contract body kernel; `compute` remains canonical node spelling |
| `type` structural record | canon | spec ch2/ch3 | Accepted record type surface |
| `def` | canon | spec ch2 | Pure non-recursive function surface |
| `external ruby/rust/js/wasm` | canon | spec ch2 | Kernel external declaration exists; richer `external pure` helper signatures are pressure |
| ordinary operators `+ - * / == != < <= > >= && ||` | canon | spec ch2 | Least-surprise expression grammar already in kernel |
| `ArrayLit` as `[a, b]` | canon | spec ch2 | Kernel array literal exists |
| record literal `{ field: value }` | canon | spec ch2 | Kernel record literal exists; record spread is not canon |
| `Collection[T]`, `Option[T]`, `Result[T,E]`, `Map[K,V]` | canon | spec ch2/ch3 | Type forms exist in kernel/type system |
| `History[T]`, `BiHistory[T]` | canon | Stage 2 close / PROP-022 | Closed in Stage 2 proofs |
| `stream` / `fold_stream` | canon | Stage 2 close / PROP-023 | Closed in Stage 2; friendlier aliases remain pressure |
| `olap_point` / `OLAPPoint[T,Dims]` | canon | Stage 2 close / PROP-024 | Canonical Stage 2 OLAP surface |
| invariant severity `:error/:warn/:soft/:metric` | canon | Stage 2 close / PROP-025 | Closed with deferred OOF-I1/I3/I5 gaps |
| `view` as materialized projection | pressure | field supply v0/v2 | Type/view split reads better, but lifecycle/materialization semantics need formalization |
| `packet`, `event`, `receipt` | pressure | field supply fixtures | Strong data-role readability; not closed canon as source top-level profiles |
| `EvidenceRef` / `evidence_refs(...)` | pressure | field supply v2 | Better than `ObsId`, but evidence identity surface still unsettled |
| `evidence [...]` on outputs | pressure | field supply fixtures | Strong audit signal; needs separation from proof/witness/signature semantics |
| `receipt` for audit artifacts | pressure | field supply fixtures | Valuable for operational decisions; `receipt SortProof` shows misuse risk |
| `proof` / `witness` | pressure | sorting review | Needed to separate math proof from audit receipt; no canon spelling yet |
| `content_hash(...)` for receipt id | pressure | field supply v0/v2 | Need declarative receipt identity, e.g. `id by content_hash(...)`; not canon |
| `agent mesh` | non-canon experiment | field supply v0 | Over-associated with AI model; avoid as future surface |
| `mesh SupplyAnalysisMesh` | pressure | field supply v2 | Mesh concept is important; vocabulary boundary with agent/model/tool still open |
| `delegate ... capability` | pressure | field supply v2 | Strong readability; no canon grammar/proof yet |
| `trust all`, `peer.trust at_least` | pressure | field supply v2 | Good lattice pressure; not canon |
| `human_review` | non-canon experiment | field supply v0 | Replaced in tests by clearer `await_review`; keep only as historical fixture spelling |
| `await_review` | pressure | field supply v2 | Strong lifecycle signal; sync/async/suspend/resume semantics need proof |
| `let` inside `def` / expression blocks | canon | spec ch2 | Kernel local binding exists |
| `let` as contract-body replacement for `compute` | pressure | field supply v2 / sorting | Readable, but must preserve graph node identity if adopted |
| `metric` | pressure | field supply v2 | Friendly alias candidate over `olap_point`; not canon |
| `Decimal[scale: n]` | pressure | field supply v2 | Clearer than `Decimal[n]`; current type docs still use `Decimal[N]` / `Decimal[2]` |
| named `threshold` / constants | pressure | comprehension results 002 | Needed for verifiability; no canon spelling |
| `external pure fn(...) -> T` | pressure | comprehension results 002 | FFI/helper signature lane; distinct from kernel `external LangId` |
| `entrypoint` | proposal | Stage 3 governance / surface review | PROP-029 review lane after prerequisite spec sync; not canon |
| `section` | pressure | surface-layering review | Useful grouping without namespace semantics; needs specimen before PROP |
| `entity` | proposal | Stage 3 governance / surface review | PROP-031 idea; identity/lifecycle boundary open |
| map literal `{ "k" => v }` | pressure | surface-layering review | Needs decision versus record literal `{ field: value }` |
| set literal `#{ ... }` | pressure | surface-layering review | Useful primitive surface; no canon type/literal yet |
| method-chain streams `.window().map().filter()` | pressure | surface-layering review | Readable sugar candidate over stream contracts; not canon |
| record spread `{ ...report, field: value }` | pressure | surface-layering review | Compact DTO pressure; risky for audit if field mapping is hidden |
| `trait` | pressure | academic sorting | General-purpose capability pressure; no canon source declaration yet |
| `variant Name { case }` top-level declaration | pressure | academic sorting | Variant type concept exists, but this source spelling is not canon |
| bare constructors `nil`, `cons(...)` | pressure | academic sorting | Constructor resolution and namespacing need formal grammar |
| `match` | pressure | academic sorting | Needed for ADT ergonomics; not canon in current source kernel |
| `decreases` | pressure | academic sorting | Termination/proof pressure; structural vs well-founded distinction unresolved |

---

## Registry Rules

[R1] When creating a new syntax fixture, list non-canon constructs in the
fixture's evaluator guide.

[R2] Use fixture syntax to test comprehension, not to imply parser support.

[R3] If a pressure construct appears in two successful independent reviews,
route it to a bounded Stage 3 experiment before PROP work.

[R4] If a construct affects semantics, runtime behavior, evidence, time,
storage, or trust, it needs Compiler/Grammar Expert or Bridge Agent ownership
before canon.

[R5] Prefer preserving exact historical fixture spellings in old fixtures rather
than rewriting archaeology.

---

## S3-R4 Review Routing Snapshot

Source: [Syntax Pressure Review Results](syntax-pressure-review-results-v0.md)

| Construct | Route | Note |
|-----------|-------|------|
| `threshold name: T = value` | route_to_proposal | High verifiability gain, low runtime risk |
| `external pure fn(...) -> T` | route_to_proposal | Needed for helper/FFI reasoning, purity, effects, evidence behavior |
| `entrypoint` | route_to_proposal | Repeatedly reinforced as visible start surface |
| `section` | route_to_proposal | Low-risk if organizational only, no namespace semantics |
| declarative receipt identity | needs_another_specimen | Wait for evidence/receipt/proof/hash/signature separation |
| `entity` | needs_another_specimen | Needs identity-over-time fixture tied to History/BiHistory/lifecycle |
| map literal `{ k => v }` / `HashMap` | needs_another_specimen | Compare against record literal and JSON-like alternatives |
| set literal `#{ ... }` / `Set[T]` / `in` | needs_another_specimen | Compare alternatives and typed lowering rules |
| collection method chains | needs_another_specimen | Must preserve contract graph identity and evidence/proof edges |
| `EvidenceRef`, `evidence_refs(...)`, `evidence [...]` | needs_another_specimen | Needs dedicated provenance/evidence fixture |
| `accumulate` | keep_pressure | Compare with `fold_stream` and stream method chains |
| `await_review` | keep_pressure | Needs suspend/resume/timeout/receipt model |
| `delegate ... capability` | keep_pressure | Route through mesh/agent/tool/model vocabulary review |
| `metric` | keep_pressure | Friendly alias over canonical OLAPPoint, not urgent |
| `profile`, `packet`, `event`, `receipt`, `view` | keep_pressure | Strong data-role pressure, profile taxonomy not closed |
| `let` as contract-body `compute` replacement | keep_pressure | Needs graph identity proof before proposal |
| fixture-level `let` | keep_pressure | May belong in `fixture`/`sample` surface |
| `assert` section | reject_defer | Keep as evaluator/test fixture syntax for now |

No construct in this snapshot is promoted to canon.

---

## Recommended Next Specimens

### 1. Field Supply Watch v3 — Verifiability Layer

Purpose:

```text
Test named thresholds, external pure helper signatures, declarative receipt id,
and a friendlier stream accumulation surface.
```

Include:
- `threshold` or named constants
- `external pure` helper signatures
- `id decision_id by content_hash(...)` or equivalent
- `accumulate` or stream-chain surface
- explicit distinction between evidence, hash, and signature

Do not canonize:
- `metric`
- `delegate`
- `await_review`
- new receipt-id syntax

### 2. Proof Sorting v1 — Proof/Audit Split

Purpose:

```text
Retest academic sorting after separating proof/witness from audit receipt.
```

Include:
- `proof` or `witness`
- `proof: required`, `evidence: optional`
- shared `MergeSort` intermediates
- named strategy cutoff
- explicit recursion mode

Do not canonize:
- `trait`
- `variant`
- `match`
- `decreases`

### 3. Primitive Surface Fixture

Purpose:

```text
Test whether ordinary arrays/maps/sets/operators can be read as familiar code
while agents infer contract-backed types.
```

Include:
- `[1, 2, 3]`
- map literal candidate
- set literal candidate
- `Option` / `Result`
- ordinary arithmetic and comparison
- evaluator guide explaining expected lowerings

Do not canonize:
- map/set literal spelling until grammar decision

### 4. Entry / Section / Entity Business Fixture

Purpose:

```text
Test visible abstraction layers and identity-over-time in a CRM/ERP-style file.
```

Include:
- `section Domain`, `section Storage`, `section Contracts`, `section Entry`
- `entrypoint`
- `entity alice: Employee`
- History/BiHistory-backed lifecycle

Do not canonize:
- `section`
- `entrypoint`
- `entity`

### 5. Mesh Capability Vocabulary Fixture

Purpose:

```text
Separate mesh peer execution, agent policy, model/tool invocation, capability,
trust/admission, timeout/retry, and delegation evidence.
```

Include:
- mesh peer
- agent policy
- model/tool call
- capability declaration
- trust lattice/admission rule
- delegation receipt/evidence

Do not canonize:
- `delegate`
- trust syntax
- mesh vocabulary

---

## Handoff

```text
Card: S3-R2-C6-P
Agent: [Igniter-Lang Archive/Form Expert]
Role: archive-form-expert
Track: syntax-pressure-registry-v0
Status: done

[D] Created syntax pressure registry for current comprehension fixtures.
[S] Indexed Field Supply Watch v0/v2, academic sorting, and surface-layering
    review.
[T] Construct table marks canon/proposal/pressure/non-canon experiment without
    promoting fixture syntax.
[R] Next specimens: Field Supply Watch v3, Proof Sorting v1, Primitive Surface,
    Entry/Section/Entity, Mesh Capability Vocabulary.
```
