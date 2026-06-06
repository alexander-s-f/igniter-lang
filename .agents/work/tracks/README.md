# Igniter-Lang Tracks

Status: active index
Owner: `[Architect Supervisor / Codex]`
Last updated: 2026-05-24

---

## Purpose

Track documents are slice evidence, not the global project log.

New agents should start from `../../../docs/README.md`,
`../../org/documentation-metabolism.md`, `../../agent-context.md`,
`../../current-status.md`, and the assigned track only.

---

## Current Navigation

| Need | Start here |
|------|------------|
| Trusted current context | `../../agent-context.md` |
| Current language state | `../../current-status.md` |
| Process / handoff rules | `../../org/documentation-metabolism.md` |
| Canonical spec | `../../../docs/spec/` |
| Proposal queue | `../proposals/README.md` |
| Historical archaeology | `.agents/docs/`, `.agents/work/archive/`, or git history |

---

## Background Compiler Profile Foundation

These tracks are proof-local foundation work for future Profile/Pack compiler
architecture. They are not production migration authorization.

| Track | Status | Notes |
|-------|--------|-------|
| `compiler-profile-chain-closure-index-v0.md` | done | Closure index PASS 28/28 from shadow profile through ProgressionPack shadow boundary and R32 M-3 backreference; guard only, no dispatch/.igapp/.ilk/runtime authority change |
| `compiler-profile-shadow-chain-dependency-index-v0.md` | done | R33 curation index: direct summary dependencies, regeneration order, shadow/pre-POC boundary, and archive candidates; no migration authorization |
| `compiler-profile-r32-shadow-chain-backreference-v0.md` | done | Backreferences R32 pressure item M-3 to the closure index; marks shadow dependency-map ask addressed without closing manifest PROP numbering or durable audit items |
| `compiler-profile-manifest-prop-draft-v0.md` | done | PROP-ready draft candidate for top-level `compiler_profile_id`; legacy_optional/profile_required policies; hash/signature ordering; no official PROP number claimed |
| `profile-source-syntax-pressure-v0.md` | done | Compiler/Grammar-facing syntax pressure; descriptor-data style preferred before parser work; block-style syntax pressure-only |
| `compiler-profile-manifest-prop-review-ready-v0.md` | done | Architect-review-ready packet; locks authority firewall, receipt/profile lane split, required exactly-one slots, slot-order dispatch invariant, and bootstrap traceability |
| `compiler-profile-manifest-prop-promotion-v0.md` | done | Promotion packet ready for Architect numbering/routing; detects PROP-033 queue occupation; creates no proposal file and mutates no proposal index |
| `compiler-profile-prop-numbering-decision-v0.md` | done | Architect-owned numbering decision request; observes PROP-033 occupied and PROP-036 as next candidate if queue unchanged; does not assign a number |
| `compiler-profile-descriptor-error-taxonomy-sharpening-v0.md` | done | Descriptor diagnostic precedence: shape -> slot assignment -> pack semantics -> registry ordering; helper-only does not override slot errors |
| `profile-source-syntax-compiler-review-v0.md` | done | Research baseline for Compiler/Grammar review; descriptor-first accepted for research, block syntax pressure-only, parser work unauthorized |
| `profile-source-syntax-grammar-boundary-v0.md` | done | Compiler/Grammar-owned decision boundary; Research recommends accept_baseline_only but accepts no grammar and opens no parser work |
| `compiler-profile-validator-implementation-plan-v0.md` | done | No-code validator plan: descriptor shape -> slots -> pack semantics -> registry ordering -> canonicalize/fingerprint; no lib file created |
| `compiler-profile-manifest-prop-architect-routing-v0.md` | done | Architect routing packet for `compiler_profile_id` manifest PROP; no PROP number assigned, no proposal queue mutation, implementation cards stay blocked |
| `progression-pack-shadow-boundary-v0.md` | done | Maps external progression runtime model to proposed `ProgressionPack`; sibling to Stream/Temporal/Pipeline, no syntax/SemanticIR/runtime auth |

---

## Stage 3 Round 93 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `oof-fragment-registry-ownership-and-canon-semantics-design-v0.md` | done | Design-only R93 packet: OOFRegistry as kernel service data populated by pack-owned descriptors; FragmentRegistry as kernel service data populated by fragment-owner packs; `oof` status-primary with secondary projection; recommends pressure-only `oof-fragment-registry-design-pressure-v0` next |
| `../discussions/oof-fragment-registry-design-pressure-v0.md` | proceed | R94 pressure PASS 7/7; recommends proof-only policy proof and preserves implementation/spec/canon/compiler/runtime closures |
| `oof-fragment-registry-policy-proof-v0.md` | done / PASS | R95 proof-only policy model PASS 16/16 cases and 7/7 checks; covers alias/collision, OOF projection guard, guarded non-fragments, and profile-contract namespace exclusion; implementation held |
| `../gates/oof-fragment-registry-policy-proof-acceptance-decision-v0.md` | accepted-pinv-tinv-lifecycle-design-next-implementation-held | R96 accepts R95 as proof-only policy evidence and opens only design-only `pinv-tinv-lifecycle-and-registry-classification-design-v0`; implementation-boundary design remains held |
| `pinv-tinv-lifecycle-and-registry-classification-design-v0.md` | done | R97 classifies PINV/TINV as non-public invariant support metadata, not OOF descriptors or aliases; public OOF authority remains with `OOF-IV*` / `OOF-I*` |
| `../gates/pinv-tinv-lifecycle-classification-acceptance-decision-v0.md` | accepted-implementation-boundary-design-next-implementation-held | R98 accepts R97 and opens only design-only `oof-fragment-registry-implementation-boundary-design-v0`; implementation/spec/canon/compiler/runtime surfaces remain closed |
| `oof-fragment-registry-implementation-boundary-design-v0.md` | done | R99 designs isolated internal validator plus proof-local parity harness boundary; implementation held pending pressure and authorization review |
| `../discussions/oof-fragment-registry-implementation-boundary-pressure-v0.md` | proceed | R100 pressure PASS; write scope isolated, parity plan comprehensive, but 9 blockers routed to R101 closure |
| `oof-fragment-registry-authorization-blocker-closure-design-v0.md` | done | R101 closes/routes R100 blockers; pins first-slice write scope, excludes `oof_fragment_registry_data.rb`, includes support markers, defines inactive-row proof and 8-command matrix |
| `../gates/oof-fragment-registry-implementation-authorization-review-v0.md` | authorized-bounded-internal-validator-proof-slice | R102 authorizes only `lib/igniter_lang/oof_fragment_registry.rb`, `experiments/oof_fragment_registry_implementation_boundary_proof/**`, and proof track; compiler integration/public/runtime/Spark surfaces remain closed |
| `oof-fragment-registry-implementation-boundary-proof-v0.md` | done / PASS | R103 lands isolated internal validator and proof-local harness inside R102 scope; 27/27 proof checks PASS and pinned 8-command matrix PASS; `oof_fragment_registry_data.rb` absent |
| `../gates/oof-fragment-registry-implementation-acceptance-decision-v0.md` | accepted-closure-static-internal-data-design-next | R104 accepts R103 closure and opens only design-only `oof-fragment-registry-static-internal-data-design-v0`; compiler integration and static data implementation remain closed |
| `oof-fragment-registry-static-internal-data-design-v0.md` | done | R105 rejects `oof_fragment_registry_data.rb` and static proof-derived registry constants for now; recommends supplied source boundary before any non-proof registry data |
| `oof-fragment-registry-loader-supplied-data-source-design-v0.md` | done | R106 designs staged non-canon source envelope; keeps loader/report/profile/pack paths future-only and recommends proof-local supplied-data source evidence |
| `oof-fragment-registry-supplied-data-source-proof-v0.md` | done / PASS | R107 proves proof-local supplied-data source envelope checks: 7/7 cases and 9/9 checks PASS; nested registry validation remains in `IgniterLang::OOFFragmentRegistry`; implementation held |
| `../gates/oof-fragment-registry-source-envelope-validation-placement-decision-v0.md` | accepted-proof-local-evidence-helper-boundary-design-next-implementation-held | R108 accepts R107 proof evidence, keeps current source-envelope validation proof-local, and opens only design-only internal helper boundary; loader/report/public/compiler/spec/runtime/data-file surfaces remain closed |
| `oof-fragment-registry-source-envelope-helper-boundary-design-v0.md` | done | R109 recommends bounded internal helper placement inside `oof_fragment_registry.rb`; accepted modes are only `proof_fixture` and `caller_supplied`; separate helper/data files and public/compiler/runtime surfaces remain closed |
| `../gates/oof-fragment-registry-source-envelope-helper-implementation-authorization-review-v0.md` | authorized-bounded-internal-source-envelope-helper-proof-slice | R110 authorizes only the internal helper/proof slice in `oof_fragment_registry.rb`, proof experiment folder, and proof track; loader/report/public/compiler/spec/runtime/data-file/Spark surfaces remain closed |
| `oof-fragment-registry-source-envelope-helper-proof-v0.md` | done / PASS | R111 lands `validate_source_envelope` inside `OOFFragmentRegistry`; helper proof 9/9 cases and 10/10 checks PASS; pinned matrix PASS with R107 UTF-8 locale note |
| `../gates/oof-fragment-registry-source-envelope-helper-acceptance-decision-v0.md` | accepted-helper-closure-utf8-proof-hygiene-next | R112 accepts R111 closure and opens only `oof-fragment-registry-utf8-proof-hygiene-cleanup-v0`; compiler integration, profile/pack promotion, loader/report/public/spec/runtime/data-file surfaces remain closed |
| `oof-fragment-registry-profile-pack-source-mode-proof-v0.md` | done / PASS | R115 proves proof-only `profile_candidate` / `pack_descriptor_candidate` modeling: 9/9 cases and 7/7 checks PASS; R123 refresh updates live-helper expectation to internal-only acceptance |
| `oof-fragment-registry-source-authority-design-v0.md` | done | R116 designs both-authority semantics: pack rows own row provenance, profile owns selected pack set/order/conflict policy; implementation held |
| `oof-fragment-registry-source-authority-precedence-proof-v0.md` | done / PASS | R117 proves precedence: 9/9 cases and 9/9 checks PASS; duplicate ownership rejects aggregate, profile cannot override pack-row conflict; R123 refresh confirms the exact four R121/R122 accepted modes |
| `../gates/oof-fragment-registry-source-authority-model-acceptance-decision-v0.md` | accepted-proof-design-foundation-implementation-held-preconditions-design-next | R118 accepts profile/pack source-authority model as proof/design foundation and opens only design-only source-acceptance preconditions; implementation/compiler/public/report/runtime/spec/PROP surfaces remain closed |
| `oof-fragment-registry-profile-pack-source-acceptance-preconditions-design-v0.md` | done | R119 defines exact blocker checklist and internal-only result shape before profile/pack source acceptance; no implementation or `SOURCE_ACCEPTED_MODES` change |
| `../discussions/oof-fragment-registry-profile-pack-source-acceptance-bridge-pressure-v0.md` | proceed-with-nonblockers | R120 finds no bridge blockers; NB-1 future-qualifies accepted-mode wording, NB-2 splits pre-authorization invariant from post-authorization proof assertion |
| `../gates/oof-fragment-registry-profile-pack-source-acceptance-authorization-review-v0.md` | authorized-bounded-profile-pack-source-acceptance-helper-slice | R121 authorizes only internal helper acceptance for `profile_candidate` and `pack_descriptor_candidate`; public/report/compiler/PROP/runtime/Spark surfaces remain closed |
| `oof-fragment-registry-profile-pack-source-acceptance-proof-v0.md` | implemented-with-matrix-stale-proof-failures | R122 implements the bounded internal helper acceptance: acceptance proof PASS 13/13 cases and 5/5 checks; old proof expectations were intentionally left for R123 refresh |
| `oof-fragment-registry-profile-pack-source-proof-refresh-v0.md` | done / PASS | R123 refreshes stale proof expectations after R121/R122: full 11-command matrix PASS; candidate modes accepted only inside internal helper; external surfaces remain closed |
| `oof-fragment-registry-compiler-profile-source-input-design-v0.md` | done | R124 designs a proof-only compiler-profile source-input packet route; compiler/public/report/loader/runtime implementation remains held |
| `oof-fragment-registry-compiler-profile-source-input-proof-v0.md` | done / PASS | R125 proves proof-only source-input packet mapping to helper envelopes: 9/9 cases and 6/6 checks PASS; source-input model accepted, implementation held |
| `compiler-profile-source-input-lifecycle-owner-design-v0.md` | done | R126 chooses hybrid profile assembly ownership and internal constructor/test seam as future carrier; implementation and public/report/compiler surfaces remain held |
| `../discussions/compiler-profile-source-input-lifecycle-bridge-pressure-v0.md` | proceed-with-nonblockers | R127 finds no bridge blockers; NB-1 requires "internal profile-assembly source packet" wording, NB-2 defines `finalized_internal` as non-PROP-036 internal assembly state |
| `../gates/internal-profile-assembly-source-packet-implementation-authorization-review-v0.md` | authorized-bounded-internal-profile-assembly-source-packet | R128 authorizes only an internal profile-assembly source packet implementation in one internal lib file plus proof experiment/track; public/report/compiler/manifest/PROP/runtime/Spark surfaces remain closed |
| `internal-profile-assembly-source-packet-implementation-v0.md` | done / PASS | R129 implements `IgniterLang::InternalProfileAssemblySourcePacket`: 6/6 cases and 5/5 checks PASS; root require and compiler pipeline remain closed |
| `internal-profile-assembly-boundary-design-v0.md` | done | R130 designs proof-only `internal_profile_assembly_result` boundary around the packet and OOF registry; implementation review held |
| `internal-profile-assembly-boundary-proof-v0.md` | done / PASS | R131 proves proof-only assembly boundary/result: 6/6 cases and 5/5 checks PASS; valid packet finalizes internally, invalid packets do not finalize, external surfaces remain closed |
| `../gates/internal-profile-assembly-boundary-implementation-authorization-review-v0.md` | authorized-bounded-internal-profile-assembly-boundary | R132 authorizes only `IgniterLang::InternalProfileAssembly` as a tiny internal boundary object/result; root require, compiler pipeline, public/report/manifest/PROP/runtime/Spark surfaces remain closed |
| `internal-profile-assembly-boundary-implementation-v0.md` | done / PASS | R133 implements `IgniterLang::InternalProfileAssembly`; implementation proof PASS 7/7 cases and 5/5 checks; R134 resolves the stale R131 matrix assertion |
| `internal-profile-assembly-boundary-proof-maintenance-v0.md` | done / PASS | R134 supersedes R131 `no_new_lib_assembly_boundary_file` with authorized-file/direct-require-only check; full R132/R133 matrix PASS and external surfaces remain closed |
| `internal-profile-assembly-next-carrier-design-v0.md` | done | R135 recommends a no-code/proof-local `internal_profile_assembly_carrier_map`; live carriers remain held and Bridge review is required before external surfaces |
| `internal-profile-assembly-carrier-map-v0.md` | done / PASS | R136 creates proof-local carrier map JSON; deterministic digest PASS; map is not CompilerProfile, compiler_profile_id, `.igapp`, report, loader, CompatibilityReport, runtime readiness, or production readiness |
| `compiler-pack-profile-migration-design-v0.md` | done | R138 designs CP1 migration: future CompilerProfile as frozen compiler-surface snapshot, CompilerPack as declarative contribution unit, pure projection first |
| `internal-profile-migration-projection-proof-v0.md` | done / PASS | R139 creates proof-local migration projection JSON; digest PASS; proves pure projection is not CompilerProfile, compiler_profile_id, `.igapp`, report, PROP-036/038 authority, runtime, or production readiness |
| `compiler-pack-pass-boundary-ownership-map-v0.md` | done / PASS | R140 maps parser/classifier/TypeChecker/SemanticIR/assembler/OOF/fragment ownership; digest PASS; HP2-HP6 hold points active; implementation remains held |
| `oof-fragment-registry-parity-proof-v0.md` | done / PASS | R141 proves observed emitted OOF codes have shadow descriptors; alias/deprecation and excluded namespace parity PASS; `compiler_profile_contract.*` leakage absent; remains shadow-only |
| `fragment-precedence-parity-proof-v0.md` | done / HOLD | R142 proves fragment row coverage, OOF status projection, and guarded non-fragment parity; holds live precedence migration because stream-vs-escape and epistemic-vs-escape would drift if candidate order became live |
| `fragment-precedence-compatibility-adapter-proof-v0.md` | done / PASS | R144 proves R143 two-layer declaration-presence + selected-fragment adapter preserves all 23 observed classifier goldens; adapter remains proof-local and live dispatch held |
| `fragment-registry-adapter-implementation-boundary-design-v0.md` | done | R145 C1 designs adapter boundary: selected-fragment compatibility belongs near classifier semantics, first implementation candidate held, reports/`.igapp`/runtime closed |
| `fragment-registry-adapter-evidence-and-risk-map-v0.md` | done | R145 maps live classifier behavior, proof-local adapter behavior, touchpoints, hidden mutation risks, and missing evidence before any future adapter implementation review |
| `../discussions/fragment-registry-adapter-boundary-pressure-v0.md` | proceed-with-notes | R145 C3 pressure PASS 6/6; NB-1 vocabulary alignment, NB-2 first-slice divergence, NB-3 classifier-parity scope routed to C4-A |
| `../gates/fragment-registry-adapter-implementation-boundary-decision-v0.md` | accepted-design-proof-route-next-implementation-held | R145 C4 accepts design/proof foundation and opens only proof/design internal-helper boundary; implementation, live classifier dispatch, SemanticIR/report/`.igapp`, public/runtime/Spark surfaces remain closed |
| `stage3-round145-status-curation-v0.md` | done | R145 status curation: records accepted/held adapter boundary, proof/design next route, closed surfaces, and demo-shadow note-only state |
| `fragment-registry-compatibility-adapter-internal-helper-boundary-proof-v0.md` | done / PASS | R146 C1 proof-only helper boundary: helper input/result shape, R144 parity 23/23, negative scans, and command matrix PASS without lib/root/classifier wiring |
| `../discussions/fragment-registry-compatibility-adapter-helper-boundary-pressure-v0.md` | proceed | R146 C2 pressure PASS 7/7; carries implementation-review notes for dynamic lib checks, assumptions proof, broader scans, and exact/delta helper result shape |
| `../gates/fragment-registry-compatibility-adapter-helper-boundary-proof-decision-v0.md` | accepted-proof-implementation-authorization-review-next-implementation-held | R146 C3 accepts proof-only helper boundary and opens only implementation-authorization review; implementation and protected compiler/public/runtime/Spark surfaces remain closed |
| `stage3-round146-status-curation-v0.md` | done | R146 status curation: records accepted helper-boundary proof, authorization-review next route, implementation-held status, closed surfaces, and demo-shadow note-only state |
| `../gates/fragment-registry-compatibility-adapter-helper-implementation-authorization-review-v0.md` | authorized-bounded-direct-require-helper-implementation | R147 C1 authorizes only bounded direct-require helper implementation/proof; exact C2-I scope limited to helper file, proof experiment, and track; root/classifier/compiler/report/artifact/public/runtime/Spark remain closed |
| `stage3-round147-status-curation-v0.md` | done | R147 status curation: records bounded helper implementation authorization, exact next route, not-yet-landed implementation status, closed surfaces, and demo-shadow note-only state |
| `fragment-registry-compatibility-adapter-helper-implementation-proof-v0.md` | done / PASS | R147 C2-I implements direct-require helper: 44/44 proof checks, R144 23/23 parity, clean root/classifier/report/artifact scans, full regression matrix PASS |
| `../discussions/fragment-registry-compatibility-adapter-helper-implementation-pressure-v0.md` | proceed-with-notes | R148 C1 pressure accepts implementation evidence with NB-1 CS4 proof-check logic bug disposition required; no implementation blockers, classifier wiring/root require remain closed |
| `../gates/fragment-registry-compatibility-adapter-helper-implementation-acceptance-decision-v0.md` | accepted-implementation-closure-proof-hygiene-next | R148 C2 accepts helper implementation closure and opens only status curation plus proof-hygiene follow-up; no classifier wiring, root require, public/report/artifact/runtime/Spark authority |
| `stage3-round148-status-curation-v0.md` | done | R148 status curation: records helper implementation accepted/landed/closed, proof-hygiene next route, closed classifier/root/public/runtime surfaces, and demo-shadow note-only state |
| `fragment-registry-compatibility-adapter-helper-proof-hygiene-v0.md` | done / PASS | R149 C1 proof hygiene fixes CS4, scan counts, live-derived closed-surface assertions, and machine-asserted pinned command counts without helper code edits |
| `../discussions/fragment-registry-compatibility-adapter-helper-proof-hygiene-pressure-v0.md` | proceed | R149 C2 pressure PASS 8/8; helper unchanged, write scope exact, command matrix PASS, root/classifier/live dispatch/public/runtime surfaces closed |
| `../gates/fragment-registry-compatibility-adapter-helper-proof-hygiene-acceptance-decision-v0.md` | accepted-proof-hygiene-strategic-vector-next | R149 C3 accepts proof hygiene and selects status curation then strategic compiler-mainline vector decision; no automatic classifier wiring or report/artifact route |
| `stage3-round149-status-curation-v0.md` | done | R149 status curation: records accepted proof hygiene, strategic vector decision next route, unchanged helper implementation, closed wiring/root/public/runtime surfaces, and demo-shadow note-only state |
| `../gates/compiler-mainline-strategic-vector-decision-v0.md` | adapter-lane-paused-compiler-profile-architecture-reentry-next | R150 pauses adapter lane, treats Spark L3B as applied pressure only, and opens only design/report compiler-profile architecture reentry map; no implementation, wiring, report/artifact, Spark, production, or demo work |
| `stage3-round150-status-curation-v0.md` | done | R150 status curation: records adapter lane paused, Spark pressure-only disposition, exact S3-R151 design/report next boundary, closed implementation/wiring/Spark/demo surfaces |
| `compiler-profile-architecture-reentry-map-v0.md` | done | R151 C1 maps compiler/profile architecture axes and recommends design-only `compiler-profile-source-mode-static-data-boundary-design-v0`; adapter lane paused, Spark pressure external, implementation/public/report/runtime/demo surfaces closed |
| `stage3-round151-status-curation-v0.md` | done | R151 status curation: records source-mode/static-data boundary design as next route, adapter lane paused, Spark pressure-only disposition, closed implementation/wiring/public/report/runtime/demo surfaces |
| `compiler-profile-source-mode-static-data-boundary-design-v0.md` | done | R152 C1 accepts source-mode/static-data as design/proof candidate only; static data is not library data, generated index, public discovery, manifest/report/artifact/runtime/Spark authority |
| `../discussions/compiler-profile-source-mode-static-data-boundary-pressure-v0.md` | proceed | R152 C2 pressure PASS 7/7; carries NB-1 minimal synthetic shape and NB-3 PROP-036 token scan guidance into proof route |
| `../gates/compiler-profile-source-mode-static-data-boundary-decision-v0.md` | accepted-proof-only-next | R152 C3 accepts boundary design and opens only proof-only `compiler-profile-source-mode-static-data-boundary-proof-v0`; no implementation/public/report/artifact/Spark/runtime/demo work |
| `stage3-round152-status-curation-v0.md` | done | R152 status curation: records accepted boundary, role hygiene note, proof-only S3-R153 next route, Spark pressure-only disposition, and closed surfaces |
| `compiler-profile-source-mode-static-data-boundary-proof-v0.md` | done / PASS | R153 C1 proves source-mode/static-data boundary with synthetic proof-local data; PASS 16/16, duplicate ownership rejection, PROP-036 scoped scan, closed surfaces preserved |
| `../discussions/compiler-profile-source-mode-static-data-boundary-proof-pressure-v0.md` | proceed | R153 C2 pressure PASS 10/10; notes PROP-036 scan forbidden-payload scope and stated semantic closed-surface assertions as non-blocking |
| `../gates/compiler-profile-source-mode-static-data-boundary-proof-decision-v0.md` | accepted-implementation-authorization-review-next | R153 C3 accepts proof and opens only implementation-authorization review; no implementation/public/report/artifact/Spark/runtime/demo work |
| `stage3-round153-status-curation-v0.md` | done | R153 status curation: records accepted proof, implementation-authorization review next boundary, Spark pressure-only disposition, and closed implementation/public/report/runtime/demo surfaces |
| `../gates/compiler-profile-source-mode-static-data-internal-carrier-implementation-authorization-review-v0.md` | authorized-bounded-internal-carrier-implementation | R154 C1 authorizes only `IgniterLang::InternalProfileStaticDataCarrier` as a direct-require internal carrier/test seam for a future bounded implementation card; public/report/artifact/Spark/runtime/demo surfaces remain closed |
| `stage3-round154-status-curation-v0.md` | done | R154 status curation: records bounded internal-carrier authorization and Portfolio review satisfied for exact S3-R154-C2-I boundary only; implementation was later accepted in R155 |
| `compiler-profile-source-mode-static-data-internal-carrier-implementation-v0.md` | done / PASS | R154 C2-I lands bounded direct-require internal static-data carrier implementation; proof summary 9/9 PASS and command matrix PASS; root require/compiler pipeline/public/report/Spark/runtime/demo remain closed |
| `../discussions/compiler-profile-source-mode-static-data-internal-carrier-implementation-pressure-v0.md` | proceed | R155 C1 pressure PASS 12/12 with no blockers; notes stricter forbidden fields, unnamed lower-risk validation paths, and adjacent admin dispatch commit as non-blocking |
| `../gates/compiler-profile-source-mode-static-data-internal-carrier-implementation-acceptance-decision-v0.md` | accepted-implementation-closure-pause-next | R155 C2 accepts bounded internal carrier implementation closure and opens no immediate follow-up; any widening requires fresh Portfolio-visible review |
| `stage3-round155-status-curation-v0.md` | done | R155 status curation: records accepted implementation closure, carrier lane pause, Spark pressure-only disposition, and closed public/report/artifact/runtime/demo surfaces |
| `../gates/compiler-mainline-post-carrier-strategic-vector-decision-v0.md` | docs-spec-sync-next | R156 C1 selects docs/spec sync as the next compiler-mainline route; carrier lane remains paused, Spark pressure external, and implementation/public/report/artifact/runtime/demo surfaces remain closed |
| `stage3-round156-status-curation-v0.md` | done | R156 status curation: records docs/spec sync next boundary `compiler-profile-internal-carrier-docs-spec-sync-v0`, paused carrier lane, Spark pressure-only disposition, and closed protected surfaces |
| `compiler-profile-internal-carrier-docs-spec-sync-v0.md` | done | S3-R156-C2-P1 docs/spec sync: records accepted direct-require-only internal carrier closure, corrects living-map drift, holds old historical track wording, and recommends pause/no immediate follow-up |
| `../gates/poc-mvp-live-touch-scope-decision-v0.md` | authorized-bounded-local-poc-implementation-proof | R157 C1 opens only bounded local POC/MVP live-touch implementation/proof under `experiments/poc_mvp_live_touch_v0/**`; public demo/release, Spark integration, production runtime, deployment, and language semantics remain closed |
| `stage3-round157-status-curation-v0.md` | done | R157 status curation: records local POC/MVP route opened, exact S3-R157-C2-I `poc-mvp-live-touch-v0` boundary, public-demo/release closure, Spark pressure-only disposition, and closed runtime/deployment surfaces |
| `poc-mvp-live-touch-v0.md` | done / PASS | R157 C2-I bounded local POC/MVP lab: 4/4 `.ig` sources compiled, 4/4 proof-local traces trusted, `.igapp` outputs contained under the POC `out/` directory; not public demo/release, production runtime, Spark integration, or language-semantics authority |
| `compiler-release-poc-acceptance-fractal-seed-v0.md` | done | R158 C1-P1 accepts the POC as bounded local demo-lab and release-readiness seed evidence; release-candidate/public demo/public release/production/Spark readiness remain closed |
| `fractal-supervisor-packet-synthesis-v0.md` | done | R158 C5-A accepts available supervisor packets, routes compiler release-readiness mapping next, keeps Spark sanitized pressure as design/fixture input only, pauses Ruby compiler-alignment until a stable Lang export fixture, and returns to unified round mode |
| `compiler-release-readiness-map-v0.md` | done / accepted | R159 C1-D maps first compiler release-readiness: POC evidence is seed only; missing RC harness, negative/refusal corpus, normalization policy, package/install/load-path smoke, release docs, and closed-surface scan remain before RC evidence gathering |
| `../discussions/compiler-release-readiness-map-pressure-v0.md` | proceed | R159 C2-X pressure finds no blockers across 8/8 challenges; NB-1..NB-5 become required inputs for the next acceptance-harness design |
| `compiler-release-readiness-and-ruby-hygiene-decision-v0.md` | done / accepted | R159 C4-A accepts the release-readiness map, pressure review, and Ruby Framework docs/examples hygiene; opens only design-only `compiler-release-acceptance-harness-design-v0`; no implementation/release/public/Spark/runtime authority |
| `stage3-round159-status-curation-v0.md` | done | R159 status curation: records accepted map, analyzer/tracer/visualizer design-only disposition, Spark sanitized-pressure-only disposition, accepted Ruby hygiene, and R160 design-only harness route |
| `compiler-release-acceptance-harness-design-v0.md` | done / accepted | R160 C1-D defines the first compiler release acceptance harness design: inputs, stable/normalized/excluded artifact fields, corpus requirements, command matrix, PASS/HOLD/FAIL packet, non-claims, and closed-surface scan; design only, no RC evidence gathering |
| `../discussions/compiler-release-acceptance-harness-design-pressure-v0.md` | proceed | R160 C2-X pressure finds no blockers across 10/10 checks; C3-A carries five notes as mandatory implementation-authorization inputs |
| `compiler-release-acceptance-harness-design-decision-v0.md` | done / accepted | R160 C3-A accepts the harness design and pressure review, keeps RC evidence gathering closed, and opens only `compiler-release-acceptance-harness-implementation-authorization-review-v0` next |
| `stage3-round160-status-curation-v0.md` | done | R160 status curation: records accepted harness design, R159 NB-1..NB-5 design closure, R160 pressure notes carried forward, RC evidence still closed, Spark/Ruby held, and R161 authorization-review route |
| `compiler-release-acceptance-harness-implementation-authorization-review-v0.md` | authorized bounded proof-local implementation | R161 C1-A authorizes only proof-local harness runner implementation under `experiments/compiler_release_acceptance_harness_v0/**` plus the proof track; RC evidence gathering, release execution, public claims, Spark/Ruby, runtime, and production remain closed |
| `stage3-round161-status-curation-v0.md` | done | R161 status curation: records exact C2-I authorization boundary, R160 note disposition, RC evidence closed, analyzer/tracer/visualizer internal-linkage-only status, Spark/Ruby held, and next `compiler-release-acceptance-harness-implementation-proof-v0` route |
| `compiler-release-acceptance-harness-implementation-proof-v0.md` | done / HOLD | R161 C2-I lands proof-local harness runner implementation; command matrix 14/14 PASS, failed_checks 0, HOLD is branch/conditional boundary signal, not official RC evidence |
| `compiler-release-acceptance-harness-implementation-closure-decision-v0.md` | conditional accept | R162 C1-A accepts proof-local runner closure, keeps HOLD as correct branch/conditional boundary signal, and requires semantic profile-source refusal follow-up before RC evidence authorization |
| `stage3-round162-status-curation-v0.md` | done | R162 status curation: records conditional implementation closure, HOLD interpretation, branch/conditional disposition, semantic-refusal proof gap, RC evidence closed, and next semantic-profile refusal follow-up route |
| `compiler-release-harness-semantic-profile-refusal-follow-up-decision-v0.md` | authorized bounded proof-local fix | R163 C1-A authorizes only harness-local semantic profile-source diagnostic extraction fix; reclassification rejected, compiler/library changes closed, RC evidence gathering closed |
| `stage3-round163-status-curation-v0.md` | done | R163 status curation: records C2-I authorization boundary, semantic diagnostic disposition, R162 semantic condition closable after proof, branch/conditional HOLD still open, and RC evidence closed |
| `compiler-release-harness-semantic-profile-refusal-follow-up-v0.md` | done / accepted by R164 | R163 C2-I lands the harness-local semantic profile-source diagnostic extraction fix; qualified diagnostic found from report diagnostics, failed_checks 0, branch/conditional HOLD remains separate |
| `compiler-release-harness-semantic-profile-follow-up-closure-decision-v0.md` | done / accepted | R164 C1-A accepts semantic follow-up closure, formally closes the R162 semantic profile-source condition, and opens first-RC branch/conditional scope disposition as design-only |
| `first-rc-branch-conditional-scope-disposition-v0.md` | done | R164 C2-D recommends Option A: first RC explicitly excludes branch/conditional `if_expr`; no code, parser, TypeChecker, SemanticIR, compiler, RC evidence, release, or public claims authorized |
| `../discussions/first-rc-branch-conditional-scope-pressure-v0.md` | proceed | R164 C3-X pressure proceeds with no blockers and NB-1..NB-5: machine-visible out-of-scope marker, release_scope, non_claims, no-implementation wording, and RC evidence label protection |
| `first-rc-branch-conditional-scope-decision-v0.md` | done / accepted | R164 C4-A accepts narrowed first-RC scope excluding branch/conditional `if_expr`; official RC evidence stays closed until a scope-aware harness update reruns to PASS and a later authorization review opens it |
| `compiler-release-acceptance-harness-scope-aware-rc-evidence-authorization-review-v0.md` | authorized bounded harness update | R165 C1-A authorizes only scope-aware harness update under `experiments/compiler_release_acceptance_harness_v0/**` plus the C2-I track doc; outputs are not official RC evidence |
| `stage3-round165-status-curation-v0.md` | done | R165 status curation records C2-I authorization boundary, required out_of_scope/release_scope/non_claims shape, RC evidence closure, branch/conditional implementation closure, and next scope-aware harness update route |
| `compiler-release-acceptance-harness-scope-aware-update-v0.md` | done / PASS | R165 C2-I lands scope-aware harness update: branch_conditional_if_expr out_of_scope, release_scope/non_claims added, command matrix 14/14 PASS, failed_checks 0, hold_reasons 0; still pre-RC evidence only |
| `compiler-release-scope-aware-harness-update-acceptance-prep-v0.md` | done | R166 C1-A recommends accepting the scope-aware harness PASS and opening an official first-RC evidence-gathering authorization review; does not authorize evidence gathering itself |
| `practical-rc-ledger-spark-crosslane-decision-v0.md` | done / accepted | R166 C4-A accepts Lang harness PASS, accepts Ruby Ledger stress probe as local evidence, accepts Spark schedule_grid facade direction with formal report/observe deferred, and opens R167 authorization review |
| `compiler-release-official-first-rc-evidence-gathering-authorization-review-v0.md` | authorized bounded evidence gathering next | R167 C1-A authorizes only a fresh bounded official first-RC evidence card under `experiments/compiler_release_official_first_rc_evidence_v0/**` plus its track; existing R165/R166 outputs cannot be relabeled |
| `stage3-round167-status-curation-v0.md` | done | R167 status curation records official first-RC evidence-gathering authorization for R168 C1-I, Ruby Ledger state-plane/concurrency design PASS with implementation gated, deferred Spark schedule_grid report/observe, and closed surfaces |
| `compiler-release-official-first-rc-evidence-gathering-v0.md` | done / PASS | R168 C1-I produces fresh official first-RC evidence under `compiler_release_official_first_rc_evidence_v0/**`: 3/3 evidence commands PASS, source harness 14/14 PASS, failed_checks 0, hold_reasons 0, branch_conditional_if_expr excluded |
| `../discussions/compiler-release-official-first-rc-evidence-pressure-v0.md` | proceed | R168 C3-X pressure passes 10/10 checks with no blockers; carries NB-1 hash cross-check, NB-2 command-matrix interpretation, and NB-3 self-reference naming for future evidence rounds |
| `official-first-rc-evidence-acceptance-and-next-release-vector-decision-v0.md` | done / accepted | R168 C4-A accepts official first-RC evidence for `repo_local_compiler_rc`, keeps release execution and public claims closed, allows Ruby Ledger implementation to proceed independently under S3-R168-C2-A, and routes release-readiness summary/package next |
| `stage3-round168-status-curation-v0.md` | done | R168 status curation records accepted official evidence, release execution/public claims closure, Ruby Ledger bounded implementation authorization, Spark deferral, and next `compiler-release-readiness-summary-package-v0` route |
| `compiler-release-readiness-summary-package-v0.md` | done / accepted | R169 C1-D packages accepted official first-RC evidence for `repo_local_compiler_rc`, records installed-gem readiness not established, keeps release execution/public claims closed, and recommends authorization review next |
| `../discussions/compiler-release-readiness-summary-package-pressure-v0.md` | proceed | R169 C3-X pressure passes 7/7 checks with no blockers; carries NB-1 version/tagging, NB-2 docs/non-claims by target type, and NB-3 package/install matrix pass criteria into authorization review |
| `compiler-release-readiness-package-acceptance-decision-v0.md` | done / accepted | R169 C4-A accepts the release-readiness package, opens only `compiler-release-execution-authorization-review-v0` next, keeps release execution and public claims closed now, and keeps Spark out of the round |
| `stage3-round169-status-curation-v0.md` | done | R169 status curation records accepted readiness package, release execution/public claims closure, Ruby Ledger hardening independent path, Spark exclusion, and next release-execution authorization review route |
| `compiler-release-target-versioning-and-execution-options-v0.md` | done | R170 C1-P1 records target/versioning options; installed-gem readiness is not established, public gem release is premature, and Option A repo-local RC marker is safest if movement is desired |
| `compiler-release-evidence-hash-docs-and-package-smoke-policy-v0.md` | done | R170 C2-P1 defines EH-1..EH-7 evidence hygiene policy, target-typed docs/non-claims, package/install smoke PASS/HOLD/FAIL criteria, and public wording guardrails without authorizing execution |
| `../discussions/compiler-release-execution-authorization-pressure-v0.md` | proceed | R170 C3-X pressure passes 10/10 checks; C4-A must fix `igc compile` executable wording, use Section 5 Tier 3 wording if needed, and make Option A null-version-change explicit |
| `compiler-release-execution-authorization-review-v0.md` | done / authorized bounded marker | R170 C4-A authorizes only `repo_local_compiler_rc_marker` execution next, requires independent hash verification, keeps version/tag/push/publish/sign/deploy/public claims closed, and leaves installed-gem/package readiness not established |
| `stage3-round170-status-curation-v0.md` | done | R170 status curation records bounded repo-local marker authorization, null-version/tagging status, public claims and package readiness closure, closed surfaces, and next `compiler-release-repo-local-rc-marker-v0` route |
| `compiler-release-repo-local-rc-marker-v0.md` | done | R171 C1-I writes the repo-local RC marker: independent hash verification PASS, official evidence `repo_local_compiler_rc` scope accepted, PASS status, all non-claims and exclusions preserved; no version change, no tag, no push, no gem publish; release execution beyond marker closed |
| `../discussions/compiler-release-repo-local-rc-marker-pressure-v0.md` | proceed | R171 C2-X pressure passes 12/12 checks with no blockers; NB-1 about secondary `rg` command is informational only and not a blocker |
| `compiler-release-repo-local-rc-marker-acceptance-decision-v0.md` | done / accepted | R171 C3-A accepts the repo-local compiler RC marker, keeps release execution beyond marker and public claims closed, keeps installed-gem/package readiness not established, and opens only package/install smoke authorization review next |
| `stage3-round171-status-curation-v0.md` | done | R171 status curation records accepted marker, hash PASS, release/public/package readiness closures, closed surfaces, and next `compiler-release-package-install-smoke-authorization-review-v0` route |
| `compiler-release-package-install-smoke-boundary-v0.md` | done | R172 C1-P1 defines bounded local package/install smoke target, current version `0.1.0.pre.stage2`, installed `igc` command shape, temp-only artifact policy, and no-version/no-tag/no-publish stance |
| `compiler-release-package-install-smoke-criteria-v0.md` | done | R172 C2-P1 defines concrete PKG-1..PKG-5 PASS/HOLD/FAIL criteria, required summary JSON shape, non-claims, and cleanup/retention policy; corrects installed CLI command to `igc compile`; no smoke run |
| `../discussions/compiler-release-package-install-smoke-authorization-pressure-v0.md` | proceed | R172 C3-X pressure passes 11/11 checks with no blockers; C4-A must define repo write scope, defer or include profile-source checks, and assign the execution card designation |
| `compiler-release-package-install-smoke-authorization-review-v0.md` | done / authorized bounded smoke | R172 C4-A authorizes only `S3-R173-C1-I / compiler-release-package-install-smoke-v0` for bounded local package/install smoke; installed readiness remains unestablished until PASS and later acceptance; public/version/tag/publish/sign/deploy surfaces remain closed |
| `stage3-round172-status-curation-v0.md` | done | R172 status curation records bounded smoke authorization, installed package readiness hold, public/version/tag/publish closure, closed surfaces, and next `compiler-release-package-install-smoke-v0` route |
| `compiler-release-package-install-smoke-v0.md` | done / PASS | R173 C1-I runs the bounded local package/install smoke: PKG-0..PKG-5 PASS, installed `igc compile`, 5/5 positive corpus, 3/3 refusal corpus, no repo path leak, no version/tag/publish/sign/deploy action |
| `../discussions/compiler-release-package-install-smoke-pressure-v0.md` | proceed | R173 C2-X pressure passes 14/14 checks with no blockers; refusal_kind and PKG-0 criteria placement notes are non-blocking smoke hygiene |
| `compiler-release-package-install-smoke-acceptance-decision-v0.md` | done / accepted | R173 C3-A accepts smoke PASS and recognizes installed-gem/package readiness only for bounded local smoke scope; public release/demo, RubyGems, production, version/tag/publish/sign/deploy, profile-source smoke, Spark, and Ruby Framework claims remain closed |
| `stage3-round173-status-curation-v0.md` | done | R173 status curation records accepted smoke PASS, local installed package readiness scope, public/version/tag/publish closure, closed surfaces, and next `compiler-release-installed-gem-readiness-marker-v0` route |
| `compiler-release-installed-gem-readiness-marker-v0.md` | done | R174 C1-S records the accepted local package/install smoke readiness marker for `igniter_lang` `0.1.0.pre.stage2`, run `S3R173C1I_20260525T063543Z`, built gem SHA256, installed `igc compile` PASS, 5/5 positive and 3/3 refusal corpus; public/RubyGems/version/tag/publish/sign/deploy claims remain closed |
| `compiler-release-next-vector-options-v0.md` | done | R174 C2-P1 compares next release-vector options and recommends profile-source smoke extension authorization review; public claims, release execution, version/tag/publish/sign/deploy, branch/conditional, Spark, and runtime remain closed |
| `../discussions/compiler-release-installed-gem-marker-and-next-vector-pressure-v0.md` | proceed | R174 C3-X pressure passes 9/9 checks with no blockers; carries full-chain release-closure citation and not-allowed wording constraints as future notes |
| `compiler-release-installed-readiness-and-next-vector-decision-v0.md` | done / accepted | R174 C4-A accepts the installed-gem readiness marker, keeps local package/install smoke readiness bounded, selects profile-source smoke extension authorization review next, and keeps release execution/public/RubyGems/version/tag/publish/sign/deploy closed |
| `stage3-round174-status-curation-v0.md` | done | R174 status curation records marker acceptance, selected profile-source authorization-review vector, public/version/tag/publish closure, profile-source execution closure, and closed surfaces |
| `compiler-release-profile-source-smoke-extension-boundary-v0.md` | done | R175 C1-P1 defines the bounded installed-package profile-source smoke extension boundary, success/refusal fixtures, expected compiler_profile_id, non-claims, and execution-authorization preconditions; no smoke run or execution authorization |
| `compiler-release-profile-source-smoke-extension-criteria-v0.md` | done | R175 C2-P1 defines PSS-0..PSS-8 PASS/HOLD/FAIL criteria, installed package isolation, command matrix, success/preflight/semantic refusal criteria, required result packet shape, artifact policy, and R173 NB-1 refusal-kind hygiene; no smoke run or execution authorization |
| `../discussions/compiler-release-profile-source-smoke-extension-authorization-pressure-v0.md` | proceed | R175 C3-X pressure passes 14/14 checks with no blockers; notes C4-A should assign concrete execution card ids and acknowledge the PSS-3/PSS-4 report distinction |
| `compiler-release-profile-source-smoke-extension-authorization-review-v0.md` | done / authorized bounded smoke | R175 C4-A authorizes only `S3-R176-C1-I / compiler-release-profile-source-install-smoke-v0` for bounded installed-package profile-source smoke; public release/demo claims, release execution, RubyGems publish, version/tag/push/publish/sign/deploy, profile finalization/discovery/defaulting, Spark, runtime, and production remain closed |
| `stage3-round175-status-curation-v0.md` | done | R175 status curation records bounded profile-source smoke authorization, execution-not-run status, required next summary path, public/release/version closure, and next `compiler-release-profile-source-install-smoke-v0` route |
| `compiler-release-profile-source-install-smoke-v0.md` | done / PASS | R176 C1-I runs the bounded installed-package profile-source smoke: PSS-0..PSS-8 PASS, run `S3R176C1I_20260525T101425Z`, installed `igc compile --compiler-profile-source PATH.json`, valid finalized profile-source success, malformed JSON preflight refusal, semantic wrong-kind refusal, and all 24 non-claims true |
| `../discussions/compiler-release-profile-source-install-smoke-pressure-v0.md` | proceed | R176 C2-X pressure passes 19/19 checks with no blockers; NB-1 notes partial temp `out/` cleanup as non-blocking hygiene and NB-2 notes prior non-claims count wording |
| `compiler-release-profile-source-install-smoke-acceptance-decision-v0.md` | done / accepted | R176 C3-A accepts the PASS smoke closure for bounded installed-package profile-source readiness evidence, preserves all release/public/version/profile-discovery/runtime/Spark non-authorizations, and selects profile-source installed readiness marker/status next |
| `stage3-round176-status-curation-v0.md` | done | R176 status curation records accepted smoke state, run id/status, non-blocking cleanup hygiene, preserved non-authorizations, and next `compiler-release-profile-source-installed-readiness-marker-v0` route |
| `compiler-release-profile-source-installed-readiness-marker-v0.md` | done | R177 C1-S records the bounded profile-source installed smoke readiness marker from accepted run `S3R176C1I_20260525T101425Z`, allowed/not-allowed wording, PSS-0..PSS-8 PASS, NB-1 cleanup hygiene, and preserved public/release/version/runtime/Spark non-authorizations |
| `../discussions/compiler-release-profile-source-installed-readiness-marker-pressure-v0.md` | proceed | R177 C2-X pressure passes 14/14 checks with no blockers; verifies marker fields, bounded wording, PSS-0..PSS-8, NB-1 hygiene, and non-claim preservation |
| `compiler-release-profile-source-installed-readiness-marker-acceptance-decision-v0.md` | done / accepted | R177 C3-A accepts the bounded profile-source installed readiness marker, keeps release execution/public claims/RubyGems/version/profile-discovery/runtime/Spark surfaces closed, and opens public release/docs non-claims planning next |
| `stage3-round177-status-curation-v0.md` | done | R177 status curation records accepted marker state, next public release/docs non-claims planning route, round receipt, and preserved non-authorizations |
| `compiler-release-public-nonclaims-docs-scope-v0.md` | done | R178 C1-P1 drafts public release/docs non-claims planning wording, preferred phrase shapes, excluded surfaces, and later docs polish boundary; no public docs edited |
| `compiler-release-public-readme-and-demo-claim-risk-survey-v0.md` | done | R178 C2-P1 surveys README/docs/demo-facing claim risk and classifies CR-1 as blocker before public docs polish and CR-13 as Portfolio-gated before public Spark mention |
| `../discussions/compiler-release-public-nonclaims-pressure-v0.md` | proceed | R178 C3-X pressure passes 12/12 checks with no blockers on planning acceptance; verifies safe wording, non-claims, CR-1/CR-13 handling, and closed release/public surfaces |
| `compiler-release-public-nonclaims-planning-decision-v0.md` | done / accepted | R178 C4-A accepts public release/docs non-claims planning as planning-only/future-authorized wording candidate, requires CR-1 handling before docs polish, keeps CR-13 internal by default, and opens bounded docs polish authorization review next |
| `stage3-round178-status-curation-v0.md` | done | R178 status curation records accepted planning state, CR-1/CR-13 dispositions, next bounded docs polish authorization-review route, round receipt, and preserved non-authorizations |
| `compiler-release-docs-polish-authorization-review-v0.md` | done / authorized bounded docs polish | R179 C1-A authorizes bounded docs polish in exact named files only; release execution, public claims, RubyGems, version/tag/push/publish/sign/deploy, Spark, compiler/runtime behavior remain closed |
| `compiler-release-public-nonclaims-docs-polish-v0.md` | done | R179 C2-I performs bounded docs polish within authorized scope; CR-1 fixed/fenced; CR-13 remains internal-only; P1-P9 PASS; forbidden phrase scan CLEAN |
| `../discussions/compiler-release-public-nonclaims-docs-polish-pressure-v0.md` | proceed | R179 C3-X pressure passes 12/12 checks with no blockers and no non-blocking notes; confirms closed surfaces stay closed |
| `compiler-release-public-nonclaims-docs-polish-acceptance-decision-v0.md` | done / accepted | R179 C4-A accepts docs polish, CR-1 closure/fence, CR-13 internal-only preservation, and opens release-execution authorization review next while keeping execution/public claims closed |
| `stage3-round179-status-curation-v0.md` | done | R179 status curation records accepted docs polish state, CR-1/CR-13 dispositions, next release-execution authorization-review route, round receipt, and preserved non-authorizations |

---

## Spark Availability Metrics Fixture Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `spark-availability-metrics-fixture-design-v0.md` | done | Design-only P4 route for sanitized synthetic metrics-backed aggregate examples; no fixture files created; recommends pressure review before fixture creation |
| `../discussions/spark-availability-metrics-fixture-design-pressure-v0.md` | proceed | P5 pressure PASS 7/7; success fixtures safe; error fixture held pending Spark confirmation that `unknown` is synthetic-only |
| `spark-availability-synthetic-fixture-creation-v0.md` | done | P6 creates two success-case synthetic fixtures only; error summary held; no spec/proposal/canon/compiler/runtime surfaces changed |
| `spark-availability-error-fixture-design-v0.md` | done | P7 design-only optional error fixture; marks `unknown` as synthetic error-fixture vocabulary only, not Spark production state vocabulary; no fixture file created |

---

## Shadow Agent Orchestra Research

These tracks are shadow orchestration research. They are not Igniter-Lang syntax,
not PROP promotion, and not parser/tooling authorization.

| Track | Status | Notes |
|-------|--------|-------|
| `portable-context-mnemonics-grammar-options-v0.md` | done | Sketches three mnemonic grammar variants; recommends Variant 1 Minimal Readable for first pressure testing; Variant 3 held due canonization risk |
| `portable-context-mnemonics-reconstruction-proof-v0.md` | done | Tests MN-A/MN-B/MN-C reconstruction; balanced MN-B scores best as default external validation seed; preserves evidence/closure/auth invariant |
| `portable-context-mnemonics-shadow-round-synthesis-v0.md` | done | Synthesizes C1/C2/C3 into a two-model external validation packet; recommends continuing as Agent Orchestra DNA candidate while keeping all PROP/spec/parser/tooling bridges closed |
| `portable-context-mnemonics-blind-test-context-packet-v0.md` | done | Records informal blind-test results; finds register header improves reconstruction but `CLOSED+gate` remains ambiguous; proposes Context Packet v0 with mini-grammar, dictionary id, domain-qualified atoms, invariants, and expansion refs |

---

## Stage 3 Round 92 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/tracks/oof-fragment-registry-shadow-proof-boundary-v0.md` | done | Re-anchors R92 on LANG-R91 PASS; defines proof-only OOF/Fragment registry boundary and closed surfaces |
| `oof-fragment-registry-shadow-proof-v0.md` | done / PASS | Proof-local shadow registry PASS 18/18; 63 OOF descriptors, 8 fragment rows, registry_id `oof_fragment_shadow_registry/sha256:279c9e69b50264539027d6a7`; no live registry or dispatch |
| `oof-fragment-registry-semantics-review-v0.md` | proceed-with-notes | Recommends `oof` as status-primary with secondary fragment projection candidate, and `oof > temporal > stream > escape > epistemic > core` as non-canon reference ordering |
| `../discussions/oof-fragment-registry-shadow-proof-pressure-v0.md` | proceed | 7/7 checks PASS; no blockers; three non-blocking notes resolved by C4-A |
| `../gates/oof-fragment-registry-shadow-proof-decision-v0.md` | accepted-design-only-registry-semantics-next-implementation-held | Accepts proof-only evidence; opens only design-only ownership/canon-semantics route; implementation and protected surfaces remain closed |
| `stage3-round92-status-curation-v0.md` | done | R92 status curation and Portfolio closure packet; no fallback report file needed |

---

## Stage 3 Round 90 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `compiler-pack-shadow-profile-proof-v1.md` | done / PASS | LANG-R91 proof-only shadow profile refresh; 18/18 checks PASS; records PROP-032 current assumptions surface, PROP-036 optional profile-id transport, PROP-038 internal-only strict terminal; recommends proof-only `oof-fragment-registry-shadow-proof-v0` next |
| `../org/tracks/compiler-pack-boundary-report-r90-file-boundary-v0.md` | done | Selects Option A: update existing `compiler-pack-boundary-report-v0.md` with a clearly marked R90 addendum and preserve S3-R31 body as historical foundation |
| `compiler-pack-boundary-report-v0.md` | done | R90 addendum accepted as current compiler pack boundary design/report evidence; no code, Ch6, or spec edits; S3-R31 body remains historical |
| `compiler-pack-boundary-proof-fixture-and-oof-survey-v0.md` | done | Maps proof fixtures, OOF ownership, fragments, and stale S3-R31 assumptions; recommends proof-only shadow profile or OOF/fragment registry route |
| `../discussions/compiler-pack-boundary-report-pressure-v0.md` | proceed | 7/7 checks PASS, no blockers, two non-blocking notes about stale S3-R31 wording and historical handoff pointer |
| `../gates/compiler-pack-boundary-report-decision-v0.md` | accepted-proof-only-shadow-profile-next-implementation-held | Accepts the report as design evidence; opens only proof-only `compiler-pack-shadow-profile-proof-v1` after R90 closure; implementation and protected surfaces remain closed |
| `stage3-round90-status-curation-v0.md` | done | R90 status curation and Portfolio closure packet; no fallback report file needed |

---

## Stage 3 Round 89 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/tracks/compiler-mainline-reentry-boundary-map-v0.md` | done | Separates compiler mainline from Spark applied-pressure intake; confirms R89 Portfolio close packet path and recommends conservative no-code compiler-pack boundary report route |
| `compiler-mainline-next-axis-options-v0.md` | done | Compares candidate compiler/profile axes; recommends `compiler-pack-boundary-report-v0` as primary next route and keeps strict-terminal regression hardening as backup only |
| `compiler-mainline-touchpoint-and-proof-gap-survey-v0.md` | done | Maps compiler/profile touchpoints and proof gaps; identifies Ch6 / CompilationReport spec-lag; no tests or code edits |
| `../discussions/compiler-mainline-next-axis-pressure-v0.md` | proceed | 6/6 checks PASS, no blockers, two non-blocking notes; recommends C4-A accept the pack boundary report and resolve Ch6 disposition |
| `../gates/compiler-mainline-next-axis-decision-v0.md` | accepted-design-report-next-implementation-held | Accepts `compiler-pack-boundary-report-v0` after R89 closure; design/report-only; includes Ch6 spec-lag disposition section; implementation and protected surfaces remain closed |
| `stage3-round89-status-curation-v0.md` | done | R89 status curation and Portfolio closure packet; no fallback report file needed; flags existing `compiler-pack-boundary-report-v0.md` S3-R31 filename collision for R90 handling |

---

## Stage 3 Round 88 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/tracks/sparkcrm-letter-guidance-alignment-v0.md` | done | Aligns R88 letter route with Base Role, Portfolio guidance `PG-2026-05-20-01`, R87 decision, and Portfolio closure packet expectation; recommends letter status `draft` |
| `../org/letters/sparkcrm-contractable-shadowing-pilot-scope-letter-v0.md` | draft | Cross-lane communication/request packet only; asks Spark/Ruby/Ledger/Lang to answer active guidance questions; not sent/received/answered/accepted and not implementation authority |
| `../discussions/sparkcrm-contractable-shadowing-letter-pressure-v0.md` | proceed | 9/9 checks PASS, no blockers, one non-blocking note: `availability_slotmap_v0` is recommendation pending Spark confirmation, not decided vocabulary |
| `stage3-round88-status-curation-v0.md` | done | R88 status curation and Portfolio closure packet; routes response intake next; no fallback report file needed |

---

## Stage 3 Round 87 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/tracks/sparkcrm-pilot-cross-lane-reporting-and-letter-boundary-v0.md` | done | Confirms R87 Portfolio close packet path and letter boundary; status-curation track can serve as report packet if it contains required fields |
| `sparkcrm-contractable-shadowing-pilot-scope-v0.md` | done | Recommends `AvailabilityLedger::SlotMap` for first why-not availability diagnostics pilot; defines redacted receipt shape, digest policy, sampling gate, fail-open behavior, sidecar boundary, and 17-item implementation authorization checklist |
| `../discussions/sparkcrm-contractable-shadowing-pilot-scope-pressure-v0.md` | proceed | 11/11 checks PASS, no blockers, four non-blocking notes for future implementation / C3-A disposition |
| `../gates/sparkcrm-contractable-shadowing-pilot-scope-decision-v0.md` | accepted-scope-letter-next-implementation-held | Accepts `AvailabilityLedger::SlotMap` scope as design-only; next route is `sparkcrm-contractable-shadowing-pilot-scope-letter-v0`; implementation and production remain closed |
| `stage3-round87-status-curation-v0.md` | done | R87 status curation and Portfolio closure packet; no fallback report file needed |

---

## Stage 3 Round 86 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/tracks/sparkcrm-inbox-disposition-and-pressure-routing-v0.md` | done | Routes Spark CRM inbox report as `promoted-track / active applied-pressure source`; source is not canon, not implementation authority, and not Spark CRM production authority |
| `prop038-strict-refusal-spec-chapter-sync-v0.md` | done | Synchronizes Ch5/Ch7/language-spec for R84/R85 PROP-038 strict-refusal internal foundation; no code or authority widening |
| `sparkcrm-igniter-adoption-readiness-map-v0.md` | done | Readiness map: observe existing Spark services, shadow/compare contracts, emit redacted receipts, optional sidecar Ledger sink, sanitized Lang fixtures; replacement/runtime production paths closed |
| `../discussions/r86-spec-sync-and-spark-applicability-pressure-v0.md` | proceed | 12/12 checks PASS, no blockers, four non-blocking notes; recommends C4-A accept sync/routing and bound Spark next route |
| `../gates/r86-spec-sync-and-spark-applicability-routing-decision-v0.md` | accepted-spec-sync-spark-routed | Accepts spec sync and Spark routing; next route is `sparkcrm-contractable-shadowing-pilot-scope-v0`; no implementation authorized |
| `stage3-round86-status-curation-v0.md` | done | R86 status curation; closes round card, updates status/index maps, and records Bridge Agent as Spark inbox next owner |

---

## Stage 3 Round 85 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop038-strict-refusal-canon-sync-v0.md` | done | Syncs PROP-038/current-status canon with R84 accepted live internal foundation; preserves internal-only strict source, validator-as-evidence, `compile_refusal_authorized: false`, `report.pass_result == "ok"`, exact 13-key terminal key-set, non-persisting terminal paths, and closed public/runtime surfaces |
| `prop038-strict-refusal-regression-and-canon-map-v0.md` | done | Compact canon/regression map for the R84 accepted internal-only foundation; records 10 regression anchors, expansion risks, and future expansion guard checklist; no proof rerun or implementation authorization |
| `../discussions/prop038-strict-refusal-canon-sync-pressure-v0.md` | proceed | 8/8 checks PASS, no blockers, 3 non-blocking notes: Ch5/Ch7 spec wording deferred, C2 read-only/no proof rerun, CLI/assembler anchors not rerun |
| `../gates/prop038-strict-refusal-canon-sync-acceptance-decision-v0.md` | accepted-canon-sync-docs-spec-sync-next | Accepts canon sync and regression/canon map; next route is `prop038-strict-refusal-spec-chapter-sync-v0`; no implementation or public/runtime expansion |
| `stage3-round85-status-curation-v0.md` | done | R85 status curation; records accepted sync, pressure verdict, preserved closed surfaces, and docs/spec sync next route |

---

## Stage 3 Round 84 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/prop038-strict-refusal-live-implementation-acceptance-decision-v0.md` | accepted-live-internal-foundation | Accepts the R83 bounded internal-only strict-refusal implementation as the live internal foundation; no new implementation or public/runtime expansion authorized |
| `stage3-round84-status-curation-v0.md` | done | R84 status curation; records accepted live internal foundation, preserved closed surfaces, and requirement that future routes need separate Architect gates |

---

## Stage 3 Round 83 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/prop038-strict-refusal-live-implementation-authorization-review-v0.md` | authorized-bounded-internal-only-implementation | Authorizes only the bounded internal-only strict-refusal live implementation slice; public API/CLI, loader/report, CompatibilityReport, runtime, Gate 3, and production remain closed |
| `prop038-strict-refusal-live-implementation-v0.md` | done | Lands bounded internal-only implementation in `compiler_orchestrator.rb` and `compiler_result.rb` plus live proof harness; 16 cases / 46 checks / 0 failed; all 11 command matrix commands PASS |
| `../discussions/prop038-strict-refusal-live-implementation-pressure-v0.md` | proceed | All 10 scope checks pass; no blockers; one non-blocking instrumentation asymmetry for non-strict success-path `assembler_calls`; forbidden surfaces remain closed |
| `stage3-round83-status-curation-v0.md` | done | R83 status curation; records landed bounded internal-only implementation, proof matrix, pressure verdict, preserved non-authorizations, and next acceptance/closure recommendation |

---

## Stage 3 Round 82 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-strict-refusal-live-scope-orientation-map-v0.md` | active orientation map | C0-O org-sidecar map; separates implementation-scope design/review from implementation authorization; orientation only |
| `prop038-strict-refusal-live-implementation-scope-review-v0.md` | done | Design/review-only live implementation scope review; names candidate future write scope, authority requirements, `report.pass_result` policy, `configuration_error` public surface, non-persisting boundary, proof matrix, and blockers before implementation |
| `prop038-live-implementation-touchpoint-survey-v0.md` | done | Read-only live touchpoint survey; maps current orchestrator/result/report/assembler/CLI/facade touchpoints, coupling risks, regression anchors, and must-not-change surfaces |
| `../discussions/prop038-live-implementation-scope-pressure-v0.md` | proceed | All 11 scope checks pass; no blockers; NB-1 authority source and NB-2 public API/facade passthrough resolved by C4-A |
| `../gates/prop038-strict-refusal-live-implementation-scope-decision-v0.md` | accepted-scope-review-implementation-held | Accepts live implementation scope review and authorizes only `prop038-strict-refusal-live-implementation-authorization-review-v0` next; implementation, live refusal, public API/CLI, persisted reports/sidecars, `.igapp`, loader/report, CompatibilityReport, runtime, Gate 3, and production remain closed |
| `stage3-round82-status-curation-v0.md` | done | R82 status curation; records accepted scope review, implementation-held state, preserved closed surfaces, remaining blockers, and R83 authorization-review recommendation |

---

## Stage 3 Round 81 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-strict-refusal-result-shape-proof-orientation-map-v0.md` | active orientation map | C0-O org-sidecar map; separates proof-local result-shape modeling from live compiler behavior, `CompilerResult`, public API/CLI widening, persisted reports, and `.igapp` artifacts; orientation only |
| `prop038-strict-refusal-result-shape-proof-local-v0.md` | done | Proof-local strict-refusal result-shape experiment; PASS with 3 cases / 44 checks / 0 failed; exact 13-key public allowlist, `compilation_report_path: null`, nested diagnostics isolation, wrapper diagnostics, no sidecars, and no `.igapp` target artifacts proven |
| `../discussions/prop038-strict-refusal-result-shape-proof-pressure-v0.md` | proceed | All 11 scope checks pass; no blockers; commands re-run PASS; confirms zero `lib/` or `bin/` changes and carries one non-blocking note about future `report.pass_result` and `configuration_error` public-surface policy |
| `../gates/prop038-strict-refusal-result-shape-proof-acceptance-decision-v0.md` | accepted-proof-local-closure-implementation-held | Accepted R81 proof-local closure and authorized only `prop038-strict-refusal-live-implementation-scope-review-v0`; that scope review was accepted in R82; no live implementation, live refusal, `CompilerResult`, public API/CLI, persisted reports/sidecars, `.igapp`, loader/report, CompatibilityReport, runtime, Gate 3, or production behavior opens |
| `stage3-round81-status-curation-v0.md` | done | R81 status curation; records accepted proof-local closure, implementation-held state, preserved closed surfaces, remaining live blockers, and the R82 scope-review route later accepted by C4-A |

---

## Stage 3 Round 80 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-strict-refusal-result-shape-orientation-map-v0.md` | active orientation map | C0-O org-sidecar map; separates strict-refusal result-shape/non-persisting path design from live refusal implementation, `CompilerResult` mutation, public result widening, and persisted report authorization; orientation only |
| `strict-refusal-result-shape-and-nonpersisting-path-design-v0.md` | done | Design-only strict-refusal result-shape and non-persisting path design; names future `refused` vocabulary, public key allowlist, nested diagnostics isolation, `configuration_error` malformed policy, no-sidecar/no-assembler path, and blockers before implementation |
| `prop038-public-result-and-diagnostics-proof-surface-survey-v0.md` | done | Read-only public result/diagnostics/refusal report/proof-surface survey; maps deny-one `public_result`, nested diagnostics isolation, current sidecar writes, observed CLI key sets, and reusable proof anchors |
| `../discussions/prop038-strict-refusal-result-shape-pressure-v0.md` | proceed | All 11 scope checks pass; no blockers; NB-1 assigns strict-refusal public key-set ownership to future strict-refusal proof; NB-2 accepts null-present `compilation_report_path` convention via C4-A |
| `../gates/prop038-strict-refusal-result-shape-decision-v0.md` | accepted-design-proof-local-next-implementation-held | Accepted strict-refusal result-shape/non-persisting path design and authorized only `prop038-strict-refusal-result-shape-proof-local-v0`; that proof-local route was accepted in R81; implementation, live compile refusal, public API/CLI, `CompilerResult`, persisted reports/sidecars, `.igapp`, loader/report, CompatibilityReport, runtime, Gate 3, and production remain closed |
| `stage3-round80-status-curation-v0.md` | done | R80 status curation; records accepted design, proof-local next route, implementation-held state, preserved closed surfaces, and the R81 proof-local route later accepted by C3-A |

---

## Stage 3 Round 79 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-internal-strict-source-status-orientation-map-v0.md` | active orientation map | C0-O org-sidecar map; distinguishes internal strict-source/status design from implementation, public surface widening, persisted report authorization, and live compile refusal; orientation only |
| `internal-orchestrator-strict-source-and-status-design-v0.md` | done | Design-only internal strict-source/status boundary; recommends constructor-only `CompilerOrchestrator` strict requirement candidate, keeps public API/CLI/manifest closed, defers `CompilerResult`, and recommends new non-persisting strict refusal path as next design candidate |
| `prop038-refusal-report-and-result-surface-survey-v0.md` | done | Read-only refusal/report/result survey; maps existing `CompilerOrchestrator#refusal` sidecar write path, `CompilerResult` status/public result behavior, CLI exit/output behavior, report-only placement, coupling risks, and future test surfaces |
| `../discussions/prop038-internal-strict-source-status-pressure-v0.md` | proceed | All 11 scope checks pass; no blockers; NB-1 routes `public_result` key-set and nested-diagnostics isolation assertions into next design route; malformed strict requirement policy remains open blocker before implementation |
| `../gates/prop038-internal-orchestrator-strict-source-status-decision-v0.md` | accepted-design-implementation-held | Accepted internal strict-source/status design and authorized only `strict-refusal-result-shape-and-nonpersisting-path-design-v0`; that route was accepted in R80; implementation, live compile refusal, public API/CLI, `CompilerResult`, persisted reports/sidecars, `.igapp`, loader/report, CompatibilityReport, runtime, Gate 3, and production remain closed |
| `stage3-round79-status-curation-v0.md` | done | R79 status curation; records accepted design, implementation-held state, preserved closed surfaces, remaining blockers, and the R80 design route later accepted by C4-A |

---

## Stage 3 Round 78 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-live-refusal-boundary-design-orientation-map-v0.md` | active orientation map | C0-O org-sidecar map; separates live-refusal boundary design from authorizing live refusal, compiler behavior changes, public surfaces, persisted artifacts, and runtime/production behavior; orientation only |
| `prop038-live-refusal-implementation-boundary-design-v0.md` | done | Design-only live-refusal boundary map; accepts R77 evidence as proof-local only, keeps implementation held, maps open blockers, recommends internal orchestrator option as next design candidate, and defines graduation rule for `would_refuse` -> `refused` behind a separate gate |
| `prop038-live-refusal-current-pipeline-surface-survey-v0.md` | done | Read-only pipeline survey; maps current refusal points, report-only validation insertion, `report_for_assembly` boundary, public result shaping, CLI behavior, and protected surfaces; no code edited |
| `../discussions/prop038-live-refusal-boundary-design-pressure-v0.md` | proceed | All 8 scope checks pass; no blockers; NB-1 first `compile_refusal_authorized: true` appears only as future design sketch; NB-2 records tension between no-persisted-report recommendation and existing `CompilerOrchestrator#refusal` report write path |
| `../gates/prop038-live-refusal-implementation-boundary-design-decision-v0.md` | accepted-boundary-design-implementation-held | Accepted boundary design and authorized only `internal-orchestrator-strict-source-and-status-design-v0`; that route was accepted in R79; implementation, live compile refusal, public API/CLI, `CompilerResult`, persisted reports/sidecars, `.igapp`, loader/report, CompatibilityReport, runtime, Gate 3, and production remain closed |
| `stage3-round78-status-curation-v0.md` | done | R78 status curation; records accepted boundary design, implementation-held state, preserved closed surfaces, NB-2 next-route obligation, and the R79 design route later accepted by C4-A |

---

## Stage 3 Round 77 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-strict-mode-refusal-trigger-proof-local-boundary-map-v0.md` | active orientation map | C0-O org-sidecar boundary map; distinguishes proof-local `would_refuse` from live compiler refusal, public API/CLI behavior, `CompilerResult`, persisted artifacts, loader/report, CompatibilityReport, runtime, and production behavior; orientation only |
| `prop038-strict-mode-refusal-trigger-proof-local-v0.md` | done | Proof-local strict-mode trigger experiment; PASS with 12 cases / 15 checks / 0 failed; only `contract_digest_mismatch` maps to proof-local `would_refuse`; no `igniter-lang/lib` files changed |
| `../discussions/prop038-strict-mode-refusal-trigger-proof-local-pressure-v0.md` | proceed | All 9 scope checks pass; no blockers; NB-1 accepts the expected report-only integration rerun artifact; confirms `would_refuse` proof-local only, `refused` absent, and `compile_refusal_authorized=false` across all cases |
| `../gates/prop038-strict-mode-refusal-trigger-proof-local-acceptance-decision-v0.md` | accepted-proof-local-trigger-closure | Accepts the bounded proof-local trigger experiment and closes the S3-R76 authorization; its design route was accepted in R78; live refusal/compiler behavior, public API/CLI, `CompilerResult`, `.igapp`, loader/report, CompatibilityReport, runtime, Gate 3, and production remain closed |
| `stage3-round77-status-curation-v0.md` | done | R77 status curation; records accepted proof-local closure, preserved closed surfaces, remaining live-refusal blockers, and the R78 design route later accepted by C4-A |

---

## Stage 3 Round 76 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-contract-digest-strict-mode-refusal-trigger-boundary-map-v0.md` | active orientation map | C0-O org-sidecar boundary map; separates strict-mode/refusal trigger design from enabling refusal, compiler/orchestrator behavior changes, public surfaces, persisted artifacts, and production authority; orientation only |
| `prop038-contract-digest-strict-mode-refusal-trigger-design-v0.md` | done | Design-only strict-mode/refusal trigger semantics; recommends gate-controlled proof-local strict source, wrapper vocabulary, fail-open recompute policy, and proof-local matrix without enabling refusal |
| `prop038-strict-mode-current-compiler-surface-survey-v0.md` | done | Read-only survey of current compiler/report/CLI surface; maps provider entry point, no-field/no-refusal paths, public result boundary, and "must not infer strict mode" list |
| `../discussions/prop038-strict-mode-refusal-trigger-design-pressure-v0.md` | proceed | All 9 scope checks pass; no blockers; two non-blocking notes resolved by C4-A; confirms `would_refuse` proof vocabulary, gate-controlled source, fail-open recompute, and preserved legacy paths |
| `../gates/prop038-strict-mode-refusal-trigger-design-decision-v0.md` | accepted-design-authorized-proof-local-experiment | Accepted design and authorized only `prop038-strict-mode-refusal-trigger-proof-local-v0`; that proof-local route was satisfied and closed in R77; live refusal/compiler behavior, public API/CLI, `CompilerResult`, `.igapp`, loader/report, CompatibilityReport, runtime, Gate 3, and production remain closed |
| `stage3-round76-status-curation-v0.md` | done | R76 status curation; records accepted design, proof-local-only next route later satisfied and closed in R77, candidate statuses, and preserved closed surfaces |

---

## Stage 3 Round 75 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-contract-digest-refusal-preconditions-boundary-map-v0.md` | active orientation map | C0-O org-sidecar refusal-boundary map; separates precondition design from enabling refusal, compiler integration, public surfacing, persisted artifacts, and production authority; orientation only |
| `prop038-contract-digest-compile-refusal-preconditions-design-v0.md` | done | Design-only refusal precondition map; keeps report-only behavior live, compile refusal closed, and names future candidate/blocker matrix without enabling behavior |
| `../discussions/prop038-contract-digest-compile-refusal-preconditions-pressure-v0.md` | proceed | All 8 scope checks pass; no blockers or notes; confirms five vocabulary layers, nil/non-Hash/provider-error legacy behavior, proof requirements, and forbidden surfaces |
| `../gates/prop038-contract-digest-compile-refusal-preconditions-decision-v0.md` | accepted-preconditions-design-refusal-held | Accepts preconditions design; no `contract_digest_*` diagnostic is authorized as compile-refusal behavior; its authorized strict-mode/refusal trigger design route was resolved in R76 |
| `stage3-round75-status-curation-v0.md` | done | R75 status curation; records accepted preconditions design, closed refusal boundary, candidate statuses, blockers, and the R76 strict-mode/refusal trigger design route later accepted by C4-A |

---

## Stage 3 Round 74 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-contract-digest-live-validator-implementation-boundary-map-v0.md` | active orientation map | C0-O org-sidecar implementation-boundary map; distinguishes validator-only implementation from compiler/orchestrator integration, compile refusal, public/report surfacing, persisted artifacts, and production authority; orientation only |
| `prop038-contract-digest-live-validator-implementation-v0.md` | done | Implements all four accepted `contract_digest_*` diagnostics inside `IgniterLang::CompilerProfileContractValidator`; validator API/result shape unchanged; proof summaries PASS 13/30, 8/20, 14/16, 12/21 |
| `../discussions/prop038-contract-digest-live-validator-implementation-pressure-v0.md` | proceed | All 9 scope checks pass; no blockers or notes; changed files inside authorized scope; canonicalization, mutation safety, result shape, report-only/no-refusal, non-stdlib require and untouched surface checks pass |
| `../gates/prop038-contract-digest-live-validator-implementation-acceptance-decision-v0.md` | accepted-live-validator-implementation-closure | Accepts bounded live validator implementation only inside `IgniterLang::CompilerProfileContractValidator`; compile refusal remains closed; its only authorized preconditions-design route was resolved in R75 |
| `stage3-round74-status-curation-v0.md` | done | R74 status curation; records implementation acceptance, proof matrix, preserved closed surfaces, and the R75 refusal-preconditions design route later accepted by C3-A |

---

## Stage 3 Round 73 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-contract-digest-live-design-boundary-map-v0.md` | active orientation map | C0-O org-sidecar boundary map; distinguishes design-only live validator planning from implementation, compiler integration, compile refusal, public/report surfacing, and production authority; orientation only |
| `prop038-contract-digest-live-implementation-design-v0.md` | done | Designs one bounded internal validator slice for all four `contract_digest_*` diagnostics; keeps validator API/result shape unchanged; requires private canonicalization helpers and report-only/no-refusal invariants |
| `prop038-contract-digest-live-implementation-surface-survey-v0.md` | done | Read-only implementation surface survey; confirms minimal validator-only surface, canonicalization risk, proof updates, and untouched public/compiler/runtime surfaces |
| `../discussions/prop038-contract-digest-live-implementation-design-pressure-v0.md` | proceed-with-notes | All 9 scope checks pass; no blockers; NB-1 helper naming is non-authority, NB-2 proof directories need explicit write scope; no public/compiler/orchestrator/refusal/runtime authority implied |
| `../gates/prop038-contract-digest-live-implementation-design-decision-v0.md` | accepted-design-authorized-one-slice-validator-implementation | Accepts design and authorizes only one bounded internal validator implementation card: `prop038-contract-digest-live-validator-implementation-v0`; compiler/orchestrator integration, compile refusal, public API/CLI, loader/report, CompatibilityReport, runtime, and production remain closed |
| `stage3-round73-status-curation-v0.md` | done | R73 status curation; records accepted design, narrow implementation authorization, closed pressure notes, next R74 implementation route, and preserved excluded surfaces |

---

## Stage 3 Round 72 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-contract-digest-errata-canon-sync-boundary-map-v0.md` | active orientation map | C0-O org-sidecar canon-sync boundary map; distinguishes PROP-038 errata/design authoring from implementation, compile refusal, public/report surfacing, and production authority; orientation only |
| `prop038-contract-digest-errata-authoring-v0.md` | done | Updates PROP-038 with accepted `contract_digest` design/errata text; records four diagnostic codes, nested placement, report-only invariants, canonicalization material, and R69/R70/R71 proof-chain references; documentation-only |
| `../discussions/prop038-contract-digest-errata-pressure-v0.md` | proceed | All 9 scope checks pass; no blockers or notes; confirms §10 four-code vocabulary, §9.6 R70 canonicalization match, §10.2 placement, closed compile refusal, held live implementation, and documentation-only authoring |
| `../gates/prop038-contract-digest-errata-acceptance-decision-v0.md` | accepted-errata-design-closure | Accepts PROP-038 `contract_digest` errata/design closure; vocabulary canon as design vocabulary; authorizes only `prop038-contract-digest-live-implementation-design-v0` next; no implementation/refusal/public/runtime authority |
| `stage3-round72-status-curation-v0.md` | done | R72 status curation; records errata/design acceptance, canon design vocabulary, next design-only planning route, and preserved closed surfaces |

---

## Stage 3 Round 71 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-contract-digest-report-only-integration-boundary-map-v0.md` | active orientation map | C0-O org-sidecar boundary map; separates proof-local report-only digest integration from live validator implementation, compiler authority, compile refusal, persisted reports, public surfacing, and production behavior; orientation only |
| `prop038-contract-digest-report-only-integration-proof-v0.md` | done | Proof-local report-only integration model; 12 cases / 21 checks PASS; all four digest diagnostics stay nested under `compiler_profile_contract_validation.diagnostics`; R70/R69/R67 and validator regressions remain PASS |
| `../discussions/prop038-contract-digest-report-only-integration-proof-pressure-v0.md` | proceed | All 9 scope checks pass; no blockers or notes; R70 NB-1 closed by restored `non_authorizations_preserved`; no live implementation/refusal/public/runtime authority |
| `../gates/prop038-contract-digest-report-only-integration-proof-decision-v0.md` | accepted-proof-local-report-only-integration-closure | Accepts proof-local report-only integration closure; three-phase digest chain complete for design purposes; authorizes only `prop038-contract-digest-errata-authoring-v0`; live validator/compiler implementation and compile refusal remain closed |
| `stage3-round71-status-curation-v0.md` | done | R71 status curation; records report-only integration proof acceptance, three-phase chain closure, R70 NB-1 closure, next errata/design route, and preserved closed surfaces |

---

## Stage 3 Round 70 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-contract-digest-recompute-proof-boundary-map-v0.md` | active orientation map | C0-O org-sidecar boundary map; separates proof-local canonicalization/recompute evidence from live validator implementation, digest authority, compile refusal, public/report surfacing, and production behavior; orientation only |
| `prop038-contract-digest-recompute-match-proof-v0.md` | done | Proof-local recompute-match/canonicalization model; 14 cases / 15 checks PASS; shape-policy proof, validator matrix, and R67 report-only integration remain PASS |
| `../discussions/prop038-contract-digest-recompute-match-proof-pressure-v0.md` | proceed-with-note | All 10 scope checks pass; no blockers; NB-1 requires future summaries to restore `non_authorizations_preserved` for hold-inventory traceability |
| `../gates/prop038-contract-digest-recompute-match-proof-decision-v0.md` | accepted-proof-local-recompute-match-closure | Accepts proof-local recompute-match closure and authorizes only proof-local `prop038-contract-digest-report-only-integration-proof-v0`; live validator/compiler implementation, compile refusal, public API/CLI, loader/report, CompatibilityReport, runtime, and production remain closed |
| `stage3-round70-status-curation-v0.md` | done | R70 status curation; records recompute-match proof acceptance, four-code digest vocabulary proof coverage, NB-1, next report-only integration proof route, and preserved closed surfaces |

---

## Stage 3 Round 69 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-contract-digest-shape-proof-boundary-map-v0.md` | active orientation map | C0-O org-sidecar boundary map; separates proof-local shape evidence from live validator implementation, recompute-match integrity proof, compile refusal, public/report surfacing, and production authority; orientation only |
| `prop038-contract-digest-shape-policy-proof-v0.md` | done | Proof-local model for `contract_digest` shape policy under `prop038_24_plus`; 8 cases / 19 checks PASS; existing validator matrix and R67 report-only integration remain PASS |
| `../discussions/prop038-contract-digest-shape-policy-proof-pressure-v0.md` | proceed | All 8 scope checks pass; no blockers or notes; confirms exact 2 diagnostic candidates, no recompute/integrity proof, no live validator/compiler change, and no refusal/public/runtime authority |
| `../gates/prop038-contract-digest-shape-policy-proof-decision-v0.md` | accepted-proof-local-shape-policy-closure | Accepts proof-local shape-policy closure and authorizes only proof-local `prop038-contract-digest-recompute-match-proof-v0`; live validator/compiler implementation, compile refusal, public API/CLI, loader/report, CompatibilityReport, runtime, and production remain closed |
| `stage3-round69-status-curation-v0.md` | done | R69 status curation; records shape-policy proof acceptance, diagnostic candidate status, recompute-match next route, and preserved closed surfaces |

---

## Stage 3 Round 68 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-contract-digest-policy-map-v0.md` | active orientation map | C0-O org-sidecar map; separates descriptor digest, finalization payload digest, `contract_digest`, canonicalization, validation level, and authority effects; orientation only |
| `prop038-contract-digest-validation-policy-design-v0.md` | done | Designs hybrid policy: current validator remains `prop038_24_plus` report-only with no `contract_digest` check; future shape-only proof precedes recompute-match proof |
| `../discussions/prop038-contract-digest-validation-policy-pressure-v0.md` | proceed | All 7 scope checks pass; no blockers or notes; confirms descriptor/contract separation, explicit canonicalization material, report-only invariant, and no hidden implementation authority |
| `../gates/prop038-contract-digest-validation-policy-decision-v0.md` | accepted-authorized-proof-local-shape-policy | Accepts hybrid policy design and authorizes only proof-local `prop038-contract-digest-shape-policy-proof-v0`; implementation, compile refusal, public API/CLI, persisted reports, loader/report, CompatibilityReport, runtime, and production remain closed |
| `stage3-round68-status-curation-v0.md` | done | R68 status curation; records digest-policy acceptance, proof-local next route, existing no-check behavior, and preserved closed surfaces |

---

## Stage 3 Round 67 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-report-only-leakage-watch-v0.md` | active orientation note | C0-O org-sidecar leakage watch; distinguishes internal annotation from public output, refusal, persisted reports, loader/report, CompatibilityReport, and production surfaces; orientation only |
| `prop038-report-only-compiler-integration-implementation-v0.md` | done | Implements Candidate A: constructor-only `compiler_profile_contract_provider` on `CompilerOrchestrator` plus in-memory `CompilationReport` field; proof PASS with 5 cases and 20 checks |
| `../discussions/prop038-report-only-compiler-integration-implementation-pressure-v0.md` | proceed | All 9 scope checks pass; no blockers or non-blocking notes; unchanged public result/refusal behavior, no persisted success report, no sidecar, no `.igapp` manifest mutation |
| `../gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md` | accepted-report-only-closure | Accepts bounded Candidate A and closes the R66 implementation authorization; future persisted reports, sidecars, contract-digest validation, report surfacing, public API/CLI, or compile refusal require a new design/pressure/Architect chain |
| `stage3-round67-status-curation-v0.md` | done | R67 status curation; records internal annotation closure, proof result, leakage watch, and preserved closed surfaces |

---

## Stage 3 Round 66 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-report-integration-boundary-map-v0.md` | active orientation map | C0-O org-sidecar boundary map; records current accepted validator surface, report-only touchpoint risks, forbidden transitions, digest/canonicalization risks, and safe future design checklist; orientation only |
| `prop038-report-only-compiler-integration-design-v0.md` | done | Design-only Candidate A: internal `compiler_profile_contract_provider` on `CompilerOrchestrator`, in-memory `CompilationReport` annotation, report-only and never refusal; options B-D/G held, E/F rejected |
| `../discussions/prop038-report-only-compiler-integration-design-pressure-v0.md` | proceed | All 8 scope checks pass; no blockers; NB-1 provider callable/exception policy and NB-2 `compiler_integrated=false` semantics routed into C3-A |
| `../gates/prop038-report-only-compiler-integration-design-decision-v0.md` | accepted-authorized-bounded-report-only-implementation | Accepts the design and authorizes only next Candidate A implementation; R67 later accepts/closes that implementation |
| `stage3-round66-status-curation-v0.md` | done | R66 status curation; records design acceptance, bounded next implementation authorization, org-sidecar boundary map, and then-preserved closed surfaces |

---

## Stage 3 Round 65 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/prop038-implementation-surface-watch-map-v0.md` | active orientation map | C0-O org-sidecar watch map; records authorized C1-I surfaces, prohibited compiler/report/runtime/public surfaces, proof parity obligations, digest/diagnostic deferrals, and handoff risks; orientation only |
| `prop038-library-validator-extraction-implementation-v0.md` | done | Creates internal `IgniterLang::CompilerProfileContractValidator`; proof script calls validator; summary PASS with 13 cases, 13 validator matrix rows, and 27 checks |
| `../discussions/prop038-library-validator-extraction-implementation-pressure-v0.md` | proceed | All 9 scope checks pass; no blockers or notes; write scope stayed authorized, no facade require, 10 diagnostic codes only, `contract_digest` still deferred, all 15 non-authorization flags false |
| `../gates/prop038-library-validator-extraction-acceptance-decision-v0.md` | accepted-extraction-closure | Accepts bounded internal extraction and closes R64 implementation authorization; report-only integration, compile refusal, CLI/API, runtime, and production remain closed |
| `stage3-round65-status-curation-v0.md` | done | R65 status curation; records internal validator extraction closure, proof parity, org-sidecar watch map, and then-preserved closed surfaces; R66 later accepts the report-only design |

---

## Stage 3 Round 64 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../org/indexes/compiler-code-and-experiment-map-v0.md` | active orientation map | C0-O org-sidecar blueprint; path-indexes production compiler spine, proof families, authority/evidence layers, and protected surfaces; orientation only, not authority |
| `../org/reports/compiler-blueprint-orientation-v0.md` | done | C0-O compact report; recommends a future PROP-038 implementation-surface watch map before broader archaeology |
| `prop038-library-validator-extraction-design-v0.md` | done | Option B design: internal `CompilerProfileContractValidator.validate(contract, digest_reference_policy: :prop038_24_plus)`, local diagnostics, caller-supplied Hash input, proof-parity only, non-integrated and non-refusal |
| `../discussions/prop038-library-validator-extraction-design-pressure-v0.md` | proceed | All 9 scope checks pass; no blockers; NB-1 records intentional deferral of `contract_digest` format/mismatch validation |
| `../gates/prop038-library-validator-extraction-design-decision-v0.md` | accepted-authorized-bounded-option-b-implementation | Accepts the design and authorizes only the next bounded internal proof-parity implementation card; compiler integration, report/refusal, CLI/API, runtime, and production remain closed |
| `stage3-round64-status-curation-v0.md` | done | R64 status curation; records design acceptance, bounded internal implementation authorization, org-sidecar blueprint, and preserved closed surfaces |

---

## Stage 3 Round 63 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop038-proof-local-missing-after-implementation-v0.md` | done | Proof-local implementation only; adds `missing_after_rule_reference`; summary PASS with 13 cases and 23 checks; diagnostics remain in proof script |
| `../discussions/prop038-proof-local-missing-after-pressure-v0.md` | proceed | All 7 scope checks pass; no blockers or non-blocking notes; R60 missing-`after` NB is machine-closed; report-only integration and compile refusal remain held |
| `../gates/prop038-proof-local-missing-after-acceptance-decision-v0.md` | accepted-proof-local-closure | Accepts the proof-local implementation, closes R62 Option A for the named gap, and opens only design-only library validator extraction planning for R64 |
| `stage3-round63-status-curation-v0.md` | done | R63 status curation; records proof-local closure, held compiler/library integration, held report/refusal behavior, and org-sidecar pilot as optional/non-authority |

---

## Stage 3 Round 62 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop038-compiler-profile-contract-implementation-scope-survey-v0.md` | done | Survey-only; maps 10 write-surface options, recommends proof-local Option A first, holds report-only integration and compile-refusal behavior |
| `../discussions/prop038-implementation-scope-pressure-v0.md` | proceed | All 8 scope checks pass; no blockers; missing-`after` coverage belongs in the first proof-local card; forbidden runtime/production/report/refusal surfaces remain closed |
| `../gates/prop038-compiler-profile-contract-implementation-authorization-decision-v0.md` | authorized-proof-local-only | Authorizes only the next proof-local implementation under `experiments/compiler_profile_contract_proof/`; descriptor digest input material remains deferred for integrated/persisted behavior |
| `stage3-round62-status-curation-v0.md` | done | R62 status curation; records scope survey complete, proof-local-only authorization, org sidecar non-authority boundary, and preserved runtime/production closures |

---

## Stage 3 Round 61 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop038-compiler-profile-contract-authoring-v0.md` | done | Authored PROP-038 for `compiler_profile_contract`; indexed proposal, moved managed local recursion / loop-class placeholder to PROP-039+, set ordered-rule `stage` as informational metadata, and kept progression under `pipeline` |
| `../discussions/prop038-compiler-profile-contract-pressure-v0.md` | proceed | All 10 scope checks pass; 17 required sections present; 14 acceptance criteria met; two non-blocking digest follow-ups preserved; no implementation/runtime/production authority implied |
| `../gates/prop038-compiler-profile-contract-acceptance-decision-v0.md` | accepted-proposal-only-implementation-held | Accepts PROP-038 as proposal-only, keeps implementation held, and opens only implementation scope survey / authorization prep for R62 |
| `stage3-round61-status-curation-v0.md` | done | R61 status curation; records PROP authoring complete, PROP accepted proposal-only, implementation held, and production/runtime authority closed |

---

## Stage 3 Round 60 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `compiler-profile-contract-validator-coverage-proof-v0.md` | done | Extends proof-local contract experiment; 12 validator cases and 22 checks PASS; five R59 validator blockers covered; positional lookup debt and optional fragment-owner coverage closed |
| `../discussions/compiler-profile-contract-validator-coverage-pressure-v0.md` | proceed | All required validator paths are machine-asserted; R58 shape and namespace separation preserved; `stage` remains PROP-scope; no implementation/runtime/production authority implied |
| `../gates/compiler-profile-contract-validator-coverage-decision-v0.md` | accepted-prop-authoring-next | Accepts validator coverage, lifts R59 authoring hold, assigns PROP-038 to `compiler_profile_contract`, and authorizes only PROP authoring next; implementation and production/runtime authority remain closed |
| `stage3-round60-status-curation-v0.md` | done | R60 status curation; records accepted validator coverage, PROP-038 authoring-only route, and preserved implementation/runtime closures |

---

## Stage 3 Round 59 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `compiler-profile-contract-schema-and-rule-ownership-pressure-v0.md` | done | Compiler/Grammar ownership record accepted for slot schema/order/assignments, strict registries, one-owner semantics, ordered-rule graph, rule cycles/references, diagnostics, and future `profile_not_supplied`; PROP authoring held |
| `../discussions/compiler-profile-contract-schema-ownership-pressure-v0.md` | proceed | All 7 scope checks pass; C1 avoids implementation authorization; five validator paths remain required before PROP authoring; stage field status and optional fragment-owner duplicate coverage are non-blocking notes |
| `../gates/compiler-profile-contract-prop-authoring-decision-v0.md` | hold-validator-coverage-proof-next | Accepts R59 formal ownership record; holds new PROP authoring; authorizes only proof-local `compiler-profile-contract-validator-coverage-proof-v0`; implementation and production/runtime authority remain closed |
| `stage3-round59-status-curation-v0.md` | done | R59 status curation; records accepted formal pressure, held PROP authoring, R60 validator coverage proof route, and preserved authority closures |

---

## Stage 3 Round 58 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `compiler-profile-contract-proof-v0.md` | done | Proof-local canonical `compiler_profile_contract` experiment PASS; six cases and 16 machine-asserted checks cover object shape, diagnostics, source projection, future `profile_not_supplied`, execution order, and disclaimer |
| `../discussions/compiler-profile-contract-proof-pressure-v0.md` | proceed | All 7 scope checks pass; proof is behavioral; diagnostic namespaces and loader/source/obligation separation are machine-asserted; NB-1/NB-2 routed before PROP authoring |
| `../gates/compiler-profile-contract-proof-decision-v0.md` | accepted-proof-formal-pressure-next | Accepts proof as proof-local/behavioral/report-only/non-authorizing; opens only `compiler-profile-contract-schema-and-rule-ownership-pressure-v0`; PROP authoring and implementation remain held |
| `stage3-round58-status-curation-v0.md` | done | R58 status curation; records proof acceptance, pre-PROP formal pressure route, and preserved implementation/runtime closures |

---

## Stage 3 Round 57 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `compiler-profile-contract-boundary-v0.md` | done | Design-only contract boundary: four vocabularies separated; lifecycle placement accepted as future SemanticIR profile-obligation checkpoint after emit/before assembly; no implementation |
| `compiler-profile-contract-bridge-surface-review-v0.md` | done | Bridge/report pressure only; future loader/report and CompatibilityReport needs mapped as report-only, no schema or implementation |
| `../discussions/compiler-profile-contract-boundary-pressure-v0.md` | proceed | All 6 scope checks pass; R56 NB-1/NB-2 resolved; NB-1 design sequence disclaimer and NB-2 execution ordering routed to proof scope |
| `../gates/compiler-profile-contract-boundary-decision-v0.md` | accepted-design-proof-next | Accepts R57 design record and authorizes only proof-local `compiler-profile-contract-proof-v0`; no implementation |
| `stage3-round57-status-curation-v0.md` | done | R57 status curation; records accepted boundary design, R58 proof-local route, and preserved authority closures |

---

## Stage 3 Round 56 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `compiler-profile-obligation-coverage-proof-v0.md` | done | Proof-local `CompilerProfileObligationReport`; command PASS, syntax OK, 18 checks PASS; selected current artifacts unchanged; statuses are `covered`, `missing_slot`, `unsupported_surface`, `profile_not_supplied` |
| `../discussions/compiler-profile-obligation-coverage-proof-pressure-v0.md` | proceed | All 7 scope checks pass; output-only machine-asserted; `missing_slot` is report-not-gate; slot map gate-aligned; NB-1/NB-2 are future vocabulary/shape notes |
| `../gates/compiler-profile-obligation-coverage-proof-decision-v0.md` | accepted-proof-design-next | Accepts the obligation coverage proof and authorizes only `compiler-profile-contract-boundary-v0` as the next design-only track; no implementation |
| `stage3-round56-status-curation-v0.md` | done | R56 status curation; records accepted proof, design-only R57 route, and preserves implementation/runtime closure |

---

## Stage 3 Round 55 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `language-profile-compiler-obligation-map-v0.md` | done | Maps active/accepted language surfaces to compiler profile slots; identifies report-only obligation coverage as the missing middle before loader/report, CompatibilityReport, dispatch, or golden migration |
| `compiler-profile-contract-formalization-options-v0.md` | done | Compares descriptor-only, slot, ordered-rule, pack-registry, and hybrid compiler profile contract options; recommends proof/design route before any implementation |
| `../discussions/compiler-profile-contract-pressure-v0.md` | proceed-with-notes | Thesis is evidence-backed; authority lanes remain clean; sequencing and PROP-037 progression-slot question routed to C4-A |
| `../gates/compiler-profile-next-axis-decision-v0.md` | approved-proof-only-obligation-coverage-first | Authorizes only `compiler-profile-obligation-coverage-proof-v0` as proof-local/report-only next axis; implementation and production/runtime authority remain closed |
| `stage3-round55-status-curation-v0.md` | done | R55 status curation; records obligation coverage first and preserves PROP-036 CLI release-confidence versus compiler/profile next-axis separation |

---

## Stage 3 Round 54 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop036-cli-release-confidence-smoke-v0.md` | done | Caller-style smoke 5/5 PASS for no-flag legacy compile, valid bounded profile-source path, bad-path refusal, malformed JSON refusal, and semantic unfinalized-source refusal; no code/golden mutation |
| `prop036-cli-docs-navigation-polish-v0.md` | done | Adds `docs/README.md` pointer to `ruby-api.md#cli-compiler-profile-source-transport`; wording says only exact bounded shape and no production/runtime authority |
| `../discussions/prop036-cli-release-confidence-pressure-v0.md` | proceed | R54 strengthens release confidence; smoke matches R52 gate spec; navigation anchor correct; no forbidden-surface implication or production-deployment vocabulary drift |
| `stage3-round54-status-curation-v0.md` | done | R54 status curation; records release-confidence/docs-navigation strengthening and preserves production/runtime closure |

---

## Stage 3 Round 53 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop036-cli-release-readiness-docs-sync-v0.md` | done | Updates `docs/ruby-api.md` with exact bounded CLI surface, finalized source input shape, legacy/no-flag behavior, refusal shapes, transport-only semantics, no discovery/defaulting/finalization, and excluded surfaces |
| `../discussions/prop036-cli-release-readiness-docs-pressure-v0.md` | proceed | R52 docs condition satisfied; all eight items verified; prohibited-surface closure confirmed; NB-1 docs-navigation link closed later in R54 |
| `stage3-round53-status-curation-v0.md` | done | R53 status curation; records bounded CLI transport fully release-ready in exact R52 package scope and preserves production/runtime closure |

---

## Stage 3 Round 52 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/prop036-cli-release-readiness-decision-v0.md` | conditional-release-readiness-doc-sync-required | Conditionally approves package-surface release-readiness for exact bounded `--compiler-profile-source PATH.json` transport; docs sync condition later satisfied in R53; no production/runtime/Gate 3 authority |
| `../discussions/prop036-cli-release-readiness-pressure-v0.md` | proceed | All six scope checks pass; conditional gate is correctly structured; NB-1 is terminology orientation only; R53 docs sync recommended |
| `stage3-round52-status-curation-v0.md` | done | R52 status curation; records conditional release-readiness state and routes docs-only R53 condition sync |

---

## Stage 3 Round 51 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/prop036-cli-remaining-blockers-formal-closure-decision-v0.md` | approved-remaining-cli-blockers-formally-closed | Formally closes `PROP036-CLI-B3/B4/B5/B6/B9`; full `PROP036-CLI-B1..B9` blocker package closed; no production/readiness or surface widening authorized |
| `../discussions/prop036-cli-remaining-blockers-closure-pressure-v0.md` | proceed | All five scope checks pass; B2 citation gap resolved; no implementation or production readiness implied; NB-1 is orientation-only |
| `stage3-round51-status-curation-v0.md` | done | R51 status curation; records full blocker package closure and routes R52 production/release readiness gate |

---

## Stage 3 Round 50 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/prop036-cli-b3-b6-implementation-authorization-review-v0.md` | approved-bounded-cli-implementation-proof | Authorizes only bounded `--compiler-profile-source PATH.json` transport/proof in `IgniterLang::CLI`; explicitly does not close B3/B4/B5/B6/B9 |
| `prop036-cli-profile-source-b3-b6-implementation-proof-v0.md` | done | Implements bounded CLI transport and proof-local matrix; 12/12 cases PASS, 4/4 command matrix PASS, forbidden exact-token hits 0, B6 scanner self-tests true |
| `../discussions/prop036-cli-profile-source-implementation-pressure-v0.md` | proceed | All nine scope checks pass; B3/B4/B5/B6 evidence complete and ready for formal closure review; B9 satisfied by this pressure review; no blockers |
| `stage3-round50-status-curation-v0.md` | done | R50 status curation; records evidence complete before R51 closure for B3/B4/B5/B6/B9; R51 later closes the package |

---

## Stage 3 Round 49 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/prop036-cli-b1-formal-closure-decision-v0.md` | approved-b1-formally-closed-implementation-held | Formally closes `PROP036-CLI-B1` from R48 artifact/proof and pressure evidence; B3/B4/B5/B6/B9 later close in R51; CLI implementation/path loading remains held |
| `../discussions/prop036-cli-b1-formal-closure-pressure-v0.md` | proceed | All five scope checks pass; closure uses gate authority, does not imply implementation readiness, names remaining blockers, and does not overstate R48 evidence; NB: B2 gate-path citation debt only |
| `stage3-round49-status-curation-v0.md` | done | R49 status curation; closes cards dispatch layer, records B1 formally closed by S3-R49-C1-A, and keeps CLI implementation held |

---

## Stage 3 Round 48 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop036-cli-b1-standalone-artifact-proof-v0.md` | done | Emits proof-owned standalone `compiler_profile_source.stage3_proof.json`, validates through `finalization_and_assembler_source_contract`, records required fields, exact forbidden hits 0; proof PASS 27/27 and assembler regression PASS 19/19; recommends B1 closed |
| `../discussions/prop036-cli-b1-standalone-artifact-pressure-v0.md` | proceed | Independently verifies all B1 artifact criteria; no loader-status vocabulary, CLI path-loading, runtime authority, or wider implementation implication; NB formal gate acceptance later resolved by R49 C1-A |
| `stage3-round48-status-curation-v0.md` | done | R48 status curation; closes cards dispatch layer, records B1 as partial in living maps, and keeps CLI implementation held |

---

## Stage 3 Round 47 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop036-cli-b7-b8-ruby-api-docs-v0.md` | done | Lands `docs/ruby-api.md` and README navigation; public docs cover source shape, nil behavior, non-authorized surfaces, transport-only wording; recommends B7/B8 closed |
| `prop036-cli-closure-criteria-precision-addendum-prep-v0.md` | done | Prepares minor Architect addendum wording for R46 pressure notes: B6 scanner self-test, B8-C Architect-owned deferral authority, and B1 validation-chain specificity; no gate edit or CLI implementation authorization |
| `../gates/prop036-b7-b8-docs-and-criteria-precision-review-v0.md` | approved-b7-b8-docs-closed-implementation-held | Closes B7/B8; Architect-defers source-level comment visibility for this phase; adopts B1/B6/B8-C precision amendments; implementation remains held |
| `../discussions/prop036-b7-b8-docs-and-criteria-pressure-v0.md` | proceed | No blockers; verifies public docs, transport-only wording, Architect-level deferral, and binding precision amendments; NB: C1-P1 track-level B8-C deferral claim superseded by C3-A |
| `stage3-round47-status-curation-v0.md` | done | R47 status curation; closes cards dispatch layer and updates current maps |

---

## Stage 3 Round 46 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop036-cli-b1-standalone-source-artifact-closure-v0.md` | done | Defines B1 closure as artifact + docs: proof-owned standalone `compiler_profile_source.stage3_proof.json`, named generation command, validation, forbidden-token scan, and non-authorizations |
| `prop036-cli-b3-refusal-shape-and-b6-scan-scope-v0.md` | done | Resolves B3 with hybrid refusal shape: CLI profile-source path/JSON preflight is stderr-only/no artifacts; compiler/orchestrator refusals keep compiler_result + compilation_report; maps exact B3 -> B6 scan surface; no CLI implementation authorization |
| `prop036-cli-b7-b8-docs-completion-bar-v0.md` | done | Defines B7/B8 completion bars: public `docs/ruby-api.md` or approved API path, docs README link, transport-only wording, and source-level visibility landed or explicitly deferred |
| `../gates/prop036-cli-blocker-closure-criteria-decision-v0.md` | approved-closure-criteria-implementation-held | Governing closure-criteria supplement for B1/B3/B6/B7/B8; CLI implementation/path loading remains held |
| `../discussions/prop036-cli-blocker-closure-criteria-pressure-v0.md` | proceed-with-notes | No blockers; non-blockers route B6 scanner self-test, B8-C deferral authority, and B1 validation-chain specificity |
| `stage3-round46-status-curation-v0.md` | done | R46 status curation; closes cards dispatch layer and updates current maps |

---

## Stage 3 Round 45 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop036-cli-exposure-input-shape-options-v0.md` | done | Design-only comparison; immediate hold; future first CLI shape should be explicit `--compiler-profile-source PATH.json`; inline JSON, named lookup, discovery/defaulting rejected |
| `prop036-facade-source-contract-hardening-v0.md` | done | Dev-contract wording for finalized `compiler_profile_id_source` and transport-only Ruby facade; guide/API docs still pending |
| `../gates/prop036-cli-exposure-design-and-blocker-tracking-decision-v0.md` | approved-design-route-implementation-held | Approves future CLI design route only; implementation held behind `PROP036-CLI-B1..B9`; no CLI code/path loading or wider behavior authorized |
| `../discussions/prop036-cli-exposure-design-pressure-v0.md` | proceed-with-notes | No blockers for design; B1 closure criterion, B3 refusal shape/B6 scan surface, and B7/B8 completion bars need tightening before implementation authorization |
| `stage3-round45-status-curation-v0.md` | done | R45 status curation; closes cards dispatch layer and updates current maps |

---

## Stage 3 Round 44 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop036-post-orchestrator-negative-artifact-scan-v0.md` | done | Refreshes PROP-036 proof outputs and scans 49 JSON artifacts/refusal reports; 0 exact forbidden loader-status/runtime-readiness token hits |
| `../gates/prop036-cli-api-exposure-authorization-review-v0.md` | approved-bounded-ruby-facade-exposure | Authorizes only `IgniterLang.compile(..., compiler_profile_source:)` transport of a caller-supplied finalized source; CLI/path loading/finalization/defaulting and all wider surfaces remain closed |
| `prop036-ruby-facade-profile-source-exposure-v0.md` | done | Adds optional Ruby facade keyword and forwards unchanged; proof PASS 7/7; exact forbidden-token scan over 29 JSON/refusal artifacts has 0 hits |
| `prop036-post-cli-api-exposure-regression-chain-v0.md` | done | Post-exposure regression PASS; nil/default legacy preserved across facade, CLI, orchestrator, production CLI; 88 JSON files scanned with 0 exact forbidden hits |
| `../discussions/prop036-cli-api-profile-source-pressure-v0.md` | proceed-with-notes | No blockers; non-blockers are caller-facing source-shape docs, explicit transport-only contract wording, and CLI blocker tracking |
| `stage3-round44-status-curation-v0.md` | done | R44 status curation; closes cards dispatch layer and updates current maps |

---

## Stage 3 Round 43 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop036-orchestrator-profile-source-pass-through-v0.md` | done | Implements bounded `CompilerOrchestrator#compile(compiler_profile_source: nil)` pass-through to assembler; 11/11 PASS; no finalization/discovery/defaulting/loader/report/runtime behavior |
| `prop036-post-orchestrator-regression-chain-v0.md` | done | Regression chain PASS: orchestrator syntax, C1 proof, `igapp_assembler_proof`, `production_compiler_cli_proof`, and legacy nil manifest check; no code changes |
| `../discussions/r43-orchestrator-profile-source-pressure-v0.md` | proceed-with-notes | No blockers for current pass-through; future CLI/API exposure should broaden negative scans across all written JSON/refusal artifacts |
| `stage3-round43-status-curation-v0.md` | done | R43 status curation; refreshes PROP-036 maps and R44 route from C1/C2/C3 evidence |

---

## Stage 3 Round 42 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop036-assembler-impact-survey-v0.md` | done | Maps assembler impact for top-level `manifest.compiler_profile_id`; recommends assembler-only path; no code/manifest/golden change |
| `prop036-assembler-implementation-contract-v0.md` | done | Defines assembler-only implementation contract, `legacy_optional`, hash-before-sign ordering, refusal conditions, and blockers before implementation |
| `../gates/prop036-assembler-field-implementation-authorization-review-v0.md` | hold-redirect | Holds assembler field implementation until authoritative `compiler_profile_id` source contract/proof exists |
| `prop036-compiler-profile-id-source-contract-v0.md` | done | Chooses frozen descriptor -> minimal finalization -> finalized `compiler_profile_id_source` as authority source; raw id/proof constant rejected |
| `prop036-source-contract-code-surface-survey-v0.md` | done | Maps source-contract code surfaces and risks; blocks assembler implementation until finalization proof passes |
| `../gates/prop036-source-contract-implementation-authorization-review-v0.md` | approved-bounded-proof-implementation | Authorizes only proof-local minimal CompilerProfile finalization under `experiments/` |
| `minimal-compiler-profile-finalization-proof-v0.md` | done | Proof-local finalization PASS 22/22; emits finalized `compiler_profile_id_source`; no assembler/manifest/golden/loader/runtime change |
| `../gates/prop036-assembler-field-implementation-reconsideration-v0.md` | approved-bounded-assembler-implementation | Authorizes only `lib/igniter_lang/assembler.rb` field implementation; orchestrator/golden/loader/report/runtime remain closed |
| `assembler-compiler-profile-id-field-v0.md` | done | Bounded assembler `manifest.compiler_profile_id` implementation PASS 19/19; legacy nil unchanged; no golden migration |
| `../gates/prop036-orchestrator-wiring-authorization-review-v0.md` | approved-bounded-orchestrator-transport | Authorizes only optional caller-supplied `compiler_profile_source:` pass-through in `CompilerOrchestrator#compile` |

---

## Stage 3 Round 41 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop037-compatibility-report-readiness-proof-v0.md` | done | Report-only CompatibilityReport readiness proof PASS for valid `clock.every`, `queue`, and `external_event` descriptors; readiness remains false with `progression.runtime_execution_not_authorized`; no scheduler/materializer/durable/runtime calls |
| `gate3-r13-r22-lineup-historical-blockers-hardening-v0.md` | done | Applies optional R40 hardening: `Historical R22 Remaining Blockers` wording plus current-status/gates pointers; no authority change, movement, or deletion |
| `gate3-discussion-index-no-zombie-plan-v0.md` | movement/link plan only | Plans additive discussion-index grouping and no-zombie checklist; no README rewrite, movement, deletion, or broad redirect collapse; opens P-57 for supervisor-approved follow-up |
| `../gates/context-capture-pack-shadow-boundary-routing-decision-v0.md` | approved-design-research-only-shadow-boundary | Architect authorizes descriptor/profile/pack vocabulary research only for Context Capture Pack; no parser/package/runtime/LLM/Ledger/BiHistory/production/external utility mutation |
| `context-capture-pack-shadow-boundary-v0.md` | done | Maps candidate context-capture pack/profile vocabulary as shadow research only; all names candidate labels; Contextizer CLI vocabulary external utility signal; ContextSnapshot/KeyPoint pressure-only |
| `../discussions/r41-prop037-gate3-context-capture-pressure-v0.md` | complete — PROCEED (non-blockers only) | Adds P-57, flags `progression_sources` schema ownership, and warns context-capture `source_kind` values are not closed vocabulary |
| `stage3-round41-status-curation-v0.md` | done | R41 status curation; refreshes current maps and R42 route from landed evidence |

---

## Stage 3 Round 40 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop037-descriptor-oof-pr-proof-v0.md` | done | Descriptor OOF-PR proof PASS for OOF-PR1/2/3/4/5/7/9; valid descriptors now produce readiness refusal instead of compiler OOF; OOF-PR6/8 remain deferred; no runtime/scheduler/queue/auth |
| `gate3-r13-r22-lineup-authority-verification-v0.md` | done | Closes P-55: Gate 3 R13-R22 Line Up verified as safe active memory card and future redirect target after History Curator movement/link and no-zombie checks; no movement/deletion |
| `pre-gate3-lineup-rq1-rq2-revision-v0.md` | done | Closes P-56: applies RQ-1/RQ-2 plus RQ-3 hardening to the pre-Gate-3 Line Up; source remains authoritative; no redirects/movement |
| `contextizer-lineup-bridge-analysis-v0.md` | done | Compares Line Ups, legacy `[GEM]/contextizer` CLI, and `Igniter.DocumentContextizer` pressure specimen; recommends descriptor-only context capture pack shadow route; no package/parser/runtime/LLM/Ledger/BiHistory/production authorization |
| `../discussions/r40-prop037-lineup-contextizer-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms P-55/P-56 closed, R39 NB-1 resolved, no R40 scope leak; routes optional Gate 3 Line Up hardening, PROP-037 CompatibilityReport readiness proof, and Architect-gated context-capture shadow boundary |
| `stage3-round40-status-curation-v0.md` | done | R40 status curation; refreshes current maps and R41 route from landed evidence |

---

## Stage 3 Round 39 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `contextizer-pressure-specimen-routing-v0.md` | done | Routes `Igniter.DocumentContextizer` as active pressure specimen only; bridges to legacy `source:contextizer` CLI signal; no package/runtime/Ledger/LLM/canon authority |
| `ch11-profile-oof-namespace-sync-v0.md` | done | Closes P-54: Ch11 profile diagnostics renamed to `OOF-PROF1..3`; `OOF-PR*` reserved for PROP-037 progression diagnostics; no implementation |
| `phase1-durable-audit-operational-rollout-readiness-plan-v0.md` | done | Design-only rollout readiness plan authorized by S3-R38-C1-A; covers storage identity, signer abstraction, startup/rebuild, appender/reader roles, refusal/observability export, disable/rollback, smoke, ownership, drills, and blockers; operational rollout remains closed |
| `line-up-authority-hoist-risk-review-v0.md` | done | Reviews R38 Line Ups for authority-hoist risk; requires RQ-1/RQ-2 before R2-R12 discussion redirects or movement; no movement/deletion |
| `gate3-r13-r22-discussions-lineup-v0.md` | done | Adds high-risk Gate 3 R13-R22 discussion Line Up using History-S7; source remains authoritative; no movement/deletion |
| `../discussions/r39-p54-rollout-readiness-and-lineup-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms P-54 closed and rollout plan design-only; opens P-55 Archive/Form review and P-56 RQ-1/RQ-2 edits before redirects/movement |
| `stage3-round39-status-curation-v0.md` | done | R39 status curation; refreshes current maps and R40 route from landed evidence |

---

## Stage 3 Round 38 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/durable-audit-restricted-deployment-proof-review-v0.md` | proof-local-closure-confirmed-next-rollout-design-only | Closes P-53 as confirmation review and boundary check; operational rollout remains closed; only design-only rollout readiness plan authorized |
| `prop037-progression-descriptor-shape-proof-v0.md` | done | Descriptor shape proof PASS for `clock.every`, `queue`, and `external_event`; closed `source_kind` vocabulary preserved; runtime authority and PROGRESSION fragment class remain closed |
| `prop037-oof-pr-diagnostic-design-v0.md` | done | Designs OOF-PR1..9 and separates descriptor validation, compiler OOF, and runtime readiness refusal; flags Ch11 OOF-PR namespace collision as P-54 before descriptor OOF proof |
| `prop036-assembler-field-design-plan-v0.md` | done | Design-only plan for top-level `manifest.compiler_profile_id`, hash ordering, legacy_optional rollout, and split implementation surfaces; no `.igapp`, loader, assembler, golden, or runtime change |
| `line-up-stage1-stage2-second-batch-v0.md` | done | Second Line Up batch: Stage 2 compiler package spine, Stage 2->3 typed switch spine, and old pre-Gate-3 discussions; no movement/deletion |
| `../discussions/r38-durable-audit-prop037-prop036-docs-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms no R38 scope leaks; adds P-54; flags external_event naming, pre-Gate-3 authority-hoist review, PROP-036 authorization-route visibility, and R13-R22 Line Up follow-ups |
| `stage3-round38-status-curation-v0.md` | done | R38 status curation; refreshes current maps and R39 route from landed evidence |

---

## Stage 3 Round 37 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `prop032-assumptions-spec-sync-and-temporal-specimen-disposition-v0.md` | done | Closes P-50/P-52: Ch2 bounded PROP-032 source grammar synced, Heat Map assumptions rows show compiler experiment-pass, temporal audit pressure specimens marked non-canonical/non-evidence; PROP-033/runtime receipts still excluded |
| `durable-audit-restricted-deployment-implementation-v0.md` | done | Closes P-51 proof-locally: 7 S3-R36-C1-A follow-up surfaces, 30/30 cases, 5/5 invariants, 9/9 regression PASS; operational rollout still requires Architect review |
| `../gates/prop037-progression-acceptance-review-v0.md` | accepted-proposal-only | Accepts PROP-037 progression/service liveness proposal; descriptor/proof follow-ups only; parser/runtime/fragment-class and production execution remain closed |
| `full-stage3-language-regression-matrix-v0.md` | done | Broad Stage 3 regression matrix PASS 19/19; safe for bounded PROP-032 downstream compiler-surface dependencies; PROP-033/runtime still excluded |
| `prop036-artifact-hash-ordering-proof-v0.md` | done | Synthetic proof-local artifact-hash ordering PASS; `compiler_profile_id` must be covered before hash/sign; no real `.igapp`, loader, assembler, golden, dispatch, runtime, or production signing change |
| `documentation-fate-inventory-stage1-stage2-v0.md` | done | Classifies first cleanup source set: Stage 1/2 hot tracks and old completed discussions; no movement/deletion; routes Line Up summaries and History Curator movement planning |
| `documentation-movement-link-ledger-stage1-stage2-v0.md` | movement/link plan only | Plans no-move/no-delete link lifecycle for Stage 1/2 cleanup; first safe Line Up batch identified; movements require explicit approval |
| `../lineups/README.md` | active compact-memory index | First Stage 1/2 Line Ups landed: Stage 1 close transition, Stage 2 close proof spine, Stage 2 proof surface spine, Stage 2 round-map/status curation |
| `../discussions/r37-deployment-prop037-regression-profile-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms P-50/P-51/P-52 closed without scope leaks; adds P-53 Architect review before operational rollout; mundane OOF and PROP-037 follow-up cards remain pending |
| `stage3-round37-general-status-curation-v0.md` | done | General no-card status consolidation for R37 evidence; refreshes current maps and next route |

---

## Stage 3 Round 36 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/durable-audit-b-e-deployment-review-decision-v0.md` | approved-restricted-phase1-production-durable-audit-deployment-scope | Opens bounded audit append/read/rebuild deployment scope only; Ledger, Phase 2, BiHistory, stream/OLAP, cache, broad RuntimeMachine, concrete HSM/KMS onboarding, and general persistence remain closed |
| `../gates/prop032-assumptions-experiment-pass-decision-v0.md` | experiment-pass | Promotes PROP-032 bounded compiler surface; PROP-033 evidence validation, runtime receipts, and production behavior remain excluded |
| `stage3-round36-status-preflight-sync-v0.md` | done | Preflights R35 same-round decisions plus R36 C1/C2 before further implementation/proposal work; fixes stale R35 C2-S recommendations in living maps |
| `prop037-external-progression-proposal-authoring-v0.md` | authored-pending-review | Authors PROP-037 as proposal-only; no parser, TypeChecker, SemanticIR, RuntimeMachine, Ledger/TBackend, durable queue, production execution, ProgressionPack migration, or fragment-class authorization |
| `prop036-loader-status-report-proof-v0.md` | done | Proof-local synthetic loader status report matrix PASS; `present_verified` remains separate from runtime readiness; real `.igapp`, loader, assembler, dispatch, runtime, and goldens remain closed |
| `mundane-stdlib-and-oof-signal-extraction-v0.md` | done | Extracts blind mundane specimen signals into stdlib/capability packs, syntax pressure, type vocabulary drift, OOF candidates, profile presets, and proposal routes; non-canonical, no implementation auth |
| `../discussions/r36-deployment-prop032-prop036-prop037-mundane-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms no scope leaks; routed P-50/P-51/P-52, later closed in R37 with P-51 proof-local only |
| `stage3-round36-status-curation-v0.md` | done | Final R36 map curation after C1-C6/X1; keeps B-E, PROP-032, PROP-036, PROP-037, and mundane pressure states exact |

---

## Stage 3 Round 35 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `mundane-application-pressure-analysis-v0.md` | routed-pressure-specimen | Sidecar analysis of blind external mundane application specimens; preserves them as non-canonical pressure evidence and routes stdlib/effect/OOF/profile signals for extraction |
| `durable-audit-post-implementation-regression-matrix-v0.md` | done | Closes B-D: 9/9 command matrix PASS; 97/97 durable audit proof cases PASS across bounded implementation, restart rebuild, traversal/reader, role boundary; no excluded-surface widening; ready for B-E review, not deployment approval |
| `stage3-round35-status-curation-v0.md` | done | R35 status/index sync before C3-A/C4-A; B-D closed in living maps and C2-P same-round drift cross-referenced; later PROP-036/037 state superseded by this Round 35 section |
| `../gates/prop036-compiler-profile-id-acceptance-decision-v0.md` | accepted-proposal-only | Accepts PROP-036 as proposal-only; no `.igapp`, loader, assembler, runtime, dispatch, Ledger, Phase 2, or production behavior authorization |
| `../gates/progression-prop-number-assignment-decision-v0.md` | approved-numbering-only | Assigns PROP-037 to external progression and service liveness semantics; proposal authoring next; no parser/runtime/fragment-class implementation auth |
| `prop032-assumptions-phase4-parser-proof-v0.md` | done | Closes PROP-032 Phase 4 parser/P28/source proof; recommends experiment-pass review; no PROP-033 evidence validation or runtime receipt work |
| `proposal-lifecycle-status-labels-sync-v0.md` | done | Clarifies proposal lifecycle labels and active maps: Track done is not Proposal accepted; PROP-036 accepted proposal-only; PROP-037 assigned numbering-only; later R36 C2-A promotes PROP-032 to experiment-pass |

---

## Stage 3 Round 34 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `durable-audit-reader-traversal-proof-v0.md` | done | Closes B-B: proof-local AuditReader scans full chain before filters, re-derives compliance_posture, refuses mutating/authorizing operations; PASS 26/26 + 4/4 invariants; no lib/ or production deployment |
| `durable-audit-append-reader-role-boundary-proof-v0.md` | done | Closes B-C and P-43: appender/reader role gate plus clean-rebuild append gate; PASS 21/21 + 6/6 invariants; Ledger/Phase2/HSM/KMS/deployment absent |
| `prop036-placeholder-governance-sync-v0.md` | done | Closes P-44 governance drift: PROP-036 is `compiler_profile_id` numbering-only; managed recursion/service loop placeholders moved to PROP-037+ in active maps; no implementation or migration authorization |
| `prop032-assumptions-phase3-semanticir-v0.md` | done | Closes PROP-032 Phase 3: typed assumptions lower to SemanticIR/report outputs; OOF-A1/TASSUMP-1 stay report-only; parser grammar/P28/full experiment-pass still open |
| `prop036-compiler-profile-id-manifest-proposal-v0.md` | proposal-authored | Authors PROP-036 for unified `compiler_profile_id`; docs-only; later accepted proposal-only by S3-R35-C3-A; separate Architect implementation authorization still required before assembler/loader/hash/golden/receipt work |
| `external-progression-prop-scope-draft-v0.md` | scope draft | PROP scope draft for progression: runtime capability/manifest metadata first, no new fragment class; service loop lowers to progression obligations; later assigned PROP-037 by S3-R35-C4-A; no implementation auth |
| `../discussions/r34-audit-assumptions-profile-progression-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms B-B/B-C/P-43/P-44 closed; notes C2-P same-round stale B-B table; routes B-D, P-45 PROP-036 acceptance, P-46 progression number, and PROP-032 Phase 4 |
| `stage3-round34-status-curation-v0.md` | done | R34 status/index sync — this track |

---

## Stage 3 Round 33 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `durable-audit-restart-rebuild-proof-v0.md` | done | Closes B-A: restart rebuild proof PASS 21/21; proof-local only, no deployment/signing/HSM/KMS |
| `prop032-assumptions-phase2-typechecker-v0.md` | done | Closes PROP-032 Phase 2 TypeChecker; OOF-A1 propagation and typed assumptions checks landed; SemanticIR remained open until R34 |
| `../gates/compiler-profile-manifest-prop-number-decision-v0.md` | approved-numbering-only | Assigns PROP-036 to `compiler_profile_id` manifest identity; no `.igapp`, loader, assembler, runtime, or migration authorization |
| `compiler-profile-shadow-chain-dependency-index-v0.md` | done | R33 dependency index for compiler profile shadow chain; summary dependencies/regeneration order only; no migration or dispatch authorization |
| `external-progression-semantics-decision-prep-v0.md` | done | Decision brief recommends formal PROP: progression as separate semantic primitive; service loop as surface over progression; stream/fold_stream distinct; no code/grammar/runtime auth |
| `../discussions/r33-rebuild-prop032-profile-and-progression-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms B-A and PROP-032 Phase 2 landed; routes P-43/P-44 plus B-B/B-C and PROP-032 Phase 3 to R34 |

---

## Stage 3 Round 32 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `r32-governance-authority-sync-v0.md` | done | Closes P-39/P-40 follow-up docs: META-EXPERT-013 defers to Covenant, Covenant OQ-Filter-1 points to S3-R31-C2-A, Heat Map Domain 8 authority split is closed; no PROP-032 implementation authorization |
| `durable-audit-hash-and-posture-design-amendment-v0.md` | done | Closes P-37/P-38; five canonical hash excluded fields documented; compliance_posture stored+derived+mismatch-checked; B-A/B-B/B-C unblocked; no deployment auth |
| `prop032-assumptions-phase1-classifier-implementation-v0.md` | done | Classifier Phase 1 landed: assumption_registry, uses_assumptions, assumption_refs, epistemic precedence, OOF-A1; assumptions_proof + regressions PASS; TypeChecker/SemanticIR open |
| `../discussions/r32-durable-audit-prop032-and-compiler-profile-pressure-v0.md` | complete — PROCEED (non-blockers only) | P-37..P-40 closed; B-A still open; PROP-032 Phase 2 unblocked; compiler_profile_id PROP number needed |
| `stage3-round32-status-curation-v0.md` | done | R32 status/context/index sync — this track |

---

## Stage 3 Round 31 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `phase1-production-durable-audit-bounded-implementation-v0.md` | done | Proof-local surfaces 1/2/3/8 PASS 29/29 + 5/5 invariants; no `lib/` writer, no Ledger/Phase2/HSM/KMS/deployment; B-A/B-B/B-C/B-D remain open |
| `../gates/prop-governance-authority-decision-v0.md` | approved-authority-hierarchy | Closes OQ-Filter-1: Covenant normative, META-EXPERT-013 operational; does not authorize PROP-032 implementation |
| `r31-governance-map-sync-v0.md` | done | Heat Map GI-1/stale rows synced; proposals/README and CSM pre-checked as already current before this card |
| `startup-freshness-design-amendment-d1-d2-d3-v0.md` | done | R29 startup design now matches R30 validator: non-default `expires_at`, format-invalid code, direct-seconds refusal code |
| `prop032-assumptions-implementation-gate-review-v0.md` | done | PROP-032 Phase 1 gate satisfied; OOF-A1 and `epistemic` insertion specified; no compiler code/goldens/experiment PASS |
| `compiler-profile-architecture-direction-v0.md` | done | Profile-Baseline-Pack accepted as post-POC target direction; current compiler remains proof compiler; no rewrite authorized |
| `compiler-pack-boundary-report-v0.md` | done | No-code pack decomposition report; capability-owned boundaries; ContractModifiersPack recommended first optional pack after shadow profile |
| `compiler-pack-shadow-profile-proof-v0.md` | done | Shadow profile PASS; `shadow_no_dispatch`; no `.igapp` change; AssumptionsPack proposed-shadow-only |
| `contract-modifiers-pack-native-boundary-v0.md` | done | Descriptor-only ContractModifiersPack boundary PASS; no compiler dispatch or `.igapp` integration |
| `compiler-kernel-pack-registry-spike-v0.md` | done | Proof-local CompilerKernel registry mechanics PASS; no real compiler pass dispatch |
| `compiler-kernel-ordered-rule-precedence-v0.md` | workspace-present shadow | Ordered registry semantics PASS; uncommitted at curation time; no compiler dispatch or `.igapp` change |
| `compiler-profile-id-manifest-boundary-plan-v0.md` | workspace-present shadow | Proof-local `compiler_profile_id` manifest boundary PASS; no assembler/runtime/signed artifact changes; explicit manifest PROP required before implementation |
| `../discussions/r31-bounded-audit-and-governance-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms P-31/P-33..P-36 closed; routes P-37..P-40 plus B-A/B-B/B-C/B-D to R32 |
| `stage3-round31-status-curation-v0.md` | done | R31 status/context/index sync — this track |

---

## Stage 3 Round 30 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/phase1-production-durable-audit-implementation-authorization-decision-v0.md` | approved-bounded-implementation | Authorizes bounded Phase 1 production durable audit implementation track only; production deployment, concrete HSM/KMS, Ledger/Phase 2, BiHistory, stream/OLAP, cache, broad RuntimeMachine binding, and excluded surfaces remain closed |
| `startup-time-freshness-override-validator-v0.md` | done | Proof-local validator PASS 28/28 + 12/12 invariants; all non-default policies require `expires_at`; direct seconds refused; no Ledger/Phase2/online lookup/gate authority |
| `observed-temporal-precedence-golden-r30-v0.md` | done | V-3 observed+temporal precedence anchored in `contract_modifiers_proof`; check-golden PASS 25/25; no grammar added |
| `semantic-governance-heat-map-v0.md` | done | Creates `../dev/semantic-governance-heat-map.md`; 8 domains, GI-1..GI-5; doc-only drift index; X1 notes two stale-credit rows after same-round C2/C3 landed |
| `covenant-promise-enforcement-path-rule-v0.md` | done | Formalizes enforcement path rule for every Covenant promise; enforcement registry added; P28 partial; OQ-P28-1 and OQ-Filter-1 routed |
| `prop032-assumptions-block-draft-r30-v0.md` | done | PROP-032 assumptions block drafted and queue renumbering applied in proposals index; proposes `epistemic` fragment and OOF-A1; no parser/classifier/SemanticIR implementation or proof |
| `../discussions/r30-decision-heatmap-and-assumptions-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms bounded authorization only; P-28/P-29/P-30/P-32 closed; P-31 and new P-33..P-36 routed |
| `stage3-round30-status-curation-v0.md` | done | R30 status/context/index sync — this track |

---

## Stage 3 Round 29 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `startup-time-freshness-override-interface-v0.md` | done | Design-only override interface: constant 24h default + deployment manifest policy_ref + bundled authority-signed policy; direct env/config seconds rejected; no proof script or production implementation |
| `prop031-compatibility-addendum-r29-v0.md` | done | PROP-031 §14 compatibility addendum + errata; documents Stage 3 migration, stream-triggered OOF-M1, temporal precedence, and Classifier→TypeChecker ownership; doc-only |
| `covenant-accountability-postulates-r29-v0.md` | done | Covenant adds Honesty/Accountability split, P27/P28, and PROP Governance Filter; governance only, no compiler semantics |
| `canonical-semantic-model-bootstrap-r29-v0.md` | done | Creates `../dev/canonical-semantic-model.md`; implemented/experiment-pass entities require golden anchors; unanchored entries remain `spec_candidate` |
| `../discussions/r29-authorization-and-canon-pressure-v0.md` | complete — PROCEED (non-blockers only) | Confirms S3-R29-C1 Architect authorization did not land; no unauthorized implementation; P-24..P-27 closed; P-28 deferred to R30 |
| `stage3-round29-status-curation-v0.md` | done | R29 status/context/index sync — this track |

## Stage 3 Round 28 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `production-durable-audit-blocker-amendment-and-validation-proofs-v0.md` | done | Closes C1-A Blockers 1/2/3/7 by amendment + bounded proofs: compliance posture 14/14 PASS, signer validation 18/18 PASS; startup_time 24h fail-closed design only; no implementation authorization |
| `../proposals/PROP-031-contract-modifiers-v0.md` | experiment-pass | Parser/classifier/typechecker/SemanticIR implementation landed for optional `pure|observed|effect|privileged|irreversible`; implicit pure default; OOF-M1 only; no Effect Surface/Profile/runtime enforcement |
| `../discussions/r28-durable-audit-and-prop031-pressure-v0.md` | complete — PROCEED with interim blockers | X1 confirmed C1/C2 scope and found an intermediate 26/29 matrix blocker from Stage 3 fixture migration; later R28 evidence resolved it |
| `agent-d-cross-review-values-and-meta-cards-r28-v0.md` | done | Agent-D values/cross-review; temporal fragment precedence fixed; legacy stream/History/BiHistory fixtures marked `observed`; 10/10 proof surfaces PASS; R29 Meta agenda proposed |
| `post-r27-regression-matrix-with-volatile-lint-v0.md` | done | Final sequential post-R27/R28 matrix 29/29 PASS with volatile_fields_lint first; C1 bounded proofs and C2 contract modifiers proof included |
| `stage3-round28-status-curation-v0.md` | done | R28 status/index/proposal sync — this track |

## Stage 3 Round 27 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/phase1-production-durable-audit-implementation-authorization-review-v0.md` | hold-before-implementation-authorization | Architect holds production durable audit implementation authorization; design is review-ready, implementation still closed |
| `volatile-fields-lint-and-artifact-stability-survey-v0.md` | done | Validator shipped; PASS 4 annotated artifacts, 0 violations; artifact stability survey complete; R28 later closed matrix integration; Time.now grep hook remains optional |
| `../proposals/PROP-031-contract-modifiers-v0.md` | proposal at R27 close | Contract modifiers proposal; R28 later moved index status to experiment-pass after implementation/proof landed |
| `contract-modifiers-proof-fixture-plan-v0.md` | done | Fixture/command plan ready for implementation card; no fixtures created and no PASS claimed |
| `../discussions/durable-audit-authorization-and-prop031-pressure-v0.md` | complete — PROCEED (non-blockers only) | X1 confirms C1-A is HOLD, C2 closes lint/survey blockers, PROP-031 remains scoped, C4 is plan-only |
| `stage3-round27-status-curation-v0.md` | done | R27 status/index/proposal sync — this track |

## Stage 3 Round 26 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `phase1-production-durable-audit-v0.md` | done | Production durable audit design; ready for implementation authorization review, not implementation authorization; defines schema/signing/rebuild/version/traversal/storage/reader/compliance/error/blocker/proof plan |
| `../gates/phase1-production-registry-ownership-decision-v0.md` | approved-design-source-of-truth | Gate document store is source of truth; generated content-addressed registry index is query artifact; package/runtime are read-only cache/validator only |
| `deterministic-regression-artifact-policy-v0.md` | done | Two-tier artifact policy implemented; tamper-evidence JSONL byte-stable; stage2 summary marks `timestamp` volatile |
| `../discussions/phase1-production-durable-audit-design-pressure-v0.md` | complete — PROCEED (non-blockers only) | X1 confirms design-only scope, signing recommendation not execution auth, audit traversal not replay, registry self-auth prohibited, deterministic policy scoped |
| `stage3-round26-status-curation-v0.md` | done | R26 status/index sync — this track |

## Stage 3 Round 25 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `phase1-post-r24-regression-rerun-v0.md` | done | PASS 25/25; regression readiness only, expands matrix with R24 storage/tamper fixtures; no implementation authorization |
| `../gates/phase1-production-durable-audit-scope-decision-v0.md` | approved-for-design-only | Architect approves `phase1-production-durable-audit-v0` design work only; implementation/deployment/signing execution/Ledger/Phase 2 remain closed |
| `production-registry-ownership-options-v0.md` | done | Recommends gate document store + generated content-addressed registry index as Phase 1 default; no binding ownership decision or implementation |
| `../discussions/phase1-production-audit-scope-and-registry-ownership-pressure-v0.md` | complete — PROCEED (non-blockers only) | X1 confirms 25-command matrix, design-only scope, closed excluded surfaces; closes P-13, adds P-14 deterministic artifact policy |
| `stage3-round25-status-curation-v0.md` | done | R25 status/index sync — this track |

## Stage 3 Round 24 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `phase1-post-r23-regression-rerun-v0.md` | done | PASS 23/23; full post-R23 proof chain rerun, no production implementation authorization |
| `phase1-durable-registry-storage-semantics-v0.md` | done | PASS 10/10; proof-local durable/queryable registry storage semantics, direct active -> superseded blocked; no signing/Ledger/executor |
| `phase1-observation-tamper-evidence-shape-v0.md` | done | PASS 23/23; proof-local tamper_evidence block and SHA256 canonical hash chain; not production durable audit, signing, Ledger, or compliance |
| `../discussions/phase1-post-r23-regression-and-durability-pressure-v0.md` | complete — PROCEED (non-blockers only) | X1 closes P-8/P-9, confirms excluded surfaces closed, and routes 25-command rerun plus production durable-audit/registry ownership decisions |
| `stage3-round24-status-curation-v0.md` | done | R24 status/index sync — this track |

## Stage 3 Round 23 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `phase1-durable-observation-persistence-shape-v0.md` | done | PASS 9/9; proof-local file-backed JSONL persistence shape only; `production_durable_audit=false`, no Ledger/write/replay/compact/subscribe |
| `gate3-authority-registry-v1-receipts-shape-v0.md` | done | PASS 11/11; registry v1 issuance -> revocation -> supersession receipts with content-addressed decision refs; no signing/keys/executor calls |
| `phase1-reason-code-legacy-aliases-deprecation-signal-v0.md` | done | PASS 21/21 plus lib-prep 17/17; lib/ emits canonical `runtime.temporal_scope_exclusion`; sealed old fixtures preserved |
| `../discussions/phase1-durable-audit-and-registry-v1-pressure-v0.md` | complete — PROCEED (non-blockers only) | X1 confirms no scope widening, no production audit/signing, P-6 closed, P-8/P-9 routed |
| `stage3-round23-status-curation-v0.md` | done | R23 status/index sync — this track |

## Stage 3 Round 22 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `phase1-end-to-end-invocation-fixture-v0.md` | done | PASS 9/9; composes registry check -> caller authorization -> Phase1 executor -> explicit audit-ready envelope; proof-local only |
| `phase1-addendum-content-address-ref-v0.md` | done | PASS 9/9; signed addendum evidence requires human path plus content_sha256/git_commit/status/signed_on/authority_ref; path-only evidence non-compliant |
| `../discussions/phase1-e2e-and-content-address-pressure-v0.md` | complete — PROCEED | X1 confirms no production behavior, no scope widening, P-4/P-5 closed, P-8 regression rerun added |
| `stage3-round22-status-curation-v0.md` | done | R22 status/index/context/gate sync — this track |

## Stage 3 Round 21 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `compatibility-report-persistence-audit-v0.md` | done | Phase 1 audit-ready envelope PASS 10/10; explicit export only; `audit_ready_not_persisted`; no durable audit, production storage, Ledger write, or authority registry |
| `gate3-authority-registry-shape-v0.md` | done | Proof-local authority registry shape PASS 11/11; registry check composes before caller passes `gate3_authorized: true`; no executor calls, signing, keys, production authority service, or Phase 2 |
| `../discussions/phase1-post-signature-audit-registry-pressure-v0.md` | complete — PROCEED | X1 confirms neither durable audit nor production signing is implied; routes pre-production checklist P-1..P-7 |
| `stage3-round21-status-curation-v0.md` | done | R21 status/index/context/gate sync — this track |

## Stage 3 Round 20 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/gate3-live-read-decision-addendum-v0.md` | signed-approved-restricted-phase1-live-read | Architect signed the restricted Phase 1 live-read addendum; callers may pass `gate3_authorized: true` only with signed-addendum invocation evidence and only inside the named scope |
| `gate3-first-post-signature-fixture-v0.md` | done | Post-signature fixture PASS 10/10; signing changes caller policy/status only; executor guard order unchanged; Ledger/BiHistory/stream/OLAP/write/cache paths remain closed |
| `../discussions/gate3-post-signature-runtime-pressure-v0.md` | complete — PROCEED | X1 confirms no scope widening and no behavior drift; routes low traceability/honor-system/full-chain notes as non-blocking |
| `stage3-round20-status-curation-v0.md` | done | R20 status/index/context/gate sync — this track |

## Stage 3 Round 19 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `phase1-r18-cleanup-regression-rerun-v0.md` | done | Post-R18 full regression rerun PASS 15/15; includes R18 backend identity guard proof and `observation.backend_identity_emitted: ok` |
| `../discussions/gate3-live-read-addendum-pre-signature-pressure-v0.md` | complete — PROCEED to Architect signature review | Evidence blockers 1-5 closed; blocker 6 remains Architect signature/status update; no hidden Ledger/BiHistory/stream/OLAP/cache/write path |
| `stage3-round19-status-curation-v0.md` | done | R19 status/index/context/gate sync — this track |

---

## Stage 3 Round 18 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/gate3-live-read-decision-addendum-v0.md` | superseded by R20 signed status | R18 drafted the addendum; R20 later signed the same file for restricted Phase 1 only |
| `temporal-executor-proof-local-docstring-amendment-v0.md` | done | Source comments clarify `GATE3_AUTHORITY_REF` is source-code-parity only, `observations` are in-memory/non-audit, and `gate3_authorized` is caller honor-system |
| `runtime-temporal-scope-exclusion-reason-alias-v0.md` | done | Lib emissions canonicalized to `runtime.temporal_scope_exclusion`; legacy narrow strings retained as aliases; proof PASS |
| `phase1-backend-identity-guard-v0.md` | done | Code-level backend identity guard blocks unmarked, Ledger-backed, Ledger proxy, and malformed backends before scope/cache/kernel/read; proof PASS |
| `../discussions/live-read-addendum-draft-safety-pressure-v0.md` | complete — proceed; two pre-signing conditions | Cleanup tracks correctly scoped and non-authorizing; two pre-signing conditions were routed and later closed by R19 |
| `stage3-round18-status-curation-v0.md` | done | R18 status/index/context/gate sync — this track |

---

## Stage 3 Round 17 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `phase1-lib-prep-regression-chain-rerun-v0.md` | done | Post-C1 lib-prep regression rerun PASS 14/14 across S3-R7..R10, S3-R13..R16, Stage 1, and Stage 2; safety pressure may proceed |
| `runtime-temporal-executor-lib-boundary-spec-sync-rerun-v0.md` | done | Ch7 now names `IgniterLang::TemporalExecutor::Phase1` as proof-local implementation boundary with `gate3_authorized: false`, guard order, composed report, and exact authority_ref |
| `../discussions/runtime-temporal-executor-lib-prep-safety-pressure-v0.md` | complete — PROCEED | All eight scope guarantees confirmed for proof-local Phase 1; routes docstring amendments, reason-code alias, backend identity guard, and live-read addendum track |
| `stage3-round17-status-curation-v0.md` | done | R17 status/index/context/gate sync — this track |

---

## Stage 3 Round 16 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `runtime-temporal-executor-lib-prep-v0.md` | done | S3-R16 C1 landed `IgniterLang::TemporalExecutor::Phase1` in lib/ with `gate3_authorized: false` default, exact authority_ref, CompatibilityReport-shaped hash, token-before-gate order, and targeted proof PASS 17/17; live reads still blocked |
| `phase1-lib-prep-regression-chain-v0.md` | stale-blocked | S3-R16 C2 track was written before C1 landed and records dependency absent; superseded by R17 rerun |
| `runtime-temporal-executor-lib-boundary-spec-sync-v0.md` | stale no-op | S3-R16 C3 track was written before C1 landed and made no Ch7 edit; superseded by R17 spec-sync rerun |
| `stage3-round16-status-curation-v0.md` | done | R16 status/index/context/gate sync — this track |

---

## Stage 3 Round 15 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `runtime-report-enforcement-order-amendment-v0.md` | done | Ordering drift fixed: canonical `CompatibilityReport -> approval_token -> gate_state -> scope -> cache_key -> executor_backend`; no PROP-030 errata needed |
| `runtime-report-enforcement-preflight-v0.md` | amended | Preflight doc and proof now use token-before-gate ordering; mixed failure proves missing approval wins before Gate 3 closed |
| `runtime-temporal-executor-composition-integration-v0.md` | done | AT-2 closed: Phase1TemporalExecutorWithReport consumes one composed CompatibilityReport and rejects split fragments before executor/gate/token/cache/backend paths |
| `executor-approval-authority-ref-proof-v0.md` | done | AT-9 proof-local PASS: exact decision-record `authority_ref` accepted; missing/wrong/stale/self-issued refs refused before live paths |
| `phase1-prelive-regression-chain-v0.md` | done | Base S3-R7..R10 chain PASS 9/9; added pre-live surface PASS 6/6; Stage 1 and Stage 2 close candidates PASS; lib-prep allowed next |
| `stage3-round15-status-curation-v0.md` | done | R15 status/index/context/gate sync — this track |

---

## Stage 3 Round 14 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/gate3-decision-record-v0.md` | amended | Phase 1 authority URI constant and active revocation paths recorded; runtime authority registry remains future Phase 2/prod work |
| `runtime-temporal-executor-phase1-preflight-v0.md` | done | Proof-local `Phase1TemporalExecutor` 9/9 PASS; initial composition/authority gaps closed by R15; experiments-local only |
| `temporal-scope-exclusion-runtime-fixture-v0.md` | done | `runtime.temporal_scope_exclusion` proved for CORE, STREAM, OLAP, BiHistory, Ledger write/replay, and unknown surfaces before live paths; History valid-time control accepted |
| `runtime-report-enforcement-preflight-v0.md` | amended in R15 | Composed-report preflight matrix PASS with blocked operation flags false; R15 fixed canonical token-before-gate ordering |
| `spec-ch7-gate3-approval-sync-v0.md` | done | Ch7 now reflects approved-restricted Phase 1, pre-live block, AT-1..AT-12, scope exclusion, and closed adjacent surfaces |
| `../discussions/phase1-implementation-prep-safety-pressure-v0.md` | complete — PROCEED | No live-eval/Ledger/BiHistory/cache leak; proof-local Phase 1 may continue; production/live blockers are C4 ordering, AT-2 integration, AT-9 URI comparison |
| `news-clarity-aggregator-syntax-pressure-form-v0.md` | done | Non-canon syntax/product pressure only; no parser/runtime/spec authorization |
| `truth-systems-osint-applied-pressure-v0.md` | done | Applied truth-system/OSINT pressure; synthetic/public-style safety boundary; no canon promotion |
| `general-purpose-fixtures-syntax-pressure-form-v0.md` | done | Cross Test 2 syntax/product pressure for HTTP API, AgentKnowledgeMesh, ClarityDuelEngine, LegalAdvocateOSINT; raw snippets should not become parser fixtures verbatim |
| `general-purpose-and-legal-osint-applied-pressure-v0.md` | done | Applied pressure routes HTTP/JSON baseline, agent knowledge conflict, truth-system evidence bundles, legal safety, and agent authority profiles; no implementation authorization |
| `general-purpose-fixtures-syntax-pressure-form-cross-test-3-v0.md` | done | Cross Test 3 pressure for EmergencyAgentMeshReplicator and DecentralizedMarketplace; self-replication/self-modification/escrow remain high-risk product pressure only |
| `general-purpose-emergency-mesh-marketplace-pressure-v0.md` | done | Applied emergency mesh/marketplace pressure; recommends controlled synthetic fixtures before any live spawn/patch/escrow adapter discussion |
| `stage3-round14-status-curation-v0.md` | done | R14 status/index/context/gate sync — this track |

---

## Stage 3 Round 13 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/gate3-decision-record-v0.md` | approved-restricted-phase1 | Architect decision authorizes Phase 1 TEMPORAL History[T] valid_time executor implementation via abstract proof-local/non-Ledger TBackend; at R13 close, live reads were blocked until pre-live conditions, AT-1..AT-12, and regression proof chain passed |
| `../proposals/PROP-030A-temporal-scope-exclusion-errata-v0.md` | proposal | Canonical scope-exclusion refusal code: `runtime.temporal_scope_exclusion`; does not authorize new executor/backend scope |
| `prop-030-temporal-scope-exclusion-errata-v0.md` | done | Formalizes PROP-030A errata and refusal mapping for out-of-scope TEMPORAL executor attempts |
| `prop-005-temporal-read-observation-v0.md` | done | Defines minimum `temporal_read_observation` envelope for authorized live History[T] reads; proof PASS; no live TBackend/Ledger eval |
| `compatibility-report-composition-v0.md` | done | Defines single composed CompatibilityReport shape for readiness + enforcement; proof PASS; split report/enforcement fragments rejected |
| `../discussions/gate3-decision-safety-pressure-v0.md` | complete — PROCEED | X1 finds no hidden authorization leaks; recommends non-blocking wording amendments and Phase 2 authority/addendum follow-ups |
| `stage3-round13-status-curation-v0.md` | done | R13 status/index/context/gate sync — this track |

---

## Stage 3 Round 12 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `runtime-temporal-executor-gate3-request-revision-v0.md` | done | S3-R11-X1 HOLD resolved: authority ref is gate-opening precondition; AT-10 unconditional (Q5 closed); AT-12 added (CORE refusal); Q3 Option C phases defined; scope-not-expanded binding added; routed to R13 Architect decision |
| `gate3-request-revision-spec-review-v0.md` | done | Compiler/Grammar review found no semantic/spec blocker for Architect review; superseded by R13 approved-restricted decision; no parser, SemanticIR node-kind, BiHistory, stream/OLAP, or production-cache authorization |
| `gate3-regression-proof-chain-index-v0.md` | done | S3-R7..R10 proof-chain index added with commands, expected outputs, risk coverage, and proof-local vs production-required boundaries; no named proof missing |
| `gate3-tbackend-adapter-phase-plan-v0.md` | done | Bridge phase plan: base Gate 3 may authorize abstract History[T] valid_time read interface only; Phase 1 non-Ledger/proof-local; Phase 2 real Ledger adapter requires Architect addendum |
| `../discussions/gate3-request-revision-safety-pressure-v0.md` | complete — PROCEED | X1 confirms both S3-R11 HOLD blockers closed; no new blocker-level ambiguity; request is safe to route to Architect review, not approved |
| `stage3-round12-status-curation-v0.md` | done | R12 status/index/context/value sync — this track |

---

## Stage 3 Round 11 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../gates/runtime-temporal-executor-gate3-request-v0.md` | revised / decided | Gate 3 opening request; S3-R11-X1 HOLD resolved (S3-R12-C1-S); restricted scope became R13 approved-restricted Phase 1; live reads still blocked |
| `gate3-acceptance-condition-matrix-v0.md` | done | Extracts prerequisite matrix from S3-R7..R10 evidence; marks production RuntimeMachine binding, authority/revocation/signature, report persistence/audit, unified report composition, physical TBackend serving proof, and cache enforcement as missing production items |
| `gate3-ledger-tbackend-scope-and-bihistory-exclusion-v0.md` | done | Recommends first Gate 3 request be History[T] valid_time read-only; BiHistory, writes, replay, compact, subscriptions, stream binding, and migrations excluded |
| `gate3-request-spec-consistency-check-v0.md` | done | Request shape is coherent with PROP-028/PROP-030/Ch6/Ch7; no parser/syntax authorization; C4 noted the request artifact missing at its review point, while current discovery finds C1 in `docs/gates/` |
| `../discussions/gate3-request-safety-pressure-v0.md` | complete — HOLD | X1 says request intent/scope are sound but routing is held for two edits: authority ref must be in the decision record and live-read audit trace must not remain optional |
| `stage3-round11-status-curation-v0.md` | done | R11 status/index/context/value sync — this track |

---

## Stage 3 Round 10 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `executor-approval-token-report-proof-v0.md` | done | PROP-030 token validation matrix covered in report-only CompatibilityReport; valid token still blocks while Gate 3 is closed; no executor/TBackend/Ledger/cache call attempted |
| `guarded-runtime-executor-approval-enforcement-v0.md` | done | proof-local GuardedRuntimeMachine enforces missing approval, Gate 3 closed, and CORE-shaped TEMPORAL cache-key refusal before executor/cache/backend paths |
| `compatibility-report-package-descriptor-consumption-v0.md` | done | ratified Gate 2 package descriptor metadata consumed into report-only `backend_check.temporal_backend_descriptor`; `runtime_enforced=false`; Gate 3 closed |
| `invariant-source-metadata-preservation-v0.md` | done | parser/classifier/typechecker/SemanticIR preserve descriptive invariant source metadata and start span; no new invariant semantics |
| `stage3-round10-status-curation-v0.md` | done | R10 status/index/context sync — this track |

## Stage 3 Round 9 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `descriptor-gate2-architect-ratification-record-v0.md` | ratified | Gate 2 ratified for metadata-only descriptor exposure; trusted report metadata only; Gate 3 closed |
| `prop-030-executor-approval-token-contract-v0.md` | done | PROP-030 drafted; ExecutorApprovalToken is a Gate 3 prerequisite backed by Architect authority; proposal-only, no executor implementation |
| `executor-boundary-cache-key-contract-v0.md` | done | executor boundary must use `manifest.contract_index.cache_key_schema_hint`; TEMPORAL keys require temporal coordinates; CORE-shaped TEMPORAL keys refuse with L-T5-style fault |
| `guarded-runtime-c2-profile-consistency-v0.md` | done | S3-R8 C2 claimed-executor and approved-placeholder profiles are blocked in CompatibilityReport and refused by GuardedRuntimeMachine with explicit reason mapping |
| `stream-replay-metadata-emission-v0.md` | done | stream replay metadata now emitted into SemanticIR nodes and assembled `stream_nodes`; full smoke uses assembled metadata, no proof-local defaults |
| `stage3-round9-status-curation-v0.md` | done | R9 status/index/context sync — this track |

## Stage 3 Round 8 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `runtime-smoke-post-switch-full-coverage-v0.md` | done | all six current `emit_typed` surfaces covered: Add, stream_fold, OLAPPoint, History, BiHistory, invariant severity; TEMPORAL still refuses evaluation; C1/C3 report/guard cross-check included |
| `runtime-compatibility-report-executor-boundary-v0.md` | done | positive executor/live-binding report profiles added; capability flags and approved placeholder remain blocked without explicit approval and Gate 3 authorization; no live operations attempted |
| `descriptor-gate2-ratification-decision-v0.md` | ratify-recommended | Bridge recommendation for formal Gate 2 ratification; metadata-only descriptor exposure/report use allowed if Architect ratifies; Gate 3 closed |
| `prop-029-entrypoint-section-surface-v0.md` | done | PROP-029 authored; `entrypoint` proposed as named evaluation/run profile over existing contract, `section` as grouping-only source organization; no parser implementation |
| `../discussions/stage3-round8-pre-gate3-pressure-v0.md` | complete — routed | X1 grouped executor approval token, executor cache-key proof, report/runtime enforcement, and stream metadata as pre-Gate-3 prerequisite package |
| `stage3-round8-status-curation-v0.md` | done | R8 status/index/context sync — this track |

## Stage 3 Round 7 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `docs-value-hoisting-micro-round-v0.md` | done | docs micro-round: cold snapshot after S3-R7 plus `../value-index.md` as hoisted durable-idea map |
| `runtime-compatibility-report-temporal-load-check-v0.md` | done | CompatibilityReport-shaped boundary separates bundle load from evaluation readiness; TEMPORAL loads for inspection while evaluation remains blocked; report-only and `runtime_enforced=false` |
| `invariant-typed-shape-discharge-v0.md` | done | `invariant_valid` typed shape accepted as production shape; C-8 delta discharged; no rollback to parsed emitter |
| `runtime-smoke-temporal-post-switch-v0.md` | done | post-switch CORE Add bundle evaluates (`sum=42`); TEMPORAL BiHistory bundle loads for inspection and refuses evaluation structurally |
| `spec-entrypoint-sync-v0.md` | done | `entrypoint`/`section` disposition set: Stage 3 proposal candidates only; no parser support, no hard keyword reservation, `contract` remains canonical boundary |
| `descriptor-compatibility-package-consumption-v0.md` | done | package descriptor fields mapped to report-only `backend_check.temporal_backend_descriptor`; Gate 2 ratification still formal approval point; Gate 3 remains closed |
| `../discussions/runtime-compatibility-and-typed-delta-pressure-v0.md` | complete — routed | X1 found no current production bug; routes full post-switch smoke, executor-boundary case, and C1/C3 cross-validation before Gate 3 |
| `stage3-round7-status-curation-v0.md` | done | R7 status/index/context sync — this track |

## Stage 3 Round 6 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../agent-context.md` | done | trusted first context layer added: read order, do-not-reread guard, active gates, conflict rule, ownership reminders, proof/test budget |
| `spec-ch6-semanticir-temporal-sync-v0.md` | done | Ch6 synced to current Stage 3 SemanticIR/.igapp shape: temporal nodes, `temporal_nodes`, `fragment_summary`, `contract_index`, requirements derivation, guard policy |
| `spec-ch4-temporal-fragment-sync-v0.md` | done | Ch4 synced with TEMPORAL as first-class fragment, node/value/contract split, History/BiHistory classification, OOF-TM aliases, parser syntax caveat |
| `spec-ch7-runtime-temporal-cache-sync-v0.md` | done | Ch7 synced with CORE/TEMPORAL cache key schemas, freshness states, and `load_accept_evaluate_refuse` policy; no production cache/executor |
| `spec-ch5-emit-typed-sync-v0.md` | done | Ch5 synced after `CompilerOrchestrator` switch; `emit_typed` is production path and parsed emitter is Stage 1 legacy/comparison |
| `parity-track-stale-header-sweep-v0.md` | done | stale/superseded headers added to 4 old parity/cache tracks so old blocked states are not treated as current truth |
| `proposal-lifecycle-index-sync-v0.md` | done | PROP-022..025 → closed (Stage 2 PASS); PROP-028 → implementation-partial; PROP-022A added to index as experiment-pass; proposals/README.md restructured into 3 sections with lifecycle vocabulary; Stage 1 deferred gap resolved |
| `../discussions/docs-context-and-spec-sync-pressure-v0.md` | complete — routed | X1 confirmed spec ch4–ch7 and role profiles are fresh; routed remaining scoreboard/agent-context/invariant/entrypoint doc debt |
| `stage3-round6-docs-status-curation-v0.md` | done | R6 docs round close map sync — this track |

## Spec Freshness Table

| Surface | Freshness | Anchor | Notes |
|---------|-----------|--------|-------|
| `docs/agent-context.md` | current | `../agent-context.md` | Trusted read order, gates, conflict rule, proof budget; S3-R15 next movement refreshed |
| `docs/spec/ch4-fragment-classification.md` | synced | `spec-ch4-temporal-fragment-sync-v0.md` | TEMPORAL fragment and node/value split current |
| `docs/spec/ch5-compiler-pipeline.md` | synced + discharged + metadata | `spec-ch5-emit-typed-sync-v0.md`; `invariant-typed-shape-discharge-v0.md`; `invariant-source-metadata-preservation-v0.md` | `emit_typed` production path current; invariant source metadata preservation landed |
| `docs/spec/ch6-semanticir.md` | synced + stream/invariant metadata | `spec-ch6-semanticir-temporal-sync-v0.md`; `stream-replay-metadata-emission-v0.md`; `invariant-source-metadata-preservation-v0.md` | STREAM replay metadata emitted; invariant source_metadata/source_span needs spec sync |
| `docs/spec/ch7-runtime.md` | synced + R20 signed addendum | `spec-ch7-runtime-temporal-cache-sync-v0.md`; `executor-approval-token-report-proof-v0.md`; `guarded-runtime-executor-approval-enforcement-v0.md`; `compatibility-report-package-descriptor-consumption-v0.md`; `../gates/gate3-decision-record-v0.md`; `../proposals/PROP-030A-temporal-scope-exclusion-errata-v0.md`; `prop-005-temporal-read-observation-v0.md`; `compatibility-report-composition-v0.md`; `spec-ch7-gate3-approval-sync-v0.md`; `runtime-temporal-executor-composition-integration-v0.md`; `executor-approval-authority-ref-proof-v0.md`; `phase1-prelive-regression-chain-v0.md`; `gate3-first-post-signature-fixture-v0.md` | Restricted Phase 1 live read is signed-authorized only inside addendum scope; Phase 2/Ledger/BiHistory/cache/audit closed |
| `docs/proposals/README.md` | synced + PROP-030A pending index check | `proposal-lifecycle-index-sync-v0.md`; `prop-029-entrypoint-section-surface-v0.md`; `prop-030-executor-approval-token-contract-v0.md`; `../proposals/PROP-030A-temporal-scope-exclusion-errata-v0.md` | Stage 2 closed, PROP-028 implementation-partial, PROP-022A experiment-pass, PROP-029/030 proposal-only; PROP-030A landed as proposal evidence |

---

## Stage 3 Round 5 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `temporal-assembler-manifest-contract-index-v0.md` | done | assembler now emits `manifest.fragment_summary` and per-contract `manifest.contract_index`; TEMPORAL cache hints and mismatch negatives proven; cache proof now prefers manifest index |
| `temporal-runtime-load-guard-v0.md` | done | proof-local `GuardedRuntimeMachine` uses `load_accept_evaluate_refuse`; valid TEMPORAL artifacts load for inspection; evaluation refuses unsupported runtime or missing caps |
| `bihistory-source-fixture-parity-gate-v0.md` | done | SparkCRM-shaped BiHistory source fixture added to parity harness; `sparkcrm_bihistory` moved from NOT_COMPARABLE to measured FAIL due to legacy parsed OOF; switch gate status PROCEED |
| `orchestrator-emit-typed-switch-v0.md` | done | `CompilerOrchestrator` production path switched to `emit_typed(typed)`; Stage 1, Stage 2, production compiler CLI, and release gate PASS; parsed emitter retained as Stage 1 legacy/comparison |
| `descriptor-package-exposure-gate2-ratification-v0.md` | ratify | recommends Gate 2 ratification for metadata-only package descriptor exposure; package spec 9 examples, 0 failures; Gate 3 remains closed |
| `stage3-round4-and-round5-status-curation-v0.md` | done | R4 repair + R5 close map sync — this track |
| `spec-stage3-sync-and-doc-compaction-plan-v0.md` | done | S3-R1..R5 evidence → spec backlog per chapter; CRITICAL stale sections in ch6/ch7 identified; 4 spec sync cards + 1 stale sweep card defined; 7 debt items registered |

## Stage 3 Round 4 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `temporal-assembler-boundary-v0.md` | done | temporal SemanticIR now assembles into `.igapp/`; temporal nodes stored as non-compute `temporal_nodes`; runtime execution marked unsupported; Stage 1/2 regressions PASS |
| `prop-022a-temporal-manifest-errata-v0.md` | done | docs-only errata chooses ContractIR canonical source plus manifest `contract_index` load-time projection; `fragment_class: mixed` rejected as TEMPORAL authority |
| `temporal-requirements-from-escape-boundaries-v0.md` | implemented | `requirements.json` now derives caps/effects/fragments from SemanticIR `escape_boundaries`; CORE, History, BiHistory, and Stream requirements differ in proof |
| `typed-emission-stage2-switch-decision-v0.md` | done | Meta Expert governance decision: Option B adopted — typed emission becomes sole Stage 2+ lowering path; switch gate = BiHistory source fixture parity PASS + stage2_close_candidate post-switch; next cards C5+C6 defined |
| `runtime-cache-proof-local-memoization-v0.md` | done | proof-local MemoryCacheStore validates CORE/TEMPORAL keys, stale/unknown rejection, provisional downgrade, and no raw input payload observations; no production cache |
| `descriptor-package-exposure-gate2-decision-v0.md` | decision-request | Gate 2 metadata-only package exposure request written; Gate 1 PASS reviewed; Gate 3 production binding explicitly closed |
| `../meta-proposals/syntax-pressure-review-results-v0.md` | research-review | S3-R3 pressure specimens reviewed; threshold, external pure, entrypoint/section routed toward proposal candidates; no syntax promoted to canon |
| `../meta-proposals/META-EXPERT-012-document-lifecycle-and-rotation-v0.md` | governance | document lifecycle/rotation methodology added; stale/lifecycle markers introduced for debt control |
| `../discussions/temporal-igapp-runtime-boundary-pressure-v0.md` | complete — routed | X1 pressure says deep-read proof-local load works, but manifest dispatch needed `contract_index` and load guard; both became R5 C1/C2 |

---

## Stage 3 Round 3 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `typed-emission-stage2-source-lowering-parity-v0.md` | done/blocked | typed source blockers dropped to 0; parity runner PASS with verdict blocked; `legacy_parity_delta_items=11`, `blocked_items=13`, `safe_to_switch_production_path=false` |
| `temporal-semanticir-access-node-v0.md` | done | typed History/BiHistory lower to `temporal_input_node` + `temporal_access_node`; fragment/capability/coordinate refs preserved; no parser syntax, cache, or production TBackend binding |
| `runtime-temporal-cache-contract-v0.md` | done | RuntimeMachine cache key/entry/freshness/observation contract defined from proof; no production memoization, cache store, or manifest change |
| `gem-release-automation-v0.md` | done | `bin/release-gate` PASS; gemspec, gem-native boundary, Stage 1, Stage 2, artifact build all PASS; local `.gem` and `.sha256` built; publish not attempted |
| `compatibility-report-descriptor-consumption-fixture-v0.md` | done | proof-local descriptor consumption fixture PASS; trusted/provisional/blocked cases covered; `runtime_enforced=false`; Gate 2 package exposure and Gate 3 production binding remain closed |
| `../meta-proposals/syntax-pressure-specimens-v0.md` | research-fixtures | Field Supply Watch v3 and Primitive Surface specimens/guides added as pressure artifacts only; no parser/spec/proposal/runtime changes |
| `../discussions/temporal-manifest-and-cache-boundary-pressure-v0.md` | complete — routed | S3-R3-X1 pressure: TEMPORAL survives through SemanticIR but not assembler boundary; `contract_file` temporal-node crash and manifest/requirements gaps routed |
| `stage3-round3-status-curation-v0.md` | done | S3-R3 map sync and R4 prep — this track |

## Stage 3 Round 2 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `typed-emission-canonical-shape-v0.md` | done/blocked | source-hash public identity and canonical compute JSON shape fixed; `package_facade_add` parity PASS; overall verdict still blocked with 7 remaining source-path blockers |
| `temporal-fragment-classifier-typechecker-v0.md` | done | PROP-028 first implementation boundary: History/BiHistory reads classify as TEMPORAL nodes that bind CORE values; TypeChecker preserves temporal metadata; SemanticIR/runtime/parser syntax still open |
| `temporal-cache-key-proof-v0.md` | done | proof-local CORE vs TEMPORAL cache-key model PASS; CORE-shaped keys for temporal evaluation are stale-collision bugs; no RuntimeMachine memoization added |
| `gem-release-policy-v0.md` | done | gem metadata placeholders closed; local release gate named; RubyGems publish requires Architect approval and human owner; CI/release automation still open |
| `../bridge/compatibility-report-descriptor-consumption-v0.md` | done | report-only bridge proposal: CompatibilityReport may consume descriptor metadata as backend evidence with `runtime_enforced: false`; no Ledger read/write/replay/runtime binding |
| `../meta-proposals/syntax-pressure-registry-v0.md` | research-registry | comprehension fixtures indexed as canon/proposal/pressure/non-canon experiment; no fixture syntax promoted to canon |
| `stage3-round2-status-curation-v0.md` | done | S3-R2 map sync and R3 prep — this track |

## Stage 3 Round 1 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `stage3-governance-opening-v0.md` | done | Stage 3 formally OPEN (2026-05-08); META-EXPERT-011; 5 lanes authorized; PROP-028 authorized; R1 cards issued |
| `../proposals/PROP-028-temporal-fragment-class-v0.md` | proposal | TEMPORAL fragment class proposal written; OOF > TEMPORAL > STREAM > CORE; cache key semantics specified |
| `typed-emission-main-path-parity-v0.md` | blocked | parity runner PASS with verdict blocked; do not switch orchestrator to `emit_typed` yet; 9 blocked items recorded |
| `../archive/snapshots/2026-05-07-stage2-close/README.md` | done | Stage 2 close snapshot archived as cold archaeology context |
| `../meta-proposals/axiomatic-and-system-forming-ideas-lens-v0.md` | research-note | АИ/СОИ captured as soft Stage 3 design lens, not spec/canon and not a hard gate |
| `stage3-round1-status-curation-v0.md` | done | S3-R1 map sync and R2 prep — this track |

## Stage 2 Round 15 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `../meta-proposals/META-EXPERT-009.1-stage2-close-decision-v0.md` | decision | Stage 2 formally CLOSED WITH DEFERRED GAPS on 2026-05-07; close candidate PASS, 8 proofs, 7 surface checks, 5 deferred gaps |
| `gem-native-package-boundary-specs-v0.md` | done | installed gem require/compile/igc proof PASS from isolated gem home; 7 checks PASS, 4 release-readiness gaps remain |
| `../meta-proposals/human-agent-comprehension-synthesis-v0.md` | research-synthesis | comprehension pressure synthesized; routes Stage 3 syntax experiments without canon promotion |
| `future-syntax-pressure-formalization-v0.md` | done | formal grammar questions extracted from pressure fixtures; no parser changes and no canon promotion |
| `stage2-round15-status-curation-v0.md` | done | R15 map sync and Stage 3 intake prep — this track |

## Stage 2 Round 14 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `stage2-close-candidate-v0.md` | done | close candidate runner PASS; JSON status `PASS`, verdict `stage2_close_candidate`, proofs_run=8, surface_checks=7, deferred_gaps=5 |
| `packages/igniter-ledger/docs/tracks/ledger-tbackend-adapter-descriptor-package-v0.md` | done | package-side metadata-only descriptor implemented; targeted package spec 9 examples, 0 failures |
| `stage2-round14-status-curation-v0.md` | done | R14 map sync — this track |

## Stage 2 Round 13 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `compiler-packaging-skeleton-v0.md` | done | prerelease gem skeleton, `IgniterLang::VERSION`, package CLI, and `bin/igc`; gem build/install and installed `igc compile` smokes PASS |
| `stage2-close-candidate-planning-v0.md` | done | planning-only R14 close runner design; target JSON schema, proof list, fixtures, and deferred gaps defined |
| `ledger-tbackend-adapter-descriptor-package-plan-v0.md` | done | package-side descriptor-only implementation plan; no runtime/Ledger operation binding authorized |
| `stage2-round13-status-curation-v0.md` | done | R13 map sync — this track |

## Stage 2 Round 12 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `runtime-smoke-extraction-v0.md` | done | `IgniterLang::RuntimeSmoke` extracted; CLI uses reusable callback; production compiler, assembler, and Stage 1 proofs PASS |
| `compiler-package-boundary-v0.md` | done | direct API, CLI, and load-path proof share `IgniterLang.compile(...)`; no gemspec/bin/version release packaging yet |
| `ledger-tbackend-adapter-descriptor-v0.md` | done | metadata-only Ledger descriptor fixture PASS; descriptor hash, registry hash, and missing-history diagnostics proven |
| `runtime-invariant-violation-observations-v0.md` | done | invariant violations emit runtime observation records linked to source `invariant_node`; invariant proof and Stage 1 PASS |
| `stage2-round12-status-curation-v0.md` | done | R12 map sync — this track |

## Stage 2 Round 11 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `packageable-compiler-api-v0.md` | done | top-level `IgniterLang.compile(...)` facade added; CLI delegates to facade; production compiler, SemanticIR, assembler, and Stage 1 proofs PASS |
| `invariant-severity-semanticir-lowering-v0.md` | done | typed invariants lower to `invariant_node`; output effect propagation and invariant coverage preserved; invariant proof PASS |
| `tbackend-ledger-bridge-conformance-v0.md` | done | docs-only Ledger-backed TBackend conformance map; descriptor-first, metadata-only package slice recommended |
| `stage2-round11-status-curation-v0.md` | done | R11 map sync — this track |

## Stage 2 Round 10 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `compiler-orchestrator-v0.md` | done | lib/igniter_lang/compiler_orchestrator.rb extracted |
| `stream-semanticir-surface-lowering-v0.md` | done | stream SemanticIR lowering PASS; stream_t_proof PASS |
| `production-tbackend-adapter-fixture-v0.md` | done | proof-local AdapterRegistry + CompatibilityReport persistence |
| `invariant-severity-parser-impl-v0.md` | done | PINV-1..4 + TINV-1..3 PASS; +3 typechecker cases |
| `stage2-round10-map-and-role-profile-refresh-v0.md` | done | R10 map sync — this track |

## Stage 2 Round 9 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `extract-assembler-module-v0.md` | done | lib/igniter_lang/assembler.rb extracted; Stage 1 goldens PASS; CLI PASS |
| `production-tbackend-adapter-shape-v0.md` | done | Docs-only: TBackend adapter shape spec; no code changes |
| `semanticir-stage2-surface-lowering-v0.md` | done | OLAP SemanticIR lowering in emitter; olap_point_proof PASS; stage1 PASS |
| `stage2-round9-map-refresh-v0.md` | done | R9 map sync — this track |

## Stage 2 Round 8 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `extract-semanticir-emitter-module-v0.md` | done | `lib/igniter_lang/semanticir_emitter.rb` extracted; source→SemanticIR golden PASS |
| `olap-point-typechecker-semanticir-v0.md` | done | OOF-O2..O5; `olap_access_node`; explicit `dims_record`; OLAP proof PASS |
| `stream-oof-s3-typechecker-v0.md` | done | ESCAPE-in-fold TypeChecker rule; stream OOF-S1..S5 all proven |
| `production-runtime-machine-temporal-access-integration-v0.md` | done | RuntimeMachine load/evaluate proof-local hook integration; TBackend adapter still future |

## Stage 2 Round 7 Evidence

| Track | Status | Notes |
|-------|--------|-------|
| `extract-typechecker-module-v0.md` | done | lib/igniter_lang/typechecker.rb extracted; typechecker_proof + CLI PASS |
| `stream-oof-s2-classifier-v0.md` | done | OOF-S2 missing-window classifier rule; golden PASS; semanticir golden PASS |
| `runtime-machine-temporal-access-hook-proof-v0.md` | done | RuntimeMachineHook wired in history+bihistory proofs; both PASS |
| `olap-point-parser-implementation-v0.md` | done | revenue_point.ig parses live; olap_points[]; dims_record; parser spec 61 PASS |
| `stage2-round7-map-refresh-v0.md` | done | R7 map sync — this track |

## Stage 2 Round 6 Evidence (summary)

| Track | Status | Notes |
|-------|--------|-------|
| `extract-classifier-module-v0.md` | done | lib/igniter_lang/classifier.rb extracted |
| `stream-classifier-escape-propagation-v0.md` | done | SC-1/2/3 ESCAPE propagation; semanticir goldens 6→9 |
| `runtime-machine-temporal-access-hook-v0.md` | done | RuntimeMachineHook spec + smoke |
| `olap-point-parser-typechecker-boundary-v0.md` | done | Grammar spec: dims_record, OOF-O1..5; olap_point_proof 21 PASS |

---

## igniter-lang/lib — Current State (14 files)

```text
igniter_lang.rb           (R11/R13/S3-R44) — package facade; exposes VERSION + compile; bounded PROP-036 compiler_profile_source facade transport
igniter_lang/version.rb   (R13) — prerelease package version
igniter_lang/cli.rb       (R13) — thin package CLI for igc compile
diagnostics.rb            (R3)
compiler_result.rb        (R4)
compilation_report.rb     (R4)
parser.rb                 (R5/R7/R10) — parser + stream + olap_point + invariant
temporal_access_runtime.rb (R5–R7) — MemoryBackend + RuntimeMachineHook
temporal_executor.rb    (S3-R16) — proof-local Phase1 History[T] valid_time executor boundary; live blocked by default
runtime_smoke.rb          (R12) — reusable proof-backed RuntimeSmoke callback
classifier.rb             (R6/R7/S3-R2/R3) — ParsedProgram→ClassifiedProgram; stream/temporal metadata
typechecker.rb            (R7/R8/R10/S3-R2/R3) — TypedProgram boundary; stream/OLAP/invariant/TEMPORAL
semanticir_emitter.rb     (R8/R9/R10/R11/S3-R3) — SemanticIR emitter; typed temporal lowering
assembler.rb              (R9/S3-R4/R5/S3-R42) — .igapp/ assembler; temporal nodes + manifest contract_index + bounded PROP-036 compiler_profile_id field
compiler_orchestrator.rb  (R10/S3-R5/S3-R43) — compiler pass orchestration; production path uses emit_typed; bounded PROP-036 compiler_profile_source pass-through
```

---

## Stage 3 Next Recommendations

| Candidate | Purpose | Role | Status |
|-----------|---------|------|--------|
| P-50 PROP-032 Ch2/Heat Map sync | Confirm/apply S3-R36-C2-A follow-up docs for Ch2 source grammar and governance maps; keep PROP-033 evidence validation/runtime receipts excluded | Meta Expert / Compiler/Grammar Expert | closed by `prop032-assumptions-spec-sync-and-temporal-specimen-disposition-v0.md` |
| P-52 temporal audit specimen disposition | Decide/archive/map `experiments/pressure-specimens/temporal-audit-pressure-v0/` without making it canonical by accident | Meta Expert / Research Agent | closed by `prop032-assumptions-spec-sync-and-temporal-specimen-disposition-v0.md` |
| P-56 pre-Gate-3 Line Up edits | Apply RQ-1/RQ-2 to `old-discussions-pre-gate3-spine.md` before R2-R12 discussion-index redirects or movement | Line Up Summarizer / docs agent | closed by `pre-gate3-lineup-rq1-rq2-revision-v0.md`; no movement performed |
| P-55 Gate 3 Line Up verification | Archive/Form verification of `gate3-r13-r22-discussions-spine.md` before movement or discussion-index redirects | Archive/Form Expert | closed by `gate3-r13-r22-lineup-authority-verification-v0.md`; redirects still need no-zombie checks |
| PROP-037 descriptor OOF-PR proof | Proof-local descriptor validation for OOF-PR1..5, OOF-PR7, and OOF-PR9; readiness refusal remains separate from OOF | Research Agent / Compiler/Grammar Expert | closed by `prop037-descriptor-oof-pr-proof-v0.md`; OOF-PR6/8 remain deferred |
| Gate 3 Line Up optional hardening | Rename remaining historical blocker wording and add current-status/gates pointer before primary redirect use | History Curator / Line Up Summarizer | closed by `gate3-r13-r22-lineup-historical-blockers-hardening-v0.md`; no movement/deletion |
| P-57 discussion-index additive grouping | Add group rows and authority notes to `docs/discussions/README.md` while preserving direct source rows | History Curator / Docs agent | new from R41 X1; requires supervisor approval, no movement/deletion |
| durable-audit rollout implementation review | Architect review of design-only readiness plan before any operational implementation or rollout authorization | Architect Supervisor / Implementation Agent | readiness plan done; implementation/rollout still closed |
| PROP-037 CompatibilityReport readiness proof | Show progression metadata can be present while runtime readiness stays false with stable refusal | Compiler/Grammar Expert / Research Agent | closed by `prop037-compatibility-report-readiness-proof-v0.md`; report-only, no scheduler/runtime auth |
| PROP-037 `progression_sources` schema contract | Decide manifest vs CompatibilityReport ownership for progression metadata while keeping runtime readiness closed | Compiler/Grammar Expert / Bridge Agent | next from R41 C1/X1; implementation-facing ambiguity |
| PROP-037 OOF-PR6/8 AST boundary | Define/prove compiler-owned progression AST/typed fragment context before descriptor/typed mismatch diagnostics | Compiler/Grammar Expert / Research Agent | follow-up opened by R40 C1; no parser/runtime auth |
| PROP-037 profile descriptor specialization proof | Prove `external_event` specialization below closed top-level source kinds | Compiler/Grammar Expert / Bridge Agent | authorized design/proof follow-up; no production listener/queue |
| context-capture-pack-shadow-boundary-v0 | Explore a descriptor-only context capture pack boundary from Line Up / Contextizer pressure without canonizing the specimen | Architect Supervisor / Compiler-Profile Agent | closed as design/research-only shadow boundary by R41 C4/C5; no implementation/canon |
| context-capture-descriptor-proof-v0 | Validate capture source descriptors, policy refs, evidence links, and non-authorization flags without runtime/package authority | Research Agent / Compiler-Profile Agent | candidate next; keep source_kind values candidate-only until formal closure |
| PROP-036 assembler/source/orchestrator/facade chain | Keep current bounded implementation state visible: source finalization proof, assembler field, orchestrator transport, Ruby facade exposure, B1 formal closure, bounded CLI transport proof, full CLI blocker package closure, release-readiness completion, and release-confidence smoke | Meta Expert / Compiler/Grammar Expert | current through R55; no broad migration; R55 moves next pressure to proof-only obligation coverage, not more CLI work |
| PROP-036 CLI exposure design/tracking | Decide CLI input shape, refusal wording, nil/no-flag legacy proof, negative scan coverage, and pressure review before any CLI implementation | Architect Supervisor / Compiler/Grammar Expert | design route closed by R45 C3-A; blocker package closed by R51; release-readiness condition satisfied by R53 |
| PROP-036 CLI blocker closure criteria | Tighten B1 standalone artifact closure, B3 refusal output shape, B3->B6 scan surface, and B7/B8 docs completion bars | Architect Supervisor / Research Agent / Docs agent | closed by R46 C4-A; no CLI implementation |
| PROP-036 B7/B8 Ruby API docs | Land caller-facing `docs/ruby-api.md` or approved API path with source-shape and transport-only wording; link from docs README; record source-level visibility landed or deferred | Compiler/Grammar Expert / Docs agent | closed by R47 C3-A; source-comment visibility Architect-deferred for this phase |
| PROP-036 closure criteria minor addendum | Add B6 scanner self-test, B8-C deferral authority, and B1 validation-chain specificity to governing criteria before implementation authorization | Architect Supervisor / External Pressure Reviewer | closed by R47 C3-A; implementation still held |
| PROP-036 B1 standalone artifact proof | Emit and validate `compiler_profile_source.stage3_proof.json` through the compiler-profile-source validation chain and scan exact forbidden tokens | Research Agent / Compiler/Grammar Expert | evidence satisfied by R48 C1/C2; formally closed by R49 C1-A; no CLI implementation |
| PROP-036 B1 formal closure gate | Explicitly accept or hold the R48 B1 artifact evidence before any implementation authorization cites B1 as closed | Architect Supervisor | closed by R49 C1-A; implementation still held |
| PROP-036 CLI B3/B4/B5/B6 package | Authorize and prove the remaining CLI implementation-facing package, with B6 adversarial scanner self-test as a named sub-deliverable | Architect Supervisor / Implementation Agent / Research Agent | evidence complete in R50; formally closed by R51 C1-A/C2-X |
| PROP-036 CLI B3/B4/B5/B6/B9 closure gate | Formally close or hold the remaining CLI blockers by citing the R50 C2-I proof and C3-X pressure verdict | Architect Supervisor | closed by R51 C1-A; full `PROP036-CLI-B1..B9` blocker package closed |
| PROP-036 CLI production/release readiness gate | Decide whether the already-bounded `--compiler-profile-source PATH.json` CLI transport can be promoted as-is or must hold for additional review; explicitly keep closed or reopen non-authorized surfaces by name | Architect Supervisor / External Pressure Reviewer | package-surface release-readiness complete in exact R52 scope after R53; production/runtime authority still closed |
| PROP-036 CLI caller-facing docs sync | Update `docs/ruby-api.md` or a linked CLI doc with exact bounded CLI flag shape, finalized-source input shape, no-flag legacy behavior, preflight/semantic refusals, transport-only semantics, no discovery/defaulting/finalization, and excluded surfaces | Docs Agent / Compiler/Grammar Expert / Status Curator | closed by R53 C1/C2; README navigation link closed by R54 C2/C3 |
| PROP-036 CLI release-confidence smoke/navigation | Confirm bounded CLI behavior from caller perspective and make CLI docs discoverable from docs index without widening scope | Research Agent / Archive/Form Expert / External Pressure Reviewer | closed by R54; smoke 5/5 PASS and docs navigation polished |
| PROP-036 CLI production-promotion / release-engineering | Exercise the bounded CLI transport outside proof context or promote toward production/package release if needed, without widening runtime authority | Architect Supervisor / Release Agent / External Pressure Reviewer | optional future only if Architect requests installed gem / bundled executable confidence; separate authorization required |
| compiler-profile-obligation-coverage-proof-v0 | Prove report-only mapping from fixture language surfaces to required compiler profile slots and finalized `compiler_profile_id_source` coverage statuses | Research Agent | closed by R56 C1/C2/C3; accepted as proof-local/report-only/output-only; implementation still held |
| compiler-profile-contract-boundary-v0 | Design the later `compiler_profile_contract` boundary after obligation coverage proof clarifies coverage semantics | Compiler/Grammar Expert / Architect Supervisor | closed by R57 C1/C2/C3/C4; accepted as design record; implementation still held |
| compiler-profile-contract-proof-v0 | Prove canonical `compiler_profile_contract` object shape, diagnostic separation, future `profile_not_supplied` shape, and execution ordering without touching live compiler or artifacts | Research Agent | authorized as R58 proof-local next track by `compiler-profile-contract-boundary-decision-v0.md`; no implementation, dispatch, loader/report, CompatibilityReport, runtime, or production authority |
| PROP-036 golden migration | Name exact `.igapp` fixtures and expected hash churn before migrating any existing goldens | Compiler/Grammar Expert / Research Agent | still blocked; no existing golden migration |
| PROP-036 loader/report status | Implement/report `absent_legacy`, `present_verified`, `mismatch`, `malformed`, `missing_required` separately from assembler/orchestrator | Bridge Agent / Compiler/Grammar Expert | still blocked behind separate authorization |
| PROP-036 CompatibilityReport section | Design/prove compiler-profile section without runtime readiness or Gate 3 authority | Bridge Agent / Research Agent | still blocked behind separate authorization |
| PROP-036 caller-facing facade docs | Document the accepted finalized source shape for `IgniterLang.compile` without adding finalization/discovery/defaulting behavior | Compiler/Grammar Expert / Docs agent | dev-contract wording landed in R45 C2; guide/API docs still pending |
| rollout kind-name consistency check | In any future rollout implementation card, confirm `phase1_audit_storage` matches storage identity acceptance/refusal logic | Implementation Agent / Architect Supervisor | NB from R39 X1 |
| mundane OOF fixture planning | Plan OOF-MA1/MA2/MA3 fixtures from blind mundane pressure without canonizing stdlib/effect/runtime behavior | Compiler/Grammar Expert / Research Agent | pressure-only, non-canonical; NB from R37 X1 |
| OQ-P28-1 escape naming answer | Verify whether unnamed `escape` declaration is currently parse error; update Covenant P28 table | Compiler/Grammar Expert | still open; route before PROP-035 |
| OOF-I1/I3/I5 closure | PROP-025 addendum + targeted fixtures for deferred invariant OOF anchors | Research Agent / Compiler/Grammar Expert | still deferred; route when invariant lane reopens |
| `_volatile_fields` Time.now grep hook | Detect newly-added unannotated `Time.now` usage in experiment scripts | Implementation Agent / Research Agent | optional follow-up; not required for R28 close |
| registry implementation planning | Draft generated index schema and proof plan under registry implementation authorization gate | Bridge Agent / Architect Supervisor | deferred; audit blockers first |
| production `git_commit` compliance amendment | Treat `workspace-current` as non-compliant outside proof-local mode; require CI/registry-supplied immutable ref | Bridge Agent / Research Agent | before production |
| `gate3-production-signing-v1` | Production signer identity, key rotation, signature algorithm, verification policy, deployment trust store | Bridge Agent / Architect Supervisor | after registry v1 |
| Phase 2 Ledger adapter addendum | Separate Architect decision for real Ledger adapter/package binding; not enabled by signed Phase 1 addendum | Architect Supervisor / Bridge Agent | closed until separate decision |
| `gate3-authority-registry-v0` | Define trusted authority/revocation source for PROP-030 tokens before Phase 2; do not imply live Ledger binding | Bridge Agent + Research Agent | before Phase 2 |
| `gate3-phase2-addendum-process-v0` | Define explicit Architect addendum route for real Ledger adapter/package binding after Phase 1 | Meta Expert / Bridge Agent | before Phase 2 |
| `external-http-json-capability-pressure-v0` | Define minimum HTTP/JSON capability profile: request, response, error, redaction, replay, receipt, and refusal cases | Compiler/Grammar Expert + Bridge Agent | pressure backlog |
| `controlled-agent-replication-boundary-pressure-v0` | Define spawn intent/receipt, resource budget, authority inheritance, and refusal diagnostics before emergency mesh fixtures | Research Agent + Bridge Agent | pressure backlog |
| `data-role-vocabulary-specimen-v0` | Narrow `packet/event/receipt` pressure into evidence/receipt/proof vocabulary candidates without parser promotion | Compiler/Grammar Expert | pressure backlog |
| `store-declaration-surface-pressure-v0` | Continue recurring `store` pressure across History/BiHistory/product fixtures without implying live evaluation | Compiler/Grammar Expert + Research Agent | pressure backlog |
| `compatibility-report-package-adoption-v0` | Package/Bridge adoption of report-only descriptor consumption shape while preserving `runtime_enforced=false` and no live binding | Bridge Agent / Package Agent | recommended |
| `spec-ch6-invariant-source-metadata-sync-v0` | Document optional `source_metadata` / `source_span` on `invariant_node` and invariant coverage report entries | Compiler/Grammar Expert | docs/spec sync |
| `entrypoint-section-parser-typechecker-v0` | Implement and prove PROP-029 contextual parser/typechecker behavior only after proposal acceptance | Compiler/Grammar Expert | gated |
| `gem-release-ci-wiring-v0` | Wire `bin/release-gate` into CI or preserve release artifacts/checksum under an approved release record; publish remains gated | Research Agent | optional |
| `syntax-thresholds-and-constants-prop-v0` | Draft proposal for named thresholds/constants from S3-R4 review signals; no parser implementation yet | Compiler/Grammar Expert | proposal |
| `syntax-external-pure-helper-signatures-prop-v0` | Draft proposal for `external pure fn(...) -> T` helper signatures and effect/evidence annotations | Compiler/Grammar Expert + Bridge Agent | proposal |
| `invariant-persistence-boundary-v0` | Production RuntimeMachine invariant observation persistence boundary remains open from Stage 3 intake | Research Agent | authorized |
| `typed-emission-post-switch-baseline-v0` | Archive/normalize post-switch public compile goldens and document parsed emitter as Stage 1 legacy comparison only | Research Agent | optional |

---

## Handoff Template

```text
Card:
Agent: [Igniter-Lang <Agent Name>]
Role: <role-profile-id>
Track:
Status:

[D] Decisions
- ...

[S] Shipped / Signals
- ...

[T] Tests / Proofs
- ...

[R] Risks / Recommendations
- ...

[Next] Suggested next slice
- ...
```
