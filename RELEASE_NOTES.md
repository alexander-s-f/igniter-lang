# Igniter-Lang Release Notes

## 0.1.0.alpha.1 (alpha prerelease)

**Status:** published alpha prerelease
**Package:** `igniter_lang`
**Executable:** `igc`
**RubyGems:** <https://rubygems.org/gems/igniter_lang>
**Tag:** `igniter-lang-v0.1.0.alpha.1`
**Artifact SHA256:** `sha256:749ee7879cf4b5cb80035e16facdc68dd63e2ebbbec9f13d3d8c23e56e6282d6`

---

### What This Is

This is the first public prerelease candidate for the `igniter_lang` package.
It is an alpha release of the bounded compiler CLI for the Igniter contract-native
language research workspace.

This is **not** a stable release, **not** a production release, and **not** a
public demo claim.

---

### Accepted Release Evidence

The following evidence was accepted for `0.1.0.alpha.1` before and after
publication.

| Evidence | Status |
|---|---|
| Repo-local compiler RC evidence | PASS |
| Combined post-prep package/install smoke | PASS |
| Combined post-prep profile-source installed smoke | PASS |
| RubyGems API verification | PASS |
| Isolated install from RubyGems | PASS |
| Isolated `require "igniter_lang"` | PASS |
| Installed `igc` executable present | PASS |
| Local and remote tag `igniter-lang-v0.1.0.alpha.1` | PASS |

RubyGems reports the published gem SHA as:

```text
sha256:749ee7879cf4b5cb80035e16facdc68dd63e2ebbbec9f13d3d8c23e56e6282d6
```

---

### Bounded CLI

The installed `igc` CLI supports bounded contract compilation:

```text
igc compile SOURCE --out OUT.igapp
igc compile SOURCE --out OUT.igapp --compiler-profile-source PATH.json
```

`PATH.json` must be an already-finalized `compiler_profile_id_source` JSON object.
The CLI does not discover, default, finalize, or infer compiler profile sources.

---

### Exclusions

The following are **explicitly excluded** from this release:

| Surface | Status |
|---|---|
| Stable release | Not this version |
| Production-ready | No claim |
| Public demo-ready | No claim |
| All grammar support | No claim — bounded accepted corpus only |
| Branch/conditional `if_expr` | **Excluded** from first RC scope |
| Profile finalization | Closed — explicit finalized path transport only |
| Profile discovery | Closed |
| Profile defaulting | Closed |
| Named/generated profile lookup | Closed |
| Inline JSON profile source | Closed |
| Env/config/sidecar profile lookup | Closed |
| Spark integration | Out of scope |
| Ruby Framework compatibility | Not claimed |
| Runtime / Ledger / TBackend / BiHistory | Not claimed |
| Public API/CLI widening | No widening beyond accepted `--compiler-profile-source PATH.json` |
| RubyGems availability | Published alpha prerelease |
| Release execution | Completed for `0.1.0.alpha.1` |
| Tag/push | Completed for exact tag `igniter-lang-v0.1.0.alpha.1` |
| Signing/deploy | Closed |

---

### What Remains Closed

Signing and deployment remain closed. This alpha prerelease does not authorize
stable, production, public demo, all grammar, branch/conditional `if_expr`,
profile discovery/defaulting/finalization, Spark, or runtime readiness claims.

---

### Non-Claims

```text
not_stable:                              true
not_production_ready:                    true
not_public_demo_ready:                   true
not_all_grammar_support:                 true
branch_conditional_if_expr_excluded:     true
profile_finalization_closed:             true
profile_discovery_closed:                true
profile_defaulting_closed:               true
spark_out_of_scope:                      true
ruby_framework_compatibility_not_claimed: true
rubygems_available_claim:                true
release_execution_completed:             true
tag_push_completed:                      true
sign_deploy_authorized:                  false
```
