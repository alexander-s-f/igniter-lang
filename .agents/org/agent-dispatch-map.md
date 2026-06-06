# Agent Dispatch Map

Status: active
Date: 2026-05-25

This map is a practical dispatch aid. A well-formed card carries enough role,
scope, authority, and deliverable context that many competent agents can execute
it even if the chat was accidentally opened in the wrong role. Prefer the
default owner, but do not block the round only because the exact title differs.

For platform-specific dispatch guidance across Codex, Claude, and Gemini, keep
platform notes in `.agents/org/` or in the assigned card packet.

## Dispatch Table

| Card suffix | Work mode | Default owner | Good substitutes | Typical deliverable |
| --- | --- | --- | --- | --- |
| `C*-A` | authority decision | Portfolio Architect Supervisor / Architect Supervisor | lane supervisor with explicit authority card | decision doc, next boundary |
| `C*-I` | implementation / execution | Implementation Agent | lane supervisor only for tiny doc-only execution | changed files, proof/evidence track |
| `C*-D` | design packet | Domain/Compiler/Release Designer | Igniter-Lang Supervisor, Research Agent | design track, options, recommendation |
| `C*-P1` | proof / prep / packet | lane specialist | supervisor fork, Research Agent, Meta Expert | proof/prep packet, matrix, recommendation |
| `C*-X` | pressure review | External Pressure Reviewer | Meta Expert, second supervisor instance | discussion doc, proceed/hold verdict |
| `C*-S` | status curation | Status Curator | Meta Expert, lane supervisor | round status, index/current-status sync |
| `C*-O` | org/process sidecar | Org Architect Supervisor | Portfolio Architect Supervisor | process/report/operating artifact |

## Role Defaults

| Need | Default agent | Notes |
| --- | --- | --- |
| Cross-lane decision | Portfolio Architect Supervisor | Owns Lang/Ruby/Spark direction and release authority boundaries. |
| Igniter-Lang lane decision | Igniter-Lang Supervisor | Good for design/proof routing; Portfolio decides cross-lane or release execution. |
| Compiler/profile/language design | Compiler/Profile Architect or Compiler/Grammar Expert | Use for contract, grammar, compiler profile, source-mode, OOF/registry semantics. |
| Proof-local experiment | Research Agent or Proof Agent | Should not mutate production code unless card explicitly allows it. |
| Code change | Implementation Agent | Must follow exact write scope and proof matrix. |
| Release target/package policy | Release Readiness Agent | Can be a borrowed lens on Igniter-Lang Supervisor or Meta Expert. |
| Evidence hygiene / non-claims | Meta Expert or External Pressure Reviewer | Good for hash, command traceability, wording safety. |
| Status/index/document sync | Status Curator | Should update current status and indexes, not reopen decisions. |
| Ruby Framework / Ledger | Ruby Framework Supervisor | Portfolio receives compact reports and only intervenes on cross-lane direction. |
| Spark applied pressure | Spark App Supervisor | Spark production authority remains local to Spark unless separately routed. |
| Org/document/process system | Org Architect Supervisor | Handles docs hygiene, memory, agent-process improvements. |

## Wrong-Chat Rule

If a card lands in the wrong agent chat:

1. If the card is self-contained and non-authority, the agent may execute it
   under the assigned role written in the card.
2. If the card is an authority decision (`*-A`) and the chat is not the named
   supervisor, the agent should either refuse/redirect or produce only a
   recommendation packet.
3. If implementation requires writes outside the card scope, the agent must hold
   and ask for a corrected card.
4. The handoff must disclose any role mismatch:

```text
role_mismatch: yes/no
executed_as_card_role: yes/no
authority_claimed: yes/no
```

## Quick Dispatch Mnemonic

```text
A = authority
I = implementation
D = design
P = proof/prep packet
X = pressure
S = status
O = org sidecar
```

Operational rule:

```text
Right card > perfect agent title, except for authority decisions.
```
