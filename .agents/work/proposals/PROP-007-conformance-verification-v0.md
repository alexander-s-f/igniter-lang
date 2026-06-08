# PROP-007: Conformance Verification v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-004-type-system-v0.md`,
             `proposals/PROP-005-bridge-observation-envelope-v0.md`,
             `proposals/PROP-006-runtime-contract-specification-v0.md`

---

## Purpose

PROP-006 defined the `RuntimeContract` — a typed, versioned declaration of
how a runtime executes user contracts. But a declaration is not a proof.

A runtime that declares `storage.consistency: :strong` may in practice
serve stale reads. A runtime that declares `capability.grants_by_default:
false` may silently execute effects without capability checks.

This proposal defines **conformance verification**: the protocol by which
agents, compilers, and consumers can determine whether a runtime's actual
behaviour matches its declared `RuntimeContract`.

Goals:

1. Define the `verification_observation` protocol — a typed observation
   kind for conformance evidence.
2. Define checks for each sub-contract (scheduler, clock, cache, storage,
   capability).
3. Specify what constitutes a **warning** vs. a **failure** in conformance.
4. Define how an agent determines that runtime evidence is **trusted**.

This is a **formal specification only**. No implementation. No package edits.

---

## Compact Claim

[D] A runtime's `RuntimeContract` is a **promise**. Conformance verification
is the protocol for producing structured evidence that the promise was kept
or broken.

```text
RuntimeContract (promise)
  +  VerificationSuite (checks)
  ->  VerificationReport
        { passed: [...], warned: [...], failed: [...] }
        emitted as Obs[:platform_observation, VerificationReport]
```

A `VerificationReport` is itself an observation — a first-class semantic
artifact that agents and compilers can read, link, and reason about. It is
not a test runner output or a log file.

---

## Verification Observation Type

We introduce one new observation kind for this proposal: `:verification_observation`.

This is added to the closed `ObsKind` family from PROP-005 as a **controlled
extension**:

```text
ObsKind (extended) =
  ...existing eight kinds...
  | :verification_observation    -- result of a conformance check
```

**[D]** `:verification_observation` is CORE. It is a structured observation
that any conformance-capable runtime must be able to produce. It is not an
ESCAPE kind.

```text
Obs[:verification_observation, VerificationPayload]
where VerificationPayload = Record {
  suite_id    : String                        -- which suite was run
  suite_version: String                       -- semver
  runtime_ref : ObsId                         -- link to RuntimeContract obs
  axiom_ref   : ObsId                         -- link to AxiomDescriptor obs
  checks      : Collection[CheckResult]
  summary     : VerificationSummary
}

CheckResult = Record {
  check_id    : String                        -- stable check identifier
  check_kind  : CheckKind
  target      : Symbol                        -- which sub-contract this checks
  outcome     : :passed | :warned | :failed | :skipped | :inconclusive
  severity    : :info | :warning | :error | :critical
  evidence    : Collection[ObsId]             -- linked obs used as evidence
  expectation : String                        -- what was promised
  actual      : Option[String]                -- what was observed (may be redacted)
  remediation : Option[RemediationHint]
}

CheckKind = :behavioural   -- tests actual runtime behaviour
          | :declarative   -- validates internal consistency of declaration
          | :reachability  -- checks that a sub-contract surface is reachable
          | :capability    -- checks capability boundary enforcement
          | :temporal      -- checks temporal contract promises

VerificationSummary = Record {
  conformance_level  : :full | :partial | :failed | :inconclusive
  trust_level        : TrustLevel
  passed_count       : Int
  warned_count       : Int
  failed_count       : Int
  skipped_count      : Int
  inconclusive_count : Int
}
```

---

## Warning vs. Failure: Classification Rules

**[D]** A check outcome is:

| Outcome | Meaning | Conformance effect |
|---------|---------|-------------------|
| `:passed` | Observed behaviour matches declared promise | No effect |
| `:warned` | Observed behaviour deviates within declared ESCAPE bounds | Conformance is `partial`; trust is `conditional` |
| `:failed` | Observed behaviour contradicts declared promise | Conformance is `failed`; trust is `untrusted` |
| `:skipped` | Check could not run (missing capability, dry-run only, etc.) | No effect unless all checks are skipped |
| `:inconclusive` | Evidence was collected but not sufficient to decide | Conformance stays `inconclusive` |

**Warning threshold rule:**

A deviation is a **warning** if:
1. The declared `RuntimeContract` already lists this behaviour as ESCAPE, OR
2. The deviation is within the declared bound (e.g., storage lag within
   `lag_bound`), OR
3. The check kind is `:reachability` (surface exists but is not proven correct).

A deviation is a **failure** if:
1. The declared behaviour is CORE and the observed behaviour contradicts it, OR
2. The deviation exceeds a declared bound, OR
3. A required capability check is bypassed, OR
4. A CORE observation kind is missing or malformed.

---

## Check Suites

### Suite 1: Scheduler Checks

| Check ID | Kind | Promise checked | Failure condition | Warning condition |
|----------|------|----------------|------------------|------------------|
| `sched.order` | behavioural | `evaluation_order: :demand_driven` | Eager evaluation observed for a demand-only dependency | Topological ordering used instead |
| `sched.isolation` | behavioural | `isolation` level | Cross-contract mutation observed in `:isolated` mode | Shared state read in `:isolated` mode |
| `sched.timeout_obs` | declarative | `timeout_policy.timeout_obs: true` | Timeout occurred with no `failure_observation` emitted | Timeout obs emitted late (after client disconnects) |
| `sched.concurrency` | behavioural | `concurrency_max` | More than `concurrency_max` concurrent evaluations observed | Approaching max (> 90%) |
| `sched.obs_emit` | declarative | `observation_emit` mode | Observations missing when `:inline` promised | Observations delayed when `:async` promised |

**Verification method for `sched.order`:**

Run two contracts: `C1` with an expensive dependency and `C2` that does not
need it. Under demand-driven evaluation, `C2`'s dependency must not be
evaluated. Observe whether the AxiomDescriptor platform_observation shows
the unused dependency as evaluated. If it does, `sched.order` fails.

---

### Suite 2: Clock Checks

| Check ID | Kind | Promise checked | Failure condition | Warning condition |
|----------|------|----------------|------------------|------------------|
| `clock.source` | declarative | `source` matches actual | `clock.source: :monotonic` but timestamps go backward | Clock source field missing from obs |
| `clock.drift` | behavioural | `drift_bound` | Observed drift > `drift_bound` | Drift > 80% of `drift_bound` |
| `clock.as_of_policy` | behavioural | `allows_caller_supplied` | Caller-supplied `as_of` silently ignored | Caller-supplied `as_of` logged but not used |
| `clock.law6` | behavioural | No ambient clock reads | `Time.now` or equivalent observed in evaluation without TemporalCtx | Undeclared clock read in an internal node |
| `clock.test_determinism`| behavioural | `:test` source is deterministic | Same seed → different timestamps | Seed ignored |

**Verification method for `clock.law6`:**

Inject a sentinel contract that makes no temporal declarations. Observe
whether any `value_observation` or `fact_observation` packet in the session
carries an undeclared temporal context (i.e., a `temporal` field that was
not declared in the contract's `TemporalPolicy`). If so, ambient clock
reads are occurring.

**[D]** `clock.law6` failure is **critical severity**: ambient clock reads
violate Law 6 (Temporal Explicitness) and make all results from that session
potentially non-reproducible. A session with a `clock.law6` failure has
`trust_level: :untrusted`.

---

### Suite 3: Cache Checks

| Check ID | Kind | Promise checked | Failure condition | Warning condition |
|----------|------|----------------|------------------|------------------|
| `cache.invalidation_cascade` | behavioural | `cascade: true` | Stale derived value served after dependency change | Cascade delay > threshold |
| `cache.obs_emit` | declarative | `observation_emit` includes `:on_invalidation` | Cache invalidation occurs with no `platform_observation` emitted | Invalidation obs emitted after the invalidated value is served |
| `cache.scope` | behavioural | `scope` boundary | Cache hit crosses declared `scope` boundary | Cross-scope cache pollution detected |
| `cache.strategy` | declarative | `strategy` value | `:none` declared but caching observed | Cache used beyond declared scope |
| `cache.law5` | behavioural | Observation conservation | Changed dependency → unchanged cached result served without invalidation | Invalidation delayed but eventually consistent |

**Verification method for `cache.law5`:**

Evaluate contract `C` at `Tt₁`. Mutate a dependency `D`. Evaluate `C` again
at `Tt₂ > Tt₁`. If the second evaluation returns the same result as the
first (when it should differ), and no `platform_observation` for cache
invalidation was emitted between the two evaluations, then `cache.law5` fails.

**[D]** `cache.law5` failure is **critical severity**: it means the runtime
is silently violating observation conservation. Results from this session
cannot be trusted as reflecting current state.

---

### Suite 4: Storage Checks

| Check ID | Kind | Promise checked | Failure condition | Warning condition |
|----------|------|----------------|------------------|------------------|
| `storage.consistency` | behavioural | `ConsistencyModel.model` | `:strong` declared but non-monotonic reads observed | `:causal` declared but causal order violated |
| `storage.read_your_writes` | behavioural | `read_your_writes: true` | Write immediately followed by read returns stale value | Read-your-writes violated in different session |
| `storage.replay_enabled` | reachability | `replay.enabled: true` | Replay cursor rejected at runtime | Replay window shorter than declared `horizon` |
| `storage.compaction_obs` | declarative | `retention.compaction_obs: true` | Compaction occurs with no `platform_observation` emitted | Compaction obs emitted with incomplete payload |
| `storage.retention` | behavioural | `default_ttl` | Fact expired before `default_ttl` elapsed | Fact retained longer than declared (not a failure; a warning) |
| `storage.snapshot` | reachability | `snapshot: true` | Snapshot read fails when declared supported | Snapshot read succeeds but is slower than non-snapshot |

**Verification method for `storage.consistency`:**

For `:strong` consistency: write fact F, then read F from two different
consumers. If any consumer reads a version older than the write, `storage.consistency`
fails.

For `:causal` consistency: issue write W₁ causally before W₂. Read from a
consumer. If W₂ is visible but W₁ is not, causal order is violated — failure.

**[D]** `storage.consistency` failure where `:strong` was declared is
**critical severity**: any reproducibility claim from this session is invalid.

---

### Suite 5: Capability Checks

| Check ID | Kind | Promise checked | Failure condition | Warning condition |
|----------|------|----------------|------------------|------------------|
| `cap.default_deny` | behavioural | `grants_by_default: false` | Effect executed without explicit grant | Capability check skipped in dry-run mode |
| `cap.audit_obs` | declarative | `audit_obs: true` | Capability check occurs with no `constraint_observation` emitted | Audit obs emitted late or incomplete |
| `cap.approval_gate` | behavioural | `approval_required` set | Listed capability executed without approval receipt | Approval receipt present but expired |
| `cap.executor_model` | declarative | `executor_model` | Effect executed when `:dry_run_only` declared | Effect executed before intent_observation emitted |
| `cap.receipt_emit` | declarative | Effect execution emits receipt | Effect executed with no `receipt_observation` or `failure_observation` | Receipt emitted without `caused_by` link to intent |
| `cap.revocation` | behavioural | `revocable: true` | Revoked capability still grants access | Revocation delay > threshold |

**Verification method for `cap.default_deny`:**

Issue a contract with a declared effect that has NOT been granted. Observe
whether the effect executes or produces a `failure_observation` with
`status: :blocked` and `reason_code: capability.approval_required`. If the
effect executes, `cap.default_deny` fails.

**[D]** `cap.default_deny` failure is **critical severity**: silent capability
execution means the runtime cannot be used as a security boundary. All
capability claims from this session are invalid. Trust level drops to `:untrusted`.

**[D]** `cap.receipt_emit` failure (effect with no receipt or failure_observation)
is also **critical severity**: it means effects are invisible. The observation
spine is broken for this runtime.

---

## Trust Level Model

```text
TrustLevel = :trusted | :conditional | :untrusted | :unknown
```

Trust is derived from the `VerificationSummary`:

| Condition | Trust level |
|-----------|------------|
| All checks passed; zero failures; zero warnings | `:trusted` |
| Zero failures; warnings exist; all warnings are ESCAPE-declared deviations | `:conditional` |
| Any check with outcome `:failed` and severity `:error` | `:conditional` |
| Any check with outcome `:failed` and severity `:critical` | `:untrusted` |
| Suite not run or all checks `:skipped` | `:unknown` |

**[D]** Critical-severity failures always produce `:untrusted`. There is no
override. A runtime with a `clock.law6` failure, `cache.law5` failure,
`storage.consistency` failure, or `cap.default_deny` failure is `:untrusted`
regardless of how many other checks pass.

**How an agent reads trust:**

```text
-- An agent consumes a VerificationReport:
report : Obs[:verification_observation, VerificationPayload]

-- Check trust level:
if report.payload.some?.summary.trust_level == :trusted:
  -- evidence is trusted; agent may act on results
elif report.payload.some?.summary.trust_level == :conditional:
  -- agent must read warned_checks and decide per use case
  -- agent must NOT use results for irreversible effects without human review
elif report.payload.some?.summary.trust_level == :untrusted:
  -- agent must NOT act on results from this runtime
  -- agent emits failure_observation with reason_code: dependency.unresolved_reference
else -- :unknown:
  -- agent must request verification before acting
```

**[D]** An agent must not treat `:untrusted` runtime results as trusted by
adding more evidence or reasoning. The trust decision is made at the
verification boundary, not by downstream reasoning.

---

## Verification Session Protocol

A verification session is itself a contract — it has inputs, outputs,
temporal context, and produces observations:

```text
VerificationSession = Contract {
  inputs: {
    runtime_obs_id  : ObsId              -- the RuntimeContract obs to verify
    axiom_obs_id    : ObsId              -- the AxiomDescriptor obs
    suite_ids       : Collection[String] -- which check suites to run
    as_of           : TimeRef            -- temporal context for the session
    executor        : :inline | :external -- who runs the checks
  }
  outputs: {
    report          : Obs[:verification_observation, VerificationPayload]
  }
  effects: [
    -- Each check may produce platform_observations as side effects
    -- No user-visible effects; verification is read-only by default
  ]
  temporal: TemporalCtx { requires_as_of: true }
}
```

**[D]** Verification sessions are **read-only by default**. Checks observe
behaviour but do not write to user stores or trigger user effects. The only
writes are the `verification_observation` packet and any `platform_observation`
packets produced by checks themselves.

**[D]** A verification session has its own `Tt`. The `as_of` in the session's
`Tt` determines which `RuntimeContract` version is being verified. If the
runtime superseded its contract mid-session (PROP-006 open question), the
verifier must declare which version it is checking.

---

## Verification Observation Lifecycle

```text
1. Verification session starts
   -> Obs[:platform_observation, VerificationSessionStart]

2. For each check in the suite:
   -> Obs[:constraint_observation, CheckAttempt]  (check starts)
   -> [runtime behaviour observations collected as evidence]
   -> Obs[:constraint_observation, CheckResult]   (check concludes)

3. All checks complete
   -> Obs[:verification_observation, VerificationPayload]  (final report)
      links:
        describes  -> runtime_obs_id (the RuntimeContract)
        observed_under -> axiom_obs_id (the AxiomDescriptor)
        caused_by  -> VerificationSessionStart obs_id
```

**[D]** Every `CheckResult` in the report carries an `evidence` field:
a `Collection[ObsId]` of the observation packets used as evidence. This makes
verification decisions **auditable**: an agent or human can follow the links
and inspect the raw evidence that led to each check outcome.

---

## Fragment Classification

| Construct | Class | Reason |
|-----------|-------|--------|
| `VerificationSession` contract | CORE | Typed, demand-driven, read-only |
| `verification_observation` kind | CORE | Closed kind; structured |
| Running checks against CORE sub-contracts | CORE | Deterministic check logic |
| Running checks against distributed runtime | ESCAPE | Non-deterministic environment |
| Trust level `:trusted` assertion | CORE | Derived from verification report |
| Trust level override by downstream reasoning | OOF | Trust decisions are at verification boundary |
| Verification session with effects | ESCAPE | Side-effecting verification |
| Mutable check results (results change after emission) | OOF | Violates content-address stability |

---

## Relation to Existing Igniter Platform

The current Igniter platform has no formal `VerificationReport`. However,
the existing `Igniter::Diagnostics::Report` and `Igniter::Compiler::CompiledGraph`
produce structured output that maps partially to verification:

| Igniter concept | Verification equivalent |
|----------------|------------------------|
| `CompiledGraph` validation | `sched.order` + `sched.isolation` declarative checks |
| `Igniter::Error` with context | `CheckResult` with `failed` outcome |
| `VerificationReport` (existing) | `Obs[:verification_observation, ...]` formal type |
| Contract compile-time warnings | `warned` checks with `:warning` severity |
| No current runtime conformance check | Gap — `VerificationSession` fills this |

**[Signal]** The main gap in the existing platform is **behavioural checks**:
the platform validates contracts at compile time but does not emit structured
evidence that runtime behaviour (clock, cache, storage, capability) matches
declared contracts. PROP-007 specifies the protocol for filling this gap.

---

## Open Questions

[Q] Should the `VerificationSession` be a user-runnable contract or a
runtime-internal process? Recommendation: both. A runtime may run its own
internal verification at session start and emit the report. A user (agent,
CI pipeline) may also initiate a `VerificationSession` externally. The same
check suite applies in both cases; the `executor` field distinguishes.

[Q] Should failed checks block evaluation? Recommendation: critical-severity
failures should be configurable as blocking. In strict mode (production):
`trust_level: :untrusted` blocks further evaluation and emits a
`failure_observation` with `reason_code: dependency.unresolved_reference`.
In lenient mode (development/testing): warnings and non-critical failures
emit `platform_observation` but do not block.

[Q] How often should the verification suite run? Recommendation: at session
start (mandatory); optionally on a scheduled interval; always before an
irreversible effect is executed. Continuous runtime monitoring is a future
track.

[Q] Should individual checks have declared `as_of` points? Some checks
(e.g., `storage.replay_enabled`) must be run at a specific historical point.
Recommendation: checks that require historical state carry their own `as_of`
from the session's `TemporalCtx`.

---

## Rejected Paths

[X] Test-runner output as verification evidence. A text-format test result
is not a semantic artifact. Verification evidence must be typed
`Obs[:verification_observation, ...]` packets with content-addressed identity
and provenance links.

[X] Trust by declaration alone (no behavioural checks). A runtime that declares
`:strong` consistency but is never checked can make that declaration with no
consequence. Behavioural checks are mandatory for `:trusted` status.

[X] Trust override by downstream reasoning. Trust decisions are made at the
verification boundary. An agent may not accumulate additional evidence to
promote `:untrusted` to `:conditional`. This would undermine the purpose of
the trust model.

[X] Infinite check vocabulary. The check suite vocabulary must be closed and
versioned. New checks require a new suite version. Platform extensions may
define new checks via `platform_observation` but those are advisory only.

[X] Silent conformance failures. Every check outcome must produce a typed
observation. Silent failures are OOF — they contradict the fundamental
principle that every semantic event is observable.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-007
Status: done

[D] Decisions:
- Conformance verification produces Obs[:verification_observation, VerificationPayload].
  This extends the closed ObsKind family with one new CORE kind.
- VerificationPayload contains: suite_id, runtime_ref, axiom_ref, checks
  (Collection[CheckResult]), and VerificationSummary with trust_level.
- CheckResult carries: check_id, kind, target, outcome, severity, evidence
  (Collection[ObsId]), expectation, actual, remediation.
- Warning vs. failure rule: deviation is a warning if declared as ESCAPE or
  within bounds; failure if CORE promise is contradicted or bound exceeded.
- Critical severity failures (clock.law6, cache.law5, storage.consistency,
  cap.default_deny, cap.receipt_emit) always produce trust_level: :untrusted.
  No override is possible.
- Trust levels: trusted / conditional / untrusted / unknown.
  Agents must not act on :untrusted results for irreversible effects.
  Trust override by downstream reasoning is OOF.
- VerificationSession is a read-only contract (no user-visible effects).
  It has its own Tt; it checks the RuntimeContract version declared at as_of.
- Five check suites: scheduler (5 checks), clock (5 checks), cache (5 checks),
  storage (6 checks), capability (6 checks).
- Every CheckResult carries an evidence field (Collection[ObsId]) linking to
  the raw observation packets used as evidence. Verification is fully auditable.
- The verification observation lifecycle: SessionStart -> CheckAttempt ->
  CheckResult -> VerificationReport; all linked by causes_by and observed_under.

[R] Recommendations:
- Add :verification_observation to the closed ObsKind family in PROP-005's
  formal envelope spec (as a v0.1 extension to PROP-005).
- The existing Igniter VerificationReport should adopt the typed
  Obs[:verification_observation, ...] shape as the target for the bridge track.
- Run VerificationSession at session start (before first user contract),
  and before any irreversible (non-dry-run) effect is executed.
- Consider strict mode (block on critical failures) for production deployments.
- Proceed to Research Agent track: temporal-contracts-and-projections-v0.
  The formal foundation (PROP-001..PROP-007) is now complete; the research
  track can build named slices on solid ground.

[S] Signals:
- The five check suites map cleanly to the six RuntimeContract sub-contracts
  (FragmentSupport has no behavioural checks in v0 — it is verified by Pass 0).
- The evidence field in CheckResult is the observation-spine analogue of a
  test assertion's "expected vs. actual" — but typed, linked, and auditable.
- The trust level model (trusted/conditional/untrusted/unknown) is simple
  enough for agents to implement as a decision procedure:
  check trust_level before acting on results.
- The gap between Igniter's existing compile-time validation and the
  verification protocol's behavioural checks is exactly the gap the bridge
  track needs to fill first.

[Q] Open Questions:
- VerificationSession: runtime-internal, user-runnable, or both?
- Should critical failures block evaluation in strict mode?
- How often should verification suites run?
- Should individual checks carry their own as_of?

[X] Rejected:
- Test-runner output as semantic evidence.
- Trust by declaration alone.
- Trust override by downstream reasoning.
- Open check vocabulary.
- Silent conformance failures.

[Next] Proposed next slices:
- Research Agent track: temporal-contracts-and-projections-v0
  (PROP-001..PROP-007 are the formal foundation; the research track
   explores named slices, projection horizons, and command lifecycle)
- PROP-005 extension: add :verification_observation to the closed ObsKind family
- Bridge implementation track: VerificationSession as the first runtime
  bridge contract (cites PROP-005, PROP-006, PROP-007)
```
