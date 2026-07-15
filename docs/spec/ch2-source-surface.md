# Ch2: Source Surface and Grammar

Source PROPs: PROP-014, PROP-015; PROP-032 (bounded assumptions surface);
PROP-ENTRYPOINT (default target selector)
Status: accepted (grammar kernel); partial (OOF rejection at parse time); PROP-032 experiment-pass for compiler surface only
Proof: experiments/parser/ — 61 specs, add.ig + availability_projection.ig + polymorphic_add.ig

---

## 2.1 Guiding Constraints (PROP-014 §Guiding Constraints)

```
C-1  Syntax must map directly to SemanticIR node types.
     No syntax without a SemanticIR equivalent.
C-2  Every construct must declare its observable properties at source level.
     No implicit defaults hiding semantic choices.
C-3  The source language must be human-writable.
C-4  The source language must be agent-readable.
C-5  Parser output (ParsedProgram) is a stable JSON boundary.
     All downstream passes consume ParsedProgram, not raw source.
```

**Decision**: SemanticIR is the stable toolchain center. The parser is a frontend
pass that emits ParsedProgram. It does not own evaluation, lifecycle, or runtime.

---

## 2.2 Grammar Kernel v0 BNF (PROP-015 §Part 4)

```text
SourceFile    := ModuleDecl? ImportDecl* TopDecl*

ModuleDecl    := "module" ModPath
ImportDecl    := "import" ModPath ("." "{" Name ("," Name)* "}")?
ModPath       := Name ("." Name)*

TopDecl       := AssumptionsDecl | ContractDecl | TypeDecl | ConstDecl | FunctionDecl | ExternalDecl

AssumptionsDecl := "assumptions" "{" AssumptionDecl* "}"
AssumptionDecl  := "assumption" Name "{" AssumptionField* "}"
AssumptionField := "kind" ":" AssumptionKind
                 | "statement" StrLiteral
                 | "strength" FloatLit
                 | "source" StrLiteral
AssumptionKind  := ":heuristic"|":empirical"|":synthetic"|":calibrated"

ContractDecl  := "contract" Name "{" BodyDecl* "}"
BodyDecl      := EscapeDecl | InputDecl | ReadDecl | ComputeDecl
               | SnapshotDecl | WindowDecl | UsesAssumptionsDecl | OutputDecl

EscapeDecl    := "escape" Name
InputDecl     := "input" Name ":" TypeRef
ReadDecl      := "read"  Name ":" TypeRef "from" StrLiteral LifecycleAnn?
ComputeDecl   := "compute" Name "=" Expr
SnapshotDecl  := "snapshot" Name "=" Expr LifecycleAnn?
WindowDecl    := "window" StrLiteral "{" WindowOpt* "}"
WindowOpt     := ("kind" | "unit" | "on_close") ":" Name
UsesAssumptionsDecl := "uses" "assumptions" Name
OutputDecl    := "output" Name ":" TypeRef LifecycleAnn? EvidenceAnn?
EvidenceAnn   := "evidence" "[" Name ("," Name)* "]"
LifecycleAnn  := "lifecycle" LifecycleClass
LifecycleClass:= ":local"|":session"|":window"|":durable"|":audit"

TypeDecl      := "type" Name "{" FieldDecl* "}"
FieldDecl     := Name ":" TypeRef "?"?

ConstDecl     := "const" Name ":" TypeRef "=" ConstExpr
ConstExpr     := ScalarLiteral | ConstRef | ConstArray | ConstRecord
ConstRef      := Name
ConstArray    := "[" (ConstExpr ("," ConstExpr)*)? "]"
ConstRecord   := "{" (Name ":" ConstExpr ("," Name ":" ConstExpr)*)? "}"
ScalarLiteral:= IntLit | FloatLit | StrLiteral | BoolLit

FunctionDecl  := "def" Name "(" Params? ")" "->" TypeRef "{" Body "}"
Params        := Param ("," Param)*
Param         := Name ":" TypeRef
Body          := Stmt* Expr
Stmt          := "let" Name "=" Expr

ExternalDecl  := "external" LangId Name "{" ExternalOpt* "}"
LangId        := "ruby" | "rust" | "js" | "wasm"

TypeRef       := "Integer"|"Float"|"String"|"Bool"|"Text"|"Timestamp"|"Date"|"Symbol"
               | Name
               | "Collection[" TypeRef "]"
               | "Option["     TypeRef "]"
               | "Result["     TypeRef "," TypeRef "]"
               | "Map["        TypeRef "," TypeRef "]"

Expr          := Literal | Ref | BinOp | Call | IfExpr | BlockExpr
               | FieldAccess | IndexAccess | Lambda | ArrayLit | RecordLit
               | LetExpr

Literal       := IntLit | FloatLit | StrLiteral | BoolLit | NilLit
BinOp         := Expr Op Expr
Op            := "+" | "-" | "*" | "/" | "==" | "!=" | "<" | ">" | "<=" | ">="
               | "&&" | "||" | "++"
Call          := Name "(" (Expr ("," Expr)*)? ")"
IfExpr        := "if" Expr "{" Expr "}" ("else" "{" Expr "}")?
  -- Note: the parser accepts the tolerant shape above. V0 accepted semantics
  -- require else; a missing else produces OOF-IF2, not a parse error.
  -- Branch bodies are BlockExpr-shaped (Stmt* + final Expr), not bare Expr.
  -- See §2.2.3 for the accepted v0 source shape and required-else grammar.
BlockExpr     := "{" Stmt* Expr "}"
Lambda        := "(" Params? ")" "->" Expr | Name "->" Expr
FieldAccess   := Expr "." Name
IndexAccess   := Expr "[" Expr "]"
ArrayLit      := "[" (Expr ("," Expr)*)? "]"
RecordLit     := "{" (Name ":" Expr ("," Name ":" Expr)*)? "}"
LetExpr       := "let" Name "=" Expr   -- inside Body only
```

**Note**: This is NOT a final grammar. It is the minimal syntax kernel
sufficient to produce SemanticIR for the two canonical fixture contracts
(Add, AvailabilityProjection). Full grammar is a separate track.

**Single-output law (`OOF-RET1`)**: although the grammar admits repeated
`OutputDecl`, a v0 contract returns exactly ONE value. A contract with two or
more `output` declarations is refused at declaration typechecking with one root
`OOF-RET1` in both toolchains (Ruby canon and lab Rust). When several fields
belong together, the author defines a named result record and returns it:

```igniter
type ScoreResult { score : Integer, grade : String }

contract Score {
  input a : Integer
  compute score = a * 10
  compute grade = if a > 5 { "high" } else { "low" }
  compute result : ScoreResult = { score: score, grade: grade }
  output result : ScoreResult
}
```

The named result record is the permanent v0 law, not a temporary workaround:
the runtime returns one value per contract activation (Ch7), the SemanticIR
`outputs` array carries exactly one port for accepted value-returning
contracts (Ch6), effectful `invoke` binds one result value (Ch12), and
`recur()` already requires exactly one output (`OOF-R7`, Ch13). Zero-output
contracts keep their current behavior; their final ruling is explicitly OPEN.
Landed by LANG-CONTRACT-SINGLE-OUTPUT-LAW-P2 (2026-07-13).

**Operator semantics — `+` vs `++`**: `+` is arithmetic-only (homogeneous
numeric operands; Ch3). Concatenation is the separate `++` operator:

- `String ++ String -> String`, lowering to `stdlib.string.concat`;
- `Collection[T] ++ Collection[T] -> Collection[T]`, lowering to
  `stdlib.collection.concat`; element type mismatch refuses through the
  existing collection concat law (`OOF-COL7`).

There is no implicit number-to-text conversion and no `+` overload for text,
collections or bytes. A text-shaped `+` (e.g. `String + String`) refuses
`OOF-TY0` with an actionable hint naming `++` and string interpolation
(§2.2.4). `++` accepts the `String` spelling; `Text ++ Text` currently refuses
in both toolchains (named `concat(Text, Text)` remains the Text route — the
alias seam is tracked by the String/Text alias policy, not by `++`).
Landed by LANG-CONCAT-OPERATOR-DUAL-PARITY-P1 (2026-07-14).

## 2.2.1 Entrypoint (Implemented) and Section (Candidate)

`entrypoint ContractName` is a top-level contextual declaration with cardinality
zero-or-one per compilation unit. Both compiler pipelines resolve it to a
contract, emit it into SemanticIR and the `.igapp` manifest, and diagnose
duplicate, unknown, ambiguous, or non-contract targets with `OOF-EP*` rules.

The VM consumes the manifest entrypoint when no explicit `--entry` selector is
provided. This is selection metadata only: an effect contract still requires
normal host capability admission and policy checks. A CLI selector may override
the default for an explicit operator run.

`section` remains a Stage 3 proposal candidate and is not parser-supported.
It must not accidentally become `module`, namespace, visibility,
  lifecycle, dependency, or evaluation-order syntax. If promoted, its default
  recommended semantics are grouping-only with explicit flattening into normal
  top-level declarations.

## 2.2.3 Expression-Level if_expr v0 (R190 Internal Compiler Support)

R190 accepts expression-level `if_expr` as internal compiler support
(TypeChecker + typed SemanticIR lowering). Parser support already existed;
no new parser syntax is added.

Accepted v0 source shape:

```igniter
compute result = if condition { then_expr } else { else_expr }
```

Accepted v0 grammar (required-else form for spec purposes):

```text
IfExpr   := "if" Expr BlockExpr "else" ( IfExpr | BlockExpr )
BlockExpr := "{" BlockBody "}"
BlockBody := Stmt* Expr
```

The `else` branch may be either a `BlockExpr` (the plain form) or another
`IfExpr` (the `else if` chaining sugar; see §2.2.3.1). The chaining form is pure
surface syntax that desugars to a nested `BlockExpr` holding the trailing
`IfExpr`, so it introduces no new grammar node beyond the existing `IfExpr`.

Branch bodies are `BlockExpr`-shaped (`Stmt*` followed by a final `Expr`), not
bare expressions. The tolerant parser BNF in §2.2 uses `BlockExpr := "{" Stmt* Expr "}"`,
which subsumes this correctly. The `Stmt* Expr` structure means branches may
contain leading `let` bindings, but the final `Expr` is the value-producing
expression that the TypeChecker reads as the branch result.

Parsed AST shape:

```json
{ "kind": "if_expr", "cond": "<condition expr>", "then": "<BlockBody>", "else": "<BlockBody>" }
```

Where each `BlockBody` is:

```json
{ "stmts": [], "return_expr": "<final Expr or null>" }
```

V0 accepted semantics:

- `else` is required; a missing `else` is not accepted source semantics
  and produces `OOF-IF2` (not a parse error — the parser emits `else: null`
  to allow TypeChecker rejection).
- Condition must resolve to canonical Bool `{"name":"Bool","params":[]}`.
- Then/else branch `return_expr` must both exist (non-null) and resolve to
  the same type; see Ch3 §3.6.
- Nested `if_expr` follows the same rules at every nesting level.

### 2.2.3.1 else if chaining (source-surface sugar)

`else if` is accepted source-surface sugar that desugars to the existing nested
form. It reuses the two existing keywords `else` and `if`; no `elif` or alternate
keyword is added.

Accepted source shape:

```igniter
compute result = if c1 { a } else if c2 { b } else { c }
```

Desugaring (exact, applied recursively):

```text
if c1 { a } else if c2 { b } else { c }
  ≡  if c1 { a } else { if c2 { b } else { c } }
```

The parser rewrites `else if …` into an `else` branch whose sole value-producing
expression is the trailing `if_expr`. Consequences, all inherited (no new rule):

- **No new AST/SIR node.** The desugared tree is byte-identical to the
  hand-written nested form; the lowered SemanticIR `contracts` are equal (only
  the source-text-derived `source_hash` differs, by construction).
- **Totality preserved.** A chain with no final `else`
  (`if c1 { a } else if c2 { b }`) desugars to an inner `if` with no `else`, so
  `OOF-IF2` fires on that inner node exactly as the nested form does.
- **Diagnostics unchanged.** `OOF-IF1` (non-Bool condition), `OOF-IF3` (branch
  type mismatch), and `OOF-IF4` (empty branch) apply per link at its source span.
- **Unambiguous parse.** After `else`, one-token lookahead disambiguates: the
  `if` keyword starts a chain link; `{` starts a block. Each branch body is
  brace-delimited, so a trailing `else` binds to the nearest `if`.

Non-claims for this surface:

```text
runtime/lazy branch execution is not claimed;
else-if desugars to the nested form and adds no new SIR node or runtime semantics;
branch-local declaration scoping beyond BlockExpr is not added;
statement-level if is not supported;
public API/CLI is not widened by this surface.
```

### 2.2.4 String interpolation (source-surface sugar)

`"prefix ${expr} suffix"` is accepted parse-time sugar in both toolchains,
desugaring to left-associated nested `concat(...)` calls:

```text
"dispatch:${application_id}:${idempotency_key}"
  -> concat(concat(concat("dispatch:", application_id), ":"), idempotency_key)
```

Rules:

- `${expr}` uses the ordinary expression grammar (refs, calls, field access,
  nested strings). There is no new AST/SIR/VM node and no template runtime —
  the typechecker and emitter own everything after parse through the existing
  concat path (Ch8 §8.10).
- **Explicit-conversion law**: interpolation performs NO implicit formatting.
  `${text_value}` is accepted; `${int_to_text(n)}` is accepted; `${n}` for a
  numeric refuses through ordinary concat typing (`OOF-TY0`). Float requires
  an explicit conversion with a rounding mode.
- `SecretRef` and future protected values cannot interpolate — the existing
  concat observation refusal (`OOF-SR1` family) stays authoritative.
- Malformed interpolation refuses at parse time (`OOF-P1`, identical messages
  in both toolchains): unterminated `${`, empty `${}`, trailing tokens, or an
  invalid inner expression. Interpolation never recovers as literal text.
- **Literal `${` is HELD**: there is no escape for it. `\$` refuses
  `OOF-LEX1` (invalid string escape) in both toolchains. Representing a
  literal `${` inside a string literal is an explicit open decision; do not
  assume an escape exists.
- `const` RHS strings do NOT desugar (const expressions cannot carry calls);
  `${` in a const string stays literal bytes in both toolchains.
- Interpolation applies only to `.ig` string literals — host config, SQL,
  secrets, manifests and other non-`.ig` syntaxes are not interpolated by
  implication.

Landed by LANG-STRING-INTERPOLATION-DUAL-PARITY-P2 (2026-07-14), promoting
the Rust lab proof LAB-LANG-STRING-INTERPOLATION-SUGAR-P1.

## 2.2.2 Assumptions Surface (PROP-032 Experiment-Pass)

PROP-032 adds a bounded compiler surface:

```igniter
assumptions {
  assumption homophily {
    kind      :heuristic
    statement "People with similar beliefs interact more often."
    strength  0.70
  }
}

observed contract ScoreInteraction {
  input signal: Signal
  uses assumptions homophily
  compute rationale = homophily.statement
  output rationale: String evidence [signal, homophily]
}
```

The accepted source surface is limited to:

- one top-level `assumptions {}` block per module;
- named `assumption NAME { ... }` declarations;
- body-level `uses assumptions NAME` declarations;
- propagation of `output ... evidence [...]` lists as opaque provenance labels.

Compiler status: experiment-pass by S3-R36-C2-A for parser, classifier,
TypeChecker, and SemanticIR propagation. P28 unnamed-assumption rejection is part
of this surface. OOF-A1 undeclared-assumption detection and TASSUMP-1 strength
checks are compiler diagnostics, not runtime behavior.

Explicit exclusions: semantic validation of evidence sufficiency/freshness, runtime receipt
`assumption_refs`, runtime injection of assumption values, cross-module
assumption sharing, constraints/form/effect-surface behavior, and production
RuntimeMachine behavior are not authorized by this Ch2 sync.

---

## 2.3 ParsedProgram Shape (PROP-014 §Part 3, PROP-018 §Part 2)

The parser emits a stable JSON structure:

```json
{
  "kind": "parsed_program",
  "grammar_version": "0.1.0",
  "source_path": "source/add.ig",
  "source_hash": "sha256:<hex>",
  "module": "Lang.Examples.Add",
  "assumptions": [],
  "imports": [],
  "types": [],
  "functions": [],
  "contracts": [
    {
      "kind": "contract",
      "name": "Add",
      "escapes": [],
      "inputs": [
        { "kind": "input_decl", "name": "a", "type": "Integer" },
        { "kind": "input_decl", "name": "b", "type": "Integer" }
      ],
      "reads": [],
      "computes": [
        { "kind": "compute_decl", "name": "sum",
          "expr": { "kind": "call", "fn": "stdlib.numeric.add",
                    "args": [{"kind":"ref","name":"a"}, {"kind":"ref","name":"b"}] } }
      ],
      "outputs": [
        { "kind": "output_decl", "name": "result", "type": "Integer",
          "expr": { "kind": "ref", "name": "sum" } }
      ]
    }
  ]
}
```

**ParsedProgram is a stable boundary**: all downstream passes (classifier,
typechecker, emitter) consume ParsedProgram JSON, never raw source.

PROP-032-compatible ParsedProgram adds top-level `assumptions: []` when no
assumptions are declared, `uses_assumptions` body nodes for explicit assumption
dependencies, and parsed-only `evidence: [...]` on output nodes when present.
Validation of evidence-list membership and runtime receipt propagation remain
PROP-033 or later work.

---

## 2.4 def Blocks (PROP-015 §Part 1)

User-defined functions via `def`:

```
def clamp(value: Float, lo: Float, hi: Float) -> Float {
  if value < lo { lo }
  else { if value > hi { hi } else { value } }
}
```

**Semantic rules**:
- Non-recursive (self-reference is OOF-F1)
- Pure: no reads, no effects, no ambient state
- Inlined at the call site in SemanticIR (no lambda node in emitted IR)
- Scope: module-level or contract-local

---

## 2.5 TypeDecl (PROP-015 §Part 2)

User-defined structural record types:

```
type ProductRef {
  id:   Integer
  sku:  String
  name: String?
}
```

**Semantic rules**:
- Structural (not nominal): two types with identical fields are compatible
- Optional fields (`?`) map to `Option[T]` in TypeEnv
- TypeDecl produces a named entry in the program's TypeEnv
- `const` is a compile-time name for a scalar, record, or collection literal.
  Its annotation is mandatory and is checked with the existing type/record/
  collection rules. References may target other consts but must be acyclic.
- Const references are fully folded and inlined before SemanticIR emission.
  A const declaration emits no runtime node, storage segment, or VM opcode.
  Calls, lambdas, conditionals, operators, IO, and variant constructors are not
  part of `ConstExpr`.

---

## 2.6 Module System (PROP-015 §Part 3)

```
module Lang.Examples.Add
import Lang.Stdlib.{ fold, map, filter }
```

**Resolution rules**:
- Module path = dotted name, no filesystem path inference
- Import resolution is compile-time only
- Const names are named importable items. Project `[exports]` policy gates the
  containing module exactly as it gates types, variants, and contracts; v0 has
  no item-level export policy.
- Circular imports are OOF-M1
- Unknown import is OOF-M2

---

## 2.7 OOF Rules at Parse Stage

```
OOF-G1  Unrecognized keyword at top level
OOF-G2  Missing type annotation on input/output
OOF-G3  Malformed lifecycle class (not in LifecycleClass set)
OOF-F1  Recursive def (self-reference)
OOF-M1  Circular import
OOF-M2  Unknown import path
OOF-CONST-CYCLE    Direct or indirect const-reference cycle
OOF-CONST-UNKNOWN  Const RHS references an unknown const
OOF-CONST-LITERAL  Const RHS leaves the literal-only subgrammar
```

**Implementation gap**: The current parser (experiments/parser/) does not
yet reject all OOF-G constructs at parse time. This is a known Stage 1 gap.
