# LANG-FOLD-STRUCT-ACCUMULATOR-P1: Readiness

**Status:** CLOSED -- readiness proved -- 62/62 PASS
**Date:** 2026-06-14
**Route:** LANG / stdlib.collection.fold / record accumulators
**Authority:** proposal/readiness only; no implementation
**Proof:** `experiments/fold_struct_accumulator_proof/verify_fold_struct_accumulator_p1.rb`

---

## Goal

Determine whether Igniter should support record/struct accumulators in
`fold(Collection[T], Acc, (Acc,T)->Acc)`, and identify the smallest safe next
route.

This is not `group_by`, `join`, `flat_map`, `scan`, or relational algebra. The
shape under review is still ordinary left fold with one accumulator value.

---

## Verdict

**Route: P2 implementation planning.**

Record accumulators should be supported, but **not by direct implementation from
this card**. Current behavior is mixed:

- Ruby TypeChecker already supports typed record accumulators when the lambda
  returns a parenthesized record expression.
- Rust TypeChecker supports record accumulators only when the seed is annotated
  or otherwise known; inline record seeds remain `Unknown`.
- Rust does not currently validate fold lambda return type against `Acc`.
- Ruby SemanticIR lowering has no fold-specific pipeline lowering; Rust emitter
  already lowers fold pipeline nodes.

Therefore P2 should plan **Rust TC parity plus Ruby/Rust lowering parity**, not a
Ruby-only TypeChecker patch.

---

## Evidence Summary

Proof runner: `verify_fold_struct_accumulator_p1.rb` -- 62/62 PASS.

| Section | Checks | Finding |
| --- | ---: | --- |
| A | 10 | Ruby TC has strict fold typing; Rust fold returns seed type; Ruby emitter caveat found |
| B | 7 | Existing scalar fold behavior is protected |
| C | 11 | Ruby record accumulator works with parenthesized record lambda and catches bad fields |
| D | 7 | Rust inline record seed fails; annotated seed works; lambda return validation missing |
| E | 10 | trade_robot pressure is real and current baseline remains clean |
| F | 5 | No group_by/join/relational expansion is needed |
| G | 7 | Next route is P2 planning, not reject/hold/direct implementation |
| H | 5 | Closure guards |

---

## Answers

### Q1. Does current `fold` reject record accumulator types?

No, not universally.

Ruby accepts record `Acc`:

```igniter
compute stats = fold(xs, { sum: 0, count: 0 },
  (acc, x) -> ({ sum: acc.sum + x, count: acc.count + 1 })
)
output stats : Stats
```

Rust accepts record `Acc` if the seed is annotated:

```igniter
compute seed : Stats = { sum: 0, count: 0 }
compute stats = fold(xs, seed,
  (acc, x) -> ({ sum: acc.sum + x, count: acc.count + 1 })
)
output stats : Stats
```

The pressure is **inference and parity**, not a semantic rejection of record
accumulators.

### Q2. Can `fold(Collection[T], Acc, (Acc,T)->Acc)` already typecheck for record `Acc`?

Ruby: yes, with parenthesized record lambda expression.

Rust: partly. Annotated seed compiles. Inline record seed fails with:

```text
OOF-TY1: Output type mismatch: expected Stats, got Unknown
```

### Q3. If it fails, where is the gap?

Current gaps:

1. **Rust seed inference:** inline record literal seed remains `Unknown` inside
   `fold`; Rust fold currently returns `typed_args[1].resolved_type`.
2. **Rust lambda validation:** Rust accepts bad lambda returns such as
   `(acc, x) -> "bad"` and bad record fields without OOF.
3. **Ruby lambda syntax ergonomics:** `-> { sum: ... }` is parsed as a block,
   not a record literal expression. The safe current syntax is `-> ({ sum: ... })`.
4. **Lowering parity:** Rust emitter has fold pipeline lowering; Ruby emitter
   has no fold-specific pipeline node and uses generic call lowering.

### Q4. What trade_robot manual unroll could become a fold?

`RunBacktest` currently threads:

```igniter
compute p1  = call_contract("BacktestTick", p0,  candles, c1,  config)
...
compute p10 = call_contract("BacktestTick", p9,  candles, c10, config)
```

The desired shape is:

```igniter
compute p10 = fold(candles, p0,
  (portfolio, candle) -> call_contract("BacktestTick", portfolio, candles, candle, config)
)
```

`BacktestTick` already returns `Portfolio`, so this is a direct record
accumulator use case, not dynamic dispatch or relational aggregation.

### Q5. Does this require nested record literal typing P1 first?

For the Ruby record-lambda form, yes in practice. The typed lambda body relies on
record literal inference under contextual node names. After
`LAB-NESTED-RECORD-LITERAL-TYPING-P1`, Ruby catches bad nested field values
precisely and does not silently leak outer hints.

The Rust gaps remain independent of that Ruby fix.

### Q6. What regression protects scalar fold behavior?

The proof includes:

- Ruby scalar fold clean: `fold(xs, 0, (acc, x) -> acc + x)`.
- Ruby bad scalar lambda emits `OOF-COL4`.
- Rust scalar fold compiles cleanly.
- Source guards for existing scalar fold sites in `trade_robot` and
  `sim_framework`.

### Q7. Is P2 likely Ruby-only, dual-toolchain, or proposal-only?

P2 should be **implementation planning** and should cover both toolchains. It is
not Ruby-only:

- Ruby TC is already mostly sufficient.
- Rust TC needs record seed inference and lambda return validation.
- Lowering parity needs explicit design because Ruby and Rust emitters differ.

---

## P2 Planning Targets

P2 should answer and plan:

1. Rust TC: should `fold` infer inline record seed via output context, structural
   candidate matching, or annotated seed only?
2. Rust TC: how to bind `acc` and `elem` in fold lambda and validate body type
   equals `Acc`, with Unknown permissive behavior matching Ruby.
3. Ruby/Rust lowering: whether canonical fold should remain generic call in
   Ruby or gain explicit fold pipeline lowering to match Rust.
4. Syntax guidance: whether `-> ({ ... })` is accepted as the v0 record-returning
   lambda spelling, or whether parser ergonomics should be improved later.
5. trade_robot route: no app migration in P2; use a minimal fixture modeled on
   `BacktestTick` and `Portfolio`.

---

## Closed Surfaces

- No `group_by`, `join`, `flat_map`, `scan`, `zip`, or relational algebra.
- No parser syntax change in P1.
- No app source migration.
- No runtime authority, IO, broker, exchange, market-data, DB, SQL, ORM, or Rack.
- No dynamic dispatch.
- No temporal history implementation.

---

## Closure

`LANG-FOLD-STRUCT-ACCUMULATOR-P1` is closed as readiness proved. The next safe
route is `LANG-FOLD-STRUCT-ACCUMULATOR-P2` implementation planning.
