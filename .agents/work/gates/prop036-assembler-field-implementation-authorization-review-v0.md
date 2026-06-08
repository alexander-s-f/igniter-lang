# PROP-036 Assembler Field Implementation Authorization Review v0

Card: S3-R42-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop036-assembler-field-implementation-authorization-review-v0
Route: UPDATE
Status: hold-redirect
Date: 2026-05-13

---

## Decision

**HOLD / REDIRECT.**

The first bounded PROP-036 assembler implementation is not authorized yet.

The assembler field shape is ready, but the implementation request still lacks a
safe authoritative source for `compiler_profile_id`. Implementing a real
assembler field with a proof-local or hardcoded profile id would risk producing
artifacts that claim compiler-profile identity before the compiler can actually
derive or verify that identity.

No C4-I implementation may start from this decision.

---

## Evidence Read

- `docs/tracks/prop036-assembler-impact-survey-v0.md`
- `docs/tracks/prop036-assembler-implementation-contract-v0.md`
- `docs/proposals/PROP-036-compiler-profile-manifest-identity-v0.md`
- `docs/gates/prop036-compiler-profile-id-acceptance-decision-v0.md`
- `docs/tracks/prop036-loader-status-report-proof-v0.md`
- `docs/tracks/prop036-artifact-hash-ordering-proof-v0.md`
- `docs/tracks/prop036-assembler-field-design-plan-v0.md`
- `lib/igniter_lang/assembler.rb`
- `lib/igniter_lang/compiler_orchestrator.rb`

---

## Findings

### Ready

- The implementation surface is narrow and correctly identified:
  `lib/igniter_lang/assembler.rb`, especially `Assembler#build_artifact`.
- The field placement is clear: top-level `manifest.compiler_profile_id`.
- The hash-ordering invariant is clear:

```text
compiler_profile_id must enter artifact material before artifact_hash is computed
```

- Loader/report/status implementation remains separate.
- Compiler dispatch migration remains separate.
- RuntimeMachine binding remains separate.
- `legacy_optional` remains the initial rollout policy.
- `present_verified != runtime ready` remains a hard invariant.

### Not Ready

The origin of `compiler_profile_id` is not safely defined.

C1 identified three options:

1. proof-local constant;
2. parameter from orchestrator;
3. in-place CompilerProfile finalization.

Option 1 is not acceptable for a real assembler implementation because it would
let production-like assembler output claim a compiler profile without an
authoritative compiler profile source. It is useful for proof material only, not
for the first real assembler field.

Option 2 needs a defined caller/source contract.

Option 3 needs a separate bounded compiler-profile finalization design/proof.

Therefore the implementation authorization is held.

---

## Blockers Before Implementation Authorization

Before `assembler-compiler-profile-id-field-v0` can be authorized, a follow-up
card must close all of these blockers:

1. Define the authoritative source for `compiler_profile_id`.
2. Prove or specify how the source value is derived without migrating compiler
   dispatch.
3. Preserve the accepted value shape:

```text
compiler_profile_unified/sha256:<24+ lowercase hex chars>
```

4. Explain whether the assembler receives the id as a keyword, obtains it from a
   compiler-profile object, or derives it from a frozen profile descriptor.
5. Show how malformed or unavailable profile-id input is refused by the
   assembler without implementing loader/report status semantics.
6. Preserve `legacy_optional`.
7. Preserve `present_verified != runtime ready`.
8. Keep golden migration separate unless a later card names exact fixtures and
   expected hash churn.
9. Keep loader/report/status implementation separate.
10. Keep CompatibilityReport implementation separate.
11. Keep CompilationReceipt, signing, `.ilk`, compiler dispatch migration,
    RuntimeMachine binding, Gate 3, Ledger/TBackend, BiHistory, stream/OLAP
    executors, production cache, and production behavior out of scope.

---

## Authorized Redirect

The next safe card is design/proof-only:

```text
prop036-compiler-profile-id-source-contract-v0
```

Allowed scope:

- define the compiler-profile-id source contract;
- compare keyword parameter vs frozen profile descriptor vs minimal
  CompilerProfile finalization;
- produce refusal rules for missing/malformed source ids;
- preserve no-dispatch-migration;
- preserve no manifest mutation;
- preserve no runtime authority.

This redirect may be assigned to Compiler/Grammar Expert with Implementation
Agent support for code-surface realism.

---

## Non-Authorizations

This decision does not authorize:

- assembler implementation;
- `.igapp` manifest mutation;
- `.igapp` golden migration;
- `.ilk` changes;
- loader/report/status implementation;
- CompatibilityReport production changes;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- parser syntax;
- TypeChecker or SemanticIR changes;
- RuntimeMachine binding;
- RuntimeMachine execution authority;
- Gate 3 widening;
- Ledger or TBackend binding;
- BiHistory live execution;
- stream or OLAP production executors;
- production cache;
- production deployment.

---

## Compact Summary

Decision: **hold / redirect**.

PROP-036 assembler field implementation is close, but not yet authorized. The
field shape and hash-ordering rule are ready; the missing piece is an
authoritative `compiler_profile_id` source. A proof-local constant is not enough
for real assembler output. Open
`prop036-compiler-profile-id-source-contract-v0` before any C4-I implementation.
