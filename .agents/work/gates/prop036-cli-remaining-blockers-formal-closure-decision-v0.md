# PROP-036 CLI Remaining Blockers Formal Closure Decision v0

Card: S3-R51-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop036-cli-remaining-blockers-formal-closure-decision-v0
Route: UPDATE
Status: approved-remaining-cli-blockers-formally-closed
Date: 2026-05-15

---

## Decision

Formally close the remaining PROP-036 CLI blockers:

```text
PROP036-CLI-B3
PROP036-CLI-B4
PROP036-CLI-B5
PROP036-CLI-B6
PROP036-CLI-B9
```

Together with the previously closed blockers, this means the
`PROP036-CLI-B1..B9` blocker package is formally closed.

This decision does not authorize new implementation. It does not widen the
already-landed bounded CLI transport:

```text
igc compile SOURCE --out OUT.igapp --compiler-profile-source PATH.json
```

The CLI surface remains transport-only: read exactly `PATH.json`, parse it as a
JSON object, and pass the parsed object unchanged to `IgniterLang.compile`.

---

## Evidence Read

- `igniter-lang/docs/gates/prop036-cli-b3-b6-implementation-authorization-review-v0.md`
- `igniter-lang/docs/tracks/prop036-cli-profile-source-b3-b6-implementation-proof-v0.md`
- `igniter-lang/docs/discussions/prop036-cli-profile-source-implementation-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round50-status-curation-v0.md`
- `igniter-lang/docs/gates/prop036-cli-b1-formal-closure-decision-v0.md`
- `igniter-lang/docs/gates/prop036-cli-blocker-closure-criteria-decision-v0.md`
- `igniter-lang/docs/gates/prop036-b7-b8-docs-and-criteria-precision-review-v0.md`
- `igniter-lang/experiments/prop036_cli_profile_source_b3_b6_implementation_proof/out/prop036_cli_profile_source_b3_b6_implementation_proof_summary.json`

---

## Closure Summary

The R50 implementation/proof and pressure review satisfy the closure criteria
for the remaining blockers.

Proof matrix:

```text
cases: 12/12 PASS
commands: 4/4 PASS
forbidden_exact_token_hits: 0
scanner_self_test_bare_forbidden_token_fails: true
scanner_self_test_qualified_source_validation_allowed: true
```

Pressure review:

```text
S3-R50-C3-X verdict: proceed
blockers: none
scope checks: 9/9 PASS
B9: satisfied by S3-R50-C3-X
```

The R50 pressure NB-1 about `--compiler-profile-source --some-flag` falling
through as a path token is accepted as non-blocking. It is standard Unix
argument behavior, has no authority/safety implication, and was not part of the
R46 B3 closure criteria.

---

## B3 Formal Closure

`PROP036-CLI-B3` is formally closed.

Closure basis:

- S3-R50-C1-A accepted the hybrid refusal model from R46.
- S3-R50-C2-I proves all seven required preflight refusal cases.
- S3-R50-C3-X independently verifies the refusal shape and reports `PASS`.

Required preflight cases proven:

```text
B3.missing_profile_path
B3.profile_path_not_found
B3.profile_path_not_regular_file
B3.unreadable_path
B3.invalid_json
B3.top_level_not_object
B3.unsupported_extra_argument
```

Required preflight shape proven:

```text
exit: non-zero
stdout: empty
stderr: one stable line
OUT.compilation_report.json: absent
OUT.igapp: absent
profile-source report JSON: absent
raw file contents: not emitted
parser backtrace: not emitted
bare forbidden tokens: absent
```

Semantic profile-source refusals after `IgniterLang.compile` continue to use
the existing compiler/orchestrator/assembler refusal path. That boundary is
intentional and matches R46/R50.

---

## B4 Formal Closure

`PROP036-CLI-B4` is formally closed.

Closure basis:

- no-flag legacy compile remains valid;
- no profile source is loaded, discovered, defaulted, or inferred when the flag
  is absent;
- manifest omits `compiler_profile_id`;
- behavior remains `legacy_optional`.

Proof evidence:

```text
case: B4.legacy_no_flag
result: PASS
exit: 0
stdout_shape: compiler_result_json
stderr: empty
igapp_emitted: true
legacy_no_flag_manifest_omits_compiler_profile_id: true
```

---

## B5 Formal Closure

`PROP036-CLI-B5` is formally closed.

Closure basis:

- parsed JSON objects that pass CLI preflight but fail source validation refuse
  through the existing compiler/orchestrator/assembler path;
- no profiled `.igapp` is emitted for invalid semantic source objects;
- refusal reasons use qualified `compiler_profile_source.*` vocabulary.

Required semantic refusal cases proven:

```text
B5.wrong_kind
B5.unfinalized_status
B5.runtime_authority_requested
```

Proof evidence:

```text
invalid_profile_source_no_igapp: true
OUT.compilation_report.json: present for B5 refusal cases
stdout_shape: compiler_result_json
stderr: empty
```

Qualified refusal terms accepted as source-validation vocabulary:

```text
compiler_profile_source.wrong_kind
compiler_profile_source.unfinalized
compiler_profile_source.runtime_authority_forbidden
```

These are not loader-status or runtime-readiness vocabulary.

---

## B6 Formal Closure

`PROP036-CLI-B6` is formally closed.

Closure basis:

- proof scans every stream/artifact required by R46/R50;
- exact forbidden-token hits are `0`;
- adversarial scanner self-test satisfies R47 C3-A Amendment 2.

Scan surface proven:

```text
stdout streams for all proof cases
stderr streams for all proof cases
proof summary JSON
proof-local .igapp/**/*.json
proof-local OUT.compilation_report.json
```

Forbidden exact-token result:

```text
forbidden_exact_token_hits: 0
```

Scanner self-test evidence:

```text
scanner_self_test_bare_forbidden_token_fails: true
scanner_self_test_qualified_source_validation_allowed: true
```

Allowed qualified source-validation terms:

```text
compiler_profile_source.wrong_kind
compiler_profile_source.unfinalized
compiler_profile_source.runtime_authority_forbidden
```

The scanner distinction between exact forbidden tokens and qualified
`compiler_profile_source.*` validation vocabulary is accepted for this blocker.

---

## B9 Formal Closure

`PROP036-CLI-B9` is formally closed.

Closure basis:

- R45 defined B9 as runtime-pressure review after the proposed implementation
  boundary and before implementation acceptance;
- S3-R50-C3-X is that review;
- all nine scope checks pass;
- verdict is `proceed`;
- blockers are none.

This decision accepts S3-R50-C3-X as the B9 evidence record.

---

## Formal Blocker Status Table

| Blocker | Status | Closure Authority |
| --- | --- | --- |
| `PROP036-CLI-B1` | closed | S3-R49-C1-A |
| `PROP036-CLI-B2` | satisfied by approved design route | S3-R45-C3-A / preserved by S3-R50-C1-A |
| `PROP036-CLI-B3` | closed | S3-R51-C1-A |
| `PROP036-CLI-B4` | closed | S3-R51-C1-A |
| `PROP036-CLI-B5` | closed | S3-R51-C1-A |
| `PROP036-CLI-B6` | closed | S3-R51-C1-A |
| `PROP036-CLI-B7` | closed | S3-R47-C3-A |
| `PROP036-CLI-B8` | closed | S3-R47-C3-A |
| `PROP036-CLI-B9` | closed | S3-R51-C1-A citing S3-R50-C3-X |

The full `PROP036-CLI-B1..B9` blocker package is closed.

---

## Explicit Non-Authorizations

This decision does not authorize:

- new CLI implementation;
- widening the CLI surface beyond `--compiler-profile-source PATH.json`;
- inline JSON CLI input;
- named/generated profile lookup;
- environment/config/sidecar profile lookup;
- profile source discovery/defaulting/finalization in CLI/API;
- loader/report status implementation beyond existing compiler refusal behavior;
- CompatibilityReport compiler-profile section;
- existing `.igapp` golden migration;
- `.ilk`;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- RuntimeMachine binding;
- Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

This decision also does not claim production readiness. It closes the named
PROP-036 CLI blocker package only.

---

## Next Allowed Boundary

The next pressure card may review this decision.

After pressure review, a future Architect decision may decide whether the
bounded CLI transport should move from blocker-closed to next implementation or
release-readiness work. Any such future decision must keep separate:

- blocker package closure;
- production/release readiness;
- loader/report/CompatibilityReport status;
- dispatch migration;
- RuntimeMachine and Gate 3 surfaces;
- production behavior.

---

## Compact Summary

S3-R51-C1-A formally closes the remaining PROP-036 CLI blockers B3/B4/B5/B6/B9
from R50 implementation proof and pressure evidence. The full
`PROP036-CLI-B1..B9` blocker package is now closed. No new implementation,
surface widening, production behavior, RuntimeMachine, Ledger/TBackend,
CompatibilityReport, loader/report, dispatch migration, `.ilk`, receipts, or
cache behavior is authorized.
