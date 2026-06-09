# PROP-044 (P2): `variant` Declaration and Exhaustive `match` Expression — Grammar Design

**PROP:** 044 (grammar design phase)  
**Track:** variant-and-exhaustive-match-design-v0  
**Status:** grammar-design (P2 authored 2026-06-09)  
**Depends on:** PROP-044-P1 (convention doc), PROP-004 (ch3 type grammar), PROP-026 (parser OOF hardening)  
**Author:** Portfolio Architect Supervisor  
**Gate route:** grammar design (P2) → parser implementation (P3, requires explicit auth) → typechecker (P4) → SemanticIR emitter (P5) → VM dispatch (P6)

---

## 1. Context

PROP-044-P1 defined the Kind-Discriminated Record (KDR) convention: the
`kind: String` field pattern proved across three independent domains. It also
catalogued what the convention cannot do — no closed kind vocabulary, no
exhaustive match enforcement, no type narrowing. All four blockers require new
grammar.

This document (P2) designs that grammar. It produces:

- The `variant` type declaration form and its EBNF
- The `match` exhaustive expression and its EBNF  
- Type narrowing rules (how the typechecker handles match arm scope)
- Variant construction syntax
- OOF-KIND1 through OOF-KIND4 formal definitions
- SemanticIR node shapes (design only — no IR implementation authorized)
- Parser extension points (design only — no parser changes authorized)
- Explicit design decisions for each non-obvious choice

**What this document does not authorize:**

- Any parser change
- Any typechecker change
- Any classifier change
- Any SemanticIR emitter change
- Any VM change
- Activating OOF-KIND codes
- Creating a stable `Result[T]` / `Outcome[T]` public type

---

## 2. Grammar: `variant` Declaration

### 2.1 Placement in `TopDecl`

`variant` is a new top-level declaration form, parallel to `type` and `contract`.
The current `TopDecl` dispatch (parser.rb line ~410):

```
TopDecl := ContractDecl | TypeDecl | FunctionDecl | OLAPPointDecl | AssumptionsDecl
         | TraitDecl | ImplDecl | ContractShapeDecl
```

After this design lands, it becomes:

```
TopDecl := ContractDecl | TypeDecl | VariantDecl | FunctionDecl | OLAPPointDecl
         | AssumptionsDecl | TraitDecl | ImplDecl | ContractShapeDecl
```

The parser keyword table currently includes:

```ruby
input output compute read snapshot window escape
```

`variant` and `match` would be added to the keyword table. (Implementation
detail — noted here; not authorized yet.)

### 2.2 EBNF: `VariantDecl`

```ebnf
VariantDecl  ::= "variant" Name "{" VariantArm+ "}"
VariantArm   ::= Name ArmBody? ","?
ArmBody      ::= "{" ArmField ("," ArmField)* ","? "}"
ArmField     ::= Name ":" TypeRef
```

`Name` in a `VariantArm` is a **PascalCase arm name** (the variant constructor
name). `Name` in `ArmField` is a snake_case field name. The typechecker enforces
PascalCase for arm names as a style rule, not a hard parser requirement (v0).

**Unit arm** — an arm with no payload:

```igniter
variant Signal {
  Ok,
  Pending,
  Cancelled
}
```

**Record arm** — an arm with named fields:

```igniter
variant ValidationOutcome {
  Valid     { message: String, metadata: Map[String, String] }
  Invalid   { field: String, message: String, metadata: Map[String, String] }
  Unauthorized { reason: String, metadata: Map[String, String] }
  SystemError  { detail: String, metadata: Map[String, String] }
}
```

**Mixed** — some arms have fields, some do not:

```igniter
variant Lifecycle {
  Pending,
  Active  { started_at: String },
  Closed  { reason: String, closed_at: String }
}
```

### 2.3 Parse AST shape

`parse_variant_decl` would produce:

```json
{
  "kind":  "variant",
  "name":  "ValidationOutcome",
  "arms": [
    {
      "name":   "Valid",
      "fields": [
        { "name": "message",  "type_annotation": { "kind": "type_ref", "name": "String",  "params": [] } },
        { "name": "metadata", "type_annotation": { "kind": "type_ref", "name": "Map",
                                                    "params": [{"name":"String","params":[]},
                                                               {"name":"String","params":[]}] } }
      ]
    },
    {
      "name":   "Invalid",
      "fields": [
        { "name": "field",   "type_annotation": { "kind": "type_ref", "name": "String", "params": [] } },
        { "name": "message", "type_annotation": { "kind": "type_ref", "name": "String", "params": [] } },
        { "name": "metadata", "type_annotation": { "kind": "type_ref", "name": "Map",
                                                    "params": [{"name":"String","params":[]},
                                                               {"name":"String","params":[]}] } }
      ]
    },
    {
      "name":   "Unauthorized",
      "fields": [
        { "name": "reason",   "type_annotation": { "kind": "type_ref", "name": "String", "params": [] } },
        { "name": "metadata", "type_annotation": { "kind": "type_ref", "name": "Map",
                                                    "params": [{"name":"String","params":[]},
                                                               {"name":"String","params":[]}] } }
      ]
    },
    {
      "name":   "SystemError",
      "fields": [
        { "name": "detail",   "type_annotation": { "kind": "type_ref", "name": "String", "params": [] } },
        { "name": "metadata", "type_annotation": { "kind": "type_ref", "name": "Map",
                                                    "params": [{"name":"String","params":[]},
                                                               {"name":"String","params":[]}] } }
      ]
    }
  ]
}
```

Parallel to how `parse_type_decl` produces `{ "kind" => "type", ... }`, this
produces `{ "kind" => "variant", ... }`. The classifier and typechecker learn to
handle `"kind" => "variant"` top-level nodes.

---

## 3. Grammar: Variant Construction Expression

### 3.1 Motivation

To produce a value of a `variant` type inside a contract, the source must
construct a specific arm. This requires a construction expression form.

### 3.2 EBNF: `VariantConstruct`

```ebnf
VariantConstruct ::= Name "{" FieldInit ("," FieldInit)* ","? "}"
                   | Name                                        -- unit arm
FieldInit        ::= Name ":" Expr
```

The leading `Name` is the **arm name** (PascalCase). This mirrors record literal
syntax but is distinguished by the leading uppercase name before `{`.

```igniter
compute result = Valid { message: "submission accepted", metadata: context }
compute denied = Unauthorized { reason: reason_str, metadata: context }
```

Unit arm construction (no `{}`):

```igniter
compute sig = Pending
```

### 3.3 Parser disambiguation

In `parse_primary`, an identifier token currently produces `{ "kind" => "ref",
"name" => tok.value }`. After this design lands, an uppercase identifier
immediately followed by `{` would produce `{ "kind" => "variant_construct",
"arm" => name, "fields" => [...] }`.

The disambiguation rule:

```
peek = ident (PascalCase) AND peek(1) = lbrace  →  parse_variant_construct
peek = ident (PascalCase)                         →  ref (may be arm name as unit constructor;
                                                      typechecker validates)
peek = lbrace                                     →  parse_record_or_block (existing)
```

PascalCase detection: first character is uppercase. This is a parser-level heuristic;
the typechecker provides the authoritative check that the name is a declared arm.

**Ambiguity note:** A PascalCase `ref` followed by `{` will always be attempted
as a `variant_construct`. If the typechecker determines the name is not a variant
arm (e.g. it is a type name being used improperly), it emits OOF-KIND2. This is
the same resolution pattern as record literal vs block disambiguation already in
the parser (`parse_record_or_block`).

### 3.4 Parse AST shape for construction

```json
{
  "kind": "variant_construct",
  "arm":  "Valid",
  "fields": {
    "message":  { "kind": "ref", "name": "msg_str" },
    "metadata": { "kind": "ref", "name": "context"  }
  }
}
```

Unit arm: `{ "kind" => "variant_construct", "arm" => "Pending", "fields" => {} }`

---

## 4. Grammar: `match` Expression

### 4.1 Placement in `parse_primary`

`match` is a new keyword expression, parallel to `if`. From `parse_primary`:

```ruby
when "match" then advance; parse_match_expr
```

This extends the existing:

```ruby
when "if"  then advance; parse_if_expr
```

### 4.2 EBNF: `MatchExpr`

```ebnf
MatchExpr    ::= "match" Expr "{" MatchArm+ "}"
MatchArm     ::= MatchPattern "=>" Expr ","?
MatchPattern ::= ArmPattern | WildcardPattern
ArmPattern   ::= Name BindingBlock?
BindingBlock ::= "{" BindingName ("," BindingName)* ","? "}"
BindingName  ::= Name
WildcardPattern ::= "_"
```

`Name` in `ArmPattern` is the arm name (PascalCase).  
`BindingName` is a name introduced into the arm body scope (snake_case).

### 4.3 Concrete syntax examples

**Four-arm exhaustive match:**

```igniter
compute action = match outcome {
  Valid     { message, metadata }        => "accept"
  Invalid   { field, message, metadata } => "reject"
  Unauthorized { reason, metadata }      => "deny"
  SystemError  { detail, metadata }      => "error"
}
```

**Unit arms:**

```igniter
compute label = match sig {
  Ok        => "done"
  Pending   => "waiting"
  Cancelled => "stopped"
}
```

**Mixed (record and unit arms):**

```igniter
compute display = match lc {
  Pending                      => "not started"
  Active   { started_at }      => started_at
  Closed   { reason, closed_at } => closed_at
}
```

**With wildcard arm (suppresses OOF-KIND1 but loses exhaustiveness guarantee):**

```igniter
compute label = match outcome {
  Valid { message } => message
  _                 => "unhandled"
}
```

### 4.4 Binding semantics

Each `BindingName` in a `BindingBlock` introduces a local binding scoped to
that arm's `Expr`. The binding name must match a field name declared in the
matched variant arm. The typechecker assigns the binding the type of that field.

```igniter
-- In the Invalid { field, message, metadata } arm:
--   field    : String          (declared in Invalid arm)
--   message  : String          (declared in Invalid arm)
--   metadata : Map[String,String] (declared in Invalid arm)
```

Attempting to bind a name not declared in the arm's fields → OOF-KIND2 (field
not in variant arm). Attempting to use a binding from one arm in a different
arm's expression → scope error (existing OOF-TY0 class, undefined reference).

### 4.5 Result type constraint

All arms of a match expression must produce the same type. The typechecker
infers the match expression's result type from the first arm and checks that
all subsequent arms unify with it.

If arm types diverge → OOF-KIND5 (arm type mismatch — new candidate, not in
the OOF-KIND1..4 set defined in P1; reserved here).

### 4.6 Parse AST shape

```json
{
  "kind":    "match_expr",
  "subject": { "kind": "ref", "name": "outcome" },
  "arms": [
    {
      "pattern": { "arm": "Valid",       "bindings": ["message", "metadata"] },
      "body":    { "kind": "literal",    "value": "accept", "type_tag": "String" }
    },
    {
      "pattern": { "arm": "Invalid",     "bindings": ["field", "message", "metadata"] },
      "body":    { "kind": "literal",    "value": "reject", "type_tag": "String" }
    },
    {
      "pattern": { "arm": "Unauthorized","bindings": ["reason", "metadata"] },
      "body":    { "kind": "literal",    "value": "deny",   "type_tag": "String" }
    },
    {
      "pattern": { "arm": "SystemError", "bindings": ["detail", "metadata"] },
      "body":    { "kind": "literal",    "value": "error",  "type_tag": "String" }
    }
  ]
}
```

Wildcard arm: `{ "pattern": { "arm": "_", "bindings": [] }, "body": ... }`

---

## 5. Type Narrowing Rules

Type narrowing is the mechanism by which the typechecker assigns precise types
to bindings inside a match arm, based on the arm's field declarations.

### 5.1 Narrowing algorithm (design)

Given a match expression `match subject { ArmA { b1, b2 } => expr_a, ... }`:

1. Resolve `subject` to its declared type in the current scope. Call it `T`.
2. Verify `T` is a `variant` type in the type environment. If not → OOF-KIND4.
3. For each arm pattern `ArmN { b1, b2, ... }`:
   a. Locate arm `ArmN` in the variant declaration of `T`. If not found → OOF-KIND2.
   b. For each binding `bi`, find the field named `bi` in `ArmN`'s field list.
      Assign `bi` type = that field's declared type. If `bi` not in fields → OOF-KIND2.
   c. Type-check `expr_N` under the extended scope containing `{b1: T1, b2: T2, ...}`.
   d. The arm result type is the resolved type of `expr_N`.
4. Verify all arm result types are equal (or unify). If not → OOF-KIND5.
5. Verify all arms in the variant declaration are covered, or `_` is present.
   If any arm is missing and `_` is absent → OOF-KIND1.
6. The match expression's resolved type = the common arm result type.

The narrowed scope in step 3b is **per-arm-only**. Bindings from one arm are not
visible in other arms or outside the match expression.

### 5.2 Interaction with `compute` chain

In a contract body, `compute` names are added to the scope as the chain
progresses. A binding introduced by a match arm is arm-local and does not
escape into subsequent compute nodes.

```igniter
compute action = match outcome {
  Valid { message } => message    -- `message` visible in this arm only
  _                 => "unknown"
}
-- `message` is NOT in scope here; only `action` (type: String) is
compute summary = action ++ " processed"  -- valid
```

This is consistent with the existing `compute` chain scoping model.

### 5.3 Subject expression restrictions (v0)

In v0, the match subject must be a simple `ref` (variable name in scope) or a
field access chain (`a.b`, `a.b.c`). Complex expressions as subjects (function
calls, binary ops) are deferred to v1.

This restriction keeps exhaustiveness checking tractable in v0: the typechecker
always has a named subject whose type is known from the scope.

---

## 6. OOF-KIND Codes — Formal Definitions

OOF-KIND1 through OOF-KIND4 were reserved in P1. This document provides formal
definitions. OOF-KIND5 is new (arm type mismatch, discovered during match design).

All OOF-KIND codes are **candidates** — they are not active until grammar
implementation is authorized (P3+).

### OOF-KIND1: Non-exhaustive match

```
Code:      OOF-KIND1
Phase:     Typechecking
Condition: A match expression covers fewer arms than the matched variant declares,
           and no wildcard `_` arm is present.
Message:   "match on `{VariantName}` is not exhaustive: missing arms {ArmA, ArmB, ...}"
Severity:  Error (nil semantic_ir for the enclosing contract)
Suppressed by: a `_` wildcard arm anywhere in the match
```

Example:

```igniter
-- ValidationOutcome has 4 arms; only 2 are matched → OOF-KIND1
compute action = match outcome {
  Valid   { message } => "accept"
  Invalid { field }   => "reject"
  -- Unauthorized and SystemError are missing
}
```

### OOF-KIND2: Arm name or binding name not in variant

```
Code:      OOF-KIND2
Phase:     Classification / Typechecking
Condition: (a) A match arm pattern names an arm that doesn't exist in the variant, OR
           (b) A binding name in an arm pattern doesn't match a declared field of that arm, OR
           (c) A variant_construct names an arm that doesn't exist in the target variant type
Message:   "arm `{ArmName}` is not a member of variant `{VariantName}`"
           "field `{name}` is not declared in arm `{ArmName}` of `{VariantName}`"
Severity:  Error
```

### OOF-KIND3: Unreachable match arm

```
Code:      OOF-KIND3
Phase:     Typechecking
Condition: (a) A `_` wildcard arm appears before the last arm (making subsequent arms dead), OR
           (b) The same arm name appears twice in the same match expression
Message:   "arm `{ArmName}` is unreachable: already covered above"
           "wildcard `_` makes subsequent arms unreachable"
Severity:  Warning (semantic_ir still emitted; arm is dead code)
```

### OOF-KIND4: Match subject is not a variant type

```
Code:      OOF-KIND4
Phase:     Typechecking
Condition: The subject of a `match` expression has a type that is not a declared
           `variant` type (e.g. String, Integer, Record, Map, Option[T])
Message:   "cannot match on `{Type}`: match requires a variant type"
Severity:  Error
```

Note: `Option[T]` is a built-in type, not a user-declared variant. Matching on
`Option[T]` is separately handled if/when Option pattern matching is designed
(deferred, not part of this proposal).

### OOF-KIND5: Match arm result type mismatch

```
Code:      OOF-KIND5
Phase:     Typechecking
Condition: Two or more arms of a match expression produce values of incompatible types
Message:   "match arm `{ArmName}` produces `{TypeB}` but earlier arms produce `{TypeA}`"
Severity:  Error
```

---

## 7. SemanticIR Shapes (Design Only)

These shapes describe what the SemanticIR emitter would produce. They are
**design proposals** — no emitter changes are authorized.

### 7.1 Variant declaration in program IR

At the top-level program node, alongside `type_defs`, a new `variant_defs` array:

```json
{
  "variant_defs": [
    {
      "kind": "variant_decl",
      "name": "ValidationOutcome",
      "arms": [
        {
          "name": "Valid",
          "fields": [
            { "name": "message",  "type": "String" },
            { "name": "metadata", "type": "Map[String,String]" }
          ]
        },
        {
          "name": "Invalid",
          "fields": [
            { "name": "field",    "type": "String" },
            { "name": "message",  "type": "String" },
            { "name": "metadata", "type": "Map[String,String]" }
          ]
        },
        {
          "name": "Unauthorized",
          "fields": [
            { "name": "reason",   "type": "String" },
            { "name": "metadata", "type": "Map[String,String]" }
          ]
        },
        {
          "name": "SystemError",
          "fields": [
            { "name": "detail",   "type": "String" },
            { "name": "metadata", "type": "Map[String,String]" }
          ]
        }
      ]
    }
  ]
}
```

### 7.2 `variant_construct` node in contract body

A `compute` node whose `expr` is a variant construction:

```json
{
  "kind": "compute",
  "name": "result",
  "expr": {
    "kind":          "variant_construct",
    "variant_type":  "ValidationOutcome",
    "arm":           "Valid",
    "fields": {
      "message":  { "kind": "ref", "name": "msg" },
      "metadata": { "kind": "ref", "name": "context" }
    }
  },
  "resolved_type": "ValidationOutcome"
}
```

### 7.3 `match_node` in contract body

A `compute` node whose `expr` is a match expression:

```json
{
  "kind": "compute",
  "name": "action",
  "expr": {
    "kind":          "match_node",
    "subject":       { "kind": "ref", "name": "outcome" },
    "subject_type":  "ValidationOutcome",
    "exhaustive":    true,
    "arms": [
      {
        "arm":      "Valid",
        "bindings": { "message": "String", "metadata": "Map[String,String]" },
        "body":     { "kind": "literal", "value": "accept", "type_tag": "String" }
      },
      {
        "arm":      "Invalid",
        "bindings": { "field": "String", "message": "String", "metadata": "Map[String,String]" },
        "body":     { "kind": "literal", "value": "reject", "type_tag": "String" }
      },
      {
        "arm":      "Unauthorized",
        "bindings": { "reason": "String", "metadata": "Map[String,String]" },
        "body":     { "kind": "literal", "value": "deny",   "type_tag": "String" }
      },
      {
        "arm":      "SystemError",
        "bindings": { "detail": "String", "metadata": "Map[String,String]" },
        "body":     { "kind": "literal", "value": "error",  "type_tag": "String" }
      }
    ]
  },
  "resolved_type": "String"
}
```

`exhaustive: true` when all arms are covered with no wildcard. `exhaustive: false`
when a `_` arm is present (coverage is not verified by the typechecker for the
wildcard path).

---

## 8. Migration Path: Convention → Grammar

### 8.1 The convention remains valid

The KDR convention (`type` + `kind: String`) is not deprecated by this grammar
addition. Existing lab code and domain docs remain correct. The convention is
the production-safe approach today; the grammar form becomes available when P3+
is authorized.

### 8.2 Correspondence table

| Convention form | Grammar form |
|----------------|-------------|
| `type ValidationResult { kind: String, ... }` | `variant ValidationOutcome { Valid {...}, ... }` |
| Comment-level kind vocabulary | Arm declarations (closed, checked) |
| Host-layer String match (`if kind == "valid"`) | `match outcome { Valid {...} => ..., ... }` |
| No exhaustiveness guarantee | OOF-KIND1 enforced by typechecker |
| No typo detection | OOF-KIND2 (arm name not in variant) |
| `Map[String,String]` metadata convention | Retained — same field shape in each arm |
| Denial-as-data design law | Modeled as a named arm (`Unauthorized`, `Denied`, etc.) |

### 8.3 Renaming note

PROP-044-P1 noted that `ContractResult` is HTTP-domain-bound. The grammar form
makes this more precise: `ContractResult` is a `type` (KDR convention), and any
future grammar-promoted version would be a `variant` with a domain-specific name.
Renaming `ContractResult` is a separate concern and is not authorized by this
proposal.

---

## 9. Relationship to Existing Grammar

### 9.1 `Option[T]` is not a `variant`

`Option[T]` is a built-in parameterised type, not a user-declared `variant`.
It has special handling in the typechecker (`or_else`, `map_get` return types).
This proposal does not change `Option[T]` handling.

If Option pattern matching is eventually desired:

```igniter
-- future (not this proposal)
compute result = match maybe_val {
  Some { value } => value
  None           => "default"
}
```

This is deferred. In v0, `or_else` remains the idiomatic Option handler.

### 9.2 `type` and `variant` are distinct

| Form | Use when |
|------|----------|
| `type` (named Record) | Key set known at compile time; all fields always present |
| `variant` (sum type) | Value is exactly one of N named constructors; field sets differ per constructor |

A `type` with a `kind: String` field is not the same as a `variant`. The type
system treats them differently. The KDR convention uses `type`; the grammar
promotion uses `variant`.

### 9.3 Interaction with `pure contract`

Variant types as input and output:

```igniter
pure contract ValidationRouter {
  input  outcome : ValidationOutcome
  compute action = match outcome {
    Valid        { message, metadata } => "accept"
    Invalid      { field, message, metadata } => "reject"
    Unauthorized { reason, metadata } => "deny"
    SystemError  { detail, metadata } => "error"
  }
  output action : String
}
```

`input name : VariantType` — the `input` declaration accepts any declared type
including variant types. No change needed to the input declaration form.

`output name : VariantType` — same. A contract can produce a variant value.

`compute name = match ...` — the match expression is an expression in a compute
node. No change to the `compute` declaration form; only the expression language
is extended.

### 9.4 Interaction with `Map[String,String]` (PROP-043)

Variant arm fields may include `Map[String,String]` (proven in all KDR domains).
The `map_get` + `or_else` chain works on any `Map[String,String]` value — whether
it comes from a record field, a direct input, or a variant arm binding.

```igniter
compute action = match outcome {
  Valid { message, metadata } =>
    or_else(map_get(metadata, "override"), "accept")
  -- `metadata` here is Map[String,String]; map_get/or_else chain applies
  ...
}
```

This follows from the existing PROP-043-P5 production surface. No new VM
operations are needed for map access inside match arms.

---

## 10. Design Decisions (15 locked)

| # | Question | Decision |
|---|----------|----------|
| D1 | New keyword `variant`, or extend `type`? | **New keyword `variant`** — syntactically distinct from record `type`; prevents confusion at the type-system level |
| D2 | New keyword `match`, or reuse `if`/`case`? | **New keyword `match`** — `if` is boolean; `case` is not in vocabulary; `match` is the established term for exhaustive dispatch on sum types |
| D3 | Arm names: enforced PascalCase or not? | **Style rule, not hard parser rule** — typechecker emits a warning for lowercase arm names; parser accepts any identifier; enforced PascalCase is deferred to a linting pass |
| D4 | Unit arms (no fields) allowed? | **YES** — `variant Signal { Ok, Pending, Cancelled }` covers the common case of pure kind enumeration without payload |
| D5 | Wildcard `_` arm allowed? | **YES** — suppresses OOF-KIND1; the arm is marked `exhaustive: false` in SemanticIR; the user accepts non-exhaustive coverage explicitly |
| D6 | Guard conditions in arms (`when cond`)? | **NO — deferred to v1** — guards complicate exhaustiveness analysis; no proven need in the current corpus |
| D7 | Nested match (match inside match arm body)? | **Deferred to v1** — single-level match sufficient for all KDR patterns; nesting adds parsing ambiguity for the `{` delimiter |
| D8 | Match subject: expressions or names only? | **v0: simple ref or field access only** (`a`, `a.b`, `a.b.c`) — keeps exhaustiveness tractable; complex subject expressions deferred |
| D9 | Arm result type: must be identical or unifiable? | **Must unify** — the typechecker uses the same unification rule as for record field types; divergent arm types → OOF-KIND5 |
| D10 | Does `Option[T]` become a `variant`? | **NO** — Option[T] remains built-in; `match` on Option is separately deferred |
| D11 | Variant construction: `Name {}` vs `Name::Arm {}`? | **`Name {}` with PascalCase arm name directly** — `Valid { ... }` not `ValidationOutcome::Valid { ... }`; shorter and consistent with the proven KDR vocabulary shape; typechecker resolves the arm name from context |
| D12 | Can a variant arm name shadow a local variable? | **NO — OOF-KIND2 (arm name conflict)** — arm names occupy a distinct namespace; a lowercase local and a PascalCase arm name cannot collide |
| D13 | Partial binding (bind only some fields of an arm)? | **YES — allowed in v0** — `Invalid { field }` binds only `field` even if `message` and `metadata` are declared; unused fields are not bound and not in scope |
| D14 | Can a contract output a variant value directly? | **YES** — `output result : ValidationOutcome` is valid; the variant type is a fully-fledged type in the type system |
| D15 | `variant` in type parameters (e.g. `Collection[ValidationOutcome]`)? | **YES** — variant types are first-class in v0; they may appear anywhere a TypeRef is accepted |

---

## 11. Parser Extension Points (Design Reference)

This section describes exactly where the parser would be extended, for use
when P3 implementation is authorized. **No changes are authorized now.**

| Extension point | Current form | Addition |
|----------------|-------------|---------|
| `TopDecl` dispatch (line ~410) | `when "type" then advance; parse_type_decl` | Add `when "variant" then advance; parse_variant_decl` |
| `parse_primary` (line ~1723) | `when "if" then advance; parse_if_expr` | Add `when "match" then advance; parse_match_expr` |
| `parse_primary` postfix (line ~1731) | `when :ident then advance; { "kind" => "ref", ... }` | Check: if PascalCase and next is `lbrace` → `parse_variant_construct` |
| Keyword table (`TOKEN_TYPES` / keyword list) | `input output compute read ...` | Add `variant match` |
| `parse_body_decl` | `when "compute"` | No change — `compute name = match_expr` already fits |

New methods to add (when authorized):

```
parse_variant_decl       -- parses VariantDecl, produces { kind: "variant", ... }
parse_variant_arm        -- parses one VariantArm (name + optional ArmBody)
parse_match_expr         -- parses MatchExpr, produces { kind: "match_expr", ... }
parse_match_arm          -- parses one MatchArm (pattern + => body)
parse_arm_pattern        -- parses ArmPattern or WildcardPattern
parse_variant_construct  -- parses VariantConstruct expression
```

---

## 12. Typechecker Extension Points (Design Reference)

For use when P4 is authorized. **No changes authorized now.**

| Concern | Current typechecker | Addition needed |
|---------|-------------------|----------------|
| Type environment for variants | `@type_shapes` holds record types | Add `@variant_shapes` hash: variant name → { arm_name → { field_name → type } } |
| `variant` top-level node | Not handled | `check_variant_decl` — populates `@variant_shapes` |
| `variant_construct` expr | Not handled | `infer_variant_construct` — looks up arm in `@variant_shapes`; checks fields; returns variant type |
| `match_node` expr | Not handled | `infer_match_expr` — resolves subject type; checks exhaustiveness; runs narrowing per arm; checks arm type unification; emits OOF-KIND1/2/3/4/5 as appropriate |
| OOF-KIND1..5 | Not present | New diagnostic codes added to the OOF registry |

---

## 13. Gap Packet

```
proof:          variant-and-exhaustive-match-design / v0
status:         grammar-design (P2 authored 2026-06-09)
authority:      design-only / no-production-impl

grammar_design:
  variant_decl:     DESIGNED — TopDecl; parse_variant_decl; { kind: "variant", arms: [...] }
  match_expr:       DESIGNED — parse_primary; parse_match_expr; { kind: "match_expr", arms: [...] }
  variant_construct: DESIGNED — PascalCase+lbrace; { kind: "variant_construct", arm, fields }
  type_narrowing:   DESIGNED — per-arm binding scope; arm field types assigned by typechecker
  oof_kinds:
    OOF-KIND1: non-exhaustive match (typechecker, error)
    OOF-KIND2: arm/binding not in variant (classifier+typechecker, error)
    OOF-KIND3: unreachable arm (typechecker, warning)
    OOF-KIND4: match subject not a variant (typechecker, error)
    OOF-KIND5: arm result type mismatch (typechecker, error)
  semantic_ir:
    variant_decl: in program variant_defs array
    variant_construct: expr node, resolved_type = variant name
    match_node: expr node, exhaustive flag, per-arm bindings + resolved_types

closed:
  parser_impl:       CLOSED — P3 (explicit auth)
  typechecker_impl:  CLOSED — P4 (explicit auth)
  emitter_impl:      CLOSED — P5 (explicit auth)
  vm_dispatch:       CLOSED — P6 (explicit auth)
  oof_activation:    CLOSED — P4+ (grammar must land first)
  option_match:      CLOSED — deferred (not part of this proposal)
  stable_api:        CLOSED — no Result[T]/Outcome[T] claim

next_authorized:
  immediate:    convention use (PROP-044-P1 KDR doc)
  P3 (requires explicit auth): parser implementation
  P4 (requires explicit auth): typechecker + OOF-KIND activation
  P5 (requires explicit auth): SemanticIR emitter
  P6 (requires explicit auth): VM variant dispatch
```

---

## 14. Authority Statement

This document is a **grammar design proposal only**. It authorizes:

- Following the KDR convention (PROP-044-P1) in lab code and design docs
- Referencing this design when authoring P3+ cards

It does not authorize:

- Parser changes (`variant` keyword, `match` expression)
- Typechecker changes (`@variant_shapes`, `infer_match_expr`)
- OOF-KIND activation (codes reserved but not live)
- SemanticIR emitter changes
- VM changes
- Production promotion of any variant-based API

**Lab-only boundary maintained.**  
No canon files modified. No grammar added. No VM modified.
