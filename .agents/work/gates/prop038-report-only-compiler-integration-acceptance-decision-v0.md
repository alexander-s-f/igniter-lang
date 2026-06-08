# PROP-038 Report-Only Compiler Integration Acceptance Decision v0

Card: S3-R67-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-report-only-compiler-integration-acceptance-decision-v0
Route: UPDATE
Status: accepted-report-only-closure
Date: 2026-05-17

---

## Decision

Accept the bounded Candidate A report-only compiler integration closure.

The R66 implementation authorization is satisfied:

```text
internal provider on CompilerOrchestrator constructor
in-memory CompilationReport field only
report-only, never refusal
```

This decision closes only the authorized Candidate A scope. It does not open
compile refusal, public API/CLI widening, persisted reports, sidecars, `.igapp`
mutation, loader/report behavior, CompatibilityReport behavior, runtime behavior,
Gate 3 widening, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-report-only-compiler-integration-implementation-v0.md`
- `igniter-lang/docs/discussions/prop038-report-only-compiler-integration-implementation-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-design-decision-v0.md`
- `igniter-lang/docs/tracks/prop038-report-only-compiler-integration-design-v0.md`
- `igniter-lang/docs/discussions/prop038-report-only-compiler-integration-design-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-acceptance-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round66-status-curation-v0.md`
- `igniter-lang/experiments/prop038_report_only_compiler_integration/out/prop038_report_only_compiler_integration_summary.json`
- `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb`
- `igniter-lang/lib/igniter_lang/compilation_report.rb`
- `igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb`

---

## Exact Changed Files

Accepted implementation files:

```text
igniter-lang/lib/igniter_lang/compiler_orchestrator.rb
igniter-lang/lib/igniter_lang/compilation_report.rb
igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb
igniter-lang/experiments/prop038_report_only_compiler_integration/out/prop038_report_only_compiler_integration_summary.json
igniter-lang/docs/tracks/prop038-report-only-compiler-integration-implementation-v0.md
```

Confirmed unchanged by the implementation track:

```text
igniter-lang/lib/igniter_lang.rb
igniter-lang/lib/igniter_lang/cli.rb
igniter-lang/lib/igniter_lang/compiler_result.rb
```

All changed files are within the R66 authorized write boundary.

---

## Provider API And Exception Behavior

Accepted internal provider constructor shape:

```ruby
CompilerOrchestrator.new(compiler_profile_contract_provider: provider)
```

Accepted provider call shape:

```ruby
provider.call(
  source_path: source_path,
  out_path: out_path,
  parsed_program: parsed,
  compiler_profile_source: compiler_profile_source
)
```

Accepted return policy:

```text
Hash => validate through CompilerProfileContractValidator
nil or non-Hash => no report field
provider/validator StandardError => no report field
```

The `compile(...)` method signature is unchanged. No CLI flag, public facade
input, path loading, inline JSON parsing, profile discovery/defaulting, or
profile finalization is introduced.

---

## Report Field Shape

Accepted in-memory report field:

```json
{
  "compiler_profile_contract_validation": {
    "kind": "compiler_profile_contract_validation_result",
    "format_version": "0.1.0",
    "valid": true,
    "diagnostics": [],
    "diagnostic_codes": [],
    "digest_reference_policy": "prop038_24_plus",
    "compiler_integrated": false,
    "compile_refusal_authorized": false,
    "report_only": true
  }
}
```

`CompilationReport.with_compiler_profile_contract_validation(report:, validation:)`
returns the original report when validation is absent, and otherwise returns a
merged in-memory report with `report_only=true`.

The assembler receives `report_for_assembly`, captured before annotation, so the
annotation does not mutate `.igapp` manifest/artifact output.

---

## Proof Result

Observed proof summary:

```text
kind=prop038_report_only_compiler_integration_summary
status=PASS
cases=5
checks=20
failed_checks=0
```

Proof cases:

```text
baseline_no_provider
valid_contract
invalid_contract
nil_provider
exception_provider
```

All eight required R66 proof cases pass:

| Required case | Status |
| --- | --- |
| valid contract attaches `valid=true` | PASS |
| invalid contract attaches `valid=false` and diagnostics | PASS |
| invalid contract still returns compile status `ok` | PASS |
| public result remains unchanged | PASS |
| no `.igapp` manifest changes | PASS |
| no refusal report is written because of contract validation | PASS |
| provider nil preserves legacy behavior and attaches no field | PASS |
| provider exception preserves legacy behavior and attaches no field | PASS |

Additional proof confirms `pass_result`, `stages`, compiler diagnostics,
assembler execution, `compiler_integrated=false`, and
`compile_refusal_authorized=false` remain stable.

---

## Command Matrix

Commands rerun by Architect Supervisor:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/compiler_orchestrator.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/compilation_report.rb` | PASS |
| `ruby -c igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |

---

## Public Result And Refusal Status

Accepted:

- public result remains unchanged for valid, invalid, nil, and exception
  provider cases against the no-provider baseline;
- invalid contract does not change compile status;
- invalid contract does not change `pass_result`, stages, or compiler
  diagnostics;
- invalid contract does not prevent assembler execution;
- no refusal report is written by contract validation;
- provider failure does not become compile failure.

Therefore `compiler_integrated=false` is accepted as behaviorally confirmed:
validation may annotate an internal report field, but it does not drive compiler
outcome.

---

## Digest And Diagnostic Policy

Accepted for this closure:

- descriptor digest behavior remains shape-only;
- `contract_digest` validation remains deferred;
- validator diagnostics remain inside
  `compiler_profile_contract_validation.diagnostics`;
- validator diagnostics are not centralized through `IgniterLang::Diagnostics`;
- validator diagnostics are not appended to `report["diagnostics"]`;
- validation diagnostics do not affect compile refusal.

---

## Pressure Verdict

R67-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: none
```

Architect accepts the pressure result.

---

## Preserved Closed Surfaces

This decision does not authorize:

- compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted success reports or sidecars;
- parser, TypeChecker, SemanticIR;
- assembler or `.igapp` mutation beyond proof-local output generation;
- loader/report behavior;
- CompatibilityReport behavior;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`, receipts, signing;
- dispatch migration;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

---

## Next Allowed Boundary

Allowed next card:

```text
S3-R67-C4-S: stage3-round67-status-curation-v0
```

No additional implementation opens from this acceptance.

Any future move toward persisted success reports, sidecars, contract-digest
validation, report surfacing, public API/CLI exposure, or compile refusal
requires a separate design/pressure/Architect authorization chain.

---

## Compact Summary

Candidate A is accepted and closed. The implementation stayed inside the R66
boundary, all 8 required proof cases and 20 total checks pass, public result and
refusal behavior remain unchanged, `.igapp` output stays unmodified, and all
production/runtime/public surfaces remain closed.
