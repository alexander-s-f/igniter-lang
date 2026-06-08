# PROP Governance Authority Decision v0

Card: S3-R31-C2-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop-governance-authority-decision-v0
Status: approved-authority-hierarchy
Date: 2026-05-10

---

## Decision

The **Language Covenant is the normative authority** for PROP acceptance.

META-EXPERT-013 remains the **operational routing and checklist document** for the
Stage 3 language lane. It must cite and defer to the Covenant when deciding whether
a PROP is acceptable.

This selects **Option A** from OQ-Filter-1:

```text
Covenant is normative. META-EXPERT-013 cites it and defers to it.
```

No new consolidated lifecycle document is required for Stage 3.

---

## Authority Rule

PROP acceptance now has two layers:

1. **Normative principle:** `language-covenant.md`
   - The PROP Governance Filter is the primary rule.
   - A PROP must answer whether it makes the audit trail more legible, neutral, or
     less legible.
   - A PROP that makes the audit trail less legible is rejected.
   - A PROP that cannot answer the legibility question is not ready for acceptance.

2. **Operational checklist:** `META-EXPERT-013-spec-extension-governance-v0.md`
   - Defines routing, sequencing, acceptance criteria templates, and role handoffs
     for the Stage 3 language lane.
   - Must include the Covenant PROP Governance Filter as a mandatory acceptance
     criterion.
   - May add stricter operational requirements, but may not weaken the Covenant.

If the Covenant and META-EXPERT-013 appear to conflict, the Covenant controls.

---

## Rationale

The Covenant owns language commitments: accountability, audit legibility, explicit
boundaries, and named semantic identity. Those commitments are the reason PROP
acceptance exists.

META-EXPERT-013 is valuable because it turns those commitments into a repeatable
work process for agents. It should not become a parallel authority. The clean
shape is:

```text
Covenant = what must remain true
META-EXPERT-013 = how agents prove and route it during Stage 3
```

Creating a third consolidated lifecycle document now would add ceremony without
reducing ambiguity. Consolidation can be reconsidered later if Stage 4 introduces
multiple concurrent language lanes.

---

## Immediate Effects

- OQ-Filter-1 is closed.
- P-31 is closed for the pre-production checklist.
- Future PROP authors must consult both documents, but precedence is now explicit:
  Covenant first, META-EXPERT-013 second.
- PROP acceptance criteria must include a Covenant legibility answer.
- PROP implementation cards must not begin merely because a PROP draft exists.
  Implementation still requires the appropriate acceptance / authorization gate.

---

## PROP-032 Boundary

This decision **does not authorize PROP-032 implementation**.

PROP-032 (`assumptions {}`) remains a draft/proposal surface until a later card
explicitly approves implementation. In particular, this decision does not authorize:

- parser changes
- classifier changes
- TypeChecker changes
- SemanticIR changes
- the new `epistemic` fragment class in code
- OOF-A1 implementation

The next PROP-032 gate/review card must use this authority hierarchy:

```text
1. Covenant PROP Governance Filter: normative legibility decision
2. META-EXPERT-013-style acceptance criteria: operational proof checklist
3. Implementation card: only after explicit approval
```

---

## Required Follow-Up Docs To Sync

1. `META-EXPERT-013-spec-extension-governance-v0.md`
   - Add a note that the Covenant PROP Governance Filter is the normative
     acceptance authority.
   - Update any Stage 3 priority table that still assigns PROP-032 to `via profile`
     if a separate GI-1 decision/curation card has already resolved that queue.

2. `language-covenant.md`
   - Mark OQ-Filter-1 as resolved by this decision.
   - Add a pointer from OQ-Filter-1 to this gate decision.

3. `current-status.md` and `tracks/README.md`
   - Record P-31 / OQ-Filter-1 as closed once status curation runs.

4. Any future PROP template or onboarding card that mentions PROP acceptance
   - State: "Covenant first, operational checklist second."

---

## Non-Authorizations

This decision does not authorize:

- new language semantics
- PROP-032 implementation
- Effect Surface implementation
- profile system implementation
- Ledger, Phase 2, BiHistory, stream/OLAP, production cache, writes/replay/compact/subscribe
- RuntimeMachine binding
- production deployment

---

## Compact Summary

Decision: **Covenant is normative; META-EXPERT-013 is operational.**

OQ-Filter-1 is closed. PROP authors must answer the Covenant audit-legibility
filter first, then satisfy the operational acceptance checklist. This removes the
split-authority ambiguity without introducing a new process document. PROP-032
remains draft-only and is not authorized for implementation by this decision.

