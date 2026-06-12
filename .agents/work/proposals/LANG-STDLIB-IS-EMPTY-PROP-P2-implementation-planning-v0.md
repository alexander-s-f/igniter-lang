# LANG-STDLIB-IS-EMPTY-PROP-P2
## Implementation Planning — Ruby TC `stdlib.collection.is_empty` + `stdlib.collection.non_empty`

**Lane:** lang / stdlib / collection  
**Mode:** IMPLEMENTATION PLANNING ONLY — no code changes  
**Status:** CLOSED — READY FOR P3  
**Date:** 2026-06-12  
**Grounded by:** LAB-STDLIB-IS-EMPTY-P1 (48/48 PASS — ACCEPT) + LANG-STDLIB-IS-EMPTY-PROP-P1 (proposal authored)  
**Next route:** LANG-STDLIB-IS-EMPTY-PROP-P3 (Ruby TC implementation proof)

---

## Planning Decision: READY FOR P3

No SPLIT. No HOLD. Both entry contracts are stable (P1 closed), the insertion point is clear,
the OOF code set (COL1/COL2 reused — no new codes needed), and no helper infrastructure is
required beyond `type_ir("Bool")` which is already present throughout the TC. P3 is a
single-file change (~22 lines in `typechecker.rb`) plus two inventory entries.

---

## Q1 — Exact Ruby TC Insertion Points

**Two insertions in `typechecker.rb`:**

### Insertion 1 — Dispatch arm in `infer_call`

After the `when "append"` arm (~line 900–902), before `when "or_else"` (~line 903):

```ruby
when "append"
  # LANG-STDLIB-COLLECTION-APPEND-PROP-P3: stdlib.collection.append
  infer_append_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
when "is_empty", "non_empty"
  # LANG-STDLIB-IS-EMPTY-PROP-P3: stdlib.collection.is_empty + stdlib.collection.non_empty
  infer_is_empty_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
when "or_else"
  # PROP-043: Option[V] unwrap with default
  infer_or_else(args, symbol_types, type_errors, type_warnings, node_name)
```

### Insertion 2 — Private method `infer_is_empty_call`

After `infer_append_call` ends (~line 2581), before the `# Rule OR-ELSE` comment (~line 2583):

```ruby
    end  # end infer_append_call

    # LANG-STDLIB-IS-EMPTY-PROP-P3: stdlib.collection.is_empty + stdlib.collection.non_empty
    # is_empty(Collection[T]) -> Bool
    # non_empty(Collection[T]) -> Bool
    # Both: pure, total, authority_surface:none. non_empty cannot be derived (unary_op gap).
    # OOF-COL1: arity != 1
    # OOF-COL2: non-Collection, non-Unknown first arg
    # Bool returned on ALL paths including error paths (no Unknown propagation).
    def infer_is_empty_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = fn == "is_empty" ? "stdlib.collection.is_empty" : "stdlib.collection.non_empty"

      # ── OOF-COL1: arity ──────────────────────────────────────────────────────
      unless args.length == 1
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 1 argument (collection), got #{args.length}", node_name)
        return typed_expr("call", type_ir("Bool"), [], "fn" => qualified, "args" => [])
      end

      # ── Infer collection arg ──────────────────────────────────────────────────
      collection_typed = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      col_type_name    = type_name(collection_typed.fetch("resolved_type"))

      # ── OOF-COL2: first arg must be Collection or Unknown ─────────────────────
      unless col_type_name == "Collection" || col_type_name == "Unknown"
        type_errors << oof("OOF-COL2",
          "#{qualified}: first argument must be Collection[T], got #{col_type_name}", node_name)
        return typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_typed])
      end

      typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
                 "fn" => qualified, "args" => [collection_typed])
    end

    # Rule OR-ELSE: or_else(Option[V], V) → V
```

~22 lines — matches P1 estimate of ~20 lines.

---

## Q2 — Shared `infer_is_empty_call` or Two Methods?

**One shared method `infer_is_empty_call`.** The `fn` parameter is passed through from the
`when "is_empty", "non_empty"` dispatch arm. The `qualified` name is derived via:

```ruby
qualified = fn == "is_empty" ? "stdlib.collection.is_empty" : "stdlib.collection.non_empty"
```

Both functions have identical arity (1), identical OOF code set (COL1/COL2), identical return
type (Bool), identical Unknown permissive rule, and identical dep propagation. Splitting them
into two methods would duplicate ~20 lines for no semantic gain. This matches the `infer_fold_call`
precedent — `fold` handles a single named function, but the same principle applies: one method
per logical contract, not one method per source alias.

---

## Q3 — OOF-COL1 Arity Trigger

`args.length != 1` → OOF-COL1.

Message: `"#{qualified}: expected 1 argument (collection), got #{args.length}"`

Early-return with `type_ir("Bool")` result (see Q5 below). Both `is_empty` and `non_empty`
expect exactly 1 argument. The message includes the qualified canonical name so diagnostics
identify which function was misused.

Applies at: `is_empty()` (0 args), `is_empty(a, b)` (2 args), `non_empty()` (0 args), etc.

---

## Q4 — OOF-COL2 Non-Collection Trigger

`col_type_name != "Collection" && col_type_name != "Unknown"` → OOF-COL2.

Message: `"#{qualified}: first argument must be Collection[T], got #{col_type_name}"`

Early-return preserving `collection_typed`'s deps (same pattern as append OOF-COL2 early-return).
Unknown is permissive — no OOF-COL2 on Unknown first arg (consistent with map/filter/count/fold/append).

Applies at: `is_empty(some_string)`, `non_empty(42)`, `is_empty(my_bool)`, etc.

---

## Q5 — Return Type: Always `type_ir("Bool")`

**All paths — including OOF error paths — return `type_ir("Bool")`.**

This differs from `infer_append_call` which returns `type_ir("Unknown")` on OOF-COL1. For a
predicate function, Bool is always the declared output type regardless of argument errors.
Returning Unknown on error would create downstream false OOF-TY0 when the result is used in
an `if` condition or Boolean expression — exactly the use cases `is_empty`/`non_empty` are
designed for.

```ruby
# OOF-COL1 path:
return typed_expr("call", type_ir("Bool"), [], "fn" => qualified, "args" => [])

# OOF-COL2 path:
return typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
                  "fn" => qualified, "args" => [collection_typed])

# Happy path:
typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
           "fn" => qualified, "args" => [collection_typed])
```

---

## Q6 — SIR Names

**Qualified canonical names inline via `qualified` variable.**

```ruby
typed_expr("call", type_ir("Bool"), ..., "fn" => qualified, ...)
```

Where `qualified` is `"stdlib.collection.is_empty"` or `"stdlib.collection.non_empty"`.

The bare names `"is_empty"` / `"non_empty"` MUST NOT appear in any SIR output. The proof
runner must verify that `collect_sir_fns(sir)` returns the qualified name and NOT the bare name
for direct-call fixtures.

Zero emitter changes — the Ruby `semanticir_emitter.rb` preserves the `fn` field as-is.

---

## Q7 — Inventory Entry Timing

**P3 deliverable.** Both entries added to `stdlib-inventory.json` during P3 alongside the Ruby
TC implementation. `stdlib_surface_digest` recomputed after both entries are added.

**`stdlib.collection.is_empty` entry shape:**

```json
{
  "canonical_name": "stdlib.collection.is_empty",
  "semantic_ir_name": "stdlib.collection.is_empty",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "is_empty" }],
  "category": "collection",
  "lifecycle_status": "lab-implemented",
  "semantic_stability": "experiment-pass",
  "lowering_status": "ruby-only",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total",
  "type_params": ["T"],
  "input_signature": ["Collection[T]"],
  "output_signature": "Bool",
  "diagnostics": ["OOF-COL1", "OOF-COL2"],
  "failure_behavior": "none",
  "authority_surface": "none",
  "proof_lineage": [
    "LANG-STDLIB-IS-EMPTY-PROP-P1 proposal authored",
    "LANG-STDLIB-IS-EMPTY-PROP-P2 implementation planning closed",
    "LANG-STDLIB-IS-EMPTY-PROP-P3 Ruby TC implemented"
  ],
  "examples": ["is_empty([]) -> true", "is_empty([1, 2]) -> false"],
  "compatibility_note": "Predicate: Collection[T] → Bool. True iff collection has zero elements at runtime. Pure; total; no authority. OOF-COL1 on arity != 1; OOF-COL2 on non-Collection first arg. Bool returned on all paths. Ruby-only in P3; Rust parity is P4.",
  "owner_surface": "LAB-STDLIB-IS-EMPTY-P1",
  "entry_digest": null
}
```

**`stdlib.collection.non_empty` entry shape:**

```json
{
  "canonical_name": "stdlib.collection.non_empty",
  "semantic_ir_name": "stdlib.collection.non_empty",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "non_empty" }],
  "category": "collection",
  "lifecycle_status": "lab-implemented",
  "semantic_stability": "experiment-pass",
  "lowering_status": "ruby-only",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total",
  "type_params": ["T"],
  "input_signature": ["Collection[T]"],
  "output_signature": "Bool",
  "diagnostics": ["OOF-COL1", "OOF-COL2"],
  "failure_behavior": "none",
  "authority_surface": "none",
  "proof_lineage": [
    "LANG-STDLIB-IS-EMPTY-PROP-P1 proposal authored",
    "LANG-STDLIB-IS-EMPTY-PROP-P2 implementation planning closed",
    "LANG-STDLIB-IS-EMPTY-PROP-P3 Ruby TC implemented"
  ],
  "examples": ["non_empty([1, 2]) -> true", "non_empty([]) -> false"],
  "compatibility_note": "Predicate: Collection[T] → Bool. True iff collection has one or more elements at runtime. Cannot be derived as !is_empty(x) — unary_op not dispatched in infer_expr (LAB-STDLIB-IS-EMPTY-P1 C-03/E-02). Pure; total; no authority. OOF-COL1 on arity != 1; OOF-COL2 on non-Collection first arg. Bool returned on all paths. Ruby-only in P3; Rust parity is P4.",
  "owner_surface": "LAB-STDLIB-IS-EMPTY-P1",
  "entry_digest": null
}
```

**`stdlib_surface_digest`** must be recomputed via Ruby's `canonical_json` + `Digest::SHA256`
after both entries are inserted. The P3 proof runner Section G verifies the stored digest
matches the Ruby-computed value.

---

## Q8 — Why `non_empty` Is a Separate First-Class Entry

Proven conclusively by LAB-STDLIB-IS-EMPTY-P1 checks C-03 and E-02.

`!is_empty(x)` in Igniter source → parser produces `{"kind"=>"unary_op", "op"=>"!", "operand"=>...}`.
This AST node reaches `infer_expr` and falls to the `else` branch →
`OOF-TY0: "Unsupported expression kind: unary_op"`.

The `unary_op` keyword in `typechecker.rb` appears ONLY in:
- `fn_expr_has_call?` — call-graph traversal for SCC analysis
- `fn_collect_calls_expr` — call-graph traversal for SCC analysis

It is NEVER present in the `infer_expr` case dispatch. There is no workaround short of the
verbose `if is_empty(x) { false } else { true }` which compiles but is unidiomatic and
defeats the purpose of a named predicate.

`non_empty` must be implemented as a direct `when "non_empty"` dispatch arm alongside `is_empty`.
The shared `infer_is_empty_call` method distinguishes them by the `fn` parameter — the TC
implementation is free to use one method; the stdlib contract is two independent named functions.

---

## Q9 — No New OOF Codes

OOF-COL1 (arity) and OOF-COL2 (non-Collection first arg) are sufficient.

Both codes are already in use by `count`, `sum`, `fold`, `append`, `map`, `filter` — the full
collection stdlib family. No item-type mismatch check needed (is_empty/non_empty don't inspect
element type T). OOF-COL6 was claimed by append and is not reused here.

No new diagnostic codes are introduced in P3.

---

## Q10 — App Fixture Pressure (4 fixtures — updated by P3 if fixtures are in scope)

| Fixture | Current pattern | After is_empty/non_empty |
|---------|----------------|--------------------------|
| `dsa/sets.ig` SetContains | Returns `Collection[Integer]` because `"we lack is_empty()"` | `is_empty(matches)` → Bool predicate; output `Bool` |
| `dsa/graphs.ig` HasEdge | Returns `Collection[Edge]` with comment "Non-empty implies true" | `non_empty(matches)` → `Bool` output |
| `arch_patterns/state_machine.ig` TryTransition | Optimistic apply documented: `"we lack is_empty()"` | `non_empty(candidates)` guard expressible |
| `bloom_filter/ops.ig` CheckBitAtIndex | `"If matches is non-empty"` — output `Collection[BitSlot]` | `non_empty(matches)` → Bool; output `Bool` |

P3 scope: inline fixture variants verifying the new patterns compile correctly and produce
`output_signature: "Bool"`. Existing app fixture files NOT modified in P3 — real fixture
migration is post-P3 scope (separate card). P3 proof runner Section H uses inline source
strings modeled on the fixture patterns.

---

## Q11 — COLLECTION_HOF_FNS: Not Added

`is_empty` and `non_empty` are NOT added to `COLLECTION_HOF_FNS`.

`COLLECTION_HOF_FNS` is built around higher-order functions that take a lambda argument
(`has_lambda: true` for map/filter; `has_lambda: false` for count but still uses the HOF
infrastructure). The HOF dispatch path in `infer_collection_hof_call` returns element-type-
derived results (Collection[U] for map, Collection[T] for filter, Integer for count).

Adding Bool-returning entries to `COLLECTION_HOF_FNS` would require a `result_type: "Bool"` key
in the hash structure and conditional logic in `infer_collection_hof_call` to choose between
the existing element-type derivation and the new fixed-Bool return. That is a larger change
than needed and the table comment says "Adding entries requires PROP amendment + P4+ authorization."

Direct dispatch arm follows the established precedent of `sum`, `fold`, `append` — all of which
are semantically collection functions but not HOF entries.

---

## Authorized Files for P3

1. `igniter-lang/lib/igniter_lang/typechecker.rb` — two insertions (~22 new lines total)
2. `igniter-lang/docs/spec/stdlib-inventory.json` — two new entries + digest update
3. `igniter-lang/experiments/stdlib_is_empty_proof/verify_stdlib_is_empty_p3.rb` — proof runner (new file, new directory)

**Closed in P3:**
- No emitter changes (Ruby or Rust)
- No parser changes (unary_op gap not closed here)
- No Rust TC changes (P4 scope)
- No app fixture file edits (inline proof fixtures only)
- No COLLECTION_HOF_FNS changes
- No new OOF codes
- No head()/find_one() implementation
- No VM / runtime changes

---

## Q12 — Proof Matrix

≥60 checks / 10 sections.

| Section | Content | Checks |
|---------|---------|--------|
| A (source structure) | `when "is_empty", "non_empty"` arm present; `infer_is_empty_call` defined; OOF-COL1/COL2 in method source; both qualified constants correct; no emitter changes | 6 |
| B (is_empty happy path) | Collection[String] → Bool; SIR fn = "stdlib.collection.is_empty"; bare "is_empty" absent from SIR; deps propagated; Collection[Integer] → Bool; status ok | 8 |
| C (non_empty happy path) | Collection[String] → Bool; SIR fn = "stdlib.collection.non_empty"; bare "non_empty" absent from SIR; status ok | 6 |
| D (OOF-COL1 arity) | 0-arg is_empty → COL1; 2-arg is_empty → COL1; 0-arg non_empty → COL1; message includes qualified name; code = OOF-COL1; Bool returned on error | 6 |
| E (OOF-COL2 non-Collection) | String first arg → COL2; Integer first arg → COL2; Bool first arg → COL2; message includes type name; code = OOF-COL2; Bool returned on error | 6 |
| F (Unknown permissive) | Unknown collection → is_empty no OOF-COL2; Unknown collection → non_empty no OOF-COL2; Bool returned for Unknown input | 4 |
| G (inventory) | is_empty entry exists; non_empty entry exists; both lifecycle=lab-implemented; both output=Bool; both diagnostics=[COL1,COL2]; digest stored == Ruby-computed | 8 |
| H (app fixture pressure) | Inline sets.ig pattern + is_empty → Bool; inline graphs.ig pattern + non_empty → Bool; inline state_machine guard compiles; inline bloom_filter check compiles | 6 |
| I (regression) | map/filter/count/fold/sum/append baselines still pass (no regressions from insertion) | 6 |
| J (authority closed) | no emitter changes; no Rust TC changes; no new OOF codes; no parser changes; no app fixture edits | 4 |

**Total: 60 checks.** Satisfies the P1 requirement of ≥48 checks and the P2 bar of ≥60.

---

## Proof Runner Location

```
igniter-lang/experiments/stdlib_is_empty_proof/verify_stdlib_is_empty_p3.rb
```

New directory. Pattern follows `verify_stdlib_collection_append_p3.rb` — uses inline Ruby
source fixtures compiled through the Ruby TC directly (not through the Rust compiler).

---

## Method Body (Reference)

Full `infer_is_empty_call` body for P3 implementation:

```ruby
def infer_is_empty_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  qualified = fn == "is_empty" ? "stdlib.collection.is_empty" : "stdlib.collection.non_empty"

  unless args.length == 1
    type_errors << oof("OOF-COL1",
      "#{qualified}: expected 1 argument (collection), got #{args.length}", node_name)
    return typed_expr("call", type_ir("Bool"), [], "fn" => qualified, "args" => [])
  end

  collection_typed = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  col_type_name    = type_name(collection_typed.fetch("resolved_type"))

  unless col_type_name == "Collection" || col_type_name == "Unknown"
    type_errors << oof("OOF-COL2",
      "#{qualified}: first argument must be Collection[T], got #{col_type_name}", node_name)
    return typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
                      "fn" => qualified, "args" => [collection_typed])
  end

  typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
             "fn" => qualified, "args" => [collection_typed])
end
```

22 lines. No new helpers required — `type_ir`, `type_name`, `infer_expr`, `typed_expr`, `oof`
all already present throughout the TC.

---

## Closed Surfaces Summary

P2 re-states the P1 closed surfaces. Still closed:

- No `!` (unary_op) operator fix — separate card
- No head()/find_one() — separate cards
- No empty collection literal syntax
- No OOF-COL3/COL4/COL5 activations
- No COLLECTION_HOF_FNS additions
- No VM / runtime / capability authority
- No Rust TC implementation (P4)
- No app fixture file edits (inline proof fixtures only)

---

## Next Route

**LANG-STDLIB-IS-EMPTY-PROP-P3** — bounded Ruby TC implementation proof.

Deliverables:
- Two insertions in `typechecker.rb`: `when "is_empty", "non_empty"` arm + `def infer_is_empty_call` (~22 lines)
- Two inventory entries in `stdlib-inventory.json` + recomputed digest
- Proof runner `verify_stdlib_is_empty_p3.rb` reaching ≥60 checks / 0 failures
- Lab doc + agent card + portfolio entry
