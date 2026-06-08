# PROP-036 Orchestrator Wiring Authorization Review v0

Card: S3-R42-C10-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop036-orchestrator-wiring-authorization-review-v0
Route: UPDATE
Status: approved-bounded-orchestrator-transport
Date: 2026-05-13

---

## Decision

**AUTHORIZE bounded CompilerOrchestrator transport wiring.**

`CompilerOrchestrator#compile` may accept an optional
`compiler_profile_source: nil` keyword and pass it unchanged to
`Assembler#assemble_artifacts`.

The orchestrator must be a transport boundary only. It must not derive,
finalize, load, discover, default, cache, or verify compiler profiles beyond
delegating the finalized source object to the assembler, which already owns
source validation for this slice.

---

## Evidence Read

- `docs/tracks/assembler-compiler-profile-id-field-v0.md`
- `docs/gates/prop036-assembler-field-implementation-reconsideration-v0.md`
- `docs/tracks/minimal-compiler-profile-finalization-proof-v0.md`
- `docs/proposals/PROP-036-compiler-profile-manifest-identity-v0.md`
- `lib/igniter_lang/compiler_orchestrator.rb`
- `lib/igniter_lang/assembler.rb`

---

## Findings

### Ready

C9 landed the assembler field support with the expected boundary:

- `Assembler#assemble_artifacts` accepts `compiler_profile_source: nil`;
- nil preserves `legacy_optional`;
- valid source emits top-level `manifest.compiler_profile_id`;
- `compiler_profile_id` enters hash material before `artifact_hash`;
- invalid source refuses through `AssemblyRefused`;
- C9 proof passed 19/19 and existing `igapp_assembler_proof` passed.

`CompilerOrchestrator` currently still calls:

```ruby
@assembler.assemble_artifacts(
  case_name: case_name_for(source_path, parsed),
  report: report,
  semantic_ir: semantic_ir,
  target_dir: out_path
)
```

Therefore the next change can be a small pass-through.

### Required Source Of `compiler_profile_source`

For C11, the exact source is:

```text
caller-supplied finalized compiler_profile_id_source object
```

The caller must have obtained that object out-of-band from a finalization layer
compatible with `minimal-compiler-profile-finalization-proof-v0`.

The orchestrator may not accept a raw `compiler_profile_id` string as authority.
The orchestrator may not construct a source object from partial fields. The
orchestrator may not load a profile from a default path, environment variable,
package registry, sidecar, `.ilk`, `.igapp`, or runtime state.

Assembler validation remains authoritative for the source object shape in this
slice.

---

## Authorized C11 Implementation Boundary

The next allowed implementation card is:

```text
Card: S3-R42-C11-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop036-orchestrator-profile-source-pass-through-v0
```

### Production Code Surface

Allowed production code change:

```text
lib/igniter_lang/compiler_orchestrator.rb
```

Allowed change:

```ruby
def compile(
  source_path:,
  out_path:,
  sample_input: nil,
  sample_input_resolver: nil,
  runtime_smoke: nil,
  compiler_profile_source: nil
)
```

and pass through:

```ruby
@assembler.assemble_artifacts(
  case_name: case_name_for(source_path, parsed),
  report: report,
  semantic_ir: semantic_ir,
  target_dir: out_path,
  compiler_profile_source: compiler_profile_source
)
```

No other `lib/` file is authorized by this decision.

### Semantics

`compiler_profile_source: nil`:

- preserves current legacy behavior;
- omits `manifest.compiler_profile_id`;
- does not change existing default compilation output.

`compiler_profile_source: <finalized Hash>`:

- is passed unchanged to `Assembler`;
- may result in profiled `.igapp` output if assembler validation succeeds;
- refuses through existing `AssemblyRefused` handling if assembler validation
  fails.

Invalid source:

- must surface as the existing orchestrator `assembler_refused` path;
- must not introduce loader/report compiler-profile status values.

---

## Required Proof Matrix

C11 must prove at least:

| Case | Required result |
| --- | --- |
| compile without source | `status == "ok"` and manifest omits `compiler_profile_id` |
| compile with valid finalized source | `status == "ok"` and manifest includes matching `compiler_profile_id` |
| profiled compile hash effect | artifact hash differs from legacy compile for same source |
| invalid source | orchestrator returns `status == "assembler_refused"` |
| invalid source reason | compilation report/error includes `compiler_profile_source.*` refusal text |
| no loader status leakage | no `absent_legacy`, `present_verified`, `mismatch`, `missing_required` status emitted |
| no runtime authority | output does not imply RuntimeMachine/Gate 3 readiness |
| no golden mutation | existing fixtures/goldens unchanged |

Required command matrix:

```text
ruby igniter-lang/experiments/prop036_orchestrator_profile_source_pass_through/prop036_orchestrator_profile_source_pass_through.rb
ruby -c igniter-lang/lib/igniter_lang/compiler_orchestrator.rb
```

Run an existing compiler smoke/regression only if the implementation changes a
path that smoke already covers.

---

## Fixture And Output Policy

The proof may write only into a new experiment output directory, for example:

```text
experiments/prop036_orchestrator_profile_source_pass_through/
  prop036_orchestrator_profile_source_pass_through.rb
  out/prop036_orchestrator_profile_source_pass_through_summary.json
```

Existing `.igapp` fixtures and goldens must not be migrated.

---

## Non-Authorizations

This decision does not authorize:

- profile finalization inside `CompilerOrchestrator`;
- profile discovery from env/config/files/registry/sidecars;
- default compiler profile injection;
- loader/report/CompatibilityReport implementation;
- `.ilk` changes;
- CompilationReceipt links;
- signing;
- production signer/key/HSM/KMS behavior;
- compiler dispatch migration;
- parser syntax;
- Classifier, TypeChecker, or SemanticIR changes;
- RuntimeMachine binding;
- RuntimeMachine execution authority;
- Gate 3 widening;
- Ledger or TBackend binding;
- BiHistory live execution;
- stream or OLAP production executors;
- production cache;
- production deployment;
- existing `.igapp` fixture/golden migration.

---

## Blockers After C11

Even if C11 passes, these remain separate future decisions:

- defining a real CompilerProfile finalization library/API;
- deciding where production-like compiler profile sources are produced;
- CLI/API exposure for `compiler_profile_source`;
- loader/report compiler-profile status implementation;
- CompatibilityReport compiler-profile section;
- golden migration for profiled `.igapp` artifacts;
- CompilationReceipt manifest links;
- `.ilk` profile references;
- signing and production verification;
- compiler dispatch migration.

---

## Compact Summary

C10 authorizes a bounded `CompilerOrchestrator` pass-through only.

C11 may add optional `compiler_profile_source: nil` to `compile` and forward it
unchanged to `Assembler#assemble_artifacts`. Nil keeps legacy output. Valid
source produces profiled output through the assembler. Invalid source refuses
through the existing `assembler_refused` path.

The orchestrator must not become a profile finalizer, loader, registry reader,
runtime authority, or production profile source.
