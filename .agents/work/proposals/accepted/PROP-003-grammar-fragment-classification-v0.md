# PROP-003: Grammar Fragment Classification v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-001-semantic-domain-v0.md`,
             `proposals/PROP-002-contract-composition-algebra-v0.md`

---

## Purpose

PROP-001 defined the semantic domain. PROP-002 defined the composition
algebra. Both documents hinted at a fragment classification: some constructs
are decidably valid, some require explicit escape annotations, some are
out-of-fragment in v0.

This proposal makes the classification **precise and actionable**: every
language construct gets a class, every class has a compiler behaviour, and
every escape has a named annotation form.

The classifier is the first piece of compiler logic in Igniter-Lang. It runs
before type-checking and before evaluation. Its output is one of three labels
per construct:

```text
CORE      — decidably valid; compile and evaluate normally
ESCAPE    — allowed with explicit annotation; generates a compiler warning
            and an observable platform_observation in the packet spine
OOF       — out-of-fragment; rejected at compile time with a
            compile.out_of_fragment failure_observation
```

---

## Why Classify Before Grammar

Fragment classification does not require a concrete grammar. It operates on
the **abstract semantic constructs** from PROP-001 and the **composition
operators** from PROP-002.

A concrete grammar (`.il` syntax, EBNF, PEG) is a later artifact. But the
classifier must be defined now because it constrains what grammar productions
are legal: a grammar that can express OOF constructs without annotation is a
broken grammar.

The classifier is a **semantic fence**: it makes the language safe-by-default
and extensible-by-annotation, without committing to syntax.

---

## Classification Criteria

A construct is **CORE** if:

1. It inhabits the semantic domain defined in PROP-001.
2. Its dependency graph is a finite DAG (no cycles, no open-world references).
3. Its evaluation terminates under all inputs in the V domain.
4. Type-checking is decidable (structural unification, no higher-order).
5. Observation conservation (Law 5) is provable at compile time.

A construct is **ESCAPE** if:

1. It violates one criterion above in a controlled, bounded way.
2. The violation is statically detectable and annotatable.
3. The runtime can still produce structured failure observations for it.
4. The escape is named and versioned (not a silent platform extension).

A construct is **OOF** if:

1. It violates one or more criteria with no bounded control.
2. The violation cannot be annotated away without changing the semantic model.
3. Decidability or termination cannot be guaranteed even with annotations.

---

## Construct Classification Table

### Value Constructs (PROP-001 §1)

| Construct | Class | Reason |
|-----------|-------|--------|
| `Int`, `Float`, `String`, `Bool`, `Symbol`, `nil` | CORE | Base; always terminates; structurally typed |
| `Record { ... }` | CORE | Structural product; finite field set |
| `Variant tag V` | CORE | Structural sum; closed tag set |
| `Collection [V]` | CORE | Finite, ordered; no lazy streams |
| `Ref r` | CORE | Stable handle; no dereferencing at value level |
| `bottom` (undefined) | CORE | Legal partial value; produces `value_observation` with status `pending` |
| `Redacted` | CORE | Legal sealed value; produces `value_observation` with privacy policy |
| Infinite / lazy stream | OOF | Violates finite collection requirement; reserved as `Stream[T]` escape |

### Type Constructs (PROP-001 §2)

| Construct | Class | Reason |
|-----------|-------|--------|
| Base types | CORE | Trivially decidable |
| `Record { ... }` structural | CORE | Structural unification decidable |
| `Variant { ... }` structural | CORE | Closed tag set; unification decidable |
| `Collection[T]` | CORE | Covariant; decidable |
| `Ref[T]` | CORE | No higher-order; handle only |
| `Store[T]` | CORE | Descriptor only in v0; no runtime semantics yet |
| `History[T]` | CORE | Descriptor only in v0 |
| `BiHistory[T]` | CORE | Descriptor only in v0; bitemporal model deferred |
| `T where guard` refinement | ESCAPE | Guard decidability depends on predicate; see §Refinement Escape |
| `T1 -> T2` contract arrow | OOF | Higher-order; undecidable type-checking in general |
| Dependent types | OOF | Breaks decidability of type-checking |
| Recursive types | OOF | Requires coinduction; not in v0 fragment |

### Expression Constructs (PROP-001 §5)

| Construct | Class | Reason |
|-----------|-------|--------|
| `Literal V` | CORE | Trivial |
| `Var name` | CORE | Resolved at compile time via DAG |
| `FieldAccess Expr label` | CORE | Structural; label must exist in type |
| `Apply built_in [Expr]` | CORE | Built-ins are typed, total, named axioms |
| `Case Expr { tags }` | CORE | Tags must be closed (statically known variant) |
| `Temporal(as_of: t, body: E)` | CORE | Explicit temporal fork; observable; always annotated |
| Lambda `fn(x) -> Expr` | OOF | Higher-order; closures capture environment |
| Arbitrary `Apply f [Expr]` (non-built-in) | OOF | Non-typed external call; no contract boundary |
| Recursion / self-reference in body | OOF | Fixed-point; may not terminate |
| `while` / `loop` | OOF | Unbounded iteration; termination undecidable |

### Contract Constructs (PROP-001 §4)

| Construct | Class | Reason |
|-----------|-------|--------|
| Named contract with DAG deps | CORE | Finite DAG; stratified; demand-driven |
| Input declaration with type | CORE | Typed port |
| Output declaration with type | CORE | Typed port |
| `ComputeNode` with body `Expr` | CORE | Decidable expression body |
| Guard on node (`constraint`) | ESCAPE | Guard decidability depends on predicate |
| Effect declaration (`EffectDecl`) | CORE | Declared shape; no implicit side effect |
| Temporal policy (`TemporalPolicy`) | CORE | Explicit `as_of` policy; observable |
| Self-referencing contract (cycle) | OOF | Cycle in DAG; `compile.cycle_detected` |
| Mutually recursive contracts | OOF | Cycle across contract boundaries |
| Open-world input (unknown type) | OOF | Breaks type-decidability and DAG closure |

### Composition Operators (PROP-002)

| Operator | Class | Condition |
|----------|-------|-----------|
| `>>` Sequential | CORE | No cycle introduced; port types compatible |
| `\|\|` Parallel | CORE | Always (independent DAGs) |
| `branch` Branch | CORE | Arms statically closed; arm types compatible |
| `over` Collection | CORE | Finite source; element contract is CORE |
| `embed` Hierarchical | CORE | No circular embedding; static ref resolution |
| `>>` with cycle | OOF | `compile.cycle_detected` |
| `branch` with dynamic arms | OOF | Runtime arm selection; open-world |
| `over` with infinite stream | ESCAPE | `Stream` escape annotation required |
| `embed` with dynamic ref | OOF | Runtime contract selection |
| Feedback / loop operator | OOF (v0) | Reserved as `workflow_loop` escape in v1 |

### Temporal Constructs (PROP-001 §3)

| Construct | Class | Reason |
|-----------|-------|--------|
| `as_of: TimeRef` explicit | CORE | Explicit parameter; observable |
| `rule_version: Version` | CORE | Explicit; observable |
| `replay: ReplayCursor` | CORE | Explicit; observable |
| `causal_clock: ClockRef` | ESCAPE | Multi-node causal consistency; expensive |
| Ambient time (implicit `now`) | OOF | Violates Law 6 (Temporal Explicitness) |
| Bitemporal query (`valid_time + transaction_time`) | ESCAPE | Two-axis time; `BiTemporal` escape annotation |
| Probabilistic time (fuzzy `as_of`) | OOF | Out of decidable temporal fragment |

### Observation Constructs (PROP-001 §6)

| Construct | Class | Reason |
|-----------|-------|--------|
| `descriptor_observation` | CORE | Static shape declaration |
| `value_observation` | CORE | Typed value under Tt |
| `constraint_observation` | CORE | Satisfied or failed guard |
| `fact_observation` | CORE | Store/history read result |
| `intent_observation` | CORE | Declared action before mutation |
| `receipt_observation` | CORE | Mutation result and evidence |
| `failure_observation` | CORE | Structured unsatisfied contract |
| `platform_observation` | CORE | Named axiom/platform boundary |
| Raw log line (untyped string) | OOF | Not a semantic packet; host noise |
| Observation without identity fields | OOF | Violates observation identity model |
| Observation with mutable id | OOF | Violates content-address stability |

### Failure Constructs (PROP-001 §7)

| Construct | Class | Reason |
|-----------|-------|--------|
| `computation_status: :ok \| :failed \| :rejected \| :blocked` | CORE | Closed enum |
| `service_level: :nominal \| :degraded` | CORE | Closed enum |
| Closed reason code family | CORE | `compile`, `input`, `constraint`, etc. |
| Package-specific reason sub-code | CORE | Namespaced under family; family is closed |
| Platform extension code (advisory) | ESCAPE | `platform_extension` annotation; advisory only |
| Reason code that changes core semantics | OOF | Violates closed core contract |
| Failure without `violates` link | OOF | Violates observation link requirements |

---

## Escape Annotation Model

When a construct is ESCAPE, the compiler must:

1. Accept the construct for evaluation.
2. Emit a `platform_observation` with `kind: :escape_boundary`:

```text
kind: :platform_observation
subject: escape://fragment/<escape_name>
status: :accepted
diagnostics:
  - reason_code: platform.out_of_core_fragment
    severity: :warning
    summary: "Construct uses escape <escape_name>. Core fragment guarantees
              do not apply to this evaluation path."
```

3. Mark the containing contract's `VerificationReport` with the escape name.
4. Propagate the escape marker upward through `>>` and `embed` composition
   (but NOT across `||` — independent parallel contracts do not inherit
   each other's escapes).

### Named Escape Vocabulary (v0)

| Escape name | Applies to | Relaxes |
|-------------|-----------|---------|
| `refinement_predicate` | `T where guard` with non-linear predicate | Guard decidability |
| `causal_clock` | `causal_clock: ClockRef` in TemporalContext | Multi-node consistency cost |
| `bi_temporal` | BiHistory queries with valid_time + transaction_time | Two-axis temporal model |
| `stream_collection` | `over` with `Stream[T]` source | Finite collection requirement |
| `platform_extension_code` | Non-family reason code in failure_observation | Closed reason code family |
| `soft_real_time` | Deadline/WCET annotations that are report-only | Runtime enforcement |

Each escape name is stable, versioned with the proposal that introduces it,
and must appear in the `VerificationReport.escapes` list.

---

## OOF Compiler Behaviour

When a construct is OOF, the compiler must:

1. Reject the contract at compile time.
2. Emit a `failure_observation` with:

```text
kind: :failure_observation
status: :rejected
subject: <offending contract or node ref>
diagnostics:
  - reason_code: compile.out_of_fragment
    severity: :error
    path: <node or expression path>
    expectation: "v0 core or named escape fragment"
    summary: "<construct name> is out-of-fragment in v0."
    remediation:
      action: :fix_descriptor
      safe_to_automate: false
links:
  - rel: :violates
    ref: fragment://v0/core
```

3. Do NOT partially evaluate. OOF rejection is total for the containing
   contract.

---

## Fragment Lattice

The three classes form a strict partial order:

```text
CORE  ⊂  ESCAPE  ⊂  (CORE ∪ ESCAPE)  ⊂  all constructs
OOF = all constructs \ (CORE ∪ ESCAPE)
```

Properties:

- A contract is **fully CORE** if all its constructs are CORE.
- A contract is **escape-annotated** if it has at least one ESCAPE construct
  and no OOF constructs. It compiles but carries escape markers.
- A contract is **rejected** if it has any OOF construct.

Composition propagation:

```text
CORE  >>  CORE   = CORE
CORE  >>  ESCAPE = ESCAPE   (escape propagates forward through >>)
ESCAPE >> CORE   = ESCAPE
ESCAPE >> ESCAPE = ESCAPE
CORE  ||  ESCAPE = CORE + ESCAPE  (independent; no propagation across ||)
```

[D] Escapes do NOT propagate across `||`. Two parallel contracts are
independent; an escape in one branch does not taint the other.

[D] Escapes DO propagate through `>>` and `embed`. A sequential or
hierarchical dependency on an escaped contract inherits the escape.

---

## Mapping to Current Igniter DSL Keywords

The current Ruby DSL (`lib/igniter/dsl/contract_builder.rb`) maps to the
fragment classifier as follows:

| DSL keyword | Composition operator | Fragment class |
|-------------|---------------------|----------------|
| `input` | typed input port | CORE |
| `output` | typed output port | CORE |
| `compute` | `ComputeNode` | CORE (if body is CORE Expr) |
| `compose` | `embed` | CORE (if static ref) |
| `project` | `embed` + field adapter | CORE |
| `branch` | `branch` | CORE (if arms closed) |
| `collection` | `over` | CORE (if finite source) |
| `map` | `over` element | CORE |
| `aggregate` | `>>` + fold built-in | CORE |
| `guard` | refinement constraint | ESCAPE (if non-linear predicate) |
| `const` | `Literal V` node | CORE |
| `lookup` | `embed` store read | CORE |
| `effect` | `EffectDecl` | CORE |
| `on_success` | conditional `>>` on receipt | CORE |
| `scope` | temporal context parameter | CORE |
| `namespace` | node name prefix | CORE (structural only) |
| `expose` | output port alias | CORE |
| `export` | cross-contract port binding | CORE (static) |

No current DSL keyword maps to OOF. This confirms the existing platform is
already operating in a naturally CORE-compatible discipline.

---

## Fragment Classifier as Compiler Pass

The classifier runs as **Pass 0** of the Igniter-Lang compiler pipeline:

```text
Pass 0: Fragment Classification
  Input:  parsed or DSL-constructed contract AST
  Output: ClassifiedAST with per-node Fragment label (CORE | ESCAPE | OOF)
          + list of escape annotations
          + list of OOF violations (if any)
  Action: emit failure_observations for OOF; emit escape platform_observations
          for ESCAPE; pass CORE nodes silently

Pass 1: Type Checking (PROP-004)
  Input:  ClassifiedAST (OOF already rejected)
  Output: TypedAST

Pass 2: DAG Validation
  Input:  TypedAST
  Output: ValidatedDAG (cycles detected here -> compile.cycle_detected)

Pass 3: Stratification Check
  Input:  ValidatedDAG
  Output: StratifiedDAG (guard evaluation order confirmed)

Pass 4: Observation Plan
  Input:  StratifiedDAG
  Output: ObservationPlan (which packets are emitted at which nodes)

Runtime: eval(StratifiedDAG, Tt, inputs)
```

Pass 0 is the **earliest possible rejection point**. It prevents invalid
constructs from reaching type checking, which preserves the decidability
guarantee: type checking only sees CORE or ESCAPE constructs, never OOF.

---

## Decidability Proof Sketch

**Claim:** Fragment classification (Pass 0) is decidable in polynomial time.

**Proof sketch:**

1. The construct table above assigns a fixed class to each syntactic/semantic
   construct. No construct has a class that depends on runtime values.
2. The only ESCAPE construct that requires non-trivial analysis is
   `T where guard` with a non-linear predicate. Detection of non-linearity
   is decidable (check if the predicate AST contains multiplication of
   two variable terms or exponential forms).
3. Cycle detection in the DAG is O(V + E) (DFS).
4. All other classifications are O(1) per construct.

Total: O(n) + O(V + E) where n is AST size and (V, E) is the dependency
graph. Polynomial; in practice linear for typical contract sizes.

---

## Open Questions

[Q] Should `soft_real_time` (deadline/WCET as report-only) be ESCAPE or
CORE? Current `Igniter::Lang` descriptors treat deadline/WCET as
`report_only: true, runtime_enforced: false`. If they never affect
evaluation, they are CORE annotations. If they can affect scheduling or
error reporting, they become ESCAPE. Recommendation: CORE in v0 (report-only
always); promote to ESCAPE if enforcement is added.

[Q] Should the `causal_clock` escape be in v0 or deferred entirely? It is
needed for distributed consistency claims but adds significant runtime cost.
Recommendation: include as named ESCAPE in v0 vocabulary; implementation
deferred.

[Q] How should the classifier handle unknown DSL extensions (future keywords)?
Recommendation: unknown constructs are OOF by default until explicitly
classified. This is a safe-by-default posture.

---

## Rejected Paths

[X] Binary classification (valid / invalid) without ESCAPE. Too coarse:
it forces out useful constructs (refinement types, causal clocks) that are
semantically meaningful but not in the decidable core.

[X] Infinite ESCAPE vocabulary (everything can be escaped). This defeats
the purpose of the classifier. The escape vocabulary must be closed and
named in proposals.

[X] Runtime fragment detection. Classification must be fully static (Pass 0).
Runtime surprises are not classification — they are execution failures.

[X] Grammar-first classification (classify by syntax). Syntax is a later
artifact. Classification is semantic: it applies to AST constructs, not
surface forms.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-003
Status: done

[D] Decisions:
- Three fragment classes: CORE (decidably valid), ESCAPE (annotated, warned),
  OOF (rejected at compile time with failure_observation).
- Classification criteria are static: no runtime information needed.
- Fragment classification is Pass 0 of the compiler pipeline, before type
  checking. This preserves type-checking decidability.
- Named escape vocabulary is closed in v0: refinement_predicate,
  causal_clock, bi_temporal, stream_collection, platform_extension_code,
  soft_real_time.
- Escapes propagate through >> and embed but NOT across ||.
- All current Igniter DSL keywords map to CORE. The existing platform is
  already operating in a naturally CORE-compatible discipline.
- Fragment classification is decidable in O(n) + O(V+E) time.

[R] Recommendations:
- Use the construct classification table as the normative reference for
  the future grammar spec: any grammar production that can express an OOF
  construct without annotation is invalid.
- Proceed to PROP-004 (Type System v0): type checking is Pass 1 and must
  work only on ClassifiedAST (OOF already rejected).
- Add fragment classification output to VerificationReport:
  escapes list + OOF violations list.
- The bridge-observation-envelope-v0 track should emit Pass 0 escape
  platform_observations as first-class observable artifacts.

[S] Signals:
- The classifier confirms that the existing Igniter Ruby DSL is entirely
  CORE-compatible. This validates the research claim that Ruby DSL usage
  is a safe source horizon for language semantics.
- The ESCAPE propagation rules (through >> and embed, not ||) are consistent
  with the composition closure theorem from PROP-002: independent parallel
  contracts do not infect each other.
- Pass 0 as the earliest rejection point is standard compiler architecture
  (cf. Rust's borrow checker running before type inference, Haskell's
  instance resolution before code generation).

[Q] Open Questions:
- Is soft_real_time CORE or ESCAPE in v0?
- Should causal_clock escape be implemented in v0 or deferred?
- Unknown DSL extensions: OOF-by-default confirmed?

[X] Rejected:
- Binary classification without ESCAPE middle ground.
- Infinite/open escape vocabulary.
- Runtime fragment detection.
- Grammar-first (syntax-first) classification.

---

## Errata v0.1 — stream T surface form (2026-05-06)

_Source: META-EXPERT-006-language-model-revision-v0.md (Q2 resolved)._

### E1 — `stream T` is ESCAPE by definition

`stream_collection` was listed in the v0 escape vocabulary as a name only.
This errata formalises the classification rule:

```
stream name: Type
```

**Classification**: always ESCAPE. Reasoning: a stream is an unbounded external
source. Unbounded access to external data cannot be CORE (CORE requires bounded,
decidably-terminating evaluation).

**Escape vocabulary entry** (replaces the implicit `stream_collection` entry):

```
stream_input     ← replaces stream_collection in the escape vocabulary
                    capability: the runtime must hold a stream handle
                    propagation: ESCAPE propagates to the containing contract
```

### E2 — `fold_stream` reduces ESCAPE stream to CORE-safe value

The bounded reduction rule:

```
fold_stream(s: stream T, init: A, fn: (A, T) -> A) @window_bounded  →  A
fold_stream(s: stream T, init: A, fn: (A, T) -> A) @count_bounded(n) →  A
```

**Classification of the fold_stream expression**: CORE if and only if:
1. The accumulator function `fn` is CORE (no ESCAPE inside the lambda)
2. The annotation `@window_bounded` or `@count_bounded(n)` is present
3. `n` is a statically-known Integer literal (for `@count_bounded`)

Without an explicit bounding annotation, `fold_stream` is OOF:

```
OOF-S1: fold_stream without @window_bounded or @count_bounded
         → compile error: "unbounded stream fold is not CORE"
```

### E3 — Window declaration is ESCAPE metadata, not CORE construct

```
window "sensor[device_id]" {
  kind:     :count | :calendar | :session
  size:     Integer            -- for :count
  period:   Duration           -- for :calendar
  on_close: :snapshot | :emit
}
```

The `window` declaration is ESCAPE metadata attached to a `stream_input`.
It does not produce a value itself — it parameterises how the runtime
delivers bounded batches from the stream.

**Classification**: the window declaration is not evaluated by the CORE engine.
It is an ESCAPE lifecycle annotation processed by the stream capability handler.

[Next] Proposed next slices:
- PROP-004: Type System v0
  (type checking as Pass 1; structural types, refinement types, subtyping
  relation, soundness statement)
- bridge-observation-envelope-v0 (Research Agent track)
  (can now reference Pass 0 escape observations as bridge candidates)
```
