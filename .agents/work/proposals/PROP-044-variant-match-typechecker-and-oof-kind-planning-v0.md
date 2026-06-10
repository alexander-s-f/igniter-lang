# PROP-044 — Variant + Match TypeChecker Planning
## variant-match-typechecker-and-oof-kind-planning-v0

**Status:** DESIGN ONLY — no implementation  
**Date:** 2026-06-09  
**Track:** variant-match-typechecker-and-oof-kind-planning-v0  
**Route:** TYPECHECKER DESIGN / NO IMPLEMENTATION  
**Authority:** P4 planning document only  
**Closed:** TypeChecker implementation; SemanticIR emitter; VM runtime; public/stable sum type API

---

## 1. Purpose

PROP-044-P3 proved that `variant`, `variant_construct`, and `match` AST shapes
are correctly parsed and recognized by `grammar_version = "variant-v0"`. The
TypeChecker today emits `OOF-TY0 Unsupported expression kind` for any
`match_expr` or `variant_construct` node — this is the correct P3 boundary.

This document plans what P5 (TypeChecker implementation) must build. It names
every method, store, and data structure; defines all five OOF-KIND error codes
formally; walks through per-arm narrowing and exhaustiveness semantics; and
documents design decisions. No code is written here.

---

## 2. Architecture Overview

The TypeChecker operates in two phases:

1. **Setup phase** (`typecheck()` entry): builds instance-variable registries
   from `classified_program` before any contract is typechecked.
2. **Contract phase** (`typecheck_contract()`): per-contract, walks
   declarations; calls `infer_expr` for compute nodes; accumulates `type_errors`
   and `type_warnings`.

Today's setup phase builds:

- `@type_shapes` — `type_name → {field_name → type_ir}` for all `type`
  declarations
- `@assumption_registry` — assumption registry entries
- `@size_registry` — PROP-041 structural size registry
- `@olap_env` — PROP-040 OLAP point declarations

P5 adds a single new store:

- `@variant_shapes` — `variant_name → {arm_name → {field_name → type_ir}}`

---

## 3. Classifier Bridge (prerequisite for P5)

### 3a. Gap

The Classifier's `classify()` method produces `classified_program`. It calls
`type_declarations(parsed_program)` which reads `parsed_program.fetch("types",
[])` and maps each type into a normalized `{ "kind", "name", "fields" }` hash.

The Classifier does **not** currently read `parsed_program.fetch("variants",
[])`. Until P5 adds this, `classified_program` contains no
`"variant_declarations"` key, and `@variant_shapes` would always be empty.

### 3b. New method: `variant_declarations(parsed_program)`

```ruby
# PROP-044 P5: variant declarations through to TypeChecker
def variant_declarations(parsed_program)
  parsed_program.fetch("variants", []).map do |variant|
    {
      "kind"  => "variant",
      "name"  => variant.fetch("name"),
      "arms"  => variant.fetch("arms", []).map do |arm|
        {
          "name"   => arm.fetch("name"),
          "fields" => arm.fetch("fields", []).map do |field|
            {
              "name"            => field.fetch("name"),
              "type_annotation" => normalized_type_annotation(
                                     field.fetch("type_annotation")
                                   )
            }
          end
        }
      end
    }
  end
end
```

The `normalized_type_annotation` call reuses the existing Classifier method
(which handles `Map[K,V]` params — PROP-043 C1).

### 3c. Propagation into `classified_program`

In `classify()`, after the `size_relations` block:

```ruby
# PROP-044 P5: variant declarations for TypeChecker @variant_shapes
variant_decls = variant_declarations(parsed_program)
result["variant_declarations"] = variant_decls unless variant_decls.empty?
```

This follows the existing conditional-propagation pattern used by
`size_relations`, `olap_points`, etc.

### 3d. Why conditional?

Programs without `variant` declarations produce no key, keeping `classified_program`
identical to today's shape. The TypeChecker uses
`classified_program.fetch("variant_declarations", [])` with a default empty
array — no crash if absent.

---

## 4. `@variant_shapes` Store

### 4a. Structure

```
@variant_shapes : Hash[String, Hash[String, Hash[String, TypeIR]]]

@variant_shapes["ValidationOutcome"]
  = { "Valid"        => { "message"  => type_ir("String"),
                          "metadata" => type_ir("Map", ["String","String"]) },
      "Invalid"      => { "field"    => type_ir("String"),
                          "message"  => type_ir("String"),
                          "metadata" => type_ir("Map", ["String","String"]) },
      "Unauthorized" => { "reason"   => type_ir("String"),
                          "metadata" => type_ir("Map", ["String","String"]) },
      "SystemError"  => { "detail"   => type_ir("String"),
                          "metadata" => type_ir("Map", ["String","String"]) } }
```

Three-level nesting: variant name → arm name → field name → type_ir.

### 4b. `variant_shapes()` method (TypeChecker private)

```ruby
def variant_shapes(classified_program)
  classified_program.fetch("variant_declarations", []).each_with_object({}) do |variant, vshapes|
    vshapes[variant.fetch("name")] =
      variant.fetch("arms", []).each_with_object({}) do |arm, arms|
        arms[arm.fetch("name")] =
          arm.fetch("fields", []).each_with_object({}) do |field, fields|
            fields[field.fetch("name")] = type_ir(field.fetch("type_annotation"))
          end
      end
  end
end
```

Mirrors `type_shapes()` exactly but with the extra arm level.

### 4c. Wiring into `typecheck()`

```ruby
def typecheck(classified_program)
  @type_shapes    = type_shapes(classified_program)
  @variant_shapes = variant_shapes(classified_program)  # PROP-044 P5
  # ... existing setup ...
end
```

Also propagate into the `typed_program` result for downstream consumers:

```ruby
result["variant_env"] = @variant_shapes unless @variant_shapes.empty?
```

### 4d. Querying `@variant_shapes`

```ruby
# Is name a known variant?
def variant_type?(name)
  @variant_shapes.key?(name)
end

# Arms for a variant (empty hash if not a variant)
def variant_arms(name)
  @variant_shapes.fetch(name, {})
end

# Field type for a specific arm (type_ir("Unknown") if not found)
def variant_arm_field_type(variant_name, arm_name, field_name)
  @variant_shapes
    .fetch(variant_name, {})
    .fetch(arm_name, {})
    .fetch(field_name, type_ir("Unknown"))
end
```

---

## 5. `@output_type_hints` Extension

### 5a. Current pre-scan (lines 172-183)

The TypeChecker pre-scans output declarations to build `@output_type_hints`:
a map from declared output name to its `type_shape` hash, used by
`infer_record_literal` to check field completeness.

```ruby
decls.each do |decl|
  next unless decl.fetch("kind") == "output"
  type_name_str = decl.fetch("type", nil)
  next unless type_name_str && @type_shapes.key?(type_name_str)
  @output_type_hints[decl.fetch("name")] = @type_shapes[type_name_str]
end
```

### 5b. Extension for variant output types

A contract may declare `output result : ValidationOutcome`. Today
`@type_shapes` does not contain `ValidationOutcome`, so no hint is stored.

In P5, extend the pre-scan to also check `@variant_shapes`:

```ruby
# PROP-044 P5: output typed as a variant also provides shape hints
if type_name_str && @variant_shapes.key?(type_name_str)
  # Variant output: hint maps arm names → their field shapes
  # Stored as a special sentinel so infer_record_literal can distinguish
  @output_type_hints[decl.fetch("name")] = {
    "__variant__" => type_name_str,
    "__arms__"    => @variant_shapes[type_name_str]
  }
end
```

This sentinel shape is checked in `infer_record_literal` (or the new
`infer_variant_construct`) to provide variant-specific field hints.

**Design Decision DD-07:** `infer_record_literal` is NOT changed to recognize
variant outputs. A `{ field: val }` record literal assigned to a variant-typed
output is an OOF-KIND-adjacent mismatch (not the variant construct form). The
sentinel is checked only in `infer_variant_construct`.

---

## 6. `infer_variant_construct` — Method Design

### 6a. AST input

```json
{ "kind": "variant_construct",
  "arm": "Valid",
  "fields": {
    "message":  { "kind": "ref",     "name": "msg" },
    "metadata": { "kind": "ref",     "name": "ctx" }
  }
}
```

### 6b. Context available

- `expr.fetch("arm")` — arm name (PascalCase string)
- `expr.fetch("fields")` — `{field_name → expr_node}` hash
- `symbol_types` — per-contract scope (inputs + prior computes)
- `@output_type_hints` — sentinel if output is a variant type
- `@variant_shapes` — full variant registry

### 6c. Resolution strategy

The arm name alone (e.g. `"Valid"`) does not identify the variant. The
TypeChecker must look up which variant declares an arm named `"Valid"`:

```ruby
def find_variant_for_arm(arm_name)
  @variant_shapes.each do |variant_name, arms|
    return variant_name if arms.key?(arm_name)
  end
  nil
end
```

**This is unambiguous IFF arm names are unique across all variants in the
program.** See DD-08 for the duplicate arm name policy.

### 6d. Pseudocode

```ruby
def infer_variant_construct(expr, symbol_types, type_errors, type_warnings, node_name)
  arm_name = expr.fetch("arm")
  fields   = expr.fetch("fields", {})

  # Step 1: resolve variant for this arm
  variant_name = find_variant_for_arm(arm_name)
  if variant_name.nil?
    type_errors << oof("OOF-KIND2",
      "variant_construct arm '#{arm_name}' is not declared in any variant",
      node_name)
    return typed_expr("variant_construct", type_ir("Unknown"), [],
                      "arm" => arm_name, "fields" => {})
  end

  arm_fields = @variant_shapes[variant_name][arm_name]  # {field_name → type_ir}

  # Step 2: typecheck each provided field
  typed_fields = {}
  field_deps   = []
  fields.each do |fname, fexpr|
    if arm_fields.key?(fname)
      typed_fexpr = infer_expr(fexpr, symbol_types, type_errors, type_warnings, node_name)
      expected_type = arm_fields[fname]
      # Type mismatch check (see DD-09 for mismatch policy)
      unless types_compatible?(typed_fexpr.fetch("resolved_type"), expected_type)
        type_errors << oof("OOF-KIND2",
          "field '#{fname}' in #{variant_name}::#{arm_name}: " \
          "expected #{type_name(expected_type)}, got #{type_name(typed_fexpr.fetch("resolved_type"))}",
          node_name)
      end
      typed_fields[fname] = typed_fexpr
      field_deps.concat(typed_fexpr.fetch("deps", []))
    else
      # Field not in arm declaration
      type_errors << oof("OOF-KIND2",
        "field '#{fname}' is not declared in #{variant_name}::#{arm_name}",
        node_name)
    end
  end

  # Step 3: check for missing required fields
  arm_fields.each_key do |required_field|
    unless fields.key?(required_field)
      type_errors << oof("OOF-KIND2",
        "field '#{required_field}' required by #{variant_name}::#{arm_name} is missing",
        node_name)
    end
  end

  # Step 4: return typed node with the variant type
  typed_expr(
    "variant_construct",
    type_ir(variant_name),
    field_deps.uniq,
    "arm"          => arm_name,
    "variant"      => variant_name,
    "typed_fields" => typed_fields
  )
end
```

### 6e. Return type

`infer_variant_construct` returns `type_ir(variant_name)` — e.g.
`type_ir("ValidationOutcome")`. This allows `symbol_types` to bind the result
to a compute variable: `compute result = Valid { ... }` makes `result` have
type `ValidationOutcome`.

---

## 7. `infer_match_expr` — Method Design

### 7a. AST input

```json
{ "kind": "match_expr",
  "subject": { "kind": "ref", "name": "outcome" },
  "arms": [
    { "kind": "match_arm",
      "pattern": { "wildcard": false, "arm": "Valid",
                   "bindings": ["message", "metadata"] },
      "body": { "kind": "literal", "value": "accept", "type_tag": "String" }
    },
    ...
    { "kind": "match_arm",
      "pattern": { "wildcard": true, "arm": "_", "bindings": [] },
      "body": { "kind": "literal", "value": "other", "type_tag": "String" }
    }
  ]
}
```

### 7b. Pseudocode — outer method

```ruby
def infer_match_expr(expr, symbol_types, type_errors, type_warnings, node_name)
  subject_node = infer_expr(expr.fetch("subject"), symbol_types,
                             type_errors, type_warnings, node_name)
  subject_type = type_name(subject_node.fetch("resolved_type"))

  # OOF-KIND4: subject must be a known variant type
  unless variant_type?(subject_type)
    type_errors << oof("OOF-KIND4",
      "match subject has type '#{subject_type}' which is not a variant type",
      node_name)
    # Still typecheck arms in degraded mode (subject_type = "Unknown")
    # but do not attempt exhaustiveness or narrowing.
    return infer_match_expr_degraded(expr, symbol_types, type_errors,
                                      type_warnings, node_name)
  end

  declared_arms = variant_arms(subject_type)  # {arm_name → {field_name → type_ir}}
  covered_arms  = {}  # arm_name → true
  has_wildcard  = false
  arm_types     = []
  typed_arms    = []

  expr.fetch("arms").each_with_index do |arm, idx|
    pattern = arm.fetch("pattern")

    if pattern.fetch("wildcard", false)
      has_wildcard = true
      arm_symbol_types = symbol_types  # no bindings for wildcard
      typed_body = infer_expr(arm.fetch("body"), arm_symbol_types,
                               type_errors, type_warnings, node_name)
      arm_types << typed_body.fetch("resolved_type")
      typed_arms << { "pattern" => pattern, "body" => typed_body }
      next
    end

    arm_name = pattern.fetch("arm")
    bindings = pattern.fetch("bindings", [])

    # OOF-KIND3: arm already covered (unreachable)
    if covered_arms.key?(arm_name)
      type_errors << oof("OOF-KIND3",
        "arm '#{arm_name}' is unreachable — already covered at arm #{covered_arms[arm_name]}",
        node_name)
      next
    end

    # OOF-KIND2: arm not declared in the variant
    unless declared_arms.key?(arm_name)
      type_errors << oof("OOF-KIND2",
        "arm '#{arm_name}' is not declared in variant '#{subject_type}'",
        node_name)
      covered_arms[arm_name] = idx
      arm_symbol_types = symbol_types
    else
      covered_arms[arm_name] = idx
      arm_field_shapes = declared_arms[arm_name]

      # Build per-arm narrowed scope: binding_name → type_ir
      arm_bindings = {}
      bindings.each do |binding|
        if arm_field_shapes.key?(binding)
          arm_bindings[binding] = arm_field_shapes[binding]
        else
          # OOF-KIND2: binding not a field of this arm
          type_errors << oof("OOF-KIND2",
            "binding '#{binding}' is not a field of #{subject_type}::#{arm_name}",
            node_name)
          arm_bindings[binding] = type_ir("Unknown")
        end
      end
      arm_symbol_types = symbol_types.merge(arm_bindings)
    end

    typed_body = infer_expr(arm.fetch("body"), arm_symbol_types,
                             type_errors, type_warnings, node_name)
    arm_types << typed_body.fetch("resolved_type")
    typed_arms << { "pattern" => pattern, "body" => typed_body }
  end

  # OOF-KIND1: exhaustiveness check
  uncovered = declared_arms.keys - covered_arms.keys
  if uncovered.any? && !has_wildcard
    type_errors << oof("OOF-KIND1",
      "match on '#{subject_type}' is non-exhaustive — " \
      "missing arms: #{uncovered.sort.join(", ")}",
      node_name)
  end

  # OOF-KIND5: result type unification
  result_type = unify_match_arm_types(arm_types, subject_type, node_name,
                                       type_errors, type_warnings)

  subject_deps = subject_node.fetch("deps", [])
  arm_deps     = typed_arms.flat_map { |a| a.fetch("body", {}).fetch("deps", []) }

  typed_expr(
    "match_expr",
    result_type,
    (subject_deps + arm_deps).uniq,
    "subject"         => subject_node,
    "subject_type"    => subject_type,
    "arms"            => typed_arms,
    "exhaustive"      => uncovered.empty? || has_wildcard,
    "has_wildcard"    => has_wildcard
  )
end
```

### 7c. Degraded mode (OOF-KIND4 fired)

When the subject is not a variant type, the TypeChecker still walks arm bodies
to collect type_errors from within them. It cannot do narrowing or
exhaustiveness. It returns `type_ir("Unknown")` as the result type.

```ruby
def infer_match_expr_degraded(expr, symbol_types, type_errors, type_warnings, node_name)
  expr.fetch("arms").each do |arm|
    infer_expr(arm.fetch("body"), symbol_types, type_errors, type_warnings, node_name)
  end
  typed_expr("match_expr", type_ir("Unknown"), [],
             "subject" => nil, "arms" => [], "exhaustive" => false)
end
```

---

## 8. Result Type Unification — `unify_match_arm_types`

### 8a. Rules

1. If all arms return the same concrete type, the match result is that type.
2. If all arms return `Unknown`, the result is `Unknown`.
3. If arms return a mix of concrete types (e.g. `String` in arm 1, `Integer`
   in arm 2), that is **OOF-KIND5** — the match cannot be used as a typed value.
4. If `Unknown` is mixed in with a concrete type (because one arm had an error),
   do NOT fire OOF-KIND5 — propagate the concrete type and let the prior error
   explain the inconsistency.

### 8b. Pseudocode

```ruby
def unify_match_arm_types(arm_types, subject_type, node_name, type_errors, type_warnings)
  return type_ir("Unknown") if arm_types.empty?

  concrete = arm_types.map { |t| type_name(t) }.reject { |t| t == "Unknown" }.uniq
  return type_ir("Unknown") if concrete.empty?

  if concrete.length == 1
    return type_ir(concrete.first)
  end

  # OOF-KIND5: divergent arm result types
  type_errors << oof("OOF-KIND5",
    "match on '#{subject_type}' has divergent arm result types: " \
    "#{concrete.sort.join(", ")}",
    node_name)
  type_ir("Unknown")
end
```

---

## 9. OOF-KIND Error Codes — Formal Definitions

All five codes are reserved as of PROP-044-P1. P5 activates them.

### OOF-KIND1 — Non-Exhaustive Match

| Field | Value |
|-------|-------|
| **Code** | `OOF-KIND1` |
| **Trigger** | A `match_expr` subject has a known variant type, and one or more arms declared in that variant are absent from the match arm list, and no wildcard `_` arm is present. |
| **Message form** | `match on '<VariantName>' is non-exhaustive — missing arms: Arm1, Arm2` |
| **Node context** | `node_name` of the compute declaration that contains the match |
| **Severity** | Error (blocks typed output) |
| **Resolution** | Add the missing arms, or add a `_` wildcard arm |

### OOF-KIND2 — Undeclared Arm or Binding

| Field | Value |
|-------|-------|
| **Code** | `OOF-KIND2` |
| **Trigger (arm)** | A match arm names an arm not declared in the variant type of the subject; OR a `variant_construct` names an arm not declared in any visible variant |
| **Trigger (binding)** | A match arm binding names a field that is not declared in that arm's field list |
| **Trigger (field)** | A `variant_construct` supplies a field name that is not in the arm, or omits a required field |
| **Message form** | Various; always includes variant, arm, and field/binding names |
| **Severity** | Error |

### OOF-KIND3 — Unreachable Arm

| Field | Value |
|-------|-------|
| **Code** | `OOF-KIND3` |
| **Trigger** | A match arm names an arm that was already covered by a prior arm in the same match expression |
| **Message form** | `arm '<ArmName>' is unreachable — already covered at arm <index>` |
| **Severity** | Error (the arm body is dead code; never executed) |
| **Note** | Arms after a wildcard `_` are also unreachable — fire OOF-KIND3 for each |

### OOF-KIND4 — Non-Variant Match Subject

| Field | Value |
|-------|-------|
| **Code** | `OOF-KIND4` |
| **Trigger** | The subject of a `match_expr` resolves to a type that is not in `@variant_shapes` (includes `Unknown`, `String`, `Integer`, `Map[...]`, any `type`-declared record, etc.) |
| **Message form** | `match subject has type '<TypeName>' which is not a variant type` |
| **Severity** | Error; match is typechecked in degraded mode |
| **Note** | Does NOT fire if the subject is `Unknown` due to a prior `OOF-P1` — the prior error is sufficient |

### OOF-KIND5 — Divergent Arm Result Types

| Field | Value |
|-------|-------|
| **Code** | `OOF-KIND5` |
| **Trigger** | After typechecking all arms, the concrete result types are not all identical (e.g. arm 1 returns `String`, arm 2 returns `Integer`) |
| **Message form** | `match on '<VariantName>' has divergent arm result types: Integer, String` |
| **Severity** | Error; match result assigned `Unknown` |
| **Note** | Does NOT fire if the only divergence involves `Unknown`-typed arms (prior error explains them) |

---

## 10. Per-Arm Scoping — Detailed Rules

### 10a. Binding introduction

For a match arm `Valid { message, metadata } => body`:

- `message` and `metadata` are introduced into `arm_symbol_types` for the
  duration of `body` typechecking only.
- They shadow any outer `symbol_types` binding with the same name (DD-10).
- Their types come from `@variant_shapes[subject_type]["Valid"]`, not from any
  annotation — the binding is structurally typed.

### 10b. Scope isolation

```ruby
arm_symbol_types = symbol_types.merge(arm_bindings)
typed_body = infer_expr(body, arm_symbol_types, ...)
```

`symbol_types` is not mutated. `arm_bindings` is merged into a copy. Bindings
do not escape the arm body.

### 10c. Wildcard arm

A wildcard arm (`_`) introduces no bindings. `arm_symbol_types = symbol_types`
(the outer scope, unmodified). The wildcard does not consume any declared arm —
it is an unconditional catch-all.

### 10d. Wildcard arm position

Arms after a wildcard are unreachable (OOF-KIND3). Wildcard need not be last,
but placing it last is the canonical style. The TypeChecker does not enforce
position — it detects unreachability.

### 10e. Partial binding lists

A match arm may name fewer bindings than the arm has fields:
`Valid { message } => body` — `metadata` is simply not in scope. This is
valid. OOF-KIND2 fires only for bindings that name fields **not declared** in
the arm, not for **absent** fields.

---

## 11. `@output_type_hints` Integration

When a contract declares:

```
output result : ValidationOutcome
```

and the compute body for `result` is a `match_expr` returning
`type_ir("ValidationOutcome")` — the TypeChecker does not need the hint for
type inference (the match already produces the correct type). The hint is
needed for the `infer_record_literal` path, which is not used with variants.

**The output type hint is still checked for compatibility:**

In `typecheck_contract`, after `infer_expr` returns a `typed_expr` for a
compute declaration, the TypeChecker checks:

```ruby
if expected_type && type_name(typed_expr_result) != type_name(expected_type) &&
   type_name(typed_expr_result) != "Unknown"
  type_errors << oof("OOF-TY1", "type mismatch: ...")
end
```

This check naturally handles variant-typed outputs: if `infer_match_expr`
returns `type_ir("ValidationOutcome")` and the output annotation says
`ValidationOutcome`, the check passes. If it says `String`, it fires OOF-TY1.

---

## 12. Method Signatures Summary

```ruby
# TypeChecker private methods for PROP-044 P5

# Registry builder
def variant_shapes(classified_program)
  # → Hash[String, Hash[String, Hash[String, TypeIR]]]

# Registry queries
def variant_type?(name)
  # → Boolean
def variant_arms(name)
  # → Hash[String, Hash[String, TypeIR]] (empty if not a variant)
def variant_arm_field_type(variant_name, arm_name, field_name)
  # → TypeIR (type_ir("Unknown") if not found)
def find_variant_for_arm(arm_name)
  # → String (variant_name) | nil

# Expression inference
def infer_variant_construct(expr, symbol_types, type_errors, type_warnings, node_name)
  # → TypedExpr (resolved_type = type_ir(variant_name) on success)
def infer_match_expr(expr, symbol_types, type_errors, type_warnings, node_name)
  # → TypedExpr (resolved_type = unified arm result type)
def infer_match_expr_degraded(expr, symbol_types, type_errors, type_warnings, node_name)
  # → TypedExpr (resolved_type = type_ir("Unknown"))

# Unification
def unify_match_arm_types(arm_types, subject_type, node_name, type_errors, type_warnings)
  # → TypeIR
```

### Wiring into `infer_expr`

```ruby
when "variant_construct"
  infer_variant_construct(expr, symbol_types, type_errors, type_warnings, node_name)
when "match_expr"
  infer_match_expr(expr, symbol_types, type_errors, type_warnings, node_name)
```

These two `when` arms replace the `else` fallthrough for these node kinds.

---

## 13. Classifier Changes Summary

| File | Change |
|------|--------|
| `classifier.rb` | Add `variant_declarations(parsed_program)` private method |
| `classifier.rb` | Add `result["variant_declarations"] = variant_decls unless variant_decls.empty?` in `classify()` |

No existing method signatures change. No existing tests break. The change is
additive: programs without variants continue to produce identical
`classified_program` output.

---

## 14. TypeChecker Changes Summary

| File | Change |
|------|--------|
| `typechecker.rb` | Add `@variant_shapes = variant_shapes(classified_program)` in `typecheck()` |
| `typechecker.rb` | Add `result["variant_env"] = @variant_shapes unless @variant_shapes.empty?` in `typecheck()` |
| `typechecker.rb` | Add `variant_shapes()` private method |
| `typechecker.rb` | Add `variant_type?()`, `variant_arms()`, `variant_arm_field_type()`, `find_variant_for_arm()` helpers |
| `typechecker.rb` | Add `infer_variant_construct()` private method |
| `typechecker.rb` | Add `infer_match_expr()` private method |
| `typechecker.rb` | Add `infer_match_expr_degraded()` private method |
| `typechecker.rb` | Add `unify_match_arm_types()` private method |
| `typechecker.rb` | Extend `infer_expr` with two new `when` cases |
| `typechecker.rb` | Extend output type hint pre-scan for variant output types (DD-07) |

---

## 15. Design Decisions

### DD-01 — `@variant_shapes` is a separate store from `@type_shapes`

Variant arms are not flat field maps — they have a three-level structure.
Merging variants into `@type_shapes` would require a sentinel or discriminant
to distinguish type shapes from variant shapes. A separate `@variant_shapes`
store preserves clean separation and makes `variant_type?(name)` a single
`Hash#key?` check.

### DD-02 — Arm name resolution by search across `@variant_shapes`

`variant_construct` AST carries only the arm name (`"Valid"`), not the variant
name (`"ValidationOutcome"`). The TypeChecker resolves the variant by searching
all keys of `@variant_shapes` for a match. This is correct if arm names are
unique across variants. DD-08 covers the duplicate case.

### DD-03 — `infer_match_expr` receives `subject_type` from `infer_expr` sub-call

The match subject is an arbitrary expression (`ref`, `field_access`, `call`,
etc.). The TypeChecker infers it normally first, then extracts its
`resolved_type`. This reuses all existing `infer_expr` machinery for the
subject without special-casing.

### DD-04 — Exhaustiveness check uses declared arm set minus covered arm set

`declared_arms.keys - covered_arms.keys` directly computes uncovered arms.
The wildcard flag short-circuits: if `has_wildcard` is true, exhaustiveness is
satisfied regardless of `uncovered`. This matches the parser's wildcard AST
shape (`wildcard: true, arm: "_"`).

### DD-05 — OOF-KIND4 triggers degraded mode, not a hard abort

The match body may contain expressions that produce further errors. Walking the
arms in degraded mode surfaces these errors. An early return after OOF-KIND4
would hide downstream errors and make the first step toward fixing a program
harder.

### DD-06 — OOF-KIND5 does NOT fire when `Unknown` arms are mixed with concrete

An arm that fails type inference already produced its own `OOF-TY0` or
`OOF-KIND2` error. Firing OOF-KIND5 in addition creates redundant noise. The
rule: only concrete–concrete divergence fires KIND5.

### DD-07 — `infer_record_literal` is not changed to recognize variant outputs

A record literal `{ field: val }` assigned to a variant-typed output is a
structural mismatch — the user likely intended `Arm { field: val }`. Feeding
this through the variant hint path would produce confusing "field missing"
errors. It is better for the TypeChecker to fall through to `infer_record_literal`
normally, which will not find the variant name in `@type_shapes` and leave the
type as `Unknown` — the output annotation check then fires a clear OOF-TY1.

### DD-08 — Duplicate arm names across variants

If two variants declare an arm with the same name (e.g. both `OutcomeA` and
`OutcomeB` have arm `Ok`), `find_variant_for_arm("Ok")` is ambiguous.

**P5 policy:** The first variant found in iteration order wins. An additional
OOF-KIND2 warning (not error) is emitted noting the ambiguity. This is a
degenerate case — idiomatic variant names are unique per arm.

**Future:** A separate OOF-KIND check (beyond KIND1..5) can enforce unique arm
names at module scope. Not in P5 scope.

### DD-09 — Type compatibility uses `type_name` string equality

`types_compatible?(a, b)` is initially `type_name(a) == type_name(b)`. This
handles `String == String`, `Integer == Integer`, etc. Map types:
`type_name(type_ir("Map", ["String","String"]))` should return
`"Map[String,String]"` or similar. The existing `type_name` helper already
handles this for PROP-043 — reuse without change.

### DD-10 — Arm bindings shadow outer scope

If the outer `symbol_types` contains `message: type_ir("String")` (from a
prior compute) and the match arm introduces `message` as a binding of type
`Integer`, the arm's `message` takes precedence. This is standard lexical
scoping. The shadow is intentional — the user explicitly named the binding.

### DD-11 — Match result is a compute-level value

A `match_expr` can appear anywhere an expression can appear:

```
compute result = match outcome { ... }
```

The result type of the match becomes the type of `result` in `symbol_types`.
This enables chaining: `compute s = match x { Ok {} => "ok" ... }` → `s` is
`String`.

### DD-12 — Unit arms (no fields) produce empty binding scope

For a variant arm with no fields (e.g. `Pending` in `Signal { Ok Pending Cancelled }`):

```
match sig {
  Pending {} => "waiting"   -- empty binding list, valid
  Pending    => "waiting"   -- also valid (no braces in pattern)
}
```

Either form produces `arm_bindings = {}`. The parser already supports both
(zero-binding arm). TypeChecker simply passes empty `arm_bindings`.

### DD-13 — `grammar_version = "variant-v0"` is already gated in the parser

The TypeChecker reads `classified_program.fetch("grammar_version")` and
propagates it verbatim to `typed_program`. No TypeChecker-level grammar version
change is needed for P5.

### DD-14 — `variant_env` is propagated to `typed_program`

Downstream consumers (SemanticIR emitter, P5) will need `@variant_shapes` to
emit variant type declarations in SemanticIR. Propagating as `"variant_env"`
mirrors `"type_env"` in the existing `typed_program` result.

### DD-15 — Per-arm `typed_arms` shape for SemanticIR readiness

The `typed_expr` for `match_expr` stores `"arms"` as an array of
`{ "pattern" => pattern, "body" => typed_body }` hashes. This is the exact
shape the SemanticIR emitter (P6) will need to emit a `match_node` with
typed arm bodies. No reshaping required at the SemanticIR boundary.

### DD-16 — OOF-KIND3 arms are not typechecked

An unreachable arm's body is dead code. The TypeChecker skips body inference
for OOF-KIND3 arms (the `next` in the pseudocode). This avoids spurious errors
from dead arm bodies that may reference bindings that would be out of scope.

---

## 16. Proof Requirements for P5

P5 must prove:

| Check group | Description |
|-------------|-------------|
| VTCK-SHAPES | `@variant_shapes` populated correctly from fixture variants |
| VTCK-CONSTRUCT-OK | `infer_variant_construct` returns correct variant type, no errors |
| VTCK-CONSTRUCT-ERR | OOF-KIND2 fires for unknown arm, missing field, undeclared field |
| VTCK-MATCH-OK | `infer_match_expr` returns correct unified type, no errors, exhaustive |
| VTCK-KIND1 | OOF-KIND1 fires for missing arm, does not fire with wildcard |
| VTCK-KIND2-ARM | OOF-KIND2 fires for arm not in variant |
| VTCK-KIND2-BINDING | OOF-KIND2 fires for binding not in arm, not for absent binding |
| VTCK-KIND3 | OOF-KIND3 fires for duplicate arm coverage |
| VTCK-KIND4 | OOF-KIND4 fires for String/Integer/record-typed subject |
| VTCK-KIND5 | OOF-KIND5 fires for divergent arm result types, not for Unknown mix |
| VTCK-SCOPE | Arm bindings visible in body, not in adjacent arms or outer scope |
| VTCK-UNIFY | Unified type = concrete type when all arms agree |
| VTCK-DEGRADED | Degraded mode: no crash, arm bodies still walked, Unknown returned |
| VTCK-REGRESSION | Existing proofs (55/55, 45/45, 34/34, 100/100, 50/50) still pass |
| VTCK-BOUNDARY | OOF-TY0 no longer fires for `match_expr` or `variant_construct` nodes |

Target gate: **75/75** or **80/80** PASS (exact count determined when proof is
written). VTCK-BOUNDARY-last must confirm that OOF-TY0 is not emitted for
variant/match nodes.

---

## 17. Promotion Boundary

| Layer | Status |
|-------|--------|
| Proposal (P1) | ✅ DONE |
| Grammar design (P2) | ✅ DONE |
| Parser (P3) | ✅ DONE — 50/50 PASS |
| TypeChecker design (P4, this) | ✅ DONE — design only |
| TypeChecker implementation + OOF-KIND activation (P5) | 🔒 Requires explicit authorization |
| SemanticIR emitter (P6) | 🔒 Requires explicit authorization |
| VM variant dispatch (P7) | 🔒 Requires explicit authorization |

---

## 18. Authority

Design document only. No TypeChecker or Classifier code is changed by this
document. All OOF-KIND codes remain reserved (not active) until P5 is
explicitly authorized.
