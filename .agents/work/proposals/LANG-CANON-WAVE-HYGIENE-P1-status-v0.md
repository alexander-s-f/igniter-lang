# LANG-CANON-WAVE-HYGIENE-P1: Status And Commit Slicing

**Status:** CLOSED -- hygiene report
**Date:** 2026-06-14
**Authority:** status/slicing report only; no staging or commit performed

---

## Current Git Status

Checked:

- `git status --short --untracked-files=all` in `igniter-lang`
- `git status --short --untracked-files=all` in `igniter-gov`
- `git diff --cached --name-status` in `igniter-lang`
- `.gitignore` entries for `experiments/` and `.agents/work/**`

### igniter-lang

Visible status:

```text
?? .agents/work/proposals/LANG-COMPOSE-ENTITY-PROP-P2-entity-prop-v0.md
```

Staged status:

```text
(none)
```

Tracked source changes currently dirty:

```text
(none)
```

So the earlier mixed source wave (`typechecker.rb`, `compilation_report.rb`,
`compiler_orchestrator.rb`) is not dirty in the current worktree snapshot.

### igniter-gov

Visible status:

```text
(clean)
```

The private checkpoints from today are already tracked/clean in `igniter-gov`:

- `portfolio/governance/2026-06-14-lang-compilation-report-diagnostic-attribution-p1-v0.md`
- `portfolio/governance/2026-06-14-lang-fold-struct-accumulator-p1-v0.md`
- `portfolio/governance/2026-06-14-lang-fold-struct-accumulator-p2-v0.md`
- `portfolio/governance/2026-06-14-lang-nested-record-literal-typing-p1-v0.md`

### igniter-lab

Visible status:

```text
(clean)
```

The nested-record source card is ignored by the lab/lang card ignore pattern,
but the file exists and is closed.

---

## Ignore Rules That Matter

From `igniter-lang/.gitignore`:

```gitignore
/experiments/
/.agents/work/**
!/.agents/work/
!/.agents/work/*/
!/.agents/work/proposals/
!/.agents/work/proposals/**
!/.agents/work/gates/
!/.agents/work/gates/**
!/.agents/work/meta/
!/.agents/work/meta/**
!/.agents/work/meta-proposals/
!/.agents/work/meta-proposals/**
!/.agents/work/conformance/
!/.agents/work/conformance/**
!/.agents/work/cards/
!/.agents/work/cards/README.md
```

Implications:

- Proof runners under `experiments/` are ignored.
- Individual cards under `.agents/work/cards/**` are ignored.
- Proposal docs under `.agents/work/proposals/**` are unignored and visible to
  normal git status.
- Card updates require explicit `git add -f` if they are meant to be committed.
- Proof runners require explicit `git add -f` if they are meant to be committed.

---

## Card Ownership Map

### Compose Entity

Card:

- `.agents/work/cards/lang/LANG-COMPOSE-ENTITY-P1.md` -- ignored, closed.

Tracked/visible proposal docs:

- `.agents/work/proposals/LANG-COMPOSE-ENTITY-P1-compose-entity-readiness-v0.md` -- tracked/clean.
- `.agents/work/proposals/LANG-COMPOSE-ENTITY-PROP-P2-entity-prop-v0.md` -- **visible untracked**.

Ignored proof runner:

- `experiments/compose_entity_proof/verify_compose_entity_p1.rb`

Recommended slice:

- Commit `LANG-COMPOSE-ENTITY-PROP-P2-entity-prop-v0.md` only with the P2 authoring
  card/proof artifacts if the user wants the P2 proposal captured.
- Do not mix this with diagnostic attribution source fixes or fold hygiene.

### Fold Struct Accumulator

Card:

- `.agents/work/cards/lang/LANG-FOLD-STRUCT-ACCUMULATOR-P1.md` -- ignored, closed.

Tracked/visible proposal docs:

- `.agents/work/proposals/LANG-FOLD-STRUCT-ACCUMULATOR-P1-readiness-v0.md` -- tracked/clean.
- `.agents/work/proposals/LANG-FOLD-STRUCT-ACCUMULATOR-P2-implementation-planning-v0.md` -- tracked/clean.

Ignored proof runners:

- `experiments/fold_struct_accumulator_proof/verify_fold_struct_accumulator_p1.rb`
- `experiments/fold_struct_accumulator_proof/verify_fold_struct_accumulator_p2.rb`

Recommended slice:

- No visible action required in the current status.
- If committing proof/card deliverables, force-add P1/P2 proof runners and cards
  in a fold-only commit.

### Temporal State

Card:

- `.agents/work/cards/lang/LANG-TEMPORAL-STATE-P1.md` -- ignored, closed.

Tracked/visible proposal doc:

- `.agents/work/proposals/LANG-TEMPORAL-STATE-P1-temporal-state-readiness-v0.md` -- tracked/clean.

Ignored proof runner:

- `experiments/temporal_state_proof/verify_temporal_state_p1.rb`

Recommended slice:

- No visible action required in the current status.
- If committing ignored artifacts, keep it docs-pattern/readiness only; do not
  mix with fold implementation planning.

### Diagnostic Attribution

Card:

- `.agents/work/cards/lang/LANG-COMPILATION-REPORT-DIAGNOSTIC-ATTRIBUTION-P1.md`
  -- ignored, closed.

Tracked/visible proposal doc:

- `.agents/work/proposals/LANG-COMPILATION-REPORT-DIAGNOSTIC-ATTRIBUTION-P1-v0.md`
  -- tracked/clean.

Ignored proof runner:

- `experiments/diagnostic_attribution_proof/verify_compilation_report_diagnostic_attribution_p1.rb`

Tracked source files named by the closed card:

- `lib/igniter_lang/compilation_report.rb`
- `lib/igniter_lang/compiler_orchestrator.rb`

Current status for those source files:

```text
clean
```

Recommended slice:

- If source changes need to be reconstructed or committed from another branch,
  keep diagnostic attribution as its own source commit:
  `compilation_report.rb` + `compiler_orchestrator.rb` + proposal/proof/card.
- Do not mix with readiness-only design cards.

### Nested Record Literal Typing

Card:

- `igniter-lab/.agents/work/cards/lang/LAB-NESTED-RECORD-LITERAL-TYPING-P1.md`
  -- ignored by lab work-card rules, closed.

Tracked/visible proposal doc in canon:

- `.agents/work/proposals/LAB-NESTED-RECORD-LITERAL-TYPING-P1-nested-record-hint-leakage-v0.md`
  -- tracked/clean.

Ignored proof runner:

- `experiments/nested_record_literal_typing_proof/verify_nested_record_literal_typing_p1.rb`

Tracked source file named by the closed card:

- `lib/igniter_lang/typechecker.rb`

Current status for that source file:

```text
clean
```

Recommended slice:

- If source changes need to be reconstructed or committed from another branch,
  keep nested record typing as its own compiler correctness commit:
  `typechecker.rb` + proposal/proof/card.
- Do not mix with fold/compose readiness docs.

---

## Minimal Safe Commit Grouping

Current visible work only needs one possible commit:

### Slice A -- Compose Entity P2 Proposal

Files:

- `.agents/work/proposals/LANG-COMPOSE-ENTITY-PROP-P2-entity-prop-v0.md`

Optional force-adds if the user wants complete local governance artifacts in the
same commit:

- `.agents/work/cards/lang/LANG-COMPOSE-ENTITY-PROP-P2.md`
- any matching proof runner if one exists for P2.

Rationale:

- It is the only visible untracked file in `igniter-lang`.
- It is proposal authoring only.
- It should not be mixed with already-clean P1 readiness docs or source-fix cards.

If the user wants to checkpoint the whole day including ignored proof/card
artifacts, use separate commits:

1. Diagnostic attribution source/reporting fix.
2. Nested record literal TypeChecker fix.
3. Compose entity P1/P2 design proposal docs.
4. Fold struct accumulator P1/P2 readiness/planning docs.
5. Temporal state docs-pattern readiness.
6. Private `igniter-gov` portfolio checkpoints, committed only in `igniter-gov`.

---

## Do Not Stage By Accident

Do not use a broad `git add -A` from `igniter-lang` if the intent is only the
visible compose P2 proposal. It would still not include ignored proof/card files,
but it could pick up any future visible proposal/source changes.

Do not force-add the ignored cards/proofs unless the commit explicitly wants
those artifacts:

```text
experiments/**
.agents/work/cards/lang/**
```

Do not move private `igniter-gov` checkpoints into `igniter-lang`. They are
private governance memory and do not create canon authority.

---

## Questions Answered

1. **Which tracked source changes belong together?** None are dirty right now.
   If reconstructed, diagnostic attribution is one source slice
   (`compilation_report.rb`, `compiler_orchestrator.rb`), and nested record
   typing is a separate source slice (`typechecker.rb`).
2. **Which ignored proof/card artifacts need force-add if committing?** Proof
   runners under `experiments/` and cards under `.agents/work/cards/lang/` for
   compose, fold, temporal, diagnostic attribution, and nested record typing.
3. **Which private gov checkpoints stay in gov only?** All
   `igniter-gov/portfolio/governance/2026-06-14-*` files stay in `igniter-gov`.
4. **Minimal safe commit grouping?** Commit only the visible compose P2 proposal
   now, or use separate card-specific commits if force-adding ignored artifacts.
5. **Unrelated staged changes?** None. `git diff --cached --name-status` is empty.

---

## Closure

No staging, commit, deletion, cleanup, or source edit was performed for this
card. This is a status/slicing report only.
