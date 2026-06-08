# PROP-014 Candidate: Source Syntax to SemanticIR Boundary v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `PROP-001`, `PROP-003`, `PROP-004`, `PROP-012`, `PROP-013`

---

## Purpose

The hand-authored `.igapp/` fixtures prove that `RuntimeMachine` can load,
evaluate, checkpoint, and resume without a real compiler. The next question
is: what is the **minimal source syntax boundary** that maps to `SemanticIR`
without over-committing to a full grammar?

This proposal:

1. Defines the minimal syntax for `Add`-like CORE contracts
2. Defines the minimal syntax for projection/window contracts
3. Defines the parser output shape (`ParsedProgram`)
4. Maps the classification path: source → ParsedProgram → ClassifiedProgram
   → TypedProgram → SemanticIR
5. Defines what must be rejected as OOF at each stage
6. Maps how `.igapp/` fixtures correspond to future source forms

[D] This proposal does **not** commit to a final grammar. It defines the
**minimal syntax kernel** sufficient to produce SemanticIR for the two
existing fixture contracts (Add, AvailabilityProjection). Full grammar
design is a separate track (PROP-015 candidate).

[D] SemanticIR remains the stable toolchain center. The parser is a
frontend pass that emits ParsedProgram; it does not own evaluation
semantics, lifecycle, or runtime contracts.

---

## Guiding Constraints

```text
C-1: Syntax must map directly to SemanticIR node types.
     No syntax that has no SemanticIR equivalent (yet).

C-2: Every construct must declare its observable properties
     at the source level: lifecycle, escape, effects, capabilities.
     No implicit defaults that hide semantic choices.

C-3: The source language must be human-writable.
     A developer writing a contract should not need to know
     the internal SemanticIR representation.

C-4: The source language must be agent-readable.
     An agent should be able to inspect a contract and determine:
     - what it computes
     - what facts it needs
     - what lifecycle its outputs carry
     - what effects it declares

C-5: OOF constructs must fail at Parse or Classify, not at runtime.
     The source language must have explicit OOF markers or the absence
     of required declarations (lifecycle, escape, effects) must trigger
     Pass 0 rejection.
```

---

## Part 1: Minimal Syntax for CORE Contracts (Add-like)

### Source form

```text
contract Add {
  input  a: Integer
  input  b: Integer

  compute sum = a + b

  output sum: Integer
}
```

### Semantic interpretation

```text
contract Add {
  -- declares a contract with fragment_class: core (no escape, no effects)
  -- lifecycle defaults to :session for compute nodes, :local for inputs

  input a: Integer
  -- declares input port: { name: "a", type_tag: "Integer", lifecycle: :local, required: true }

  input b: Integer
  -- declares input port: { name: "b", type_tag: "Integer", lifecycle: :local, required: true }

  compute sum = a + b
  -- declares compute node: { name: "sum", expression: apply(add, [ref(a), ref(b)]) }
  -- type_tag inferred: Integer (Integer + Integer = Integer)
  -- lifecycle inferred: :session (CORE compute default)
  -- obs_kind: value_observation

  output sum: Integer
  -- declares output port: { name: "sum", type_tag: "Integer", lifecycle: :session }
}
```

### ParsedProgram output (sketch)

```json
{
  "kind": "contract",
  "name": "Add",
  "inputs": [
    { "name": "a", "type_annotation": "Integer" },
    { "name": "b", "type_annotation": "Integer" }
  ],
  "body": [
    {
      "kind": "compute",
      "name": "sum",
      "expr": {
        "kind": "binary_op",
        "op": "+",
        "left":  { "kind": "ref", "name": "a" },
        "right": { "kind": "ref", "name": "b" }
      }
    }
  ],
  "outputs": [
    { "name": "sum", "type_annotation": "Integer" }
  ]
}
```

### Classification path

```text
Parse:
  "a + b" -> BinaryOp("+", Ref("a"), Ref("b"))
  No ambient IO detected -> CORE candidate

Classify (Pass 0):
  Ref("a") -> input port -> CORE
  Ref("b") -> input port -> CORE
  BinaryOp("+") -> stdlib.numeric.add -> CORE (Tier 1 axiom)
  Sum node -> CORE
  No escape_set, no effects, no FFI -> fragment_class: CORE

Type (Pass 1):
  a: Integer (from input annotation)
  b: Integer (from input annotation)
  sum: Integer (Integer + Integer inferred from stdlib.numeric.add signature)
  output sum: Integer (matches annotation)
  No type errors -> TypedProgram

SemanticIR:
  contract_id:    "add"
  name:           "Add"
  fragment_class: "core"
  input_ports:    [{ name: "a", type_tag: "Integer", lifecycle: "local" },
                   { name: "b", type_tag: "Integer", lifecycle: "local" }]
  compute_nodes:  [{ node_id: "node_sum", name: "sum",
                     expression: { kind: "apply", operator: "stdlib.numeric.add",
                                   operands: [ref(a), ref(b)] },
                     type_tag: "Integer", lifecycle: "session" }]
  output_ports:   [{ name: "sum", type_tag: "Integer", lifecycle: "session" }]
```

---

## Part 2: Minimal Syntax for Projection / Window Contracts

### Source form

```text
contract AvailabilityProjection {
  input technician_id: String
  input date: String

  escape stream_collection

  read geo_signals: Collection[GeoSignal]
    from "geo_signal/{technician_id}/{date}"
    lifecycle :window

  read schedule: ScheduleFact
    from "schedule/{technician_id}/{date}"
    lifecycle :durable

  compute available_slots =
    compute_slots(geo_signals, schedule)

  window "availability[technician, day]" {
    kind     :calendar
    unit     :day
    on_close :snapshot
  }

  snapshot snap = build_snapshot(available_slots, technician_id, date)
    lifecycle :durable

  output available_slots: Collection[TimeSlot]  lifecycle :window
  output snap: AvailabilitySnapshot             lifecycle :durable
}
```

### Semantic interpretation

```text
escape stream_collection
-- declares escape_set: ["stream_collection"]
-- escalates fragment_class from :core to :escape

read geo_signals: Collection[GeoSignal]
  from "geo_signal/{technician_id}/{date}"
  lifecycle :window
-- tbackend_read node: reads Collection[GeoSignal] at as_of
-- subject_template: "geo_signal/{technician_id}/{date}"
-- lifecycle: :window -> obs survives within window, compacted at boundary
-- fragment: :escape (reads from TBackend with stream_collection escape)

read schedule: ScheduleFact
  from "schedule/{technician_id}/{date}"
  lifecycle :durable
-- tbackend_read node: reads ScheduleFact at as_of
-- lifecycle: :durable -> obs persists across sessions
-- fragment: :core (no escape needed for durable fact read)

compute available_slots = compute_slots(geo_signals, schedule)
-- applies user-defined operator compute_slots
-- depends on: node_geo_signals, node_schedule
-- fragment: :core (pure compute over inputs)
-- lifecycle: :window (inherits from highest-lifecycle dependency)

window "availability[technician, day]" {
  kind :calendar; unit :day; on_close :snapshot
}
-- declares TemporalWindow with BoundaryDescriptor
-- on_close :snapshot -> emit window snapshot at boundary

snapshot snap = build_snapshot(available_slots, technician_id, date)
  lifecycle :durable
-- snapshot compute node
-- lifecycle: :durable -> persists after window close
-- materializes BoundaryReceipt evidence

output available_slots: Collection[TimeSlot] lifecycle :window
output snap: AvailabilitySnapshot            lifecycle :durable
```

### ParsedProgram output (sketch)

```json
{
  "kind": "contract",
  "name": "AvailabilityProjection",
  "escape_set": ["stream_collection"],
  "inputs": [
    { "name": "technician_id", "type_annotation": "String" },
    { "name": "date",          "type_annotation": "String" }
  ],
  "body": [
    { "kind": "read",    "name": "geo_signals", "type_annotation": "Collection[GeoSignal]",
      "from": "geo_signal/{technician_id}/{date}", "lifecycle": "window" },
    { "kind": "read",    "name": "schedule",    "type_annotation": "ScheduleFact",
      "from": "schedule/{technician_id}/{date}", "lifecycle": "durable" },
    { "kind": "compute", "name": "available_slots",
      "expr": { "kind": "call", "fn": "compute_slots",
                "args": [{ "kind": "ref", "name": "geo_signals" },
                         { "kind": "ref", "name": "schedule" }] } },
    { "kind": "window",  "name": "availability[technician, day]",
      "options": { "kind": "calendar", "unit": "day", "on_close": "snapshot" } },
    { "kind": "snapshot","name": "snap", "type_annotation": "AvailabilitySnapshot",
      "expr": { "kind": "call", "fn": "build_snapshot",
                "args": [{ "kind": "ref", "name": "available_slots" },
                         { "kind": "ref", "name": "technician_id" },
                         { "kind": "ref", "name": "date" }] },
      "lifecycle": "durable" }
  ],
  "outputs": [
    { "name": "available_slots", "type_annotation": "Collection[TimeSlot]", "lifecycle": "window" },
    { "name": "snap",            "type_annotation": "AvailabilitySnapshot",  "lifecycle": "durable" }
  ]
}
```

---

## Part 3: Parser Output Shape

```text
ParsedProgram = Record {
  source_ref      : SourceRef
  source_hash     : Hash                    -- SHA-256 of raw source bytes
  grammar_version : String
  ast             : Collection[TopLevelDecl]
  source_spans    : Map[NodeId, Span]
  parse_errors    : Collection[ParseError]  -- non-empty -> halt at Stage 0
}

TopLevelDecl =
  | ContractDecl(name, escape_set, inputs, body, outputs)
  | TypeDecl(name, fields)           -- record type declaration
  | ExternalDecl(name, ffi)          -- FFI declaration
  | WindowDecl(name, kind, options)  -- named window (global scope)

BodyDecl =
  | InputDecl(name, type_ann)
  | ReadDecl(name, type_ann, from, lifecycle)
  | ComputeDecl(name, expr)
  | SnapshotDecl(name, type_ann, expr, lifecycle)
  | WindowDecl(name, kind, options)      -- inline window

Expr =
  | Literal(value, type_ann)
  | Ref(name)
  | BinaryOp(op, left, right)
  | Call(fn, args)
  | Lambda(params, body)
  | FieldAccess(expr, field)
  | IfExpr(cond, then_branch, else_branch)

ParseError = Record {
  message : String
  span    : Span
  code    : String    -- e.g. "syntax.unexpected_token"
}
```

**[D]** `ParsedProgram` is the output of Stage 0 (parse) only. It contains
no type information, no fragment classification, no lifecycle inference.
Type annotations are strings, not resolved types.

---

## Part 4: Classification Path

### Stage 0 → Stage 1: ParsedProgram → ClassifiedProgram

```text
For each BodyDecl in ContractDecl.body:

  InputDecl   -> ClassifiedNode(kind: :input,   fragment: :core,   escape: nil)
  ReadDecl    -> if escape_set declared:
                   ClassifiedNode(kind: :read, fragment: :escape, escape: escape_name)
                 else:
                   ClassifiedNode(kind: :read, fragment: :core,   escape: nil)
  ComputeDecl -> walk expr:
                   all refs are CORE inputs/computes -> CORE
                   any ref is ESCAPE -> ESCAPE
                   any ambient IO detected -> OOF
  SnapshotDecl -> same rules as ComputeDecl; lifecycle must be declared

OOF detection at Pass 0:
  - Undeclared external call (no ExternalDecl) -> OOF
  - Ambient clock access (Time.now, Date.today) -> OOF (Law 6)
  - File/network IO without FFI declaration -> OOF
  - Self-referential compute node (cycle in deps) -> OOF (cycle = non-terminating)
  - Missing lifecycle on read/snapshot nodes -> OOF warning in strict mode
```

### Stage 1 → Stage 2: ClassifiedProgram → TypedProgram

```text
For each ClassifiedNode:

  Resolve type_annotation strings to TypeTag values.
  Infer types for compute nodes:
    - BinaryOp("+", Integer, Integer) -> Integer  (from stdlib.numeric.add)
    - Call("compute_slots", Collection[GeoSignal], ScheduleFact)
      -> Collection[TimeSlot]  (user-defined; requires TypeDecl for GeoSignal, TimeSlot)
  
  Lifecycle inference:
    - input -> :local (always)
    - read with declared lifecycle -> use declared
    - compute -> max(lifecycle of dependencies)
    - snapshot -> use declared; must be >= :durable
    - output -> use declared; must match compute node lifecycle

  Type errors -> halt (TypedProgram.type_errors non-empty)
```

### Stage 2 → Stage 3: TypedProgram → SemanticIR

```text
For each ContractDecl in ParsedProgram:
  Build ContractIR:
    - resolve input_ports from InputDecl + type inference
    - resolve compute_nodes from ComputeDecl/ReadDecl + expression lowering
    - resolve output_ports from OutputDecl + type inference
    - build DependencyGraph from expr refs
    - verify DAG (no cycles; cycle = compile error)

Expression lowering:
  BinaryOp("+", ...)     -> apply(stdlib.numeric.add, ...)
  Call("compute_slots")  -> apply(compute_slots, ...)  [user-defined: must be in scope]
  Call("fold", ...)      -> apply(stdlib.collection.fold, ...)
  ReadDecl(from, ...)    -> tbackend_read(subject_template, lifecycle)
  Ref(name)              -> ref(name)

Window declarations -> TemporalWindow, BoundaryDescriptor in SemanticIR
Snapshot nodes -> ProjectionDescriptor in SemanticIR
```

---

## Part 5: What Must Be Rejected as OOF

### At Parse (Stage 0)

```text
OOF-P1: Syntax that has no ParsedProgram equivalent.
         Example: class definitions, loops, exceptions, `begin/rescue`.
         The parser grammar must not accept these constructs.

OOF-P2: Missing required declarations for read nodes.
         `read x: T from "..."` without `lifecycle` annotation
         is a parse error in strict mode (warning in lenient mode).
```

### At Classify (Stage 1, Pass 0)

```text
OOF-C1: Ambient clock access.
  Law 6 (PROP-003): any expression that calls Time.now, DateTime.now,
  Date.today without TemporalCtx is OOF. Blocked.

OOF-C2: Undeclared external call.
  A Call(fn) where fn is not declared in:
    - stdlib (PROP-013 Tier 1)
    - contract inputs/computes
    - an ExternalDecl (FFI)
  -> OOF. Blocked.

OOF-C3: Dependency cycle.
  If the DependencyGraph contains a cycle, the cycle's nodes are OOF.
  The compile error names the cycle members.

OOF-C4: Missing escape declaration for stream reads.
  A ReadDecl with `lifecycle: :window` without a corresponding
  `escape stream_collection` declaration -> OOF.

OOF-C5: File/network IO in compute body.
  Any Call that resolves to OS-level IO (File.read, HTTP.get) without
  an ExternalDecl -> OOF.
```

### At Type (Stage 2, Pass 1)

```text
OOF-T1: Type mismatch.
  avg(Collection[String]) -> type error; avg requires Numeric.
  Blocked with type_error code.

OOF-T2: Lifecycle downgrade attempt.
  output declared with lifecycle :local when compute node is :durable.
  Blocked: output lifecycle must be >= compute node lifecycle.

OOF-T3: Missing type annotation for external types.
  A user-defined type (GeoSignal, ScheduleFact) without a TypeDecl.
  Blocked: cannot type-check compute nodes without type definitions.
```

---

## Part 6: How .igapp/ Fixtures Map to Future Source

The hand-authored `.igapp/` fixtures are **target SemanticIR** — they
represent exactly what a future compiler must produce from source.

```text
fixtures/add.igapp/
  contracts/add.json
    -- corresponds to the source:
    contract Add {
      input  a: Integer
      input  b: Integer
      compute sum = a + b
      output sum: Integer
    }

fixtures/availability_projection.igapp/
  contracts/availability_projection.json
    -- corresponds to the source:
    contract AvailabilityProjection {
      input technician_id: String
      input date: String
      escape stream_collection
      read geo_signals: Collection[GeoSignal]
        from "geo_signal/{technician_id}/{date}" lifecycle :window
      read schedule: ScheduleFact
        from "schedule/{technician_id}/{date}" lifecycle :durable
      compute available_slots = compute_slots(geo_signals, schedule)
      window "availability[technician, day]" { kind :calendar; unit :day; on_close :snapshot }
      snapshot snap = build_snapshot(available_slots, technician_id, date) lifecycle :durable
      output available_slots: Collection[TimeSlot] lifecycle :window
      output snap: AvailabilitySnapshot lifecycle :durable
    }
```

**[D]** The future compiler is correct when it produces, for the source above,
an artifact whose `artifact_hash` matches the hand-authored fixture's
`artifact_hash`. The fixtures are the **acceptance tests** for the future
compiler frontend.

**[D]** The `.igapp/` fixture format is the **specification** for compiler
output. The parser and classifier must produce exactly this shape.
If the fixture needs to change (because the spec evolves), both the fixture
and the source mapping must be updated together.

---

## Parser Technology Note

[R] The minimal parser can be implemented as a recursive-descent parser
over a grammar with these productions:

```text
Program       := TopDecl*
TopDecl       := ContractDecl | TypeDecl | ExternalDecl
ContractDecl  := "contract" Name "{" BodyDecl* "}"
BodyDecl      := InputDecl | ReadDecl | ComputeDecl | SnapshotDecl | WindowDecl | EscapeDecl
InputDecl     := "input" Name ":" TypeRef
ReadDecl      := "read" Name ":" TypeRef "from" String ("lifecycle" LifecycleClass)?
ComputeDecl   := "compute" Name "=" Expr
SnapshotDecl  := "snapshot" Name "=" Expr ("lifecycle" LifecycleClass)?
WindowDecl    := "window" String "{" WindowOpt* "}"
EscapeDecl    := "escape" Name
OutputDecl    := "output" Name ":" TypeRef ("lifecycle" LifecycleClass)?
TypeRef       := Name | "Collection[" TypeRef "]" | "Option[" TypeRef "]"
Expr          := ... (standard expression grammar with precedence)
LifecycleClass := ":local" | ":session" | ":window" | ":durable" | ":audit"
```

[R] The parser should be implemented in Ruby (to match the platform) or in
Igniter-Lang itself (Stage 1 of self-hosting ladder, PROP-012 §Self-Hosting).
The choice is not binding for v0 — the grammar above is the specification.

[R] The parser output (`ParsedProgram`) should be serialisable to JSON and
match the shape defined in Part 3. This enables incremental tooling: a
language server can consume `ParsedProgram`, an agent can inspect the AST,
and the classifier can run as a separate pass.

---

## Risks

[R-1] Grammar ambiguity. The minimal grammar above has potential ambiguity
in expression precedence (function call vs binary op). This must be resolved
with a formal precedence table before implementing the parser.

[R-2] User-defined functions. `compute_slots` and `build_snapshot` in the
`AvailabilityProjection` fixture are user-defined. The v0 grammar allows
`Call(fn)` but does not define `fn` in a `def` block. This must be resolved:
either user-defined functions are declared inline (lambda) or in a separate
`def` block.

[R-3] Type inference scope. The TypedProgram pass infers types from
annotations and stdlib signatures. User-defined types (GeoSignal, TimeSlot)
require `TypeDecl`. If a TypeDecl is missing, the compiler halts. This may
be frustrating for early users — a partial type-check mode (warnings, not
errors) may be useful.

---

## Rejected Paths

[X] Full grammar commitment in v0. The grammar above is minimal and
explicitly incomplete. A full grammar (generics, modules, import system,
pattern matching) is PROP-015+.

[X] Parser as the first thing to implement. The fixtures are the compiler
acceptance tests. The parser is correct when it produces artifacts that
match the fixtures. Write fixtures first, parser second.

[X] LLVM or native binary output in v0. Not relevant until SemanticIR is
stable and the parser-to-SemanticIR pipeline is validated.

[X] Inline type inference without annotations. The v0 grammar requires type
annotations on inputs and outputs. Inference is limited to compute nodes.
Full Hindley-Milner inference is PROP-015+.

[X] Exceptions or `try/catch`. Error handling in Igniter-Lang is via
`Result[T, E]` and `failure_observation`. No exception mechanism.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-014-source-syntax-semanticir-boundary-v0.md
Status: done

[D] Decisions:
- PROP-014 defines the minimal syntax kernel; not a full grammar.
- SemanticIR is the stable toolchain center. Parser is a frontend pass.
- .igapp/ fixtures are the compiler acceptance tests: the parser is correct
  when it produces artifacts matching the fixtures.
- OOF is caught at 3 stages: Parse (OOF-P1/P2), Classify (OOF-C1..C5),
  Type (OOF-T1..T3). No OOF survives to SemanticIR.
- Lifecycle must be declared on read/snapshot nodes. Inference is limited
  to compute nodes (max of dependencies).
- User-defined types require TypeDecl. Missing TypeDecl -> type error.
- The grammar is minimal: contract, input, read, compute, snapshot,
  window, escape, output. No loops, no exceptions, no classes.
- ParsedProgram is JSON-serialisable. Each pass is a separate stage.

[R] Recommendations:
- Implement parser as recursive-descent in Ruby or Igniter-Lang.
- ParsedProgram should be serialisable to JSON (enables agent inspection).
- Write a fixture-comparison acceptance test before writing the parser.
- Resolve user-defined function scope (inline lambda vs def block) before
  implementing the classifier.
- Add a formal precedence table before parser implementation.

[S] Signals:
- The two source forms defined here (Add, AvailabilityProjection) map
  exactly to the two existing .igapp/ fixtures. The pipeline is concrete,
  not speculative.
- The ParsedProgram JSON shape is compatible with the existing SemanticIR
  JSON format in the fixtures. A future parser could emit directly to
  contracts/add.json format with minimal transformation.
- OOF-C3 (cycle detection) is already implemented in the devkit RSpec
  tests (DAG acyclic check). The classifier can reuse this logic.

[Q] Open Questions:
- User-defined functions: inline lambda only, or separate def block?
- Grammar ambiguity: where exactly does call vs binary op conflict?
- Partial type-check mode: warnings vs errors for missing TypeDecls?
- Module/import system: required before first real programs? Or defer?

[X] Rejected:
- Full grammar commitment in v0.
- Parser before fixtures.
- LLVM output before SemanticIR stability.
- Inline type inference without annotations (v0).
- Exceptions / try-catch.

[Next] Proposed next slice:
- PROP-015 candidate: Grammar and Module System v0
  (define def blocks, TypeDecl syntax, module/import)
- Bridge track: ffi-ruby-contractable-proof-v0
  (prove Ruby host calls as ESCAPE contracts)
- Devkit: extend compiled_program.rb evaluator to handle
  stdlib.collection.fold as a named operator (closes PROP-013 gap)
```
