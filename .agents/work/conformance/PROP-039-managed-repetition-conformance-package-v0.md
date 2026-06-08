# PROP-039 Gate 7: Canonical Conformance Package
# Managed Repetition — Alternate Implementation Consumer Boundary

**Date:** 2026-06-07
**Gate:** 7 of 7 — Alternate implementation conformance consumer route
**Status:** ✅ CLOSED
**Authority:** experiment-pass compiler surface; alternate implementation may consume
**Tracked location:** `.agents/work/conformance/PROP-039-managed-repetition-conformance-package-v0.md`

---

## Purpose

Gate 7 produces the canonical conformance package for PROP-039. It defines:

1. What is accepted as experiment-pass compiler surface (the spine).
2. What remains proposal-only candidates (not yet proven).
3. What lab and alternate implementations may consume.
4. What remains firmly closed (runtime, body semantics, production).
5. The boundary between PROP-039 (local repetition) and PROP-037 (service liveness).

This document IS the conformance package. An alternate implementation passes
PROP-039 conformance when it processes the grammar forms, emits the expected
diagnostics, and produces the SemanticIR shapes defined here.

---

## Part I — Conformance Spine

### 1.1 Grammar Forms (experiment-pass)

All grammar forms below are accepted as experiment-pass compiler surface.
They are proven in `igniter-lang/experiments/loop_class_parser_proof/` — 60/60 PASS.

#### FiniteLoop

```igniter
for <LoopName> <item> in <source> {
  -- body (deferred; body=[] in SemanticIR v0)
}
```

- `LoopName`: stable loop identifier (Postulate 28)
- `item`: explicit item variable (canon form; required by grammar)
- `source`: must be `Collection[T]` (OOF-L1 fires if not)

#### BudgetedLocalLoop

```igniter
loop <LoopName> <item> in <source> max_steps: <N> {
  -- body (accepted by Rust lab; SemanticIR body=[] deferred in canon)
}
```

- `max_steps` must be a static integer literal
- `item`: explicit item variable (G1 conformance requirement)
- `source`: collection reference

#### StructuralRecursion

```igniter
recursive contract <Name> {
  input <name>: <Type>
  ...
  output <name>: <Type>
  decreases <variant>
}
```

- `decreases <variant>`: required (OOF-R2 fires if absent)
- `variant`: identifier or dotted path (e.g. `items.remaining`, `fuel`)
- `recur()` primitive: deferred (body semantics gate)

#### FuelBoundedRecursion

```igniter
fuel_bounded contract <Name> {
  input <name>: <Type>
  ...
  output <name>: <Type>
  max_steps <N>
}
```

- `max_steps <N>`: required (OOF-R4 fires if absent)
- `N`: static integer literal

#### decreases fuel shorthand (StructuralRecursion variant)

```igniter
recursive contract <Name> {
  ...
  decreases fuel
  max_steps <N>
}
```

- `decreases fuel` requires `max_steps` (OOF-R4 fires if absent)
- This is a shorthand candidate; final shape remains future proof work.

### 1.2 Active OOF Diagnostics (experiment-pass)

These codes are active in the canon classifier/typechecker pipeline.

| Code | Fires when | Stage | Proof |
|------|-----------|-------|-------|
| OOF-L1 | `for_loop` source is not `Collection[T]` | TypeChecker | loop_typechecker_proof (49/49) |
| OOF-L5 | Unsupported loop body form (nested loop, lead at contract level, non-literal initial, undefined compute target) | TypeChecker | loop_body_semantics_proof (100/100) |
| OOF-L7 | Body compute targets loop item or outer contract symbol (read-only violation) | TypeChecker | loop_body_semantics_proof (100/100) |
| OOF-L8 | `lead` binding shadows outer contract symbol or loop item variable | TypeChecker | loop_body_semantics_proof (100/100) |
| OOF-R1 | Invalid `recur()` context — `recur()` outside `recursive`/`fuel_bounded` contract (incl. loop body, regular contract) | TypeChecker | recursive_body_proof (100/100) |
| OOF-R2 | `recursive` contract missing `decreases` declaration | Classifier | loop_typechecker_proof (49/49) |
| OOF-R4 | `fuel_bounded` (or `recursive + decreases fuel`) missing static `max_steps` | Classifier | loop_typechecker_proof (49/49) |
| OOF-R5 | `recur()` arity mismatch — arg count ≠ input count | TypeChecker | recursive_body_proof (100/100) |
| OOF-R6 | `recur()` argument type mismatch — arg type ≠ corresponding input type | TypeChecker | recursive_body_proof (100/100) |
| OOF-R7 | `recur()` return type unavailable or ambiguous — contract ≠ exactly one output | TypeChecker | recursive_body_proof (100/100) |

### 1.3 SemanticIR Shapes (experiment-pass)

Proven in `igniter-lang/experiments/loop_semanticir_proof/` — 49/49 PASS.

#### FiniteLoop → loop_node

```json
{
  "kind": "loop_node",
  "loop_class": "finite",
  "name": "<LoopName>",
  "item": "<item-variable>",
  "source_ref": "<source-name>",
  "termination": "collection_exhaustion",
  "body": [],
  "fragment": "<fragment-class>"
}
```

#### BudgetedLocalLoop → loop_node

```json
{
  "kind": "loop_node",
  "loop_class": "budgeted",
  "name": "<LoopName>",
  "item": "<item-variable>",
  "source_ref": "<source-name>",
  "termination": "budget_exhaustion",
  "max_steps": "<N>",
  "body": [],
  "fragment": "<fragment-class>"
}
```

#### StructuralRecursion / FuelBoundedRecursion → contract_ir modifier

```json
{
  "kind": "contract_ir",
  "modifier": "recursive",   // or "fuel_bounded"
  ...
}
```

`body=[]` in all loop_node shapes: body semantics are deferred. An alternate
implementation may emit body content in its own IR, but canon conformance
is defined by the shapes above.

### 1.4 grammar_version

All conformant programs must carry `grammar_version: "loop-v0"` through the
full pipeline (parse → classify → typecheck → SemanticIR).

---

## Part II — Proposal Candidates (not yet proven)

The following are PROP-039 proposal text only. They do NOT define conformance
obligations for alternate implementations at this time.

| Item | Status | Notes |
|------|--------|-------|
| OOF-L2/L3/L4 | candidate | dynamic max_steps, unnamed loop, break — not yet proven |
| OOF-L5/L7/L8 | ✅ experiment-pass — gate 8 closed 2026-06-08 | loop body scope rules; see §1.2 |
| OOF-R1/R5/R6/R7 | ✅ experiment-pass — gate 5 closed 2026-06-08 | recur() context + arg + output validation; see §1.2 |
| OOF-R3 | candidate | variant not proven to decrease (future TypeChecker proof — NOT gate 5) |
| `recur()` primitive — G5 | ✅ gate 5 closed 2026-06-08 — recursive_body_proof 100/100 PASS. OOF-R1/R5/R6/R7 experiment-pass. SemanticIR `recur_call` sub-expr. Termination (OOF-R3), named args, multi-output, execution: all deferred. |
| `ConvergentLoop` | vocabulary only | metric/threshold/budget form; future proof |
| loop body semantics | ✅ gate 8 closed 2026-06-08 — `lead_node` + `compute_node`; OOF-L5/L7/L8 active; scope rules proven. See PROP-039 §"Local Loop Body Semantics (Gate 8 Design)". |
| `for` with optional max_steps cap | open question | deferred per §for/loop split |
| `break` in loop body | deferred | terminates loop evidence; deferred |
| Dynamic `max_steps` | deferred | type/provenance/upper-bound rules needed first |

---

## Part III — Lab Consumption Contract

### 3.1 What lab may consume

An alternate implementation (lab / Rust compiler) is a conformance consumer of
PROP-039. It is permitted to:

- Consume canon conformance fixtures from `igniter-lang/experiments/` as
  integration test inputs.
- Implement grammar forms, OOF diagnostics, and SemanticIR shapes defined in
  Part I.
- Run canon fixtures through its full pipeline (parse → VM exec) as conformance
  evidence.
- Emit lab-local diagnostics under lab-local code names (e.g. lab OOF-L1 with
  "unbounded loop" meaning is lab-only; it does not collide with canon OOF-L1
  from a governance standpoint, but should eventually be renamed for alignment).

### 3.2 What lab must not do

- Lab implementation inertia must not redefine canon grammar. A Rust parser
  accepting a form that PROP-039 has not accepted does not make that form canon.
- Lab conformance fixtures must not be submitted as canon evidence. Only
  `igniter-lang/experiments/` gate proofs are canon evidence.
- Lab may not claim canon authority, registry authority, or production authority
  based on implementation alone.
- Lab must not widen `igc run`, `.igbin`, or any public API surface for
  recursive/fuel_bounded contract execution without separate authorization.

### 3.3 Lab conformance status (2026-06-08)

| Conformance item | Lab status |
|------------------|-----------|
| BudgetedLocalLoop `loop Name item in source` | ✅ G1 closed 2026-06-07 — verify_g1_canon_loop.rb PASS |
| `recursive`/`fuel_bounded` contract modifiers | ✅ G2 closed 2026-06-07 — verify_loops.rb PASS |
| FiniteLoop `for Name item in source` | ✅ G3b closed 2026-06-08 — parser.rs + VM fuel sentinel; verify_g3_conformance.rb PASS |
| OOF-R2 (recursive missing decreases) | ✅ G3a closed 2026-06-08 — classifier.rs; 5/5 diagnostic cases PASS |
| OOF-R4 (fuel_bounded/decreases-fuel missing max_steps) | ✅ G3a closed 2026-06-08 — classifier.rs; PASS |
| SemanticIR loop_node shape | ✅ G3c closed 2026-06-08 — emitter.rs emits kind="loop_node", loop_class, termination, source_ref |
| OOF-L1 (Collection source check) | ✅ G6 closed 2026-06-08 — TypeChecker emits OOF-L1 for FiniteLoop source not Collection[T] (canon meaning). Parser-level OOF-L1 ("unbounded loop") remains as lab-local diagnostic for `loop` without max_steps — lab delta, does not collide in practice (different trigger context). |
| body execution | ✅ lab VM executes loop body; body_nodes = compute-only execution field (VM compat) |
| Gate 8 — loop body semantics | ✅ G8 closed 2026-06-08 — `lead` keyword in parser.rs, OOF-L5/L7/L8 in classifier.rs + typechecker.rs, `body=[lead_node*,compute_node*]` + `item_type` in emitter.rs; two-track: `body_nodes` VM exec / `body` canon; verify_g4_body_semantics.rb 18/18 PASS |

Lab is now symmetric with canon on gate 8 body semantics.

---

## Part IV — Front Boundary

### 4.1 PROP-039 scope (local repetition — closed surface)

PROP-039 owns:
- FiniteLoop (`for Name item in source`)
- BudgetedLocalLoop (`loop Name item in source max_steps: N`)
- StructuralRecursion (`recursive contract`)
- FuelBoundedRecursion (`fuel_bounded contract`)
- OOF-L* (local loop diagnostics, L1..L5)
- OOF-R* (managed recursion diagnostics, R1..R5)

PROP-039 does NOT own:
- ServiceLoop / clock.every / tick.time → PROP-037
- OOF-SL* codes → PROP-037
- OOF-L6 (`now()` prohibition) → Ch8 authority
- OOF-PR* (progression) → PROP-037
- Runtime execution, igc run, production → closed

### 4.2 PROP-037 scope (service liveness — separate boundary)

PROP-037 owns `clock.every`, `tick.time`, `Progression`, `ProgressionEvent`,
`ProgressionSource`, `OOF-SL*`, `OOF-PR*`. Lab G3 (PROP-037 fixture split)
is the next frontier for service liveness, not a PROP-039 widening.

The `loop TickLoop tick in clock.every(5.seconds)` form in lab conformance
fixtures is annotated as PROP-037 territory and must not be processed as a
PROP-039 BudgetedLocalLoop.

### 4.3 Runtime hold

The following surfaces remain closed for PROP-039:

| Surface | Status |
|---------|--------|
| Loop body execution semantics | closed |
| `recur()` primitive implementation | closed |
| VM runtime authority | closed |
| `igc run` widening | closed |
| `.igbin` / `.igapp` execution of recursive contracts | closed |
| RuntimeSmoke productization | closed |
| Reference Runtime | closed |
| Production, release, performance claims | closed |
| Certification, portability guarantees | closed |
| Stable public API for loop/recursion | closed |

---

## Evidence Summary

| Gate | Artifact | Result |
|------|----------|--------|
| 1 — semantics | `igniter-lang/experiments/loop_class_semantics_proof/` | 66/66 PASS |
| 3 — parser | `igniter-lang/experiments/loop_class_parser_proof/` | 60/60 PASS |
| 4 — typechecker | `igniter-lang/experiments/loop_typechecker_proof/` | 49/49 PASS |
| 5 — SemanticIR | `igniter-lang/experiments/loop_semanticir_proof/` | 49/49 PASS |
| 6 — OOF registry | `igniter-lang/.agents/work/gates/PROP-039-gate6-oof-registry-review.md` | namespace resolved |
| 7 — conformance pkg | this document | spine defined |
| Lab G1 | `igniter-lab/igniter-compiler/verify_g1_canon_loop.rb` | PASS |
| Lab G2 | `igniter-lab/igniter-compiler/verify_loops.rb` | PASS |
| Lab G3 (G3a/G3b/G3c/G6) | `igniter-lab/igniter-compiler/verify_g3_conformance.rb` | 14/14 PASS — 2026-06-08 |
| Lab G3 Rust tests | `igniter-lab/igniter-compiler/tests/loop_conformance_tests.rs` | 14/14 PASS — 2026-06-08 |
| Canon Gate 8 | `igniter-lang/experiments/loop_body_semantics_proof/` | 100/100 PASS — 2026-06-08 |
| Lab Gate 8 (Rust symmetry) | `igniter-lab/igniter-compiler/verify_g4_body_semantics.rb` | 18/18 PASS — 2026-06-08 (incl. non-literal OOF-L5, clean OOF-L8 fixture) |
| Canon Gate 5 | `igniter-lang/experiments/recursive_body_proof/` | 100/100 PASS — 2026-06-08 |
| Lab Gate 5 (Rust symmetry) | `igniter-lab/igniter-compiler/verify_g5_recur.rb` | 18/18 PASS — 2026-06-08 |
