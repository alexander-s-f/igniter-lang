# PROP-023: Classified Expression Boundary Formalization v0

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Status: proposal
Date: 2026-05-06
Track: igniter-lang/classified-expr-boundary-formalization-v0
Amends: PROP-020 (Classifier Pass), PROP-021 (TypeChecker Pass)

---

## Purpose

Decide whether `ClassifiedProgram` should carry raw `ParsedProgram` expr AST
or emit normalized `ClassifiedExpr` nodes. Formalize the boundary table
so TypeChecker and future emitter can treat `ClassifiedProgram` as a
stable, self-contained pass input.

---

## Part 1: Decision

**[D] ClassifiedProgram v0 carries a normalized `ClassifiedExpr` — not the raw ParsedProgram expr AST.**

Rationale:

```text
Raw ParsedProgram AST in ClassifiedProgram:
  + No transformation cost.
  - TypeChecker must re-walk raw AST and redo fragment tagging.
  - OOF tagging lives in the node, not the expr — TypeChecker can't trust it.
  - Pass boundary blurs as the compiler grows: classifier and typechecker
    become coupled to the same AST node shapes.

Normalized ClassifiedExpr:
  + Each expr node carries its fragment_class tag inline.
  + TypeChecker receives a single, stable input shape.
  + Source span is preserved as an optional annotation (not required for v0 proof).
  + OOF exprs are explicit ClassifiedExpr nodes with oof_rule field.
  + Adds one transformation step (trivial for v0 expr set).
```

**[D] `ClassifiedExpr` is a normalized expr tree. Raw `ParsedProgram` expr (`ExprNode`) must not be forwarded into `ClassifiedProgram` body nodes.**

---

## Part 2: Boundary Table

```text
ParsedProgram ExprNode        ClassifiedExpr kind      TypedExpr kind
────────────────────────────  ───────────────────────  ─────────────────────────
{ kind: "literal", value, type }
                              CExpr::Literal            TExpr::Literal
                              { kind: :literal          { kind: :literal
                                value, lit_type           value, type: TypeRef
                                fragment: :core }         resolved_type: TypeRef }

{ kind: "ref", name }
  resolved in scope         -> CExpr::Ref              TExpr::Ref
                              { kind: :ref              { kind: :ref
                                name                      name
                                fragment: :core|:escape   resolved_type: TypeRef }
                                dep: String }
  unresolved               -> CExpr::OofRef            (not reached; pass_result: oof)
                              { kind: :oof_ref
                                name
                                oof_rule: "OOF-P1" }

{ kind: "call", fn, args }
  fn in OperatorEnv/FnDecl -> CExpr::Call              TExpr::Call
                              { kind: :call             { kind: :call
                                fn                        fn (monomorphic)
                                args: [ClassifiedExpr]    args: [TypedExpr]
                                fragment: :core|:escape   resolved_type: TypeRef }
  fn unresolved            -> CExpr::OofCall
                              { kind: :oof_call
                                fn
                                oof_rule: "OOF-P1" }

{ kind: "field_access", expr, field }
  expr resolved, field ok  -> CExpr::FieldAccess       TExpr::FieldAccess
                              { kind: :field_access     { kind: :field_access
                                expr: ClassifiedExpr      expr: TypedExpr
                                field: String             field: String
                                fragment: :core|:escape   resolved_type: TypeRef }
  field unknown/non-record -> CExpr::OofFieldAccess
                              { kind: :oof_field_access
                                expr, field
                                oof_rule: "OOF-TC4" }

{ kind: "record", fields }
  all fields resolved      -> CExpr::Record             TExpr::Record
                              { kind: :record           { kind: :record
                                fields: {name:CExpr}      fields: {name:TExpr}
                                fragment: :core|:escape   resolved_type: TypeRef }
```

---

## Part 3: ClassifiedExpr Shape (JSON)

All `ClassifiedExpr` variants share a `fragment_class` field.
OOF variants add `oof_rule` and do NOT carry `fragment_class` (they are rejected).

```json
CExpr::Literal:
{ "kind": "literal", "value": 42, "lit_type": "int", "fragment_class": "core" }

CExpr::Ref:
{ "kind": "ref", "name": "a", "dep": "input:a", "fragment_class": "core" }

CExpr::Call:
{ "kind": "call",
  "fn": "stdlib.integer.add",
  "args": [ <CExpr>, <CExpr> ],
  "fragment_class": "core" }

CExpr::FieldAccess:
{ "kind": "field_access", "expr": <CExpr>, "field": "company_id",
  "fragment_class": "escape" }

CExpr::Record:
{ "kind": "record",
  "fields": { "x": <CExpr>, "y": <CExpr> },
  "fragment_class": "core" }

CExpr::OofRef:
{ "kind": "oof_ref", "name": "missing_b", "oof_rule": "OOF-P1" }

CExpr::OofCall:
{ "kind": "oof_call", "fn": "unknown_fn", "oof_rule": "OOF-P1" }

CExpr::OofFieldAccess:
{ "kind": "oof_field_access", "expr": <CExpr>, "field": "bad",
  "oof_rule": "OOF-TC4" }
```

**[D] `fragment_class` on `ClassifiedExpr` propagates bottom-up:**

```text
Literal  -> always :core
Ref      -> inherits dep node's fragment_class
Call     -> max(all arg fragment_class; :core if all :core, :escape if any :escape)
FieldAccess -> inherits expr.fragment_class (or :escape if field is ESCAPE source)
Record   -> max of all field expr fragment_class
```

---

## Part 4: ClassifiedNode Body Shape (Revised)

Body nodes in `ClassifiedContract.nodes` now carry `ClassifiedExpr` instead of raw expr:

```json
{
  "kind": "compute",
  "name": "sum",
  "type_annotation": "Integer",
  "fragment_class": "core",
  "deps": ["a", "b"],
  "expr": {
    "kind": "call",
    "fn": "stdlib.integer.add",
    "args": [
      { "kind": "ref", "name": "a", "dep": "input:a", "fragment_class": "core" },
      { "kind": "ref", "name": "b", "dep": "input:b", "fragment_class": "core" }
    ],
    "fragment_class": "core"
  }
}
```

For an OOF node (e.g. unresolved symbol):

```json
{
  "kind": "compute",
  "name": "sum",
  "type_annotation": "Integer",
  "fragment_class": "oof",
  "deps": ["a", "missing_b"],
  "expr": {
    "kind": "call",
    "fn": "stdlib.integer.add",
    "args": [
      { "kind": "ref", "name": "a", "dep": "input:a", "fragment_class": "core" },
      { "kind": "oof_ref", "name": "missing_b", "oof_rule": "OOF-P1" }
    ],
    "fragment_class": "oof"
  }
}
```

---

## Part 5: What TypeChecker Requires from ClassifiedProgram

TypeChecker is guaranteed by this contract:

```text
From ClassifiedProgram, TypeChecker receives:
  1. symbol_table (SymbolTable from PROP-020) — for type_annotation lookups.
  2. ClassifiedContract.nodes — all body nodes with ClassifiedExpr (not raw AST).
  3. Each ClassifiedExpr carries fragment_class — TypeChecker need not re-classify.
  4. OOF exprs are explicit (oof_ref / oof_call / oof_field_access kinds).
     TypeChecker skips type inference on OOF exprs; they are already failing.
  5. type_annotation is a string or structured TypeRef — same as PROP-021 defined.

TypeChecker must NOT depend on:
  - Raw ParsedProgram ExprNode fields (kind: "literal", type: "int" string form).
  - ParsedProgram.parse_errors (already surfaced in classifier diagnostics).
  - Any field not present on ClassifiedExpr.
```

---

## Part 6: Source Span Preservation

**[D] Source spans (line/column) are optional annotation in v0.**

```text
If the parser emits line numbers on ExprNodes, the classifier MAY propagate them
as an optional "span" field on ClassifiedExpr:

{ "kind": "ref", "name": "a", "dep": "input:a", "fragment_class": "core",
  "span": { "line": 4, "col": 22 } }

span is never required. TypeChecker must not fail if span is absent.
Diagnostics use "line" from span when available; null otherwise.
```

---

## Part 7: Acceptance Checklist

```text
☐ CE-1: ClassifiedProgram.contracts[i].nodes[j].expr is a ClassifiedExpr
         (kind is one of: literal, ref, call, field_access, record,
          oof_ref, oof_call, oof_field_access).
         Raw ParsedProgram ExprNode kinds ("literal" with type string, etc.)
         must not appear.

☐ CE-2: CExpr::Ref carries "dep" pointing to the declaring node
         ("input:<name>", "compute:<name>", "const:<name>", etc.)

☐ CE-3: CExpr fragment_class propagates correctly:
         pure literal chain -> all :core
         chain through escape Read -> :escape at FieldAccess and above

☐ CE-4: OOF expr (oof_ref, oof_call) causes parent node fragment_class: "oof"
         and parent contract fragment_class: "oof".

☐ CE-5: TypeChecker proof reads ClassifiedExpr only (not ParsedProgram ExprNode).
         TypeChecker proof must not import or reference parser ExprNode shapes.

☐ CE-6: OOF expr nodes are skipped by TypeChecker type inference.
         OOF diagnostic from classifier is forwarded; no new type error added.

☐ CE-7: Span field is optional; TypeChecker proof works with and without it.
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/classified-expr-boundary-formalization-v0
Status: done

[D] Decisions:
- ClassifiedProgram carries ClassifiedExpr (normalized), NOT raw ParsedProgram ExprNode.
- Seven CExpr kinds: literal, ref, call, field_access, record, oof_ref, oof_call,
  oof_field_access.
- CExpr carries fragment_class (core/escape) or oof_rule (for OOF variants).
- fragment_class propagates bottom-up: Literal=core; Ref=dep class;
  Call=max(args); FieldAccess=inherits expr; Record=max(fields).
- CExpr::Ref carries "dep" pointer to declaring node.
- TypeChecker receives only ClassifiedExpr; must not depend on raw ParsedProgram shapes.
- OOF exprs are explicit; TypeChecker skips them; forwards classifier diagnostic.
- Source spans optional; never required; propagated as "span": { line, col }.
- 7-item acceptance checklist: CE-1..CE-7.

[Files] Changed:
- igniter-lang/docs/proposals/PROP-023-classified-expr-boundary-v0.md [NEW]
- igniter-lang/docs/agent-motion.md  [updated]

[Next]:
- [Research Agent]: Update classifier experiment to emit ClassifiedExpr
  per this spec before starting TypeChecker proof.
  CE-1..CE-7 checklist applies to the classifier output.
- [Research Agent]: TypeChecker proof (PROP-021) may then read ClassifiedExpr
  with confidence that no raw ExprNode shapes are present.
```
