# PROP-036 CLI/API Exposure Authorization Review v0

Card: S3-R44-C2-A
Agent: `[Architect Supervisor / Codex]`
Role: architect-supervisor
Track: `prop036-cli-api-exposure-authorization-review-v0`
Route: UPDATE
Status: approved-bounded-ruby-facade-exposure
Date: 2026-05-14

---

## Decision

Authorize the first bounded public caller surface for caller-supplied
`compiler_profile_source` through the Ruby facade only:

```ruby
IgniterLang.compile(
  source_path: source_path,
  out_path: out_path,
  compiler_profile_source: compiler_profile_source
)
```

This decision does not authorize a CLI flag, path-based profile loading, JSON
file parsing in the CLI, profile discovery, profile finalization, defaulting, or
any runtime/reporting surface.

The authorized public surface is a transport-only Ruby API pass-through from
`IgniterLang.compile` to `CompilerOrchestrator#compile`, preserving
`legacy_optional` when `compiler_profile_source` is nil.

---

## Evidence Read

- `docs/tracks/prop036-post-orchestrator-negative-artifact-scan-v0.md`
- `docs/gates/prop036-orchestrator-wiring-authorization-review-v0.md`
- `docs/tracks/prop036-orchestrator-profile-source-pass-through-v0.md`
- `docs/proposals/PROP-036-compiler-profile-manifest-identity-v0.md`
- `lib/igniter_lang.rb`
- `lib/igniter_lang/cli.rb`
- `bin/igc`
- `bin/igniter-lang`
- `rg "CompilerOrchestrator|compile\\(" igniter-lang`

---

## Findings

S3-R44-C1-P1 is sufficient for this bounded authorization:

- source finalization proof: PASS 22/22;
- assembler field proof: PASS 19/19;
- orchestrator pass-through proof: PASS 11/11;
- exact-token JSON scan: `json_files=49`, `exact_forbidden_hits=0`;
- refusal reports were included in the scan;
- substring hits were proof-local validation/check vocabulary, not loader status
  or runtime-readiness vocabulary.

Relevant public entry points discovered:

- `IgniterLang.compile` in `lib/igniter_lang.rb`;
- `IgniterLang::CLI.run` in `lib/igniter_lang/cli.rb`;
- `bin/igc`, which delegates to `IgniterLang::CLI.run`;
- `bin/igniter-lang`, which delegates to the production compiler CLI experiment.

The Ruby facade is the correct first public surface because it can pass a
caller-finalized object without introducing profile file loading, profile
discovery, defaulting, CLI syntax, or new JSON parsing policy.

The CLI remains held because a CLI flag would immediately require a path/file
input policy, parse/refusal wording, and another negative vocabulary scan.

---

## Authorized C3-I Boundary

```text
Card: S3-R44-C3-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop036-ruby-facade-profile-source-exposure-v0

Route: UPDATE
Depends on:
- S3-R44-C2-A approved-bounded-ruby-facade-exposure

Goal:
Expose caller-supplied finalized `compiler_profile_source` through the public
Ruby facade `IgniterLang.compile`, preserving nil legacy behavior.

Authorized files:
- igniter-lang/lib/igniter_lang.rb
- igniter-lang/experiments/prop036_ruby_facade_profile_source_exposure/
- igniter-lang/docs/tracks/prop036-ruby-facade-profile-source-exposure-v0.md

Allowed implementation:
- Add optional keyword `compiler_profile_source: nil` to `IgniterLang.compile`.
- Forward the keyword unchanged to `CompilerOrchestrator#compile`.
- Preserve all existing keywords and default behavior.
- Preserve `legacy_optional` when the keyword is nil.

Source input shape:
- Caller supplies the already-finalized source object/hash accepted by the
  existing assembler/orchestrator validation path.
- `IgniterLang.compile` must not finalize, discover, infer, load, normalize from
  a path, or default a compiler profile source.

Refusal behavior:
- Invalid non-nil source must refuse through the existing assembler/orchestrator
  compiler-profile-source refusal path.
- No loader-status vocabulary or runtime-readiness vocabulary may appear as
  exact JSON keys or scalar values in newly written JSON or refusal artifacts.

Proof matrix:
- `IgniterLang.compile(..., compiler_profile_source: nil)` succeeds and produces
  legacy output without `compiler_profile_id`.
- `IgniterLang.compile(..., compiler_profile_source: valid_source)` succeeds and
  writes top-level `compiler_profile_id`.
- `IgniterLang.compile(..., compiler_profile_source: invalid_source)` refuses
  before profiled artifact output.
- Existing CLI behavior remains unchanged.
- Negative vocabulary scan over newly written JSON/refusal artifacts reports
  exact forbidden-token hits: 0.
```

---

## Explicit Non-Authorizations

This decision does not authorize:

- CLI flags or CLI argument parsing for compiler profile sources;
- path-based profile source loading;
- JSON file parsing in CLI/API;
- profile finalization, discovery, inference, or defaulting in public caller
  surfaces;
- golden migration;
- loader/report implementation;
- CompatibilityReport compiler-profile section;
- `.ilk` changes;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- RuntimeMachine binding;
- Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP production executor;
- production cache;
- production behavior.

---

## Blockers Before CLI Exposure

A later CLI exposure decision must close, at minimum:

1. Exact CLI input shape: explicit path, inline JSON, or another bounded shape.
2. Parse and refusal wording for malformed input.
3. Proof that nil/no-flag CLI behavior remains legacy optional.
4. Negative vocabulary scan over all CLI-written JSON/refusal artifacts.
5. Pressure review for authority widening through path/file input.

---

## Compact Summary

S3-R44-C2-A approves only the Ruby facade exposure of
`compiler_profile_source`. It holds CLI exposure. C3-I may add an optional
`compiler_profile_source: nil` keyword to `IgniterLang.compile` and pass it
unchanged to `CompilerOrchestrator#compile`. All runtime, loader/report,
CompatibilityReport, dispatch, Ledger/TBackend, cache, production, and CLI flag
surfaces remain closed.
