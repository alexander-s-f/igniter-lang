# PROP-038: Compiler Profile Contract v0

Status: accepted; partial-impl  [proof-local impl + validator extraction + report-only annotation + contract_digest policy: all closed; see current-status.md S3-R61..R68]
Date: 2026-05-16
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Stage: 3
Authoring card: S3-R61-C1-P1
Numbering authority: `docs/gates/compiler-profile-contract-validator-coverage-decision-v0.md`
Depends on: PROP-036, PROP-037
Source tracks:
- `docs/tracks/compiler-profile-contract-boundary-v0.md`
- `docs/tracks/compiler-profile-contract-proof-v0.md`
- `docs/tracks/compiler-profile-contract-schema-and-rule-ownership-pressure-v0.md`
- `docs/tracks/compiler-profile-contract-validator-coverage-proof-v0.md`
- `docs/tracks/prop038-contract-digest-validation-policy-design-v0.md`
- `docs/tracks/prop038-strict-refusal-live-implementation-v0.md`
- `docs/tracks/prop038-strict-refusal-canon-sync-v0.md`

---

## Queue And Authority Note

PROP-038 is assigned to `compiler_profile_contract` by the Architect decision
`S3-R60-C3-A`.

That decision authorizes proposal authoring only. This PROP does not authorize
parser changes, TypeChecker changes, SemanticIR changes, assembler or `.igapp`
changes, CLI/API widening, loader/report behavior, CompatibilityReport behavior,
compiler dispatch migration, dynamic pack loading, RuntimeMachine behavior,
Gate 3 widening, Ledger/TBackend binding, stream/OLAP production execution,
cache, or production behavior.

The managed local recursion / loop-class placeholder moves to `PROP-039+` or
later.

---

## §1. Purpose

PROP-036 gives Igniter-Lang a manifest identity:

```text
compiler_profile_id
```

R57-R60 proved the missing contract layer before that identity can be treated as
more than transport:

```text
compiler_profile_contract
```

PROP-038 defines the canonical v0 contract object that describes compiler
understanding before a finalized `compiler_profile_id_source` is transported and
before a manifest carries `compiler_profile_id`.

The contract object explains:

- which compiler slots exist;
- which slots are required;
- which slot assignments claim compiler-understanding ownership;
- which strict registry keys have exactly one owner;
- which ordered rules participate in a profile-local ordering graph;
- which digest references bind the contract to descriptor/finalization material;
- which authority flags must remain false.

It does not make the compiler dispatch through profiles.

---

## §2. Relationship To Existing PROPs

### §2.1 Relationship To PROP-036

PROP-036 owns:

```text
compiler_profile_id
manifest identity
finalized compiler_profile_id_source transport
loader/report status vocabulary for manifest interpretation
```

PROP-038 owns:

```text
compiler_profile_contract
contract object schema
required slot schema
slot assignment semantics
strict registry one-owner invariant
ordered-rule graph validity
contract diagnostic vocabulary
```

Relationship:

```text
compiler_profile_contract
  -> finalizes to compiler_profile_id_source
  -> may supply manifest compiler_profile_id through PROP-036 paths
```

`compiler_profile_id` remains a compact identity. PROP-038 does not inline the
full contract object into `.igapp/manifest.json`.

### §2.2 Relationship To PROP-037

PROP-037 owns external progression and service liveness semantics. PROP-038 does
not introduce a `progression` slot.

For v0 profile contracts:

```text
progression_descriptor metadata remains under pipeline
```

Any future dedicated `progression` slot requires a separate Architect decision
and proposal/proof path.

---

## §3. Terminology

| Term | Meaning |
| --- | --- |
| `compiler_profile_contract` | Canonical object describing compiler-understanding slots, ownership, strict registries, ordered rules, digests, and non-authority flags. |
| `compiler_profile_id_source` | Finalized source object already accepted by PROP-036 transport work. |
| `compiler_profile_id` | Manifest identity string naming the profile that understood/assembled an artifact. |
| `required_slot_schema` | Schema section defining required, optional, and all slots for v0. |
| `slot_assignment` | Declared compiler-understanding ownership for one slot. |
| `strict_registry` | Registry where each key has exactly one owner entry within the contract object. |
| `ordered_rule_graph` | Profile-local graph of ordering constraints between named compiler rules. |
| `CompilerProfileObligationReport` | Report-only object comparing emitted surfaces against supplied profile slots. |

---

## §4. Contract Object Schema

Canonical v0 shape:

```json
{
  "kind": "compiler_profile_contract",
  "format_version": "0.1.0",
  "profile_namespace": "compiler_profile_unified",
  "profile_kind": "Stage3ProofCompilerProfileSpec",
  "compiler_profile_id": "compiler_profile_unified/sha256:<24+ lowercase hex>",
  "descriptor_digest": "compiler_profile_descriptor/sha256:<24+ lowercase hex>",
  "finalization_payload_digest": "sha256:<64 lowercase hex>",
  "required_slot_schema": {
    "required_slots": [],
    "optional_slots": [],
    "all_slots": [],
    "cardinality": {}
  },
  "slot_order": [],
  "slot_assignments": {},
  "strict_registries": {},
  "ordered_rule_graph": {
    "rules": []
  },
  "non_authority": {
    "runtime_authority_granted": false,
    "dispatch_migration_authorized": false,
    "compiler_understanding_only": true
  },
  "contract_digest": "compiler_profile_contract/sha256:<24+ lowercase hex>"
}
```

Required top-level fields:

```text
kind
format_version
profile_namespace
profile_kind
compiler_profile_id
descriptor_digest
finalization_payload_digest
required_slot_schema
slot_order
slot_assignments
strict_registries
ordered_rule_graph
non_authority
contract_digest
```

`kind` must be:

```text
compiler_profile_contract
```

`format_version` must be:

```text
0.1.0
```

---

## §5. Slot Vocabulary

### §5.1 Required Slots

The v0 required slots are:

```text
core
oof_registry
fragment_registry
escape_boundary
```

Required slots have cardinality:

```text
exactly_one
```

A contract missing a required slot from either `slot_order` or
`slot_assignments` is invalid.

### §5.2 Optional Slots

The v0 optional slots are:

```text
contract_modifiers
temporal
stream
olap
invariant
assumptions
evidence_observation
pipeline
```

Optional means surface-specific. If a program uses a surface, the
`CompilerProfileObligationReport` may require the matching slot for coverage.
Optional does not mean semantically irrelevant.

### §5.3 Slot Order

The canonical v0 slot order is:

```text
core
oof_registry
fragment_registry
escape_boundary
contract_modifiers
temporal
stream
olap
invariant
assumptions
evidence_observation
pipeline
```

Slot order is contract identity and validation material. It may become future
dispatch-order material, but PROP-038 does not authorize dispatch migration.

---

## §6. Slot Assignment Semantics

A slot assignment has at least:

```json
{
  "implementation_id": "contract_modifiers.current_monolith_adapter.v0",
  "pack_name": "ContractModifiersPack"
}
```

Normative meaning:

```text
slot assignment = declared compiler-understanding ownership
```

Explicit non-meanings:

```text
slot assignment != handler execution
slot assignment != live dispatch binding
slot assignment != dynamic pack loading
slot assignment != runtime authority
```

`implementation_id` identifies the implementation/adapter identity that the
profile claims for a slot. `pack_name` is descriptive profile material. Neither
field authorizes the current compiler to call a pack.

---

## §7. Strict Registries

`strict_registries` is a map from registry name to entries.

Each entry has:

```json
{
  "key": "OOF-M1",
  "owner_slot": "contract_modifiers",
  "rule_ref": "contract_modifiers.oof_m1_pure_escape.v0"
}
```

V0 strict registries include:

```text
oof_descriptors
fragment_class_owners
```

### §7.1 One-Owner Invariant

Within one strict registry:

```text
one key must have exactly one owner entry
```

Duplicate keys are invalid. This invariant is closed within the contract object
being validated. It does not claim that the language can never add new keys in a
future proposal.

### §7.2 Owner Slot Validity

Every `owner_slot` in a strict registry entry must be present in `slot_order`.

If an owner slot is absent, the contract is invalid.

---

## §8. Ordered-Rule Graph

`ordered_rule_graph.rules` is a list of rule entries:

```json
{
  "rule_id": "classify.contract_modifiers",
  "stage": "classify",
  "owner_slot": "contract_modifiers",
  "before": ["typecheck.oof_propagation"],
  "after": ["parse.contract_modifiers"]
}
```

### §8.1 Required Validity Rules

Each rule must have a unique `rule_id`.

Every `owner_slot` must be present in `slot_order`.

Every target in `before` and `after` must resolve to a declared `rule_id` in the
same `ordered_rule_graph.rules` set.

The directed ordering graph must be acyclic.

### §8.2 Edge Semantics

`before` and `after` define ordering edges:

```text
rule.before target  => rule must run before target
rule.after source   => source must run before rule
```

These are contract-level ordering constraints. PROP-038 does not define a live
dispatcher that executes them.

### §8.3 Stage Field Decision

`stage` is informational metadata in PROP-038 v0.

The proof vocabulary uses:

```text
parse
classify
typecheck
emit
```

However, R60 did not validate `stage` values against a closed set. Therefore v0
does not make `stage` a normative validated vocabulary. Unknown `stage` values
must not be used as a contract-refusal basis under PROP-038 v0.

A future proposal may promote `stage` to normative validated vocabulary after a
dedicated proof or implementation gate.

---

## §9. Digest Semantics

### §9.1 Descriptor Digest

`descriptor_digest` identifies the canonical compiler profile descriptor.

V0 reference format:

```text
compiler_profile_descriptor/sha256:<24+ lowercase hex>
```

The hex segment is a SHA-256 digest reference. The v0 proof and PROP-036 profile
ids use short content-addressed references with at least 24 lowercase
hexadecimal characters. Full 64-character SHA-256 references are valid and
preferred for durable storage.

### §9.2 Finalization Payload Digest

`finalization_payload_digest` identifies the canonical finalization payload that
projects to the finalized `compiler_profile_id_source`.

Required format:

```text
sha256:<64 lowercase hex>
```

The digest is computed over canonicalized finalization payload material that
excludes the derived profile id.

### §9.3 Contract Digest

`contract_digest` identifies the canonical contract object.

V0 reference format:

```text
compiler_profile_contract/sha256:<24+ lowercase hex>
```

The digest is computed over canonicalized contract material excluding
`contract_digest` itself.

### §9.4 Digest Limits

Digest validity proves content-addressed identity. It does not prove runtime
readiness, loader acceptance, signature validity, or execution authorization.

### §9.5 Contract Digest Validation Policy Errata

R69-R71 accept a proof-local `contract_digest` chain for design purposes:

```text
R69 shape policy proof
R70 recompute/canonicalization proof
R71 report-only integration proof
```

The accepted v0 policy is:

```text
shape policy + recompute policy are design/proof vocabulary
live validator diagnostics are implemented inside the internal validator
bounded internal-only strict refusal is accepted as a live internal foundation
public/runtime/production refusal remains closed
```

The accepted reference shape remains:

```text
compiler_profile_contract/sha256:<24+ lowercase hex>
```

Full 64-character SHA-256 references are valid under this shape. Short
references are prefix references under `prop038_24_plus`.

### §9.6 Contract Digest Canonicalization Material

If recomputation is enabled by a later implementation decision, canonical
material is:

```text
contract object excluding contract_digest
```

Accepted included fields:

```text
kind
format_version
profile_namespace
profile_kind
compiler_profile_id
descriptor_digest
finalization_payload_digest
required_slot_schema
slot_order
slot_assignments
strict_registries
ordered_rule_graph
non_authority
```

Accepted excluded fields:

```text
contract_digest
validation result fields
report_only
compiler_integrated
compile_refusal_authorized
provider metadata
source_path / out_path
parsed_program
compiler_profile_source
```

Accepted canonicalization rules:

- object keys sort recursively;
- `slot_order` remains order-sensitive;
- strict registry names and entries are order-insensitive;
- ordered-rule list order is order-insensitive;
- `before` and `after` edge arrays are treated as sorted unique sets;
- `descriptor_digest` is included as a string field value;
- descriptor material is not fetched or recomputed.

`descriptor_digest` and `contract_digest` remain separate identities.
`descriptor_digest` identifies descriptor material. `contract_digest` identifies
the contract object and includes the `descriptor_digest` string value as part of
canonical contract material.

---

## §10. Diagnostic Vocabulary And Refusal Rules

Contract validation diagnostics live under:

```text
compiler_profile_contract.*
```

V0 diagnostic vocabulary:

| Code | Meaning |
| --- | --- |
| `compiler_profile_contract.wrong_kind` | `kind` is not `compiler_profile_contract`. |
| `compiler_profile_contract.unsupported_format_version` | `format_version` is not supported by this contract version. |
| `compiler_profile_contract.descriptor_digest_invalid` | `descriptor_digest` does not match v0 descriptor digest reference format. |
| `compiler_profile_contract.finalization_payload_digest_invalid` | `finalization_payload_digest` is not a full SHA-256 payload digest. |
| `compiler_profile_contract.contract_digest_invalid` | `contract_digest` is missing or does not match accepted reference shape. |
| `compiler_profile_contract.contract_digest_policy_unsupported` | Selected contract digest policy is not supported. |
| `compiler_profile_contract.contract_digest_mismatch` | Declared `contract_digest` does not match recomputed canonical contract digest. |
| `compiler_profile_contract.contract_digest_recompute_unavailable` | Recompute was requested but canonicalization/recompute support is unavailable. |
| `compiler_profile_contract.missing_required_slot` | A required slot is absent from `slot_order` or `slot_assignments`. |
| `compiler_profile_contract.unknown_owner_slot` | A strict registry entry references an owner slot absent from `slot_order`. |
| `compiler_profile_contract.unknown_rule_owner_slot` | An ordered rule references an owner slot absent from `slot_order`. |
| `compiler_profile_contract.duplicate_strict_key` | A strict registry contains the same key more than once. |
| `compiler_profile_contract.rule_cycle` | The ordered-rule graph contains a cycle. |
| `compiler_profile_contract.missing_rule_reference` | A `before` or `after` target does not resolve to a declared rule id. |
| `compiler_profile_contract.runtime_authority_forbidden` | Contract material attempts to grant runtime authority. |
| `compiler_profile_contract.dispatch_migration_forbidden` | Contract material attempts to grant dispatch migration authority. |

Invalid contract diagnostics are refusal rules for the contract object only.
They do not create compile-time refusal behavior in the current compiler unless
a later implementation card explicitly authorizes that behavior.

### §10.1 OOF Ownership Rules

OOF ownership is represented through:

```text
strict_registries.oof_descriptors
```

Each OOF descriptor key must have exactly one owner entry in that registry. The
owner entry must name an `owner_slot` present in `slot_order` and a `rule_ref`
owned by the profile contract.

PROP-038 does not mint new OOF codes. It defines how a compiler profile contract
claims ownership of OOF codes that already exist or are introduced by later
accepted proposals.

### §10.2 Contract Digest Diagnostic Placement

The four `contract_digest_*` diagnostics are accepted as design/proof vocabulary
only. They are not live validator implementation authority.

If implemented later, digest diagnostics belong under:

```text
report["compiler_profile_contract_validation"]["diagnostics"]
```

They must not be appended to top-level:

```text
report["diagnostics"]
```

They must not be centralized in:

```text
IgniterLang::Diagnostics
```

without a separate Architect decision.

### §10.3 Contract Digest Report-Only Invariants

`contract_digest` diagnostics do not change:

- compile status;
- `pass_result`;
- stages;
- public result;
- assembler execution;
- `.igapp` manifest;
- refusal-report behavior.

Contract digest diagnostics alone do not authorize refusal. R84 accepts only the
bounded internal-only strict refusal foundation described in §10.4. Any public
exposure, loader/report behavior, CompatibilityReport status, persisted refusal
report, runtime behavior, or production refusal behavior still requires a
separate explicit gate.

### §10.4 Strict Refusal Live Internal Foundation

R84 accepts the R83 bounded internal-only strict-refusal implementation as the
live internal foundation for PROP-038.

Accepted authority model:

```text
internal strict requirement source
  -> orchestrator-level strict requirement decision path
  -> report-only compiler_profile_contract_validation evidence
  -> non-persisting strict terminal CompilerResult when selected
```

Normative boundaries:

- the strict source is an internal constructor/test seam only;
- the orchestrator-level strict requirement decision path is the authority;
- `CompilerProfileContractValidator` output is evidence, not authority;
- nested `compile_refusal_authorized: false` remains a report-only marker;
- `report.pass_result == "ok"` remains invariant for strict terminal paths;
- strict terminal paths are non-persisting, with no sidecar, no report write,
  no `.igapp`, and no assembler call;
- raw validator diagnostics remain nested under
  `compiler_profile_contract_validation.diagnostics`;
- public diagnostics use wrapper codes only.

Accepted strict terminal statuses:

```text
refused
configuration_error
```

Accepted strict terminal public key-set for both statuses:

```text
kind
format_version
status
program_id
source_path
source_hash
grammar_version
stages
igapp_path
contracts
compilation_report_path
diagnostics
warnings
```

Accepted public wrapper diagnostics:

```text
compiler_profile_contract_refusal.contract_digest_mismatch
compiler_profile_contract_refusal.strict_requirement_malformed
```

Closed surfaces:

- public Ruby API;
- CLI;
- env/config/manifest/default/generated strict source lookup;
- loader/report strict source or status;
- CompatibilityReport strict source or status;
- persisted refusal reports;
- sidecars;
- `.igapp` mutation;
- `IgniterLang::Diagnostics` centralization;
- RuntimeMachine, Gate 3, runtime, and production behavior.

---

## §11. Vocabulary Separation

PROP-038 keeps four vocabularies separate:

| Vocabulary | Owns | Example |
| --- | --- | --- |
| `compiler_profile_contract.*` | Contract object validity | `compiler_profile_contract.missing_required_slot` |
| `compiler_profile_source.*` | Finalized source object transport validity | `compiler_profile_source.id_digest_mismatch` |
| `compiler_profile_obligation.*` | Surface/slot coverage report status | `compiler_profile_obligation.missing_slot` |
| Loader/report status | Manifest/profile rollout interpretation | `missing_required`, `present_verified` |

Required distinction:

```text
compiler_profile_contract.missing_required_slot
  != compiler_profile_obligation.missing_slot
  != loader/report missing_required
```

Meaning:

1. `missing_required_slot`: the contract object lacks a schema-required slot.
2. `missing_slot`: emitted program surfaces require a slot the supplied profile
   did not cover.
3. `missing_required`: a manifest lacks `compiler_profile_id` under a future
   `profile_required` loader/report policy.

---

## §12. Future `profile_not_supplied` Shape

When no profile is supplied, future obligation coverage should report:

```json
{
  "status": "profile_not_supplied",
  "required_slots": ["..."],
  "missing_slots": []
}
```

`required_slots` remains populated from detected program surfaces. `missing_slots`
remains empty because there is no supplied profile slot set to compare against.

This shape belongs to obligation coverage, not to contract validation.

---

## §13. Non-Authority Boundary

Required contract flags:

```json
{
  "runtime_authority_granted": false,
  "dispatch_migration_authorized": false,
  "compiler_understanding_only": true
}
```

PROP-038 explicitly states:

```text
compiler_profile_contract grants no runtime authority.
compiler_profile_contract grants no dispatch migration authority.
compiler_profile_contract does not authorize dynamic pack loading.
compiler_profile_contract does not authorize loader/report behavior.
compiler_profile_contract does not authorize CompatibilityReport behavior.
compiler_profile_contract does not authorize production behavior.
```

Also:

```text
valid compiler_profile_contract != runtime evaluation readiness
valid compiler_profile_contract != loader/report present_verified
valid compiler_profile_contract != obligation coverage success
valid compiler_profile_contract != dispatch binding
```

---

## §14. Validation Order

The accepted design order is:

```text
compiler_profile_contract_validated
  -> finalizes_to_compiler_profile_id_source
  -> source_transported_and_validated_by_compiler_profile_source.*
  -> semantic_ir_emitted
  -> semanticir_profile_obligation_checkpoint
  -> manifest_report_interpretation_later
```

The SemanticIR profile-obligation checkpoint is a proposed future design
position, not current implementation.

This order is normative as an architecture rule for future design. It does not
authorize implementation.

---

## §15. Proof Evidence

Accepted evidence:

- `docs/tracks/compiler-profile-contract-boundary-v0.md`
- `docs/gates/compiler-profile-contract-boundary-decision-v0.md`
- `docs/tracks/compiler-profile-contract-proof-v0.md`
- `docs/discussions/compiler-profile-contract-proof-pressure-v0.md`
- `docs/gates/compiler-profile-contract-proof-decision-v0.md`
- `docs/tracks/compiler-profile-contract-schema-and-rule-ownership-pressure-v0.md`
- `docs/discussions/compiler-profile-contract-schema-ownership-pressure-v0.md`
- `docs/gates/compiler-profile-contract-prop-authoring-decision-v0.md`
- `docs/tracks/compiler-profile-contract-validator-coverage-proof-v0.md`
- `docs/discussions/compiler-profile-contract-validator-coverage-pressure-v0.md`
- `docs/gates/compiler-profile-contract-validator-coverage-decision-v0.md`
- `docs/tracks/prop038-contract-digest-validation-policy-design-v0.md`
- `docs/gates/prop038-contract-digest-validation-policy-decision-v0.md`
- `docs/gates/prop038-contract-digest-shape-policy-proof-decision-v0.md`
- `docs/gates/prop038-contract-digest-recompute-match-proof-decision-v0.md`
- `docs/gates/prop038-contract-digest-report-only-integration-proof-decision-v0.md`
- `docs/gates/prop038-contract-digest-live-validator-implementation-acceptance-decision-v0.md`
- `docs/gates/prop038-strict-refusal-live-implementation-authorization-review-v0.md`
- `docs/gates/prop038-strict-refusal-live-implementation-acceptance-decision-v0.md`
- `docs/tracks/prop038-strict-refusal-live-implementation-v0.md`
- `experiments/prop038_contract_digest_shape_policy_proof/out/prop038_contract_digest_shape_policy_proof_summary.json`
- `experiments/prop038_contract_digest_recompute_match_proof/out/prop038_contract_digest_recompute_match_proof_summary.json`
- `experiments/prop038_contract_digest_report_only_integration_proof/out/prop038_contract_digest_report_only_integration_proof_summary.json`
- `experiments/prop038_strict_refusal_live_implementation_proof/out/prop038_strict_refusal_live_implementation_proof_summary.json`
- `experiments/compiler_profile_contract_proof/out/compiler_profile_contract_proof_summary.json`

R60 proof evidence shows:

- `status: PASS`;
- 22 checks pass;
- all five R59 validator paths are proof-covered;
- both strict registries have duplicate-key coverage;
- namespace separation remains intact;
- positional `required_slots` proof debt is closed;
- R58 object shape is preserved.

R69-R71 digest proof evidence shows:

- R69 shape policy proof: 8 cases PASS;
- R70 recompute/canonicalization proof: 14 cases PASS;
- R71 report-only integration proof: 12 cases PASS;
- all four `contract_digest_*` diagnostics are proof-covered;
- canonical material is the contract object excluding `contract_digest`;
- digest diagnostics remain nested under
  `compiler_profile_contract_validation.diagnostics`;
- top-level diagnostics, `pass_result`, stages, compile status, public result,
  assembler execution, `.igapp` manifest, and refusal-report behavior remain
  unchanged;
- live validator/compiler implementation was later split into bounded internal
  steps.

R74 live validator evidence shows:

- all four `contract_digest_*` diagnostics are implemented inside
  `IgniterLang::CompilerProfileContractValidator`;
- validator result shape remains internal/report-only;
- compile refusal, public API/CLI, loader/report, CompatibilityReport, runtime,
  and production behavior remain closed.

R83/R84 strict-refusal live evidence shows:

- bounded internal-only strict refusal is accepted as the live internal
  foundation;
- strict source is constructor/test-seam only;
- validator output remains evidence, not authority;
- nested `compile_refusal_authorized: false` remains report-only evidence;
- `report.pass_result == "ok"` remains invariant for strict terminal paths;
- `refused` and `configuration_error` share the exact 13-key public key-set;
- strict terminal paths are non-persisting and skip sidecar/report/`.igapp`
  writes and assembler execution;
- public API/CLI, loader/report, CompatibilityReport, RuntimeMachine/Gate 3,
  runtime, and production remain closed.

This proof evidence supports the current PROP-038 canon. It does not authorize
public exposure, persisted artifacts, loader/report behavior,
CompatibilityReport behavior, runtime, Gate 3, or production behavior.

---

## §16. Explicit Excluded Surfaces

PROP-038 does not authorize:

- parser syntax changes;
- TypeChecker changes;
- SemanticIR changes;
- assembler or `.igapp` changes;
- CLI or Ruby API widening;
- profile discovery/defaulting/finalization in public surfaces;
- loader/report implementation or schema;
- CompatibilityReport implementation or schema;
- `.ilk`;
- CompilationReceipt links;
- signing;
- compiler dispatch migration;
- dynamic pack loading;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP production execution;
- cache;
- production behavior.

The R84 live internal foundation is the sole accepted exception to the older
blanket "no compile refusal implementation" wording: it is internal-only,
constructor/test-seam driven, non-persisting, and bounded to the accepted
`CompilerOrchestrator` / `CompilerResult` strict terminal path. It does not open
any excluded surface above.

---

## §17. Open Questions

[Q] Should `ordered_rule_graph.stage` become normative validated vocabulary in a
future version?

[Q] Should a future proof add a missing-`after` direction case for
`missing_rule_reference`, even though v0 referential integrity is
direction-agnostic?

[Q] Should durable storage require full 64-character digest references for
`descriptor_digest` and `contract_digest`, instead of permitting proof-era
24+ character references?

[Q] If contract validation becomes persisted, where should the contract object
live: sidecar, receipt bundle, `.ilk`, or another artifact?

[Q] When should a dedicated PROP-037 `progression` slot be considered?

---

## §18. Deferred Implementation Gates

Before any additional or widened implementation may begin:

1. PROP-038 must be reviewed and accepted by a separate governance decision.
2. A separate implementation authorization must name exact write scope.
3. The implementation card must state whether it is report-only, internal-only
   strict terminal behavior, public exposure, persisted artifact behavior,
   loader/report behavior, CompatibilityReport behavior, or runtime behavior.
4. Any persisted output requires a golden/artifact mutation policy.
5. Public Ruby API and CLI exposure require separate authorizations.
6. Loader/report and CompatibilityReport work require separate authorizations.
7. Dispatch migration requires a separate proof and authorization.
8. Runtime/production behavior remains closed unless explicitly opened by later
   governance.

---

## §19. Acceptance Criteria

PROP-038 is authored when:

1. This document exists as `docs/proposals/PROP-038-compiler-profile-contract-v0.md`.
2. `docs/proposals/README.md` lists PROP-038 as Stage 3 active.
3. The proposal defines contract object schema.
4. The proposal defines required and optional slot vocabulary.
5. The proposal defines slot assignment semantics as declared
   compiler-understanding ownership.
6. The proposal defines strict registry one-owner invariant.
7. The proposal defines ordered-rule graph reference and cycle semantics.
8. The proposal decides `stage` is informational metadata in v0.
9. The proposal defines digest semantics.
10. The proposal defines `compiler_profile_contract.*` diagnostics and
    separates them from source, obligation, and loader/report vocabularies.
11. The proposal states future `profile_not_supplied` shape.
12. The proposal keeps progression metadata under `pipeline` for v0.
13. The proposal preserves non-authority language and excluded surfaces.
14. No code or experiment files are edited by the authoring card.
