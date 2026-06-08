# META-EXPERT-011: Stage 3 Governance Opening v0

Card: S3-R1-C1-S
Agent: [Igniter-Lang Meta Expert]
Role: meta-expert
Track: stage3-governance-opening-v0
Date: 2026-05-08
Status: **active**

Supersedes: nothing (new stage)
Prerequisite: META-EXPERT-009.1 (Stage 2 closed 2026-05-07)
Policy source: `docs/operating-model.md`, `roles/README.md`

---

## I. Purpose

Open Stage 3 formally. Define what is in scope, what requires Architect
approval, what stays as review pressure, and how external signals enter
the formal work queue.

Stage 3 is not a single deliverable — it is the production and adoption
phase. It operates in lanes, not a single linear roadmap.

---

## II. Stage 3 Open

> **STAGE 3: OPEN** (2026-05-08) — META-EXPERT-011

Stage 3 opens with all Stage 2 deferred gaps as explicit intake.
No Architect approval is required to *work on* deferred gaps — they were
pre-approved by being recorded in the Stage 2 close decision.
Architect approval is required for: new PROP-028+ language semantics,
gem release to RubyGems.org, and production Ledger/TBackend binding.

---

## III. Inherited Starting State

```text
From Stage 2 close (META-EXPERT-009.1):

  ✅ IgniterLang.compile Ruby facade (11 modules + version + CLI)
  ✅ VERSION = "0.1.0.pre.stage2"
  ✅ Compiler pipeline: Parser → Classifier → TypeChecker → SemanticIREmitter → Assembler
  ✅ emit_typed exists (semanticir_emitter.rb:26) — not yet wired in orchestrator
  ✅ RuntimeMachineHook proof (history_read + bihistory_read)
  ✅ Ledger descriptor: metadata-only, descriptor-first, 9 package specs PASS
  ✅ Runtime violation observations: proof-backed
  ✅ stage1_close_candidate PASS | stage2_close_candidate PASS
```

---

## IV. Stage 3 Deferred Gaps — Intake Lanes

These five gaps were formally transferred from Stage 2. They are the
primary Stage 3 intake. Each maps to a lane with an owner role.

```text
Gap                              Lane          Owner role
──────────────────────────────────────────────────────────────────
gem_release_readiness            Release       Research Agent
production_tbackend_adapter      TBackend      Bridge Agent
invariant_persistence            Runtime       Research Agent
deferred_invariant_oofs          Language      Compiler/Grammar Expert
olap_distributed_execution       Language      Compiler/Grammar Expert
```

### Lane: Release

`gem_release_readiness` — gemspec/bin proven locally (R13). Remaining:
- Final gem metadata (homepage, license, description, authors)
- CI configuration (run specs + rubocop on push)
- RubyGems publish policy decision (Architect approval required)
- `rake release` gate: build → install locally → publish

First track: `gem-release-policy-v0` [Research Agent]

### Lane: TBackend

`production_tbackend_adapter_binding` — descriptor-first conformance done (R11/R12).
Package-side descriptor implementation done (R14). Remaining:
- `CompatibilityReport` consumption of descriptor evidence
- Proof-local AdapterRegistry fixture with real read path
- Production Ledger/Durable Model read binding (Architect approval required)

First track: `compatibility-report-descriptor-consumption-v0` [Bridge Agent]

### Lane: Runtime

`invariant_persistence` — runtime violation observations proof-backed (R12).
Remaining:
- Production RuntimeMachine emission boundary
- Persistence store decision (where violation observations go in production)

First track: `invariant-persistence-boundary-v0` [Research Agent]

### Lane: Language (deferred OOFs)

`deferred_invariant_oofs` — OOF-I1 (`@bitemporal`), OOF-I3 (`~T`), OOF-I5
(requirements DB). These require Compiler/Grammar Expert formal proposal.
Cannot start without PROP-028 TEMPORAL fragment class as prerequisite.

First track: after PROP-028 lands.

### Lane: Language (OLAP distributed)

`olap_distributed_execution` — OLAP scatter/gather, rollup, multi-cluster.
Low priority. No first track yet — start only after TBackend lane progresses.

---

## V. Stage 3 New Work Lanes

Beyond deferred gaps, Stage 3 opens three new lanes based on accumulated
pressure from Stage 2 external review and META-EXPERT-008.2.

### Lane: Compiler Internals

These are internal compiler improvements that do not change language semantics.
No PROP required. Research Agent can start immediately.

```text
Priority | Work                              | Track candidate
─────────────────────────────────────────────────────────────────────
HIGH     | emit_typed in orchestrator        | orchestrator-emit-typed-v0
HIGH     | sample_input removed from         | classifier-type-inference-v0
         | Classifier                        |
MEDIUM   | gem-native package boundary specs | gem-native-specs-v0
         | (require/compile/igc outside      |
         | proof harness)                    |
LOW      | Rust rb_range_by_valid_time       | (after TBackend lane)
LOW      | Rust rb_at_bi                     | (after TBackend lane)
```

**Note on emit_typed:** switching orchestrator from `emit(parsed, ...)` to
`emit_typed(typed_program)` is the highest-leverage small change. TypedProgram
is currently computed and discarded. This change is internal only — no grammar,
no PROP.

### Lane: Language Formalization (PROP-028+)

New language semantics require a PROP-028+ number and Compiler/Grammar Expert
authorship. Meta Expert identifies the gap; C/G Expert writes the formal PROP.

**PROP-028 is authorized** — TEMPORAL fragment class. Requirements defined in
`external-review-response-2026-05-07.md`. Assign to Compiler/Grammar Expert.

```text
PROP    | Title                          | Status     | Author role
─────────────────────────────────────────────────────────────────────────
PROP-028 | TEMPORAL fragment class       | authorized | Compiler/Grammar Expert
          | (7 requirements in review doc)|            |
PROP-029 | entrypoint / section syntax   | review     | Compiler/Grammar Expert
          | (requires spec-entrypoint-    |            | after spec sync
          | sync-v0 first)               |            |
PROP-030 | ExecutionIR contract (SSA)    | idea       | Compiler/Grammar Expert
          |                              |            | after emit_typed lands
PROP-031 | entity / lifecycle identity   | idea       | Compiler/Grammar Expert
          | (entity = History[T] sugar?) |            | after PROP-028
PROP-028+ | OOF-I1/I3/I5 (deferred      | blocked    | Compiler/Grammar Expert
           | invariant OOFs)              |            | after PROP-028
```

**PROP status definitions:**
- `authorized` — can start now
- `review` — needs a prerequisite slice first
- `idea` — promising but not ready for formal proposal
- `blocked` — waiting for another PROP

### Lane: External Pressure

External agents and domain experts can bring pressure in the form of:
- Syntax critiques (like the review in `external-review-response-2026-05-07.md`)
- Architecture analysis (Ledger Rust gap analysis)
- Performance assessments

**Accepted process:**

```text
External signal
    → Meta Expert writes meta-response
    → Requirements extracted (numbered list)
    → If language semantics: Compiler/Grammar Expert writes PROP
    → If compiler internal: Research Agent writes track
    → If platform: Bridge Agent writes bridge note
```

Review pressure **does not** directly create PROP numbers or authorize
implementation. It populates the requirements queue that C/G Expert formalizes.

**Active requirements from external review (2026-05-07):**
- PROP-028: 7 requirements (TEMPORAL fragment class + cache key semantics)
- PROP-029 prerequisite: spec-entrypoint-sync-v0 (stale spec lines to clean)
- PROP-031 prerequisite: formalize entity vs History[T] semantic boundary

---

## VI. Authorization Matrix

```text
Work type                              Authorized?   Gate
──────────────────────────────────────────────────────────────────────────
Stage 2 deferred gap work              YES           This document
emit_typed in orchestrator             YES           This document
Compiler internal improvements         YES           This document
PROP-028 (TEMPORAL fragment)           YES           This document
spec-entrypoint-sync-v0               YES           This document
gem metadata + CI                      YES           This document
gem-native boundary specs              YES           This document

PROP-029+ (new language surfaces)      REVIEW        Needs prerequisite slice
                                                     + C/G Expert authorship
Gem release to RubyGems.org            REQUIRES      Architect explicit approval
Production Ledger read/write binding   REQUIRES      Architect explicit approval
OLAP distributed execution             REQUIRES      After TBackend lane + PROP
MCP/mesh integration                   REQUIRES      Architect explicit approval
```

---

## VII. Stage 3 Scoreboard (opening state)

```text
Surface                              Status        Lane         PROP
──────────────────────────────────────────────────────────────────────
Stage 2 close evidence               ✅ CLOSED     —            —
gem metadata + CI                    ⏳ open       Release      —
gem publish policy                   ⏳ gated      Release      Architect
emit_typed in orchestrator           ⏳ open       Compiler     —
sample_input removed from Classifier ⏳ open       Compiler     —
gem-native boundary specs            ⏳ open       Compiler     —
PROP-028 TEMPORAL fragment class     ⏳ authorized  Language     PROP-028
spec-entrypoint-sync-v0             ⏳ open       Language     prereq
PROP-029 entrypoint/section syntax   ⏳ review     Language     PROP-029
PROP-030 ExecutionIR SSA             ⏳ idea       Compiler     PROP-030
PROP-031 entity / lifecycle identity ⏳ idea       Language     PROP-031
TBackend descriptor consumption      ⏳ open       TBackend     —
Invariant persistence boundary       ⏳ open       Runtime      —
OOF-I1/I3/I5 (deferred)             ⏳ blocked    Language     after PROP-028
OLAP distributed execution           ⏳ low-pri    Language     after TBackend
Rust rb_range_by_valid_time          ⏳ low-pri    TBackend     after lane
Rust rb_at_bi                        ⏳ low-pri    TBackend     after lane
──────────────────────────────────────────────────────────────────────
STAGE 3 CLOSED:  NO
```

---

## VIII. Stage 3 Close Criteria (draft)

Stage 3 closes when:

1. Gem released to RubyGems.org (Architect approval required)
2. Production TBackend binding proven with real Ledger read path
3. PROP-028 TEMPORAL fragment class implemented and proven
4. Invariant persistence boundary defined and proven
5. `emit_typed` path active in orchestrator
6. Stage 3 close candidate PASS (equivalent of stage2_close_candidate)

Deferred-to-Stage-4 candidates:
- OLAP distributed execution
- MCP/mesh integration
- OOF-I1/I3/I5 (unless landed in Stage 3)
- `igniter-frontend` Arbre/Tailwind

---

## IX. First Stage 3 Cards

```text
Round 1 (authorized now):

S3-R1-C1-S: stage3-governance-opening-v0      [Meta Expert]       ← this doc
S3-R1-C2-P: orchestrator-emit-typed-v0        [Research Agent]
S3-R1-C3-P: prop-028-temporal-fragment-v0     [Compiler/Grammar Expert]
S3-R1-C4-P: spec-entrypoint-sync-v0           [Compiler/Grammar Expert]
S3-R1-C5-P: gem-release-policy-v0             [Research Agent]
```

---

## Handoff

```text
Card: S3-R1-C1-S
Agent: [Igniter-Lang Meta Expert]
Role: meta-expert
Track: stage3-governance-opening-v0
Status: done

[D] Decisions
- STAGE 3: OPEN (2026-05-08). Governed by this document.
- 5 deferred gaps from Stage 2 are authorized intake — no new approval needed.
- PROP-028 (TEMPORAL fragment class) is authorized. Requirements in external-review-response.
- emit_typed in orchestrator is authorized immediately — internal change, no PROP.
- External review pressure enters via: signal → meta-response → requirements → PROP/track.
- Gem release to RubyGems.org and production Ledger binding require Architect approval.
- Stage 3 operates in 5 lanes: Release, TBackend, Runtime, Language, Compiler Internals.

[S] Shipped
- META-EXPERT-011-stage3-governance-opening-v0.md (this document)
- Updated current-status.md: Stage 3 OPEN
- Updated meta-proposals/README.md

[T] No proofs — governance document only.
    Proofs happen in Round 1 C2/C3/C4/C5.

[R] Risks
- emit_typed switch: must run stage2_close_candidate after change to confirm no regression.
- PROP-028 must be written before OOF-I1/I3/I5 start — they depend on TEMPORAL class.
- spec-entrypoint-sync-v0 must land before PROP-029 starts — avoids keyword collision.

[Next] Round 1 cards (all authorized):
  S3-R1-C2-P: orchestrator-emit-typed-v0        [Research Agent]
  S3-R1-C3-P: prop-028-temporal-fragment-v0     [Compiler/Grammar Expert]
  S3-R1-C4-P: spec-entrypoint-sync-v0           [Compiler/Grammar Expert]
  S3-R1-C5-P: gem-release-policy-v0             [Research Agent]
```
