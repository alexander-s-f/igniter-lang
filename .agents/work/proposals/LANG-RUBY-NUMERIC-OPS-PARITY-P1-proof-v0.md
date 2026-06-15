# LANG-RUBY-NUMERIC-OPS-PARITY-P1 — proof packet (v0)

**Status:** closed / proved — **124/124 PASS** (target ≥ 80)
**Route:** lang / Ruby canon typechecker / homogeneous numeric ops parity
**Date:** 2026-06-15
**Authority:** Ruby canon typechecker parity only. No VM, Rust, app, or coercion changes.

## Goal

Mirror the already-landed Rust homogeneous numeric relaxation in the Ruby canon
typechecker (`lib/igniter_lang/typechecker.rb`), resolving the residuals pinned by the
decimal cluster:

- `erp_logistics`: Ruby rejected `Float < Float` / `Float * Float` in production contracts.
- `bookkeeping`: Ruby rejected `Decimal + Decimal` after the explicit `decimal(0,2)` migration.

## Implementation (one method + one helper, `typechecker.rb` only)

`operator_type(op, left, right, …)` gained two blocks ahead of the existing Integer-only
`case`, mirroring the Rust `operator_type` (`igniter-compiler/src/typechecker.rs` ~3440):

1. **Fixed-point Decimal rules** (both operands `Decimal`): `+`/`-` require equal scale
   (`OOF-TC5` on mismatch) and return `Decimal[scale]` (`stdlib.decimal.add`); `*` returns
   `Decimal[A+B]` (`stdlib.decimal.mul`).
2. **v0 homogeneous relaxation** (both sides the *same* numeric family
   `Integer`/`Float`/`Decimal`): arithmetic `+ - * /` returns the operand type; comparison
   `< <= > >=` and `==` return `Bool`. The nominal `stdlib.integer.*` fn name is kept (the
   VM opcodes already dispatch by value type — no runtime change).

New helper `decimal_scale(t)` reads the scale param whether it is a bare scalar (the
integer `2` from a `Decimal[2]` annotation) or a named-type node (`{"name"=>"2"}` from the
`decimal()` constructor).

Heterogeneous numeric (`Integer + Float`, `Float + Decimal`, …) and implicit
`Float`/`Integer` → `Decimal` fall through to the unchanged Integer-only / boundary
rejection paths — strictly homogeneous, non-coercive.

**Operator set mirrored exactly from Rust:** `+ - * / < <= > >= ==`. `!=` is typed by
neither toolchain, so it was deliberately not added (adding it to Ruby alone would
introduce a divergence).

## Evidence (dual-toolchain, Ruby canon vs Rust lab)

Proof: `experiments/numeric_ops_parity_proof/verify_ruby_numeric_ops_parity_p1.rb` —
**124/124 PASS**, deterministic across runs (Rust compile retries the fd/timing flake).

- **B/C** — homogeneous Integer/Float arithmetic + comparison + `==` ACCEPTED dual.
- **D** — Decimal (constructor-based) `+ - * < ==` ACCEPTED dual; `*` → `Decimal[A+B]`.
- **E** — Decimal scale mismatch → `OOF-TC5` dual.
- **F** — heterogeneous (`Integer+Float`, `Integer<Float`, `Float*Integer`,
  `Float+Decimal`) REJECTED dual (`OOF-TY0`).
- **G** — implicit `0.00`/`Float`/`Integer` → `Decimal[2]` STILL `OOF-TY1` dual (boundary
  not regressed).
- **H** — `Text==Text`, `Bool==Bool` unaffected (no regression).
- **I** — `erp_logistics` Ruby now **ok/0** (Float residual resolved → app dual-clean);
  `bookkeeping` loses the `Decimal+Decimal` error and the `OOF-COL4` cascade (residual
  reduced to the `sum` scalar form `OOF-COL1`+`OOF-P1`, classified separately under
  `LANG-STDLIB-COLLECTION-SUM-SCALAR`).
- **J** — closed surfaces: no implicit coercion, no `round_decimal`, no `Money`, no
  one-arg `sum` implementation; heterogeneous stays rejected.
- **K** — see discovered finding below.

## Acceptance

- Ruby accepts homogeneous `Float` arithmetic/comparison/equality — **MET**.
- Ruby accepts same-scale `Decimal[N]` arithmetic/comparison/equality where Rust does —
  **MET** (constructor-based).
- Ruby rejects heterogeneous combinations and Decimal scale mismatch — **MET**.
- `bookkeeping` Ruby residual loses the `Decimal+Decimal` error; the `sum` scalar residual
  is classified separately — **MET**.
- `erp_logistics` Ruby numeric residual resolved (app now dual-clean) — **MET**.
- Existing string/sum/decimal-construct proofs remain green — **MET** (decimal-construct
  73/73, string char_at VM 96/96; the pre-existing `verify_lab_stdlib_sum_p1` failures are
  unrelated stale — see below).

## Reconciled downstream proofs (same decimal storyline)

This parity fix and the prior bookkeeping migration legitimately resolved residuals that
several closed-card proofs had pinned as live. Each was updated to assert the resolved
state and reference the resolving card, staying green as forward regression guards:

- `verify_lab_numeric_decimal_boundary_p1.rb` — 62/62 (E-section: bookkeeping blocker now
  resolved; I-05 reframed).
- `verify_lab_numeric_decimal_construct_p1.rb` — 73/73 (J-04 reframed to the card's
  closed-surface claim).
- `verify_lab_bookkeeping_decimal_migration_p1.rb` — 70/70 (F-05/F-06/K-02/K-05: the
  `Decimal+Decimal` residual + `OOF-COL4` cascade now RESOLVED by this card).
- `verify_lab_erp_logistics_demo_entry_p1.rb` — 141/141 (C-section: erp Ruby now ok/0).
- `verify_pursuit_guidance_p1.rb` — 45/45 (HYP-MATHGAP-01..03 + HYP-COMPILE-03: the
  numeric-op gap is now closed/converged dual; the full pursuit fixture is now Ruby-clean).

## Discovered finding (routed, out of this card's authority)

**Rust mis-extracts the scale from a Decimal *input annotation* in the operator path**
(read as `0`). So Rust types `input Decimal[2] * input Decimal[2]` as `Decimal[0]`
(→ `OOF-TY1`) and misses `input Decimal[2] + input Decimal[4]` scale mismatch (accepts).
The Ruby canon TC (this card) reads the scale correctly from both bare-int and named-type
params, so **Ruby is now more correct than Rust here**. Section K of the proof documents
the divergence (Ruby correct; Rust latent bug) and confirms it is isolated to
input-annotation Decimals — the `decimal()` constructor path agrees dual. → Rust follow-up.

## Pre-existing stale proofs (NOT caused by this card)

- `verify_lab_stdlib_collection_map_filter_count_inventory_p5.rb` /
  `..._append_rust_parity_p4.rb` — hardcoded entry counts + `typechecker.rs` append-arm
  greps (moved to `typechecker/stdlib_calls.rs`) + `semantic_stability` vocab drift.
- `verify_lab_stdlib_sum_p1.rb` — asserts the pre-`sum`-implementation state ("Unknown
  function: sum"); superseded by the implemented `sum` + `LANG-STDLIB-COLLECTION-SUM-SCALAR`.
- `verify_lab_neural_net_baseline_p1.rb` G-02 — Rust `artifact_hash` baseline drift
  (Rust-side; a Ruby-only TC change cannot affect it).

These are unrelated to the Ruby numeric-parity change and left for proof-refresh cards.

## Closed surfaces (held)

No Rust changes. No VM changes. No app source edits. No implicit coercion. No
`round_decimal`. No `Money` type. No one-arg `sum` implementation.

## Artifacts

- Implementation: `lib/igniter_lang/typechecker.rb` (`operator_type` + `decimal_scale`).
- Proof: `experiments/numeric_ops_parity_proof/verify_ruby_numeric_ops_parity_p1.rb` (124/124).
- Card: `.agents/work/cards/lang/LANG-RUBY-NUMERIC-OPS-PARITY-P1.md`.
