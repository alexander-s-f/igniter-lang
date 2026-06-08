# PROP-019.1: SemanticIR Envelope Errata and Diagnostic Placement

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Status: proposal
Date: 2026-05-06
Track: igniter-lang/prop019-errata-and-diagnostic-placement-v0
Amends: PROP-019 (Canonical SemanticIR Envelope v0)
Depends on: PROP-020 (Classifier Pass)

---

## Purpose

Resolve four ambiguities that block the `.igapp/` assembler:

1. Where do OOF contracts live?
2. May a loadable SemanticIR contain `fragment_class: "oof"`?
3. What is the relationship between the four pipeline outputs?
4. Which stdlib operator name is canonical after type resolution?

---

## Part 1: OOF Contracts — Location Decision

**[D] A loadable `SemanticIRProgram` must NOT contain any contract with `fragment_class: "oof"`.** OOF output is never loadable into the RuntimeMachine.

**[D] OOF contracts are captured in `CompilationReport`, NOT in the SemanticIRProgram.**

```text
Two possible outputs of a compilation attempt:

  Success path:
    ParsedProgram  ->  ClassifiedProgram  ->  TypedProgram  ->  SemanticIRProgram
    (all contracts core or escape; oof_log empty)

  Failure path:
    ParsedProgram  ->  ClassifiedProgram  (pass_result: "oof")
    ->  CompilationReport  (no SemanticIRProgram emitted)
```

**[D] `SemanticIRProgram.oof_log` is REMOVED from the canonical spec.** PROP-019 §Part 1 listed `oof_log` at the program level. That field is deprecated. OOF entries belong in `CompilationReport` only.

**[D] `ContractIR.oof_log` is also removed.** A `ContractIR` inside a loadable `SemanticIRProgram` must have an empty diagnostic set. If the classifier produced OOF entries for a contract, that contract is not emitted to SemanticIR.

---

## Part 2: CompilationReport Shape

```json
{
  "kind":            "compilation_report",
  "format_version":  "0.1.0",
  "program_id":      "<same as ParsedProgram.program_id>",
  "grammar_version": "<propagated>",
  "source_hash":     "sha256:<hex>",
  "source_path":     "<relative>",
  "pass_result":     "ok | oof | error",
  "stages": {
    "parse":    "ok | oof | error",
    "classify": "ok | oof | error",
    "typecheck":"ok | oof | skipped",
    "emit":     "ok | skipped | error"
  },
  "diagnostics": [ <Diagnostic> ],
  "semantic_ir_ref": "<program_id> | null"
}
```

```text
semantic_ir_ref:
  non-null  -> SemanticIRProgram was emitted; this id locates it
  null      -> compilation failed; no SemanticIRProgram exists

diagnostics:
  All Diagnostic entries from all passes, in declaration order.
  Diagnostic shape from PROP-020 §Part 6:
    { rule, severity, message, node, path, line }

pass_result: "ok" means all stages completed and semantic_ir_ref is non-null.
```

**[D] The `.igapp/` assembler reads `CompilationReport` to decide whether to proceed.** It reads `semantic_ir_ref` to locate the `SemanticIRProgram` artifact. It does not read the `SemanticIRProgram` directly.

---

## Part 3: Four-Stage Pipeline Relationship

```text
Stage     Input             Output              Failure output
--------  ----------------  ------------------  ----------------
Parse     .ig source bytes  ParsedProgram       ParsedProgram (parse_errors non-empty)
Classify  ParsedProgram     ClassifiedProgram   ClassifiedProgram (pass_result: "oof")
Typecheck ClassifiedProgram TypedProgram        TypedProgram (pass_result: "oof")
Emit      TypedProgram      SemanticIRProgram   (not emitted; CompilationReport captures)

CompilationReport is written at the end of every attempt, success or failure.
SemanticIRProgram is written only on full success (all stages "ok").
```

**[D] Each stage is a standalone data transformation.** No stage reads a prior stage's artifact directly — it receives the output as its input parameter. This enables partial re-runs.

**[D] Typecheck is `"skipped"` if Classify produced `pass_result: "oof"`.** The typecheck stage is not entered for OOF programs. This prevents cascading false errors.

---

## Part 4: Revised SemanticIRProgram Shape (PROP-019 Amendment)

Remove `oof_log` from top-level and from `ContractIR`. Add `compilation_report_ref`.

```json
{
  "kind":                    "semantic_ir_program",
  "format_version":          "0.1.0",
  "program_id":              "semanticir/<prefix16>",
  "grammar_version":         "<detected>",
  "source_hash":             "sha256:<hex>",
  "source_path":             "<relative>",
  "module":                  "<ModulePath | null>",
  "compilation_report_ref":  "<program_id>",
  "contracts":               [ <ContractIR> ]
}
```

`ContractIR` removes `oof_log`. All contracts in a loadable `SemanticIRProgram` are guaranteed clean.

---

## Part 5: Stdlib Operator Naming

**[D] Classifier-level call names use the annotation-qualified form.**

```text
In source:         stdlib.integer.add(a, b)
After classify:    "fn": "stdlib.integer.add"   -- preserved as-is if parseable

After typecheck (TypedProgram):
  The fn name is RESOLVED to the type-qualified form:
    Integer operands  -> "fn": "stdlib.integer.add"
    Float operands    -> "fn": "stdlib.float.add"
    Decimal operands  -> "fn": "stdlib.decimal.add"

"stdlib.numeric.add" (from polymorphic_add fixture) was a pre-resolution name.
It is valid in ClassifiedProgram/TypedProgram as an overloaded ref,
but MUST be resolved to the monomorphic form before SemanticIR emission.
```

**[D] A `SemanticIRProgram` node must not contain `"stdlib.numeric.add"` or any other polymorphic/overloaded operator name.** Only monomorphic, type-qualified names are permitted. Unresolved overloads → OOF-P1 at typecheck.

```text
Canonical stdlib type prefixes (v0):
  stdlib.integer.*    -- Integer operands
  stdlib.float.*      -- Float operands
  stdlib.decimal.*    -- Decimal[N] operands
  stdlib.string.*     -- String operands
  stdlib.bool.*       -- Bool operands
  stdlib.collection.* -- Collection[T] operands
  stdlib.option.*     -- Option[T] operands
  stdlib.result.*     -- Result[T,E] operands
```

---

## Part 6: Fixture Migration Notes (amending PROP-019 §Part 7)

```text
source_to_semanticir_fixture/golden/*.semantic_ir.json:
  REMOVE oof_log from top-level envelope
  REMOVE oof_log from each contract
  ADD compilation_report_ref: "<program_id>"
  CREATE companion *.compilation_report.json for each fixture

  Negative case fixtures (negative_*.semantic_ir.json):
    These should NOT have a semantic_ir.json at all in canonical form.
    They should have ONLY a *.compilation_report.json with pass_result: "oof".
    Rename: negative_*.semantic_ir.json -> negative_*.compilation_report.json
    Remove the semantic_ir shape from negative cases entirely.

polymorphic_add.semantic_ir.expected.json:
  "stdlib.numeric.add" -> "stdlib.integer.add" (post-typecheck, Integer specialization)
  Remove oof_log fields
  Add compilation_report_ref
```

---

## Part 7: Assembler Acceptance Criteria

```text
The .igapp/ assembler proof is accepted when:

A1: Assembler reads CompilationReport and checks pass_result: "ok".
    Assembler rejects (with error) if pass_result != "ok".

A2: Assembler locates SemanticIRProgram via compilation_report_ref.
    SemanticIRProgram.kind must equal "semantic_ir_program".

A3: Assembler iterates SemanticIRProgram.contracts.
    No contract may have fragment_class: "oof".
    Assembler rejects if any OOF contract present (should not occur; defensive).

A4: Assembler writes .igapp/ directory:
    .igapp/manifest.json     -- program_id, grammar_version, contract names
    .igapp/contracts/<Name>.json  -- one file per ContractIR
    .igapp/compilation_report.json -- copied from CompilationReport

A5: RuntimeMachine loads .igapp/ by reading manifest.json,
    then loading each contracts/<Name>.json.
    Load succeeds without OOF check (guaranteed clean by A3).

A6: Negative case: assembler given CompilationReport with pass_result: "oof"
    must refuse to write .igapp/ and return exit code != 0.
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/prop019-errata-and-diagnostic-placement-v0
Status: done

[D] Decisions:
- Loadable SemanticIRProgram NEVER contains OOF contracts or oof_log.
  oof_log removed from SemanticIRProgram (top-level and ContractIR).
- OOF diagnostics live in CompilationReport only.
- CompilationReport is always written; SemanticIRProgram only on full success.
- Four stages: Parse -> Classify -> Typecheck -> Emit.
  Typecheck skipped if Classify is OOF.
- Assembler reads CompilationReport.semantic_ir_ref to locate artifact.
- stdlib.numeric.add is a pre-resolution name; must become stdlib.integer.add
  (or float/decimal/etc) before SemanticIR emission. Unresolved overload -> OOF-P1.
- Negative case fixtures must NOT have a .semantic_ir.json; only
  .compilation_report.json with pass_result: "oof".

[Files] Changed:
- igniter-lang/docs/proposals/PROP-019.1-semanticir-envelope-errata-v0.md [NEW]
- igniter-lang/docs/README.md  [updated]
- igniter-lang/docs/agent-motion.md  [updated]

[Next]:
- [Research Agent]: Slice A (.igapp/ Assembler).
  Input: CompilationReport + SemanticIRProgram JSON (existing golden fixtures).
  Output: .igapp/ directory per §Part 7 criteria A1..A6.
  Migrate negative case fixtures: remove *.semantic_ir.json -> *.compilation_report.json.
```
