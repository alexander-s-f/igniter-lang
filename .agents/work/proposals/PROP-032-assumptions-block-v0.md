# PROP-032: Assumptions Block v0

Status: experiment-pass  [bounded compiler surface; PROP-033 evidence/runtime receipts excluded]
Date: 2026-05-10
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Depends on: PROP-031 (contract modifiers + escape declaration surface)
Stage: 3
Authorizing card: S3-R30-C6-P
Source: `docs/meta-proposals/META-EXPERT-013-spec-extension-governance-v0.md`
Governance: META-EXPERT-013 §VI (acceptance criteria); Covenant P22, P27, P28

---

## Queue Note — GI-1 Resolution

`proposals/README.md` previously queued PROP-032 as `via profile binding`.
`docs/dev/canonical-semantic-model.md`, `docs/agent-context.md`, and the
Semantic Governance Heat Map (GI-1) identify a conflict: the `assumptions {}`
block (Gap-H) is a higher governance priority under the Four Axes of Honesty and
has been consistently assigned PROP-032 in all CSM and status documents.

**This PROP resolves GI-1 by asserting PROP-032 = `assumptions {}` block.**

Downstream renumbering required in `proposals/README.md`:

| Old ID | Feature | New ID |
|--------|---------|--------|
| PROP-032 | `via profile binding` | PROP-033 |
| PROP-033 | `output evidence syntax` | PROP-034 |
| PROP-034 | profile declarations / authority resolution | PROP-035 |
| PROP-035 | Effect Surface | TBD (PROP-036 or beyond) |

---

## § 1. Purpose

A program that makes decisions must declare the premises it relies on. When a
contract scores risk using a threshold, classifies content by a heuristic, or
infers a zone from sensor data, the threshold, heuristic, and inference rule are
assumptions — premises that shape the output but are not derivable from the inputs.

The current grammar has no mechanism to declare these premises. They live in
magic constants, undocumented parameters, and model weights. They are hidden.

PROP-032 introduces the `assumptions {}` block as the language primitive for
**epistemic provenance**: a named, typed, traceable declaration of what a contract
takes as given.

```igniter
assumptions {
  assumption homophily {
    kind     :heuristic
    statement "People with similar beliefs interact more often."
    strength  0.70
  }
}

observed contract ScoreInteraction {
  input a: Signal
  input b: Signal
  uses assumptions homophily
  compute score = similarity(a, b) * homophily.strength
  output score: Decimal[4] evidence [a, b, homophily]
}
```

The assumption is named (P28), declared (P22), and carried through the evidence
chain (P22, P27). At receipt time, `assumption_refs` in the receipt names every
assumption the execution relied on.

Non-goals:

- No `constraints {}` block (Gap-J — deferred to a later PROP)
- No `form` constructor (Gap-I — deferred)
- No epistemic state machine enforcement (ESM upward-coercion guard — deferred)
- No runtime injection of assumption values (deferred; assumptions are compile-time
  declarations in this PROP)
- No cross-module assumption sharing (assumptions are module-scoped in this PROP)
- No Effect Surface interaction (PROP-035)

---

## § 2. Grammar

### § 2.1 New productions

```
-- Top-level declaration (alongside contracts, types, traits)
assumptions-block   ::= "assumptions" "{" assumption-decl* "}"

assumption-decl     ::= "assumption" ident "{" assumption-field* "}"

assumption-field    ::= "kind"      ":" assumption-kind
                      | "statement" string-literal
                      | "strength"  decimal-literal       -- range [0.0, 1.0]
                      | "source"    string-literal        -- optional provenance URI

assumption-kind     ::= ":heuristic"
                      | ":empirical"
                      | ":synthetic"
                      | ":calibrated"

-- In contract body (new body-decl variant)
uses-assumptions-decl ::= "uses" "assumptions" ident
```

`assumptions-block` is a top-level program declaration. There is at most one
`assumptions {}` block per module. Multiple named assumptions live inside it.

`uses-assumptions-decl` appears inside a contract body, alongside `input`,
`compute`, `output`, and `escape` declarations. It is a named, explicit dependency
on a declared assumption. A contract may declare multiple `uses assumptions` lines,
one per assumption it relies on.

### § 2.2 Backward compatibility guarantee

No existing grammar changes. `assumptions {}` and `uses assumptions` are new
productions. All programs without them parse without modification. No existing
fixtures require changes.

### § 2.3 Assumption kind vocabulary

| Kind | Meaning |
|------|---------|
| `:heuristic` | Rule-of-thumb premise; not empirically measured |
| `:empirical` | Measured or observed; carries documented strength |
| `:synthetic` | Constructed for simulation or test; declared world premise |
| `:calibrated` | Probabilistically measured with confidence; strength is calibration |

This vocabulary maps to the Epistemic State Machine states in the Covenant.
An `assumed` epistemic state in the ESM corresponds to a declared `assumption`.

---

## § 3. Assumption Semantics

### § 3.1 Scope

Assumptions are **module-scoped**. A declaration in the `assumptions {}` block
is visible to all contracts in the same source file (module). Cross-module
assumption sharing is not defined in this PROP.

### § 3.2 Naming invariant (P28)

Every assumption must have a name. There is no anonymous assumption. The grammar
enforces this: `assumption NAME { ... }` is the only form. An `assumptions {}`
block that contains an unnamed body is a parse error.

This satisfies P28: an unnamed block with semantic consequence is uncompilable.

### § 3.3 Uses-assumptions declaration

A contract must declare `uses assumptions NAME` to reference assumption NAME in:

- its `compute` expressions (`homophily.strength`)
- its `output ... evidence [...]` list

A contract that references `homophily.strength` or includes `homophily` in an
evidence list without a prior `uses assumptions homophily` is a type error (OOF-A1).

### § 3.4 Strength field

`strength` is a `Decimal` in the closed interval `[0.0, 1.0]`. It is the declared
author-assigned confidence in the assumption's validity. A TypeChecker check
enforces the range. Absent strength defaults to `null` (no confidence claim).

### § 3.5 Evidence propagation (P22)

A `uses assumptions NAME` declaration makes NAME a trackable evidence participant.
The compiler records it in `assumption_refs` on the contract and propagates it to:

- the classified contract's `assumption_refs` field
- the SemanticIR `contract_ir` `assumption_refs` field
- the receipt's `assumption_refs` field at runtime

This is the P22 guarantee: assumptions are carried through the evidence chain.

---

## § 4. Pipeline Stage Shapes

### § 4.1 Parser output (`parsed_program`)

The top-level `parsed_program` gains an `assumptions` field (array of declarations):

```json
{
  "kind": "parsed_program",
  "module": "Risk.Scoring",
  "assumptions": [
    {
      "kind": "assumption_decl",
      "name": "homophily",
      "fields": {
        "kind": "heuristic",
        "statement": "People with similar beliefs interact more often.",
        "strength": 0.70,
        "source": null
      }
    }
  ],
  "contracts": [
    {
      "kind": "contract",
      "name": "ScoreInteraction",
      "modifier": "observed",
      "type_params": [],
      "body": [
        { "kind": "input",            "name": "a", "type_annotation": "Signal" },
        { "kind": "input",            "name": "b", "type_annotation": "Signal" },
        { "kind": "uses_assumptions", "name": "homophily" },
        {
          "kind": "compute",
          "name": "score",
          "expr": {
            "kind": "binary_op",
            "op": "*",
            "left":  { "kind": "call", "fn": "similarity", "args": [
              { "kind": "ref", "name": "a" }, { "kind": "ref", "name": "b" }
            ]},
            "right": { "kind": "field_access", "object": { "kind": "ref", "name": "homophily" }, "field": "strength" }
          }
        },
        {
          "kind": "output",
          "name": "score",
          "type_annotation": { "kind": "type_ref", "name": "Decimal", "params": [{ "kind": "type_ref", "name": "4", "params": [] }] },
          "evidence": ["a", "b", "homophily"]
        }
      ]
    }
  ],
  "types": [],
  "parse_errors": []
}
```

Key deltas vs current shape:

- `parsed_program.assumptions: []` — new top-level field (empty array when no assumptions block)
- `body` may contain `{ "kind": "uses_assumptions", "name": NAME }` nodes
- `output` node gains `"evidence": [...]` field (list of names)

### § 4.2 Classifier output (`classified_program`)

The Classifier processes the assumption declarations into a registry and annotates
each contract with its assumption dependencies:

```json
{
  "kind": "classified_program",
  "assumption_registry": [
    {
      "kind": "assumption_entry",
      "name": "homophily",
      "fields": { "kind": "heuristic", "statement": "...", "strength": 0.70, "source": null },
      "declared_in_module": "Risk.Scoring"
    }
  ],
  "contracts": [
    {
      "kind": "classified_contract",
      "name": "ScoreInteraction",
      "modifier": "observed",
      "fragment_class": "escape",
      "assumption_refs": ["homophily"],
      "declarations": [
        { "decl_id": "input:a",                "kind": "input",            "fragment_class": "core",      ... },
        { "decl_id": "input:b",                "kind": "input",            "fragment_class": "core",      ... },
        { "decl_id": "uses_assumptions:homophily", "kind": "uses_assumptions", "fragment_class": "epistemic", "name": "homophily", "deps": [], "missing_refs": [] },
        { "decl_id": "compute:score",          "kind": "compute",          "fragment_class": "core",      ... },
        { "decl_id": "output:score",           "kind": "output",           "fragment_class": "core",      ... }
      ],
      "oof_log": []
    }
  ]
}
```

Key deltas vs current shape:

- `classified_program.assumption_registry: []` — new top-level field
- `classified_contract.assumption_refs: []` — names of assumptions used by the contract
- `uses_assumptions` declarations get `fragment_class: "epistemic"` (new fragment class)

### § 4.3 TypeChecker output (`typed_program`)

```json
{
  "kind": "typed_contract",
  "name": "ScoreInteraction",
  "modifier": "observed",
  "status": "accepted",
  "fragment_class": "escape",
  "assumption_refs": ["homophily"],
  "declarations": [ ... ],
  "type_errors": []
}
```

No new fields beyond propagating `assumption_refs` from the classified stage.
OOF-A1 entries (if any) appear in `type_errors` and set `status: "blocked"`.

### § 4.4 SemanticIR output (`semantic_ir`)

```json
{
  "kind": "semantic_ir",
  "assumption_registry": [
    {
      "kind": "assumption_ir",
      "name": "homophily",
      "fields": { "kind": "heuristic", "statement": "...", "strength": 0.70, "source": null }
    }
  ],
  "contracts": [
    {
      "kind": "contract_ir",
      "contract_name": "ScoreInteraction",
      "modifier": "observed",
      "fragment_class": "escape",
      "assumption_refs": ["homophily"],
      "inputs": [ ... ],
      "outputs": [ ... ],
      "nodes": [ ... ],
      "escape_boundaries": [ ... ]
    }
  ]
}
```

Key deltas vs current shape:

- `semantic_ir.assumption_registry: []` — new top-level field
- `contract_ir.assumption_refs: []` — new field; empty array when no assumptions used

---

## § 5. Classifier Changes

### § 5.1 New fragment class: `epistemic`

PROP-032 introduces a sixth fragment class: **`epistemic`**.

Updated fragment class vocabulary:

| Fragment class | Assigned to |
|---------------|-------------|
| `core` | Pure computation; no external access; no assumptions |
| `escape` | External I/O, observed reads, effect contracts |
| `temporal` | Contracts with `History[T]` or `BiHistory[T]` reads |
| `stream` | Contracts with stream declarations |
| `epistemic` | Contracts whose highest-class declaration is `uses_assumptions` |
| `oof` | Contracts with detected OOF violations |

`uses_assumptions` body declarations receive `fragment_class: "epistemic"` at node
level. A `pure contract` with only `uses_assumptions` and core declarations gets
`fragment_class: "epistemic"` at contract level.

### § 5.2 Precedence in `contract_fragment_for`

The updated precedence (highest to lowest):

```
oof > temporal > escape > epistemic > core
```

A contract with `fragment_class: "epistemic"` node declarations and no escape/
temporal declarations gets contract-level `fragment_class: "epistemic"`.
A contract with escape and epistemic declarations gets `fragment_class: "escape"`;
`assumption_refs` is still populated. This preserves the existing escape/temporal
precedence rules.

**P27 interaction:** Epistemic declarations carry accountability information
(assumption provenance). Making them a first-class fragment class means the
Classifier can identify contracts that rely on declared premises. This serves P27:
every primitive exists to make accountability legible.

### § 5.3 Assumption registry construction

The Classifier builds an `assumption_registry` from the parsed program's
`assumptions` array. Each entry maps name → declared fields. The registry is
available to all contract classification passes in the program.

### § 5.4 OOF-A1: undeclared assumption reference

```
OOF-A1  uses assumptions NAME where NAME is not declared in the module's
         assumptions {} block
         severity: error
         message:  "contract '#{contract_name}' uses assumptions '#{name}' but
                    no assumption named '#{name}' is declared in this module"
         node:     uses_assumptions declaration
```

**Stage ownership:** OOF-A1 is **detected by the Classifier**, following the same
two-stage pipeline as OOF-M1 (PROP-031 §14.5):

1. Classifier: appends OOF-A1 to `oof_log`, sets `fragment_class: "oof"`
2. TypeChecker: propagates to `type_errors`, sets `status: "blocked"`
3. SemanticIR Emitter: returns `nil` for blocked contracts

### § 5.5 TypeChecker check: strength range

When `strength` is present, the TypeChecker verifies `0.0 ≤ strength ≤ 1.0`.
A strength outside this range is a type error (not an OOF — it is a malformed
declaration, not a usage violation).

---

## § 6. TypeChecker Changes

The TypeChecker propagates assumption state without new logic beyond:

1. OOF-A1 propagation from `oof_log` → `type_errors` (standard two-stage pattern)
2. Strength range check (§5.5)
3. `assumption_refs` field passthrough from classified → typed contract

No new TypeChecker passes are introduced. The existing OOF propagation loop
handles OOF-A1 automatically.

---

## § 7. SemanticIR Changes

### § 7.1 Top-level `assumption_registry`

The SemanticIR gains a top-level `assumption_registry` field. When no `assumptions {}`
block is present, the field is an empty array `[]`.

### § 7.2 `assumption_refs` on `contract_ir`

Each `contract_ir` node gains an `assumption_refs` field: an array of assumption
names that the contract declares via `uses assumptions`. Empty array `[]` when no
assumptions are used. Default value: `[]` (defensive; absent in typed contract →
empty in contract_ir).

### § 7.3 No existing fields changed

`contract_ir` shape is otherwise unchanged. All existing golden files remain valid.

---

## § 8. Evidence and Receipt Propagation

### § 8.1 Evidence list

The `output` node gains an optional `evidence` field in the parsed AST: a list of
names that the output is derived from. Assumption names may appear in this list
only if the enclosing contract has a corresponding `uses assumptions NAME`
declaration. Referencing an undeclared assumption name in an evidence list triggers
OOF-A1.

```igniter
output score: Decimal[4] evidence [a, b, homophily]
--                                          ^ allowed: uses assumptions homophily declared above
```

The evidence list is informational in this PROP. Full evidence chain enforcement
(OOF codes for missing evidence, lineage validation) is deferred to PROP-033
(`output evidence syntax`).

### § 8.2 Receipt `assumption_refs`

At runtime, the execution receipt carries `assumption_refs: [...]` — the names of
all assumptions the contract declared via `uses assumptions`. This provides the
epistemic provenance trail required by P22.

```json
{
  "kind": "execution_receipt",
  "contract_name": "ScoreInteraction",
  "assumption_refs": ["homophily"],
  "escape_boundaries": ["sensor_read"],
  "inputs": { ... },
  "outputs": { ... }
}
```

The runtime copies `assumption_refs` from the SemanticIR `contract_ir` into the
receipt at execution time. No runtime resolution of assumption values occurs in
this PROP; the field is a name trace only.

---

## § 9. Covenant Interactions

### § 9.1 Postulate 22 — Assumption Visibility

**Direct implementation.** P22 states: "Every assumption a program relies on must
be declared, typed, and carried through its evidence chain."

PROP-032 satisfies this postulate at the language surface level:

| P22 requirement | PROP-032 mechanism |
|----------------|-------------------|
| Declared | `assumption NAME { ... }` in `assumptions {}` block |
| Typed | `kind`, `statement`, `strength` fields; TypeChecker validates range |
| Carried through evidence chain | `assumption_refs` in contract_ir + receipt |
| Named (not anonymous) | Grammar requires name; parse error otherwise |

### § 9.2 Postulate 27 — Accountability as Architecture

**Direct implementation.** P27's primitive table lists:

> `assumptions {}` — Epistemic provenance — what premises were declared and relied upon

PROP-032 turns this Covenant entry from aspirational (`spec_candidate`) to
`proposed`. When experiment PASS is reached, it becomes `experiment-pass` and the
P27 table entry is verifiable.

PROP Governance Filter check:

> Does this feature leave the audit trail more legible, neutral, or less legible?

Answer: **more legible.** Without `assumptions {}`, premises are hidden. With it,
every assumption is named, declared, and traceable in receipts. Accepted under the
filter.

### § 9.3 Postulate 28 — No Unnamed Block May Carry Semantic Identity

**Directly enforced.** P28 states: "`assumptions {}` blocks — named, carried
through `evidence []` chain."

PROP-032 enforces P28 for assumptions in two ways:

1. **Grammar enforcement**: The `assumption NAME { ... }` form requires a name.
   An unnamed assumption body is a parse error. There is no anonymous assumption.

2. **Classifier enforcement**: OOF-A1 detects `uses assumptions NAME` where NAME
   is undeclared. A contract cannot silently rely on an assumption that has no
   declared identity in the module's assumption registry.

The combination of grammar and OOF enforcement means: assumptions are either
named and declared, or they do not compile.

---

## § 10. Non-Goals

The following are explicitly **not** in scope for PROP-032:

| Feature | Deferred to |
|---------|-------------|
| `constraints {}` block (Gap-J) | Future PROP (after PROP-032 closes) |
| Epistemic state machine upward-coercion guard | Gap-H extension; needs ESM PROP |
| Cross-module assumption sharing | Stage 3+ extension |
| `uses assumptions` as a modifier (contract-level) | Under consideration; deferred |
| Runtime injection of assumption values | Effect Surface / runtime lane |
| `form` constructors | Gap-I; separate PROP |
| Evidence chain enforcement OOF codes | PROP-033 (output evidence syntax) |
| `output evidence [...]` full validation | PROP-033 |
| Synthetic world markers (`:synthetic` mode) | Separate PROP |
| Assumption versioning or migration | Future PROP |

---

## § 11. Acceptance Criteria

Per META-EXPERT-013 §VI:

1. Parser accepts `assumptions { assumption NAME { kind :K; statement "S"; strength N } }`
   at module top level
2. Parser accepts `uses assumptions NAME` in contract body
3. Classifier builds `assumption_registry` from declared assumptions; annotates contracts
   with `assumption_refs`; assigns `fragment_class: "epistemic"` to `uses_assumptions` nodes
4. Classifier fires OOF-A1 when `uses assumptions NAME` references an undeclared name
5. TypeChecker propagates OOF-A1 to `type_errors`; sets `status: "blocked"`
6. SemanticIR emits `assumption_registry` at top level and `assumption_refs` on `contract_ir`
7. All existing Stage 1–2–3 regression fixtures PASS without modification
8. Positive fixture: assumed contract with declared assumption → `status: "accepted"`,
   `assumption_refs: ["homophily"]` in semantic_ir
9. Negative fixture: `uses assumptions undeclared` → OOF-A1, `status: "blocked"`,
   SemanticIR `nil`
10. **§P28-AC-1 (gate-added, S3-R31-C5-P):** Parser rejects any `assumption` body without
    a name — a parse error is emitted and the program does not reach the Classifier.
    This closes the P28 enforcement status for the `assumptions {}` surface.
    Tested by: `oof_p28_unnamed_assumption_body` parse-error fixture.

---

## § 12. Minimum Proof Fixture Plan

See `docs/tracks/prop032-assumptions-block-draft-r30-v0.md §Fixture Plan` for the
Research Agent fixture specification. Summary:

**Fixture: `assumption_basic.ig`** (positive)

```igniter
assumptions {
  assumption homophily {
    kind      :heuristic
    statement "People with similar beliefs interact more often."
    strength  0.70
  }
}

observed contract ScoreInteraction {
  input a_id: String
  input b_id: String
  uses assumptions homophily
  escape interaction_read
  read a: Signal from "signals/{a_id}" lifecycle: :local
  read b: Signal from "signals/{b_id}" lifecycle: :local
  compute score = 0.70
  output score: Decimal[4] evidence [a, b, homophily]
}
```

Expected: `status: "accepted"`, `assumption_refs: ["homophily"]`, `fragment_class: "escape"`.

**Fixture: `oof_a1_undeclared_assumption.ig`** (negative)

```igniter
pure contract ScoreRisk {
  input value: Integer
  uses assumptions undeclared_heuristic
  compute result = value
  output result: Integer
}
```

Expected: OOF-A1 in `oof_log`, `fragment_class: "oof"`, `status: "blocked"`, SemanticIR `nil`.

The fixtures are hand-authored (parsed AST JSON) until parser implementation lands,
following the same pattern as `temporal_semanticir_access_node` and the
`observed_temporal_precedence` fixture added in S3-R30-C3-P.

---

## § 13. Open Questions

**OQ-1: Contract-level modifier for `assumptions {}`**

Should a contract that uses assumptions acquire a higher-level modifier (`assumed
contract`)? Or is `uses assumptions NAME` always a body-level declaration without
modifier promotion? The current PROP takes the body-level route for minimal scope.
If the compiler needs to express "this contract is epistemically bounded by its
declared assumptions" at the modifier level, a modifier extension is a future PROP.

**OQ-2: Assumption field completeness**

Are `kind`, `statement`, `strength`, `source` the right four fields, or is
`expires_at` (temporal validity) needed at PROP-032 time? Recommend deferring
`expires_at` — it implies assumption lifecycle management which is out of scope.

**OQ-3: Undeclared-name in evidence list** *(Resolved — S3-R31-C5-P, gate decision G-1)*

Evidence list names in `output` nodes are **not validated by PROP-032**. The Classifier
does not inspect the `evidence` field; it passes through unchanged. Full OOF suite for
evidence list validation is PROP-033 scope. OOF-A1 fires ONLY on `uses_assumptions`
body declarations. No evidence-list OOF code is introduced in PROP-032.

**OQ-4: `assumption_refs` in evidence OOF enforcement**

PROP-033 will introduce OOF codes for outputs that are missing expected evidence
citations. Should PROP-032 pre-position `assumption_refs` as a required evidence
participant for any output that uses an assumption? Recommend yes — flag it in
PROP-033's fixture plan, not PROP-032's.

**OQ-5: Multiple `assumptions {}` blocks per module**

The grammar currently allows at most one `assumptions {}` block. Should multiple
blocks (e.g. per domain) be allowed? Recommend deferring: a single block per module
is sufficient for the minimum fixture plan and avoids name-collision design questions.
