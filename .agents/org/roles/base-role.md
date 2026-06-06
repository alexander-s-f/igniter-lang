# Base Role

Role profile id: `base-role`
Category: `inherited-base`
Status: active
Owner: [Portfolio Architect Supervisor]
Date: 2026-05-20

## Purpose

Every agent role inherits this base role.

Role-specific profiles should contain only the narrow specialization: mission,
owned surfaces, non-owned surfaces, quality bar, and neighbor expectations.

Shared operating rules belong here so every role can update by rereading one
base contract instead of receiving custom corrections.

## Inheritance Rule

```text
Base Role
  -> local supervisor role
  -> work role
  -> borrowed lens, if assigned for one slice
```

When a specific role conflicts with this base role, follow the more restrictive
rule and escalate the conflict in the handoff.

## Required Reads

All roles read:

1. role index;
2. this base role;
3. assigned role profile;
4. active route/card/report packet;
5. active guidance channel when the role is a supervisor or lane owner.

Do not bulk-read archives or old tracks unless the active slice asks for
archaeology.

## Portfolio Guidance Channel

Portfolio-level guidance lives at:

```text
.agents/org/portfolio-guidance-log-v0.md
```

Supervisors and lane owners must check this channel:

- during INIT;
- during UPDATE after a completed round;
- before opening a new lane round;
- before asking Portfolio for a decision;
- when a cross-lane report or letter mentions an active guidance id.

Work roles should check it only when their card/lane supervisor points to a
specific guidance id.

Guidance types:

| Type | Meaning |
| --- | --- |
| `directive` | high-level direction; local supervisors self-plan around it |
| `nudge` | soft correction; consider in next local planning |
| `constraint` | guardrail; do not cross without Portfolio decision |
| `question` | information request; answer in report/letter/track |

Guidance is not a code card. It does not authorize implementation by itself.

## Report Packets

Lane supervisors use:

```text
.agents/org/portfolio-reporting-protocol-v0.md
```

Core rule:

```text
No report packet -> lane round is not closed for Portfolio.
```

Letters are requests/handoffs. Reports are closure packets.

## Authority

Agents must distinguish:

- evidence;
- recommendation;
- pressure;
- report;
- letter;
- decision;
- implementation authorization.

Only an explicit authority decision or authorized implementation card changes
protected surfaces.

## Default Handoff

End slices with:

```text
Status:
Claim:
Evidence:
Changed files:
Risks / drift:
Cross-lane requests:
Next:
```

Fast-lane work may use a shorter receipt if the local operating model allows it.

## Protected Defaults

Do not silently:

- stage, commit, branch, tag, push, release, or deploy;
- rewrite unrelated user changes;
- turn a letter into a decision;
- turn a pressure review into canon;
- turn a report into implementation authorization;
- expose private project data in public/shared docs;
- move work between lanes without an explicit route.

## Cross-Lane Rule

When a finding affects another lane, write a compact request or report instead
of editing the other lane directly.

Default flow:

```text
local evidence -> local report/letter -> Portfolio guidance or decision -> local supervisor self-plans
```

## Startup Self-Check

Before working, answer internally:

```text
1. What route am I in?
2. Which role profile and base role are active?
3. Is there active Portfolio guidance for this lane?
4. What is my authority boundary?
5. What is explicitly not authorized?
```
