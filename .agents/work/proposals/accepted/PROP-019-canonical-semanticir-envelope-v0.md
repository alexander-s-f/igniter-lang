# PROP-019: Canonical SemanticIR Envelope v0

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Status: proposal
Date: 2026-05-06
Track: igniter-lang/canonical-semanticir-envelope-v0
Supersedes: PROP-018 §Part 4 (partial shape), source_to_semanticir_fixture divergent shapes
Depends on: PROP-014, PROP-015, PROP-018

---

## Problem

Two SemanticIR shapes exist in the workspace and they conflict:

```text
source_to_semanticir_fixture/golden/add.semantic_ir.json:
  kind: "semantic_ir_fixture_program"
  contracts[].inputs[]         -- "inputs" / "outputs" / "nodes"
  contracts[].kind = "contract_ir"

polymorphic_add.semantic_ir.expected.json:
  kind: "semantic_ir"
  contracts[].input_ports[]    -- "input_ports" / "compute_nodes"
  contracts[].contract_id      -- not "contract_ref"
```

Neither is canonical. Both must be migrated. This proposal freezes the v0 shape.

---

## Part 1: Canonical Top-Level Envelope

**[D] `kind: "semantic_ir_program"` is the canonical kind for v0.** Both existing shapes are deprecated.

```json
{
  "kind":            "semantic_ir_program",
  "format_version":  "0.1.0",
  "program_id":      "<stable-id>",
  "grammar_version": "<detected>",
  "source_hash":     "sha256:<hex>",
  "source_path":     "<relative-path>",
  "module":          "<ModulePath | null>",
  "contracts":       [ <ContractIR> ],
  "oof_log":         [ <OofEntry> ]
}
```

### Field definitions

```text
format_version:  Semver string for the envelope schema itself.
                 "0.1.0" for this proposal. Bumped when envelope shape changes.

program_id:      "semanticir/<source_hash_prefix_16>"
                 Stable across recompiles of identical source.
                 Changes only when source content changes.

grammar_version: Propagated from ParsedProgram.grammar_version.
                 One of: "0.1.0" | "decimal-v0" | "spark-pipeline-v0" |
                         "polymorphic-v0".

source_hash:     "sha256:<hex>" of the source file bytes.
                 Canonical: lowercase hex, no prefix variation.

source_path:     Relative path from igniter-lang/ root.
                 Never absolute. Never includes machine-specific prefix.

module:          Module path string or null.

contracts:       Ordered array of ContractIR. Order = source declaration order.

oof_log:         Union of all contract-level oof_log entries, de-duplicated,
                 for program-level rejection summary. Empty array if no OOF.
```

---

## Part 2: Canonical ContractIR Shape

```json
{
  "kind":              "contract_ir",
  "contract_ref":      "contract/<Name>/sha256:<prefix24>",
  "contract_name":     "<Name>",
  "specialization_of": "<GenericName | null>",
  "type_args":         { "<param>": "<type>" },
  "fragment_class":    "core | escape | mixed | oof",
  "inputs":            [ <PortIR> ],
  "outputs":           [ <PortIR> ],
  "nodes":             [ <NodeIR> ],
  "escape_boundaries": [ <EscapeBoundaryIR> ],
  "oof_log":           [ <OofEntry> ]
}
```

### Naming reconciliation

```text
OLD (source_to_semanticir_fixture)  | OLD (polymorphic_add)  | CANONICAL
------------------------------------|------------------------|--------------------
"inputs"                            | "input_ports"          | "inputs"
"outputs"                           | (output_ports)         | "outputs"
"nodes"                             | "compute_nodes"        | "nodes"
"contract_ref"                      | "contract_id"          | "contract_ref"
"kind": "contract_ir"               | (no kind field)        | "kind": "contract_ir"
(no specialization_of)              | "specialization_of"    | "specialization_of": null
(no type_args)                      | "type_args"            | "type_args": {}
```

**[D] `inputs` / `outputs` / `nodes` are the canonical array names.** `input_ports` and `compute_nodes` are deprecated.

---

## Part 3: Canonical Sub-Shapes

### PortIR

```json
{ "name": "a", "type": { "name": "Integer", "params": [] }, "lifecycle": "session" }
```

`lifecycle` is present on outputs (may be null on inputs). Type is always `{ name, params }`.

### NodeIR (compute)

```json
{
  "kind":     "compute",
  "name":     "sum",
  "expr":     <ExprIR>,
  "type":     { "name": "Integer", "params": [] },
  "deps":     ["a", "b"],
  "fragment": "core"
}
```

**[D] `deps` is an ordered array of name strings in dependency order, not a map.**
**[D] `fragment` on a node is `"core" | "escape" | "oof"`.** Never mixed (mixed is only at contract level).

### ExprIR

```json
{ "kind": "call",    "fn": "stdlib.integer.add", "args": [...], "resolved_type": {...} }
{ "kind": "ref",     "name": "a",                               "resolved_type": {...} }
{ "kind": "literal", "value": 42, "type": "int",               "resolved_type": {...} }
{ "kind": "record",  "fields": { "x": <ExprIR> },              "resolved_type": {...} }
```

**[D] `resolved_type` is required on every ExprIR node.** If unresolved: `{ "name": "Unknown", "params": [] }` + OOF-P1 in `oof_log`.

### EscapeBoundaryIR

```json
{ "name": "backend_read", "kind": "tbackend_read", "declared_at": "read technician" }
```

### OofEntry

```json
{ "rule": "OOF-P1", "message": "Unresolved symbol: missing_b", "node": "sum", "line": null }
```

`line` is an integer or null. `node` is the body node name or null (program-level).

---

## Part 4: Hashing and Content Addressing

```text
source_hash:
  sha256(file_bytes)
  Format: "sha256:<64-hex-lowercase>"

program_id:
  "semanticir/" + source_hash[7..22]   -- 16 hex chars from sha256 body
  Stable: same source -> same program_id across all runs.

contract_ref:
  "contract/" + contract_name + "/sha256:" + sha256(canonical_contract_body)[0..23]
  canonical_contract_body = JSON.generate(contract_ir_without_oof_log, sorted_keys: true)
  -- Excludes oof_log from hash input so an OOF annotation doesn't change the ref.

shape_ref:  (fixture-only; not present in canonical output)
  "shape/" + sha256(inputs_array + outputs_array)[0..15]
  Used by Research fixtures for shape-level comparison without full node graph.

artifact_ref: (package bridge)
  "artifact/" + program_id + "/" + format_version
  Used by RuntimeMachine to identify a loaded artifact.
```

**[D] `shape_ref` and `artifact_ref` are NOT part of the canonical ContractIR.** They are computed by consumers. Fixtures may include them as fixture-only fields under `"_fixture"` key.

---

## Part 5: JSON Ordering and Canonical Form

```text
Canonical JSON ordering (for hash stability):
  Top-level keys: kind, format_version, program_id, grammar_version,
                  source_hash, source_path, module, contracts, oof_log
  ContractIR keys: kind, contract_ref, contract_name, specialization_of,
                   type_args, fragment_class, inputs, outputs, nodes,
                   escape_boundaries, oof_log
  NodeIR keys: kind, name, expr, type, deps, fragment
  ExprIR keys: kind, then type-specific keys, resolved_type last

Rule: all keys alphabetical within each object EXCEPT the ordering lists above,
which take precedence. Consumers must not depend on key order for parsing.
```

---

## Part 6: Fixture-Only Fields

```text
Fixture-only fields are permitted under a "_fixture" sibling key at any level.
They are NOT present in canonical pipeline output.

Example:
{
  "kind": "semantic_ir_program",
  ...
  "_fixture": {
    "case_id": "C-1",
    "description": "pure CORE integer add",
    "shape_ref": "shape/abc123",
    "expected_fragment_class": "core"
  }
}
```

**[D] The `"_fixture"` key is the only permitted extension point.** Canonical parsers must ignore it. Fixture validators must read it.

---

## Part 7: Migration Notes for Existing Fixtures

```text
source_to_semanticir_fixture/golden/*.semantic_ir.json:
  kind:        "semantic_ir_fixture_program" -> "semantic_ir_program"
  format_version: ADD "0.1.0"
  contracts[].kind: already "contract_ir" ✓
  contracts[].inputs: already "inputs" ✓
  contracts[].outputs: already "outputs" ✓
  contracts[].nodes: already "nodes" ✓
  Move fixture metadata -> "_fixture" key
  Add specialization_of: null, type_args: {}

polymorphic_add.semantic_ir.expected.json:
  kind:        "semantic_ir" -> "semantic_ir_program"
  format_version: ADD "0.1.0"
  contracts[].contract_id -> contract_ref
  contracts[].input_ports -> inputs
  contracts[].compute_nodes -> nodes
  contracts[].node_id field on nodes -> remove (use "name" only)
  contracts[].expression -> expr
  contracts[].type_tag -> type (as { name, params })
  Move axiom_version -> "_fixture"."axiom_version"
```

---

## Part 8: Bridge Acceptance Criteria

```text
Package bridge consumers must:
  1. Accept kind: "semantic_ir_program" and reject deprecated kinds.
  2. Read artifact_ref as "artifact/" + program_id + "/" + format_version.
  3. Treat "_fixture" key as opaque metadata; do not depend on its contents.
  4. Validate source_hash format: must match /^sha256:[0-9a-f]{64}$/.
  5. Reject contracts where fragment_class: "oof" unless in diagnostic-only mode.
  6. Preserve oof_log entries when forwarding to diagnostics adapters.
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/canonical-semanticir-envelope-v0
Status: done

[D] Decisions:
- kind: "semantic_ir_program" is the canonical top-level kind.
- format_version: "0.1.0" added to envelope for schema evolution.
- Canonical array names: inputs / outputs / nodes (not input_ports / compute_nodes).
- contract_ref (not contract_id).
- resolved_type required on every ExprIR node; Unknown if unresolved.
- deps is an ordered name array (not a map).
- shape_ref and artifact_ref are computed by consumers; not in canonical output.
- "_fixture" key is the only extension point for fixture metadata.
- JSON key ordering: canonical order defined; hash stability requires sorted_keys on contract_body hash input.
- program_id = "semanticir/" + source_hash[7..22].

[Files] Changed:
- igniter-lang/docs/proposals/PROP-019-canonical-semanticir-envelope-v0.md [NEW]
- igniter-lang/docs/README.md  [updated]
- igniter-lang/docs/agent-motion.md  [updated]

[R] Recommendations:
- Research Agent: migrate existing golden fixtures per §Part 7 before adding new ones.
  Do not create new golden fixtures using the deprecated shapes.
- Bridge Agent: adopt artifact_ref format from §Part 4 for RuntimeMachine loading.

[Next]:
- [Research Agent]: migrate golden fixture files per §Part 7.
- [Research Agent]: add Decimal C-2 and scoped-read C-3 golden fixtures
  using the canonical envelope (§Part 4 of PROP-018 + this spec).
- [Compiler/Grammar Expert]: semanticir-emitter-v0
  Implement the emitter experiment that reads ParsedProgram JSON
  and emits canonical semantic_ir_program JSON for conformance cases C-1..C-5.
```
