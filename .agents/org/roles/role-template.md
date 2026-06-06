# Igniter-Lang Role Template

Status: template
Maintainer: `[Architect Supervisor / Codex]`

Use this file as the starting shape for a new role profile.

---

## Role Identity

Role profile id: `<kebab-case-role-id>`
Default agent name: `[Igniter-Lang <Agent Name>]`

The role profile id is stable documentation/process identity. The agent name is
the concrete handoff/chat identity and may vary when the same role needs several
specialized agents.

---

## Mission

Describe what this role protects, discovers, proves, or pressures.

Keep it narrow enough that neighboring roles still have real ownership.

---

## Start

Read in this order:

1. `igniter-lang/AGENTS.md`
2. `igniter-lang/roles/README.md`
3. `igniter-lang/roles/base-role.md`
4. this role profile
5. `igniter-lang/handoff/INSTANCE_ROUTING.md`
6. choose route: `INIT`, `UPDATE`, `IN_FLIGHT_REFRESH`, `STALE_REFRESH`,
   `DISCUSSION`, or `STAGE_LOOP`
7. follow the route-specific reads
8. `igniter-lang/docs/org/portfolio-guidance-log-v0.md` when acting as a
   supervisor or lane owner
9. `igniter-lang/docs/README.md`
10. `igniter-lang/docs/operating-model.md`
11. `igniter-lang/docs/current-status.md`
12. `igniter-lang/docs/discussions/README.md` when `Mode: discussion` is assigned
13. relevant chapters in `igniter-lang/docs/spec/`
14. only the assigned track/proposal/source docs

Do not read archives, old tracks, package docs, or external project docs unless
the card explicitly asks for that context.

---

## Owns

- ...

---

## Does Not Own

- git cleanup
- unrelated dirty files
- neighboring role surfaces
- ...

---

## Default Output

End the slice with:

- compact claim
- decisions
- shipped signals or changed docs/proofs
- tests/proofs/evidence
- risks/recommendations
- changed files
- handoff

## Discussion Participation

If the card says `Mode: discussion`, follow
`igniter-lang/docs/discussions/README.md` instead of normal track/proposal
output.

End discussion output with:

- `[Agree]`
- `[Challenge]`
- `[Missing]`
- `[Sharper Question]`
- `[Route]`

---

## Neighbor Awareness

Ask `[Igniter-Lang Research Agent]` for executable proof pressure.

Ask `[Igniter-Lang Compiler/Grammar Expert]` for formal grammar/type/runtime
pressure.

Ask `[Igniter-Lang Bridge Agent]` for package/platform bridge mapping after
Architect approval.

Ask `[Igniter-Lang Meta Expert]` for priority and cross-cutting governance.

Ask `[Igniter-Lang Archive/Form Expert]` for historical signal recovery.
