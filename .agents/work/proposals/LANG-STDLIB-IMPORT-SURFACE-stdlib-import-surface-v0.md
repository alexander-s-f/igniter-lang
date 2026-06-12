# LANG-STDLIB-IMPORT-SURFACE: Stdlib Import Surface v0

**Track:** lang / stdlib / import-surface
**Route:** PROPOSAL AUTHORING ONLY / BOUNDARY DESIGN
**Authority:** proposal text only — no implementation
**Date:** 2026-06-12
**Status:** authored — pending review
**Lineage:** PROP-IMPORT-RESOLUTION-P5 (P5 closed with stdlib-as-import explicitly deferred);
LANG-STDLIB-ENTRY-CONTRACT-P3 (24-entry inventory live; stdlib_surface_digest proved);
Advanced-Logistics AL-P01 / Vector-Editor VE-P01 (both blocked on OOF-IMP2 stdlib.collection)

---

## Problem Statement

Both `advanced_logistics/router.ig` and `vector_editor/document.ig` carry
`import stdlib.collection.{ … }` declarations:

```text
# router.ig (advanced_logistics)
import stdlib.collection.{ filter }

# document.ig (vector_editor)
import stdlib.collection.{ append, map }
```

Both Rust and Ruby emit `OOF-IMP2 unknown import path 'stdlib.collection'`.

The root cause: PROP-IMPORT-RESOLUTION-P5's `MultifileResolver` builds a module
table from source-file `module` declarations. `stdlib.collection` has no source
file and no user-declared `module stdlib.collection`. The resolver correctly
rejects it as an unknown module.

PROP-IMPORT-RESOLUTION-P1 §9 lists "stdlib-as-import" as explicitly deferred.
P5's §9 (Known Limits) repeats: "stdlib-as-import" is not implemented.

This proposal defines **where the boundary sits** for stdlib import resolution:
what it means, what it does, what it does NOT do, and what diagnostics apply.
It closes none of those surfaces itself — implementation is separately
authorized after this proposal is accepted.

---

## 1. Authority Boundary

This is proposal text and boundary design only.

This proposal authorizes no implementation:

- no parser changes
- no compiler driver changes (MultifileResolver, CompilerOrchestrator)
- no classifier or typechecker changes
- no SemanticIR or assembler changes
- no VM or runtime changes
- no stdlib-inventory.json edits
- no new OOF codes (OOF-IMP2/OOF-IMP3 reuse is decided here; no new codes are opened)
- no package registry, trust store, or distribution system
- no capability/profile authority surface
- no public/stable API claim
- no runtime loading or dynamic imports
- no stdlib visibility or export system

Lab proofs (AL-P02 probes, VE probe) are pressure evidence. This proposal may
cite them as evidence that the shape is viable. They do not create canon
authority.

---

## 2. The Six Boundary Questions

### Q1 — Resolution Mechanism: compiler profile, built-in module table, or package-like sealed claim?

**Answer: built-in stdlib module table — a pre-populated table keyed on stdlib
module path prefixes, consulted as a privileged tier before user module
resolution.**

The three candidates and why the first is correct:

**Built-in module table (ACCEPTED).**
The resolver holds an additional table: `StdlibModulePath → Set[SourceAliasName]`.
Entries are derived from `stdlib-inventory.json` — the `canonical_name` hierarchy
(`stdlib.collection.*`) defines the module path; each entry's `source_alias`
entries define the importable names.

```text
stdlib.collection  →  { map, filter, count, sum, fold }   (from inventory)
stdlib.text        →  { concat, contains, starts_with, … }
stdlib.map         →  { map_get, map_has_key, map_empty, map_from_pairs }
stdlib.option      →  { or_else }
…
```

The resolver consults this table when it encounters an `import` path that starts
with `stdlib.`. If the path is found, it is a known stdlib module; if a selected
name is found in that module's set, the import is valid. The resolver then
clears the import declaration (identical to how P5 clears user-module imports
after merge) — stdlib imports are resolved and consumed at compile time.

This mechanism is NOT:

**Compiler profile (REJECTED for resolution).**
The compiler profile (PROP-036/038) is the authority boundary for compiler
behavior and capability context — not a name-resolution table. Stdlib name
availability is not a profile policy: a name is importable if it exists in the
inventory, regardless of profile. Profile may later pin the `stdlib_surface_digest`
to freeze the available surface (see Q4), but that is profile-as-identity-anchor,
not profile-as-resolver.

**Package-like sealed claim (REJECTED for v0).**
Package semantics (PROP-IMPORT-RESOLUTION-P1 §8) require a registry, trust store,
distribution system, and semver. LANG-STDLIB-ENTRY-CONTRACT §11 notes that a
future self-hosting direction *may* represent stdlib as a compiler-owned
first-party package, but explicitly writes: "The entry contract is written to
survive that transition — only the trust position would change." v0 stdlib
import uses the compiler's built-in table, not a package acquisition path.

**Key consequence of the built-in table model:**
A user source file may not declare `module stdlib.collection` or any `stdlib.*`
module name. Such a declaration would collide with the built-in table and must
be rejected by the resolver with a dedicated diagnostic (candidate:
`OOF-IMP-STDLIB-SHADOW` — reserved for P2 implementation planning; exact code
and handling are a P2 decision). The stdlib namespace prefix `stdlib.` is
sealed to the compiler.

---

### Q2 — Does `import stdlib.collection.{ map }` only expose source aliases?

**Answer: yes.**

`import stdlib.collection.{ map }` makes the short name `map` available as a
source-level name in the importing module. It does not:

- introduce a new dispatch arm in the TypeChecker
- change what the TypeChecker already dispatches on
- change any runtime behavior

The name `map` is already a `source_alias` in `stdlib.collection.map`'s
inventory entry. The TypeChecker's `COLLECTION_HOF_FNS` constant already
dispatches on `"map"` as a key. The import statement is a **declaration** that
the source file intends to use the `map` alias — it validates the alias exists
in the named module and then clears itself.

After resolution, the merged logical universe's TypeChecker sees the same
source alias it already handles. No new source spelling is created. The import
is an integrity check + intent declaration, not a binding injection.

**Whole-module import** (`import stdlib.collection`) makes ALL importable names
for that module available — all inventory entries whose `canonical_name` starts
with `stdlib.collection.` and whose `source_alias` entries exist. Semantics
are consistent with PROP-IMPORT-RESOLUTION-P1 §4.1 whole-module import.

**No import required for stdlib aliases in v0.** This is a deliberate design
gap acknowledged here: the current TypeChecker already dispatches on bare `map`,
`filter`, `count`, `sum`, `fold` without any import statement. The import
surface is being defined so that:
- app source files that *do* write `import stdlib.collection.{ map }` compile
  cleanly instead of emitting OOF-IMP2
- future enforcement (requiring explicit import before use) is a separate
  authorization, not opened by this proposal

This "import validates, not gates" position is the v0 stance. Gating bare-alias
use on explicit import would be a visibility/enforcement change requiring a
separate proposal.

---

### Q3 — Does stdlib import affect capability authority?

**Answer: NO.**

Import is compile-time name resolution only. This is the same rule as
PROP-IMPORT-RESOLUTION-P1 §7:

> name availability ≠ authority to execute

Stdlib entries with `authority_surface: "none"` (all current collection, text,
map, option, outcome entries) grant no authority when imported. Importing a name
does not:

- change the contract's fragment class (CORE entries remain CORE)
- satisfy a capability requirement
- inject a profile binding
- widen or grant any authority surface
- create any runtime execution permission

For the (currently closed) effectful/ESCAPE-tier stdlib entries
(`authority_surface: "capability: <Type>"` — e.g., future IO entries), the
same rule applies in the inverted direction: importing an effectful stdlib name
does not grant the capability to call it. A consumer contract must still declare
the capability explicitly and have it validated by the classifier/typechecker.
Import makes the name available; it does not satisfy the effect gate.

**This preserves the existing authority model in full.** The compiler does not
change its capability, profile, or fragment-class behavior because of a stdlib
import declaration.

---

### Q4 — Relationship to stdlib_surface_digest

**Answer: the built-in stdlib module table is derived from the same inventory
that defines stdlib_surface_digest; the digest is the identity anchor for what
is importable.**

LANG-STDLIB-ENTRY-CONTRACT §9 defines:

```text
stdlib_surface_digest = sha256(canonical_json(sorted entries by canonical_name))
```

The built-in stdlib module table is a **derived view** of the inventory:
- `canonical_name` hierarchy → module path keys (`stdlib.collection`, etc.)
- `aliases[].name` where `kind == "source_alias"` → importable short names for each module

This derivation means: the set of importable stdlib module paths and names is
exactly the set representable by the current inventory surface. An entry present
in the inventory with a `source_alias` is importable via that alias; an entry
absent from the inventory is not importable (OOF-IMP3).

**Profile pinning (future, not opened here):** PROP-036/038 define a
`compiler_profile` slot. When a future profile-pinning card is authorized, the
`stdlib_surface_digest` can be recorded in the compiler profile to freeze the
importable surface at a known inventory snapshot. Import resolution would then
validate the built-in table against the pinned digest. This is designed-for but
not authorized here.

**Consequence for inventory growth:** adding a new stdlib entry to the inventory
changes the `stdlib_surface_digest` AND makes a new name importable. This is
intentional — the digest is the identity surface, and changes to it are visible.

**Consequence for orphaned entries:** inventory entries with `status: orphaned`
(e.g., `stdlib.bool.and`, `stdlib.collection.concat`) exist in the inventory
but may not have usable `source_alias` entries. Whether orphaned entries are
importable is a P2 implementation decision. The conservative default: only
entries with at least one `source_alias` of `kind: "source_alias"` are importable.

---

### Q5 — Diagnostics for unknown stdlib module / unknown stdlib name

**Answer: reuse OOF-IMP2 for unknown stdlib module path; reuse OOF-IMP3 for
known stdlib module, unknown name. No new OOF codes.**

P2A (PROP-IMPORT-RESOLUTION-P2A) reserved `OOF-IMP*` for all import/module
resolution diagnostics. The stdlib import surface is a species of import
resolution — the same codes apply:

| Failure | Code | Example |
|---------|------|---------|
| Stdlib module path not in built-in table | `OOF-IMP2` | `import stdlib.bogus.{ foo }` → OOF-IMP2 "unknown stdlib module: stdlib.bogus" |
| Stdlib module known, selected name not in inventory | `OOF-IMP3` | `import stdlib.collection.{ append }` → OOF-IMP3 "unknown name 'append' in stdlib.collection" |
| Stdlib namespace shadow (user declares `module stdlib.X`) | Reserved `OOF-IMP*` candidate | P2 decision on exact code and payload; documented here as a required guard |

**Specific note on `append`:** `stdlib.collection.append` is NOT in the current
inventory (LANG-STDLIB-ENTRY-CONTRACT-P3 has 26 entries; collection has
`count`, `map`, `filter`, `concat`; no `append`). `import stdlib.collection.{ append }`
would produce OOF-IMP3 until an `append` entry is added to the inventory.
VE-P02 is the pressure to add `append` — routing to `LANG-STDLIB-COLLECTION-APPEND-P1`.

**Payload requirements** (same as P5):
- `source_path` — the file containing the import
- `module_path` — the stdlib module path attempted
- `import_path` — the full import expression
- `missing_name` — for OOF-IMP3, the name not found

**Existing OOF-IMP2 emitted by apps today:** both apps currently produce
`OOF-IMP2 unknown import path 'stdlib.collection'` because the resolver has no
built-in table and rejects `stdlib.collection` as an unknown user module. After
this proposal is implemented, valid stdlib imports produce no diagnostic;
truly unknown stdlib paths still produce OOF-IMP2 (consistent payload).

---

### Q6 — Does stdlib import change SIR names?

**Answer: NO. Canonical SIR names stay qualified. Import changes nothing in SIR.**

The canonical SIR names are already fully qualified:

```text
stdlib.collection.map      (COLLECTION_HOF_FNS, Ruby TC + Rust TC after P4)
stdlib.collection.filter
stdlib.collection.count
stdlib.collection.sum
stdlib.collection.fold
stdlib.text.concat
stdlib.map.get
…
```

LANG-STDLIB-ENTRY-CONTRACT §4 mandates: `semantic_ir_name MUST equal canonical_name`.
The TypeChecker dispatch tables (COLLECTION_HOF_FNS, TEXT_STDLIB_FNS,
MAP_STDLIB_FNS, OUTCOME_STDLIB_FNS) already map source aliases to canonical
qualified names in SIR. The `generic semantic_expr` path preserves the `fn`
field verbatim (proved across all collection P3/P4 cards).

Stdlib import is resolved and cleared before classification/typechecking runs.
The TypeChecker never sees the import declaration — it sees source aliases
(`map`, `filter`, etc.) in function call positions, dispatches them to qualified
canonical names in SIR, and the import is gone.

**There is nothing for import to change in SIR.** SIR canonical name discipline
is an entry contract rule, not an import rule.

---

## 3. What This Proposal Does and Does Not Authorize

### Authorized by this proposal (design decisions only, no code):

- Built-in stdlib module table as the resolution mechanism (Q1)
- Source-alias-only exposure on `import stdlib.module.{ name }` (Q2)
- No capability authority through import (Q3)
- stdlib_surface_digest as the identity anchor for the importable surface (Q4)
- OOF-IMP2 / OOF-IMP3 reuse for stdlib diagnostics; stdlib namespace shadow
  guard reserved for P2 (Q5)
- SIR names unchanged by import (Q6)
- `stdlib.*` namespace sealed to the compiler (user cannot declare
  `module stdlib.X`)

### Explicitly NOT authorized:

- Any compiler code change
- MultifileResolver changes
- stdlib-inventory.json edits
- New OOF codes
- Gating bare-alias use on explicit import (visibility enforcement is future work)
- Whole-module import without selective names (policy decision for P2)
- Package acquisition path for stdlib
- Profile-pinning implementation for stdlib_surface_digest (future PROP-036/038 extension)
- `stdlib.collection.append` introduction (VE-P02 → LANG-STDLIB-COLLECTION-APPEND-P1)
- Runtime loading, dynamic imports, late-bound stdlib lookup
- Import ordering or priority when both user module and stdlib have the same
  source alias (collision policy is a P2 decision)

---

## 4. Pressure Evidence

| App | File | Import statement | Current diagnostic | Route |
|-----|------|------------------|--------------------|-------|
| advanced_logistics | router.ig:4 | `import stdlib.collection.{ filter }` | OOF-IMP2 | This proposal → P2 |
| vector_editor | document.ig:3 | `import stdlib.collection.{ append, map }` | OOF-IMP2 | This proposal → P2 (map); LANG-STDLIB-COLLECTION-APPEND-P1 (append) |

AL-P02 probe (both toolchains): removing stdlib import from advanced_logistics
and running bare `filter(...)` → Rust: status ok, zero diagnostics. Confirms:
stdlib implementation is NOT the import blocker. Import surface resolution is
the first barrier.

VE probe: removing `import stdlib.collection.{ append, map }` → Rust reaches
`OOF-TY0 unknown callee 'append'` (VE-P02). Map compiles clean. Confirms:
`map` is already dispatched; `append` needs a separate entry.

---

## 5. Relationship to Existing Proposals

| Proposal | Relationship |
|----------|--------------|
| PROP-IMPORT-RESOLUTION-P5 | Provides the MultifileResolver substrate; defines import as compile-time name resolution; stdlib-as-import explicitly deferred to future route |
| LANG-STDLIB-ENTRY-CONTRACT-P3 | Provides the 26-entry inventory and stdlib_surface_digest algorithm; the built-in module table is derived from this |
| PROP-IMPORT-RESOLUTION-P2A | Establishes OOF-IMP* namespace; OOF-IMP2/IMP3 reuse decided here |
| PROP-036 / PROP-038 | Profile identity; future stdlib_surface_digest pin slot; not opened here |
| LANG-STDLIB-COLLECTION-APPEND-P1 | Blocked until append entry exists in inventory; import surface does not unblock this — it only prevents OOF-IMP2; OOF-IMP3 remains until append is added |
| LANG-STDLIB-IMPORT-SURFACE-P2 | Next route: implementation planning only (bounded MultifileResolver extension) |

---

## 6. Non-Goals

- No stdlib entry authorship (inventory edits are separate)
- No implementation of any kind
- No enforcement rule requiring explicit import before stdlib use
- No canonical name changes
- No new diagnostic codes
- No package acquisition path
- No whole-module import policy (P2 decision)
- No profile pinning implementation (future)

---

## 7. Next Routes

| Card | Scope | Gate |
|------|-------|------|
| **LANG-STDLIB-IMPORT-SURFACE-P2** | Implementation planning: exact MultifileResolver extension (built-in table construction from inventory, stdlib path interception, OOF-IMP2/3 payload, stdlib namespace shadow guard, whole-module import policy, import ordering/alias collision policy) | This proposal accepted |
| **LANG-STDLIB-COLLECTION-APPEND-P1** | Inventory entry authorship for `stdlib.collection.append` + proof | Independent; unblocked by this proposal; VE-P02 pressure |
| **PROP-IMPORT-RESOLUTION-P6** | Bounded CLI or driver policy (multi-source CLI input surface) | PROP-IMPORT-RESOLUTION-P5 closed |

---

## 8. Decision Summary

| Question | Decision |
|----------|----------|
| Resolution mechanism | Built-in stdlib module table (derived from inventory); consulted before user module table; NOT compiler profile; NOT package-like sealed claim |
| Source aliases only? | YES — import makes short source alias available; TypeChecker dispatch unchanged; import clears after resolution |
| Capability authority? | NO — import is name availability only; no authority surface, no capability grant, no fragment class change |
| stdlib_surface_digest | Built-in table is derived view of inventory; digest is identity anchor for importable surface; profile pinning is future (PROP-036/038 slot) |
| Diagnostics | OOF-IMP2 (unknown stdlib module); OOF-IMP3 (known module, unknown name); stdlib namespace shadow guard reserved for P2; no new codes |
| SIR names change? | NO — canonical qualified names in SIR are an entry contract rule, not an import rule; import clears before TC runs |

---

## 9. Acceptance Criteria

This P1 is accepted when:

- All 6 boundary questions are answered with explicit decisions (section 2 above)
- Authority boundary is explicit (section 1 and 3)
- Resolution mechanism is one of three candidates with reasoning (Q1)
- Relationship to stdlib_surface_digest is stated (Q4)
- Diagnostic codes are mapped without new OOF codes (Q5)
- SIR name rule is confirmed (Q6)
- Pressure evidence is cited (section 4)
- No implementation code appears anywhere in this document
- Next implementation route is concrete (section 7)
