# PROP-022: .igapp Assembler Contract and RuntimeMachine Load Gate v0

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Status: proposal
Date: 2026-05-06
Track: igniter-lang/stage1-assembler-contract-formalization-v0
Depends on: PROP-019.1 (canonical envelope), PROP-020 (classifier), PROP-021 (typechecker)

---

## Purpose

Formalize what the `.igapp/` assembler must guarantee and define the
RuntimeMachine load trust gate. This is the final Stage 1 acceptance
barrier before `evaluate` can be called on a source-derived artifact.

---

## Part 1: .igapp Directory Contract

```text
.igapp/
  manifest.json            -- REQUIRED
  compilation_report.json  -- REQUIRED
  contracts/               -- REQUIRED; one file per contract
    <ContractName>.json
  stdlib/                  -- OPTIONAL in v0; reserved for operator descriptors
```

### manifest.json

```json
{
  "kind":            "igapp_manifest",
  "format_version":  "0.1.0",
  "program_id":      "semanticir/<prefix16>",
  "grammar_version": "0.1.0 | decimal-v0 | spark-pipeline-v0 | polymorphic-v0",
  "source_hash":     "sha256:<hex>",
  "source_path":     "<relative>",
  "module":          "<ModulePath | null>",
  "contracts":       ["<ContractName>", ...],
  "assembled_at":    "<ISO8601>",
  "assembler_version": "0.1.0"
}
```

**[D] `contracts` array lists names only.** The assembler writes one `contracts/<Name>.json` per entry. Order matches SemanticIRProgram.contracts declaration order.

### contracts/\<Name\>.json

Each file is a `ContractIR` object exactly as defined in PROP-019.1:

```json
{
  "kind":              "contract_ir",
  "contract_ref":      "contract/<Name>/sha256:<prefix24>",
  "contract_name":     "<Name>",
  "specialization_of": null,
  "type_args":         {},
  "fragment_class":    "core | escape | mixed",
  "inputs":            [ <PortIR> ],
  "outputs":           [ <PortIR> ],
  "nodes":             [ <NodeIR> ],
  "escape_boundaries": [ <EscapeBoundaryIR> ]
}
```

**[D] `fragment_class: "oof"` is forbidden in any `contracts/<Name>.json`.** If the emitter would write an OOF contract, the assembler must refuse (refusal rule R-4).

### compilation_report.json

Copied verbatim from the CompilationReport emitted by the pipeline:

```json
{
  "kind":               "compilation_report",
  "format_version":     "0.1.0",
  "program_id":         "...",
  "pass_result":        "ok",
  "stages":             { "parse":"ok","classify":"ok","typecheck":"ok","emit":"ok" },
  "diagnostics":        [],
  "semantic_ir_ref":    "semanticir/<prefix16>"
}
```

---

## Part 2: Assembler Refusal Rules

The assembler must refuse (exit non-zero, write no `.igapp/`) if:

```text
R-1: CompilationReport.pass_result != "ok"
     Reason: classifier, typechecker, or emitter produced OOF/error.

R-2: CompilationReport.semantic_ir_ref is null
     Reason: no SemanticIRProgram was emitted; nothing to assemble.

R-3: SemanticIRProgram.contracts contains any contract with
     fragment_class: "oof"
     Reason: defensive check; should not occur after R-1/R-2.

R-4: CompilationReport.diagnostics contains any entry with severity: "error"
     Reason: errors must not produce a loadable artifact.

R-5: Any stdlib call in a node's expr.fn that is not in the canonical
     OperatorEnv (PROP-021 §Part 2) AND not declared as a FunctionDecl.
     Includes: "stdlib.numeric.add" (unresolved overload — OOF-P1).
     Reason: unresolved operator would silently fail at evaluate time.

R-6: manifest.contracts array is empty
     Reason: an empty .igapp is not a valid program artifact.
```

**[D] The assembler writes a `refusal_report.json` alongside any failed attempt:**

```json
{
  "kind":     "assembler_refusal",
  "rule":     "R-1",
  "reason":   "pass_result is 'oof', not 'ok'",
  "program_id": "...",
  "source_hash": "..."
}
```

---

## Part 3: RuntimeMachine Load Trust Gate

When `RuntimeMachine.load(igapp_path)` is called:

```text
Load gate sequence:

L-1: Read manifest.json
     Validate kind: "igapp_manifest", format_version: "0.1.0"
     Missing/invalid -> structured refusal (not exception)

L-2: Read compilation_report.json
     Validate pass_result: "ok"
     Any other value -> LoadRefusal { reason: "compilation not ok" }

L-3: For each name in manifest.contracts:
     Read contracts/<Name>.json
     Validate kind: "contract_ir"
     Validate fragment_class != "oof"
     Any failure -> LoadRefusal { reason: "invalid contract: <Name>" }

L-4: Register loaded contracts in RuntimeMachine program registry.
     Emit:
       SemanticImage (trusted, from manifest + contracts)
       CompatibilityReport (trusted — source-derived artifact)

L-5: Return LoadResult { status: :loaded, program_id, contract_names }
```

### LoadRefusal shape

```json
{
  "kind":       "load_refusal",
  "reason":     "<message>",
  "program_id": "<id | null>",
  "gate":       "L-1 | L-2 | L-3"
}
```

**[D] `CompatibilityReport` is `trusted` for a source-derived, assembler-validated `.igapp/`.** This is the Stage 1 definition of "trusted": the artifact passed all compiler gates (classifier, typechecker, emitter) and the assembler validated it before writing.

**[D] A hand-authored `.igapp/` that bypasses the assembler is `provisional`, not `trusted`.** The RuntimeMachine checks for `compilation_report.json` presence and `pass_result: "ok"` to determine this.

---

## Part 4: Stdlib Operator Requirements at Assemble Time

```text
v0 required operators (must be resolvable at assemble time):
  stdlib.integer.add / sub / mul / div / eq / lt / lte / gt / gte
  stdlib.float.add / mul
  stdlib.decimal.add / sub / mul / rescale
  stdlib.bool.and / or / not
  stdlib.string.concat
  stdlib.collection.map / filter / fold / count
  stdlib.option.or_else

Resolution check:
  For each NodeIR.expr (recursively):
    if kind == "call" and fn starts with "stdlib.":
      fn must be in OperatorEnv (PROP-021 §Part 2)
      else -> R-5 (assembler refusal)
```

---

## Part 5: Acceptance Checklist for igapp-assembler-proof-stage1-v0

The Research Agent proof is accepted when all items pass:

```text
☐ A-1: Assembler reads CompilationReport. Refuses (R-1) if pass_result != "ok".
☐ A-2: Assembler reads SemanticIRProgram via semantic_ir_ref. Refuses (R-2) if null.
☐ A-3: Assembler writes .igapp/manifest.json with correct program_id, contracts list.
☐ A-4: Assembler writes .igapp/compilation_report.json copied verbatim.
☐ A-5: Assembler writes .igapp/contracts/<Name>.json for each contract.
        No OOF contract written (R-3 checked).
☐ A-6: RuntimeMachine.load(.igapp/) passes gates L-1..L-4 without exception.
☐ A-7: RuntimeMachine emits CompatibilityReport with status: :trusted.
☐ A-8: Negative — assembler given OOF CompilationReport refuses and writes refusal_report.json.
☐ A-9: Negative — assembler given stdlib.numeric.add in node expr refuses (R-5).
☐ A-10: RuntimeMachine.load given hand-authored .igapp/ (no compilation_report.json)
         emits CompatibilityReport with status: :provisional, not :trusted.
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/stage1-assembler-contract-formalization-v0
Status: done

[D] Decisions:
- .igapp/ requires: manifest.json, compilation_report.json, contracts/<Name>.json.
  stdlib/ directory reserved; empty in v0.
- 6 assembler refusal rules: R-1..R-6.
  R-5 catches unresolved stdlib.numeric.add and any non-canonical op name.
- Assembler writes refusal_report.json on any refusal; does not write .igapp/.
- RuntimeMachine load gate: L-1..L-5. LoadRefusal shape defined.
- Source-derived + assembler-validated -> CompatibilityReport trusted.
  Hand-authored (no compilation_report.json or pass_result != "ok") -> provisional.
- 10-item acceptance checklist: A-1..A-10.

[Files] Changed:
- igniter-lang/docs/proposals/PROP-022-igapp-assembler-contract-v0.md [NEW]
- igniter-lang/docs/README.md  [NOT updated — README crystallized by Meta Expert]
- igniter-lang/docs/agent-motion.md  [updated]

[Next]:
- [Research Agent]: Slice 0 — migrate golden files to PROP-019.1 shape.
- [Research Agent]: Slice A — igapp_assembler_proof.rb per A-1..A-10.
  Input: existing add.ig golden SemanticIRProgram JSON (post-migration).
  Output: .igapp/ directory + RuntimeMachine.load trust check.
```
