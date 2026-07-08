# Chapter 11: Profile System

Status: proposed (binding + declarations experiment-pass via PROP-033/PROP-040)
Stage: 3 (Phase 2)
Source PROPs: PROP-033 (via profile binding, experiment-pass) +
  PROP-040 (profile declarations + OOF-M7/M8, experiment-pass;
  renumbered out of the original PROP-035 slot on 2026-06-07)
Governance: META-EXPERT-013
Last updated: 2026-07-06

> **Proposed, partially proven.** Profile binding syntax (PROP-033) and v0
> profile declarations with OOF-M7/M8 binding checks (PROP-040) are
> experiment-pass. Runtime profile injection/authority resolution, the
> reversibility scale, and broader profile policy remain closed until
> separately authorized. Status advances to `accepted` when the full
> profile-system regression suite passes. (Historical note: this chapter
> originally cited "PROP-034", which is now Output Evidence Syntax.)

---

## § 11.1 Overview

A profile is a named, compile-time policy declaration that binds to a contract
via the `via` clause. It declares what the contract is *obligated* to do and
*restricted* from doing — independently of the contract body.

```igniter
profile audited_billing {
  time: explicit
  lifecycle: :audit
  backend: :ledger
  evidence: required
  allowed_effects: [external.payment_gateway, internal.ledger]
  requires_authority: [billing_operator]
}

effect contract ChargeCustomer(customer_id: String, amount: Decimal[2])
  via audited_billing
{
  ...
}
```

The compiler validates that the contract body satisfies the profile's obligations
and does not exceed its restrictions. A contract without `via` uses the implicit
`default` profile, which imposes no additional constraints.

---

## § 11.2 Grammar

```
profile-decl  ::= "profile" ident "{" profile-prop* "}"

profile-prop  ::= time-prop
               | lifecycle-prop
               | backend-prop
               | evidence-prop
               | allowed-effects-prop
               | requires-authority-prop
               | loop-prop
               | heartbeat-prop
               | checkpoint-prop
               | cancellation-prop
               | max-step-latency-prop

via-clause    ::= "via" ident

contract-decl ::= contract-modifier? "contract" ident type-params?
                  "(" param-list? ")" ("->" output-spec)?
                  via-clause?
                  "{" body-decl* "}"
```

`profile-decl` is a new top-level declaration alongside `contract`, `type`, and
`olap_point`. The `via-clause` is an optional extension to `contract-decl`.

---

## § 11.3 Profile Properties

| Property | Values | Meaning |
|----------|--------|---------|
| `time` | `explicit`, `implicit`, `none` | Whether `as_of: DateTime` is required on the contract |
| `lifecycle` | `:session`, `:durable`, `:audit` | Minimum persistence tier for outputs |
| `backend` | `:memory`, `:ledger`, `:external` | Required storage backend |
| `evidence` | `required`, `optional`, `none` | Whether `output ... evidence [...]` is mandatory |
| `allowed_effects` | list of `<scope>.<system>` refs | Restricts which Effect Surface `affects` targets a bound contract may declare (dot-boundary prefix match). Exceeding ⇒ OOF-PROF1. **Implemented (PROP-048/P35).** |
| `requires_authority` | list of authority symbols | Contract must receive matching authority |
| `loop` | `none`, `finite_loop`, `fuel_bounded`, `convergent`, `service` | Permitted loop class |
| `heartbeat` | `required`, `optional`, `none` | Service loop heartbeat obligation |
| `checkpoint` | `required`, `optional`, `none` | Service loop checkpoint obligation |
| `cancellation` | `required`, `optional`, `none` | Service loop cancellation handling obligation |
| `max_step_latency` | duration | Maximum time budget per loop step |
| `retry` | `enabled`, `disabled` | Whether the host may replay a bound contract's effect. `enabled` + a bound `idempotency none` contract ⇒ OOF-PROF4. **Implemented (PROP-048/P31).** |
| `max_reversibility` | reversibility scale value | Ceiling on a bound contract's ch12 `reversibility`; exceeding it ⇒ OOF-PROF5. **Implemented (PROP-048/P32).** |

---

## § 11.4 Compiler Enforcement

Profile-system diagnostics use the `OOF-PROF*` namespace. `OOF-PR*` is reserved
for PROP-037 progression diagnostics.

> **Namespace split (LANG-CH11-OOF-NAMESPACE-RECONCILE-P30, 2026-07-08).** The
> profile system emits two diagnostic families, and they use different code
> prefixes for compatibility reasons:
>
> - **Binding diagnostics** (shipped, PROP-040 experiment-pass) use `OOF-M7`
>   (contract modifier authority below the profile's declared authority) and
>   `OOF-M8` (unknown profile name). These are **stable** — they are asserted by
>   committed evidence (`profile_declarations_proof`, 63/63) — and are **not**
>   renumbered into `OOF-PROF*`. A future `accepted`-stage decision may add
>   `OOF-PROF*` *aliases*, but never a silent renumber.
> - **Policy diagnostics** (the obligations/restrictions below) use the
>   `OOF-PROF*` namespace: `OOF-PROF1` (bound `affects` target not in the
>   profile's `allowed_effects`; PROP-048 — **implemented Ruby-canon,
>   LANG-PROFILE-ALLOWED-EFFECTS-P35**), `OOF-PROF2`–`OOF-PROF3` (target rows
>   below — `requires_authority` is HELD, see the P36 readiness packet),
>   `OOF-PROF4` (retry-enabled profile bound to an `idempotency none` contract;
>   PROP-048 — **implemented Ruby-canon, LANG-PROFILE-IDEMPOTENCY-RETRY-P31**),
>   `OOF-PROF5` (bound contract `reversibility` exceeds the profile's
>   `max_reversibility`; PROP-048 — **implemented Ruby-canon,
>   LANG-PROFILE-MAX-REVERSIBILITY-P32**), `OOF-PROF6` (malformed profile policy
>   field value — an unknown `retry`/`max_reversibility` value or an
>   `allowed_effects` entry lacking an `external|internal` scope; fail-closed at
>   parse — **implemented with the fields, P31/P32/P35**). `OOF-PROF1/4/5/6` are
>   declared contradictions between two explicit declarations and are **hard
>   errors**, not warnings. Three PROP-048 policy fields have landed: `retry`
>   (`enabled | disabled`, P31), `max_reversibility` (ch12 scale value, P32 —
>   which encodes the scale ORDERING for the first time), and `allowed_effects`
>   (`[<scope>.<system>, ...]`, P35 — affects-target allow-list).

For each contract with a `via` clause, the compiler checks:

1. **Obligations met**: if `evidence: required`, every `output` in the body must
   carry an `evidence [...]` clause. If `time: explicit`, the contract must declare
   `input as_of: DateTime`.

2. **Restrictions not exceeded** (**implemented, PROP-048/P35**): if
   `allowed_effects` is set (a list of `<external|internal>.<system>` refs), a
   bound contract's Effect Surface `affects <scope> <target>` must match some
   entry — same scope AND `target` equal to the entry's system or beginning with
   `system + "."` (dot-boundary prefix, so `external.payment_gateway` covers
   `payment_gateway.charge`). No match ⇒ **OOF-PROF1** (hard). Absent
   `allowed_effects` ⇒ no restriction; no `affects` clause ⇒ no violation; empty
   list ⇒ allow nothing. (v0 restricts `affects` targets — the stable
   cross-contract system identity — not local capability aliases; see the P34
   readiness packet.)

3. **Authority**: if `requires_authority` is set, the contract modifier must be
   `privileged` or `irreversible`. Violation: OOF-PROF2.

4. **Loop class**: if `loop: service` is declared, the contract modifier must be
   absent or use the `service contract` form (Ch13). Violation: OOF-PROF3.

---

## § 11.5 Stdlib Profiles

The stdlib ships seven built-in profiles:

| Profile | Intended use |
|---------|-------------|
| `pure` | Pure computation only; no escape, no evidence |
| `simple_compute` | Lightweight compute; session lifecycle |
| `audited_compute` | Evidence required; durable lifecycle; ledger backend |
| `mesh` | Distributed computation; causal consistency |
| `safety_critical` | Strong consistency; evidence required; authority required |
| `agent_planning` | Fuel-bounded convergent loops; audit lifecycle |
| `emergency_service` | Service loop with all three obligations; strong consistency |

Full property tables for each profile are specified in PROP-034.

---

## § 11.6 Relationship to Other Chapters

- **Ch10 (Contract Modifiers):** profiles may restrict which modifiers are permitted
  (e.g., a `pure`-only profile rejects `effect` contracts). Ch10 is a prerequisite.
- **Ch12 (Effect Surface):** the `allowed_effects` profile property validates
  against the Effect Surface fields in Ch12.
- **Ch13 (Managed Recursion):** the `loop`, `heartbeat`, `checkpoint`,
  `cancellation`, and `max_step_latency` properties govern service loops defined
  in Ch13.
