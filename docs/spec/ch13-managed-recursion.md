# Chapter 13: Managed Recursion and Service Loops

Status: proposed
Stage: 4 (deferred)
Source PROP: PROP-039+ placeholder for managed local recursion / loop-class
extensions; PROP-037 owns external progression and service liveness
Governance: META-EXPERT-013
Last updated: 2026-06-08

> **Proposed — Stage 4 deferred.** This chapter describes the managed recursion
> and service loop extension. It is not in scope for Stage 3.
> Status advances when Stage 4 governance opens and an assigned managed-recursion
> PROP passes. Managed local recursion / loop-class extensions route to PROP-039+
> or later. Service-loop liveness maps through PROP-037 progression descriptors.
> PROP-036 is reserved for `compiler_profile_id` manifest identity.

---

## § 13.1 Overview

Every repetition in Igniter-Lang is *managed*: it belongs to one of five loop
classes, each with a compiler-verified termination or liveness contract. There is
no general recursion and no unbounded loop.

```igniter
-- Finite loop: bounded by collection size
for ClaimLoop item in claims {
  FactCheckClaim(item, as_of)
}

-- Structural recursion: variant decreases at every recur() call
-- NOTE: This is an aspirational Stage-4 / v1 form.
--   `decreases items.remaining` — dotted-path variant: fail-closed OOF-R3 in v0.
--   `recur(items: items.tail, ...)` — named args: v1 form; v0 uses positional recur().
--   See §13.3 for the v0-compatible form.
recursive contract SumList(items: Collection[Integer], acc: Integer) -> total: Integer
  decreases items.remaining
{
  match items.head {
    none    => output acc
    some(x) => recur(items: items.tail, acc: acc + x)
  }
}

-- Fuel-bounded: explicit step budget
fuel_bounded contract SearchOptimal(state: SearchState) -> best: Route
  max_steps 10_000
  on_exhaustion :suspend
{
  ...
}

-- Convergent: metric converges toward threshold
loop contract Optimize(params: Params) -> result: Params
  variant loss_function(params)
  convergence epsilon: 0.001
  max_steps 100_000
  on_exhaustion :return_partial
{
  ...
}

-- Service loop: continuous, stoppable, observable
-- Design text only: source syntax is not implemented.
service contract LiveNewsClarityService()
  heartbeat every 10.seconds
  checkpoint every 1.minute
  cancellation required
  max_step_latency 2.seconds
  via audited_truth_mesh
{
  loop TickLoop tick in clock.every(10.seconds) {
    as_of = tick.time
    receipt = RunArticlePipeline(tick.payload.article, as_of)
    write clarity_reports <- receipt.report evidence [receipt]
  }
}
```

---

## § 13.2 The Five Loop Classes

| Class | Termination contract | Compiler verification |
|-------|---------------------|----------------------|
| `FiniteLoop` | Terminates when collection is exhausted | Collection size is finite; proven by type |
| `StructuralRecursion` | Terminates because structural variant strictly decreases | Compiler performs syntactic_v0 decrease check at every `recur()` site: whitelist `variant−N`, `variant.tail`, `variant.rest`; other forms fire OOF-R3 |
| `FuelBoundedRecursion` | Terminates when fuel counter reaches zero | `max_steps` is a static literal |
| `ConvergentLoop` | Terminates when metric reaches threshold or fuel exhausts | `convergent` modifier + `variant`/`convergence epsilon`/`max_steps`/`on_exhaustion` declared. **Implemented Ruby-canon (PROP-050 / LANG-CH13-CONVERGENT-LOOP-P46).** Termination is guaranteed by `max_steps` (fuel); the compiler does NOT prove convergence. |
| `ServiceLoop` | Does not terminate by design; must be stoppable, observable, and bounded per step | **v0 declaration slice implemented (PROP-037 annex / P50):** `service` modifier + `heartbeat`/`cancellation`/`max_step_latency` obligations checked for **declaration presence** (OOF-SL1/2/3). Actual liveness (heartbeat arrives, step within budget) is RUNTIME — **HELD** (OOF-SL10+, PROP-037 + lab machine). Declaring the obligations grants no liveness. |

`FiniteLoop`, `StructuralRecursion`, `FuelBoundedRecursion` (PROP-039) and now
`ConvergentLoop` (PROP-050/P46) are implemented managed-local-repetition classes.
`ServiceLoop` is a service-liveness surface whose source binding and descriptor
obligations are governed by PROP-037 companion wording — still deferred
(Stage-4). Spelling note: the aspirational `loop contract` header in §13.1 is
realised as the **`convergent` contract modifier** (`convergent` sits alongside
`recursive`/`fuel_bounded`; `loop` stays a body keyword).

---

## § 13.3 `recur()` Combinator

`recur()` is not a self-call. It is a compiler primitive for structural and
fuel-bounded recursion:

```igniter
-- v0 form: simple identifier decreases variant, positional recur() args
recursive contract SumList {
  input items: Collection[Integer]
  input acc: Integer
  output total: Integer
  decreases items        -- simple identifier; dotted-path (e.g. items.remaining) is OOF-R3 in v0
  max_steps 10000
  compute total = recur(items.tail, acc + 1)   -- v0: positional args; named args are v1
}
```

> **v0 syntactic decrease check (OOF-R3 gate, experiment-pass 2026-06-08):**
> The compiler verifies at every `recur()` call site that the variant-position
> argument syntactically decreases the declared `decreases` variant.
> Accepted patterns: `variant - N` (N > 0), `variant.tail`, `variant.rest`.
> All other forms fire OOF-R3 (error). Dotted-path `decreases` variants such as
> `decreases items.remaining` are fail-closed — they fire OOF-R3 immediately
> as an unsupported variant form in v0. The broader aspirational form (arbitrary
> structural variant, SMT proof, named `recur()` args) remains Stage 4 design work.

A `recur()` outside a `recursive` or `fuel_bounded` context is OOF-R1
(experiment-pass — recursive_body_proof 100/100 PASS).

For fuel-bounded recursion, `decreases fuel` is the accepted shorthand:
the fuel counter is compiler-managed, not a named input variant. `fuel_bounded`
contracts and `recursive + decreases fuel` contracts are exempt from OOF-R3.
Static `max_steps` is required for both (OOF-R4 fires if absent).

---

## § 13.4 Service Loop Obligations

A service loop must satisfy three compiler-checked obligations:

1. **Stoppable**: `cancellation required` — the loop handles a cancellation signal
   and terminates gracefully.

2. **Observable**: `heartbeat every N.duration` — the loop emits a heartbeat signal
   within each heartbeat window. A step that blocks the heartbeat will be
   OOF-SL* (PROP-037 territory; deferred — see §13.7 migration note).

3. **Bounded per step**: `max_step_latency N.duration` — each iteration must
   complete within the latency budget. A step that provably exceeds the budget
   will be OOF-SL* (PROP-037 territory; deferred — see §13.7 migration note).

Service loops do not have a termination proof. Instead, they are governed by
liveness theory: the loop is alive as long as heartbeat signals arrive.

> **v0 declaration slice (PROP-037 annex / LANG-CH13-SERVICE-LOOP-P50, Ruby-canon;
> Stage-4 lane opened 2026-07-08).** The compiler checks that a `service` contract
> **declares** its three obligations — missing `heartbeat` ⇒ **OOF-SL1**, missing
> `cancellation` ⇒ **OOF-SL2**, missing `max_step_latency` ⇒ **OOF-SL3** (hard).
> `checkpoint every N` is optional in v0. **A passing check grants NO runtime
> liveness** — the "step blocks heartbeat / exceeds latency" conditions above are
> RUNTIME (OOF-SL10+), HELD to PROP-037 + the lab machine
> (`igniter-machine/src/service_loop.rs`); declaration is not enforcement (the
> same boundary as ch12 authority declaration-vs-enforcement). Timer binding
> (§13.5) and `write ... evidence` (§13.6) remain HELD. `loop: service` (ch11)
> now enforces the class.

---

## § 13.5 Timer-Driven Progression Source Binding

A service loop may bind a timer source through a PROP-037 progression descriptor:

```igniter
loop TickLoop tick in clock.every(250.ms)
  max_steps 1_000_000
  on_exhaustion :suspend
{
  as_of = tick.time
  ...
}
```

`clock.every(N.duration)` is a progression `source_kind` / source binding for
service liveness. It is not semantically equivalent to `Stream[DateTime]`, and
it does not weaken PROP-023 `fold_stream` / window OOF rules.

`tick.time` is explicit event-time binding from the materialized progression
event. It is not ambient time. Source-level `now()` remains prohibited; use an
explicit TemporalCtx-style input or event-time binding such as `tick.time`.

---

## § 13.6 `write store <- value evidence [refs]`

Inside a service loop body, a contract may append a value to a temporal store:

```igniter
write clarity_reports <- receipt.report
  evidence [receipt]
```

This is an effect statement, not an output declaration. The `evidence` clause is
mandatory and names the receipts or observations that justify the write. The
append is `lifecycle: :audit` by default.

> **v0 compile slice implemented (LANG-CH13-WRITE-EVIDENCE-P60, dual-toolchain).**
> `write <store> <- <value> evidence [refs]` parses (the `<-` append operator) as a
> body statement; the compiler checks: the mandatory `evidence` clause is present
> (missing ⇒ **OOF-W1**), every evidence ref resolves to a declared local symbol
> (unresolved ⇒ **OOF-W2**), and the placement is legal — `write` is a mutation
> effect, valid only in `effect`/`privileged`/`irreversible`/`service` contracts
> (`pure`/`observed` ⇒ **OOF-W3**). The value is typed via normal inference.
> **Declaration only — a passing `write` grants no runtime write**: the actual
> append to a temporal store and the `lifecycle: :audit` map to the machine
> runtime (`igniter-machine/src/write.rs`, the P16–P20 write/audit line) and stay
> **HELD**. Also HELD: store-as-declared-`stream` resolution, `affects`/
> `allowed_effects` registration of the write target, and the strict "only inside
> a `clock.every` loop body" placement (needs §13.5).

---

## § 13.7 OOF Rules

**Updated: PROP-039 OOF-R3 gate (2026-06-08)**

### Managed Local Recursion (PROP-039 authority)

All OOF-R1..R7 codes are PROP-039 canon experiment-pass compiler surface.

| Code | Condition | Severity | Status |
|------|-----------|----------|--------|
| OOF-R1 | `recur()` outside `recursive` or `fuel_bounded` context (incl. regular contract, loop body) | error | **experiment-pass** — typechecker.rb; recursive_body_proof 100/100 |
| OOF-R2 | `recursive` contract missing a `decreases` declaration | error | **experiment-pass** — classifier.rb; loop_typechecker_proof 49/49 |
| OOF-R3 | Variant-position arg does not syntactically decrease declared variant; also fires when `decreases` variant is a dotted-path (fail-closed in v0) | error | **experiment-pass** — syntactic_v0; typechecker.rb; oof_r3_syntactic_variant_decrease_proof 33/33 |
| OOF-R4 | `fuel_bounded` (or `recursive + decreases fuel`) missing static `max_steps` | error | **experiment-pass** — classifier.rb; loop_typechecker_proof 49/49 |
| OOF-R5 | `recur()` arity mismatch — arg count does not match input count | error | **experiment-pass** — typechecker.rb; recursive_body_proof 100/100 |
| OOF-R6 | `recur()` argument type mismatch — arg type does not match corresponding input type | error | **experiment-pass** — typechecker.rb; recursive_body_proof 100/100 |
| OOF-R7 | `recur()` return type unavailable or ambiguous — contract does not have exactly one output | error | **experiment-pass** — typechecker.rb; recursive_body_proof 100/100 |

> Cross-reference: since LANG-CONTRACT-SINGLE-OUTPUT-LAW-P2 (2026-07-13), ANY
> contract with two or more outputs is already refused at declaration by
> `OOF-RET1` (Ch2 single-output law). `OOF-R7` remains the recur-semantics
> rule and keeps its own behavior and tests; on a multi-output recursive
> contract both refusals may appear — R7 owns the `recur()` return-type
> question, OUT1 owns the declaration shape.

### ConvergentLoop (PROP-050 / LANG-CH13-CONVERGENT-LOOP-P46)

A `convergent` contract must declare four obligations; each missing one is a hard
error. **Termination is guaranteed by `max_steps` (fuel) — the compiler does not
prove convergence** (undecidable); `variant`/`convergence`/`on_exhaustion`
declare intent and exhaustion behaviour.

| Code | Condition | Severity | Status |
|------|-----------|----------|--------|
| OOF-R12 | `convergent` contract missing a `variant <metric>` clause | error | **experiment-pass** — classifier.rb; convergent_loop_proof 19/19 |
| OOF-R13 | `convergent` contract missing `convergence epsilon: <n>` (or a non-numeric epsilon) | error | **experiment-pass** — classifier.rb/parser.rb |
| OOF-R14 | `convergent` contract missing `on_exhaustion :<action>` (or an unknown action) | error | **experiment-pass** — classifier.rb/parser.rb |

Missing `max_steps` reuses **OOF-R4** (its "loop class requiring a static
max_steps" condition). `convergent` is recur-authorized (like `fuel_bounded`);
it has no `decreases`, so OOF-R3 does not apply. v0 actions: `:return_partial`,
`:suspend`. `loop: convergent` (ch11) now enforces the class.

> **Code-numbering correction (P46):** OOF-R8..R11 are **NOT** free — they are
> taken by PROP-041 (structural size-relations: R8 missing relation, R9
> mismatch) and PROP-042 (numeric measures: R10 unknown measure fn, R11
> call-site check). The "OOF-R1..R7 owned by PROP-039" framing below predates
> those allocations; ConvergentLoop therefore uses fresh **OOF-R12/R13/R14**.

OOF-R1..R7 are managed local recursion codes owned by PROP-039.
OOF-R3 scope: `recursive` contracts with named (non-fuel) `decreases` variant only;
`fuel_bounded` and `recursive + decreases fuel` are exempt.
Full termination proof, SMT verification, and dotted-path variant support remain
Stage 4 design work — not claimed by the syntactic_v0 gate.

### Service Loop Obligations (`OOF-SL*`)

The `OOF-SL*` namespace splits **compile-time declaration** (low numbers, live
via the P50 v0 slice) from **runtime liveness** (SL10+, HELD, PROP-037). The two
never collide.

**Compile-time — declaration presence (PROP-037 annex / P50, experiment-pass):**

| Code | Condition | Severity | Status |
|------|-----------|----------|--------|
| OOF-SL1 | `service` contract missing a `heartbeat every <dur>` obligation | error | **experiment-pass** — classifier.rb; service_loop_proof 18/18 |
| OOF-SL2 | `service` contract missing `cancellation <mode>` (or a malformed mode) | error | **experiment-pass** — classifier.rb/parser.rb |
| OOF-SL3 | `service` contract missing a `max_step_latency <dur>` obligation | error | **experiment-pass** — classifier.rb |

`checkpoint every <dur>` is optional in v0. A passing check grants NO runtime
liveness. `OOF-SL4` is reserved for a future required-checkpoint decision.

**Runtime — liveness (HELD; PROP-037 + lab machine; SL10+ reserved):**

| Reserved code | Condition | Home |
|---------------|-----------|------|
| OOF-SL10 | Service loop step blocks heartbeat window | PROP-037 runtime |
| OOF-SL11 | Service loop step exceeds `max_step_latency` | PROP-037 runtime |
| OOF-SL12 | `on_exhaustion: :suspend` without suspension point | PROP-037 runtime |

### Local Loop (PROP-039 OOF-L*)

| Code | Condition | Severity | Status |
|------|-----------|----------|--------|
| OOF-L1 | `for_loop` source is not `Collection[T]` | error | **experiment-pass** — typechecker.rb; loop_typechecker_proof 49/49 |
| OOF-L2 | `max_steps` is dynamic where v0 requires static literal | error | candidate |
| OOF-L3 | Semantic loop block is unnamed (Postulate 28) | error | candidate |
| OOF-L4 | `break` in a PROP-039 v0 loop | error | candidate |
| OOF-L5 | Unsupported loop body form (nested loop at body level, non-literal `lead` initial, `lead` at contract level, undefined compute target) | error | **experiment-pass** — typechecker.rb; loop_body_semantics_proof 100/100 |
| OOF-L7 | Loop body compute targets loop item variable or outer contract symbol (read-only violation) | error | **experiment-pass** — typechecker.rb; loop_body_semantics_proof 100/100 |
| OOF-L8 | `lead` binding shadows outer contract symbol or loop item variable | error | **experiment-pass** — typechecker.rb; loop_body_semantics_proof 100/100 |

OOF-L6 is Ch8 authority (ambient-clock / `now()` refusal). PROP-039 does not
own or modify OOF-L6.

OOF-L2/L3/L4 remain candidates. Source-level `break` is deferred. Future proof
fixtures must include unnamed-loop robustness for Postulate 28 (the R246/R247
`OOF-L3` pressure item), but enforcement is not yet proven.

---

## § 13.8 Relationship to Other Chapters

- **Ch11 (Profile System):** the `loop`, `heartbeat`, `checkpoint`, `cancellation`,
  and `max_step_latency` profile properties bind to the service loop obligations
  defined here.
- **Ch10 (Contract Modifiers):** service loops are declared with the `service`
  keyword. **v0 (P50) realises `service` as a contract modifier** (alongside
  `recursive`/`fuel_bounded`/`convergent`) for parser-parity — the original
  "syntactically distinct form" intent is deferred; the structural differences
  (no output, timer-bound body) live in the HELD parts (§13.5/§13.6), not the v0
  declaration slice.
- **Ch9 (Stage 2 Reserved):** `fold_stream @window_bounded` and `fold_stream
  @count_bounded(n)` are stream/window bounded folds, not arbitrary managed
  local loops. They remain separate from PROP-039+ local loop/recursion work.
- **PROP-037:** service-loop source binding maps to progression descriptors,
  including `clock.every` source kind, materialization, receipts, cancellation,
  checkpoint, and backpressure obligations. PROP-037 does not authorize parser,
  runtime, scheduler, or a `PROGRESSION` fragment class.
