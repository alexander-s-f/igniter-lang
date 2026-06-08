# PROP-028: TEMPORAL Fragment Class v0

Status: implementation-partial
Date: 2026-05-08
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Depends on: PROP-003, PROP-008, PROP-022, PROP-023, PROP-024
Stage: 3
Source: `docs/meta-proposals/external-review-response-2026-05-07.md`

Implementation evidence (S3-R2..R5):
  ✅ Classifier: TEMPORAL classification for History[T]/BiHistory[T] reads (S3-R2-C2)
  ✅ TypeChecker: temporal node propagation + OOF rules (S3-R2-C2)
  ✅ SemanticIR: temporal_input_node + temporal_access_node (S3-R3-C2)
  ✅ Cache key contract: CORE vs TEMPORAL key schema proven (S3-R3-C3, S3-R4-C5)
  ✅ Assembler: temporal nodes assemble to .igapp/ (S3-R4-C1, S3-R5-C1)
  ✅ RuntimeMachine load guard: TEMPORAL loads for inspection (S3-R5-C2)
  ⏳ Parser coordinate syntax: not yet settled (future parser-syntax proposal)
  🚫 Production runtime execution: guarded until executor + TBackend binding (Gate 3)

---

## § 1. Purpose

Stage 2 proved `History[T]`, `BiHistory[T]`, stream T, OLAPPoint, and typed
SemanticIR lowering. The remaining gap is that temporal reads are still treated
like generic `ESCAPE` in the classifier/runtime boundary.

This is too coarse.

Temporal access is not merely "outside CORE." It is a deterministic evaluation
of a contract under an explicit temporal coordinate:

```text
eval(G, Tt, inputs)
```

A temporal read requires a TBackend capability and an explicit time axis, but it
produces an ordinary typed value that downstream pure computation can consume.
That distinction matters for classification, routing, and cache correctness.

PROP-028 introduces `TEMPORAL` as a first-class fragment class.

Non-goals:

- no parser implementation in this PROP
- no runtime implementation in this PROP
- no `fold_temporal`
- no change to the `History[T] ≡ OLAPPoint[T, {time: DateTime}]` theorem

---

## § 2. Fragment Classes

### § 2.1 Refined Stage 3 fragment order

For refined Stage 3 fragment propagation:

```text
OOF > TEMPORAL > STREAM > CORE
```

Meaning:

- `CORE`: no external capability required; cache key depends only on contract
  identity and explicit inputs.
- `STREAM`: requires stream/window capability; bounded stream fold may produce a
  CORE-typed result, but the contract remains stream-involved.
- `TEMPORAL`: requires TBackend read capability under explicit temporal
  coordinates; produces CORE-typed values, but the contract remains temporal.
- `OOF`: compile-time rejection.

Existing `ESCAPE` remains a legacy/coarse category for surfaces that have not
yet been split into refined classes. Stage 3 implementations should normalize
known temporal reads to `TEMPORAL` and known stream nodes to `STREAM` before
computing `contract_fragment_class`.

### § 2.2 Node-level vs contract-level class

PROP-028 distinguishes:

```text
node_fragment_class
value_fragment_class
contract_fragment_class
```

For a temporal read:

```text
node_fragment_class  = TEMPORAL
value_fragment_class = CORE
contract_fragment_class includes TEMPORAL
```

The node requires TBackend access. The symbol it binds is an ordinary typed
value such as `Option[Money]`, `Collection[Report]`, or `ScheduleFact`.
Downstream pure compute nodes that consume the bound symbol remain CORE nodes.
The containing contract remains TEMPORAL because its evaluation depends on
`Tt`.

Example:

```text
read price_at_order: History[Money] from prices as_of order.created_at
compute taxed = price_at_order.value * tax_rate
```

Classification:

```text
read price_at_order    node_fragment_class: TEMPORAL
price_at_order symbol  value_fragment_class: CORE
compute taxed          node_fragment_class: CORE
contract               contract_fragment_class: TEMPORAL
```

---

## § 3. TEMPORAL Read Semantics

### § 3.1 Definition

A TEMPORAL read is a node that:

1. reads from `History[T]`, `BiHistory[T]`, or an OLAP-backed temporal view;
2. requires a TBackend capability;
3. names an explicit temporal coordinate (`as_of`, `vt`, `tt`, or a typed
   `TemporalCtx`);
4. produces a CORE-typed value;
5. emits temporal access evidence/observations at runtime.

Canonical SemanticIR node families:

```text
temporal_input_node
temporal_access_node
olap_access_node with temporal dimensions
```

Capability names:

```text
history_read     -- single-axis valid-time read
bihistory_read   -- valid-time + transaction-time read
olap_point_read  -- OLAP-backed temporal/multidimensional read
```

`bitemporal_read` may remain as a compatibility alias during migration, but the
canonical capability name is `bihistory_read`.

### § 3.2 TEMPORAL value flow

A TEMPORAL read does not poison the value graph.

Bad model:

```text
TEMPORAL read -> TEMPORAL value -> all downstream computes TEMPORAL
```

Correct model:

```text
TEMPORAL read -> CORE-typed value -> downstream pure computes remain CORE nodes
```

The contract-level class still records that a TBackend was required.

### § 3.3 No `fold_temporal`

There is no `fold_temporal`.

This is a semantic statement, not an implementation limitation.

`fold_stream` exists because an unbounded stream can be turned into a bounded
closed window, and the fold result is a CORE value over that window.

Temporal data is different:

- a temporal read is an indexed view at explicit coordinates;
- it is not an unbounded sequence that can be "closed";
- the contract is parameterized by `Tt`;
- no local fold removes the TBackend requirement from the contract.

Downstream pure computations can be CORE nodes, but the contract remains
TEMPORAL.

---

## § 4. Classification Tables

### § 4.1 AST / declaration kinds

| AST or declaration kind | Node class | Bound value class | Contract impact |
|-------------------------|------------|-------------------|-----------------|
| `input` | CORE | CORE | CORE |
| `const` | CORE | CORE | CORE |
| pure `compute` | CORE | CORE | max deps by value class |
| `stream name: T` | STREAM | STREAM handle | STREAM |
| bounded `fold_stream` node | STREAM | CORE | STREAM |
| `read History[T] ... as_of` | TEMPORAL | CORE | TEMPORAL |
| `read BiHistory[T] ... vt/tt` | TEMPORAL | CORE | TEMPORAL |
| temporal `olap_access_node` | TEMPORAL | CORE | TEMPORAL |
| `bi_history_correct` / append | TEMPORAL or ESCAPE-write | CORE/receipt | TEMPORAL + audit capability |
| unknown external call | OOF | none | OOF |

### § 4.2 Contract class computation

Given a contract with node classes:

```text
contract_fragment_class = max(node_fragment_class*)
```

using:

```text
OOF > TEMPORAL > STREAM > CORE
```

Pure computes that consume CORE-typed values emitted by TEMPORAL reads do not
individually become TEMPORAL. The contract remains TEMPORAL because the read
node is present.

---

## § 5. Cache Semantics

### § 5.1 CORE cache key

CORE contracts are deterministic over contract identity and explicit inputs:

```text
CORE cache key = hash(contract, inputs)
```

`contract` means the stable compiled contract identity, such as `contract_ref`
or equivalent canonical contract hash.

### § 5.2 TEMPORAL cache key

TEMPORAL contracts are deterministic over contract identity, explicit inputs,
and temporal coordinates:

```text
TEMPORAL cache key = hash(contract, inputs, as_of/Tt)
```

For single-axis reads:

```text
hash(contract, inputs, as_of)
```

For bitemporal reads:

```text
hash(contract, inputs, vt, tt)
```

For multiple temporal reads, the temporal component is the canonical sorted set
of all temporal coordinates used by the contract evaluation.

### § 5.3 Silent staleness bug

If a RuntimeMachine caches a TEMPORAL contract using the CORE key, it can return
a stale value for a different `as_of` without crashing.

This is not a performance detail. It is a semantic correctness requirement.

Runtime implementations must inspect `contract_fragment_class` before building
cache keys:

```text
CORE      -> hash(contract, inputs)
TEMPORAL  -> hash(contract, inputs, temporal_coordinates)
STREAM    -> runtime/window-specific cache policy, not CORE key
OOF       -> not cacheable; not emitted
```

---

## § 6. OOF Rules For Temporal Misuse

Existing Stage 2 implementations already use some concrete rule names:

```text
OOF-H1   history_at requires as_of
OOF-BT2  bihistory_at missing vt
OOF-BT3  bihistory_at missing tt
OOF-BT4  bihistory_at axis type mismatch
```

PROP-028 defines the Stage 3 temporal misuse rule family. Implementations may
keep old names as compatibility aliases during migration.

```text
OOF-TM1: Temporal read without explicit temporal coordinate
         → "temporal read requires explicit as_of/Tt"
         Existing alias: OOF-H1 for History[T].

OOF-TM2: Temporal read uses ambient time (`now`, wall clock, runtime default)
         without an explicit TemporalCtx binding
         → "ambient time is OOF; pass as_of/Tt explicitly"

OOF-TM3: History[T] temporal coordinate has non-DateTime type
         → "history read as_of must be DateTime, got {type}"
         Existing alias: OOF-BT1 where applicable.

OOF-TM4: BiHistory[T] read missing valid-time axis (`vt`)
         → "bitemporal read requires valid_time (vt)"
         Existing alias: OOF-BT2.

OOF-TM5: BiHistory[T] read missing transaction-time axis (`tt`)
         → "bitemporal read requires transaction_time (tt)"
         Existing alias: OOF-BT3.

OOF-TM6: BiHistory[T] axis has non-DateTime type
         → "bitemporal axis {axis} must be DateTime, got {type}"
         Existing alias: OOF-BT4.

OOF-TM7: TEMPORAL construct inside CORE-required lambda/body
         → "CORE-required function contains TEMPORAL read: {node}"
         Example: fold_stream accumulator body reads TBackend.
         This may also surface as OOF-S3 for fold_stream-specific contexts.

OOF-TM8: TEMPORAL read without required TBackend capability
         → "temporal read requires capability {history_read|bihistory_read|olap_point_read}"

OOF-TM9: TEMPORAL contract declared/cacheable as CORE
         → "temporal contract cannot use CORE cache key; include as_of/Tt"
         This is a compile/load-time conformance failure, not a parser syntax error.
```

Deferred or non-goal rules:

- temporal write/correction semantics remain governed by PROP-022/PROP-008
- stream-specific OOF-S1..S5 remain in PROP-023
- OLAP dimension validation remains in PROP-024

---

## § 7. SemanticIR Requirements

SemanticIR should preserve the node/value distinction.

Required fields for temporal access nodes:

```json
{
  "kind": "temporal_access_node",
  "name": "status_at_dispatch",
  "node_fragment_class": "temporal",
  "value_fragment_class": "core",
  "source_ref": "status_history",
  "axis": "valid_time",
  "as_of_ref": "decision_at",
  "result_type": { "constructor": "Option", "params": ["Status"] },
  "required_capability": "history_read"
}
```

For bitemporal:

```json
{
  "kind": "temporal_access_node",
  "name": "hgb_known_at_decision",
  "node_fragment_class": "temporal",
  "value_fragment_class": "core",
  "source_ref": "hgb_history",
  "axis": "bitemporal",
  "valid_time_ref": "decision_at",
  "transaction_time_ref": "decision_at",
  "result_type": { "constructor": "Option", "params": ["LabValue"] },
  "required_capability": "bihistory_read"
}
```

ContractIR should include:

```json
{
  "fragment_class": "temporal",
  "required_capabilities": ["history_read"],
  "cache_policy": {
    "kind": "temporal",
    "key_parts": ["contract", "inputs", "as_of"]
  }
}
```

Exact field names may be refined during implementation, but the semantics are
not optional.

---

## § 8. Implementation Acceptance Checklist

Implementation is complete when all of the following are true:

### Classifier / ClassifiedProgram

- [ ] `read History[T]` with explicit `as_of` classifies as
      `node_fragment_class: temporal`.
- [ ] `read BiHistory[T]` with explicit `vt` and `tt` classifies as
      `node_fragment_class: temporal`.
- [ ] Symbols bound by temporal reads are registered as CORE-typed values for
      downstream pure compute classification.
- [ ] Contract fragment class uses `OOF > TEMPORAL > STREAM > CORE`.
- [ ] Existing STREAM SC-1/2/3 behavior remains unchanged.
- [ ] Legacy `escape` labels are normalized or explicitly bridged.

### TypeChecker

- [ ] `OOF-TM1` / `OOF-H1` blocks missing `as_of`.
- [ ] `OOF-TM4` / `OOF-BT2` blocks missing `vt`.
- [ ] `OOF-TM5` / `OOF-BT3` blocks missing `tt`.
- [ ] `OOF-TM3` and `OOF-TM6` validate DateTime axis types.
- [ ] `OOF-TM7` blocks temporal reads inside CORE-required lambdas, including
      fold_stream accumulators.
- [ ] `OOF-TM8` checks required TBackend capability metadata.

### SemanticIR

- [ ] `temporal_access_node` carries `node_fragment_class: temporal`.
- [ ] `temporal_access_node` carries `value_fragment_class: core`.
- [ ] ContractIR carries `fragment_class: temporal` when any node is temporal.
- [ ] ContractIR carries required temporal capabilities.
- [ ] ContractIR or CompilationReport carries a temporal cache policy.
- [ ] No `fold_temporal` node is emitted.

### Runtime / Cache

- [ ] RuntimeMachine chooses cache key by `contract_fragment_class`.
- [ ] CORE key is `hash(contract, inputs)`.
- [ ] TEMPORAL key is `hash(contract, inputs, as_of/Tt)`.
- [ ] Bitemporal key includes both `vt` and `tt`.
- [ ] TEMPORAL contracts cannot be loaded with a CORE cache policy.
- [ ] Existing RuntimeMachine temporal access observations still include
      selected temporal coordinates and evidence links.

### Proofs / Goldens

- [ ] Positive History[T] temporal read proof emits TEMPORAL contract class.
- [ ] Positive BiHistory[T] temporal read proof emits TEMPORAL contract class.
- [ ] Downstream pure compute from temporal read remains CORE node.
- [ ] Missing `as_of`, missing `vt`, missing `tt`, wrong axis type negatives
      still PASS.
- [ ] Cache key proof demonstrates two different `as_of` values produce two
      distinct TEMPORAL cache keys.
- [ ] Stage close candidate remains PASS.

---

## Handoff

```text
Card: S3-R1-C2-P
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/prop-028-temporal-fragment-class-v0
Status: proposal written

[D] Decisions:
- TEMPORAL is a first-class Stage 3 fragment class.
- Node-level and contract-level fragment classes are distinct.
- TEMPORAL reads require TBackend capability but produce CORE-typed values.
- No fold_temporal.
- Fragment ordering is OOF > TEMPORAL > STREAM > CORE.
- CORE and TEMPORAL cache keys differ by explicit temporal coordinates.

[S] Signals:
- External review response is incorporated directly.
- Existing OOF-H/OOF-BT rules are preserved as compatibility aliases.
- Runtime cache staleness is treated as a semantic correctness risk.

[T] Tests / Proofs:
- Proposal-only slice. No parser/runtime implementation and no executable tests.

[R] Risks / Residuals:
- Existing ESCAPE labels must be normalized carefully during implementation.
- Temporal write/correction remains separate from read classification.
- Runtime cache semantics are latent until memoization lands, but must be fixed before it does.

[Next]
- Implement classifier/typechecker TEMPORAL split.
- Add SemanticIR temporal fragment/cache policy goldens.
- Add RuntimeMachine cache-key proof before enabling temporal memoization.
```
