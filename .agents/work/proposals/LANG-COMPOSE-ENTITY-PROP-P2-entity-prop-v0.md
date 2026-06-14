# LANG-COMPOSE-ENTITY-PROP-P2: `entity` Declaration v0

**Status:** CLOSED -- full PROP authored -- READY FOR P3 IMPLEMENTATION PLANNING
**Date:** 2026-06-14
**Route:** LANG PROP / entity composition
**Authority:** proposal authoring only; no parser/compiler/runtime implementation
**Card:** `LANG-COMPOSE-ENTITY-PROP-P2`

---

## 0. Summary

This PROP introduces a same-module `entity` declaration as compile-time sugar for
an already-proven pattern: a state record threaded through a set of pure or
modifier-classified contracts, with config records and a static behavior set.

The selected surface is deliberately narrow:

- one threaded `state` binding;
- zero or more immutable `config` bindings;
- a static `uses` behavior set of typed contract references;
- `action` declarations that lower to ordinary contracts;
- same-module v0 only;
- no runtime object, no mutable state, no dynamic dispatch, no IO authority.

`entity` is not a synonym for PROP-016 `composes`. PROP-016 already reserves
`composes` for contract-shape wiring. This PROP uses the distinct keyword
`entity`.

---

## 1. Motivation

The app fleet repeatedly expresses a **config + state + behavior triad**:

- `trade_robot`: `RobotConfig` + `Portfolio` + strategy/transition contracts.
- `sim_framework`: `SimConfig` + `SimState` + rule/lens contracts.
- `arch_patterns`: `AccountState` / `StateMachine` + transition contracts.

The current manual form compiles, but it forces every action to restate the same
state input/output and config threading. The entity declaration removes that
boilerplate while lowering to the manual form.

This is design/ergonomic pressure, not a runtime unblocker. The manual
desugaring target is already dual-clean.

---

## 1.1 Prior Art Integration

This PROP composes existing canon language surfaces rather than replacing them:

- PROP-002 remains the composition algebra substrate; entity actions lower to
  ordinary contracts that can participate in existing composition.
- PROP-016 reserves `composes`, so entity v0 deliberately uses a different
  keyword and does not redefine contract-shape composition.
- LANG-TYPED-CONTRACT-REF supplies the static `uses ContractName` model used by
  the entity behavior set.
- PROP-031 supplies modifier and fragment inference for generated action
  contracts.
- PROP-044 variants and exhaustive match remain the closed polymorphism route.
- PROP-022/028 temporal history and temporal fragments stay separate; entity v0
  introduces no temporal clocks or ambient time.

---

## 2. Non-Goals

The v0 entity surface does not include:

- dynamic dispatch or runtime string-to-contract lookup;
- open plugin registries;
- inheritance, virtual methods, vtables, or subtype polymorphism;
- cross-module entity declarations or cross-module entity behavior resolution;
- runtime mutable objects or identity;
- `group_by`, join, `flat_map`, scan, or relational operations;
- temporal clocks or ambient time;
- IO, capability, effect authority, broker/exchange/market-data integration;
- app source migration;
- parser ergonomics for record-returning lambdas;
- collection-run sugar that depends on fold-to-record implementation.

---

## 3. Same-Module v0 Grammar

This is the proposed source grammar for P3 planning. It is not implemented by
this card.

```ebnf
entity_decl       ::= "entity" TypeIdent "{" entity_member* "}"

entity_member     ::= state_decl
                    | config_decl
                    | entity_uses_decl
                    | action_decl

state_decl        ::= "state" ident ":" type_ref
config_decl       ::= "config" ident ":" type_ref

entity_uses_decl  ::= "uses" contract_ref ("," contract_ref)*

action_decl       ::= "action" TypeIdent "(" param_list? ")" action_result? action_body
action_result     ::= "->" type_ref
action_body       ::= "{" action_stmt* "}"

action_stmt       ::= compute_stmt
                    | state_update_stmt
                    | output_stmt

compute_stmt      ::= "compute" ident "=" entity_expr
state_update_stmt ::= "state" "=" behavior_call
output_stmt       ::= "output" ident

behavior_call     ::= ContractIdent "(" arg_list? ")"
entity_expr       ::= existing_expr
                    | behavior_call
```

### Notes

- `entity` is a new top-level declaration kind.
- `state` declares the one threaded state binding for v0.
- `config` bindings are read-only inputs to every generated action contract.
- `uses` entries are typed contract references, not invocations and not
  runtime capabilities.
- `ContractIdent(...)` in an action body is an entity-local static behavior call.
  It must resolve to a contract listed in the entity's `uses` set.
- The v0 grammar does not allow `composes`.
- The v0 grammar does not allow `action Run over candles`; collection-run sugar
  waits for fold-to-record P3/P4.

---

## 4. Example

Source:

```igniter
entity Robot {
  config config : RobotConfig
  state portfolio : Portfolio

  uses CombinedStrategy, ExecuteSignal

  action ProcessCandle(candle : Candle, candles : Collection[Candle]) -> Signal {
    compute signal = CombinedStrategy(candles, config)
    state = ExecuteSignal(portfolio, signal, candle.close, config, candle.tick)
    output signal
  }
}
```

Desugaring target:

```igniter
contract RobotProcessCandle {
  input portfolio : Portfolio
  input config : RobotConfig
  input candle : Candle
  input candles : Collection[Candle]

  compute signal = call_contract("CombinedStrategy", candles, config)
  compute next_portfolio = call_contract(
    "ExecuteSignal",
    portfolio,
    signal,
    candle.close,
    config,
    candle.tick
  )

  output next_portfolio : Portfolio
  output signal : Signal
}
```

The generated contract is ordinary Igniter. The entity declaration creates no
runtime object. State update is copy-on-write threading: the input state binding
is not mutated; a new output state value is produced.

The entity-level `uses` set is validated before this lowering. The executable
v0 source target does not require today's ordinary `contract` parser to accept
contract-reference `uses`; generated `call_contract("LiteralName", ...)` sites
are emitted only after static validation against the entity `uses` set.

---

## 5. Desugaring Rules

For an entity:

```igniter
entity E {
  config c1 : C1
  config c2 : C2
  state s : S
  uses A, B
  action Do(x : X) -> R { ... }
}
```

the compiler lowers each action to a generated contract:

```igniter
contract EDo {
  input s : S
  input c1 : C1
  input c2 : C2
  input x : X
  ...
  output next_s : S
  output result : R
}
```

Rules:

1. The generated contract name is `EntityName + ActionName`.
2. The generated contract receives inputs in this order:
   state, configs in source order, action parameters in source order.
3. Each entity `uses` entry is validated as a typed contract reference and
   recorded as entity desugaring metadata. A future implementation may also copy
   supported `uses` references into generated contracts, but v0 executable
   lowering must not depend on that parser surface.
4. Each entity-local `Behavior(args...)` call lowers to
   `call_contract("Behavior", args...)` only after static resolution against
   the entity `uses` set succeeds.
5. `state = Behavior(...)` requires the behavior output type to be assignable to
   the entity state type `S`.
6. If an action declares `-> R`, it must contain exactly one value output in
   addition to the threaded state output.
7. If an action omits `-> R`, it is state-only and emits only the threaded state
   output.
8. Action-local computes remain ordinary compute declarations.

---

## 6. Static Dispatch

Entity behavior calls are **static**:

- The callee is a source identifier, not a string expression.
- The callee must be listed in the entity `uses` set.
- The `uses` reference must resolve using existing typed contract reference
  rules.
- Dynamic `call_contract(r, ...)` remains blocked.

This preserves the safety outcome from `LAB-DYNAMIC-CONTRACT-DISPATCH-P2`.
Entity actions do not introduce runtime reflection, stringly authority, plugin
lookup, or duck typing.

---

## 7. Modifier and Fragment Inference

There is no explicit `pure entity` / `effect entity` modifier in v0. The entity
modifier is inferred from generated action contracts and their referenced
behaviors.

Inference rules:

1. Generate the action contracts.
2. Classify each generated action using the existing PROP-031 modifier and
   fragment rules.
3. Entity modifier is the least upper bound of generated action modifiers.
4. Entity fragment class is the maximum fragment class of generated actions.
5. TEMPORAL takes precedence over ESCAPE when temporal declarations are present,
   following PROP-028 and PROP-031.

Consequences:

- An entity whose actions are all pure is pure/CORE.
- An entity that calls an effect behavior is effect/ESCAPE.
- An entity that reads temporal state through approved temporal surfaces is
  TEMPORAL.
- Composition itself grants no authority; authority comes only from the member
  contracts already classified by existing rules.

---

## 8. Variants and Polymorphic Behaviors

Entity v0 supports variants only as ordinary typed inputs/outputs:

- An action may output a PROP-044 variant type.
- An action may `match` on a variant using existing exhaustive match rules.
- Behavior selection remains static.

Closed for v0:

- no open behavior registry;
- no runtime strategy string;
- no trait-object dispatch;
- no plugin lookup;
- no implicit union of behavior outputs.

If a future entity needs strategy selection, it must use a closed variant/enum
selector and exhaustive static branches. That is a separate card, not part of
this v0 PROP.

---

## 9. Fold-To-Record Relationship

`LANG-FOLD-STRUCT-ACCUMULATOR-P2` is closed and no longer blocks core entity
authoring.

Entity v0 does not include collection-run syntax. A source form such as:

```igniter
action Run(candles : Collection[Candle]) over candles { ... }
```

is deferred. When fold-to-record P3/P4 land, a later entity extension may define
such syntax by lowering to canonical fold SemanticIR. The core v0 entity
lowering remains ordinary action contracts and does not depend on fold
implementation.

---

## 10. OOF Rules

Entity v0 reserves the `OOF-ENT*` namespace.

| Rule | Condition | Message sketch |
| --- | --- | --- |
| `OOF-ENT1` | duplicate entity name or generated contract name collision | `entity '<name>' conflicts with existing declaration '<name>'` |
| `OOF-ENT2` | missing or duplicate `state` declaration | `entity '<name>' must declare exactly one state binding` |
| `OOF-ENT3` | duplicate config/action/local binding | `entity '<name>' has duplicate member '<member>'` |
| `OOF-ENT4` | unknown state/config/action type | `entity '<name>' references unknown type '<type>'` |
| `OOF-ENT5` | behavior call not listed in `uses` | `entity action '<action>' calls '<behavior>' not declared in uses` |
| `OOF-ENT6` | unresolved behavior reference | `entity '<name>' uses unknown contract '<behavior>'` |
| `OOF-ENT7` | state update returns non-state type | `entity action '<action>' state update expected <S>, got <T>` |
| `OOF-ENT8` | action result missing or mismatched | `entity action '<action>' expected result <R>, got <T>` |
| `OOF-ENT9` | v0 closed-surface violation | `entity '<name>' uses unsupported v0 feature: <feature>` |

Existing rules still apply after desugaring:

- `OOF-REF1` for typed contract reference resolution failures where applicable.
- `OOF-TY1` for output assignability.
- `OOF-M1` for pure contracts that contain escape-class declarations.
- `OOF-KIND*` for variant/match errors.

---

## 11. SemanticIR Shape

P3 planning should choose between two equivalent internal representations:

1. **Desugared-only:** the compiler emits only generated `contract_ir` nodes.
2. **Annotated desugaring:** the compiler emits generated `contract_ir` nodes plus
   an optional top-level `entity_desugarings` metadata block.

This PROP recommends annotated desugaring for auditability:

```json
{
  "entity_desugarings": [
    {
      "entity": "Robot",
      "state": {"name": "portfolio", "type": "Portfolio"},
      "configs": [{"name": "config", "type": "RobotConfig"}],
      "uses": ["CombinedStrategy", "ExecuteSignal"],
      "actions": [
        {
          "name": "ProcessCandle",
          "generated_contract": "RobotProcessCandle"
        }
      ]
    }
  ]
}
```

The metadata is evidence only. Runtime execution uses the generated contracts.

---

## 12. P3 Implementation Readiness

This PROP is ready for a P3 implementation-planning card, not direct code.

Recommended P3 split:

1. Parser/classifier planning for `entity` declarations and `OOF-ENT*`.
2. TypeChecker planning for generated action contract validation.
3. SemanticIR/manifest planning for optional `entity_desugarings`.
4. A proof plan that compiles generated contracts and proves no dynamic dispatch
   widening.

Do not implement parser/compiler changes from this P2 card.

---

## 13. Acceptance Closure

- Does not reuse or redefine `composes`.
- Keeps entity as compile-time sugar over already-compiling pure contracts.
- Preserves static dispatch and dynamic-dispatch fail-closed policy.
- Includes desugaring examples and non-goals.
- Incorporates Fold P2 by excluding collection-run syntax from v0.
- Ends with P3 implementation planning readiness.
