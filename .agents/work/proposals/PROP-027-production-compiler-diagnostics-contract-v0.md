# PROP-027: Production Compiler Diagnostics Contract v0

Role: `[Igniter-Lang Compiler/Grammar Expert]`
Status: closed
Closed: 2026-05-07 (Stage 2 — experiment PASS, META-EXPERT-009.1)
Date: 2026-05-07
Track: igniter-lang/production-compiler-diagnostics-contract-v0
Depends on: PROP-019.1 (CompilationReport), PROP-022 (assembler refusal)

---

## Purpose

Formalize the compiler CLI output contract — stdout JSON shape, exit codes,
and diagnostic categories — before package extraction. This is the surface
that downstream tools, CI pipelines, and the Bridge Agent consume.

---

## Part 1: Exit Code Policy

```text
Code  Meaning                   Trigger
────  ──────────────────────    ─────────────────────────────────────────────────
0     success                   All stages ok; .igapp/ written (or --check only).
1     compilation failure       pass_result: "oof" or "error" in any stage.
                                Includes: parser OOF, classifier OOF, typechecker OOF,
                                emitter error, assembler refusal.
2     CLI usage error           Missing required argument, unknown flag, invalid path.
                                No compilation attempted.
3     internal error            Unexpected exception inside the compiler itself.
                                Should never occur in a correct implementation.
                                Emits a minimal error JSON and stack trace to stderr.
```

**[D] Exit code 1 is the only expected failure in a correct usage scenario.**
Exit code 3 indicates a compiler bug, not a user error.

---

## Part 2: Stdout JSON Shape — Success

```json
{
  "kind":           "compiler_result",
  "format_version": "0.1.0",
  "status":         "ok",
  "program_id":     "semanticir/<prefix16>",
  "source_path":    "<relative>",
  "source_hash":    "sha256:<hex>",
  "grammar_version":"0.1.0",
  "stages": {
    "parse":    "ok",
    "classify": "ok",
    "typecheck":"ok",
    "emit":     "ok",
    "assemble": "ok"
  },
  "igapp_path":     ".igapp/",
  "contracts":      ["Add"],
  "diagnostics":    [],
  "warnings":       []
}
```

- `diagnostics` is empty on success.
- `warnings` carries non-blocking advisory entries (parser PW-1..PW-3, etc.).
- `igapp_path` is the assembled artifact directory (null if `--check` mode).

---

## Part 3: Stdout JSON Shape — OOF / Failure

```json
{
  "kind":           "compiler_result",
  "format_version": "0.1.0",
  "status":         "oof",
  "program_id":     "semanticir/<prefix16> | null",
  "source_path":    "<relative>",
  "source_hash":    "sha256:<hex>",
  "grammar_version":"0.1.0",
  "stages": {
    "parse":    "ok",
    "classify": "oof",
    "typecheck":"skipped",
    "emit":     "skipped",
    "assemble": "skipped"
  },
  "igapp_path":     null,
  "contracts":      [],
  "diagnostics": [
    {
      "category":  "classifier_oof",
      "rule":      "OOF-P1",
      "severity":  "error",
      "message":   "Unresolved symbol: missing_b",
      "contract":  "Add",
      "node":      "sum",
      "path":      "contract:Add/compute:sum/ref:missing_b",
      "span":      { "line": 7, "col": 22 }
    }
  ],
  "warnings": []
}
```

- `status` is `"oof"` for semantic/structural failures, `"error"` for internal failures.
- `stages` shows where the pipeline stopped (skipped stages were not reached).
- `igapp_path` is always null on failure.
- `program_id` may be null if parse failed before a program_id was assigned.

---

## Part 4: Diagnostic Categories

```text
Category               Owner pass             Trigger
─────────────────────  ─────────────────────  ─────────────────────────────────────
"parser_error"         Parser                 Syntax OOF (OOF-P2, OOF-DM3, OOF-PG1..5)
                                              Parse_errors with severity:"error"
"parser_warning"       Parser                 Advisory (PW-1..PW-3)
                                              Parse_errors with severity:"warning"
"classifier_oof"       Classifier             OOF-P1, OOF-P3, OOF-P4, OOF-OS2, etc.
"typechecker_oof"      TypeChecker            OOF-TC1..5, OOF-CE4, OOF-DM1..2
"emitter_error"        SemanticIR emitter     Structural violation during emit
                                              (should not occur after clean typecheck)
"assembler_refusal"    Assembler              R-1..R-6 (PROP-022)
"runtime_smoke_failure" Post-assemble smoke   RuntimeMachine.load failed after assembly
```

**[D] Each diagnostic entry in `compiler_result.diagnostics` must carry `category`.**

This allows CI tools to filter by origin pass:
```bash
jq '[.diagnostics[] | select(.category == "classifier_oof")]' result.json
```

---

## Part 5: Diagnostic Entry Shape

```text
DiagnosticEntry = {
  category:  DiagnosticCategory   -- see §Part 4
  rule:      String                -- "OOF-P1", "OOF-TC5", "R-3", "PW-1", etc.
  severity:  "error" | "warning" | "info"
  message:   String                -- human-readable; one line
  contract:  String | nil          -- contract_name if applicable
  node:      String | nil          -- body node name if applicable
  path:      String | nil          -- "contract:<N>/compute:<N>/ref:<X>" format
  span:      { line: Integer, col: Integer } | nil  -- from parser token, if available
}
```

**[D] `span` is optional but stable.** When present, `line` and `col` are 1-indexed. When the parser does not track line numbers, `span` is null. A consumer must not fail if `span` is absent.

**[D] `path` is the primary location identifier.** It does not depend on line numbers and is always present when a node is known.

---

## Part 6: CompilationReport Relation

```text
compiler_result (stdout)      CompilationReport (on disk)
───────────────────────────   ──────────────────────────────
kind: "compiler_result"       kind: "compilation_report"
status                     ↔  pass_result
stages                     ↔  stages
diagnostics                ↔  diagnostics (same entries)
program_id                 ↔  program_id
igapp_path                    (not in CompilationReport)
contracts list                (not in CompilationReport)

CompilationReport is written to .igapp/compilation_report.json (success only).
compiler_result is always written to stdout, success or failure.
They share the same diagnostics entries but serve different consumers.
```

**[D] `compiler_result` is the machine-readable CLI output for CI/tooling.**
**[D] `CompilationReport` is the artifact-embedded record for RuntimeMachine.**

---

## Part 7: CLI Usage Error Shape

```json
{
  "kind":    "compiler_result",
  "format_version": "0.1.0",
  "status":  "usage_error",
  "message": "Missing required argument: <source_path>",
  "usage":   "igc <source.ig> [--check] [--output <dir>] [--grammar-version <v>]"
}
```

Exit code 2. No stages, no diagnostics array. Minimal JSON only.

---

## Part 8: Internal Error Shape (stderr)

On exit code 3, the compiler writes to **stderr**:

```json
{
  "kind":    "compiler_internal_error",
  "message": "Unexpected exception in ClassifierPass",
  "stage":   "classify",
  "error":   "NoMethodError: undefined method 'fragment_class' for nil",
  "backtrace": ["classifier_pass_proof.rb:42", "..."]
}
```

Stdout is empty or partial on exit code 3. Consumers must check exit code before parsing stdout.

---

## Part 9: Acceptance Checklist for production-compiler-cli-wrapper-v0

```text
CLI output contract:
  ☐ CL-1: Exit 0 + stdout compiler_result status:"ok" on clean compilation.
  ☐ CL-2: Exit 1 + stdout compiler_result status:"oof" on OOF case.
  ☐ CL-3: Exit 2 + minimal usage_error JSON on missing source_path arg.
  ☐ CL-4: Exit 3 + stderr internal_error JSON on unexpected exception.
  ☐ CL-5: diagnostics[] is empty on exit 0.
  ☐ CL-6: diagnostics[] contains at least one entry with correct category on exit 1.
  ☐ CL-7: Each diagnostic entry carries: category, rule, severity, message,
           and (when applicable) contract, node, path.
  ☐ CL-8: span field is present when parser emits line numbers;
           null is accepted when unavailable. Consumer must not fail on null.
  ☐ CL-9: stages object shows "skipped" for stages not reached after OOF.
  ☐ CL-10: igapp_path is non-null on exit 0 (unless --check mode).
            igapp_path is null on exit 1.

Negative fixture coverage:
  ☐ NF-1: Compile negative_unresolved_symbol.ig -> exit 1,
           diagnostics[0].category: "classifier_oof", rule: "OOF-P1".
  ☐ NF-2: Compile with Decimal (no scale) -> exit 1,
           diagnostics[0].category: "parser_error", rule: "OOF-DM3".
  ☐ NF-3: Invoke compiler with no args -> exit 2, status: "usage_error".
  ☐ NF-4: Compile add.ig (clean) -> exit 0, diagnostics: [].
```

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/production-compiler-diagnostics-contract-v0
Status: done

[D] Decisions:
- 4 exit codes: 0 (ok), 1 (oof/failure), 2 (usage), 3 (internal).
- compiler_result is the canonical stdout shape for all outcomes.
- "kind": "compiler_result", "format_version": "0.1.0" on every stdout emission.
- 7 diagnostic categories: parser_error, parser_warning, classifier_oof,
  typechecker_oof, emitter_error, assembler_refusal, runtime_smoke_failure.
- DiagnosticEntry carries: category, rule, severity, message, contract?, node?, path?, span?.
- span optional; null when parser doesn't track line numbers. Consumer must not fail.
- path is the primary location identifier; always present when node is known.
- CompilationReport (artifact) and compiler_result (stdout) share diagnostics entries
  but serve different consumers. CompilationReport written only on success.
- CLI usage error: exit 2, status:"usage_error", no diagnostics array.
- Internal error: exit 3, stderr only, stdout may be empty.
- 10-item CLI acceptance checklist: CL-1..CL-10.
- 4 negative fixture targets: NF-1..NF-4.

[Files] Changed:
- igniter-lang/docs/proposals/PROP-027-production-compiler-diagnostics-contract-v0.md [NEW]
- igniter-lang/docs/agent-motion.md [updated]

[Next]:
- [Research Agent]: production-compiler-cli-wrapper-v0.
  Wrap existing compiler passes (parser/classifier/typechecker/emitter/assembler)
  behind a single CLI entry point that emits compiler_result JSON to stdout
  and exits with the correct code per this spec.
  Apply CL-1..CL-10 and NF-1..NF-4 as acceptance criteria.
```
