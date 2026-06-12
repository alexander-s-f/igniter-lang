# LANG-STDLIB-IS-EMPTY v0 — stdlib.collection.is_empty / non_empty

**Track:** stdlib / collection / predicate  
**Status:** authored-pending-review  
**Date:** 2026-06-12  
**Route:** PROPOSAL AUTHORING ONLY / NO IMPLEMENTATION  
**Predecessor proof:** LAB-STDLIB-IS-EMPTY-P1 (48/48 PASS — ACCEPT verdict)  
**Predecessor governance:** LANG-STDLIB-FOLD-PROP-P3 (52/52 PASS), LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P3 (61/61 PASS), LANG-STDLIB-ENTRY-CONTRACT-P1/P2/P3

---

## 1. Context and Evidence Base

`LAB-STDLIB-IS-EMPTY-P1` (48/48 PASS) confirmed that `stdlib.collection.is_empty`
and `stdlib.collection.non_empty` are ready for proposal authoring with an ACCEPT
verdict. No HOLD blockers. No SPLIT required. **Both functions must be in the same
proposal — neither can be derived from the other** (see §6).

The readiness proof established:

- **App pressure confirmed** — 3 fixtures, 5 explicit comments:
  - `arch_patterns/state_machine.ig` line 68: `"we'd check candidates is non-empty, but we lack is_empty()"` — `TryTransition` optimistic apply documented
  - `bloom_filter/ops.ig`: `"If matches is non-empty, the bit is set"` — `CheckBitAtIndex` forced to output `Collection[BitSlot]` instead of `Bool`
  - `bloom_filter/ops.ig`: `"we can't call length() or head()"` — emptiness check gap entangled with head() gap
  - `bloom_filter/types.ig`: `"No array index access (no head(), no col[i])"`
  - `decision_tree/evaluator.ig`: `"Without head() we can't extract a single node"` — emptiness guard needed before future extraction
- **Ruby TC:** `is_empty(items)` → `OOF-TY0 "Unknown function: is_empty"` (else arm of `infer_call`). Same for `non_empty`.
- **`!` unary is parsed but not type-checked:** `!x` → `OOF-TY0 "Unsupported expression kind: unary_op"` — `unary_op` is absent from `infer_expr`'s case dispatch (only present in call-graph helpers `fn_expr_has_call?` and `fn_collect_calls_expr`). This is why `non_empty` cannot be derived.
- **OOF-COL1 and OOF-COL2 are sufficient** — no new diagnostic code needed in v0.

---

## 2. Core Principle

**`stdlib.collection.is_empty` and `stdlib.collection.non_empty` are pure cardinality
predicates over a finite collection.**

They do not:
- Access storage, query external systems, or consume capabilities
- Mutate the input collection
- Grant authority or produce side effects of any kind
- Require knowledge of element type T beyond validating that the input is a Collection
- Evaluate lazily or stream

The functions return `Bool` at typecheck time without evaluating runtime cardinality —
the same pattern as `count` returning `Integer` without knowing the actual count.

**`non_empty(xs)` is NOT defined as `!is_empty(xs)` — it is a first-class separate
function.** The `!` (bang) operator is parsed by the Igniter parser but not
type-checked by the TypeChecker. A user cannot write `!is_empty(x)` without getting
`OOF-TY0: "Unsupported expression kind: unary_op"`. The only user-level workaround
is `if is_empty(x) { false } else { true }`, which is verbose and unidiomatic.

---

## 3. Scope of v0

**Accepted (this proposal):**

- `stdlib.collection.is_empty` — `Collection[T] → Bool`; `true` if the collection has zero elements
- `stdlib.collection.non_empty` — `Collection[T] → Bool`; `true` if the collection has at least one element

**Invariant:** `non_empty(xs) == !is_empty(xs)` holds at runtime; this proposal
does not introduce the `!` operator (that is a separate language concern).

**Explicitly excluded from v0:**

- `head()` / `first()` — element extraction; partial function; requires Option[T] wrapper or panic — separate card
- `find_one()` — safe extraction returning `Option[T]` — separate card
- `count(items, pred)` — predicate-count form — separate from this proposal
- `length` / `size` as field accessor — not a function call form
- `empty_collection()` / `collection_empty()` — empty collection construction — separate; requires type parameter resolution
- Any form of mutable collection modification

---

## 4. Canonical Names and Source Aliases

**Canonical names:**

| Entry | Canonical name |
|-------|---------------|
| Is-empty predicate | `stdlib.collection.is_empty` |
| Non-empty predicate | `stdlib.collection.non_empty` |

Both follow the `stdlib.<category>.<fn>` schema.

**Source aliases accepted:**

| Source | Kind | Maps to |
|--------|------|---------|
| `is_empty` | `source_alias` | `stdlib.collection.is_empty` |
| `non_empty` | `source_alias` | `stdlib.collection.non_empty` |

Bare unqualified forms are the expected usage — consistent with `count`, `map`,
`filter`, `fold`, `sum`, `or_else`.

No other aliases introduced. No method syntax. No qualified-only policy.

---

## 5. Signature

Both entries share the same shape:

```
stdlib.collection.is_empty  : Collection[T] → Bool
stdlib.collection.non_empty : Collection[T] → Bool
```

| Parameter | Position | Type | Description |
|-----------|----------|------|-------------|
| collection | arg[0] | `Collection[T]` | Input collection; T is unused beyond validation |
| **result** | — | `Bool` | `true` for empty / non-empty respectively |

**Arity = 1.** Wrong arity → OOF-COL1. Non-Collection first arg → OOF-COL2.

**No lambda, no seed, no symbol.** The simplest possible collection stdlib shape.

**Totality:** total — empty collection is a valid input (`is_empty([]) == true`).

**Result at typecheck time:** `type_ir("Bool")` regardless of collection contents.
The TC cannot and does not evaluate runtime cardinality; it only validates the input type.

---

## 6. Why `non_empty` Cannot Be Derived

This is the central non-obvious design point that distinguishes this proposal from
a single-entry `is_empty` proposal.

### The `!` unary gap

The Igniter parser handles the `!` (bang) operator via `parse_unary` in `parser.rb`:

```ruby
def parse_unary
  if peek_type?(:bang)
    op = advance.value
    expr = parse_postfix
    return { "kind" => "unary_op", "op" => op, "operand" => expr }
  end
  parse_postfix
end
```

This produces a `{"kind" => "unary_op", "op" => "!", "operand" => ...}` AST node.
**But `infer_expr` in `typechecker.rb` has no `when "unary_op"` arm.** The node
falls through to the `else` branch:

```ruby
else
  type_errors << oof("OOF-TY0", "Unsupported expression kind: #{expr.fetch("kind")}", node_name)
  typed_expr("unsupported", type_ir("Unknown"), [], "source_kind" => expr.fetch("kind"))
end
```

Result: `OOF-TY0: "Unsupported expression kind: unary_op"`.

Proven by LAB-STDLIB-IS-EMPTY-P1 proof checks C-03 / E-02 / E-03.

### The if/else workaround

The only user-level workaround is:

```igniter
compute negated = if is_empty(items) { false } else { true }
```

This compiles cleanly (the if/else Bool-return pattern works). But it is verbose
and unidiomatic for a predicate that should be a direct function call. The `non_empty`
pressure in app fixtures is clear — `bloom_filter/ops.ig` and `arch_patterns/state_machine.ig`
express the concept with the word "non-empty" directly.

### Design consequence

`non_empty` is a first-class separate entry — not a note, not a workaround alias, not
a future P3 concern. It must be authored and implemented alongside `is_empty`.

The runtime invariant `non_empty(xs) == !is_empty(xs)` holds but cannot be expressed
in Igniter today, making both functions independently necessary.

---

## 7. Diagnostics

No new OOF codes are required in v0.

| Error condition | Code | Notes |
|----------------|------|-------|
| Wrong arity (not exactly 1 arg) | OOF-COL1 | Existing; used by count, map, filter, append |
| Non-Collection, non-Unknown first arg | OOF-COL2 | Existing; used by count, map, filter, append |

**OOF-COL6** is already claimed by `stdlib.collection.append`
(LANG-STDLIB-COLLECTION-APPEND-PROP-P1 proposal) for the item-type-mismatch
diagnostic. `is_empty` and `non_empty` do not use it — they have no item type
constraint (T is unconstrained).

Unknown-permissive rule: if the first arg type is Unknown, both functions return
`type_ir("Bool")` with no error — same permissive pattern as count/map/filter.

---

## 8. Entry Contracts

### stdlib.collection.is_empty

```json
{
  "canonical_name": "stdlib.collection.is_empty",
  "semantic_ir_name": "stdlib.collection.is_empty",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "is_empty" }],
  "category": "collection",
  "lifecycle_status": "proof-local",
  "semantic_stability": "experiment-pass",
  "lowering_status": "none",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total: empty collection returns true; non-empty returns false",
  "type_params": ["T"],
  "input_signature": ["Collection[T]"],
  "output_signature": "Bool",
  "diagnostics": ["OOF-COL1", "OOF-COL2"],
  "failure_behavior": "none; arity mismatch → OOF-COL1; non-Collection first arg → OOF-COL2",
  "authority_surface": "none",
  "proof_lineage": [
    "LAB-STDLIB-IS-EMPTY-P1 (48/48 PASS — ACCEPT verdict)",
    "arch_patterns/state_machine.ig: 'we lack is_empty()' comment (line 68)",
    "bloom_filter/ops.ig: 'If matches is non-empty, the bit is set'",
    "decision_tree/evaluator.ig: emptiness guard needed before head()"
  ],
  "examples": [
    "is_empty([]) -> true",
    "is_empty([1, 2, 3]) -> false",
    "is_empty(filter(items, x -> x.active)) -> Bool"
  ],
  "compatibility_note": "Bare source alias 'is_empty' accepted. 1-arg; no lambda; no symbol. OOF-COL1 for arity != 1; OOF-COL2 for non-Collection first arg. Unknown input → Bool result (permissive). Ruby TC currently emits OOF-TY0 'Unknown function: is_empty'. Dual non_empty sibling required (! unary not type-checked; OOF-TY0 unary_op gap proven in P1).",
  "owner_surface": "LANG-STDLIB-IS-EMPTY-PROP-P1",
  "entry_digest": null
}
```

### stdlib.collection.non_empty

```json
{
  "canonical_name": "stdlib.collection.non_empty",
  "semantic_ir_name": "stdlib.collection.non_empty",
  "legacy_sir": null,
  "aliases": [{ "kind": "source_alias", "name": "non_empty" }],
  "category": "collection",
  "lifecycle_status": "proof-local",
  "semantic_stability": "experiment-pass",
  "lowering_status": "none",
  "compatibility_status": "pre-v1-none",
  "fragment_class": "core",
  "purity": "pure",
  "deterministic": true,
  "totality": "total: empty collection returns false; non-empty returns true",
  "type_params": ["T"],
  "input_signature": ["Collection[T]"],
  "output_signature": "Bool",
  "diagnostics": ["OOF-COL1", "OOF-COL2"],
  "failure_behavior": "none; arity mismatch → OOF-COL1; non-Collection first arg → OOF-COL2",
  "authority_surface": "none",
  "proof_lineage": [
    "LAB-STDLIB-IS-EMPTY-P1 (48/48 PASS — ACCEPT verdict)",
    "arch_patterns/state_machine.ig: 'candidates is non-empty' guard needed",
    "bloom_filter/ops.ig: 'If matches is non-empty' — direct pressure"
  ],
  "examples": [
    "non_empty([]) -> false",
    "non_empty([1, 2, 3]) -> true",
    "non_empty(filter(candidates, t -> t.from_status == current)) -> Bool"
  ],
  "compatibility_note": "Bare source alias 'non_empty' accepted. 1-arg; no lambda; no symbol. Structurally identical to is_empty; semantically inverted. NOT derivable as !is_empty(x) — Igniter's unary ! operator (bang) is parsed but not type-checked: 'unary_op' is absent from infer_expr's case dispatch → OOF-TY0 'Unsupported expression kind: unary_op'. Requires independent dispatch and implementation alongside is_empty.",
  "owner_surface": "LANG-STDLIB-IS-EMPTY-PROP-P1",
  "entry_digest": null
}
```

**Critical invariant check (both entries):** `semantic_ir_name == canonical_name` ✓  
**No legacy_sir:** Ruby TC currently emits `OOF-TY0 "Unknown function: is_empty/non_empty"` — no prior stable SIR name.

---

## 9. Questions Answered

### Q1. Helper name: `is_empty`, `non_empty`, or `count == 0`?

**`is_empty`** — the app fixtures literally say `"we lack is_empty()"`. `count == 0` is
not expressible: `count(items) == 0` would require the `==` operator on Integer, which
the TC handles but emits Unknown for non-Integer comparisons, and even with Integer
`count`, the user would need to write `count(items) == 0` which is more verbose and
semantically indirect. `is_empty` as a named predicate is the correct form.

`non_empty` must be a first-class sibling — see Q8.

### Q2. Canonical names?

`stdlib.collection.is_empty` and `stdlib.collection.non_empty`. Both follow the
`stdlib.<category>.<fn>` schema established for all stdlib entries.

### Q3. Type: `Collection[T] → Bool`?

**Yes.** Both entries:
- Input: `Collection[T]` (T unconstrained — only the cardinality matters)
- Output: `Bool` (pure, deterministic)
- TC emits `type_ir("Bool")` at typecheck time regardless of runtime cardinality

### Q4. Empty collection construction: blocked or required?

**Not blocked.** `is_empty` and `non_empty` test collections they *receive* as input —
they do not require constructing an empty collection. `filter(items, x -> false)` can
simulate a runtime-empty collection in fixtures without requiring empty literal syntax.

### Q5. Does it need runtime cardinality?

**No — pure over collection value, no external state.** At typecheck time the TC
returns `type_ir("Bool")` without evaluating cardinality (same as `count` returning
`Integer` without knowing the actual count). At VM runtime, the implementation
evaluates `collection.len() == 0` / `collection.len() > 0` — pure and deterministic.

### Q6. OOF-COL code?

**No new code in v0.** OOF-COL1 (arity check: must be exactly 1 arg) and OOF-COL2
(non-Collection first arg) are sufficient — the same two codes `count` uses for the
same structural reasons. OOF-COL6 is already claimed by the `stdlib.collection.append`
proposal for item-type mismatch; `is_empty`/`non_empty` have no item type constraint.

### Q7. Relationship to `find_one` / `head`?

`is_empty` and `non_empty` are **guard primitives** that semantically enable safe
usage of future `head()` and `find_one()`:

- `is_empty(xs)` → Bool: cardinality predicate only; no element extraction
- `head(xs)` → T: partial element extraction; panics on empty — future card; needs `is_empty` guard
- `find_one(xs, pred)` → Option[T]: safe extraction via Option — future card; orthogonal

The relationship is sequential dependency: `is_empty` unlocks guard-guarded `head()`
patterns. But `head()` is NOT required for `is_empty` — they are separate proposals.

### Q8. Should `non_empty` be separate or derived?

**MUST be separate.** See §6 for the full argument. Summary:

1. `!is_empty(x)` → `OOF-TY0 "Unsupported expression kind: unary_op"` — the `!`
   operator is parsed but absent from `infer_expr`'s case dispatch
2. If/else workaround compiles but is verbose and unidiomatic
3. App fixtures use the word "non-empty" directly — the concept has independent pressure

`non_empty` is not a convenience alias or a future P4 concern. It is a first-class
entry required in the same proposal.

---

## 10. Toolchain Status

### Ruby TypeChecker (canon — `igniter-lang/lib/igniter_lang/typechecker.rb`)

| Operation | Current State | P2 Action |
|-----------|--------------|-----------|
| `is_empty` (regular call) | `OOF-TY0 "Unknown function: is_empty"` | Add dispatch arm + `infer_is_empty_call` |
| `non_empty` (regular call) | `OOF-TY0 "Unknown function: non_empty"` | Same method handles both |

**Readiness preconditions confirmed (all from P3 map/filter/fold work):**
- `element_type_from_collection` — exists; but not needed here (T unconstrained)
- `type_ir("Bool")` — used by `map_has_key`, `contains`, `starts_with`; no new primitive
- `infer_expr` / `typed_expr` / `oof` — standard helpers; no changes needed
- `COLLECTION_HOF_FNS` — established pattern; `is_empty`/`non_empty` may or may not go here (P2 decision)

**Implementation shape (P2 decision):**

Both `is_empty` and `non_empty` have arity=1, no lambda, `Collection[T] → Bool`.
They fit the COLLECTION_HOF_FNS structural shape (`has_lambda: false`, same as `count`),
but `count` is already special-cased in `infer_collection_hof_call` to return Integer
rather than Bool. Adding `is_empty`/`non_empty` to `COLLECTION_HOF_FNS` would require
a `result_type` key in the hash structure.

The cleaner approach — consistent with `sum` and `fold` — is a direct dispatch arm:

```ruby
when "is_empty", "non_empty"
  infer_is_empty_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

With a shared private method (~20 lines):

```ruby
def infer_is_empty_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  qualified = fn == "is_empty" ? "stdlib.collection.is_empty" : "stdlib.collection.non_empty"

  unless args.length == 1
    type_errors << oof("OOF-COL1",
      "#{qualified}: expected 1 argument (collection), got #{args.length}",
      node_name)
    return typed_expr("call", type_ir("Bool"), [], "fn" => qualified, "args" => [])
  end

  collection_typed = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  col_type_name    = type_name(collection_typed.fetch("resolved_type"))

  unless col_type_name == "Collection" || col_type_name == "Unknown"
    type_errors << oof("OOF-COL2",
      "#{qualified}: first argument must be Collection[T], got #{col_type_name}",
      node_name)
    return typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
                      "fn" => qualified, "args" => [collection_typed])
  end

  typed_expr("call", type_ir("Bool"), collection_typed.fetch("deps", []),
             "fn" => qualified, "args" => [collection_typed])
end
```

**SIR fn emission:** `"fn" => qualified` where `qualified` is the canonical name.
The generic `semantic_expr` in `semanticir_emitter.rb` preserves the `fn` field verbatim.
`semantic_ir_name == canonical_name` is satisfied automatically. Zero emitter changes.

**Insertion point:** After `when "fold"` arm and before `when "or_else"` in `infer_call`.
After `infer_fold_call` and before `infer_or_else` in the private methods section.
Exact lines determined in P2 planning.

### Rust TypeChecker (lab — `igniter-lab/igniter-compiler/src/typechecker.rs`)

| Entry | Current State |
|-------|-------------|
| `is_empty` | No dispatch; falls to unknown-function error |
| `non_empty` | No dispatch; falls to unknown-function error |

Rust parity is out of scope for v0 proposal and P2/P3 Ruby implementation.
Rust parity is a P4 scope item (same pattern: LANG-STDLIB-COLLECTION-MAP-FILTER-PROP-P4
handled Rust parity for map/filter/count after Ruby P3 was proven).

---

## 11. Design Decisions Locked

1. **Canonical names:** `stdlib.collection.is_empty` and `stdlib.collection.non_empty`
2. **Source aliases:** bare `is_empty` / `non_empty` — consistent with all other collection stdlib entries
3. **Both functions in same proposal** — `non_empty` is non-derivable; both have independent app pressure
4. **Signature:** `Collection[T] → Bool`; arity = 1; T unconstrained
5. **Totality:** total — empty collection is a valid and expected input
6. **Result at typecheck time:** `type_ir("Bool")` — TC does not evaluate runtime cardinality
7. **OOF-COL1** for arity mismatch (wrong number of args)
8. **OOF-COL2** for non-Collection first arg — Unknown passes permissively
9. **No new OOF code** — OOF-COL6 is already claimed by append; not needed here
10. **Dispatch shape:** direct `when "is_empty", "non_empty"` arm + shared `infer_is_empty_call` (P2 confirms)
11. **`semantic_ir_name == canonical_name`** — no `legacy_sir`; no emitter changes needed
12. **Inventory edits deferred to P2/P3** — entry contracts defined here; file edit after Ruby implementation proof
13. **`head()` and `find_one()` are separate cards** — is_empty does not enable or require them
14. **`!` operator gap is NOT fixed by this proposal** — adding `non_empty` works around the gap without addressing it
15. **No COLLECTION_HOF_FNS extension** — direct dispatch arm is cleaner given Bool result type divergence from existing entries

---

## 12. Authority Closed

- No Ruby TypeChecker implementation (P2 scope)
- No `head()` / `find_one()` implementation
- No `!` (bang/negation) operator implementation
- No Rust TypeChecker changes
- No VM/runtime changes
- No `stdlib-inventory.json` file edits (P2/P3 scope)
- No `COLLECTION_HOF_FNS` structural changes (P2 decision to confirm)
- No app fixture changes
- No new OOF codes
- No `empty_collection()` constructor
- No `count(items, pred)` predicate form
- No public compatibility promise beyond this proposal

---

## 13. Next Routes

**Primary:**  
`LANG-STDLIB-IS-EMPTY-PROP-P2` — Implementation planning for Ruby TC dispatch.  
Authorized files: `typechecker.rb` only.  
Proof matrix target: ≥48 checks across sections:
- A: regression (string_core + typed_ref_p5 + stdlib_outcome_p3 + collection_HOF 61/61 + fold 52/52)
- B: is_empty basics (happy path / returns Bool / Unknown permissive)
- C: non_empty basics (happy path / returns Bool / Unknown permissive)
- D: OOF-COL1 (arity: both functions, various wrong-arity cases)
- E: OOF-COL2 (non-Collection first arg: both functions)
- F: SIR names (`fn == "stdlib.collection.is_empty"` / `fn == "stdlib.collection.non_empty"` in SIR)
- G: App fixture pressure (state_machine candidates / bloom_filter matches — OOF-TY0 gone)
- H: Authority closed (no new OOF / no head / no find_one / no ! operator / no Rust)

**Parallel tracks (unblocked):**
- `LANG-STDLIB-FOLD-PROP-P4` — fold inventory amendment + Rust parity
- `LANG-STDLIB-COLLECTION-APPEND-PROP-P3` — append Ruby implementation proof
