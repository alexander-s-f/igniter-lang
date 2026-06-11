# LANG-TYPED-CONTRACT-REF-P2: Implementation Planning — `uses ContractName` in Ruby Canon Pipeline

**Track:** typed-contract-reference-parser-typechecker-semanticir-planning-v0  
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE  
**Authority:** planning only — no implementation authority; P3 required  
**Date:** 2026-06-11  
**Status:** PLANNING COMPLETE — READY FOR P3  
**Predecessors:** LANG-TYPED-CONTRACT-REF-PROP-P1 (proposal), LAB-TYPED-CONTRACT-REF-P1 (58/58 PASS)

---

## 1. Authority Boundary

P2 plans the bounded implementation of `uses ContractName` in the Ruby canon pipeline.
P2 produces a planning document and a card. It does NOT implement code.

P3 (the implementation proof) is authorized only for:

- Ruby `igniter-lang` canon pipeline only
- same-module typed references only (cross-module requires import module table, deferred)
- metadata-only `contract_refs` field in SemanticIR
- `dependency_edges` array in manifest
- OOF-REF1 (unknown), OOF-REF2 (cross-module / ambiguous, v0 = not implemented), OOF-REF4 (self/cycle)

Closed in P3 (must NOT be opened):

- no VM / runtime changes
- no cross-module typed refs (deferred to import module table gate)
- no `call_contract` behavior changes — call_contract is not deprecated, not replaced
- no forms vocabulary or form lowering
- no macro or composition system
- no capability or profile authority
- no public or stable API widening
- no Rust lab pipeline changes (parity deferred to lab card)
- no fragment classification change for any declaring contract

---

## 2. Summary of What P3 Adds

`uses ContractName` is a contract body declaration (BodyDecl) that creates a
typed, source-visible dependency edge from the declaring contract to the named
contract. In v0 it is metadata-only: it does not invoke, execute, or compose
the referenced contract.

P3 adds:

- parser branch in `parse_uses_decl` for `uses ContractName` → `{ "kind" => "uses_contract", "target" => NAME }`
- classifier passthrough in `classify_contract` — no fragment effect; collects in `contract_ref_declarations`
- typechecker resolution in per-contract typecheck loop — same-module registry lookup; OOF-REF1/2/4
- SemanticIR emitter: `contract_refs` per-contract field in `typed_contract_ir`
- assembler: `dependency_edges` array in manifest (enters artifact_hash)

P3 does not touch:

- `parse_uses_decl` disambiguation logic for `uses assumptions ...` (unchanged)
- `parse_body_decl` dispatch — `"uses"` already routes here (unchanged)
- classifier fragment logic for any other node kind
- typechecker `call_contract` resolution (unchanged)
- SemanticIR `assumption_refs` field (unchanged)
- assembler `contract_refs` manifest field (name→hash; unchanged; different from per-contract field)

---

## 3. Planning Questions and Answers

### Q1 — Parser: Insertion Point and Parse Rule

**Current state:** `parse_uses_decl` (line 980, `parser.rb`):

```ruby
def parse_uses_decl
  tok = peek
  unless peek_kw?("assumptions")
    add_parse_error(
      rule: "OOF-P0",
      message: "uses declaration currently supports only 'uses assumptions NAME'",
      ...
    )
    skip_until_body_boundary
    return nil
  end
  advance
  name = name_token!(%i[:ident])
  { "kind" => "uses_assumptions", "name" => name }
end
```

**Insertion point:** Replace the `unless peek_kw?("assumptions")` guard with a dispatch:

```
if peek_kw?("assumptions")
  → existing parse_uses_assumptions branch
elsif peek_type?(:ident)
  → new parse_uses_contract branch
else
  → OOF-P0 error (unchanged behavior for truly unknown syntax)
```

**ContractTarget grammar:**

```
UsesContractDecl := "uses" ContractTarget
ContractTarget   := Name | ModPath
ModPath          := Name ("." Name)+
```

- Tokenizer already produces `:dot` and `:ident` tokens.
- After `advance` (consuming `uses`), read the first `:ident`. Then while `peek_type?(:dot)`, advance the dot and read another `:ident`.
- Produce a single `target` string: `"Name"` or `"Mod.Name"` or `"A.B.C"`.
- The `.` traversal is a tight parse loop — no whitespace concern since dots in names are not keyword-separated.

**AST node shape:**

```ruby
{ "kind" => "uses_contract", "target" => "ContractName" }
{ "kind" => "uses_contract", "target" => "Mod.ContractName" }
```

No `"name"` field (it is not a named local symbol). No `:colon`. No braces.
The parser produces exactly one node per `uses ContractName` declaration.
Multiple `uses` declarations are allowed (parser does not enforce uniqueness).

**Disambiguation table:**

| Token after `uses` | Branch |
|--------------------|--------|
| `assumptions` (keyword) | → `uses_assumptions` (existing) |
| `:ident` | → `uses_contract` (new) |
| anything else | → OOF-P0 parse error (existing) |

This is 1-token lookahead. No ambiguity. `uses` is already in KEYWORDS.

**`ParsedProgram#to_h`:** no change needed. `uses_contract` nodes appear inside
contract body arrays, not at the top level. The program hash shape is unchanged.

**Keyword check for body boundary (`peek_body_boundary?` or equivalent):**
The parser at line 1632 checks for known body keywords to detect declaration boundaries.
`"uses"` is already in that list — no change needed.

---

### Q2 — Classifier: Insertion Point and Fragment Treatment

**Current state:** `classify_contract` (line 101, `classifier.rb`) has a `case node.fetch("kind")` branch. The `when "uses_assumptions"` branch (line 160) does:

```ruby
when "uses_assumptions"
  name = node.fetch("name")
  assumption_refs << name
  symbol_fragments[name] = "core"
  symbol_kinds[name] = "assumption"
  ...
  declarations << classified_decl(node, "epistemic", [], missing)
```

**Insertion point:** Add `when "uses_contract"` to the same `case` block,
immediately after `when "uses_assumptions"`:

```ruby
when "uses_contract"
  contract_ref_declarations << node
  declarations << classified_decl(node, "metadata", [], [])
```

Key properties:
- `uses_contract` does NOT enter `symbol_fragments` — the target name is not a local symbol
- `uses_contract` does NOT enter `symbol_kinds` — same reason
- Fragment for the node itself: `"metadata"` (new, inert — does not affect contract's `fragment_class`)
- No `missing` entries — resolution is deferred to typechecker
- `contract_ref_declarations` is a new local array initialized at the top of `classify_contract`, similar to `assumption_refs`

**Contract result hash addition:**

At the point where the classifier builds its result hash for the contract (after the body traversal), add:

```ruby
result["contract_ref_declarations"] = contract_ref_declarations unless contract_ref_declarations.empty?
```

This mirrors the `assumption_refs` pattern exactly.

**Fragment classification invariant:** A `pure` contract that declares `uses EffectContract` remains `pure`. The classifier must not propagate the target's modifier into the declaring contract's `fragment_class`. This is verified by the P3 proof (see §8, regression matrix).

**`grammar_version` discriminant:** The classifier currently sets `grammar_version` to `"assumptions-v0"` when any contract has a `uses_assumptions` node (line 2056). A new `"uses-contract-v0"` discriminant is NOT required in P3 — `grammar_version` is already set at parse time. Verify that `uses_contract` nodes do not accidentally trigger the `"assumptions-v0"` guard; they should not because the discriminant checks `n["kind"] == "uses_assumptions"`, not `"uses_contract"`.

---

### Q3 — TypeChecker: Insertion Point, Registry, and Resolution

**Current state:** The typechecker `when "uses_assumptions"` branch (line 333, `typechecker.rb`):

```ruby
when "uses_assumptions"
  type = type_ir("Assumption")
  symbol_types[decl.fetch("name")] = type
  typed_decls << typed_decl(decl, type, nil, [])
```

**Insertion point:** Add `when "uses_contract"` to the same `case` block:

```ruby
when "uses_contract"
  typed_decls << typed_decl_contract_ref(decl, same_module_registry, current_contract_name, type_errors)
```

**Registry needed:** a `same_module_registry` — a hash of `contract_name → { modifier, inputs, outputs }` built from the classified program's contracts, excluding the current contract. This is analogous to the `ContractRegistryEntry` built in the Rust typechecker.

Build it once per module typecheck, pass into `typecheck_contract_body` (or equivalent):

```ruby
same_module_registry = classified_program.fetch("contracts").each_with_object({}) do |c, reg|
  reg[c.fetch("name")] = {
    "modifier" => c.fetch("modifier", "pure"),
    "inputs"   => c.fetch("declarations").select { |d| d.fetch("kind") == "input" }.map { |d| d.fetch("name") },
    "outputs"  => c.fetch("declarations").select { |d| d.fetch("kind") == "output" }.map { |d| d.fetch("name") }
  }
end
```

**Resolution algorithm (`typed_decl_contract_ref`):**

```
target = decl.fetch("target")
if target == current_contract_name
  → OOF-REF4, return typed_decl with unresolved ContractRef
elsif target.include?(".")
  → OOF-REF2 (cross-module, deferred in v0), return typed_decl with unresolved ContractRef
elsif same_module_registry.key?(target)
  entry = same_module_registry[target]
  resolved_ref = { "contract_name" => target, "module_name" => current_module,
                   "modifier" => entry["modifier"], "input_count" => entry["inputs"].size,
                   "input_names" => entry["inputs"], "output_names" => entry["outputs"],
                   "resolution_status" => "resolved" }
  return typed_decl + resolved_ref
else
  → OOF-REF1, return typed_decl with unresolved ContractRef
```

**`uses_contract` does NOT enter `symbol_types`** — the target is not a local typed symbol that other nodes can reference. This is essential: `uses ContractName` is not a value binding.

**Typed decl shape for resolved case:**

```ruby
{
  "kind" => "uses_contract",
  "target" => target,
  "resolution_status" => "resolved",
  "resolved_ref" => {
    "contract_name" => target,
    "module_name"   => current_module,
    "modifier"      => entry["modifier"],
    "input_count"   => entry["inputs"].size,
    "input_names"   => entry["inputs"],
    "output_names"  => entry["outputs"]
  },
  "type" => type_ir("ContractRef"),   # new type tag; inert
  "deps" => [],
  "fragment" => "metadata"
}
```

**Typed decl shape for unresolved case (OOF-REF1/2/4):**

```ruby
{
  "kind" => "uses_contract",
  "target" => target,
  "resolution_status" => "unresolved",
  "type" => type_ir("ContractRef"),
  "deps" => [],
  "fragment" => "metadata"
}
```

**Propagation of `contract_ref_declarations` to typed result:**

At the end of `typecheck_contract_body` (near line 423), add:

```ruby
contract_ref_decls = typed_decls.select { |d| d["kind"] == "uses_contract" }
result["contract_ref_declarations"] = contract_ref_decls unless contract_ref_decls.empty?
```

This mirrors the `assumption_refs` propagation pattern exactly.

---

### Q4 — Diagnostics: OOF-REF1, OOF-REF2, OOF-REF4 Exact Shapes

All three diagnostics are produced in the typechecker (not parser or classifier).

**OOF-REF1 — Unknown contract reference:**

```ruby
oof("OOF-REF1",
    "contract '#{current_contract_name}' uses unknown contract '#{target}' — " \
    "no contract named '#{target}' is declared in this module",
    "uses_contract:#{target}")
```

Trigger: unqualified `target` not in `same_module_registry`.  
Severity: blocking (type_error). The `resolution_status` is `"unresolved"`.

**OOF-REF2 — Cross-module reference (deferred in v0):**

```ruby
oof("OOF-REF2",
    "contract '#{current_contract_name}' uses cross-module reference '#{target}' — " \
    "cross-module typed refs require the import module table (deferred; use same-module contracts in v0)",
    "uses_contract:#{target}")
```

Trigger: `target.include?(".")` — qualified path.  
Severity: blocking (type_error). The `resolution_status` is `"unresolved"`.  
Note: OOF-REF2 in the proposal covers both ambiguity and cross-module cases. In P3, the trigger is
simply "any dotted target" — the deeper ambiguity semantics are deferred with the module table.

**OOF-REF4 — Self-reference or cycle:**

```ruby
oof("OOF-REF4",
    "contract '#{current_contract_name}' uses itself — self-reference is not allowed",
    "uses_contract:#{current_contract_name}")
```

Trigger: `target == current_contract_name`.  
Severity: blocking (type_error). The `resolution_status` is `"unresolved"`.  
Cycle detection beyond direct self-reference is deferred (requires DAG traversal of all `contract_ref_declarations` across contracts). P3 proves only the direct self-reference case.

---

### Q5 — SemanticIR: `contract_refs` Field Schema and Hash Placement

**Insertion point:** `typed_contract_ir` method (line 162, `semanticir_emitter.rb`), after the `assumption_refs` emission (lines 184-185):

```ruby
# Existing:
assumption_refs = contract.fetch("assumption_refs", [])
contract_ir["assumption_refs"] = assumption_refs unless assumption_refs.empty?

# New (add after):
contract_ref_decls = contract.fetch("contract_ref_declarations", [])
unless contract_ref_decls.empty?
  contract_ir["contract_refs"] = contract_ref_decls.map do |decl|
    ref = {
      "contract_name"     => decl.fetch("target"),
      "resolution_status" => decl.fetch("resolution_status", "unresolved")
    }
    if decl["resolved_ref"]
      ref.merge!(decl.fetch("resolved_ref").slice("module_name", "modifier", "input_count",
                                                   "input_names", "output_names"))
    end
    ref
  end
end
```

**Full schema for a resolved `contract_refs` entry:**

```json
{
  "contract_name": "Validator",
  "resolution_status": "resolved",
  "module_name": "Lab.TypedRef.Basic",
  "modifier": "pure",
  "input_count": 1,
  "input_names": ["value"],
  "output_names": ["result"]
}
```

**Unresolved entry (OOF-REF1/2/4):**

```json
{
  "contract_name": "Unknown",
  "resolution_status": "unresolved"
}
```

**Hash placement decision:** `contract_refs` IS included in the `contract_ref` content hash.

Rationale: the `contract_ref` hash (computed by `contract_ref` method at line 840) is a
content-addressed identity of the contract's declared structure. A `uses ContractName`
declaration is a source-visible structural claim — adding or removing it changes the
declaring contract's declared structure and thus its identity. This is consistent with
`assumption_refs` (which is also included in the hash material).

The `contract_ref` method rejects only `"contract_ref"` and `"diagnostics"` from the hash body:

```ruby
def contract_ref(contract_ir)
  body = contract_ir.reject { |key, _value| key == "contract_ref" || key == "diagnostics" }
  "contract/#{contract_ir.fetch("contract_name")}/sha256:#{Digest::SHA256.hexdigest(canonical_json(body))[0, 24]}"
end
```

No change to this method is needed — `contract_refs` naturally enters the hash body.

---

### Q6 — Assembler / Manifest: `dependency_edges` Field

**Insertion point:** `assemble` method in `assembler.rb` (near line 246), after the existing
`contract_refs` manifest field (name→hash):

```ruby
# Existing (name → contract_ref hash):
"contract_refs" => semantic_ir.fetch("contracts").to_h do |contract|
  [contract.fetch("contract_name"), contract.fetch("contract_ref")]
end,

# New (add after):
"dependency_edges" => dependency_edges(semantic_ir),
```

**`dependency_edges` helper:**

```ruby
def dependency_edges(semantic_ir)
  semantic_ir.fetch("contracts").flat_map do |contract|
    (contract.fetch("contract_refs", [])).map do |ref|
      {
        "from_contract" => contract.fetch("contract_name"),
        "to_contract"   => ref.fetch("contract_name"),
        "resolution"    => ref.fetch("resolution_status")
      }
    end
  end
end
```

This produces a flat array of `{ from_contract, to_contract, resolution }` objects.
Only emit when non-empty (omit key if empty, consistent with existing optional fields).

**Artifact hash inclusion:** `dependency_edges` enters the manifest as a top-level field.
The manifest is included in `artifact_hash` material (Canonical.hash of the full manifest).
No additional action is required — the field inclusion in the manifest struct automatically
enters the hash.

**Naming disambiguation:**
- Manifest `contract_refs` (existing): `{ "ContractName" => "contract/ContractName/sha256:..." }` — name → hash
- Per-contract SemanticIR `contract_refs` (new): `[{ "contract_name": ..., "modifier": ... }]` — typed ref objects
- Manifest `dependency_edges` (new): `[{ "from_contract": ..., "to_contract": ..., "resolution": ... }]` — edge list

These are at different levels (manifest vs. per-contract); no naming conflict.

---

### Q7 — Import Interaction

**v0 scope:** same-module only. Cross-module refs require the import module table (PROP-IMPORT-RESOLUTION-P3 gate). This is the F8 finding from LAB-TYPED-CONTRACT-REF-P1.

**What P3 must prove about import coexistence:**
- A file with both `import` declarations and `uses ContractName` compiles without error when the target is same-module
- `import` declarations do not affect the same-module registry lookup for `uses`
- `import` declarations do not grant `uses` resolution for imported module contracts in v0
- Attempting `uses Mod.Contract` (qualified) while having a valid `import Mod` → OOF-REF2 (not resolved; cross-module deferred)

**Classifier import interaction:** The `classified_program` already builds the import table for its own purposes. The `uses_contract` classifier branch does NOT touch the import table — it only collects the raw node.

**Typechecker import interaction:** The `same_module_registry` is built from `classified_program.fetch("contracts")` — this is the module-local contract universe, which does not include imported contracts. Attempting to resolve an imported contract name in v0 → OOF-REF1 (unknown). This is correct and intentional.

---

### Q8 — Forms Boundary

**What is locked:** `uses ContractName` is the TH-1 lowering substrate for the forms layer
(LAB-FORM-LAYER-THEORY-P1 / TH-1 conservativity). P3 must preserve this substrate role
by ensuring `contract_refs` in SemanticIR carries exactly the fields that LAB-FORM-LAYER-THEORY needs:

- `contract_name`, `module_name`, `modifier`, `input_count`, `input_names`, `output_names`

These fields are the same ones proven sufficient in LAB-TYPED-CONTRACT-REF-P1 (F7).

**What P3 must NOT open:**

- No form syntax (no `form`, `call_form`, etc.)
- No form vocabulary or DSL
- No `form_registry` or `form_resolver` references
- No macro expansion hooks
- No `uses ContractName` as a form constructor or invocation point

P3's `uses_contract` node is a static metadata declaration only. The forms layer
interprets it later. P3 does not know about forms.

---

### Q9 — Runtime Boundary

P3 must not implement any of:

- `ContractRef#execute`, `ContractRef#invoke`, `ContractRef#call`
- VM dispatch via `uses_contract` nodes
- `runtime_dispatch` from contract_refs
- capability or profile authority derived from `uses_contract`
- `contract_refs` emitted as executable VM bytecode or instructions
- `uses_contract` nodes reaching `RuntimeMachine`

The `uses_contract` SemanticIR node is a metadata node. The SemanticIR emitter's
`typed_nodes` method (line 250) filters nodes for VM emission. A `uses_contract`
node must NOT appear in the `nodes` array of the emitted `contract_ir` — it is
metadata, not a compute node.

**Insertion in `typed_nodes`:**

```ruby
when "uses_contract"
  nil  # metadata only; not emitted as a runtime node
```

Or more simply, ensure `filter_map` returns `nil` for `uses_contract` nodes.
The check: `typed_nodes` must not emit a compute/temporal/stream/fold node for
`uses_contract` declarations.

---

### Q10 — Regression Matrix

**Proof runner location (P3):**

```text
igniter-lang/experiments/typed_contract_ref_proof/verify_typed_contract_ref_p3.rb
```

**Target: ≥60 checks, all PASS.**

**Proposed proof sections:**

| Section | Checks | Focus |
|---------|--------|-------|
| PARSE | ~10 | unqualified target; dotted path; multiple uses; alongside uses_assumptions; OOF-P0 for blank uses |
| CLASSIFY | ~8 | no fragment change for pure/effect target; contract_ref_declarations collected; passthrough |
| TYPECHECK | ~12 | same-module resolved; OOF-REF1 unknown; OOF-REF4 self; OOF-REF2 cross-module; modifier preserved |
| SEMANTICIR | ~10 | contract_refs field present; schema shape; resolved entry fields; unresolved entry fields |
| MANIFEST | ~8 | dependency_edges present; enters artifact_hash; deterministic replay; empty omitted |
| COEXISTENCE | ~8 | alongside call_contract; alongside import; alongside uses_assumptions; alongside entrypoint |
| AUTHORITY | ~8 | no execute/dispatch/capability; no fragment change; call_contract unchanged; no VM node |
| **Total** | **~64** | |

**Regression proofs that must stay green (P3 card must list these):**

| Proof | Location | Expected |
|-------|----------|---------|
| PROP-IMPORT-RESOLUTION-P5 | `experiments/import_resolution_proof/verify_prop_import_resolution_p5.rb` | 99/99 PASS |
| PROP-ENTRYPOINT-P3 | `experiments/entrypoint_descriptor_proof/verify_entrypoint_p3.rb` | 53/53 PASS |
| LAB-TYPED-CONTRACT-REF-P1 | `igniter-lab/igniter-view-engine/proofs/verify_lab_typed_contract_ref_p1.rb` | 58/58 PASS |
| P11 call_contract typechecker | `igniter-lab/igniter-view-engine/proofs/verify_p11_call_contract_typechecker_resolution.rb` | PASS |
| P10 call_contract preflight | `igniter-lab/igniter-view-engine/proofs/verify_p10_call_contract_type_preflight.rb` | PASS |

---

## 4. Insertion Point Summary Table

| Pipeline stage | File | Line approx | Change kind | Size estimate |
|----------------|------|-------------|-------------|---------------|
| Parser | `lib/igniter_lang/parser.rb` | 980 `parse_uses_decl` | Branch + dotted-name loop | 20–35 lines |
| Classifier | `lib/igniter_lang/classifier.rb` | 160 `classify_contract` case | `when "uses_contract"` branch + array init | 10–15 lines |
| TypeChecker | `lib/igniter_lang/typechecker.rb` | 333 body loop | `when "uses_contract"` + registry helper + 3 OOF cases | 50–70 lines |
| SemanticIR | `lib/igniter_lang/semanticir_emitter.rb` | 184 `typed_contract_ir` | `contract_refs` field emission | 15–20 lines |
| SemanticIR nodes | `lib/igniter_lang/semanticir_emitter.rb` | 250 `typed_nodes` | `when "uses_contract" then nil` | 1–2 lines |
| Assembler | `lib/igniter_lang/assembler.rb` | ~246 manifest block | `dependency_edges` field + helper | 15–20 lines |

Total estimated implementation scope: ~110–160 lines across 5 files.

---

## 5. Data Flow Through Pipeline

```
Source:  "uses Validator"  (BodyDecl in contract body)
         ↓
Parser:  { kind: "uses_contract", target: "Validator" }
         ↓
Classifier: classified_decl(..., "metadata", [], [])
            contract_ref_declarations << node
         ↓
TypeChecker: same_module_registry lookup → resolved
             typed_decl + resolved_ref{ modifier, input_count, ... }
             OOF-REF1/2/4 if not resolved
         ↓
SemanticIR: contract_ir["contract_refs"] = [{ contract_name, resolution_status,
              module_name, modifier, input_count, input_names, output_names }]
            NOT in typed_nodes (metadata only)
         ↓
contract_ref hash: includes contract_refs (behavioral identity of contract)
         ↓
Assembler: manifest["dependency_edges"] = [{ from_contract, to_contract, resolution }]
           enters artifact_hash via manifest material
```

---

## 6. Open Questions Deferred to P3 or Later

| Question | Deferred to |
|----------|------------|
| Cross-module `uses Mod.Contract` resolution | Import module table gate (PROP-IMPORT-RESOLUTION-P3 parity) |
| Cycle detection beyond direct self-reference | After cross-module; requires full DAG traversal |
| Visibility/export gating on typed refs | PROP-MODULE-VISIBILITY-P1 |
| OOF-REF3 (effect/boundary cases) | Reserved; not active in v0 |
| OOF-REF5 (signature mismatch) | Reserved; not active in v0; requires typed signature comparison |
| `contract_refs` in Rust lab pipeline | Lab parity card after P3 lands |
| Forms lowering over contract_refs (TH-1) | LAB-CONTRACT-FORMS-P2 (has this substrate now) |

---

## 7. Coexistence Summary

**With `call_contract`:** `uses Validator` and `call_contract("Validator", ...)` can coexist
in the same contract body. The `uses_contract` node provides typed metadata; the
`call_contract` node provides the stringly runtime invocation. Neither changes the other.
P3 must prove a fixture where both appear and both compile successfully.

**With `uses assumptions NAME`:** `uses assumptions A` and `uses Validator` can coexist.
They are distinct node kinds in the same body. P3 must prove coexistence.

**With `import`:** An `import` declaration and `uses ContractName` coexist — import
provides name visibility for other purposes; `uses` in v0 only resolves same-module
contracts. P3 must prove that having both does not cause errors when target is same-module.

**With `entrypoint`:** Orthogonal. A module with an `entrypoint` declaration and
contracts containing `uses` declarations compiles correctly. P3 must prove.

---

## 8. Decision

**READY FOR P3.**

The implementation is bounded to the Ruby canon pipeline, same-module contracts only.
The insertion points are exact and the size estimate (~110–160 lines across 5 files) is
consistent with prior bounded implementation cards (PROP-ENTRYPOINT-P3 ~160 lines,
PROP-IMPORT-RESOLUTION-P5 ~280 lines with resolver).

No authority is opened. `call_contract` is unchanged. Fragment classification is unchanged.
The VM and runtime are untouched.

---

## 9. Closed Surfaces

- No implementation in this card (planning only)
- No code written or modified
- No cross-module typed refs
- No forms vocabulary
- No runtime/VM
- No call_contract changes
- No Rust lab parity
- No public API widening
- No OOF-REF3/5 implementation

---

## 10. Next Route

```
LANG-TYPED-CONTRACT-REF-PROP-P3   — bounded Ruby canon implementation proof
                                    (parser + classifier + typechecker + SemanticIR
                                    + assembler; OOF-REF1/2/4; ≥60 checks)

LAB-CONTRACT-FORMS-P2             — PROP-Forms lineage reconciliation (now has
                                    typed-ref substrate as TH-1 lowering target)

LAB-FORM-CONSTRUCTOR-P1           — Gap-I (Covenant P27/P28, independent clock)
```
