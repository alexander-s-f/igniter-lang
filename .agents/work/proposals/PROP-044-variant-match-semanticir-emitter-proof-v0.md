# PROP-044-P6 Gap Packet — SemanticIR Emitter for `variant` + `match`

**Track:** variant-match-semanticir-emitter-proof-v0  
**Route:** SEMANTICIR EMITTER IMPLEMENTATION / BOUNDED  
**Date:** 2026-06-10  
**Proof:** 50/50 PASS  

---

## What Was Delivered

Three edits to `semanticir_emitter.rb`:

1. **`typed_semantic_ir_program`** — emit `variant_declarations` array by reading `typed_program["variant_env"]` (the 3-level hash produced by P5). The variant_decl array lives at the top level of `semantic_ir_program`, not inside any contract.

2. **`semantic_expr` dispatch** — added `elsif "variant_construct"` and `elsif "match_expr"` branches before the existing recur-call check. Without these, both expression kinds would fall through to the generic hash-recursive transform, which would: (a) produce `match_expr` kind instead of the designed `match_node` kind, and (b) not rename `typed_fields` → `fields` in construct nodes.

3. **Four new methods:**
   - `semantic_variant_declarations(variant_env)` — converts 3-level hash to array of `variant_decl` nodes
   - `semantic_variant_construct(expr)` — renames `typed_fields` → `fields`; drops `deps`; preserves arm/variant/resolved_type
   - `semantic_match_node(expr)` — renames kind from `match_expr` → `match_node`; lowers all arms; preserves exhaustive/has_wildcard flags
   - `semantic_match_arm(arm)` — preserves pattern verbatim (including bindings list); lowers body via `semantic_expr`; emits arm-level `resolved_type`

---

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | `match_expr` → `match_node` kind rename | Distinguishes SemanticIR shape from TypeChecker intermediate; `match_node` is the planned canonical shape from P2 grammar design |
| D2 | `typed_fields` → `fields` rename in construct | TypeChecker uses `typed_fields` to communicate it has inferred types; SemanticIR consumers want `fields` without the internal prefix |
| D3 | `variant_declarations` at top-level (not per-contract) | Variant declarations are module-level; they do not belong to any single contract; mirrors how `assumption_registry` is emitted |
| D4 | Unit arms emitted with `fields: []` | Absence vs empty-array distinction avoided; downstream consumers check `fields.empty?` not presence |
| D5 | Pattern preserved verbatim in match arms | Pattern hash from TypeChecker (wildcard, arm name, bindings) is already the right IR shape; no lowering needed |
| D6 | OOF guard at `emit_typed` boundary | `emit_typed` already checks `type_errors.empty?`; all OOF-KIND* programs produce nil semantic_ir without any additional check in the new methods |

---

## What Remains Closed

- **VM runtime** — no OP_MATCH, no variant dispatch bytecode, no changes to `igniter-lab`
- **Stable public API** — the SemanticIR shape is experimental; consumers must not treat it as stable
- **Grammar expansion** — no new syntax, no match guards, no nested match expansion
- **`emit` (old path)** — only `emit_typed` is extended; the non-typed `emit` path does not receive variant/match support

---

## Known Gap: Old `emit` Path

The `emit` path (not `emit_typed`) is the legacy single-pass path that doesn't go through the TypeChecker. It remains unchanged. Programs using variant/match can only be compiled through the `emit_typed` path (Parser → Classifier → TypeChecker → SemanticIREmitter.emit_typed). This is intentional — variant type inference requires the TypeChecker's `@variant_shapes` store.

---

## Proof Coverage Summary

| Group | Checks | What it covers |
|-------|--------|----------------|
| SIR-VARDECL | 5 | variant_decl present; kind/name correct; arm count; arm structure |
| SIR-UNIT-ARM | 5 | Lifecycle fixture; unit arm with fields=[]; record arm with typed fields |
| SIR-CONSTRUCT | 5 | MakeSuccess contract; compute node; variant_construct kind; arm/variant; fields |
| SIR-MATCH-KIND | 5 | UseResult contract; match_node kind (not match_expr); subject/subject_type/arms |
| SIR-MATCH-ARMS | 5 | Arm count; pattern/body/resolved_type per arm; bindings in pattern |
| SIR-MATCH-FLAGS | 5 | exhaustive=true for full match; has_wildcard=true for wildcard arm |
| SIR-OOF-GUARD | 5 | KIND1/4/5 → nil semantic_ir; compilation_report present + pass_result=oof |
| SIR-REGRESSION | 5 | Non-variant programs unaffected; if_expr lowering unchanged; no variant_declarations key |
| SIR-DEGRADED | 5 | OOF programs: pass_result=oof; diagnostics present; emit stage=skipped |
| SIR-BOUNDARY | 5 | No vm_execute/runtime_dispatch; variant_declarations at top level |

---

## Next Route

PROP-044-P7 — VM variant dispatch. Requires explicit authorization.  
Scope will cover: OP_MATCH or equivalent instruction; variant value representation in Lab Rust VM; arm dispatch at runtime.
