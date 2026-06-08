# OOF/Fragment Registry Source Envelope Helper Implementation Authorization Review

Status: authorized-bounded-internal-source-envelope-helper-proof-slice
Date: 2026-05-21
Card: LANG-R110-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: oof-fragment-registry-source-envelope-helper-implementation-authorization-review-v0

---

## Decision

Authorize the first bounded implementation slice for an internal source-envelope
helper inside `IgniterLang::OOFFragmentRegistry`.

The authorization is narrow:

- implementation may add an internal helper to
  `igniter-lang/lib/igniter_lang/oof_fragment_registry.rb`;
- proof evidence may be created under
  `igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/**`;
- closure evidence may be recorded in
  `igniter-lang/docs/tracks/oof-fragment-registry-source-envelope-helper-proof-v0.md`.

No other implementation, integration, public surface, or data-source authority
is opened.

---

## Evidence Read

- `igniter-lang/docs/tracks/oof-fragment-registry-supplied-data-source-proof-v0.md`
- `igniter-lang/docs/gates/oof-fragment-registry-source-envelope-validation-placement-decision-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-source-envelope-helper-boundary-design-v0.md`
- `igniter-lang/lib/igniter_lang/oof_fragment_registry.rb`

---

## Basis

R107 proved the source envelope model in a proof-local harness:

- 7/7 cases PASS.
- 9/9 checks PASS.
- valid `proof_fixture` and `caller_supplied` envelopes validate nested
  registries through the existing `OOFFragmentRegistry#validate`;
- invalid envelopes remain internal-only;
- `profile_candidate`, canon-status envelopes, public/report/runtime keys, and
  closed-surface openings are rejected or absent.

R108 accepted that proof evidence while holding implementation and opened only a
design-only helper boundary.

R109 closed the design questions needed for a bounded implementation review:

- helper placement: inside `lib/igniter_lang/oof_fragment_registry.rb`;
- no separate helper/source file;
- no `lib/igniter_lang.rb` require exposure;
- accepted modes: `proof_fixture` and `caller_supplied` only;
- `profile_candidate`, `pack_descriptor_candidate`, and canon-status envelopes
  stay rejected or held;
- internal-only result shape and diagnostic vocabulary are defined;
- a concrete proof matrix is required.

This is enough to authorize the helper implementation as an isolated internal
validator extension. It is not enough to authorize loader/report, compiler,
public API/CLI, spec/canon, runtime, production, Spark, or static-data work.

---

## Exact Implementation Card Boundary

Card: LANG-R111-I1

Agent: `[Igniter-Lang Compiler/Grammar Expert]`

Role: compiler-grammar-expert

Route: UPDATE

Track:

```text
oof-fragment-registry-source-envelope-helper-proof-v0
```

Goal:

Implement and prove an internal source-envelope helper inside
`IgniterLang::OOFFragmentRegistry`, preserving the isolated validator boundary.

Allowed write scope:

```text
igniter-lang/lib/igniter_lang/oof_fragment_registry.rb
igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/**
igniter-lang/docs/tracks/oof-fragment-registry-source-envelope-helper-proof-v0.md
```

Implementation constraints:

- add the helper inside `IgniterLang::OOFFragmentRegistry`;
- accepted source modes are only `proof_fixture` and `caller_supplied`;
- reject or hold `profile_candidate`, `pack_descriptor_candidate`, unknown
  modes, and canon-status envelopes internally;
- call the existing nested registry validator only after source-envelope
  validation passes;
- preserve nested registry validation result shape;
- return internal-only source-envelope validation results;
- include closed-surface assertions in the proof evidence;
- do not create static registry data.

Forbidden writes and behavior:

- no `igniter-lang/lib/igniter_lang/oof_fragment_registry_data.rb`;
- no separate helper/source file;
- no `igniter-lang/lib/igniter_lang.rb` edits;
- no parser, classifier, TypeChecker, SemanticIR, assembler, orchestrator,
  compiler pass, report, diagnostics, `CompilerResult`, or CLI edits;
- no `docs/spec/`, `docs/proposals/`, or canon edits;
- no `.igapp`, `.ilk`, or golden changes;
- no loader/report or `CompatibilityReport` behavior;
- no public API/CLI input or output;
- no runtime, production, cache, signing, Ledger/TBackend, Gate 3, or Spark
  behavior.

Required proof matrix:

| Command | Required Result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/oof_fragment_registry.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/oof_fragment_registry_source_envelope_helper_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_supplied_data_source_proof/oof_fragment_registry_supplied_data_source_proof.rb` | PASS or explicitly superseded by helper proof with documented reason |
| `ruby igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb` | PASS |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS |
| `ruby igniter-lang/experiments/typechecker_proof/typechecker_proof.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |

Required helper proof cases:

- valid `proof_fixture` source validates nested registry;
- valid `caller_supplied` source validates nested registry;
- wrong kind rejected internally;
- missing registry rejected internally;
- `profile_candidate` rejected or held internally;
- `pack_descriptor_candidate` rejected or held internally;
- canon status rejected internally;
- open closed-surface assertion rejected internally;
- invalid nested registry reports nested registry diagnostics without public
  surface keys;
- `oof_fragment_registry_data.rb` remains absent;
- `lib/igniter_lang.rb` is not changed or used as an exposure path;
- compiler passes do not require or call the helper;
- no public/report/runtime keys appear in helper results.

---

## Not Authorized

This decision does not authorize:

- loader/report behavior;
- public API/CLI input or output;
- compiler integration;
- specs, canon, or proposals mutation;
- `oof_fragment_registry_data.rb`;
- separate helper/source file;
- static registry constants;
- `lib/igniter_lang.rb` require changes;
- parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator/report,
  `CompilerResult`, `CompatibilityReport`, diagnostics, or CLI behavior;
- `.igapp`, `.ilk`, or golden mutation;
- runtime, production, cache, signing, Ledger/TBackend, Gate 3, or Spark
  behavior.

---

## Acceptance Conditions

The implementation slice may be accepted only if:

- all writes stay inside the authorized scope;
- the helper remains internal to `OOFFragmentRegistry`;
- accepted source modes stay limited to `proof_fixture` and
  `caller_supplied`;
- R109 diagnostic/result-shape intent is preserved or any narrower change is
  explicitly justified in the proof track;
- the required proof matrix is recorded with PASS results or documented
  supersession for the R107 proof;
- no protected surface opens.

---

## Compact Summary

AUTHORIZED: bounded internal source-envelope helper implementation/proof slice.

Implementation is limited to `oof_fragment_registry.rb`, a new proof experiment
folder, and its proof track. All loader/report/public/compiler/spec/runtime,
data-file, production, and Spark surfaces remain closed.
