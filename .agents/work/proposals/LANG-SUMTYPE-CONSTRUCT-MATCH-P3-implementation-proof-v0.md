# LANG-SUMTYPE-CONSTRUCT-MATCH-P3 — Implementation Proof

**Status:** CLOSED — IMPLEMENTED 109/109 — dual-toolchain, fleet-stable
**Track:** lang / type-system / built-in sumtypes / dual-toolchain implementation
**Date:** 2026-06-15
**Authority:** canon Ruby + lab Rust parity implementation; no app migration
**Gate:** P1 (76/76) + P2 (78/78) + FIRST-LAST-P2 + RESULT-BIND-P2 — all CLOSED

---

## 0. TL;DR

Sealed built-in `Option[T]` and `Result[T,E]` construction + source-level `match`
are now implemented in **both** toolchains in lockstep:

- `some(v)` / `none()` / `ok(v)` / `err(e)` typecheck and lower to **sealed
  `variant_construct`** SIR nodes (`sealed: true`), reusing the user-variant
  construct/emit machinery. Payload labels are locked to `value` / `error`.
- `match` over `Option` / `Result` is admitted; the binding gets the **concrete**
  payload type substituted from the subject's params (`Some.value : T`, `Err.error : E`).
- `none()` / `ok()` / `err()` recover the missing type parameter from
  **expected-type context** at an Option/Result-annotated output boundary.
- `unwrap_or` and `and_then` typecheck in both (Result reader + fixed-error-family bind).
- `first(xs)` / `last(xs)` results are matchable as `Option[T]`.
- The `sealed: true` marker is **sealed-only**: user-variant SIR is byte-unchanged.

**Verdict:** P3 proof **109/109 PASS**. Fleet recheck **19/20 DUAL-CLEAN**;
`rule_engine` stays at its frozen fail-closed boundary (unchanged). Zero app regressions.

---

## 1. Route taken (vs the P2 plan)

P2 locked "5 mirrored edit sites per side". The landed implementation refines two of
those, faithfully to canon:

1. **Sealed registry held SEPARATELY** from `@variant_shapes`, not merged into it.
   Merging would have emitted `Option`/`Result` into the SemanticIR `variant_env` for
   *every* program (Ruby `typechecker.rb` emits `@variant_shapes` as `variant_env`),
   changing all SIR goldens. A separate `SEALED_VARIANT_SHAPES` registry consulted by
   `variant_type?` / `variant_arms` keeps the emitted `variant_env` user-variant-only.

2. **Admission == registration** ⇒ no separate OOF-KIND4 allowlist edit. Because the
   sealed registry is what `variant_type?` / `variant_type_exists` consults, `Option` /
   `Result` are admitted to the match path automatically and arbitrary named types stay
   rejected — a cleaner relax than a 2-name allowlist, with no change to the emitted SIR.

3. **Constructors lower to `variant_construct` (canon), not `call`.** P1/P2 locked the
   sealed marker on `variant_construct` / `match_node`. The Rust lab previously emitted
   `some/none/ok/err` as `call` nodes (frontier approximation); per the boundary that
   *lab proofs do not create canon authority*, P3 moves them to the canon
   `variant_construct` shape in **both** toolchains. No dual-clean app previously
   contained these constructors (Ruby rejected them as `OOF-TY0 Unknown function`), so
   redefining the SIR shape regresses no existing golden.

4. **Expected-type propagation** uses a dedicated `sealed_output_hints` map (parallel to
   the record-literal `output_type_hints`), seeded per-contract from output/compute
   decls annotated `Option[…]` / `Result[…]`, read by the constructor inference via
   `node_name`. Held separately so record-literal hinting and the emitted SIR are untouched.

---

## 2. Landed edit sites (live line refs)

### Ruby canon — `lib/igniter_lang/typechecker.rb` + `semanticir_emitter.rb`

| Site | Location |
|---|---|
| `SEALED_VARIANT_SHAPES` + `SEALED_CONSTRUCTORS` constants | typechecker.rb (after `COLLECTION_FIRST_LAST_FNS`) |
| `variant_type?` / `sealed_builtin?` / `sealed_arm_field_types` / `variant_arms` | typechecker.rb variant helpers |
| `@sealed_output_hints` seeding (per-contract) | typechecker.rb (after `@output_type_hints`) |
| dispatch: `some/none/ok/err`, `unwrap_or`, `and_then` | `infer_call` |
| `infer_sealed_construct` + `build_sealed_construct` + `infer_unwrap_or` + `infer_and_then` + `result_type_ir` | typechecker.rb (near `infer_or_else`) |
| match payload substitution + `match_extra["sealed"]` | `infer_match_expr` |
| `sealed: true` marker (conditional) | semanticir_emitter.rb `semantic_variant_construct` / `semantic_match_node` |

### Rust lab — `igniter-compiler/src/typechecker.rs` + `typechecker/stdlib_calls.rs`

| Site | Location |
|---|---|
| `sealed_output_hints` field + `new()` init | typechecker.rs struct |
| `is_sealed_constructor` / `sealed_builtin` / `declared_arms_for` / `sealed_arm_field_types` | typechecker.rs helpers |
| `variant_type_exists` consults sealed | typechecker.rs |
| `make_option_ir` / `make_result_ir` / `sealed_hint_param` / `infer_sealed_construct` | typechecker.rs (near `infer_variant_construct`) |
| constructor interception (before user-fn/stdlib) | `Expr::Call` else-branch |
| match `declared_arms_for` + `sealed` + payload substitution + `sealed:true` marker | `infer_match_expr` |
| `sealed_output_hints` per-contract seeding | `typecheck_contract` |
| `and_then` fixed-error-family (lambda param→T; E from input) | stdlib_calls.rs `flat_map \| and_then` (guarded `fn_name == "and_then"`) |
| `some/none/ok/err` removed from stdlib_calls (now intercepted) | stdlib_calls.rs |

---

## 3. SIR byte-parity

Both toolchains canonicalise SIR by **sorting keys** before hashing/comparison
(Rust `serde_json` without `preserve_order` ⇒ BTreeMap; Ruby `canonical_json` =
`JSON.generate(deep_sort(value))`). So key insertion order is irrelevant; only the
key/value set matters. The `sealed: true` marker therefore lands identically.

The P3 proof asserts structural SIR parity **modulo the toolchains' pre-existing
volatile-key representation differences** (`resolved_type` `type_ref` wrapper vs
name-only; literal `literal_type` vs `type_tag`) — the same keys the conformance
harness strips. These differences are present in the user-variant `match_node` too
(already dual-clean in the fleet), confirming they are pre-existing and not introduced
by P3.

Canonical sealed shapes (verified emitted by both):

```jsonc
// some(n)  where n : Integer, output : Option[Integer]
{ "kind":"variant_construct","arm":"Some","variant":"Option",
  "fields":{"value":{"kind":"ref","name":"n", ...}},
  "resolved_type":{"name":"Option","params":[{"name":"Integer","params":[]}]},
  "sealed":true }

// none()  output : Option[Integer]  (param recovered from expected type)
{ "kind":"variant_construct","arm":"None","variant":"Option","fields":{},
  "resolved_type":{"name":"Option","params":[{"name":"Integer","params":[]}]},
  "sealed":true }

// match o { Some{value} => value  None{} => 0 }
{ "kind":"match_node","subject":{...},"subject_type":"Option",
  "arms":[{"pattern":{"wildcard":false,"arm":"Some","bindings":["value"]}, ...},
          {"pattern":{"wildcard":false,"arm":"None","bindings":[]}, ...}],
  "exhaustive":true,"has_wildcard":false,"resolved_type":{...},"sealed":true }

// user variant match_node — NO "sealed" key (byte-unchanged)
```

---

## 4. Proof results

| Runner | Result |
|---|---|
| `verify_sumtype_construct_match_p3.rb` (this card) | **109/109 PASS** (target ≥100) |
| `verify_sumtype_construct_match_p1.rb` (updated to fixed-state) | **76/76 PASS** |
| `verify_sumtype_construct_match_p2.rb` (updated to fixed-state) | **78/78 PASS** |
| `prop044_p5_typechecker` (user-variant/match regression guard) | 75/75 PASS |
| `optional_field_prop_p2` | 57/57 PASS |
| `compose_entity_prop_p2` | 71/71 PASS |

P3 sections: A gate(6) / B admission(10) / C constructors(10) / D expected-type(9) /
E payload labels(8) / F diagnostics reuse(12) / G unwrap_or+and_then(10) /
H first/last matchable(6) / I SIR marker+parity(14) / J user-variant regression(6) /
K source anchors(10) / L closed surfaces(8).

P1/P2 runners were updated to **fixed-state** (card deliverable): stale gap-assertions
that documented the *pre-P3* state are flipped to assert the post-P3 reality and marked
`[P3-FIXED]`. Proof totals are preserved (76/76, 78/78).

---

## 5. Fleet recheck (20-app wave P12)

Dual compile (Ruby orchestrator + Rust binary), comparing status + diagnostics:

**19/20 DUAL-CLEAN.** `rule_engine` remains the sole non-clean app at its **frozen**
fail-closed boundary (`LAB-RULE-ENGINE-BASELINE-P1`): Ruby `oof/2` (OOF-P1 + OOF-P1),
Rust `oof/2` (OOF-P1 + OOF-TY1) — exactly the recorded baseline. `rule_engine` does not
touch any P3 surface (no `match`/`Option`/`Result`/`some`/`none`/`ok`/`err`/`and_then`/
`unwrap_or`), confirmed by grep. **No clean app regressed.**

The Ruby↔Rust secondary-diagnostic asymmetry on `rule_engine` (and on a deliberately
invalid `match` over `Integer`) is a pre-existing degraded-mode cascade difference
documented since P1; the **primary** diagnostic (OOF-KIND4 / fail-closed) is identical.

---

## 6. Acceptance checklist

- ✅ `some/none/ok/err` typecheck correctly in both toolchains.
- ✅ `match` over `Option`/`Result` accepted only for sealed built-ins; arbitrary named
  types still `OOF-KIND4` (fail-closed preserved).
- ✅ Payload labels are exactly `value` / `error`.
- ✅ `none`/`ok`/`err` use expected-type context where available; no `Unknown` leak at an
  Option/Result-annotated output boundary. (No-context cases degrade consistently /
  fail-closed in both — documented sub-gap behaviour, dual-parity.)
- ✅ `first`/`last` results matchable as `Option[T]` (dual-clean).
- ✅ `unwrap_or` and `and_then` work in both toolchains.
- ✅ User `variant` fixtures + SIR output unchanged (no `sealed` key; byte-parity modulo
  pre-existing volatile-key normalization).
- ✅ Full app fleet recheck stable: 19/20 dual-clean; `rule_engine` frozen boundary unchanged.

---

## 7. Closed surfaces (respected)

- No generic Monad / typeclass / do-notation / generic user-variant bind.
- No constructor-form `Some {…}` / `Ok {…}` in source — still `OOF-KIND2` (deferred), dual.
- No dynamic dispatch widening — `and_then` accepts a lambda with an optional **static**
  `call_contract` inside; it does **not** authorize dynamic callee dispatch.
- No optional-field omission semantics, no nullable runtime value (`None` is a sealed arm).
- No IO/runtime/microservice changes, no app migration.

## 8. Inventory decision (deferred, canon-respecting)

`some/none/ok/err` are sealed **constructors** (variant_construct lowering), not
call-surface stdlib functions; `unwrap_or`/`and_then` emit **bare** SIR names. Adding
them to `stdlib-inventory.json` would violate the entry-contract invariants
(`semantic_ir_name == canonical_name` for non-legacy entries, and "exactly one
non-null `legacy_sir`" — currently `or_else`). Canonical-qualified inventory promotion
is therefore **deferred** to a dedicated inventory/migration card (mirroring the
`or_else → stdlib.option.or_else` P4 migration). The call-surface inventory and its
`stdlib_surface_digest` are intentionally **unchanged** by P3 — the constructors are
catalogued by the sealed registry instead. (`first`/`last` were already added by
`FIRST-LAST-P2`.)

## 9. Superseded predecessor proofs (documented, not rewritten)

P3 closes the "Option not matchable / no Ruby constructors / and_then not dual-clean"
gap that several CLOSED predecessor readiness proofs documented as point-in-time
caveats. Their gap-assertions are now historically stale (EXPECTED supersession, **not**
regressions). Per scope, only the sumtype P1/P2 runners were updated here; a follow-up
sweep is flagged for:

- `stdlib_collection_first_last_option_proof/verify_stdlib_collection_first_last_option_p1.rb`
- `stdlib_collection_first_last_option_proof/verify_stdlib_collection_first_last_p2.rb`
- `stdlib_outcome_bind_proof/verify_stdlib_outcome_bind_p1.rb`

`fold_struct_accumulator_p1` and `stdlib_entry_contract_p3` failures are **pre-existing**
(fold P2/P3 supersession; inventory grew 24→39 entries in later cards) — unrelated to
this wave and untouched.

---

## 10. Unblocked next routes

| Card | Now |
|---|---|
| `LANG-STDLIB-RESULT-BIND-P2` follow-on | built-in `Result` + `and_then` are dual-clean; wiring `lead_router` LR-P01 railway is unblocked |
| `LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P3` | `T?` omit→`none()`, present→`some(T)` lowering now has the construct/match substrate |
| inventory promotion card | canonical-qualified `some/none/ok/err/unwrap_or/and_then` entries + digest (with the legacy_sir/dual-accept window) |
| stale-readiness-proof sweep | fixed-state the three predecessor proofs above |
