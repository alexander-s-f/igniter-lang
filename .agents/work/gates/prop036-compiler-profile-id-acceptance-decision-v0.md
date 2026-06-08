# PROP-036 Compiler Profile ID Acceptance Decision v0

Card: S3-R35-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop036-compiler-profile-id-acceptance-decision-v0
Status: accepted-proposal-only
Date: 2026-05-11

---

## Decision

Accept **PROP-036 — Compiler Profile Manifest Identity** as a Stage 3 proposal.

This is proposal acceptance only. It does not authorize implementation,
artifact mutation, loader/assembler changes, compiler dispatch migration,
runtime binding, or production behavior.

Accepted proposal:

```text
docs/proposals/PROP-036-compiler-profile-manifest-identity-v0.md
```

Numbering authority:

```text
docs/gates/compiler-profile-manifest-prop-number-decision-v0.md
```

---

## Rationale

PROP-036 is ready to be accepted at the proposal layer because it satisfies the
numbering decision and preserves the authority firewall required by the
compiler-profile shadow chain.

The accepted semantic boundary is:

```text
compiler_profile_id identifies compiler understanding.
compiler_profile_id does not grant runtime execution authority.
```

The hard invariant remains:

```text
compiler_profile_status.present_verified
  does not imply
runtime_evaluation_readiness.ready
```

The proposal correctly separates:

```text
CompilerProfile      -> compiler understanding identity
CompilationReceipt   -> build evidence
Runtime approval     -> execution authority from separate gates
```

---

## Acceptance Criteria Review

| Criterion | Decision |
|-----------|----------|
| PROP-036 document exists under `docs/proposals/` | PASS |
| `docs/proposals/README.md` lists PROP-036 as authored Stage 3 proposal | PASS |
| Numbering decision is cited as numbering-only | PASS |
| Top-level `compiler_profile_id` field shape is defined | PASS |
| Unified compiler profile id is chosen as manifest authority source | PASS |
| `legacy_optional` and future `profile_required` policies are defined | PASS |
| Status vocabulary is defined: `absent_legacy`, `present_verified`, `mismatch`, `malformed`, `missing_required` | PASS |
| `present_verified` does not imply runtime readiness | PASS |
| Artifact hash/signing ordering is defined | PASS |
| `CompilerProfile` and `CompilationReceipt` remain separate | PASS |
| Implementation blockers are listed before code cards | PASS |
| Authoring card made no `.igapp`, `.ilk`, loader, assembler, runtime, or dispatch implementation changes | PASS |

---

## Authorized Next Design / Proof Boundaries

This decision authorizes only future **design/proof cards** that stay within the
accepted proposal boundary.

Allowed next cards:

```text
prop036-loader-status-report-proof-v0
```

May model `absent_legacy`, `present_verified`, `mismatch`, `malformed`, and
`missing_required` as proof-local report states. It must not implement or wire a
production loader.

```text
prop036-artifact-hash-ordering-proof-v0
```

May prove, using synthetic/proof-local artifact material, that
`compiler_profile_id` participates in hash material before signing. It must not
mutate real `.igapp` goldens or production artifact output.

```text
prop036-assembler-field-design-v0
```

May design the future assembler surface and golden migration plan. It must not
edit assembler code, current `.igapp` fixtures, or artifact hash goldens.

```text
prop036-compilation-receipt-link-design-v0
```

May design the relationship between `manifest.compiler_profile_id` and future
`receipt.compiler_profile_id`. It must not implement receipt storage, signing,
sidecars, or `.ilk` links.

Any code-changing implementation card still requires a separate Architect
authorization.

---

## Non-Authorizations

This decision does not authorize:

- creating or editing `.igapp` manifest output;
- `.ilk` format changes;
- assembler implementation;
- loader implementation;
- CompatibilityReport implementation changes;
- artifact hash/golden migration;
- CompilationReceipt manifest links;
- compiler dispatch migration;
- parser syntax;
- RuntimeMachine binding;
- RuntimeMachine execution authority;
- Gate 3 widening;
- Ledger binding;
- Phase 2;
- BiHistory live execution;
- stream or OLAP production executors;
- production cache;
- production deployment.

---

## Blockers Before Any Implementation Card

Before any implementation card can be authorized, the requesting card must:

1. cite this decision and the accepted PROP-036 document;
2. name exactly one implementation surface;
3. state whether it is assembler-only, loader-only, report-only,
   golden-migration-only, or receipt-link-only;
4. preserve the invariant that compiler profile verification is not runtime
   readiness;
5. preserve `legacy_optional` as the initial rollout policy unless a later
   Architect decision changes it;
6. include a proof plan for all affected status values or hash/golden effects;
7. explicitly exclude compiler dispatch migration and RuntimeMachine binding
   unless separately authorized by a later gate.

---

## Compact Summary

Decision: **accept PROP-036 as proposal-only**.

PROP-036 is now the accepted Stage 3 proposal for `compiler_profile_id` manifest
identity. The next work may design and prove loader-status, hash-ordering,
assembler-field, and receipt-link boundaries, but implementation remains closed.
No `.igapp`, loader, assembler, compiler dispatch, runtime, Ledger, Phase 2, or
production behavior is authorized by this decision.
