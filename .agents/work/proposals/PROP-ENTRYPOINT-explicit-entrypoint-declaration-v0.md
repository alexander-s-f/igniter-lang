# PROP-ENTRYPOINT - Explicit Entrypoint Declaration and igapp Manifest Binding

**Track:** explicit-entrypoint-declaration-and-igapp-manifest-binding-v0
**Route:** PROPOSAL AUTHORING ONLY
**Authority:** proposal text only
**Date:** 2026-06-11
**Status:** authored-pending-review
**Predecessors / evidence:**
- PROP-029 entrypoint/section surface draft
- LAB-LANGFORM-RESEARCH-P1 application-form readiness notes
- LAB-MULTIFILE-COMPILATION-P1 multi-file import proof
- LAB-RACK-P7 named CLI entry selector pressure

---

## Purpose

This proposal defines a narrow source-level declaration for the intended
starting contract of an Igniter compilation unit.

The core question is:

```text
How does an Igniter program declare "this is where execution starts" without
creating runtime authority or hiding the dependency graph?
```

Current tooling can select an entry contract by CLI convention, by explicit
tool flag, or by falling back to the first contract in a source/manifest list.
That behavior is useful as compatibility policy, but it is not language-visible
structure. It becomes less honest as multi-file compilation makes declaration
order and file order less meaningful.

This proposal names the entrypoint explicitly while preserving the existing
contract graph. An entrypoint is a selector over an existing contract. It is not
a scheduler, app route, process main loop, capability grant, or hidden root.

---

## Non-Goals

This proposal does not authorize:

- parser implementation;
- compiler implementation;
- VM/runtime implementation;
- CLI behavior changes;
- app framework or service model;
- public/internal visibility;
- module section/grouping grammar;
- package system;
- runtime scheduling semantics;
- capability authority;
- live debugger stepping;
- stable/public API claims.

This proposal intentionally narrows the entrypoint portion of PROP-029 and does
not carry forward PROP-029's `section` surface.

---

## Decision Summary

**Recommendation:** add a top-level declaration:

```igniter
entrypoint ContractName
```

For a multi-file compilation unit, the target may be module-qualified:

```igniter
entrypoint Billing.Invoice.RunInvoice
```

v0 cardinality:

- a compilation unit may declare zero or one default entrypoint;
- zero is allowed for library modules and compatibility-mode tooling;
- more than one default entrypoint is a diagnostic;
- named multi-entrypoint sets are deferred.

Meaning:

- the entrypoint names the intended starting contract;
- it does not define a contract;
- it does not change dependency analysis;
- it does not change fragment classification;
- it does not grant authority;
- it does not hide inputs, outputs, effects, or callees.

---

## Syntax Shape Decision

### Candidate A: top-level `entrypoint ContractName`

Example:

```igniter
module Billing.Invoice

entrypoint RunInvoice

pure contract RunInvoice {
  input invoice_id: String
  output result: InvoiceResult
}
```

Disposition: **accepted for v0**.

Reasons:

- smallest source-visible form;
- declares the start target without adding a new block language;
- does not duplicate contract inputs/outputs;
- works in single-file sources;
- can extend to module-qualified names for multi-file units;
- has clear manifest binding;
- keeps graph structure visible on the target contract.

### Candidate B: module-level metadata

Example:

```igniter
module Billing.Invoice {
  entrypoint: RunInvoice
}
```

Disposition: rejected for v0.

Reasons:

- current module syntax is not a metadata block;
- module metadata would entangle entrypoint with future module attributes;
- multi-file units may contain several modules, so the unit-level default would
  be ambiguous unless this proposal also defines module aggregation policy.

### Candidate C: contract modifier

Example:

```igniter
entrypoint pure contract RunInvoice {
  ...
}
```

Disposition: rejected for v0.

Reasons:

- conflates "what this contract is" with "which contract a runner should start";
- makes it harder for tools to change the default selector without changing a
  contract declaration line;
- risks implying fragment or runtime semantics.

### Candidate D: manifest-only declaration

Example:

```json
{
  "entrypoint": "Billing.Invoice.RunInvoice"
}
```

Disposition: rejected as the source language declaration.

Reasons:

- useful as compiled artifact metadata, but invisible in source;
- would preserve the current problem for authors and IDEs;
- makes source-to-manifest drift possible unless source has an authoritative
  declaration to bind.

Manifest binding is still required, but it is derived from source, not the only
place the entrypoint exists.

---

## Grammar Target

This is a proposal target only. No parser change is authorized by P1.

```text
TopDecl        := EntryPointDecl | existing_top_decl
EntryPointDecl := "entrypoint" QualifiedContractName

QualifiedContractName := Name ("." Name)*
```

Keyword policy:

- `entrypoint` should be contextual at top-level declaration position;
- this proposal does not require reserving `entrypoint` as an ordinary
  identifier everywhere;
- contract names and module path segments retain their existing naming rules.

---

## Cardinality

### Compilation unit rule

For v0, a compilation unit may contain:

- zero entrypoint declarations; or
- one default entrypoint declaration.

Multiple declarations are rejected, even if they reference the same contract.
This avoids hidden conflict between files and keeps the manifest field singular.

### Library modules

Zero entrypoint declarations are valid for library-like modules and shared
source units. A tool mode that requires a runnable target may reject such a unit
with a tool-mode diagnostic. The language declaration itself remains optional.

### Deferred: named multi-entrypoints

Future syntax may allow named entrypoints:

```igniter
-- Deferred only; not v0.
entrypoint smoke: SmokeTest
entrypoint main: Billing.Invoice.RunInvoice
```

That surface is not part of v0. It requires separate naming, CLI selection,
manifest schema, and ambiguity rules.

---

## Scope

### Single-file today

In a single-file compilation unit, an unqualified entrypoint name resolves
against contracts declared in the file's module/program scope.

Example:

```igniter
entrypoint Start
```

### Multi-file compilation unit later

In a multi-file compilation unit, the entrypoint belongs to the logical
compilation unit, not to one input file by order. The manifest records the
resolved target, including module path when available.

Recommended v0 resolution:

- module-qualified entrypoint names resolve exactly;
- unqualified names are accepted only if exactly one contract with that name is
  present in the compilation unit;
- if two modules declare the same contract name, an unqualified entrypoint is
  ambiguous and fails closed.

This proposal does not define import semantics. It only states how an entrypoint
references the contract set that a compiler has already resolved.

---

## Manifest Binding

When present, the source declaration is recorded in `.igapp/manifest.json`.

Recommended manifest shape:

```json
{
  "kind": "igapp_manifest",
  "entrypoint": {
    "kind": "default_entrypoint",
    "declared_name": "RunInvoice",
    "resolved_contract": "Billing.Invoice.RunInvoice",
    "contract_ref": "contracts/RunInvoice.json"
  }
}
```

If no entrypoint is declared, omit `manifest.entrypoint` or set it to `null`
according to the existing manifest compatibility policy chosen by the
implementation route. P1 does not choose that serialization detail.

### Hash impact

Entrypoint declaration changes artifact identity.

- `source_hash`: changes because source text changes.
- `artifact_hash`: changes because manifest content changes.
- `behavior_hash`: should not change solely because the selected start contract
  changes, if behavior hash is defined as contract/body semantics.

If a future behavior hash includes runner target policy, it must use a distinct
name such as `run_profile_hash`; this proposal does not define one.

### Manifest authority

`manifest.entrypoint` is compiled evidence of the source declaration. It is not
runtime authority. A runner still needs whatever execution/capability policy is
required to run the target contract.

---

## Type and Fragment Constraints

An entrypoint may reference any supported contract fragment:

- `pure`;
- `observed`;
- `effect`;
- `privileged`;
- `irreversible`;
- future fragment classes if accepted elsewhere.

The entrypoint does not make an effect contract runnable by itself. It only names
the target. Existing capability, profile, loader, and runtime policies still
apply.

For v0, the entrypoint target must be a contract, not a type, function, module,
profile, section, or external host symbol.

Input satisfiability is a runner/tool concern:

- the compiler can record target input names/types in the existing contract
  index;
- a CLI/debugger/tool may require all inputs to be supplied before execution;
- the entrypoint declaration itself does not provide input defaults or sample
  args.

This is the key narrowing from PROP-029: v0 entrypoint is a target selector, not
a fixture/run profile.

---

## Diagnostics

Candidate diagnostics are reserved for a future implementation route. Names are
not active OOF codes in P1.

| Code | Trigger | Notes |
|------|---------|-------|
| OOF-EP1 | duplicate entrypoint declarations in one compilation unit | More than one default entrypoint |
| OOF-EP2 | unknown entrypoint contract | No resolved contract matches |
| OOF-EP3 | missing entrypoint when required by tool mode | Tool/runner mode diagnostic, not ordinary library compile failure |
| OOF-EP4 | ambiguous unqualified entrypoint in multi-file context | Use module-qualified name |
| OOF-EP5 | entrypoint points to unsupported declaration kind | Target is not a contract |
| OOF-EP6 | entrypoint target unsupported by selected runner | Runner cannot execute that fragment/kind |

Diagnostic law:

- duplicate/unknown/ambiguous declarations fail closed;
- a library module without an entrypoint may compile;
- tool modes that require a runnable target may refuse missing entrypoint
  separately from language parsing.

---

## CLI Relationship

The language declaration and runner policy are separate.

Recommended policy:

- `igc compile` may compile sources with zero or one entrypoint;
- `igc run` may use the declared entrypoint when exactly one exists;
- `igc run --entry Name` may override or select a target according to runner
  policy;
- if no entrypoint exists, existing `contracts[0]` behavior may remain as
  compatibility mode, but it should be labeled compatibility behavior, not
  language semantics.

Future named entrypoints may let `--entry smoke` select a named profile, but v0
does not define named multi-entrypoints.

---

## Debugger and IDE Relationship

Explicit entrypoint improves tool setup:

- the IDE can show the intended start contract;
- trace/session setup can preselect the contract;
- debugger UI can distinguish "program default" from arbitrary contract
  inspection;
- `.igapp` consumers can display the intended target without guessing.

This does not authorize:

- live stepping;
- breakpoints;
- debugger protocol;
- runtime execution;
- host IO;
- capability grants.

The dependency graph remains visible through existing contract inputs, computes,
outputs, effects, and call edges. Entrypoint is a pointer into that graph, not a
hidden root node.

---

## Relationship to Imports and Multi-File

Entrypoint is useful before import resolution because it removes `contracts[0]`
guessing in a single source file.

After multi-file/import work, module-qualified names become important:

```igniter
entrypoint Billing.Invoice.RunInvoice
```

This proposal depends on the compiler having a resolved contract universe. It
does not define:

- import syntax;
- import resolution;
- package lookup;
- visibility;
- export/public/internal;
- distribution;
- stdlib-as-import.

PROP-IMPORT-RESOLUTION-P1 can proceed in parallel. If import resolution changes
the final qualified-name model, a P2 implementation plan for entrypoints should
adapt to that model before parser/manifest work begins.

---

## Relationship to PROP-029

PROP-029 proposed two surfaces:

- `entrypoint` as a richer named evaluation/run profile;
- `section` as grouping-only source organization.

This proposal intentionally narrows that shape:

- v0 entrypoint is only a default target selector;
- no `args` block;
- no `output` field;
- no named entrypoint profiles;
- no `section`;
- no grouping grammar.

PROP-029 remains historical design input. This proposal is the recommended
narrow route for an explicit entrypoint declaration.

---

## Closed Surfaces

Closed in P1:

- no `section`;
- no `component`;
- no app framework;
- no application manifest beyond an entrypoint field;
- no public/internal visibility;
- no package system;
- no module grouping grammar;
- no scheduler/main loop;
- no service/daemon model;
- no route/controller model;
- no input defaults or fixture args;
- no output narrowing;
- no named multi-entrypoints;
- no runtime/capability authority;
- no parser/compiler/VM implementation;
- no public/stable API claim.

---

## Implementation Route

If accepted, the next route is:

```text
PROP-ENTRYPOINT-P2 - parser/manifest implementation planning
```

P2 should be planning-only unless explicitly authorized otherwise. It should:

- decide exact AST shape;
- decide manifest null/omission compatibility;
- map diagnostics to current parser/typechecker phases;
- define regression fixtures;
- verify interaction with import-resolution qualified names.

Alternative route:

```text
Defer until PROP-IMPORT-RESOLUTION progresses if qualified-name semantics are
not stable enough for parser/manifest planning.
```

No implementation authority is opened by P1.

---

## Acceptance Checklist

- Syntax recommendation chosen: top-level `entrypoint ContractName`.
- Cardinality explicit: zero or one default entrypoint.
- Manifest impact explicit: source/manifest/artifact identity changes;
  behavior hash should not change solely from target selection.
- CLI interaction explicit: declaration separate from runner policy.
- Debugger/IDE interaction explicit: setup aid, not live stepping authority.
- Multi-file interaction acknowledged: module-qualified target names required
  once qualified names are stable.
- Closed surfaces explicit.
