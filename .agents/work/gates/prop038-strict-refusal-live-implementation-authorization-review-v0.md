# PROP-038 Strict Refusal Live Implementation Authorization Review v0

Card: S3-R83-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-strict-refusal-live-implementation-authorization-review-v0
Route: UPDATE
Status: authorized-bounded-internal-only-implementation
Date: 2026-05-19

---

## Decision

Authorize a bounded internal-only PROP-038 strict-refusal live implementation.

This authorization opens only the C2-I implementation boundary defined in this
document:

```text
prop038-strict-refusal-live-implementation-v0
```

Rationale:

- R81 proved the target result shape proof-locally.
- R82 accepted the exact candidate live write scope.
- R82 pressure found no blockers.
- R82 resolved both remaining non-blocking notes:
  - live authority comes from orchestrator-level strict requirement decision
    path, not validator result fields;
  - first implementation remains internal-only/test-seam only, with public
    API/CLI closed.

This is an anti-loop gate: no additional design-only round is required before
the first bounded internal implementation.

---

## Evidence Read

- `igniter-lang/docs/gates/prop038-strict-refusal-live-implementation-scope-decision-v0.md`
- `igniter-lang/docs/tracks/prop038-strict-refusal-live-implementation-scope-review-v0.md`
- `igniter-lang/docs/tracks/prop038-live-implementation-touchpoint-survey-v0.md`
- `igniter-lang/docs/discussions/prop038-live-implementation-scope-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-strict-refusal-result-shape-proof-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round82-status-curation-v0.md`

---

## Authorized Write Scope

C2-I may edit only the following files or directories:

| Path | Authorization |
| --- | --- |
| `igniter-lang/lib/igniter_lang/compiler_orchestrator.rb` | Authorized for internal strict requirement source, strict decision point, pre-assembly non-persisting terminal branch, and assembly skip only. |
| `igniter-lang/lib/igniter_lang/compiler_result.rb` | Authorized for non-persisting `refused` and `configuration_error` result construction only. |
| `igniter-lang/experiments/prop038_strict_refusal_live_implementation_proof/` | Authorized for proof harness and output artifacts. |
| `igniter-lang/docs/tracks/prop038-strict-refusal-live-implementation-v0.md` | Authorized implementation track doc. |

Conditional rerun summary output is allowed only when the required proof matrix
reruns an existing proof and naturally refreshes its summary.

Any need to edit a path outside this table is a stop condition and must return
to Architect.

---

## Explicitly Authorized Behavior

C2-I may implement a live internal-only strict terminal branch with these
constraints:

- strict source is supplied only through an internal `CompilerOrchestrator`
  construction/test seam;
- no public Ruby facade, CLI flag, env/config lookup, manifest lookup,
  generated/defaulted lookup, loader/report source, or CompatibilityReport
  source is authorized;
- strict terminal evaluation occurs after baseline report enrichment and only
  when the baseline report has `pass_result == "ok"`;
- malformed internal strict requirement may produce
  `status: "configuration_error"`;
- strict digest mismatch may produce `status: "refused"`;
- strict terminal paths are non-persisting and pre-assembly;
- strict terminal paths skip assembler and do not mutate `.igapp`;
- ordinary parse, OOF, assembler, runtime-smoke, and internal-error refusal
  behavior remains unchanged.

---

## `CompilerOrchestrator` Authority

`CompilerOrchestrator` changes are authorized only for:

1. accepting an internal strict requirement source via constructor/test seam;
2. evaluating strict terminal behavior after report-only contract validation and
   before assembly;
3. returning non-persisting `CompilerResult` strict terminal objects;
4. skipping assembly/runtime-smoke for strict terminal paths;
5. preserving current behavior when strict source is absent, nil, malformed in a
   non-strict context, or not applicable.

`CompilerOrchestrator#refusal` must not be used for PROP-038 strict terminal
paths in this slice.

No public facade, CLI, loader/report, CompatibilityReport, RuntimeMachine, or
production source may call or configure strict behavior.

---

## `CompilerResult` Authority

`CompilerResult` changes are authorized only for:

1. constructing a non-persisting strict `refused` result;
2. constructing a non-persisting strict `configuration_error` result;
3. preserving the exact public key-set accepted by R81/R82;
4. producing wrapper diagnostics without exposing raw nested validator
   diagnostics as top-level public diagnostics;
5. preserving existing `ok`, ordinary `refusal`, and `public_result` behavior
   for non-PROP-038 paths.

Accepted public key-set for both `refused` and `configuration_error`:

```text
kind
format_version
status
program_id
source_path
source_hash
grammar_version
stages
igapp_path
contracts
compilation_report_path
diagnostics
warnings
```

`compilation_report_path` must be present and `null` for strict terminal paths.

No raw strict source payload, `strict_requirement` object, nested validation
object, wrapper evidence object, or `compile_refusal_authorized` top-level key
may appear in the public result.

---

## Live Authority Source

The live strict-refusal authority source is:

```text
orchestrator-level internal strict requirement decision path
```

The validator remains an evidence producer only.

Required constraints:

- `CompilerProfileContractValidator` does not become an authority source;
- validator `compile_refusal_authorized: false` remains nested report-only
  evidence;
- invalid validation alone must never authorize refusal;
- strict terminal status requires both:
  - explicit internal strict source; and
  - orchestrator strict decision path selecting a strict terminal outcome.

The implementation proof must mechanically check this boundary.

---

## Report And Persistence Policy

`report.pass_result` policy:

```text
report.pass_result == "ok"
```

remains invariant for all PROP-038 strict terminal paths in this route.

Strict terminal status belongs to orchestration/result status, not to
`report["pass_result"]`.

Non-persisting policy:

- do not call `CompilerOrchestrator#refusal`;
- do not write `.compilation_report.json`;
- do not write a distinct PROP-038 report;
- do not produce sidecar paths;
- do not create or mutate `.igapp`;
- do not call `Assembler.assemble_artifacts` on strict terminal paths;
- do not append nested validation diagnostics to top-level report diagnostics.

Persisted refusal report behavior remains closed.

---

## Required Proof Matrix

C2-I must run and record PASS/FAIL for at least:

### Syntax

```bash
ruby -c igniter-lang/lib/igniter_lang/compiler_orchestrator.rb
ruby -c igniter-lang/lib/igniter_lang/compiler_result.rb
ruby -c igniter-lang/experiments/prop038_strict_refusal_live_implementation_proof/prop038_strict_refusal_live_implementation_proof.rb
```

### New Live Proof

```bash
ruby igniter-lang/experiments/prop038_strict_refusal_live_implementation_proof/prop038_strict_refusal_live_implementation_proof.rb
```

Required proof cases:

| Case | Required result |
| --- | --- |
| no strict source | current report-only behavior unchanged |
| nil strict source | current report-only behavior unchanged |
| valid strict source + valid contract | current assembly/success behavior unchanged |
| valid strict source + digest mismatch | `status: "refused"`, non-persisting, pre-assembly |
| malformed strict source | `status: "configuration_error"`, non-persisting, pre-assembly |
| validator invalid but no strict authority | no refusal; report-only behavior unchanged |
| provider nil/non-Hash/exception | no-field/no-refusal behavior unchanged |
| ordinary parse/OOF/assembler/runtime-smoke paths | existing refusal/report behavior unchanged |

Required assertions:

- exact 13-key public allowlist for `refused`;
- exact 13-key public allowlist for `configuration_error`;
- `configuration_error` and `refused` differ by values/diagnostics, not keys;
- `compilation_report_path: null`;
- `igapp_path: null`;
- assembler not called for strict terminal paths;
- no `.igapp`;
- no sidecar or persisted report;
- `CompilerOrchestrator#refusal` not called for strict terminal paths;
- nested validator diagnostics remain nested;
- public diagnostics use wrapper codes only;
- validator `compile_refusal_authorized: false` remains nested evidence, not
  authority;
- public API/CLI and `IgniterLang.compile` signature unchanged.

### Existing Proof Chain

The following must remain PASS:

```bash
ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb
ruby igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb
ruby igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/prop038_contract_digest_recompute_match_proof.rb
ruby igniter-lang/experiments/prop038_contract_digest_report_only_integration_proof/prop038_contract_digest_report_only_integration_proof.rb
ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb
ruby igniter-lang/experiments/prop038_strict_mode_refusal_trigger_proof/prop038_strict_mode_refusal_trigger_proof.rb
ruby igniter-lang/experiments/prop038_strict_refusal_result_shape_proof/prop038_strict_refusal_result_shape_proof.rb
```

If any proof fails, C2-I must stop and report hold/fix recommendation.

---

## Explicit Non-Authorizations

This decision does not authorize:

- public API or CLI widening;
- `IgniterLang.compile` signature changes;
- `igniter-lang/lib/igniter_lang.rb` edits;
- `igniter-lang/lib/igniter_lang/cli.rb` edits;
- `igniter-lang/bin/igc` edits;
- env/config/manifest/default/generated strict source lookup;
- loader/report strict source or status;
- CompatibilityReport strict source or status;
- persisted refusal reports;
- sidecars;
- `.igapp` mutation or golden migration;
- parser changes;
- TypeChecker changes;
- SemanticIR changes;
- assembler changes;
- `CompilationReport` changes;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`;
- receipts;
- signing;
- dispatch migration;
- RuntimeMachine or Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

---

## Exact C2-I Boundary

```text
Card: S3-R83-C2-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop038-strict-refusal-live-implementation-v0

Route: UPDATE
Depends on:
- S3-R83-C1-A authorization

Goal:
Implement the bounded internal-only PROP-038 strict-refusal live slice exactly
within the S3-R83-C1-A authorization boundary.

Authorized write scope:
- igniter-lang/lib/igniter_lang/compiler_orchestrator.rb
- igniter-lang/lib/igniter_lang/compiler_result.rb
- igniter-lang/experiments/prop038_strict_refusal_live_implementation_proof/
- igniter-lang/docs/tracks/prop038-strict-refusal-live-implementation-v0.md

Required implementation constraints:
- internal-only strict source/test seam;
- orchestrator-level strict requirement is authority;
- validator output is evidence, not authority;
- validator compile_refusal_authorized:false remains nested report-only marker;
- report.pass_result:"ok" remains invariant for strict terminal paths;
- refused/configuration_error share exact 13-key public allowlist;
- no sidecar, no persisted report, no .igapp;
- no use of CompilerOrchestrator#refusal for PROP-038 strict terminal paths;
- ordinary parse/OOF/assembler/runtime-smoke/internal-error behavior unchanged;
- no public API/CLI/Ruby facade widening.

Deliver:
- implementation track doc;
- exact changed files;
- command matrix and PASS/FAIL;
- new proof summary artifact;
- evidence for no-sidecar/no-report/no-.igapp;
- evidence for authority-source separation;
- recommendation: ready for pressure review / hold.
```

No other implementation card is authorized by this decision.

---

## Current Behavior Until C2-I Lands

Until C2-I lands and is accepted by a later gate:

- current live PROP-038 behavior remains report-only;
- live compile refusal remains closed;
- public API/CLI remains closed;
- persisted refusal report behavior remains closed;
- loader/report and CompatibilityReport remain closed.
