# META-001: Compiler/Grammar Expert — Entry Assessment

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Role: meta-observer, meta-corrector, validator
Supervisor: `[Architect Supervisor / Codex]`

---

## Role Declaration

I am joining this workspace as an external expert observer with a specific
disciplinary lens:

```text
Formal language theory
  -> grammar design (CFG, EBNF, PEG, attribute grammars)
  -> type theory (refinement types, dependent types, substructural types)
  -> compiler architecture (multi-pass, incremental, attribute-directed)
  -> denotational / operational / axiomatic semantics
  -> decidability, soundness, completeness
  -> runtime models (reduction, evaluation order, memory models)
```

My function is **meta-observation and meta-correction**: I read existing
research slices and proposals to validate their formal coherence, identify
hidden assumptions, expose blind spots, and propose next research directions
grounded in compiler/language theory.

I do not produce runtime code. I do not commit syntax ahead of semantics.
I produce proposals and correction notes inside `igniter-lang/docs/proposals/`.

---

## Current Track Assessment

### Tracks Read

- `tracks/observable-contract-language-v0.md` — OCL axioms
- `tracks/observable-spine-v0.md` — observation envelope
- `tracks/failure-observation-v0.md` — failure packet semantics

### Overall Assessment

**Verdict: Semantically coherent foundation, but pre-formal.**

The three slices establish a clear informal theory. The axioms are well-chosen
and the observation envelope is disciplined. What the tracks lack — by design
and by correct priority — is a formal semantic grounding that would allow:

1. Proving the laws are consistent with each other.
2. Detecting which language fragments are decidable.
3. Identifying where the contract algebra is compositional vs. where it is not.
4. Specifying what "compile-time" means in Igniter-Lang terms.

This is not a criticism. The research policy is "semantics before syntax."
But as the tracks mature, formal grounding is the next necessary layer.

---

## Meta-Observations

### [S] The Ten Laws Need a Semantic Model

The ten proposed laws in `observable-contract-language-v0` read as design
principles, not as formal axioms. They are correct design principles — but
they have not been grounded in a semantic domain.

Example: Law 1 (Result-orientation) says evaluation runs "backward from what
the contract promises." This is a dataflow semantics claim. It implies:

- a dependency graph is the central artifact
- evaluation is demand-driven (lazy / pull-based)
- the graph must be finite and acyclic for decidability (cf. Law 3, 10)

These implications must be stated, not left implicit, before any compiler
can validate them.

### [S] "Contract" Needs a Compositional Definition

The observation spine defines contracts extensionally ("a contract is any
typed relation from required observations to promised observations"). This is
useful for orientation, but it is intensionally incomplete: we do not yet
know:

- Is the composition of two contracts a contract?
- What is the unit of composition?
- Is composition associative? Commutative?

Without answers, a future "contract algebra" cannot be validated.

### [S] "Observable" Is Still Informal

The observability concept is defined by listing observable surfaces. This is
the right first step. But "observable" in formal language theory has a precise
meaning related to bisimulation and process calculi: two systems are
observationally equivalent if no context can distinguish them.

Igniter-Lang should decide: is "observable" meant in the informal sense
("semantically inspectable") or in the formal sense (bisimulation / testing
equivalence)? The answer affects what the language can prove.

### [S] Failure Model Is the Strongest Slice — and the Riskiest

`failure-observation-v0` is the most grounded slice. It introduces:

- a closed status vocabulary (failed, rejected, blocked, degraded)
- a closed reason-code family
- structured link requirements

**Risk**: The reason-code family is extensible per package. This is pragmatic
but introduces a hidden open-world assumption. If package-specific codes can
change failure semantics, the failure contract is no longer closed.

**Recommendation**: Distinguish core reason codes (closed, provable) from
platform extensions (open, advisory). The closed core should have a formal
semantics; the open extensions should be treated as opaque debug artifacts
for the purpose of the language model.

### [Q] What Is the Evaluation Order?

The tracks assume demand-driven evaluation (Law 1). But the observation spine
introduces temporal context (`as_of`, `valid_time`, `transaction_time`) that
implies state-dependent reads. These two assumptions need reconciliation:

- In a purely demand-driven, stateless graph, `as_of` is just a parameter.
- In a stateful, reactive graph, `as_of` creates temporal forks.

Which is the v0 semantics? This choice determines whether the language is a
functional DSL (simple) or a reactive temporal language (hard).

### [Q] Where Is the Type Theory?

Types appear throughout: `Store[T]`, `History[T]`, type descriptors, type
checks. But the type theory has not been stated. Open questions:

- Are types structural or nominal?
- Is there subtyping?
- Are parameterized types covariant, contravariant, or invariant?
- What is the metatheory for refinement types (guards, invariants)?

Without a type theory, the compiler cannot prove type safety.

---

## Corrections

### [X] Law 6 (Temporal Explicitness) May Conflict With Law 3 (Closed Graph)

Law 3 says the default core is a "finite, stratified dependency graph."
Law 6 says time is never ambient and requires explicit `as_of` semantics.

If `as_of` is a parameter to the evaluation function, then the graph itself
is parameterized over time — and a finite, stratified, closed graph plus a
time parameter creates a family of closed graphs, not a single one.

This is fine, but it must be stated explicitly. Otherwise the compiler may
try to validate the graph statically but fail because time parameters create
dynamic branching that looks like open-world behavior.

**Correction**: Restate Law 3 as: "The default core is a finite, stratified
dependency graph, parameterized over an explicit temporal context. Each
evaluation at a fixed temporal context is a closed computation."

### [X] The Envelope "Required Fields" List Conflates Categories

In `observable-spine-v0`, the required fields include both identity fields
(`observation_id`, `space`, `subject`) and audit/provenance fields
(`producer`, `observed_at`, `content_hash`) and policy fields (`privacy`,
`links`).

These categories have different formal properties:

- Identity fields determine equivalence.
- Audit fields determine provenance, which is a separate relation.
- Policy fields determine what consumers may do.

Mixing them in one "required" list makes it hard to define when two packets
are the "same observation" vs. the "same data with different provenance."

**Correction**: Separate the required fields into three groups:
- **Identity fields**: `observation_id`, `space`, `kind`, `subject`
- **Provenance fields**: `producer`, `observed_at`, `content_hash`
- **Policy fields**: `privacy`, `links`

This separation will matter for deduplication, re-emission, and audit.

---

## Proposed Next Research Vectors

These are proposed as `igniter-lang/docs/proposals/` candidates for
Architect review. I will author them in order unless redirected.

### PROP-001: Semantic Domain Proposal

Define the semantic domain for Igniter-Lang v0:

- What mathematical object is a contract? (relation, function, monad, effect
  system, Petri net, ...?)
- What is the carrier set for values?
- What is the evaluation function signature?
- What does "valid under temporal context T" mean formally?

This does not require a parser. It requires one page of mathematical prose
or pseudo-notation.

### PROP-002: Contract Composition Algebra

Define contract composition: sequential, parallel, branch, and collection.
Prove or disprove associativity, commutativity, and identity element.
Identify which composition operations preserve the observable contract laws.

### PROP-003: Grammar Fragment Classification

Given the current axioms and the semantic domain (from PROP-001), classify
the language fragments:

- What is in the decidable core (Horn/stratified/finite-domain)?
- What requires explicit escape annotations?
- What is out-of-fragment (probabilistic, recursive, open-world)?

This classification directly informs the compiler's rejection and escape
mechanisms.

### PROP-004: Type System v0

Propose a minimal type system for v0:

- base types
- structural record types
- parameterized types (`Store[T]`, `History[T]`)
- refinement types (guards, invariants as types)
- a subtyping relation (or its absence)
- soundness statement (what the type system guarantees)

### PROP-005: Bridge Observation Envelope v0

(Already recommended by prior tracks.) Map current Ledger, Durable Model,
and Diagnostics packets into the observation envelope. This is the practical
bridge. Assign to a dedicated track after PROP-001 and PROP-002 provide
grounding.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/META-001
Status: done

[D] Decisions:
- The three completed tracks are a coherent informal theory with correct
  research discipline.
- The next necessary layer is formal semantic grounding, not more informal
  axiom proposals.
- The failure model is the strongest slice but needs a formal distinction
  between closed core codes and open platform extensions.

[R] Recommendations:
- Author PROP-001 (Semantic Domain) next as the formal grounding anchor.
- Separate observation envelope required fields into identity / provenance /
  policy groups.
- Clarify temporal parameterization in Law 3.

[S] Signals:
- The ten laws imply a demand-driven, graph-structured, temporally
  parameterized evaluation model. This is close to a stratified Datalog
  with temporal parameters — a well-studied and decidable fragment.
- The observation spine's link model is structurally similar to a typed
  hypergraph, which has good theoretical foundations for compositional
  reasoning.

[Q] Open Questions:
- Is "observable" meant informally or in the bisimulation sense?
- What is the evaluation order semantics (lazy, eager, demand-driven)?
- Are contract types nominal or structural?

[Next] Proposed next slice:
- `igniter-lang/docs/proposals/PROP-001-semantic-domain-v0.md`
```
