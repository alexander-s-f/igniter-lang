# Compiler Profile Manifest PROP Number Decision v0

Card: S3-R33-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: compiler-profile-manifest-prop-number-decision-v0
Status: approved-numbering-only
Date: 2026-05-11

---

## Decision

Assign **PROP-036** to the `compiler_profile_id` manifest feature.

Title:

```text
PROP-036 — Compiler Profile Manifest Identity
```

This decision is **numbering and routing only**. It does not create the proposal
file, does not approve the proposal, and does not authorize implementation.

---

## Rationale

The compiler profile manifest packet is review-ready enough to enter the formal
PROP lifecycle, but it was becoming a floating design assumption. Assigning a
number removes that ambiguity and lets future work say:

```text
compiler_profile_id manifest semantics belong to PROP-036.
```

The existing queue remains intact:

```text
PROP-033 = via profile binding
PROP-034 = output evidence syntax
PROP-035 = profile declarations / authority resolution
PROP-036 = compiler_profile_id manifest identity
```

Effect Surface remains queued but unnumbered until its own scoping/numbering
decision.

Numbering is not priority. PROP-036 may be authored and reviewed without jumping
ahead of urgent durable-audit or PROP-032 implementation work.

---

## Scope Of PROP-036

PROP-036 may define:

- top-level `compiler_profile_id` field shape;
- whether the field uses unified compiler profile identity;
- loader status vocabulary:
  - `absent_legacy`
  - `present_verified`
  - `mismatch`
  - `malformed`
  - `missing_required`
- `legacy_optional` vs future `profile_required` rollout policy;
- artifact hash/signature ordering requirements;
- CompatibilityReport fields for compiler profile status;
- relationship between `CompilerProfile` and `CompilationReceipt`;
- migration order and required golden regeneration plan.

PROP-036 must preserve:

```text
compiler_profile_status.present_verified
  does not imply
runtime_evaluation_readiness.ready
```

And:

```text
CompilerProfile proves compiler understanding only.
CompilationReceipt explains build evidence only.
Neither grants runtime execution authority.
```

---

## Non-Authorizations

This decision does not authorize:

- creating or editing `.igapp` manifest fields;
- `.ilk` format changes;
- assembler implementation;
- loader implementation;
- artifact hash/golden migration;
- compilation receipt manifest links;
- compiler dispatch migration;
- runtime execution authority;
- RuntimeMachine binding;
- Ledger, Phase 2, BiHistory, stream/OLAP production executor, production cache;
- production deployment.

The following implementation cards remain blocked until PROP-036 is authored,
accepted, and separately authorized:

```text
assembler-compiler-profile-id-field-v0
loader-compiler-profile-status-report-v0
artifact-hash-profile-id-golden-migration-v0
compilation-receipt-manifest-link-v0
```

---

## Follow-Up Docs To Sync

1. `docs/proposals/README.md`
   - Add `PROP-036` to the queued table.
   - Keep `PROP-033..035` unchanged.

2. `docs/tracks/README.md` and `docs/current-status.md`
   - Record P-41 closed by this decision during the next status curation pass.

3. `docs/dev/semantic-governance-heat-map.md`
   - If compiler profile identity is tracked there, mark it as queued proposal
     only, not implementation.

4. Future PROP-036 authoring card
   - Must use this decision as numbering authority.
   - Must not mutate `.igapp` fixtures or implementation.

---

## Compact Summary

Decision: **PROP-036 is assigned to Compiler Profile Manifest Identity**.

The feature now has a formal lifecycle slot. The queue remains stable:
PROP-033 via profile, PROP-034 output evidence, PROP-035 profile/authority,
PROP-036 compiler profile manifest identity. This decision does not authorize
implementation, `.igapp` changes, loader/assembler work, runtime binding, or
production behavior.

