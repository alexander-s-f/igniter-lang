# Igniter — Compact Dev Tutorial

> Status: living document, kept in sync with the **implemented** dual-toolchain
> surface (Ruby canon TC + Rust lab TC). Everything in §1–§9 compiles **dual-clean
> today**. §10 lists proposed/partial surfaces that do NOT yet compile in both
> toolchains — do not use them in apps yet.
> Last verified: 2026-06-14 against `igniter-lang/lib` + `igniter-lab/igniter-compiler`.

Igniter programs are graphs of **pure contracts**. You declare data (`type`),
declare computations (`contract`), wire contracts together by name, and name one
**entry point**. Definition and execution are separate: the compiler builds the
graph; a tool runs the chosen entrypoint.

Worked examples live in `igniter-lab/igniter-apps/` — this tutorial draws from
`trade_robot`, `air_combat`, `lead_router`, `call_router`.

---

## 1. Program shape: module, contract, entrypoint

```igniter
module Hello
import stdlib.collection.{ map }     -- import only the stdlib HOFs you use

pure contract Double {
  input n : Integer
  compute r = n + n
  output r : Integer
}

entrypoint Double                    -- names the program's start contract
```

- `module Name` — one per file; the namespace.
- `contract` — the unit of computation (inputs → computes → outputs).
- `entrypoint Contract` — the source-level "start here" anchor (parsed,
  typechecked, carried into the manifest). It is a **selector**, not a `main`: it
  picks which contract a tool runs. At most one bare entrypoint per program.

**Mental model — the entrypoint is the control surface, not a reorderer.** You
control a program by choosing *which* contract is the entry and *what* you observe;
the internal evaluation order is pure dataflow (dependency-driven), not line order.

---

## 2. Types and records

```igniter
type Vec2 { x : Integer, y : Integer }

type Plane {
  id   : Integer
  team : Integer
  pos  : Vec2          -- records nest
  vel  : Vec2
}
```

Scalars: `Integer`, `String`, `Bool`, `Decimal`. Collections: `Collection[T]`.
There is no float — money/coordinates use **fixed-point Integer** (e.g. scale 100,
`1.00 == 100`); see §6.

A **record literal** `{ x: 1, y: 2 }` infers to the named type whose field set it
matches. ⚠️ See the factory gotcha in §8.

---

## 3. Compute and contract calls

`compute name = expr` binds a value inside a contract body (a node in the graph).
Call another contract by **string literal name** with `call_contract`:

```igniter
pure contract Advance {
  input p : Plane
  compute moved = call_contract("VAdd", p.pos, p.vel)   -- Tier-1 static call
  compute np = {
    id: p.id, team: p.team, pos: moved, vel: p.vel
  }
  output np : Plane
}
```

- The callee must be a **string literal** (Tier 1, statically resolved). A variable
  callee (`call_contract(name, …)`) returns `Unknown` and is fail-closed — see §8.
- Field access: `p.pos.x` (chains).
- `compute` is the body binding (graph node). `let` exists for local bindings
  inside an expression; prefer `compute` for named graph values.

---

## 4. Collections

```igniter
import stdlib.collection.{ map, filter, count, fold }

pure contract AliveCount {
  input planes : Collection[Plane]
  compute living = filter(planes, p -> if p.alive > 0 { true } else { false })
  compute n = count(living)
  output n : Integer
}

pure contract SumX {
  input planes : Collection[Plane]
  compute total = fold(planes, 0, (acc, p) -> acc + p.pos.x)
  output total : Integer
}
```

- `map(coll, x -> …)`, `filter(coll, x -> bool)`, `count(coll)`, `concat(a, b)`,
  `fold(coll, seed, (acc, x) -> acc')`, array literals `[a, b]`.
- `fold` supports scalar accumulators and named-record accumulators **dual-clean**.
  For record accumulators, give the fold result an expected named type through the
  output or a compute annotation:

```igniter
type Stats { sum : Integer, count : Integer }

pure contract Summarize {
  input xs : Collection[Integer]
  compute stats : Stats = fold(xs, { sum: 0, count: 0 },
    (acc, x) -> ({ sum: acc.sum + x, count: acc.count + 1 }))
  output stats : Stats
}
```

Unannotated intermediate record folds can still infer as `Unknown` if you read
fields downstream; annotate the compute or output the fold result as the named
record type.

---

## 5. Variant + match (result types & state machines)

`variant` declares a sum type; `match` dispatches exhaustively. This is the
idiomatic way to write a `Result`/railway or a state machine. **Dual-clean.**

```igniter
variant Pipe {
  Proceed { ctx : Ctx }
  Reject  { stage : String, message : String }
}

pure contract FindVendor {
  input prev : Pipe
  input vendor_found : Integer
  input vendor : Vendor
  compute r = match prev {
    Reject  { stage, message } => Reject { stage: stage, message: message }   -- carry
    Proceed { ctx } => if vendor_found == 1 {
      Proceed { ctx: call_contract("CtxWithVendor", ctx, vendor) }
    } else {
      Reject { stage: "find_vendor", message: "Vendor not found" }
    }
  }
  output r : Pipe
}
```

- Arms are `Pattern { fields } => expr`, newline-separated, `=>` (not `->`).
- Variant **constructors** (`Proceed { … }`) are fine inside `if/else` and match
  arms — unlike plain record literals (§8).
- `_` is a wildcard arm.
- `Option[T]` is **not** a matchable variant; don't `match` on it (§8).
  > **NB (verify-first, 2026-06-16):** both toolchains *currently* typecheck `match` over
  > `Option`/`Result` as sealed built-in variants (proven dual, 109/109). This guidance encodes the
  > canon stance (PROP-044: `or_else` is the idiomatic Option handler); the doc-vs-implementation
  > reconciliation is pending — see `.agents/work/cards/lang/LANG-SUMTYPE-OPTION-RESULT-SURFACE-P1.md`
  > and the proposed `LANG-SUMTYPE-CANON-RECONCILE-P1` gate. Until reconciled, prefer `or_else`.

Patterns: `lead_router` models the whole eligibility railway this way;
`call_router` models the telephony state machine (`NoCall`/`Ringing`/`CallConnected`).

---

## 6. Control flow & fixed-point arithmetic

```igniter
compute trend = if d1 > 0 {
  if d2 > 0 { "GROWING" } else { "RECOVERING" }
} else {
  if d1 == 0 { "STABLE" } else { "DECLINING" }
}
```

- `if cond { … } else { … }` is an **expression**; nest for multi-way.
- No unary minus: write `0 - x`. No `abs`: `if x < 0 { 0 - x } else { x }`.
- Fixed-point multiply/divide keep the scale: `(a * b) / 100` at scale 100.
- No `sqrt` — keep magnitudes squared and compare squared (`air_combat/vec.ig`).

---

## 7. Contract modifiers (effect character)

A contract's modifier declares how much it touches the world. `pure` is the
default; `observed` is dual-clean:

```igniter
pure     contract ScoreRisk { … }     -- deterministic, no IO (default)
observed contract ReadFlag  { … }     -- read-only external observation
```

`effect` / `privileged` / `irreversible` + `capability` + `effect … using …` are
the **IO membrane** — but they are **not dual-clean yet** (Rust pending). See §10.

---

## 8. Gotchas (current dual-clean reality)

1. **Branch/arm record literals infer to `Unknown` in the Rust TC.** An inline
   record built in an `if/else` branch or a `match` arm — or an intermediate
   `compute params = { … }` whose fields you later read — fails Rust with
   `OOF-TY1 …got Unknown` / `OOF-P1 Unresolved field`. **Fix: a factory contract.**
   ```igniter
   pure contract MakeParams {
     input trade : String  input zip : String
     compute p = { trade: trade, zip: zip }
     output p : Params                       -- typed output pins the record type
   }
   ```
   This is the `MakeXxx` pattern across the fleet (`MakeSignal`, `MakePlane`,
   `MakeBehavior`, `MakeParams`).

2. **Record folds need a named-type context.** `fold(xs, {…}, …)` is dual-clean
   when the accumulator is pinned by output or compute annotation. If you bind an
   unannotated intermediate and then read `acc.field` downstream, you may still
   get `Unknown`; annotate the compute.

3. **Dynamic dispatch is blocked.** `call_contract(variable, …)` → `Unknown`,
   fail-closed. Select behaviour by a literal name in `if/else` (static dispatch).

4. **No fuzzy strings.** `concat`, `char_at`, `substring` exist; **no `contains`/
   `ends_with`** — exact equality only for matching.

5. **`first`/`last` are Rust-only and return `Option[T]`**, and `Option` isn't
   matchable — don't rely on them for dual-clean code; inject the picked value.

---

## 9. Putting it together (the shape of an app)

A typical app is: `types.ig` (types + variants) → domain modules (pure contracts
composed by `call_contract`) → an `example.ig` with a root contract + `entrypoint`.
DB reads / clock / RNG are **injected as inputs** — the pure core never does IO.

```
types.ig      → type + variant declarations
*.ig          → pure contracts, composed by call_contract; match for branching
example.ig    → Demo* factories, a Run* root contract, `entrypoint Run*`
```

See `lead_router` (request/reply railway), `call_router` (correlation + state
machine), `air_combat` (tick simulation) as full worked baselines.

---

## 10. Proposed / not yet dual-clean (do NOT use in apps yet)

These are designed/accepted-as-direction but **not implemented in both toolchains**.
Verified non-working on 2026-06-14:

| Surface | Intended syntax | Current state |
|---|---|---|
| **Effect surface** | `effect contract C { capability c: IO.X  effect e using c }` | **Dual-clean for ANY well-formed effect name** (LANG-EFFECT-NAME-PARITY-P2, 2026-06-16 — Rust no longer limits effect names; `e` is a label, not an authority selector). `capability`-binding diagnostics still fire (undeclared/unbound). IO membrane is host-side, not a language primitive. (PROP-031/035) |
| **Profiles** | `profile P { authority: effect }` + `contract C via P { … }` | Rust parser → `OOF-G1` (unknown). Ruby-only. (PROP-033/040) |
| **Rich entrypoint** | `entrypoint plan { contract: C  output: o  args: {…}  default: true }` + named profiles + `section` | Only the **bare** `entrypoint C` is implemented. (PROP-029) |
| **Form vocabulary** | `vocabulary V { submit -> Validate }` + `speaks V` → call as `submit(x)` | Not implemented; substrate `uses ContractName` IS implemented. (LANG-FORM-VOCABULARY) |
| **Composition algebra** | `A >> B`, `A \|\| B`, `embed` | Proposal; compose by `call_contract` today. (PROP-002) |
| **entity / compose** | `entity Robot { state … action … }` | Readiness only; thread state by hand today. (LANG-COMPOSE-ENTITY) |
| **Reactions** | `on <observation/stream> -> Contract` | No proposal yet — genuinely new. |

When any of these lands dual-clean, move it from §10 into the body and add a worked
example. Fold-to-struct moved into §4 after LANG-FOLD-STRUCT-ACCUMULATOR-P3/P4.
