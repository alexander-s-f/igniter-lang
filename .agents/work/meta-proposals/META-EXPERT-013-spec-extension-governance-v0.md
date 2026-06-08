# META-EXPERT-013: Spec Extension Governance — Contract Modifiers, Profiles, Effects v0

Card: S3-R26-C1-M (external pressure routing)
Agent: [Igniter-Lang Meta Expert]
Role: meta-expert
Date: 2026-05-10
Status: active governance
Supersedes: nothing (new scope)

---

## I. Situation

External pressure review (`[Igniter-Lang External Pressure Reviewer]`) produced:

- `docs/spec-extension-gap-analysis.md` — impl-level gap map (Gap-A through Gap-G)
- Three hypothetical application programs in `experiments/external_pressure_specimens/`

The programs (NewsClarityAggregator, IgniterSwarmTriangulationV1,
RealTimeVideoProcessorV1) were compiled against the spec. None compile against
igniter-lang v0.1.0.pre.stage2 because the following are absent from the grammar:

1. Contract modifiers (`pure/observed/effect/privileged/irreversible`) — **CRITICAL**
2. `via profile_name` binding on contract declarations — **HIGH**
3. Profile declarations as top-level language construct — **HIGH**
4. Effect Surface (7 mandatory fields for effect/privileged/irreversible) — **HIGH**
5. `output ... evidence [refs]` provenance syntax — **MEDIUM**
6. Service loops with heartbeat/checkpoint/cancellation semantics — **MEDIUM**

All six are additive. None break existing programs. The existing spec (ch1–ch9) accurately
describes Stage 1–2 implementation. These additions are Stage 3+ scope.

---

## II. Decisions

### Authority Note: Covenant First, META-013 Operational

**Decision: The Language Covenant is the normative authority for PROP
acceptance. META-EXPERT-013 is the operational routing and checklist document
for Stage 3 language-lane work.**

Authority reference:
`docs/gates/prop-governance-authority-decision-v0.md` (S3-R31-C2-A).

Every PROP acceptance review must answer the Covenant PROP Governance Filter
first: whether the proposed feature makes the audit trail more legible, neutral,
or less legible. META-EXPERT-013 supplies sequencing, role handoffs, and
acceptance checklist shape, but it may not weaken the Covenant. If this document
and the Covenant appear to conflict, the Covenant controls.

### Decision 1: Spec Placement — Extend, Do Not Replace

**Decision: Add new spec chapters ch10+ alongside ch1–ch9. Do not modify ch1–ch9.**

Rationale:
- ch1–ch9 = ground truth for Stage 1–2 impl; 25/25 regression PASS; agent references are live
- New concepts are additive — they do not contradict ch1–ch9, they extend it
- Replacing mid-Stage-3 would invalidate live agent references and break regression anchors
- "Extend" is the correct posture: ch10 = contract modifiers, ch11 = profile system,
  ch12 = effect surface, ch13 = managed recursion / service loops

New chapters carry status `proposed` until the corresponding PROP-03x lands and regression
suite passes. At that point they are promoted to `accepted` (same lifecycle as ch1–ch9).

Ch2 (source-surface.md) gains a minor addendum for the modifier prefix grammar change
when PROP-031 lands. This is not a replacement — it is a versioned extension note.

### Decision 2: Language Policy — English Canonical

**Decision: All spec, proposal, and meta-proposal documents are authored in English.**

- English = canonical for public-facing and cross-agent communication
- Russian companion documents permitted for complex design decisions or discussion artifacts
- Russian companions use suffix `.ru.md` (e.g., `ch10-contract-modifiers.ru.md`)
- Russian-language research notes are private source material, not canonical —
  they are rewritten in English when entering igniter-lang as PROP-* or spec chapters
- This policy applies from S3-R26 forward; older Russian documents are not retroactively
  translated unless a card assigns it

### Decision 3: Transition Entry Route

External Pressure Reviewer findings enter igniter-lang through the standard route:

```
External Pressure Reviewer (findings in docs/ + experiments/)
  → META-EXPERT-013 (this document — routing decision)
  → [Compiler/Grammar Expert]: PROP-031, PROP-032, PROP-033, PROP-034
  → [Research Agent]: regression fixtures for each PROP
  → [Meta Expert]: round-close curation after each PROP lands
```

This is NOT a "spec migration". It is a phased additive extension through normal PROP process.

---

## III. Priority Ordering

### Phase 1 — Stage 3 Language Lane

Rationale: These are additive language-lane proposals. Backward compatibility and
implementation authorization are proven per PROP, not inferred from this routing
table.

| Order | PROP | Title | Key change |
|-------|------|-------|------------|
| 1 | PROP-031 | Contract Modifiers | Optional modifier prefix; 5 fragment-class extensions |
| 2 | PROP-032 | `assumptions {}` Block | Declared assumptions + `uses assumptions NAME`; proposal only until explicit implementation/proof |
| 3 | PROP-033 | `via profile` Binding | Optional clause on contract declaration |
| 4 | PROP-034 | `output ... evidence [refs]` | Optional evidence provenance in output |

PROP-031 is the gating dependency. PROP-032 is proposal-only until an explicit
implementation/proof card authorizes compiler work. PROP-033 and PROP-034 remain
queued language-lane proposals and do not authorize parser/compiler changes until
their own proposal and proof cards land.

### Phase 2 — New Lane (Architect decision required)

| Order | PROP | Title | Dependency |
|-------|------|-------|------------|
| 5 | PROP-035 | Profile Declarations / Authority Resolution | PROP-031 + PROP-033 |
| TBD | TBD | Effect Surface | PROP-031 (effect modifier must exist) |

Profile declarations require a new compiler pass (policy-gate enforcement). This is
semantic scope, not parser scope. Needs Architect authorization for new Lane.

### Phase 3 — Stage 4 (deferred)

Service loops, managed recursion, view declarations, placement declarations.
Not in scope for Stage 3 Language Lane.

---

## IV. Spec Chapter Map

New chapters to be authored (English, status: proposed until PROP lands):

| Chapter | File | Source material | PROP dependency |
|---------|------|-----------------|-----------------|
| ch10 | `ch10-contract-modifiers.md` | PROP-Contract-v0 §1, §1.1 | PROP-031 |
| ch11 | `ch11-profile-system.md` | PROP-Profile-v0 §2–6 | PROP-035 |
| ch12 | `ch12-effect-surface.md` | PROP-External-Effects-v0 | TBD |
| ch13 | `ch13-managed-recursion.md` | PROP-Loop-v0 | Stage 4 |

ch10 stub is created now (proposed status) to anchor grammar discussion.
ch11–ch13 stubs created now (proposed status) to establish chapter structure.

---

## V. Requests to Neighboring Roles

**→ [Igniter-Lang Compiler/Grammar Expert]:**

1. Keep `PROP-032-assumptions-block-v0.md` proposal-only until an explicit implementation/proof card
2. Author `PROP-033-via-profile-binding-v0.md` after PROP-031 regression PASS
3. Author `PROP-034-output-evidence-syntax-v0.md` after PROP-031 regression PASS
4. Keep `ch10-contract-modifiers.md` as the accepted anchor for PROP-031 work

**→ [Igniter-Lang Research Agent]:**

1. Prepare PROP-032 implementation fixtures only when the explicit implementation/proof card lands.
2. Keep existing PROP-031 fixtures as regression anchors for modifier behavior.

**→ [Igniter-Lang Meta Expert] (self):**

1. Open Architect channel for Phase 2 Lane decision only when a queued Phase 2 card is ready
2. Update `current-status.md` after each PROP-03x closes

---

## VI. PROP-031 Acceptance Criteria

Proposed acceptance criteria for `[Architect / Codex]` approval:

1. Parser accepts `[modifier] contract Name(params) { body }` — modifier is optional
2. `contract Foo {}` without modifier = `pure contract Foo {}` — backward compat verified
3. Classifier maps modifier → fragment class:
   - `pure` → CORE
   - `observed`, `effect`, `privileged`, `irreversible` → ESCAPE
4. TypeChecker: `pure` contract body cannot contain `escape` declarations (OOF-M1)
5. SemanticIR: `contract_ir` node emits `modifier` field (default: `"pure"`)
6. All existing Stage 1–2 regression fixtures PASS without modification
7. Positive fixtures for all 5 modifiers PASS
8. Negative fixture for `pure` + `escape` combination produces OOF-M1

---

## VII. New OOF Error Codes Introduced

| Code | Trigger | Severity |
|------|---------|----------|
| OOF-M1 | `pure contract` body contains `escape` declaration | error |
| OOF-M2 | `effect/privileged/irreversible` without required Effect Surface fields | error (Phase 2) |
| OOF-M3 | `irreversible` without `compensation` or explicit `no_compensation` | warn (Phase 2) |

OOF-M2 and OOF-M3 are deferred to the future Effect Surface PROP. Document now
to reserve codes.

---

## VIII. Affected Neighbors

- `[Igniter-Lang Compiler/Grammar Expert]` — PROP-031..033 authorship
- `[Igniter-Lang Research Agent]` — regression fixtures
- `[Igniter-Lang Bridge Agent]` — notify: no platform integration changes in Phase 1
- `[Igniter-Lang Applied Pressure Agent]` — can use new modifier syntax in pressure specimens
  once PROP-031 lands
- `[Architect / Codex]` — Phase 2 Lane authorization request (deferred to post-PROP-031)

---

## IX. Handoff

```
Current:      PROP-031 is experiment-pass; PROP-032 is proposal with Phase 1 gate satisfied
Next action:  PROP-032 implementation/proof card may proceed only under its explicit gate
Then:         PROP-033 + PROP-034 remain queued; each needs its own proposal/proof path
Then:         Architect request for Phase 2 Lane (Profile / Authority + Effect Surface) only when scoped
```

Blocker: no authority blocker for this routing note. This document does not
authorize PROP-032 implementation beyond the existing gate status.
