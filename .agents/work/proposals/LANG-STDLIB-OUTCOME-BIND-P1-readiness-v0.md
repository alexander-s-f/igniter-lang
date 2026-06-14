# LANG-STDLIB-OUTCOME-BIND-P1 — Readiness (lead_router LR-P01, Result/.bind railway)

**Status:** CLOSED — READINESS PROVED 56/56 — ROUTE: P2 PLANNING (bind/and_then combinator)
**Track:** lang / stdlib / outcome-result-bind readiness
**Date:** 2026-06-14
**Authority:** proposal/readiness only — no implementation
**Primary evidence:** `lead_router` LR-P01 (a pure re-model of SparkCRM `ExecutorService` dry-monads `.bind` railway)

---

## 0. TL;DR

`lead_router` re-implements a dry-monads `Result` `.bind` railway **by hand**: a
user `variant Pipe { Proceed { ctx } | Reject { stage, message } }`, threaded
through **7 steps** that each re-write the *identical* `Reject`-carry arm to
short-circuit. That repeated carry arm is exactly what `.bind` / `and_then`
automates — and no such combinator exists in canon.

**Route: P2 planning for a `bind`/`and_then` combinator.** This is **not** addressed
by the existing `stdlib.outcome.*` helpers (those are `Map[String,String]`
inspection predicates — a different axis), and the canon `Result[T,E]` type is
spec'd but **lacks `and_then`** and is **not dual-clean** (Ruby unimplemented; Rust
partial). No implementation is authorized here; default expectation is P2 planning.

---

## 1. LR-P01 quantified — from source, not report text

`pipeline.ig`, verified by the proof runner:

| Metric | Source count |
|--------|--------------|
| railway steps with `input prev : Pipe` (`Pipe -> Pipe`) | **7** |
| `compute r = match prev { … }` short-circuit sites | **7** |
| **identical** `Reject { stage, message } => Reject { stage: stage, message: message }` carry arms | **7** |
| entry step (no `prev`, no carry) | 1 (`Validate`) |
| terminal Pipe eliminations in `service.ig` (`match p` → `VendorResponse`/`LeadSignal`) | 2 |

The 7 steps are `FindTrade · FindVendor · FindZip · BusinessHours · ResolveMode ·
CheckAvailability · GenerateResults`. Each begins with the same boilerplate carry
arm; the per-step logic lives only in the `Proceed` arm.

> **Discrepancy noted:** `PRESSURE_REGISTRY.md` (LR-P01) says "8 steps." From source
> the count of carry-arm steps is **7**; the registry's 8 includes `Validate`, which
> is the railway *entry* (it produces the first `Pipe` from `Params`, has no `prev`
> and no carry arm). The acceptance ("quantify from source, not report text") is met
> by the 7-step figure; the registry over-counts by 1.

---

## 2. The seven PROP questions — answers

**Q1. How many manual `match prev { Reject => carry; Proceed => work }` steps exist?**
**7** in `pipeline.ig` (§1), each with the identical `Reject`-carry arm. Plus 1 entry
(`Validate`) and 2 terminal eliminations in `service.ig` (which map `Pipe` to a
different type, so they are railway *elimination*, not `bind` steps).

**Q2. Is the pressure truly equivalent to `.bind`/`and_then`, or does it need richer audit/receipt data?**
The **short-circuit** is exactly `.bind`/`and_then`: "if `Reject`, carry unchanged;
if `Proceed`, run the next `Ctx -> Pipe` step." The richer **audit/receipt** need is
a **separate** concern: the `Reject` arm already carries `{stage, message}` (audit),
and the production `record_step` trail is modeled by `StepReceipt` + **LR-P02**
(fold-to-struct receipt accumulation). So `bind` handles LR-P01's sequencing;
receipt accumulation is orthogonal and routes to `LANG-FOLD-STRUCT-ACCUMULATOR`. The
combinator must *preserve* the carried `Reject` payload, not flatten it.

**Q3. Does existing `stdlib.outcome.*` address this? If not, why not?**
**No.** The existing track (`LANG-STDLIB-OUTCOME-PROP-P1/P2/P3`, CLOSED 60/60) is
**inspection over a `Map[String,String]` outcome envelope**: `stdlib.outcome.kind`
plus the PROP-047 failure predicates (`is_denied`, `is_unknown_external_state`,
`is_timed_out`, `is_system_error`, `is_query_error`, `is_partial_success`). That is a
**different axis** — *"what kind of outcome is this?"* — not *"sequence the next step
unless rejected."* It contains no `bind`/`and_then`, and it does not operate on a
user `variant`.

**Q4. Is a generic `Outcome[T,E]` authorized by existing canon, or still blocked?**
**The type is spec'd; the monad is incomplete and not dual-clean.** `Result[T,E]
-- Ok(T) | Err(E)` is a canon type (ch3 §3.1) and ch8 §8.4 (PROP-013) specs a
surface: `ok / err / map / unwrap_or`. **But:** (a) the spec'd surface has **no
`and_then`/`bind`** (the monadic sequencer — the exact LR-P01 need); and (b) the
surface is **not dual-clean** — the Ruby TC implements none of `ok/err/and_then/
unwrap_or` (each is "Unknown function"), while the Rust TC has `"ok"`, `"err"`, and
`"flat_map" | "and_then"` arms. User `variant`+`match`, by contrast, **is** dual-clean
— which is precisely why `lead_router` models the railway with `variant Pipe`, not
`Result`. So generic `Outcome` is *type-authorized* but *operationally incomplete*;
it is not "blocked by generic/sealed semantics" (user sum types work), it is simply
unfinished and divergent.

**Q5. Can a domain-local `Pipe` combinator be expressed without widening dynamic dispatch?**
**Yes.** A `bind`/`and_then` HOF takes the carried payload and a **statically-named**
next step (a lambda `(Ctx) -> Pipe`, or a typed contract reference). Every step in
`pipeline.ig` is already a Tier-1 literal `call_contract("StepName", …)` — static
dispatch. A combinator dispatches to those same named steps; it introduces **no
variable callee**, so `LAB-DYNAMIC-CONTRACT-DISPATCH-P2`'s fail-closed discipline is
preserved (LR-P05's dynamic vendor dispatch stays closed and unrelated).

**Q6. Canonical source alias and SIR name if a helper is later accepted?**
Align with the existing namespace and the ch8 §8.4 Result surface: source alias
**`stdlib.outcome.and_then`** (≡ dry-monads `.bind`; `and_then` matches the Rust TC
arm name and reads better than `bind` in Igniter), or, under candidate A, complete
**`Result.and_then`** as part of the spec'd Result surface. SIR: a typed call node
`{ fn: "stdlib.outcome.and_then", … }` (or a dedicated `bind_node` if lowering parity
needs it — a P2 decision). *Named, not committed.*

**Q7. Which surfaces remain closed?**
Runtime routing, retry/backoff policy, capability/effect authority, and **generic
sealed `Outcome[T,E]`** (the sealed-generic implementation) all remain closed. Also
closed: VM/runtime authority, app source edits, dynamic dispatch widening.

---

## 3. Route decision

**ROUTE = P2 PLANNING for a `bind`/`and_then` combinator.** The pressure is real,
primary ("the headline"), and fleet-wide (the SparkCRM companions share it). It is
**not** a proof-local convention and **not** "no helper." Two candidates for P2 to
adjudicate:

- **Candidate A — complete + unify the canon `Result[T,E]` monad, dual-clean.** Add
  Ruby parity for `ok/err/map/unwrap_or` and introduce `and_then` to the spec'd
  surface so both toolchains agree. *Pro:* canon already specs Result; Rust already
  half-implements it; `and_then` is the natural completion. *Con:* requires Result to
  be constructible + matchable dual-clean (today Rust-only), and apps would migrate
  `variant Pipe → Result[Ctx, RejectInfo]` (the `Reject` payload becomes `E`).
- **Candidate B — a `bind`/`and_then` combinator over a user 2-arm `variant`.** Keep
  the app's domain-local `Pipe`; the combinator collapses the 7 identical carry arms.
  *Pro:* `variant`+`match` is already dual-clean; no migration; preserves rich
  `Reject` payload. *Con:* needs a convention for "which arm short-circuits" (e.g. a
  2-arm variant with a designated continue-arm) and HOF-over-variant typing.

**Recommended primary = A** (canon-aligned completion of an already-spec'd type),
with **B as the lower-risk fallback** if dual-clean generic Result construction/match
proves too large for one card. Either way, P2 decides; **no implementation here**.

### Acceptance (card §Acceptance)

- ✅ LR-P01 quantified from source (7 carry-arm steps; registry's 8 over-counts) — §1.
- ✅ Existing `stdlib.outcome` track distinguished from bind/and_then (Map inspection vs sequencing) — Q3.
- ✅ No implementation authorized; default = P2 planning — §3.
- ✅ Dynamic dispatch remains closed (static Tier-1 only) — Q5.
- ✅ No app source edits.

---

## 4. Proof

```
runner:   igniter-lang/experiments/stdlib_outcome_bind_proof/verify_stdlib_outcome_bind_p1.rb
result:   56/56 PASS
sections: A preconditions (6) / B LR-P01 source-quantified (9) / C variant+match railway (6) /
          D stdlib.outcome ≠ bind (7) / E Result spec'd-but-not-dual-clean (9) /
          F sequencing vs receipts/dispatch (7) / G route (6) / H closed surfaces (6)
```

---

## 5. Closed surfaces

- No parser/typechecker/emitter/runtime changes.
- No generic sealed `Outcome[T,E]` implementation.
- No retryability or policy routing helper.
- No VM/runtime authority.
- No app migration.

---

## 6. Open routes (successors)

| Card | Scope |
|------|-------|
| LANG-STDLIB-OUTCOME-BIND-P2 (planning) | Adjudicate Candidate A vs B; name exact insertion points (Ruby `ok/err/and_then` parity OR variant combinator), SIR shape, dual-clean proof matrix |
| LANG-FOLD-STRUCT-ACCUMULATOR-P3/P4 | LR-P02 receipt accumulation (orthogonal to bind) |
| LANG-COMPOSE-ENTITY → PROP | LR-P04 `Ctx`/`Vendor` entity / state threading |
| LAB-DYNAMIC-CONTRACT-DISPATCH-P2 | LR-P05 vendor-protocol dispatch — stays fail-closed |
