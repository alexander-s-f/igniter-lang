# PROP-036 Assembler Field Implementation Reconsideration v0

Card: S3-R42-C8-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop036-assembler-field-implementation-reconsideration-v0
Route: UPDATE
Status: approved-bounded-assembler-implementation
Date: 2026-05-13

---

## Decision

**AUTHORIZE bounded assembler-only implementation.**

`assembler-compiler-profile-id-field-v0` may begin because the missing
authoritative source blocker from S3-R42-C3-A is now closed by
`minimal-compiler-profile-finalization-proof-v0` with 22/22 checks PASS.

The authorization is narrow:

- implementation code may touch `lib/igniter_lang/assembler.rb`;
- proof/doc artifacts may be added under `experiments/` and `docs/tracks/`;
- `CompilerOrchestrator` must remain unchanged in this first assembler slice;
- existing `.igapp` goldens and fixtures must not be migrated.

---

## Evidence Read

- `docs/gates/prop036-assembler-field-implementation-authorization-review-v0.md`
- `docs/gates/prop036-source-contract-implementation-authorization-review-v0.md`
- `docs/tracks/minimal-compiler-profile-finalization-proof-v0.md`
- `experiments/minimal_compiler_profile_finalization_proof/out/minimal_compiler_profile_finalization_summary.json`
- `docs/tracks/prop036-source-contract-code-surface-survey-v0.md`
- `docs/proposals/PROP-036-compiler-profile-manifest-identity-v0.md`

---

## Findings

### Former Blocker Closed

S3-R42-C3-A held assembler implementation because the `compiler_profile_id`
source was not authoritative.

That blocker is now closed:

```text
minimal-compiler-profile-finalization-proof-v0 -> PASS 22/22
```

The proof demonstrates:

- a frozen descriptor finalizes into a C4-compatible
  `compiler_profile_id_source`;
- the id shape is `compiler_profile_unified/sha256:<24+ lowercase hex chars>`;
- key-order changes preserve the same id;
- implementation identity changes change the id;
- `compiler_profile_id` is excluded from the payload it hashes;
- runtime authority and dispatch migration are both refused when truthy;
- all required source refusal cases pass.

### Remaining Risk

The next risk is not source authority. It is accidental widening:

- silently changing default artifacts;
- mutating existing goldens;
- letting a raw id string become authority;
- adding loader/report status behavior in assembler;
- passing profile state through the orchestrator before that path is designed.

This decision authorizes only the minimum assembler field slice needed to prove
manifest placement and artifact hash ordering.

---

## Authorized C9 Implementation Boundary

The next allowed implementation card is:

```text
Card: S3-R42-C9-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: assembler-compiler-profile-id-field-v0
```

### Production Code Surface

Allowed production code change:

```text
lib/igniter_lang/assembler.rb
```

Allowed method changes:

- `assemble_case(case_name, compiler_profile_source: nil)`;
- `assemble_artifacts(case_name:, report:, semantic_ir:, target_dir:, compiler_profile_source: nil)`;
- private `build_artifact(case_name, report, semantic_ir, compiler_profile_source: nil)`;
- new private `validate_compiler_profile_source!(case_name, source)`;
- any tiny private helpers needed only by that validation.

No other `lib/` file is authorized.

### Transport Shape

The assembler receives a finalized source object:

```text
compiler_profile_source: <Hash>
```

The source object is the authority. A raw `compiler_profile_id:` string is not
authorized as an authority source.

Nil source behavior:

```text
compiler_profile_source: nil
```

means `legacy_optional`: omit `compiler_profile_id` and preserve existing
unprofiled assembler behavior.

### Validation Behavior

`validate_compiler_profile_source!` must run before `artifact_material` is
built when `compiler_profile_source` is not nil.

It must raise `AssemblyRefused` with `compiler_profile_source.*` reason text
for at least:

- non-hash source;
- wrong `kind`;
- non-`finalized` status;
- unsupported namespace;
- malformed `compiler_profile_id`;
- digest/id mismatch;
- slot-order mismatch;
- `runtime_authority_granted: true`;
- `dispatch_migration_authorized: true`.

It must not emit loader/report status values such as:

```text
absent_legacy
present_verified
mismatch
malformed
missing_required
```

### Artifact Hash Ordering

When a valid source is provided:

1. extract `compiler_profile_id`;
2. add it to `artifact_material` before `Canonical.hash(artifact_material)`;
3. compute `artifact_hash`;
4. add top-level `manifest["compiler_profile_id"]`;
5. ensure contract files receive the same `artifact_hash` as before.

Adding `compiler_profile_id` after `artifact_hash` is computed is forbidden.

### Fixture And Golden Policy

Existing fixture/golden mutation is not authorized.

Required proof may write only into a new experiment output directory, for
example:

```text
experiments/assembler_compiler_profile_id_field/
  assembler_compiler_profile_id_field.rb
  out/assembler_compiler_profile_id_field_summary.json
```

Existing `.igapp` fixtures must remain legacy/unprofiled unless a later
golden-migration decision names exact fixtures and expected hash churn.

---

## Required Proof Matrix

C9 must prove at least:

| Case | Required result |
| --- | --- |
| legacy no-source assembly | no `manifest.compiler_profile_id`; existing behavior preserved |
| valid source assembly | top-level `manifest.compiler_profile_id` emitted |
| valid source hash ordering | `artifact_hash` changes because profile id is in hash material |
| profile id changed | `artifact_hash` changes |
| post-hash annotation model | proven forbidden or not produced by implementation |
| non-hash source | `AssemblyRefused` |
| wrong kind | `AssemblyRefused` |
| unfinalized source | `AssemblyRefused` |
| unsupported namespace | `AssemblyRefused` |
| malformed id | `AssemblyRefused` |
| digest/id mismatch | `AssemblyRefused` |
| slot-order mismatch | `AssemblyRefused` |
| runtime authority true | `AssemblyRefused` |
| dispatch migration true | `AssemblyRefused` |
| loader status leakage | no loader status values emitted |

Required command matrix:

```text
ruby igniter-lang/experiments/assembler_compiler_profile_id_field/assembler_compiler_profile_id_field.rb
ruby -c igniter-lang/lib/igniter_lang/assembler.rb
```

Run additional existing assembler or compiler smoke commands only if the
implementation changes a path those commands exercise.

---

## Non-Authorizations

This decision does not authorize:

- `CompilerOrchestrator` changes;
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

## Blockers After C9

Even if C9 passes, these remain separate future decisions:

- orchestrator wiring to provide a finalized source object;
- loader/report compiler-profile status implementation;
- CompatibilityReport compiler-profile section;
- golden migration for profiled `.igapp` artifacts;
- CompilationReceipt manifest links;
- `.ilk` profile references;
- signing and production verification;
- compiler dispatch migration.

---

## Compact Summary

C8 authorizes `assembler-compiler-profile-id-field-v0` as a bounded
assembler-only implementation.

C9 may add optional `compiler_profile_source:` transport to `Assembler`, validate
the finalized source object, inject `compiler_profile_id` into hash material
before `artifact_hash`, and emit top-level `manifest.compiler_profile_id` only
when a valid source is supplied.

Legacy no-source behavior must remain unchanged. Existing goldens are not
migrated. Runtime, loader, report, orchestrator, dispatch, Ledger/TBackend, and
production behavior remain closed.
