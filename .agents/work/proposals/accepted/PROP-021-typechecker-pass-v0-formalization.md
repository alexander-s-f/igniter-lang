# PROP-021: TypeChecker Pass v0 Formalization

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Status: proposal
Date: 2026-05-06
Track: igniter-lang/typechecker-pass-v0-formalization
Depends on: PROP-018, PROP-019.1, PROP-020 (Classifier Pass)

---

## Purpose

Define the narrow typecheck pass needed for Stage 1:
`ClassifiedProgram → TypedProgram`

This pass resolves declared type annotations, infers types for
unannotated compute nodes, resolves stdlib operator result types,
and enforces type-level OOF rules. It does NOT perform trait
resolution or monomorphization (see extension note §Part 7).

---

## Part 1: Input / Output Contract

```text
Input:  ClassifiedProgram (from PROP-020; pass_result: "ok" or "oof")
Output: TypedProgram

TypedProgram = {
  kind:            "typed_program",
  format_version:  "0.1.0",
  program_id:      String,          -- propagated
  grammar_version: String,
  source_hash:     String,
  module:          String | nil,
  type_env:        TypeEnv,
  contracts:       [TypedContract],
  diagnostics:     [Diagnostic],    -- classifier diagnostics + new type errors
  pass_result:     "ok" | "oof" | "skipped"
}
```

`pass_result: "skipped"` — emitted verbatim when `ClassifiedProgram.pass_result == "oof"`.
No type inference is attempted. `ClassifiedProgram.diagnostics` are forwarded unchanged.

---

## Part 2: TypeEnv, ShapeEnv, OperatorEnv

### TypeEnv

```text
TypeEnv = {
  primitives: {
    "Integer":         { kind: "primitive" },
    "Float":           { kind: "primitive" },
    "Bool":            { kind: "primitive" },
    "String":          { kind: "primitive" },
    "Nil":             { kind: "primitive" },
    "Symbol":          { kind: "primitive" },
    "Timestamp":       { kind: "primitive" },
    "Date":            { kind: "primitive" },
    "Duration":        { kind: "primitive" }
  },
  parameterized: {
    "Decimal":         { kind: "parameterized", params: ["scale:Integer"] },
    "Collection":      { kind: "parameterized", params: ["T"] },
    "Option":          { kind: "parameterized", params: ["T"] },
    "Result":          { kind: "parameterized", params: ["T","E"] }
  },
  domain_types: {
    "ConfidenceLabel": { kind: "enum",
                         values: ["high","medium","low","unverifiable","contested"] },
    "AlertSeverity":   { kind: "enum",
                         values: ["critical","high","medium","low","informational"] },
    "TrustClass":      { kind: "enum",
                         values: ["real","runtime","synthetic","forecast","counterfactual"] }
  },
  aliases: {}     -- populated from TypeDecl nodes in ParsedProgram
}
```

**[D] TypeEnv is built once per program.** It is not mutated per contract.

### ShapeEnv

```text
ShapeEnv = {
  <ContractName>: {
    <node_name>: TypeRef    -- resolved TypeRef for each body node
  }
}
```

Built during typecheck. Initially populated from declared `type_annotation` fields.
Inference fills in compute nodes whose annotation is nil.

### OperatorEnv

```text
OperatorEnv = {
  "stdlib.integer.add":    { params: ["Integer","Integer"],  result: "Integer" },
  "stdlib.integer.sub":    { params: ["Integer","Integer"],  result: "Integer" },
  "stdlib.integer.mul":    { params: ["Integer","Integer"],  result: "Integer" },
  "stdlib.integer.div":    { params: ["Integer","Integer"],  result: "Integer" },
  "stdlib.integer.eq":     { params: ["Integer","Integer"],  result: "Bool" },
  "stdlib.integer.lt":     { params: ["Integer","Integer"],  result: "Bool" },
  "stdlib.float.add":      { params: ["Float","Float"],      result: "Float" },
  "stdlib.float.mul":      { params: ["Float","Float"],      result: "Float" },
  "stdlib.decimal.add":    { params: ["Decimal[S]","Decimal[S]"], result: "Decimal[S]",
                             constraint: "scales_equal" },
  "stdlib.decimal.mul":    { params: ["Decimal[A]","Decimal[B]"], result: "Decimal[A+B]",
                             constraint: "none" },
  "stdlib.decimal.rescale":{ params: ["Decimal[A]","Integer","Symbol"],
                             result: "Decimal[target]",
                             constraint: "target_is_literal" },
  "stdlib.bool.and":       { params: ["Bool","Bool"],        result: "Bool" },
  "stdlib.bool.or":        { params: ["Bool","Bool"],        result: "Bool" },
  "stdlib.bool.not":       { params: ["Bool"],               result: "Bool" },
  "stdlib.string.concat":  { params: ["String","String"],    result: "String" },
  "stdlib.collection.map": { params: ["Collection[T]","(T)->U"], result: "Collection[U]" },
  "stdlib.collection.filter": { params: ["Collection[T]","(T)->Bool"],result:"Collection[T]"},
  "stdlib.collection.fold":   { params: ["Collection[T]","U","(U,T)->U"], result: "U" },
  "stdlib.collection.count":  { params: ["Collection[T]"],   result: "Integer" },
  "stdlib.option.or_else": { params: ["Option[T]","T"],      result: "T" }
}
```

**[D] OperatorEnv is the v0 stdlib surface.** Calls to names not in this table are OOF-P1 unless declared in a user `FunctionDecl`.

---

## Part 3: Annotation-Driven Type Resolution

```text
Resolution order per contract (in topological dep order):

1. Input nodes:    type = parse_type_annotation(node.type_annotation)
2. Const nodes:    type = infer_literal(node.expr)
3. Escape nodes:   type = Unknown  (no declared type; used only as boundary)
4. Read nodes:     type = parse_type_annotation(node.type_annotation)
5. Compute nodes:
   a. If type_annotation present: type = parse_type_annotation(node.type_annotation)
      -- still verify against inferred type; mismatch -> OOF-TC1
   b. If type_annotation nil:     type = infer_expr_type(node.expr)
6. Output nodes:   type = resolve_ref(node.name).type
                   verify == parse_type_annotation(output.type_annotation)
                   mismatch -> OOF-TC2
```

### parse_type_annotation

```text
Input: TypeRef (string like "Integer" or structured { kind, name, params })

String form:
  "Integer"           -> { name: "Integer", params: [] }
  "Collection[T]"     -> parsed by splitting on "[" (best-effort in v0)
  "Decimal[2]"        -> { name: "Decimal", params: [2] }  (structured from parser)
  "ConfidenceLabel"   -> { name: "ConfidenceLabel", params: [] }
  unknown name        -> { name: "Unknown", params: [] } + OOF-P1

Structured form (already parsed by Decimal branch in parser):
  { kind: "type_ref", name: "Decimal", params: [2] } -> { name: "Decimal", params: [2] }
```

### infer_expr_type

```text
LiteralNode:
  type: "int"    -> Integer
  type: "float"  -> Float
  type: "bool"   -> Bool
  type: "string" -> String
  type: "symbol" -> Symbol
  type: "nil"    -> Nil

RefNode:
  resolve_ref(name) -> look up ShapeEnv[contract][name]
  OOF-P1 if not found (already caught by classifier; defensive)

CallNode:
  look up OperatorEnv[fn]
  check arity: args.length == params.length, else OOF-TC3
  infer arg types recursively
  apply constraint (e.g. scales_equal for Decimal add)
  return result type (parameterized if needed)

RecordNode:
  type = { name: "Record", fields: { field_name: inferred_type } }
```

---

## Part 4: Record Field Access Typing

```text
FieldAccess node: { kind: "field_access", expr: ExprIR, field: String }

1. Infer type of expr.
2. If type.name == "Record":
     look up type.fields[field]
     found     -> return fields[field]
     not found -> OOF-TC4 (unknown field)
3. If type.name is a known stdlib type with fields (e.g. ObsPacket):
     look up field in domain type shape table
4. If type.name == "Unknown":
     return Unknown; OOF-P1 already recorded
5. Otherwise -> OOF-TC4 (field access on non-record type)
```

---

## Part 5: TypedProgram Node Shape

```json
{
  "kind":           "typed_contract",
  "contract_name":  "Add",
  "fragment_class": "core",
  "nodes": [
    {
      "kind":           "input",
      "name":           "a",
      "type":           { "name": "Integer", "params": [] },
      "fragment_class": "core"
    },
    {
      "kind":           "compute",
      "name":           "sum",
      "type":           { "name": "Integer", "params": [] },
      "expr": {
        "kind":          "call",
        "fn":            "stdlib.integer.add",
        "args":          [ {"kind":"ref","name":"a","resolved_type":{"name":"Integer","params":[]}},
                           {"kind":"ref","name":"b","resolved_type":{"name":"Integer","params":[]}} ],
        "resolved_type": { "name": "Integer", "params": [] }
      },
      "deps":           ["a", "b"],
      "fragment_class": "core"
    }
  ],
  "diagnostics": []
}
```

Key differences from `ClassifiedContract`:
- All `type` fields are resolved `{ name, params }` objects (not strings or nil).
- All `ExprIR.resolved_type` fields are resolved.
- `fn` names are monomorphic (no `stdlib.numeric.*`).

---

## Part 6: Type-Level OOF Rules

```text
OOF-TC1: Declared annotation conflicts with inferred type.
  compute node declares type_annotation: "Integer" but inferred type is "Bool".
  severity: error

OOF-TC2: Output type annotation conflicts with source node type.
  output declared "Decimal[2]" but resolved source is "Decimal[4]".
  severity: error

OOF-TC3: Operator arity mismatch.
  Call to stdlib.integer.add with 3 args (expects 2).
  severity: error

OOF-TC4: Field access on non-record or unknown field.
  severity: error

OOF-TC5: Decimal scale constraint violation.
  stdlib.decimal.add(Decimal[2], Decimal[4]) — scales_equal constraint fails.
  severity: error  (this is OOF-DM1 at type level)

OOF-CE4: ConfidenceLabel used as Bool.
  Compute node output type is Bool, but input is ConfidenceLabel.
  Enforced here with full type information (classifier catches annotation-only cases;
  typechecker catches inferred cases).
  severity: error

OOF-DM2: Float in Decimal position.
  Float literal or ref used where Decimal[N] is expected.
  severity: error
```

---

## Part 7: Conformance Cases (Typecheck Pass)

```text
TC-1: Add contract — pure Integer
  Input: ClassifiedProgram for add.ig
  Expected TypedProgram:
    all types resolved to Integer
    fn: "stdlib.integer.add"
    pass_result: "ok"

TC-2: Decimal contract — Decimal[2] / Decimal[4]
  Input: ClassifiedProgram for decimal_contract.ig
  Expected TypedProgram:
    base_bid type: { name: "Decimal", params: [2] }
    tax_rate type:  { name: "Decimal", params: [4] }
    gross_bid expr type: { name: "Decimal", params: [6] }  (2+4 from mul)
    pass_result: "ok"

TC-3: Decimal scale violation
  Input: compute result = stdlib.decimal.add(base_bid, tax_rate)
    where base_bid: Decimal[2], tax_rate: Decimal[4]
  Expected TypedProgram:
    diagnostics: [{ rule: "OOF-TC5", message: "Decimal scale mismatch: 2 vs 4" }]
    pass_result: "oof"

TC-4: ConfidenceLabel as Bool
  Input: ClassifiedProgram for negative_confidence_bool.ig
  Expected TypedProgram:
    diagnostics: [{ rule: "OOF-CE4" }]
    pass_result: "oof"

TC-5: Classifier OOF forwarded (skipped typecheck)
  Input: ClassifiedProgram with pass_result: "oof" (unresolved symbol)
  Expected TypedProgram:
    pass_result: "skipped"
    diagnostics: forwarded from ClassifiedProgram unchanged
```

---

## Part 8: Trait / Monomorphization Extension Note

**[D] Trait resolution and monomorphization are NOT in the v0 TypeChecker.** They are a separate pass (`MonomorphizationPass`) that runs between TypeChecker and Emitter when `grammar_version: "polymorphic-v0"` is detected.

```text
v0 typechecker handles:
  generic contract type params (T in contract Add[T]) -> deferred to MonomorphizationPass
  impl/trait resolution                               -> deferred to MonomorphizationPass
  contract_shape matching                             -> deferred to MonomorphizationPass

For grammar_version: "0.1.0", "decimal-v0", "spark-pipeline-v0":
  MonomorphizationPass is skipped; TypedProgram is ready for Emit.

For grammar_version: "polymorphic-v0":
  MonomorphizationPass is required before Emit.
  TypedProgram marks generic nodes with type: { name: "TypeParam", params: ["T"] }.
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/typechecker-pass-v0-formalization
Status: done

[D] Decisions:
- ClassifiedProgram -> TypedProgram. Skipped (pass_result: "skipped") if
  ClassifiedProgram.pass_result == "oof". Classifier diagnostics forwarded.
- Three environments: TypeEnv (global), ShapeEnv (per-contract), OperatorEnv (stdlib ops).
- Annotation-driven: declared type_annotation is ground truth.
  Inferred type must match declared; mismatch -> OOF-TC1.
- parse_type_annotation handles both opaque strings and structured Decimal TypeRef.
- OperatorEnv covers v0 stdlib surface. Unknown fn -> OOF-P1.
- Decimal mul result scale = A+B. Decimal add requires scales_equal (OOF-TC5).
- stdlib.numeric.add unresolved at this pass -> OOF-P1.
  Monomorphization pass handles polymorphic-v0 resolution separately.
- OOF-CE4: ConfidenceLabel as Bool enforced here with full inferred types
  (classifier catches annotation-only cases).
- 7 type-level OOF rules: OOF-TC1..5, OOF-CE4, OOF-DM2.
- 5 conformance cases: TC-1..TC-5.
- MonomorphizationPass is a separate pass; not in TypeChecker v0.

[Files] Changed:
- igniter-lang/docs/proposals/PROP-021-typechecker-pass-v0-formalization.md [NEW]
- igniter-lang/docs/README.md  [updated]
- igniter-lang/docs/agent-motion.md  [updated]

[Next]:
- [Research Agent]: implement TypeCheckerPass in
  igniter-lang/experiments/typechecker/ for TC-1..TC-5.
  Input: ClassifiedProgram JSON. Output: TypedProgram JSON.
  Existing negative_confidence_bool classified fixture maps to TC-4.
- Stage 1 path after this: Emitter (ClassifiedProgram+TypedProgram -> SemanticIRProgram)
  then Assembler (.igapp/) then RuntimeMachine.evaluate proof.
```
