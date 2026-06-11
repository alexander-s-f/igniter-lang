# LANG-TYPED-CONTRACT-REF: Typed Contract Reference Declaration

**Track:** typed-contract-reference-declaration-and-contract-dependency-edge-v0
**Route:** PROPOSAL AUTHORING ONLY / NO IMPLEMENTATION
**Authority:** proposal text only — no parser, compiler, VM, or runtime implementation authorized
**Date:** 2026-06-11
**Status:** authored — pending review
**Grounding evidence:**
- LAB-TYPED-CONTRACT-REF-P1 (58/58 PASS — ACCEPT; proof-local model validated)
- LAB-CONTRACT-FORMS-P1 (SPLIT verdict; this proposal executes Track 1 of 3)
- LAB-FORM-LAYER-THEORY-P1 (OPEN; typed refs are the lowering substrate for forms — TH-1 path)
- PROP-032 (`uses assumptions NAME` precedent — `uses` keyword already in language)
- PROP-IMPORT-RESOLUTION (import = compile-time name visibility; typed ref = compile-time dependency edge)
- PROP-002 (contract composition algebra; typed refs are named DAG edges in the traced SMC)

---

## 1. Purpose

An Igniter contract that uses another contract via `call_contract("Name", args...)`
hides the dependency from source. The compiler knows the edge (Tier 1 static
resolution since LAB-RACK-P11), but a reader or tool cannot find it without
compiling. The dependency is expressed as a string literal, not a typed,
inspectable declaration.

This proposal introduces:

```igniter
uses ContractName
```

as a contract body declaration that makes the dependency **source-visible, typed,
and statically inspectable** — without executing the referenced contract, without
granting authority, and without changing the contract's fragment classification.

The core claim:

```text
uses ContractName
  = compile-time ContractRef (typed, static, inspectable)
  ≠ invocation
  ≠ import
  ≠ capability grant
  ≠ fragment class change
  ≠ runtime dispatch
```

---

## 2. Authority Boundary

This proposal authorizes no implementation:

- no parser changes
- no compiler changes (classifier, typechecker, SemanticIR emitter, assembler)
- no VM or runtime changes
- no `call_contract` behavior changes
- no form syntax or form vocabulary
- no macro or composition system changes
- no visibility, package, or public API changes
- no capability or profile authority
- no stdlib promotion
- no cross-file import authority

Lab proofs (LAB-TYPED-CONTRACT-REF-P1) are evidence of viability.
They are not canon authority. Implementation is gated behind
LANG-TYPED-CONTRACT-REF-PROP-P2 planning.

---

## 3. Context and Motivation

### 3.1 The stringly problem

`call_contract("Validator", amount)` has three structural weaknesses:

1. **Source-invisible edge**: tools and readers cannot enumerate contract
   dependencies without compiling. The compiler sees the DAG; the source hides it.

2. **Stringly-typed name**: renaming `Validator` silently orphans all callers
   until the next compile — and only Tier 1 literal callers get a diagnostic.
   Tier 2 dynamic callers are permanently opaque.

3. **No signature at call site**: nothing at the call site declares what
   inputs and outputs the callee is expected to have. A signature mismatch
   is a runtime surprise.

### 3.2 What typed refs fix

A `uses ContractName` declaration:
- makes the dependency **source-visible** (tools can find it without compilation)
- gives the dependency an **inspectable signature** (input/output ports, modifier)
- makes the dependency **refactor-safe** (rename → update `uses` → compiler confirms)
- creates an **explicit DAG edge** that can appear in manifests, receipts, and debug views
- serves as the **lowering substrate** for Contract Invocation Forms (LAB-FORM-LAYER-THEORY-P1 TH-1)

### 3.3 What typed refs do not fix

This proposal does NOT:
- replace `call_contract` (that is a separate, future decision — see §10)
- introduce runtime invocation semantics
- introduce form vocabulary or form-assisted composition
- solve the module visibility / export problem

### 3.4 Grammar precedent: `uses assumptions NAME` (PROP-032)

The `uses` keyword is already in the Igniter language.
PROP-032 (`assumptions {}` block) introduced:

```igniter
uses assumptions homophily
```

as a contract body declaration that references a named assumptions block.
This proposal follows the identical structural pattern:

```igniter
uses ContractName          -- typed contract reference (this PROP)
uses assumptions NAME      -- assumptions reference (PROP-032)
```

Parser disambiguation is 1-token lookahead: if the token after `uses` is
the keyword `assumptions`, it is a `UsesAssumptionsDecl`; otherwise it is
a `UsesContractDecl`. No ambiguity.

---

## 4. Explicit Design Answers

| Question | Answer |
|----------|--------|
| v0: metadata-only or first-class value? | **Metadata-only** — `uses` produces a `ContractRef` in SemanticIR; it is not a runtime value, not addressable in `compute` nodes |
| Can `uses` point to effect contracts? | **Yes** — modifier is preserved in the ContractRef; no v0 restriction on target modifier; boundary enforcement (if ever needed) belongs to a future Effect Surface extension |
| Cross-module reference allowed? | **Yes** — `uses Mod.Contract` (qualified form) or `uses Contract` after `import Mod.{Contract}` |
| Unqualified external name requires import? | **Yes** — unqualified names resolve to: (1) current module, (2) explicit imports, (3) OOF-REF1 |
| Creates DAG execution dependency? | **No** — `uses` is a compile-time metadata declaration; no runtime ordering, no execution guarantee, no scheduler edge |
| Affects fragment classification? | **No** — `uses Validator` in a `pure` contract does not make the contract non-pure; modifier of the declaring contract is unchanged |
| Appears in SemanticIR / receipts? | **Yes** — `contract_refs` field on each contract object; propagates into manifest `dependency_edges` |
| Replaces `call_contract`? | **No** — `call_contract` continues unchanged; `uses` is an independently declared dependency annotation |
| `call_contract` deprecated now? | **No** — marked as "stringly-typed pressure source"; upgrade path defined (see §10); no deprecation timeline in this PROP |
| Implementation authorized after P1? | **No** — P2 implementation planning card required |

---

## 5. Syntax

### 5.1 Grammar extension

This PROP extends `BodyDecl` with one new form:

```text
BodyDecl := EscapeDecl
           | InputDecl
           | ReadDecl
           | ComputeDecl
           | SnapshotDecl
           | WindowDecl
           | OutputDecl
           | UsesAssumptionsDecl     -- from PROP-032
           | UsesContractDecl        -- this PROP (NEW)

UsesContractDecl := "uses" ContractTarget

ContractTarget   := Name              -- unqualified: "Validator"
                  | ModPath           -- qualified: "Lab.Core.Validator"

ModPath          := Name ("." Name)+  -- e.g. "Lab.Core.Validator"
```

`Name` here must be a valid contract name (PascalCase identifier resolving
to a `ContractDecl`). Type names, function names, and assumption block names
are not valid targets.

**Disambiguation from PROP-032:**

```text
If token[1] after "uses" == "assumptions" → UsesAssumptionsDecl
Otherwise                                 → UsesContractDecl
```

No grammar conflict; `assumptions` is reserved in this position.

### 5.2 Syntax examples

```igniter
module Lab.Payments

import Lab.Validation.{ AmountValidator }

pure contract PaymentProcessor {
  -- Declare typed reference to Validator (same module)
  uses FraudChecker
  -- Declare typed reference to AmountValidator (imported module)
  uses AmountValidator

  input amount : Integer
  compute fraud_ok = call_contract("FraudChecker", amount)
  compute amount_ok = call_contract("AmountValidator", amount)
  output fraud_ok : Bool
}

pure contract FraudChecker {
  input amount : Integer
  compute result = amount < 10000
  output result : Bool
}
```

```igniter
-- Qualified form (no import needed if module is in compilation universe)
pure contract Reporter {
  uses Lab.Analytics.EventAggregator

  input event_id : Integer
  compute result = call_contract("EventAggregator", event_id)
  output result : Integer
}
```

### 5.3 Ordering within contract body

`UsesContractDecl` may appear anywhere in the contract body after any
modifier prefix and before or after `input`/`compute`/`output` declarations.
Convention (not enforced): declare `uses` before `input`.

```igniter
pure contract Example {
  uses OtherContract          -- convention: uses before inputs
  input n : Integer
  compute result = call_contract("OtherContract", n)
  output result : Integer
}
```

### 5.4 Multiple uses declarations

A contract may declare multiple `uses` targets:

```igniter
pure contract Orchestrator {
  uses ValidatorA
  uses ValidatorB
  uses Transformer

  input n : Integer
  compute a = call_contract("ValidatorA", n)
  compute b = call_contract("ValidatorB", n)
  compute t = call_contract("Transformer", n)
  output t : Integer
}
```

---

## 6. Semantics

### 6.1 ContractRef (compile-time model)

Each `uses ContractTarget` declaration produces a compile-time `ContractRef`:

```text
ContractRef = {
  declared_name   : String             -- as written in source: "Validator" or "Lab.Core.Validator"
  module_name     : String             -- resolved module: "Lab.TypedRef.Basic"
  contract_name   : String             -- resolved contract: "Validator"
  contract_ref    : String             -- "contract/<Name>/sha256:<24-hex>"
  modifier        : "pure"|"effect"|"query"
  input_ports     : [{name, type}]     -- callee's input declarations
  output_ports    : [{name, type}]     -- callee's output declarations
  source_span     : {line, col}?       -- position of the `uses` declaration
  resolution_status : "resolved"|"failed"
}
```

`contract_ref` is derived from the callee's `source_hash` per the identity
model from LANG-MODULE-IDENTITY-P1/P2: `"contract/<Name>/sha256:<24-hex prefix>"`.

### 6.2 Resolution algorithm

```text
Resolve(UsesContractDecl { target }) at compile time:

  If target is unqualified Name:
    1. Look up in current module's contract registry (same-module)
    2. Look up in imported names (from explicit import declarations)
    3. If zero matches → OOF-REF1 (unknown contract reference)
    4. If >1 matches  → OOF-REF2 (ambiguous contract reference)

  If target is ModPath (qualified):
    1. Split into module path + final Name
    2. Verify the module path is in the compilation universe
       (either current module or imported module)
    3. Look up the final Name in that module's contract registry
    4. If module not found → OOF-REF1
    5. If contract not found in module → OOF-REF1
    6. If ambiguity (multiple modules match path prefix) → OOF-REF2
```

Resolution is **order-independent**: the result does not depend on declaration
order within the source file or file order in a multi-file compilation unit.
(Evidence: LAB-TYPED-CONTRACT-REF-P1 F-04.)

### 6.3 What resolution produces

A resolved ContractRef carries the full signature of the target contract:
input ports, output ports, and modifier. This creates a compile-time
**signature contract** between the declaring contract and its dependency:

```text
Processor uses Validator:
  Validator.modifier    == "pure"
  Validator.input_ports == [{name: "amount", type: "Integer"}]
  Validator.output_ports == [{name: "is_valid", type: "Bool"}]
```

In v0, this is metadata — no enforcement of signature compatibility between
`call_contract` invocations and the declared `uses` target. Enforcement
belongs to a future PROP (signature binding pass).

### 6.4 What resolution does NOT produce

- **No execution**: resolving a `uses` declaration does not invoke the contract
- **No capability grant**: even if the callee is an `effect` contract, the
  declaring contract's modifier and capability surface are unchanged
- **No runtime edge**: no scheduling edge, no priority ordering, no dependency
  lifecycle coupling is implied
- **No public visibility**: `uses` does not make either contract public

### 6.5 Self-reference

`uses ContractName` where `ContractName` is the declaring contract:

```text
OOF-REF4: self-reference in uses declaration
  → forbidden in v0
  → message: "contract 'X' cannot use itself"
```

### 6.6 Cycle detection

Direct A-uses-B / B-uses-A cycles are forbidden:

```text
OOF-REF4: cycle in uses dependency graph
  → message: "cycle detected in uses declarations: A → B → A"
```

The `uses` DAG must be acyclic. (Note: `call_contract` cycles are handled
separately at the VM level; this rule applies only to `uses` declarations.)

---

## 7. Diagnostics (OOF-REF namespace)

The `OOF-REF*` namespace is reserved for typed contract reference diagnostics.
It does not overlap with:

- `OOF-M*` — modifier/effect/profile/evidence (PROP-031/035/040/034)
- `OOF-IMP*` — import/module resolution (PROP-IMPORT-RESOLUTION-P2A)
- `OOF-TY*` — type checker (PROP-021)
- `OOF-L*`/`OOF-R*` — recursion/loop (PROP-039)

| Code | Trigger | Message shape |
|------|---------|---------------|
| OOF-REF1 | Target contract not found | `"uses: unknown contract '${name}' — not found in current module or imports"` |
| OOF-REF2 | Ambiguous unqualified name | `"uses: ambiguous contract '${name}' — found in modules: ${list}"` |
| OOF-REF3 | (reserved) | Effect/capability boundary violation if v0 restricts targets (currently open; not emitted in v0) |
| OOF-REF4 | Self-reference or cycle | `"uses: self-reference or cycle in dependency: ${chain}"` |
| OOF-REF5 | (reserved) | Signature mismatch if port constraints are added in a future PROP |

In v0, only OOF-REF1, OOF-REF2, and OOF-REF4 are active diagnostics.
OOF-REF3 and OOF-REF5 are reserved for future extension.

---

## 8. SemanticIR

A new field `contract_refs` is added to each contract object in the
SemanticIR program envelope:

```json
{
  "contracts": [
    {
      "contract_name": "Processor",
      "modifier": "pure",
      "inputs": [...],
      "outputs": [...],
      "nodes": [...],
      "contract_refs": [
        {
          "declared_name": "Validator",
          "module_name": "Lab.TypedRef.Basic",
          "contract_name": "Validator",
          "contract_ref": "contract/Validator/sha256:a3f8c1d7e9b2045e",
          "modifier": "pure",
          "input_ports": [
            {"name": "amount", "type": "Integer"}
          ],
          "output_ports": [
            {"name": "is_valid", "type": "Bool"}
          ],
          "resolution_status": "resolved"
        }
      ]
    }
  ]
}
```

**Notes:**
- `contract_refs` is an empty array `[]` when no `uses` declarations are present.
- `resolution_status` is `"resolved"` or `"failed"` (failed refs produce a
  diagnostic and may or may not appear in the field — implementation decision for P2).
- `source_span` is optional in v0 (may be added when parser provides span info).

Contracts with no `uses` declarations emit `"contract_refs": []` and are
backward-compatible with all existing SemanticIR consumers.

---

## 9. Manifest (.igapp)

A new field `dependency_edges` is added to the `.igapp` manifest:

```json
{
  "kind": "igapp",
  "source_hash": "sha256:...",
  "contract_index": {...},
  "entrypoint": {...},
  "dependency_edges": [
    {
      "from_module": "Lab.Payments",
      "from_contract": "PaymentProcessor",
      "to_ref": "contract/FraudChecker/sha256:a3f8c1d7e9b2045e",
      "to_module": "Lab.Payments",
      "to_contract": "FraudChecker",
      "resolution_status": "resolved"
    },
    {
      "from_module": "Lab.Payments",
      "from_contract": "PaymentProcessor",
      "to_ref": "contract/AmountValidator/sha256:7d2b9c3e1a4f0852",
      "to_module": "Lab.Validation",
      "to_contract": "AmountValidator",
      "resolution_status": "resolved"
    }
  ]
}
```

`dependency_edges` enters the artifact hash material (it is part of the
compilation outcome, not a post-hoc annotation). Contracts with no `uses`
declarations emit `"dependency_edges": []`.

---

## 10. Relationship to Existing Surfaces

### 10.1 `call_contract` — stringly-typed pressure source (not deprecated)

`call_contract("Name", args...)` continues to work exactly as today.
It is **not deprecated** in this PROP. It is marked as a "stringly-typed
pressure source": source code that uses `call_contract` without a
corresponding `uses` declaration is valid but carries reduced inspectability.

**Upgrade path** (documented, not enforced in v0):

```igniter
-- Before (stringly):
pure contract Processor {
  input n : Integer
  compute result = call_contract("Validator", n)
  output result : Bool
}

-- After (typed + stringly): both forms present during transition
pure contract Processor {
  uses Validator
  input n : Integer
  compute result = call_contract("Validator", n)
  output result : Bool
}

-- After (typed only, once call_contract replacement is designed):
pure contract Processor {
  uses Validator
  input n : Integer
  compute result = Validator(n)   -- hypothetical future invocation syntax
  output result : Bool
}
```

The third form (hypothetical invocation syntax) is out of scope for this PROP.

### 10.2 Import — name visibility only

`import Mod.{Name}` makes a name available in the current source unit.
It does NOT create a typed contract reference. `uses Name` creates the
typed reference. The two are independent:

```text
import = name visibility
uses   = dependency edge

You can import without using. You can use (qualified) without importing.
```

To use an unqualified external contract name, you must import it first.
To use a qualified name (`uses Mod.Contract`), import is not required
(the module must be in the compilation universe).

### 10.3 Entrypoint

`entrypoint ContractName` (PROP-ENTRYPOINT) is a module-level declaration
that selects a contract as the compilation unit's entry point.
`uses ContractName` is a contract-body declaration that declares a dependency.
They are orthogonal:

```igniter
entrypoint Main          -- module-level: this is the entry

pure contract Main {
  uses Helper            -- contract body: Main depends on Helper
  ...
}
```

### 10.4 Contract Invocation Forms (LAB-CONTRACT-FORMS-P2)

The `uses` declaration is the **lowering substrate** for Contract Invocation
Forms. A form that desugars to a `ContractInvocation` node must know which
contract it refers to. That knowledge is carried by a `ContractRef`. TH-1
(conservativity receipt) requires: `form-expanded-IR ≡ hand-expanded-IR`.
The `ContractRef` from `uses` is the "hand-expanded" side.

```text
uses Contract    ← the substrate (this PROP)
form InvokeStyle → Contract(args)  ← the sugar (LAB-CONTRACT-FORMS-P2)
```

### 10.5 PROP-002 Composition Algebra

PROP-002 defines the contract composition algebra as a traced symmetric
monoidal category (SMC) where contracts are generators and composition
operators (`>>`, `||`, `branch`, `over`, `embed`) are structure maps.

`uses ContractName` creates a **named reference to a generator** in the
SMC graph. It is not a composition operator. It is the labeling mechanism
for a node in the string diagram: the `ContractRef` is the type tag on
a "box" in the diagram before any wires are drawn.

---

## 11. Non-Goals

This proposal does NOT address:

- **Runtime invocation syntax**: no `Contract(args)` syntax is proposed
- **Form vocabulary**: `uses` is not a form; no `speaks`/`form` authority opened
- **Macro expansion**: `uses` does not expand to code
- **Module visibility**: `uses` does not make contracts public or private
- **Package system**: `uses` does not interact with distribution or semver
- **Capability delegation**: `uses` to an effect contract does not grant the declaring contract effect capability
- **Scheduler edges**: `uses` does not imply execution ordering
- **Gap-I Form Constructor** (`form NAME -> TypeTarget`, Covenant P27/P28): independent track

---

## 12. Fragment Classification

`uses` does not change the fragment classification of the declaring contract:

```text
Rule: fragment_class(declaring_contract) is determined by its modifier and body declarations,
      not by the modifier of its `uses` targets.

Corollary: a `pure` contract may declare `uses EffectContract`
           and remain `pure` — it has not executed the effect contract.
```

This preserves the single-contract inspectability invariant: you can determine
a contract's fragment class from its own declarations without examining its
dependency graph.

---

## 13. Proof Evidence Mapping

From LAB-TYPED-CONTRACT-REF-P1 (58/58 PASS):

| Proposal claim | Proof check |
|---------------|-------------|
| All ContractRef fields already in SemanticIR | A-06 PASS |
| Literal callee discriminant available | A-02 PASS |
| ContractRef resolves with full signature | B-01..B-08 PASS |
| Unknown/effect/arity/self-rec → fail closed | C-01..C-08 PASS |
| Ref has no execute/dispatch/capability method | D-01..D-03 PASS |
| Effect modifier preserved in resolved ref | D-04 PASS |
| Fragment classification unchanged | D-05 PASS |
| Not a form / not a macro / future lowering target | E-01..E-06 PASS |
| Cross-file order-independent resolution | F-04 PASS |
| Import ≠ capability grant | F-05 PASS |
| Ambiguity = diagnostic, not first-wins | F-06 PASS |
| Edge label, signature expansion, JSON serialization | G-01..G-06 PASS |

---

## 14. Implementation Path (not authorized by P1)

P1 closes with proposal text only. Implementation requires:

1. **LANG-TYPED-CONTRACT-REF-PROP-P2** — implementation planning card:
   - Parser extension: `UsesContractDecl` grammar production
   - Classifier pass: collect `uses` declarations, verify target type
   - Typechecker pass: resolve `ContractRef`, populate `contract_refs`
   - SemanticIR emitter: emit `contract_refs` field
   - Assembler: emit `dependency_edges` in manifest
   - OOF-REF1/REF2/REF4 diagnostic implementation
   - Proof matrix target: ≥40 checks

2. Tests / proof fixtures required before any implementation is merged.

3. Ruby canon parity decision required (mirrors PROP-IMPORT-RESOLUTION-P4/P5 pattern).

---

## 15. Open Questions

The following design decisions are deferred to P2 or a future PROP:

| Question | Deferred to |
|----------|-------------|
| Should `uses` with unresolvable targets block compilation or warn? | P2 implementation planning |
| Should v0 restrict `uses` targets to pure contracts only? | P2 (currently: no restriction) |
| Can `uses` declarations be inherited by subtypes or composition? | Future PROP (requires PROP-016 polymorphism) |
| Signature enforcement: should the typechecker verify `uses` signature matches `call_contract` args? | Future PROP (requires signature binding pass) |
| Tool / IDE support: should `uses` generate a machine-readable dependency graph for static analysis? | Tooling track (out of scope for language PROP) |
| Aliasing: `uses Validator as V`? | Deferred (aliasing opens disambiguation questions) |
| Multiple targets in one declaration: `uses {ValidatorA, ValidatorB}`? | Deferred |

---

## 16. Summary

`uses ContractName` is the smallest intervention that makes contract dependency
edges source-visible, typed, and inspectable. It follows the exact syntactic
precedent of `uses assumptions NAME` (PROP-032), requires no new keywords, has
1-token lookahead disambiguation, and is backward-compatible with all existing
programs (adding `"contract_refs": []` to contracts with no `uses` declarations).

The declaration is metadata-only in v0: it creates no execution, no capability,
no authority, and no runtime dispatch. Its primary purpose is to lay the
foundations for:

1. **Refactor-safe dependencies**: rename callee → update `uses` → compiler confirms
2. **Source-visible DAG**: tools find dependency graph without compilation
3. **Form lowering substrate**: Contract Invocation Forms (LAB-CONTRACT-FORMS-P2)
   lower to typed refs as TH-1 conservativity path
4. **Manifest dependency edges**: `.igapp` carries the dependency graph as
   evidence, entering the artifact hash

The `OOF-REF*` namespace is reserved. Implementation gates on
LANG-TYPED-CONTRACT-REF-PROP-P2.
