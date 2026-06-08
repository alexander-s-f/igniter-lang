# PROP-018: Source-to-SemanticIR Minimal Pipeline v0

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Status: proposal
Date: 2026-05-06
Track: igniter-lang/source-to-semanticir-minimal-pipeline-v0
Depends on: PROP-014 (source/SemanticIR boundary), PROP-015 (grammar/module), PROP-004 (type system)

---

## Purpose

Define the minimal, executable compiler pipeline from `.ig` source to `SemanticIR`
sufficient to prove correctness of the language semantics formalized across all
v0 tracks. This is a conformance floor, not a feature ceiling.

---

## Part 1: Accepted v0 Source Subset

```text
v0 source := ModuleDecl? ImportDecl* TopDecl*

TopDecl  := ContractDecl | TypeDecl | FunctionDecl

ContractDecl :=
  "contract" Name TypeParams? "{" BodyDecl* "}"

TypeParams := "[" Name ("," Name)* "]"

BodyDecl :=
  | InputDecl
  | OutputDecl
  | ComputeDecl
  | ConstDecl
  | ReadDecl          -- with scoped_by/cardinality/schema_version/tenant_free
  | SnapshotDecl
  | EscapeDecl

InputDecl    := "input"    Name ":" TypeRef
OutputDecl   := "output"   Name ":" TypeRef LifecycleClause?
ComputeDecl  := "compute"  Name "=" Expr
ConstDecl    := "const"    Name "=" Literal
EscapeDecl   := "escape"   Name

TypeRef := Name | Name "[" (TypeRef | IntLit) ("," TypeRef)* "]"
         -- Decimal[N] emits structured { kind, name, params:[Integer] }
         -- All others emit opaque string

LifecycleClause := "lifecycle" ":" Symbol

Expr :=
  | Literal
  | Ref                  -- bare ident
  | CallExpr             -- Name "(" ArgList ")"
  | FieldAccess          -- Expr "." Name   (ESCAPE: unresolved -> OOF-P1)
  | RecordLiteral        -- "{" FieldInits "}"
  | IfExpr               -- not in v0 minimum; classifier rejects

Literal := StringLit | IntLit | FloatLit | BoolLit | NilLit | SymbolLit

-- OOF at parser level: pipeline/step inside contract body -> OOF-P2
-- pipeline is top-level only
```

**Excluded from v0 minimum** (parser accepts, classifier rejects):

```text
- IfExpr / branching inside compute          -- future: branch contract
- Generic type params on compute node        -- future: polymorphic-v0
- Inline trait/impl inside contract          -- top-level only
- Cross-session refs without explicit import -- OOF-P3
```

---

## Part 2: Parser Output AST Shape

```text
ParsedProgram = {
  kind:            "source_file"
  grammar_version: String         -- "0.1.0" | "decimal-v0" | "spark-pipeline-v0" | ...
  module:          String | nil
  imports:         [ImportNode]
  contracts:       [ContractNode]
  types:           [TypeNode]
  functions:       [FunctionNode]
  pipelines:       [PipelineNode]
  traits:          [TraitNode]
  impls:           [ImplNode]
  contract_shapes: [ContractShapeNode]
  parse_errors:    [{ message: String, line: Integer }]
}

ContractNode = {
  kind:       "contract"
  name:       String
  type_params: [String]
  body:        [BodyNode]
}

BodyNode kinds: "input" | "output" | "compute" | "const" | "read" |
                "snapshot" | "escape"

InputNode = { kind: "input", name: String, type_annotation: TypeRef }
OutputNode = { kind: "output", name: String, type_annotation: TypeRef,
               lifecycle: String | nil }
ComputeNode = { kind: "compute", name: String, expr: ExprNode }
ConstNode   = { kind: "const",   name: String, expr: LiteralNode }
EscapeNode  = { kind: "escape",  name: String }

ExprNode kinds: "literal" | "ref" | "call" | "record" | "field_access"
LiteralNode = { kind: "literal", value: Any, type: "string"|"int"|"float"|"bool"|"nil"|"symbol" }
CallNode    = { kind: "call", fn: String, args: [ExprNode] }
RefNode     = { kind: "ref", name: String }
```

---

## Part 3: Classifier Gates (Pass 0 and Pass 1)

### Pass 0 — Fragment class assignment

```text
For each BodyNode, assign: :core | :escape | :oof

:core    rules:
  - InputDecl, OutputDecl, ConstDecl: always :core
  - ComputeDecl: :core if all referenced names are :core-resolved
  - ReadDecl: :core if lifecycle is :durable | :window AND no live stream
  - EscapeDecl: always declares an escape boundary (not :core by itself)

:escape  rules:
  - ReadDecl with lifecycle :live -> :escape
  - ComputeDecl whose expr contains a :live read ref -> :escape
  - Any node referencing an EscapeDecl name -> :escape boundary

:oof     (immediate rejection):
  OOF-P1: Unresolved symbol ref (name not declared in body or imports).
  OOF-P2: pipeline/step inside contract body.
  OOF-P3: Cross-module ref without import.
  OOF-P4: Cycle in compute dependency graph.
  OOF-DM1: Decimal scale mismatch (add/sub/compare different scales).
  OOF-DM2: Float used as Decimal proxy.
  OOF-CE1: Claim with empty source_obs.
  OOF-CE4: ConfidenceLabel used as Bool.
  OOF-OS2: EvidenceLinkedAlert with empty signal_refs or claim_refs.
```

### Pass 1 — Type inference and evidence gates

```text
Type inference rules (subset):
  - InputDecl annotation -> declared type (opaque or structured Decimal TypeRef)
  - ConstDecl literal -> infer: String | Integer | Float | Bool | Nil | Symbol
  - CallExpr fn lookup:
      stdlib.*    -> consult stdlib signature table
      user def    -> lookup FunctionDecl signature
      unknown     -> OOF-P1 (unresolved)
  - Decimal[S] + Decimal[S] -> Decimal[S]       (scale match required; OOF-DM1)
  - Decimal[A] * Decimal[B] -> Decimal[A+B]
  - ConfidenceLabel -> NOT Bool (OOF-CE4 if used in boolean position)
  - Float in Decimal position -> OOF-DM2

Evidence gates (Pass 1):
  - EvidenceLinkedAlert must have signal_refs.length >= 1 (OOF-OS2)
  - EvidenceLinkedAlert must have claim_refs.length >= 1 (OOF-OS2)
  - EvidenceLinkedAlert must have valid_until (OOF-OS4)
  - ConfidenceAssessment must have evidence_refs.length >= 1 (OOF-CE5)
  - RetentionExecutionReceipt must reference dry_run_ref (OOF-RT1)
  - AcceptanceReceipt must have review_projection_ref (OOF-MD5)
  - AcceptanceReceipt at :staging/:production must have runtime_verification_ref (OOF-MD3)
```

---

## Part 4: SemanticIR Emission Shape

```text
SemanticIR := {
  contract_ref:  ArtifactRef   -- content hash of source + grammar_version
  contract_name: String
  fragment_class: :core | :escape | :mixed
  inputs:  [InputIR]
  outputs: [OutputIR]
  nodes:   [NodeIR]            -- topological order (dependency graph resolved)
  escape_boundaries: [EscapeBoundaryIR]
  oof_log: [OofEntry]          -- any Pass 0/1 rejections
}

InputIR  = { name: String, type: TypeIR }
OutputIR = { name: String, type: TypeIR, lifecycle: Symbol }
TypeIR   = { name: String, params: [Any] }   -- structured for Decimal; name-only otherwise

NodeIR = one of:
  ConstIR    = { kind: :const,   name: String, value: LiteralIR, type: TypeIR }
  ComputeIR  = { kind: :compute, name: String, expr: ExprIR, type: TypeIR,
                  deps: [String], fragment: :core | :escape }
  ReadIR     = { kind: :read,    name: String, from: String, type: TypeIR,
                  lifecycle: Symbol, scoped_by: String | nil,
                  cardinality: { min: Int, max: Int } | nil,
                  schema_version: String | nil, tenant_free: Bool }
  SnapshotIR = { kind: :snapshot, name: String, expr: ExprIR, lifecycle: Symbol }
  EscapeIR   = { kind: :escape,  name: String }

ExprIR = one of:
  LiteralIR  = { kind: :literal, value: Any, type: TypeIR }
  RefIR      = { kind: :ref,     name: String, resolved_type: TypeIR }
  CallIR     = { kind: :call,    fn: String, args: [ExprIR], resolved_type: TypeIR }
  RecordIR   = { kind: :record,  fields: { String => ExprIR }, type: TypeIR }

EscapeBoundaryIR = { name: String, kind: Symbol, declared_at: String }

OofEntry = { rule: String, message: String, node: String | nil, line: Int | nil }
```

### AST → SemanticIR Mapping

```text
ParsedProgram.contracts[i] -> SemanticIR

1. Resolve import graph -> build symbol table
2. Pass 0: fragment class + OOF-P1/2/3/4 detection
3. Pass 1: type inference + evidence gate checks
4. Topological sort of compute nodes by dependency
5. Emit nodes in resolution order
6. Assign contract_ref = sha256(source_path + grammar_version + source_hash)
```

---

## Part 5: Minimal Conformance Cases

### C-1: Pure CORE contract

```text
Source: add.ig (existing fixture)
Expected SemanticIR:
  fragment_class: :core
  nodes: [ComputeIR(add, expr: CallIR(add_integers, ...))]
  oof_log: []
```

### C-2: Decimal type annotation

```text
Source: decimal_contract.ig (existing fixture)
Expected SemanticIR:
  inputs:  [InputIR(base_bid, Decimal[2]), InputIR(tax_rate, Decimal[4])]
  outputs: [OutputIR(gross_bid, Decimal[2])]
  nodes:   [ComputeIR(gross_bid, CallIR(mul, ...), Decimal[6])]
  oof_log: []
```

### C-3: Scoped read contract

```text
Source: tenant_availability_projection.ig (existing fixture)
Expected SemanticIR:
  reads: [ReadIR(technician, scoped_by: company_scope, cardinality: {1,1}, ...)]
  fragment_class: :escape  (TBackend reads are ESCAPE)
  oof_log: []
```

### C-4: OOF — unresolved symbol

```text
Source: contract with compute = unknown_fn(x)
Expected SemanticIR:
  oof_log: [{ rule: "OOF-P1", message: "Unresolved symbol: unknown_fn", ... }]
```

### C-5: OOF — Decimal scale mismatch

```text
Source: compute result = add(Decimal[2] input, Decimal[4] input2)
Expected SemanticIR:
  oof_log: [{ rule: "OOF-DM1", message: "Decimal scale mismatch: 2 vs 4", ... }]
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/source-to-semanticir-minimal-pipeline-v0
Status: done

[D] Decisions:
- v0 minimum: contract/input/output/compute/const/read/snapshot/escape.
  Branching (if/else), generics in compute, and inline trait/impl excluded.
- Parser output shape extended: all existing ParsedProgram fields used.
  SemanticIR adds fragment_class, resolved types, deps, oof_log.
- Two classifier passes: Pass 0 (fragment class + structural OOF), Pass 1 (types + evidence).
- OOF rules unified: OOF-P1..4 (pipeline), OOF-DM1/2 (Decimal), OOF-CE1/4/5 (Claim),
  OOF-OS2/4 (OSINT), OOF-RT1/MD3/MD5 (receipts/acceptance).
- ArtifactRef = sha256(source_path + grammar_version + source_hash).
- Five conformance cases: C-1 (CORE add), C-2 (Decimal), C-3 (scoped read),
  C-4 (OOF-P1), C-5 (OOF-DM1).
- Existing parser fixtures (add.ig, decimal_contract.ig, tenant_availability_projection.ig)
  are the primary C-1/C-2/C-3 conformance targets.

[Files] Changed:
- igniter-lang/docs/proposals/PROP-018-source-to-semanticir-minimal-pipeline-v0.md [NEW]
- igniter-lang/docs/README.md  [updated]
- igniter-lang/docs/agent-motion.md  [updated]

[Next]:
- [Research Agent]: implement the SemanticIR emitter experiment in
  igniter-lang/experiments/semanticir/ for conformance cases C-1..C-5.
  Use ParsedProgram JSON from existing fixtures as input.
  Emit SemanticIR JSON matching the shapes in §Part 4.
- [Compiler/Grammar Expert]: decimal-classifier-v0
  Implement Pass 1 Decimal scale inference rules as a classifier proof.
```
