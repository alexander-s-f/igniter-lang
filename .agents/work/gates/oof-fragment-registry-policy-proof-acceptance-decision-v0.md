# OOF/Fragment Registry Policy Proof Acceptance Decision v0

Card: LANG-R96-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: oof-fragment-registry-policy-proof-acceptance-decision-v0
Status: accepted-pinv-tinv-lifecycle-design-next-implementation-held
Date: 2026-05-20

---

## Decision

Accept the R95 OOF/Fragment Registry policy proof as proof-only evidence:

```text
accepted as proof-only policy model
implementation remains held
```

Accepted proof track:

```text
igniter-lang/docs/tracks/oof-fragment-registry-policy-proof-v0.md
```

Accepted proof result:

```text
PASS
cases: 16/16
checks: 7/7
policy_id: oof_fragment_policy/sha256:027ba71cd5a14c104b3b246a
recommendation: PASS_FOR_PROOF_ONLY_POLICY_MODEL_HOLD_IMPLEMENTATION
```

No implementation, spec, canon, compiler, runtime, registry, dispatch, public
API/CLI, loader/report, CompatibilityReport, `.igapp`, Ledger/TBackend, cache,
signing, or production behavior is authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/tracks/oof-fragment-registry-ownership-and-canon-semantics-design-v0.md`
- `igniter-lang/docs/discussions/oof-fragment-registry-design-pressure-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-policy-proof-v0.md`
- `igniter-lang/experiments/oof_fragment_registry_policy_proof/out/oof_fragment_registry_policy_proof_summary.json`
- `igniter-lang/experiments/oof_fragment_registry_policy_proof/out/oof_fragment_registry_policy_model.json`
- `igniter-lang/docs/gates/oof-fragment-registry-shadow-proof-decision-v0.md`

---

## Accepted Proof Disposition

R95 is accepted for the policy areas it actually proved:

| Policy area | Accepted disposition |
| --- | --- |
| Alias / collision policy | Proof covers unique descriptor codes, compatibility-alias descriptors, replacement existence, current replacement requirement, and alias collision rejection. |
| OOF projection guard | Proof covers status-primary, blocked, non-loadable, status-only, capability-free projection. |
| Guarded non-fragments | Proof covers `olap` and `progression` as guarded non-fragment surfaces that cannot be promoted, given precedence, or made loadable. |
| Exclusion namespaces | Proof covers `compiler_profile_contract.*` and `compiler_profile_contract_refusal.*` as excluded from OOF descriptors and aliases. |

These areas no longer need another immediate proof pass before the next design
slice.

R95 does not close implementation readiness.

---

## Clarifications

Forward vocabulary:

```text
OOF registry service
```

`OOFRegistryPack` in R91/R92/R95 proof-local JSON or prose is a shadow artifact
name only. It must not be interpreted as an ordinary optional language pack or
as a live pack registry implementation.

Forward OOF semantics:

```text
status-primary / secondary fragment projection
```

The projection remains blocked, non-loadable, status-only, and capability-free.
It is not an execution mode and not a loadable artifact class.

Forward guarded non-fragment invariant:

```text
guarded_non_fragment != candidate_fragment
```

`olap` and `progression` remain guarded non-fragment classes unless a separate
future proposal/spec/gate explicitly changes that.

---

## Next Route Decision

Open only the PINV/TINV lifecycle design route next:

```text
pinv-tinv-lifecycle-and-registry-classification-design-v0
```

Route type:

```text
design-only
no implementation
no spec/proposal/canon mutation
no live registry
no compiler/runtime changes
```

Reason:

- R95 closes the proof-local policy model for alias/collision, OOF projection,
  guarded non-fragments, and profile-contract namespace exclusion.
- R93/R95 both keep `PINV-*` / `TINV-*` treatment open as a blocker before
  implementation.
- Opening implementation-boundary design now would be premature because the
  lifecycle/classification of these invariant markers is still unresolved.

Do not open implementation-boundary design yet.

---

## Exact Next Allowed Boundary

```text
Card: LANG-R97-D1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Route: UPDATE
Track: pinv-tinv-lifecycle-and-registry-classification-design-v0

Goal:
Decide the design-only lifecycle and registry classification for `PINV-*` and
`TINV-*` before any OOF/Fragment Registry implementation-boundary design.

Scope:
- Read R93 design, R94 pressure, R95 proof, and this R96 decision.
- Decide whether `PINV-*` and `TINV-*` should be:
  - proof markers only;
  - OOF descriptor entries with `proof_only` / `candidate_proof_only`
    stability;
  - invariant/support metadata outside the OOF descriptor registry;
  - or another explicitly bounded classification.
- Define lifecycle states for any chosen classification:
  proof-only, candidate, descriptor-only, current, deprecated, or excluded.
- Define public-code stability posture and source-authority requirements.
- Preserve profile-contract diagnostic separation.
- Preserve `OOF registry service` as kernel/support service vocabulary, not
  optional pack vocabulary.
- Do not edit specs, proposals, canon, compiler/runtime code, `.igapp` goldens,
  public API/CLI, loader/report, CompatibilityReport, RuntimeMachine/Gate 3,
  Ledger/TBackend, cache, signing, production behavior, or Spark fixture/spec
  material.

Deliver:
- design track in `igniter-lang/docs/tracks/`
- recommended classification for `PINV-*` / `TINV-*`
- lifecycle/state table
- blockers before implementation-boundary design
- recommendation: implementation-boundary design next / proof-only policy
  follow-up / hold
```

---

## Implementation-Boundary Hold

Implementation-boundary design remains held until at least:

- PINV/TINV lifecycle design is accepted;
- exact future write scope is proposed;
- byte-for-byte diagnostic/report/golden parity strategy is defined;
- descriptor lifecycle and source-authority policy are complete;
- public-code stability promotion policy is complete;
- pack install / absent-pack interaction is resolved or explicitly deferred;
- pressure review confirms the implementation-boundary route cannot widen
  protected surfaces;
- Architect opens a separate implementation-boundary design or authorization
  route.

---

## Closed Surfaces

This decision does not authorize:

- implementation;
- specs, proposals, or canon edits;
- compiler/runtime code changes;
- live OOF registry or Fragment registry behavior;
- pack registry or live dispatch;
- parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator, or
  report behavior changes;
- public diagnostic renames, deletions, promotions, or wording changes;
- public API/CLI widening;
- loader/report or CompatibilityReport changes;
- `.igapp`, `.ilk`, or golden mutation;
- RuntimeMachine or Gate 3 widening;
- Ledger/TBackend, BiHistory, stream/OLAP production executors;
- cache, signing, deployment, or production behavior;
- Spark fixture/spec work or Spark production integration.

---

## Compact Summary

```text
Decision: accept R95 proof-only policy model.
Accepted proof: 16/16 cases, 7/7 checks, policy_id
  oof_fragment_policy/sha256:027ba71cd5a14c104b3b246a.
Next: open only `pinv-tinv-lifecycle-and-registry-classification-design-v0`.
Held: implementation-boundary design and all implementation/spec/canon/compiler/
  runtime/public/production surfaces.
```

