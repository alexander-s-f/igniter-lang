# LAB-OUTPUT-TYPE-PARAMETER-CHECK-P1 — Output Type Parameter Check Gap

**Track:** lab / safety  
**Route:** SAFETY PROOF / GAP DOCUMENTATION  
**Status:** PROVED 38/38 — READY FOR IMPLEMENTATION PLANNING  
**Date:** 2026-06-12  
**Predecessor:** LAB-UNKNOWN-OUTPUT-COERCION-P1 (36/36 PASS — scope was Unknown-only)

---

## Summary

The output boundary type check in both the Ruby and Rust TypeCheckers is
structurally blind to type parameters. `type_name()` reads only the outer
`"name"` field of a type hash; the `"params"` array is never consulted.
This means any parametric mismatch where the outer container name matches
is silent — no `OOF-TY0` fires.

The gap is wider than P1 documented. P1 discovered the gap for
`Collection[Unknown] → Collection[T]`. P2 (this card) proves the gap extends
to all parametric mismatches regardless of `Unknown`:
`Collection[Integer] → Collection[Text]` is equally silent.

---

## Root Cause

```ruby
# typechecker.rb, line 1358
def type_name(type)
  type.fetch("name")
end

# typechecker.rb, lines 410-413 — output boundary check
when "output"
  expected = type_ir(decl.fetch("type_annotation"))
  actual   = symbol_types.fetch(decl.fetch("name"), type_ir("Unknown"))
  if type_name(actual) != type_name(expected) && !blocking_rule_present?(type_errors)
    type_errors << type_mismatch(expected, actual, decl.fetch("name"))
  end
```

`type_name(Collection[Integer])` → `"Collection"`  
`type_name(Collection[Text])` → `"Collection"`  
`"Collection" != "Collection"` → `false` → no `OOF-TY0` fires.

The Rust TC has the identical outer-name-only pattern at lines 1236-1244.

---

## Confirmed Silent Cases (PROVED 38/38)

| Actual output type | Declared output type | Ruby TC | Rust TC |
|--------------------|---------------------|---------|---------|
| `Unknown` → `T` (scalar) | **CAUGHT** (OOF-TY0) | SILENT (LAB-RACK-P9) |
| `Collection[Unknown]` | `Collection[T]` | SILENT | SILENT |
| `Collection[Integer]` | `Collection[Text]` | SILENT | SILENT — **NEW** |
| `Collection[Foo]` | `Collection[Bar]` | SILENT | SILENT — **NEW** |
| `Map[String,Integer]` | `Map[String,Text]` | SILENT | SILENT — **NEW** |
| `Collection[Collection[Integer]]` | `Collection[Collection[Text]]` | SILENT | SILENT — **NEW** |
| `Collection[Integer]` | `Collection[Unknown]` | SILENT | SILENT — **NEW** |

Confirmed CAUGHT (outer names differ):

| Actual | Declared | Result |
|--------|----------|--------|
| `Unknown` (scalar) | `Text` | CAUGHT — Ruby TC fires OOF-TY0 |
| `Unknown` (scalar, call_contract) | `Map[String,Integer]` | CAUGHT — outer names differ |

---

## Why the Blocking Guard Doesn't Explain the Silence

`blocking_rule_present?` (line 1500) does NOT include `OOF-TY0`.
For `Collection[Integer] → Collection[Text]` the TypeChecker runs zero previous
errors — there is nothing to block. The output check runs unconditionally and
silently passes because `type_name` returns `"Collection"` for both.

---

## Infrastructure That Already Exists

`element_type_from_collection` (Ruby TC, line 1857) reads `params[0]` from a
collection type hash and is already called in `for_loop` and `budgeted_loop`
body type propagation:

```ruby
def element_type_from_collection(collection_type)
  return type_ir("Unknown") unless collection_type.is_a?(Hash)
  params = collection_type.fetch("params", [])
  first  = params.first
  return type_ir("Unknown") unless first
  first.is_a?(Hash) ? first : type_ir(first.to_s)
end
```

This helper can be reused directly by the fix.

---

## Recommended Fix — `structurally_assignable?`

Replace the single `type_name` equality in the output check with a recursive
structural comparison:

```ruby
def structurally_assignable?(actual, expected)
  # Unknown is permissive at every depth — consistent with LAB-RACK-P9 intent
  return true if type_name(actual) == "Unknown"
  # Outer name must match
  return false if type_name(actual) != type_name(expected)
  # All type params must be recursively assignable
  actual_params   = actual.fetch("params", [])
  expected_params = expected.fetch("params", [])
  return false if actual_params.length != expected_params.length
  actual_params.zip(expected_params).all? { |a, e| structurally_assignable?(a, e) }
end
```

Replace in output check (line 413):
```ruby
# Before
if type_name(actual) != type_name(expected) && !blocking_rule_present?(type_errors)
# After
if !structurally_assignable?(actual, expected) && !blocking_rule_present?(type_errors)
```

Rust equivalent is the same logic at lines 1236-1237, with the LAB-RACK-P9
`Unknown`-guard folded into `structurally_assignable`.

---

## Scope of Fix

| Dimension | Scope |
|-----------|-------|
| Files changed | `igniter-lang/lib/igniter_lang/typechecker.rb`, `igniter-lab/igniter-compiler/src/typechecker.rs` |
| Lines changed | ~20 lines each (one new method + one line replacement) |
| New helper | `structurally_assignable?` (Ruby), `structurally_assignable()` (Rust) |
| OOF codes | Extend `OOF-TY0` message OR add `OOF-TY1` (planning-card decision) |
| Parser / emitter / assembler | No changes |
| Stdlib inventory | No changes |
| Unknown-permissive policy | Unknown at any depth is permissive — preserves LAB-RACK-P9 intent |

---

## Planning-Card Decisions (for P2)

1. **Unknown-permissive depth.** Current recommendation: Unknown is permissive at ALL
   depths (depth-0 scalar, depth-1 element, nested). This is consistent with the
   call_contract design where element types may genuinely be Unknown at analysis time.
   Alternative: only permissive at depth 0. The P2 card should decide.

2. **OOF code.** Extend `OOF-TY0` with a better message ("Type mismatch: expected
   `Collection[Text]`, got `Collection[Integer]` — element type mismatch") OR add a new
   `OOF-TY1` code for parametric element mismatch. OOF-TY1 is cleaner for rule filtering
   but adds a new code. P2 decides.

3. **Map multi-param.** `Map[K,V]` has two params. The structural rule handles this
   correctly (zip of params). Decide whether K-type mismatches should be a separate
   diagnostic from V-type mismatches.

4. **Ruby Unknown-strictness alignment.** Ruby currently CATCHES scalar `Unknown → T`
   (unlike Rust). After the fix, `structurally_assignable?` with Unknown-permissive-always
   would silence Ruby scalar Unknown too. If Ruby's stricter behavior is desired, the
   Unknown guard should only apply at depth ≥ 1. P2 decides.

---

## Closed Surfaces

- No changes to any source file in this proof card.
- No new OOF codes defined here.
- No dynamic dispatch proposal.
- No plugin model changes.
- No runtime validation receipt design.

---

## Next Route

**LAB-OUTPUT-TYPE-PARAMETER-CHECK-P2** — implementation planning  
Scope: decide Unknown-permissive policy, OOF code, implement `structurally_assignable?`
in Ruby TC, implement Rust parity, write regression proof runner.
