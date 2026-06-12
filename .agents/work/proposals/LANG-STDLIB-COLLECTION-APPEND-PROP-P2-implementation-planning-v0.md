# LANG-STDLIB-COLLECTION-APPEND-PROP-P2
## Implementation Planning — Ruby TC `stdlib.collection.append`

**Lane:** lang / stdlib / collection / append  
**Mode:** IMPLEMENTATION PLANNING ONLY — no code changes  
**Status:** CLOSED — READY FOR P3  
**Date:** 2026-06-12  
**Grounded by:** LANG-STDLIB-COLLECTION-APPEND-P1 (proposal + entry contract)  
**Next route:** LANG-STDLIB-COLLECTION-APPEND-PROP-P3 (Ruby TC implementation proof)

---

## Planning Decision: READY FOR P3

No SPLIT. No HOLD. The append contract is stable (P1 closed), the insertion point is clear,
the OOF code set (COL1/COL2/COL6) is fully defined, and the helper infrastructure already
exists (`element_type_from_collection`, `collection_type_ir_from`). P3 is a single-file
change (~38 lines in `typechecker.rb`) with one inventory entry added.

---

## Q1 — Exact Ruby TC Insertion Point

**Two insertions in `typechecker.rb`:**

### Insertion 1 — Dispatch arm in `infer_call`

After the `when "fold"` arm (~line 897), before `when "or_else"` (~line 900):

```ruby
when "fold"
  # LANG-STDLIB-FOLD-PROP-P1/P3: stdlib.collection.fold — accumulator HOF
  infer_fold_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
when "append"
  # LANG-STDLIB-COLLECTION-APPEND-PROP-P3: stdlib.collection.append
  infer_append_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
when "or_else"
  # ...
```

### Insertion 2 — Private method `infer_append_call`

After `infer_fold_call` ends (~line 2524), before the `# Rule OR-ELSE` comment (~line 2526):

```ruby
    end  # end infer_fold_call

    # LANG-STDLIB-COLLECTION-APPEND-PROP-P3: stdlib.collection.append
    # append(Collection[T], T) -> Collection[T]
    # OOF-COL1: arity != 2
    # OOF-COL2: non-Collection first arg
    # OOF-COL6: item type concrete mismatch (both concrete, different)
    # Unknown permissive on both sides.
    def infer_append_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
      qualified = "stdlib.collection.append"

      # ── OOF-COL1: arity ──────────────────────────────────────────────────────
      unless args.length == 2
        type_errors << oof("OOF-COL1",
          "#{qualified}: expected 2 arguments, got #{args.length}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified, "args" => [])
      end

      # ── Infer collection arg ──────────────────────────────────────────────────
      collection_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
      col_type_name  = type_name(collection_arg.fetch("resolved_type"))

      # ── OOF-COL2: first arg must be Collection or Unknown ─────────────────────
      unless col_type_name == "Collection" || col_type_name == "Unknown"
        type_errors << oof("OOF-COL2",
          "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
          node_name)
        return typed_expr("call", type_ir("Unknown"), collection_arg.fetch("deps", []),
                          "fn" => qualified, "args" => [collection_arg])
      end

      # ── Infer item arg ────────────────────────────────────────────────────────
      item_arg  = infer_expr(args[1], symbol_types, type_errors, type_warnings, node_name)
      elem_type = element_type_from_collection(collection_arg.fetch("resolved_type"))
      elem_name = type_name(elem_type)
      item_name = type_name(item_arg.fetch("resolved_type"))

      # ── OOF-COL6: concrete type mismatch (Unknown permissive) ─────────────────
      unless elem_name == "Unknown" || item_name == "Unknown" || elem_name == item_name
        type_errors << oof("OOF-COL6",
          "#{qualified}: item type #{item_name} does not match collection element type #{elem_name}",
          node_name)
      end

      all_deps = (collection_arg.fetch("deps", []) + item_arg.fetch("deps", [])).uniq
      typed_expr("call", collection_type_ir_from(elem_type), all_deps,
                 "fn" => qualified, "args" => [collection_arg, item_arg])
    end

    # Rule OR-ELSE: ...
```

~38 lines — matches P1 estimate.

---

## Q2 — Separate Arm or Part of HOF Table?

**Separate `when "append"` arm with dedicated `def infer_append_call`.** Not added to
`COLLECTION_HOF_FNS`.

Reasons:
- `COLLECTION_HOF_FNS` is HOF-specific: it is built around lambda inference
  (`has_lambda`, `infer_lambda_body`, element binding). Append takes an item, not a lambda.
- Adding append to the HOF table would require special-casing OOF-COL6 inside a
  lambda-centric dispatch path — wrong abstraction layer.
- `sum` and `fold` are also separate arms with dedicated methods. Append follows the same pattern.
- The `COLLECTION_HOF_FNS` comment explicitly says "Adding entries requires PROP amendment
  + P4+ authorization" — that gate is for HOF entries only. Append is a non-HOF collection op.
- Separation makes the OOF-COL6 logic local and visible, not buried in a shared method.

---

## Q3 — How to Read Element Type from Collection[T]

Use the existing `element_type_from_collection(collection_arg.fetch("resolved_type"))` helper
at [typechecker.rb:1845](../../lib/igniter_lang/typechecker.rb).

```ruby
def element_type_from_collection(collection_type)
  return type_ir("Unknown") unless collection_type.is_a?(Hash)
  params = collection_type.fetch("params", [])
  first  = params.first
  return type_ir("Unknown") unless first
  first.is_a?(Hash) ? first : type_ir(first.to_s)
end
```

Returns `type_ir("Unknown")` when the collection has no resolved type params (e.g., Unknown
collection). Same helper used in map/filter (`infer_collection_hof_call`) and fold
(`infer_fold_call`) — no new infrastructure.

---

## Q4 — Return Type Shape

`collection_type_ir_from(elem_type)` where `elem_type` is extracted from the input collection.

```ruby
typed_expr("call", collection_type_ir_from(elem_type), all_deps, ...)
```

The output collection preserves the element type of the input: `append(Collection[T], T) →
Collection[T]`. When the input collection has Unknown element type, `elem_type` is
`type_ir("Unknown")` and the return type is `Collection[Unknown]`.

`collection_type_ir_from` at [typechecker.rb:2860](../../lib/igniter_lang/typechecker.rb):

```ruby
def collection_type_ir_from(elem_type_ir)
  { "name" => "Collection", "params" => [elem_type_ir.is_a?(Hash) ? elem_type_ir : type_ir(elem_type_ir.to_s)] }
end
```

No new infrastructure required.

---

## Q5 — OOF-COL1 Trigger

`args.length != 2` → OOF-COL1.

Message: `"stdlib.collection.append: expected 2 arguments, got #{args.length}"`

Early-return with `type_ir("Unknown")` result after emitting the error. Matches the pattern
of all other collection ops. Bootstrap calls via `call_contract` do NOT go through this path —
they bypass `infer_call` entirely.

---

## Q6 — OOF-COL2 Trigger

`col_type_name != "Collection" && col_type_name != "Unknown"` → OOF-COL2.

Message: `"stdlib.collection.append: first argument must be Collection[T], got #{col_type_name}"`

Early-return preserving `collection_arg`'s deps. Unknown is permissive (no error). Same
guard used in map, filter, count, sum, fold.

---

## Q7 — OOF-COL6 Concrete Item Mismatch

After inferring both the collection and the item:

```ruby
elem_name = type_name(elem_type)   # from element_type_from_collection
item_name = type_name(item_arg.fetch("resolved_type"))

unless elem_name == "Unknown" || item_name == "Unknown" || elem_name == item_name
  type_errors << oof("OOF-COL6",
    "#{qualified}: item type #{item_name} does not match collection element type #{elem_name}",
    node_name)
end
```

OOF-COL6 fires ONLY when:
- `elem_name` is not "Unknown", AND
- `item_name` is not "Unknown", AND
- `elem_name != item_name`

OOF-COL6 is non-early-return: the error is recorded but inference continues and returns
`collection_type_ir_from(elem_type)` (preserving the declared collection type, not corrupting it).

Note: OOF-COL6 was reserved in P1. It is first activated here in P3. The inventory entry
for P3 must include `"OOF-COL6"` in its `diagnostics` array.

---

## Q8 — Unknown Permissive Rule

If either side of the type comparison is Unknown, skip OOF-COL6:

- `elem_name == "Unknown"`: collection has unknown element type (e.g., result of an
  unresolved call). No mismatch check — permissive.
- `item_name == "Unknown"`: item type could not be resolved. No mismatch check — permissive.
- Both Unknown: also permissive.

This matches the "Unknown is always permissive" rule applied throughout the collection family
(OOF-COL2: `col_type_name == "Unknown"` passes; OOF-COL3: `pred_name == "Unknown"` passes;
fold body mismatch: `body_name == "Unknown" || acc_name == "Unknown"` passes).

---

## Q9 — Canonical SIR Name

`"stdlib.collection.append"` — the `"fn"` field in the emitted `typed_expr` call:

```ruby
typed_expr("call", collection_type_ir_from(elem_type), all_deps,
           "fn" => qualified, "args" => [collection_arg, item_arg])
```

The Ruby `semanticir_emitter.rb` already preserves the `fn` field as-is (no bare-name
rewriting step in the Ruby path — the qualified name comes directly from the TC method).
Zero emitter changes needed for Ruby P3.

The bare name `"append"` MUST NOT appear in any SIR output. The proof runner must verify
that `collect_sir_fns(sir)` returns `"stdlib.collection.append"` and does NOT return
`"append"` for direct-call fixtures.

---

## Q10 — Relationship to Bootstrap Form

Bootstrap form: `call_contract("append", item_a, item_b)` where both args are non-Collection.

**This form is outside the canonical type and is NOT handled by `infer_append_call`.**

`call_contract(...)` calls use a different dispatch path in the TC. They do not reach
`infer_call` for the named function. Therefore `infer_append_call` never sees the bootstrap
form — it will never fire OOF-COL2 or OOF-COL6 on a bootstrap call.

**Consequence:** If `append(item_a, item_b)` is called DIRECTLY (not via `call_contract`),
it WILL reach `infer_append_call` and WILL fire OOF-COL2 (first arg not Collection). This
is correct behavior — the canonical type is `Collection[T] × T`, not `T × T`. The bootstrap
pattern is an acknowledged call_contract escape hatch that will be superseded by
`stdlib.collection.empty` (out of scope for this track).

**P3 proof must verify:** `call_contract("append", ...)` still compiles without OOF errors
(bootstrap unchanged). The P3 runner Section G covers this with 4 checks.

---

## Q11 — Inventory Entry Timing

**P3 deliverable.** The inventory entry for `stdlib.collection.append` is added during P3,
alongside the Ruby TC implementation.

**Entry shape:**

```json
{
  "canonical_name": "stdlib.collection.append",
  "lifecycle_status": "lab-implemented",
  "lowering_status": "ruby-only",
  "semantic_stability": "experiment-pass",
  "fragment_class": "core",
  "purity": "pure",
  "authority_surface": "none",
  "type_params": ["T"],
  "input_signature": ["Collection[T]", "T"],
  "output_signature": "Collection[T]",
  "aliases": [{"kind": "source_alias", "name": "append"}],
  "diagnostics": ["OOF-COL1", "OOF-COL2", "OOF-COL6"],
  "proof_lineage": [
    {"proof": "LANG-STDLIB-COLLECTION-APPEND-P1", "status": "authored"},
    {"proof": "LANG-STDLIB-COLLECTION-APPEND-P2", "status": "planning"},
    {"proof": "LANG-STDLIB-COLLECTION-APPEND-P3", "status": "proved"}
  ]
}
```

**Why P3:** Adding the entry at P3 time makes `stdlib.collection.append` a known inventory
name. Once Import Surface P3 is live, this unblocks `import stdlib.collection.{ append }`.
The P5-style separate inventory pass is not needed here — P3 is the first implementation,
and the entry is simple (no dual-toolchain lowering to reconcile yet).

**`stdlib_surface_digest` must be recomputed** using Ruby's `canonical_json` +
`Digest::SHA256` after adding the entry. The P3 proof runner Section H verifies the stored
digest matches the Ruby-computed value.

---

## Authorized Files for P3

1. `igniter-lang/lib/igniter_lang/typechecker.rb` — two insertions (~38 new lines)
2. `igniter-lang/docs/spec/stdlib-inventory.json` — one new entry + digest update
3. `igniter-lang/experiments/stdlib_collection_append_proof/verify_stdlib_collection_append_p3.rb` — proof runner (new file)

**Closed in P3:**
- No emitter changes (Ruby or Rust)
- No parser changes
- No Rust TC changes (P4 scope)
- No app fixture changes
- No `stdlib.collection.empty` / collection literals
- No `concat` changes
- No `call_contract` changes
- No VM / runtime changes

---

## Rust P4 Scope (planning only — not P3)

For reference, the Rust parity work expected in P4:

1. **`typechecker.rs`**: Add `"append"` match arm analogous to the `"map"` arm. OOF-COL1
   (`args.len() != 2`), OOF-COL2 (non-Collection first arg), OOF-COL6 (concrete mismatch).

2. **`emitter.rs`**: Add `("append", "stdlib.collection.append")` to `COLLECTION_HOF_OPS`
   table. Add `|| matches!(fn_val, "map" | "filter" | "count" | "append")` to the
   `TEXT_STDLIB_OPS_C` delegation guard in `semantic_expr_for_compute`.

3. **Inventory update**: Change `lowering_status` from `"ruby-only"` to `"dual-toolchain"`.
   Recompute digest.

---

## Q12 — Proof Matrix

≥60 checks / 10 sections.

| Section | Content | Checks |
|---------|---------|--------|
| A (source structure) | `when "append"` arm present; `infer_append_call` defined; OOF-COL1/COL2/COL6 in method source; qualified constant set correctly; no emitter changes | 8 |
| B (OOF-COL1) | 0 args → OOF-COL1; 1 arg → OOF-COL1; 3 args → OOF-COL1 (message content, code, status ok for each) | 6 |
| C (OOF-COL2) | String first arg → OOF-COL2; Integer first arg → OOF-COL2; Bool first arg → OOF-COL2 (code, message) | 6 |
| D (OOF-COL6) | Collection[String] + Integer item → OOF-COL6; Collection[Integer] + String item → OOF-COL6; mismatch type names in message; status still ok | 6 |
| E (Unknown permissive) | Unknown collection + typed item → no OOF-COL6; typed collection + Unknown item → no OOF-COL6; both Unknown → no errors; no false OOF-COL2 on Unknown collection | 5 |
| F (happy path) | Collection[String] + String → ok; SIR fn = "stdlib.collection.append"; bare "append" NOT in SIR; return type = Collection[String]; Collection[Integer] + Integer → Collection[Integer] | 8 |
| G (bootstrap unchanged) | `call_contract("append", ...)` T×T form still compiles; no OOF-COL1/COL2/COL6 from bootstrap path; existing app fixture smoke ok | 4 |
| H (inventory) | entry exists with canonical_name; lifecycle=lab-implemented; lowering=ruby-only; aliases=[{source_alias, "append"}]; OOF-COL6 in diagnostics; digest stored == Ruby-computed | 8 |
| I (authority closure) | no emitter.rb changes; no Rust source changes; no parser changes; no capability claim; no new import authority; no app fixture edits | 6 |
| J (regression) | map/filter/count/fold/sum baseline checks still pass (representative sample) | 8 |

**Total: 65 checks.** Satisfies P1 requirement of ≥50 checks and standard P2 bar of ≥60.

---

## Proof Runner Location

```
igniter-lang/experiments/stdlib_collection_append_proof/verify_stdlib_collection_append_p3.rb
```

Pattern follows `verify_stdlib_collection_map_filter_p3.rb` — uses inline Ruby source
fixtures compiled through the Ruby TC directly (not through the Rust compiler).

---

## Closed Surfaces Summary

P2 re-states the P1 closed surfaces. Still closed:

- No `stdlib.collection.empty` / collection literal syntax
- No concat changes
- No `fold`/`sum`/`map`/`filter` changes
- No OOF-COL3/COL4/COL5 activations
- No VM / runtime / capability authority
- No Rust TC implementation (P4)
- No inventory entry before P3 implementation is proved
- No app fixture edits

---

## Next Route

**LANG-STDLIB-COLLECTION-APPEND-PROP-P3** — bounded Ruby TC implementation proof.

Deliverables:
- Two insertions in `typechecker.rb`: `when "append"` arm + `def infer_append_call` (~38 lines)
- One inventory entry in `stdlib-inventory.json` + recomputed digest
- Proof runner `verify_stdlib_collection_append_p3.rb` reaching ≥65 checks / 0 failures
- Lab doc + agent card + proposals README row + portfolio entry
