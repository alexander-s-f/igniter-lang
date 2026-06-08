# PINV/TINV Lifecycle Classification Acceptance Decision v0

Card: LANG-R98-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: pinv-tinv-lifecycle-classification-acceptance-decision-v0
Status: accepted-implementation-boundary-design-next-implementation-held
Date: 2026-05-20

---

## Decision

Accept R97 PINV/TINV lifecycle classification:

```text
accepted as design-only lifecycle/classification record
implementation remains held
```

Accepted track:

```text
igniter-lang/docs/tracks/pinv-tinv-lifecycle-and-registry-classification-design-v0.md
```

Accepted classification:

```text
PINV-* / TINV-* are invariant support checkpoint metadata.
They are not public OOF descriptors.
They are not compiler-emitted diagnostics.
They may appear in proof-local registry models only as non-public marker rows.
```

No implementation, spec, canon, compiler, runtime, registry, dispatch, public
API/CLI, loader/report, CompatibilityReport, `.igapp`, Ledger/TBackend, cache,
signing, or production behavior is authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/tracks/pinv-tinv-lifecycle-and-registry-classification-design-v0.md`
- `igniter-lang/docs/gates/oof-fragment-registry-policy-proof-acceptance-decision-v0.md`
- R93/R94/R95 evidence referenced by the R97 track

---

## Accepted Classification

R97 is accepted with these binding design constraints:

| Subject | Accepted posture |
| --- | --- |
| PINV/TINV registry class | `support_metadata`, not `oof_descriptors`. |
| Default lifecycle state | `support_metadata_current`. |
| Public code stability | `non_public_support_marker`. |
| Public emission | Not compiler-emitted diagnostics. |
| Alias policy | Not aliases for `OOF-IV*` / `OOF-I*`. |
| Public OOF authority | Remains with `OOF-IV*` / `OOF-I*` descriptors. |
| Candidate OOF codes | `OOF-I1`, `OOF-I2`, `OOF-I3`, and `OOF-I5` remain separate candidate OOF descriptors. |
| Runtime/proof categories | `INV-WARN`, `INV-SOFT`, `INV-METRIC`, `INV-ERROR` remain outside OOF. |

Recommended future registry bucket, if modeled:

```text
support_markers.invariant_support_markers
```

Not:

```text
oof_descriptors
```

The R92 shadow proof rows that placed `PINV-*` / `TINV-*` in
`oof_descriptors.shadow_registry.json` remain accepted only as proof-local
historical evidence. They are not the forward live-registry shape.

---

## Authorized Next Route

Authorize only:

```text
oof-fragment-registry-implementation-boundary-design-v0
```

Route type:

```text
design-only
no implementation
no spec/proposal/canon mutation
no compiler/runtime changes
no live registry
```

Purpose:

```text
Define exact future write scope, parity requirements, source-authority gates,
registry-shape boundaries, and remaining blockers for a possible later
OOF/Fragment Registry implementation authorization review.
```

This is not implementation authorization.

---

## Exact Next Allowed Boundary

```text
Card: LANG-R99-D1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Route: UPDATE
Track: oof-fragment-registry-implementation-boundary-design-v0

Goal:
Design the implementation boundary for a possible future OOF/Fragment Registry
without implementing it or mutating specs/canon/compiler/runtime behavior.

Scope:
- Read R92 shadow proof/decision, R93 design, R94 pressure, R95 policy proof,
  R96 policy proof decision, R97 PINV/TINV lifecycle design, and this R98
  decision.
- Define candidate future write scope for implementation authorization review.
- Define registry shape boundary:
  - `oof_descriptors`;
  - `fragment_rows`;
  - optional `support_markers.invariant_support_markers`;
  - excluded namespaces.
- Preserve PINV/TINV as non-public support metadata, not OOF descriptors.
- Preserve `OOF registry service` as kernel/support service vocabulary, not
  optional pack vocabulary.
- Define byte-for-byte diagnostic/report/golden parity requirements.
- Define source-authority gates for promoting candidate OOF descriptors.
- Define exact proof/pressure required before implementation authorization.
- Do not edit specs, proposals, canon, compiler/runtime code, `.igapp`
  goldens, public API/CLI, loader/report, CompatibilityReport,
  RuntimeMachine/Gate 3, Ledger/TBackend, cache, signing, production behavior,
  or Spark fixture/spec material.

Deliver:
- design track in `igniter-lang/docs/tracks/`
- candidate implementation write-scope map
- parity and source-authority requirements
- remaining blockers before implementation authorization review
- recommendation: implementation authorization review / proof-only follow-up /
  hold
```

---

## Implementation Remains Closed

Even after R99 design, implementation must remain closed unless a later
Architect decision explicitly authorizes a bounded implementation slice.

Minimum blockers before implementation authorization:

- completed R99 implementation-boundary design;
- pressure review of the R99 design;
- exact file write scope;
- byte-for-byte diagnostic/report/golden parity proof or plan;
- proof that registry validation can be introduced without parser,
  classifier, TypeChecker, SemanticIR, assembler, public API/CLI,
  loader/report, CompatibilityReport, `.igapp`, runtime, or production drift;
- explicit treatment of absent optional packs and profile assembly;
- explicit migration/non-migration statement for existing R92 proof-local JSON;
- Architect implementation authorization gate.

---

## Closed Surfaces

This decision does not authorize:

- implementation;
- specs, proposals, or canon edits;
- compiler/runtime code changes;
- live OOF registry, Fragment registry, or support marker registry behavior;
- pack registry or live dispatch;
- parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator, or
  report behavior changes;
- public diagnostic renames, deletions, promotions, aliases, or wording changes;
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
Decision: accept R97 PINV/TINV classification.
Accepted classification: support metadata, not OOF descriptors or public
  diagnostics.
Next: authorize only `oof-fragment-registry-implementation-boundary-design-v0`.
Held: implementation/spec/canon/compiler/runtime/public/report/production
  surfaces.
```

