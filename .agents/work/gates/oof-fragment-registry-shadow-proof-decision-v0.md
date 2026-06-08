# OOF/Fragment Registry Shadow Proof Decision v0

Card: S3-R92-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: oof-fragment-registry-shadow-proof-decision-v0
Route: UPDATE
Status: accepted-design-only-registry-semantics-next-implementation-held
Date: 2026-05-20

---

## Decision

Accept the R92 OOF/Fragment registry shadow proof as proof-only evidence:

```text
accepted as proof-only shadow registry evidence
implementation remains held
```

Accepted proof track:

```text
igniter-lang/docs/tracks/oof-fragment-registry-shadow-proof-v0.md
```

Accepted executable proof:

```text
igniter-lang/experiments/oof_fragment_registry_shadow_proof/oof_fragment_registry_shadow_proof.rb
```

Accepted proof summary:

```text
PASS
checks: 18/18
registry_id: oof_fragment_shadow_registry/sha256:279c9e69b50264539027d6a7
OOF descriptors: 63
fragment registry rows: 8
```

No implementation is authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/org/tracks/oof-fragment-registry-shadow-proof-boundary-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-shadow-proof-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-semantics-review-v0.md`
- `igniter-lang/docs/discussions/oof-fragment-registry-shadow-proof-pressure-v0.md`
- `igniter-lang/experiments/oof_fragment_registry_shadow_proof/out/oof_fragment_registry_shadow_proof_summary.json`
- `igniter-lang/experiments/oof_fragment_registry_shadow_proof/out/oof_descriptors.shadow_registry.json`
- `igniter-lang/experiments/oof_fragment_registry_shadow_proof/out/fragment_registry.shadow_registry.json`
- `igniter-lang/docs/tracks/compiler-pack-shadow-profile-proof-v1.md`
- `igniter-lang/docs/reports/lang-r91-compiler-pack-shadow-profile-proof-v1.md`
- `igniter-lang/docs/cards/S3/S3-R92.md`

---

## Accepted Proof Disposition

R92 C1 is accepted as a successful data-only shadow registry proof.

Accepted findings:

- every OOF code surfaced by the R91 shadow profile has a proof-local
  descriptor;
- `compiler_profile_contract.*` and `compiler_profile_contract_refusal.*`
  remain outside OOF descriptor ownership;
- `OOF-RUNTIME-SMOKE` remains an excluded runtime helper;
- current shadow fragment rows are limited to `core`, `escape`, `temporal`,
  `stream`, `epistemic`, and `oof`;
- `olap` and `progression` remain guarded non-fragment classes;
- output JSON files under
  `igniter-lang/experiments/oof_fragment_registry_shadow_proof/out/` are
  accepted as proof-local artifacts within the authorized experiment directory.

The OOF descriptor schema is sufficiently stable to support a later design
route. It is not yet stable enough for live registry implementation, public
canon, spec mutation, compiler integration, or loader/report behavior.

Fragment semantics do not require another immediate proof pass. They do require
a design-only ownership and canon-semantics route before any implementation or
canon edit can be considered.

---

## Semantic Clarifications

Use the C2/C3 pressure clarification as the forward design reference:

```text
oof is status-primary with a secondary fragment projection candidate.
```

The C1 `oof_as_both` model is accepted only as proof-local modeling evidence.
It is not canon.

Use this non-canon reference ordering for the next design route:

```text
oof > temporal > stream > escape > epistemic > core
```

This supersedes the C1 proof-local ordering where `epistemic` appeared before
`escape`. The ordering remains a design candidate only; it is not live compiler
behavior and not a fragment registry contract.

Recommended ownership direction for the next design route:

```text
OOFRegistry: kernel service data populated by pack-owned descriptors
FragmentRegistry: kernel service data populated by fragment-owner packs
```

This is a design candidate, not implementation authority.

---

## Authorized Next Route

Authorize only a design-only follow-up route:

```text
oof-fragment-registry-ownership-and-canon-semantics-design-v0
```

Route type:

```text
design-only
no implementation
no spec/canon mutation
no live registry
no compiler dispatch
```

Goal:

```text
Decide the design posture for OOF descriptor ownership, fragment registry
ownership, `oof` status/fragment semantics, candidate precedence, and marker vs
descriptor treatment before any later implementation authorization review.
```

Allowed design questions:

- whether OOF registry ownership should be kernel service data populated by
  pack-owned descriptors;
- whether fragment registry ownership should be kernel service data populated
  by fragment-owner packs;
- whether `oof` should remain status-primary with a blocked/non-loadable
  fragment projection candidate;
- whether the reference candidate ordering
  `oof > temporal > stream > escape > epistemic > core` is the right future
  design baseline;
- whether `PINV-*` and `TINV-*` should be descriptors, markers, or separate
  support metadata;
- how public-code stability should be expressed for candidate/proof-only codes;
- how to preserve profile-contract diagnostics outside OOF.

---

## Exact Next Card Boundary

Immediate required next R92 card:

```text
Card: S3-R92-C5-S
Agent: [Igniter-Lang Status Curator]
Role: status-curator
Track: stage3-round92-status-curation-v0
Route: UPDATE

Goal:
Close R92 for Portfolio using the accepted C4-A decision and all R92 evidence.

Deliver:
- status-curation packet at
  igniter-lang/docs/tracks/stage3-round92-status-curation-v0.md
- compact executive summary
- completed card list
- changed files / evidence links
- risks and drift notes
- cross-lane requests, if any
- exact next route recommendation
```

Next allowed compiler card after R92 closes:

```text
Card: S3-R93-C1-D
Agent: [Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: oof-fragment-registry-ownership-and-canon-semantics-design-v0
Route: UPDATE

Goal:
Produce a design-only ownership and canon-semantics packet for the OOF and
fragment registry model accepted as proof-only evidence in R92.

Scope:
- Read all R92 outputs and this decision.
- Read relevant PROP-032, PROP-036, PROP-038, and compiler pack boundary
  evidence as context.
- Decide design posture for OOF registry ownership, fragment registry
  ownership, `oof` status-primary semantics, fragment projection guard,
  candidate precedence, `PINV-*`/`TINV-*` classification, and profile-contract
  diagnostic separation.
- Do not edit specs, proposals, compiler/runtime code, `.igapp` goldens, public
  API/CLI, loader/report, CompatibilityReport, RuntimeMachine/Gate 3, Ledger,
  cache, signing, production behavior, or Spark fixture/spec material.

Deliver:
- design track in `igniter-lang/docs/tracks/`
- compact design summary
- open questions before implementation authorization review
- exact next recommended route: proof-only / docs-only / implementation
  authorization review hold
```

---

## Not Authorized

This decision does not authorize:

- implementation;
- live `OOFRegistry` or `FragmentRegistry`;
- parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator, or
  dispatch behavior changes;
- public API or CLI widening;
- loader/report compiler-profile status;
- CompatibilityReport changes;
- `.igapp` mutation or golden migration;
- public OOF code renaming or compile-refusal behavior changes;
- spec/proposal/canon mutation;
- RuntimeMachine or Gate 3 widening;
- Ledger/TBackend binding;
- cache, signing, deployment, or production behavior;
- Spark fixture/spec work, real Spark data exposure, or Spark production
  integration.

---

## Required Proof Before Implementation

Before any future implementation authorization review, require at minimum:

- completed ownership/canon-semantics design route;
- pressure review of that design;
- exact write-scope proposal;
- byte-for-byte diagnostic/report/golden parity strategy;
- explicit treatment of `PINV-*` and `TINV-*`;
- explicit exclusion of profile-contract diagnostics from OOF;
- explicit conflict handling for fragment precedence and projection guards;
- Architect decision that narrowly authorizes an implementation slice.

Portfolio review is not required before the design-only follow-up route. Normal
R92 status curation is sufficient. Portfolio review is required again before any
cross-lane commitment, production-adjacent rollout, or implementation route that
widens protected surfaces.

