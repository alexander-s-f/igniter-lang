# LANG-COMPOSE-ENTITY-P1 — Entity Composition Readiness

**Status:** CLOSED — PROVED 49/49 — ROUTE: LANGUAGE PROPOSAL (held at readiness; no implementation)
**Track:** lang / design / entity-composition readiness
**Date:** 2026-06-14
**Authority:** proposal/readiness only — no parser/compiler/runtime implementation, no canon claim
**Card:** LANG-COMPOSE-ENTITY-P1
**Primary evidence:** LAB-TRADE-ROBOT-BASELINE-P1 (TR-P02/P03/P06); fleet survey (8 apps)

---

## 0. TL;DR

The fleet's strongest ergonomic pain is **state threading**: a family of contracts
that each take an entire state record in and return the entire (updated) state
record out, manually wired together with a separate config record and behavior
contracts — the **config + state + behavior triad**. It appears in ≥3 apps
(`trade_robot`, `sim_framework`, `arch_patterns`) and is heavily self-documented
as pain in source.

**Route: pursue a language proposal** for a first-class, **purely compile-time**
entity primitive that desugars to today's manual threading. It is *held at
readiness* here — P1 names the pattern, proves the desugaring target already
compiles dual-clean, maps the canon vocabulary it must build on, and fixes the
closed surfaces. **No implementation, no grammar, no keyword is reserved by P1.**

The keystone fact: the desugaring target (manual state threading over a record by
pure contracts) **already compiles dual-clean today** (Ruby 0 / Rust ok 0). So the
primitive can be **sugar with zero new runtime authority** — no mutable state, no
dynamic dispatch, no effect surface.

---

## 1. The pattern, named precisely

> **State threading** — a contract whose signature is `input s : S … output s' : S`
> for a record state type `S`, repeated across a family of contracts that
> collectively behave as one stateful object, with a sibling **config** record and
> a set of **behavior** contracts manually wired through every call site.

This is the "fat contract that threads all state manually" the apps complain about.

### Survey (≥3 apps; quantified, file:line)

| App | State type | Threading contracts (in S → out S) | Triad |
|-----|-----------|-------------------------------------|-------|
| `trade_robot` | `Portfolio` | `ExecuteSignal` (robot.ig:35-117), `RobotTick` (robot.ig:122-138), `BacktestTick` (backtester.ig) | config `RobotConfig` + state `Portfolio` + behavior {strategies, ExecuteSignal, dispatcher} |
| `sim_framework` | `SimState` | `SimTick` (engine.ig:15-59), `TimeTravel` (engine.ig:78-94) | config `SimConfig` + state `SimState` + behavior {GrowthRule, DecayRule, DisasterRule, ApplyRulePipeline, lenses} |
| `arch_patterns` | `AccountState`, `StateMachine` | `ApplyEvent` (event_sourcing.ig:12-53), `TryTransition` (state_machine.ig:55-77) | implicit rules + state + {ApplyEvent, CheckTransition, GuardCheck, TryTransition} |

`trade_robot/robot.ig:3` states it outright: *"THIS IS THE PAIN POINT. Without
`compose`, a Robot is just a fat contract that threads all state manually."*

### What the pattern is NOT (scope separation)

Two adjacent pains look related but are **different problems** and are out of scope
for an entity primitive:

1. **Dynamic dispatch** — `rule_engine`'s `call_contract(r, t)` with a variable
   callee. This is the **blocked witness** classified by
   **LAB-DYNAMIC-CONTRACT-DISPATCH-P2** (route: DEFER + preserve fail-closed). An
   entity must **not** widen it. Entity actions reference behavior by *name*
   (static), never by runtime string.
2. **Record-literal inference** — the `MakeSignal` / `MakeCell` / `MakeViolation`
   / `MakeLeaf` factory anti-pattern exists because inline records in `if/else`
   branches infer to `Unknown`. That is a **typechecker** concern (cf.
   LANG-RUBY-RECORD-LITERAL-INFERENCE), not a composition concern.

A third, **manual unroll** (`p1..p10 = call_contract("BacktestTick", …)`), is a
*fold-over-struct* gap — related to entities (an entity's "run N steps" would lower
to a managed loop, cf. PROP-039) but solvable independently. An entity primitive
would *benefit* from a fold-over-struct fix but does not require it.

---

## 2. Canon prior art — what an entity must build on (not reinvent)

Igniter already has **decentralized composition vocabulary**. An entity primitive
must integrate these, and must avoid colliding with reserved surface.

| Canon surface | What it gives | Constraint on entity design |
|---------------|---------------|------------------------------|
| **PROP-002** contract composition algebra | `>>` sequential, `\|\|` parallel, `branch`, `over`, `embed` over typed ports | An entity is, at the algebra level, hierarchical `embed` + sequential `>>`. Port binding is explicit and directional — no implicit type routing. |
| **PROP-016** polymorphism/traits/shapes | `trait`, `impl`, `contract_shape`, `refines`, **`composes`** | ⚠️ **`composes` is already reserved** (PROP-016:318) for contract-level explicit wiring — *not inheritance*. The entity keyword must be **distinct** (recommend `entity`). No OO inheritance; compose-by-wiring only. |
| **LANG-TYPED-CONTRACT-REF** | `uses ContractName` — typed, static, inspectable dependency edge, **no invocation/capability/dispatch** | The entity's behavior set is declared with `uses`. This is the exact static, named-reference model — preserves P2's static-dispatch discipline. |
| **PROP-031** contract modifiers | `pure` / `observed` / `effect` / `privileged` / `irreversible` | An entity's modifier must be **inferred from its actions** (an entity of `pure` actions is `pure`; one `effect` action forces `effect`). |
| **PROP-044** variant + exhaustive `match` | sum types; per-arm narrowing | Entity action outcomes (success/branch/failure) model as variants; the factory anti-pattern partly dissolves once branch records type cleanly. |
| **PROP-022 / PROP-028** History[T] / TEMPORAL | first-class temporal state + fragment class | If an entity tracks history (`temporal portfolio.balance` in the trade_robot wishlist), it must use `History[T]` and inherit TEMPORAL classification — not a bespoke struct. |

**Conclusion:** canon has the *pieces* (algebra, named refs, modifiers, variants,
temporal) but **no first-class entity syntax** binding them. The gap is integration,
not invention.

---

## 3. Candidate approaches (explored)

The card asks for a route among: reject / hold / stdlib helper / language proposal /
app pattern. Four candidates were weighed.

### Candidate A — App pattern / convention only (no language change)

Document the manual triad + `uses` as a blessed convention; ship nothing.

- ✅ Zero risk; works today (proven dual-clean).
- ❌ Does not remove the boilerplate — every action still restates the whole-state
  signature; every call site still threads `pN → pN+1`. The pain is *volume of
  mechanical wiring*, which a convention cannot reduce.
- **Verdict:** insufficient alone; keep as the **interim guidance** until the
  proposal lands.

### Candidate B — stdlib helper

A `stdlib` function that threads state (e.g. a generic `pipeline(state, [contracts])`).

- ❌ The pain is **declaration-site signature repetition** and the absence of a
  *namespace* binding config+state+behavior — neither is expressible as a function.
- ❌ A runtime helper that selects contracts would drift toward dynamic dispatch
  (P2-blocked).
- **Verdict:** reject — this is syntax, not a function.

### Candidate C — first-class `entity` as compile-time desugaring  ⭐ RECOMMEND

A declaration that groups a **state record**, a declared **behavior set**, and
**actions** that auto-thread the state, desugaring to exactly today's manual form.

Illustrative surface (design sketch, **not** grammar — for P-next to specify):

```igniter
entity Robot {
  config  : RobotConfig            -- immutable inputs, threaded read-only
  state   : Portfolio              -- the threaded record (copy-on-write)
  uses    SMACrossoverStrategy, RSIMeanReversion, CombinedStrategy, ExecuteSignal

  action ProcessCandle(candle : Candle, candles : Collection[Candle]) -> Signal {
    compute signal = CombinedStrategy(candles, config)         -- named, static
    state = ExecuteSignal(state, signal, candle.close, config, candle.tick)
    output signal
  }
}
```

Desugars to (today's working idiom — **already dual-clean**):

```igniter
contract RobotProcessCandle {
  input state : Portfolio
  input config : RobotConfig
  input candle : Candle
  input candles : Collection[Candle]
  compute signal = call_contract("CombinedStrategy", candles, config)
  compute new_state = call_contract("ExecuteSignal", state, signal, candle.close, config, candle.tick)
  output new_state : Portfolio
  output signal : Signal
}
```

- ✅ **Pure compile-time sugar** — desugaring target proven dual-clean (Section E
  of the proof; smallest fixture `Counter`/`Increment`/`Reset`/`Drive`).
- ✅ **Preserves static dispatch** — actions call behavior by name; the variable-
  callee form stays Unknown/blocked (P2 intact, proven F-02/F-05).
- ✅ **Builds on canon** — `uses` for the behavior set, modifier inference (PROP-031),
  `embed`/`>>` semantics (PROP-002), variants for outcomes (PROP-044).
- ✅ **No new runtime authority** — `state =` is copy-on-write rewrite to threaded
  outputs, not mutation; no effect surface.
- ⚠️ Cost: real parser/classifier/typechecker/emitter work in a future P. Must be
  scoped tightly (same-module v0, like LANG-TYPED-CONTRACT-REF did).
- **Verdict:** the right target. Removes the boilerplate at its source while
  staying inside the determinism/purity model.

### Candidate D — algebra + `uses` only (no entity keyword)

Lean entirely on PROP-002 operators + `uses`; let users write `A >> B` pipelines.

- ✅ Reuses accepted-direction surface; no new top-level form.
- ❌ Does not remove **state-threading signature repetition** — the operators
  compose *contracts*, but each contract still restates the whole-state I/O. The
  config+state+behavior *namespace* is still absent.
- **Verdict:** partial — a complement to C (an entity can lower **through** the
  algebra), not a replacement.

**Selected:** **C**, with **A** as interim guidance and **D** as the lowering
substrate. Route = **language proposal, held at readiness**.

---

## 4. The seven questions

**Q1. What repeated manual pattern is `compose` supposed to remove?**
**State threading** (whole-state in → whole-state out) and the **config + state +
behavior triad** that surrounds it — the two are the same problem from different
angles. *Not* record assembly (that's record-literal inference), *not* contract
chaining alone (PROP-002 covers that), *not* dynamic dispatch (P2).

**Q2. Language primitive, stdlib helper, or app-level pattern?**
**Language primitive** — specifically a *compile-time desugaring* (Candidate C).
It is syntax (a declaration form + auto-threading), not a function (rejects B) and
not merely a convention (A removes no boilerplate). The interim posture is the app
pattern (A) until the proposal lands.

**Q3. Can compose remain purely compile-time and deterministic?**
**Yes — and it must.** The desugaring target already compiles dual-clean (proof
Section E). `state =` is copy-on-write to threaded outputs, not mutation. No vtables
(PROP-016 monomorphization), no runtime selection. Determinism and CORE purity are
preserved; an entity is a pure projection over existing contracts.

**Q4. Does compose require dynamic dispatch, or can it preserve P2's static discipline?**
**It preserves static dispatch and requires no dynamic dispatch.** Actions name
their behavior contracts (via `uses` / literal callees), which are statically
resolved. The variable-callee form stays Unknown/blocked (proof F-02/F-05). If
*polymorphic strategy selection* is later wanted, that is the **separate,
P2-deferred typed closed-union** feature — explicitly out of scope here.

**Q5. How does compose interact with record-literal inference, output assignability, and capability/effect boundaries?**
- *Record-literal inference*: the entity's `state` record and action outputs are
  concrete record types; they benefit from (and do not regress) the record-literal
  inference track. Branch-record factories remain a separate fix.
- *Output assignability*: entity action outputs are concrete `S`/variant types —
  they flow through the existing OOF-TY1/D2 boundary unchanged; **no Unknown
  coercion is introduced** (LANG-OUTPUT-TYPE-ASSIGNABILITY-P4 preserved).
- *Capability/effect*: the entity **modifier is inferred** from its actions
  (PROP-031). A `pure` entity stays CORE; an `effect`/temporal action lifts the
  whole entity's fragment class (TEMPORAL precedence per PROP-028). No new effect
  authority is created by composition itself.

**Q6. Smallest proof fixture demonstrating value without inventing runtime authority?**
The `Counter` entity desugaring: a `Counter` state record + `Increment(by)` /
`Reset()` actions (each `Counter → Counter`) + a `Drive` sequencer calling them by
name. Its **manual desugaring compiles dual-clean today** (Ruby 0 / Rust ok 0,
proof Section E). This shows the target semantics already exist — value is the
*removal of boilerplate*, achievable with no new runtime behavior.

**Q7. What surfaces must remain closed before any P2 planning?**
- No parser/compiler/runtime implementation (P1 is readiness only).
- No reservation of the `entity` keyword in any toolchain yet.
- No reuse/redefinition of PROP-016 `composes`.
- No dynamic dispatch widening (variable callees stay Unknown/blocked).
- No mutable state, no `state =` runtime mutation semantics — copy-on-write only.
- No IO/capability/effect authority introduced by composition.
- No cross-module entity resolution in v0 (mirror LANG-TYPED-CONTRACT-REF's
  same-module-first discipline).
- No inheritance / virtual dispatch / vtables.

---

## 5. Route decision

**ROUTE = LANGUAGE PROPOSAL, held at readiness (HOLD).**

- It is a **language proposal** (not stdlib, not app-pattern-only): the pain is
  declaration-site syntax and a missing namespace, provable as a desugaring.
- It is **held** at readiness: P1 authorizes **no implementation**. The next step
  is a dedicated PROP that specifies the `entity` grammar, desugaring rules,
  modifier inference, and the v0 scope boundary — then a bounded implementation
  card with a proof matrix, mirroring the LANG-TYPED-CONTRACT-REF P2→P5 ladder.
- **Interim guidance:** apps keep the manual triad + `uses` convention (Candidate A)
  — it compiles dual-clean and is the literal desugaring target.

### Acceptance (card §Acceptance)

- ✅ Names the exact repeated pattern (state threading / triad) and distinguishes it
  from dynamic dispatch and record-literal inference.
- ✅ ≥3 app sources surveyed, including `trade_robot` (also `sim_framework`,
  `arch_patterns`).
- ✅ Route is one of the allowed set: **language proposal** (held).
- ✅ No implementation made.
- ✅ Closed surfaces fixed for any future P2.

---

## 6. Proof

```
runner:   igniter-lang/experiments/compose_entity_proof/verify_compose_entity_p1.rb
result:   49/49 PASS
sections: A preconditions (6) / B state-threading survey (8) / C distinct patterns (6) /
          D canon prior art (7) / E dual-clean desugaring target (6) /
          F static-dispatch preserved (5) / G closed surfaces (6) / H route decision (5)
```

---

## 7. Closed Surfaces (this card)

- No parser/compiler/runtime implementation.
- No dynamic dispatch widening.
- No IO/capability/effect authority.
- No app source edits.
- No `entity` keyword reserved; no PROP-016 `composes` redefinition.
- No public/canon claim.

---

## 8. Open routes (successors)

| Card | Scope |
|------|-------|
| LANG-COMPOSE-ENTITY-PROP-P2 (future) | Author the full `entity` PROP: grammar, desugaring rules, modifier inference, same-module v0 scope, OOF codes |
| (depends-on) fold-over-struct | Managed loop / fold with record accumulator (removes manual unroll) — cf. PROP-039, LANG-RUBY-RECORD-LITERAL-INFERENCE |
| (separate) branch-record inference | Dissolve the MakeXxx factory anti-pattern at the typechecker |
| (deferred, P2) typed closed strategy union | Polymorphic action selection without dynamic dispatch — LAB-DYNAMIC-CONTRACT-DISPATCH-P2 successor |
