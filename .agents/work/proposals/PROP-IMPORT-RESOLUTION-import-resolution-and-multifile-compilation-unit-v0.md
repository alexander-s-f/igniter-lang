# PROP-IMPORT-RESOLUTION: Import Resolution and Multi-File Compilation Unit Semantics

**Track:** import-resolution-and-multifile-compilation-unit-semantics-v0
**Route:** PROPOSAL AUTHORING ONLY
**Authority:** proposal text only
**Date:** 2026-06-11
**Status:** DRAFT - authored by PROP-IMPORT-RESOLUTION-P1
**Grounding Evidence:** LANG-MODULE-IDENTITY-P1/P2; LAB-MULTIFILE-COMPILATION-P1

---

## Purpose

This proposal defines what `import` means in Igniter v0:

```text
import = compile-time name resolution only
```

Import lets one source unit refer to named declarations from another module in
the same logical compilation unit. It does not load code at runtime, authorize
effects, bind profiles, grant package trust, or create public API stability.

The smallest useful semantic target is:

```text
N .ig source files
-> one logical compilation universe
-> one .igapp artifact
```

with deterministic multi-file identity, fail-closed import diagnostics, and no
new runtime authority.

---

## 1. Authority Boundary

This is proposal authoring only.

This proposal authorizes no implementation:

- no parser changes
- no compiler driver changes
- no classifier changes
- no typechecker changes
- no SemanticIR changes
- no VM changes
- no runtime loading
- no package registry
- no semver or distribution system
- no trust store
- no public/internal visibility
- no export list
- no stdlib-as-import promotion
- no capability import or capability binding
- no profile binding through import
- no public/stable API claim

Lab proofs are evidence, not canon authority. This proposal may cite
LAB-MULTIFILE-COMPILATION-P1 as evidence that the shape is viable, but the lab
driver does not itself create canon semantics.

---

## 2. Current State

Igniter already has source-level `module` and `import` grammar inherited from
the grammar/module surface. The grammar is not enough: current import handling
is semantically inert in the active compilation path.

Observed current state:

- `module` can be parsed as a label.
- `import` can be parsed.
- imported names are not resolved by the active compiler pipeline.
- unknown imports may fail to produce a useful module diagnostic.
- module names are labels until a multi-file resolver builds a module table.
- cross-file reuse is therefore simulated today by copy-pasting type/record
  declarations in independent proof files.

Existing diagnostic vocabulary already points at the gap:

- `OOF-P3` in older parser/classifier planning names cross-module reference
  without import as a classifier-owned rule.
- `OOF-M1` and `OOF-M2` have been reserved in module/import planning.
- LAB-MULTIFILE-COMPILATION-P1 showed viable boundaries for `OOF-M1`,
  `OOF-M2`, and `OOF-M3`.

This proposal does not reopen older broad module-system claims such as package
distribution, stdlib pre-import, public/internal visibility, or module fragment
authority. P1 defines only the import-resolution substrate.

---

## 3. Multi-File Compilation Unit

### Definition

A multi-file compilation unit is a bounded set of N `.ig` source files compiled
as one logical universe.

The unit has:

- source units: the input files and their raw source text;
- modules: named scopes declared by source units;
- declarations: contracts, record/type declarations, and other top-level
  declarations supported by the language at that stage;
- a module table: `ModulePath -> SourceUnit`;
- a resolved import graph;
- one emitted `.igapp` artifact.

### Source Units

Each source unit contributes at most one module declaration in v0. A future
implementation may decide how to handle missing module declarations, but the
import resolver must not treat the file path alone as module authority.

Source-unit ordering is canonicalized for identity and compilation planning.
Input file order must not affect successful output.

Recommended canonical ordering:

```text
sort by module path, then by canonical source path as tie-breaker
```

Duplicate module declarations are fail-closed before tie-breaker behavior can
create ambiguous authority.

### Module Table Construction

The compiler driver builds the module table before classifier/typechecker
resolution:

1. Parse all source units enough to read module declarations and imports.
2. Build `ModulePath -> SourceUnit`.
3. Reject duplicate module paths.
4. Resolve import graph.
5. Reject unknown imports.
6. Reject circular imports.
7. Build the merged logical universe for classifier/typechecker/SemanticIR.

### One Artifact

A successful multi-file compilation unit emits one `.igapp` artifact for the
whole universe.

`contract_ref` remains per-contract. It is not replaced by module identity.

`artifact_hash` remains the final artifact identity. It is not replaced by
`source_hash`, module path, pass-local `program_id`, or package identity.

---

## 4. Import Semantics

### Whole-Module Import

Whole-module import imports the named module into the current source unit's
compile-time resolution environment.

Example:

```text
import Lab.Query.Types
```

Names declared by `Lab.Query.Types` become resolvable from the importing module
according to the implementation's v0 name lookup rule. P1 does not require
runtime namespace objects or module values.

### Selective Import

Selective import imports explicitly named declarations from a module.

Example:

```text
import Lab.Query.Types.{ QueryResult, FilterPredicate }
```

The imported names must exist in the target module. Missing imported names fail
closed as an unknown import/name-resolution diagnostic.

### Resolution Timing

Imports resolve at compile time before typechecking a consumer declaration that
uses imported names.

The resolver must be deterministic:

- import declaration order in a source file must not affect the resolved set;
- input file order must not affect the resolved set;
- diagnostics must identify the module/import path that failed.

### Symbol Visibility Inside the Compilation Unit

In P1, import controls compile-time name availability only. Public/internal
visibility is not defined here.

Within the logical compilation unit:

- a source unit always sees its own declarations;
- a source unit sees imported declarations according to whole-module or
  selective import rules;
- a source unit must not silently see arbitrary declarations from sibling
  modules without import.

### No Runtime Loading

Import is not runtime loading. It does not create dynamic imports, late-bound
module lookup, plugin loading, package fetch, or VM loader behavior.

No dynamic imports are defined in this proposal.

---

## 5. Diagnostics

Import and module diagnostics must fail closed. A compiler must not silently
drop a missing module, treat it as an empty module, or continue with ambiguous
module identity.

### OOF-M1: Circular Import

`OOF-M1` is raised when the module import graph contains a cycle.

Diagnostic payload should include:

- diagnostic code: `OOF-M1`
- source file
- current module path
- cycle path, if available
- import path that completed or exposed the cycle

### OOF-M2: Unknown Import

`OOF-M2` is raised when an import path cannot be resolved.

It covers:

- unknown module path;
- selective import of a missing declaration from a known module.

Diagnostic payload should include:

- diagnostic code: `OOF-M2`
- source file
- current module path
- import path
- missing name, when the module exists but a selective name is missing

### OOF-M3: Duplicate Module Declaration

`OOF-M3` is raised when two or more source units declare the same module path in
one compilation unit.

Diagnostic payload should include:

- diagnostic code: `OOF-M3`
- duplicate module path
- all source files that declared it, or at least both conflicting files

### Duplicate Contract/Type Across Universe

Duplicate declaration behavior must be fail-closed before public visibility or
overload rules exist.

P1 recommends:

- duplicate contract names in the same effective resolution universe fail
  closed;
- duplicate record/type names in the same effective resolution universe fail
  closed;
- diagnostics include declaration name, declaration kind, source file, and
  module path.

The exact final diagnostic codes for duplicate contract/type names may be
assigned by the future implementation card. They must not collapse into
successful shadowing in v0.

---

## 6. Identity Rules

LANG-MODULE-IDENTITY-P2 closed the C1 identity blocker by aligning Rust lab
pass-local `program_id` generation to the SHA256 seed contract used by Ruby.

The identities remain distinct:

- `source_hash`: raw source identity;
- `classifier_pass/*`: pass-local classifier identity;
- `typed_pass/*`: pass-local typechecker identity;
- `semanticir/*`: SemanticIR reference;
- `compilation_report/*`: report reference;
- `contract_ref`: per-contract identity;
- `artifact_hash`: final artifact identity;
- `compiler_profile_id`: compiler profile identity.

Multi-file compilation needs a multi-file `source_hash` rule.

Recommended rule:

```text
source_hash = sha256(canonical_json([
  { module, source_hash, source },
  ...
] sorted by module path))
```

Where:

- each source unit contributes raw source text and its single-file raw
  `source_hash`;
- entries are sorted canonically, not by user-provided file order;
- module name is included as label material, not as sole identity;
- duplicate modules fail before the canonical list is accepted.

Consequences:

- file input order must not affect identity;
- changing one file changes multi-file `source_hash`;
- comment-only changes affect raw-source identity unless a future
  `semantic_hash` exists;
- module name is not content identity;
- `source_hash` does not replace `artifact_hash`;
- `contract_ref` remains per-contract.

---

## 7. Capability Boundary

Import does not confer capability authority.

Required rules:

- importing an effect contract does not make it callable from a pure consumer;
- imported declarations do not import their capability bindings into the
  consumer;
- capability/profile binding remains consumer-side and explicit;
- import cannot smuggle authority through a module boundary;
- package trust, if it exists later, is a separate authority surface;
- runtime execution permission is not derived from import.

This preserves the existing authority model:

```text
name availability != authority to execute
```

If a consumer calls an imported declaration whose fragment/effect requirements
exceed the consumer context, the existing classifier/typechecker/effect gates
must reject or require explicit authorized binding according to the relevant
proposal. Import itself never satisfies that requirement.

---

## 8. Relationship To Packages

Package semantics are not required for import P1.

Import resolution can exist entirely inside one explicit compilation unit before
any registry, distribution, semver, trust store, or package manager exists.

Future package semantics should be treated as sealed claims, not code drops.
A package may later supply a sealed set of source units or artifacts plus trust
metadata. That future work must not rewrite P1 import into implicit package
authority.

Deferred:

- package registry
- semver
- distribution
- trust store
- remote fetch
- dependency solver
- package lockfile
- package-level capability grants

---

## 9. Relationship To Stdlib

Stdlib-as-import is enabled later by this substrate, but not promoted here.

This proposal does not add, bless, or stabilize stdlib contents. Numeric stdlib
work remains separate. Any future stdlib import route must say:

- which stdlib modules exist;
- whether they are implicit or explicit;
- how stdlib source/artifact identity is represented;
- what compatibility and trust rules apply;
- whether stdlib names are ordinary imports or a special prelude.

Until then, this proposal defines only ordinary compile-time import resolution
inside an explicit compilation unit.

---

## 10. Relationship To Visibility

Public/internal visibility is deferred.

Import resolution is a prerequisite for meaningful visibility, but it does not
define visibility by itself.

This proposal does not define:

- `public`
- `internal`
- `private`
- export lists
- sealed interfaces
- module interface hashes
- package-visible names

Future visibility work may build on this import substrate by deciding which
declarations are importable and which are implementation-local.

---

## 11. Acceptance / Future Implementation Plan

This P1 is accepted as authored when:

- import is clearly defined as compile-time name resolution only;
- multi-file compilation unit semantics are specified;
- OOF-M1, OOF-M2, and OOF-M3 are specified;
- multi-file identity rule is specified;
- authority boundaries are explicit;
- package, stdlib, and visibility surfaces remain deferred;
- future implementation route is concrete.

Future implementation path:

1. `PROP-IMPORT-RESOLUTION-P2` or equivalent planning card:
   - confirm parser sufficiency;
   - define exact AST fields consumed by the resolver;
   - define implementation-owned diagnostic codes for duplicate contract/type
     names if needed.
2. Compiler driver:
   - accept N input files for one compilation unit;
   - build source-unit inventory;
   - compute canonical multi-file `source_hash`.
3. Resolver:
   - build module table;
   - resolve whole-module and selective imports;
   - reject unknown imports, cycles, and duplicate modules.
4. Classifier/typechecker:
   - operate over the merged logical universe;
   - preserve consumer-side authority/capability checks.
5. SemanticIR/artifact emission:
   - emit one `.igapp`;
   - preserve per-contract `contract_ref`;
   - preserve final `artifact_hash`.
6. Proof matrix:
   - mirror LAB-MULTIFILE-COMPILATION-P1;
   - include at least three valid multi-file fixtures;
   - include unknown import, circular import, duplicate module, duplicate
     contract/type, and authority-smuggling negative cases;
   - prove file-order determinism.

Recommended next route:

```text
PROP-IMPORT-RESOLUTION-P2
```

or a supervised implementation-planning card if governance chooses to move from
proposal text into bounded implementation.

Parallel route:

```text
PROP-ENTRYPOINT-P1
```

Visibility remains deferred until import/multi-file semantics are implemented
or explicitly planned.

---

## Decision Output

PROP-IMPORT-RESOLUTION-P1 authors the canon proposal text for import resolution
and multi-file compilation-unit semantics.

Implementation remains explicitly closed.
