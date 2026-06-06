# Canonical Semantic Model (CSM)

Status: index (living document)
Date: 2026-05-11
Author: `[Igniter-Lang Meta Expert]`
Source: S3-R29-C2-P (R28 meta-card) + S3-R29-C5-P (R29 bootstrap) + S3-R34-C3-S (PROP-036 placeholder sync)

> The CSM is a verifiable index, not a design document.
> If an entity lacks a golden anchor, its status is at most `spec_candidate`.
> Golden paths are relative to `igniter-lang/experiments/`.

---

## Schema

| Column | Meaning |
|--------|---------|
| `entity` | Language concept name |
| `status` | See status legend below |
| `pipeline_entry_point` | First compiler stage where the entity appears |
| `classifier_fragment` | Fragment class assigned by the Classifier (`core / escape / temporal / stream / oof / N/A`) |
| `golden_anchor` | Representative golden file that proves the entity is real |
| `PROP` | Authorizing or planned PROP |
| `Covenant` | Governing postulate(s) |

**Status legend:**

| Value | Meaning |
|-------|---------|
| `implemented` | In a closed stage (Stage 1 or Stage 2) or in the active production compiler path with runtime support |
| `experiment-pass` | Stage 3 proof PASS; golden files exist; compiler stages wired; not yet in a closed stage |
| `spec_candidate` | Documented in spec chapter or gap analysis; no experiment PASS; no golden anchor |
| `proposed` | PROP written; fixture plan exists; no experiment PASS |

---

## Entity Index

### Contract + Modifiers

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| Contract (pure, unmodified) | implemented | Parser | `core` | `contract_modifiers_proof/golden/pure_contract_implicit.semantic_ir.json` | PROP-031 | P1, P2 |
| Contract modifier: `pure` (explicit) | implemented | Parser | `core` | `contract_modifiers_proof/golden/pure_contract_explicit.semantic_ir.json` | PROP-031 | P1, P2 |
| Contract modifier: `observed` | experiment-pass | Parser | `escape` or `temporal`† | `contract_modifiers_proof/golden/observed_contract_basic.semantic_ir.json` (escape path); `contract_modifiers_proof/golden/observed_temporal_precedence.classified.json` (temporal path — V-3) | PROP-031 | P4, P7 |
| Contract modifier: `effect` | experiment-pass | Parser | `escape` | `contract_modifiers_proof/golden/modifier_variants.semantic_ir.json` | PROP-031 | P4, P17, P19 |
| Contract modifier: `privileged` | experiment-pass | Parser | `escape` | `contract_modifiers_proof/golden/modifier_variants.semantic_ir.json` | PROP-031 | P9 |
| Contract modifier: `irreversible` | experiment-pass | Parser | `escape` | `contract_modifiers_proof/golden/modifier_variants.semantic_ir.json` | PROP-031 | P17, P19 |

†`observed` yields `temporal` when body contains `History[T]` or `BiHistory[T]` reads;
`escape` otherwise. See PROP-031 §4.1 and §14.4.

### Type Declaration

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| Type declaration (basic: Integer, String, Bool, Decimal[N]) | implemented | Parser | `core` (embedded in contract) | `source_to_semanticir_fixture/golden/add.semantic_ir.json` | PROP-003, PROP-004 | P2, P11 |
| Record type (struct-shaped: `type Foo { fields }`) | implemented | Parser | `core` | `source_to_semanticir_fixture/golden/claim_evidence.semantic_ir.json` | PROP-003, PROP-004 | P2 |
| `History[T]` type annotation | experiment-pass | Parser | `temporal` (node-level) | `temporal_semanticir_access_node/golden/history_valid.semantic_ir.json` | PROP-022, PROP-028 | P3 |
| `BiHistory[T]` type annotation | experiment-pass | Parser | `temporal` (node-level) | `temporal_semanticir_access_node/golden/bihistory_valid.semantic_ir.json` | PROP-022, PROP-028 | P3 |

### Receipt

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| Receipt (runtime execution trace) | implemented | Runtime (post-SemanticIR) | N/A — runtime artifact | `runtime_machine_memory_proof/ffi_ruby_receipt_fixtures/ffi_ruby_receipts.golden.json` | PROP-008 | P8 |

**Note:** Receipt shape is defined by runtime contract (PROP-008). Full production receipt
semantics (authority, compensation, audit reference) are gated on PROP-035 (Effect Surface).
The golden anchor covers FFI-level receipt descriptors only.

### Escape Declaration

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| `escape NAME` declaration (body-level) | implemented | Parser | `escape` (node-level) | `contract_modifiers_proof/golden/observed_contract_basic.semantic_ir.json` | PROP-031 | P4, P7, P28 |
| `escape_boundaries` in SemanticIR | implemented | SemanticIR Emitter | — (field on `contract_ir`) | `contract_modifiers_proof/golden/observed_contract_basic.semantic_ir.json` | PROP-031 | P7 |

### Stream Node

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| `stream NAME: T` declaration | implemented | Parser | `stream` | `source_to_semanticir_fixture/golden/stream_ingress_escape.parsed_ast.json` | PROP-023 | P14 |
| `window "key" { kind, size, on_close }` | implemented | Parser | `stream` | `source_to_semanticir_fixture/golden/stream_ingress_escape.parsed_ast.json` | PROP-023 | P14 |
| `fold_stream(src, init, fn) @window_bounded` | implemented | Parser → SemanticIR | `core` (output value) | `source_to_semanticir_fixture/golden/stream_fold_core.parsed_ast.json` | PROP-023 | P14 |

### Temporal Read

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| `History[T]` read (`history_at(src, as_of)`) | experiment-pass | Parser | `temporal` | `temporal_semanticir_access_node/golden/history_valid.semantic_ir.json` | PROP-022, PROP-028 | P3 |
| `BiHistory[T]` read (valid_time + transaction_time) | experiment-pass | Parser | `temporal` | `temporal_semanticir_access_node/golden/bihistory_valid.semantic_ir.json` | PROP-022, PROP-028 | P3 |
| `temporal_input_node` (SemanticIR node) | experiment-pass | SemanticIR Emitter | — (node type in `contract_ir`) | `temporal_semanticir_access_node/golden/history_valid.semantic_ir.json` | PROP-028 | P3 |
| `temporal_access_node` (SemanticIR node) | experiment-pass | SemanticIR Emitter | — (node type in `contract_ir`) | `temporal_semanticir_access_node/golden/history_valid.semantic_ir.json` | PROP-028 | P3 |

### Assumption

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| `assumptions { assumption NAME { ... } }` block | proposed | Parser | `epistemic` (new — PROP-032 §5.1) | — | PROP-032 | P22, P27, P28 |
| `uses assumptions NAME` declaration | proposed | Classifier | `epistemic` | — | PROP-032 | P22, P28 |

### Form Constructor

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| `form NAME -> TypeTarget` constructor | spec_candidate | Parser (Gap-I) | — | — | TBD | P27, P28 |

### Loop Class

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| Loop class: `finite_by_collection` | spec_candidate | Parser (Stage 3 Language Lane) | — | — | PROP-037+ placeholder | P14, P28 |
| Loop class: `finite_by_fuel` | spec_candidate | Parser (Stage 3 Language Lane) | — | — | PROP-037+ placeholder | P14 |
| Loop class: `convergent_by_metric` | spec_candidate | Parser (Stage 3 Language Lane) | — | — | PROP-037+ placeholder | P14 |
| Loop class: `alive_by_liveness` (service loop) | spec_candidate | Parser (Stage 3 Language Lane) | — | — | PROP-037+ placeholder | P14 |

---

## OOF Code Registry

All active OOF codes are detected in the **Classifier** stage. Each produces a
`fragment_class: "oof"` on the containing contract and propagates to `type_errors`
via the TypeChecker.

| code | triggers when | golden_anchor | PROP | Covenant |
|------|--------------|---------------|------|----------|
| OOF-M1 | `pure` contract body declares `escape`-class capability | `contract_modifiers_proof/golden/oof_m1_pure_with_escape.classified.json` | PROP-031 | P4, P7 |
| OOF-P1 | Unresolved compute dependency or output source symbol | `classifier_pass_proof/golden/negative_unresolved_symbol.classified.json` | PROP-018, PROP-020 | P2 |
| OOF-S2 | `stream` declared without a `window` block | `classifier_pass_proof/golden/negative_stream_missing_window.classified.json` | PROP-023 | P14 |
| OOF-S4 | Stream value used directly (must use `fold_stream`) | `classifier_pass_proof/golden/negative_stream_direct_use.classified.json` | PROP-023 | P14 |
| OOF-CE4 | `ConfidenceLabel` value used where `Bool` is expected | `classifier_pass_proof/golden/negative_confidence_bool.classified.json` | PROP-025 | P11 |
| OOF-OS2 | `EvidenceLinkedAlert` output missing `signal_refs` or `claim_refs` | `classifier_pass_proof/golden/negative_evidence_less_alert.classified.json` | PROP-025 | P22 |
| OOF-I1 | `@bitemporal` invariant on non-bitemporal type (deferred) | — | PROP-025 (deferred) | P14 |
| OOF-I3 | `~T` invariant shape violation (deferred) | — | PROP-025 (deferred) | P14 |
| OOF-I5 | (deferred invariant OOF, exact condition TBD) | — | PROP-025 (deferred) | P14 |

---

## Missing Anchor Log

Entities without a golden anchor as of R29. All are at most `spec_candidate`.

| entity | gap | blocking PROP |
|--------|-----|---------------|
| `assumptions {}` block | Gap-H — PROP-032 authored (S3-R30-C6-P); no compiler implementation yet | PROP-032 |
| `uses assumptions NAME` | Gap-H — PROP-032 authored; no classifier implementation yet | PROP-032 |
| `form NAME -> T` | Gap-I — no parser keyword, no fragment class | TBD |
| Loop class (all variants) | Stage 3 Language Lane — no parser, no classifier; PROP-036 is occupied by `compiler_profile_id` | PROP-037+ placeholder |
| OOF-I1 | Stage 2 deferred invariant OOF | PROP-025 addendum |
| OOF-I3 | Stage 2 deferred invariant OOF | PROP-025 addendum |
| OOF-I5 | Stage 2 deferred invariant OOF | PROP-025 addendum |
| Receipt (production shape) | Effect Surface not yet implemented | PROP-035 |

---

## R30 Recommendations

**Promote from `spec_candidate` → `experiment-pass`:**

1. **Assumption (PROP-032)**: Gap-H is rated HIGH priority in the gap analysis.
   PROP-032 bootstrap is the C3 deliverable of R29. Once the PROP is written, the
   Research Agent can create the minimum fixture (one positive, one OOF case for
   undeclared assumption in contract body) to generate a golden anchor.

2. **OOF-I1, OOF-I3, OOF-I5**: deferred from Stage 2. No new PROP needed — these
   are addenda to PROP-025. A focused experiment pass would close the missing anchors.

**Do not promote yet:**

- **Form constructor**: Gap-I has no PROP. Promote only after a PROP draft establishes
  grammar, classifier fragment class, and at minimum one positive fixture.
- **Loop class**: Stage 3 Language Lane. Requires a PROP before any fixture work.
  No date or priority set in gap analysis.

**CSM maintenance rule:**

> If you add a new entity to the compiler, add a row here. If the row has no golden
> anchor, the status is `spec_candidate`. If you remove an entity, remove the row.
> The CSM is not aspirational — it reflects what exists, verifiably.
