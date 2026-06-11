# LANG-STDLIB-ENTRY-CONTRACT-P2: Implementation Planning v0

**Track:** stdlib-entry-contract-registry-derived-dispatch-and-first-entries-planning-v0
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE
**Status:** CLOSED — READY FOR P3
**Date:** 2026-06-11
**Predecessor:** LANG-STDLIB-ENTRY-CONTRACT-P1 (CLOSED / PROPOSAL AUTHORED)

---

## 1. Registry Location

**Decision: single hand-authored JSON file in the canonical repo:**

```
igniter-lang/docs/spec/stdlib-inventory.json
```

Rationale against alternatives:

| Option | Verdict | Why |
|---|---|---|
| JSON in `docs/spec/` | **CHOSEN** | Normatively referenced by Ch8 (resolves RES-001 open question Q1); Ruby reads it natively (`JSON.parse`); Rust reads it natively (serde) when P4 parity lands; diffable in review; data, not code |
| YAML | rejected | cross-language YAML parsing differences (anchors, implicit typing) threaten digest determinism |
| Ruby literal (constant) | rejected | not consumable by Rust without a generator; entrenches the hand-maintained-constant pattern the registry exists to replace |
| Generated artifact | rejected for v0 | nothing to generate FROM yet; the inventory IS the source of truth; derived artifacts come later (P4+) |

Determinism rule: the digest is computed over **canonical re-serialization**
(`Assembler::Canonical.normalize` + `JSON.generate`), never over raw file bytes —
formatting, key order, and whitespace in the authored file are irrelevant to
identity. The file may be pretty-printed for humans.

Sharing with Rust lab: read-only consumption of the same file by path in P4;
no export/copy step. Future compiler-profile pinning: see §3.

## 2. Entry Schema (finalized)

Concrete serialized shape — every entry is one object in the top-level
`"entries"` array:

```jsonc
{
  "kind": "stdlib_inventory",                  // top-level envelope
  "format_version": "stdlib-inventory-v0",
  "entries": [
    {
      "canonical_name": "stdlib.map.get",      // REQ; unique key; qualified lowercase dotted
      "semantic_ir_name": "stdlib.map.get",    // REQ; MUST equal canonical_name…
      "legacy_sir": null,                      // …UNLESS legacy_sir is non-null: the exact string
                                               // currently emitted in SIR (grandfather marker)
      "aliases": [                             // REQ (may be []); append-only
        { "name": "map_get", "kind": "source_alias", "status": "active" }
      ],
      "category": "map",                       // REQ; closed list from P1 §7
      "lifecycle_status": "production-implemented",
      "semantic_stability": "design-locked",
      "lowering_status": "dual-toolchain",
      "compatibility_status": "pre-v1-none",   // only legal value in v0
      "fragment_class": "core",
      "purity": "pure",
      "deterministic": true,
      "totality": "total",
      "type_params": ["V"],
      "input_signature": ["Map[String,V]", "String"],
      "output_signature": "Option[V]",
      "diagnostics": ["OOF-TY0"],              // exact codes the dispatch site can emit (P3 enumerates from code)
      "failure_behavior": "missing key -> none",
      "authority_surface": "none",             // "none" | "capability: <Type>" — closed enum shape
      "proof_lineage": ["PROP-043"],
      "examples": ["fixtures/..."],            // OPT
      "compatibility_note": null,              // OPT
      "entry_digest": "sha256:..."             // derived; see §3
    }
  ],
  "stdlib_surface_digest": "sha256:..."        // derived; see §3
}
```

Schema validity rules (P3 proof checks, not prose):
- `canonical_name` unique across entries; matches `^stdlib\.[a-z_]+\.[a-z_]+$`
- `semantic_ir_name == canonical_name` OR `legacy_sir` non-null (and then
  `legacy_sir` must also appear in `aliases` with `kind: "legacy_sir"`)
- `aliases[].kind` ∈ {source_alias, legacy_sir, lab_only, rejected}
- alias names unique globally — an alias may not collide with another entry's
  canonical_name or aliases (this is what "aliases are not identities" means
  mechanically: one resolution target per name)
- `authority_surface` = `"none"` or `"capability: <Type>"` — no other shape
  parses; `purity: "effect"` ⟺ capability form ⟺ `fragment_class: "escape"`
- four axis fields each from their closed enum (P1 §3)
- `orphaned` entries: `lifecycle_status: "orphaned"` requires non-empty
  `compatibility_note` naming the triage route

## 3. Digest Calculation (exact)

- **`entry_digest`** = `"sha256:" + SHA256(JSON.generate(Canonical.normalize(entry_without_entry_digest)))`
  — every field except `entry_digest` itself is material, including aliases
  (append = new digest) and all four axis fields.
- **`stdlib_surface_digest`** = `"sha256:" + SHA256(JSON.generate(Canonical.normalize(
  entries_sorted_by_canonical_name_each_without_entry_digest)))`
  — computed over the digest-stripped records, NOT over the per-entry digests,
  so the surface digest is independently recomputable and per-entry digests are
  independently verifiable; sorting by `canonical_name` gives file-order
  independence (the IMPORT-P5 discipline).
- Envelope fields (`kind`, `format_version`) are material to the surface digest;
  `stdlib_surface_digest` itself is excluded.
- **compiler_profile_id relationship:** the unified profile's `slot_order` is a
  closed 12-slot list (PROP-036/038); adding a `stdlib_surface` slot is a
  profile-descriptor change requiring its own PROP amendment. P3 does NOT touch
  profiles; the planned shape is: future slot `stdlib_surface` →
  `stdlib_surface_digest`. Recorded as the designated P5+ route, closed here.

## 4. Derived Dispatch Strategy

**Decision: Option A for P3** — registry exists; Ruby/Rust dispatch tables
remain hand-maintained; the P3 proof runner **verifies them against the
registry** in both directions:

- **Coverage:** every entry with `lowering_status` claiming ruby production has
  a live dispatch site (TEXT_STDLIB_FNS / MAP_STDLIB_FNS /
  NUMERIC_MEASURE_BUILTINS keys, `infer_or_else` arm) — checked by introspecting
  the Ruby constants at proof time (read-only, no code change).
- **No strays:** every key in those Ruby constants resolves to a registry
  canonical_name or an active alias. A dispatch name with no registry record =
  proof FAIL (this is the anti-accretion gate — new builtins cannot land
  without a record).

Why not B (Ruby derives from registry): deriving TEXT_STDLIB_FNS from JSON
means typechecker code change — closed in P3's planned authority, and risky
while the registry format is one proof old. Why not D (HOLD): verification
needs no implementation authority at all and immediately makes the registry
load-bearing. B is the natural P4/P5 candidate after one cycle of stability;
C (Rust derives) follows Rust parity, not before.

## 5. First Entries (P3 set — 24 records)

| Group | Entries | Justification |
|---|---|---|
| `text` ×14 | concat, trim, contains, starts_with, ends_with, split, replace, replace_all, byte/rune/grapheme_length, byte/rune/grapheme_slice | the reference category — full three-way agreement (Ch8 §8.10 + TEXT_STDLIB_FNS + VM dispatch); all `production-implemented` / `design-locked` / `dual-toolchain` |
| `map` ×4 | stdlib.map.get, has_key, from_pairs, empty | PROP-043 lineage; short names (`map_get`…) as `source_alias`; see §8 |
| `option` ×1 | stdlib.option.or_else | the grandfathered legacy_sir case — including it day one is the point (§6) |
| `collection` ×1 | stdlib.collection.count | production (PROP-042 NUMERIC_MEASURE_BUILTINS, qualified name already `stdlib.collection.count`) |
| orphans ×4 | stdlib.option.wrap, stdlib.bool.and, stdlib.integer.gt, stdlib.collection.concat | P1 drift procedure: every orphan gets a record immediately — visibility before judgment; each `lifecycle_status: orphaned` + compatibility_note naming its triage route (OPTION-P1 / operator-semantics re-home / STAB-P4 / COLLECTION-P1) |

Name justifications where a choice existed:
- **`stdlib.option.or_else`, NOT `stdlib.option.unwrap_or`:** Ch8 §8.3 defines
  `or_else(opt, fallback)` for Option; `unwrap_or(r, fallback)` is the Ch8 §8.4
  *Result* operation with a different input type. They are different entries,
  not synonyms. New drift found during P2 reads: the Rust TypeChecker matches
  `"unwrap_or" | "or_else"` in one arm (typechecker.rs:2696) — conflating the
  Option and Result operations. Recorded in or_else's `compatibility_note`;
  untangling is LAB-STDLIB-OPTION-P1 scope. `unwrap_or` gets NO record in P3
  (Result category not opened).
- **Bare `length`:** deliberately absent — the text unit model makes unqualified
  length ambiguous (byte vs rune vs grapheme). Recorded as `kind: rejected`
  alias on all three `*_length` entries so it is never re-proposed.
- **`join`:** no canon text, no implementation, no proof — held; no record.
- Excluded from P3 entirely: §8.2 collection ops (kernel-only marking is
  COLLECTION-P1 triage work), numeric/datetime (HOLD gates), outcome
  (OUTCOME-P1), monadic option/result surface (OPTION-P1).

## 6. `or_else` Migration (exact plan)

Current facts (verified in code): source name `or_else` → TC `infer_or_else`
(typechecker.rb:2093) → SIR `"fn" => "or_else"` bare (deliberate v0 comment);
14 source-level uses across lab fixtures; Rust TC accepts bare (shared arm with
unwrap_or); VM consumes the SIR string.

- **Registry record (P3):** `canonical_name: "stdlib.option.or_else"`,
  `semantic_ir_name: "stdlib.option.or_else"` (the target),
  `legacy_sir: "or_else"` (the current emission), aliases:
  `{or_else, source_alias, active}` + `{or_else, legacy_sir, active}`.
  The P3 proof asserts this is the ONLY entry with non-null `legacy_sir` —
  the grandfather invariant from P1 is a counted check, not prose.
- **Fixtures need no change — ever.** All 14 uses are source-level; `or_else`
  remains the permanent `source_alias`. Source spelling never migrates.
- **Emission change is NOT P3.** The actual switch (`"fn" => "stdlib.option.or_else"`
  in infer_or_else) is separately-authorized implementation (P4 candidate),
  requiring: SIR golden regeneration (contract_ref hashes change), Rust TC/VM
  dual-accept window (dispatch accepts both strings during migration, bare form
  removed after one proof cycle), and regression: every fixture using or_else
  re-compiled with qualified name asserted in SIR.
- **Proof expectation at each stage:** P3 — discrepancy expected and counted;
  P4 — `semantic_ir_name == canonical_name` holds, `legacy_sir` moves to
  history (field set null, alias entry remains forever).

## 7. Option Constructor Drift

**P3 does not touch it** beyond the `stdlib.option.wrap` orphan record
(`lifecycle_status: orphaned`, `lowering_status: dual-toolchain`,
compatibility_note → LAB-STDLIB-OPTION-P1). Canon `some`/`none` get no records
in P3 (doc-only status would be the honest marking — deferred to OPTION-P1
which reconciles constructors as one coherent move rather than piecemeal).

## 8. Map Category (full record plan)

| Entry | type_params | input_signature | output_signature | diagnostics | notes |
|---|---|---|---|---|---|
| stdlib.map.get | [V] | [Map[String,V], String] | Option[V] | OOF-TY0 + map-arg type errors | |
| stdlib.map.has_key | [V] | [Map[String,V], String] | Bool | same | |
| stdlib.map.from_pairs | [V] | [Collection[Pair[String,V]]] | Map[String,V] | same | depends on array_literal inference (typechecker.rb infer_array_literal) — recorded in examples |
| stdlib.map.empty | [] | [] | Map[String,Unknown] | OOF-TY0 (args present) | **Unknown is honest, not a bug:** value type is context-deferred; the live emission carries `"note": "empty-type-context-inference-deferred-v1"` — that note string is recorded in the entry's compatibility_note verbatim |

All four: `production-implemented` / `design-locked` / lowering per evidence
(get/has_key `dual-toolchain` — VM dispatch confirmed; from_pairs/empty —
verify VM handlers at P3 proof time and record `single-toolchain` if absent;
the registry records what proofs show, never what we assume).
Diagnostics enumeration: P3 includes a check that extracts the exact OOF codes
from the dispatch sites (OOF-TY0 confirmed at arity sites; any OOF-MAP* from
PROP-043 enumerated from code, not from memory).

## 9. Text Category

All 14 ops READY with full records (justification in §5). Held without records:
`join` (no evidence), bare `length` (rejected by unit-model design), any
`stdlib.string.*` revival (`Text` is canonical per Ch8 §8.10.1; `String`
supersession note goes in category-level compatibility_note on each entry's
record where relevant). The Gemini finding that the VM also dispatches *bare*
text aliases (`starts_with` etc.) is recorded per entry as
`{name: "<bare>", kind: "source_alias", status: "active"}` — accurately
describing today's dual dispatch; tightening bare-SIR acceptance is P4 scope
with the or_else migration.

## 10. Cross-Toolchain Strategy

- **P3 = Ruby-only proof runner + registry file.** Runner location:
  `igniter-lang/experiments/stdlib_inventory_proof/verify_stdlib_inventory_p3.rb`.
  It validates schema, digests, and Ruby dispatch coverage (§4). No Rust reads.
- **P4 = Rust parity slice:** Rust-side check that VM OP_CALL intercept list and
  Rust TC match arms resolve to registry names/aliases (read-only consumption of
  the same JSON); plus the or_else emission migration if separately authorized.
- **Derived artifacts (generation):** earliest P5, only after one full proof
  cycle of the verified-manual regime.

## 11. Proof Matrix For P3 (target ≥60; planned 68)

| Section | Checks | Focus |
|---|---|---|
| A — Schema validation | 12 | envelope kind/format_version; per-entry required fields; canonical_name regex + uniqueness; axis enums; alias kinds; authority_surface shape; purity⟺capability⟺escape consistency; orphan⟹compatibility_note |
| B — Digest determinism | 8 | entry_digest recompute matches for all 24; surface digest recompute; re-serialization (shuffled file) → same digests; entry order in file irrelevant; digest excludes itself; alias append changes digest (negative fixture) |
| C — Identity rules | 8 | semantic_ir_name == canonical_name for 23/24; exactly ONE legacy_sir entry (or_else); legacy_sir string present in aliases; alias names globally unique; no alias collides with any canonical_name |
| D — Map entries | 8 | four records complete; signatures match dispatch reality (introspect MAP_STDLIB_FNS); map.empty Unknown note recorded; OOF codes enumerated from code |
| E — Text entries | 10 | 14 records present; TEXT_STDLIB_FNS keys ⊆ aliases; arg_types/return_type match input/output signatures; rejected `length` alias on the three *_length entries |
| F — or_else exception | 6 | record shape; counted-grandfather invariant; current SIR emission string equals legacy_sir (compile a fixture, read SIR); fixtures unchanged assertion |
| G — Dispatch coverage | 8 | both directions per §4 incl. NUMERIC_MEASURE_BUILTINS/count; stray-name negative fixture FAILS |
| H — Authority closure | 6 | all 24 authority_surface "none"; no grant/profile/runtime field parses anywhere in inventory; no package/origin/version-range fields |
| I — Orphan records | 4 | four orphans present with triage routes; orphan ≠ alias of any live entry |
| J — Closed surfaces | 4 | no Ruby lib/ source modified by proof run (hash check); no VM/parser/SIR change; registry file is the only new artifact |

## 12. Closed Surfaces (P3 must not)

Rename live functions (incl. the or_else SIR string — P4) · change VM behavior ·
generate dispatch tables · parser/typechecker/SemanticIR changes · implement
packages/distribution · add compatibility promises above `pre-v1-none` ·
promote numeric/datetime/outcome/monadic entries "while we're at it" — the
24-entry list in §5 is exhaustive; additions require a card amendment.

## 13. Recommendation

**READY FOR P3 — registry + verification** (full §5 scope, not narrowed):
the 24 entries are all evidence-complete today, and narrowing to map/text only
would drop exactly the two records that carry the model's value — the
grandfathered or_else and the orphan visibility set.

Next route: **LANG-STDLIB-ENTRY-CONTRACT-P3** — bounded implementation:
author `docs/spec/stdlib-inventory.json` (24 records) + proof runner (68
checks); no compiler-source changes. Then P4: Rust parity + or_else emission
migration (separate authorization).
