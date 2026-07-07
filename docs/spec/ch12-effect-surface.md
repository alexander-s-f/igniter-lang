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

Names the authority requirement of this contract. Required for `privileged`
and `irreversible`. Optional for `effect`.

> **Declaration vs enforcement (split 2026-07-06,
> LANG-EFFECT-SURFACE-AUTHORITY-SPEC-SPLIT-P7).** The clause declares
> `authority_ref` — a SOURCE-DECLARED intent/requirement reference, following
> the CR-003 pattern (a source-level intent record, like `profile_binding`).
> **Parsing or IR presence of `authority_ref` must NOT be read as proof that
> any runtime authority check happened.** Host enforcement is a HELD runtime
> responsibility: it activates only when an explicit, reviewed mapping exists
> from the source reference to one of —
> a passport subject/scope/capability requirement;
> a PROP-030-style executor approval token requirement;
> or another reviewed host-policy binding.
> **Ratified mapping model (2026-07-06,
> LANG-EFFECT-SURFACE-AUTHORITY-GOVERNANCE-P9, decision A — model F of the
> P8 readiness packet, unchanged):**
> - source domain: `authority_ref` is a **bare role ident**
>   (`billing_operator`) — no dotted refs, no host-policy keys, no secrets;
> - compile-time responsibility: syntax, placement, and IR emission ONLY —
>   the compiler never resolves roles;
> - runtime responsibility (**HELD** until the host-policy slice is
>   separately authorized): the HOST policy table resolves role → required
>   passport scope(s) on the existing `verify_passport` seam; a **missing
>   mapping fails closed** (refusal, no receipt — never silent allow);
>   receipts record the declared role alongside the checked authority digest;
> - a PROP-030 executor approval token remains an ORTHOGONAL
>   executor/artifact gate, not the role mapping;
> - a future profile PROP may constrain the allowed role set
>   (ch11's `requires_authority` prose — currently unauthored).
>
> With this model ratified: **the parser may accept `authority_ref` as
> declared intent only** (route: LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10);
> host role→scope enforcement remains held until the runtime/host-policy
> slice lands. Parser acceptance is NOT runtime enforcement — the
> declaration-vs-enforcement rule above stays load-bearing.

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
> metadata illegal placement (pure contract; observed for `idempotency` and
> `affects`) or duplicate clause; **OOF-M10** — `receipt`/`failure` references
> an unresolvable type; **OOF-M11** — malformed `idempotency` mode
> (parse-time); **OOF-M12** — malformed `affects` scope (parse-time);
> **OOF-M13** — malformed `authority` reference form (dotted ref or string
> literal; parse-time).
> (OOF-M3 stays reserved for authority resolution — **PROP-030
> executor-approval territory, with PROP-040 `requires_authority`
> interaction**; the older "deferred to PROP-034" pointer from the PROP-035
> card was a numbering-era ghost: PROP-034 is Output Evidence Syntax and owns
> OOF-M9. OOF-M7/M8 are taken by PROP-040 profile binding.) Tracked as ledger
> row D-009 in igniter-gov `DELTA-LEDGER.md`.
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
> - `affects external|internal <qualified-name>` parses as body-level metadata
>   in both toolchains (LANG-EFFECT-SURFACE-AFFECTS-P5); the dotted target
>   preserves source spelling; placement = effect/privileged/irreversible only
>   (pure AND observed refused — affects names a mutation target); parsed
>   values replace the former `effect_surface_v1` constants, absent clause
>   keeps the documented defaults (`external` / `IO.Capability`). Profile
>   `allowed_effects` enforcement stays **HELD** (profile policy). Proofs:
>   `experiments/effect_surface_affects_proof/` (12/12) + lab
>   `tests/effect_surface_affects_tests.rs` (8/8).
> - `authority <ident>` parses as body-level DECLARED-INTENT metadata in both
>   toolchains (LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10, under the ratified
>   model F): bare role symbol only — dotted refs and string literals fail
>   closed with OOF-M13; placement = effect/privileged/irreversible only
>   (pure AND observed refused, OOF-M6); `effect_surface_v1.authority_ref`
>   carries the parsed ident, absent → null. **Parser acceptance is NOT
>   runtime enforcement** — the declaration-vs-enforcement rule in §12.3
>   stays load-bearing; runtime status is the next bullet. Proofs:
>   `experiments/effect_surface_authority_proof/` (12/12) + lab
>   `tests/effect_surface_authority_tests.rs` (9/9).
> - Host-side role→scope resolution has a machine PROOF
>   (LANG-EFFECT-SURFACE-AUTHORITY-HOST-POLICY-P12, the runtime half of the
>   ratified model F): igniter-machine's host-constructed `AuthorityPolicy`
>   resolves the declared role to required passport scope(s) on the UNCHANGED
>   `verify_passport` seam; a declared role with no mapping **fails closed**
>   (`AuthRefusal::UnmappedAuthorityRole`, before the executor, no receipt);
>   receipts gain additive `declared_authority_role` / `resolved_scopes` /
>   `authority_policy_digest`; null `authority_ref` is a nil-safe passthrough.
>   **Proof-only — NOT wired into any production runner or host config**;
>   production wiring stays HELD for the host-config slices
>   (LANG-EFFECT-SURFACE-AUTHORITY-HOST-CONFIG-READINESS-P13 /
>   LANG-EFFECT-SURFACE-AUTHORITY-HOST-CONFIG-P14), so no production runner
>   enforces configured authority yet. Proof: machine
>   `tests/capability_io_authority_policy_tests.rs` (7/7).
> - `compensation <ContractName>` / `no_compensation` parse as body-level
>   metadata in both toolchains (LANG-EFFECT-SURFACE-COMPENSATION-P22);
>   three-state emission `compensation_mode: "ref"|"none"|null` +
>   `compensation_ref` (null=undeclared ≠ explicit waiver ≠ named ref —
>   Covenant P17); bare same-module ref only (dotted → OOF-M14; unknown →
>   OOF-M15); placement/duplicate/mutual-exclusion → OOF-M6; bare
>   `irreversible` → OOF-M3 warn. **Declaration only: names intent — grants no
>   authority, binds no host executor, executes nothing** (runtime compensation
>   = machine P12; a future host-binding card follows the authority
>   host-policy pattern). Typed compensator input/output compatibility is
>   deferred to a PROP-002-aligned slice. Proofs:
>   `experiments/effect_surface_compensation_proof/` (17/17) + lab
>   `tests/effect_surface_compensation_tests.rs` (8/8).
> - **Unified IR object (LANG-EFFECT-SURFACE-IR-UNIFICATION-P3):** both
>   toolchains emit the same nested `contract_ir["effect_surface"]` with
>   `kind: "effect_surface_v1"` (Ruby's former `effect_surface_v0_stub` renamed;
>   all stub-era proofs updated). Fields: `capability_bindings[{capability_name,
>   capability_type, effect_name}]` (capability_type follows **CR-001** — `IO.*`
>   normalizes to the `"IO.Capability"` sentinel), `affects_scope`/
>   `affects_target` (defaults until the `affects` slice), `authority_ref`
>   (null until the `authority` slice), `idempotency_mode`/`idempotency_key_expr`,
>   `receipt_type`/`failure_type`. The Rust flat fields and
>   `capabilities[]`/`effects[]` arrays remain as LEGACY compatibility surfaces
>   (igniter-machine `discover_effect_surface` consumes the arrays; the arrays
>   keep the concrete `IO.*` type name); new consumers read `effect_surface`.
>   Proofs: lab `tests/effect_surface_ir_unification_tests.rs` (5/5) + machine
>   `capability_io_host_tests` (9/9) + all Ruby effect-surface proofs green.

---

## § 12.6 Relationship to Other Chapters

- **Ch10 (Contract Modifiers):** Effect Surface applies only to `effect`, `privileged`,
  and `irreversible` contracts. Ch10 is a prerequisite.
- **Ch11 (Profile System):** profile `allowed_effects` restricts `affects` targets;
  `reversibility` maximum enforces OOF-M5.
- **Ch6 (SemanticIR):** the Effect Surface fields are emitted into the `contract_ir`
  node as a structured `effect_surface` object.
