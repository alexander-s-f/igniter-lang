# PROP-036 CLI Exposure Design And Blocker Tracking Decision v0

Card: S3-R45-C3-A
Agent: `[Architect Supervisor / Codex]`
Role: architect-supervisor
Track: `prop036-cli-exposure-design-and-blocker-tracking-decision-v0`
Route: UPDATE
Status: approved-design-route-implementation-held
Date: 2026-05-14

---

## Decision

Approve the future CLI exposure design route as:

```text
igc compile SOURCE --out OUT.igapp --compiler-profile-source PATH.json
```

where `PATH.json` is an explicit path to a standalone, already-finalized
`compiler_profile_id_source` JSON object.

Implementation remains held. This decision does not authorize CLI code changes.

The current public caller surface remains the Ruby facade only:

```ruby
IgniterLang.compile(..., compiler_profile_source: finalized_source)
```

---

## Evidence Read

- `docs/tracks/prop036-cli-exposure-input-shape-options-v0.md`
- `docs/tracks/prop036-facade-source-contract-hardening-v0.md`
- `docs/discussions/prop036-cli-api-profile-source-pressure-v0.md`
- `docs/tracks/stage3-round44-status-curation-v0.md`
- `docs/cards/S3/S3-R44.md`

---

## Findings

S3-R45-C1 compared four CLI input shapes:

1. explicit path to source JSON;
2. inline JSON string;
3. no CLI support yet / Ruby facade only;
4. named generated profile-source artifact.

The explicit path option is the best future CLI shape because it is scriptable,
inspectable, and can remain discovery-free if the CLI reads exactly the provided
path.

Inline JSON is rejected for first exposure because shell quoting, logging, and
report redaction risks are higher than the benefit.

Named generated artifact lookup is not ready because there is no standalone
generator/registry authority or stable generated profile-source artifact
contract.

S3-R45-C2 closes the R44 pressure concern at the dev-contract level: a finalized
`compiler_profile_source` is a finalized `compiler_profile_id_source` Hash-like
object from the minimal finalization proof, and the Ruby facade is
transport-only. Public guide/API docs and optional source-level visibility are
still pending.

---

## Approved Future CLI Shape

Future implementation cards may propose only this first CLI shape:

```text
--compiler-profile-source PATH.json
```

Allowed future behavior:

```text
No flag:
  preserve legacy_optional
  compile exactly as today
  manifest.compiler_profile_id absent

Flag present:
  read exactly PATH.json
  parse JSON object
  pass parsed object unchanged to IgniterLang.compile(..., compiler_profile_source:)
  let existing assembler/orchestrator validation own source-shape refusal
```

Rejected for first CLI implementation:

```text
--compiler-profile-source-json JSON
--compiler-profile-source-name NAME
--compiler-profile default
auto-discovery from cwd
auto-discovery from source sidecar
ENV/config based profile selection
profile finalization inside CLI
loader/report status emission
CompatibilityReport profile section
```

---

## Tracked Blockers Before CLI Implementation

Any future CLI implementation authorization must explicitly close every blocker
below.

| ID | Blocker | Required closure |
| --- | --- | --- |
| PROP036-CLI-B1 | Standalone source artifact contract | Define or prove a standalone finalized `compiler_profile_id_source` JSON artifact contract. Current proof summary JSON is evidence only, not a caller artifact contract. |
| PROP036-CLI-B2 | Exact CLI input shape | Use only `--compiler-profile-source PATH.json` for first exposure. No inline JSON, named lookup, env/config/sidecar/defaulting, or discovery. |
| PROP036-CLI-B3 | Path/parse refusal wording | Define missing path, nonexistent path, unreadable path, invalid JSON, and non-object JSON refusal wording without loader-status vocabulary. |
| PROP036-CLI-B4 | Nil/no-flag legacy proof | Prove `igc compile SOURCE --out OUT.igapp` remains unchanged and emits no `compiler_profile_id`. |
| PROP036-CLI-B5 | Invalid-source no-artifact proof | Prove invalid parsed source refuses before profiled `.igapp` output and uses existing `assembler_refused` / `compiler_profile_source.*` vocabulary. |
| PROP036-CLI-B6 | Negative-token scan set | Define and run the exact forbidden-token scan over all CLI-written JSON/refusal artifacts, including success manifests, refusal reports, summaries, and any stdout/stderr JSON if added. |
| PROP036-CLI-B7 | Caller-facing source-shape docs | Add or route public API/guide docs explaining the finalized source object, nil behavior, and non-authorized assumptions. |
| PROP036-CLI-B8 | Transport-only facade contract location | Add or route explicit contract wording so future orchestrator validation widening does not silently become public facade policy without review. |
| PROP036-CLI-B9 | Pressure review | Run runtime-pressure review after the proposed implementation boundary and before any implementation card is accepted as complete. |

---

## Authorized Next Work

This decision authorizes only design/docs/proof preparation:

- docs-only API guide work for `IgniterLang.compile(..., compiler_profile_source:)`;
- dev-contract tracking for finalized source-shape and transport-only wording;
- standalone `compiler_profile_id_source` artifact contract design/proof;
- CLI refusal-matrix design;
- pressure review of this decision.

It does not authorize CLI implementation.

---

## Explicit Non-Authorizations

This decision does not authorize:

- editing `igniter-lang/lib/igniter_lang/cli.rb`;
- editing `bin/igc`;
- adding a CLI flag;
- path loading in code;
- inline JSON parsing;
- named generated profile lookup;
- profile finalization, discovery, inference, or defaulting in CLI/API;
- loader/report implementation;
- CompatibilityReport compiler-profile section;
- `.igapp` golden migration;
- `.ilk` changes;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- RuntimeMachine binding;
- Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP production executor;
- production cache;
- production behavior.

---

## Compact Summary

S3-R45-C3-A approves the future CLI design route:
`--compiler-profile-source PATH.json`, where the path points to a standalone
finalized `compiler_profile_id_source` JSON object. CLI implementation is held.
Nine named blockers, `PROP036-CLI-B1` through `PROP036-CLI-B9`, must close
before any CLI implementation authorization. The current active public surface
remains Ruby facade transport only.
