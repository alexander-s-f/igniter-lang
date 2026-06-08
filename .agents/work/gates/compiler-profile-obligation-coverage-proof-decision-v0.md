# Compiler Profile Obligation Coverage Proof Decision v0

Card: S3-R56-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: compiler-profile-obligation-coverage-proof-decision-v0
Route: UPDATE
Status: accepted-proof-design-next
Date: 2026-05-16

---

## Decision

Accept `compiler-profile-obligation-coverage-proof-v0` as a successful
proof-local, report-only, output-only obligation coverage proof.

Authorize the next bounded track as design-only:

```text
compiler-profile-contract-boundary-v0
```

No implementation is authorized.

---

## Evidence Read

- `igniter-lang/docs/tracks/compiler-profile-obligation-coverage-proof-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-obligation-coverage-proof-pressure-v0.md`
- `igniter-lang/docs/gates/compiler-profile-next-axis-decision-v0.md`
- `igniter-lang/docs/tracks/stage3-round55-status-curation-v0.md`
- `igniter-lang/experiments/compiler_profile_obligation_coverage_proof/out/compiler_profile_obligation_coverage_summary.json`

---

## Proof Acceptance

The proof is accepted because it satisfies the S3-R55-C4-A boundary:

- executable proof passes;
- summary status is `PASS`;
- all 18 internal checks pass;
- selected existing artifacts remain unchanged;
- detected surfaces are grounded in existing proof artifacts;
- the four status cases are present:

  ```text
  covered
  missing_slot
  unsupported_surface
  profile_not_supplied
  ```

- `missing_slot` is a report status, not a compile refusal;
- `progression_descriptor` remains under the existing `pipeline` slot for v0;
- every report carries output-only flags showing no `.igapp`, CLI, assembler,
  loader/report, CompatibilityReport, dispatch, RuntimeMachine, or production
  effect.

Pressure review verdict:

```text
proceed
```

No blockers were found.

---

## Accepted Meaning

This decision accepts a narrow meaning:

```text
CompilerProfileObligationReport can describe whether a supplied finalized
compiler profile source covers the language surfaces observed in selected
compiled artifacts.
```

This does not mean:

- compilation is gated by the report;
- `missing_slot` refuses compilation;
- loader/report status exists;
- CompatibilityReport has a compiler-profile section;
- dispatch is profile-driven;
- runtime readiness is granted;
- production behavior is authorized.

The phrase remains:

```text
profile transport != profile coverage
```

R56 proves a report-only bridge from profile transport toward profile coverage.
It does not implement enforcement.

---

## Authorized Next Card Boundary

The next allowed design-only card is:

```text
Card: S3-R57-C1-P1
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: compiler-profile-contract-boundary-v0
```

Allowed scope:

- Read R55/R56 outputs and PROP-036.
- Design the boundary between:
  - `compiler_profile_source.*`;
  - `compiler_profile_obligation.*`;
  - future `compiler_profile_contract.*`;
  - loader/report status vocabulary.
- Decide the proposed lifecycle placement for obligation coverage:
  - before compile;
  - after SemanticIR emit;
  - before assembly;
  - or another explicitly named design position.
- Define the design-only relationship between:
  - finalized `compiler_profile_id_source`;
  - proof-local `CompilerProfileObligationReport`;
  - future `compiler_profile_contract`;
  - manifest `compiler_profile_id`.
- Include a vocabulary comparison table addressing pressure NB-1:

  ```text
  compiler_profile_obligation.missing_slot
  compiler_profile_contract.missing_required_slot
  ```

- Decide design treatment for pressure NB-2:
  whether `profile_not_supplied` should carry `missing_slots` or leave them
  empty in a future implementation design.
- Preserve PROP-037 v0 treatment:
  `progression_descriptor` stays under `pipeline` unless a later Architect
  decision opens a dedicated `progression` slot.
- State whether the design should become:
  - new PROP;
  - design packet;
  - PROP-036 addendum;
  - or remain proof-local.

Deliver:

- track doc in `igniter-lang/docs/tracks/`;
- boundary diagram or table;
- lifecycle placement recommendation;
- vocabulary namespace table;
- open questions and blockers before implementation authorization.

---

## Required Guardrails For The Next Track

The next design-only track must not:

- implement a compiler pass;
- mutate `.igapp` artifacts or goldens;
- change CLI or Ruby API behavior;
- define a new public profile input shape;
- introduce profile discovery/defaulting/finalization in public surfaces;
- authorize loader/report;
- authorize CompatibilityReport;
- authorize dispatch migration;
- authorize RuntimeMachine or Gate 3 widening;
- authorize Ledger/TBackend, BiHistory, stream/OLAP production execution,
  cache, or production behavior.

---

## Held / Not Authorized

This decision does not authorize:

- implementation in production compiler paths;
- compile refusal based on obligation coverage;
- `.igapp` emission changes;
- CLI widening;
- inline JSON, named/generated lookup, env/config/sidecar lookup;
- profile discovery/defaulting/finalization in public surfaces;
- golden migration;
- loader/report implementation;
- CompatibilityReport compiler-profile section;
- `.ilk`;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- pack loading;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP production execution;
- cache;
- production behavior.

---

## Blockers Before Implementation Authorization

Implementation remains blocked until at least:

1. `compiler-profile-contract-boundary-v0` lands and is pressure reviewed.
2. The lifecycle placement of obligation coverage is decided.
3. The diagnostic namespaces are stable:
   - `compiler_profile_source.*`;
   - `compiler_profile_obligation.*`;
   - future `compiler_profile_contract.*`;
   - loader/report status vocabulary.
4. The future treatment of `profile_not_supplied.missing_slots` is decided.
5. PROP-037 progression slot disposition is either kept under `pipeline` or
   separately authorized.
6. Architect issues a separate implementation authorization with exact write
   scope.

---

## Compact Summary

R56 accepts the obligation coverage proof. The proof shows that selected
language surfaces can be detected from existing artifacts, mapped to required
profile slots, and checked against a finalized `compiler_profile_id_source`
without changing compiler behavior.

The next track may design the compiler-profile contract boundary, but only as a
design artifact. Obligation coverage remains report-only/output-only until a
future implementation gate says otherwise.
