# Chapter 12: Effect Surface

Status: proposed (body-decl subset experiment-pass via PROP-035 v0)
Stage: 3 (Phase 2)
Source PROP: PROP-035 — authored + experiment-pass 2026-06-07
  (`.agents/work/proposals/PROP-035-effect-surface-io-capability-v0.md`,
  proof 64/64 `experiments/io_capability_proof/`)
Governance: META-EXPERT-013
Delta tracking: igniter-gov `DELTA-LEDGER.md` rows D-001 / D-005 / D-009
Last updated: 2026-07-06

> **Proposed, partially proven.** PROP-035 v0 is authored and experiment-pass,
> but its scope is the body-level `capability` / `effect ... using` declarations
> plus structural checks — NOT the seven-field Effect Surface this chapter
> defines. The seven-field grammar, outcome taxonomy, required-field enforcement,
> and unified parsed `effect_surface` SemanticIR shape remain incomplete. (Ruby
> has a later `effect_surface_v0_stub`; Rust emits `capabilities[]`/`effects[]`.)
> Chapter status advances to `accepted` when the full surface regression suite passes.
>
> Lab evidence (igniter-machine capability-IO receipts/reconcile; softphone
> P6–P8 unknown→reconcile loop) proves the outcome semantics at the host
> boundary. That is design evidence for this chapter — not canon acceptance.

---

## § 12.1 Overview

An `effect`, `privileged`, or `irreversible` contract must declare its Effect
Surface — a set of seven fields that make the contract's consequences explicit and
compiler-verifiable.

```igniter
effect contract ChargeCustomer(customer_id: String, amount: Decimal[2], currency: String)
  -> receipt: ChargeReceipt
  affects  external PaymentGateway.ChargeEndpoint
  authority billing_operator
  reversibility :compensatable
  idempotency key content_hash(customer_id, amount, currency)
  receipt  ChargeReceipt
  failure  PaymentFailure
  compensation RefundCustomer
  via audited_billing
{
  ...
}
```

The Effect Surface separates the *declaration of consequence* from the *body of
computation*. A reader can understand the full external impact of a contract by
reading the surface alone, without inspecting the body.

`pure` and `observed` contracts do not carry an Effect Surface. `observed` contracts
may carry `receipt` and `failure` for the observation result, but the remaining
fields are not applicable.

---

## § 12.2 Grammar

```
effect-surface ::= affects-clause
                   authority-clause?
                   reversibility-clause
                   idempotency-clause
                   receipt-clause
                   failure-clause
                   compensation-clause?

affects-clause       ::= "affects" ("external" | "internal") qualified-name
authority-clause     ::= "authority" ident
reversibility-clause ::= "reversibility" reversibility-value
reversibility-value  ::= ":reversible" | ":compensatable" | ":refundable"
                       | ":append_only" | ":irreversible" | ":destructive"
idempotency-clause   ::= "idempotency" ("key" expr | "natural" | "none")
receipt-clause       ::= "receipt" type-ref
failure-clause       ::= "failure" type-ref
compensation-clause  ::= "compensation" contract-ref | "no_compensation"
```

The Effect Surface appears between the return type and the `via` clause in a
contract declaration.

---

## § 12.3 The Seven Fields

### affects

Names the external or internal system that the contract mutates. Required for all
three modifiers. The `external` keyword signals that the named system is outside
the current igniter-lang application boundary.

### authority

Names the authority role required to execute this contract. Required for
`privileged` and `irreversible`. Optional for `effect`. When present, the runtime
verifies the authority before execution.

### reversibility

Declares where the action sits on the reversibility scale:

| Value | Meaning |
|-------|---------|
| `:reversible` | Can be undone without consequence |
| `:compensatable` | Cannot be undone, but can be compensated |
| `:refundable` | Monetary or resource compensation is possible |
| `:append_only` | Data can be appended but not deleted |
| `:irreversible` | No compensation is possible |
| `:destructive` | Data is deleted or permanently altered |

### idempotency

Declares the idempotency contract for this operation. Required for all three
modifiers. Non-idempotent operations under automatic retry are a compile-time error.

- `key expr`: the operation is idempotent when the key expression matches a prior call
- `natural`: the operation is naturally idempotent (e.g., `SET x = 5`)
- `none`: explicitly declares non-idempotency; prohibited in retry-enabled profiles

### receipt

Names the type of audit proof emitted when the operation completes. The receipt
is returned as part of the contract's output.

### failure

Names the error type emitted when the operation fails. This is not an exception —
it is a declared output variant. The full error taxonomy includes seven possible
outcomes:

| Outcome | Description |
|---------|-------------|
| `succeeded` | Operation completed as expected |
| `failed` | Operation returned a known error |
| `partial` | Operation partially completed |
| `timed_out` | Time limit exceeded — outcome unknown |
| `unknown_external_state` | Request sent, no confirmation received |
| `compensated` | Failure triggered compensation |
| `cancelled` | Operation was cancelled before completion |

`unknown_external_state` is not a failure. It signals that a reconciliation pass
is required before retrying.

### compensation

Names the contract that reverses or compensates for the operation if it must be
undone. Required for `irreversible` contracts unless `no_compensation` is declared.
Optional for `effect` and `privileged`.

---

## § 12.4 Reversibility Scale

```
reversible < compensatable < refundable < append_only < irreversible < destructive
```

A profile may declare a maximum reversibility level. An `irreversible` contract
in a profile that only permits `compensatable` is a compile-time error (OOF-M2).

---

## § 12.5 OOF Rules

| Code | Condition | Severity |
|------|-----------|----------|
| OOF-M2 | `effect/privileged/irreversible` missing required Effect Surface fields | error |
| OOF-M3 | `irreversible` without `compensation` or `no_compensation` | warn |
| OOF-M4 | `idempotency: none` used in a retry-enabled profile | error |
| OOF-M5 | `reversibility` exceeds profile maximum | error |

> **Numbering decision (2026-07-06, LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1 D1).**
> The implemented v0 allocation is KEPT: OOF-M2/M4/M5 remain PROP-035's
> capability/effect_binding **structural** checks (pure-with-capability /
> undeclared-capability-ref / unbound-capability), dual-toolchain proven. The
> table above is this chapter's TARGET-requirement prose; its rules will receive
> fresh codes as each field slice lands (do not read table codes as implemented).
> Codes allocated so far by completion slices: **OOF-M6** — Effect Surface
> metadata illegal placement (pure contract; observed for `idempotency`) or
> duplicate clause; **OOF-M10** — `receipt`/`failure` references an
> unresolvable type; **OOF-M11** — malformed `idempotency` mode (parse-time).
> (OOF-M3 stays reserved for authority resolution / PROP-034 territory;
> OOF-M7/M8 are taken by PROP-040 profile binding; OOF-M9 by PROP-034
> evidence.) Tracked as ledger row D-009 in igniter-gov `DELTA-LEDGER.md`.
>
> **Implemented so far (2026-07-06):**
> - `receipt <TypeRef>` / `failure <TypeRef>` parse as body-level Effect
>   Surface metadata in both toolchains; typechecker resolves the referenced
>   type (declared type/variant or builtin scalar) and fails closed otherwise;
>   SemanticIR carries the parsed `receipt_type`/`failure_type` (Ruby
>   `effect_surface_v0_stub`; Rust `contract_ir` fields). Proofs:
>   `experiments/effect_surface_receipt_failure_proof/` (18/18) + lab
>   `tests/effect_surface_receipt_failure_tests.rs` (8/8).
> - `idempotency key <expr>` / `natural` / `none` parse as body-level metadata
>   in both toolchains (LANG-EFFECT-SURFACE-IDEMPOTENCY-P2); the key expression
>   types through normal inference; placement = effect/privileged/irreversible
>   only (pure AND observed refused — idempotency governs mutation retry);
>   SemanticIR carries parsed `idempotency_mode`/`idempotency_key_expr`.
>   Proofs: `experiments/effect_surface_idempotency_proof/` (16/16) + lab
>   `tests/effect_surface_idempotency_tests.rs` (9/9). The §12.5 target rule
>   "`idempotency: none` in a retry-enabled profile" stays **HELD** for the
>   profile-policy follow-up — no retry-enabled profile flag exists in either
>   toolchain yet.

---

## § 12.6 Relationship to Other Chapters

- **Ch10 (Contract Modifiers):** Effect Surface applies only to `effect`, `privileged`,
  and `irreversible` contracts. Ch10 is a prerequisite.
- **Ch11 (Profile System):** profile `allowed_effects` restricts `affects` targets;
  `reversibility` maximum enforces OOF-M5.
- **Ch6 (SemanticIR):** the Effect Surface fields are emitted into the `contract_ir`
  node as a structured `effect_surface` object.
