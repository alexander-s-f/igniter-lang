# OOF/Fragment Registry Source Envelope Helper Acceptance Decision

Status: accepted-helper-closure-utf8-proof-hygiene-next
Date: 2026-05-21
Card: LANG-R112-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: oof-fragment-registry-source-envelope-helper-acceptance-decision-v0

---

## Decision

Accept the R111 source-envelope helper closure.

R111 stayed inside the R110 authorization boundary and delivered a bounded
internal helper on `IgniterLang::OOFFragmentRegistry` with proof evidence:

- helper proof: 9/9 cases PASS, 10/10 checks PASS;
- pinned 9-command matrix PASS;
- accepted source modes remain only `proof_fixture` and `caller_supplied`;
- `profile_candidate` and `pack_descriptor_candidate` remain held;
- canon-status envelopes remain rejected;
- nested registry validation is called only after source-envelope validation
  passes;
- no loader/report, public API/CLI, compiler integration, spec/canon/proposal,
  runtime, production, Spark, or static-data surface opened.

Next safe route:

```text
oof-fragment-registry-utf8-proof-hygiene-cleanup-v0
```

This route is selected over profile/pack source-mode design and compiler
integration design because R111 surfaced a small but real proof portability gap:
R107 needs UTF-8 mode or a UTF-8 locale when reading a pre-existing JSON summary
that contains UTF-8 checkmark bytes. The helper closure is accepted, but the
proof lane should remove that environment sensitivity before opening wider OOF
routes.

---

## Evidence Read

- `igniter-lang/docs/gates/oof-fragment-registry-source-envelope-helper-implementation-authorization-review-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-source-envelope-helper-proof-v0.md`
- `igniter-lang/lib/igniter_lang/oof_fragment_registry.rb`
- `igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/out/oof_fragment_registry_source_envelope_helper_proof_summary.json`

---

## Local Verification

I reran the R110/R111 matrix locally:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/lib/igniter_lang/oof_fragment_registry.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/oof_fragment_registry_source_envelope_helper_proof.rb` | PASS: 9/9 cases, 10/10 checks |
| `RUBYOPT='-Eutf-8:utf-8' ruby igniter-lang/experiments/oof_fragment_registry_supplied_data_source_proof/oof_fragment_registry_supplied_data_source_proof.rb` | PASS: 7/7 cases, 9/9 checks |
| `ruby igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb` | PASS: 27/27 checks |
| `ruby igniter-lang/experiments/classifier_pass_proof/classifier_pass_proof.rb` | PASS |
| `ruby igniter-lang/experiments/typechecker_proof/typechecker_proof.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/source_to_semanticir_fixture/source_to_semanticir_fixture.rb --check-golden` | PASS |
| `ruby igniter-lang/experiments/igapp_assembler_proof/igapp_assembler_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |

The UTF-8 flag on the R107 command matches the R111 note. It is not a helper
behavior failure, but it is worth cleaning up before broader routing.

---

## Scope Verification

R111 changed only the authorized implementation/proof scope:

```text
igniter-lang/lib/igniter_lang/oof_fragment_registry.rb
igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/**
igniter-lang/docs/tracks/oof-fragment-registry-source-envelope-helper-proof-v0.md
```

Verified preserved closures:

- no `igniter-lang/lib/igniter_lang/oof_fragment_registry_data.rb`;
- no separate helper/source file under `igniter-lang/lib/igniter_lang/`;
- no `igniter-lang/lib/igniter_lang.rb` exposure;
- no compiler pass require/call of `validate_source_envelope`;
- no report, `CompilerResult`, `CompatibilityReport`, CLI, spec, proposal,
  `.igapp`, runtime, production, or Spark opening.

---

## Next Allowed Boundary

Card: LANG-R113-H1

Track:

```text
oof-fragment-registry-utf8-proof-hygiene-cleanup-v0
```

Route: UPDATE

Mode: bounded proof-hygiene cleanup

Goal:

Remove locale-dependent UTF-8 handling from OOF/Fragment registry proof scripts
and summaries so the R103/R107/R111 proof chain passes under the default local
Ruby execution path without requiring `RUBYOPT` or an external UTF-8 locale.

Allowed write scope:

```text
igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/**
igniter-lang/experiments/oof_fragment_registry_supplied_data_source_proof/**
igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/**
igniter-lang/docs/tracks/oof-fragment-registry-utf8-proof-hygiene-cleanup-v0.md
```

Allowed actions:

- make proof-local JSON reads explicitly UTF-8 safe;
- optionally replace non-ASCII proof-summary status glyphs with ASCII-only
  strings if that is the smallest stable fix;
- regenerate only proof-local outputs in the allowed experiment folders;
- record the cleanup and command matrix in the new track.

Required proof commands:

| Command | Required Result |
| --- | --- |
| `ruby igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb` | PASS |
| `ruby igniter-lang/experiments/oof_fragment_registry_supplied_data_source_proof/oof_fragment_registry_supplied_data_source_proof.rb` | PASS without `RUBYOPT` |
| `ruby igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/oof_fragment_registry_source_envelope_helper_proof.rb` | PASS |
| `ruby -c igniter-lang/experiments/oof_fragment_registry_implementation_boundary_proof/oof_fragment_registry_implementation_boundary_proof.rb` | PASS |
| `ruby -c igniter-lang/experiments/oof_fragment_registry_supplied_data_source_proof/oof_fragment_registry_supplied_data_source_proof.rb` | PASS |
| `ruby -c igniter-lang/experiments/oof_fragment_registry_source_envelope_helper_proof/oof_fragment_registry_source_envelope_helper_proof.rb` | PASS |

Forbidden actions:

- no changes to `igniter-lang/lib/igniter_lang/oof_fragment_registry.rb`;
- no `oof_fragment_registry_data.rb`;
- no separate helper/source file;
- no `lib/igniter_lang.rb`;
- no compiler integration;
- no profile/pack source-mode promotion;
- no loader/report, public API/CLI, `CompilerResult`, `CompatibilityReport`;
- no specs/canon/proposals;
- no `.igapp` or golden migration;
- no runtime, production, or Spark behavior.

---

## Routes Not Opened

This decision does not open:

- pause-and-idle as the next route, because the UTF-8 proof hygiene gap is
  small, bounded, and worth closing now;
- `profile_candidate` / `pack_descriptor_candidate` proof design, because the
  source-helper foundation should be portable first;
- compiler integration design-only, because helper acceptance does not create
  compiler authority;
- any implementation beyond the proof-hygiene cleanup boundary above.

---

## Compact Summary

ACCEPT R111.

Next route: `oof-fragment-registry-utf8-proof-hygiene-cleanup-v0`.

OOF implementation expansion pauses after helper acceptance until proof hygiene
is clean. All loader/report/public/compiler/spec/runtime/data-file/production
and Spark surfaces remain closed.
