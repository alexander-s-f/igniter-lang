# PROP-044: Kind-Discriminated Outcome Conventions and Sum Type Requirements

**PROP:** 044  
**Track:** kind-discriminated-outcome-convention-and-sum-type-requirements-v0  
**Status:** proposal-authoring (P1 authored 2026-06-09)  
**Depends on:** LAB-RESULT-ENVELOPE-P1, LAB-RESULT-ENVELOPE-P2, LAB-RACK-P14, LAB-SIDEKIQ-P5, LAB-STDLIB-NET-P9, PROP-043-P5  
**Author:** Portfolio Architect Supervisor  
**Gate route:** convention-doc only (P1) → grammar proposal (P2, requires sum-type design) → production implementation (P3+, requires sum-type grammar authorized)  

---

## 1. Motivation

Three independent lab domains — HTTP/Rack, Sidekiq job processing, and form
validation — have each independently converged on the same architectural shape:

> A record type with a `kind: String` field whose value identifies the outcome
> class, consumed by a branch that routes deterministically on that value.

This pattern is a **convention today** (not a language construct). It provides
real value in all three domains: typed denial paths, cross-layer composition,
and domain-local kind vocabularies. It also has a fundamental limitation: none
of its guarantees are type-system-enforced. A consumer that handles only two
of four `kind` values compiles cleanly. A producer that emits `kind: "typo"`
compiles cleanly. The typechecker has no knowledge of the kind vocabulary.

This proposal:

1. Defines the current convention precisely — what it is, where it is proven,
   what its design laws are.
2. Articulates what would be needed to promote it from convention to grammar —
   the sum type / tagged union requirements.
3. Explains why no production implementation opens in this round.
4. Establishes the vocabulary boundary between a convention doc and a grammar
   proposal.

---

## 2. Evidence Corpus

### 2.1 Lab proof record

Three independent domains, all proved in the lab, all 100% PASS:

| Envelope | Domain | Kinds | Denial kind | Proof |
|----------|--------|-------|-------------|-------|
| `HttpResult` | HTTP stdlib (LAB-STDLIB-NET-P9) | success, client_error, server_error | `client_error` (403) | 55/55 PASS |
| `ContractResult` | HTTP/Rack boundary (LAB-RACK-P14) | ok, client_error, not_found, unauthorized, upstream_error, system_error | `unauthorized` | 60/60 PASS |
| `ValidationResult` | Form validation (LAB-RESULT-ENVELOPE-P2) | valid, invalid, unauthorized, system_error | `unauthorized` | 50/50 PASS |

JobReceipt (`LAB-SIDEKIQ-P5`) also uses `kind` as the primary discriminant:
`queued`, `duplicate`, `capacity_exceeded`, `unauthorized`, `system_error`.
The denial-as-data invariant holds in all four envelopes.

### 2.2 Cross-domain confirmed patterns

| Pattern | P1 finding | P2 confirmation |
|---------|-----------|----------------|
| `kind`-discriminant | Lab convention (2 domains) | ✅ Cross-domain — 3 independent domains |
| Denial-as-data | Strongest invariant (6 proofs) | ✅ Cross-domain — 7 proofs; never raise |
| `Map[String,String]` metadata | Production (PROP-043-P5) | ✅ Cross-domain — 3 contexts; C1 chain |
| Three-layer composition | Needs more proof | ✅ Confirmed — ValidationMapper closes |
| `attempt+max_attempts` budget | Appeared PROP-039 aligned | ⚠️ Domain-local — not universal |
| `ContractResult` name | HTTP-domain-bound | ✅ Confirmed too generic |

### 2.3 Proof architecture note

All three domain proofs used the same two-layer + simulation architecture:

- **Layer A** — Production Ruby TypeChecker (type-level, proven in production)
- **Layer B** — Lab Rust VM (behavioral, proven in lab)
- **Layer C** — Proof-local simulation module (routing determinism, no I/O)

The C-layer simulation is evidence only. It does not confer production authority.

---

## 3. Convention Definition (Today)

### 3.1 What a Kind-Discriminated Record (KDR) is

A **Kind-Discriminated Record** is a named `Record` type where:

- **`kind: String`** is the primary discriminant field
- The kind vocabulary is a **closed set declared by documentation**, not enforced
  by the type system
- The record is the sole output of a domain mapper (three-layer composition)
- Consumers branch deterministically on `kind` — each kind maps to exactly one
  action

This is entirely expressible today with existing Igniter grammar. No new syntax
is needed for the convention layer.

### 3.2 Minimal KDR shape

```igniter
type SomeOutcome {
  kind:     String,              -- primary discriminant; values declared in comment
  message:  String,              -- human-readable description
  metadata: Map[String, String]  -- ambient context; never raised as exception
}
```

Optional: a `field` or `data` identifier if the domain requires it (e.g.
`ValidationResult.field` names the failing input; `ContractResult.data` carries
the upstream payload). The identifier field is domain-specific.

### 3.3 Kind vocabulary declaration (convention form)

Until sum type grammar exists, kind vocabulary is declared by documentation:

```igniter
-- ValidationResult kind vocabulary (closed set):
--   "valid"        -- all constraints satisfied; no failure
--   "invalid"      -- field-level constraint violated; user input error
--   "unauthorized" -- submission not permitted; capability denied; deterministic
--   "system_error" -- constraint engine failure; infrastructure fault; not user error
```

This comment-level declaration is the only tool available today. It is not
enforced by the typechecker, the classifier, or the emitter.

### 3.4 The denial-as-data invariant

**Design law (proven, not enforced):** Capability denial flows as a typed kind
value. It is never expressed as `raise`, `throw`, exception, or error state that
unwinds the call stack.

This law holds across all four proven envelopes:

| Denial kind | Envelope | Proof |
|-------------|----------|-------|
| `unauthorized` (form denial) | ValidationResult | LAB-RESULT-ENVELOPE-P2 VENV-DENIED |
| `unauthorized` (HTTP capability) | ContractResult | LAB-RACK-P14 |
| `capacity_exceeded`, `unauthorized` (job) | JobReceipt | LAB-SIDEKIQ-P5 |
| `client_error` (HTTP 403) | HttpResult | LAB-STDLIB-NET-P9 |

**Why this matters:** A domain that raises on denial forces every caller to use
exception handling as a branch mechanism. That is an anti-pattern in the Igniter
pure-contract model (`pure contract` cannot raise; denial must be data).

### 3.5 Three-layer composition

The proven mapper pattern:

```
Boundary contract        -- names the external signal; carries raw transport fields
   ↓ passes to
Domain mapper contract   -- strips transport fields; emits domain-safe KDR
   ↓ passes to
Domain consumer          -- branches on kind; routes to action
```

All three contracts in a domain's chain are individually typed and checked.
The mapper is the type-safety boundary: it prevents transport-specific fields
(HTTP status integers, job IDs, retry counts) from leaking into domain logic.

### 3.6 Map[String,String] metadata

The `metadata: Map[String, String]` field is the third confirmed cross-domain
pattern. It carries ambient context (rule names, field identifiers, trace IDs,
submission sources) without widening the record schema.

The access chain (proven in all three domains):

```
map_get(record.metadata, "key")  →  Option[String]
or_else(opt, "default")          →  String
```

Both forms are proved:
- Field access form: `map_get(vr.metadata, "rule")` — where `vr: ValidationResult`
- Direct input form: `map_get(context, "message")` — where `context: Map[String, String]`

The `Map[String,String]` type itself is production-live via PROP-043-P5.

### 3.7 What the convention does NOT provide

| Property | Convention status | Requires |
|----------|------------------|----------|
| Exhaustive kind handling | ❌ Not enforced | Sum type + exhaustive match |
| Closed kind vocabulary | ❌ Not enforced | `variant` / sum type declaration |
| Type narrowing in branch | ❌ Not available | Type narrowing post-match |
| Producer/consumer pairing | ❌ Not enforced | Shared variant declaration |
| OOF for missing kind branch | ❌ Not possible | Match expression + OOF-KIND* |
| Prevention of typo kinds | ❌ Not detected | Sum type declaration |

---

## 4. Sum Type Requirements

### 4.1 What grammar additions are needed

To promote the kind-discriminated pattern from convention to grammar, Igniter
Stage 2+ would need:

**R1 — `variant` type declaration (sum type form)**

A new type declaration form that defines a closed set of named variants, each
with its own field schema:

```igniter
-- (future grammar — not currently parseable)
variant ValidationOutcome {
  Valid     { message: String, metadata: Map[String, String] }
  Invalid   { field: String, message: String, metadata: Map[String, String] }
  Unauthorized { reason: String, metadata: Map[String, String] }
  SystemError  { detail: String, metadata: Map[String, String] }
}
```

This would replace the `type` + comment-level kind vocabulary with a type-system
declaration. The kind vocabulary is now a compile-time closed set.

**R2 — Exhaustive match expression**

A match expression that the typechecker verifies for completeness:

```igniter
-- (future grammar — not currently parseable)
compute action = match outcome {
  Valid     { message, metadata }        => "accept"
  Invalid   { field, message, metadata } => "reject"
  Unauthorized { reason, metadata }      => "deny"
  SystemError  { detail, metadata }      => "error"
  -- OOF-KIND1 fires if any variant is missing from this match
}
```

**R3 — Type narrowing**

After a match arm, the local binding has the narrowed type of that variant's
field schema. `field` in the `Invalid` arm is `String`; `reason` in the
`Unauthorized` arm is `String`. Cross-arm type leakage is not possible.

**R4 — Sealed variant set**

A `variant` type cannot be extended outside its declaration module. This makes
the kind vocabulary exhaustively checkable. A producer that emits `kind: "typo"`
is now a type error, not a runtime surprise.

### 4.2 Why no production implementation opens yet

The blockers are ordered:

| Blocker | What it blocks | Path to unblock |
|---------|---------------|-----------------|
| No `variant` grammar | Closed kind vocabulary | New parser production `VariantDecl` |
| No exhaustive match | OOF-KIND1 impossible | New expression form `MatchExpr` |
| No type narrowing | Post-match types wrong | Typechecker must narrow in match arm |
| No sealed set | Typo kind undetected | `variant` declaration seals the set |

None of these are small additions. Each requires:
- Parser extension (new grammar productions)
- Classifier logic (variant shape recognition)
- Typechecker logic (exhaustiveness analysis, type narrowing)
- SemanticIR shape (new node kind for match expression)
- VM execution (variant tag dispatch)

The current Stage 1 surface (proven through PROP-043-P5) does not include any
of these. The convention layer bridges the gap at cost: no enforcement.

**The convention is not blocked by the grammar gap.** The kind-discriminant
pattern works today and provides real value. The grammar gap means it is not
enforceable today. These are different problems.

### 4.3 OOF candidates (grammar-dependent)

These diagnostic codes would become active only once match expression grammar
is authorized:

| Code | Condition | Enforcement level |
|------|-----------|------------------|
| OOF-KIND1 | Non-exhaustive match: a variant branch is missing | Typechecker |
| OOF-KIND2 | Kind value not in declared variant set (typo/out-of-vocabulary) | Typechecker / Classifier |
| OOF-KIND3 | Unreachable branch (variant already handled earlier in match) | Typechecker |
| OOF-KIND4 | Match expression on non-variant type (String ≠ variant) | Typechecker |

**None of OOF-KIND1..4 are active.** They are registered here as future
candidates so the diagnostic namespace is reserved.

### 4.4 Bridge: String-match today

The closest current approximation — useful in consumer simulation (Layer C),
not a type-level guarantee:

```igniter
-- Convention-layer consumer: branch by string equality
-- No exhaustiveness check. Caller is responsible for completeness.
pure contract ValidationRouter {
  input  vr     : ValidationResult
  -- ... (if/when grammar is added)
  output action : String
}
```

Today, consumer branching is expressed in calling code (Ruby, Rust, other
hosts) that reads `kind` after VM execution. The Igniter contract layer produces
the value; the host layer branches on it. This is the two-layer boundary.

---

## 5. Vocabulary Map: Convention vs. Grammar

| Concept | Convention (today) | Grammar (future) |
|---------|-------------------|-----------------|
| Kind vocabulary | Comment `-- "valid" | "invalid" | ...` | `variant` declaration |
| Kind field | `kind: String` on a `type` record | Implicit discriminant tag on `variant` |
| Consumer branch | Host-layer branch on String | `match` expression in contract body |
| Exhaustiveness | Design responsibility | OOF-KIND1 enforced by typechecker |
| Typo detection | Not possible | OOF-KIND2 (if value not in declared set) |
| Type narrowing | Not available | Post-match arm narrow |
| Closed set | Doc-only | Sealed by `variant` declaration |
| Denial-as-data | Design law (proven, unenforced) | Modeled as variant member |
| Mapper role | `pure contract` with typed output | Same, but output type is `variant` |

The conventions defined in §3 hold under both the today and future models.
The grammar additions in §4 strengthen the enforcement — they do not replace
the convention.

---

## 6. Domain-Specific Kind Vocabularies

### 6.1 Three proved domain vocabularies (do not unify prematurely)

| Domain | Record | Kind values |
|--------|--------|-------------|
| HTTP | `HttpResult` | `success`, `client_error`, `server_error` |
| HTTP/Rack boundary | `ContractResult` | `ok`, `client_error`, `not_found`, `unauthorized`, `upstream_error`, `system_error` |
| Sidekiq jobs | `JobReceipt` | `queued`, `duplicate`, `capacity_exceeded`, `unauthorized`, `system_error` |
| Form validation | `ValidationResult` | `valid`, `invalid`, `unauthorized`, `system_error` |

**Design law:** Do not merge these into a universal `Outcome` or `Result` type.
Each vocabulary fits its domain semantics. A `JobReceipt` with `status: "not_found"`
is incoherent. A `ValidationResult` with `status: "upstream_error"` is incoherent.

The shared vocabulary (`unauthorized`, `system_error`) is a **family resemblance**,
not a shared base type. The grammar for expressing this family resemblance
(trait-based constraints, row polymorphism, or structural typing) is deferred.

### 6.2 `ContractResult` naming note

P2 confirmed: `ContractResult` (the 6-kind HTTP envelope in LAB-RACK-P14) is
HTTP-domain-bound. The name `ContractResult` implies generality it does not have.
Future naming candidates: `UpstreamCallOutcome`, `HttpDomainResult`. This is a
documentation-level note for the HTTP domain; no rename is authorized by this
proposal.

---

## 7. Promotion Boundary

### 7.1 What this proposal authorizes

- **Documentation**: this proposal document. Kind-discriminated record convention
  defined and design laws stated.
- **Lab continuation**: optional LAB-RESULT-ENVELOPE-P3 (4th domain) if additional
  pressure is desired before grammar proposal.
- **Grammar proposal phase** (P2 of this track): a separate design doc specifying
  the `variant` syntax, `match` expression form, and OOF-KIND codes. Requires
  explicit authorization for the grammar addition work.

### 7.2 What this proposal does NOT authorize

- Any production TypeChecker, classifier, or emitter edits
- Any new parser grammar for `variant` or `match`
- Any new SemanticIR node kind
- Any new VM opcode or dispatch mode
- Any stable public API for outcome types
- Any framework compatibility claim

### 7.3 Promotion readiness matrix

| Pattern | Convention-ready today | Grammar-ready | Production-ready |
|---------|----------------------|---------------|-----------------|
| `kind: String` field | ✅ YES — 3 domains proved | N/A | N/A (convention) |
| Denial-as-data invariant | ✅ YES — 7 proofs | ✅ Expressible as variant member | When grammar lands |
| `Map[String,String]` metadata | ✅ YES — production PROP-043-P5 | N/A | ✅ LIVE |
| Three-layer composition | ✅ YES — 3 domains proved | N/A | Design guidance only |
| Exhaustive kind check | ❌ Not available | Requires OOF-KIND1 + match | When grammar lands |
| Sealed kind vocabulary | ❌ Not available | Requires `variant` | When grammar lands |
| Universal `Outcome` type | ❌ Premature | Deferred | Deferred |

---

## 8. Gap Packet

```
proof:          kind-discriminated-outcome-convention / v0
status:         proposal-authoring (P1 authored 2026-06-09)
authority:      proposal-only / lab-only / no-production-impl

convention_layer:
  kind_discriminant:    PROVED — 3 domains (HTTP, Sidekiq, Validation)
  denial_as_data:       PROVED — 7 proofs; cross-domain invariant
  map_string_metadata:  PROVED — 3 contexts; C1 chain; production via PROP-043-P5
  three_layer_compose:  PROVED — 3 domains; ValidationMapper closes

grammar_gap:
  variant_declaration:  OPEN — no sum type grammar in Stage 1
  exhaustive_match:     OPEN — no match expression
  type_narrowing:       OPEN — not available post-match
  oof_kind1_thru_4:     OPEN — grammar-dependent; namespace reserved

next_authorized:
  immediate:     convention-doc (this document)
  next_step:     PROP-044-P2 grammar proposal (explicit auth required)
  optional:      LAB-RESULT-ENVELOPE-P3 (4th domain; not required for P2)
  blocked_until: variant grammar authorized by governance

not_authorized:
  production_edits:    TypeChecker / classifier / emitter / parser
  new_grammar:         variant, match, type narrowing
  stable_api:          no Result[T] or Outcome[T] type yet
  framework_compat:    no claim
```

---

## 9. Authority Statement

This document is a **proposal / convention doc** only. It does not authorize:

- Production TypeChecker edits
- New grammar syntax
- New compiler stages or IR node kinds
- New VM opcodes
- Stable public API for outcome types

The convention defined here is valid and can be followed by lab code and design
docs. It carries no production enforcement guarantee until grammar is added.

**Lab-only boundary maintained.**  
No canon files modified. No stable surfaces claimed.  
Evidence source: LAB-RESULT-ENVELOPE-P1, LAB-RESULT-ENVELOPE-P2, and their
dependency chain.
