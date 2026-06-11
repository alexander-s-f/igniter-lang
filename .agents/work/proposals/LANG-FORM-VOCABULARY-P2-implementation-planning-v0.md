# LANG-FORM-VOCABULARY-P2 — Form Vocabulary Implementation Planning

**Track:** form-vocabulary-parser-typechecker-semanticir-planning-v0
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE
**Date:** 2026-06-11
**Status:** planning-complete — ready for P3
**Predecessors:**
- LANG-FORM-VOCABULARY-PROP-P1 (proposal; V-1..V-9; OOF-FORM1..9; `speaks` direction)
- LANG-TYPED-CONTRACT-REF-PROP-P5 (71/71 PASS; cross-module typed-ref substrate)
- PROP-IMPORT-RESOLUTION-P5 (99/99 PASS; multifile import substrate)

---

## Q1 — Implementation Scope Decision

**Decision: P3-C — PHASED. P3 implements declaration/import/validation metadata layer only. Form word invocation (use sites in compute/output nodes) is deferred to P4.**

### What P3 implements

- `vocabulary VocPath { trigger -> ContractRef, ... }` — module-level vocabulary declaration
- `speaks VocPath` — module-level vocabulary import
- TypeChecker: V-1 (structurally), V-2 (ownership), V-3+V-4 (ambiguity at import time), V-5 (anchor at declaration time), V-7 (primitive reservation), V-8 (unknown vocabulary), V-9 (duplicate trigger in vocabulary)
- OOF-FORM1 / FORM3 / FORM4 / FORM7 / FORM8 / FORM9 active in P3
- SemanticIR: `form_vocabularies` top-level field
- Manifest: `form_vocabulary_imports` informational field
- Assembler: no changes to `dependency_edges`

### What P4 adds

- Form word use at call sites in `compute` / `output` / `input` nodes
- OOF-FORM2 (unknown word at use site)
- OOF-FORM3 at use sites (in addition to import time)
- OOF-FORM5 (invalid input mapping at use site)
- OOF-FORM6 (non-conservative lowering)
- SemanticIR: `form_resolutions`, `resugaring_trace`, `lowered_from_form` flag
- Dependency edges for form-lowered invocations

### Rationale for phased approach

Invocation syntax requires solving the **form-trigger vs. function-call disambiguation problem**: inside a `compute` node, `submit(id)` looks syntactically identical to a function call. Distinguishing it requires type-directed resolution (the approach used by `form_resolver.rs`), which is a post-classify, pre-typecheck pass over the expression AST. This is a fundamentally different architecture from how `compute` nodes are currently processed (expression evaluation with `symbol_types` lookup). Bundling it into P3 would make the proof surface too wide to be bounded.

The declaration/validation layer is independently provable and provides the governance structures (vocabulary_registry, form word validation) that P4 builds on.

---

## Q2 — Grammar / Parser

### 2.1 New keywords

Add two keywords to the `KEYWORDS` constant (parser.rb line 43):

```
speaks
vocabulary
```

These do not conflict with any existing keyword. `vocabulary` is not currently in the keyword list. `speaks` is not currently in the keyword list.

### 2.2 Program hash extensions (parser.rb line 277)

Add two new top-level arrays to the program hash:

```ruby
"vocabulary_declarations" => [],  # vocabulary VocPath { ... } blocks
"vocabulary_imports"      => [],  # speaks VocPath declarations
```

These are emitted alongside `"imports"`, `"contracts"`, `"profiles"`, etc.

### 2.3 `parse_top_decl` additions (parser.rb line 424)

Add two branches to `parse_top_decl`:

```ruby
when "speaks"     then advance; parse_speaks_decl
when "vocabulary" then advance; parse_vocabulary_decl
```

Add routing in `parse_program`'s top-level dispatch (line 313):

```ruby
when "speaks"     then program["vocabulary_imports"]     << decl
when "vocabulary" then program["vocabulary_declarations"] << decl
```

### 2.4 `parse_speaks_decl`

Position: after `import` declarations, before or alongside other top-level declarations. Reuses `parse_module_path` (already exists):

```
speaks Query.Forms
speaks Query.Forms.Extended
```

AST result:
```ruby
{ "kind" => "speaks", "vocabulary_path" => "Query.Forms", "line" => <line> }
```

### 2.5 `parse_vocabulary_decl`

```
vocabulary Query.Forms {
  submit -> Validator
  fetch  -> Lab.TypedRef.Query.Scorer
}
```

AST result:
```ruby
{
  "kind"           => "vocabulary",
  "vocabulary_path" => "Query.Forms",
  "form_words"     => [
    { "kind" => "form_word", "trigger" => "submit", "target" => "Validator", "line" => N },
    { "kind" => "form_word", "trigger" => "fetch",  "target" => "Lab.TypedRef.Query.Scorer", "line" => N }
  ],
  "line" => N
}
```

Body parsing: inside `{ }`, read zero or more form word entries until `}`. Each entry: identifier (trigger) + `->` separator + dotted name (target). Empty vocabulary body is valid.

### 2.6 Form word syntax decision

**Chosen:** `trigger -> ContractRef`

- `trigger`: plain identifier (not a keyword). Any identifier that is not a language primitive keyword may be used.
- `->`: arrow separator. Requires lexer support for `:arrow` token. **Implementation note for P3:** either add `:arrow` to the lexer or use an alternative separator. If the lexer does not have `->`, use `:` (colon — already in lexer). The planning-level decision is `->` (arrow); P3 may choose `:` if arrow adds lexer complexity.
- `ContractRef`: dotted module path or plain name — reuse `parse_module_path` logic.

**Deferred:** form word use at call sites (`submit(id)` in compute expressions). P3 does not parse form word uses.

### 2.7 Ambiguity with existing syntax

`vocabulary` and `speaks` at the top level do not conflict with any existing top-level declaration. Inside a vocabulary block, `trigger -> ContractRef` is structurally distinct from all existing contract body nodes (which use `kind:` keywords like `input`, `output`, `compute`). No disambiguation issues in P3.

### 2.8 `to_h` / grammar_version

Add `vocabulary_declarations` and `vocabulary_imports` to the `to_h` output (parser.rb line 2052). Grammar version: carry `"form-vocabulary-v0"` when any vocabulary_declarations or vocabulary_imports are non-empty. Otherwise unchanged.

---

## Q3 — Classifier

### 3.1 Module-level handling

The classifier processes `parsed.fetch("contracts")` for contract-level work and `parsed` at the module level for module structures. Vocabulary support adds two passes at the module level.

**Vocabulary declarations:** Propagate `parsed.fetch("vocabulary_declarations", [])` through the classified program unchanged. These are pure metadata — no symbol binding, no fragment classification change.

**Vocabulary imports (speaks):** Propagate `parsed.fetch("vocabulary_imports", [])` through the classified program unchanged. These are pure metadata.

### 3.2 Contract body: no change

Form vocabulary does not appear in contract bodies. Fragment class of any contract is unchanged by vocabulary imports (V-8). The classifier's contract body dispatch (`parse_body_decl` / body loop) does not need modification.

### 3.3 Classified program additions

Add to the classified program hash:

```ruby
"vocabulary_declarations" => parsed.fetch("vocabulary_declarations", []),
"vocabulary_imports"      => parsed.fetch("vocabulary_imports", [])
```

### 3.4 No new symbol types

Vocabulary imports and declarations introduce no new `symbol_types` entries. They are module-level metadata, not typed symbols.

---

## Q4 — TypeChecker

### 4.1 New kwargs

Extend `typecheck` signature with two new kwargs:

```ruby
def typecheck(classified_program,
  cross_module_registry: {},
  per_module_imports: {},
  per_contract_module: {},
  vocabulary_registry: {},     # NEW: { vocab_path => { source_module, form_words } }
  per_module_speaks: {}        # NEW: { module_name => [ speaks_decl, ... ] }
)
```

These default to `{}` — single-file backward compat preserved.

### 4.2 Validation phase

After `typed_contracts` is built (existing phase), run:

```ruby
vocabulary_errors = validate_vocabulary_layer(classified_program, typed_contracts)
```

This validation is post-contract-typecheck (so the `same_module_registry` and `cross_module_registry` are available for anchor checking).

### 4.3 `validate_vocabulary_layer`

Two sub-passes:

**Pass 1 — Vocabulary declarations:**
For each `vocabulary_declaration` in the classified program:
- `validate_vocabulary_declaration(vocab_decl)` → OOF-FORM4, OOF-FORM7, OOF-FORM9, OOF-FORM1

**Pass 2 — Speaks imports:**
For each `speaks_decl` in the classified program:
- `validate_speaks_import(speaks_decl, vocabulary_registry, module_name)` → OOF-FORM8, OOF-FORM3

### 4.4 `validate_vocabulary_declaration`

Receives: one vocabulary declaration AST node, current module name, `same_module_registry`, `cross_module_registry`.

Checks:
- **OOF-FORM4** (invalid owner): vocabulary_path must begin with or match the current module's name. If the vocabulary declares form words for contracts in another module that the declaring module does not own, fire OOF-FORM4. Simple rule: `vocab_decl.fetch("vocabulary_path")` must be rooted in the current module name.
- **OOF-FORM9** (duplicate trigger): collect all triggers in the vocabulary's form_words; if any trigger appears twice, fire OOF-FORM9.
- **OOF-FORM7** (hygiene): each trigger must not be in the reserved primitives set (language keywords, arithmetic operators). If it is, fire OOF-FORM7.
- **OOF-FORM1** (missing anchor): each form word's target must exist in the declaring module (`same_module_registry`) or in the `cross_module_registry`. If the target is not resolvable, fire OOF-FORM1.

### 4.5 `validate_speaks_import`

Receives: one speaks_decl, `vocabulary_registry`, declaring module name.

Checks:
- **OOF-FORM8** (unknown vocabulary): `speaks_decl["vocabulary_path"]` must be a key in `vocabulary_registry`. If not, fire OOF-FORM8.
- **OOF-FORM3** (ambiguous trigger): collect all form words from all imported vocabularies (via `per_module_speaks`). If any two vocabularies contribute form words with the same trigger, fire OOF-FORM3. Message names both contributing vocabularies and the conflicting trigger. This validation runs after all speaks imports are collected for the module.

Note: OOF-FORM3 is validated at import time in P3. No first-wins — all conflicts are reported, not just the first.

### 4.6 Result

Vocabulary errors added to `type_errors` in the typecheck result:

```ruby
"type_errors" => typed_contracts.flat_map { |c| c.fetch("type_errors") }
                 + module_reserved_errors + entrypoint_errors + cycle_errors
                 + vocabulary_errors
```

### 4.7 Rules active in P3

| Rule | P3 Active | Where Enforced |
|------|-----------|----------------|
| V-1 no ambient | Structural (speaks required) | SemanticIR only includes imported vocab content |
| V-2 ownership | OOF-FORM4 | `validate_vocabulary_declaration` |
| V-3 no first-wins | OOF-FORM3 | `validate_speaks_import` |
| V-4 order independence | OOF-FORM3 detection deterministic | `validate_speaks_import` |
| V-5 typed-ref anchor | OOF-FORM1 | `validate_vocabulary_declaration` |
| V-6 InvocationIntent equality | Deferred | P4 (no invocation in P3) |
| V-7 no_form propagation | Deferred | P4 (no use sites) |
| V-8 fragment class invariant | Structural | Classifier does not modify fragment class |
| V-9 primitive reservation | OOF-FORM7 | `validate_vocabulary_declaration` |

---

## Q5 — OOF-FORM Diagnostics

Exact message templates for P3-active codes. All follow the existing `oof()` helper pattern in typechecker.rb.

### OOF-FORM1 — missing typed-ref anchor

**Trigger:** Form word in vocabulary declaration references a contract that is not resolvable (not in declaring module's same_module_registry or cross_module_registry).

**Message:** `"vocabulary '#{vocab_path}' declares form word '#{trigger}' → '#{target}' — no contract '#{target}' is declared in this compilation unit"`

**Evidence path:** `"vocabulary:#{vocab_path}:form_word:#{trigger}"`

### OOF-FORM3 — ambiguous form word

**Trigger:** Two or more imported vocabularies (via speaks) export form words with the same trigger in the same module.

**Message:** `"module '#{module_name}' imports conflicting form word '#{trigger}' from multiple vocabularies: #{vocab_names.join(", ")} — qualify the reference or remove one vocabulary import"`

**Evidence path:** `"speaks:ambiguous_trigger:#{trigger}"`

### OOF-FORM4 — invalid form owner

**Trigger:** Vocabulary declaration's path is not rooted in the declaring module's name (the declaring module does not own the vocabulary namespace).

**Message:** `"vocabulary '#{vocab_path}' is declared in module '#{module_name}' but its path does not belong to that module's namespace — form vocabularies must be declared in their owning module"`

**Evidence path:** `"vocabulary:#{vocab_path}:ownership"`

### OOF-FORM7 — hygiene / primitive shadow

**Trigger:** Form word trigger is a reserved language keyword or primitive operator.

**Message:** `"vocabulary '#{vocab_path}' form word trigger '#{trigger}' shadows a reserved language keyword or primitive — choose a different trigger name"`

**Evidence path:** `"vocabulary:#{vocab_path}:form_word:#{trigger}:hygiene"`

### OOF-FORM8 — unknown vocabulary

**Trigger:** `speaks VocPath` imports a vocabulary not declared in any file in the compilation unit.

**Message:** `"module '#{module_name}' speaks '#{vocab_path}' — no vocabulary '#{vocab_path}' is declared in the compilation unit"`

**Evidence path:** `"speaks:#{vocab_path}"`

### OOF-FORM9 — duplicate form word in vocabulary

**Trigger:** Two form words in the same vocabulary block declare the same trigger.

**Message:** `"vocabulary '#{vocab_path}' declares duplicate form word trigger '#{trigger}' — each trigger must be unique within a vocabulary"`

**Evidence path:** `"vocabulary:#{vocab_path}:duplicate_trigger:#{trigger}"`

### Deferred to P4

- OOF-FORM2 (unknown form word at use site)
- OOF-FORM5 (invalid input mapping at use site)
- OOF-FORM6 (non-conservative lowering)

---

## Q6 — Typed-Ref Integration

### 6.1 Form word anchor resolution

In `validate_vocabulary_declaration`, each form word's `target` field is resolved using the existing registries:
- If `target` contains a dot → look up in `cross_module_registry[module_path][contract_name]`
- If `target` is plain → look up in `same_module_registry[target]`

This is the same resolution logic already used by `typecheck_uses_contract` (PATH 1 and PATH 2a). No new resolution code needed — reuse the existing lookup pattern.

### 6.2 No new `contract_refs` entries

Vocabulary declarations do **not** produce new entries in the contract's `contract_ref_declarations`. They are module-level metadata, not contract-level typed-ref uses. The existing `uses T` in the declaring module is the substrate; the form word references T but does not create a second typed-ref binding.

### 6.3 OOF-REF interaction

Form word target resolution failures fire OOF-FORM1, not OOF-REF1. The OOF-REF namespace remains for `uses T` declarations. OOF-FORM1 is the vocabulary-level diagnostic.

### 6.4 `resolution_kind` not extended

The `resolution_kind` values (`"local"`, `"qualified"`, `"imported"`) on existing `contract_refs` are not changed. Form vocabulary adds no new `resolution_kind` variants in P3.

---

## Q7 — Import / Multifile Integration

### 7.1 MultifileResolver additions

Three patterns after the existing `build_cross_module_registry` / `build_per_module_imports` / `build_per_contract_module`:

```ruby
def build_vocabulary_registry(sorted)
  # { vocab_path => { "source_module" => mod, "form_words" => [...] } }
  sorted.each_with_object({}) do |unit, registry|
    unit.fetch("parsed").fetch("vocabulary_declarations", []).each do |vocab_decl|
      path = vocab_decl.fetch("vocabulary_path")
      registry[path] = {
        "source_module" => unit.fetch("module"),
        "form_words"    => vocab_decl.fetch("form_words", [])
      }
    end
  end
end

def build_per_module_speaks(sorted)
  # { module_name => [ speaks_decl, ... ] }
  sorted.each_with_object({}) do |unit, map|
    map[unit.fetch("module")] = unit.fetch("parsed").fetch("vocabulary_imports", [])
  end
end
```

Both exposed in the resolve result hash. Default `{}` when called from single-file path.

### 7.2 Result hash extension

```ruby
{
  "ok"                    => true,
  # ... existing keys ...
  "vocabulary_registry"   => build_vocabulary_registry(sorted),
  "per_module_speaks"     => build_per_module_speaks(sorted)
}
```

### 7.3 Order-independent vocabulary_registry

`build_vocabulary_registry` iterates `sorted` (alphabetically sorted by module path). Vocabulary_registry is keyed by `vocabulary_path`, which is unique per compilation unit (duplicate vocabulary paths raise OOF-FORM9 or similar). Result is deterministic.

### 7.4 Speaks under file-order permutations

`build_per_module_speaks` keyed by module name (stable). Speaks declarations within a module maintain their declaration order within that module. OOF-FORM3 detection uses a trigger-set comparison that is order-independent: both `[A, B]` and `[B, A]` orderings produce the same OOF-FORM3 naming the same two vocabularies for the same conflicting trigger.

### 7.5 No package/visibility opening

`speaks VocPath` is a compilation-unit-scoped import. It does not open package namespace, does not grant cross-module visibility, and does not affect the existing `per_module_imports` resolution.

### 7.6 CompilerOrchestrator extension

`compile_parsed` kwargs extend with:

```ruby
vocabulary_registry: {},
per_module_speaks: {}
```

`compile_sources` passes these from `resolved.fetch("vocabulary_registry", {})` and `resolved.fetch("per_module_speaks", {})` to `compile_parsed`. Same pattern as `cross_module_registry` (P5).

---

## Q8 — SemanticIR

### 8.1 `form_vocabularies` top-level field

Added to the SemanticIR program hash by `semanticir_emitter.rb`:

```json
{
  "form_vocabularies": [
    {
      "vocabulary_path": "Query.Forms",
      "source_module":   "Lab.TypedRef.Query",
      "form_words": [
        {
          "trigger":         "submit",
          "target_contract": "Validator",
          "target_module":   "Lab.TypedRef.Query"
        }
      ]
    }
  ]
}
```

Only vocabularies declared in the compilation unit are emitted. Vocabularies imported via `speaks` but declared elsewhere are referenced by path in the `form_vocabulary_imports` manifest field; their content is in the source module's SIR.

`form_vocabularies` is `[]` when no vocabularies are declared in the compilation unit.

### 8.2 `typed_nodes` filter

Add `when "vocabulary"` → `nil` (metadata only, not a runtime node). Same pattern as `uses_contract`:

```ruby
when "vocabulary"
  nil  # LANG-FORM-VOCABULARY-PROP-P3: module-level metadata only — not emitted as a runtime node
```

This is in `typed_nodes`, which filters out nil values. No VM node created.

### 8.3 Deferred to P4

- `form_resolutions` array
- `resugaring_trace` per resolution
- `lowered_from_form` flag on InvocationIntent nodes

### 8.4 Content hash

`form_vocabularies` enters the artifact hash via the existing SIR content hash mechanism (the entire semantic_ir contributes to the hash material). No separate hash handling needed.

---

## Q9 — Manifest / Artifact Hash

### 9.1 `form_vocabulary_imports` manifest field

Added by assembler.rb:

```json
{
  "form_vocabulary_imports": [
    {
      "module":        "Lab.TypedRef.App",
      "vocabulary":    "Query.Forms",
      "source_module": "Lab.TypedRef.Query"
    }
  ]
}
```

Present when the compiled module has one or more `speaks` imports. Absent (field omitted) when no speaks declarations.

### 9.2 `dependency_edges` unchanged

Form vocabulary imports do not add dependency edges in P3. The `dependency_edges` field is populated by `contract_refs` (typed-ref uses), not by vocabulary imports. Form-lowered invocations (P4) will eventually add edges; P3 does not.

### 9.3 Deterministic ordering

`form_vocabulary_imports` entries are sorted by `vocabulary` path (alphabetical). This ensures file-order independence of the artifact hash.

### 9.4 Artifact hash inclusion

`form_vocabulary_imports` enters the `artifact_hash` via manifest material (existing hash discipline — all manifest content is included).

### 9.5 Source units evidence

`source_units` in the manifest already carries vocabulary declarations implicitly via the full source files. No additional evidence field needed.

---

## Q10 — Runtime Boundary

Explicit confirmations:

| Claim | P3 Status |
|-------|-----------|
| Forms lower before runtime | Vacuously true in P3 (no invocations) |
| VM does not know form words | Confirmed — no typed_nodes for vocabulary |
| No execution dependency | Confirmed — `execution_dependency: false` by absence |
| No capability / profile grant | Confirmed — vocabulary declares no capability fields |
| No scheduler edge | Confirmed — no runtime dispatch |
| No call_contract behavior change | Confirmed — call_contract unchanged |
| `speaks` grants no module access | Confirmed — separate from `import` |

---

## Q11 — Proof Matrix (≥51 checks, 8 sections)

**Proof runner:** `experiments/typed_contract_ref_proof/verify_form_vocabulary_p3.rb` (new file)

### Section A — Regression (6 checks)

| Check | Description |
|-------|-------------|
| A-01 | LANG-TYPED-CONTRACT-REF-PROP-P5: verify_typed_contract_ref_p5.rb still passes (71/71) |
| A-02 | PROP-IMPORT-RESOLUTION-P5: import regression clean |
| A-03 | PROP-ENTRYPOINT-P3: entrypoint regression clean |
| A-04 | basic_uses (same-module typed-ref) still resolves with resolution_kind "local" |
| A-05 | existing single-file with no vocabulary: compiles clean with no form_vocabularies field |
| A-06 | existing multifile compilation with no vocabulary: compiles clean |

### Section B — Parser: Vocabulary Declaration (7 checks)

| Check | Description |
|-------|-------------|
| B-01 | `vocabulary Query.Forms { }` parses without error (empty body valid) |
| B-02 | vocabulary with one form word: AST has form_words array with one entry |
| B-03 | vocabulary with two form words: AST has two entries |
| B-04 | form word trigger and target correctly captured in AST |
| B-05 | dotted target in form word (cross-module ref) parsed correctly |
| B-06 | vocabulary at end of file (no contracts after) parses correctly |
| B-07 | vocabulary alongside contract declarations parses correctly |

### Section C — Parser: Speaks Import (5 checks)

| Check | Description |
|-------|-------------|
| C-01 | `speaks Query.Forms` parses without error |
| C-02 | multiple speaks declarations in one file: all parsed |
| C-03 | speaks with dotted vocabulary path parses correctly |
| C-04 | speaks appears in program["vocabulary_imports"] |
| C-05 | file with speaks but no vocabulary declaration parses ok (typechecker catches later) |

### Section D — TypeChecker: Vocabulary Validation (8 checks)

| Check | Description |
|-------|-------------|
| D-01 | valid vocabulary with resolvable form word targets: no errors |
| D-02 | OOF-FORM1: form word target not in same_module_registry or cross_module_registry → fires |
| D-03 | OOF-FORM4: vocabulary path not rooted in declaring module namespace → fires |
| D-04 | OOF-FORM7: form word trigger is reserved keyword → fires |
| D-05 | OOF-FORM7: form word trigger is arithmetic primitive → fires |
| D-06 | OOF-FORM9: two form words with same trigger in one vocabulary → fires |
| D-07 | OOF-FORM9: message names the duplicate trigger |
| D-08 | multiple valid form words with distinct triggers: no errors |

### Section E — TypeChecker: Speaks Validation (9 checks)

| Check | Description |
|-------|-------------|
| E-01 | valid speaks import: vocabulary in vocabulary_registry → no errors |
| E-02 | OOF-FORM8: speaks unknown vocabulary → fires |
| E-03 | OOF-FORM8 message names the missing vocabulary path |
| E-04 | OOF-FORM3: two imported vocabularies with same trigger → fires |
| E-05 | OOF-FORM3: message names both contributing vocabularies |
| E-06 | OOF-FORM3: same error under [VocA, VocB] ordering |
| E-07 | OOF-FORM3: same error under [VocB, VocA] ordering (order independence) |
| E-08 | Non-conflicting two-vocabulary speaks import: no OOF-FORM3 |
| E-09 | Non-conflicting: same trigger receipts under both vocabulary orderings |

### Section F — SemanticIR Shape (7 checks)

| Check | Description |
|-------|-------------|
| F-01 | form_vocabularies present in SIR when vocabulary declared |
| F-02 | form_vocabularies is [] when no vocabulary declared |
| F-03 | form_vocabulary entry has vocabulary_path, source_module, form_words |
| F-04 | each form_word has trigger and target_contract |
| F-05 | target_module populated for cross-module targets |
| F-06 | single-file vocabulary declaration emits correctly |
| F-07 | multifile vocabulary declaration emits correctly |

### Section G — Manifest (7 checks)

| Check | Description |
|-------|-------------|
| G-01 | form_vocabulary_imports present in manifest when speaks declared |
| G-02 | form_vocabulary_imports absent when no speaks declared |
| G-03 | each entry has module, vocabulary, source_module |
| G-04 | artifact_hash stable on re-compile (vocabulary content unchanged) |
| G-05 | file-order independence: [query, app] hash == [app, query] hash |
| G-06 | different vocabulary contents produce different artifact_hash |
| G-07 | form_vocabulary_imports sorted deterministically |

### Section H — Authority (8 checks)

| Check | Description |
|-------|-------------|
| H-01 | vocabulary declaration does not create typed_nodes (no VM node) |
| H-02 | speaks import does not create typed_nodes |
| H-03 | form_vocabularies SIR field carries no execution_dependency field |
| H-04 | vocabulary import does not grant capability or profile authority |
| H-05 | dependency_edges unchanged by vocabulary declaration |
| H-06 | dependency_edges unchanged by speaks import |
| H-07 | runtime sees no form vocabulary content (not in VM bytecode) |
| H-08 | call_contract behavior unchanged |

**Total: 57 checks** across 8 sections. All are binary pass/fail with deterministic expected outcomes.

---

## Q12 — Authorized Files for P3

| File | Change |
|------|--------|
| `lib/igniter_lang/parser.rb` | Add `"speaks"` and `"vocabulary"` to KEYWORDS; add `"vocabulary_declarations"` and `"vocabulary_imports"` to program hash; add `parse_speaks_decl`, `parse_vocabulary_decl`, `parse_form_word`; add to `parse_top_decl` case; route in `parse_program` dispatch; add to `to_h` output |
| `lib/igniter_lang/classifier.rb` | Propagate `vocabulary_declarations` and `vocabulary_imports` from parsed to classified program; no contract body changes |
| `lib/igniter_lang/typechecker.rb` | Add `vocabulary_registry:` and `per_module_speaks:` kwargs; add `validate_vocabulary_layer`, `validate_vocabulary_declaration`, `validate_speaks_import` private methods; OOF-FORM1/3/4/7/8/9 using existing `oof()` helper; add vocabulary_errors to type_errors |
| `lib/igniter_lang/semanticir_emitter.rb` | Add `form_vocabularies` emission to program-level SIR; add `when "vocabulary" then nil` to `typed_nodes` filter |
| `lib/igniter_lang/assembler.rb` | Add `form_vocabulary_imports` field to manifest when speaks imports exist; read from semantic_ir or from compiler_orchestrator-passed data |
| `lib/igniter_lang/multifile_resolver.rb` | Add `build_vocabulary_registry` and `build_per_module_speaks` private methods; expose both in resolve result hash |
| `lib/igniter_lang/compiler_orchestrator.rb` | Add `vocabulary_registry:` and `per_module_speaks:` kwargs to `compile_parsed`; pass from `compile_sources` resolver result |

**NOT authorized in P3:**

- VM bytecode / runtime
- Form invocation use in compute/output/input nodes
- OOF-FORM2 (use-site unknown word)
- OOF-FORM5 (use-site input mapping)
- OOF-FORM6 (non-conservative lowering)
- `form_resolutions` SIR field
- `resugaring_trace`
- `lowered_from_form` flag
- `dependency_edges` form entries
- Package / visibility
- `call_contract` behavior

---

## Recommendation

**READY FOR NARROW P3**

P3 is bounded, has clear insertion points, reuses existing patterns (cross_module_registry pattern for vocabulary_registry, oof() helper for diagnostics, nil in typed_nodes for metadata-only), and is independently provable at 57 checks across 8 sections.

The invocation surface (form word use in compute nodes) is deliberately deferred to P4. This keeps P3's proof surface manageable and avoids solving the form-trigger/function-call disambiguation problem before the declaration/validation layer is proved.

**P3 authorized files: 7 Ruby canon files** (same set as P5 typed-refs, minus no new files needed outside the existing pipeline).

**Approximate line count:** ~200–280 lines across 7 files (parser: ~60, classifier: ~15, typechecker: ~80, semanticir_emitter: ~20, assembler: ~20, multifile_resolver: ~30, compiler_orchestrator: ~15).

**Next card:** LANG-FORM-VOCABULARY-PROP-P3 — Bounded Ruby Implementation
