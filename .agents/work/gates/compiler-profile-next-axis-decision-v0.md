# Compiler Profile Next Axis Decision v0

Card: S3-R55-C4-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: compiler-profile-next-axis-decision-v0
Route: UPDATE
Status: approved-proof-only-obligation-coverage-first
Date: 2026-05-16

---

## Decision

Authorize the next bounded compiler/profile axis as a **proof-local,
report-only obligation coverage track**:

```text
compiler-profile-obligation-coverage-proof-v0
```

This is the next authoritative pressure point after PROP-036 CLI closure.

The proof must test whether the active/finalized compiler profile source covers
the language surfaces exercised by a program. It must not change compiler
behavior, `.igapp` emission, CLI behavior, loader/report behavior,
CompatibilityReport behavior, dispatch, runtime, or production surfaces.

Implementation remains held.

---

## Evidence Read

- `igniter-lang/docs/tracks/language-profile-compiler-obligation-map-v0.md`
- `igniter-lang/docs/tracks/compiler-profile-contract-formalization-options-v0.md`
- `igniter-lang/docs/discussions/compiler-profile-contract-pressure-v0.md`
- `igniter-lang/docs/tracks/stage3-round54-status-curation-v0.md`
- `igniter-lang/docs/proposals/PROP-036-compiler-profile-manifest-identity-v0.md`
- `igniter-lang/docs/current-status.md`

---

## Findings

R55 confirms the thesis:

```text
language surface -> profile identity -> compiler obligations -> infrastructure pressure
```

but also identifies the missing middle layer:

```text
finalized compiler_profile_id_source exists
  but
surface coverage by that profile is not yet proven
```

Today, PROP-036 proves that a caller can transport a finalized profile source
and the assembler can emit `manifest.compiler_profile_id`. It does not prove
that the supplied profile's slots cover the language surfaces compiled in a
specific program.

That gap must be closed before loader/report, CompatibilityReport, dispatch, or
golden migration can be treated as well-founded next steps.

---

## CompilerProfile Role For The Next Axis

For the next track, `CompilerProfile` acts as a:

```text
profile slot obligation source
```

It does not yet act as:

- a live compiler dispatch contract;
- a pack registry contract;
- a RuntimeMachine capability contract;
- a production authority contract.

The eventual target may be a hybrid `compiler_profile_contract`, as described
by C2-P1, but the next immediate move is obligation coverage proof over the
existing finalized profile source path.

---

## Authorized Next Card Boundary

The next allowed card is:

```text
Card: S3-R56-C1-P1
Agent: [Igniter-Lang Research Agent]
Role: research-agent
Track: compiler-profile-obligation-coverage-proof-v0
```

Allowed scope:

- Read existing compiler/profile proposals, R55 outputs, and existing proof
  fixtures.
- Define a proof-local `CompilerProfileObligationReport`.
- Detect language surfaces used by selected existing fixtures, including as
  practical:
  - core;
  - contract modifiers;
  - temporal;
  - stream;
  - olap;
  - invariant;
  - assumptions;
  - progression descriptor/report metadata if present.
- Map each detected surface to required compiler profile slots.
- Validate that an existing finalized `compiler_profile_id_source` has the
  required `slot_order` / `slot_assignments`.
- Emit report-only statuses such as:

  ```text
  covered
  missing_slot
  unsupported_surface
  profile_not_supplied
  ```

- Prove that missing coverage affects only profile-coverage reporting in this
  proof-local slice.
- Preserve the invariant:

  ```text
  profile-covered compile does not imply runtime readiness
  ```

Required guardrail:

```text
The obligation report is output-only. It must not gate `.igapp` emission,
CLI exit status, assembler emission, loader/report status, CompatibilityReport,
or RuntimeMachine behavior.
```

Deliver:

- track doc in `igniter-lang/docs/tracks/`;
- executable proof or proof-local script under `igniter-lang/experiments/`;
- summary JSON;
- compact evidence table mapping fixture -> surfaces -> required slots ->
  coverage status;
- exact list of remaining blockers before any implementation authorization.

---

## Sequencing Decision

The obligation coverage proof runs first.

C2-P1's `compiler_profile_contract` formalization options are accepted as the
correct target direction, but not opened as an implementation track now.

Reason:

- the obligation proof will reveal concrete coverage semantics;
- the future contract design should be informed by those semantics;
- running contract design first risks freezing an abstract object before the
  proof demonstrates what it must carry.

After the obligation coverage proof lands, Architect may open a design-only
track such as:

```text
compiler-profile-contract-boundary-v0
```

That future design track should use a new PROP or new design packet, not a
small PROP-036 errata, if it promotes `CompilerProfile` from manifest identity
to compiler contract.

---

## PROP-037 Progression Slot Disposition

For the obligation coverage proof v0:

```text
progression descriptor/report metadata remains under the existing `pipeline`
slot if it appears at all.
```

No new `progression` slot is authorized in this decision.

The question of whether PROP-037 needs a future explicit `progression` slot is
kept open for the later contract boundary/design track. It must not be silently
baked into the v0 proof.

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

1. `compiler-profile-obligation-coverage-proof-v0` lands and is pressure
   reviewed.
2. The proof demonstrates stable fixture -> surface -> slot coverage mapping.
3. The proof demonstrates output-only behavior and does not mutate compiler
   behavior.
4. Diagnostic/status vocabulary is stable enough to avoid collision with:
   - `compiler_profile_source.*`;
   - future `compiler_profile_contract.*`;
   - loader/report status vocabulary.
5. Architect issues a separate implementation authorization decision with an
   exact write scope.

---

## Compact Summary

R55 chooses obligation coverage as the next compiler/profile axis. PROP-036 CLI
transport is complete at package-surface confidence level, but profile transport
is not yet profile coverage. The next proof must show which language surfaces a
program uses, which profile slots those surfaces require, and whether the
finalized profile source covers them.

The proof is report-only and output-only. It must not gate compilation or widen
any runtime, loader/report, CLI, dispatch, or production surface.
