# LANG-DYNAMIC-DISPATCH-UNKNOWN-POLICY-P1 — Dynamic Dispatch & Unknown-State Policy (Readiness)

**Stage:** readiness / language-policy / governance boundary
**Repo:** igniter-lang (primary) · igniter-lab (evidence)
**Date:** 2026-06-16
**Authority:** readiness/policy only. No compiler, VM, app, or IO change. Cards/proofs are evidence, not authority.
**Verify-first:** dual-toolchain (Ruby canon TC + Rust compiler), live diagnostics.
**Proof:** `igniter-lang/experiments/dynamic_dispatch_unknown_policy_proof/verify_dynamic_dispatch_unknown_policy_p1.rb` — **29/29 PASS**.

---

## 0. TL;DR — Policy decision

**Selected policy: A (keep dynamic dispatch fail-closed) + D (reject permissive
Unknown) — both already TRUE in the live toolchains and re-affirmed as the canon
governance default.** B (typed sealed dispatch registry) is named as the *only*
sanctioned forward design, **held at readiness behind a future PROP** — not
authorised here. C (dispatch-as-host-capability) is **deferred**, not rejected,
but is out of scope for the language surface. **Recommended next step: HOLD** —
no P2 implementation card is opened by this readiness. The lab decision
`LAB-DYNAMIC-CONTRACT-DISPATCH-P2` (DEFER + NO-CHANGE + PRESERVE fail-closed) is
**confirmed and lifted into a canon-side policy statement**; it is not new
behaviour.

This card changes nothing executable. Its product is a *legible, verified
boundary* so that dynamic dispatch is never opened casually and `Unknown` is
never treated as permissive by accident.

---

## 1. Authority surface (named before any claim)

- **What decides behaviour today:** the live Ruby canon typechecker
  (`igniter-lang/lib/igniter_lang/typechecker.rb`, `infer_call_contract`) and the
  live Rust compiler (`igniter-lab/igniter-compiler/src/typechecker/stdlib_calls.rs`,
  `"call_contract"` arm). Both were read and exercised.
- **What is only evidence:** the `rule_engine` app, its `PRESSURE_REGISTRY.md` /
  `report.md`, the lab cards `LAB-DYNAMIC-CONTRACT-DISPATCH-P1/P2`, and the prior
  parity work `LAB-RUBY-CALL-CONTRACT-PARITY-P3`. None of these confer canon
  authority.
- **What this card may change:** only `.agents/` proposal + card docs and a
  read-only `experiments/` proof runner. Nothing else.
- **Closed surfaces:** parser/typechecker/SemanticIR/VM, app sources, OOF code
  set, host IO/capability authority, live/staging.
- **Relevant canon prior art:** gov `DELTA-LEDGER.md` **D-001** (three-valued
  outcome model — canon-ahead, "do NOT re-litigate"), **D-007** (`call_contract`
  dispatch exists in the VM with guards; recursive self-call + TCO are the v0
  hold), PROP-031 modifiers, `LANG-TYPED-CONTRACT-REF-PROP` (`uses`).

> **Critical disambiguation.** The `Unknown` *type* produced by the typechecker
> for a Tier-2 callee is **not** the three-valued **outcome state** of D-001.
> One is a static type-inference fallback (fail-closed today); the other is the
> canon runtime outcome model (a separate, accepted design). This card governs
> the **type**; it deliberately does not touch D-001.

---

## 2. Verify-first answers to the card's 10 questions

All claims below are observed live (see §3 transcript and the 29/29 proof).

### Q1 — What forms of `call_contract` are accepted today?

| Callee form | Example | Classification | Result type |
|---|---|---|---|
| Literal `String` | `call_contract("RuleA", n)` | **Tier 1 (static)** | callee's single output type (resolved); multi-output → `Unknown` |
| Variable / value | `call_contract(name)` | **Tier 2 (dynamic)** | `Unknown` |
| Expression | `call_contract(if flag { "RuleA" } else { "RuleA" }, n)` | **Tier 2 (dynamic)** | `Unknown` |

The literal/non-literal split is the **only** distinction. A variable callee and
an expression callee are treated identically — both are "non-literal" and fall to
Tier 2 → `Unknown`. There is no third tier.

### Q2 — How do Ruby and Rust behave on a dynamic callee today?

**Identically.** Both implement the same two-tier logic and both resolve a
non-literal callee to `Unknown` with **no** error at the call site (no "Unknown
function"). Tier-1 checks (unknown callee, non-pure callee, self-recursion,
arity, first-arg-must-be-String) are byte-identical `OOF-TY0` diagnostics in both
toolchains. Dual-toolchain parity holds on every probe (proof G-03).

- Ruby: `typechecker.rb:705–774` (`infer_call_contract`, "Tier 1 … Tier 2 …").
- Rust: `stdlib_calls.rs:1417–1517` (`"call_contract"` arm, same comment header).

### Q3 — What exact diagnostics does `rule_engine` produce today?

Frozen, unchanged through Wave P13 / VM RUN-OK P3, re-verified live here:

- **Ruby — oof / 2:** `OOF-P1: Unresolved symbol: d` · `OOF-P1: Unresolved field: Unknown.action`
- **Rust — oof / 2:** `OOF-P1: Unresolved field: Unknown.action` · `OOF-TY1: Output type mismatch: expected RuleDecision, got Unknown`

Source hash unchanged (`engine.ig` still carries `map(rules, r -> call_contract(r, t))`). The app is the canonical *fail-closed evidence* app and must stay so.

### Q4 — Where does `Unknown` arise in the typechecker pipeline?

`Unknown` is the type-inference **fallback / bottom-compatible** marker. It is
emitted (non-exhaustively) for: a **Tier-2 dynamic callee**; a **multi-output**
literal callee (deferred); uncontextualised **record/array literals**; and as
the post-error sentinel after most `OOF-*` emissions. It is *not* a value-level
"any"; it marks "the checker has no concrete type here," and downstream rules
treat it as fail-closed at every boundary that demands a concrete type.

### Q5 — What field-access behaviour on `Unknown` exists today?

**Fail-closed.** Reading a field on an `Unknown`-typed value emits
`OOF-P1: Unresolved field: Unknown.<field>` in **both** toolchains. There is
**no permissive/duck-typed field access.** This directly contradicts the lab
app's narrative prose (see §5) and is the single most important correction this
card records.

### Q6 — Is `Unknown` permissiveness ever safe, or must it remain fail-closed?

It must remain **fail-closed** under the current model. The *only* clean Tier-2
path is an explicit `output : Unknown` **quarantine** — and that quarantine
grants **no capability**: it does not survive field access and produces no
concrete value. Any "permissive Unknown" (field access, upward coercion to a
concrete type) is rejected today and must stay rejected unless a *separate*,
explicitly-gated proof introduces bounded narrowing (validation receipt /
typed dispatch). Permissive Unknown is **not** accepted by accident — proof
section G pins this.

### Q7 — What authority model would dynamic dispatch require?

Ranked by safety (most → least sanctioned):

1. **Typed sealed dispatch registry (Policy B)** — `dispatch name : ContractRef[I,O]`
   drawn from a *static, closed* table; callee set and result type known at TC
   time. Preserves fail-closed; never yields `Unknown`. **This is the sanctioned
   forward design** (held behind a PROP).
2. **Host/capability boundary (Policy C)** — the contract *asks the host* to
   dispatch; the result is epistemic/outcome-wrapped (ties to D-001's outcome
   model, not the `Unknown` type). Deferred; a runtime/effect concern, not a
   language-surface concern.
3. **Allowlist** — weaker than a typed registry (no result-type guarantee);
   subsumed by B.
4. **Open dynamic dispatch / permissive Unknown (Policy D)** — **rejected.**

### Q8 — How does this differ from static string-literal dispatch in `lead_router`?

`lead_router` (and `trade_robot`'s `StrategyDispatcher`, TR-P06) use **Tier-1
literal** callees: `call_contract("CombinedStrategy", …)`. The name is a compile-
time constant, so the registry resolves the callee, checks purity/arity, and
yields a **concrete** result type — dual-clean, no `Unknown`. `rule_engine` uses
a **Tier-2 variable** callee (`r` from `map(rules, …)`), which is data, not a
constant, so it yields `Unknown` and fails closed downstream. The boundary is
exactly *literal vs non-literal*; static dispatch is already fully supported and
is the recommended pattern.

### Q9 — Which app pressures genuinely need dynamic dispatch vs can be rewritten?

Surveyed evidence:

- `rule_engine` — the *only* fleet app with a variable callee. Its rule-pipeline
  pressure is **rewritable** as a static `match`/variant pipeline or a closed
  `StrategyDispatcher` (the `trade_robot` pattern), at the cost of listing rules
  statically. No app *requires* data-driven callees today.
- `trade_robot` / `lead_router` — already static-dispatch; positive baselines.
- The genuine residual want is **ergonomic** (a plugin/middleware list), not a
  capability gap. That want is the target of Policy B, not a reason to open
  Tier-2.

**Conclusion:** no current app pressure justifies opening dynamic data dispatch.
The pressure is real but addressable by static rewrite now and by typed sealed
dispatch (B) later.

### Q10 — What is the narrow next card, if any?

**None opened. Recommend HOLD.** If/when the ergonomic pressure is prioritised,
the single safe slice is a **PROP** for Policy B (typed sealed dispatch
registry), mirroring the `LANG-TYPED-CONTRACT-REF` P2→P5 ladder, with the closed
surfaces in §6 fixed. This readiness deliberately does **not** open it.

---

## 3. Live probe transcript (abridged; full = 29/29 proof)

```
P1a literal valid   call_contract("RuleA", n)        Ruby CLEAN          Rust ok/0
P1b literal unknown call_contract("NoSuch", n)        Ruby OOF-TY0+OOF-TY1 Rust OOF-TY0+OOF-TY1
P2  variable callee + typed output                    Ruby OOF-TY1         Rust OOF-TY1  (got Unknown)
P2b variable callee + `output : Unknown` (quarantine) Ruby CLEAN          Rust ok/0
P3  variable callee + field access (.action)          Ruby OOF-P1 x2       Rust OOF-P1   (Unresolved field: Unknown.action)
P4  expression (if) callee + typed output             Ruby OOF-TY1         Rust OOF-TY1  (got Unknown)
P5  rule_engine (real, 4 files)                        Ruby oof/2           Rust oof/2
```

Every Ruby verdict matches the corresponding Rust verdict (parity). The Tier-1
checks, the Tier-2 `Unknown` fallback, the output-boundary rejection, and the
field-access rejection are all present in both toolchains.

---

## 4. Policy options evaluated

| Option | Description | Verdict | Rationale |
|---|---|---|---|
| **A** | Keep dynamic dispatch fail-closed (governance default) | **SELECTED** | Already TRUE in both toolchains; re-affirmed as canon policy |
| **B** | Typed sealed dispatch registry (`dispatch name : ContractRef[I,O]`) | **HELD (forward design)** | The only sanctioned path to lift the hold; requires a PROP; not authorised here |
| **C** | Dispatch as host capability/effect; outcome-wrapped result | **DEFERRED** | Legitimate but a runtime/effect concern; ties to D-001 outcome model, not the `Unknown` type; out of language-surface scope |
| **D** | Unknown permissiveness | **REJECTED** | Field access + upward coercion already fail-closed; must not be relaxed without a separate bounded proof |

---

## 5. Overclaim flagged (lab evidence — correction recommended, not made here)

The lab app `report.md` and parts of `PRESSURE_REGISTRY.md` narrate `Unknown` as
**permissive** — e.g. *"We proved that you can perform field access on an
`Unknown` object without causing a typecheck error"* and *"Igniter's `Unknown`
type acts similarly to `any` in TypeScript."* **This is contradicted by the live
toolchains:** field access on `Unknown` emits `OOF-P1` in both Ruby and Rust
(proof E-01/E-02), and the app itself is blocked precisely *because* of that
rejection. The prose describes an *aspiration the compiler does not implement*.

- **Authority note:** these are **lab** documents; this is a **canon** card. The
  correction is **recommended**, not performed here — it belongs to the lab
  owner. No lab source or doc was edited.
- **Recommended lab follow-up:** annotate `rule_engine/report.md` §2 ("Duck
  Typing via Permissive Unknown") to state that field access on `Unknown` is
  fail-closed (`OOF-P1`), and that the app is a *fail-closed counterexample*, not
  a duck-typing proof. If touched, leave a `PRESSURE_REGISTRY.md` pointer back to
  this card.

No canon (`igniter-lang`) document makes the permissive-Unknown claim (verified
by grep), so **no DELTA-LEDGER edit is required**. D-001 already correctly frames
the *outcome-state* Unknown and is untouched.

---

## 6. Closed surfaces fixed for any future P2 (Policy B PROP)

- No widening of Tier-2 (`Unknown`) dispatch; literal-vs-non-literal split holds.
- No permissive Unknown: no field access on `Unknown`, no `Unknown`→concrete
  coercion, no `Collection[Unknown]`→`Collection[T]` pass.
- Dispatch table must be **static and closed**; result type known at TC time.
- No new OOF code without a PROP.
- No host IO / capability / effect authority change (Policy C stays separate).
- Same-module v0 scope; no reflection; no stringly runtime authority.
- No app source migration (`rule_engine` stays fail-closed evidence).

---

## 7. Acceptance self-check

- ✅ Verify-first against **both** Ruby and Rust (29/29; live transcript).
- ✅ `rule_engine` status documented with **exact** diagnostics (§Q3).
- ✅ Static literal dispatch vs dynamic data dispatch **clearly separated** (§Q1, §Q8).
- ✅ Unknown-state policy **explicit**; permissive Unknown not accepted by accident (§Q6, proof G).
- ✅ Names one safe next slice (**Policy B PROP**) and **recommends HOLD** (no P2 opened).
- ✅ Does **not** implement dynamic dispatch; no `rule_engine` source change; no machine IO change.
- ✅ Overclaim in lab docs flagged with authority boundary respected (correction recommended, not made).

---

## 8. References (read for this card)

- `igniter-lang/lib/igniter_lang/typechecker.rb` — `infer_call_contract` (705–774).
- `igniter-lab/igniter-compiler/src/typechecker/stdlib_calls.rs` — `"call_contract"` (1417–1517).
- `igniter-lab/igniter-apps/rule_engine/{engine,types,rules,example}.ig`, `PRESSURE_REGISTRY.md`, `report.md`.
- `igniter-lab/igniter-apps/rule_engine/verify_dynamic_dispatch_p2.rb` (47/47, lab golden).
- `igniter-lab/lab-docs/lang/lab-dynamic-contract-dispatch-p2-safe-route-v0.md`.
- `igniter-gov/DELTA-LEDGER.md` — D-001 (outcome model), D-007 (VM dispatch).
- `igniter-lang/.agents/work/cards/lang/LANG-COMPOSE-ENTITY-P1.md` (Q4 cross-reference on preserving static dispatch).
