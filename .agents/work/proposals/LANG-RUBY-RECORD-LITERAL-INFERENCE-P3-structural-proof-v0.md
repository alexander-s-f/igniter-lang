# LANG-RUBY-RECORD-LITERAL-INFERENCE-P3: Structural Proof

**Status:** CLOSED (direct implementation; 76/76 PASS)  
**Date:** 2026-06-13  
**Proof:** `igniter-lang/experiments/record_literal_inference_proof/verify_record_literal_inference_p3.rb`  
**One-file scope:** `typechecker.rb` only — `infer_record_literal` fallback path

---

## Problem

Unannotated intermediate record literals (`compute name = { ... }`) infer as `Unknown` in Ruby TC when no `@output_type_hints` entry exists for the compute name. Structural field information is present in `@type_shapes` but was never consulted for the unannotated path.

12 `ACTIVE_TRUE_INTERMEDIATE` symbols across 9 apps were blocked by this gap (Wave P5 APP-RECHECK finding).

---

## Implementation

**File:** `igniter-lang/lib/igniter_lang/typechecker.rb`  
**Method:** `infer_record_literal`  
**Insertion:** After the `@output_type_hints` hint-path block, before the final Unknown fallback return  
**Change:** +14 lines (no removals)

```ruby
# P3: structural field-set matching against @type_shapes when no hint was available.
# Finds all type shapes whose field names exactly equal the literal's field names and
# whose field types are compatible (Unknown literal values are permissive).
literal_field_names = typed_fields.keys.sort
candidates = @type_shapes.select do |tn, shape_fields|
  shape_fields.keys.sort == literal_field_names &&
    shape_fields.all? do |fname, exp_type|
      act_type = typed_fields[fname].fetch("resolved_type")
      type_name(act_type) == "Unknown" || structurally_assignable?(act_type, exp_type)
    end
end

if candidates.length == 1
  matched_name, = candidates.first
  return typed_expr("record_literal", type_ir(matched_name), deps, "fields" => typed_fields)
elsif candidates.length > 1
  type_errors << oof(
    "OOF-TY0",
    "Ambiguous record literal type: fields {#{literal_field_names.join(", ")}} match #{candidates.keys.join(", ")}",
    node_name
  )
end
```

**Why `structurally_assignable?` (not `type_name` comparison):**  
Shallow `type_name` comparison cannot distinguish `Collection[IndexedElement]` from `Collection[Integer]` — both return `"Collection"`. The DSA app has `ArrayIndexed { size: Integer, elements: Collection[IndexedElement] }` and `IntSet { size: Integer, elements: Collection[Integer] }` which share the same field names. Full structural assignability with param-depth recursion correctly disambiguates these by element type. Bare `Unknown` field values retain their permissive override via the `type_name(act_type) == "Unknown"` guard.

---

## Candidate Match Rules

| Rule | Implementation |
|---|---|
| Field names exactly equal | `shape_fields.keys.sort == literal_field_names` |
| All candidate fields present | (implied by sorted equality — same set) |
| No extra literal fields | (implied by sorted equality — same set) |
| Field value type compatible | `structurally_assignable?(actual_field_type, expected_field_type)` |
| Unknown field values permissive | `type_name(act_type) == "Unknown"` override (bare Unknown only) |
| Unique candidate → infer type | `candidates.length == 1` → return typed_expr with matched type |
| Zero candidates → Unknown | falls through to existing Unknown return |
| Multiple candidates → OOF-TY0 | emit "Ambiguous record literal type: fields {…} match A, B" |

---

## Preserved Behaviors

| Behavior | How preserved |
|---|---|
| `@output_type_hints` hint path (same-name output/compute) | Structural fallback only runs when `hint_type` block did not return early |
| Annotated compute P2 path | P2 installs temporary hint → hint-path block returns early → structural fallback never reached |
| Zero candidates → Unknown (permissive) | falls through to final `typed_expr("record_literal", type_ir("Unknown"), ...)` |
| OOF-TY0 for ambiguity | existing OOF code; new message "Ambiguous record literal type" |
| P2 bind_type derivation | structurally-inferred type flows into bind_type logic unchanged |
| `@output_type_hints` not mutated | structural fallback only reads `@type_shapes` and `typed_fields` |

---

## Application Impact (Wave P6 live check)

| App | Before P3 (Wave P5) | After P3 | Change |
|---|---|---|---|
| advanced_logistics | ok / 0 | ok / 0 | unchanged — CLEAN |
| vector_math | oof / 41 | oof / 36 | −5 (VM-P09: gravity, point, b, a_min, min_pt resolved; VM-P10 field mismatch correctly surfaced) |
| dsa | oof / 4 | ok / 0 | **RESOLVED** (e0, edge1, s, c_h) |
| vector_editor | oof / 4 | oof / 3 | −1 (default_style, new_pos resolved; stringly append remains) |
| decision_tree | oof / 7 | oof / 7 | unchanged (all stringly call_contract) |
| arch_patterns | oof / 14 | oof / 14 | unchanged (all stringly call_contract) |
| dataframes | oof / 2 | ok / 0 | **RESOLVED** (c00, p1) |
| rule_engine | oof / 3 | oof / 2 | −1 (tx1 resolved; dynamic dispatch d remains) |
| neural_net | oof / 2 | ok / 0 | **RESOLVED** (w1, x1) |
| sim_framework | oof / 4 | oof / 3 | −1 (pop_constraint, wolves resolved; String/Text alias SIM-P10/P11 remains) |

**Net: 3 apps go CLEAN. 12 ACTIVE_TRUE_INTERMEDIATE symbols resolved across 9 apps.**

---

## Proof Matrix

Target: ≥70 checks / 12 sections. **Actual: 76/76 PASS.**

| Section | Checks | Topic |
|---|---|---|
| A | 8 | Source guard: P2 preserved + P3 structural fallback added |
| B | 12 | Unique exact field-set match infers type |
| C | 6 | Output boundary clean after structural inference |
| D | 4 | Field value type mismatch rejects candidate, preserves Unknown |
| E | 5 | Zero candidates preserves Unknown (fail-open) |
| F | 7 | Ambiguity with multiple candidates fails closed |
| G | 4 | Unknown field values are permissive for candidate matching |
| H | 4 | Extra / missing fields do not match any candidate |
| I | 4 | Output hint regression: P2 hint path unchanged |
| J | 5 | Compute annotation regression: P2 annotated compute path unchanged |
| K | 12 | App-pressure fixtures: DSA, Dataframes, Neural net, Rule engine, Sim framework |
| L | 5 | Scope closure: parser, Rust, emitter unchanged |

---

## Key Design Decisions

**Q: Why field-name sorted equality (not subset/subset check)?**  
The card specifies: "candidate field names exactly equal literal field names / all candidate fields present / no extra literal fields." Sorted set equality enforces all three simultaneously. A partial-match would admit too many candidates and create spurious ambiguity.

**Q: Why `structurally_assignable?` not `type_name` comparison?**  
`type_name` is shallow — `Collection[IndexedElement]` and `Collection[Integer]` both return `"Collection"`. DSA has two types (`ArrayIndexed`, `IntSet`) with the same field names but different element types; `structurally_assignable?` correctly distinguishes them by recursively comparing params. The permissive `Unknown` override is kept as an explicit guard before calling `structurally_assignable?`.

**Q: Why not emit an error for zero candidates?**  
The card explicitly requires: "Do not make 'zero candidates' an error in P3 — that would break currently permissive untyped record literals." Apps may use record literals as anonymous data bags without matching any declared type.

**Q: Where does P2 fit in the priority ordering?**  
The P2 annotated-compute path installs a temporary `@output_type_hints` hint, which causes `infer_record_literal` to return early via the hint-path block. The structural fallback is never reached for annotated computes. P3 is strictly additive with P2.

---

## Out of Scope

| Pattern | Route |
|---|---|
| Unannotated record literals in `if/else` branches | `LAB-IF-ELSE-RECORD-LITERAL-TYPING-P1` |
| Nested record literals | `LAB-NESTED-RECORD-LITERAL-TYPING-P1` |
| Rust parity | Not needed; only Ruby TC has record literal inference |
| Structural inference for array element records | Separate track |
| VM-P10 field name mismatch (x/y/z vs r0/r1/r2) | App source alignment or type declaration fix |

---

## Remaining Pressures After P3

| Pressure | App | Root cause | Route |
|---|---|---|---|
| VM-P10 | vector_math | Field name mismatch (x/y/z vs r0/r1/r2) in type declaration vs literals | App-level alignment |
| DT-P03/P09 | decision_tree | Stringly `call_contract("append", ...)` | `LAB-STDLIB-STRINGLY-CALL-CONTRACT-MIGRATION-P1` |
| AP-P02/P11/P12-partial | arch_patterns | Stringly `call_contract("append", ...)` | `LAB-STDLIB-STRINGLY-CALL-CONTRACT-MIGRATION-P1` |
| VE-P02/P03/P08-partial | vector_editor | Stringly `call_contract("append", ...)` | `LAB-STDLIB-STRINGLY-CALL-CONTRACT-MIGRATION-P1` |
| RE-P02/P03/P07-partial | rule_engine | Dynamic `call_contract(variable_callee, ...)` | `LAB-DYNAMIC-CONTRACT-DISPATCH-P1` |
| SIM-P10/P11 | sim_framework | String/Text alias mismatch | `LANG-STRING-TEXT-ALIAS-P1` |
