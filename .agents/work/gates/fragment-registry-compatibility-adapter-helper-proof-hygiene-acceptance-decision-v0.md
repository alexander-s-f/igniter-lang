# Fragment Registry Compatibility Adapter Helper Proof Hygiene Acceptance Decision

Status: accepted-proof-hygiene-strategic-vector-next
Date: 2026-05-23
Card: S3-R149-C3-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: fragment-registry-compatibility-adapter-helper-proof-hygiene-acceptance-decision-v0
Depends on: S3-R149-C1-P1, S3-R149-C2-X

---

## Decision

Accept the proof-hygiene cleanup.

The R149 proof-hygiene slice closes the R148 proof-quality follow-up without
changing helper code and without opening root require, classifier wiring, live
classifier dispatch, public/report/artifact/runtime/Spark/production surfaces,
or demo work.

The adapter lane is not advanced directly into classifier wiring or
SemanticIR/report/`.igapp` parity work from this decision.

After R149 status curation, the next compiler-mainline route is a strategic
compiler-mainline vector decision.

---

## Evidence Read

- `igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-helper-proof-hygiene-v0.md`
- `igniter-lang/docs/discussions/fragment-registry-compatibility-adapter-helper-proof-hygiene-pressure-v0.md`
- `igniter-lang/docs/gates/fragment-registry-compatibility-adapter-helper-implementation-acceptance-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round148-status-curation-v0.md`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/out/fragment_registry_compatibility_adapter_helper_implementation_proof_summary.json`

Local confirmation:

```text
git show --name-status --oneline --no-renames ad3ff50c
```

---

## Acceptance Findings

### Write Scope

Accepted hygiene commit:

```text
ad3ff50c fix(proof): improve hygiene for helper implementation checks and report
```

Changed files:

```text
igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-helper-proof-hygiene-v0.md
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/fragment_registry_compatibility_adapter_helper_implementation_proof.rb
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/out/fragment_registry_compatibility_adapter_helper_implementation_proof_summary.json
```

All changed files are inside the R148-C2-A proof-hygiene write scope.

### CS4 Fix Status

Accepted.

CS4 now scans the union of public and private singleton methods:

```ruby
helper_methods =
  IgniterLang::FragmentRegistryCompatibilityAdapter.methods(false) +
  IgniterLang::FragmentRegistryCompatibilityAdapter.private_methods(false)

(helper_methods.uniq & forbidden).empty?
```

This fixes the prior always-passing intersection check. C2-X verified the
forbidden set covers dispatch-like names: `dispatch`, `classify`, `wire`,
`register`, and `install`.

### Vocabulary Scan Count Status

Accepted.

The vocabulary scan now records:

```text
19 total / 18 checked / 1 authorized skipped
```

Summary fields:

```text
total_files: 19
checked_files: 18
authorized_skipped_files: 1
authorized_skipped_paths:
  lib/igniter_lang/fragment_registry_compatibility_adapter.rb
hits: []
status: CLEAN
```

### Closed-Surface Assertion Derivation Status

Accepted.

`closed_surface_assertions` now derives from live CS/NEG/PARITY checks where
practical. C2-X verified 13 assertions derive from live check results and no
duplicated hardcoded `false` values remain for the protected surfaces.

The absent `prop036_mutated` / `prop038_mutated` fields are accepted as a
cosmetic assertion-shape change, not a weakening. The underlying protection is
covered by broad vocabulary scan plus regression/parity evidence.

### Pinned Command Count Status

Accepted.

All six pinned regression counts were machine-asserted from observed command
output:

| Command | Expected | Observed | Assertion |
| --- | ---: | ---: | --- |
| `classifier_pass_proof` | 21 | 21 | PASS |
| `contract_modifiers_proof` | 20 | 20 | PASS |
| `assumptions_proof` | 39 | 39 | PASS |
| `source_to_semanticir_fixture --check-golden` | 31 | 31 | PASS |
| `igapp_assembler_proof` | 17 | 17 | PASS |
| `invariant_severity_proof` | 34 | 34 | PASS |

C2-X notes that the `UNAVAILABLE` fallback for future commands should be
documented when reused. It was not triggered in this run.

### Command Matrix Result

Accepted.

| Command | Result |
| --- | --- |
| `ruby igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/fragment_registry_compatibility_adapter_helper_implementation_proof.rb` | PASS, 44/44 |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS, 21 `: ok` checks |
| `ruby igniter-lang/experiments/contract_modifiers_proof/contract_modifiers_proof.rb` | PASS, 20 `: ok` checks |
| `ruby igniter-lang/experiments/assumptions_proof/assumptions_proof.rb` | PASS, 39 `: ok` checks |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS, 31 `: ok` checks |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS, 17 `: ok` checks |
| `ruby igniter-lang/experiments/invariant_severity_proof/invariant_severity_proof.rb` | PASS, 34 `: ok` checks |
| `ruby -c igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/fragment_registry_compatibility_adapter_helper_implementation_proof.rb` | Syntax OK |

The implementation proof summary remains:

```text
status: PASS
checks_total: 44
checks_pass: 44
checks_fail: 0
input_digest: 47e938fdea0e46e067a2c88b
result_digest: c109ef1b1b124fd825172327
r144_contracts: 23
r144_mismatches: 0
```

### No Helper Code Edit Status

Accepted.

The helper implementation file was not edited by R149. C2-X verified the helper
file history still points only to the original implementation commit:

```text
f865dd9c Add S3-R147-C2-I: fragment registry compatibility adapter helper implementation
```

No helper/lib/compiler/runtime behavior changed.

---

## Remaining Closed Surfaces

This decision does not authorize:

- root require from `igniter-lang/lib/igniter_lang.rb`;
- classifier wiring or live classifier dispatch;
- direct `contract_fragment_for` replacement;
- parser, TypeChecker, SemanticIR, assembler, or `.igapp` edits;
- `ClassifiedProgram` schema changes;
- public API/CLI widening;
- loader/report;
- `CompilationReport`, `CompilerResult`, or CompatibilityReport changes;
- `.igapp`, `.ilk`, manifest, sidecar, artifact hash, or golden mutation;
- PROP-036 or PROP-038 mutation;
- runtime, Spark, production;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, signing, or deployment
  behavior;
- demo lane, demo fixture, demo artifact, or production-facing scenario.

Classifier wiring remains closed and requires a separate later gate if ever
considered.

---

## Next Allowed Boundary

Immediate next route:

```text
Card: S3-R149-C4-S
Track: stage3-round149-status-curation-v0
Route: UPDATE
Mode: status curation only
```

After R149 status curation, the next compiler-mainline route is:

```text
Card: S3-R150-C1-A
Track: compiler-mainline-strategic-vector-decision-v0
Route: UPDATE
Mode: strategic decision only
```

Goal:

Choose the next bounded compiler-mainline axis after the fragment registry
compatibility adapter helper has reached accepted implementation plus accepted
proof hygiene.

Required read set:

- `igniter-lang/docs/tracks/stage3-round149-status-curation-v0.md`
- `igniter-lang/docs/gates/fragment-registry-compatibility-adapter-helper-proof-hygiene-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/fragment-registry-compatibility-adapter-helper-implementation-acceptance-decision-v0.md`
- current compiler/profile architecture status and current-status docs

Allowed decisions:

- open a design-only classifier-wiring route;
- open a design-only SemanticIR/report/`.igapp` parity route;
- pause adapter lane and return to compiler/profile architecture;
- open another bounded proof/design route;
- hold for Portfolio/lane review.

Not authorized by S3-R150-C1-A unless a later decision explicitly narrows it:

- implementation;
- root require;
- classifier wiring or live classifier dispatch;
- public surfaces;
- reports, artifacts, `.igapp`, loader/report, CompatibilityReport;
- runtime, Spark, production, demo work;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, signing.

---

## Compact Summary

ACCEPT proof hygiene.

R149 fixes CS4, clarifies vocabulary scan counts, derives closed-surface
assertions from live checks, machine-asserts pinned command counts, and keeps
the helper implementation untouched. The command matrix remains PASS and all
protected surfaces remain closed.

Next immediate route is status curation. After that, run a strategic
compiler-mainline vector decision rather than opening classifier wiring or
SemanticIR/report/`.igapp` work automatically.
