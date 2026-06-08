# PROP-035: Effect Surface — IO.Capability v0

Status: experiment-pass
Date: 2026-06-07
Implemented: 2026-06-07
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Depends on: PROP-031 (contract modifiers), PROP-003 (fragment classification), PROP-019 (SemanticIR)
Stage: 3
Evidence: experiments/io_capability_proof/ — 64/64 PASS
Numbering note: PROP-031 §1 deferred "Effect Surface" explicitly to PROP-035.
  current-status.md had queued "profile declarations" also as PROP-035 (numbering collision).
  Resolution (2026-06-07, Portfolio Architect): PROP-035 = Effect Surface (PROP-031 intent wins;
  file already written and grammar implemented). Profile declarations renumbered to PROP-040.
Source: `docs/meta-proposals/META-EXPERT-013-spec-extension-governance-v0.md`
Governance: META-EXPERT-013 §VI (acceptance criteria)

---

## § 1. Purpose

PROP-031 introduced five contract modifiers (`pure`, `observed`, `effect`, `privileged`,
`irreversible`) and explicitly deferred IO.Capability body declarations to this proposal:

> "No Effect Surface validation (deferred to PROP-035)"
> "Effect Surface in PROP-035"
> "OOF-M2, OOF-M3 are deferred to PROP-035"

This proposal closes that deferral. It introduces two new body-level declarations:

1. **`capability <name>: <CapType>`** — declares an IO capability bound to a name inside
   the contract body. The capability type (e.g., `IO.NetworkCapability`) describes what
   external resource is accessible and under what constraints.

2. **`effect <name> using <cap_ref>`** — binds an effect surface to a declared capability.
   Declares intent to perform a side-effecting operation using the named capability.
   Operationally, this is the compile-time statement that the `effect` contract modifier
   corresponds to a specific, named capability.

Together, these two declarations provide the grammatical surface for IO capability
programs. All compile-time constraints (OOF-M2..M5) and classifier/typechecker changes
are defined here.

Non-goals:
- No runtime capability resolution or authority injection (Phase 2)
- No capability delegation validation at compile time (proof-layer concern, proved in LAB-STDLIB-NET-P2..P6)
- No IO.NetworkCapability schema validation at compile time (the type is opaque to the compiler — it is the contract's module that defines schema; the compiler enforces grammar and structural rules only)

---

## § 2. Grammar Change

### § 2.1 New productions

```
capability-decl    ::= "capability" ident ":" type-ref

effect-binding-decl ::= "effect" ident "using" ident

body-decl          ::= ... | capability-decl | effect-binding-decl     -- added
```

`capability-decl` is a body declaration. It follows the same `name: Type` shape as
`input`, `read`, and `stream` declarations.

`effect-binding-decl` binds the effect surface label `name` to the declared capability
named `cap_ref`. The `using` keyword is the binding connector.

### § 2.2 Illustrative source

```igniter
effect contract ConnectToService {
  capability net_conn: IO.NetworkCapability
  effect connect_to_service using net_conn

  -- ... compute declarations, escape nodes, etc.
}
```

### § 2.3 Backward compatibility guarantee

Contracts without `capability` or `effect` body declarations compile without
modification. These are strictly additive grammar productions. `effect` as a body
keyword is already in the reserved keyword set (via CONTRACT_MODIFIERS); this proposal
adds it as a valid body-level declaration keyword inside a contract body only.

---

## § 3. ParsedProgram AST Delta

### capability-decl node

```json
{
  "kind": "capability",
  "name": "net_conn",
  "type_annotation": "IO.NetworkCapability"
}
```

`type_annotation` may be a bare string (`"IO.NetworkCapability"`) or a structured
type-ref hash if the type has parameters (e.g., `IO.NetworkCapability[Tcp]`).

### effect-binding-decl node

```json
{
  "kind": "effect_binding",
  "name": "connect_to_service",
  "capability_ref": "net_conn"
}
```

`capability_ref` is the identifier that must resolve to a `capability` declaration
in the same contract body.

---

## § 4. Classifier Changes

### § 4.1 capability body-node handler

`capability` declarations are classified as `escape` fragment class. They introduce
a named binding into the symbol table with kind `"capability"`.

```ruby
when "capability"
  symbol_fragments[node.fetch("name")] = "escape"
  symbol_kinds[node.fetch("name")]     = "capability"
  capability_declarations[node.fetch("name")] = node
  declarations << classified_decl(node, "escape", [], [])
```

### § 4.2 effect_binding body-node handler

`effect_binding` declarations are classified as `escape`. They reference a capability
by name. If the referenced capability is not declared in the same contract body,
OOF-M4 fires.

```ruby
when "effect_binding"
  cap_ref = node.fetch("capability_ref")
  effect_bindings << cap_ref
  unless capability_declarations.key?(cap_ref)
    diagnostics << oof("OOF-M4",
      "effect binding '#{node.fetch("name")}' references undeclared capability '#{cap_ref}'",
      node.fetch("name"))
  end
  symbol_fragments[node.fetch("name")] = "escape"
  symbol_kinds[node.fetch("name")]     = "effect_binding"
  declarations << classified_decl(node, "escape", [cap_ref].select { capability_declarations.key?(cap_ref) }, [])
```

### § 4.3 Post-loop diagnostics

After the body loop, two additional checks run:

**OOF-M2**: A `pure` contract that declares capabilities is an error. Pure contracts
cannot have IO access.

```
OOF-M2  pure contract with capability declaration
         severity: error
         message:  "pure contract '#{name}' cannot declare IO capabilities; use 'effect' modifier"
```

**OOF-M5**: A capability declared in the body but not referenced by any `effect`
binding is a warning-level structural inconsistency. A declared-but-unbound capability
is operationally inert — it can never be used to authorise an operation.

```
OOF-M5  capability declared but has no effect binding
         severity: warning (does not block compilation)
         message:  "capability '#{cap_name}' declared but has no effect...using binding"
```

### § 4.4 Fragment class interaction

`capability` and `effect_binding` both produce `"escape"` fragment class. This means:
- A contract with either declaration classifies as `"escape"` (not `"core"`)
- OOF-M1 fires if `modifier == "pure"` and any escape declaration is present (inherited from PROP-031)
- OOF-M2 fires specifically when `modifier == "pure"` and `capability_declarations.any?` (more specific message)

OOF-M1 and OOF-M2 may both fire for the same contract if a `pure` contract has both
a legacy `escape` declaration and a new `capability` declaration. This is correct: both
messages are informative.

---

## § 5. TypeChecker Changes

### § 5.1 capability node in typecheck_contract

The TypeChecker receives `capability` nodes from the Classifier. Type resolution:
`IO.NetworkCapability`, `IO.FileCapability`, `IO.Capability` are treated as opaque
capability types — they resolve to `type_ir("IO.Capability")` sentinel type, not
`Unknown`. The `when "capability"` branch is analogous to `when "stream"`.

```ruby
when "capability"
  type = type_ir(decl.fetch("type_annotation", "IO.Capability"))
  symbol_types[decl.fetch("name")] = type
  typed_decls << typed_decl(decl, type, nil, [])
when "effect_binding"
  # effect_binding is purely structural; type is Unit
  type = type_ir("Unit")
  symbol_types[decl.fetch("name")] = type
  typed_decls << typed_decl(decl, type, nil, decl.fetch("deps", []))
```

### § 5.2 IO.Capability type kind

`IO.NetworkCapability`, `IO.FileCapability`, and `IO.Capability` are valid type-ref
identifiers for `capability` declarations. They are opaque to the TypeChecker — the
compiler does not validate the fields of the capability value (that is the runtime
concern). The type resolves to the string `"IO.Capability"` in the type IR, which
is distinct from `"Unknown"` and does not trigger type-mismatch errors.

---

## § 6. Diagnostic Codes

| Code | Stage | Severity | Trigger | Message |
|------|-------|----------|---------|---------|
| OOF-M2 | Classifier | error | `pure` contract with `capability` body decl | `"pure contract '${name}' cannot declare IO capabilities; use 'effect' modifier"` |
| OOF-M4 | Classifier | error | `effect_binding` references undeclared capability | `"effect binding '${name}' references undeclared capability '${cap_ref}'"` |
| OOF-M5 | Classifier | warning | `capability` declared, no `effect` binding references it | `"capability '${cap_name}' declared but has no effect...using binding"` |

Note: OOF-M3 (authority resolution for `privileged` contracts) is deferred to
PROP-034 which addresses the authority/executor approval surface.

---

## § 7. Conformance Fixtures

Two new source fixtures are added to `igniter-lang/source/`:

### `io_capability_basic.ig`

```igniter
module Proof.IOCapability.Basic

effect contract ConnectToService {
  capability net_conn: IO.NetworkCapability
  effect connect_to_service using net_conn
}
```

Expected classifier output: `fragment_class: "escape"`, no OOF entries, one
`capability` declaration and one `effect_binding` declaration.

### `io_capability_oof_blocked.ig`

```igniter
module Proof.IOCapability.OofBlocked

pure contract WrongModifier {
  capability bad_cap: IO.NetworkCapability
  effect connect_bad using bad_cap
}

effect contract MissingCap {
  effect orphan using nonexistent_cap
}

effect contract UnboundCap {
  capability unused_cap: IO.NetworkCapability
}
```

Expected classifier output: OOF-M2 on `WrongModifier`, OOF-M4 on `MissingCap`,
OOF-M5 on `UnboundCap`.

---

## § 8. Backward Compatibility

All existing `.ig` source files compile without modification. The new keywords
`capability` and `effect` (as body declarations) are additive. No existing body
declaration keyword is removed or modified.

The `effect` keyword was already reserved as a contract modifier in PROP-031; this
proposal adds it as a valid body-level declaration inside a contract body. There is
no syntactic ambiguity: the modifier is parsed before the `contract` keyword; the
body declaration is parsed inside `parse_body_decl`.

---

## § 9. Evidence Base

This proposal is supported by the LAB-STDLIB-NET proof chain (200 checks across P2–P5)
which proved the IO.NetworkCapability algebra, delegation semantics, safety policies,
and compiler diagnostic codes. The lab proofs establish the design invariants that
this grammar extension encodes at the compiler level.

| Lab card | Checks | Scope |
|---|---|---|
| LAB-STDLIB-NET-P2 | 53/53 | Schema, delegation algebra, safety policies |
| LAB-STDLIB-NET-P3 | 61/61 | FFI surface, stub mode, operation sequence |
| LAB-STDLIB-NET-P4 | 42/42 | Compiler escape classification, 10 E-NET-* codes |
| LAB-STDLIB-NET-P5 | 44/44 | Hardening: glob, direction:both, chains, bind-address |
| **Total** | **200/200** | |
