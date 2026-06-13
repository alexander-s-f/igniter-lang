# LANG-RUBY-RECORD-LITERAL-INFERENCE-P2: Implementation Planning

**Status:** CLOSED (direct implementation authorised; all insertion points mechanical)
**Date:** 2026-06-13
**Proof:** `igniter-lang/experiments/record_literal_inference_proof/verify_record_literal_inference_p2.rb` — 52/52 PASS
**One-file scope:** `typechecker.rb` only

---

## Problem

`compute p : Point = { x: 1, y: 2 }` does not activate `infer_record_literal`'s existing field-validation logic. The annotation is discarded before record literal inference runs. Field errors (missing, extra, mismatched) are silently ignored; the expr resolves to Unknown.

`LANG-TYPED-COMPUTE-BINDING-P2` already makes `symbol_types["p"] = Point` via its bind_type fallback (`unknown_or_unknown_bearing?` → use annotation), so downstream field accesses work. The gap is that OOF-TY0 diagnostics for malformed record literals are suppressed, and `typed_expr.resolved_type` is Unknown rather than Point.

---

## 13 Questions — Answers

### Q1: Call path for compute declarations today

```
classified_contract.fetch("declarations").each  (line 359)
  when "compute"                                 (line 408)
    infer_expr(decl["expr"], …, decl["name"])   (line 409)
      case expr.fetch("kind")
        when "record_literal"                    (line 972)
          infer_record_literal(expr, …, node_name)  (line 973)
            @output_type_hints&.fetch(node_name, nil)  (line 2890)
```

`node_name` is the compute declaration name throughout; it is the same key that `@output_type_hints` uses.

### Q2: Where does `decl["type_annotation"]` become a `type_ir`?

In the `when "compute"` arm at **line 414** — after `infer_expr` returns:

```ruby
expected_type = type_ir(decl["type_annotation"])   # line 414 — AFTER infer_expr
```

`infer_record_literal` runs inside `infer_expr` (line 409), so the annotation is not yet a `type_ir` when record literal inference runs. The annotation must be resolved to `type_ir` **before** calling `infer_expr` for it to be visible to `infer_record_literal`.

### Q3: How does `infer_record_literal` discover expected type today?

Via a single lookup:

```ruby
hint_type = @output_type_hints&.fetch(node_name, nil)   # line 2890
```

`@output_type_hints` is populated at lines 327–333 from **output declarations only** — a pre-scan that runs before the declarations loop. The key is the output declaration name; the value is `type_ir(annotation)`.

If no hint exists (node_name ≠ any output name), `infer_record_literal` skips the entire validation block and returns `type_ir("Unknown")` at line 2927.

### Q4: Lowest-risk approach

**Chosen: temporarily install `@output_type_hints[name]` before `infer_expr`, clean up in `ensure` block.**

Four candidates considered:

| Approach | Verdict |
|---|---|
| Temporary `@output_type_hints[name]` with `ensure` | **Chosen** — reuses 100% of existing validation, zero new structures |
| Explicit expected-type arg through `infer_expr` | Rejected — threads new arg across all 15+ case arms; large surface change |
| New `@compute_type_hints` instance variable | Rejected — identical semantics to temporary hint; more code, same result |
| Bypass `infer_expr`, call `infer_record_literal` directly | Rejected — must replicate dispatch; inconsistent with other declaration kinds |

The temporary hint approach works because:
- `infer_record_literal` already performs the exact validation needed
- `@output_type_hints` is already the lookup mechanism used by that validation
- The `ensure` block guarantees cleanup regardless of exception paths

### Q5: Can the chosen approach leak hints beyond the current compute declaration?

No. Three levels of containment:

1. **`ensure` block** — `@output_type_hints.delete(name)` runs immediately after `infer_expr` returns or raises; the hint is never visible to a subsequent iteration of the declarations loop.
2. **Sequential processing** — `declarations.each` is a serial loop; no concurrent access to `@output_type_hints` within a single contract typecheck.
3. **Guard `!@output_type_hints.key?(name)`** — prevents installing a hint when an output declaration already registered one for the same name (same-name output/compute pattern).

### Q6: Does it preserve unannotated compute behavior?

Yes. The temp-hint installation is gated on:

```ruby
decl["type_annotation"] && decl.fetch("expr", {}).fetch("kind", nil) == "record_literal"
```

If no annotation, the branch is never entered. `infer_expr` is called with no hint installed. `infer_record_literal` returns Unknown exactly as before.

### Q7: Does it preserve output hints behavior?

Yes. Guard `!@output_type_hints.key?(name)` skips installation when the same-name output/compute pattern is active (an output declaration already installed a hint). The existing output hint is used unchanged. The guard also prevents double-cleanup: if the hint was already present, `temp_hint_installed` stays false, and the `ensure` block does not delete the pre-existing hint.

### Q8: Interaction with LANG-TYPED-COMPUTE-BINDING-P2 bind_type logic?

The two mechanisms are cleanly additive. After this change:

- **Matching fields:** `infer_record_literal` returns `resolved_type = Point`. bind_type logic: `structurally_assignable?(Point, Point)` → true → `bind_type = inferred_type = Point`. Same symbol registration, now also correct typed_expr.resolved_type.
- **Field errors (missing/extra/mismatch):** `infer_record_literal` emits OOF-TY0 and returns Unknown. bind_type logic: `unknown_or_unknown_bearing?(Unknown)` → true → `bind_type = expected_type = Point`. Symbol still registers as Point — downstream analysis is not blocked. This is the desired behaviour: diagnose the literal error without blocking downstream.
- **No annotation:** unchanged (unannotated path never enters the temp-hint block).

### Q9: What happens when annotation names an unknown type?

```ruby
compute p : GhostType = { x: 1 }
```

- `type_name(declared_type) = "GhostType"`, `@type_shapes.key?("GhostType")` → false
- No hint installed; `infer_expr` proceeds normally
- `infer_record_literal` returns Unknown
- bind_type: `unknown_or_unknown_bearing?(Unknown)` → true → `bind_type = type_ir("GhostType")`
- `symbol_types["p"] = GhostType`
- No new OOF codes; downstream output check (if any) may surface a mismatch

Behaviour unchanged from current P2 pass.

### Q10: What happens when annotation is not a record shape?

Examples: `Collection[Point]`, `Integer`, `Bool`.

- `type_name` = "Collection", "Integer", "Bool"
- None are in `@type_shapes` (which contains only user-declared record types)
- `@type_shapes.key?(tn)` → false → no hint installed
- `infer_record_literal` returns Unknown (no validation, no OOF-TY0)
- bind_type uses the annotation as fallback

Behaviour unchanged. A record literal with a primitive annotation is a semantic error that will surface at the output boundary, not in `infer_record_literal`.

### Q11: What diagnostic text/code for field errors?

No new codes. All field errors reuse the existing `infer_record_literal` diagnostics (lines 2896–2916):

| Case | Code | Message |
|---|---|---|
| Missing required field | `OOF-TY0` | `record literal missing required field: #{fname}` |
| Unexpected extra field | `OOF-TY0` | `record literal has unexpected field: #{fname}` |
| Field type mismatch | `OOF-TY0` | `record literal field '#{fname}': expected #{type_name(expected_type)}, got #{type_name(actual_type)}` |

These messages are consistent with the output/compute same-name path already in production.

### Q12: App fixtures for P3 proof?

All Wave P4 app pressures (DSA-P10, NN-P09, DF-P10, VE-P08, AP-P12, RE-P07, VM-P09, SIM-P12, SIM-P13) use **unannotated** computes. They are **not** relieved by this change. Section J of the P3 proof should confirm that these patterns remain Unknown — i.e., regression coverage, not positive fixtures.

**Critical fixture insight (confirmed by proof):** Wave P4 app pressures that use the same-name output/compute pattern (e.g., `compute c00 = {...}` + `output c00 : Cell`) are ALREADY handled by the `@output_type_hints` pre-scan. Section J regression fixtures must use compute names that differ from all output names to represent true intermediate compute gaps.

Positive fixtures use synthetic annotated forms:

| Fixture | Checks |
|---|---|
| `compute p : Point = { x: 1, y: 2 }` → resolves to Point | B section happy path |
| `compute e0 : IndexedElement = { index: 0, value: 10 }` → IndexedElement | B section, DSA-style synthetic |
| `compute p : Point = { x: 1 }` (missing y) → OOF-TY0 | D section |
| `compute p : Point = { x: 1, y: 2, z: 3 }` (extra z) → OOF-TY0 | E section |
| `compute p : Point = { x: "hello", y: 2 }` (x type mismatch) → OOF-TY0 | F section |
| `compute p : Point = { x: unk_ref, y: 2 }` (Unknown field value) → Point | G section |
| `compute p = { x: 1, y: 2 }` (unannotated) → Unknown | H section regression |
| Wave P4 unannotated fixtures (DSA, DF, NN, etc.) → Unknown | J section regression |

### Q13: Can P3 stay Ruby-only?

**Yes.** The implementation is one file (`typechecker.rb`), one method scope (`when "compute"` arm). No parser, emitter, semantic IR, or Rust changes needed.

---

## Exact Insertion Point

**File:** `igniter-lang/lib/igniter_lang/typechecker.rb`  
**Location:** `when "compute"` arm, before line 409 (`typed_expr = infer_expr(...)`)

**Current code (lines 408–410):**
```ruby
when "compute"
  typed_expr = infer_expr(decl.fetch("expr"), symbol_types, type_errors, type_warnings, decl.fetch("name"))
  validate_declared_olap_type(decl, typed_expr, type_errors)
```

**New code:**
```ruby
when "compute"
  name = decl.fetch("name")
  temp_hint_installed = false
  if decl["type_annotation"] && decl.fetch("expr", {}).fetch("kind", nil) == "record_literal"
    declared_type = type_ir(decl["type_annotation"])
    tn = type_name(declared_type)
    if @type_shapes.key?(tn) && !@output_type_hints.key?(name)
      @output_type_hints[name] = declared_type
      temp_hint_installed = true
    end
  end
  begin
    typed_expr = infer_expr(decl.fetch("expr"), symbol_types, type_errors, type_warnings, name)
  ensure
    @output_type_hints.delete(name) if temp_hint_installed
  end
  validate_declared_olap_type(decl, typed_expr, type_errors)
```

**Lines added:** 9  
**Lines removed:** 1 (the plain `typed_expr = infer_expr(...)` line, replaced by the `begin/ensure` block)  
**Net change:** +8 lines

Remaining lines of the `when "compute"` arm (bind_type derivation, `symbol_types` registration, `typed_decls` append) are **unchanged**.

---

## Why This Cannot Leak

The hint is ephemeral within a single `infer_expr` call stack:

1. `@output_type_hints[name] = declared_type` — installed
2. `infer_expr` called — `infer_record_literal` can now read the hint
3. `ensure @output_type_hints.delete(name)` — removed

The outer declarations loop is serial. No subsequent compute declaration can observe the hint from a prior one. The only way leakage could occur is if an exception propagates out of `infer_expr` AND past the `ensure` — which `ensure` prevents by definition.

---

## Direct Implementation: AUTHORISED

All 13 questions answered with certainty from source. The insertion point is a single location, the approach reuses existing validated code, and there is no design ambiguity. Direct implementation is safe.

**P3 scope:**
- ONE FILE: `igniter-lang/lib/igniter_lang/typechecker.rb`
- ONE ARM: `when "compute"` in the declarations loop
- NO new OOF codes
- NO parser changes
- NO Rust changes
- NO app source changes
- NO new methods
- NO new instance variables

---

## P3 Proof Matrix

Target: ≥55 checks across 10 sections.

| Section | Topic |
|---|---|
| A | Source insertion — no parser changes, one-file scope |
| B | Happy path: `compute p : Point = { x: 1, y: 2 }` → Point |
| C | Output boundary clean: resolved Point flows through output check |
| D | Missing field → OOF-TY0 |
| E | Extra field → OOF-TY0 |
| F | Field type mismatch → OOF-TY0 |
| G | Unknown field value permissive (no disqualification) |
| H | Unannotated record literal unchanged (still Unknown, no OOF) |
| I | Output hint path regression (same-name output/compute unaffected) |
| J | Wave P4 app-pressure fixtures: unannotated computes still Unknown |
| K | No scope widening / no Rust changes |
