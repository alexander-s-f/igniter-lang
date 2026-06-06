# Igniter-Lang Proposals Index

Status: Stage 3 active intake
Maintainer: `[Igniter-Lang Compiler/Grammar Expert]`
Stage 1 closed: 2026-05-06 (META-EXPERT-007)
Stage 2 closed: 2026-05-07 (META-EXPERT-009.1)

---

## Accepted — Stage 1 Frozen

All Stage 1 PROPs are frozen and read-only.

→ See [proposals/accepted/](accepted/README.md) — 20 files.

Do not modify accepted PROPs. Errata may be added alongside originals.

---

## Stage 2 — Closed (2026-05-07)

Stage 2 PROPs are closed when their experiment reached PASS verdict in META-EXPERT-009.1.
Closed PROPs remain in `proposals/` for reference. They are not moved to `accepted/`
(that directory is Stage 1 only).

| File | Status | Summary |
|------|--------|---------|
| [PROP-022](PROP-022-history-type-constructor-v0.md) | accepted | History[T]/BiHistory[T]; temporal operations; Stage 2 experiment PASS (META-EXPERT-009.1); Stage 3 extensions: PROP-028, PROP-022A |
| [PROP-023](PROP-023-stream-input-surface-v0.md) | accepted | stream T; window; fold_stream; KPN grounding; Stage 2 experiment PASS (META-EXPERT-009.1) |
| [PROP-024](PROP-024-olap-point-primitive-v0.md) | accepted | OLAPPoint[T,Dims]; olap_point declaration; Stage 2 experiment PASS (META-EXPERT-009.1) |
| [PROP-025](PROP-025-invariant-severity-levels-v0.md) | accepted | invariant severity :error/:warn/:soft/:metric; Stage 2 experiment PASS (META-EXPERT-009.1); OOF-I1/I3/I5 deferred |
| [PROP-026](PROP-026-parser-oof-hardening-spec-v0.md) | accepted | Parser OOF hardening; PH-1..PH-8, PF-1..PF-4; Stage 2 experiment PASS (META-EXPERT-009.1) |
| [PROP-027](PROP-027-production-compiler-diagnostics-contract-v0.md) | accepted | Production compiler CLI + diagnostics contract; CL-1..CL-10; Stage 2 experiment PASS (META-EXPERT-009.1) |

---

## Stage 3 — Active

| File | Status | Summary |
|------|--------|---------|
| [PROP-028](PROP-028-temporal-fragment-class-v0.md) | implemented-proof | TEMPORAL fragment class; classifier/typechecker/SemanticIR/assembler/load-guard proven (S3-R2..R5); parser syntax + production runtime pending |
| [PROP-022A](PROP-022A-temporal-manifest-errata-v0.md) | experiment-pass | Errata to accepted/PROP-022A: TEMPORAL manifest contract_index + fragment_summary; assembler PASS (S3-R5-C1) |
| [PROP-029](PROP-029-entrypoint-section-surface-v0.md) | authored-pending-review | Entrypoint as named evaluation/run profile; section as grouping-only source organization; no parser implementation yet |
| [PROP-030](PROP-030-executor-approval-token-contract-v0.md) | authored-pending-review | ExecutorApprovalToken contract; explicit approval as Gate 3 prerequisite; no executor or Gate 3 authorization |
| [PROP-030A](PROP-030A-temporal-scope-exclusion-errata-v0.md) | authored-pending-review | Errata to PROP-030: canonical `runtime.temporal_scope_exclusion` refusal for out-of-scope TEMPORAL executor artifacts |
| [PROP-031](PROP-031-contract-modifiers-v0.md) | experiment-pass | Contract modifiers: optional `pure/observed/effect/privileged/irreversible` prefix, implicit pure default, OOF-M1 only; parser/classifier/typechecker/SemanticIR proof PASS; no Effect Surface/Profile/authority/runtime enforcement |
| [PROP-032](PROP-032-assumptions-block-v0.md) | experiment-pass | `assumptions {}` block + `uses assumptions NAME`; Phase 1/2/3/4 compiler proofs accepted by S3-R36-C2-A; PROP-033 evidence validation and runtime receipts remain excluded |
| [PROP-036](PROP-036-compiler-profile-manifest-identity-v0.md) | accepted | `compiler_profile_id` manifest identity; accepted proposal-only by S3-R35-C3-A; separate implementation authorization required before code |
| [PROP-037](PROP-037-external-progression-service-liveness-v0.md) | accepted | External progression and service liveness semantics; accepted proposal-only by S3-R37-C3-A; descriptor/proof follow-ups only, no parser/runtime/fragment-class authorization |
| [PROP-038](PROP-038-compiler-profile-contract-v0.md) | accepted | `compiler_profile_contract`; accepted proposal-only by S3-R61-C3-A; proof-local implementation, internal validator extraction, report-only annotation, digest policy/proofs/errata, live validator implementation, strict-mode/refusal designs, proof-local result-shape, live implementation scope review, bounded internal-only strict-refusal implementation, live internal foundation acceptance, canon sync, and R86 Ch5/Ch7/language-spec sync are accepted in sequence through S3-R86-C4-A; public API/CLI, persisted reports/sidecars, loader/report, CompatibilityReport, runtime, Gate 3 widening, and production remain closed |
| [PROP-039](PROP-039-managed-local-recursion-and-loop-classes-v0.md) | authored-pending-review | Managed local recursion and loop classes: FiniteLoop, BudgetedLocalLoop, StructuralRecursion, FuelBoundedRecursion, ConvergentLoop vocabulary; service liveness remains PROP-037-owned; proposal-only, no parser/typechecker/SemanticIR/runtime/API/CLI/package/public/reference/stable/production/release/performance/certification/portability authority |

---

## Stage 2+ — Open Proposals (authored, not yet experiment-PASS)

These proposals were authored in Stage 2 but their experiments have not yet reached PASS.
They remain active intake. Verification requires Architect authorization.

| File | Status | Summary |
|------|--------|---------|
| [PROP-002](PROP-002-contract-composition-algebra-v0.md) | authored-pending-review | Typed port graph algebra: >>, \|\|, branch, over, embed; algebraic laws |
| [PROP-005](PROP-005-bridge-observation-envelope-v0.md) | authored-pending-review | Obs[kind,T] envelope; Identity/Provenance/Policy groups; ObsPacket |
| [PROP-005.1](PROP-005.1-obspacket-patch-lifecycle-verification-v0.md) | authored-pending-review | Patch document: ObsPacket v0.1 lifecycle field, :verification_observation, WF-10/11 |
| [PROP-007](PROP-007-conformance-verification-v0.md) | authored-pending-review | Verification protocol: 5 check suites, trust levels, agent trust decision |
| [PROP-008](PROP-008-tbackend-contract-v0.md) | implemented-proof | TBackend[T]: read, append, replay, snapshot, compact, subscribe; descriptor fixture PASS (Stage 2); live binding gated (Gate 3 closed) |
| [PROP-010](PROP-010-temporal-lifecycle-retention-semantics-v0.md) | authored-pending-review | 6 lifecycle classes, flush semantics, semantic GC roots, downgrade rules |
| [PROP-016](PROP-016-polymorphism-traits-contract-shapes-v0.md) | authored-pending-review | Generic contracts, traits, contract_shape, monomorphization |
| [PROP-017](PROP-017-schema-evolution-contract-migration-v0.md) | authored-pending-review | SemVer versioning, schema_fingerprint, MigrationDecl, OOF-S1..S5 |

---

## Queued (not yet authored)

PROP-032 is authored and promoted to experiment-pass by proof (assumptions block). New Stage 3+
proposal IDs must consult this queue before claiming a number.

**Queue renumbering (GI-1 resolution, S3-R30-C6-P):** PROP-032 was previously assigned to
`via profile binding`. It is now PROP-032 = `assumptions {}` block. All downstream IDs shift +1.

**PROP-036 lifecycle:** S3-R33-C3-A assigns PROP-036 to `compiler_profile_id`
manifest identity, S3-R34-C5-P authors the proposal, and S3-R35-C3-A accepts it
as proposal-only. It still authorizes no implementation, `.igapp` mutation,
loader/assembler/runtime binding, dispatch migration, or runtime execution
authority.

**PROP-037 lifecycle:** S3-R35-C4-A assigns PROP-037 to external progression and
service liveness semantics; S3-R36-C4-P authors the proposal as proposal-only.
S3-R37-C3-A accepts it as proposal-only, and no parser, TypeChecker, SemanticIR,
RuntimeMachine scheduler, Ledger/TBackend, durable queue, production execution,
ProgressionPack migration, or new fragment class is authorized. Managed local
recursion / loop-class extensions are now authored separately as PROP-039;
PROP-037 remains authoritative for external progression and service liveness.

**PROP-038 lifecycle:** S3-R60-C3-A assigns PROP-038 to
`compiler_profile_contract` after R57-R60 boundary/proof/validator coverage.
S3-R61-C1-P1 authors the proposal, and S3-R61-C3-A accepts it as proposal-only
with implementation held. S3-R62-C3-A authorizes only the first proof-local
implementation under `experiments/compiler_profile_contract_proof/` for
missing-`after` coverage, and S3-R63-C3-A accepts/closes that proof-local gap.
S3-R64-C3-A accepts the Option B library validator extraction design and
authorizes only the next bounded internal proof-parity implementation card.
S3-R65-C3-A accepts and closes that internal validator extraction. It does not
authorize production compiler integration, compile refusal, `.igapp` mutation,
loader/report behavior, CompatibilityReport behavior, dispatch migration,
dynamic pack loading, runtime execution, or production behavior. S3-R66-C3-A
accepts the report-only compiler integration design and authorizes only next
bounded Candidate A implementation: internal provider on `CompilerOrchestrator`
plus in-memory `CompilationReport` field, report-only and never refusal. Public
API/CLI widening, persisted success reports, sidecars, `.igapp`, loader/report,
CompatibilityReport, runtime, and production remain closed. S3-R67-C3-A accepts
and closes that bounded Candidate A implementation with 5 cases / 20 checks PASS.
Public API/CLI widening, `CompilerResult` changes, persisted success reports,
sidecars, `.igapp` mutation beyond proof-local output generation, loader/report,
CompatibilityReport, runtime, Gate 3, compile refusal, and production remain
closed. S3-R68-C3-A accepts the hybrid `contract_digest` validation policy
design: current validator behavior remains `prop038_24_plus` and report-only,
with no `contract_digest` check added now; future validation must pass
shape-only proof before recompute-match proof. Only the proof-local
`prop038-contract-digest-shape-policy-proof-v0` route opens next; implementation,
compile refusal, public surfaces, persisted reports, loader/report,
CompatibilityReport, runtime, Gate 3 widening, and production remain closed.
S3-R69-C3-A accepts the proof-local shape-policy proof with 8 cases / 19 checks
PASS. The diagnostic candidates
`compiler_profile_contract.contract_digest_invalid` and
`compiler_profile_contract.contract_digest_policy_unsupported` are stable enough
for future design/proof work only, not live implementation. Only the proof-local
`prop038-contract-digest-recompute-match-proof-v0` route opens next; live
validator/compiler implementation, compile refusal, public surfaces,
loader/report, CompatibilityReport, runtime, Gate 3 widening, and production
remain closed.
S3-R70-C3-A accepts the proof-local recompute-match proof with 14 cases / 15
checks PASS. Canonicalization material is stable enough for future design/proof,
and the full four-code `contract_digest_*` candidate set is proof-covered across
R69/R70. Only the proof-local
`prop038-contract-digest-report-only-integration-proof-v0` route opens next.
PROP-038 errata and live validator/compiler implementation remain held until
that integration proof is accepted and a separate Architect decision opens them.
S3-R71-C3-A accepts the proof-local report-only integration proof with 12 cases /
21 checks PASS. The three-phase digest proof chain is complete for design
purposes, and the four-code `contract_digest_*` vocabulary is stable enough for
PROP-038 errata/design text. S3-R72-C3-A accepts the errata/design text; the
four-code vocabulary is now canon as PROP-038 design vocabulary. Only the
`prop038-contract-digest-live-implementation-design-v0` route opens next, and it
is design-only planning. S3-R73-C4-A accepts the design and authorizes only one
bounded internal validator implementation card next:
`prop038-contract-digest-live-validator-implementation-v0`. S3-R74-C3-A accepts
that bounded implementation only inside `IgniterLang::CompilerProfileContractValidator`.
S3-R75-C3-A accepts `prop038-contract-digest-compile-refusal-preconditions-design-v0`
as precondition design only. No `contract_digest_*` diagnostic is authorized as
compile-refusal behavior. S3-R76-C4-A accepts the strict-mode/refusal trigger
design and authorizes only `prop038-strict-mode-refusal-trigger-proof-local-v0`
as the next bounded proof-local experiment. S3-R77-C3-A accepts and closes that
proof-local experiment with 12 cases / 15 checks PASS; only
`contract_digest_mismatch` maps to proof-local `would_refuse`, while live
`refused` behavior remains absent. S3-R78-C4-A accepts the live-refusal boundary
design and keeps implementation held. S3-R79-C4-A accepts the internal
orchestrator strict-source/status design and keeps implementation held.
S3-R80-C4-A accepts the strict-refusal result-shape/non-persisting path design
and keeps implementation held. S3-R81-C3-A accepts the proof-local
strict-refusal result-shape experiment with 3 cases / 44 checks PASS and keeps
implementation held. S3-R82-C4-A accepts the live implementation scope review
and keeps implementation held. S3-R83-C1-A authorizes and S3-R83-C2-I lands the
bounded internal-only strict-refusal live implementation; S3-R83-C3-X pressure
passes, and S3-R84-C1-A accepts the slice as the live internal foundation. S3-R85
accepts canon sync and regression/canon map, and S3-R86 accepts Ch5/Ch7/language-spec
sync for that foundation.
Compiler/orchestrator integration, live compile refusal, public surfaces,
`CompilerResult`, persisted reports/sidecars, loader/report,
CompatibilityReport, runtime, Gate 3 widening, and production remain closed.
S3-R251-C1-A authorizes bounded proposal authoring for managed local recursion
and loop-class extensions. S3-R251-C2-I authors PROP-039 as proposal-only text.
PROP-039 does not authorize parser, TypeChecker, SemanticIR, runtime, API, CLI,
package, `igc run`, `.igapp`, `.igbin`, compiler passport, RuntimeSmoke, public
runtime, Reference Runtime, stable API, production, Spark, release, public demo,
public performance, official/reference status, alternative certification,
portability, or lab-canon authority.

| ID | Title | Depends On | Stage | Priority |
|----|-------|------------|-------|----------|
| PROP-033 | `via profile binding` | PROP-031 | 3 | high |
| PROP-034 | `output evidence syntax` | PROP-031, PROP-032 | 3 | high |
| PROP-035 | profile declarations / authority resolution | PROP-031, PROP-033 | 3 | medium |
| TBD | Effect Surface | PROP-031 | 3 | medium |
| TBD | Prior queued ideas need renumbering/requeue | — | 3+ | medium |

---

## Deferred Gaps Register

```
Stage 1 deferred gap:
  production_compiler_assembly  → RESOLVED in Stage 2 (PROP-027 + S2-R13 compiler package PASS)

Stage 2 deferred gaps (carried to Stage 3 — see current-status.md §Deferred Gaps):
  production_tbackend_adapter_binding  — Gate 3 closed; live Ledger reads not yet authorized
  olap_distributed_execution           — OLAP scatter/gather, rollup: not yet authorized
  invariant_persistence                — runtime violation observation persistence: open (S3 Runtime lane)
  deferred_invariant_oofs             — OOF-I1 (@bitemporal), OOF-I3 (~T), OOF-I5: deferred
  gem_release_readiness                — publish not yet attempted; release gate PASS (S3-R3-C4)
```

---

## Proposal Lifecycle

```text
draft -> authored-pending-review -> accepted / conditional-accepted
                                      |
                                      v
                              implemented-proof -> experiment-pass
                                      |
                                      v
                                  deferred
```

### Lifecycle Labels

Use these labels in the proposal index `Status` column. Track status is a separate
namespace: `Track: done` means the assigned card delivered its artifact; it does
not mean the proposal is accepted, implemented, or experiment-pass.

| Label | Meaning | Authority / evidence |
|-------|---------|----------------------|
| `draft` | Working text, scope packet, or proposal sketch exists, but no formal proposal file is indexed as the review target | Track evidence or discussion routing |
| `authored-pending-review` | Formal proposal file exists and is indexed; governance has not accepted or rejected it | Proposal file + track handoff |
| `accepted` | Governance accepted the proposal scope | Architect / Meta close decision; implementation may still require a separate card |
| `conditional-accepted` | Governance accepts direction with named blockers, exclusions, or required edits | Gate / decision record with explicit conditions |
| `implemented-proof` | Authorized implementation/proof landed for part or all of the proposal, but full experiment-pass or closure is still open | Track proof, golden, or matrix evidence |
| `experiment-pass` | Verification matrix for the accepted proposal scope passed; the proposal can be closed/frozen by the owning governance flow | PASS evidence + proposal/track reference |
| `deferred` | Proposal or sub-scope is intentionally postponed; not active implementation work | Stage close decision, gate, or explicit routing note |

Historical aliases:

- `proposal` in older docs means `authored-pending-review`.
- `implementation-partial` means `implemented-proof`.
- `closed` is a stage/archive map state; the proposal lifecycle label should name
  the evidence state (`accepted` or `experiment-pass`) instead.
- `patch` is a document type, not a lifecycle status.

Stage 1 PROPs: see `accepted/` — frozen read-only.
Stage 2 closed PROPs: in `proposals/` with lifecycle label `accepted`.
New Stage 3 proposal IDs must consult the queued table above. PROP-033 through
PROP-035 are reserved there; PROP-036 is accepted proposal-only for compiler
profile manifest identity; PROP-037 is accepted proposal-only for external
progression and service liveness semantics; PROP-038 is accepted proposal-only
for `compiler_profile_contract` with first proof-local experiment implementation
accepted/closed, bounded internal library validator extraction accepted/closed,
bounded report-only internal annotation accepted/closed, and hybrid
`contract_digest` policy design accepted; proof-local shape-policy proof accepted
and recompute-match proof accepted; report-only integration proof accepted with
PROP-038 errata/design text accepted; live validator implementation design
accepted; bounded live validator implementation accepted; compile-refusal
preconditions design accepted; strict-mode/refusal trigger design accepted;
strict-mode refusal trigger proof-local experiment accepted/closed;
live-refusal boundary design accepted with implementation held; internal
orchestrator strict-source/status design accepted with implementation held; and
strict-refusal result-shape/non-persisting path design accepted with
implementation held; proof-local strict-refusal result-shape experiment accepted
with implementation held; live implementation scope review accepted with
implementation held; bounded internal-only strict-refusal live implementation
authorized and landed; live internal foundation accepted; canon sync accepted;
and R86 Ch5/Ch7/language-spec sync accepted. Spark CRM is an active
applied-pressure source only, not PROP-038 authority.
PROP-039 is authored-pending-review for managed local recursion and loop-class
extensions. It remains proposal-only and grants no implementation, runtime,
public, reference, stable, release, certification, or portability authority.
