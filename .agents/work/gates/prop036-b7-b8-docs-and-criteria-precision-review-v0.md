# PROP-036 B7/B8 Docs And Criteria Precision Review v0

Card: S3-R47-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop036-b7-b8-docs-and-criteria-precision-review-v0
Route: UPDATE
Status: approved-b7-b8-docs-closed-implementation-held
Date: 2026-05-14

---

## Decision

S3-R47-C1-P1 and S3-R47-C2-P1 are accepted as sufficient inputs for a minor
Architect decision/addendum.

This decision:

- closes `PROP036-CLI-B7` for the current CLI blocker package;
- closes `PROP036-CLI-B8` for the current CLI blocker package, with source-level
  comment visibility explicitly deferred by Architect authority;
- adds binding precision to `PROP036-CLI-B1`, `PROP036-CLI-B6`, and
  `PROP036-CLI-B8-C`;
- does not authorize CLI implementation.

CLI path loading, JSON parsing, loader/report, CompatibilityReport, golden
migration, `.ilk`, receipts, signing, dispatch migration, RuntimeMachine,
Ledger/TBackend, BiHistory, stream/OLAP, cache, and production behavior remain
closed.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop036-cli-b7-b8-ruby-api-docs-v0.md`
- `igniter-lang/docs/tracks/prop036-cli-closure-criteria-precision-addendum-prep-v0.md`
- `igniter-lang/docs/gates/prop036-cli-blocker-closure-criteria-decision-v0.md`
- `igniter-lang/docs/discussions/prop036-cli-blocker-closure-criteria-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round46-status-curation-v0.md`
- `igniter-lang/docs/ruby-api.md`
- `igniter-lang/docs/README.md`

---

## B7 Status

`PROP036-CLI-B7` is closed.

Reasons:

1. Caller-facing Ruby API docs landed at `igniter-lang/docs/ruby-api.md`.
2. `igniter-lang/docs/README.md` links to `ruby-api.md`.
3. The public doc includes `IgniterLang.compile` with
   `compiler_profile_source: nil`.
4. The public doc states the only supported caller shapes:
   `nil` and an already-finalized `compiler_profile_id_source` Hash-like
   object.
5. The public doc lists required finalized source fields.
6. The public doc states that `nil` preserves `legacy_optional`.
7. The public doc rejects file paths, raw JSON strings, raw profile id strings,
   unfinalized descriptors, runtime-authority objects, and dispatch-migration
   objects.
8. The public doc lists the non-authorized surfaces that remain closed.

Track docs alone did not close B7; the public API doc landing did.

---

## B8 Status

`PROP036-CLI-B8` is closed for the current CLI blocker package.

Reasons:

1. `igniter-lang/docs/ruby-api.md` contains transport-only wording for
   `compiler_profile_source:`.
2. The doc states the facade forwards the value unchanged to
   `CompilerOrchestrator#compile`.
3. The doc states the facade does not validate, finalize, discover, infer, load,
   parse, normalize, or default compiler profile sources.
4. The doc states future orchestrator/assembler validation widening does not
   automatically close facade/API review.
5. This Architect decision explicitly defers source-level comment visibility for
   this phase.

The source-comment deferral path is:

```text
igniter-lang/docs/gates/prop036-b7-b8-docs-and-criteria-precision-review-v0.md
```

The deferred optional follow-up remains:

```text
PROP036-facade-transport-source-comment-v0
```

That optional follow-up may add a source comment near `compiler_profile_source:`
in `lib/igniter_lang.rb`, but it is not required before closing B8 for the
current CLI blocker package.

---

## Precision Addendum

This addendum clarifies S3-R46-C4-A without changing the approved CLI design
route.

### Amendment 1: B1 Validation Chain

For `PROP036-CLI-B1`, `standalone_artifact_valid: true` must mean the standalone
artifact was validated by the same compiler-profile-source validation path used
by the finalization proof and assembler source contract.

It is not satisfied by JSON well-formedness, top-level object shape, or
field-presence checks alone.

Future B1 closure evidence must record a validation path such as:

```text
standalone_artifact_validation_path: finalization_and_assembler_source_contract
```

The closing track must state that the standalone file validates as a
`compiler_profile_id_source` payload suitable for future
`--compiler-profile-source PATH.json` use without discovery, defaulting, or
lookup.

### Amendment 2: B6 Scanner Self-Test

For `PROP036-CLI-B6`, a clean scan over real outputs is not enough. The B6 proof
must include an adversarial scanner self-test.

Required self-test cases:

1. Inject a bare forbidden token, for example `present_verified`, into a
   controlled scanner fixture or proof-local output. The scanner must report
   failure for that injected surface.
2. Include a qualified source-validation string, for example
   `compiler_profile_source.id_digest_mismatch` or
   `compiler_profile_source.malformed`, in a controlled scanner fixture or
   proof-local output. The scanner may pass only if the proof summary records
   that qualified `compiler_profile_source.*` strings are allowed
   source-validation vocabulary and are not loader-status vocabulary.

The proof summary must record:

```text
scanner_self_test_bare_forbidden_token_fails: true
scanner_self_test_qualified_source_validation_allowed: true
allowed_qualified_source_validation_terms
```

B6 is not closed by a scanner that traverses the right files but does not prove
that it can fail on an injected bare forbidden token.

### Amendment 3: B8-C Deferral Authority

For `PROP036-CLI-B8-C`, source-level visibility may be deferred only by an
explicit Architect decision or gate document that names the deferral path and
states that B8 relies on public Ruby API docs plus dev-contract wording instead
of a source comment for this phase.

A Research Agent, Compiler/Grammar Expert, Implementation Agent, or docs track
may recommend deferral, but a track recommendation alone does not close B8-C.

The closing evidence must record the exact gate/decision document path that
authorized the deferral.

Silent absence of a source comment still does not close B8.

---

## Resulting Blocker Status

| Blocker | Status | Notes |
| --- | --- | --- |
| `PROP036-CLI-B1` | open | Closure now requires validation-chain-specific evidence. |
| `PROP036-CLI-B3` | open | Unchanged by this decision. |
| `PROP036-CLI-B4` | open | Unchanged by this decision. |
| `PROP036-CLI-B5` | open | Unchanged by this decision. |
| `PROP036-CLI-B6` | open | Closure now requires adversarial scanner self-test evidence. |
| `PROP036-CLI-B7` | closed | Public Ruby API docs landed and are linked. |
| `PROP036-CLI-B8` | closed | Transport-only docs landed; source-level comment is Architect-deferred for this phase. |
| `PROP036-CLI-B9` | open | Unchanged by this decision. |

---

## Non-Authorization

This decision does not authorize:

- CLI flags;
- path loading;
- JSON parsing;
- profile discovery, inference, finalization, or defaulting in CLI/API;
- source code edits;
- loader/report implementation;
- CompatibilityReport compiler-profile section;
- `.igapp` golden migration;
- `.ilk`;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- RuntimeMachine binding;
- Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP production executors;
- production cache;
- production behavior.

---

## Next Allowed Boundary

The next pressure card may review this decision.

Future implementation authorization remains blocked until the remaining
`PROP036-CLI-B1..B9` blockers close under the updated criteria and an explicit
Architect implementation decision is issued.
