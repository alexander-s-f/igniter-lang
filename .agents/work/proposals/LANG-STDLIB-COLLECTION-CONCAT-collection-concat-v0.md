# Proposal: stdlib.collection.concat
## LANG-STDLIB-COLLECTION-CONCAT-P1

**Lane:** lang / stdlib / collection / concat  
**Status:** authored-pending-review  
**Date:** 2026-06-12  
**Card:** `igniter-lab/.agents/work/cards/lang/LANG-STDLIB-COLLECTION-CONCAT-P1.md`

---

## Summary

`stdlib.collection.concat` joins two collections of the same element type into a single
collection: `concat(Collection[T], Collection[T]) → Collection[T]`. It is the
collection-level sibling of `stdlib.text.concat`, sharing the bare source alias `concat`
but disambiguated at typechecking time by the type of the first argument.

This proposal defines the canonical contract, OOF namespace, disambiguation rule,
current toolchain state, and the triage route to promote the existing orphaned inventory
entry to `lab-implemented`.

---

## Canonical Contract

| Field | Value |
|-------|-------|
| `canonical_name` | `stdlib.collection.concat` |
| `semantic_ir_name` | `stdlib.collection.concat` |
| `source_alias` | `concat` (shared with `stdlib.text.concat`; disambiguated by first arg type) |
| `type_params` | `[T]` |
| `input_signature` | `[Collection[T], Collection[T]]` |
| `output_signature` | `Collection[T]` |
| `purity` | `pure` |
| `fragment_class` | `core` |
| `authority_surface` | `none` |
| `totality` | `total` |

---

## Relationship to Existing Concat

### stdlib.text.concat (production-implemented, dual-toolchain)

`concat(Text, Text) → Text` — already live in both toolchains. Source alias `concat`
is registered in TEXT_STDLIB_FNS (Ruby) and TEXT_STDLIB_OPS (Rust).

### Disambiguation rule

At TypeChecker time, bare `concat(a, b)` routes based on the type of the first arg:

| First arg type | Route |
|----------------|-------|
| `Collection` | → `stdlib.collection.concat` |
| `Unknown` | → `stdlib.collection.concat` (Unknown permissive — no false positives from field access / unresolved expressions) |
| `Text`, `String` | → `stdlib.text.concat` (existing path) |
| Other concrete | → `stdlib.text.concat` (existing path; OOF-TY0 from text validation) |

**Rationale for Unknown permissive → collection path:** The primary unknown-first-arg
case arises when the first arg is a field access expression (e.g. `s.elements`) that
resolves to a Collection at runtime but returns "Unknown" from the TypeChecker's
shallow `quick_arg_type` (see DSA-P03 below). Routing Unknown to text.concat produces
a false OOF (the DSA-P03 bug). Routing Unknown to collection.concat produces a
`Collection[Unknown]` return — permissive, but accurate. P2 implementation must
define exactly how deep the disambiguation look-ahead goes.

### Relation to stdlib.collection.append

| Property | `append` | `concat` |
|----------|----------|---------|
| Second arg | Single item T | Full Collection[T] |
| Return | `Collection[T]` | `Collection[T]` |
| Order | Item appended at end | Second collection at end |
| OOF mismatch | COL6 (item vs element type) | COL7 (element types of both collections differ) |

---

## OOF Namespace

| Code | Name | Trigger | New/Reuse |
|------|------|---------|-----------|
| OOF-COL1 | Arity | `concat` called with ≠ 2 args | Reuse (consistent with all collection ops) |
| OOF-COL2 | Non-Collection first arg | First arg is concrete non-Collection, non-Unknown | Reuse (consistent with append/map/filter) |
| **OOF-COL7** | Element type mismatch | Both args are `Collection[T]` and `Collection[U]` where T ≠ U, both concrete | **NEW** |

**OOF-COL7 definition:** Fires when `concat(Collection[String], Collection[Integer])` — both
element types are concrete (non-Unknown) and differ by `type_name`. If either element
type is Unknown, skip OOF-COL7 (Unknown permissive). Non-early-return: error is recorded
but inference continues and returns `collection_type_ir_from(elem_type_of_first_arg)`.

**OOF-COL7 does NOT fire for:**
- Second arg being non-Collection entirely — that triggers OOF-COL2 on the second positional
  arg, or no error if Unknown (collection.concat: second arg must be Collection[T] or Unknown)
- Either element type Unknown

**Note on second arg non-Collection:** When first arg is Collection and second arg is a
concrete non-Collection type, the message should be "stdlib.collection.concat: second argument
must be Collection[T], got X" under code OOF-COL2. This extends COL2's meaning to "any
collection argument must be Collection[T]" consistently with its use in other collection ops.

---

## Current Toolchain State

### Ruby TypeChecker

`concat` is dispatched **only** via `TEXT_STDLIB_FNS`:

```ruby
"concat" => { arg_types: %w[Text Text], return_type: "Text" }
```

Any `concat(Collection, Collection)` call hits OOF-TY0 with message
`"stdlib.text.concat arg 1: expected Text, got Collection"`. There is no
`stdlib.collection.concat` dispatch path in Ruby.

**Ruby gap: ALL collection concat → OOF-TY0 via text.concat path.**

### Rust TypeChecker

Rust has **partial** collection.concat dispatch with two known bugs:

**DSA-P03 bug — field access mislabeling:**

`rewrite_concat_calls()` runs a pre-pass on each contract's expression tree before the
main typing pass. It calls `quick_arg_type(first_arg, symbol_types)` to decide the route:

```rust
Expr::Ref { name } => symbol_types.get(name).map(|t| self.type_name(t)).unwrap_or("Unknown")
_ => "Unknown"  // field access, array literals, etc.
```

When the first arg is a field access (`s.elements`), `quick_arg_type` returns `"Unknown"`,
so the rewrite sends it to `stdlib.text.concat`. The main typing pass then sees
`fn = "stdlib.text.concat"` with Collection args — but the `"concat"` arm in the typechecker
only matches the bare name. The TEXT_STDLIB_OPS path in the emitter handles the rewritten node,
producing `resolved_type: Text` with no diagnostic.

**Result:** `concat(s.elements, [new_elem])` where `s.elements: Collection[Integer]` →
SIR fn = `"stdlib.text.concat"`, resolved_type = Text — silently wrong. No OOF emitted.
This is the DSA baseline DSA-P03 finding (confirmed by `verify_lab_dsa_baseline_p1.rb` K-04).

**Bug 2 — element type parameter erasure:**

Even when the rewrite correctly identifies the first arg as Collection (bare Ref case),
the emitter's `resolved_type` for `stdlib.collection.concat` is:

```rust
{"name": "Collection", "params": []}
```

Element type T is NOT preserved. Downstream inference using the result of a concat call
cannot recover the element type from the SIR node.

**Conformance fixture verdict:**

| Fixture | Rust | Ruby |
|---------|------|------|
| `concat(items, extra)` where both are `Collection[Item]` (bare refs) | `stdlib.collection.concat` in SIR, ok, params=[] | OOF-TY0 (text path) |
| `concat(s.elements, [new_elem])` (field access + array literal) | `stdlib.text.concat` in SIR, ok (DSA-P03) | OOF-TY0 (text path) |

---

## Design Decisions

**D1: Source alias shared with text.concat**  
`concat` is the sole bare alias for both. Two registries must be maintained: the text
dispatch table (TEXT_STDLIB_FNS in Ruby / TEXT_STDLIB_OPS in Rust) and the new collection
dispatch arm. The disambiguation logic must run before the text table lookup to intercept
the collection case.

**D2: Disambiguation depth in Ruby TC**  
Ruby TC currently dispatches via `TEXT_STDLIB_FNS[fn]` — a hash lookup with no arg
inspection. The new collection path requires inspecting the first arg's resolved type.
This means either: (a) a `when "concat"` arm before the TEXT_STDLIB_FNS dispatch that
checks `col_type_name` of the first arg, or (b) a type-check pre-pass analogous to
Rust's `rewrite_concat_calls` — Option (a) is simpler and consistent with the append/fold
precedent. P2 planning selects the dispatch shape.

**D3: Unknown-first-arg route**  
Unknown first arg → collection.concat path (permissive, returns Collection[Unknown]).
This is the correct fix for DSA-P03 at the disambiguation boundary. The alternative
(Unknown → text.concat, existing Rust behavior) produces false-positive OOF-TY0 errors
in Ruby and silent mislabeling in Rust.

**D4: OOF-COL7 first activation**  
OOF-COL7 is reserved here and activated in P3 (Ruby implementation). It fires for
`concat(Collection[String], Collection[Integer])` — both element types concrete and
different. Unknown element type on either side → skip (permissive). This mirrors the
append/COL6 pattern.

**D5: Second-arg type check**  
When first arg is Collection or Unknown (collection path), second arg must be
Collection[U] or Unknown. If second arg is a concrete non-Collection type → OOF-COL2
with message "stdlib.collection.concat: second argument must be Collection[T], got X".
OOF-COL2 generalizes to "non-Collection argument to a collection operation" without
a new code.

**D6: Rust DSA-P03 fix scope**  
The `rewrite_concat_calls` / `quick_arg_type` approach is fragile. P4 (Rust parity) should
replace or supplement it with a post-rewrite type-check that re-inspects the first arg's
`resolved_type` from the typed arg list (as done in the `"concat"` arm at line 3096 of
typechecker.rs). This is consistent with how `"append"` was implemented — no pre-pass,
just arm-level type inspection.

**D7: Element type preservation in Rust emitter**  
Bug 2 (params=[]) must be fixed in P4: the emitter's `stdlib.collection.concat` branch
must extract the first arg's element type param and propagate it to the `resolved_type`.
This mirrors how the `append` emitter uses `elem_type` from the first arg.

**D8: Import surface**  
`import stdlib.collection.{ concat }` — current inventory entry has `aliases: []`,
so this produces OOF-IMP3 today. P3 must add `{kind: "source_alias", name: "concat"}`
to the collection.concat inventory entry. The text.concat entry also has `source_alias:
concat`. The import system must accept both — context-driven disambiguation at import
time is not required (source alias validates that the name exists in the module; the
TC disambiguation handles which path fires at call site).

**D9: Inventory triage**  
Current entry: lifecycle=orphaned, lowering=single-toolchain, aliases=[], diagnostics=[].
Route: P3 upgrades to lifecycle=lab-implemented, lowering=ruby-only, adds source_alias,
adds diagnostics=[COL1,COL2,COL7]. P4 upgrades lowering to dual-toolchain after Rust fix.

**D10: COLLECTION_HOF_OPS + TEXT_STDLIB_OPS_C**  
`concat` should NOT be added to `COLLECTION_HOF_OPS` in emitter.rs (that table rewrites
bare → qualified for HOF ops). Instead, the `stdlib.collection.concat` qualification
happens through the same `rewrite_concat_calls` pre-pass (after it's fixed) or via the
emitter's existing `stdlib.collection.concat`-specific branch. The TEXT_STDLIB_OPS_C
delegation guard should also NOT include `concat` because `concat` already goes through
the pre-pass disambiguation before reaching that guard.

**D11: Bootstrap form**  
`call_contract("concat", a, b)` — same as all other stdlib ops: fn = "call_contract" in
the AST, never reaches the new `when "concat"` arm. No COL1/COL2/COL7 from bootstrap.

**D12: flatten/flat_map/join/group_by**  
Explicitly closed. This card covers only `concat(Collection[T], Collection[T]) →
Collection[T]`. No flatten, flat_map, join, or group_by in this scope.

**D13: Proof matrix scope for P3**  
At minimum: OOF-COL1 arity / OOF-COL2 first arg / OOF-COL7 element type mismatch /
Unknown permissive / happy path / SIR fn name qualified / DSA-P03 fix (field access
first arg no longer mislabels) / text.concat regression / inventory upgrade.

---

## App Fixture Evidence

| Fixture | Usage | Current status |
|---------|-------|---------------|
| `igniter-lab/igniter-apps/dsa/sets.ig` | `concat(s.elements, [new_elem])` — field access first arg | Rust: DSA-P03 mislabel (stdlib.text.concat, resolved=Text); Ruby: OOF-TY0 |
| `igniter-lab/igniter-compiler/fixtures/conformance/source/collection_extension.ig` | `concat(items, extra)` — bare ref inputs | Rust: ok (stdlib.collection.concat); Ruby: OOF-TY0 |
| `igniter-lab/igniter-stdlib/stdlib/collections.ig` | `def concat(a: Collection[T], b: Collection[T]) -> Collection[T]` — stdlib declaration | Declarative surface only |
| `igniter-lab/igniter-apps/dataframes/matrix.ig` | Comment: "concatenate their cells" — not yet implemented | Future pressure, no current call |

---

## Inventory Triage Plan

| Phase | lifecycle_status | lowering_status | aliases | diagnostics |
|-------|-----------------|-----------------|---------|-------------|
| P1 (this proposal) | orphaned (no change) | single-toolchain | [] | [] |
| P3 (Ruby impl) | lab-implemented | ruby-only | [{source_alias: concat}] | [COL1, COL2, COL7] |
| P4 (Rust fix) | lab-implemented | dual-toolchain | same | same |

---

## Closed Surfaces

- No parser changes
- No VM / runtime / capability authority
- No flatten / flat_map / join / group_by
- No unary concat (`concat(a)` with 1 arg)
- No implementation in P1 — no typechecker.rb / typechecker.rs changes
- No new import surface authority

---

## Open Questions for P2 Planning

1. Ruby TC dispatch shape: `when "concat"` arm before TEXT_STDLIB_FNS vs new pre-pass helper?
2. Rust TC fix: replace `rewrite_concat_calls` for concat or augment `concat` arm to re-check
   resolved types after the pre-pass?
3. `quick_arg_type` in Rust: extend to handle `Expr::FieldAccess` by looking up field type
   in `@type_shapes`, or abandon the pre-pass approach entirely?
4. Emitter `resolved_type` fix: copy element type from first arg's params[0], or use helper?

---

## Next Route

**LANG-STDLIB-COLLECTION-CONCAT-PROP-P2** — implementation planning:
- Answer open questions D1–D13
- Choose Ruby TC dispatch shape
- Choose Rust TC fix approach for DSA-P03
- Plan proof matrix ≥50 checks / 9 sections
- Produce planning doc + READY FOR P3 verdict
