# LANG-RUBY-RECORD-LITERAL-INFERENCE-P1: Record Literal Inference — Readiness Proof

**Status:** CLOSED (readiness proof; P2 design authorized)
**Proof:** `igniter-lang/experiments/record_literal_inference_proof/verify_record_literal_inference_p1.rb` — 49/49 PASS
**One-file scope:** `typechecker.rb` only (P2)

---

## Problem Statement

Ruby TC `infer_record_literal` (typechecker.rb ~line 2883) returns `type_ir("Unknown")` for unannotated intermediate compute bindings with record literal RHS when no `@output_type_hints` entry exists for the compute name. This cascades to `OOF-P1 "Unresolved symbol: <name>"` whenever the intermediate value is subsequently referenced.

The gap affects 8+ apps and 15+ active pressure entries across the lab corpus.

---

## 13 Research Questions — Answers

### Q1: Does the parser already preserve `type_annotation` for compute bindings with record literal RHS?

**Yes.** Parser `body[]` for a compute binding preserves `type_annotation` when present; it is `nil` when absent (A-01 through A-05 PASS). No parser changes needed.

### Q2: What exact shape does the record literal AST use?

```json
{"kind": "record_literal", "fields": {"x": {"kind": "literal", "value": 1, "type_tag": "Integer"}, ...}}
```

Field values are sub-expressions with their own `kind` and `type_tag` (B-01 through B-04 PASS).

### Q3: What does current `infer_record_literal` return and why?

`infer_record_literal` first checks `@output_type_hints&.fetch(node_name, nil)`. If a hint is present, it validates field shapes and returns the expected named type. If no hint → returns `type_ir("Unknown")` unconditionally (line 2927).

`@output_type_hints` is built by a pre-scan of output declarations only (lines 327–333). Compute declarations are excluded. Intermediate computes that don't share a name with any output have no hint → Unknown.

### Q4: Does Ruby TC have enough type shape information in `@type_shapes` to validate fields?

**Yes.** `@type_shapes` (exposed as `type_env` in TC result) contains the full `{field_name → type_ir}` map for every user-declared type (D-01 through D-04 PASS). Field names and types are available for structural matching.

### Q5: Should the expected type come from compute annotation, output declaration context, variable binding context, or all of the above?

**P2 answer: structural shape matching from `@type_shapes`.** Neither annotation alone (annotated case already handled by P2) nor output decl context (requires backward propagation — P3+) nor variable binding context (forward-only pass). The practical fix is: when `infer_record_literal` has no hint, try to match the record literal's field-name set against `@type_shapes` entries; if exactly one passes both name and type compatibility checks → infer that type.

### Q6: What is the narrowest P2/P3 route?

**P2 (direct implementation):** Add a structural field-matching fallback inside `infer_record_literal` in `typechecker.rb`. Single-method change, ~15 lines. High app impact.

**No intermediate planning card needed** — the fix is well-understood and bounded to one method in one file.

### Q7: Should missing fields fail immediately?

**No.** In the structural matching path (no expected type declared), the goal is type resolution, not enforcement. If fields don't match any type uniquely → fall back to Unknown (current behavior). Missing field OOF-TY0 fires in the `@output_type_hints` path (F-01 PASS) — that existing mechanism is unchanged.

### Q8: Should extra fields fail immediately?

**No** — same rationale as Q7. The structural match path is for inference only. OOF-TY0 for extra fields continues to fire in the output_type_hints path.

### Q9: Should field type mismatches use `OOF-TY0` or a new code?

**Use existing `OOF-TY0`.** The P2 structural matching path uses type compatibility as a filter (if types are incompatible → candidate is excluded from matches), not as a diagnostic trigger. Existing OOF-TY0 from the `@output_type_hints` path is unchanged (H-01 through H-02 PASS).

### Q10: How should Unknown field values behave?

**Permissive.** When a record literal field value is Unknown, it does not disqualify a type candidate. This mirrors the existing `infer_record_literal` behavior: `type_name(actual_type) == "Unknown"` is treated as compatible with any expected type (I-03 PASS).

### Q11: Should nested record literals be supported in v0?

**No — out of scope for P2.** Inner record literals in field value positions (`compute a = { x: { inner: 1 } }`) are a separate structural inference problem. Route: `LAB-NESTED-RECORD-LITERAL-TYPING-P1`.

### Q12: Does this fix inline records in `if/else`, or is that separate?

**Separate.** The `@output_type_hints` mechanism already handles the same-name output/compute if-else pattern (J-02: CLEAN). The gap is for intermediate computes returning record literals from if/else branches where no output_type_hints match. Route: `LAB-IF-ELSE-RECORD-LITERAL-TYPING-P1` (already registered as SIM-P05).

### Q13: Which app pressures are unblocked by compute-annotation record inference alone?

**Zero.** No app in the corpus uses `compute name : Type = { ... }` form (annotated intermediate compute + record literal). The annotated case was already fixed by `LANG-TYPED-COMPUTE-BINDING-P2` (C-04 PASS — P2 bind_type from annotation makes field access work via symbol_types even though typed_expr.resolved_type is still Unknown).

The real impact comes from structural matching for unannotated computes (Q5/Q6).

---

## App Pressure Impact Table

| App | Symbol | Fields | Unique @type_shapes match | Status |
|---|---|---|---|---|
| dsa | e0, c_h | {index, value} | IndexedElement ✓ | Unblocked by structural matching |
| dsa | edge1, edge2, edge3 | {from_node, to_node, weight} | Edge ✓ | Unblocked |
| dsa | s (IntSet case) | {size, elements[Integer]} | IntSet ✓ (type checking disambiguates from ArrayIndexed) | Unblocked when c1 element type is concrete |
| dsa | arr (ArrayIndexed) | {size, elements[IndexedElement]} | ArrayIndexed ✓ (after e0 resolved first) | Unblocked with sequential fix |
| neural_net | x1, x2 | {x1, x2} | InputVector ✓ | Unblocked |
| neural_net | w1 | {w11,w12,w21,w22,b1,b2} | Weights2x2 ✓ | Unblocked |
| dataframes | c00 | {row, col, val} | Cell ✓ | Unblocked |
| dataframes | p1 | {row_id, col_name, val} | DataPoint ✓ | Unblocked |
| vector_editor | default_style | {fill_hex, stroke_hex, stroke_width} | Style ✓ | Unblocked |
| vector_editor | new_pos | {x, y} | Point ✓ | Unblocked |
| arch_patterns | genesis | {account_id, status, balance, version} | AccountState ✓ | Unblocked |
| rule_engine | tx1 | {id, amount, currency, status, fraud_score} | Transaction ✓ | Unblocked |
| vector_math | gravity, point, min_pt, a_min, b | {x,y,z} or {x,y} | Vec3 or Vec2 ✓ | Unblocked |
| sim_framework | pop_constraint | {name, entity_type, field, min_val, max_val} | ConstraintDef ✓ | Unblocked |
| sim_framework | wolves | {id, entity_type, name, region, population, resources} | Entity ✓ | Unblocked |

**Not unblocked by structural matching alone:** VM-P09 symbols already have unique matches (Vec3, Vec2) — structural matching would work. VM-P10 (field name mismatch `x/y/z` vs `r0/r1/r2` in vec2/vec3 result computes) is a separate field-name alignment issue requiring app-level investigation, not a structural matching gap.

---

## P2 Design: Structural Field-Matching Fallback

### Location

`infer_record_literal` in `typechecker.rb` — add before the final fallback `return` at line 2927.

### Algorithm

```
1. Collect literal_field_names = fields.keys.to_set
2. Find all @type_shapes entries where shape.keys.to_set == literal_field_names
   (= candidates)
3. If candidates is empty or has > 1 entry:
   a. Filter by type compatibility: for each candidate, check all field types
      - actual = typed_fields[fname].resolved_type
      - skip if type_name(actual) == "Unknown" (permissive)
      - discard candidate if type_name(actual) != type_name(expected)
   b. If filtered to exactly one candidate → use it
   c. Otherwise → fall through to Unknown (current behavior)
4. If candidates has exactly 1 entry from step 2, still validate types (step 3a):
   - Eliminates false positives from coincidental field-name matches
5. Return typed_expr("record_literal", type_ir(matched_type_name), deps, ...)
```

### Implementation Sketch

```ruby
# Structural field-matching fallback — add inside infer_record_literal before final return
literal_field_names = fields.keys.to_set
candidates = @type_shapes.select { |_, shape| shape.keys.to_set == literal_field_names }

if candidates.any?
  type_compatible = candidates.select do |_, expected_fields|
    expected_fields.all? do |fname, expected_type|
      actual_type = typed_fields[fname].fetch("resolved_type")
      type_name(actual_type) == "Unknown" ||
        structurally_assignable?(actual_type, expected_type)
    end
  end
  if type_compatible.length == 1
    matched_name = type_compatible.keys.first
    return typed_expr("record_literal", type_ir(matched_name), deps, "fields" => typed_fields)
  end
end

typed_expr("record_literal", type_ir("Unknown"), deps, "fields" => typed_fields)
```

### Key Properties

- **No OOF emissions**: structural matching path is inference only, not validation
- **Unknown permissive**: Unknown-typed field values don't disqualify a candidate
- **Ambiguity-safe**: zero or multiple candidates → Unknown (current behavior preserved)
- **Sequential benefit**: each resolved intermediate unlocks downstream resolutions (DSA `arr` resolves after `e0` is resolved)
- **No parser changes**: type_annotation is read but not required
- **Annotated path unchanged**: `@output_type_hints` path (same-name output/compute) unchanged; `LANG-TYPED-COMPUTE-BINDING-P2` annotated bind path unchanged
- **Existing field validation unchanged**: OOF-TY0 for missing/extra/mismatched fields continues to fire in the output_type_hints path

### New Helper

`infer_record_literal_with_expected_type` is NOT needed — the structural matching fallback is added directly to `infer_record_literal`, preserving the existing interface.

---

## Out-of-Scope for P2

| Pattern | Route |
|---|---|
| Annotated intermediate compute (`compute e0 : T = {...}`) | Already fixed by `LANG-TYPED-COMPUTE-BINDING-P2` |
| Inline records in `if/else` branches (non-output context) | `LAB-IF-ELSE-RECORD-LITERAL-TYPING-P1` (= SIM-P05) |
| Nested record literals (record in field position) | `LAB-NESTED-RECORD-LITERAL-TYPING-P1` |
| Array element record literals (`[{...}, {...}]`) | HOF context propagation track |
| Unannotated records where field names don't match any type | Remain Unknown; no false inference |
| VM-P10 field name mismatch (`x/y/z` vs `r0/r1/r2`) | App-level investigation (not a structural matching gap) |

---

## Proof Runner

`igniter-lang/experiments/record_literal_inference_proof/verify_record_literal_inference_p1.rb` — 49/49 PASS

| Section | Checks | Topic |
|---|---|---|
| A | 5 | Parser preserves compute type_annotation |
| B | 4 | AST record literal shape |
| C | 5 | Current Ruby TC gap reproduces |
| D | 4 | @type_shapes has required metadata |
| E | 10 | App fixture gap inventory |
| F | 3 | Missing field → OOF-TY0 |
| G | 2 | Extra field → OOF-TY0 |
| H | 2 | Field type mismatch → OOF-TY0 |
| I | 3 | Unknown field value permissive |
| J | 4 | Nested/if-else/array out-of-scope classification |
| K | 3 | Rust comparison |
| L | 4 | Authority and scope closure |

---

## P2 Authorization

P2 is authorized. Scope:

- ONE FILE: `igniter-lang/lib/igniter_lang/typechecker.rb`
- ONE METHOD: `infer_record_literal` — add structural field-matching fallback (~15 lines)
- NO new OOF codes
- NO parser changes
- NO Rust changes
- NO app source changes
- NO stdlib proposal
