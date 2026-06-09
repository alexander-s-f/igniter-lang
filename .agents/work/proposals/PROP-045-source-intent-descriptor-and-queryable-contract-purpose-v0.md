# PROP-045: Source-Level `intent` Descriptor and Queryable Contract Purpose

**PROP:** 045  
**Track:** source-intent-descriptor-and-queryable-contract-purpose-v0  
**Status:** proposal-authoring (P1 authored 2026-06-09)  
**Depends on:** docs/language-covenant.md (Axiom 1, Axiom 2, Postulate 7), PROP-033 (profile binding), PROP-040 (profile declarations / CR-003), PROP-044-P1 (KDR convention), LAB-RESULT-ENVELOPE-P2, LAB-QUERY-P1  
**Author:** Portfolio Architect Supervisor  
**Gate route:** proposal-authoring (P1) → parser implementation (P2, explicit auth required) → SemanticIR/manifest integration (P3+)

---

## Core Formula

```
intent  = declared purpose metadata
intent ≠ behavior guarantee
intent ≠ capability
intent ≠ proof
intent ≠ policy
intent ≠ runtime effect
```

This formula is binding throughout the design. Every decision below must be
consistent with it.

---

## 1. Motivation

### 1.1 Comments are not enough

Comments serve human readers of source code. They do not serve:

| Consumer | Comments | `intent` |
|----------|----------|---------|
| Human reader | ✅ readable | ✅ readable |
| Compiler IR | ❌ stripped | ✅ preserved |
| Agent contract discovery | ❌ not queryable | ✅ queryable |
| IDE search index | ❌ not structured | ✅ structured |
| `.igapp` manifest | ❌ absent | ✅ present |
| Docs generation pipeline | ❌ unreliable | ✅ reliable |
| Audit receipt / manifest | ❌ absent | ✅ present |

A comment on a contract answers "what does this code do?" only for a human
reading that exact source file. It is stripped from the AST before IR emission,
invisible to agents querying contract metadata, absent from manifests, and
unavailable at docs-generation time.

### 1.2 Igniter is a language for humans and agents

Igniter source artifacts must be able to answer the following questions from
outside the source file:

- **"What is this contract's purpose?"** — agent discovery, IDE tooltip
- **"What should this contract be used for?"** — safe selection guidance
- **"What should this contract not be used for?"** — boundary enforcement guidance
- **"What domain does this module cover?"** — module browsing, docs indexing

None of these questions can be answered reliably with comments.

### 1.3 Covenant grounding

**Axiom 1 — Honesty:**
> A program is an honest account of what it does to the world.

If the program cannot say *what it intends to do* in a queryable, durable form,
it cannot be fully honest. Intent text is the source-level declaration of purpose
that makes honesty legible outside the compile context.

**Axiom 2 — Accountability:**
> Every language primitive exists to make accountability legible.

An auditor, agent, or operator reading a manifest entry for a deployed contract
should see its declared purpose alongside its effect surface and profile binding.
`intent` makes that possible.

**Postulate 7 — No Hidden Consequences:**
> A reader who reads only the contract header knows the full consequence.

Intent is part of the header-visible metadata. It extends Postulate 7 from
behavioral consequence (what it does) to purpose consequence (why it exists).

### 1.4 Why not `description`?

`description` is already used as an optional field name inside `profile`
declarations (PROP-040 §2):

```igniter
profile payments_profile {
  authority:    effect
  description: "Production payment processing profile"
}
```

Using `description` as a keyword would conflict with this established field
name and introduce parsing ambiguity inside profile bodies. `intent` is chosen
instead: it aligns with the Covenant's language ("declared intent", "honest
account"), with PROP-033's language ("source-level declaration intent"), and
with the core formula above.

---

## 2. Design: Keyword and Shape

### 2.1 Keyword: `intent`

```igniter
intent "validate an email address format; does not check delivery"
```

Single keyword, single string literal, standalone declaration. No colon, no
struct body, no sub-keys in v0.

### 2.2 v0 shape: bounded plain string

- One `intent` declaration per declaration site (module or contract)
- String literal only — no interpolation, no multi-line heredocs in v0
- Maximum length: 500 characters (enforced as OOF-INTENT1 advisory warning)
- No markdown execution semantics
- No embedded structured fields in v0
- Secrets detection: advisory warning for patterns matching known secret shapes
  (OOF-INTENT2)
- Optional everywhere in v0

The 500-character limit is advisory in v0. The rationale: intent text should be
a concise statement of purpose, not a documentation chapter. Length enforcement
defers to lint tooling; the compiler warns, does not error.

### 2.3 v1 extension sketch (not this proposal)

Structured fields are deferred to v1:

```igniter
-- (future grammar — not currently parseable)
intent {
  does      "charge a customer's payment method"
  does_not  "validate card details; does not hold funds"
  audience  "payment processing agents"
  domain    "payments"
}
```

This requires a new parser production for the structured intent body. It is
**deferred entirely** — no design commitment made here for structured shape.

---

## 3. Placement

### 3.1 v0 allowed sites

**a) Module/file level** — after the `module` declaration, before imports:

```igniter
module Payments.Contracts
intent "payment authorization and charge contracts for e-commerce order flow"

import Payments.Types
```

**b) Contract level** — first `BodyDecl` in a contract body (before `input`):

```igniter
pure contract ValidateEmailFormat {
  intent "check that an email string matches RFC-5322 format; does not verify delivery"
  input  email  : String
  compute valid = ...
  output result : Bool
}
```

Placement inside the contract body is consistent with other header-like
`BodyDecl` forms (e.g., `escape` modifier declarations, `assumptions` blocks).
The `intent` declaration is valid in any position within the contract body, but
by convention it is placed first.

**c) With `via` profile binding** — intent and profile binding are orthogonal
and may both appear:

```igniter
effect contract ChargeCustomer via payments_profile {
  intent "charge a customer's card for a completed order; irreversible after settlement"
  capability charge_cap: IO.NetworkCapability
  effect charge using charge_cap
  input  order_id : String
  input  amount   : Decimal[2]
  output receipt  : ChargeReceipt
}
```

### 3.2 v0 deferred sites

| Site | Status | Reason |
|------|--------|--------|
| `type` declarations | ❌ Deferred v1 | Types describe data, not purpose; lower-priority |
| `output` declarations | ❌ Deferred v1 | Contract-level intent covers outputs sufficiently |
| `input` declarations | ❌ Deferred v1 | Contract-level intent covers inputs sufficiently |
| `trait` / `impl` blocks | ❌ Deferred v1 | Trait semantics separate concern |
| Function declarations | ❌ Deferred v1 | Functions less common than contracts in Igniter v0 |

### 3.3 EBNF additions (design only — no parser changes authorized)

**Module-level placement:**

```ebnf
SourceFile  ::= ModuleDecl? IntentDecl? ImportDecl* TopDecl*
IntentDecl  ::= "intent" StringLiteral
```

The module-level `IntentDecl` is positioned immediately after the optional
`ModuleDecl` and before any imports.

**Contract-level placement:**

```ebnf
BodyDecl    ::= EscapeDecl | InputDecl | ReadDecl | ComputeDecl
              | SnapshotDecl | WindowDecl | OutputDecl | IntentDecl   -- NEW
```

`IntentDecl` is a new `BodyDecl` variant. The parser accepts it anywhere a
`BodyDecl` appears; the typechecker enforces that at most one appears per
contract (OOF-INTENT3 on duplicate).

**Parse AST:**

```json
{ "kind": "intent", "text": "validate an email address format" }
```

At the top-level program node: `{ "kind": "intent", "text": "..." }` alongside
`ModuleDecl` metadata.

At the contract level: the `intent` node appears in the contract's body list
with `kind: "intent"`.

---

## 4. Syntax / Placement Options Matrix

| Option | v0 decision | Rationale |
|--------|-------------|-----------|
| Keyword: `intent` | ✅ Selected | Covenant-aligned; avoids `description` conflict |
| Keyword: `purpose` | — | Acceptable alternative; less Covenant-specific |
| Keyword: `about` | — | Too casual; could be confused with `description` |
| Keyword: `summary` | — | Implies condensing a longer text, not declaration |
| Keyword: `description` | ❌ Rejected | Conflicts with PROP-040 profile field name |
| Single plain string | ✅ Selected | Minimal complexity; sufficient for v0 |
| Structured fields | ❌ Deferred v1 | Requires larger parser surface; no proven need yet |
| Multiple intent lines | ❌ Rejected | OOF-INTENT3 on duplicate; one intent per site |
| Module-level placement | ✅ Selected | Module discovery; docs index; manifest |
| Contract-level placement | ✅ Selected | Primary use case |
| Type-level placement | ❌ Deferred v1 | Lower priority; types are data, not purpose |
| Required everywhere | ❌ Optional in v0 | Mandatory intent deferred to a later PROP |
| Interpolation allowed | ❌ Rejected | No runtime value in metadata string |
| Markdown rendering | ❌ Rejected | Metadata, not documentation; no execution semantics |

---

## 5. Metadata Preservation Matrix

Where does `intent` text travel once declared?

| Destination | v0 status | Notes |
|-------------|-----------|-------|
| Parser AST | ✅ YES | `{ "kind": "intent", "text": "..." }` node |
| Classifier output | ✅ YES | Passed through unchanged |
| TypeChecker output (typed_contract_ir) | ✅ YES | `intent_text` field on contract metadata |
| SemanticIR (contract_ir) | ✅ YES | `intent_text: String | null` in `contract_ir` |
| Module-level program IR | ✅ YES | `intent_text` in module metadata node |
| `.igapp` manifest (metadata section) | ✅ YES | Listed under non-behavioral contract metadata |
| IDE search index | ✅ YES (by convention) | Intent text queryable for contract discovery |
| Agent contract index | ✅ YES (by convention) | Primary motivation; enables discovery queries |
| Docs generation pipeline | ✅ YES (by convention) | Rendered as purpose statement in contract docs |
| Behavior digest / semantic hash | ❌ NO | Intent text does not affect behavioral semantics |
| Bytecode / VM instruction | ❌ NO | No runtime presence |
| Receipt / runtime audit trail | ❌ NO | Runtime behavior only; intent is compile-time |
| Capability grant surface | ❌ NEVER | `intent` cannot create authority |

The critical distinction: `intent` is in the **source metadata digest** (what
the contract says about itself), not the **behavior digest** (what the contract
actually does). These are separate hash surfaces.

---

## 6. Digest / Compatibility Matrix

How does `intent` interact with change tracking and compatibility?

| Change type | Behavioral compatibility | Docs/metadata compatibility | Notes |
|-------------|------------------------|----------------------------|-------|
| Add `intent` where absent | No change | Minor metadata change | New field; compatible |
| Update intent text | No change | Documentation update | Not a breaking change |
| Remove `intent` | No change | Documentation regression | Not a breaking change |
| Change `input` declaration | Breaking (type change) | Intent unchanged | Behavioral change |
| Change `output` type | Breaking | Intent unchanged | Behavioral change |
| Change intent + change behavior | Breaking (behavior change) | Both change | Breaking driven by behavior |

**Rule:** Intent text changes do not affect behavioral compatibility versioning.
A semver patch or minor version bump may include intent text corrections.
Intent text alone never forces a major version bump.

**Implication for semantic diffing:** A diff tool checking behavioral
compatibility should skip the `intent_text` field. It belongs to the
documentation diff, not the breaking-change diff.

---

## 7. Authority and Closed-Surface Matrix

This matrix explicitly answers what `intent` can and cannot do.

| Authority surface | `intent` status | Reason |
|------------------|----------------|--------|
| Capability grants | ❌ NEVER | Capabilities come from PROP-035/038/040 profiles |
| Policy validation | ❌ NEVER | Policy comes from profile declarations (PROP-040) |
| Effect modifier | ❌ NEVER | Effect modifiers come from PROP-031 |
| Semantic proof | ❌ NEVER | Proof comes from type-checked body; not from metadata |
| Runtime effects | ❌ NEVER | Intent is compile-time metadata; no bytecode |
| Compile blocking | ❌ NOT IN v0 | Absence never blocks; malformed is advisory only |
| Behavioral compatibility | ❌ NO | Intent is not part of the behavior digest |
| Requirement for public contracts | ❌ Not in v0 | Optional; may become required in later PROP |
| AI-generated intent as verified truth | ❌ NEVER | Agent-generated intent is a suggestion only |
| Canon behavior authority | ❌ NEVER | Lab artifacts with intent remain lab-only |

---

## 8. Relationship to Existing Constructs

### 8.1 CR-003 and `profile_binding`

CR-003 (closed by PROP-040) was a conformance note:

> Profile binding is intent record only — not validated authority until PROP-040 OOF-M7/M8 active.

The word "intent" in CR-003 referred to `profile_binding` being a *declaration
of intent to bind a profile* — a statement that the compiler records but does
not immediately validate. This is a narrow, specific use of the word "intent"
for one field in one context.

PROP-045 `intent` is a **general-purpose purpose metadata string** for any
contract or module. The two are **orthogonal**:

| | `profile_binding` (CR-003/PROP-040) | `intent` (PROP-045) |
|-|--------------------------------------|---------------------|
| Declares | Which profile the contract binds to | What the contract does |
| Validated | Yes (OOF-M7/M8 active, PROP-040) | Advisory only in v0 |
| Authority | Profile authority chain | None |
| Content | Profile name identifier | Human-readable purpose string |

**CR-003 does not cover the general case.** PROP-045 is a new surface.

### 8.2 Comments

Comments and `intent` serve different purposes and co-exist:

| | Comments (`--`) | `intent` |
|-|----------------|----------|
| Audience | Human reading source | Agents, IDE, docs, manifests, humans |
| Preserved in IR | ❌ No | ✅ Yes |
| Queryable | ❌ No | ✅ Yes |
| Structured | ❌ No | Optional (v1) |
| Location | Anywhere | Module header + contract body |
| Convention | Explain "how" | Declare "why" / "what for" |

Comments remain valid and valuable for explaining implementation details,
algorithm choices, and in-body logic. `intent` replaces only the "what is this
for?" function of comments at the declaration level.

### 8.3 PROP-044 Kind-Discriminated Records

Intent can usefully describe outcome-producing contracts:

```igniter
pure contract ValidationRouter {
  intent "route a ValidationResult to one of four deterministic actions; denial-as-data"
  input  outcome : ValidationResult
  compute action = ...
  output action  : String
}
```

`intent` describes the contract's purpose. It does not define the variant
vocabulary, the kind values, or the routing logic. PROP-044 and PROP-045 are
independent and complementary.

### 8.4 LAB-QUERY-P1/P2 patterns

The QueryPlan contracts from LAB-QUERY-P1/P2 are a natural use case:

```igniter
pure contract BuildFilteredQuery {
  intent "construct a filtered QueryPlan from a source, projection, and predicate list"
  input source     : QuerySource
  input projection : Projection
  input filters    : Collection[FilterPredicate]
  ...
}
```

Agent-assisted query builder discovery becomes possible when each contract
declares what it builds or transforms.

### 8.5 LAB-RESULT-ENVELOPE patterns

Denial-as-data contracts benefit directly:

```igniter
pure contract UnauthorizedSubmission {
  intent "produce a denial ValidationResult; deterministic; retrying will not help"
  input  reason   : String
  input  metadata : Map[String, String]
  compute result  = { field: "", kind: "unauthorized", message: reason, metadata: metadata }
  output result   : ValidationResult
}
```

The intent text here conveys the retry semantics of the denial — information
that could not be inferred from the type alone.

---

## 9. Explicit Answers

| Question | Answer |
|----------|--------|
| Should a general source-level `intent` descriptor open? | **YES** — unmet need; comments insufficient; covenant-aligned |
| Does CR-003 already cover this? | **NO** — CR-003/PROP-040 `profile_binding` is about *which profile* to bind; PROP-045 is about *what the contract does* |
| Should `intent` be a keyword or metadata field? | **Keyword** — `intent "..."` as a standalone declaration, not a key-value field in a block |
| Is contract-level intent enough for v0? | **Contract-level alone is sufficient** for the primary use case; module-level adds important discovery capability and is recommended for v0 |
| Is module/file-level intent needed for v0? | **YES** — module-level discovery is the second most important use case; agents and docs pipelines need module-level purpose statements |
| Should intent affect behavioral compatibility? | **NO** — intent is metadata only; it does not enter the behavior digest |
| Should intent be queryable from SemanticIR / metadata? | **YES** — `intent_text` field in contract_ir; primary reason for the feature |
| Can intent create capability/policy/runtime authority? | **NEVER** |
| Should intent mismatch block compile? | **NO in v0** — advisory only; a future lint PROP may introduce OOF-INTENT-MISMATCH |
| May production implementation open next? | **NO** — P2 (parser implementation) requires explicit authorization |
| Exact P2 recommendation? | **Parser implementation card** — see §10 |

---

## 10. OOF-INTENT Codes (Candidates — Not Active)

These diagnostic codes would become active when parser implementation is
authorized. They are registered here to reserve the namespace.

| Code | Condition | Severity |
|------|-----------|----------|
| OOF-INTENT1 | Intent text exceeds 500 characters | Advisory warning (does not block compile) |
| OOF-INTENT2 | Intent text contains a potential secret pattern (token-shaped strings, `key=`, `password`, `Bearer `, etc.) | Advisory warning — never a hard error |
| OOF-INTENT3 | More than one `intent` declaration on the same contract or module | Error — first one wins; subsequent ones are rejected |
| OOF-INTENT4 | `intent` appears in a context not yet supported (e.g., type declaration in v0) | Advisory warning |

All four codes are candidates — not active until P2.

---

## 11. SemanticIR Integration (Design Only)

### 11.1 Contract IR

The `contract_ir` object (produced by the SemanticIR emitter) would gain an
optional `intent_text` field:

```json
{
  "modifier":       "pure",
  "name":           "ValidateEmailFormat",
  "profile_binding": null,
  "intent_text":    "check that an email string matches RFC-5322 format",
  "inputs":         [...],
  "outputs":        [...],
  "compute_nodes":  [...]
}
```

`intent_text` is `null` when no `intent` declaration is present. This mirrors
the existing `profile_binding` field (also optional, also `null` when absent).

### 11.2 Program-level metadata

At the program IR root, module-level intent appears in a metadata section:

```json
{
  "module":       "Payments.Contracts",
  "intent_text":  "payment authorization and charge contracts for e-commerce order flow",
  "contracts":    [...],
  "types":        [...]
}
```

### 11.3 Pipeline propagation

The same four-stage pattern as PROP-033 (`profile_binding`) and PROP-040:

```
Parser         → intent node in AST (kind: "intent", text: "...")
Classifier     → passes through unchanged; validates no duplicate
TypeChecker    → copies to typed_contract_ir as intent_text
SemanticIR     → emits intent_text in contract_ir; module_intent_text in program IR
```

No new validation logic beyond OOF-INTENT3 (duplicate) is needed in v0.

---

## 12. P2 Recommendation

**Authorized next step: PROP-045-P2 — Parser Implementation**

Route: IMPLEMENTATION  
Scope:
- Add `intent` to the keyword table
- Add `parse_intent_decl` method (trivial: `expect :keyword "intent"`, then `parse_string_lit`)
- Add `IntentDecl` arm to `parse_body_decl`
- Add module-level `IntentDecl` handling in `parse_source_file`
- Propagate through all four pipeline stages (parse → classify → typecheck → emit)
- Add `intent_text` field to `contract_ir` schema
- Activate OOF-INTENT3 (duplicate — classifier level)
- OOF-INTENT1 and OOF-INTENT2 are advisory; activate as advisory warnings

**Complexity:** Low. Intent parsing is simpler than profile binding — it's a
single string, no sub-structure, no validation against external declarations.
It mirrors the existing `parse_output_decl` / `parse_input_decl` pattern.

**Blocker:** Explicit card authorization required.

---

## 13. Gap Packet

```
proof:          source-intent-descriptor / v0
status:         proposal-authoring (P1 authored 2026-06-09)
authority:      proposal-only / no-production-impl

design:
  keyword:        `intent`
  shape:          bounded plain string (500 char advisory limit)
  placement_v0:   module/file level + contract body (BodyDecl)
  placement_v1:   type / output / input declarations (deferred)
  required:       optional in v0
  queryable:      YES — intent_text in contract_ir
  behavior_digest: NO — metadata only
  capability:     NEVER
  policy:         NEVER
  runtime:        NEVER

oof_intent:
  OOF-INTENT1: text too long (advisory warning) — candidate
  OOF-INTENT2: secret pattern detected (advisory warning) — candidate
  OOF-INTENT3: duplicate intent on same site (error) — candidate
  OOF-INTENT4: intent in unsupported site (advisory) — candidate

cr003:    CLOSED by PROP-040; not the same surface as PROP-045
prop033:  via profile_binding is orthogonal — which profile vs what purpose
prop044:  KDR convention and intent are complementary, not overlapping

next_authorized:
  immediate:    convention use (intent text as comments in lab code)
  P2 (explicit auth): parser implementation + pipeline propagation
  P3 (explicit auth): manifest integration; SemanticIR schema update
  future PROP:  OOF-INTENT-MISMATCH lint (intent vs effect surface diff)
  future PROP:  required intent for exported contracts
  future PROP:  structured intent fields (does/does_not/audience/domain)
```

---

## 14. Authority Statement

This document is a **proposal / design boundary only**. It authorizes:

- `intent` as a convention in lab code (comment-style, no enforcement)
- Referencing this design when authoring P2 parser cards

It does not authorize:

- Parser changes (`intent` keyword, `parse_intent_decl`)
- Typechecker changes (`intent_text` field propagation)
- SemanticIR emitter changes
- Manifest schema changes
- OOF-INTENT activation
- Requiring intent on any existing contract
- AI-generated intent as a verified claim

**Lab-only boundary maintained.**  
No canon files modified. No grammar added. No VM modified.
