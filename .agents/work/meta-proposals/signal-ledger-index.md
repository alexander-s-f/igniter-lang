# Living Signal Ledger Index v0

Role: `[Igniter-Lang Archive/Form Expert]`
Card: `S2-R9-C4-P`
Track: `living-signal-ledger-index-v0`
Status: index
Date: 2026-05-07

> ⚠️ **STALE — Stage 2 snapshot only.**
> Last updated: 2026-05-07 (Stage 2 close, S2-R9).
> Stage 3 signals (TEMPORAL, typed emission, temporal-assembler boundary, cache contract)
> are **not** reflected here. Do not treat this index as current.
> Refresh action: `archive-form-expert` to extend coverage through S3-R1..R4 when
> a Stage 3 signal-ledger refresh is authorized.

Sources:
- [META-EXPERT-008.4](META-EXPERT-008.4-origin-temporal-concordance-v0.md)
- [META-EXPERT-008.5](META-EXPERT-008.5-runtime-ledger-mesh-concordance-v0.md)

---

## Purpose

This is a compact living index over signals already recovered by concordance
slices. It does not promote any signal to canon.

Status enum:

```text
current_canon   -- already language canon/proof; protect during implementation
package_bridge  -- strong package/runtime evidence; needs explicit bridge
future_proof    -- valuable signal needing proof/PROP/experiment later
parked          -- preserve as warning/reference; no action now
```

---

## Ledger

| Signal | Status | Source | Owning next role | Next possible action |
|--------|--------|--------|------------------|----------------------|
| S01 | future_proof | META-EXPERT-008.4 | Compiler/Grammar Expert | Add five-identity review matrix for future constructs |
| S02 | future_proof | META-EXPERT-008.4 | Applied Pressure Agent | Design SIR benchmark over real app corpus |
| S03 | current_canon | META-EXPERT-008.4 | Compiler/Grammar Expert | Keep grammar-after-semantics as review gate |
| S04 | package_bridge | META-EXPERT-008.4 | Bridge Agent | Frame Ruby DSL/reference backend as BackendContract pressure |
| S05 | future_proof | META-EXPERT-008.4 | Compiler/Grammar Expert | Define general-purpose CORE/ESCAPE profile later |
| S06 | future_proof | META-EXPERT-008.4 | Compiler/Grammar Expert | Classify old constructs as CORE/ESCAPE/runtime/parked |
| S07 | current_canon | META-EXPERT-008.4 | Research Agent | Protect History temporal access during production RM integration |
| S08 | current_canon | META-EXPERT-008.4 | Research Agent | Protect BiHistory axes/four-query semantics |
| S09 | future_proof | META-EXPERT-008.4 | Compiler/Grammar Expert | Later rule algebra/RDG proof sketch |
| S10 | future_proof | META-EXPERT-008.4 | Research Agent | Park until rule algebra exists; then temporal synthesis proof |
| S11 | future_proof | META-EXPERT-008.4 | Bridge Agent | Route into distributed RuntimeContract pressure |
| S12 | current_canon | META-EXPERT-008.4 | Compiler/Grammar Expert | Protect stream ESCAPE/bounded fold bridge |
| S13 | current_canon | META-EXPERT-008.4 | Compiler/Grammar Expert | Preserve History/OLAP unification invariant |
| S14 | current_canon | META-EXPERT-008.4 | Compiler/Grammar Expert | Continue OLAP TypeChecker/SemanticIR path |
| S15 | future_proof | META-EXPERT-008.4 | Research Agent | Later Forecast/time_machine proof after temporal lowering |
| S16 | package_bridge | META-EXPERT-008.4 | Bridge Agent | Shape Store/Backend/RuntimeContract bridge |
| S17 | package_bridge | META-EXPERT-008.4 | Bridge Agent | Map HistorySegment/DistributedHistory to Ledger/Store lowering |
| S18 | parked | META-EXPERT-008.4 | Compiler/Grammar Expert | Preserve as ambient-time warning |
| RLM01 | current_canon | META-EXPERT-008.5 | Research Agent | Protect RuntimeMachine lifecycle during SemanticIR emitter extraction |
| RLM02 | current_canon | META-EXPERT-008.5 | Bridge Agent | Use TBackend six-op contract as adapter boundary |
| RLM03 | current_canon | META-EXPERT-008.5 | Research Agent | Preserve SemanticImage as content-addressed session root |
| RLM04 | current_canon | META-EXPERT-008.5 | Research Agent | Preserve CompatibilityReport GATE-1 invariant |
| RLM05 | future_proof | META-EXPERT-008.5 | Bridge Agent | Align lifecycle/retention/GC roots with Ledger compaction |
| RLM06 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Production RuntimeMachine temporal TBackend integration |
| RLM07 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Use selected_profile for first package conformance candidate |
| RLM08 | future_proof | META-EXPERT-008.5 | Research Agent | Prove replacement SemanticImage after migration |
| RLM09 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Map Ledger Open Protocol to TBackend operations |
| RLM10 | future_proof | META-EXPERT-008.5 | Research Agent | Bounded inference proof over ledger facts |
| RLM11 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Align compact/prune/purge with lifecycle semantics |
| RLM12 | package_bridge | META-EXPERT-008.5 | Compiler/Grammar Expert | Relate Changefeed replay cursors to stream/replay semantics |
| RLM13 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Use Durable Model partition replay for History lowering |
| RLM14 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Persist selected proof receipts as Ledger facts |
| RLM15 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Keep MCP transport thin; route tool receipts later |
| RLM16 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Prepare distributed RuntimeContract pressure map |
| RLM17 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Map MeshExecutionTrace to distributed evaluation receipt shape |
| RLM18 | future_proof | META-EXPERT-008.5 | Compiler/Grammar Expert | Preserve MeshQL as later placement-query grammar pressure |
| RLM19 | package_bridge | META-EXPERT-008.5 | Bridge Agent | Add topology freshness to distributed runtime evidence map |
| RLM20 | parked | META-EXPERT-008.5 | Research Agent | Preserve consensus/Raft as reference only |

---

## After R9 Action Recommendation

The three signals that deserve action after R9:

| Rank | Signal | Why now |
|------|--------|---------|
| 1 | RLM06 | It directly matches the open Stage 2 production RuntimeMachine temporal integration gap. |
| 2 | RLM09 | It gives the clean package-side vocabulary for a Ledger-backed TBackend adapter. |
| 3 | S16 | It prevents the bridge from becoming package-only by keeping Store/Backend/RuntimeContract pressure visible. |

[R] Treat these as one bridge chain, not three unrelated tasks:

```text
S16 Store/Backend contract frame
  -> RLM09 Ledger Open Protocol mapping
  -> RLM06 production RuntimeMachine TBackend integration
```

---

## Handoff

Card: `S2-R9-C4-P`
Role: `[Igniter-Lang Archive/Form Expert]`
Track: `living-signal-ledger-index-v0`
Status: index

[D] Created a compact living signal ledger index over META-EXPERT-008.4 and
META-EXPERT-008.5.

[S] The normalized ledger status enum is `current_canon`, `package_bridge`,
`future_proof`, `parked`.

[T] No signal is promoted to canon by this index.

[R] After R9, action should focus on RLM06, RLM09, and S16 as one
Store/Backend/Ledger/TBackend bridge chain.

[Next] Bridge Agent should receive a focused Ledger-to-TBackend alignment slice
after SemanticIR emitter extraction.
