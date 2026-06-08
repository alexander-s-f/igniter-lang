# Human-Agent Comprehension Testing v0

Role: `[Igniter-Lang Archive/Form Expert]`
Track: `human-agent-comprehension-testing-v0`
Status: research-method
Date: 2026-05-07

Related:
- [Syntax Density Research](syntax-density-human-agent-research-v0.md)
- [Human-agent syntax comprehension fixture](../../experiments/human_agent_syntax_comprehension_fixture/evaluator_guide.md)

---

## Purpose

This document records an off-track testing method for Igniter-Lang syntax and
language design.

It is not part of the main Stage 2 proof track. It is a pressure mechanism:

```text
give a non-trivial Igniter-Lang specimen to agents and humans without context,
then measure what meaning they recover, what they distort, and what they find
ambiguous.
```

The goal is to test whether Igniter-Lang can support the intended
human <-> agent collaboration model:

- compact enough to carry dense semantics
- explicit enough to avoid Ruby-style metamagic
- readable enough for humans
- structured enough for agents
- diagnostic enough for future compilers

---

## Method

1. Prepare a hypothetical but coherent Igniter-Lang program.
2. Do not explain the language or the domain beyond "unfamiliar language".
3. Ask each participant to explain:
   - what the program does
   - main data structures
   - temporal/history/stream/OLAP concepts
   - human review points
   - evidence/audit model
   - confusing or ambiguous syntax
4. Score comprehension with a small rubric.
5. Record distortions as syntax pressure, not participant failure.

The first fixture is:

```text
igniter-lang/experiments/human_agent_syntax_comprehension_fixture/field_supply_watch.ig
```

---

## What Counts As Signal

Useful signal includes:

- consistently understood constructs
- consistently misunderstood constructs
- places where agents hallucinate semantics
- places where humans read the domain correctly but miss formal meaning
- places where compactness hides important time/evidence/lifecycle claims
- places where explicitness becomes visual noise
- requests for syntax that would improve skimming
- requests for syntax that would harm auditability

The point is not to make every participant right. The point is to learn what the
surface form naturally communicates.

---

## First Review Signal

The first blind agent review of `field_supply_watch.ig` produced a strong
overall comprehension result.

Recovered well:

- field supply monitoring / logistics purpose
- streaming field reports
- normalization into demand signals
- recent-history corroboration and contradiction checks
- bitemporal inventory
- supplier offers over a future window
- regional posture and shortage calculation
- mesh delegation
- evidence/audit trail
- human override for high risk
- invariants as declared business rules

Useful distortions:

- `agent mesh` was interpreted as "neural network or autonomous AI".
- `evidence` was partly interpreted as cryptographic proof.
- warning vs blocking severity was not fully separated.
- repeated `compute` was flagged as possible visual noise.

These are valuable syntax pressure points:

```text
agent/mesh/tool/model vocabulary needs clearer separation
evidence/receipt/hash semantics should not be conflated
severity levels must be visually obvious
compute may need a density-friendly shorthand or formatting rule
```

---

## Scoring Rubric

Use 0-2 per dimension:

```text
0 -- missed or wrong
1 -- partially understood
2 -- clearly understood
```

Dimensions:

1. Overall purpose.
2. Data shape comprehension.
3. Temporal/history comprehension.
4. Stream/window comprehension.
5. Evidence/audit comprehension.
6. Human review/override comprehension.
7. Mesh/agent execution comprehension.
8. Risk/invariant comprehension.
9. Ability to identify ambiguity.
10. Ability to summarize without source-language context.

Maximum: 20.

Do not overfit to the score. The free-text misunderstandings are often more
valuable than the number.

---

## Pressure Routing

Comprehension test findings should route as follows:

| Finding type | Owning next role |
|--------------|------------------|
| syntax ambiguity | Compiler/Grammar Expert |
| semantic density issue | Archive/Form Expert or Meta Expert |
| real-system domain mismatch | Applied Pressure Agent |
| runtime/ledger/mesh implication | Bridge Agent |
| executable proof candidate | Research Agent |

This method should not directly author PROP docs. It should produce pressure
notes and, when repeated patterns emerge, request a formal slice.

---

## Guardrails

[D] This method does not promote hypothetical syntax to canon.

[D] Test programs may use future syntax, but must be labeled as hypothetical.

[D] Human and agent test responses should be treated symmetrically: both are
readers of a shared contract surface.

[D] A misunderstanding is not automatically a syntax bug. It becomes pressure
only when it repeats or exposes a high-stakes ambiguity.

[D] Do not optimize only for LLM comprehension. Human skimmability remains a
co-equal goal.

---

## Recommended Next Uses

[R1] Run the same specimen against 3-5 agents and 3-5 humans.

[R2] Record results in a small result note, not in current-status.md.

[R3] Create at most one new specimen per major language pressure area:

- logistics/ERP
- OSINT/fact-checking
- mesh/agent coordination
- scientific modeling
- durable workflow

[R4] Compare repeated findings against the syntax-density laws before changing
any grammar.

---

## Handoff

[D] Human-agent comprehension testing is now recorded as an off-track research
method.

[S] First review indicates the specimen communicates overall intent well, while
surfacing useful pressure around `agent mesh`, `evidence`, severity, and
`compute` visual density.

[R] Continue collecting blind reviews. After several reviews, synthesize a
small comprehension-results note and route repeated ambiguities to the proper
role.
