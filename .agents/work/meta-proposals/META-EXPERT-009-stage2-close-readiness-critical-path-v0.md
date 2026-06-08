# META-EXPERT-009: Stage 2 Close Readiness — Critical Path v0

Card: S2-R12-M1-S
Agent: [Igniter-Lang Strategic Meta Expert]
Role: meta-expert
Track: stage2-close-readiness-critical-path-v0
Date: 2026-05-07
Status: active

---

## I. Purpose

Assess Stage 2 close readiness after R12 and propose the R13–R15 critical path.

This is a scoped strategic document. It does not replace META-EXPERT-008
(Stage 2 governance) — it supplements it with a close-readiness verdict
and a prioritized final-mile plan.

---

## II. What Is Strong Enough to Close

The following surfaces are **proven, extracted, and coherent**. They do not
require further work before Stage 2 closes. They form the foundation of the
close verdict.

### II.A Language Model

| Surface | Evidence | State |
|---------|----------|-------|
| Parser (61 specs + stream + OLAP + invariant) | PROP-014/015/026 | ✅ proven |
| Classifier (CORE/ESCAPE/OOF + SC-1/3 + OOF-S1/2) | PROP-018/020 | ✅ proven |
| TypeChecker (BiHistory axes + OOF-S3 + OOF-O2..5 + TINV-1..3) | PROP-021/025 | ✅ proven |
| SemanticIR Emitter (OLAP + stream + invariant_node lowering) | PROP-019.1 | ✅ proven |
| .igapp/ Assembler (A1–A6) | PROP-022A | ✅ proven |
| RuntimeMachine (load/evaluate/checkpoint/resume + hook proof) | PROP-011/022 | ✅ proven |
| Stdlib kernel | PROP-013 | ✅ proven |
| stream T OOF-S1..S5 (all five rules) | PROP-023 | ✅ proven |
| OLAPPoint full stack (parser + TC + SemanticIR) | PROP-024 | ✅ proven |
| Invariant severity full stack (PINV-1..4 + TINV-1..3 + emitter + runtime obs) | PROP-025 | ✅ proven |
| History[T] / BiHistory[T] (parser + typechecker + temporal access hook) | PROP-022 | ✅ proven |

### II.B Compiler Package

| Surface | Evidence | State |
|---------|----------|-------|
| `IgniterLang.compile(...)` Ruby facade | R11 | ✅ proven |
| CLI/API/load-path shared boundary proof | R12 | ✅ proven |
| 11 extracted libs + facade in `lib/` | R3–R12 | ✅ stable |
| Compiler orchestrator (Parser→…→Assembler) | R10 | ✅ proven |

**Assessment:** The language surface and compiler boundary are production-ready
in proof-local form. Every PROP that was required by META-EXPERT-008 for Stage 2
closure has at least a passing proof.

---

## III. What Blocks Stage 2 Close

There are three distinct classes of remaining work. Only **Class A** is a hard
blocker.

### Class A — Hard Blockers (Stage 2 cannot close without these)

**A1. Gemspec / version / bin entrypoint**

`IgniterLang.compile` exists and its API is proven. But the gem has no
`gemspec`, no `lib/igniter_lang/version.rb`, and no `bin/` entrypoint.
The package is not installable or releasable.

This is the only item that stands between the current state and a releasable
Stage 2 close artifact. It is small, bounded, and has no language semantics risk.

**A2. Stage 2 close candidate evidence file**

Stage 1 close required a `stage1_close_candidate.json` as a machine-readable
close evidence record. Stage 2 needs an equivalent:
`experiments/stage2_close_candidate/stage2_close_candidate.rb` running the
full compiled pipeline through `IgniterLang.compile`, verifying invariant
observations, OLAP cells, and stream fold — and emitting a close JSON.

This is the formal evidence artifact, not a new proof. It assembles existing
proofs into a single close-time run.

### Class B — Important But Not Blocking Close

**B1. Production RuntimeMachine TBackend adapter**

The descriptor-first Ledger conformance is done. The proof-local adapter registry
shim is selected. But there is no production `TBackend` adapter that reads from
or writes to a real Ledger. This is correctly scoped as post-close or a conditional
close with deferred gap (as Stage 1 was).

**B2. Invariant OOF deferred rules**

OOF-I1 (`@bitemporal` severity), OOF-I3 (`~T` negation), OOF-I5 (requirements DB),
OOF-I2 (caller-warning advisory) — all formally deferred. These are language model
extensions, not Stage 2 compiler spine requirements.

**B3. OLAPPoint scatter/gather and rollup production emission**

The OLAP TC/SemanticIR boundary proof is done. Production OLAP rollup, scatter-gather,
and multi-cluster lowering are not proven. These are correctly deferred.

### Class C — Purely Deferred (not Stage 2 scope)

- Full MCP/mesh routing integration
- Production multi-TBackend adapter selection
- `igniter-frontend` / Arbre integration
- Domain-specific PROP-028+ surfaces
- compiler FFI / cross-runtime boundary

---

## IV. Critical Path: R13–R15

Three focused rounds close Stage 2. Each round has one primary card and at most
one supporting card.

### R13 — Packaging Skeleton

**Primary:** `compiler-packaging-skeleton-v0` [Research Agent]

Scope (minimal):
- Add `igniter_lang.gemspec` with correct `require_paths`, `files`, `version`
  reference, `ruby >= 3.1.0`, zero production dependencies
- Add `lib/igniter_lang/version.rb` with `VERSION = "0.1.0"` (pre-release)
- Add `bin/igc` as a thin shim calling `IgniterLang::CLI.run(ARGV)` or equivalent
- Run `gem build igniter_lang.gemspec` → produces `.gem` artifact
- Run existing `production_compiler_cli_proof` and `stage1_close_candidate` against
  the installed path (or at minimum against the load path) — must PASS
- Do NOT release to RubyGems

Do not add:
- CI/CD configuration
- documentation generation
- multi-gem split
- `rake release` automation

**Supporting (optional, same round):** `runtime-smoke-production-adapter-plan-v0`
[Research Agent]

Docs-only: how `IgniterLang::RuntimeSmoke` maps to the production RuntimeMachine
boundary. Single-page decision doc. No code. Unlocks B1 slicing in Stage 3.

**Acceptance:**
- `gem build` succeeds
- `gem install igniter_lang-0.1.0.gem` succeeds in a clean `bundle exec` context
- `production_compiler_cli_proof` PASS against installed gem load path
- `stage1_close_candidate` PASS

### R14 — Stage 2 Close Candidate

**Primary:** `stage2-close-candidate-v0` [Research Agent]

Scope:
- Create `experiments/stage2_close_candidate/`
- `stage2_close_candidate.rb` calls `IgniterLang.compile(source)` for at least:
  - a contract with invariant severity (PINV + TINV path)
  - a contract that accesses OLAP cells (dims_record path)
  - a contract with stream fold (fold_stream path)
  - a BiHistory temporal access (history_read path)
- Emits `stage2_close_candidate.json` with: `stage`, `verdict`, `timestamp`,
  `proofs_run`, `libs_loaded`, `facade_version`
- Must be runnable with `ruby igniter-lang/experiments/stage2_close_candidate/stage2_close_candidate.rb`
- All four path checks must PASS

Do not:
- Re-implement compiler passes
- Add new OOF rules
- Modify any lib file

**Acceptance:**
- `stage2_close_candidate.json` verdict = `"stage2_close_candidate"`
- All four path checks PASS
- `stage1_close_candidate` still PASS (no regression)

### R15 — Close Decision

**Primary:** `stage2-close-decision-v0` [Meta Expert]

Scope:
- Author `META-EXPERT-009.1-stage2-close-decision-v0.md`
- Verify: gemspec builds, close candidate PASS, Stage 1 still PASS
- Record formal close verdict: CLOSE or CLOSE WITH DEFERRED GAPS
- Identify any deferred gaps (likely: TBackend adapter, OOF-I1/I3/I5, OLAP rollup)
- Freeze Stage 2 governance: lock META-EXPERT-008 as `decision`
- Archive: define `docs/archive/snapshots/YYYY-MM-DD-stage2-close/`
- Open Stage 3 skeleton if close is confirmed

Acceptance:
- Formal close verdict documented
- META-EXPERT-008 status updated to `decision`
- Stage 3 opening conditions drafted (or Stage 2 kept open with documented blocker)

---

## V. What Should Stay Deferred

The following are explicitly deferred and should not be pulled into R13–R15
unless the Architect overrides.

| Item | Why deferred | Recommended stage |
|------|-------------|-------------------|
| Production TBackend adapter (Ledger read/write) | Not required for compiler package close | Stage 3 / Bridge lane |
| OOF-I1 (`@bitemporal`), OOF-I3 (`~T`), OOF-I5 (req DB) | Language model extensions, no compiler spine risk | Stage 3 / PROP-028+ |
| OLAPPoint scatter/gather, multi-cluster rollup | Advanced OLAP; proof surface not ready | Stage 3 |
| MCP/mesh integration | Platform integration; requires Bridge Agent + Architect approval | Stage 3+ |
| `igniter-frontend` Arbre/Tailwind | Separate gem boundary | Stage 3+ |
| PROP-028+ new language surfaces | Not in Stage 2 scope | Stage 3 |

**Rule:** If a new idea needs a PROP-028+ number, it belongs in Stage 3.

---

## VI. Risk Register

| Risk | Severity | Mitigation |
|------|----------|-----------|
| `gem build` breaks due to load path mismatch (`../igniter_lang.rb`) | Medium | Adjust `require_paths` to `["lib"]`; `igniter_lang.rb` lives at `lib/igniter_lang.rb`; confirm path is correct before R13 |
| Stage 2 close candidate breaks on experimental proof internals | Low | Only call `IgniterLang.compile`; do not reach into experiment-local classes |
| OOF-I1/I3 pressure from applied fixtures | Low | Document as deferred in close decision; do not reopen Stage 2 |
| R14 introduces new lib behavior to pass close tests | High risk if this happens | Strictly: close candidate must be read-only toward lib |

---

## VII. Neighbor Requests

| Role | Request |
|------|---------|
| `[Research Agent]` | Execute `compiler-packaging-skeleton-v0` (R13). Confirm gem build path. |
| `[Research Agent]` | Execute `stage2-close-candidate-v0` (R14). Four path check min. |
| `[Compiler/Grammar Expert]` | Confirm no new PROP is required for R13–R15 close path. Review deferred OOF list. |
| `[Bridge Agent]` | Review Class B deferred TBackend gap. Author Stage 3 bridge note when close is confirmed. |

---

## VIII. Open Questions

**[Q1]** Is `lib/igniter_lang.rb` the correct root entrypoint, or does the gemspec
need `require_paths: ["lib"]` with the file at `lib/igniter_lang.rb`?  
Current state: `../igniter_lang.rb` references suggest it may live outside
`lib/igniter_lang/`. Confirm before R13 begins.

**[Q2]** Should the Stage 2 close candidate prove all four surface paths in one
Ruby file, or should it delegate to existing proofs via `require_relative`?  
Recommendation: single file, call `IgniterLang.compile` directly. No delegation.

**[Q3]** Should the formal close verdict in R15 produce a new META-EXPERT-009.1,
or update META-EXPERT-008 directly?  
Recommendation: new META-EXPERT-009.1 (close decision). META-EXPERT-008 updated
to `superseded: META-EXPERT-009.1`.

---

## Handoff

```text
Card: S2-R12-M1-S
Agent: [Igniter-Lang Strategic Meta Expert]
Role: meta-expert
Track: stage2-close-readiness-critical-path-v0
Status: done

[D] Decisions
- Stage 2 is close-ready in language and compiler surfaces.
- Two hard blockers remain: gemspec/packaging skeleton (A1) and Stage 2 close
  candidate evidence file (A2). Both are bounded, low-risk, and have no language semantics.
- R13 = packaging skeleton. R14 = close candidate. R15 = close decision.
  This is a 3-round critical path, not 5.
- TBackend, OOF-I1/I3/I5, OLAP rollup, MCP: explicitly deferred. Not Stage 2 blockers.
- Role governance: Meta Expert writes to meta-proposals/. Tracks belong to Research Agent.

[S] Signals
- All PROP-022 through PROP-027 are PASS with extracted lib modules.
- 11 libs + Ruby facade + shared boundary proof are in place.
- The gem just needs a gemspec and a close evidence artifact.

[T] Proofs verified at time of this assessment
- stage1_close_candidate: PASS 5/5
- production_compiler_cli_proof: PASS 9 checks
- IgniterLang.compile facade: require ok

[R] Risks
- See Section VI. Primary risk: load-path alignment for gemspec. Resolve in R13 first task.
- Do not let R13 scope creep into documentation generation, CI, or multi-gem split.
- R14 close candidate must call only the public API; no experiment-internal calls.

[Next] Suggested next slices (R13–R15 critical path)
  R13: compiler-packaging-skeleton-v0          [Research Agent]       ← primary close blocker
  R13: runtime-smoke-production-adapter-plan-v0 [Research Agent]      ← optional, docs-only
  R14: stage2-close-candidate-v0               [Research Agent]
  R15: stage2-close-decision-v0                [Meta Expert]

Neighbor requests:
  → [Research Agent]: R13, R14
  → [Compiler/Grammar Expert]: confirm no PROP needed for close path
  → [Bridge Agent]: plan Stage 3 TBackend bridge note after close
```
