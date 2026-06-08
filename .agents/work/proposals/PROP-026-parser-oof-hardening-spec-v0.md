# PROP-026: Parser OOF Hardening Spec v0

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Status: closed
Closed: 2026-05-07 (Stage 2 — experiment PASS, META-EXPERT-009.1)
Date: 2026-05-07
Track: igniter-lang/parser-oof-hardening-spec-v0
Depends on: PROP-018 (pipeline), PROP-020 (classifier), PROP-021 (typechecker)

---

## Purpose

Govern which OOF rules belong to the parser vs later passes.
Define exact parser hardening targets for Stage 2 without moving
semantic rules into the parser.

---

## Part 1: OOF Classification Principle

```text
Syntax OOF:   Parser owns. The token stream is structurally invalid.
              No valid parse tree can be produced for this input.
              Must emit parse_error and stop the contract.

Semantic OOF: Classifier or TypeChecker owns. The token stream is valid
              but the declared meaning is illegal.
              Parser MUST NOT reject these; it emits a valid (partial) AST.

Optional early diagnostic: Parser MAY emit a warning but must not block.
              Useful for obvious structural anomalies that are almost always errors
              but could in principle be valid in a future grammar version.
```

**[D] The parser must not own semantic OOF rules.** Moving OOF-P1 (unresolved symbol), OOF-OS2 (evidence-less alert), or OOF-CE4 (ConfidenceLabel as Bool) into the parser would require the parser to maintain a symbol table and type environment — that is classifier/typechecker work. This coupling is prohibited.

---

## Part 2: OOF Rule Ownership Matrix

```text
OOF Rule  Description                              Owner        Justification
────────  ───────────────────────────────────────  ───────────  ──────────────────────────────
OOF-P1    Unresolved symbol                         Classifier   Requires symbol table (built by classifier)
OOF-P2    pipeline/step inside contract body        PARSER ✓     Syntactic context: parser knows it's inside a contract
OOF-P3    Cross-module ref without import           Classifier   Requires module graph
OOF-P4    Compute cycle                             Classifier   Requires dep graph traversal (Kahn)
OOF-TC1   Annotation/inferred type mismatch         TypeChecker  Requires type inference
OOF-TC2   Output type mismatch                      TypeChecker  Requires type inference
OOF-TC3   Operator arity mismatch                   TypeChecker  Requires OperatorEnv lookup
OOF-TC4   Field access on non-record                TypeChecker  Requires type inference
OOF-TC5   Decimal scale violation                   TypeChecker  Requires parameterized type arithmetic
OOF-CE4   ConfidenceLabel as Bool                   TypeChecker  Requires type inference
OOF-DM1   Decimal scale mismatch in add             TypeChecker  Requires type inference
OOF-DM2   Float as Decimal proxy                    TypeChecker  Requires type inference
OOF-DM3   Decimal annotation missing scale          PARSER ✓     Syntactic: Decimal without [N] is structurally incomplete
OOF-DM4   Division without result_scale literal     TypeChecker  Requires expression shape + literal check
OOF-OS2   Evidence-less alert                       Classifier   Requires structural call arg inspection
OOF-OS3   Citation missing when citation_required   Classifier   Requires policy lookup
OOF-OS4   Missing temporal window or valid_until    Classifier   Requires structural call arg inspection
OOF-MD1   Prose-only acceptance (review_only exec)  Runtime      Cannot check at parse time
OOF-MD2   Stale review (diff_hash mismatch)         Runtime      Hash is computed at acceptance time
OOF-MD5   Nil review_projection_ref                 Classifier   Requires structural record check
OOF-MR1   Duplicate migration receipt               Classifier   Requires provenance graph
OOF-SP1   Missing specialization source             Classifier   Requires manifest/build context
OOF-PG1   Pipeline with no steps                   PARSER ✓     Syntactic: empty step block detectable at parse
OOF-PG2   Step with no contract ref                PARSER ✓     Syntactic: step without body is ill-formed
OOF-PG3   scoped_by on non-read body node          PARSER ✓     Syntactic: scoped_by is only valid inside read block
OOF-PG5   tenant_free on non-read node             PARSER ✓     Syntactic: same as PG3
OOF-CE1   Sourceless Claim (source_obs empty)       Classifier   Requires structural record inspection
OOF-CE2   Derivative corroboration                  Classifier   Requires provenance class reasoning
OOF-CE3   Unknown provenance in fact-check          Classifier   Requires provenance class reasoning
OOF-OS1   Evidence-less SourceReliability           Classifier   Requires structural record inspection
OOF-OS6   Unsafe external action without acceptance Runtime      AcceptanceReceipt is runtime state
```

**Parser-owned OOF rules (confirmed):**
`OOF-P2`, `OOF-DM3`, `OOF-PG1`, `OOF-PG2`, `OOF-PG3`, `OOF-PG5`

---

## Part 3: Exact Parser Hardening Targets (Stage 2)

### PH-1: pipeline/step inside contract body (OOF-P2)

```text
Grammar rule: pipeline is a top-level declaration only.
              Detecting it inside a contract body requires the parser
              to check its current parsing context.

Current behavior: parser emits pipeline node as a body node; classifier catches it.
Target behavior:  parser emits parse_error immediately.

Detection: when parsing contract body, if next token is `pipeline` or `step`,
           emit: { rule:"OOF-P2", message:"pipeline/step is not valid inside a contract body" }
           Recover: skip to next body keyword or `}`.
```

### PH-2: Decimal without scale parameter (OOF-DM3)

```text
Grammar rule: Decimal type annotation must carry a scale parameter: Decimal[N].
              Bare `Decimal` without `[N]` is structurally incomplete.

Current behavior: parser accepts bare `Decimal` as an opaque type string.
Target behavior:  when the parser recognizes `Decimal` as a type annotation identifier
                  and the next token is not `[`, emit:
                  { rule:"OOF-DM3", message:"Decimal type requires scale parameter: Decimal[N]" }
                  Recover: treat as Unknown type; continue.
```

### PH-3: Empty pipeline block (OOF-PG1)

```text
Grammar rule: a pipeline declaration must contain at least one step.

Current behavior: parser accepts `pipeline Foo {}` silently.
Target behavior:  after parsing pipeline body, if steps array is empty:
                  { rule:"OOF-PG1", message:"pipeline must contain at least one step" }
```

### PH-4: Step without contract ref (OOF-PG2)

```text
Grammar rule: a step must reference a contract.
              `step foo {}` with no contract name inside is ill-formed.

Current behavior: emits a step node with null contract_ref.
Target behavior:  if step body parsed and contract_ref is nil:
                  { rule:"OOF-PG2", message:"step must reference a contract" }
```

### PH-5: scoped_by on non-read node (OOF-PG3)

```text
Grammar rule: scoped_by is only valid as a modifier on read declarations.

Current behavior: parser may accept scoped_by on other node kinds and pass it through.
Target behavior:  if parser encounters scoped_by keyword outside of a read block:
                  { rule:"OOF-PG3", message:"scoped_by is only valid on read declarations" }
```

### PH-6: tenant_free on non-read node (OOF-PG5)

```text
Same constraint as PH-5 for the tenant_free keyword.
```

---

## Part 4: Optional Early Diagnostics (Parser Warnings)

These are NOT blocked by the parser but may emit advisory diagnostics to help developers:

```text
PW-1: Unknown keyword in contract body position.
      A token that is not a known body keyword (input, output, compute, const,
      read, snapshot, escape) appears at body position.
      emit: { severity:"warning", message:"Unknown body keyword '<token>'; ignoring" }
      Recovery: skip token; continue body parsing.
      Rationale: grammar may evolve; new keywords should not hard-fail the parser.

PW-2: Empty contract body.
      A contract with no body declarations at all.
      emit: { severity:"warning", message:"Contract '<name>' has no declarations" }
      Not an error: a contract stub may be intentional.

PW-3: Duplicate body node name.
      Two input/compute/output/etc nodes in the same contract share a name.
      emit: { severity:"warning", message:"Duplicate declaration name '<name>'" }
      Classifier will catch this as OOF-P4 (cycle) or OOF-P1 if shadowing causes issues.
```

**[D] Parser warnings are advisory. `parse_result: "ok"` is still emitted.** The classifier is the gate for semantic rejection.

---

## Part 5: ParsedProgram Diagnostic Shape (Extended)

ParsedProgram already carries `parse_errors`. Parser hardening adds structured OOF entries there:

```json
"parse_errors": [
  {
    "rule":     "OOF-P2",
    "severity": "error",
    "message":  "pipeline/step is not valid inside a contract body",
    "token":    "pipeline",
    "line":     12,
    "col":      3
  },
  {
    "rule":     "PW-1",
    "severity": "warning",
    "message":  "Unknown body keyword 'publish'; ignoring",
    "token":    "publish",
    "line":     5,
    "col":      2
  }
]
```

**[D] A `parse_error` entry with `severity: "error"` prevents the affected contract from being classified.** The classifier skips any contract whose name appears in a parse error. The contract is emitted with `fragment_class: "oof"` and the parse error forwarded to `CompilationReport.diagnostics`.

---

## Part 6: Acceptance Checklist for Research Agent

```text
Parser hardening (igniter_lang_parser.rb):

  ☐ PH-1: Emit OOF-P2 parse_error when `pipeline` or `step` token appears
           inside a contract body. Recover and continue.

  ☐ PH-2: Emit OOF-DM3 parse_error when `Decimal` type annotation
           is not followed by `[`. Treat type as Unknown; continue.

  ☐ PH-3: Emit OOF-PG1 parse_error when a pipeline has zero steps.

  ☐ PH-4: Emit OOF-PG2 parse_error when a step has no contract_ref.

  ☐ PH-5: Emit OOF-PG3 parse_error when scoped_by appears outside a read block.

  ☐ PH-6: Emit OOF-PG5 parse_error when tenant_free appears outside a read block.

  ☐ PH-7: Parser warnings PW-1..PW-3 emit severity:"warning" (not "error").
           ParsedProgram.parse_result remains "ok" for warning-only programs.

  ☐ PH-8: Classifier skips contracts with parse_error entries for that contract.
           Forwarded to CompilationReport.diagnostics.

Negative fixture coverage:
  ☐ PF-1: Source with `pipeline` inside a contract body -> OOF-P2 in parse_errors.
  ☐ PF-2: Source with `Decimal` (no scale) as type annotation -> OOF-DM3.
  ☐ PF-3: Source with empty `pipeline {}` -> OOF-PG1.
  ☐ PF-4: Source with `step foo {}` (no contract ref) -> OOF-PG2.

Non-targets (must not be in parser):
  ☐ PX-1: OOF-P1 (unresolved symbol) must NOT be in parser. Classifier owns.
  ☐ PX-2: OOF-CE4 (ConfidenceLabel as Bool) must NOT be in parser.
  ☐ PX-3: OOF-OS2 (evidence-less alert) must NOT be in parser.
  ☐ PX-4: OOF-TC5 (Decimal scale mismatch) must NOT be in parser.
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/parser-oof-hardening-spec-v0
Status: done

[D] Decisions:
- Parser owns exactly 6 OOF rules: OOF-P2, OOF-DM3, OOF-PG1, OOF-PG2, OOF-PG3, OOF-PG5.
  All are structural/syntactic; none require symbol table or type inference.
- 20+ other OOF rules belong to classifier or typechecker or runtime. Not moved.
- Parser emits OOF entries inside parse_errors[] with rule, severity, message, token, line, col.
- error severity -> classifier skips the affected contract; forwards to CompilationReport.
- warning severity -> parse_result remains "ok"; no classifier skip.
- 3 optional early diagnostics: PW-1 (unknown keyword), PW-2 (empty body), PW-3 (duplicate name).
- 8 parser hardening items: PH-1..PH-8.
- 4 negative fixture targets: PF-1..PF-4.
- 4 explicit non-targets: PX-1..PX-4.

[Files] Changed:
- igniter-lang/docs/proposals/PROP-026-parser-oof-hardening-spec-v0.md [NEW]
- igniter-lang/docs/agent-motion.md [updated]

[Next]:
- [Research Agent]: Stage 2 — apply PH-1..PH-8 to igniter_lang_parser.rb.
  Add PF-1..PF-4 as negative fixture cases.
  Verify PX-1..PX-4 are not parser-owned.
  This is a Stage 2 item; Stage 1 proof must close first.
```
