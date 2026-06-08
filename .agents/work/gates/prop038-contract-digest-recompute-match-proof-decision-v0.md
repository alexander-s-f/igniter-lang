# PROP-038 Contract Digest Recompute-Match Proof Decision v0

Card: S3-R70-C3-A
Agent: [Architect Supervisor / Codex]
Role: architect-supervisor
Track: prop038-contract-digest-recompute-match-proof-decision-v0
Route: UPDATE
Status: accepted-proof-local-recompute-match-closure
Date: 2026-05-18

---

## Decision

Accept the proof-local PROP-038 `contract_digest` recompute-match proof.

Authorize the next route only as proof-local integration proof:

```text
prop038-contract-digest-report-only-integration-proof-v0
```

This decision does not authorize live validator implementation, compiler
integration changes, compile refusal, public API/CLI widening, persisted reports,
loader/report behavior, CompatibilityReport behavior, RuntimeMachine behavior,
Gate 3 widening, or production behavior.

---

## Evidence Read

- `igniter-lang/docs/tracks/prop038-contract-digest-recompute-match-proof-v0.md`
- `igniter-lang/docs/discussions/prop038-contract-digest-recompute-match-proof-pressure-v0.md`
- `igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/out/prop038_contract_digest_recompute_match_proof_summary.json`
- `igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/prop038_contract_digest_recompute_match_proof.rb`
- `igniter-lang/docs/gates/prop038-contract-digest-shape-policy-proof-decision-v0.md`
- `igniter-lang/docs/gates/prop038-contract-digest-validation-policy-decision-v0.md`
- `igniter-lang/docs/tracks/prop038-contract-digest-validation-policy-design-v0.md`
- `igniter-lang/docs/gates/prop038-report-only-compiler-integration-acceptance-decision-v0.md`
- `igniter-lang/docs/gates/prop038-library-validator-extraction-acceptance-decision-v0.md`
- `igniter-lang/docs/proposals/PROP-038-compiler-profile-contract-v0.md`
- `igniter-lang/docs/tracks/stage3-round69-status-curation-v0.md`

---

## Proof Result

Accepted proof summary:

```text
kind=prop038_contract_digest_recompute_match_proof_summary
status=PASS
failed_checks=[]
shape_policy_proof_status=PASS
```

The proof is explicitly proof-local:

```text
live_validator_changed=false
compiler_integration_changed=false
recompute_match_live_implemented=false
compile_refusal_authorized=false
implementation_authorized=false
```

---

## Accepted 14-Case Matrix

All required recompute/canonicalization cases are accepted:

| Case | Expected | Status |
| --- | --- | --- |
| `recompute_full_match` | valid | PASS |
| `recompute_prefix_match` | valid | PASS |
| `recompute_full_mismatch` | `compiler_profile_contract.contract_digest_mismatch` | PASS |
| `recompute_prefix_mismatch` | `compiler_profile_contract.contract_digest_mismatch` | PASS |
| `recompute_unavailable` | `compiler_profile_contract.contract_digest_recompute_unavailable` | PASS |
| `canonical_excludes_contract_digest` | same canonical digest despite changed `contract_digest` | PASS |
| `canonical_includes_descriptor_digest_string` | descriptor digest string changes canonical digest | PASS |
| `canonical_does_not_recompute_descriptor_material` | descriptor material is not required or fetched | PASS |
| `canonical_slot_order_order_sensitive` | `slot_order` order changes canonical digest | PASS |
| `canonical_object_key_order_insensitive` | top-level object key order does not change canonical digest | PASS |
| `canonical_strict_registry_order_insensitive` | registry and registry-entry order do not change canonical digest | PASS |
| `canonical_rule_list_order_insensitive` | ordered-rule list order does not change canonical digest | PASS |
| `canonical_rule_edge_set_order_insensitive` | `before` / `after` edge arrays are treated as sorted unique sets | PASS |
| `canonical_rule_reference_still_validated` | `compiler_profile_contract.missing_rule_reference` remains valid | PASS |

---

## Canonicalization Status

Canonicalization material is accepted as stable enough for future design.

Accepted proof-local input:

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
source/out paths
parsed program
compiler profile source transport
```

Accepted canonicalization rules:

- object keys sort recursively;
- `slot_order` remains order-sensitive;
- strict registry names and entries are order-insensitive;
- ordered-rule list order is order-insensitive;
- `before` / `after` edge arrays are treated as sorted unique sets;
- `descriptor_digest` is included as a string field value;
- descriptor material is not fetched or recomputed.

---

## Diagnostic Candidate Status

The two Phase 2 diagnostic candidates are accepted as stable enough for future
design/proof:

```text
compiler_profile_contract.contract_digest_mismatch
compiler_profile_contract.contract_digest_recompute_unavailable
```

Together with R69, the complete four-code `contract_digest_*` candidate set is
now proof-covered:

```text
compiler_profile_contract.contract_digest_invalid
compiler_profile_contract.contract_digest_policy_unsupported
compiler_profile_contract.contract_digest_mismatch
compiler_profile_contract.contract_digest_recompute_unavailable
```

These diagnostics are not yet accepted for live validator implementation.

If implemented later, they must remain inside:

```text
report["compiler_profile_contract_validation"]["diagnostics"]
```

They must not be appended to top-level `report["diagnostics"]` and must not be
centralized in `IgniterLang::Diagnostics` without a separate decision.

---

## Shape And Recompute Coverage

Accepted:

```text
shape-policy proof + recompute-match proof are enough to consider a later
report-only integration proof route.
```

Not accepted:

```text
shape-policy proof + recompute-match proof are not implementation authorization.
```

Live validator implementation remains held until after a separate design,
pressure review, and Architect implementation authorization.

---

## Regression And Non-Authorization Checks

Accepted regression signals:

- R69 shape-policy proof remains PASS;
- existing 13-case validator matrix remains PASS;
- R67 report-only integration remains PASS;
- public result remains unchanged in the integration summary;
- proof-local and live validator paths keep `compile_refusal_authorized=false`;
- proof output contains no `.igapp` artifact;
- proof output contains no refusal report.

Accepted non-authorization flags:

```text
live_validator_changed=false
compiler_integration_changed=false
recompute_match_live_implemented=false
compile_refusal_authorized=false
implementation_authorized=false
```

R70-C2-X NB-1 is accepted as a future traceability requirement:

```text
Future proof summaries should include a structured
non_authorizations_preserved block matching the R65/R67/R69 pattern.
```

This is not a blocker for R70 acceptance.

---

## Command Matrix

Commands rerun by Architect Supervisor:

| Command | Result |
| --- | --- |
| `ruby -c igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/prop038_contract_digest_recompute_match_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_contract_digest_recompute_match_proof/prop038_contract_digest_recompute_match_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_contract_digest_shape_policy_proof/prop038_contract_digest_shape_policy_proof.rb` | PASS |
| `ruby igniter-lang/experiments/compiler_profile_contract_proof/compiler_profile_contract_proof.rb` | PASS |
| `ruby igniter-lang/experiments/prop038_report_only_compiler_integration/prop038_report_only_compiler_integration.rb` | PASS |
| `ruby -c igniter-lang/lib/igniter_lang/compiler_profile_contract_validator.rb` | PASS |

---

## Pressure Verdict

R70-C2-X verdict:

```text
proceed
blockers: none
non-blocking notes: 1
```

Non-blocking note:

```text
NB-1: future proof summaries should restore the non_authorizations_preserved
dictionary for hold-inventory traceability.
```

Architect accepts the pressure result and records NB-1 as future requirement.

---

## Status Answers

### Is the 14-case recompute/canonicalization proof accepted?

Yes. The proof is accepted as proof-local Phase 2 closure.

### Is canonicalization material stable enough for future design?

Yes, for future design and proof-local integration work.

No, not yet for live implementation.

### Are mismatch diagnostics stable enough for future design?

Yes, for future design/proof work.

No, not yet for live implementation.

### Are shape-policy and recompute-match together enough to consider a later live validator implementation design?

Not directly.

They are enough to consider a proof-local report-only integration proof next.
Live validator implementation design may be considered only after that
integration proof is accepted.

### Does live validator implementation remain held?

Yes.

### Does compile refusal remain closed?

Yes.

### May PROP-038 errata open next?

Not yet.

PROP-038 errata should wait until report-only integration proof confirms that
the full four-code digest vocabulary can travel through the accepted nested
report field without changing compiler behavior.

---

## Exact Next Allowed Boundary

Allowed next route:

```text
Card: S3-R71-C1-P1
Agent: [Igniter-Lang Research Agent]
Role: research-agent
Track: prop038-contract-digest-report-only-integration-proof-v0
```

Boundary:

- proof-local integration model only;
- may wire shape + recompute diagnostics through an experiment-local
  report-only validation result;
- must prove mismatch still returns compile status `ok`;
- must prove public result unchanged;
- must prove no `.igapp` mutation;
- must prove no refusal report creation;
- must include `non_authorizations_preserved`;
- must not edit live validator/compiler/orchestrator code;
- must not create compile refusal;
- must not widen public API/CLI, `CompilerResult`, loader/report,
  CompatibilityReport, RuntimeMachine, Gate 3, runtime, or production behavior.

Recommended follow-up:

```text
S3-R71-C2-X: pressure-review report-only integration proof
S3-R71-C3-A: Architect decision on integration proof acceptance
```

---

## Preserved Closed Surfaces

This decision does not authorize:

- live validator/compiler implementation;
- compile refusal;
- public API/CLI widening;
- `CompilerResult` changes;
- persisted success reports or sidecars;
- parser, TypeChecker, SemanticIR;
- assembler or `.igapp` mutation;
- loader/report behavior;
- CompatibilityReport behavior;
- `IgniterLang::Diagnostics` centralization;
- `.ilk`, receipts, signing;
- dispatch migration;
- RuntimeMachine / Gate 3 widening;
- Ledger/TBackend;
- BiHistory;
- stream/OLAP;
- cache;
- production behavior.

---

## Compact Summary

R70 accepts the proof-local `contract_digest` recompute-match proof. All 14
required cases pass, canonicalization material is stable enough for future design,
and the full four-code digest vocabulary is now proof-covered across R69/R70.
This is not implementation authorization. The next allowed route is only a
proof-local report-only integration proof. Live validator/compiler implementation,
compile refusal, public surfaces, loader/report, CompatibilityReport, runtime,
Gate 3, and production remain closed.
