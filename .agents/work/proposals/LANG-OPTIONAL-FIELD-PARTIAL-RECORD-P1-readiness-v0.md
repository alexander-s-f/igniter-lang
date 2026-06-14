# LANG-OPTIONAL-FIELD-PARTIAL-RECORD-P1 Readiness

**Status:** CLOSED / READINESS PROVED - 62/62 PASS  
**Date:** 2026-06-14  
**Route:** HOLD IMPLEMENTATION -> full PROP before any compiler change  
**Authority:** language readiness/proof only; no canon semantics accepted by this doc

## Decision

`?` on record field type annotations is a real dual-toolchain gap, but P1 must not implement partial record omission.

Route a full language PROP before implementation. The PROP must define what omission means for construction, later field access, output assignability, serialization, and wrong-type present fields. Until then, the safe app pattern remains explicit defaults in record literals.

## Proof

Runner:

`experiments/optional_field_proof/verify_optional_field_partial_record_p1.rb`

Result:

`62/62 PASS`

The proof characterizes current behavior:

- Ruby source has a parser branch for `:question`, but the live Ruby lexer does not emit `:question`; `String?` parses without error and currently yields `optional=false`.
- Ruby `Classifier` can carry `optional`, but the live parser does not set it for `String?`.
- Ruby `TypeChecker#type_shapes` reduces fields to `name -> type_ir` and drops any optional metadata.
- Ruby `infer_record_literal` treats every expected field as required and emits `OOF-TY0` for omitted `maybe`.
- Rust lexer/parser retain `?` as `TokenType::Question` and `FieldDecl.optional: bool`.
- Rust `build_type_shapes` also reduces fields to `name -> type_ir`, dropping optional metadata before record literal validation.
- Rust `check_record_literal_shape` treats every expected field as required and emits `OOF-TY0` for omitted `maybe`.
- When optional-spelled fields are present with the wrong type, both toolchains still emit `OOF-TY0`.

Baseline smoke:

- Ruby canon `CompilerOrchestrator.compile_sources` on `vector_editor/types.ig`, `document.ig`, and `tools.ig`: `status=ok`, diagnostics `[]`.
- Rust lab `igniter_compiler compile` on the same three files: `status=ok`, diagnostics `[]`.
- Existing lab proof `verify_lab_ve_new_obj_inference_p1.rb` is now stale in its negative Section D expectations, but its full-app Section G still reports the fixed app as Ruby `ok/0`. This P1 did not edit lab app sources.

## Answers

1. **Does parser preserve optional marker today?**  
   Ruby effectively does not preserve it in live AST because the lexer drops `?`, despite parser code containing a `:question` branch. Rust does preserve it in the parsed `FieldDecl`.

2. **Ruby-only or dual-toolchain?**  
   Dual-toolchain. Ruby loses the marker before or at parse output; Rust retains it in parsed AST but erases it in type-shape construction. Both reject partial record literals.

3. **What should omission mean?**  
   Undecided. P1 rejects choosing among absent field, `Unknown`, `None`, or app-required default. Current safe meaning remains app-required explicit defaults.

4. **Record literal validation only, or output assignability too?**  
   Undecided, and must be specified by PROP. P1 keeps output assignability closed and unchanged.

5. **Wrong-type optional fields when present?**  
   Must remain typechecked. Both current toolchains emit `OOF-TY0`; a later design should preserve this fail-closed behavior.

6. **Can implementation avoid nullable runtime semantics?**  
   Not safely without a sharper design. Allowing omission creates a runtime record value that may lack a declared field unless the compiler injects a default or the language defines absent-field reads. That is semantic authority, not a P1 patch.

7. **Should P1 reject implementation and route full PROP?**  
   Yes. P1 closes as readiness proof and routes a full PROP.

## Safe Route

Recommended next card:

`LANG-OPTIONAL-FIELD-PARTIAL-RECORD-PROP-P2`

Required design points:

- Define whether `?` is field omission, nullable value, option value, or documentation-only.
- Define read semantics for an omitted optional field.
- Define serialization/manifest shape for omitted optional fields.
- Preserve wrong-type present field diagnostics.
- Keep output assignability strict unless explicitly accepted.
- Decide whether Ruby must first add lexer support for `?`.
- Decide whether Rust parsed optional metadata should survive into type shapes as field metadata.

## Current App Guidance

For `vector_editor` and similar apps, keep explicit defaults:

- `path_pts: []`
- `rect_data: ...`
- `text_data: default_text`

This keeps the record value total under current semantics and avoids introducing implicit nullable or absent-field behavior.

## Closed Surfaces

- No parser implementation.
- No typechecker implementation.
- No nullable runtime value.
- No `None`/`nil`/`Unknown` default semantics.
- No app source migration.
- No record literal redesign.
- No output assignability relaxation.
- No emitter/assembler/runtime/IO work.

## Evidence

- Origin card: `igniter-lab/.agents/work/cards/governance/LAB-VE-NEW-OBJ-INFERENCE-P1.md`
- Origin doc: `igniter-lab/lab-docs/governance/lab-ve-new-obj-inference-p1-v0.md`
- App source: `igniter-lab/igniter-apps/vector_editor/types.ig`
- App source: `igniter-lab/igniter-apps/vector_editor/tools.ig`
- Ruby parser/typechecker: `lib/igniter_lang/parser.rb`, `lib/igniter_lang/typechecker.rb`
- Rust parser/typechecker: `igniter-lab/igniter-compiler/src/parser.rs`, `igniter-lab/igniter-compiler/src/typechecker.rs`
