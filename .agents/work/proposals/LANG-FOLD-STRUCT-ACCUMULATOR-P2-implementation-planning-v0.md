# LANG-FOLD-STRUCT-ACCUMULATOR-P2 — Implementation Planning

**Status:** CLOSED — PLAN PROVED 64/64 — ROUTE: P3 (Rust TC) → P4 (lowering parity)
**Track:** lang / planning / fold record accumulator
**Date:** 2026-06-14
**Authority:** implementation planning only — no production code changes
**Card:** LANG-FOLD-STRUCT-ACCUMULATOR-P2
**Gate:** LANG-FOLD-STRUCT-ACCUMULATOR-P1 (62/62) · LAB-NESTED-RECORD-LITERAL-TYPING-P1 · LANG-TEMPORAL-STATE-P1 — all CLOSED

---

## 0. TL;DR

Record/struct accumulators in `fold` are **not semantically banned** (P1). The gap
is a precise cluster, and the plan splits cleanly into two bounded cards:

- **P3 — Rust TC lift** (the real work): contextualize the record **seed**, **bind +
  validate** the lambda return against `Acc`, and add **OOF-COL4** arity/collection
  parity — all at the `"fold" =>` arm in `typechecker.rs`.
- **P4 — lowering parity**: give the **Ruby emitter** a canonical fold node matching
  Rust's structured `{kind:"fold", param_acc, param_val, init, body}`; optionally
  harden the Ruby TC body-vs-`Acc` check from name-only to structural.

**Canonical SemanticIR** = Rust's structured fold node. **v0 lambda spelling** =
`-> ({ ... })` (works today, no parser change); `-> { ... }` ergonomics stay a
**separate** parser card. Scalar fold is regression-protected in both toolchains.

---

## 1. Ground truth (verified against the live source + compiler)

| Surface | State today | Evidence |
|---------|-------------|----------|
| Ruby TC | record `Acc` **works** with `-> ({...})`; bad field → `OOF-TY0`; scalar clean | B-01..B-06 |
| Ruby TC | body-vs-`Acc` match is **name-only** (`body_name == acc_name`) | `typechecker.rb:2718-2724` |
| Ruby emitter | **no** fold node — fold lowers via the generic compute/`call` path | `semanticir_emitter.rb:293-302, 341-365` |
| Rust TC | thin `"fold" =>` arm: `resolved_type = typed_args[1].resolved_type` — **no** seed contextualization, **no** lambda walk, **no** OOF-COL4 | `typechecker.rs:3664-3671` |
| Rust TC | record literals get a concrete type **only** via `output_type_hints`; "uncontextualized RecordLiterals remain Unknown" | `typechecker.rs:677, 1130` |
| Rust emitter | structured fold node **already** record-capable (`init`/`body` via `semantic_expr`) — **no change needed** | `emitter.rs:1508-1540` |

Net: inline record seed `{ sum: 0, count: 0 }` → **Unknown** in Rust → `OOF-TY1
expected Stats, got Unknown` (C-01..C-03). Ruby is fine on inference; its gap is
lowering parity. Scalar fold stays `ok`/clean (C-04, B-05).

---

## 2. The nine planning questions

**Q1. Exact type rule for `fold(Collection[T], Acc, (Acc,T)->Acc)` with record `Acc`?**
Accept when: (a) the seed expression has a concrete type `Acc` (a named record, or
an inline record literal contextualized to a named record); (b) the lambda has
exactly 2 params bound `acc:Acc, elem:T`; (c) the lambda body type is
**structurally assignable** to `Acc` (same record name **and** field set/types).
Result type = `Acc`. Any failure → `OOF-COL4`. This is exactly Ruby's
`infer_fold_call` contract, to be mirrored in Rust.

**Q2. Derive `Acc` from seed, annotation, expected output, or explicit contextual type?**
**From the seed**, contextualized by the **expected output type** when the seed is
an inline record literal. Rationale: Ruby already derives `Acc` from the seed
(`acc_type = seed_typed.resolved_type`); Rust must do the same, but because Rust
leaves uncontextualized record literals as Unknown, the seed literal needs a
**contextual hint**. The hint source is the enclosing compute node's
`output_type_hints` entry (the declared output record type) — propagated into the
fold seed (and lambda-body) record literals. No annotation-on-fold syntax is added.

**Q3. How should Rust infer inline record seeds without broad `Unknown` permissiveness?**
**Reuse, do not widen.** Extend the existing `output_type_hints` /
`collection_output_hints` machinery (`typechecker.rs:677-740, 1130-1134`) so that
when a compute node `s = fold(coll, {..}, lambda)` carries an output hint `R`, the
**seed record literal** is typed against shape `R` (and the **lambda-body record
literal** likewise). This is the same contextual mechanism already used for
top-level output record literals — applied one level deeper into the fold arguments.
It does **not** make bare record literals permissive anywhere else.

**Q4. How should Rust validate lambda return against `Acc` (bad/missing/extra fields)?**
At the `"fold" =>` arm: after resolving `Acc` (seed type) and `T` (element type),
build a local scope binding `acc:Acc, elem:T`, infer the lambda body, then check the
body type against `Acc` with `structurally_assignable` (`typechecker.rs` already has
it) + a field-set comparison via `type_shapes` (used by the `avg/min/max` arm). Emit
`OOF-COL4` for: wrong field type, missing field, extra field, or non-`Acc` scalar
return. Mirror Ruby's message: *"stdlib.collection.fold: lambda return type X does
not match accumulator type Acc"* (extend with the specific field on structural
mismatch).

**Q5. What does Ruby need beyond current TC support?**
- **Emitter lowering** (the real gap): add a canonical fold node so Ruby's
  SemanticIR matches Rust's structured shape (today Ruby emits a generic `call`).
- **Optional TC hardening**: upgrade the body-vs-`Acc` check from **name-only**
  (`body_name == acc_name`, line 2720) to **structural** so two same-named-but-
  divergent records can't slip through. In practice record-literal inference already
  catches field errors via the output hint (B-03/B-04), so this is defense-in-depth,
  not a correctness blocker.
- No new Ruby validation is otherwise required; no new OOF code.

**Q6. Should `-> ({ ... })` remain v0 canonical spelling?**
**Yes.** It compiles today with zero parser changes (B-01). The unparenthesized
`-> { ... }` parses as a lambda **block**, not a record expression (B-09), and is a
**parser-ergonomics** concern explicitly kept in a separate card. P3/P4 must not
smuggle a grammar change.

**Q7. Canonical SemanticIR shape for fold with record accumulator?**
**Rust's structured fold pipeline node** (`emitter.rs:1533-1539`):

```json
{ "kind": "fold",
  "param_acc": "<acc-param-name>",
  "param_val": "<elem-param-name>",
  "init": <semantic_expr(seed)>,
  "body": <semantic_expr(lambda_body)> }
```

`init` and `body` already lower records structurally via `semantic_expr`, so no
Rust emitter change is needed. P4 makes the Ruby emitter emit the **same** node
instead of a generic `call`.

**Q8. What app pressure is actually resolved?**
**Both** trade_robot and sim_framework, plus proof fixtures — but the *primary*
unlock is **trade_robot**: `RunBacktest`'s manual `p0…p10` unroll becomes
`fold(candles, p0, (portfolio, candle) -> ({ ... }))`, and RSI/MACD history
(`{sum_gain, sum_loss, prev_close, count}`) becomes a single record fold instead of
the documented "fold() returns a single scalar" workaround (H-06). sim_framework's
temporal windows benefit but are already expressible (per LANG-TEMPORAL-STATE-P1);
they are *secondary* evidence, not the driver.

**Q9. Proof matrix required before P3 implementation?**
A dual-toolchain matrix with four mandatory sections:
- **Positive**: inline-seed record fold (Ruby + Rust) compiles; result type = `Acc`;
  nested record fields resolve; named-seed (via contract) also works.
- **Negative**: bad field type / missing field / extra field / non-`Acc` scalar
  return / wrong arity / wrong lambda-param count → `OOF-COL4` (Rust) / existing
  codes (Ruby), with exact messages.
- **App-pressure**: trade_robot backtest-as-fold fixture compiles dual-clean; RSI
  record-fold fixture compiles.
- **Regression**: scalar fold (Ruby + Rust) unchanged; `map`/`filter`/`sum`/`avg`
  unaffected; `fold_stream` untouched; SemanticIR fold node identical across
  toolchains (byte-comparable on the fixture).
Target ≥ 70 checks for P3, ≥ 50 for P4 (lowering parity + cross-toolchain SIR diff).

---

## 3. Exact insertion points

### P3 — Rust TC (`igniter-lab/igniter-compiler/src/typechecker.rs`)

1. **Seed contextualization** — extend the hint pass (`~677-740`, the
   `output_type_hints` / `collection_output_hints` builders) and the RecordLiteral
   inference site (`~1130-1134`, "Uncontextualized RecordLiterals … remain Unknown")
   so a fold compute node's output hint reaches the **seed** and **lambda-body**
   record literals.
2. **Fold arm rewrite** — replace the thin `"fold" => { … }` arm (`3664-3671`).
   New body: arity check (3 args) → collection check → seed→`Acc` → element type via
   `get_param` → bind `acc/elem` locally → infer lambda body → `structurally_assignable`
   + `type_shapes` field check → `OOF-COL4` on mismatch → `resolved_type = Acc`.
3. **Helpers reused**: `structurally_assignable`, `type_name`, `get_param`,
   `type_shapes` (all present — E-07/E-08/E-09). No new OOF code (OOF-COL4 family
   already in the Rust TC — E-06).

### P4 — Ruby emitter (`igniter-lang/lib/igniter_lang/semanticir_emitter.rb`)

1. **New `fold_node`** beside `fold_stream_node` (`~724`), emitting
   `{kind:"fold", param_acc, param_val, init: semantic_expr(seed), body: semantic_expr(body)}`.
2. **Dispatch**: in `semantic_expr` (`341`) or the compute lowering (`293-302`),
   detect a `call` with `fn == "stdlib.collection.fold"` and route to `fold_node`
   (parallel to how `recur` is special-cased at `353-358`).
3. **Optional Ruby TC hardening**: `infer_fold_call` body-vs-`Acc` check at
   `typechecker.rb:2718-2724` from `body_name == acc_name` to a structural compare.

### Unchanged (do NOT touch)

- Rust emitter fold node (`emitter.rs:1508-1540`) — already record-capable (F-08).
- Ruby `infer_fold_call` core (`typechecker.rb:2666`) — inference already correct.
- Parser / grammar — `-> ({...})` is the v0 spelling.
- `fold_stream`, `map`, `filter`, `sum`, `avg`, scalar fold paths.

---

## 4. Route decision & split

**ROUTE = P3 (Rust TC) → P4 (lowering parity).** A two-card ladder, mirroring the
`LANG-TYPED-CONTRACT-REF` (TC first) and `LANG-STDLIB-*` (impl then parity) patterns.

Why split rather than one dual-toolchain card:
- The Rust TC change (contextual inference + structural return validation) carries
  **all** the design risk and is self-contained at the `"fold"` arm + hint pass.
- The Ruby emitter fold node is **independent** of the Rust TC work and is a
  mechanical parity addition; bundling them would couple unrelated risk (H-07).
- Each card gets its own focused proof matrix (Q9).

A justified single-card alternative exists **only** if a future agent shows the
Ruby emitter node and Rust TC change must land atomically for a cross-toolchain SIR
diff to pass — current evidence shows they do not (Rust emitter already emits the
canonical node; Ruby TC already types records).

### Acceptance (card §Acceptance)

- ✅ Concrete P3/P4 split with a justified single-card fallback.
- ✅ Exact insertion points named in Ruby TC/emitter and Rust TC/emitter (§3).
- ✅ Scalar fold behavior preserved (G-01).
- ✅ No group_by/join/reduce-all semantics (G-02..G-04).
- ✅ Parser ergonomics kept separate (Q6, G-05).
- ✅ Proof matrix with positive / negative / app-pressure / regression sections (Q9).

---

## 5. Proof

```
runner:   igniter-lang/experiments/fold_struct_accumulator_proof/verify_fold_struct_accumulator_p2.rb
result:   64/64 PASS
sections: A gate+preconditions (6) / B current Ruby (9) / C current Rust (8) /
          D Ruby insertion points (8) / E Rust insertion points (9) /
          F emitter/SIR divergence (8) / G planning invariants (9) / H route (7)
```

---

## 6. Closed surfaces (this P2 card)

- No implementation in this card.
- No parser syntax change.
- No group_by/join/flat_map expansion.
- No IO/runtime/capability authority.
- No app source migration.
- No new OOF code.

---

## 7. Open routes (successors)

| Card | Scope |
|------|-------|
| LANG-FOLD-STRUCT-ACCUMULATOR-P3 | Rust TC: contextual record-seed inference + lambda-return structural validation + OOF-COL4 parity at the `"fold"` arm; proof matrix ≥70 |
| LANG-FOLD-STRUCT-ACCUMULATOR-P4 | Lowering parity: Ruby emitter canonical fold node + cross-toolchain SIR diff; optional Ruby TC structural hardening; proof ≥50 |
| (separate) parser ergonomics | `-> { ... }` record-return lambda spelling — not in scope here |
| (downstream) trade_robot backtest-as-fold | App migration once P3/P4 land (its own card) |
