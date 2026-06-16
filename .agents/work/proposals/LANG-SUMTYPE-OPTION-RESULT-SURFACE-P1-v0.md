# Sum types · Option · Result — current surface map (LANG-SUMTYPE-OPTION-RESULT-SURFACE-P1, v0)

**Lane:** readiness / language-canon / anti-drift · **Repo:** igniter-lang (canon) primary, igniter-lab evidence
**Scope:** front-door surface map. **No compiler/VM changes, no app migration, no dynamic dispatch, no Unknown policy.**

> **Authority & verify-first.** Every row below was checked against **live code + live toolchain runs
> on 2026-06-16**, not cards. Dual proofs were re-run: `verify_sumtype_construct_match_p3.rb` →
> **109/109**, `verify_sumtype_collect_p3.rb` → **95/95**. Individual snippets were compiled through
> the **real Rust binary** (`igniter-compiler/target/release/igniter_compiler`) and the Ruby TC
> (`lib/igniter_lang/typechecker.rb`). Where canon **docs** disagree with the live toolchains, this
> map flags it as **drift** (§7) and routes it — it does **not** silently change canon stance.

---

## 1. Executive summary

- **User `variant` + `match`** and **sealed built-in `Option`/`Result` construct + match** are
  **fully implemented and dual-clean** (Ruby canon TC + Rust lab TC, in lockstep, byte-parity SIR).
- Constructors **`some` `none` `ok` `err`** exist dual; helpers **`unwrap_or` `or_else` `and_then`
  `flat_map` `filter_map`** exist dual; **`map` is Collection-only** on both sides; **`collect` is
  absent** on both sides.
- The runtime **runs** it: `lead_router` (railway over a user variant) and `batch_importer`
  (`filter_map` + `some`/`none`) are dual-clean apps that execute through the VM (machine fleet sweep).
- **Canon docs lag the implementation.** PROP-044 still marks `variant`/`match` as *deferred design*,
  and `dev-tutorial.md:165` says `Option[T]` is *not matchable* — both **contradicted by live code**.
  Four such drifts are listed in §7 and routed to a canon-reconciliation gate (§9).

---

## 2. The matrix (verified live)

Status legend: ✅ implemented & clean · ❌ rejected/absent (fail-closed) · ⚠️ design/doc-only.
RB = `lib/igniter_lang/typechecker.rb`; RS = `igniter-compiler/src/typechecker.rs` (+ `typechecker/stdlib_calls.rs`).

| Feature | Canon (docs) | Ruby TC | Rust TC | SIR node | VM / runtime |
|---|---|---|---|---|---|
| `Option[T]` type | ✅ Stage-1 built-in (ch3:20,37) | ✅ sealed registry RB:113 | ✅ `sealed_builtin` RS:306 | (type) | runs |
| `Result[T,E]` type | ✅ Stage-1 built-in (ch3:21,37) | ✅ RB:113 | ✅ RS:306 | (type) | runs |
| `some` `none` `ok` `err` | ✅ stdlib (ch8:75–97) | ✅ RB:125, infer_sealed_construct:3358 | ✅ RS:306, infer_sealed_construct:3790/3812–3829 | `variant_construct` (`sealed:true`) | runs (batch_importer `some`/`none`) |
| user `variant` decl + construct | ⚠️ **design only** (PROP-044, deferred) | ✅ RB:256, infer_variant_construct:3590 | ✅ RS:infer_variant_construct:3858 | `variant_construct` / `variant_decl` | runs (lead_router `Pipe`) |
| `match` over user variant | ⚠️ **design only** (PROP-044) | ✅ RB:infer_match_expr:3642 | ✅ RS:infer_match_expr:3961 | `match_node` | runs (lead_router ×8) |
| `match` over `Option`/`Result` | ⚠️ **docs say NOT matchable** (dev-tut:165) | ✅ sealed RB:277,284 | ✅ sealed RS:4007 | `match_node` (`sealed:true`) | runs |
| match-arm param unification | — | ✅ RB:unify:3790, join:3824 | ✅ RS:unify:4146, join:4203 | — | runs |
| `unwrap_or` | ✅ stdlib (ch8:96) | ✅ RB:infer_unwrap_or:3405 | ✅ RS:stdlib_calls:418 | `call` | — |
| `or_else` | ✅ stdlib (ch8:81) | ✅ RB:infer_or_else:3331 | ✅ RS:stdlib_calls:418 | `call` | — |
| `and_then` | ❌ **not in canon** | ✅ RB:infer_and_then:3432 | ✅ RS:stdlib_calls:774 | `call` | — |
| `flat_map` | ✅ stdlib (ch8:83) | ✅ (canon stdlib) | ✅ RS:stdlib_calls:774 | `call` | — |
| `filter_map` | ⚠️ **Collection only** (canon) | ✅ RB:infer_filter_map:2747 | ✅ RS:stdlib_calls:549 | `call` `stdlib.collection.filter_map` | runs (batch_importer) |
| `map` (Collection) | ✅ stdlib (ch8:54) | ✅ RB:2660 | ✅ RS | `call` `stdlib.collection.map` | runs |
| `map` (Option/Result) | ✅ **documented** (ch8:82,95) | ❌ **OOF-COL2** RB:2679 | ❌ **OOF-COL2** RS:163 | — | — (fails closed) |
| `collect` | ❌ not canon | ❌ OOF-TY0 (unknown fn) | ❌ | — | — |

Dual-clean proofs: construct+match **109/109**, collect **95/95** (re-run 2026-06-16).

---

## 3. Separated by type family

### Option[T]
- **Built-in canon type** (Stage 1). Constructors `some(v)`, `none()` (dual). `none()` recovers its
  param from the expected-type hint, else `Unknown` (fail-closed, dual).
- Helpers: `unwrap_or`, `or_else`, `flat_map` (dual). `map(Option,…)` is **not** implemented (§4).
- **Matchable today** (dual): `match o : Option[Integer] { Some{value}=>… None{}=>… }` typechecks
  clean on both toolchains — **despite the canon doc claiming it is not** (§7-b).

### Result[T,E]
- **Built-in canon type** (Stage 1). Constructors `ok(v)`, `err(e)` (dual). Payload labels sealed to
  `value`/`error`.
- Helpers: `unwrap_or`, `and_then` (fixed-E family), `flat_map` (dual). `map(Result,…)` **not**
  implemented (§4). Matchable today (dual): `Ok{value}` / `Err{error}`.
- `and_then` lambda form: `and_then(o, (x) -> ok(x))` (parens-lambda accepted by both).

### User variants
- `variant V { A { x : Integer } B { } }` + `match v { A{x}=>… B{}=>… }` — fully dual-clean,
  exhaustiveness + arm checks (OOF-KIND1–5). Construction is **function/record-arm form**; the
  sealed `Some{…}` record-construct form is rejected (OOF-KIND2) — constructors are the function form.
- SIR keeps user-variant nodes **byte-identical**; the `sealed:true` marker is added **only** for
  built-in Option/Result, so user variants and built-ins share machinery without perturbing parity.

---

## 4. `map(Result, …)` collision — RESOLVED BY OMISSION (explicit, per acceptance)

Canon ch8 documents **both** `map(Collection[T],…)` and `map(Result[T,E],…)`/`map(Option[T],…)`.
The **implementation ships only Collection `map`.** Both toolchains gate `map`'s first argument to
`Collection`/`Unknown` and **fail closed** on Option/Result:

```
map(o : Result[Integer,String], (x) -> x)
  Ruby → OOF-COL2  "stdlib.collection.map: first argument must be Collection[T], got Result"
  Rust → OOF-COL2  (identical) + OOF-TY1 output mismatch
```

So there is **no runtime name collision** — Result/Option mapping simply isn't a surface. The
canon-documented `map` on Option/Result is **unimplemented**. Use `and_then`/`flat_map` (dual) or a
hand-written `match` instead. (Canon should either implement it or strike it from ch8 — §7-d.)

---

## 5. SIR + VM

- **Emitters (both)** produce: `variant_construct` (with conditional `sealed` marker),
  `match_node` (renamed from parse `match_expr`; carries `subject_type`, `arms`, `exhaustive`,
  `has_wildcard`, conditional `sealed`), `variant_decl` (user variants only). Helpers emit plain
  `call` nodes (`stdlib.collection.*` qualified for `map`/`filter_map`; bare for `and_then`/`unwrap_or`).
- **VM**: variant construction + `match` + `filter_map` + `some`/`none` **execute at runtime** —
  evidenced by the machine fleet sweep (lead_router railway + batch_importer filter_map are inside
  the 13/13 machine↔CLI parity sweep, igniter-lab `igniter-machine/IMPLEMENTED_SURFACE.md`).
- (The lab-only `function_ir` SIR node is a *different* track — app-local `def` functions — not the
  sum-type emitter. Don't conflate.)

---

## 6. App pressures (evidence, igniter-lab)

| App | Pattern | Dual-clean | Pressure / blocker |
|---|---|---|---|
| **lead_router** | railway over user variant `Pipe { Proceed{ctx} / Reject{stage,message} }`; 8 steps each `match prev { Reject=>carry; Proceed=>work }` | ✅ Rust ok/0, Ruby ok/0 | **LR-P01**: no `bind`/`and_then` over a *user* variant → every step re-implements the same match by hand. Highest-leverage unlock. |
| **batch_importer** | `filter_map(results, r -> match r { Valid{record}=>some(record) Invalid{}=>none() })` | ✅ Rust ok/0, Ruby ok/0 | BI-P01 **resolved** by COLLECT-P3. BI-P04 (uses user `RowResult` not built-in `Result`) = separate gated migration. |
| **rule_engine** | `map(rules, r -> call_contract(r, t))` dynamic string callee → `Unknown` | ❌ Rust oof/2, Ruby oof/2 | **Intentional fail-closed** (`Unknown.action` OOF-P1; output OOF-TY1). `LAB-DYNAMIC-CONTRACT-DISPATCH-P2` = DEFER. **Out of scope here** (closed surface). |

`ok`/`err` constructors exist dual but are **not yet exercised by any of these apps** (Result is used
via user variants today, not the built-in).

---

## 7. Drift findings (canon docs vs live code) — ROUTED, not decided here

a. **Implementation is AHEAD of canon on `variant` + `match`.** PROP-044 marks them *grammar-design,
   deferred to Stage 2+* with OOF-KIND codes "reserved, not active" — but **both toolchains fully
   implement** them, the OOF-KIND codes **fire live**, and `lead_router` ships a production railway on
   them. Canon spec is **stale relative to the shipped implementation**.

b. **`dev-tutorial.md:165` is factually wrong vs live.** It states: *"`Option[T]` is **not** a
   matchable variant; don't `match` on it (§8)."* Live: `match` over `Option`/`Result` typechecks
   clean on **both** toolchains (proof B-02/B-04). This is not merely stale — it encodes a canon
   **stance** (PROP-044: "or_else remains the idiomatic Option handler") that the implementation
   overtook. **Reconciliation is a canon decision, not a doc typo** → §9.

c. **`and_then` is implemented dual but absent from canon vocabulary.** Either adopt it into canon
   stdlib (ch8) or mark it an explicit lab extension.

d. **`map(Option/Result)` is documented in canon (ch8) but unimplemented** (both fail-closed). Canon
   overstates the surface — implement or strike.

> Per IDD (Authority ≠ evidence): live code proves *capability*, not *authorization to change canon
> stance*. This map **surfaces** a–d; it does **not** edit canon docs or flip PROP-044. The
> `dev-tutorial` correction (b) is **left for the owner** — see §9 and the card's note.

---

## 8. What is canon vocabulary vs lab stdlib convenience

| Canon (own it) | Lab/impl convenience (reconcile) |
|---|---|
| `Option[T]`, `Result[T,E]` types (ch3) | `and_then` (dual-impl, not in canon) — §7-c |
| `some`/`none`/`ok`/`err`, `unwrap_or`, `or_else`, `map`(coll), `flat_map`, `filter_map` (ch8) | sealed `Option`/`Result` **match** (impl ahead of PROP-044) — §7-a/b |
| `match` + `variant` **design** (PROP-044, deferred) | — |
| denial-as-data convention (`kind:String`) — PROP-044-P1 | `map(Option/Result)` documented-but-absent — §7-d |

---

## 9. Next narrow card(s)

**Implementation (one, narrow):** `LANG-RAILWAY-BIND-OVER-VARIANT-P1` — let `and_then`/`bind` apply
over a **user** 2-arm variant (or a blessed `Outcome`/built-in `Result`), collapsing lead_router's 8
hand-written `match prev { Reject=>carry; Proceed=>… }` steps (LR-P01). Dual-toolchain, no new
runtime primitive (lowers to the existing match). **Named here, not implemented** (closed surface).

**Canon reconciliation (gate, not code):** `LANG-SUMTYPE-CANON-RECONCILE-P1` — a canon gate decision
to (1) promote PROP-044 `variant`+`match` from *deferred* to *accepted* to match the shipped dual
implementation; (2) settle the `Option`/`Result` **match** stance and correct `dev-tutorial.md:165`;
(3) decide `and_then` canon adoption; (4) implement-or-strike `map(Option/Result)` from ch8. Owner =
canon authority (Alex), not an agent.

---

## Boundary recap

- Verify-first via live Ruby/Rust snippets + re-run dual proofs (109/109, 95/95); cards used only as leads.
- Full matrix across canon / Ruby TC / Rust TC / SIR / VM; Option, Result, user variants separated.
- `map(Result,…)` collision explicitly addressed: documented in canon, **unimplemented** both sides,
  fails closed — no real collision.
- No constructors/helpers implemented; no compiler/VM change; dynamic-dispatch/Unknown left closed.
- Canon-vs-impl drift surfaced and **routed**, not unilaterally resolved.

*Surface/readiness map. Stale docs cannot override live code. Compiled 2026-06-16.*
