# LANG-STDLIB-ENTRY-CONTRACT: Stdlib Entry Contract v0

**Track:** stdlib-entry-contract-identity-semantics-and-evidence-v0
**Route:** PROPOSAL AUTHORING ONLY / NO IMPLEMENTATION
**Status:** authored-pending-review
**Date:** 2026-06-11
**Lineage:** LAB-STDLIB-FOUNDATION-P1 (CLOSED/SPLIT), RES-001, Gemini inventory subtask, PROP-013, PROP-036 (digest pattern), PROP-043 (Map lineage)

---

## Core Principle

> A stdlib entry is not just a function name. It is a **sealed language-owned
> semantic claim** with identity, signature, authority boundary,
> lowering/stability evidence, and proof lineage.

This mirrors the package model's sealed-claim artifact (LAB-PACKAGE-MODEL-P1)
with the trust position inverted: a package's claims are verified by the
consumer's recomputation; a stdlib entry's claims are vouched by the compiler
itself. Both need the same discipline: explicit claims, no ambient anything,
digest-anchored identity.

---

## 1. Problem Statement

Five accumulating failures, each with a concrete exhibit:

1. **Name drift.** SIR contains two namespace regimes: qualified
   (`stdlib.text.concat`, `stdlib.map.get`) and bare (`or_else`, emitted with an
   explicit "no stdlib. prefix — v0 design" comment). The Gemini inventory adds
   a third: both toolchains carry *parallel dispatch* for bare aliases
   (`starts_with`, `map_get`) alongside qualified names — duplicate dispatch
   logic with no record of which form is canonical.

2. **Proof-local helpers wearing stdlib costumes.** LAB-PURSUIT's fixed-point
   contracts, query-domain helpers, `igniter-stdlib/stdlib/*.ig` sketches using
   non-canon `def` syntax. Nothing distinguishes them from real surface except
   tribal knowledge.

3. **Lab/canon mismatch.** `stdlib.option.wrap` is executable (VM + conformance
   artifacts) but canon Ch8 defines `some`/`none`; `parse_datetime`/
   `format_datetime` are hardcoded in the Rust TypeChecker while Ch8 §8.6 names
   `add_duration`/`diff`/`as_of` — disjoint sets, both live.

4. **Hardcoded dispatch as the only registry.** The de-facto inventory is a
   union of: `TEXT_STDLIB_FNS`/`MAP_STDLIB_FNS`/`NUMERIC_MEASURE_BUILTINS` Ruby
   constants, a giant Rust `match fn_name.as_str()`, and the VM's OP_CALL
   intercept list. Three hand-maintained lists, no shared source of truth, plus
   a `stdlib.unsupported.*` refusal namespace that has nothing authoritative to
   refuse against.

5. **Executable truth ≠ semantic stability.** Canon's kernel-proven collection
   surface (fold/map/filter/…) mostly does not run ("pending Slice A"); the only
   fully executable stdlib is explicitly non-canonical lab Rust. One "status"
   label cannot carry both facts.

The entry contract is the single artifact that fixes all five: one normative
machine-readable record per entry, hashed into a surface digest.

---

## 2. Stdlib Entry Contract Shape

One record per entry. Normative field set for v0 (REQUIRED unless marked opt):

```jsonc
{
  // ── Identity ────────────────────────────────────────────────
  "canonical_name": "stdlib.map.get",         // ALWAYS fully qualified, lowercase dotted (§4)
  "category": "map",                           // from the closed category list (§7)
  "aliases": [                                 // every other name that ever resolved here
    { "name": "map_get", "kind": "source_alias", "status": "active" },
    { "name": "get",     "kind": "rejected",     "status": "never" }
  ],
  "owner_surface": "PROP-043",                 // owning proposal/proof lineage anchor

  // ── Status axes (§3 — three separate axes, never collapsed) ─
  "status": "production-implemented",          // lifecycle position
  "stability": {
    "semantic": "design-locked",               // is the MEANING stable?
    "lowering": "dual-toolchain",              // does it RUN, and where?
    "compatibility": "pre-v1-none"             // what is PROMISED externally?
  },

  // ── Semantics ───────────────────────────────────────────────
  "fragment_class": "core",                    // CORE | ESCAPE; fixed at declaration
  "purity": "pure",                            // pure | effect
  "deterministic": true,
  "totality": "total",                         // total | "partial: <honest surface>"
  "type_params": ["V"],
  "input_signature": ["Map[String,V]", "String"],
  "output_signature": "Option[V]",
  "failure_behavior": "missing key -> none",   // what the caller observes; never exception/UB
  "diagnostics": ["OOF-MAP1", "OOF-MAP3"],     // OOF codes this entry can emit

  // ── Authority (§5) ──────────────────────────────────────────
  "authority_surface": "none",                 // "none" | "capability: <Type>" — nothing else exists

  // ── Lowering evidence ───────────────────────────────────────
  "semantic_ir_name": "stdlib.map.get",        // exact string in SIR; MUST equal canonical_name (§4)
  "lowering": {
    "ruby_production": "typechecker MAP_STDLIB_FNS + evaluator",
    "rust_typechecker": "match arm",
    "rust_vm": "OP_CALL dispatch",
    "kernel_only": false
  },
  "vm_lowering_status": "implemented",         // implemented | partial | kernel-only | none

  // ── Evidence ────────────────────────────────────────────────
  "proof_lineage": ["PROP-043 P1 design-lock", "experiments/..."],
  "examples": ["source/...", "fixtures/..."],  // opt
  "compatibility_note": null,                  // opt; renames/supersessions narrative

  // ── Sealing ─────────────────────────────────────────────────
  "entry_digest": "sha256:..."                 // §9; computed, never hand-written
}
```

Design rules baked into the shape:

- `semantic_ir_name` MUST equal `canonical_name`. This single constraint kills
  the bare-`or_else` class of drift permanently: an entry whose SIR string
  differs from its identity is schema-invalid. Migration is recorded in
  `aliases` + `compatibility_note`, not by relaxing the rule.
- `aliases[].kind` ∈ `source_alias` (short form accepted in source, lowered to
  canonical), `legacy_sir` (a bare/old string that historically appeared in SIR
  artifacts), `lab_only` (toolchain invention, slated for removal), `rejected`
  (considered and refused — recorded so it is not re-proposed).
- `authority_surface` has exactly two shapes. There is no grants field, no
  profile field, no runtime-injection field — authority smuggling is a schema
  violation, not a policy violation (same mechanism as the package manifest).

---

## 3. Status / Stability Axes

**Axis 1 — lifecycle `status`** (one value, ordered intake):
`doc-only` → `proposal` → `proof-local` → `lab-implemented` →
`production-implemented` → `canon`; plus terminal/abnormal: `deprecated`,
`orphaned` (exists in code with no owning record — the triage marker; the
target state is zero orphaned entries).

**Axis 2 — `stability.semantic`:** `sketch` | `convention` (deliberately
pre-final, e.g. KDR outcome helpers pre-sum-types) | `experiment-pass` |
`design-locked` | `superseded`.

**Axis 3 — `stability.lowering`:** `none` | `kernel-only` | `single-toolchain`
| `dual-toolchain`.

**Axis 4 — `stability.compatibility`:** `pre-v1-none` (current universal value)
| later: `surface-stable` | `frozen`. No entry may claim more than
`pre-v1-none` under this proposal.

The axes are independent by construction. Today's most misleading cases become
expressible: Ch8 collection ops = `status: canon` + `semantic: design-locked` +
`lowering: kernel-only`; `stdlib.option.wrap` = `status: orphaned` +
`lowering: dual-toolchain` (yes, an orphan can run — that is exactly the fact
worth recording).

---

## 4. Naming Discipline

**Decisions (not held):**

1. **`canonical_name` is ALWAYS fully qualified** — `stdlib.<category>.<fn>`,
   lowercase, dotted. No exceptions, including future ones. (Explicit answer Q1.)
2. **Short names are `source_alias` entries, not legacy** — `map_get`,
   `starts_with` remain valid *source-level* spellings, recorded per entry; they
   never appear in SIR. The existing short→qualified mapping pattern
   (TEXT_STDLIB_FNS / MAP_STDLIB_FNS) is ratified as the one sanctioned
   mechanism. (Q2.)
3. **Bare `or_else` in SIR is drift, not an exception.** Its record reads
   `canonical_name: stdlib.option.or_else`, alias `{name: "or_else", kind:
   "legacy_sir"}`. The SIR string change is implementation work — closed here,
   routed to P2. Until then the record honestly shows
   `semantic_ir_name != canonical_name` as a known schema violation grandfathered
   with a deadline, the only one. (Q3.)
4. **Monomorphization is the one sanctioned in-pipeline rename:**
   `stdlib.numeric.add` (generic, pre-resolution) → `stdlib.integer.add`
   (monomorph, post-resolution). Both are entries; the generic entry lists its
   monomorphs; the monomorph's record points back. No other pass may rewrite a
   stdlib name.
5. **Aliases are append-only.** A canonical_name change requires: old name
   appended to `aliases` with `kind: legacy_sir` or `source_alias`,
   `compatibility_note` updated, entry_digest recomputed. Deleting a name from a
   record is forbidden — the alias list is the churn ledger.
6. `?`-suffix doc names (`some?`, `ok?`) are `rejected` aliases unless a parser
   ever accepts them; promoted predicates use `is_` prefix.

---

## 5. Authority Boundary

Every entry states, by schema shape rather than promise:

- **No capability grant — ever.** `authority_surface: "none"` for pure entries.
  An effectful entry declares `"capability: <Type>"`, meaning it *consumes* a
  capability value as an explicit input parameter (the lab `io.ig` shape:
  `read_text(path, capability: IO::Capability) -> Result[...]`). There is no
  field through which an entry could grant, widen, or inject authority. (Q5: NO.)
- **Effectful entries are admissible** but born on the effect-surface side:
  `purity: effect` ⇒ `fragment_class: ESCAPE` ⇒ capability parameter required ⇒
  Result/outcome-shaped output. CORE entries are pure, deterministic, total or
  honestly partial. No entry is context-dependent. (Q4: YES, with this shape.)
- **Runtime lowering authority:** an entry record never authorizes lowering;
  `lowering`/`vm_lowering_status` are *evidence fields* describing what proofs
  demonstrated. Adding a VM dispatch arm remains separately-authorized
  implementation work.
- **Proof evidence authority:** `proof_lineage` references proofs; it does not
  re-open them.
- **No package/distribution authority:** nothing in an entry record names an
  origin, registry, version range, or acquisition path.

---

## 6. Inclusion Criteria

An entry may be admitted (at any status above `proposal`) iff ALL hold:

1. **Cross-domain demand** — ≥2 independent proof domains needed it (PROP-047
   method). Proof-local or single-domain use does NOT create stdlib status; it
   creates *demand evidence* recorded in the candidate's `examples`. (Q6: NO.)
2. **Stable typed signature expressible today** — if the signature needs absent
   machinery (runtime higher-order params, trait bounds), the entry exists only
   as `status: proposal` + `semantic: sketch`.
3. **Deterministic, or explicit effect semantics** per §5.
4. **Proof matrix** per §10 for the claimed status level.
5. **Diagnostics declared** — every OOF the entry can emit is listed; an
   undeclared diagnostic firing is itself a proof failure.
6. **No domain-local leakage** — name and semantics meaningful outside the
   demanding domain.
7. **No hidden authority** — §5 schema satisfied.

Lab VM implementation alone does NOT create canon status (Q7: NO) — it sets
`stability.lowering` only; `status: canon` additionally requires Ch8 text and
the §10 bar. The inverse also holds: Ch8 text alone does not set lowering above
`none`.

---

## 7. Category Decisions

Routing recorded from LAB-STDLIB-FOUNDATION-P1 (normative for intake):

| Category | Decision |
|---|---|
| `text` | **READY** — reference category; first to receive full entry records |
| `map` | **READY** |
| `option` / `result` | **READY-for-reconciliation** — records authored now; D1 (`or_else`) and D2 (`wrap`) resolved inside them; surface growth waits for sum-types (PROP-044 P2+) |
| `collection` | **SPLIT** — `count` production record; Ch8 §8.2 ops recorded `status: canon` + `lowering: kernel-only`; find/any/all/zip/range/concat triage in LAB-STDLIB-COLLECTION-P1 |
| `numeric` / `math` | **HOLD** — not ready (Q10: NO); STAB-P4 operator parity gates; N0/N1 records may be authored as `status: proposal` + `semantic: sketch` only |
| `datetime` / `temporal` | **HOLD** — D3 disjoint-name triage first (LAB-STDLIB-DATETIME-P1); `as_of`/TemporalCtx/OOF-L6 discipline is the fixed point |
| `outcome` | **OPEN-as-convention** — see §12 |
| `query` | **DOMAIN-LOCAL** — not stdlib |
| `io` / `net` / `storage` | **L3-reserved** — shape evidence only (capability-param + Result); no entries above `proposal` |
| `bool` | **DO NOT CREATE** unless evidence changes — `stdlib.bool.and` is operator lowering, to be re-homed in operator semantics, record marked `orphaned` meanwhile |

Category list is closed; adding a category is a proposal amendment.

---

## 8. Drift Handling

Standard procedures, one per drift class:

| Class | Procedure |
|---|---|
| **Alias migration** (bare `or_else`, bare text/map aliases in dispatch) | Record canonical_name; mark current bare SIR/dispatch strings `legacy_sir`/`source_alias`; SIR/dispatch code change routed to P2 with regression bar; alias never deleted |
| **Canon/lab mismatch** (`wrap` vs `some/none`; `parse_datetime` vs Ch8 §8.6) | Canon names win by default; lab name recorded `kind: lab_only` with removal route; where canon names were never proven and lab names were (datetime), a triage card decides per name BEFORE records claim canon status |
| **Orphaned names** (`stdlib.bool.and`, `stdlib.integer.gt`, `stdlib.collection.concat`) | Every orphan gets a record with `status: orphaned` immediately — visibility first, judgment per triage card; an orphan record asserts existence, not legitimacy |
| **Doc-only names** (Ch8 names never proven; `?`-predicates) | Records at `status: doc-only`; promotion only through §10 bar; reconciliation may also demote (remove from Ch8 via errata) |
| **VM-only names** | = orphaned with `lowering: single-toolchain`; same procedure |
| **Proof-local helpers** | NO records; listed as demand evidence in the relevant candidate entry's `examples`; the false-stdlib partition from FOUNDATION-P1 is the gatekeeping checklist |

---

## 9. Digest / Registry Concept (design-only)

- **`entry_digest`** = `sha256(canonical_json(entry minus entry_digest))` —
  same canonicalization discipline as `Assembler::Canonical` (sorted keys,
  normalized values). Any field change, including alias appends, changes the
  digest.
- **`stdlib_surface_digest`** = `sha256(canonical_json(sorted entries by
  canonical_name))` — the identity of the whole surface. (Q11: this digest
  anchors the stdlib surface.) Verbatim reuse of the composite-hash discipline
  proved order-independent in IMPORT-P5.
- **Relationship to packages:** `stdlib_surface_digest` is the pinnable object
  that makes "stdlib = the package the compiler vouches for" concrete — it
  slots into compiler-profile pinning (PROP-036 slot pattern) exactly where a
  package's `package_digest` slots into a lockfile. Symmetric mechanism,
  inverted trust.
- **Registry:** the inventory file itself (location candidate:
  `docs/spec/stdlib-inventory.json` referenced normatively by Ch8 — final
  location is a P2 decision). The VM's `stdlib.unsupported.*` refusal and both
  TypeCheckers' dispatch tables become *derived views* of this registry in the
  target state. **No implementation here** — v0 is the schema and the worked
  examples only.

---

## 10. Proof Requirements

Bar per claimed level (cumulative):

| Claim | Required proof |
|---|---|
| `status: proposal` | record well-formed; demand evidence cited |
| `semantic: experiment-pass` | dedicated runner: typechecker positive + negative (every declared diagnostic fires on a negative fixture), SIR shape (semantic_ir_name exact string present), determinism (re-run hash-stable) |
| `lowering: kernel-only` | kernel execution cases (PROP-013 pattern) |
| `lowering: single-toolchain` | end-to-end pipeline proof on that toolchain (parse→TC→SIR→manifest, or VM execution) |
| `lowering: dual-toolchain` | cross-toolchain parity case: same inputs, same outputs, both toolchains (per-entry application of the STAB-P4 operator-parity rule) |
| `status: canon` | + Ch8 text reconciled; closed-authority assertion (no capability/profile/runtime fields emitted anywhere in artifacts); entry present in inventory; surface digest updated; category regression matrix re-run |

Aggregate-producing entries additionally prove `aggregated_from` evidence
preservation (Ch8 §8.7). Effectful (L3) entries additionally prove
capability-parameter refusal when absent.

---

## 11. Relationship To Packages

- Stdlib is **language-owned**: identity = `stdlib_surface_digest` pinned via
  compiler profile; trust = constitutive (the compiler vouches); growth = PROP +
  proof. (Q8: stdlib does NOT belong to the package model now.)
- Packages are **external sealed claim artifacts**: identity = package_digest
  over source units; trust = consumer recomputation; growth = acquisition.
- Convergence note: if RES-001's self-hosting direction lands, stdlib may later
  be *represented* as a compiler-owned package-like surface (first-party
  package, digest-pinned, profile-vouched). The entry contract is written to
  survive that transition: identity, claims, and digests carry over; only the
  trust position would change.
- No package manager, registry, or distribution opens here.

---

## 12. Relationship To Outcomes

Outcome helpers are **in scope as a category decision, out of scope as
content** (Q9: part of stdlib's category model, not of this proposal's
authoring). Recorded: `outcome` category = OPEN-as-convention; entries
(`is_unknown`, `requires_reconciliation`, `partition_partial`, …) to be authored
by **LAB-STDLIB-OUTCOME-P1** with `semantic: convention` and an explicit
`superseded-by-variants` note (PROP-044 P2+ sum types are the successor).
Rationale stands in FOUNDATION-P1 §6/§7 and the Gemini inventory: the canon
unknown-state model (Ch12 + Covenant P15) exists with zero stdlib combinators,
so fixtures carry `unknown_external_state`/`timed_out` as stringly `kind`
values — the most expensive blind spot in the surface.

---

## 13. Non-Goals

- No function implementation, no VM/runtime/SemanticIR/parser/typechecker change
- No renaming in code (D1/D2 SIR string changes are P2 work)
- No registry build (schema + worked examples only)
- No package manager / distribution
- No public stdlib compatibility promise beyond `pre-v1-none`
- No numeric/datetime cleanup inside P1 (gated categories stay gated)

---

## 14. Next Routes

| Card | Scope | Gate |
|---|---|---|
| **LANG-STDLIB-ENTRY-CONTRACT-P2** | Implementation planning: inventory file location/format, derived-dispatch strategy, D1/D2 SIR string migration plan with regression bar, first full category records (text, map) | this proposal accepted |
| **LAB-STDLIB-OUTCOME-P1** | Convention-level KDR combinator records + proof | none (conventions present) |
| **LAB-STDLIB-OPTION-P1** | Option/Result reconciliation: D2 closure, executable parity for monadic surface | P2 |
| **LAB-STDLIB-COLLECTION-P1** | Example-name triage; §8.2 honest `kernel-only` marking | P2 |
| **LAB-STDLIB-DATETIME-P1** | D3 per-name triage (Ch8 §8.6 vs proven extension names vs Rust TC hardcoded names) | P2 |
| **LAB-STDLIB-MATH-P1** | N0/N1 `proposal`-status records | STAB-P4 operator parity |

---

## 15. Required Explicit Answers (consolidated)

| Question | Answer |
|---|---|
| Is canonical_name always qualified? | **YES** — `stdlib.<category>.<fn>`, no exceptions |
| Are short names aliases or legacy? | **Aliases** (`source_alias`, permanent, recorded per entry); never in SIR |
| Is `or_else` an exception or drift? | **Drift** — the one grandfathered `legacy_sir` schema violation, with a P2 migration route |
| Can a stdlib entry be effectful? | **YES** — `purity: effect` ⇒ ESCAPE tier + capability input parameter + Result/outcome output |
| Does a stdlib entry grant authority? | **NO** — grant fields are schema-absent; effectful entries consume capabilities, never produce them |
| Does proof-local use create stdlib status? | **NO** — it creates demand evidence only |
| Does lab VM implementation create canon status? | **NO** — it sets `stability.lowering` only; the axes are independent |
| Does stdlib belong to package model now? | **NO** — language-owned, profile-pinned; possible self-hosted convergence later, designed-for but not opened |
| Is outcome helper work part of stdlib? | **Category yes, content routed** — OPEN-as-convention, LAB-STDLIB-OUTCOME-P1 |
| Is numeric category ready? | **NO** — HOLD on STAB-P4 operator parity; `proposal`-status records only |
| What digest anchors a stdlib surface? | **`stdlib_surface_digest`** = sha256 over canonical-JSON sorted entry records; per-entry `entry_digest` beneath it; pinned via compiler profile (PROP-036 pattern) |
