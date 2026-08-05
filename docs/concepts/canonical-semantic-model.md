# Canonical Semantic Model (CSM)

Status: index (living document)
Date: 2026-07-20
Author: `[Igniter-Lang Meta Expert]` + `[Igniter-Lang Implementation Agent]`
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
| Derived record constructor source sugar | experiment-pass | Parser → pre-classify lowering | `core` after lowering to an ordinary pure contract | `derived_record_constructor_canon_parity_proof/golden/plan_email_send.normalized-contract-sir.json` | LANG-DERIVED-RECORD-CONSTRUCTOR-P2 | P1, P2, P27 |
| Contract modifier: `observed` | experiment-pass | Parser | `escape` or `temporal`† | `contract_modifiers_proof/golden/observed_contract_basic.semantic_ir.json` (escape path); `contract_modifiers_proof/golden/observed_temporal_precedence.classified.json` (temporal path — V-3) | PROP-031 | P4, P7 |
| Contract modifier: `effect` | experiment-pass | Parser | `escape` | `contract_modifiers_proof/golden/modifier_variants.semantic_ir.json` | PROP-031 | P4, P17, P19 |
| Contract modifier: `privileged` | experiment-pass | Parser | `escape` | `contract_modifiers_proof/golden/modifier_variants.semantic_ir.json` | PROP-031 | P9 |
| Contract modifier: `irreversible` | experiment-pass | Parser | `escape` | `contract_modifiers_proof/golden/modifier_variants.semantic_ir.json` | PROP-031 | P17, P19 |

†`observed` yields `temporal` when body contains `History[T]` or `BiHistory[T]` reads;
`escape` otherwise. See PROP-031 §4.1 and §14.4.

The derived record constructor is a source-surface entity only. Its parser
placeholder and named invocation are erased before classification; the golden
anchor records normalized ordinary-contract SIR and does not imply a constructor
SIR node, VM value, opcode, host capability, or runtime authority.

### Type Declaration

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| Type declaration (basic: Integer, String, Bool, Decimal[N]) | implemented | Parser | `core` (embedded in contract) | `source_to_semanticir_fixture/golden/add.semantic_ir.json` | PROP-003, PROP-004 | P2, P11 |
| Record type (struct-shaped: `type Foo { fields }`) | implemented | Parser | `core` | `source_to_semanticir_fixture/golden/claim_evidence.semantic_ir.json` | PROP-003, PROP-004 | P2 |
| `History[T]` type annotation | experiment-pass | Parser | `temporal` (node-level) | `temporal_semanticir_access_node/golden/history_valid.semantic_ir.json` | PROP-022, PROP-028 | P3 |
| `BiHistory[T]` type annotation | experiment-pass | Parser | `temporal` (node-level) | `temporal_semanticir_access_node/golden/bihistory_valid.semantic_ir.json` | PROP-022, PROP-028 | P3 |

### Variant Arm Identity

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| Qualified variant arm `Variant::Arm` in construction and patterns | experiment-pass | Parser → TypeChecker; qualifier erased before SemanticIR | enclosing contract unchanged | `variant_arm_qualified_construct_proof/verify_variant_arm_qualified_construct_p1.rb` (30/30) | LANG-VARIANT-ARM-QUALIFIED-CONSTRUCT-P1 | P27, P28 |

Accepted construction retains the existing `variant_construct` carrier
`{arm, variant, resolved_type}`. Bare `Arm { ... }` is compatibility sugar only
when exactly one visible user variant owns the arm; qualification and owner
selection introduce no VM carrier or runtime authority.

### First-class Option Carrier

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| `option_value_construct` (`Some` / `None`) | experiment-pass | TypeChecker → SemanticIR Emitter | enclosing contract unchanged | `option_runtime_carrier_convergence_p2/golden/ruby-option-carrier.semantic_ir.json` | LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 | P2, P11, P27 |
| `option_match` | experiment-pass | SemanticIR Emitter (statically resolved Option subject) | enclosing contract unchanged | `option_runtime_carrier_convergence_p2/golden/ruby-option-carrier.semantic_ir.json` | LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 | P2, P11 |
| `option_carrier_guard_v1` | experiment-pass | SemanticIR Emitter (first executable node in every contract) | `core` node; enclosing contract unchanged | `option_runtime_carrier_convergence_p2/golden/ruby-option-carrier.semantic_ir.json` | LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 | P2, P11, P28 |
| `stdlib.option.is_some` / `is_none` | experiment-pass | TypeChecker static Option overload | `core` | `option_runtime_carrier_convergence_p2/golden/ruby-option-carrier.semantic_ir.json` | LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 | P2, P11 |
| `stdlib.option.map` / `flat_map` / `and_then` | experiment-pass | TypeChecker static Option overload | `core` | `option_runtime_carrier_convergence_p2/golden/ruby-option-carrier.semantic_ir.json` | LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 | P2, P11 |
| `stdlib.result.map` / `and_then`; `result_unwrap_or` | experiment-pass | TypeChecker static Result overload | `core` | `option_runtime_carrier_convergence_p2/golden/ruby-option-carrier.semantic_ir.json` | LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 | P2, P11 |

The top-level marker is `option_carrier: "first_class_v1"`. The guard is an
executable downgrade fence, not provenance. The internal VM carrier is not a
source entity; Records are never reclassified as Option by field names.
Source overloads are resolved statically; runtime payload shape never selects
Option, Result, or Collection behavior. Result `flat_map` remains refused.

### Module Constant

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| Module `const` declaration and compile-time reference | experiment-pass | Parser → ConstResolver | `core` after literal substitution | `module_const_proof/golden/module_const_inlining.json` | LANG-MODULE-CONST-PROP-P3 | P2, P11 |

`const` has no SemanticIR entity of its own: the resolver replaces every use
with existing scalar/record/array literal nodes before classification.

### Receipt

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| Receipt (runtime execution trace) | implemented | Runtime (post-SemanticIR) | N/A — runtime artifact | `runtime_machine_memory_proof/ffi_ruby_receipt_fixtures/ffi_ruby_receipts.golden.json` | PROP-008 | P8 |

**Note:** Receipt shape is defined by runtime contract (PROP-008). The seven-field
Effect Surface is now emitted by both compilers, while runtime consumption remains
field-specific. Assumption refs and output-evidence refs are not yet copied into
live receipts. The golden anchor covers FFI-level receipt descriptors only.

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
| `assumptions { assumption NAME { ... } }` block | experiment-pass | Parser | `epistemic` (PROP-032 §5.1) | `assumptions_proof/golden/assumption_basic.semantic_ir.json` | PROP-032 | P22, P27, P28 |
| `uses assumptions NAME` declaration | experiment-pass | Classifier | `epistemic` | `assumptions_proof/golden/epistemic_only_pure.semantic_ir.json` | PROP-032 | P22, P28 |

### Epistemic and Execution Descriptors

| entity | status | pipeline_entry_point | classifier_fragment | golden_anchor | PROP | Covenant |
|--------|--------|---------------------|---------------------|---------------|------|----------|
| top-level `entrypoint ContractName` | implemented | Parser | N/A — program metadata | `entrypoint_descriptor_proof/out/valid_entrypoint.igapp/manifest.json` | PROP-ENTRYPOINT | P2, P27 |
| module/contract `intent "..."` descriptor | experiment-pass (Ruby canon only; Rust parity open) | Parser | unchanged — metadata only | `intent_descriptor_proof/` (53/53 proof) | PROP-045 | P27 |
| `output ... evidence [refs]` | experiment-pass | Parser | enclosing contract fragment | `output_evidence_proof/` (51/51 proof) | PROP-034 | P22, P27 |

See [Implemented Epistemic Surface](implemented-epistemic-surface.md) for the
compiler/runtime boundary. In particular, `assumption_refs` are not yet copied
into live runtime receipts and source `intent` is not Rust-parity.

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

Active OOF codes may originate in the Parser, Classifier, or TypeChecker. They
are emitted through the compiler's diagnostic envelope; classifier-owned codes
also produce `fragment_class: "oof"` on the containing contract.

| code | triggers when | golden_anchor | PROP | Covenant |
|------|--------------|---------------|------|----------|
| OOF-M1 | Pure-contract purity family: `escape`-class capability declaration or transitive ambient-I/O laundering through app-local defs | `contract_modifiers_proof/golden/oof_m1_pure_with_escape.classified.json`; igniter-lab P2 def-call corpus | PROP-031, PROP-051 | P4, P7 |
| OOF-P1 | Unresolved compute dependency or output source symbol | `classifier_pass_proof/golden/negative_unresolved_symbol.classified.json` | PROP-018, PROP-020 | P2 |
| OOF-S2 | `stream` declared without a `window` block | `classifier_pass_proof/golden/negative_stream_missing_window.classified.json` | PROP-023 | P14 |
| OOF-S4 | Stream value used directly (must use `fold_stream`) | `classifier_pass_proof/golden/negative_stream_direct_use.classified.json` | PROP-023 | P14 |
| OOF-CE4 | `ConfidenceLabel` value used where `Bool` is expected | `classifier_pass_proof/golden/negative_confidence_bool.classified.json` | PROP-025 | P11 |
| OOF-OS2 | `EvidenceLinkedAlert` output missing `signal_refs` or `claim_refs` | `classifier_pass_proof/golden/negative_evidence_less_alert.classified.json` | PROP-025 | P22 |
| OOF-KIND8 | A qualified arm is not a visible declared arm, or a bare user arm has zero or multiple visible owners | `variant_arm_qualified_construct_proof/verify_variant_arm_qualified_construct_p1.rb` | LANG-VARIANT-ARM-QUALIFIED-CONSTRUCT-P1 | P27, P28 |
| OOF-KIND9 | A qualified match pattern names a variant other than the known subject variant | `variant_arm_qualified_construct_proof/verify_variant_arm_qualified_construct_p1.rb` | LANG-VARIANT-ARM-QUALIFIED-CONSTRUCT-P1 | P27, P28 |
| OOF-VM-OPTION-CARRIER | Option marker/guard/carrier or typed host envelope is missing, incompatible, malformed, or excessive-depth | `option_runtime_carrier_convergence_p2/verify_option_runtime_carrier_p2.rb` | LANG-OPTION-RUNTIME-CARRIER-CONVERGENCE-P2 | P2, P11, P28 |
| OOF-L4 | Recursive `def` (member of a nontrivial call-graph SCC) without the literal `decreases fuel` | igniter-lab: `proofs/lang-app-local-def-call-canon-adoption-p2/specimen_corpus.py` | PROP-051 | P14 |
| OOF-L2 | Temporal access (`now()`) in `def` bodies or contract expressions | igniter-lab: `proofs/lang-app-local-def-call-canon-adoption-p2/specimen_corpus.py` | PROP-051 | P3 |
| OOF-F2 | Same-module `def` name collides with a visible stdlib callable (bare/ad-hoc or imported) or a derived/sealed constructor | igniter-lab: `proofs/lang-app-local-def-call-canon-adoption-p2/specimen_corpus.py` | PROP-051 | — |
| OOF-F3 | Duplicate `(module, name)` `def` declaration | igniter-lab: `proofs/lang-app-local-def-call-canon-adoption-p2/specimen_corpus.py` | PROP-051 | — |
| OOF-TY0 | Typing family (note, not a single rule): unknown function (not visible in the caller's module), call arity/param mismatch, declared-return-vs-body mismatch | igniter-lab: `proofs/lang-app-local-def-call-canon-adoption-p2/specimen_corpus.py` | PROP-051 | — |
| OOF-I1 | `@bitemporal` invariant on non-bitemporal type (deferred) | — | PROP-025 (deferred) | P14 |
| OOF-I3 | `~T` invariant shape violation (deferred) | — | PROP-025 (deferred) | P14 |
| OOF-I5 | (deferred invariant OOF, exact condition TBD) | — | PROP-025 (deferred) | P14 |

---

## Missing Anchor Log

Entities without a golden anchor as of R29. All are at most `spec_candidate`.

| entity | gap | blocking PROP |
|--------|-----|---------------|
| `form NAME -> T` | Gap-I — no parser keyword, no fragment class | TBD |
| Loop class (all variants) | Stage 3 Language Lane — no parser, no classifier; PROP-036 is occupied by `compiler_profile_id` | PROP-037+ placeholder |
| OOF-I1 | Stage 2 deferred invariant OOF | PROP-025 addendum |
| OOF-I3 | Stage 2 deferred invariant OOF | PROP-025 addendum |
| OOF-I5 | Stage 2 deferred invariant OOF | PROP-025 addendum |
| Receipt (full epistemic provenance envelope) | Runtime receipts do not yet carry assumption refs or output-evidence refs; Effect Surface enforcement remains field-specific | runtime provenance follow-up |

---

## R30 Recommendations

**Promote from `spec_candidate` → `experiment-pass`:**

1. **OOF-I1, OOF-I3, OOF-I5**: deferred from Stage 2. No new PROP needed — these
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
