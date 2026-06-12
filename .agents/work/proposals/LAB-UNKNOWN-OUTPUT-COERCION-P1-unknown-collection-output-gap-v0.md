# LAB-UNKNOWN-OUTPUT-COERCION-P1 — Unknown / Collection[Unknown] Output Boundary Gap

**Track:** lab / safety  
**Route:** SAFETY PROOF / GAP DOCUMENTATION  
**Status:** HOLD — SAFETY-HIGH  
**Date:** 2026-06-12  
**Predecessor:** LANG-STDLIB-TEXT-EQUALITY-P3 (impl), LAB-RACK-P6 (Rust Unknown parity)

---

## Summary

The Ruby and Rust TypeCheckers both use a shallow `type_name()` comparison at the
output boundary. This correctly catches `Unknown → T` for scalar outputs, but
**silently passes `Collection[Unknown] → Collection[T]`** because both report the
outer name `"Collection"` — the element type parameter is never compared.

The `rule_engine` app demonstrates this live: `ExecuteRules` maps dynamic
`call_contract(r, t)` calls into `raw_decisions : Collection[Unknown]`, then
filters and outputs `active_decisions : Collection[RuleDecision]`. Both toolchains
emit no diagnostic for this output boundary crossing.

---

## Root Cause

**Ruby TC** (`typechecker.rb` lines 410–415):
```ruby
when "output"
  expected = type_ir(decl.fetch("type_annotation"))
  actual = symbol_types.fetch(decl.fetch("name"), type_ir("Unknown"))
  if type_name(actual) != type_name(expected) && !blocking_rule_present?(type_errors)
    type_errors << type_mismatch(expected, actual, decl.fetch("name"))
  end
```

**`type_name`** (`typechecker.rb` line 1358):
```ruby
def type_name(type)
  type.fetch("name")
end
```

For `Collection[Unknown]` vs `Collection[RuleDecision]`:
- `type_name(Collection[Unknown])` → `"Collection"`
- `type_name(Collection[RuleDecision])` → `"Collection"`
- `"Collection" != "Collection"` → **false** → no OOF fires

For `Unknown` vs `RuleDecision` (scalar — caught correctly):
- `type_name(Unknown)` → `"Unknown"`  
- `type_name(RuleDecision)` → `"RuleDecision"`
- `"Unknown" != "RuleDecision"` → **true** → OOF-TY0 fires

**Rust TC** (`typechecker.rs` lines 1236–1238):
```rust
if self.type_name(&actual) != self.type_name(&expected)
    && self.type_name(&actual) != "Unknown"   // LAB-RACK-P9: intentional Unknown guard
    && !self.blocking_rule_present(&type_errors) {
    // OOF-TY0
}
```

Rust TC additionally has an explicit `LAB-RACK-P9` guard that silences scalar
`Unknown → T` at output (intentional: dynamic `call_contract` returns Unknown by
design). The Collection element-type gap is present in Rust TC for the same
`type_name()` reason.

---

## Asymmetry Summary

| Case | Ruby TC | Rust TC |
|------|---------|---------|
| Scalar `Unknown → T` at output | OOF-TY0 FIRES | SILENT (LAB-RACK-P9) |
| `Collection[Unknown] → Collection[T]` at output | SILENT (gap) | SILENT (gap) |
| Clean `T → T` at output | No error | No error |

---

## Evidence

**App:** `igniter-lab/igniter-apps/rule_engine/engine.ig`

```igniter
contract ExecuteRules {
  input t : Transaction
  input rules : Collection[String]

  compute raw_decisions = map(rules, r -> call_contract(r, t))

  compute active_decisions = filter(raw_decisions, d ->
    if d.action == "SKIP" { false } else { true }
  )

  output active_decisions : Collection[RuleDecision]
}
```

Type flow:
1. `call_contract(r, t)` → `Unknown` (dynamic dispatch, T2 evaluation)
2. `map(rules, ...)` → `Collection[Unknown]`
3. `filter(raw_decisions, ...)` → `Collection[Unknown]` (element type preserved)
4. `output active_decisions : Collection[RuleDecision]` → **silent pass**

---

## Proof

**Runner:** `igniter-lang/experiments/unknown_output_coercion_proof/verify_unknown_output_coercion_p1.rb`  
**Result:** 36/36 PASS  

Key checks:
- A-01–A-03: scalar Unknown → T fires OOF-TY0 (Ruby correctly catches it)
- B-01–B-04: Collection[Unknown] → Collection[T] fires NO OOF-TY0 (gap confirmed)
- D-01–D-04: engine.ig exact fixture → output boundary SILENT
- E-01–E-03: type_name shallow comparison proved via source inspection
- F-03, F-05: Rust TC asymmetry documented (LAB-RACK-P9 guard vs no guard in Ruby)

---

## Safety Classification: HOLD / SAFETY-HIGH

**Risk:** Programs that output `Collection[Unknown]` under a `Collection[T]`
declaration "compile" from the TC's perspective. The runtime VM receives actual
Unknown-typed values. Any consumer that assumes the output is a well-typed
`Collection[T]` may encounter runtime failures not surfaced at compile time.

**Not call_contract-specific:** Any Unknown-producing expression (field access
on Unknown, unresolved imports, T2 evaluation results) that lands in a collection
will have the same silent-pass behaviour.

**No blocking errors suppress the check:** `blocking_rule_present?` does not
include `OOF-TY0`, so the output check always runs — it just passes vacuously
because `"Collection" == "Collection"`.

---

## Authority Closed

- No changes to `typechecker.rb` in this card.
- No changes to Rust TC in this card.
- No dynamic dispatch proposal.
- No plugin or capability model changes.
- No new OOF codes introduced.

---

## Proposal Surface (future card)

Future fix requires element-type extraction at the output boundary for Collection
types. Proposed logic:

```ruby
when "output"
  expected = type_ir(decl.fetch("type_annotation"))
  actual   = symbol_types.fetch(decl.fetch("name"), type_ir("Unknown"))
  mismatch = if type_name(actual) == "Collection" && type_name(expected) == "Collection"
               element_name(actual) != element_name(expected) &&
                 element_name(actual) != "Unknown"
             else
               type_name(actual) != type_name(expected)
             end
  if mismatch && !blocking_rule_present?(type_errors)
    type_errors << type_mismatch(expected, actual, decl.fetch("name"))
  end
```

where `element_name(type)` would read `type.dig("of", "name")` (the element
parameter stored in the type IR). This is not implemented here — it requires a
separate card and Rust parity work.
