# PROP-009.1: Resume Ordering Errata

Status: errata (patch to PROP-009 and PROP-011)
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Patches: `proposals/PROP-009-semantic-image-resume-compatibility-v0.md`,
          `proposals/PROP-011-runtime-machine-lifecycle-v0.md`

---

## Problem

PROP-009 states:

> `CompatibilityReport` is emitted as the **first platform_observation** of
> Session B (before AxiomDescriptor, before RuntimeContract).

PROP-011 Resume sequence states:

> 1. Boot(BootInputs for Session B) → AxiomDescriptor + RuntimeContract + TBackendDescriptor
> 2. VerificationReport (if run)
> 3. CompatibilityReport
> 4. Decision by ResumeStatus

These two rules **contradict each other**:
- PROP-009 says CompatibilityReport comes before AxiomDescriptor
- PROP-011 says AxiomDescriptor comes before CompatibilityReport

Additionally, the `CompatibilityReport` in PROP-009 references
`environment_ref.verification_report` — which means the `VerificationReport`
must already exist before the CompatibilityReport is assembled. This creates
a three-way ordering dependency that was not formally resolved.

---

## Root Cause

PROP-009 was written before PROP-011 formalised the full boot sequence.
The statement "emitted as the first platform_observation of Session B" was
intended to mean "the first **user-visible gate observation** of Session B"
— not "before any other observation including boot descriptors."

The CompatibilityReport cannot be assembled without:
1. Session B's `AxiomDescriptor` (to check `axiom_version` dimension)
2. Session B's `RuntimeContract` (to check `runtime_version` dimension)
3. Session B's `TBackendDescriptor` (to check `replay_availability`)
4. Session B's `VerificationReport` (to check `trust_level` dimension)

Therefore, CompatibilityReport **must come after** all four of these.

---

## Correction: Canonical Resume Observation Order

```text
Session B canonical resume observation order:

[Boot group — identity]
1.  Obs[:platform_observation, AxiomDescriptor]          (lifecycle: :durable)
2.  Obs[:platform_observation, RuntimeContract]          (lifecycle: :durable)
3.  Obs[:platform_observation, TBackendDescriptor]       (lifecycle: :durable)
4.  Obs[:platform_observation, BootReceipt { status }]  (lifecycle: :durable)

[Verification group — trust]
5.  Obs[:verification_observation, VerificationReport]  (lifecycle: :audit)
    -- REQUIRED before CompatibilityReport
    -- If verification_run: false in ResumeRequest:
       prior session's VerificationReport ref is used;
       if none exists: trust_level = :unknown -> ResumeStatus = :blocked

[Compatibility group — gate]
6.  Obs[:platform_observation, CompatibilityReport]     (lifecycle: :audit)
    -- assembled from (1)+(2)+(3)+(5) + Session A's SemanticImage
    -- THIS is the evaluation gate; nothing user-facing before this point

[Decision: based on CompatibilityReport.resume_status]
  :trusted / :provisional / :downgraded ->
7.  Obs[:platform_observation, LoadReceipt]             (proceed to evaluate)

  :blocked ->
7b. Obs[:failure_observation, constraint.resume_incompatible]
    -- halt; no load; no evaluate
```

**[D]** The `CompatibilityReport` is the **evaluation gate**, not the first
observation. The correct invariant is:

> **No user contract may be loaded or evaluated in Session B until
> `CompatibilityReport` is emitted and `resume_status != :blocked`.**

---

## Corrected Invariants

### PROP-009 correction

Replace:

> `CompatibilityReport` is emitted as the first `platform_observation` of
> Session B (before AxiomDescriptor, before RuntimeContract).

With:

> `CompatibilityReport` is emitted after Session B's `BootReceipt` and
> `VerificationReport`, and **before** any `LoadReceipt` or
> `EvaluationReceipt`. It is the **evaluation gate** of Session B.

### PROP-011 correction

The Resume sequence in PROP-011 §Step 5 is already correct in order
(Boot → Verification → Compatibility → Decision). The issue was only in
PROP-009's wording. No structural change to PROP-011 is needed.

---

## CompatibilityReport Gate Invariant (formal)

```text
GATE-1: ∀ obs ∈ {LoadReceipt, EvaluationReceipt, value_observation, ...}
  produced_in(obs) = session_b
  =>
  ∃ compat_obs: Obs[:platform_observation, CompatibilityReport]
    produced_in(compat_obs) = session_b
    AND seq_id(compat_obs) < seq_id(obs)
    AND compat_obs.payload.resume_status ≠ :blocked
```

A runtime that produces any user-visible observation before
`CompatibilityReport` in a resume session violates GATE-1 and is OOF.

---

## Verification Absence Rule

If `ResumeRequest.verification_run: false`:

```text
IF Session A's SemanticImage.verification_report_ref exists:
  use that VerificationReport for trust_level check
  (with dimension: trust_level = :conditional if verification is stale)

IF Session A's SemanticImage.verification_report_ref = None:
  trust_level = :unknown
  => CompatibilityDimension.trust_level = :blocked
  => ResumeStatus = :blocked
```

**[D]** Skipping verification is not free. A session without any
`VerificationReport` in its evidence chain is treated as `trust_level:
:unknown`, which blocks resume. This closes the loophole of skipping
verification to avoid a `:blocked` outcome.

---

## Updated CompatibilityDimension: trust_level

| Verification state | trust_level dimension | ResumeStatus effect |
|--------------------|-----------------------|---------------------|
| Fresh `:trusted` VerificationReport | `:compatible` | No impact |
| Fresh `:conditional` VerificationReport | `:downgrade` | → `:provisional` at minimum |
| Stale VerificationReport (prior session) | `:downgrade` | → `:provisional` at minimum |
| VerificationReport `trust_level: :untrusted` | `:blocked` | → `:blocked` |
| No VerificationReport anywhere | `:blocked` (`:unknown`) | → `:blocked` |

---

## Summary of Changes

| Document | Change |
|----------|--------|
| PROP-009 §CompatibilityReport as Observation | Wording corrected: gate observation, not first observation |
| PROP-009 §Decision Rules | Add verification absence rule |
| PROP-011 §Step 5 Resume | No structural change; ordering already correct |
| New: GATE-1 invariant | Formal ordering constraint added here |

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-009.1
Status: done

[D] Decisions:
- CompatibilityReport is the evaluation gate, not the first observation.
- Canonical resume order: Boot group (1-4) -> Verification (5) ->
  CompatibilityReport (6) -> decision.
- CompatibilityReport requires AxiomDescriptor, RuntimeContract,
  TBackendDescriptor, and VerificationReport to exist before assembly.
- Skipping verification (verification_run: false) uses prior session's
  VerificationReport or results in trust_level: :unknown -> :blocked.
- GATE-1 invariant: no user-visible observation before CompatibilityReport
  in a resume session.
- PROP-011 ordering is correct; PROP-009 wording was imprecise.

[X] Rejected:
- CompatibilityReport before AxiomDescriptor (impossible: it needs A.D. as input).
- Skipping verification without consequence.
```
