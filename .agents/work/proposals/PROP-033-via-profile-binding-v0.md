# PROP-033: via Profile Binding v0

Status: experiment-pass
Date: 2026-06-07
Implemented: 2026-06-07
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Depends on: PROP-031 (contract modifiers), PROP-032 (assumptions block)
Stage: 3
Source: PROP-031 §12 (dependency specification)
Evidence: experiments/via_profile_proof/ — 52/52 PASS

---

## § 1. Purpose

PROP-031 introduced contract modifiers and explicitly specified the `via profile` binding
as the immediate downstream grammar extension (§12). This PROP implements that extension.

A contract may optionally declare which compiler profile it binds to at the source level:

```igniter
effect contract ChargeCustomer via payments_profile {
  capability charge_cap: IO.NetworkCapability
  effect charge using charge_cap
}
```

The `via <profile_name>` clause states the intent to resolve runtime authority from a
named compiler profile. It is a **source-level declaration only** — the compiler records
the binding in the AST, propagates it through all pipeline stages, and emits it in the
`contract_ir` as a `profile_binding` field. No profile schema is validated at compile time
(deferred to PROP-040: profile declarations).

Non-goals:
- No profile schema validation at compile time (PROP-040)
- No runtime profile resolution or authority injection (Phase 2)
- No OOF codes for profile constraint mismatches (requires PROP-040 profile schema)
- No `via` on functions or traits (contracts only, per PROP-031 §Q2)

---

## § 2. Grammar Change

### § 2.1 New production

```
contract-decl ::= contract-modifier? "contract" ident type-params?
                  ("implements" type-ref)?
                  ("via" ident)?                   -- NEW
                  "{" body-decl* "}"
```

The `via` clause is positioned after the optional `implements` clause and before the
opening brace. It binds the contract to a named profile by identifier.

### § 2.2 Illustrative source

```igniter
-- no via: unchanged behaviour
pure contract ScoreRisk {
  input score: Integer
  compute result = score
  output result: Integer
}

-- with via: profile binding declared
effect contract ChargeCustomer via payments_profile {
  capability charge_cap: IO.NetworkCapability
  effect charge using charge_cap
}

-- via on any modifier
privileged contract UnlockDoor via security_profile {
  capability door_cap: IO.NetworkCapability
  effect unlock using door_cap
}
```

### § 2.3 Backward compatibility

Contracts without a `via` clause parse identically to before. `via_profile` is `nil`
in the AST. No existing fixture changes.

---

## § 3. ParsedProgram AST Delta

The `contract` node gains one optional field:

```json
{
  "kind": "contract",
  "name": "ChargeCustomer",
  "modifier": "effect",
  "via_profile": "payments_profile",
  "type_params": [],
  "body": [ ... ]
}
```

`via_profile` is absent (not null) when the `via` clause is not present. This keeps the
AST compact and avoids null-checking boilerplate in downstream stages.

---

## § 4. Pipeline Propagation

`via_profile` passes through all four compiler stages unchanged. No stage transforms it —
each stage records it in the output node and passes it forward.

### Stage 1 — Parser

`parse_contract_decl` checks for `via` keyword before `expect_type!(:lbrace)` and stores
the profile name in `node["via_profile"]`.

### Stage 2 — Classifier

`classify_contract` reads `via_profile` from the parsed contract and includes it in the
`classified_contract` node. No new OOF codes in this PROP.

### Stage 3 — TypeChecker

`typecheck_contract` reads `via_profile` from `classified_contract` and includes it in the
`typed_contract` node.

### Stage 4 — SemanticIR Emitter

`typed_contract_ir` reads `via_profile` from `typed_contract` and emits `profile_binding`
in the `contract_ir` node:

```json
{
  "kind": "contract_ir",
  "contract_name": "ChargeCustomer",
  "modifier": "effect",
  "profile_binding": "payments_profile",
  "fragment_class": "escape",
  ...
}
```

`profile_binding` is absent when `via_profile` is nil. The field name changes between
stages (source uses `via_profile`, IR uses `profile_binding`) to reflect the semantic
shift: `via_profile` is a source-level declaration intent; `profile_binding` is the
compiled artefact reference.

---

## § 5. OOF Codes

None introduced by this PROP. Profile constraint validation (e.g., verifying that a
`pure` contract does not bind a profile that requires `effect` authority) requires knowing
the profile schema, which is PROP-040 scope.

Future OOF codes scoped to PROP-040:
- OOF-M7: profile binding on a `pure` contract where profile declares `effect` authority
- OOF-M8: unknown profile name (profile not declared in module)

---

## § 6. Backward Compatibility

All existing source files compile without change. The `via` keyword is already in the
reserved keyword set (it appears in `impl` declarations: `impl Trait using Module`). As a
`contract-decl`-level optional clause it is unambiguous — `via` only appears at that
position if followed by an identifier before `{`.

---

## § 7. Dependency on PROP-031

PROP-031 §12 specified this grammar production verbatim. This PROP implements it
without modification. PROP-033 must not touch:
- `CONTRACT_MODIFIERS` list
- OOF-M1 or OOF-M2 codes
- The modifier→fragment_class mapping in the classifier
- The `escape_boundaries` logic in the SemanticIR emitter
