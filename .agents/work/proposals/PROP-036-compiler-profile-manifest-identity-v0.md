# PROP-036: Compiler Profile Manifest Identity v0

Status: accepted; partial-impl  [compiler_profile_id; assembler manifest; CLI B1..B9 closed; see current-status.md]
Date: 2026-05-11
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Stage: 3
Authoring card: S3-R34-C5-P
Numbering authority: `docs/gates/compiler-profile-manifest-prop-number-decision-v0.md`
Source tracks:
- `docs/tracks/compiler-profile-id-manifest-boundary-plan-v0.md`
- `docs/tracks/compiler-profile-manifest-prop-review-ready-v0.md`
- `docs/tracks/compiler-profile-manifest-prop-promotion-v0.md`
- `docs/tracks/compiler-profile-manifest-prop-architect-routing-v0.md`
- `docs/tracks/compiler-profile-shadow-chain-dependency-index-v0.md`

---

## Queue And Authority Note

PROP-036 is assigned to `compiler_profile_id` manifest identity by the Architect
numbering decision `S3-R33-C3-A`.

That decision is numbering-only. This PROP authors the formal proposal text. It
does not approve implementation and does not mutate any `.igapp`, `.ilk`,
assembler, loader, RuntimeMachine, or compiler dispatch behavior.

Compiler profile identity proves **compiler understanding**, not runtime
execution authority.

---

## §1. Purpose

Igniter-Lang artifacts need a stable way to record which compiler profile was
allowed to understand and assemble them.

The current `.igapp/manifest.json` records source, grammar, SemanticIR,
fragment, contract index, and artifact hash information, but it does not record
the compiler surface that produced the artifact. As the compiler moves toward a
future Profile-Baseline-Pack architecture, tooling needs to distinguish:

- artifacts assembled by the legacy proof compiler;
- artifacts assembled by a known compiler profile;
- artifacts whose profile id is malformed or mismatched;
- future artifacts where profile identity is mandatory.

PROP-036 defines the manifest identity field:

```json
{
  "compiler_profile_id": "compiler_profile_unified/sha256:2944e573270aa56fca51cea3"
}
```

This field identifies a frozen compiler profile. It does not replace
`artifact_hash`, `semantic_ir_ref`, `compilation_report_ref`, approval tokens,
Gate 3 authority, TBackend capabilities, or runtime compatibility policy.

---

## §2. Terminology

| Term | Meaning |
| --- | --- |
| `CompilerProfile` | Frozen content-addressed description of installed compiler packs, slots, registries, ordered rules, and implementation identities. |
| `compiler_profile_id` | Stable manifest string naming the `CompilerProfile` that understood and assembled the artifact. |
| `CompilationReceipt` | Build evidence explaining how an artifact was produced. It may reference profile identity, but it is not the profile itself. |
| `legacy_optional` | Rollout policy where missing `compiler_profile_id` is tolerated as legacy. |
| `profile_required` | Future rollout policy where missing `compiler_profile_id` is a load/report refusal. |

`CompilerProfile` and `CompilationReceipt` are separate authority lanes:

```text
CompilerProfile      -> identifies compiler understanding
CompilationReceipt   -> explains build evidence
Runtime approval     -> authorizes runtime execution when separately granted
```

Neither the profile nor the receipt grants runtime execution authority.

---

## §3. Manifest Field Shape

### §3.1 Placement

`compiler_profile_id` is a top-level field in `.igapp/manifest.json`.

Canonical shape:

```json
{
  "kind": "igapp_manifest",
  "format_version": "0.1.0",
  "compiler_profile_id": "compiler_profile_unified/sha256:2944e573270aa56fca51cea3",
  "artifact_hash": "sha256:..."
}
```

### §3.2 Value Format

The value is a string:

```text
<profile-namespace>/sha256:<24+ lowercase hex chars>
```

The initial canonical namespace is:

```text
compiler_profile_unified
```

Rationale: the manifest should name the unified compiler profile, not merely the
ordered-rule profile. The ordered-rule profile remains useful supporting
evidence and transition diagnostic material, but it is not the final manifest
authority source in this proposal.

### §3.3 Minimality

The manifest field is intentionally small. PROP-036 does not inline the full
compiler profile object into `manifest.json`.

Future expanded profile material may live in a sidecar, receipt bundle, `.ilk`,
or a combination of those surfaces, but that storage decision is not authorized
here.

---

## §4. Compiler Profile Semantics

A valid `compiler_profile_id` means:

- the artifact claims to have been produced by the named compiler profile;
- the profile id fingerprints installed compiler capability slots;
- pack implementation identity changes the profile id;
- `CompilerProfileSpec.slot_order` is the canonical future dispatch order;
- surface order in source files is not authoritative for compiler dispatch.

The required exactly-one profile slots are:

```text
core
oof_registry
fragment_registry
escape_boundary
```

The current canonical slot order is:

```text
core
oof_registry
fragment_registry
escape_boundary
contract_modifiers
temporal
stream
olap
invariant
assumptions
evidence_observation
pipeline
```

This order is a profile identity input and a future dispatch-order source. It
does not migrate current compiler dispatch.

---

## §5. Rollout Policy

### §5.1 Initial policy: `legacy_optional`

Initial loaders and compatibility reports should use `legacy_optional`.

| Manifest state | Required result |
| --- | --- |
| field absent | accept/report `absent_legacy` |
| field present and verified | accept/report `present_verified` |
| field present but mismatched | refuse/report `mismatch` |
| field malformed | refuse/report `malformed` |

Existing `.igapp` artifacts do not have `compiler_profile_id`. They must remain
inspectable under `absent_legacy` until an explicit migration card changes that
policy.

### §5.2 Future policy: `profile_required`

`profile_required` is a future policy, not the initial state.

| Manifest state | Required result |
| --- | --- |
| field absent | refuse/report `missing_required` |
| field present and verified | accept/report `present_verified` |
| field present but mismatched | refuse/report `mismatch` |
| field malformed | refuse/report `malformed` |

`profile_required` may be considered only after:

1. PROP-036 is accepted.
2. An assembler implementation card is authorized and lands.
3. A loader/report implementation card is authorized and lands.
4. Artifact hash/golden migration is explicitly completed.
5. Existing legacy fixture treatment is documented.

---

## §6. CompatibilityReport Policy

Future CompatibilityReports may include a compiler profile section with at
least:

```json
{
  "compiler_profile": {
    "policy": "legacy_optional",
    "status": "present_verified",
    "manifest_profile_id": "compiler_profile_unified/sha256:2944e573270aa56fca51cea3",
    "expected_profile_id": "compiler_profile_unified/sha256:2944e573270aa56fca51cea3",
    "reason_code": null
  }
}
```

Required status vocabulary:

```text
absent_legacy
present_verified
mismatch
malformed
missing_required
```

Required reason codes:

```text
compiler_profile.absent_legacy
compiler_profile.present_verified
compiler_profile.mismatch
compiler_profile.malformed
compiler_profile.missing_required
```

The hard invariant is:

```text
compiler_profile_status.present_verified
  does not imply
runtime_evaluation_readiness.ready
```

Runtime readiness remains governed by runtime compatibility, Gate 3 policy,
approval tokens, TBackend capability checks, fragment support, and execution
scope.

---

## §7. Artifact Hash And Signing Policy

`compiler_profile_id` must participate in artifact hash material once it is
emitted by the assembler.

Required future ordering:

```text
finalize CompilerProfile
assemble manifest with compiler_profile_id
compute artifact_hash over profiled artifact material
sign artifact_hash and compiler_profile_id together
emit optional receipt/profile sidecars only after their own policy lands
```

Post-signing annotation is forbidden:

```text
assemble -> hash/sign -> add compiler_profile_id
```

The forbidden order would let the same signed artifact appear to have been
compiled under a different profile.

---

## §8. CompilationReceipt Relationship

CompilationReceipt may reference `compiler_profile_id` after manifest ordering
is stable.

Receipt relationship:

```text
receipt.compiler_profile_id == manifest.compiler_profile_id
```

when both are present.

But:

```text
CompilationReceipt explains build evidence.
CompilerProfile identifies compiler understanding.
Neither grants runtime execution authority.
```

Receipt storage, signing, sidecar layout, and `.ilk` links require separate
implementation and security review cards.

---

## §9. Loader And Assembler Requirements

This proposal defines future requirements only. It does not implement them.

### §9.1 Future assembler requirements

A future assembler card must:

- compute or receive the finalized `CompilerProfile`;
- write top-level `compiler_profile_id`;
- include the field before artifact hash computation;
- regenerate affected `.igapp` goldens intentionally;
- keep `legacy_optional` as the initial policy unless a later decision changes it;
- prove that adding or changing the profile id changes hash material.

### §9.2 Future loader/report requirements

A future loader/report card must:

- parse `compiler_profile_id` without treating it as runtime authority;
- distinguish `absent_legacy`, `present_verified`, `mismatch`, `malformed`, and
  `missing_required`;
- report the compiler profile status separately from runtime readiness;
- refuse malformed/mismatched profile ids before profile-sensitive execution;
- preserve legacy artifact inspectability under `legacy_optional`.

### §9.3 Future dispatch requirements

Future compiler dispatch migration may use `CompilerProfileSpec.slot_order`, but
that migration is out of scope for PROP-036.

PROP-036 does not route current Parser, Classifier, TypeChecker, SemanticIR
Emitter, Assembler, or RuntimeMachine execution through packs.

---

## §10. Acceptance Criteria

PROP-036 can be accepted as a proposal when:

1. This document exists under `docs/proposals/` with PROP-036 identity.
2. `docs/proposals/README.md` lists PROP-036 as an authored Stage 3 proposal.
3. The proposal states the Architect numbering decision as numbering-only.
4. The proposal defines top-level `compiler_profile_id` field shape.
5. The proposal chooses unified compiler profile id as the manifest authority
   source.
6. The proposal defines `legacy_optional` and future `profile_required` policies.
7. The proposal defines all compiler profile status values:
   `absent_legacy`, `present_verified`, `mismatch`, `malformed`,
   `missing_required`.
8. The proposal states that `present_verified` does not imply runtime readiness.
9. The proposal defines artifact hash/signing ordering.
10. The proposal separates `CompilerProfile` from `CompilationReceipt`.
11. The proposal lists implementation blockers before any code card.
12. No `.igapp`, `.ilk`, assembler, loader, runtime, or dispatch implementation
    changes are made by the authoring card.

---

## §11. Explicit Non-Authorizations

PROP-036 does not authorize:

- creating or editing `.igapp` manifest output;
- `.ilk` format changes;
- assembler implementation;
- loader implementation;
- RuntimeMachine binding;
- CompatibilityReport implementation changes;
- artifact hash/golden migration;
- CompilationReceipt manifest links;
- compiler dispatch migration;
- parser syntax;
- RuntimeMachine execution authority;
- Gate 3 widening;
- Ledger binding;
- Phase 2;
- BiHistory live execution;
- stream or OLAP production executors;
- production cache;
- production deployment.

---

## §12. Implementation Blockers Before Any Code Card

Before any code card may mutate assembler, loader, RuntimeMachine, `.igapp`,
`.ilk`, receipt, or golden output, all blockers below must close:

1. PROP-036 accepted by the owning governance flow.
2. Architect or owning supervisor explicitly opens the implementation card.
3. The implementation card names exactly one surface:
   - `assembler-compiler-profile-id-field-v0`
   - `loader-compiler-profile-status-report-v0`
   - `artifact-hash-profile-id-golden-migration-v0`
   - `compilation-receipt-manifest-link-v0`
4. The card states whether it is report-only, assembler-only, loader-only, or
   golden-migration-only.
5. The card preserves:
   - no runtime execution authority from profile identity;
   - no compiler dispatch migration;
   - no profile-required rollout until migration evidence exists.
6. For assembler work, the artifact hash impact must be proven before goldens
   are accepted.
7. For loader/report work, malformed, mismatched, absent legacy, and missing
   required cases must be separately tested.
8. For receipt links, manifest ordering must already be stable.

---

## §13. Deferred Questions

[Q] Which sidecar, if any, should hold expanded compiler profile material?

[Q] Should `.ilk` eventually sign `compiler_profile_id` directly, or only sign a
receipt/profile bundle that references it?

[Q] When should `legacy_optional` become `profile_required`, and who owns the
legacy fixture grandfathering policy?

[Q] Should ordered-rule profile ids remain visible as diagnostics after unified
compiler profile ids become canonical?

These questions do not block authoring PROP-036. They block implementation and
migration cards where relevant.
