# LAB-NESTED-RECORD-LITERAL-TYPING-P1: Nested Record Hint Leakage

**Status:** CLOSED -- direct implementation -- 60/60 PASS
**Date:** 2026-06-14
**Scope:** Ruby TypeChecker record literal inference
**Implementation:** `lib/igniter_lang/typechecker.rb`
**Proof:** `experiments/nested_record_literal_typing_proof/verify_nested_record_literal_typing_p1.rb`

---

## Problem

Ruby `infer_record_literal` inferred every field-value expression with the same
`node_name` as the outer record literal. For same-name output hints such as:

```igniter
compute result = {
  r0: { x: 1, y: 0, z: 0 },
  r1: { x: 0, y: 1, z: 0 },
  r2: { x: 0, y: 0, z: 1 }
}
output result : Mat3
```

the outer `@output_type_hints["result"] = Mat3` also applied to each inner
`{x,y,z}` row literal. The inner Vec3 rows were therefore validated as Mat3 and
reported false `missing required field: r0/r1/r2` plus `unexpected field: x/y/z`
diagnostics.

This was the compiler gap discovered during
`LAB-VECTOR-MATH-FIELD-ALIGNMENT-P1`, where the app workaround extracted rows as
annotated computes.

---

## Decision

Nested field-value record literals should receive expected field context under a
synthetic field-node name, not the outer node name.

Example:

| Literal | Context |
| --- | --- |
| outer `compute result = {...}` | `result` |
| field `r0: {x,y,z}` | `result.r0` |
| field `matrix.r0: {x,y,z}` | `result.matrix.r0` |

This keeps the outer hint authoritative for the outer literal while allowing
nested rows to validate against their declared field type when the outer record
shape provides one.

---

## Implementation

`typechecker.rb` now:

1. Captures the outer hint before inferring field values.
2. Computes a synthetic field node with `record_literal_field_node_name`.
3. For nested record literal field values whose expected field type is a known
   named record, temporarily installs:

```ruby
@output_type_hints[field_node_name] = expected_field_type
```

4. Restores or deletes that temporary hint in an `ensure` block.
5. Leaves the outer hint-path validation and output-boundary
   `structurally_assignable?` check unchanged.

This is a one-file patch. No parser, emitter, Rust, VM, app source, or public
surface changes were made.

---

## Questions Answered

1. Minimal inline fixture reproduces the old bug without app source complexity.
2. The implementation bug is Ruby-specific for this card; Rust has a separate
   compute-phase record-literal validation path and no Rust change was needed.
3. The leaking call path was field-value inference inside `infer_record_literal`.
4. `nil` was too weak because it can hide nested field type mismatches. Bare
   field names risk collision with same-name output hints. The accepted context
   is expected field type under a synthetic field-node name.
5. Same-name output hints and annotated compute hints are preserved.
6. P3 structural matching and P5 empty-array field wildcard behavior are
   preserved by regression proofs.
7. A direct nested `vector_math` Mat3 fixture now compiles cleanly. The previous
   app workaround can remain as source hygiene; it is no longer required by Ruby
   TC for this shape.

---

## Proof Matrix

`verify_nested_record_literal_typing_p1.rb`: 60/60 PASS

| Section | Checks | Focus |
| --- | ---: | --- |
| A | 10 | Source guards and closed parser surface |
| B | 12 | Direct nested Mat3 and deeper Scene records |
| C | 8 | Precise nested errors on synthetic nodes |
| D | 6 | Ordinary outer record errors preserved |
| E | 6 | Same-name output collision and annotated computes |
| F | 7 | P3/P5 guardrails |
| G | 5 | Direct vector_math-style nested fixture |
| H | 6 | Closed surfaces and Rust parity boundary |

Regression proofs:

- `verify_record_literal_inference_p3.rb`: 76/76 PASS
- `verify_record_literal_inference_p4.rb`: 29/29 PASS

---

## Safety Properties

- No optional-field semantics.
- No broad record-literal redesign.
- No relaxation of output assignability.
- No new OOF code.
- No Rust implementation.
- No app migration.
- Temporary nested hints are restored with `ensure`.

---

## Closure

`LAB-NESTED-RECORD-LITERAL-TYPING-P1` is closed as a bounded Ruby compiler
correctness fix. The proof distinguishes false outer-hint leakage from real
outer and inner record shape errors, and preserves existing record inference
lanes.
