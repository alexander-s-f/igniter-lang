# OOF/Fragment Registry Source Envelope Validation Placement Decision

Status: accepted-proof-local-evidence-helper-boundary-design-next-implementation-held
Date: 2026-05-21
Card: LANG-R108-A
Agent: [Architect Supervisor / Igniter-Lang]
Role: architect-supervisor
Route: UPDATE
Track: oof-fragment-registry-source-envelope-validation-placement-decision-v0

---

## Decision

Accept the R107 supplied-data source proof as proof-only evidence.

Source-envelope validation remains proof-local in current behavior. The proof
shows enough value to authorize only the next design-only internal helper
boundary route:

```text
oof-fragment-registry-source-envelope-helper-boundary-design-v0
```

No implementation is authorized by this decision.

This decision does not redirect to full source-authority design first. R106 and
R107 provide enough evidence to design whether the proof-local envelope precheck
could become an internal helper for proof/caller-supplied sources only. Broader
source authority for profile, pack, loader, report, canon, or production data
remains a later blocker and cannot be smuggled into this route.

---

## Evidence Read

- `igniter-lang/docs/tracks/oof-fragment-registry-static-internal-data-design-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-loader-supplied-data-source-design-v0.md`
- `igniter-lang/docs/tracks/oof-fragment-registry-supplied-data-source-proof-v0.md`
- `igniter-lang/experiments/oof_fragment_registry_supplied_data_source_proof/out/oof_fragment_registry_supplied_data_source_proof_summary.json`

---

## Basis

R105 rejects `lib/igniter_lang/oof_fragment_registry_data.rb` and static
proof-derived registry constants for now. Registry data should remain
fixture-local or be supplied through a separately accepted source boundary.

R106 defines a staged source envelope candidate and explicitly leaves
source-envelope validation unimplemented unless a later decision authorizes it.
It keeps profile, pack, loader, and report paths as future candidates only.

R107 proves the supplied-data source model can be checked locally without
surface widening:

- 7/7 cases PASS.
- 9/9 checks PASS.
- Nested registry hashes still validate through
  `IgniterLang::OOFFragmentRegistry#validate`.
- Invalid source envelopes produce internal-only diagnostics.
- `profile_candidate` and canon-status sources remain rejected in the proof.
- `oof_fragment_registry_data.rb` is absent.
- No `lib/igniter_lang.rb` require change or compiler integration appears.

That is enough to design an internal helper boundary, but not enough to place
the helper in the library or wire it into compiler, loader, report, runtime, or
public caller paths.

---

## Next Allowed Route

Card: LANG-R109-D1

Track:

```text
oof-fragment-registry-source-envelope-helper-boundary-design-v0
```

Route: UPDATE

Mode: design-only

Goal:

Design whether source-envelope validation should remain proof-local or become a
bounded internal helper near `IgniterLang::OOFFragmentRegistry` in a later
implementation slice.

Allowed write scope:

- `igniter-lang/docs/tracks/oof-fragment-registry-source-envelope-helper-boundary-design-v0.md`

Required design questions:

- Candidate owner and placement for the helper, if any.
- Whether the helper should be a private/internal helper in
  `lib/igniter_lang/oof_fragment_registry.rb` or remain experiment-local.
- Internal-only result shape and diagnostic vocabulary.
- Accepted source modes for any future helper: `proof_fixture` and
  `caller_supplied` only.
- Rejection behavior for `profile_candidate`, `pack_descriptor_candidate`, and
  canon-status envelopes.
- Exact future implementation-review write scope, if the design recommends
  implementation.
- Proof matrix required before any implementation can be authorized.

Deliver:

- Design track in `igniter-lang/docs/tracks/`.
- Recommendation: keep proof-local / open bounded helper implementation
  authorization review / hold / redirect.
- Explicit blockers before implementation.
- Closed-surface list.

---

## Not Authorized

This decision does not authorize:

- source-envelope helper implementation;
- loader/report behavior;
- public API/CLI input or output;
- compiler integration;
- specs/canon/proposals mutation;
- `lib/igniter_lang/oof_fragment_registry_data.rb`;
- static registry constants;
- `lib/igniter_lang.rb` require changes;
- parser/classifier/TypeChecker/SemanticIR/assembler/orchestrator changes;
- `CompilationReport`, `CompatibilityReport`, or public result changes;
- `.igapp` behavior or golden migration;
- runtime, production, cache, signing, Ledger/TBackend, or Spark behavior.

---

## Blockers Before Implementation

- The R109 design route must close with an accepted helper placement.
- A later Architect authorization review must name the exact write scope.
- The helper must remain internal-only and must not introduce public API/CLI,
  loader/report, compiler, runtime, or production behavior.
- The helper must preserve proof/caller-supplied-only source modes unless a
  separate source-authority design and decision opens additional modes.
- A pinned proof matrix must rerun the R107 supplied-source proof, the R103
  registry validator proof, and any new helper parity cases.

---

## Compact Summary

PASS for R107 proof evidence. HOLD for implementation.

Next route is design-only:
`oof-fragment-registry-source-envelope-helper-boundary-design-v0`.

The lane may design a future internal helper boundary, but current validation
remains proof-local and all loader/report/public/compiler/spec/runtime/data-file
surfaces remain closed.
