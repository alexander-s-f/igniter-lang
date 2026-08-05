# Ch2 Appendix: EBNF Grammar Specification

This appendix defines the formal EBNF (Extended Backus-Naur Form) grammar for `igniter-lang`, extracted directly from the parser implementation of the reference compiler toolchain.

---

## 1. Syntax Notation

- Symbols in double quotes `""` represent literal terminal tokens (keywords, operators).
- Syntax options are separated by the pipe character `|`.
- Optional constructs are enclosed in parentheses followed by a question mark `()?` or brackets `[]`.
- Zero-or-more repetitions are enclosed in parentheses followed by an asterisk `()*`.
- One-or-more repetitions are enclosed in parentheses followed by a plus `()+`.

---

## 2. Program Structure

```ebnf
SourceFile      ::= ModuleDecl? ImportDecl* TopDecl*

ModuleDecl      ::= "module" ModPath
ImportDecl      ::= "import" ModPath ("." "{" Name ("," Name)* "}")?
ModPath         ::= Name ("." Name)*

TopDecl         ::= AssumptionsDecl
                  | ContractDecl
                  | ConstructorDecl
                  | TypeDecl
                  | VariantDecl
                  | ConstDecl
                  | FunctionDecl
                  | ExternalDecl
                  | TraitDecl
                  | ImplDecl
                  | ContractShapeDecl
                  | PipelineDecl
                  | OlapPointDecl
```

---

## 3. Top-Level Declarations

### 3.0 Module Constants
```ebnf
ConstDecl        ::= "const" Name ":" TypeRef "=" ConstExpr
ConstExpr        ::= ScalarLiteral | Name | ConstArray | ConstRecord
ConstArray       ::= "[" (ConstExpr ("," ConstExpr)*)? "]"
ConstRecord      ::= "{" (Name ":" ConstExpr ("," Name ":" ConstExpr)*)? "}"
ScalarLiteral   ::= IntLit | FloatLit | StrLiteral | BoolLit
```

Const `Name` references resolve only to module-local or explicitly imported
const declarations and must form a DAG. Resolution substitutes fully folded
literal trees before SemanticIR emission; there is no const runtime node.

### 3.1 Traits & Polymorphism
```ebnf
TraitDecl         ::= "trait" Name ("[" TypeParams "]")? "{" TraitMethod* "}"
TypeParams        ::= Name ("," Name)*
TraitMethod       ::= "def" Name "(" Params? ")" "->" TypeRef

ImplDecl          ::= "impl" QualifiedRef "[" TypeRef "]" "using" QualifiedRef
QualifiedRef      ::= Name ("." Name)*

ContractShapeDecl ::= "contract_shape" Name ("[" TypeParams "]")? "{" ShapeBodyDecl* "}"
ShapeBodyDecl     ::= InputDecl | OutputDecl
```

### 3.2 Assumptions
```ebnf
AssumptionsDecl   ::= "assumptions" "{" AssumptionDecl* "}"
AssumptionDecl    ::= "assumption" Name "{" AssumptionField* "}"
AssumptionField   ::= "kind" ":" AssumptionKind
                    | "statement" StrLiteral
                    | "strength" FloatLit
                    | "source" StrLiteral
AssumptionKind    ::= ":heuristic" | ":empirical" | ":synthetic" | ":calibrated"
```

### 3.3 Pipelines & OLAP
```ebnf
PipelineDecl      ::= "pipeline" Name "[" TypeRef "," TypeRef "," TypeRef "]" "{" StepDecl* "}"
StepDecl          ::= "step" Name ":" QualifiedRef

OlapPointDecl     ::= "olap_point" Name "{" OlapClause* "}"
OlapClause        ::= "dimensions" ":" "{" (Name ":" TypeRef ("," Name ":" TypeRef)*)? "}"
                    | "measure" ":" TypeRef
                    | "granularity" ":" "{" (Name ":" Symbol ("," Name ":" Symbol)*)? "}"
                    | "source" ":" RawExpr
                    | "indexed" ":" "{" (Name ("," Name)*)? "}"
```

### 3.4 Contracts
```ebnf
ConstructorDecl   ::= "constructor" Name "->" ConstructorOutput
ConstructorOutput ::= "(" Name ":" TypeRef ")"
                       -- contextual, implicitly pure, modifier-free and body-free;
                       -- the output target must be a visible, non-generic,
                       -- non-recursive, non-empty record TypeDecl.
                       -- Before classification/typechecking it lowers to the
                       -- ordinary signature-bound pure ContractDecl whose inputs
                       -- and punned record body follow TypeDecl field order.

ContractDecl      ::= "contract" Name ("[" ContractTypeParams "]")? ("implements" QualifiedRef ("[" TypeRef "]")?)?
                      ( ContractSignature "{" SigBinding* "}"
                      | ContractSignature "=" Expr
                      | "{" BodyDecl* "}" )
ContractTypeParams::= ContractTypeParam ("," ContractTypeParam)*
ContractTypeParam ::= Name ":" QualifiedRef

ContractSignature ::= SigParamList "->" SigParamList
SigParamList      ::= "(" (Name ":" TypeRef ("," Name ":" TypeRef)*)? ")"
SigBinding        ::= Name (":" TypeRef)? "=" Expr
                      -- signature-bound contract: `pure contract C(a: X) -> (out: Y) { out = expr }`
                      -- is pure parse-time sugar — the signature inputs desugar to `input`
                      -- decls, each body binding to a `compute` decl, and the signature
                      -- outputs to `output` decls (identical AST/SIR to the explicit form).
                      -- Every signature output must be bound exactly once in the body; an
                      -- output binding may omit its type (inherited from the signature).
                      -- `<-` boundary bindings, `?`, inferred outputs, named/default
                      -- arguments stay closed. The one-output law (OOF-RET1) applies
                      -- unchanged. LANG-SIGNATURE-BOUND-CONTRACT-CANON-PARITY-P1
                      -- The expression alternative is pure-only and requires exactly
                      -- one explicitly named signature output. `= expr` lowers exactly
                      -- as `{ output_name = expr }`. Missing/zero/multiple outputs,
                      -- effect/read contracts, inferred output names, and `-> Type`
                      -- shorthand stay closed. LANG-PURE-CONTRACT-EXPRESSION-BODY-P1
```

### 3.5 App-local Functions
```ebnf
FunctionDecl      ::= "def" Name "(" Params? ")" "->" TypeRef ("decreases" "fuel")? "{" FnBody "}"
FnBody            ::= Stmt* Expr
```

`decreases fuel` is the optional compile-time recursion-law token (PROP-051):
required on every member of a nontrivial call-graph SCC (`OOF-L4`), with no
independent runtime fuel. `Params`, `Param`, and `Stmt` are defined in §6
(Expressions). See ch2 §2.4 for the semantic rules (identity, collision,
visibility, purity, and SIR registry emission).

---

## 4. Contract Body Declarations

```ebnf
BodyDecl          ::= InputDecl
                    | OutputDecl
                    | ReadDecl
                    | ComputeDecl
                    | SnapshotDecl
                    | WindowDecl
                    | UsesAssumptionsDecl
                    | EscapeDecl
                    | InvariantDecl
                    | StreamDecl
                    | FoldStreamDecl

InputDecl         ::= "input" Name ":" TypeRef
OutputDecl        ::= "output" Name ":" TypeRef LifecycleAnn? EvidenceAnn?
ReadDecl          ::= "read" Name ":" TypeRef "from" StrLiteral ReadModifier*
ComputeDecl       ::= "compute" Name "=" Expr
SnapshotDecl      ::= "snapshot" Name "=" Expr LifecycleAnn?
WindowDecl        ::= "window" StrLiteral "{" WindowOpt* "}"
UsesAssumptionsDecl::= "uses" "assumptions" Name
EscapeDecl        ::= "escape" Name
InvariantDecl     ::= "invariant" Name "{" InvariantAttr* "}"
StreamDecl        ::= "stream" Name ":" TypeRef
FoldStreamDecl    ::= "fold_stream" Name "=" Expr StreamBound?

ReadModifier      ::= "lifecycle" LifecycleClass
                    | "scoped_by" Name
                    | "cardinality" Cardinality
                    | "schema_version" StrLiteral
                    | "tenant_free"

Cardinality       ::= IntLit ".." IntLit
LifecycleAnn      ::= "lifecycle" LifecycleClass
LifecycleClass    ::= ":local" | ":session" | ":window" | ":durable" | ":audit"
EvidenceAnn       ::= "evidence" "[" Name ("," Name)* "]"

WindowOpt         ::= ("kind" | "unit" | "on_close") ":" Name
StreamBound       ::= "@window_bounded" | "@count_bounded" "(" IntLit ")"

InvariantAttr     ::= "predicate" ":" Name
                    | "severity" ":" Symbol
                    | "label" ":" (StrLiteral | Name)
                    | "message" ":" (StrLiteral | Name)
                    | "overridable_with" ":" (Symbol | Name)
```

---

## 5. Types & Signatures

```ebnf
TypeDecl          ::= "type" Name "{" FieldDecl* "}"
FieldDecl         ::= Name ":" TypeRef "?"?
VariantDecl       ::= "variant" Name "{" VariantArmDecl* "}"
VariantArmDecl    ::= Name ("{" FieldDecl* "}")? ","?

TypeRef           ::= "Integer" | "Float" | "String" | "Bool" | "Timestamp" | "Date" | "Symbol"
                    | Name
                    | "Collection[" TypeRef "]"
                    | "Option[" TypeRef "]"
                    | "Result[" TypeRef "," TypeRef "]"
                    | "Map[" TypeRef "," TypeRef "]"
```

---

## 6. Expressions

```ebnf
Expr              ::= Literal
                    | Ref
                    | BinOp
                    | Call
                    | NamedConstruct
                    | MatchExpr
                    | IfExpr
                    | BlockExpr
                    | FieldAccess
                    | IndexAccess
                    | Lambda
                    | ArrayLit
                    | RecordLit
                    | LetExpr

Literal           ::= IntLit | FloatLit | StrLiteral | BoolLit | NilLit
Ref               ::= Name
BinOp             ::= Expr Op Expr
Op                ::= "+" | "-" | "*" | "/" | "==" | "!=" | "<" | ">" | "<=" | ">="
                    | "&&" | "||" | "++"
Call              ::= Name "(" (Expr ("," Expr)*)? ")"
NamedConstruct    ::= Name "{" (NamedField ("," NamedField)*)? "}"
                    | Name "::" Name "{" (NamedField ("," NamedField)*)? "}"
NamedField        ::= Name (":" Expr)?
                      -- For a visible ConstructorDecl, this is an exact-field,
                      -- order-independent invocation. Punned and explicit fields
                      -- may mix. The pre-classify lowerer reorders expressions by
                      -- target TypeDecl field order and emits call_contract.
                      -- Missing/extra fields are OOF-CTOR7/8; duplicate fields
                      -- remain OOF-P1; constructor/variant ambiguity is OOF-CTOR5.
                      -- Positional natural Call to a constructor is OOF-CTOR4;
                      -- literal call_contract remains the explicit escape hatch.
                      -- `Variant::Arm { ... }` is explicit variant identity and
                      -- bypasses constructor arbitration. Dotted
                      -- `Module.Variant::Arm { ... }` and `Module.Name { ... }`
                      -- remain held in v0.
MatchExpr         ::= "match" Expr "{" (MatchArm ","?)* "}"
MatchArm          ::= MatchPattern "=>" Expr
MatchPattern      ::= "_" | (Name "::")? Name ("{" (Name ("," Name)*)? "}")?
IfExpr            ::= "if" Expr BlockExpr ("else" (IfExpr | BlockExpr))?
                      -- `else if` is surface sugar desugaring to `else { if ... }`; see ch2 §2.2.3.1
BlockExpr         ::= "{" Stmt* Expr "}"
Lambda            ::= "(" Params? ")" "->" Expr | Name "->" Expr
FieldAccess       ::= Expr "." Name
IndexAccess       ::= Expr "[" Expr "]"
ArrayLit          ::= "[" (Expr ("," Expr)*)? "]"
RecordLit         ::= "{" (RecordField ("," RecordField)*)? "}"
RecordField       ::= Name ":" Expr
                    | Name
                      -- field punning: `{ name }` is pure parse-time sugar for
                      -- `{ name: name }` (value = Ref(name)); punned and explicit
                      -- fields mix freely. Dotted/keypath punning (`{ a.b }`),
                      -- string keys, and duplicate field names are rejected.
                      -- LANG-RECORD-FIELD-PUNNING-CANON-PARITY-P1
LetExpr           ::= "let" Name "=" Expr

Stmt              ::= "let" Name "=" Expr
Params            ::= Param ("," Param)*
Param             ::= Name ":" TypeRef
```
