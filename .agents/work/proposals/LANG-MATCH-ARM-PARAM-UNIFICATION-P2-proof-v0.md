# LANG-MATCH-ARM-PARAM-UNIFICATION-P2 — Implementation Proof (route A)

**Status:** CLOSED — IMPLEMENTED 88/88 — dual-toolchain (Ruby canon + Rust lab), fleet 19/20 DUAL-CLEAN
**Track:** lang / typechecker / match / parametric structural join
**Date:** 2026-06-15
**Authority:** dual-toolchain implementation; no syntax/runtime/app changes

---

## 0. TL;DR

Landed route **(A)** from `LANG-MATCH-ARM-PARAM-UNIFICATION-P1`: `match` result
unification now **preserves type params** when all arms share a parametric family, via
a position-wise structural join inside `unify_match_arm_types` in **both** toolchains.

```igniter
match r {
  Valid   { record } => some(record)
  Invalid { }        => none()
}  -- now infers Option[ImportRecord]   (was: bare Option → OOF-TY1)
```

It is a **pure precision widening**: every case that previously dropped params still
returns the byte-identical legacy `type_ir(name)`; params are preserved only when the
join yields a non-empty, fully-resolved (not `Unknown`-bearing) result. Name divergence
keeps `OOF-KIND5`; concrete-param conflict degrades to the legacy bare family result
with **no new diagnostic**. Non-parametric match SIR is byte-unchanged. The 20-app
fleet stays **19/20 DUAL-CLEAN** (rule_engine frozen).

---

## 1. What landed

### Both toolchains — `unify_match_arm_types`
- Top-level `Unknown` arms are filtered out (`present`) — they contribute nothing to
  the join (legacy behavior preserved).
- Top-level name divergence still emits `OOF-KIND5` and returns `Unknown`.
- For a single shared name, arms are folded through a new **`join_match_param_types`**
  helper; the join is kept **iff** non-empty-param and not `unknown_or_unknown_bearing?`,
  else the legacy bare `type_ir(name)` is returned.

### `join_match_param_types` (new helper, mirrored)
Position-wise structural join of two arm result types:
- **`Unknown` is the join bottom:** `join(Unknown, X) = X` (concrete side wins).
- **Identical structures preserved as-is** (`a == b` short-circuit) — keeps any extra
  keys (e.g. OLAPPoint `dims`), zero structural change.
- Arity mismatch or concrete-name conflict at any depth ⇒ `nil`/`None` ⇒ the caller
  degrades to the legacy bare family result.
- Recurses, so nested parametrics (`Collection[Option[T]]`, `Map[String, Result[T,E]]`)
  preserve.
- Emits **no diagnostic** (P2 reserves **`OOF-KIND7`** for a future strictness card;
  `OOF-KIND6` is already taken by PROP-044-P9 reserved-field-name checks).

### Edit sites
| Toolchain | File | Function | Call site |
|---|---|---|---|
| Ruby canon | `lib/igniter_lang/typechecker.rb` | `unify_match_arm_types` + `join_match_param_types` | single (`:3501`) |
| Rust lab | `igniter-compiler/src/typechecker.rs` | `unify_match_arm_types` + `join_match_param_types` | single (`:4054`) |

## 2. Behavior — before → after (live, dual-toolchain)

| Fixture | Before | After (this card) |
|---|---|---|
| `match … => some(record)/none() : Option[ImportRecord]` | `OOF-TY1 got Option` | **clean** (`Option[ImportRecord]`) |
| `match … => ok(record)/err(message) : Result[ImportRecord,String]` | `OOF-TY1 got Result` | **clean** |
| `match … => recs/recs : Collection[ImportRecord]` | `OOF-TY1 got Collection` | **clean** |
| `match … => mp/mp : Map[String,ImportRecord]` | `OOF-TY1 got Map` | **clean** |
| same Option match `: Option` (bare boundary) | clean | **`OOF-TY1`** — result is now parameterised (precision-widening signature) |
| `match … => recs/[] : Collection[ImportRecord]` (Unknown=bottom) | `OOF-TY1` | **clean** (recovers element from the concrete arm) |
| `match … => recs/nums : Collection[ImportRecord]` (param conflict) | `OOF-TY1` | `OOF-TY1` (degrades to **bare** Collection; no `OOF-KIND5`/`OOF-KIND7`) |
| non-parametric `match … : ImportRecord` | clean | **clean** (SIR byte-unchanged) |
| `match … => 1/"x" : Integer` (name divergence) | `OOF-KIND5` | **`OOF-KIND5`** (unchanged) |

## 3. SIR impact (Q6)

Only `match_expr.resolved_type` changes, and only where params were being dropped:
- parametric match → `resolved_type` now carries the params
  (`{name:"Option", params:[{name:"ImportRecord",params:[]}]}`);
- non-parametric match → `resolved_type` unchanged (`{name:"ImportRecord", params:[]}`),
  byte-identical to the legacy `type_ir("ImportRecord")`;
- conflict / unknown-bearing fallback → bare `{name, params:[]}`, byte-identical to legacy;
- preserved `resolved_type` carries only `{name, params}` keys — no new keys introduced.

User-variant `variant_construct` / `match_node` SIR, `variant_env`, the sealed
`sealed:true` marker, and payload bindings are all untouched — confirmed by the sumtype
P3 proof staying **109/109** and the fleet staying 19/20.

## 4. Regression evidence

| Artefact | Result |
|---|---|
| `experiments/match_param_unification_proof/verify_match_arm_param_unification_p2.rb` | **88/88 PASS** (target ≥80) |
| `verify_match_arm_param_unification_p1.rb` (updated to **fixed-state**) | **72/72 PASS** |
| `verify_sumtype_construct_match_p3.rb` (core sumtype + SIR) | **109/109 PASS** |
| **20-app fleet (dual-toolchain compile)** | **19/20 DUAL-CLEAN**; `rule_engine` frozen at `oof/2` (both); no app regressed |

Fleet detail: every app compiles `ok/0` in both Ruby and Rust except `rule_engine`
(intentional fail-closed dynamic-dispatch boundary, unchanged). `batch_importer`
(the BI-P01 app) stays DUAL-CLEAN.

## 5. The one observable behavior change (precision, not regression)

A `match` whose arms produce a parametric family, **annotated against the *bare*
family** (`: Option`, `: Collection`), now correctly **rejects** with `OOF-TY1` (it was
accepted pre-fix because the result was silently bare). This is the intended
precision-widening signature: properly parameterised annotations (`: Option[T]`) are
unaffected, and no fleet app relies on a bare-parametric annotation (fleet stays 19/20).

## 6. filter_map interaction (Q9 confirmed)

`filter_map` (COLLECT-P3, in-flight in the working tree via route **B**) computes its
output element `U` from the callback body's `Option[U]` param **first**
(`infer_filter_map_call:2742-2745`), falling back to the `@collection_output_hints`
output-context lever only when that is `Unknown`. Before this fix the callback `match`
collapsed to bare `Option`, so `filter_map` relied on the route-B `ctx_u` fallback;
**after this fix the callback resolves `Option[ImportRecord]`, so the primary path
fires** and `filter_map` reads `U` directly — exactly the P1 Q9 prediction. The
route-B `ctx_u` plumbing is now redundant for this case and can be retired when
COLLECT-P3 closes.

## 7. Predecessor-runner staleness (routed to the existing sweep)

The COLLECT-track readiness runners assert the *old* state and are now stale — partly
from in-flight COLLECT-P3 (`filter_map` now exists, so the "Unknown function" gap
checks flip) and partly from this card (the match-param-drop checks flip):
- `verify_sumtype_collect_p1.rb` — several `filter_map`-absent + match-param-drop checks;
- `verify_sumtype_collect_p2.rb` — same.

These belong to the **stale-readiness-proof sweep** already flagged in the
`LANG-SUMTYPE-CONSTRUCT-MATCH-P3` closure and to COLLECT-P3's own closure (which will
fix-state its track's runners). They are **not** edited here to avoid colliding with
the in-flight COLLECT-P3 session; this card updates only its own predecessor
(`verify_match_arm_param_unification_p1.rb` → fixed-state).

## 8. Closed surfaces (held)

No parser change · no new syntax · no runtime/VM change · no app migration · no
`OOF-KIND7` implementation (reserved) · no generic typeclass / Hindley-Milner inference
— bounded strictly to match-result unification.
