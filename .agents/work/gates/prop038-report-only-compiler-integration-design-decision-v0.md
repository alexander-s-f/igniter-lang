# PROP-038 Report-Only Compiler Integration Design Decision v0

Card: S3-R66-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-report-only-compiler-integration-design-decision-v0
Route: UPDATE
Status: accepted-authorized-bounded-report-only-implementation
Date: 2026-05-17

---

## Decision

Accept the R66 report-only compiler integration design.

Authorize the next bounded implementation card for Candidate A only:

```text
internal provider on CompilerOrchestrator constructor
in-memory CompilationReport field only
report-only, never refusal
```

This decision authorizes only a non-public, report-only compiler annotation path.
It does not authorize compile refusal, public API/CLI widening, persisted success
reports, sidecars, `.igapp` mutation, loader/report behavior,
CompatibilityReport behavior, runtime behavior, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-report-only-compiler-integration-design-v0.md`
- `igniter-lang/docs/discussions/prop038-report-only-compiler-integration-design-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-design-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round65-status-curation-v0.md`
- `igniter-lang/docs/org/indexes/prop038-report-integration-boundary-map-v0.md`
- `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb`
- `igniter-lang/lib/igniter_lang/compilation_report.rb`
- `igniter-lang/lib/igniter_lang/compiler_result.rb`

---

## Acceptance Basis

R66-C1-P1 resolves the seven R65-C3-A pre-implementation questions:

| Question | Resolution |
| --- | --- |
| Contract input ownership | Internal `compiler_profile_contract_provider` on `CompilerOrchestrator` constructor. |
| Report/output location | In-memory `CompilationReport` field only. |
| Orchestrator insertion point | After report enrichment and before assembler transport. |
| Fixture/golden policy | New proof-local experiment; no golden mutation. |
| Descriptor digest material | Shape-only continues; recomputation held. |
| `contract_digest` policy | Format/mismatch validation deferred. |
| Report-only vs refusal | Five hard rules; no `pass_result`, stage, assembler, or status change. |

R66-C2-X pressure verdict:

```text
proceed
blockers: none
non-blocking notes: 2
```

Both non-blocking notes are accepted and converted into implementation
requirements below.

---

## Approved Candidate

Approved:

```text
Candidate A: internal provider + in-memory CompilationReport field
```

Held:

- persisted success `.compilation_report.json`;
- sidecar JSON;
- `compile(...)` keyword;
- `IgniterLang::Diagnostics` centralization;
- public output exposure.

Rejected for this lane:

- public facade/CLI input;
- assembler / `.igapp` integration.

---

## Authorized Implementation Scope

The next implementation card may edit only:

```text
igniter-lang/lib/igniter_lang/compiler_orchestrator.rb
igniter-lang/lib/igniter_lang/compilation_report.rb
igniter-lang/experiments/prop038_report_only_compiler_integration/
igniter-lang/docs/tracks/<future-implementation-track>.md
```

The implementation may read but must not edit:

```text
igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb
igniter-lang/lib/igniter_lang/compiler_result.rb
igniter-lang/lib/igniter_lang.rb
igniter-lang/lib/igniter_lang/cli.rb
```

The implementation must not edit:

- `igniter-lang/lib/igniter_lang/compiler_result.rb`;
- `igniter-lang/lib/igniter_lang.rb`;
- `igniter-lang/lib/igniter_lang/cli.rb`;
- `igniter-lang/lib/igniter_lang/diagnostics.rb`;
- `igniter-lang/lib/igniter_lang/assembler.rb`;
- parser, classifier, TypeChecker, or SemanticIR emitter;
- `.igapp` outputs or goldens;
- loader/report or CompatibilityReport surfaces;
- RuntimeMachine, runtime, Gate 3, Ledger/TBackend, BiHistory, stream/OLAP,
  cache, or production surfaces.

---

## Behavior Mode

Authorized behavior mode:

```text
report-only
never refusal
internal only
```

Hard rules:

```text
invalid compiler_profile_contract => report field only
invalid compiler_profile_contract != compile refusal
invalid compiler_profile_contract must not change pass_result
invalid compiler_profile_contract must not change stages
invalid compiler_profile_contract must not block assembly
```

The implementation must not use:

- `CompilationReport.internal_error`;
- `CompilerResult.refusal`;
- `AssemblyRefused`;
- `report["pass_result"] = "error"`;
- stage values `"error"` or `"skipped"` because of contract validation.

---

## Input Ownership

Authorized internal provider shape:

```ruby
CompilerOrchestrator.new(compiler_profile_contract_provider: provider)
```

The provider may be any object that responds to `call`.

Authorized call shape:

```ruby
compiler_profile_contract_provider.call(
  source_path: source_path,
  out_path: out_path,
  parsed_program: parsed,
  compiler_profile_source: compiler_profile_source
)
```

Provider return:

```text
Hash | nil
```

`nil` means no `compiler_profile_contract_validation` field is attached.

Provider exception policy for the first implementation:

```text
rescue provider exceptions and treat them as nil
```

Reason: provider failure must not become compile refusal in the first
report-only implementation.

The orchestrator must not:

- read paths for the contract;
- parse inline JSON;
- discover, default, infer, or finalize profiles;
- derive a contract from `compiler_profile_source`;
- derive `compiler_profile_source` from a contract;
- add `IgniterLang.compile(..., compiler_profile_contract: ...)`;
- add `--compiler-profile-contract`.

---

## Report Output Owner

Authorized output owner:

```text
CompilationReport in-memory field
```

Authorized field name:

```text
compiler_profile_contract_validation
```

Authorized helper shape:

```ruby
CompilationReport.with_compiler_profile_contract_validation(report:, validation:)
```

Expected behavior:

- return `report` unchanged when `validation` is nil;
- attach `validation.merge("report_only" => true)` when validation is present;
- do not modify `pass_result`;
- do not modify `stages`;
- do not append validator diagnostics into `report["diagnostics"]`.

The attached field is internal report data. It must not be exposed through
`CompilerResult.public_result` in the first implementation.

---

## Insertion Point

Authorized insertion point:

```text
after CompilationReport.enrich(...)
after semantic_ir is available
before return refusal(report, ...) unless report.pass_result == "ok"
before assembler receives compiler_profile_source
```

First implementation scope:

- normal post-emit report path only;
- parse failures do not invoke provider;
- classifier/typechecker/emitter failure paths do not attach validation unless
  a later decision explicitly authorizes failed-report validation.

---

## Digest And Diagnostic Policy

Descriptor digest remains shape-only:

```text
compiler_profile_descriptor/sha256:<24+ lowercase hex>
```

`contract_digest` format and mismatch validation remain deferred.

Do not add:

- `compiler_profile_contract.contract_digest_invalid`;
- `compiler_profile_contract.contract_digest_mismatch`;
- `compiler_profile_contract.unknown_owner_slot`;
- `compiler_profile_contract.unknown_rule_owner_slot`;
- any new `compiler_profile_contract.*` diagnostic.

Diagnostics remain local to:

```text
IgniterLang::CompilerProfileContractValidator
```

Do not centralize in:

```text
IgniterLang::Diagnostics
```

---

## `compiler_integrated` Semantics

R66-C2-X NB-2 is accepted.

For this report-only context:

```text
compiler_integrated=false
```

means:

```text
the validation result does not drive compile outcome
```

It does not mean:

```text
the validator was not called from within CompilerOrchestrator
```

Proof must assert the outcome interpretation: invalid contract validation does
not change compile status, stages, assembler execution, public result, or refusal
behavior.

---

## Fixture And Proof Policy

Authorized proof surface:

```text
igniter-lang/experiments/prop038_report_only_compiler_integration/
```

No existing golden or fixture mutation is authorized.

Required proof cases:

1. valid contract attaches `compiler_profile_contract_validation.valid=true`;
2. invalid contract attaches `valid=false` and diagnostics;
3. invalid contract still returns compile status `ok` when the program otherwise
   compiles;
4. public result remains unchanged;
5. no `.igapp` manifest changes;
6. no refusal report is written because of contract validation;
7. provider nil preserves legacy behavior and does not attach the field;
8. provider exception preserves legacy behavior and does not attach the field.

Required command matrix must include syntax checks for changed Ruby files and the
new proof experiment command.

---

## Exact Next Allowed Card Boundary

```text
Card: S3-R67-C1-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop038-report-only-compiler-integration-implementation-v0

Route: UPDATE
Authority ref:
- igniter-lang/docs/gates/prop038-report-only-compiler-integration-design-decision-v0.md

Goal:
Implement Candidate A only: internal provider plus in-memory CompilationReport
annotation for PROP-038 compiler profile contract validation, report-only and
never refusal.

Scope:
- Edit only:
  - igniter-lang/lib/igniter_lang/compiler_orchestrator.rb
  - igniter-lang/lib/igniter_lang/compilation_report.rb
  - igniter-lang/experiments/prop038_report_only_compiler_integration/
  - igniter-lang/docs/tracks/prop038-report-only-compiler-integration-implementation-v0.md
- Add `compiler_profile_contract_provider:` constructor injection to
  `CompilerOrchestrator`.
- The provider must be any object responding to `call`.
- The provider call receives:
  - `source_path:`
  - `out_path:`
  - `parsed_program:`
  - `compiler_profile_source:`
- Provider returns `Hash | nil`.
- Provider exceptions must be rescued and treated as nil.
- Add `CompilationReport.with_compiler_profile_contract_validation(report:, validation:)`.
- Attach `compiler_profile_contract_validation` only to the in-memory report.
- Add `"report_only" => true` to the attached validation field.
- Do not modify `pass_result`, `stages`, diagnostics, assembler execution, or
  compile status because of contract validation.
- Keep validator diagnostics local and unchanged.
- Keep descriptor digest shape-only.
- Keep `contract_digest` validation deferred.
- Do not change `CompilerResult`.
- Do not change `igniter-lang/lib/igniter_lang.rb`.
- Do not change CLI.

Proof:
- Syntax checks for changed Ruby files.
- New proof-local experiment proving all 8 required proof cases.

Deliver:
- Updated code in authorized files only
- New proof experiment and summary
- Track doc with exact command matrix and PASS/FAIL
- Recommendation for C3-A: accept / hold / redirect

Non-authorizations:
- No compile refusal.
- No public API/CLI widening.
- No persisted success report or sidecar.
- No `.igapp` mutation.
- No loader/report or CompatibilityReport.
- No `IgniterLang::Diagnostics` centralization.
- No `CompilerResult` change.
- No RuntimeMachine, Gate 3, Ledger/TBackend, BiHistory, stream/OLAP, cache, or
  production behavior.
```

---

## Non-Authorizations Preserved

This decision does not authorize:

- compile refusal;
- public API/CLI widening;
- parser changes;
- TypeChecker changes;
- SemanticIR changes;
- assembler or `.igapp` changes;
- persisted success `.compilation_report.json`;
- sidecar JSON;
- loader/report;
- CompatibilityReport;
- `IgniterLang::Diagnostics` centralization;
- `CompilerResult` changes;
- public result exposure;
- `.ilk`;
- receipts;
- signing;
- dispatch migration;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

---

## Compact Summary

R66 accepts the report-only compiler integration design and authorizes only a
bounded Candidate A implementation next. The allowed implementation may add an
internal `compiler_profile_contract_provider` to `CompilerOrchestrator`, attach
validator output to an in-memory `CompilationReport` field, and prove that
invalid contracts remain report-only. It may not expose public API/CLI input,
change `CompilerResult`, persist reports, mutate `.igapp`, centralize
diagnostics, enforce `contract_digest`, refuse compilation, or open runtime or
production behavior.
