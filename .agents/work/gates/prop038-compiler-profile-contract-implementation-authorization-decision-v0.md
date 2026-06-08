# PROP-038 Compiler Profile Contract Implementation Authorization Decision v0

Card: S3-R62-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-compiler-profile-contract-implementation-authorization-decision-v0
Route: UPDATE
Status: authorized-proof-local-only
Date: 2026-05-17

---

## Decision

Authorize a first bounded PROP-038 implementation card in proof-local scope only.

This decision does not authorize production compiler integration, report-only
compiler behavior, compile refusal, public API/CLI widening, persistence, or any
runtime/production behavior.

The authorized first implementation is limited to extending the existing proof
experiment:

```text
igniter-lang/experiments/compiler_profile_contract_proof/
```

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-compiler-profile-contract-implementation-scope-survey-v0.md`
- `igniter-lang/docs/discussions/prop038-implementation-scope-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-compiler-profile-contract-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round61-status-curation-v0.md`

---

## Basis

R62-C1-P1 provides an exact write-surface table with ten options. R62-C2-X
pressure verdict is:

```text
proceed
blockers: none
```

Both C1 and C2 agree that the only appropriate first implementation boundary is
proof-local Option A:

```text
igniter-lang/experiments/compiler_profile_contract_proof/
```

Report-only compiler integration is not ready because the current compiler path
receives `compiler_profile_source`, not an independent
`compiler_profile_contract` object. Compile-refusal behavior is not ready
because it would create new compiler enforcement behavior and requires a
dedicated gate.

---

## Authorized Scope

The next implementation card may:

- edit only `igniter-lang/experiments/compiler_profile_contract_proof/`;
- add missing-`after` `missing_rule_reference` coverage;
- keep all `compiler_profile_contract.*` diagnostics inside the proof script;
- keep output under the proof summary only;
- keep proof-local descriptor and contract digest references compatible with
  PROP-038 `24+` lowercase hex references;
- rerun the proof and update only proof-local summary output owned by the
  experiment;
- produce a track doc with exact command output and PASS/FAIL matrix.

The first implementation behavior mode is:

```text
proof-local only
```

It is not report-only compiler integration and not refusal-capable compiler
behavior.

---

## Digest Policy For This Boundary

### Descriptor Digest Input Material

For this proof-local implementation only, the existing proof-local projection
approach is sufficient.

Normative descriptor digest input material remains unresolved for compiler
integration or persisted/durable output. Before any production/library validator,
report-only compiler integration, or persisted validation output, a later gate
must define:

- exact object/material computed over by `descriptor_digest`;
- canonical serialization rules;
- whether `descriptor_digest` itself is excluded from hashed material;
- whether the source is descriptor object, contract projection, or finalized
  profile descriptor payload.

### Short-Vs-Full Digest References

For this proof-local implementation only:

```text
descriptor_digest: 24+ lowercase hex accepted
contract_digest:   24+ lowercase hex accepted
```

For persisted, durable, report, receipt, `.ilk`, `.igapp`, loader/report, or
production-facing output:

```text
full 64-character SHA-256 references are required unless a later gate explicitly
approves short references.
```

---

## Fixture And Output Policy

Authorized:

- proof-local fixtures/cases inside
  `igniter-lang/experiments/compiler_profile_contract_proof/`;
- proof-local summary output under that experiment's `out/` directory.

Not authorized:

- `.igapp` mutation;
- canonical golden migration;
- production spec fixture migration;
- receipt, `.ilk`, signing, loader/report, CompatibilityReport, or sidecar
  output;
- public API/CLI output changes.

---

## Diagnostic Placement

For this proof-local implementation only:

```text
compiler_profile_contract.* diagnostics stay inside the proof script.
```

Centralizing diagnostic construction in `IgniterLang::Diagnostics` or a
production validator helper is not authorized by this decision.

---

## Report-Only Compiler Integration Held

Report-only compiler integration remains held.

Before any report-only compiler integration authorization, a later gate must
resolve:

- contract input ownership: how an independent `compiler_profile_contract`
  becomes available to the compiler without unauthorized public API/CLI widening;
- descriptor digest input material and canonicalization;
- report/output location;
- whether validation appears in `CompilationReport`, sidecar output, or another
  artifact;
- orchestrator insertion point;
- diagnostic helper placement;
- fixture/golden policy.

---

## Compile Refusal Held

Compile-refusal behavior remains held.

No invalid `compiler_profile_contract` may refuse compilation under this
decision. Refusal requires a dedicated later Architect gate.

---

## Exact Next Allowed Implementation Card Boundary

```text
Card: S3-R63-C1-I
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop038-proof-local-missing-after-implementation-v0

Goal:
Implement the first proof-local PROP-038 validation extension by adding
missing-`after` `missing_rule_reference` coverage in the existing
compiler_profile_contract proof.

Scope:
- Edit only:
  - igniter-lang/experiments/compiler_profile_contract_proof/
- Add a negative proof-local case for ordered-rule `after` references to a
  missing rule.
- Assert diagnostic:
  - compiler_profile_contract.missing_rule_reference
- Keep diagnostics in the proof script.
- Keep output proof-local under the experiment summary.
- Keep descriptor/contract digest references PROP-038-compatible with 24+
  lowercase hex in proof-local output.
- Rerun the proof command and record exact PASS/FAIL.
- Do not change production compiler code.
- Do not change parser, TypeChecker, SemanticIR, assembler, `.igapp`, CLI/API,
  loader/report, CompatibilityReport, dispatch, RuntimeMachine, Gate 3,
  Ledger/TBackend, BiHistory, stream/OLAP, cache, or production behavior.

Deliver:
- Updated proof-local experiment
- Updated proof-local summary output
- Track doc in igniter-lang/docs/tracks/
- Exact command and PASS/FAIL matrix
- Recommendation for the next gate: continue proof-local, consider library
  validator design, or hold
```

---

## Non-Authorizations Preserved

This decision does not authorize:

- parser changes;
- TypeChecker changes;
- SemanticIR changes;
- assembler or `.igapp` changes;
- CLI/API widening;
- profile discovery/defaulting/finalization in public surfaces;
- golden migration;
- loader/report;
- CompatibilityReport;
- `.ilk`;
- receipts;
- signing;
- dispatch migration;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

---

## Compact Summary

R62 authorizes the first PROP-038 implementation only as a proof-local extension
inside `experiments/compiler_profile_contract_proof/`. The next implementation
may add missing-`after` `missing_rule_reference` coverage and update proof-local
summary output. Report-only compiler integration and compile refusal remain
held. Descriptor digest input material is deferred for integrated/persisted
behavior; proof-local output may keep PROP-038-compatible `24+` digest
references.
