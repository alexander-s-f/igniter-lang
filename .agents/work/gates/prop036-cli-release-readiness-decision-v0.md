# PROP-036 CLI Release Readiness Decision v0

Card: S3-R52-C1-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop036-cli-release-readiness-decision-v0
Route: UPDATE
Status: conditional-release-readiness-doc-sync-required
Date: 2026-05-15

---

## Decision

Conditionally approve release-readiness for the already-landed bounded
PROP-036 CLI transport:

```text
igc compile SOURCE --out OUT.igapp --compiler-profile-source PATH.json
```

The implementation and proof evidence are sufficient for the bounded transport,
but release-readiness is not complete until caller-facing documentation is
updated to match the now-authorized CLI surface.

This is a documentation/pre-release condition only. No new implementation is
authorized by this decision.

---

## Evidence Read

- `igniter-lang/docs/gates/prop036-cli-remaining-blockers-formal-closure-decision-v0.md`
- `igniter-lang/docs/discussions/prop036-cli-remaining-blockers-closure-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round51-status-curation-v0.md`
- `igniter-lang/docs/gates/prop036-cli-b3-b6-implementation-authorization-review-v0.md`
- `igniter-lang/docs/tracks/prop036-cli-profile-source-b3-b6-implementation-proof-v0.md`
- `igniter-lang/docs/discussions/prop036-cli-profile-source-implementation-pressure-v0.md`
- `igniter-lang/docs/ruby-api.md`
- `igniter-lang/lib/igniter_lang/cli.rb`

---

## Readiness Findings

The bounded CLI implementation is technically ready for release promotion
inside the exact scope below:

```text
--compiler-profile-source PATH.json
```

Reasons:

- the full `PROP036-CLI-B1..B9` blocker package is formally closed by named
  Architect gates and pressure records;
- R50 implementation proof passes `12/12` cases and `4/4` commands;
- forbidden exact-token scan reports `0` hits;
- B6 scanner self-test proves both bare-token failure and qualified
  `compiler_profile_source.*` allowance;
- R50/R51 pressure reviews both return `proceed`;
- `IgniterLang::CLI` adds only path JSON transport and delegates unchanged data
  to `IgniterLang.compile`;
- no RuntimeMachine, Ledger/TBackend, CompatibilityReport, loader/report,
  dispatch migration, cache, or production behavior was added.

However, `igniter-lang/docs/ruby-api.md` still says CLI profile-source flags and
path loading remain closed unless a later gate authorizes them. This R52
decision is that later gate for the bounded CLI surface, so the docs must be
updated before release-readiness is treated as complete.

---

## Exact Public CLI Surface

Release-readiness is conditionally approved only for:

```text
igc compile SOURCE --out OUT.igapp --compiler-profile-source PATH.json
```

No other CLI input shapes are approved.

Still rejected:

```text
--compiler-profile-source-json JSON
--compiler-profile-source-name NAME
--compiler-profile default
inline JSON
raw compiler_profile_id string
named/generated profile lookup
environment/config/sidecar discovery
profile source finalization in CLI
```

---

## Accepted Source Input Shape

`PATH.json` must point to an already-finalized `compiler_profile_id_source`
JSON object.

The CLI owns only OS/JSON preflight:

- path exists;
- path is a regular file;
- file is readable;
- file contains valid JSON;
- top-level JSON value is an object.

The CLI does not validate, finalize, normalize, discover, infer, or default
compiler profile sources. Semantic source validation remains owned by the
existing compiler/orchestrator/assembler path.

---

## Supported Success And Refusal Behavior

No flag:

```text
igc compile SOURCE --out OUT.igapp
```

Behavior:

- preserves legacy behavior;
- emits `.igapp` for valid source;
- manifest omits `compiler_profile_id`.

Valid `--compiler-profile-source PATH.json`:

- emits `.igapp` for valid source and valid finalized source object;
- manifest contains `compiler_profile_id` from the source object;
- stdout remains compiler_result JSON;
- stderr is empty on success.

CLI preflight refusal:

- non-zero exit;
- stdout empty;
- one stable stderr line;
- no `OUT.compilation_report.json`;
- no `OUT.igapp`;
- no profile-source report JSON.

Semantic compiler-profile-source refusal:

- non-zero exit;
- stdout compiler_result JSON;
- `OUT.compilation_report.json` exists;
- `OUT.igapp` absent;
- reasons use qualified `compiler_profile_source.*` vocabulary.

---

## R50 NB-1 Release Behavior

The R50 pressure NB-1 is accepted as release behavior:

```text
--compiler-profile-source --some-flag
```

is treated as `--some-flag` being the path token and may fall through to the
path-not-found refusal. This is standard Unix argument behavior and not a
security, authority, or runtime-scope issue.

This edge case should be documented if CLI docs add detailed refusal examples,
but it is not a blocker for the bounded release-readiness condition.

---

## Caller-Facing Documentation Condition

Before the bounded CLI transport is marked fully release-ready, a docs-only
sync must land.

Required documentation update:

- update `igniter-lang/docs/ruby-api.md` or add/link a caller-facing CLI/API doc
  that names:
  - `igc compile SOURCE --out OUT.igapp --compiler-profile-source PATH.json`;
  - `PATH.json` as an already-finalized `compiler_profile_id_source` object;
  - no-flag legacy behavior;
  - preflight refusal behavior;
  - semantic refusal behavior;
  - transport-only semantics;
  - no discovery/defaulting/finalization;
  - all excluded surfaces that remain closed.
- remove or qualify the outdated blanket statement that CLI profile-source
  flags/path loading remain closed, replacing it with the R52 bounded exception.

No code changes are required by this condition unless a future pressure review
finds a documentation/behavior mismatch.

---

## Regression And Proof Evidence Cited

Release-readiness condition cites:

```text
S3-R50-C2-I proof matrix: 12/12 PASS
S3-R50-C2-I command matrix: 4/4 PASS
forbidden_exact_token_hits: 0
scanner_self_test_bare_forbidden_token_fails: true
scanner_self_test_qualified_source_validation_allowed: true
S3-R50-C3-X pressure: proceed
S3-R51-C1-A blocker package closure: approved-remaining-cli-blockers-formally-closed
S3-R51-C2-X pressure: proceed
```

---

## Explicitly Closed Surfaces

This decision does not authorize:

- new CLI implementation;
- widening beyond `--compiler-profile-source PATH.json`;
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

This decision approves package-surface release-readiness only after the docs
condition is met. It does not grant runtime, production, ledger, or Gate 3
authority.

---

## Exact Next Allowed Boundary

Next allowed work:

```text
docs-only caller-facing CLI release-readiness sync
```

The follow-up may update:

```text
igniter-lang/docs/ruby-api.md
igniter-lang/docs/README.md
```

or create a small linked caller-facing CLI doc if that is cleaner.

After that docs sync, a pressure review or status-curation card may mark the
R52 condition satisfied if no mismatch is found. Any implementation work or
surface widening requires a separate Architect decision.

---

## Compact Summary

S3-R52-C1-A conditionally approves release-readiness for the already-landed
bounded PROP-036 CLI transport `--compiler-profile-source PATH.json`. The code
and proof are sufficient, and the full `PROP036-CLI-B1..B9` blocker package is
closed. Release-readiness remains conditional on caller-facing documentation
sync because current docs still describe CLI profile-source flags/path loading
as closed. No new implementation, surface widening, runtime authority,
CompatibilityReport, loader/report, dispatch migration, Ledger/TBackend, cache,
or production behavior is authorized.
