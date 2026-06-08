# PROP-020: Classifier Pass v0 Formalization

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Status: proposal
Date: 2026-05-06
Track: igniter-lang/classifier-pass-v0-formalization
Depends on: PROP-018 (pipeline), PROP-019 (canonical SemanticIR envelope)

---

## Purpose

Define the first real compiler pass after parsing:
`ParsedProgram → ClassifiedProgram`

This pass assigns fragment classes, resolves symbols, detects cycles, and
emits structured diagnostics. It does NOT infer types (that is Pass 1 / typecheck).

---

## Part 1: Input / Output Contract

```text
Input:  ParsedProgram  (from parser; canonical JSON per PROP-014/015/019)
Output: ClassifiedProgram

ClassifiedProgram = {
  kind:             "classified_program",
  format_version:   "0.1.0",
  program_id:       String,          -- same as ParsedProgram.program_id
  grammar_version:  String,
  source_hash:      String,
  module:           String | nil,
  symbol_table:     SymbolTable,
  contracts:        [ClassifiedContract],
  diagnostics:      [Diagnostic],
  pass_result:      "ok" | "oof" | "error"
}
```

`pass_result`:
- `"ok"` — all contracts are `:core` or `:escape`; no OOF entries
- `"oof"` — at least one OOF diagnostic; classifier completed but output is not emittable
- `"error"` — classifier could not complete (malformed ParsedProgram)

---

## Part 2: SymbolTable

Built before classifying any contract. Two scopes: program-level and contract-local.

```text
SymbolTable = {
  program_scope: { <name>: SymbolEntry },   -- imports, type aliases, functions
  contract_scopes: {
    <ContractName>: { <name>: SymbolEntry }
  }
}

SymbolEntry = {
  name:    String,
  kind:    "input" | "output" | "compute" | "const" | "read" | "snapshot" |
           "escape" | "import" | "type" | "function" | "pipeline",
  type_annotation: TypeRef | nil,    -- from parser; not yet resolved
  declared_at: String                -- e.g. "contract:Add/input:a"
}
```

**[D] Symbol resolution is strict.** Any name reference not found in the contract scope or program scope is OOF-P1.

**[D] Pipeline names are added to program_scope with `kind: "pipeline"`.** They may not appear inside a contract body — OOF-P2.

---

## Part 3: Node Classification Rules

Each body node receives a `fragment_class` tag: `:core`, `:escape`, or `:oof`.

### InputDecl → always `:core`

```text
ClassifiedInput = {
  kind: "input", name: String, type_annotation: TypeRef,
  fragment_class: "core"
}
```

### OutputDecl → `:core` if source is `:core`; `:escape` if source is `:escape`

```text
fragment_class = resolve_ref(output.name, contract_scope).fragment_class
```

### ConstDecl → always `:core`

Literal values have no ambient dependency. `fragment_class: "core"`.

### EscapeDecl → always `:escape` boundary

```text
ClassifiedEscape = {
  kind: "escape", name: String,
  fragment_class: "escape",
  boundary_kind: "declared"
}
```

### ReadDecl → `:escape` (TBackend read) unless `tenant_free: true` AND lifecycle is `:durable`

```text
If tenant_free AND lifecycle in [:durable, :window] AND no live_stream:
  fragment_class: "core"   -- pure cache read; CORE-safe
Else:
  fragment_class: "escape"

If scoped_by is present but ref does not resolve to a declared input:
  fragment_class: "oof", diagnostics += OOF-P1
```

### SnapshotDecl → inherits from its expr

```text
fragment_class = classify_expr(snapshot.expr, contract_scope).fragment_class
```

### ComputeDecl → propagation

```text
deps = all name refs in expr
dep_classes = deps.map { |d| resolve_ref(d, contract_scope)&.fragment_class }

if dep_classes.any? { :oof }  -> fragment_class: "oof"  (OOF propagates)
if dep_classes.any? { :escape } -> fragment_class: "escape"
else -> fragment_class: "core"

Unresolved dep -> OOF-P1; fragment_class: "oof"
```

### Call expr classification

```text
stdlib.* calls: CORE if all args are :core
user def calls: CORE if FunctionDecl is :core AND all args are :core
unknown fn:     OOF-P1; fragment_class: "oof"
```

### FieldAccess (Expr.field notation)

```text
If Expr resolves to a record type -> CORE (if expr is CORE)
If Expr is unresolved -> OOF-P1
FieldAccess on a live stream -> ESCAPE
```

---

## Part 4: OOF Detection Rules

### OOF-P1: Unresolved symbol

```text
Trigger: any name ref (compute dep, call fn, scoped_by ref, read from-template var)
  that does not appear in contract_scope or program_scope.
Severity: error
Node:     the compute/read/snapshot node containing the ref
```

### OOF-P2: Pipeline inside contract body

```text
Trigger: a ParsedProgram.contracts[i].body node whose kind is "step" or "pipeline".
  (Should not reach classifier if parser is correct; defensive check.)
Severity: error
Node:     the offending body node
```

### OOF-P4: Compute cycle

```text
Trigger: dependency graph of compute nodes contains a cycle.
Algorithm: Kahn's topological sort; if nodes remain after sort, cycle detected.
Severity: error
Node:     the set of nodes forming the cycle (report all)
```

### OOF-CE4: ConfidenceLabel used as Bool

```text
Trigger: a ComputeDecl whose type_annotation is Bool AND whose expr
  references a node whose type_annotation is ConfidenceLabel.
Detection: type_annotation string comparison (full type inference is Pass 1;
  classifier uses declared annotations only, not inferred types).
Severity: error
Node:     the compute node
```

### OOF-OS2: Evidence-less alert

```text
Trigger: a node whose type_annotation contains "EvidenceLinkedAlert" or
  "ReputationSignal" AND whose expr does not pass at least one
  signal_refs or claim_refs argument (CallExpr args inspection).
Detection: structural; classifier checks that the call includes named args
  signal_refs and claim_refs with non-empty array literals or ref args.
  If args are refs (not inline literals), deferred to Pass 1.
Severity: error
Node:     the compute node producing the alert
```

---

## Part 5: ClassifiedContract Shape

```json
{
  "kind":           "classified_contract",
  "contract_name":  "Add",
  "fragment_class": "core",
  "nodes": [
    {
      "kind":           "input",
      "name":           "a",
      "type_annotation": "Integer",
      "fragment_class": "core"
    },
    {
      "kind":           "compute",
      "name":           "sum",
      "type_annotation": "Integer",
      "fragment_class": "core",
      "deps":           ["a", "b"],
      "expr_class":     "core"
    }
  ],
  "escape_boundaries": [],
  "diagnostics": []
}
```

`contract.fragment_class` = max severity of all node classes:
`"oof"` > `"escape"` > `"core"`

---

## Part 6: Diagnostics Shape

```json
{
  "rule":     "OOF-P1",
  "severity": "error",
  "message":  "Unresolved symbol: missing_b",
  "node":     "sum",
  "path":     "contract:Add/compute:sum/ref:missing_b",
  "line":     null
}
```

```text
Severity levels: "error" | "warning" | "info"
  error   -> forces pass_result: "oof"; blocks SemanticIR emission
  warning -> pass_result remains "ok" if no errors
  info    -> advisory only

path format: "contract:<Name>/<kind>:<name>/..."
  Allows precise location without requiring line numbers.
  line is integer from parser token, or null if not available.
```

---

## Part 7: CORE / ESCAPE / OOF Propagation Summary

```text
Propagation order (bottom-up through dependency graph):

1. Leaf nodes (inputs, consts, escapes): assign directly.
2. Compute nodes: classify after all deps classified (topological order).
3. Output nodes: inherit from resolved source.
4. Contract: max of all node classes.
5. Program: if any contract is :oof -> pass_result: "oof".

Propagation rule:
  :oof   beats :escape beats :core
  One :oof dep -> whole compute is :oof (OOF propagates upward)
  One :escape dep -> compute is :escape (unless :oof present)
```

---

## Part 8: Conformance Cases

### CC-1: Pure CORE (add.ig)

```text
Input: ParsedProgram for Add contract (inputs: a:Integer, b:Integer; compute sum)
Expected ClassifiedProgram:
  pass_result: "ok"
  contracts[0].fragment_class: "core"
  all nodes: fragment_class: "core"
  diagnostics: []
```

### CC-2: Unresolved symbol (OOF-P1)

```text
Input: compute sum = stdlib.integer.add(a, missing_b)  -- missing_b not declared
Expected:
  pass_result: "oof"
  diagnostics: [{ rule: "OOF-P1", node: "sum", path: "contract:.../ref:missing_b" }]
  contracts[0].fragment_class: "oof"
```

### CC-3: Compute cycle (OOF-P4)

```text
Input: compute x = f(y); compute y = g(x)
Expected:
  pass_result: "oof"
  diagnostics: [{ rule: "OOF-P4", node: "x,y", message: "Compute cycle detected" }]
```

### CC-4: Scoped read (ESCAPE)

```text
Input: tenant_availability_projection.ig (reads with scoped_by)
Expected:
  pass_result: "ok"
  reads: fragment_class: "escape"
  contract.fragment_class: "escape"
  diagnostics: []
```

### CC-5: OOF-CE4 (confidence as Bool)

```text
Input: compute gate: Bool = confidence_label  -- type_annotation Bool, source ConfidenceLabel
Expected:
  pass_result: "oof"
  diagnostics: [{ rule: "OOF-CE4", node: "gate" }]
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/classifier-pass-v0-formalization
Status: done

[D] Decisions:
- ClassifiedProgram output shape defined. pass_result: ok | oof | error.
- SymbolTable has two scopes: program (imports, types, functions) and
  per-contract. Pipeline names in program scope; OOF-P2 if used in body.
- Node classification: Input/Const/Escape -> direct. Read -> escape (unless
  tenant_free+durable). Compute -> propagates from deps (oof > escape > core).
- OOF propagates upward: one OOF dep -> whole compute chain is OOF.
- Five OOF rules formalized at classifier level: OOF-P1/P2/P4/CE4/OS2.
- Diagnostics shape: rule, severity, message, node, path, line.
  path format: "contract:<Name>/<kind>:<name>/..."
- error severity -> blocks SemanticIR emission. warning -> ok continues.
- Five conformance cases: CC-1 (CORE add), CC-2 (OOF-P1), CC-3 (OOF-P4 cycle),
  CC-4 (ESCAPE scoped read), CC-5 (OOF-CE4).

[Files] Changed:
- igniter-lang/docs/proposals/PROP-020-classifier-pass-v0-formalization.md [NEW]
- igniter-lang/docs/README.md  [updated]
- igniter-lang/docs/agent-motion.md  [updated]

[Next]:
- [Research Agent]: implement ClassifierPass experiment in
  igniter-lang/experiments/classifier/ for CC-1..CC-5.
  Input: ParsedProgram JSON. Output: ClassifiedProgram JSON.
- [Compiler/Grammar Expert]: typecheck-pass-v0
  Define Pass 1: ClassifiedProgram -> TypedProgram.
  Decimal scale inference, ConfidenceLabel propagation, evidence gate checks.
```
