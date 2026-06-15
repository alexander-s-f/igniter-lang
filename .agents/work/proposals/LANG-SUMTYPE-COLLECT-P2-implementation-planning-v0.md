# LANG-SUMTYPE-COLLECT-P2 — Implementation Planning

**Status:** CLOSED — PLAN PROVED — ROUTE: dual-toolchain P3 `filter_map`, output-context fallback (B2)
**Track:** lang / stdlib / collection filter_map / implementation planning
**Date:** 2026-06-15
**Authority:** implementation planning only — NO compiler changes
**Gate:** SUMTYPE-CONSTRUCT-MATCH-P3 CLOSED + SUMTYPE-COLLECT-P1 CLOSED (68/68)

---

## 0. TL;DR

Implement `filter_map(xs : Collection[T], fn : T -> Option[U]) -> Collection[U]` as a
**TypeChecker HOF arm mirroring `map`** in both toolchains. It binds the callback param
to `T`, infers the callback body, and produces `Collection[U]`.

`U` cannot be read from the callback body alone — a parametric `match` collapses to bare
`Option` (the SUMTYPE-COLLECT-P1 sub-gap). So **P3 does NOT hard-gate on
`LANG-MATCH-ARM-PARAM-UNIFICATION`**; it carries a **local output-context fallback (B2)**:
`U` comes from the declared `Collection[U]` output/compute annotation (a new
`@collection_output_hints` lever, mirroring P3's `@sealed_output_hints`), and the
expected `Option[U]` is propagated **into** the callback (reusing P3's `sealed_output_hints`
temp-install) so `some(x)`/`none()` resolve against `U`. The sibling match-param card stays
a general improvement that later lets `filter_map` drop the context dependency.

**SIR mirrors `map` per-toolchain** (cross-toolchain byte-parity is NOT a `map`
invariant today): qualified `stdlib.collection.filter_map`; Ruby drops the lambda from
args + carries `resolved_type`, Rust keeps the lambda + the emitter qualifies via
`COLLECTION_HOF_OPS`. Diagnostics reuse `OOF-COL1/2/3` (no new code). Inventory gains one
entry + a digest recompute. Route = a single dual-toolchain P3.

---

## 1. Exact mirrored insertion points (live-confirmed)

| # | Ruby canon | Rust lab |
|---|---|---|
| dispatch | `typechecker.rb` `infer_call` — add `when "filter_map"` → new `infer_filter_map_call` (beside the `COLLECTION_HOF_FNS` / `and_then` arms) | `typechecker/stdlib_calls.rs` — add a `"filter_map" =>` arm (mirror `map`@~458 / `filter`@~366) |
| lambda inference | reuse `infer_collection_hof_call`'s machinery: bind param to `element_type_from_collection`, `infer_lambda_body` | reuse the `map`/`filter` arm's `Expr::Lambda` binding (`get_param(resolved,0)` → `local_symbols`) |
| output type | `collection_type_ir_from(U)` | build `{name:Collection, params:[U]}` |
| `U` extraction | `@collection_output_hints[node_name]` (NEW lever) → `U`; propagate `Option[U]` via temp `@sealed_output_hints[node_name]` around the callback infer | `collection_output_hints` as a `RefCell` field (NEW, mirror `sealed_output_hints`) read in the arm; temp `sealed_output_hints` install around the callback body infer |
| SIR call | `typed_expr("call", Collection[U], deps, "fn"=>"stdlib.collection.filter_map", "args"=>[collection_arg])` (lambda dropped, like `map`) | resolve type in the arm; `annotated_expr=None` → emitter fallback; add `("filter_map","stdlib.collection.filter_map")` to `COLLECTION_HOF_OPS` (`emitter.rs`~:801) |

`COLLECTION_HOF_FNS` (Ruby) may optionally gain a `filter_map` entry for arity metadata,
but the Option-unwrap means a dedicated `infer_filter_map_call` is cleaner than overloading
the shared `map`/`filter` output build.

---

## 2. The ten planning questions

**Q1. Ruby insertion.** `infer_call` `when "filter_map"` → `infer_filter_map_call`, reusing
`infer_collection_hof_call`'s collection-validation + lambda-binding + `infer_lambda_body`,
then unwrapping the body's `Option[U]` (or filling `U` from context, §Q5).

**Q2. Rust insertion.** A `"filter_map" =>` arm in `stdlib_calls.rs`, structurally a copy of
the `map`@458 arm (bind lambda param to `get_param(resolved,0)`, infer body) plus the
Option-unwrap / context fill, returning `Collection[U]`.

**Q3. New helper or shared path?** **Share** the existing HOF lambda-inference path; add a
**thin** post-step (Option-unwrap + context fallback). No parser change, no new lambda machinery.

**Q4. Extracting `U` from `Option[U]`.** When the callback body resolves to a parameterised
`Option[U]`, `U = body.params[0]`. When it collapses to bare `Option` (the match sub-gap),
`U` is taken from the output context (Q5). The result is always `Collection[U]`.

**Q5. Sequencing vs the match-param sub-gap.** **Do not hard-gate** `filter_map` P3 on
`LANG-MATCH-ARM-PARAM-UNIFICATION`. Carry a **local output-context fallback (B2)**:
- seed a `collection_output_hints` (compute/output annotated `Collection[U]` → `U`) — Ruby:
  new `@collection_output_hints`; Rust: promote the existing local to a `RefCell` field
  (both mirror P3's `sealed_output_hints` seeding);
- in the `filter_map` arm, read `U` for `node_name`, **temp-install `sealed_output_hints[node_name] = Option[U]`** around the callback inference (reuse P3 machinery) so `none()`/`some(x)` resolve against `U` and a wrong `some(y)` is caught;
- return `Collection[U]`.

Rationale: the match-unify fix is **general but high-blast-radius** — it changes the result
type of *every* parametric `match` (Option/Result/Collection/Map) currently collapsing to a
bare name, which moves SIR `resolved_type` metadata fleet-wide and needs a full SIR-golden
recheck. `filter_map` should not wait on that. The sibling card remains worthwhile: once it
lands, `filter_map` can read `U` straight from the callback and the context fallback becomes
a convenience, not a requirement.

**Q6. Diagnostics (all reused).** `OOF-COL1` arity ≠ 2; `OOF-COL2` non-`Collection` first
arg; `OOF-COL3`-analog "callback must return `Option[U]`" (mirrors `filter`'s "predicate
must return `Bool`" — fires when the body resolves to a non-`Option`, non-`Unknown` type);
non-lambda second arg → `OOF-COL1`/`COL3` (as `map`/`filter` do). **No new OOF family.**

**Q7. SIR shape + emitter edits.** Qualified `stdlib.collection.filter_map`. Per-toolchain,
mirroring `map` **exactly** (confirmed live — `map` already differs cross-toolchain, so
this is the accepted convention, not a regression):
- **Ruby:** `{kind:call, fn:"stdlib.collection.filter_map", args:[<collection>], resolved_type:Collection[U]}` — lambda dropped, `resolved_type` present. No emitter edit (the typed `fn` flows through).
- **Rust:** `{kind:call, fn:"stdlib.collection.filter_map", args:[<collection>, <lambda>]}` — lambda kept, no `resolved_type`. Emitter edit = add `("filter_map","stdlib.collection.filter_map")` to `COLLECTION_HOF_OPS`.

Cross-toolchain SIR byte-parity is **not asserted** for `filter_map` (it does not hold for
`map`/`filter` either); each toolchain's golden is self-consistent. Diagnostics + status
parity IS asserted (the fleet's dual-clean metric).

**Q8. Inventory + digest.** Add one entry `stdlib.collection.filter_map`
(`semantic_ir_name == canonical_name`, no `legacy_sir` — it emits qualified, so it fits the
entry-contract cleanly; `lowering_status` `none` → `dual-toolchain` at impl close;
`category: collection`, `purity: pure`, `type_params: [T, U]`, `input_signature:
["Collection[T]", "(T -> Option[U])"]`, `output_signature: "Collection[U]"`,
`diagnostics: [OOF-COL1, OOF-COL2, OOF-COL3]`). Recompute `stdlib_surface_digest`
(`sort_by canonical_name`, strip `entry_digest`, SHA-256 of canonical JSON). Add a
`filter_map` line to ch8 §8.2. (Done by the impl card, not here.)

**Q9. Proof matrix (for the impl P3).** BI-P01 collapse: `filter_map(results, r -> match r
{ Valid{record}=>some(record); Invalid{}=>none() }) : Collection[ImportRecord]` dual-clean
**without migrating `batch_importer`**; Result-shaped `filter_map(rs, r -> match r {
Ok{value}=>some(value); Err{}=>none() })`; diagnostics (arity / non-Collection / callback
returns `Bool` not `Option` → `OOF-COL3`); `first(filter_map(...))` → BI-P07 first-error;
regressions: `map`/`filter`/`fold`/`count` unchanged (SIR + diagnostics), user-variant
match unchanged, 20-app fleet recheck (incl. `batch_importer` still dual-clean, `rule_engine`
frozen).

**Q10. Out of scope (P3).** `partition`/`partition_result`/Pair; Result-specific
`oks`/`errs`/`collect`; `map` overload; `group_by`/`sort_by`/indexed-map; String→Int parse;
storage write; `batch_importer` source migration; the general match-param unify fix
(sibling card).

---

## 3. Route + acceptance

**Single dual-toolchain P3** (`filter_map` arm + emitter qualification + `collection_output_hints`
lever + inventory/digest). No hard dependency on the match-param card (carries fallback B2).

- ✅ `filter_map` v0 API locked; `collect` explicitly rejected as the function name.
- ✅ Exact mirrored Ruby/Rust edit sites (§1, live-confirmed).
- ✅ Diagnostics (`OOF-COL1/2/3`, no new code) + SIR shape (qualified, per-toolchain
  mirror of `map`) + inventory/digest shape locked.
- ✅ Sub-gap sequencing resolved: fallback B2, no hard gate; sibling card optional/later.
- ✅ User-variant and built-in Option/Result boundaries preserved (`filter_map` is
  agnostic to `T`; only the callback's `Option[U]` matters).
- ✅ No implementation; no app migration.

---

## 4. Proof

```
runner:  experiments/sumtype_collect_proof/verify_sumtype_collect_p2.rb
sections: A gate / B current gap / C map/filter anchors (Ruby+Rust) / D SIR shape evidence /
          E U-extraction + fallback B2 lever / F diagnostics reuse / G inventory+digest /
          H sequencing vs match-param sibling / I proof-matrix preview / J closed surfaces
```

## 5. Closed surfaces (this P2)

No parser/TC/emitter/runtime change; no app migration; no `map` overload; no
`partition`/Pair; no `group_by`/`sort_by`/indexed-map; no parse/storage; no implementation.
