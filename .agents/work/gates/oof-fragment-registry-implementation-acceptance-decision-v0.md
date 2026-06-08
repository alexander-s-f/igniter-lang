# OOF/Fragment Registry Implementation Acceptance Decision v0

Card: LANG-R104-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: oof-fragment-registry-implementation-acceptance-decision-v0
Status: accepted-closure-static-internal-data-design-next
Date: 2026-05-21

---

## Decision

Accept R103 implementation closure:

```text
accepted
```

Accepted implementation track:

```text
igniter-lang/docs/tracks/oof-fragment-registry-implementation-boundary-proof-v0.md
```

Accepted implementation result:

```text
OOFFragmentRegistryBoundaryProof: PASS
27/27 checks PASS
8/8 pinned command matrix PASS
```

The slice is accepted only as an isolated internal validator plus proof-local
boundary/parity harness. It is not compiler integration, not public registry
behavior, not spec/canon mutation, and not runtime or production authority.

---

## Evidence Read

- `igniter-lang/docs/gates/oof-fragment-registry-implementation-authorization-review-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-implementation-boundary-proof-v0.md`
- `igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/out/oof_fragment_registry_implementation_boundary_proof_summary.json`
- `igniter-lang/lib/igniter_lang/oof_fragment_registry.rb`

Additional direct checks:

- `lib/igniter_lang/oof_fragment_registry_data.rb` does not exist.
- `lib/igniter_lang.rb` does not require `oof_fragment_registry`.
- Tracked R103 files are inside the R102 authorized write scope.

---

## Scope Verification

R102 authorized only:

```text
lib/igniter_lang/oof_fragment_registry.rb
experiments/oof_fragment_registry_implementation_boundary_proof/**
docs/tracks/oof-fragment-registry-implementation-boundary-proof-v0.md
```

R103 changed/tracked files:

```text
lib/igniter_lang/oof_fragment_registry.rb
experiments/oof_fragment_registry_implementation_boundary_proof/fixtures/forward_shape_valid.json
experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb
experiments/oof_fragment_registry_implementation_boundary_proof/out/oof_fragment_registry_implementation_boundary_proof_summary.json
docs/tracks/oof-fragment-registry-implementation-boundary-proof-v0.md
```

All are within the authorized R102 scope.

Explicitly out-of-scope path remains absent:

```text
lib/igniter_lang/oof_fragment_registry_data.rb
```

No compiler pass, report, result, CLI, spec, proposal, `.igapp`, runtime,
production, or Spark surface is accepted as changed by this decision.

---

## Proof Matrix Rerun

Architect reran the pinned 8-command matrix on 2026-05-21:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/oof_fragment_registry.rb` | PASS / `Syntax OK` |
| `ruby igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb` | PASS / 27/27 |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS |
| `ruby igniter-lang/experiments/typechecker_proof/typechecker_proof.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS |
| `ruby igniter-lang/experiments/invariant_severity_proof/invariant_severity_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |

---

## Accepted Closure Details

Accepted:

- internal pure validator at `IgniterLang::OOFFragmentRegistry`;
- R98 forward shape enforcement;
- `PINV-*` / `TINV-*` under
  `support_markers.invariant_support_markers`, not `oof_descriptors`;
- absent-owner inactive rows recorded, not silently skipped;
- internal-only validation result shape;
- R92 historical JSON non-migration;
- `oof_fragment_registry_data.rb` absence;
- no require from `lib/igniter_lang.rb`;
- no public API/CLI/report/runtime effects.

R103 is closed.

---

## Authorized Next Route

Open only a static internal data design route:

```text
oof-fragment-registry-static-internal-data-design-v0
```

Route type:

```text
design-only
no implementation
no compiler integration
no spec/proposal/canon mutation
```

Reason:

- R103 proves the isolated validator can validate supplied hashes.
- The next local question is whether a static internal data constants file is
  appropriate at all, given the risk that data constants are mistaken for canon.
- Compiler integration would be premature until static data posture,
  source-authority, non-canon labeling, and loading boundaries are designed.

Do not authorize compiler integration.

---

## Exact Next Allowed Boundary

```text
Card: LANG-R105-D1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Route: UPDATE
Track: oof-fragment-registry-static-internal-data-design-v0

Goal:
Design whether `lib/igniter_lang/oof_fragment_registry_data.rb` should exist as
static internal data, remain deferred, or be rejected, now that R103 accepted
the isolated validator.

Scope:
- Read R102 authorization, R103 implementation/proof, and this R104 decision.
- Compare options:
  - no static internal data;
  - static proof-derived sample data constants;
  - generated fixture-only data;
  - loader-supplied caller data only.
- If static data is recommended, define:
  - exact non-canon labeling;
  - exact future write scope;
  - source-authority fields;
  - proof matrix additions;
  - prohibition on requiring it from `lib/igniter_lang.rb`;
  - prohibition on compiler pass integration.
- Keep compiler integration, specs/canon/proposals, public API/CLI, reports,
  `.igapp`, runtime, production, and Spark surfaces closed.

Deliver:
- design track in `igniter-lang/docs/tracks/`
- recommendation: authorize static internal data implementation / hold /
  reject / redirect
- exact blockers before any static data implementation
```

---

## Still Closed

This decision does not authorize:

- `lib/igniter_lang/oof_fragment_registry_data.rb`;
- compiler integration;
- specs, proposals, or canon edits;
- parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator,
  report, `CompilerResult`, or CLI behavior changes;
- public diagnostic renames, promotions, aliases, or wording changes;
- public API/CLI widening;
- loader/report or CompatibilityReport changes;
- `.igapp`, `.ilk`, or golden mutation;
- live pack registry or dispatch;
- RuntimeMachine or Gate 3 widening;
- Ledger/TBackend, BiHistory, stream/OLAP production executors;
- cache, signing, deployment, or production behavior;
- Spark fixture/spec/data/code work or Spark production integration.

---

## Compact Summary

```text
Decision: ACCEPT R103 closure.
PASS: R103 proof 27/27; pinned matrix rerun 8/8.
Changed files: inside R102 authorized scope.
Next: design-only `oof-fragment-registry-static-internal-data-design-v0`.
Closed: static data implementation, compiler integration, specs/canon,
  public API/CLI, reports, `.igapp`, runtime, production, Spark surfaces.
```

