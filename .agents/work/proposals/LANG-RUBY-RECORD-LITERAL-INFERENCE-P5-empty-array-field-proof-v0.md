# LANG-RUBY-RECORD-LITERAL-INFERENCE-P5: Empty Array Field Proof

**Status:** CLOSED — 29/29 PASS
**Date:** 2026-06-13
**Proof:** `igniter-lang/experiments/record_literal_inference_proof/verify_record_literal_inference_p4.rb`
**Scope:** `typechecker.rb` only — one method + one clause in `infer_record_literal`
**Pressure resolved:** SIM-P14 (sim_framework `initial_state` empty arrays)

---

## Problem

P3 structural candidate matching reused the strict `structurally_assignable?` policy for
record literal field compatibility. This policy correctly rejects `Collection[Unknown]` at
the **output boundary** — but inside a record literal, an empty array literal (`[]`) infers
as `Collection[Unknown]` and should be accepted as a field-local wildcard for any
`Collection[T]` of matching arity.

The concrete trigger: `sim_framework/example.ig` — `RunEcosystemSim.initial_state`:

```
compute initial_state = {
  tick: 0,
  entities: [wolves, rabbits, deer, bears],
  events: [],          -- Collection[Unknown]
  proofs: [],          -- Collection[Unknown]
  violations: []       -- Collection[Unknown]
}
```

`SimState` expected `Collection[SimEvent]`, `Collection[ProofEntry]`,
`Collection[ConstraintViolation]`. The strict check rejected `SimState` as a candidate →
`initial_state` resolved to `Unknown` → downstream `call_contract` cascade.

---

## Implementation

**File:** `igniter-lang/lib/igniter_lang/typechecker.rb`

### 1. New helper method (inserted after `structural_mismatch`)

```ruby
# True when `actual` is a parameterised Collection whose params are all Unknown —
# the "empty array literal" shape — and `expected` is a Collection of the same arity.
# Used only inside record literal structural candidate matching so that [] is accepted
# as a field-local wildcard. The output boundary continues to use the strict
# structurally_assignable? policy and is unaffected by this helper.
def empty_collection_assignable?(actual, expected)
  return false unless type_name(actual) == "Collection" && type_name(expected) == "Collection"
  ap = actual.fetch("params",   [])
  ep = expected.fetch("params", [])
  return false unless ap.length == ep.length && !ap.empty?
  ap.all? { |p| type_name(p) == "Unknown" }
end
```

### 2. Updated field compatibility check in `infer_record_literal` candidates block

```ruby
# BEFORE
type_name(act_type) == "Unknown" || structurally_assignable?(act_type, exp_type)

# AFTER
type_name(act_type) == "Unknown" ||
  structurally_assignable?(act_type, exp_type) ||
  empty_collection_assignable?(act_type, exp_type)
```

---

## Safety Properties

- `structurally_assignable?` body is **unchanged** — output boundary strictness preserved.
- `empty_collection_assignable?` is called **only** from the structural candidate filter
  inside `infer_record_literal`.
- Accepts Collection[Unknown] only when actual and expected outer names are both
  "Collection" and all actual params are Unknown. A partially-typed collection or
  non-Collection parameterised type is not affected.
- Ambiguity behavior unchanged — if two shapes have the same field names and both pass
  the relaxed check, OOF-TY0 fires as before.
- Hint path (annotated compute / same-name output) unchanged — it already accepted
  Collection[Unknown] via shallow `type_name` comparison.
- Zero candidates still returns Unknown (permissive, no error).

---

## Proof Results

```
TOTAL: 29/29 PASS  |  0 FAIL
```

**Sections:**
- A (source guards): 5/5 — helper defined, called in right place, output boundary clean
- B (core fix): 7/7 — empty array field resolves to named type in all combinations
- C (P3 regression): 4/4 — non-empty Collection and scalar-only records unchanged
- D (output boundary): 3/3 — OOF-TY1 still fires for Collection[Unknown] at output
- E (SIM-P14 pressure): 5/5 — SimState inferred for initial_state with 3 empty fields
- F (scope closure): 5/5 — parser, Rust, emitter unchanged

P3 proof runner: **76/76 PASS** (unchanged).

---

## SIM-P14 Resolution

sim_framework Ruby compilation after P5:
- `RunEcosystemSim.initial_state` infers as `SimState`.
- No errors from `RunEcosystemSim` contract.
- Remaining sim_framework errors: SIM-P10 / SIM-P11 only (`rule_name: expected String, got Text`
  in `CheckConstraint.corrective_event`) — pre-existing, unrelated to P5.

SIM-P14 is **RESOLVED**.

---

## Scope Confirmation

- `typechecker.rb`: +14 lines (new method + modified clause)
- No parser changes.
- No Rust TC changes.
- No emitter changes.
- No app source edits.
- No new OOF rule codes.
