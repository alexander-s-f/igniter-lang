# LANG-OUTPUT-TYPE-ASSIGNABILITY-P1 — Structural Output Type Assignability

**Track:** lang / typechecker / output-boundary  
**Route:** PROPOSAL / PLANNING  
**Status:** AUTHORED — PENDING REVIEW  
**Date:** 2026-06-12  
**Grounding:**  
- LAB-UNKNOWN-OUTPUT-COERCION-P1 (36/36 PASS — HOLD/SAFETY-HIGH)  
- LAB-OUTPUT-TYPE-PARAMETER-CHECK-P1 (38/38 PASS — READY FOR IMPLEMENTATION PLANNING)

---

## Summary

The output boundary type check in both the Ruby and Rust TypeCheckers uses a
shallow `type_name()` comparison that reads only the outer `"name"` field of a
type hash. The `"params"` array is never consulted. This means any parametric
type mismatch where the outer container name matches is **silently passed** — no
diagnostic fires.

This proposal defines a replacement rule — **structural output assignability** —
that recursively compares type parameters, adopts a strict Unknown policy, and
introduces `OOF-TY1` as the output boundary structural failure diagnostic.

The fix is bounded: two files (~20 lines each). There is no dynamic dispatch
feature, no runtime validation receipt, no VM change in scope.

---

## Background and Evidence

### Gap Proved in Two Lab Cards

**LAB-UNKNOWN-OUTPUT-COERCION-P1** (36/36 PASS):
- `Collection[Unknown] → Collection[T]` is SILENT in both TCs
- Scalar `Unknown → T` is CAUGHT in Ruby TC (OOF-TY0), SILENT in Rust TC (LAB-RACK-P9)
- Root cause: `type_name()` returns `"Collection"` for both → outer check always passes

**LAB-OUTPUT-TYPE-PARAMETER-CHECK-P1** (38/38 PASS):
- Gap is NOT Unknown-specific. `Collection[Integer] → Collection[Text]` is equally SILENT.
- Map, nested containers, all parametric mismatches are silent.
- Confirmed as a single-line root cause in each TC.

### Confirmed Silent Cases

| Actual at output | Declared output type | Both TCs before fix |
|-----------------|---------------------|---------------------|
| `Unknown` (scalar) | `T` | Ruby CAUGHT / Rust SILENT (LAB-RACK-P9) |
| `Collection[Unknown]` | `Collection[T]` | SILENT |
| `Collection[T1]` | `Collection[T2]` (T1 ≠ T2) | SILENT |
| `Collection[Foo]` | `Collection[Bar]` | SILENT |
| `Map[K,V1]` | `Map[K,V2]` | SILENT |
| `Collection[Collection[T1]]` | `Collection[Collection[T2]]` | SILENT |

### Root Cause Location

**Ruby TC** (`typechecker.rb`, line 413):
```ruby
if type_name(actual) != type_name(expected) && !blocking_rule_present?(type_errors)
  type_errors << type_mismatch(expected, actual, decl.fetch("name"))
end
```

**Rust TC** (`typechecker.rs`, lines 1236–1238):
```rust
if self.type_name(&actual) != self.type_name(&expected)
    && self.type_name(&actual) != "Unknown"   // LAB-RACK-P9 intentional guard
    && !self.blocking_rule_present(&type_errors) {
    type_errors.push(/* OOF-TY0 */);
}
```

Both use `type_name()` which reads only `type.fetch("name")` / `type["name"]` — 
`"params"` is never reached.

---

## Design

### D1 — Structural Assignability Relation

Define `structurally_assignable?(actual, expected)` as the new output boundary
predicate, replacing the `type_name` equality. The relation is directional:
`actual` is the inferred type; `expected` is the declared output type.

```
structurally_assignable?(actual, expected):
  1. If expected.name == "Unknown":
       return true                     # D3 below — declaration accepts anything
  2. If actual.name == "Unknown":
       return false                    # D2 below — Unknown cannot discharge a concrete output
  3. If actual.name != expected.name:
       return false                    # outer name mismatch (Map vs Collection, etc.)
  4. actual_params   = actual["params"]   || []
     expected_params = expected["params"] || []
  5. If actual_params.length != expected_params.length:
       return false
  6. return actual_params.zip(expected_params)
              .all? { |a, e| structurally_assignable?(a, e) }
```

**Properties:**
- Reflexive: `structurally_assignable?(T, T)` = true for any concrete T.
- Directional: `structurally_assignable?(Collection[T], Collection[Unknown])` = true;
  `structurally_assignable?(Collection[Unknown], Collection[T])` = false (rule 2 at depth 1).
- Recursive: catches any depth of nesting.
- No special casing needed for Collection vs Map — the `params` zip handles both.

**Ruby implementation (~11 lines, one new private method):**
```ruby
def structurally_assignable?(actual, expected)
  return true  if type_name(expected) == "Unknown"
  return false if type_name(actual)   == "Unknown"
  return false if type_name(actual)   != type_name(expected)
  actual_params   = actual.fetch("params",   [])
  expected_params = expected.fetch("params", [])
  return false if actual_params.length != expected_params.length
  actual_params.zip(expected_params).all? { |a, e| structurally_assignable?(a, e) }
end
```

**Rust implementation (~15 lines, one new method):**
```rust
fn structurally_assignable(&self, actual: &serde_json::Value,
                            expected: &serde_json::Value) -> bool {
    if self.type_name(expected) == "Unknown" { return true; }
    if self.type_name(actual)   == "Unknown" { return false; }
    if self.type_name(actual)   != self.type_name(expected) { return false; }
    let ap = actual.get("params").and_then(|v| v.as_array()).map(|v| v.as_slice()).unwrap_or(&[]);
    let ep = expected.get("params").and_then(|v| v.as_array()).map(|v| v.as_slice()).unwrap_or(&[]);
    if ap.len() != ep.len() { return false; }
    ap.iter().zip(ep.iter()).all(|(a, e)| self.structurally_assignable(a, e))
}
```

### D2 — Unknown Policy: Strict Rejection at Output Boundary

**Rule:** An output declaration with a concrete type (`T != Unknown`) must be
discharged by a value of that structural type. An Unknown-typed actual value does
not satisfy a concrete output declaration.

**Before this proposal:**
- Ruby TC: scalar `Unknown → T` is CAUGHT (OOF-TY0). Collection[Unknown] → Collection[T] SILENT.
- Rust TC: scalar `Unknown → T` SILENT (LAB-RACK-P9). Collection[Unknown] → Collection[T] SILENT.

**After this proposal:**
- Both TCs: `Unknown → T` at any depth is OOF-TY1. No exceptions unless the output
  declaration is explicitly typed `Unknown`.

**Rationale:**
- The output declaration is a **contract obligation**. `output active_decisions : Collection[RuleDecision]`
  is a claim to callers that this contract produces well-typed items. Silently producing
  `Collection[Unknown]` violates this claim.
- Unknown at output is not a neutral unknowing — it is **proof of incomplete typing**.
  The compiler cannot verify the contract without a validation receipt (which does not
  exist in scope).
- Ruby TC's existing behaviour (catching scalar Unknown) is correct and this proposal
  extends the same logic to all depths.

**Exemption — explicit Unknown output declaration:**
If the contract author writes `output foo : Unknown`, `structurally_assignable?` returns
true for any actual type (rule 1: expected is Unknown). This is the sanctioned escape
hatch: the author explicitly acknowledges the output type is not statically known. This
is different from writing `output foo : Collection[RuleDecision]` and accidentally
getting Unknown.

**LAB-RACK-P9 relationship:**
LAB-RACK-P9 was an explicit guard in the Rust TC (`self.type_name(&actual) != "Unknown"`)
that intentionally silenced scalar Unknown → T at output. The rationale was: dynamic
`call_contract` returns Unknown by design; rejecting it would block all dynamic dispatch
patterns.

This proposal **supersedes LAB-RACK-P9** in the Rust TC. The LAB-RACK-P9 guard is
removed as part of P2. The design intent behind LAB-RACK-P9 — enabling dynamic dispatch —
is not lost; it is reclassified: dynamic dispatch programs that output Unknown-derived
types must declare their output as `Unknown` or wait for validation receipt semantics.
The call_contract machinery itself is unchanged; only the output boundary obligation changes.

### D3 — Permissive in the Reverse Direction

`structurally_assignable?(actual, expected)` returns true when `expected.name == "Unknown"`
at any depth. This is the correct direction:

- `output foo : Unknown` with actual `Collection[RuleDecision]` → PASS (more specific than declared)
- `output foo : Collection[Unknown]` with actual `Collection[RuleDecision]` → depth-0 Collection
  match → depth-1: actual.name="RuleDecision", expected.name="Unknown" → rule 1 → PASS

This is sound: a more specific type always satisfies a less specific declaration.

### D4 — OOF-TY1: New Diagnostic for Output Structural Failure

**Decision: New OOF-TY1 code, NOT extension of OOF-TY0.**

**Rationale:**
- OOF-TY0 is used pervasively (unsupported expressions, unknown functions, operator
  mismatches, HOF arity errors). It is not exclusively an output boundary code.
- `type_mismatch()` (the OOF-TY0 helper) uses `type_name()` in its message — it
  cannot produce `"expected Collection[RuleDecision], got Collection[Unknown]"`.
- A distinct code enables tooling to query output structural failures separately from
  inline type errors.
- The Unknown policy change (superseding LAB-RACK-P9) is a semantic shift significant
  enough to deserve a new code. Programs that previously compiled with Rust TC under
  LAB-RACK-P9 will now get OOF-TY1 — the new code makes this visible and queryable.
- Rule engines, linters, and IDEs can distinguish "your output declaration is wrong type"
  from "your expression is wrong type" without parsing error messages.

**OOF-TY1 definition:**

| Field | Value |
|-------|-------|
| Code | `OOF-TY1` |
| Name | Structural output type mismatch |
| Scope | Output declaration boundary only |
| Fires when | `!structurally_assignable?(actual, expected)` at output check |
| Message | `"Output type mismatch: expected #{type_display(expected)}, got #{type_display(actual)}"` |
| Note | Uses `type_display()` not `type_name()` — full parameterized type shown |

**OOF-TY0 after this proposal:**
All existing OOF-TY0 uses remain. The output boundary check STOPS emitting OOF-TY0 via
`type_mismatch()` and instead emits OOF-TY1 via a new `structural_mismatch()` helper.
OOF-TY0 at line 413 is replaced by OOF-TY1. No other OOF-TY0 emitters change.

**New helper (Ruby TC):**
```ruby
def structural_mismatch(expected, actual, node)
  oof("OOF-TY1",
      "Output type mismatch: expected #{type_display(expected)}, got #{type_display(actual)}",
      node)
end
```

### D5 — Outer Name Mismatch Still Fires OOF-TY1

When `structurally_assignable?` returns false at step 3 (outer name mismatch, e.g.
`Collection → Map`), OOF-TY1 fires. Previously this fired OOF-TY0 via `type_mismatch()`.

The behavioral difference: the message now shows `type_display()` instead of `type_name()`.
For outer mismatches this is identical content, since scalar types have no params. For the
OOF code: OOF-TY0 is removed from the output path; OOF-TY1 covers ALL output failures.

This is a minor breaking change in diagnostic code. Existing tooling that queries OOF-TY0
at the output boundary will need to add OOF-TY1 to its filter set. The behavior (error fires)
is unchanged for all cases that previously caught.

### D6 — `type_display()` Already Exists

```ruby
def type_display(type)
  return type["name"] unless type["params"]&.any?
  rendered = params.map { |p| p.is_a?(Hash) ? type_display(p) : p.to_s }.join(",")
  "#{type.fetch("name")}[#{rendered}]"
end
```

(Ruby TC, near line 1352.) It renders full parameterized types. No new helper needed —
`structural_mismatch()` calls it directly.

Rust TC equivalent: `type_display` already exists in `typechecker.rs`. P2 confirms exact name.

---

## Structural Assignability Table

Full behavior after P2 implementation:

| Actual | Expected | Result | OOF |
|--------|----------|--------|-----|
| `T` | `T` | ✓ PASS | — |
| `T1` | `T2` (T1 ≠ T2, no params) | ✗ FAIL | OOF-TY1 |
| `Unknown` | `Unknown` | ✓ PASS (expected Unknown → rule 1) | — |
| `Unknown` | `T` (concrete) | ✗ FAIL | OOF-TY1 |
| `T` | `Unknown` | ✓ PASS (expected Unknown → rule 1) | — |
| `Collection[T]` | `Collection[T]` | ✓ PASS | — |
| `Collection[Unknown]` | `Collection[T]` | ✗ FAIL | OOF-TY1 |
| `Collection[T]` | `Collection[Unknown]` | ✓ PASS (element expected Unknown) | — |
| `Collection[T1]` | `Collection[T2]` (T1 ≠ T2) | ✗ FAIL | OOF-TY1 |
| `Map[K,V]` | `Map[K,V]` | ✓ PASS | — |
| `Map[K,V1]` | `Map[K,V2]` (V1 ≠ V2) | ✗ FAIL | OOF-TY1 |
| `Map[K1,V]` | `Map[K2,V]` (K1 ≠ K2) | ✗ FAIL | OOF-TY1 |
| `Collection[Collection[T1]]` | `Collection[Collection[T2]]` | ✗ FAIL | OOF-TY1 |
| `Collection[Unknown]` | `Collection[Unknown]` | ✓ PASS | — |
| `Collection[T]` | `Unknown` | ✓ PASS (outer expected Unknown) | — |
| `Collection[T]` | `Collection[T, S]` (param count mismatch) | ✗ FAIL | OOF-TY1 |

---

## Impact Statement: rule_engine Dynamic Dispatch

### Current State (before fix)

`igniter-lab/igniter-apps/rule_engine/engine.ig`:

```igniter
contract ExecuteRules {
  input t : Transaction
  input rules : Collection[String]

  compute raw_decisions = map(rules, r -> call_contract(r, t))  # → Collection[Unknown]
  compute active_decisions = filter(raw_decisions, d ->         # → Collection[Unknown]
    if d.action == "SKIP" { false } else { true }
  )
  output active_decisions : Collection[RuleDecision]             # SILENT today
}
```

Both TCs: **SILENT**. `Collection[Unknown] → Collection[RuleDecision]` passes vacuously.
This is a SAFETY-HIGH gap: the VM receives Unknown-typed values that may not conform to
the RuleDecision shape at runtime.

### After This Proposal (P2 implementation)

`!structurally_assignable?(Collection[Unknown], Collection[RuleDecision])` is true →
**OOF-TY1 fires** on both TCs.

```
OOF-TY1 Output type mismatch: expected Collection[RuleDecision], got Collection[Unknown]
  at: active_decisions
```

The `rule_engine` app **becomes a compile error** on both Ruby and Rust TCs.

### Resolution Options for rule_engine (not authorized in this proposal)

| Option | Mechanism | Status |
|--------|-----------|--------|
| Declare output as `Unknown` | Change `output active_decisions : Collection[Unknown]` | Loses type declaration |
| Validation receipt | Emit a typed receipt at the `call_contract` call site proving T | Closed in this proposal |
| Quarantine annotation | Annotate the contract with a quarantine marker suppressing OOF-TY1 | No quarantine syntax exists |
| Type-narrowing expression | Introduce a `narrow_type(expr, T)` expression that casts Unknown → T with explicit risk | No language feature |

**None of these options are authorized in this proposal.** The rule_engine app is
blocked. This is the correct safety outcome — the gap was hidden risk; now it is visible.
The resolution path (validation receipt or explicit cast) is deferred to a separate card.

### Scope of Impact

The rule_engine is the primary known casualty. The same pattern appears wherever
`call_contract(...)` is the source of a value that flows to a typed output.

Search target for P2 regression audit:
```
grep -r "call_contract" igniter-apps/ | grep "output"
```
Any contract that chains `call_contract → map/filter → output T` will trigger OOF-TY1
after the fix. This is not a regression — it is the intended consequence of closing the
safety gap.

---

## TC Asymmetry Resolution

After this proposal, the Ruby/Rust asymmetry documented in LAB-UNKNOWN-OUTPUT-COERCION-P1
is fully resolved:

| Case | Ruby TC (before) | Rust TC (before) | Both TCs (after) |
|------|-----------------|-----------------|------------------|
| `Unknown → T` (scalar) | OOF-TY0 | SILENT (LAB-RACK-P9) | OOF-TY1 |
| `Collection[Unknown] → Collection[T]` | SILENT | SILENT | OOF-TY1 |
| `Collection[T1] → Collection[T2]` | SILENT | SILENT | OOF-TY1 |
| `T → T` | No error | No error | No error |
| `T → Unknown` | No error (type_name "T" == "T"... wait) | | No error (rule 1) |

**OOF-TY0 migration note:** Ruby's existing scalar `Unknown → T` was OOF-TY0 before.
After P2 it becomes OOF-TY1. OOF-TY0 is no longer emitted by the output check.

---

## Open Questions for P2 (Implementation Planning)

All four questions from LAB-OUTPUT-TYPE-PARAMETER-CHECK-P1 are resolved by this proposal:

| Question | Resolution |
|----------|-----------|
| Unknown-permissive depth | Depth-0 only for "actual Unknown": rules 1+2 in `structurally_assignable?`. Expected Unknown is permissive at all depths (rule 1 recurses). Actual Unknown at any depth is rejected. |
| OOF code | **OOF-TY1** — new code for output structural failures. OOF-TY0 remains for all other TC errors. |
| Map multi-param (K vs V mismatch) | Single OOF-TY1 with type_display() message. No separate K/V diagnostics in v0. |
| Ruby Unknown-strictness alignment | Ruby already strict for scalar. After fix both TCs strict at all depths via structurally_assignable?. LAB-RACK-P9 removed from Rust TC. |

**Remaining P2 planning decisions:**

1. **`blocking_rule_present?` scope.** Today it does NOT include OOF-TY0. Should OOF-TY1
   be added to the blocking list? If OOF-TY1 fires for a previous compute error (e.g.
   output symbol is Unknown because a prior expression failed), it may be noise. P2 decides.
   Recommendation: do NOT add OOF-TY1 to blocking list — the output check fires regardless,
   which is the current behavior for scalar Unknown in Ruby TC.

2. **Rust `type_display` exact name.** P2 verifies the method name and call signature in
   `typechecker.rs` before writing the OOF-TY1 message format.

3. **Regression fixture scope.** P2 proof runner must cover:
   - `rule_engine` — confirms OOF-TY1 fires (was SILENT)
   - `neural_net` — all scalar/collection outputs clean (no regression)
   - `DSA` fixtures — all clean (DSA uses `output result : T` with concrete types)
   - LAB-UNKNOWN-OUTPUT-COERCION-P1 fixture set (36 checks) — 8 now FAIL differently (OOF-TY1 not silent)
   - LAB-OUTPUT-TYPE-PARAMETER-CHECK-P1 fixture set (38 checks) — recategorized under new codes

---

## Authorized Surfaces (P2)

| File | Change |
|------|--------|
| `igniter-lang/lib/igniter_lang/typechecker.rb` | Add `structurally_assignable?` (~8 lines) + `structural_mismatch` helper (~3 lines); replace output check condition (~1 line) |
| `igniter-lab/igniter-compiler/src/typechecker.rs` | Add `structurally_assignable()` (~15 lines); replace output check lines 1236–1238 |
| Proof runner | `experiments/structural_assignability_proof/verify_structural_assignability_p2.rb` |

**Not authorized:**
- Parser, classifier, SemanticIR emitter, assembler — no changes
- Stdlib inventory — no changes
- VM / runtime — no changes
- Dynamic dispatch feature — no
- Validation receipt implementation — no
- Quarantine annotation syntax — no
- `call_contract` machinery — no changes

---

## OOF Namespace

| Code | Owner | Condition |
|------|-------|-----------|
| OOF-TY0 | All existing uses (unchanged) | Inline type errors: operator/function/arity/HOF mismatches |
| **OOF-TY1** | **New — output boundary only** | `!structurally_assignable?(actual, expected)` at output check |

---

## Proof Matrix (P2)

Target: ≥70 checks / 12 sections

| Section | Checks | Content |
|---------|--------|---------|
| A — `structurally_assignable?` unit (Ruby) | 8 | Direct calls to the new predicate; all cases from D1 table |
| B — `structurally_assignable` unit (Rust) | 6 | Same cases via Rust proof runner |
| C — OOF-TY1 outer name mismatch | 5 | Collection→Map, Text→Integer at output: OOF-TY1 (was OOF-TY0) |
| D — OOF-TY1 Unknown → concrete | 6 | Scalar Unknown, Collection[Unknown]→Collection[T]: OOF-TY1 (was OOF-TY0/SILENT) |
| E — OOF-TY1 param mismatch (same outer) | 6 | Collection[T1]→Collection[T2], Map[K,V1]→Map[K,V2]: OOF-TY1 (was SILENT) |
| F — OOF-TY1 nested params | 5 | Collection[Collection[T1]]→Collection[Collection[T2]]: OOF-TY1 |
| G — Permissive cases (no OOF-TY1) | 7 | T→T, T→Unknown, Collection[T]→Collection[Unknown]: PASS |
| H — Unknown→Unknown (permissive) | 4 | Scalar Unknown→Unknown, Collection[Unknown]→Collection[Unknown]: PASS |
| I — rule_engine OOF-TY1 activation | 5 | engine.ig ExecuteRules: OOF-TY1 on Collection[Unknown]→Collection[RuleDecision] |
| J — Regression: prior PASS contracts | 7 | neural_net / DSA / sets / graphs: zero OOF-TY1 |
| K — OOF-TY0 NOT fired at output boundary | 5 | Confirm no OOF-TY0 at output check after fix |
| L — Authority closed | 6 | No VM / no dynamic dispatch / no receipt / no new expression forms |

---

## Authority Closed

| Surface | This proposal |
|---------|--------------|
| `typechecker.rb` output check | YES — 1 condition replaced, 2 new methods |
| `typechecker.rs` output check | YES — 1 block replaced, 1 new method |
| OOF-TY1 namespace | YES — new code defined |
| OOF-TY0 (existing uses) | NO CHANGE — all existing OOF-TY0 emitters intact |
| Parser / emitter / assembler | NO |
| Stdlib inventory | NO |
| VM / runtime | NO |
| Dynamic dispatch / validation receipt | NO |
| `blocking_rule_present?` | NO (P2 recommendation: leave unchanged) |
| `call_contract` behavior | NO |

---

## Next Route

**LANG-OUTPUT-TYPE-ASSIGNABILITY-P2** — Implementation planning  
Scope: `structurally_assignable?` in Ruby TC + Rust TC; OOF-TY1 helper; regression proof runner;
proof matrix ≥70 checks; confirm `blocking_rule_present?` decision; Rust `type_display` name;
`rule_engine` OOF-TY1 evidence fixture.
