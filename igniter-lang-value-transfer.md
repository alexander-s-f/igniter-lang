# igniter-lang Value Transfer Map

Status: rough value-positive map / underfill preferred / no physical transfer yet
Date: 2026-06-06

## Principle

This repo should receive the living Igniter Lang system, not the whole old
monorepo history. Transfer only surfaces that are required to understand,
develop, specify, test, or audit the language. Everything else should stay
out by default and be recovered from archive only when a concrete need appears.

Path notation:
- source paths are relative to `projects/`, e.g. `igniter/igniter-lang/docs/spec/`
- target paths are relative to `igniter-workspace/`, e.g. `igniter-lang/docs/spec/`

## Transfer Stance

Decision: positive allowlist, not exhaustive monorepo classification.

Bias: underfill. Do not carry stale round history, generated proof outputs,
local paths, old status churn, or Ruby Framework examples into the language repo.

## Bring First

| Source | Target | Why |
| --- | --- | --- |
| `igniter/igniter-lang/AGENTS.md` | `igniter-workspace/igniter-lang/AGENTS.md` | Language-local agent instructions. Rewrite if it still assumes monorepo paths. |
| `igniter/igniter-lang/README.md` | `igniter-workspace/igniter-lang/README.md` | Language repo entrypoint. Keep language-only, no Ruby Framework authority. |
| `igniter/igniter-lang/RELEASE_NOTES.md` | `igniter-workspace/igniter-lang/RELEASE_NOTES.md` | If still relevant to language package state; otherwise archive. |
| `igniter/igniter-lang/bin/` | `igniter-workspace/igniter-lang/bin/` | Language CLI surface, subject to tests after transfer. |
| `igniter/igniter-lang/lib/` | `igniter-workspace/igniter-lang/lib/` | Language package implementation. |
| `igniter/igniter-lang/source/` | `igniter-workspace/igniter-lang/source/` | Canonical language source specimens. |
| `igniter/igniter-lang/fixtures/` | `igniter-workspace/igniter-lang/fixtures/` | Development fixtures that support active language tests/proofs. |
| `igniter/igniter-lang/tests/` | `igniter-workspace/igniter-lang/tests/` | Current language tests if still runnable. |
| `igniter/igniter-lang/examples/` | `igniter-workspace/igniter-lang/examples/` | Only current language examples; generated `out/` stays out. |
| `igniter/igniter-lang/docs/spec/` | `igniter-workspace/igniter-lang/docs/spec/` | Runtime/language specification. |
| `igniter/igniter-lang/docs/proposals/` | `igniter-workspace/igniter-lang/docs/proposals/` | Active proposal history needed for language semantics. |
| `igniter/igniter-lang/docs/meta-proposals/` | `igniter-workspace/igniter-lang/docs/meta-proposals/` | Only if still used for governance. Otherwise move to org/archive. |
| `igniter/igniter-lang/docs/dev/` | `igniter-workspace/igniter-lang/docs/dev/` | Current developer docs. Prune monorepo/Ruby Framework language. |
| `igniter/igniter-lang/docs/gates/` | `igniter-workspace/igniter-lang/docs/gates/` | Keep only active gate docs with current authority. |
| `igniter/igniter-lang/docs/current-status.md` | `igniter-workspace/igniter-lang/docs/current-status.md` | Rewrite compactly as split-era status, not full monorepo route ledger. |
| `igniter/igniter-lang/igniter_lang.gemspec` | `igniter-workspace/igniter-lang/igniter_lang.gemspec` | Needs metadata rewrite before package/release authority. |

## Bring Selectively

| Source | Target | Rule |
| --- | --- | --- |
| `igniter/igniter-lang/docs/tracks/` | `igniter-workspace/igniter-lang/docs/tracks/` or archive | Bring only active/latest decision docs needed for current governance. Do not bulk-copy all rounds. |
| `igniter/igniter-lang/docs/discussions/` | `igniter-workspace/igniter-lang/docs/discussions/` or archive | Bring current pressure/discussion docs only when they explain active routes. |
| `igniter/igniter-lang/docs/cards/` | archive or org | Do not bulk-copy old card history. Bring only active split-era cards if useful. |
| `igniter/igniter-lang/docs/reports/` | archive | Bring only summary reports still needed by active status. |
| `igniter/igniter-lang/docs/reviews/` | archive | Archive by default. |
| `igniter/igniter-lang/docs/bridge/` | maybe `docs/bridge/` | Include only if bridge docs are current language docs, not Ruby integration drift. |
| `igniter/igniter-lang/docs/org/` | `igniter-workspace/igniter-org/` or archive | Org/portfolio material should not become language product docs. |
| `igniter/igniter-lang/experiments/` | selected `experiments/` or archive | Bring only curated active experiments that still define current proof evidence. Exclude generated `out/`. |

## Exclude From Living Repo

| Source | Disposition |
| --- | --- |
| `igniter/igniter-lang/out/` | exclude/archive; generated output. |
| any `*/out/`, `*.igapp`, logs, build outputs | exclude by default. |
| `igniter/igniter-lang/docs/archive/` | `igniter-workspace/igniter-archive/` if needed, not living language repo. |
| bulk Stage 3 round cards/tracks/status churn | archive by default; bring only compact split-era status. |
| local absolute path reports and `file://` links | rewrite, quarantine, or exclude before public push. |
| root Ruby Framework docs/examples/packages | belongs to `igniter-ruby`, not language. |
| lab frontier implementation | belongs to `igniter-lab`, not language authority. |

## First Detail Round

Proposed first per-repo card:

```text
Card: LANG-SPLIT-P1
Track: igniter-lang-positive-transfer-detail-v0
Goal: Turn this rough allowlist into a copy plan for the living language repo,
deciding which docs/tracks/experiments are current enough to copy and which
go to archive. Underfill preferred.
```

## Physical Transfer Readiness

Not ready for physical copy yet.

Required before copy:
- rewrite `README.md`, `AGENTS.md`, and `docs/current-status.md` for split-era language repo;
- decide package metadata for `igniter_lang.gemspec`;
- choose a tiny subset of `docs/tracks/` and `experiments/`;
- exclude generated outputs;
- run language tests/smokes after copy;
- scan links for monorepo-relative paths and local paths.
