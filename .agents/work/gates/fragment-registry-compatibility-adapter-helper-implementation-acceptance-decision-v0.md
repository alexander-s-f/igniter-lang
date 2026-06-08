# Fragment Registry Compatibility Adapter Helper Implementation Acceptance Decision

Status: accepted-implementation-closure-proof-hygiene-next
Date: 2026-05-23
Card: S3-R148-C2-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: fragment-registry-compatibility-adapter-helper-implementation-acceptance-decision-v0
Depends on: S3-R148-C1-X

---

## Decision

Accept the bounded direct-require-only fragment registry compatibility adapter
helper implementation as closed.

The implementation slice is accepted because the helper stayed inside the
S3-R147-C1-A write scope, exposes only the authorized internal API, preserves
R144 selected-fragment compatibility, and remains unwired from root require,
live classifier dispatch, compiler passes, reports, artifacts, runtime, Spark,
and production surfaces.

No classifier wiring is authorized.

No root require is authorized.

No additional implementation is authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/discussions/fragment-registry-compatibility-adapter-helper-implementation-pressure-v0.md`
- `igniter-lang/docs/gates/fragment-registry-compatibility-adapter-helper-implementation-authorization-review-v0.md`
- `igniter-lang/docs/tracks/stage3-round147-status-curation-v0.md`
- `igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-helper-implementation-proof-v0.md`
- `igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb`
- `igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/out/fragment_registry_compatibility_adapter_helper_implementation_proof_summary.json`

Additional local check:

```text
git show --name-status --oneline --no-renames f865dd9c
```

---

## Exact Changed Files

Accepted implementation commit:

```text
f865dd9c Add S3-R147-C2-I: fragment registry compatibility adapter helper implementation
```

Changed files:

```text
igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/fragment_registry_compatibility_adapter_helper_implementation_proof.rb
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/out/fragment_registry_compatibility_adapter_helper_implementation_proof_summary.json
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/out/helper_implementation_result.json
igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-helper-implementation-proof-v0.md
```

All files are inside the authorized S3-R147-C1-A write scope.

---

## Helper API And Result Shape

Accepted API:

```text
IgniterLang::FragmentRegistryCompatibilityAdapter.project(input_hash) -> result_hash
```

The helper is direct-require-only. It is not required from
`igniter-lang/lib/igniter_lang.rb`.

The result shape is accepted for the first slice:

```text
kind: fragment_registry_compatibility_adapter_helper_result
format_version: 0.1.0
selected_fragment_projection.rows[]
selected_fragment_projection.mismatches[]
selected_fragment_projection.rules_in_order[]
guarded_non_fragments[]
oof_projection_policy
r144_parity
held_live_dispatch: true
classifier_wiring_authorized: false
```

The helper result remains internal-only. It is not a `ClassifiedProgram` field,
not compiler input, not report output, not CLI/API output, and not artifact
metadata.

The C1-X note on result digest divergence is accepted: the live helper result
digest differs from the R146 proof-model digest because the implementation
returns the C1-A canonical shape and omits proof-model extras such as
`boundary_mode` and `closed_surface_assertions`.

---

## R144 Compatibility Preservation

R144 compatibility is accepted as preserved:

- input digest: `47e938fdea0e46e067a2c88b`;
- result digest: `c109ef1b1b124fd825172327`;
- observed R144 contracts: 23;
- mismatches: 0;
- R144 parity preserved: true;
- stream presence selects `escape`;
- epistemic plus escape selects `escape`;
- epistemic-only selects `epistemic`;
- temporal plus escape selects `temporal`;
- OOF present selects `oof`;
- OOF policy remains status-primary, blocked, non-loadable, and
  non-capability;
- `olap` and `progression` remain guarded non-fragments.

---

## Command Matrix

Accepted command matrix:

| Command | Required Count | Result |
| --- | --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb` | Syntax OK | PASS |
| `ruby igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/fragment_registry_compatibility_adapter_helper_implementation_proof.rb` | 44 checks | PASS 44/44 |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | 21 named checks | PASS |
| `ruby igniter-lang/experiments/contract_modifiers_proof/contract_modifiers_proof.rb` | 20 named checks | PASS |
| `ruby igniter-lang/experiments/assumptions_proof/assumptions_proof.rb` | 39 named checks | PASS |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | 31 named checks | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | 17 named checks | PASS |
| `ruby igniter-lang/experiments/invariant_severity_proof/invariant_severity_proof.rb` | 34 named checks | PASS |

The implementation proof summary records 44 total checks, 44 pass, 0 failures.

C1-X notes that pinned counts are recorded as metadata and command success is
currently enforced by exit code, not by machine-checking each command's actual
reported count. This is not a blocker for accepting this slice, but it is
carried into the proof-hygiene next route.

---

## Dynamic Closed-Surface Checks

Accepted with explicit CS4 disposition.

Dynamic checks accepted:

- CS1 helper file exists at the authorized path;
- CS2 root require does not reference helper;
- CS3 classifier does not reference helper;
- CS5 result records `classifier_wiring_authorized: false`;
- CS6 result records `held_live_dispatch: true`;
- CS7 classifier has no `selected_fragment_projection` or
  `declaration_fragment_presence` field;
- CS8 `compilation_report.rb` and `compiler_result.rb` have no adapter
  references;
- CS9 `assembler.rb` and `semanticir_emitter.rb` have no adapter references;
- CS10 `cli.rb` has no adapter reference.

### CS4 Disposition

C1-X correctly identifies that CS4
`no_live_classifier_dispatch_method` is non-functional because it intersects
public singleton methods with private singleton methods before checking the
forbidden names. That intersection is always empty.

This does not block acceptance of the implementation because the underlying
isolation is proven by independent evidence:

- the helper source defines only `.project` as the public class method;
- CS3 confirms `classifier.rb` does not reference the helper;
- CS7 confirms no `ClassifiedProgram` projection field was added;
- NEG1 confirms all `igniter-lang/lib/igniter_lang/*.rb` files outside the
  helper are clean for adapter vocabulary;
- root require is clean by CS2.

CS4 must not be reused in its current form. The next proof-hygiene route must
replace it with a union-based method scan:

```ruby
all_singleton_methods =
  IgniterLang::FragmentRegistryCompatibilityAdapter.methods(false) +
  IgniterLang::FragmentRegistryCompatibilityAdapter.private_methods(false)

(all_singleton_methods & forbidden).empty?
```

---

## Broad Negative Vocabulary Scan

Accepted.

The broad scan covered 19 total `igniter-lang/lib/igniter_lang/*.rb` files,
skipping the authorized helper file and checking 18 remaining files.

Forbidden terms:

```text
fragment_registry_compatibility_adapter
FragmentRegistryCompatibilityAdapter
declaration_fragment_presence
selected_fragment_projection
```

Result:

```text
CLEAN — 0 hits outside igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb
```

The C1-X file-count note is accepted as cosmetic: the proof summary reports 19
total files scanned; the track text says 18 checked files. The scan itself is
valid.

---

## Byte-For-Byte Parity Evidence

Accepted as sufficient for this slice.

Recorded parity evidence:

| Artifact | Digest | Coverage |
| --- | --- | --- |
| `.igapp` result summary | `f8b4426843a85b6a03d6629a` | live read of `experiments/igapp_assembler_proof/out/result_summary.json` |
| SemanticIR golden dir | `f3f7fa48455bed3adb2e8777` | 23 files |
| Assumptions golden dir | `156da071b981e15cc32fea13` | 12 files |
| Contract modifiers golden dir | `319721cd4d9e10f0a23c4fa1` | 23 files |
| Invariant severity summary | `b47e6cf8f64de68cd911c516` | live read of `experiments/invariant_severity_proof/summary.json` |

No existing golden mutation is accepted. `.igapp`, source-to-SemanticIR,
classifier, contract-modifier, assumptions, and invariant proof artifacts remain
unchanged outside the authorized proof output directory.

---

## No Root Require / No Classifier Wiring / No Live Dispatch

Accepted as preserved:

- no root require from `igniter-lang/lib/igniter_lang.rb`;
- no classifier reference to the helper;
- no classifier wiring;
- no live classifier dispatch;
- no `contract_fragment_for` replacement;
- no `ClassifiedProgram` schema field;
- no public/report/artifact/runtime/Spark/production surface opened.

The helper is available only to explicit direct-require callers authorized by
future gates.

---

## Remaining Closed Surfaces

This decision does not authorize:

- root require from `igniter-lang/lib/igniter_lang.rb`;
- classifier wiring or live classifier dispatch;
- `contract_fragment_for` replacement;
- parser, TypeChecker, SemanticIR, assembler, or `.igapp` edits;
- `ClassifiedProgram` schema changes;
- public API/CLI widening;
- loader/report;
- `CompilationReport`, `CompilerResult`, or CompatibilityReport changes;
- `.igapp`, `.ilk`, manifest, sidecar, artifact hash, or golden mutation;
- PROP-036 or PROP-038 mutation;
- runtime, Spark, production;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, signing, or deployment
  behavior.

Classifier wiring remains closed and requires a separate later gate.

---

## Next Allowed Boundary

Immediate next route:

```text
Card: S3-R148-C3-S
Track: stage3-round148-status-curation-v0
Route: UPDATE
Mode: status curation only
```

After status curation, the only technical follow-up opened by this decision is:

```text
Card: S3-R149-P1
Track: fragment-registry-compatibility-adapter-helper-proof-hygiene-v0
Route: UPDATE
Mode: proof-hygiene only
```

Allowed write scope:

```text
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/fragment_registry_compatibility_adapter_helper_implementation_proof.rb
igniter-lang/experiments/fragment_registry_compatibility_adapter_helper_implementation_proof/out/fragment_registry_compatibility_adapter_helper_implementation_proof_summary.json
igniter-lang/docs/tracks/fragment-registry-compatibility-adapter-helper-proof-hygiene-v0.md
```

Required proof-hygiene work:

- fix CS4 to use union of public and private singleton methods;
- clarify vocabulary scan count as `19 total / 18 checked / 1 authorized
  skipped`;
- derive `closed_surface_assertions` from live CS/NEG checks where practical;
- add machine assertions that recorded pinned counts match command-specific
  expected counts, or explicitly record why a command cannot expose an actual
  count without changing that command.

Not authorized in the next route:

- edits to `igniter-lang/lib/igniter_lang/fragment_registry_compatibility_adapter.rb`;
- root require;
- classifier wiring or live classifier dispatch;
- parser, TypeChecker, SemanticIR, assembler, report, `.igapp`, public API/CLI,
  runtime, Spark, production, or proposal edits;
- golden mutation.

---

## Compact Summary

ACCEPT implementation closure.

The direct-require-only helper implementation is accepted as a closed bounded
slice. It preserves R144 compatibility, passes 44/44 helper proof checks, passes
the required regression matrix, keeps root require and classifier wiring closed,
and has clean broad negative scans.

CS4 in the proof runner is acknowledged as non-functional but non-blocking
because CS3, CS7, NEG1, source review, and root-require checks provide the real
protection. A proof-hygiene route is opened to fix that proof check before the
pattern is reused.
