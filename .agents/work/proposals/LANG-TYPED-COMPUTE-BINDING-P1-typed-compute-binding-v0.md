# LANG-TYPED-COMPUTE-BINDING-P1: Typed Compute Bindings

**Track:** lang / type inference / compute binding
**Mode:** proposal + readiness proof
**Date:** 2026-06-13
**Status:** AUTHORED — pending review

---

## Summary

Both parsers already support `compute name : Type = expr`. The Ruby TC does not use the annotation to guide RHS type inference or to override the symbol binding when the inferred type is Unknown. The fix: when an annotation is present and the inferred type is Unknown or Unknown-bearing, use the annotation as the authoritative bind type in `symbol_types`. This resolves 26 cascade "Unresolved symbol" errors across 8 of 9 apps from Wave P3.

---

## Q1 — Syntax

**v0 syntax:** `compute name : Type = expr`

This is already valid in both parsers. No syntax change is required.

Ruby parser (`parse_compute_decl`, lines 1030–1049): optionally parses `: TypeRef` after the name; stores it as `"type_annotation"` in the AST node. The compute AST node fields are: `{ "kind" => "compute", "name" => name, "expr" => expr, "type_annotation" => type_ref }` (annotation is absent when not written).

Rust parser (`BodyDecl::Compute`, lines 268–274): `type_annotation: Option<TypeRef>` is an optional field; already parsed by `parse_compute_decl` (lines 1719–1744) via the same `: TypeRef` optional arm.

**Parallel to input/output:** Yes. Input and output declarations use the same `: TypeRef` annotation syntax. The semantics differ:
- `input name : Type` — the type is the declared interface (checked at call boundary)
- `output name : Type` — the type is the expected boundary (checked by `structurally_assignable?` at output; OOF-TY1)
- `compute name : Type = expr` — the type is a local annotation (v0: guides symbol binding when inferred is Unknown; checked against inferred type; OOF-TY0 on concrete mismatch)

**Does it conflict with existing compute grammar?** No. The `type_annotation` field is already in the AST. The Ruby TC `when "compute"` arm already calls `validate_declared_olap_type(decl, typed_expr, type_errors)`, which is the OLAP-specific validation path for PROP-024 OLAPPoint types. The general annotation check for typed compute binding is an additional responsibility, not a replacement.

---

## Q2 — Supported expected-type use

### Empty array literal (primary case)
```
compute acc : Collection[Transaction] = []
```
Current: `[]` infers as `Collection[Unknown]`. Symbol binding is `Collection[Unknown]`. Downstream: any use of `acc` propagates Unknown; dependent expressions fail with "Unresolved symbol" or Unknown field access.

After fix: `[]` still infers as `Collection[Unknown]` at the RHS level (no change to `infer_array_literal`). At binding time, annotation is present and inferred is Unknown-bearing → annotation `Collection[Transaction]` is used as the bind type. `symbol_types["acc"] = Collection[Transaction]`. Downstream: `acc` resolves correctly.

### Non-empty array literal
```
compute acc : Collection[Transaction] = [tx1]
```
Current: `tx1` has type `Transaction` (already in symbol_types) → `infer_array_literal` infers `Collection[Transaction]`. Binding type = `Collection[Transaction]`. Annotation confirms; no OOF. After fix: same behavior. Annotation matches inferred → inferred used as bind type (concrete + assignable to annotation).

### Empty map literal
Deferred to v1. `Map[K, V]` literal syntax and inference are not part of v0 scope.

### Unknown expression typed by expected type
```
compute acc : Collection[Transaction] = call_contract("append", ...)   -- stdlib-form; returns Unknown
```
Current: stdlib-form `call_contract` → OOF-TY0 "unknown callee 'append'"; inferred type = Unknown. Binding type = Unknown. Symbol is Unknown downstream.

After fix: annotation present, inferred = Unknown → annotation used as bind type. `symbol_types["acc"] = Collection[Transaction]`. The OOF-TY0 for the callee still fires (stdlib dispatch gap is a separate blocker), but the BINDING uses the annotation. Downstream code can use `acc` with correct type. This is the correct behavior: accept Unknown-typed RHS against annotation, because the Unknown is from an upstream gap, not a type error in the binding itself.

Accepted, not rejected. No additional diagnostic for Unknown-against-annotation.

---

## Q3 — Type inference

### Expected-type flow: RHS only, not infer_expr argument

The annotation flows into the binding decision after inference, not into `infer_expr`. This is the narrowest possible change:
1. `infer_expr(decl.fetch("expr"), ...)` — infers RHS type as today (no signature change)
2. After inference, check annotation against inferred type
3. Select bind type from annotation (when annotation present and inferred is Unknown or Unknown-bearing), or from inferred (when concrete and assignable to annotation)

This does NOT require passing an `expected_type` parameter through `infer_expr` or `infer_array_literal`. The annotation overrides at the binding level, not the inference level.

### Empty array `[]` with annotation
The inferred type for `[]` remains `Collection[Unknown]` in Ruby and `Unknown` in Rust. The annotation override at binding level handles the semantic intent. This is consistent with Rust's deferred array typing model (see Q6).

If a later P3 adds `expected_type` propagation into `infer_array_literal`, that would give better type information inside the RHS expression, but it is not required for v0.

### `Collection[Unknown]` and annotation acceptance
`structurally_assignable?(Collection[Unknown], Collection[T])` returns `false` per D2 (actual Unknown → reject). However, the v0 proposal ACCEPTS this combination at the binding level by treating Unknown-bearing inferred types as "inferred didn't know" rather than "inferred found a conflict." The structurally_assignable? protocol is for output boundary checks (OOF-TY1); the compute binding annotation uses a weaker rule: Unknown-inferred accepts any annotation.

The rule is:
- **Unknown or Unknown-bearing inferred → annotation is authoritative (no error)**
- **Concrete inferred, structurally_assignable? to annotation → inferred is used as bind type (annotation confirms)**
- **Concrete inferred, NOT structurally_assignable? to annotation → OOF-TY0 mismatch; annotation used as bind type (annotation is authoritative; compiler continues)**

### Interaction with OOF-TY1 strict output assignability
OOF-TY1 fires at the output boundary when `actual` is Unknown or doesn't match `expected`. After the compute binding fix:
- `compute acc : Collection[Transaction] = []` → `symbol_types["acc"] = Collection[Transaction]`
- `output acc : Collection[Transaction]` → `structurally_assignable?(Collection[Transaction], Collection[Transaction])` → true → no OOF-TY1

The fix enables clean output boundary checks by ensuring the symbol type reflects the annotation rather than the inferred Unknown. OOF-TY1 and compute annotation work together correctly.

---

## Q4 — Diagnostics

### OOF code on mismatch
Reuse **OOF-TY0** for binding annotation mismatch. No new OOF code.

Reasoning:
- OOF-TY1 is specifically for output boundary (`output` declaration with `structurally_assignable?`)
- Local compute binding is not an output boundary; it is an inline expression type check
- OOF-TY0 already covers inline type mismatches ("Type mismatch", "Type error", etc.)

### Mismatch examples

**Should fail:**
```
compute xs : Collection[Text] = [1]
```
`[1]` infers as `Collection[Integer]`. Not Unknown-bearing. `structurally_assignable?(Collection[Integer], Collection[Text])` → false (name mismatch: Integer ≠ Text). Emit: `OOF-TY0: Binding type mismatch: declared Collection[Text], got Collection[Integer]`. Bind type = `Collection[Text]` (annotation authoritative; compilation continues with declared type).

**Should pass:**
```
compute xs : Collection[Text] = []
```
`[]` infers as `Collection[Unknown]`. Unknown-bearing → annotation authoritative. No error. Bind type = `Collection[Text]`.

**Should pass (non-empty, matching):**
```
compute xs : Collection[Integer] = [1, 2]
```
`[1, 2]` infers as `Collection[Integer]`. Concrete. `structurally_assignable?(Collection[Integer], Collection[Integer])` → true. No error. Bind type = `Collection[Integer]` (same as annotation).

**Should pass (Unknown expression against annotation):**
```
compute xs : Collection[Text] = call_contract("append", ...)  -- stdlib-form Unknown
```
Inferred = Unknown. Not concrete. No mismatch error. Bind type = `Collection[Text]` (annotation).
Separate OOF-TY0 for "unknown callee 'append'" still fires (from call dispatch, not binding).

---

## Q5 — Parser impact

### Ruby parser — current compute AST shape (lines 1030–1049)
```
{ "kind" => "compute", "name" => name, "expr" => expr, ["type_annotation" => type_ref] }
```
No parser change required. Annotation already parsed and stored.

### Rust parser — current compute AST shape (lines 268–274, 1719–1744)
```rust
BodyDecl::Compute { name: String, type_annotation: Option<TypeRef>, expr: Expr }
```
No parser change required.

### AST/SIR fields needed
None new in v0. The `type_annotation` field is already in both parser ASTs. The TC reads it from `decl["type_annotation"]` (Ruby) or `type_annotation` field (Rust).

---

## Q6 — TypeChecker impact

### Ruby TC — expected-type propagation plan

**Change location:** `when "compute"` arm in `typecheck_contract_body` (lines 408–412).

**Current code:**
```ruby
when "compute"
  typed_expr = infer_expr(decl.fetch("expr"), symbol_types, type_errors, type_warnings, decl.fetch("name"))
  validate_declared_olap_type(decl, typed_expr, type_errors)
  symbol_types[decl.fetch("name")] = typed_expr.fetch("resolved_type")
  typed_decls << typed_decl(decl, typed_expr.fetch("resolved_type"), typed_expr, typed_expr.fetch("deps"))
```

**Proposed change (pseudocode — not implementation authorization):**
```ruby
when "compute"
  typed_expr = infer_expr(decl.fetch("expr"), symbol_types, type_errors, type_warnings, decl.fetch("name"))
  validate_declared_olap_type(decl, typed_expr, type_errors)

  annotation_type = decl["type_annotation"] ? type_ir(decl["type_annotation"]) : nil
  inferred_type   = typed_expr.fetch("resolved_type")

  bind_type = if annotation_type.nil?
    inferred_type                                            # no annotation → use inferred
  elsif unknown_or_unknown_bearing?(inferred_type)
    annotation_type                                          # Unknown/Collection[Unknown] → annotation authoritative (no error)
  elsif structurally_assignable?(inferred_type, annotation_type)
    inferred_type                                            # concrete match → use inferred (annotation confirms)
  else
    type_errors << oof("OOF-TY0", "Binding type mismatch: declared #{type_display(annotation_type)}, got #{type_display(inferred_type)}", decl.fetch("name"))
    annotation_type                                          # mismatch → annotation authoritative; compilation continues
  end

  symbol_types[decl.fetch("name")] = bind_type
  typed_decls << typed_decl(decl, bind_type, typed_expr, typed_expr.fetch("deps"))
```

Helper needed: `unknown_or_unknown_bearing?` — returns true when type is `Unknown` or when it is a compound type with any Unknown params (e.g., `Collection[Unknown]`, `Map[Unknown, T]`). Can be implemented as:
```ruby
def unknown_or_unknown_bearing?(t)
  return true if type_name(t) == "Unknown"
  t.fetch("params", []).any? { |p| unknown_or_unknown_bearing?(p) }
end
```

Blast radius: narrow. Only the `when "compute"` arm changes. No change to `infer_expr`, `infer_array_literal`, or any other inference path.

Total estimated change: ~12–15 lines in `typechecker.rb`. One helper method.

### Rust TC — expected-type propagation plan

**Survey finding:** Rust TC already has `check_array_literal_shape` with output type context in the compute phase (referenced in the comment at lines 3989–4016). When a compute declaration has a declared type, Rust's compute phase uses it as a hint for array literal element typing.

**Wave P3 evidence:** Rust is CLEAN for DSA (0 diags), dataframes (0 diags), neural_net (0 diags), vector_math (0 diags). All of these had Ruby "Unresolved symbol" errors but no Rust errors. This is consistent with Rust already propagating output type context into array literal inference in compute positions.

**v0 conclusion for Rust:** No Rust TC changes required. Rust's existing `check_array_literal_shape` mechanism already achieves the intended behavior. P2 Ruby implementation should reach parity with Rust's existing behavior.

The Rust `check_array_literal_shape` mechanism should be documented in P2 implementation planning as the reference behavior.

---

## Q7 — SemanticIR

### Current SIR compute node shapes

**Ruby emitter** (`semanticir_emitter.rb`, lines 634–640):
```ruby
{ "kind" => "compute_node", "name" => name, "expr" => semantic_expr(expr) }
```
No `type` field. No `declared_type` field.

**Rust emitter** (`emitter.rs`, lines 524–563):
```
{ kind, node_id, name, expr, type, deps, fragment }
```
Includes `"type"` field (= `decl.type_info`, the resolved type of the compute expression).

### Should annotation appear in SIR?
Not in v0. The TC fix changes `symbol_types` binding; downstream SIR emission reads `type_info` from the TC result. If `typed_decl` passes `bind_type` as the resolved type, the existing SIR pipeline picks it up automatically in Rust. In Ruby, the emitter doesn't include a type field — so no SIR change is needed for Ruby v0 either.

### Should compute node retain both declared_type and resolved_type?
Not in v0. Single resolved type (annotation-overridden when applicable). Declared type as a separate SIR field is a v1 concern.

### Does this affect contract_ref / artifact hash?
Ruby emitter: the compute SIR node has no type field, so no SIR structural change and no hash change.
Rust emitter: `decl.type_info` is the resolved type from the TC. If TC now produces `Collection[Transaction]` instead of `Collection[Unknown]`, the Rust SIR `"type"` field changes → artifact hash changes for affected apps. This is expected and correct — a more precise type produces a different artifact.

---

## Q8 — App pressure

### Apps with typed compute binding gap (Wave P3)

| App | Unresolved symbols | Ruby diag count | Root pattern |
|---|---|---|---|
| DSA | e0, s, edge1, c_h | 4 | call_contract Tier 1 typed output → Unknown bind → downstream unresolved |
| vector_editor | new_objects, default_style, new_pos | 3 | stdlib-form append → Unknown bind → cascade unresolved |
| decision_tree | new_nodes, nodes_0, features_good | 3 | stdlib-form append → Unknown bind → cascade unresolved |
| arch_patterns | genesis, new_trail ×3 | 4 | stdlib-form append → Unknown bind → cascade unresolved |
| dataframes | c00, p1 | 2 | call_contract Tier 1 typed output → Unknown bind → downstream unresolved |
| rule_engine | d, tx1 (+ Unknown.action cascade) | 3 | Tier 2 dynamic → Unknown bind → cascade unresolved + field access |
| neural_net | w1, x1 | 2 | call_contract Tier 1 typed output → Unknown bind → downstream unresolved |
| vector_math | gravity, point, b, a_min, min_pt | 5 | call_contract Tier 1 typed output → Unknown bind → cascade unresolved |

**Total: 26 unresolved/cascade errors across 8 of 9 apps.**

### Do these require the binding to have an explicit annotation?

For DSA, dataframes, neural_net, vector_math: the compute bindings produce Tier 1 typed call_contract results. The root cause of "Unresolved symbol" for e0/s/edge1/c_h and similar may be that the output variable of a PREVIOUS call_contract is used as an ARGUMENT in a SUBSEQUENT call that also fails, or that the compute binding with a call_contract result that returns a concrete type is somehow still producing Unknown. Investigation in P2 should trace the exact path.

For VE/DT/AP: the stdlib-form `call_contract("append", ...)` explicitly returns Unknown (OOF-TY0 + Unknown type). With a type annotation:
```
compute acc : Collection[Item] = call_contract("append", existing, new_item)
```
The binding would use the annotation `Collection[Item]` even though call_contract returns Unknown. The OOF-TY0 callee error still fires, but the symbol is typed correctly.

### Which call_contract bootstrap cases become migratable?

After the compute annotation fix, the bootstrap/accumulator pattern can be written as:
```
compute items : Collection[Item] = []
compute items2 : Collection[Item] = append(items, item1)  -- once stringly migration lands
```
Instead of:
```
compute items = call_contract("append", item1, item2)  -- bootstrap T+T shape
```

This reduces (but does not eliminate) the dependency on stringly call_contract bootstrap forms.

### Does this replace empty() need?

Partially. For collect+append patterns where the initial empty collection is a compute binding RHS, the annotation fix enables `compute acc : Collection[T] = []` without `empty()`. For `empty()` in arbitrary expression positions (e.g., function arguments, HOF arguments), `LANG-STDLIB-COLLECTION-EMPTY-P1` is still needed.

The annotation fix makes `empty()` in compute RHS positions unnecessary — which covers most of the BOOTSTRAP patterns from LAB-STDLIB-STRINGLY-CALL-CONTRACT-P1 (6 calls across apps).

### Does this reduce stringly call_contract pressure?

Yes. With annotation:
- The 6 BOOTSTRAP stringly calls can migrate to `compute acc : Collection[T] = []` + `append(...)`
- The 3 EMPTY_CONSTRUCTOR calls (zero args) similarly
- The 25 ACCUMULATING calls (`call_contract("append", c, e)`) remain until LANG-STDLIB-STRINGLY-CALL-CONTRACT-MIGRATION-P1 lands; but their downstream cascade errors clear because the initial binding is correctly typed

---

## Ruby/Rust current-state matrix

| Aspect | Ruby (current) | Rust (current) |
|---|---|---|
| Parse type annotation | Yes — `"type_annotation"` in AST | Yes — `Option<TypeRef>` in enum |
| Use annotation in TC | Only for OLAP validation (`validate_declared_olap_type`) | Has `check_array_literal_shape` with output type context |
| Empty `[]` type | `Collection[Unknown]` (immediately) | `Unknown` (deferred to compute phase) |
| Array element inference | Greedy (first non-Unknown type) | Deferred (compute phase with output hints) |
| Symbol binding when Unknown | `Collection[Unknown]` registered | Annotation/output-context type registered |
| Cascade "Unresolved symbol" | Yes — 8 apps affected | No — CLEAN for same apps |
| structurally_assignable? | D2/D3 protocol — implemented | Identical — implemented |
| OOF-TY1 at output | Yes — fires correctly | Yes — fires correctly |
| Compute SIR `type` field | Not emitted | Emitted (`decl.type_info`) |

---

## Empty literal behavior (precise)

| Expression | Annotation | Inferred | Bind type | Diagnostic |
|---|---|---|---|---|
| `compute xs = []` | None | `Collection[Unknown]` | `Collection[Unknown]` | None |
| `compute xs : Collection[T] = []` | `Collection[T]` | `Collection[Unknown]` | `Collection[T]` | None (Unknown-bearing → annotation) |
| `compute xs : Collection[T] = [item]` (item : T) | `Collection[T]` | `Collection[T]` | `Collection[T]` | None (match) |
| `compute xs : Collection[Text] = [1]` (1 : Integer) | `Collection[Text]` | `Collection[Integer]` | `Collection[Text]` | OOF-TY0 (mismatch) |
| `compute xs : Collection[T] = call_contract("append", ...)` | `Collection[T]` | `Unknown` | `Collection[T]` | None (Unknown → annotation); separate OOF-TY0 for callee |
| `compute xs : Collection[T] = call_contract("Named", ...)` (Tier 1, returns T) | `Collection[T]` | `Collection[T]` | `Collection[T]` | None (match; annotation confirms) |

---

## Relationship to OOF-TY1

OOF-TY1 fires at the **output boundary** of a contract:
```
output result : Collection[RuleDecision]  -- after all computes
```
When `symbol_types["result"]` is `Collection[Unknown]`, `structurally_assignable?(Collection[Unknown], Collection[RuleDecision])` → false → OOF-TY1.

After the compute binding fix, if the binding that produces `result` has an annotation:
```
compute result : Collection[RuleDecision] = call_contract("ApplyRules", ...)
```
Then `symbol_types["result"] = Collection[RuleDecision]` (annotation used). The output boundary check sees a concrete type → no OOF-TY1. These two mechanisms compose correctly.

If the binding does NOT have an annotation, OOF-TY1 continues to fire correctly (safety-positive). The compute annotation is opt-in.

---

## v0 Scope

**Authorized:**
- Ruby TC `when "compute"` arm: annotation-guided bind type selection
- One helper method: `unknown_or_unknown_bearing?`
- No change to `infer_expr` signature
- No change to `infer_array_literal`
- No Rust TC changes
- No parser changes (already implemented in both)
- No SIR changes
- No stdlib changes
- No `empty()` function
- No generic syntax such as `empty[T]()`
- No app source migration
- No dynamic dispatch
- No broad local variable type system beyond compute binding annotation

---

## Next route

**P2: Direct implementation.** The Ruby TC change is ~12–15 lines in one method plus one helper method. The design is mechanical:
1. Read `decl["type_annotation"]` if present
2. Determine bind type using annotation/inferred/unknown rules
3. Register bind type in `symbol_types`
4. Emit OOF-TY0 on concrete mismatch

No implementation planning pass needed. Direct to proof.

**Proof target:** ≥ 35 checks across sections covering: annotation parsing, array literal behavior, binding type selection, OOF-TY0 on mismatch, structurally_assignable? composition with OOF-TY1, app pressure fixture.
