# Chapter 11: Profile System

Status: accepted (profile binding + policy-restriction surface: OOF-M7/M8,
  OOF-PROF1–6) — obligation-side + stdlib profiles + Rust parity remain
  HELD/target (see scope note)
Stage: 3 (Phase 2)
Source PROPs: PROP-033 (via profile binding) + PROP-040 (profile declarations +
  OOF-M7/M8; renumbered out of the original PROP-035 slot on 2026-06-07) +
  PROP-048 (retry / max_reversibility / allowed_effects / loop) +
  PROP-049 (requires_authority)
Governance: META-EXPERT-013
Last updated: 2026-07-08

> **Accepted — scoped.** The **declaration + policy-restriction** surface is
> conformant and regression-locked (Ruby-canon):
> - `via` profile binding (PROP-033) and v0 profile declarations;
> - the authority min-modifier floor — **OOF-M7** (modifier below profile
>   authority) / **OOF-M8** (unknown profile) — dual-proven
>   (`profile_declarations_proof` 63/63);
> - the full §11.4 policy-restriction set (PROP-048/049 + PROP-037 annex):
>   **OOF-PROF1** (`allowed_effects`), **OOF-PROF2** (`requires_authority`,
>   declaration-consistency — grants nothing at runtime), **OOF-PROF3** (`loop`
>   class), **OOF-PROF4** (retry × idempotency), **OOF-PROF5** (reversibility
>   ceiling), **OOF-PROF6** (malformed policy field), **OOF-PROF7**
>   (`heartbeat`/`checkpoint`/`cancellation: required` — a bound contract must
>   declare the service obligation; P51), **OOF-PROF8** (`max_step_latency`
>   ceiling — a bound service's declared latency exceeds the profile's; P52,
>   ms-normalized). PROF7/PROF8 are declaration only — grant no runtime liveness.
>   All hard errors; per-field proofs in §11.4.
>
> **Explicitly HELD / target (NOT covered by this acceptance):**
> - the §11.4 rule-1 **obligation** checks (`evidence: required`, `time:
>   explicit`) — unimplemented;
> - the §11.3 non-service **obligation properties** (`time`/`lifecycle`/`backend`/
>   `evidence`) — not parsed as profile fields yet. (The service-loop obligations
>   `heartbeat`/`checkpoint`/`cancellation: required` ARE implemented — OOF-PROF7,
>   P51; `max_step_latency` as a ceiling is also implemented — OOF-PROF8, P52.)
> - the §11.5 **stdlib profiles** — not shipped;
> - runtime profile injection / authority resolution — separate HELD host line
>   (ch12 §12.3, P12–P20);
> - the aspirational loop spelling `finite_loop` (use `finite`); `convergent`
>   (P46) and `service` (P50) are now LIVE loop classes;
> - **Rust lab-compiler parity** — profiles are Ruby-canon-only (P33 HOLD until
>   this scoped acceptance is a stable target).
>
> Each HELD item advances this Status further when its own slice lands and
> regression-locks. (Historical note: this chapter originally cited "PROP-034",
> now Output Evidence Syntax.)

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
| `requires_authority` | list of bare role idents | A bound contract must DECLARE a ch12 `authority` clause whose role is one of the list; missing/other ⇒ OOF-PROF2. Declaration-consistency only — **grants no runtime authority**. **Implemented (PROP-049/P41).** |
| `loop` | `none`, `finite`, `recursive`, `fuel_bounded`, `budgeted`, `convergent`, `service` | Permitted loop class of a bound contract; a different class ⇒ OOF-PROF3. **Implemented (PROP-048/P42; `finite` P44, `convergent` P46, `service` P50)** over the LIVE loop vocabulary. The ch11 aspirational spelling `finite_loop` fails closed (OOF-PROF6 — use `finite`). |
| `heartbeat` | `required`, `optional`, `none` | Service loop heartbeat obligation; `required` ⇒ a bound contract must declare a `heartbeat` clause, else OOF-PROF7. **Implemented (PROP-037 annex/P51.)** Declaration only — grants no runtime liveness. |
| `checkpoint` | `required`, `optional`, `none` | Service loop checkpoint obligation; `required` ⇒ a bound contract must declare a `checkpoint` clause, else OOF-PROF7 (the meaningful case — P50 leaves checkpoint optional). **Implemented (PROP-037 annex/P51.)** |
| `cancellation` | `required`, `optional`, `none` | Service loop cancellation obligation; `required` ⇒ a bound contract must declare a `cancellation` clause, else OOF-PROF7. **Implemented (PROP-037 annex/P51.)** |
| `max_step_latency` | `<int>.<unit>` duration | Ceiling on a bound service's declared `max_step_latency`; a larger (or unit-unrecognized) declared latency ⇒ OOF-PROF8. Durations normalized to ms (`ms`/`second`/`minute`/`hour`, singular+plural). **Implemented (PROP-037 annex/P52.)** Declaration only — grants no runtime liveness. |
| `retry` | `enabled`, `disabled` | Whether the host may replay a bound contract's effect. `enabled` + a bound `idempotency none` contract ⇒ OOF-PROF4. **Implemented (PROP-048/P31).** |
| `max_reversibility` | reversibility scale value | Ceiling on a bound contract's ch12 `reversibility`; exceeding it ⇒ OOF-PROF5. **Implemented (PROP-048/P32).** |

---

## § 11.4 Compiler Enforcement

Profile-system diagnostics use the `OOF-PROF*` namespace. `OOF-PR*` is reserved
for PROP-037 progression diagnostics.

> **Absorbed surface (PROP-050, 2026-07-08).** Every policy rule in this
> section evaluates the contract's ABSORBED Effect Surface (ch12 §12.7): the
> contract's own fields AND each `invoke`d callee's absorbed record,
> conservatively. A profile ceiling (`allowed_effects`, `requires_authority`,
> retry×idempotency, `max_reversibility`) cannot be escaped by pushing an
> effect down one `invoke` level.

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
>   LANG-PROFILE-ALLOWED-EFFECTS-P35**), `OOF-PROF2` (bound contract's declared
>   ch12 `authority` role not among the profile's `requires_authority`; PROP-049
>   — **implemented Ruby-canon, LANG-PROFILE-REQUIRES-AUTHORITY-P41;
>   declaration-consistency, grants nothing at runtime**), `OOF-PROF3` (bound
>   contract's loop-class not the one permitted by the profile's `loop:`;
>   PROP-048 — **implemented Ruby-canon, LANG-PROFILE-LOOP-CLASS-P42**, over the
>   live loop vocabulary; ch11's aspirational `finite_loop`/`convergent`/`service`
>   stay Ch13-HELD),
>   `OOF-PROF4` (retry-enabled profile bound to an `idempotency none` contract;
>   PROP-048 — **implemented Ruby-canon, LANG-PROFILE-IDEMPOTENCY-RETRY-P31**),
>   `OOF-PROF5` (bound contract `reversibility` exceeds the profile's
>   `max_reversibility`; PROP-048 — **implemented Ruby-canon,
>   LANG-PROFILE-MAX-REVERSIBILITY-P32**), `OOF-PROF6` (malformed profile policy
>   field value — an unknown `retry`/`max_reversibility`/`loop` value or an
>   `allowed_effects` entry lacking an `external|internal` scope; fail-closed at
>   parse — **implemented with the fields, P31/P32/P35/P42**), **`OOF-PROF7`**
>   (a `heartbeat`/`checkpoint`/`cancellation: required` service obligation the
>   bound contract fails to declare; PROP-037 annex/P51 — declaration only,
>   **grants no runtime liveness**), and **`OOF-PROF8`** (a bound service's
>   declared `max_step_latency` exceeds the profile's ceiling, ms-normalized, or
>   uses an unrecognized unit — fail-closed; PROP-037 annex/P52 — declaration
>   only). `OOF-PROF1..8` are declared-consistency
>   violations between explicit declarations and are **hard errors**, not
>   warnings. **The ch11 §11.4 restriction set + the required-service-obligation
>   properties are implemented** (six policy fields + three service obligations):
>   `retry` (`enabled | disabled`, PROP-048/P31), `max_reversibility` (ch12 scale
>   value, PROP-048/P32 — first scale ordering), `allowed_effects`
>   (`[<scope>.<system>, ...]`, PROP-048/P35 — affects-target allow-list),
>   `requires_authority` (`[role, ...]`, PROP-049/P41 — a bound contract must
>   declare a matching ch12 `authority` role; declaration-consistency, **grants
>   nothing at runtime**), `loop` (live loop-class ceiling, PROP-048/P42), and
>   `heartbeat`/`checkpoint`/`cancellation: required` (PROP-037 annex/P51 — a
>   bound contract must declare the service obligation), and `max_step_latency`
>   (a ms-normalized ceiling on a bound service's declared latency; PROP-037
>   annex/P52). The remaining obligation-side rows
>   (`time`/`lifecycle`/`backend`/`evidence`) remain Ch13/target prose.

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

3. **Authority** (**implemented, PROP-049/P41**): if `requires_authority` is set
   (a list of bare role idents), a bound contract must DECLARE a ch12 `authority`
   clause whose role is one of the list. No `authority` clause, or a declared
   role outside the list ⇒ **OOF-PROF2** (hard). This is a **declaration-
   consistency** check over source facts only — it resolves no role, checks no
   passport, and **grants no runtime authority**: a passing OOF-PROF2 confers
   nothing; runtime authority remains the separate, HELD ch12 `authority_ref` →
   host `AuthorityPolicy` seam. (v0 is an is-one-of check against the contract's
   single declared role; a multi-role "must declare ALL" obligation is deferred
   until ch12 allows multiple `authority` clauses. The earlier modifier-floor
   reading of this rule is RETIRED — the profile `authority:` min-modifier +
   OOF-M7 already enforces the modifier floor. See PROP-049.)

4. **Loop class** (**implemented, PROP-048/P42**): if `loop:` is set (one of the
   LIVE classes `none | finite | recursive | fuel_bounded | budgeted`), a
   `via`-bound contract whose loop-class differs from the permitted one ⇒
   **OOF-PROF3** (hard). A contract's loop-class(es) are live source facts: the
   `recursive` / `fuel_bounded` modifiers, a `for` FiniteLoop (`finite`, P44),
   and a `budgeted_loop` (`loop … max_steps …`) body decl; a contract using no
   loop construct is unrestricted. `loop: none` forbids
   any loop construct. Absent `loop` ⇒ no constraint. Compile-time policy
   (Covenant P10); grants nothing at runtime.
   > The ch11 aspirational values `finite_loop` / `convergent` / `service` and
   > the original "`loop: service` ⇒ `service contract` form" reading are **HELD**
   > for Ch13 (Managed Recursion) — no compiler surface backs them, so a profile
   > naming one fails closed at parse (OOF-PROF6) rather than silently accepting
   > an unenforceable class.

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
