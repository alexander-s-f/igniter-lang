# PROP-038 Proof-Local Missing-After Acceptance Decision v0

Card: S3-R63-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-proof-local-missing-after-acceptance-decision-v0
Route: UPDATE
Status: accepted-proof-local-closure
Date: 2026-05-17

---

## Decision

Accept the R63 proof-local missing-`after` implementation.

R62 proof-local Option A is closed.

This decision does not authorize library validator extraction, compiler
integration, report-only behavior, compile refusal, runtime behavior, or
production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-proof-local-missing-after-implementation-v0.md`
- `igniter-lang/docs/discussions/prop038-proof-local-missing-after-pressure-v0.md`
- `igniter-lang/docs/gates/prop038-compiler-profile-contract-implementation-authorization-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round62-status-curation-v0.md`
- `igniter-lang/experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json`

---

## Acceptance Basis

R63-C1-I stayed inside the authorized proof-local boundary.

Changed proof-local files:

```text
igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb
igniter-lang/experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json
igniter-lang/docs/tracks/prop038-proof-local-missing-after-implementation-v0.md
```

The first two files are inside the authorized experiment directory. The third is
the required track document.

No production compiler code changed.

---

## Command Matrix

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb` | PASS / `Syntax OK` |
| `ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb` | PASS / `PASS compiler_profile_contract_proof` |

Summary verification:

```text
track=prop038-proof-local-missing-after-implementation-v0
extends_track=compiler-profile-contract-validator-coverage-proof-v0
status=PASS
cases=13
checks=23
```

---

## Missing-After Coverage

Accepted.

New proof-local case:

```text
missing_after_rule_reference
```

Mutation:

```text
ordered_rule_graph.rules[0].after = ["parse.nonexistent_rule"]
```

Observed diagnostic:

```text
compiler_profile_contract.missing_rule_reference
```

Observed path:

```text
ordered_rule_graph.rules.parse.contract_modifiers
```

The R60 proof already covered missing `before` references. R63 now covers
missing `after` references. Therefore PROP-038 ordered-rule referential
integrity is machine-backed for both directions in the current proof-local
scope.

---

## Pressure Verdict

R63-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: none
```

Pressure confirms:

- write scope was limited to the authorized experiment directory plus required
  track doc;
- the new `after` case is present;
- `compiler_profile_contract.missing_rule_reference` is asserted;
- diagnostics remain proof-local;
- all 23 checks pass;
- all 13 `non_authorizations_preserved` flags remain false;
- 24+ digest references remain proof-local only;
- report-only compiler integration and compile refusal remain held.

---

## R62 Option A Closure

R62 authorized only this first proof-local implementation:

```text
Option A: igniter-lang/experiments/compiler_profile_contract_proof/
```

That authorization is now satisfied and closed for the named gap:

```text
missing-after missing_rule_reference coverage: closed
```

No additional proof-local work is required unless a later reviewer asks for more
adversarial cases.

---

## Next Allowed Route

The next meaningful lane is design-only:

```text
Card: S3-R64-C1-P1
Agent: [Igniter-Lang Implementation Agent]
Role: implementation-agent
Track: prop038-library-validator-extraction-design-v0

Goal:
Design the Option B library validator extraction boundary without implementing
code.

Scope:
- Read:
  - igniter-lang/docs/gates/prop038-proof-local-missing-after-acceptance-decision-v0.md
  - igniter-lang/docs/gates/prop038-compiler-profile-contract-implementation-authorization-decision-v0.md
  - igniter-lang/docs/tracks/prop038-proof-local-missing-after-implementation-v0.md
  - igniter-lang/docs/discussions/prop038-proof-local-missing-after-pressure-v0.md
  - igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md
- Prepare a design-only extraction plan for a future internal validator such as:
  - igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb
- Resolve design questions before any code:
  - descriptor digest input material and canonicalization;
  - short-vs-full digest policy for library validation;
  - diagnostic placement: local validator diagnostics vs shared
    `IgniterLang::Diagnostics`;
  - contract object input ownership;
  - proof-local parity requirements;
  - fixture/spec policy;
  - whether the library validator remains non-integrated and non-refusal.
- Do not implement code.
- Do not change production compiler behavior.
- Do not integrate with CompilerOrchestrator, CompilationReport,
  CompatibilityReport, CLI/API, assembler, `.igapp`, RuntimeMachine, or
  production.

Deliver:
- Design track in igniter-lang/docs/tracks/
- Proposed exact future implementation boundary or hold reasons
- Blockers before any library validator implementation authorization
```

This next route does not authorize implementation. It prepares a later
Architect decision.

---

## Held

Still held:

- library validator implementation;
- report-only compiler integration;
- compile refusal;
- descriptor digest canonical input material for integrated/persisted behavior;
- durable/persisted short-vs-full digest policy;
- contract input ownership for compiler integration;
- output/report location.

---

## Non-Authorizations Preserved

This decision does not authorize:

- production compiler integration;
- report-only compiler integration;
- compile refusal;
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

R63 accepts the proof-local missing-`after` implementation. The
`compiler_profile_contract` proof now covers missing rule references in both
`before` and `after` directions with
`compiler_profile_contract.missing_rule_reference`. The proof reports PASS with
13 cases and 23 checks. R62 proof-local Option A is closed. Next work, if any,
should be design-only for library validator extraction; no code or compiler
integration is authorized by this decision.
