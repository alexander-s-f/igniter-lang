# LANG-FORM-VOCABULARY — Explicit Form Vocabulary and Order-Independent Resolution

**Track:** form-vocabulary-explicit-dictionary-and-order-independent-resolution-v0
**Route:** PROPOSAL AUTHORING ONLY / NO IMPLEMENTATION
**Authority:** design boundary and governance only
**Date:** 2026-06-11
**Status:** CLOSED / PROPOSAL AUTHORED
**Predecessors:**
- LAB-CONTRACT-FORMS-P1 (archaeology + formalization; SPLIT decision)
- LAB-FORM-LAYER-THEORY-P1 (fixed-skeleton + open-vocabulary model; TH-1..TH-6 obligations)
- LAB-CONTRACT-FORMS-P2 (lineage reconciliation; C-1..C-7 coherence rules; KEEP decision)
- LAB-FORM-INVOCATION-P1 (in-module proof; 66/66 PASS; TH-1/4/6 mechanised)
- LAB-FORM-VOCABULARY-P1 (cross-module vocabulary coherence; 61/61 PASS; TH-2 conditional)
- LANG-TYPED-CONTRACT-REF-PROP-P5 (substrate closed; 71/71 PASS; OOF-REF2 gap resolved)

---

## 1. Authority Boundary

This proposal is design authority only. It does not authorize:

- Parser implementation (no `speaks` keyword parser change)
- Classifier implementation
- TypeChecker implementation
- SemanticIR emitter implementation
- Assembler implementation
- VM / runtime changes
- Public syntax activation
- Package or visibility changes
- Capability or profile authority
- `call_contract` behavior changes
- Macro system

What this proposal authorizes:
- The design and governance boundary for form vocabularies
- Reservation of the `OOF-FORM` diagnostic namespace
- A named next route (LANG-FORM-VOCABULARY-PROP-P2)

Implementation authorization requires a separate planning round (P2).

---

## 2. Context and Motivation

### The substrate gap is closed

LANG-TYPED-CONTRACT-REF-PROP-P5 (71/71 PASS) proves cross-module typed contract reference
resolution is live in the Ruby canon pipeline:

- `uses Mod.Contract` → `resolution_kind: "qualified"` + `module_name` in SIR
- `import Mod; uses Contract` → `resolution_kind: "imported"` + `module_name` in SIR
- OOF-REF2 narrowed to genuine ambiguity (≥2 imported modules export the same contract name)
- `dependency_edges` carries `from_module`, `to_module`, `resolution_kind`

This satisfies the substrate requirement that LAB-FORM-VOCABULARY-P1 identified as the gate
for TH-2 unconditional proof.

### The form vocabulary problem

LAB-FORM-LAYER-THEORY-P1 established that forms are a **stratification mechanism**: a fixed
semantic kernel (typed contract references + InvocationIntent) plus an **open surface
vocabulary** (named form words that elaborate conservatively over the kernel). This is
not invocation sugar — it is definitional/conservative extension in the Felleisen sense.

LAB-FORM-VOCABULARY-P1 proved the vocabulary model is coherent and order-independent under the
explicit import model (61/61 PASS), conditional on the cross-module typed-ref substrate.
That condition is now satisfied.

The orphaned Rust implementation (`form_registry.rs`, `form_resolver.rs`) and the
`PROP-Forms-Enhanced-v0` specification have been waiting for a substrate. They have it.

This proposal authors the governance boundary for the explicit form vocabulary system, maps
all proof obligations, and specifies the design-only data shapes and diagnostic namespace.

---

## 3. Terminology

These definitions are **normative** for all P1+ form vocabulary work. Ambiguity in naming
was a source of confusion in the LAB-CONTRACT-FORMS-P1 archaeology; this section
resolves it permanently.

### 3.1 Contract Invocation Form (Invocation Form, Form)

A conservative elaboration: a named surface trigger (keyword, phrase, or constructor pattern)
that lowers to an **InvocationIntent** targeting a resolved typed contract reference. A form
does not execute a contract. It produces the same InvocationIntent as an explicit typed call.
The form is visible at the source level and in the resugaring trace; it disappears by the
time InvocationIntent is emitted.

A form is **not** a macro (it cannot change the grammar or inject new declarations). It is
**not** a capability grant (it confers no authority). It is **not** a runtime primitive (it
lowers before runtime sees any state).

Scope of this proposal: Contract Invocation Forms only. Gap-I Form Constructor (Covenant
P27/P28, value construction) and View/UI forms are separate tracks and are explicitly not
addressed here.

### 3.2 Form Vocabulary (Vocabulary, Dictionary)

A named, explicitly-imported collection of **form words**, declared by a recognized
vocabulary owner, associated with one or more typed contract references. A vocabulary
is a unit of vocabulary identity: it has a path (e.g. `Query.Forms`), a source module,
an ownership claim, and a set of form words.

A vocabulary is **not** a module. It is **not** a package. It is **not** an import in the
PROP-IMPORT-RESOLUTION sense. It does not grant authority. Importing a vocabulary does not
grant access to a module's internal contracts.

### 3.3 Form Word

A single entry in a form vocabulary: one trigger + one lowering rule + one typed-ref
anchor requirement + one ownership claim. A form word maps a surface trigger to an
InvocationIntent over a specific contract.

A form word is **invalid** without a resolved `uses T` anchor (Rule C-1).

### 3.4 Form Trigger

The surface pattern that activates a form word. In v0, triggers are keyword-class strings
(matching the FormKind ×7 model from `form_registry.rs`). A trigger identifies **which form
word** is being invoked, not which contract is being called (that is the anchor's job).

Language primitives (`+`, `-`, `*`, `==`, etc.) are reserved and may not be form triggers
(invariant H2 from `form_resolver.rs`, promoted to rule here).

### 3.5 Typed ContractRef

A `uses ContractName` or `uses Mod.Contract` declaration, as proved in
LANG-TYPED-CONTRACT-REF-PROP-P3 (same-module, 67/67 PASS) and P5 (cross-module, 71/71 PASS).
The typed-ref is the **substrate**: every valid form word is anchored to a resolved typed-ref.
Without the typed-ref, there is no form word.

### 3.6 InvocationIntent

The canonical lowered representation of "invoke this contract with these arguments." Both
explicit typed-contract calls and form-lowered calls produce the **same** InvocationIntent.
This equality is the mechanisation of TH-6 (eliminability) and TH-1 (conservativity).
InvocationIntent carries `execution_dependency: false` (same as typed-refs). It does not
carry form identity — form identity lives in the resugaring trace.

### 3.7 ResugaringTrace

Compiler metadata attached to a lowered form: `{ surface_trigger, expanded_contract,
lowering_metadata }`. The ResugaringTrace is evidence for the debugger and for TH-5. It is
**not** authority. The runtime does not read it.

### 3.8 Gap-I Form Constructor

A Covenant P27/P28 form: construction of values (not invocation of contracts). Completely
separate from Contract Invocation Forms. This proposal explicitly does not address it. The
two tracks share the word "form" but have orthogonal semantics.

### 3.9 View / UI Form

Frontend rendering primitives (the view-DSL exploration in the lab). May eventually consume
form vocabulary as a substrate. Not in scope for this proposal.

---

## 4. Source Surface

### 4.1 Vocabulary Declaration Site

A form vocabulary is declared at **module level** in the module that owns the vocabulary.
Declaration is not activation — declaring a vocabulary makes it available to importers;
it does not cause the declaring module to use its own vocabulary words automatically.

```
# Module: Query.Forms (declaration site)
module Query.Forms

vocabulary Query.Forms {
  # form word declarations (syntax TBD in P2)
}
```

The `vocabulary` block is the **declaration keyword**. It is module-level. It is not inside a
contract body.

### 4.2 Vocabulary Import / Use Site

A consuming module explicitly imports a vocabulary with the `speaks` keyword at module level:

```
module Consumer.Module

speaks Query.Forms
```

`speaks VocabularyPath` is the **preferred syntax**. It was evaluated and preferred in
LAB-FORM-VOCABULARY-P1 over `uses vocabulary VocabularyPath` and `form vocabulary { ... }`.
Rationale: `speaks` is semantically precise (the module can now use words from this
vocabulary), cleanly separate from the `uses` substrate keyword, and consistent with the
analogy that a vocabulary is a dialect spoken by a module. It is not too broad — it requires
explicit declaration and grants no authority.

**Syntax deferral:** The final grammar for `speaks` and `vocabulary { }` is deferred to P2
implementation planning. This proposal commits to the direction and semantics. P2 will
specify the exact parser rules.

Alternative `uses vocabulary VocabularyPath` remains acceptable if P2 finds `speaks`
requires too much parser surface relative to the `uses`-keyword extension cost.

Option C (`form vocabulary Query.Forms { ... }` at use site) is rejected: conflating
declaration and import at the use site breaks the ownership model (a consumer cannot declare
the vocabulary content; that is the owner's authority).

Option D (no source syntax) is rejected: the proposal must name the surface direction to
be actionable for P2.

### 4.3 Form Word Declaration Site

Form words are declared inside `vocabulary { }` blocks in the owning module. They reference
contracts by typed-ref. In v0, only the vocabulary owner (see Section 6, Rule V-2) may
declare form words.

Form words are **not** declared inside contract bodies. They live at the vocabulary/module
level, anchored to typed-refs.

### 4.4 No In-Contract Form Declaration

The fragment classification of a declaring contract is **unchanged** by vocabulary imports
(Rule C-6). Form vocabulary declarations are a module-level governance concern, not a
contract-body concern. This preserves the invariant that contract bodies describe data
flow, not language extension.

---

## 5. Semantics

### 5.1 Explicit Vocabulary Import

A module that does not `speaks V` cannot use form words from V. There is **no ambient leakage**
(Rule V-1). This is the single most important coherence property: form vocabulary is not
an ambient dialect injected by a transitive import. It must be declared at the module level
of each consuming module.

### 5.2 Visible Form Words

The visible form words in a module are exactly the union of form words from all explicitly
`speaks`-imported vocabularies, minus any conflicts (conflicts fire OOF-FORM3).

Selective import: if a future v1 supports `speaks Query.Forms.{submit, fetch}`, only
those words are visible. In v0, import is all-or-nothing per vocabulary.

### 5.3 Trigger Resolution

Trigger resolution is **type-directed and order-independent**:

1. At a use site, collect all form words from imported vocabularies whose trigger matches
   the surface pattern.
2. If zero candidates: OOF-FORM2 (unknown form word).
3. If one candidate: resolve to that form word's InvocationIntent target. No diagnostic.
4. If two or more candidates from different vocabularies: OOF-FORM3 (ambiguous). Fail-closed.
   The message names all contributing vocabularies. **No first-wins.**

Order-independence is proved: swapping the order of `speaks` declarations for two
non-conflicting vocabularies produces identical trigger receipts. Conflicting vocabularies
produce the same OOF-FORM3 naming both regardless of declaration order.

### 5.4 Typed-Ref Anchor Requirement

A form word without a resolved `uses T` anchor fires OOF-FORM1 at vocabulary validation time.
The anchor is required because:

1. The form must lower to an InvocationIntent over a specific contract. Without the typed-ref,
   the lowering target is undefined.
2. The anchor ensures the contract's existence is statically verified before the form word
   is considered valid.
3. TH-1 (conservativity) requires the form to reference an already-verified kernel object.

### 5.5 Lowering to InvocationIntent

Form lowering produces an InvocationIntent identical to an explicit typed-contract call:

```
FormInvocation(trigger: "submit", vocabulary: "Query.Forms", anchor: uses Query.Validator)
  ↓ lowers to
InvocationIntent(contract_name: "Validator", module_name: "Lab.TypedRef.Query",
                 args: <mapped>, execution_dependency: false)
```

The InvocationIntent is the same whether the call was written as a form invocation or as an
explicit typed-contract call. This is TH-6 (eliminability).

### 5.6 Resugaring Evidence

Every lowered form carries a ResugaringTrace:

```
{
  "surface_trigger": "submit",
  "vocabulary": "Query.Forms",
  "expanded_contract": "Lab.TypedRef.Query.Validator",
  "lowering_metadata": { "form_word_id": "...", "input_mapping": {...} }
}
```

The trace is emitted into SemanticIR (design shape defined in Section 9). It is consumed by
the debugger and by tooling (IDE completions, resugaring views). It is **evidence**, not
authority.

### 5.7 No Runtime Execution

Forms lower entirely at compile time. The runtime receives InvocationIntents. It does not
know which InvocationIntents originated from form words versus explicit calls. The resugaring
trace is a compiler artifact, not a runtime concept.

---

## 6. Coherence Rules

These rules are **normative** and promoted from the lab proofs to the proposal level.
Implementation must enforce all of them.

| Rule | Name | Description |
|------|------|-------------|
| V-1 | No ambient form words | A module can only use form words from explicitly `speaks`-imported vocabularies. Transitive imports do not make vocabulary words visible. |
| V-2 | Ownership rule | A form word for contract T may be declared only by T's declaring module or by a recognized vocabulary owner. Module-name matching alone is insufficient — ownership is checked via VocabularyOwner registry (from LAB-FORM-VOCABULARY-P1). |
| V-3 | No first-wins | When two vocabularies export form words with the same trigger for the same contract context, OOF-FORM3 fires. Import order does not break ties. |
| V-4 | Import-order independence | Trigger receipts for non-conflicting vocabulary pairs are identical regardless of the order `speaks` declarations appear. Conflicting pairs produce identical OOF-FORM3 under all orderings. |
| V-5 | Typed-ref anchor required | Every form word must have a resolved `uses T` anchor. Without it, OOF-FORM1 fires at vocabulary validation time. |
| V-6 | InvocationIntent equality | Form-lowered calls and explicit typed-contract calls produce the same InvocationIntent. `execution_dependency: false` for both. |
| V-7 | no_form propagation | If a contract T declares `no_form` (as specified in PROP-Forms-Enhanced-v0), no form word may target T. Attempting to declare one fires OOF-FORM9 at vocabulary validation time. |
| V-8 | Fragment class invariant | A module's vocabulary imports do not change the fragment class of any contract in that module. |
| V-9 | Language primitive reservation | Language primitives (`+`, `-`, `*`, `==`, etc.) may not be form triggers. Attempting to register one fires OOF-FORM7. |

Promoted from LAB-CONTRACT-FORMS-P2 coherence rules (C-1..C-7):
- C-1 = V-5 (typed-ref anchor)
- C-2 = V-2 (ownership)
- C-3 = V-3 (no first-wins)
- C-4 = V-4 (import-order independence)
- C-5 = V-7 (no_form propagation)
- C-6 = V-8 (fragment class invariant)
- C-7: MultiKeyword triggers restricted to System/Stdlib vocabulary owners in v0

---

## 7. TH Acceptance Frame

Each TH obligation from LAB-FORM-LAYER-THEORY-P1 maps to concrete rules and proof evidence.

### TH-1: Conservativity

**Claim:** Form lowering preserves fragment class and authority surface. A program with form
vocabulary produces the same execution graph, authority bindings, and fragment classifications
as the same program with all form words replaced by explicit typed-contract calls.

**Proposal-level rule:** LoweringReceipt.conservative = true. Fragment class identical before
and after lowering (V-8). Authority surface closed (Section 10, Section 11).

**Proof evidence:** LAB-FORM-INVOCATION-P1 (66/66 PASS) mechanised this for the in-module case.
TH-1 extends to the cross-module case by V-1 (no ambient words) + V-5 (anchor required) +
V-6 (InvocationIntent equality). Cross-module P2 proof required before production claim.

### TH-2: Order-Independent Resolution

**Claim:** Non-conflicting form words from different vocabularies produce identical trigger
receipts under any import ordering. Conflicting form words from different vocabularies produce
the same OOF-FORM3 diagnostic under any import ordering.

**Proposal-level rule:** V-3 + V-4 + fail-closed OOF-FORM3.

**Proof evidence:** LAB-FORM-VOCABULARY-P1 (61/61 PASS) mechanised this for the explicit
vocabulary model. Conditional on OOF-REF2 substrate — now unconditional (P5 closed).

### TH-3: Stable Grammar Skeleton

**Claim:** Form vocabulary import adds form words over existing FormKind productions. It
never adds new grammar productions. The grammar skeleton is fixed.

**Proposal-level rule:** `vocabulary { }` declarations and `speaks` imports are parsed into
existing syntactic positions. FormKind ×7 (from `form_registry.rs`) is the complete v0 set
and is not extensible by user vocabularies.

**Proof evidence:** Confirmed by design in LAB-CONTRACT-FORMS-P2.

### TH-4: Hygiene

**Claim:** Form words cannot shadow language primitives. Structural validity rules catch
malformed form declarations before they affect compilation.

**Proposal-level rule:** V-9 (primitive reservation) + F-01..F-06 fail-closed rules (from
`PROP-Forms-Enhanced-v0`, promoted here). OOF-FORM7 fires for primitive shadow attempts.

**Proof evidence:** LAB-FORM-INVOCATION-P1 mechanised F-01/02/03/05. F-04/F-06 carry forward.
H2 invariant from `form_resolver.rs` promoted to V-9.

### TH-5: Resugaring / Debuggability

**Claim:** Every lowered form carries ResugaringTrace with surface trigger, expanded contract,
and lowering metadata. The SemanticIR preserves both the form-level and kernel-level view.

**Proposal-level rule:** ResugaringTrace is mandatory for all form lowerings. It enters
SemanticIR via the `form_resolutions` structure (Section 9). It does not execute at runtime.

**Proof evidence:** LAB-FORM-INVOCATION-P1 demonstrated ResugaringTrace carrying
surface trigger + expanded contract + lowering metadata (TH-5 demonstrated).

### TH-6: Eliminability

**Claim:** Forms add abbreviation power, not expressive power (Felleisen eliminability).
Any program with form words has an equivalent program without form words that produces
identical InvocationIntents and an identical execution graph.

**Proposal-level rule:** V-6 (InvocationIntent equality). Form lowering is a mechanical
substitution, not an authority grant.

**Proof evidence:** LAB-FORM-INVOCATION-P1 mechanised: explicit InvocationIntent == form-lowered
InvocationIntent (same target, same args, same execution_dependency: false).

---

## 8. Diagnostics: OOF-FORM Namespace

The `OOF-FORM` namespace is **reserved** by this proposal. Exact message text is deferred to
P2 implementation planning.

| Code | Name | Trigger |
|------|------|---------|
| OOF-FORM1 | missing-typed-ref-anchor | A form word references a contract T but the declaring module has no resolved `uses T` declaration |
| OOF-FORM2 | unknown-form-word | A trigger appears at a use site but matches no form word in any `speaks`-imported vocabulary |
| OOF-FORM3 | ambiguous-form-word | Two or more vocabularies in scope export form words with the same trigger; fail-closed, names all contributing vocabularies |
| OOF-FORM4 | invalid-form-owner | A form word for contract T is declared by a module that neither owns T nor is a recognized vocabulary owner |
| OOF-FORM5 | invalid-input-mapping | A form word's input mapping is incomplete, maps to a non-existent input, or produces an ill-typed argument |
| OOF-FORM6 | non-conservative-lowering | A form word's lowering changes the fragment class or authority surface of the declaring contract |
| OOF-FORM7 | hygiene-violation | A form word's trigger is a reserved language primitive or keyword |
| OOF-FORM8 | unknown-vocabulary | A `speaks VocPath` import names a vocabulary not present in the compilation unit |
| OOF-FORM9 | duplicate-form-word | Two form words in the same vocabulary declare the same trigger (vocabulary-internal conflict) |

OOF-FORM10+ are reserved for future extensions. The namespace is distinct from:
- `OOF-REF*` (typed-ref resolution)
- `OOF-IMP*` (import resolution)
- `OOF-M*` (module/modifier)
- `OOF-EP*` (entrypoint)

---

## 9. SemanticIR / Manifest Design Shapes

**These are design-only.** No implementation is authorized. Shapes are defined here to inform
P2 planning and to ensure the vocabulary model is compatible with the existing SIR/manifest
architecture.

### 9.1 SemanticIR Extensions

```json
{
  "form_vocabularies": [
    {
      "vocabulary_name": "Query.Forms",
      "source_module": "Lab.TypedRef.Query",
      "form_words": [
        {
          "word_id": "query.forms.submit.v0",
          "trigger": "submit",
          "kind": "Keyword",
          "contract_name": "Validator",
          "module_name": "Lab.TypedRef.Query",
          "priority": 0,
          "input_mapping": { "value": "input.data" }
        }
      ]
    }
  ],
  "form_resolutions": [
    {
      "site_id": "contract:Consumer.method:compute:node:3",
      "word_id": "query.forms.submit.v0",
      "trigger": "submit",
      "contract_name": "Validator",
      "module_name": "Lab.TypedRef.Query",
      "resolution_kind": "vocabulary_word",
      "lowered_from_form": true,
      "resugaring_trace": {
        "surface_trigger": "submit",
        "vocabulary": "Query.Forms",
        "expanded_contract": "Lab.TypedRef.Query.Validator",
        "lowering_metadata": {}
      }
    }
  ]
}
```

Key design decisions:
- `form_vocabularies` is a top-level SIR field (not nested under a contract)
- `form_resolutions` is also top-level — it maps use sites to resolved form words
- `lowered_from_form: true` is a flag on the InvocationIntent node (not a separate node kind)
- The resugaring trace carries enough information to reconstruct the surface view
- All form content enters the artifact hash via SIR material (existing hash discipline applies)

### 9.2 Manifest Extensions

The existing `dependency_edges` field is **not extended** for form words. Form words lower to
InvocationIntents before manifest assembly; manifest edges represent contract-level dependencies
after lowering. A form-lowered call produces the same edge as an explicit call.

A new manifest field `form_vocabulary_imports` may be added as metadata (not dependency data):

```json
{
  "form_vocabulary_imports": [
    { "module": "Consumer.Module", "vocabulary": "Query.Forms", "source_module": "Lab.TypedRef.Query" }
  ]
}
```

This is informational. It does not affect artifact hash beyond its content.

---

## 10. Import / Package Interaction

### Vocabulary import is not module import

`speaks Query.Forms` imports form words from the `Query.Forms` vocabulary. It does **not**:
- Import any module (`import Lab.TypedRef.Query` is a separate declaration)
- Grant access to any contract in `Lab.TypedRef.Query` beyond what typed-refs already provide
- Create a package dependency in any distribution sense
- Open any visibility surface

The vocabulary substrate requires a typed-ref (`uses T`). The typed-ref requires that the
module containing T is in the compilation unit (via `import` or direct inclusion). Vocabulary
import builds on top of this, adding form words over an already-resolved typed-ref — it does
not bypass the typed-ref requirement.

### Package distribution remains closed

Vocabulary distribution (how vocabularies are packaged, versioned, and distributed) is
deferred. This proposal defines vocabulary identity by module path only. Package management,
semver, and registry authority are explicitly out of scope.

### Visibility remains unchanged

`speaks` does not affect the visibility of any module's contracts. It affects only which
form words are usable in the consuming module.

---

## 11. Runtime Boundary

Forms lower **entirely at compile time**. The following explicit boundary applies:

| Item | Status |
|------|--------|
| Form words visible to runtime | NO |
| InvocationIntents visible to runtime | YES |
| Forms execute contracts | NO |
| Forms grant capability / profile | NO |
| Forms create scheduler / runtime edges | NO |
| Forms change execution graph | NO (TH-6 eliminability) |
| ResugaringTrace visible to runtime | NO (compiler evidence only) |
| form_resolutions visible to runtime | NO (SIR-level; not lowered to VM) |
| `no_form` enforcement at runtime | NO (compile-time only) |

The runtime receives the same InvocationIntents regardless of whether the source used form
words or explicit typed-contract calls. This is the mechanisation of TH-6 and the foundation
of TH-1.

---

## 12. Rust Orphan Lineage Classification

This section classifies the fate of each orphaned artifact from the `form_registry.rs` /
`form_resolver.rs` / `PROP-Forms-Enhanced-v0` lineage. The SPLIT+KEEP decision from
LAB-CONTRACT-FORMS-P2 stands.

| Artifact | Decision | Notes |
|----------|----------|-------|
| `form_registry.rs` | KEEP (lab reference) | Complete lab implementation; coherence rules correct; superseded by canon governance once P2 planning is done; do not delete or retire |
| `form_resolver.rs` | KEEP (lab reference) | Type-directed resolution logic is sound; H2 invariant (language primitives bypass) promoted to V-9 here; key algorithms inform P2 |
| `FormEntry` struct | KEEP design vocabulary | Maps to form word declaration shape; `priority` field carries forward; `trust_level` is deferred |
| FormKind ×7 | KEEP as v0 set | 7 FormKind variants are the complete v0 extension surface; user vocabularies cannot add new FormKind variants |
| `form_resolution_trace.json` artifact | KEEP concept | Promoted to `form_resolutions` in SIR + `resugaring_trace` per resolution; trace.json as a separate file is deferred |
| F-01..F-06 fail-closed rules | KEEP, all promoted | F-01 (trigger non-empty), F-02 (contract exists), F-03 (no keyword shadow), F-04 (no duplicate in same vocabulary), F-05 (input mapping valid), F-06 (lowering conservative); maps to OOF-FORM namespace |
| `PROP-Forms-Enhanced-v0` claims | KEEP SELECTIVELY | Core form word semantics and structural rules kept; AccumulatorRef deferred; form inheritance (`FormShape`) deferred to post-P1 |
| MultiKeywordForm (7th FormKind) | KEEP, restricted | C-7 applies: restricted to System/Stdlib vocabulary owners in v0; not available to user vocabularies |
| `AccumulatorRef` | DEFERRED | Requires PROP-002 composition algebra; not P1 scope |
| FormShape inheritance | DEFERRED | Non-trivial ownership semantics; deferred to post-P1 |
| E-FORM-AMBIG, E-FORM-UNRESOLVED | PROMOTED | Mapped to OOF-FORM3 and OOF-FORM2 respectively |
| E-FORM-NOFM-MATCH | PROMOTED | Mapped to `no_form` enforcement under OOF-FORM9 (vocabulary-time) |
| Two-phase compiler mapping | KEPT as design reference | Informs P2 implementation planning for vocabulary validation + lowering phase separation |

---

## 13. Non-Goals

The following are **explicitly excluded** from this proposal and all its direct descendants
unless separately authorized:

1. **Full macro system.** Form vocabularies cannot introduce new grammar productions, rewrite
   AST nodes, or inject declarations. They are conservative elaboration, not macro authority.

2. **Arbitrary grammar extension.** The grammar skeleton is fixed (TH-3). FormKind ×7 is the
   v0 extension point. User vocabularies cannot extend FormKind.

3. **Runtime plugins.** Form words lower at compile time. There is no runtime plugin interface.

4. **Package registry.** Vocabulary distribution is deferred. No semver, no registry, no package
   manager authority is opened.

5. **UI / View form unification.** View/UI forms (the view-DSL exploration) may eventually use
   form vocabulary as a substrate, but this is a separate track. Not P1 scope.

6. **Gap-I Form Constructor implementation.** The Covenant P27/P28 value-construction form is
   a distinct feature. This proposal does not address it. The two tracks share the word "form"
   but have orthogonal semantics.

7. **`call_contract` replacement.** `call_contract` remains the existing stringly-typed call
   mechanism. Form vocabularies provide a typed alternative but do not deprecate or remove
   `call_contract`.

8. **Transitive vocabulary import.** `speaks A` does not make A's vocabulary imports visible.
   Each module must explicitly `speaks` each vocabulary it uses (V-1).

9. **Formal proof obligation (Lean/Agda).** Lab proofs at the Ruby/proof-local level are
   sufficient. No formal theorem prover obligation is created.

---

## 14. Required Explicit Answers

The card specified 13 questions that must be answered explicitly.

**Q1: Is source syntax chosen in P1?**
Direction chosen: `speaks VocabularyPath` at module level (preferred) with `uses vocabulary VocabularyPath` as acceptable alternative. Final grammar deferred to P2. Rationale: LAB-FORM-VOCABULARY-P1 evaluated all candidates; `speaks` was preferred. P1 commits to the direction; P2 specifies the parser rules.

**Q2: Is vocabulary module-level or contract-level?**
Module-level. Vocabulary declarations (`vocabulary { }`) and vocabulary imports (`speaks`) are both module-level. Form words reference contracts via typed-refs but are not declared inside contract bodies. Fragment class invariant (V-8) is maintained.

**Q3: Is `speaks` acceptable or too broad?**
Acceptable and preferred. `speaks` is semantically precise (a module "speaks" a vocabulary), is not already in the parser keyword set (no ambiguity), and grants no authority. It is not too broad: it requires explicit declaration, grants no module access, and does not leak vocabulary words to transitive importers (V-1).

**Q4: Are form words imported explicitly?**
Yes. A module must `speaks V` to use form words from vocabulary V. No ambient leakage (V-1). No transitive visibility.

**Q5: Can two vocabularies define the same word?**
Yes. Two vocabularies may both define form words with the same trigger. When a module imports both, OOF-FORM3 (ambiguous form word) fires at the use site. Fail-closed. No first-wins (V-3). The consuming module must qualify or choose one vocabulary.

**Q6: Who may define a form word for contract T?**
The module that declares T (T's owning module), or a recognized vocabulary owner (a module explicitly granted vocabulary ownership via the VocabularyOwner registry). Module-name matching alone is insufficient (V-2, from LAB-FORM-VOCABULARY-P1). This is the Rust orphan rule analogue for form vocabularies.

**Q7: Does form vocabulary require `uses T`?**
Yes. Every form word must be anchored to a resolved `uses T` declaration (V-5 = C-1). Without this, OOF-FORM1 fires. There are no exceptions.

**Q8: Does form resolution affect fragment classification?**
No. Fragment class of the declaring contract is unchanged by vocabulary imports or form word resolution (V-8 = C-6).

**Q9: Does form resolution create execution dependency?**
No. Form lowering produces InvocationIntent with `execution_dependency: false` — the same as an explicit typed-contract call. Forms do not create scheduler edges or runtime authority (Section 11).

**Q10: Does form lowering enter artifact hash?**
Yes. Form vocabulary content enters the artifact hash via SemanticIR material. `form_vocabularies` and `form_resolutions` in the SIR are part of the program identity. A program with different vocabulary imports (even if the execution graph is identical) produces a different artifact hash.

**Q11: Does runtime know forms?**
No. The runtime receives InvocationIntents only. Form words, triggers, vocabulary names, and ResugaringTraces are compile-time concepts. The runtime cannot distinguish a form-lowered call from an explicit call (TH-6 eliminability).

**Q12: Does this obsolete Gap-I Form Constructor?**
No. Gap-I Form Constructor (Covenant P27/P28) is value construction. This proposal is about invocation forms. The two are orthogonal tracks. Neither obsoletes the other.

**Q13: Does this obsolete view/UI forms?**
No. View/UI forms are a separate domain. They may eventually consume form vocabulary as a substrate (if/when authorized separately), but this proposal does not address them and does not obsolete any view/UI form work.

---

## 15. Next Route

**LANG-FORM-VOCABULARY-PROP-P2 — Implementation Planning**

The substrate gates are satisfied:
- LANG-TYPED-CONTRACT-REF-PROP-P5 (71/71 PASS): cross-module typed-ref substrate live
- PROP-IMPORT-RESOLUTION-P5 (99/99 PASS): multifile import resolution live
- LAB-FORM-VOCABULARY-P1 (61/61 PASS): coherence model proved (TH-2 now unconditional)
- LAB-FORM-INVOCATION-P1 (66/66 PASS): in-module TH-1/4/6 proved

P2 should plan implementation of:
1. Parser: `speaks VocabularyPath` module-level keyword; `vocabulary { }` declaration block
2. Classifier: vocabulary import records; form word collection
3. TypeChecker: vocabulary validation (V-1..V-9 enforcement); trigger resolution; OOF-FORM* diagnostics
4. SemanticIR emitter: `form_vocabularies`, `form_resolutions`, `resugaring_trace`
5. Assembler: `form_vocabulary_imports` manifest field

P2 must specify the proof matrix. Suggested target: ≥50 checks across 8 sections
(A: regression, B: vocabulary declaration, C: speaks import, D: trigger resolution,
E: ambiguity, F: ownership, G: SIR shape, H: authority).

P2 does not authorize public syntax activation or production deployment.

---

## 16. Acceptance Criteria

This P1 proposal closes if:

- [x] Vocabulary is clearly separated from macro/runtime/import/package
- [x] TH-1..TH-6 are mapped to concrete rules and proof evidence
- [x] OOF-FORM namespace (OOF-FORM1..OOF-FORM9) is reserved and specified
- [x] Cross-module typed-ref substrate from P5 is incorporated
- [x] Next route (LANG-FORM-VOCABULARY-PROP-P2) is concrete with known gate conditions
- [x] All 13 required explicit answers are provided
- [x] All closed surfaces remain closed (no implementation authorized)
- [x] Rust orphan lineage classified

**Status: CLOSED / PROPOSAL AUTHORED**
