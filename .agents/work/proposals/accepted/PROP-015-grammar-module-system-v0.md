# PROP-015: Grammar and Module System v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `PROP-013`, `PROP-014`

---

## Purpose

PROP-014 defined the minimal syntax kernel for two contracts. It left open
three gaps:

1. **`def` blocks** — user-defined pure functions (`compute_slots`, `build_snapshot`)
2. **`TypeDecl`** — user-defined record types (`GeoSignal`, `TimeSlot`, `ScheduleFact`)
3. **Module/import system** — how programs are split across files; how stdlib is referenced

This proposal closes all three. It extends the grammar from PROP-014 to the
point where a real `.ig` source file can express the two existing fixtures.

[D] This is still **not a full grammar**. Pattern matching, generics variance,
trait/interface system, and macro system are PROP-016+. The goal is
the minimum extension that makes the `.igapp/` fixtures expressible in source.

---

## Part 1: `def` Blocks (User-Defined Functions)

### Problem

`compute_slots` and `build_snapshot` in `AvailabilityProjection` are called
in compute nodes but not declared anywhere in the PROP-014 grammar. Without a
`def` block, the classifier must either:
- reject the call as OOF (correct but unusable), or
- special-case it (incorrect — breaks the formal model)

### Solution

```text
def compute_slots(geo_signals: Collection[GeoSignal], schedule: ScheduleFact)
    -> Collection[TimeSlot] {
  if schedule.day_off {
    []
  } else {
    let start = schedule.working_hours[0]
    let end   = schedule.working_hours[1]
    fold(range(start, end), [], (acc, hour) -> {
      let signal = geo_signals.find_by(hour: hour).map(s -> s.signal).or_else("available")
      acc ++ [{ hour: hour, status: signal }]
    })
  }
}
```

### Grammar extension

```text
FunctionDecl := "def" Name "(" Params ")" "->" TypeRef "{" Body "}"
Params       := (Param ("," Param)*)?
Param        := Name ":" TypeRef
Body         := Stmt* Expr       -- last expression is the return value
Stmt         := "let" Name "=" Expr
Expr         := ... | IfExpr | BlockExpr | ArrayLiteral | RecordLiteral
IfExpr       := "if" Expr "{" Expr "}" ("else" "{" Expr "}")?
BlockExpr    := "{" Stmt* Expr "}"
ArrayLiteral := "[" (Expr ("," Expr)*)? "]"
RecordLiteral := "{" (Name ":" Expr ("," Name ":" Expr)*)? "}"
FieldAccess  := Expr "." Name
IndexAccess  := Expr "[" Expr "]"
```

### Semantic rules for `def`

```text
DefDecl = Record {
  name        : String
  params      : Collection[Param]
  return_type : TypeTag
  body        : Expr
  fragment    : FragmentClass      -- inferred from body
}

Fragment classification of a def:
  if body contains no escape/OOF constructs -> CORE
  if body contains declared escape -> ESCAPE
  if body contains undeclared IO -> OOF (blocked)

Termination:
  A def body may contain fold over Collection[T] inputs (TR-1 applies).
  A def body may NOT call itself recursively (self-reference -> OOF-C3).
  Mutual recursion -> OOF-C3.
```

**[D]** `def` bodies are pure. They cannot call TBackend, emit observations,
or use ambient IO. They are equivalent to lambda nodes in SemanticIR with a
named entry point. Self-recursion and mutual recursion are blocked by OOF-C3
(cycle in call graph).

**[D]** A `def` that calls another `def` is valid only if the call graph is
acyclic (DAG). The classifier builds a `CallGraph` and rejects cycles.

### SemanticIR representation

```text
A def call in a compute node lowers to:

  { "kind": "apply",
    "operator": "user.<module>.<name>",
    "operands": [...] }

where the def body is inlined at classification time (no dynamic dispatch).
```

---

## Part 2: TypeDecl (User-Defined Record Types)

### Problem

`GeoSignal`, `TimeSlot`, `ScheduleFact`, `AvailabilitySnapshot` are used in
the `AvailabilityProjection` fixture but have no source declaration. Without
`TypeDecl`, Pass 1 (TypedProgram) cannot type-check compute nodes.

### Grammar

```text
TypeDecl := "type" Name "{" FieldDecl* "}"
FieldDecl := Name ":" TypeRef ("?" )?    -- "?" = optional field

TypeRef   := PrimitiveType
           | Name                         -- user-defined type
           | "Collection[" TypeRef "]"
           | "Option[" TypeRef "]"
           | "Result[" TypeRef "," TypeRef "]"
           | "Map[" TypeRef "," TypeRef "]"

PrimitiveType := "Integer" | "Float" | "String" | "Bool"
               | "Timestamp" | "Date" | "Symbol"
```

### Example

```text
type GeoSignal {
  hour:   Integer
  signal: String
}

type TimeSlot {
  hour:   Integer
  status: String
}

type ScheduleFact {
  working_hours: Collection[Integer]
  day_off:       Bool
}

type AvailabilitySnapshot {
  technician_id:   String
  date:            String
  available_slots: Collection[TimeSlot]
  available_count: Integer
  snapshot_at:     String
}
```

### Semantic rules for TypeDecl

```text
TypeDecl = Record {
  name   : String
  fields : Collection[FieldDecl]
}

FieldDecl = Record {
  name     : String
  type_tag : TypeTag
  required : Bool        -- false if "?" suffix
}
```

**[D]** All `TypeDecl` types are structural, not nominal. Two types with the
same field names and types are equivalent. This preserves the algebraic
composition laws (PROP-002) — contracts compose on structure, not on
declared names.

**[D]** A `TypeDecl` is CORE by definition — it declares structure, not
behaviour. Fields may reference other `TypeDecl` types (acyclic references
only; self-referential types → OOF-C3).

### SemanticIR representation

```text
TypeDecl -> TypeEnv entry in SemanticIR:

  "user_types": {
    "GeoSignal": {
      "fields": [
        { "name": "hour",   "type_tag": "Integer", "required": true },
        { "name": "signal", "type_tag": "String",  "required": true }
      ]
    },
    ...
  }
```

---

## Part 3: Module and Import System

### Design constraints

```text
MC-1: A module is a named scope for contracts, types, and defs.
MC-2: A file maps 1:1 to a module (no multiple modules per file in v0).
MC-3: Import is explicit: every name from another module must be imported.
MC-4: Circular imports are OOF (cycle in module dependency graph).
MC-5: stdlib is always available without import (pre-imported).
MC-6: A module is either:
      - :core (no escape, no effects, no FFI)
      - :escape (declares escapes, may import :escape modules)
      - A :core module may only import :core modules.
      - An :escape module may import :core and :escape modules.
```

### Grammar

```text
ModuleDecl := "module" ModulePath
ModulePath := Name ("." Name)*           -- e.g. SparkCRM.Dispatch

ImportDecl := "import" ModulePath ("." "{" ImportList "}")?
ImportList := Name ("," Name)*           -- specific names

SourceFile := ModuleDecl?               -- optional; defaults to file stem
              ImportDecl*
              TopLevelDecl*

TopLevelDecl := ContractDecl | TypeDecl | FunctionDecl | ExternalDecl
```

### Example

```text
module SparkCRM.Availability

import SparkCRM.Types.{ GeoSignal, TimeSlot, ScheduleFact, AvailabilitySnapshot }

type HolidayCalendar {
  holidays: Collection[Date]
}

def compute_slots(geo_signals: Collection[GeoSignal], schedule: ScheduleFact)
    -> Collection[TimeSlot] { ... }

def build_snapshot(slots: Collection[TimeSlot], technician_id: String, date: String)
    -> AvailabilitySnapshot { ... }

contract AvailabilityProjection { ... }
```

### Module resolution rules

```text
Resolution order:
  1. Current module scope
  2. Explicit imports
  3. stdlib (always available)
  4. Error: name not found -> OOF-C2

Module fragment class:
  A module's fragment_class = max(fragment_class of all its declarations).
  A :core module containing an :escape declaration -> compile error.

Import fragment guard:
  Importing an :escape module into a :core module -> compile error
  unless the import is wrapped in an explicit `escape <name>` declaration.
```

### Module map in CompiledProgram

```text
CompiledProgram.semantic_ir.module_map = Map[ModulePath, ModuleDescriptor]

ModuleDescriptor = Record {
  path           : ModulePath
  fragment_class : FragmentClass
  contracts      : Collection[String]
  types          : Collection[String]
  defs           : Collection[String]
  source_hash    : Hash
}
```

---

## Part 4: Full Grammar Kernel (v0 BNF)

```text
SourceFile    := ModuleDecl? ImportDecl* TopDecl*

ModuleDecl    := "module" ModPath
ImportDecl    := "import" ModPath ("." "{" Name ("," Name)* "}")?
ModPath       := Name ("." Name)*

TopDecl       := ContractDecl | TypeDecl | FunctionDecl | ExternalDecl

ContractDecl  := "contract" Name "{" BodyDecl* "}"
BodyDecl      := EscapeDecl | InputDecl | ReadDecl | ComputeDecl
               | SnapshotDecl | WindowDecl | OutputDecl

EscapeDecl    := "escape" Name
InputDecl     := "input" Name ":" TypeRef
ReadDecl      := "read" Name ":" TypeRef "from" StrLiteral LifecycleAnn?
ComputeDecl   := "compute" Name "=" Expr
SnapshotDecl  := "snapshot" Name "=" Expr LifecycleAnn?
WindowDecl    := "window" StrLiteral "{" WindowOpt* "}"
WindowOpt     := ("kind" | "unit" | "on_close") ":" Name
OutputDecl    := "output" Name ":" TypeRef LifecycleAnn?
LifecycleAnn  := "lifecycle" LifecycleClass
LifecycleClass:= ":local"|":session"|":window"|":durable"|":audit"

TypeDecl      := "type" Name "{" FieldDecl* "}"
FieldDecl     := Name ":" TypeRef "?"?

FunctionDecl  := "def" Name "(" Params? ")" "->" TypeRef "{" Body "}"
Params        := Param ("," Param)*
Param         := Name ":" TypeRef
Body          := Stmt* Expr
Stmt          := "let" Name "=" Expr

ExternalDecl  := "external" LangId Name "{" ExternalOpt* "}"
LangId        := "ruby" | "rust" | "js" | "wasm"
ExternalOpt   := ("input"|"output"|"effects"|"capability"|"lifecycle"|
                  "failures"|"audit") ...

TypeRef       := "Integer"|"Float"|"String"|"Bool"|"Timestamp"|"Date"|"Symbol"
               | Name
               | "Collection[" TypeRef "]"
               | "Option[" TypeRef "]"
               | "Result[" TypeRef "," TypeRef "]"
               | "Map[" TypeRef "," TypeRef "]"

Expr          := Literal | Ref | BinOp | Call | IfExpr | BlockExpr
               | FieldAccess | IndexAccess | Lambda | ArrayLit | RecordLit
               | LetExpr

Literal       := IntLit | FloatLit | StrLiteral | BoolLit | NilLit
BinOp         := Expr Op Expr
Op            := "+" | "-" | "*" | "/" | "==" | "!=" | "<" | ">" | "<=" | ">="
               | "&&" | "||" | "++"
Call          := Name "(" (Expr ("," Expr)*)? ")"
IfExpr        := "if" Expr "{" Expr "}" ("else" "{" Expr "}")?
BlockExpr     := "{" Stmt* Expr "}"
Lambda        := "(" Params? ")" "->" Expr
               | Name "->" Expr
FieldAccess   := Expr "." Name
IndexAccess   := Expr "[" Expr "]"
ArrayLit      := "[" (Expr ("," Expr)*)? "]"
RecordLit     := "{" (Name ":" Expr ("," Name ":" Expr)*)? "}"
LetExpr       := "let" Name "=" Expr   -- inside Body only
```

---

## Part 5: Complete Source File for Add Fixture

```text
-- add.ig
module Lang.Examples.Add

contract Add {
  input  a: Integer
  input  b: Integer
  compute sum = a + b
  output sum: Integer
}
```

Compiler target: `fixtures/add.igapp/` — exact match expected.

---

## Part 6: Complete Source File for AvailabilityProjection Fixture

```text
-- availability_projection.ig
module SparkCRM.Availability

import SparkCRM.Types.{ GeoSignal, TimeSlot, ScheduleFact, AvailabilitySnapshot }

def compute_slots(geo_signals: Collection[GeoSignal], schedule: ScheduleFact)
    -> Collection[TimeSlot] {
  if schedule.day_off {
    []
  } else {
    let start  = schedule.working_hours[0]
    let end    = schedule.working_hours[1]
    fold(range(start, end), [], (acc, hour) -> {
      let signal = map(filter(geo_signals, s -> s.hour == hour), s -> s.signal)
      let status = or_else(first(signal), "available")
      acc ++ [{ hour: hour, status: status }]
    })
  }
}

def build_snapshot(slots: Collection[TimeSlot], technician_id: String, date: String)
    -> AvailabilitySnapshot {
  let available_count = count(filter(slots, s -> s.status == "available"))
  { technician_id:   technician_id,
    date:            date,
    available_slots: slots,
    available_count: available_count,
    snapshot_at:     date }
}

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

  compute available_slots = compute_slots(geo_signals, schedule)

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

Compiler target: `fixtures/availability_projection.igapp/` — exact match expected.

---

## Part 7: New OOF Rules from Grammar Extension

```text
OOF-G1: Recursive def (self-call or mutual call cycle).
  CallGraph contains a cycle -> OOF-C3 extended to defs.

OOF-G2: Self-referential TypeDecl.
  type Foo { bar: Foo } -> OOF-C3.

OOF-G3: :core module importing :escape module without escape declaration.
  compile error: module fragment mismatch.

OOF-G4: Wildcard import (import Module.*).
  Blocked in v0. Explicit imports only.

OOF-G5: Unresolved import.
  import SparkCRM.Types.{ GeoSignal } where SparkCRM.Types does not exist
  -> OOF-C2: name not found.

OOF-G6: def with side effects (ambient IO, TBackend, observation emit).
  A def body that calls TBackend directly -> OOF.
  TBackend access is only in ReadDecl inside ContractDecl.
```

---

## Open Questions

[Q-1] Should `range(start, end)` be a stdlib primitive? It produces
`Collection[Integer]` from two bounds. Recommendation: yes — it is a
bounded collection; termination guaranteed (TR-1).

[Q-2] Should `first(collection)` return `Option[T]`? Yes. Analogous to
`min`/`max`. Empty collection → `None`.

[Q-3] Should TypeDecls support inheritance or `extends`? Recommendation:
no in v0. Structural typing handles most cases. Inheritance introduces
nominal subtyping complexity.

[Q-4] Should multi-file modules be supported in v0, or one module per
program? Recommendation: one module per file in v0; multi-file module
support (same module path, multiple files) is PROP-016.

[Q-5] Should `def` bodies be able to call contracts? Recommendation: no.
A `def` is a pure function. Contract calls produce observations and require
a RuntimeMachine. A `def` calling a contract would be ESCAPE at minimum.

---

## Rejected Paths

[X] Pattern matching (`match`/`case`) in v0.
Too large a grammar extension; defers to PROP-016.

[X] Generics (`def foo[T](x: T) -> T`) in v0.
Parametric polymorphism requires a type constraint system. PROP-016+.

[X] Trait or interface declarations in v0.
Structural typing is sufficient for the current fixture set. PROP-016+.

[X] Mutable variables (`var`, `let mut`).
All bindings are immutable. `let` is single-assignment inside a def body.

[X] Exception handling (`try`/`catch`/`raise`).
Error handling is via `Result[T, E]` and `failure_observation`.

[X] Wildcard imports.
Explicit imports only in v0. Name resolution must be unambiguous.

[X] Circular module imports.
Module dependency graph must be a DAG. Cycles → OOF-C3 (module-level).

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-015-grammar-module-system-v0.md
Status: done

[D] Decisions:
- def blocks are pure named functions. Self-recursion and mutual recursion
  are OOF-G1 (cycle in CallGraph). A def may call stdlib and other defs
  (acyclic only).
- def bodies are inlined at classification time. No dynamic dispatch.
  SemanticIR operator: "user.<module>.<name>".
- TypeDecls are structural, not nominal. Same-field types are equivalent.
  Self-referential TypeDecls are OOF-G2.
- Modules: one file = one module. Module fragment_class = max of declarations.
- Import is explicit. Wildcard import is OOF-G4.
- :core module cannot import :escape module without escape declaration (OOF-G3).
- Circular module imports are OOF-C3 at module level.
- stdlib is always pre-imported. No import needed for fold, map, count, etc.
- range(start, end) -> Collection[Integer]: stdlib primitive (TR-1 safe).
- first(collection) -> Option[T]: returns None on empty.
- The two source files defined here (add.ig, availability_projection.ig)
  are the acceptance test targets for the v0 compiler frontend.

[R] Recommendations:
- Implement parser from PROP-014 grammar + PROP-015 extensions
  as a recursive-descent parser in Ruby.
- ParsedProgram should emit module_map alongside contracts.
- The CallGraph acyclicity check should reuse the DependencyGraph
  DAG check already implemented in the devkit RSpec tests.
- range/first should be added to stdlib/core/collection.ig (PROP-013).

[S] Signals:
- The two complete source files in Part 5 and 6 close the fixture loop:
  every hand-authored .igapp/ file now has a corresponding source form.
- The grammar is small enough for a hand-written recursive-descent parser
  (~500 lines of Ruby) without a parser generator.
- `def` inlining at classification time means the SemanticIR evaluator
  in compiled_program.rb needs no changes — inlined defs become apply nodes.

[Q] Open Questions:
- range(start, end): confirm as stdlib primitive?
- first(collection): confirm as Option[T] stdlib?
- Multi-file modules: v0 or defer?
- def calling contract: confirm blocked in v0?

[X] Rejected:
- Pattern matching, generics, traits (PROP-016+).
- Mutable variables.
- Exceptions.
- Wildcard imports.
- Circular module imports.
- def calling contract.

[Next] Proposed next slice:
- FFI Ruby bridge: ffi-ruby-contractable-proof-v0
  (Ruby host calls as ESCAPE contracts with capabilities/receipts)
- Devkit extension: add range/first to stdlib in compiled_program.rb
  evaluator; re-run availability_projection_igapp_spec
- PROP-016 candidate: Pattern Matching and Generics v0
```
