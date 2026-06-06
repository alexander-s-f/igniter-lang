# Igniter-Lang Agent Context

Status: active current-context capsule
Maintained by: `[Igniter-Lang Meta Expert]` in Status Curator mode
Last updated: 2026-05-12

---

## Purpose

This file is the trusted first context layer for new Igniter-Lang agents.

Use it to avoid reconstructing the whole project from old tracks, archives, or
stale spec copies. It is a compact map of the current horizon, source-of-truth
rules, active gates, and proof budget.

If your card asks for archaeology, bridge/package review, or spec-lag repair,
read the named older materials. Otherwise, start here and stay narrow.

---

## Read First

Every non-discussion slice should read, in order:

1. `AGENTS.md`
2. `.agents/org/roles/README.md`
3. assigned role profile in `.agents/org/roles/`
4. `.agents/agent-context.md`
5. `.agents/current-status.md`
6. `.agents/org/documentation-metabolism.md`
7. assigned track/proposal/source files
8. relevant spec chapters only when the card touches language semantics

Compiler/Grammar or language-entity cards that add parser nodes, fragment
classes, SemanticIR entities, OOF codes, or golden-backed language concepts
should also read:

```text
docs/concepts/canonical-semantic-model.md
```

The CSM maintenance rule is current as of S3-R29: if a compiler entity is added
or removed, update the CSM row; if the entity lacks a golden anchor, its status is
at most `spec_candidate`.

Governance, PROP authoring, language-lane planning, or cross-layer drift cards
should also read:

```text
.agents/docs/semantic-governance-heat-map.md
```

The Heat Map is current as of S3-R30 as a drift index, with two known stale-credit
rows noted by R30-X1: startup_time validator and V-3 golden landed after the map
was authored.

As of S3-R32-C2-S, the Heat Map stale-credit rows and OQ-Filter-1 authority row
are synced. The Covenant is normative for PROP acceptance; META-EXPERT-013 is
the operational checklist and defers to the Covenant.

Compiler architecture / compiler-pack / profile migration cards should also read:

```text
.agents/docs/compiler-profile-architecture-direction.md
```

That direction is post-POC only. Shadow compiler-pack proofs do not authorize
compiler dispatch, current compiler rewrites, `.igapp` manifest changes, or native
pack migration. The R31 `compiler_profile_id` boundary plan is proof-local only:
no assembler output, RuntimeMachine behavior, signed artifact format, or `.ilk`
metadata changed.

As of S3-R32 shadow work, the compiler profile chain has a closure index and
R32 backreference. Treat it as a dependency/regeneration map only; it does not
assign a PROP number or open migration.

Read `.agents/work/meta-proposals/` and `.agents/work/tracks/` selectively when the card asks for strategy,
documentation compaction, archaeology routing, applied pressure, or next-round
planning. It is a hoisted durable-idea map, not required context for every
implementation slice.

Discussion cards should also read:

```text
.agents/work/discussions/README.md
```

Bridge/package cards should read package docs only when the card names that
boundary.

---

## Current Patch Ledger

```text
R37 current status:
  P-50/P-52: closed by bounded PROP-032 Ch2/Heat Map sync and temporal audit
    specimen disposition; PROP-033 validation/runtime receipts remain closed
  P-51: restricted durable-audit deployment follow-ups closed proof-locally
    (30/30 cases, 5/5 invariants, 9/9 regression PASS); operational rollout
    requires P-53 Architect review
  PROP-037: accepted proposal-only; descriptor/proof follow-ups allowed, no
    parser/runtime/fragment-class/production execution authorization
  PROP-036: loader status + artifact-hash ordering proofs PASS, synthetic only;
    real .igapp/loader/assembler/golden/dispatch/runtime work remains blocked
  Stage 3 language regression: PASS 19/19 for existing surfaces
  Documentation cleanup: Stage 1/2 fate inventory, movement ledger, and first
    Line Ups landed; no movement/deletion authorization
```

```text
Historical R32 snapshot, kept for route archaeology only:
Production durable audit implementation authorization:
  status: bounded implementation partially landed proof-locally / deployment closed
  latest: S3-R31-C1-P closes schema, signer, append-only store, excluded-surface
    regression with 29/29 PASS and 5/5 invariants
  R32: hash/posture design amendment closes P-37/P-38 and unblocks B-A/B-B/B-C
  still closed: deployment, concrete HSM/KMS, production signing/key management,
    Ledger, Phase 2, BiHistory, stream/OLAP, production cache,
    broad RuntimeMachine binding, general write/replay/compact/subscribe
  still open before deployment review: B-A restart rebuild, B-B traversal/reader,
    B-C appender/reader role boundary, B-D full post-implementation matrix

R28 proof package:
  compliance_posture proof: PASS 14/14
  signer validation proof: PASS 18/18
  final post-R27/R28 matrix: PASS 29/29 with volatile_fields_lint first

R29 additions:
  startup_time override interface: design-only; R30 later adds proof validator
  PROP-031 §14 compatibility addendum: landed, doc-only
  Covenant Axiom 2 + P27/P28 + PROP Governance Filter: landed, doc-only
  Canonical Semantic Model: docs/concepts/canonical-semantic-model.md, living index

R30 additions:
  startup_time override validator: proof-local PASS 28/28; gate authority false
  V-3 observed+temporal golden: contract_modifiers_proof PASS 25/25
  Heat Map: .agents/docs/semantic-governance-heat-map.md, living drift index
  Covenant enforcement registry: 28 postulates classified; P28 partial
  PROP-032 assumptions: proposal/draft only; no parser/classifier/proof

R31 additions:
  OQ-Filter-1: closed; Covenant normative, META-EXPERT-013 operational
  startup override D1/D2/D3: design amended to match proof
  PROP-032: Phase 1 gate satisfied
  compiler-pack shadow: post-POC direction/proofs only; no dispatch or .igapp change
  compiler_profile_id: proof-local boundary plan PASS; manifest PROP required

R32 additions:
  audit hash/posture amendment: P-37/P-38 closed; mismatch code specified
  governance authority sync: P-39/P-40 closed
  PROP-032: Phase 1 Classifier landed; TypeChecker/SemanticIR/full proof open
  compiler profile shadow chain: closure index/backreference answers dependency-map ask

Historical R33 route, superseded by later rounds:
  B-A restart rebuild proof with mismatch refusal, PROP-032 Phase 2 TypeChecker,
  compiler_profile_id PROP number decision, then B-B/B-C/B-D.
```

---

## Do Not Reread By Default

Do not reread these unless the card explicitly asks:

- `docs/archive/`
- old completed tracks not named by the card
- package docs outside the assigned bridge/package boundary
- pre-crystallization archaeology
- broad proposal history unrelated to the slice
- full proof suites not named by the card

Completed track docs are evidence, not required context for every slice.

---

## Current Horizon

```text
Source .ig
  -> Parser -> Classifier -> TypeChecker
  -> SemanticIREmitter.emit_typed(typed)        ✅ production path
  -> SemanticIR temporal/core/stream nodes      ✅ proven
  -> Assembler .igapp
       manifest.fragment_summary               ✅ emitted
       manifest.contract_index                 ✅ emitted
       requirements from escape_boundaries      ✅ emitted
       compatibility_metadata guard_policy      ✅ emitted
  -> RuntimeMachine
       load TEMPORAL for inspection             ✅ proof-local + report shape
       CompatibilityReport load/eval split      ✅ report-only
       package descriptor backend_check         ✅ report-only
       full post-switch smoke                   ✅ all six emit_typed surfaces
       executor/live-binding report profiles    ✅ modeled; still blocked
       ExecutorApprovalToken proposal           ✅ prerequisite only
       ExecutorApprovalToken report matrix      ✅ report-only
       executor cache-key boundary              ✅ TEMPORAL key or L-T5 refusal
       C2 guarded-runtime consistency           ✅ mapped refusal
       guarded approval enforcement             ✅ proof-local refusal
       Gate 3 Phase 1 decision                  ✅ approved-restricted implementation
       CompatibilityReport composition          ✅ proof-local composed shape
       temporal_read_observation envelope       ✅ proof-local minimum envelope
       temporal_scope_exclusion reason          ✅ PROP-030A
       Phase1TemporalExecutor preflight         ✅ proof-local 9/9; experiments-local only
       report enforcement preflight             ✅ proof-local matrix; ordering amendment needed
       temporal scope exclusion fixture         ✅ excluded surfaces refuse before live paths
       Ch7 Gate 3 approval sync                 ✅ approved-restricted semantics synced
       report preflight ordering                ✅ token-before-gate fixed
       AT-2 composed report integration         ✅ closed
       AT-9 authority_ref exact match           ✅ proof-local PASS
       pre-live regression chain                ✅ 17/17 PASS
       runtime temporal executor lib-prep       ✅ lib/ Phase1 PASS 17/17
       post-C1 lib-prep regression rerun        ✅ 14/14 PASS
       lib boundary spec sync                   ✅ Ch7 proof-local boundary sync
       lib-prep safety pressure                 ✅ PROCEED for proof-local Phase 1
       R18 live-read addendum draft             ⚠️ superseded by R20 signed status
       proof-local docstring warnings           ✅ authority/observation/honor-system comments
       scope-exclusion reason aliases           ✅ canonical runtime.temporal_scope_exclusion
       backend identity guard                   ✅ blocks unmarked/Ledger/proxy backends before live paths
       R18 cleanup regression rerun             ✅ 15/15 PASS
       addendum pre-signature pressure          ✅ PROCEED to Architect signature review
       signed live-read addendum                ✅ signed-approved-restricted-phase1-live-read
       first post-signature fixture             ✅ PASS 10/10; policy-only change
       post-signature runtime pressure          ✅ PROCEED; no widened surface
       evaluate TEMPORAL Phase 1 live           ✅ authorized only inside signed addendum scope:
                                                   History[T] valid_time, explicit as_of,
                                                   MemoryBackend or explicit non-Ledger Phase 1 backend
       audit-ready envelope                     ✅ explicit export, not persisted
       proof-local authority registry shape     ✅ caller policy metadata, no signing/keys
       audit/registry pressure                  ✅ PROCEED; production checklist routed
       Phase 1 end-to-end invocation            ✅ proof-local PASS 9/9
       content-addressed addendum reference     ✅ proof-local PASS 9/9
       e2e/content-address pressure             ✅ PROCEED; P-4/P-5 closed, P-8 routed
       memoize TEMPORAL                         🚫 proof-local only
  -> Ledger / TBackend
       descriptor metadata                      ✅ Gate 2 ratified
       descriptor report mapping                ✅ report-only
       Gate 2 ratification record               ✅ ratified
       Phase 1 abstract non-Ledger adapter      ✅ implementation authorized
       bounded audit schema/signer/store proof   ✅ R31 proof-local 29/29; no deployment
       hash/posture design amendment             ✅ R32 closes P-37/P-38
       restart rebuild/traversal/reader proofs   🚫 B-A/B-B/B-C/B-D still required
       Ledger adapter / package binding         🚫 Phase 2 addendum required
       live Ledger operations                   🚫 closed
  -> Stream replay
       assembled stream_nodes metadata          ✅ emitted
       production stream executor               🚫 not authorized
  -> Invariant metadata
       source_metadata/source_span              ✅ preserved
       runtime persistence                      🚫 still open
  -> Release
       alpha package publish evidence           ✅ PASS
       release-gate automation                  🚫 deferred in split-era repo
```

Current production compiler path:

```text
Parser -> Classifier -> TypeChecker -> SemanticIREmitter.emit_typed -> Assembler
```

`SemanticIREmitter#emit(parsed, sample_input:)` remains as Stage 1
legacy/internal comparison, not the production path.

---

## Active Gates

| Gate | State | Rule |
|------|-------|------|
| Stage 1 | CLOSED | Preserve regression proof unless card says otherwise. |
| Stage 2 | CLOSED WITH DEFERRED GAPS | Do not reopen closed Stage 2 surfaces casually. |
| Stage 3 | OPEN | Work within current lane/card. |
| Typed emission | SWITCHED | Production orchestrator uses `emit_typed(typed)`. |
| TEMPORAL load | PROOF-LOCAL | Load accepts valid TEMPORAL `.igapp/` for inspection. |
| TEMPORAL evaluate | SIGNED-RESTRICTED PHASE 1 | R20 signed the live-read addendum and C2 fixture PASS 10/10 proves policy-only change. `gate3_authorized: true` may be caller-passed only with signed-addendum invocation evidence and only for History[T] valid_time, explicit as_of, MemoryBackend or explicitly named non-Ledger Phase 1 backend. |
| Phase 1 audit envelope | PROOF-LOCAL / NOT PERSISTED | R21 C1 defines explicit `audit_ready_not_persisted` envelope over observation/report/authority/addendum/backend/result; no automatic persistence, durable audit, production storage, Ledger write, or authority registry. |
| Phase 1 authority registry | PROOF-LOCAL SHAPE | R21 C2 defines caller-side registry metadata checked before `gate3_authorized: true`; active/revoked/superseded/missing/scope/capability/malformed cases PASS; no executor calls, signing, keys, or production authority service. |
| Phase 1 end-to-end invocation | PROOF-LOCAL PASS | R22 C1 composes registry check -> caller authorization -> Phase1 executor -> explicit audit-ready envelope. Revoked registry and missing signed addendum block before executor; Ledger-like backend blocks before read. |
| Signed addendum content ref | PROOF-LOCAL PASS | R22 C2 requires human path plus content_sha256, git_commit, signed status/date, and authority_ref. Path-only evidence is insufficient; `workspace-current` git_commit remains pre-production placeholder only. |
| Runtime cache | PROOF-LOCAL | Cache key/memoization proofs exist; no production cache. |
| TBackend Gate 1 | PASS | Report-only descriptor consumption fixture. |
| TBackend Gate 2 | RATIFIED | Metadata-only package descriptor exposure and report-only descriptor mapping are trusted report metadata; no runtime authority. |
| Gate 3 prerequisite package | LANDED | Gate 2 ratified, PROP-030 drafted, token report proof, guarded enforcement, executor cache-key proof, and package descriptor report consumption landed; this is not Gate 3 authorization. |
| Gate 3 Phase 1 | SIGNED-APPROVED-RESTRICTED LIVE READ | R20 closes the signature blocker for the restricted Phase 1 addendum only. Executor does not self-authorize; caller policy/evidence owns `gate3_authorized: true`. Phase 2 stays closed. |
| Production durable audit | BOUNDED PROOF-LOCAL PARTIAL | R30 authorizes bounded implementation; R31 C1-P proves schema/signer/store/excluded-surface regression only. Deployment, HSM/KMS, production signing/key management, Ledger, Phase 2, and broad runtime binding remain closed. |
| PROP-032 assumptions | PHASE 1 CLASSIFIER LANDED / NOT EXPERIMENT-PASS | R32 C3-P lands Classifier-only `assumption_registry`, `uses_assumptions`, `assumption_refs`, `epistemic`, and OOF-A1. No parser grammar, TypeChecker, SemanticIR, evidence-list validation, runtime behavior, or proposal promotion. |
| Compiler pack architecture | SHADOW / POST-POC ONLY | R31/R32 shadow proofs describe Profile-Baseline-Pack, pack boundaries, registries, ordered rules, `compiler_profile_id`, and the closure index. They do not route current compiler execution through packs or change `.igapp`/`.ilk`. |
| TBackend Gate 3 Phase 2 | CLOSED | Real Ledger adapter/package binding, BiHistory, stream/OLAP, writes/replay/compact/subscribe, and production cache need separate Architect approval/addendum as specified. |
| Release publish | CLOSED | Existing alpha publish evidence is accepted; release-gate automation is deferred in the split-era repo and future RubyGems publish needs explicit approval and MFA owner action. |
| Syntax pressure | PRESSURE ONLY | Review routes proposal candidates; S3-R14 C7-C10 added truth-system, HTTP/knowledge/legal, emergency mesh, and marketplace pressure; no syntax is canon without proposal/proof. |

---

## Source-Of-Truth Hierarchy

Use this hierarchy for routine reads:

```text
agent-context.md
  -> current-status.md
  -> accepted spec / accepted proposals
  -> latest landed track evidence
  -> code + proof artifacts
  -> old tracks / archives
```

For conflicts, apply the conflict rule below.

---

## Conflict Rule

When documents disagree, do not average them. Resolve by question type:

| Conflict | Prefer | Reason |
|----------|--------|--------|
| `agent-context.md` vs `current-status.md` | `current-status.md` for detailed scoreboard; update `agent-context.md` later in Status Curator mode | Context is compact; status is fuller. |
| `current-status.md` vs latest landed track | latest landed track for exact evidence; update `current-status.md` if assigned status curation | Tracks are landing evidence. |
| spec vs current-status/latest track | spec for canon; latest track/status for implemented or proven-but-not-yet-spec-synced state | Spec lag is allowed but must be named. |
| spec vs code/proof | code/proof for observed implementation; Compiler/Grammar Expert owns spec-lag repair | Running evidence beats stale text, but not canon. |
| latest track vs code/proof | code/proof if directly verified; otherwise track | Proof artifacts are the executable truth. |
| discussion vs anything | discussion never wins by itself | Discussions route pressure; they do not authorize implementation. |

If a conflict affects behavior, record it under `[R]` or `[Q]` and route it to
the owner instead of silently fixing unrelated documents.

---

## Ownership Reminders

| Role | Current ownership |
|------|-------------------|
| Research Agent | executable proofs, fixtures, proof-local runtime/cache work; not round-close status by default |
| Compiler/Grammar Expert | formal semantics, grammar, type system, accepted proposals, spec-lag stewardship |
| Bridge Agent | bridge/package mapping and approval gates; no package/runtime production binding without approval |
| Meta Expert | Status Curator mode for round-close maps, current-status, tracks index, lifecycle/debt routing |
| Archive/Form Expert | archaeology, pressure fixtures, registry/review routing; no canon promotion by fixture |
| History Curator | compact history reports, archive compression, duplicate-removal recommendations, value preservation |
| External Pressure Reviewer | critique and pressure routing; may use borrowed `runtime-pressure` lens only when assigned |

---

## Proof/Test Budget Protocol

Default to the smallest proof that can validate the slice.

| Slice type | Default verification |
|------------|----------------------|
| Status/map/doc curation | `git diff --check`, link/path existence checks, no proof suite unless requested |
| Track/proposal docs only | `git diff --check`; validate named links/files when practical |
| Parser/classifier/typechecker/compiler code | targeted proof for touched surface + closest golden check |
| Orchestrator/compiler path | production compiler CLI proof + Stage 1/Stage 2 close candidates when path-wide behavior changes |
| Assembler/.igapp artifact shape | `igapp_assembler_proof` or the named temporal assembler proof + relevant regression |
| Runtime/cache proof-local work | named proof fixture + syntax check; do not run production suites unless path-wide |
| Release work | Split-era release automation is deferred; publish remains closed unless separately authorized |
| Package bridge work | targeted package spec named by the card; avoid full package suite unless needed |

Escalate proof scope when:

- production compiler path changes;
- manifest or `.igapp/` load contract changes;
- Stage 1/Stage 2 close candidate evidence may be affected;
- a card explicitly asks for broader verification;
- a targeted proof fails and the failure may be systemic.

Do not run broad expensive suites just to curate maps.

---

## Current Next Movement

Recommended next routing from the latest status map:

1. `phase1-post-r22-regression-rerun-v0` to consolidate R20-R22 fixtures into the current matrix
2. `durable-observation-persistence-v0` for production durable audit/storage; keep separate from proof-local envelopes
3. `gate3-authority-registry-v1` for durable registry/revocation/status transitions, including content-addressed decision refs
4. production compliance amendment: reject `git_commit: workspace-current` outside proof-local mode
5. `gate3-production-signing-v1` only after registry ordering is defined; signing/key management remains closed
6. preserve signed scope: Phase 1 History[T] valid_time only; no Ledger/BiHistory/stream/OLAP/cache/audit widening
7. `gate3-phase2-addendum-process-v0` before any real Ledger adapter/package binding
8. `invariant-persistence-boundary-v0`
9. `spec-ch6-invariant-source-metadata-sync-v0`
10. `external-http-json-capability-pressure-v0` as pressure backlog, not parser/runtime implementation
11. `controlled-agent-replication-boundary-pressure-v0` as pressure backlog before any emergency mesh fixture
