# PROP-036 CLI B3-B6 Implementation Authorization Review v0

Card: S3-R50-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop036-cli-b3-b6-implementation-authorization-review-v0
Route: UPDATE
Status: approved-bounded-cli-implementation-proof
Date: 2026-05-15

---

## Decision

Authorize a bounded implementation/proof card for the remaining PROP-036 CLI
blockers `B3`, `B4`, `B5`, and `B6`.

This decision authorizes only the first explicit CLI transport shape:

```text
igc compile SOURCE --out OUT.igapp --compiler-profile-source PATH.json
```

The implementation must read exactly `PATH.json`, parse it as a JSON object,
and pass the parsed object unchanged to:

```ruby
IgniterLang.compile(..., compiler_profile_source: parsed_object)
```

This decision does not close `B3`, `B4`, `B5`, `B6`, or `B9`. It authorizes the
implementation/proof work needed to produce closure evidence. `B9` pressure
must run after the implementation proof lands.

---

## Evidence Read

- `igniter-lang/docs/gates/prop036-cli-b1-formal-closure-decision-v0.md`
- `igniter-lang/docs/discussions/prop036-cli-b1-formal-closure-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round49-status-curation-v0.md`
- `igniter-lang/docs/gates/prop036-cli-exposure-design-and-blocker-tracking-decision-v0.md`
- `igniter-lang/docs/gates/prop036-cli-blocker-closure-criteria-decision-v0.md`
- `igniter-lang/docs/gates/prop036-b7-b8-docs-and-criteria-precision-review-v0.md`
- `igniter-lang/docs/tracks/prop036-cli-b3-refusal-shape-and-b6-scan-scope-v0.md`
- `igniter-lang/docs/ruby-api.md`
- `igniter-lang/lib/igniter_lang/cli.rb`
- `igniter-lang/bin/igc`

---

## Readiness Findings

The preconditions for a bounded implementation/proof card are sufficient:

- `PROP036-CLI-B1` is formally closed by S3-R49-C1-A.
- `PROP036-CLI-B2` is fixed to the explicit path shape
  `--compiler-profile-source PATH.json`.
- `PROP036-CLI-B3` has accepted hybrid refusal semantics.
- `PROP036-CLI-B6` has an accepted scan surface and the R47 adversarial
  scanner self-test requirement.
- `PROP036-CLI-B7` and `PROP036-CLI-B8` are closed by S3-R47-C3-A.
- Current package CLI surface is small and delegates through
  `IgniterLang.compile`, so the implementation can stay transport-only.

The remaining blockers are not closed yet because they need executable evidence
from the new CLI path.

---

## Authorized C2-I Boundary

Authorized implementation files:

```text
igniter-lang/lib/igniter_lang/cli.rb
```

Authorized proof/doc output:

```text
igniter-lang/experiments/prop036_cli_profile_source_b3_b6_implementation_proof/**
igniter-lang/docs/tracks/prop036-cli-profile-source-b3-b6-implementation-proof-v0.md
```

The implementation may:

- add optional `--compiler-profile-source PATH.json` support to
  `IgniterLang::CLI`;
- update the usage string to:

  ```text
  Usage: igc compile SOURCE --out OUT.igapp [--compiler-profile-source PATH.json]
  ```

- load exactly the provided path;
- parse the file as JSON;
- require the parsed top-level value to be an object/hash;
- pass the parsed object unchanged as `compiler_profile_source:`;
- preserve the no-flag legacy path exactly;
- create proof-local outputs under the named proof directory;
- write/update a proof summary owned by the named proof.

The implementation must not:

- add profile source discovery, defaulting, inference, lookup, sidecar loading,
  environment-variable loading, or config loading;
- finalize or normalize compiler profile sources in the CLI;
- change `IgniterLang.compile`;
- change `CompilerOrchestrator`;
- change `Assembler` validation semantics;
- edit `bin/igc` unless a proof demonstrates it is mechanically required for
  the already-authorized `IgniterLang::CLI` surface;
- edit `bin/igniter-lang` or the production compiler experiment CLI;
- migrate existing `.igapp` golden fixtures;
- add any production behavior.

---

## Required Proof Matrix

The C2-I proof must cover at least these cases.

### B4 Legacy No-Flag

```text
igc compile SOURCE --out OUT.igapp
```

Expected:

- exit zero for a valid source;
- stdout compiler_result JSON;
- stderr empty;
- `.igapp` emitted;
- `manifest.json` does not contain `compiler_profile_id`;
- behavior remains `legacy_optional`.

### Valid Profile Source Success

```text
igc compile SOURCE --out OUT.igapp --compiler-profile-source PATH.json
```

where `PATH.json` is the S3-R49 accepted standalone artifact:

```text
igniter-lang/experiments/minimal_compiler_profile_finalization_proof/out/compiler_profile_source.stage3_proof.json
```

Expected:

- exit zero for a valid source;
- stdout compiler_result JSON;
- stderr empty;
- `.igapp` emitted;
- `manifest.json` contains `compiler_profile_id` equal to the source object.

### B3 CLI Preflight Refusals

These cases must refuse before `IgniterLang.compile` is called:

- `--compiler-profile-source` without path;
- path not found;
- unreadable path when practical in local filesystem constraints;
- path is not a regular file;
- invalid JSON;
- JSON top-level value is not an object/hash;
- unsupported extra arguments in the accepted option set.

Expected for each preflight refusal:

- non-zero exit;
- stdout empty;
- one stable stderr line;
- no `OUT.compilation_report.json`;
- no `OUT.igapp`;
- no profile-source report JSON;
- no raw file contents;
- no parser backtrace;
- no bare forbidden tokens.

If local filesystem permissions make an unreadable-path case unreliable on the
runner, the proof may mark that one case as environment-constrained only if it
still proves directory/non-file and path-not-found refusals.

### B5 Semantic Source Refusals

For parsed JSON objects that reach `IgniterLang.compile` but fail existing
source validation, the proof must use the existing compiler/orchestrator/
assembler refusal path.

Minimum required semantic refusal cases:

- wrong `kind`;
- unfinalized `status`;
- runtime authority requested.

Expected:

- non-zero exit;
- stdout compiler_result JSON;
- stderr empty unless process-level failure occurs;
- `OUT.compilation_report.json` exists;
- `OUT.igapp` absent;
- refusal reasons use qualified `compiler_profile_source.*` vocabulary.

### B6 Scan And Scanner Self-Test

The proof must scan every stream and artifact recorded by the matrix:

- stdout compiler_result JSON;
- stderr text;
- proof summary JSON;
- every proof-local `.igapp/**/*.json`;
- every proof-local `OUT.compilation_report.json`.

Forbidden exact tokens:

```text
absent_legacy
present_verified
mismatch
malformed
missing_required
runtime_ready
evaluation_ready
gate3_authorized
runtime_authority
production_ready
```

The proof summary must record:

```text
forbidden_exact_token_hits: 0
scanner_self_test_bare_forbidden_token_fails: true
scanner_self_test_qualified_source_validation_allowed: true
allowed_qualified_source_validation_terms
scan_surface
```

The scanner self-test must prove both:

- injected bare forbidden token fails;
- qualified `compiler_profile_source.*` terms pass only as source-validation
  vocabulary, not loader-status/runtime-readiness vocabulary.

---

## Required Proof Summary Fields

The proof summary must include:

```text
kind
format_version
track
status
cases
commands
exitstatus
stdout_shape
stderr_text
artifact_paths
scan_surface
forbidden_exact_token_hits
scanner_self_test_bare_forbidden_token_fails
scanner_self_test_qualified_source_validation_allowed
allowed_qualified_source_validation_terms
legacy_no_flag_manifest_omits_compiler_profile_id
valid_profile_source_manifest_emits_compiler_profile_id
invalid_profile_source_no_igapp
```

---

## Remaining Blocker Status After This Decision

Still open until C2-I evidence and C3-X pressure land:

```text
PROP036-CLI-B3
PROP036-CLI-B4
PROP036-CLI-B5
PROP036-CLI-B6
PROP036-CLI-B9
```

Already closed:

```text
PROP036-CLI-B1
PROP036-CLI-B7
PROP036-CLI-B8
```

`PROP036-CLI-B2` remains satisfied by the approved shape
`--compiler-profile-source PATH.json`.

---

## Explicit Non-Authorizations

This decision does not authorize:

- closing B3/B4/B5/B6 without proof;
- closing B9 without pressure review;
- profile source discovery/defaulting/finalization in CLI/API;
- inline JSON CLI input;
- named generated profile lookup;
- environment/config/sidecar profile lookup;
- loader/report implementation beyond existing compiler refusal behavior;
- CompatibilityReport compiler-profile section;
- existing `.igapp` golden migration;
- `.ilk`;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- RuntimeMachine binding;
- Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

---

## Exact Next Card Boundary

The next allowed implementation card is:

```text
Card: S3-R50-C2-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop036-cli-profile-source-b3-b6-implementation-proof-v0
```

It must implement only the boundary in this decision and produce proof evidence
for B3/B4/B5/B6. After C2-I lands, `S3-R50-C3-X` must run pressure review before
any formal closure or next implementation decision.

---

## Compact Summary

S3-R50-C1-A authorizes the first bounded PROP-036 CLI implementation/proof
slice: `--compiler-profile-source PATH.json` in `IgniterLang::CLI`, transport
only, no discovery/finalization/defaulting, no runtime or production behavior.
The proof must cover hybrid B3 refusals, B4 no-flag legacy behavior, B5 invalid
source no-artifact behavior, and B6 full scan plus adversarial scanner self-test.
No blockers are closed by this authorization; B9 pressure follows the evidence.
