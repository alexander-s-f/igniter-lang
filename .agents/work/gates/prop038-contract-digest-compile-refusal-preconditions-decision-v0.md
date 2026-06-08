# PROP-038 Contract Digest Compile-Refusal Preconditions Decision v0

Card: S3-R75-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-contract-digest-compile-refusal-preconditions-decision-v0
Route: UPDATE
Status: accepted-preconditions-design-refusal-held
Date: 2026-05-18

---

## Decision

Accept the PROP-038 `contract_digest` compile-refusal preconditions design.

The accepted result is a precondition and blocker record only:

```text
prop038-contract-digest-compile-refusal-preconditions-design-v0
```

Compile refusal remains closed. This decision does not authorize code
implementation, compiler/orchestrator integration changes, public API/CLI
widening, `CompilerResult` changes, persisted reports or sidecars,
parser/TypeChecker/SemanticIR changes, assembler or `.igapp` mutation,
loader/report behavior, CompatibilityReport behavior, diagnostics
centralization, dispatch migration, RuntimeMachine behavior, Gate 3 widening,
Ledger/TBackend behavior, BiHistory, stream/OLAP, cache, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-contract-digest-compile-refusal-preconditions-design-v0.md`
- `igniter-lang/docs/discussions/prop038-contract-digest-compile-refusal-preconditions-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-live-validator-implementation-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-live-implementation-design-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-errata-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-report-only-integration-proof-decision-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round74-status-curation-v0.md`

---

## Accepted Preconditions Design

Architect accepts the five-layer vocabulary separation:

| Layer | Accepted status |
| --- | --- |
| Contract-object invalidity | Live in internal validator result. |
| Report-only validation diagnostics | Live as nested in-memory report metadata. |
| Compiler compile refusal | Closed. Not authorized. |
| Loader/report status | Separate vocabulary. Not opened here. |
| Runtime/production readiness | Separate runtime gates. Not opened here. |

Accepted core rule:

```text
compiler_profile_contract.* diagnostic != compile refusal
```

The current live behavior remains report-only:

- validator diagnostics may be emitted;
- digest diagnostics stay nested under
  `compiler_profile_contract_validation.diagnostics`;
- top-level `report["diagnostics"]` remains unchanged;
- compile status remains unchanged;
- public result remains unchanged;
- `.igapp` manifest remains unchanged;
- nil, non-Hash, provider-error, and validator-error paths remain
  no-field/no-refusal.

---

## Refusal Candidate Status

No `contract_digest_*` diagnostic is authorized as compile-refusal behavior.

Accepted future-candidate classification:

| Diagnostic | Future refusal candidate status |
| --- | --- |
| `compiler_profile_contract.contract_digest_invalid` | Conditional candidate only after explicit strict profile/contract requirement, caller-supplied Hash contract, and accepted user-facing wording. |
| `compiler_profile_contract.contract_digest_policy_unsupported` | Conditional candidate only after explicit policy selection exists and the unsupported policy is attributable to caller/config. |
| `compiler_profile_contract.contract_digest_mismatch` | Strongest conditional future candidate after explicit strict mode, successful recomputation, and stable mismatch proof. |
| `compiler_profile_contract.contract_digest_recompute_unavailable` | Held by default. It may only be considered under an explicit fail-closed strict mode with accepted wording and operational recovery story. |

Architect accepts `contract_digest_mismatch` as the strongest future candidate
because it represents a proven identity contradiction: the declared digest
conflicts with canonical contract material after recomputation succeeds.

Architect does not accept `contract_digest_recompute_unavailable` as a first
refusal candidate. It may represent validator or canonicalizer capability
failure, so compile-breaking behavior requires a separate operational policy.

Broader PROP-038 structural diagnostics, such as `missing_required_slot`,
`rule_cycle`, or `runtime_authority_forbidden`, are outside this decision and
remain unavailable for compile-refusal behavior through this route.

---

## Current Live Behavior

Report-only remains the current live behavior.

Compile refusal remains closed.

Loader/report and CompatibilityReport remain closed.

No future refusal implementation card may open directly from this decision.
Implementation must wait until a separate design decision accepts at least:

- explicit strict profile/contract requirement source;
- compiler/orchestrator refusal status semantics;
- user-facing diagnostic wording;
- fail-open/fail-closed policy for recompute unavailable;
- proof-local strict-mode refusal matrix;
- exact write scope and public-surface boundary, if any.

---

## Pressure Verdict

R75-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: none
```

Architect accepts the pressure result.

---

## Next Allowed Route

Authorize only a design route:

```text
prop038-contract-digest-strict-source-and-refusal-wording-design-v0
```

Allowed next card boundary:

```text
Card: S3-R76-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: prop038-contract-digest-strict-source-and-refusal-wording-design-v0

Goal:
Design the strict profile/contract source and user-facing compiler refusal
wording needed before any PROP-038 contract_digest refusal proof-local
experiment can be considered.

Allowed:
- define possible strict profile/contract requirement source options;
- design compiler/orchestrator refusal status vocabulary without implementing it;
- design user-facing diagnostic wording for API/CLI/proof contexts;
- decide whether refusal should use compiler-level wrapper codes that cite
  `compiler_profile_contract.*` diagnostics as evidence;
- propose fail-open/fail-closed policy options for recompute unavailable;
- refine the required proof-local strict-mode matrix.

Not allowed:
- code implementation;
- enabling compile refusal;
- proof-local refusal implementation;
- compiler/orchestrator behavior changes;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted reports or sidecars;
- parser, TypeChecker, SemanticIR, assembler, `.igapp`, loader/report,
  CompatibilityReport, diagnostics centralization, RuntimeMachine, Gate 3,
  Ledger/TBackend, BiHistory, stream/OLAP, cache, or production behavior.
```

No refusal proof-local experiment is authorized yet. A proof-local experiment may
be considered only after this design route, or an equivalent Architect-approved
design route, closes the strict source and wording blockers.

---

## Blockers Before Refusal Implementation Authorization

The following blockers remain open:

| Blocker | Status |
| --- | --- |
| Accepted strict profile/contract requirement source | Open |
| Compiler/orchestrator refusal status design | Open |
| User-facing diagnostic wording design | Open |
| Accepted fail-open/fail-closed policy for recompute unavailable | Open |
| Proof-local strict-mode refusal matrix | Open |
| Authorization to change compiler/orchestrator behavior | Closed / not authorized |
| Authorization to change public API/CLI behavior | Closed / not authorized |
| Authorization to change `CompilerResult` | Closed / not authorized |
| Authorization to write refusal reports or persisted sidecars | Closed / not authorized |

---

## Preserved Closed Surfaces

This decision preserves closure of:

- compiler/orchestrator integration;
- compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted success reports or sidecars;
- parser, TypeChecker, SemanticIR changes;
- assembler or `.igapp` mutation;
- loader/report behavior;
- CompatibilityReport behavior;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`, receipts, signing;
- dispatch migration;
- RuntimeMachine and Gate 3 widening;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, and production behavior.
