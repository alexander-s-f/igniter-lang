# igniter-lang

Status: separate research workspace
Owner: `[Architect Supervisor / Codex]`
Agent identity: `[Igniter-Lang Research Agent]`

`igniter-lang` is a contract-native language research ecosystem adjacent to,
but separate from, the Igniter platform.

## Working Hypothesis

```text
Igniter      = framework/platform for real systems.
Igniter-Lang = language research ecosystem for contract-native computation.
```

They share concepts, but they should not share release pressure, package
boundaries, or premature syntax/runtime commitments.

## Why Separate

- The platform must stay practical and shippable.
- The language needs room for theory, axioms, and new paradigms.
- Research docs should not pollute platform docs.
- Language experiments should influence Igniter through explicit bridge notes,
  not by silently changing packages.

## Start Here

1. Read [AGENTS.md](AGENTS.md).
2. Read [.agents/agent-context.md](.agents/agent-context.md).
3. Use [docs/README.md](docs/README.md) as the language documentation index.
4. Use [.agents/README.md](.agents/README.md) for agent handoff and work routing.

## Package Status

`igniter_lang 0.1.0.alpha.1` is available on RubyGems as an alpha prerelease
compiler package.

Install:

```bash
gem install igniter_lang -v 0.1.0.alpha.1
```

Scope: bounded `igc` compiler CLI for accepted local corpus and the accepted
`--compiler-profile-source PATH.json` transport. See
[RELEASE_NOTES.md](RELEASE_NOTES.md) for evidence, exclusions, and non-claims.

## Current Navigation

Internal context and release evidence:

- [docs/README.md](docs/README.md) — documentation index
- [.agents/current-status.md](.agents/current-status.md) — detailed stage scoreboard and accepted local evidence
- [lib/igniter_lang.rb](lib/igniter_lang.rb) — package entrypoint
- [bin/igc](bin/igc) — compiler CLI entrypoint
- [RELEASE_NOTES.md](RELEASE_NOTES.md) — alpha package evidence and non-claims

Accepted release evidence for `0.1.0.alpha.1`:

- Repo-local compiler RC evidence: PASS
- Combined post-prep package/profile-source smoke: PASS
- RubyGems publish verification: PASS
- Isolated install verification: PASS
- Tag `igniter-lang-v0.1.0.alpha.1`: present

Still excluded: stable/production/public-demo claims, all grammar support,
profile finalization/discovery/defaulting, branch/conditional `if_expr`, Spark
integration, runtime/Ledger/TBackend/BiHistory readiness, signing, and
deployment.

## Repository Boundary

This repository owns the Igniter Language research package, specification,
source fixtures, selected experiments, and language-local agent work.

It does not own the Igniter Ruby Framework, Igniter Lab frontier
implementations, generated proof output, release automation outside this repo,
or public runtime/reference/production claims.

## Write Rule

Write only inside this repository unless a separate integration card explicitly
opens another target.
