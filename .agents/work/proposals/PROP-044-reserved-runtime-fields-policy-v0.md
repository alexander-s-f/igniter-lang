# PROP-044-P9: Reserved Variant Runtime Field Policy

**Card:** PROP-044-P9  
**Track:** variant-runtime-reserved-fields-policy-v0  
**Route:** GOVERNANCE + PROOF / TYPECHECKER GUARDRAIL / NO VM CHANGE  
**Status:** CLOSED — 36/36 PASS  
**Authority:** lab_only  
**Date:** 2026-06-10  
**Predecessor:** PROP-044-P8 (Path B runtime lowering semantics)

---

## 1. Decision Summary

All `__*`-prefixed field names are reserved for compiler-owned internal use in the Igniter language. User-authored source may not declare, construct, or reference fields whose names begin with `__` (double underscore). The TypeChecker enforces this at all three user-visible sites:

- Type declarations: `type Foo { __arm: String, ... }`
- Variant arm payload fields: `variant Foo { Bar { __arm: String } }`
- Record literals: `{ __arm: "Injected", ... }`

Violation produces an OOF-KIND6 diagnostic; compilation halts at `status=oof`.

**Scope of reservation:** BROAD — all `__*` prefixes, not just `__arm` and `__variant`.

---

## 2. Motivation and Risk Being Closed

PROP-044-P8 locked the Path B runtime representation: the compiler lowers `variant_construct` to `OP_PUSH_RECORD` with internally-injected discriminant fields `__arm` and `__variant`. These fields are compiler-owned; they carry variant arm identity through the VM without new opcodes or `Value::Variant`.

**Risk from P8 §9 (RISK-006):** Without an enforcement guardrail, a user who knows the Path B representation can inject `__arm` and `__variant` fields into a record literal, creating a record that impersonates a variant arm. The match lowering chain (`OP_GET_FIELD("__arm") → OP_EQ → OP_JMP_UNLESS`) would accept this injection at runtime, producing semantically incorrect routing.

**Closed by this card:** OOF-KIND6 fires at compile time when any user source attempts to use a `__*` field, making the injection impossible to express in valid Igniter source.

---

## 3. Reservation Scope Decision

**Option A (narrow):** Reserve only `__arm` and `__variant`.  
**Option B (broad):** Reserve all `__*`-prefixed field names.

**Decision: Option B (broad).**

Rationale:
1. No existing fixture uses `__*` as a field identifier. The one `__`-containing string in the fixture tree is `"__absent__"` in `map_vm_ops.ig`, which is a string literal value (argument to `or_else`), not a field name — unaffected by this reservation.
2. Narrow reservation creates a false boundary: any future internal field added by the compiler (e.g. `__tag`, `__kind_hint`) would require a separate P-card to reserve. Broad reservation secures the namespace once.
3. The prefix `__` has no natural user meaning in Igniter field naming convention. Reserve it completely.

---

## 4. Enforcement Sites

### 4.1 Rust TypeChecker (igniter-compiler)

Three enforcement sites, all in `typechecker.rs`:

| Site | Location | Trigger |
|------|----------|---------|
| Module-level type declarations | After `build_contract_registry`, before contracts loop | `t.fields` for each `classified.type_declarations` |
| Module-level variant arm fields | Same pass | `arm.fields` for each arm in `classified.variant_declarations` |
| Record literal keys | `infer_expr` → `Expr::RecordLiteral { fields }` arm | `fields.keys()` |

All three push to `type_errors` → surface in `result['diagnostics']` with `rule: "OOF-KIND6"`.

### 4.2 Ruby TypeChecker (igniter-lang)

Two enforcement sites in `typechecker.rb` (module-level only):

| Site | Coverage |
|------|----------|
| `type_declarations` | Checks `fields[].name.start_with?("__")` |
| `variant_declarations` | Checks `arms[].fields[].name.start_with?("__")` |

**Known parity gap:** Ruby TC does not enforce record literal keys (expression-level). This requires `typecheck_contract` expression traversal not yet implemented. The Rust TC covers all three sites; the Ruby TC module-level check catches the most structural violations.

---

## 5. OOF-KIND6 Diagnostic Shape

```json
{
  "rule": "OOF-KIND6",
  "message": "Field '__arm' in type 'BadRecord' uses reserved compiler prefix '__' (compiler-owned variant runtime field)",
  "node": "BadRecord",
  "line": null
}
```

Messages include:
- The offending field name
- The type or variant name where it was found
- For variant arms: the arm name
- For record literals: the enclosing contract/node name

---

## 6. Fixtures

All five fixtures are in `igniter-lab/igniter-view-engine/fixtures/reserved_fields/`:

| File | Purpose | Expected |
|------|---------|---------|
| `reserved_type_field.ig` | `type BadRecord { __arm: String, ... }` | `status=oof`, OOF-KIND6 naming `__arm` + `BadRecord` |
| `reserved_variant_field.ig` | `variant BadVariant { ClashArm { __arm: String } }` | `status=oof`, OOF-KIND6 naming `ClashArm` + `BadVariant` |
| `reserved_record_literal.ig` | `{ __arm: "Injected", __variant: "Fake", ... }` | `status=oof`, 2× OOF-KIND6 (`__arm` + `__variant`) |
| `reserved_variant_name_field.ig` | `type AnotherBad { __variant: String, ... }` | `status=oof`, OOF-KIND6 naming `__variant` |
| `reserved_fields_valid.ig` | Normal type + variant + match, no `__*` fields | `status=ok`, 0 diagnostics |

---

## 7. Path B Regression

Compiler-generated `__arm`/`__variant` fields produced by Path B lowering do NOT trigger OOF-KIND6 because they appear in the compiler's internal lowering pass, not in user-authored source. The TypeChecker runs before lowering; lowered records are never re-checked.

Regression anchor: `outcome_variant.ig` (11-arm variant, 58/58 PASS from LAB-OUTCOME-VARIANT-P1) compiles `status=ok` with 0 OOF-KIND6 diagnostics, and all four RESERVE-PATHB VM execution checks pass.

---

## 8. Proof Result

**Runner:** `igniter-lab/igniter-view-engine/proofs/verify_prop044_p9_reserved_fields.rb`  
**Result:** 36/36 PASS

| Section | Checks | Description |
|---------|--------|-------------|
| RESERVE-SCAN | 5 | No existing user fixture relies on `__*` field names |
| RESERVE-TYPE | 5 | `type Foo { __arm: ... }` → OOF-KIND6 |
| RESERVE-RECORD | 5 | `{ __arm: ..., __variant: ... }` record literal → OOF-KIND6 (×2) |
| RESERVE-VARIANT | 5 | Variant arm payload with `__arm` → OOF-KIND6, `GoodArm` clean |
| RESERVE-ALLOW | 6 | Normal records/variants/match unaffected; `"__absent__"` string value safe |
| RESERVE-PATHB | 5 | Path B VM execution correct after P9; 4 routing arms verified |
| RESERVE-CLOSED | 5 | No OP_MATCH, no Value::Variant, TC sources correct |

---

## 9. Closed Surfaces (Unchanged)

| Surface | Status |
|---------|--------|
| `igniter-vm/src/instructions.rs` | Closed — no OP_MATCH added |
| `igniter-vm/src/vm.rs` | Closed — no new opcode dispatch |
| `igniter-vm/src/value.rs` | Closed — no Value::Variant |
| Path B runtime ABI | Closed — `__arm`/`__variant` not promoted to public API |
| Ruby canon | Closed — only module-level OOF-KIND6 check added (no behavior change) |

---

## 10. What This Proves

- OOF-KIND6 fires for all three user-authored sites (Rust TC)
- Module-level `__*` field declarations are blocked in both Rust and Ruby TCs
- Broad `__*` reservation is safe: no existing fixture broken
- `"__absent__"` string value is not affected by field-name reservation
- Path B lowering is not disrupted; the 11-arm `ReconciliationOutcome` variant still executes correctly in the VM

## 10. What This Does NOT Prove

- Complete parity between Rust and Ruby TCs at the record-literal level (known gap)
- Protection against injection through channels other than Igniter source (e.g. raw igapp manipulation)
- This is not a production security boundary — it is a compile-time source-level guardrail

---

## 11. Explicit Answers

| Question | Answer |
|----------|--------|
| Narrow vs broad reservation? | BROAD — all `__*` prefixes |
| Why broad? | No existing fixture uses `__*`; reserving just `__arm`/`__variant` leaves future internal fields unprotected |
| Does `"__absent__"` break? | No — it is a string literal value, not a field name |
| Where does OOF-KIND6 appear in compiler output? | `result['diagnostics']`, NOT `result['type_errors']` |
| Does Ruby TC cover record literals? | No — known parity gap; module-level only |
| Does Path B lowering trigger OOF-KIND6? | No — compiler-internal lowering runs after TypeChecker |
| Are `__arm`/`__variant` now public API? | No — reservation is a guard, not a promotion |
| Does this change VM opcodes? | No — VM is fully closed |

---

## 12. Recommended Next Route

**LAB-OUTCOME-VARIANT-P2** or failure-taxonomy proposal-planning.

The epistemic outcome variant surface is now stable and guarded:
- Path B runtime lowering locked (PROP-044-P8)
- Reserved fields enforced (PROP-044-P9)
- 11-arm `ReconciliationOutcome` proven end-to-end (LAB-OUTCOME-VARIANT-P1)

Remaining open questions: failure taxonomy proposal (how to express error/retry semantics in variant form), or deepening the epistemic outcome model with real KDR interop contracts.
