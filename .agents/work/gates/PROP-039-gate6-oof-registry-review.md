# PROP-039 Gate 6: OOF Registry / Diagnostic Namespace Review

**Date:** 2026-06-07
**Gate:** 6 of 7 — OOF registry / diagnostic namespace review
**Status:** ✅ CLOSED
**Authority:** experiment-pass compiler surface; runtime closed
**Tracked location:** `.agents/work/gates/PROP-039-gate6-oof-registry-review.md`

---

## Purpose

Gate 6 reviews the PROP-039 candidate diagnostics (OOF-L1..L5, OOF-R1..R5),
resolves namespace conflicts with Ch13 §13.7 deferred vocabulary, and establishes
which codes graduate to `experiment-pass compiler surface` authority and which
remain candidates.

---

## Namespace Survey

### OOF-L* (local loop diagnostics)

| Code | PROP-039 definition | Active in compiler | Notes |
|------|--------------------|--------------------|-------|
| OOF-L1 | for_loop source is not `Collection[T]` | ✅ typechecker.rb gate 4 | Proven in loop_typechecker_proof 49/49 |
| OOF-L2 | `max_steps` dynamic where v0 requires static literal | candidate | Not yet proven |
| OOF-L3 | Semantic loop block is unnamed (Postulate 28) | candidate | R246/R247 pressure; not yet proven |
| OOF-L4 | `break` in a PROP-039 v0 loop | candidate | break deferred; not yet proven |
| OOF-L5 | Loop body contains unsupported local-repetition form | candidate | Placeholder; not yet proven |
| OOF-L6 | `now()` source-level prohibition | active (Ch8) | Ch8 cross-ref; not PROP-039 territory |

**OOF-L1 to OOF-L5** are PROP-039-owned codes. They do not collide with OOF-L6
(Ch8 ambient-clock refusal). OOF-L6 is Ch8 authority only; PROP-039 may
cross-reference it but does not own or modify it.

### OOF-R* (managed recursion diagnostics)

#### PROP-039 gate 4 active codes

| Code | Gate 4 definition | Active in compiler | Proof |
|------|------------------|--------------------|-------|
| OOF-R2 | `recursive` contract missing a `decreases` declaration | ✅ classifier.rb | loop_typechecker_proof 49/49 |
| OOF-R4 | `fuel_bounded` (or `recursive + decreases fuel`) missing static `max_steps` | ✅ classifier.rb | loop_typechecker_proof 49/49 |

#### PROP-039 candidates (not yet proven)

| Code | PROP-039 definition | Notes |
|------|---------------------|-------|
| OOF-R1 | `recur()` outside recursive or fuel_bounded context | Ch13 R1 meaning identical — no conflict |
| OOF-R3 | Structural variant not proven to decrease at a `recur()` site | Requires TypeChecker proof; future gate |
| OOF-R5 | Recursive step changes output/parameter shape incompatibly | Requires type proof; future gate |

### OOF-R namespace conflict with Ch13 §13.7

Ch13 §13.7 lists deferred design vocabulary that uses overlapping R numbers:

| Code | Ch13 §13.7 meaning |
|------|--------------------|
| OOF-R2 | Service loop step blocks heartbeat window |
| OOF-R3 | Service loop step provably exceeds `max_step_latency` |
| OOF-R4 | `on_exhaustion: :suspend` without a suspension point |
| OOF-R5 | Unbounded loop (no `max_steps`, no structural proof) |

**Conflict resolution:**

Ch13 §13.7 explicitly states: *"They are not a newly accepted OOF registry namespace."*
Ch13 codes R2..R5 are therefore deferred vocabulary, not accepted registry entries.

PROP-039 gate 4 has proven OOF-R2 and OOF-R4 on experiment-pass compiler surface.
Proven experiment-pass surface takes precedence over unproven deferred vocabulary.

**Resolution:**

1. PROP-039 meanings for OOF-R2 and OOF-R4 are accepted as canon
   `experiment-pass compiler surface`.

2. Ch13 §13.7 service-loop codes for heartbeat/latency/suspension are
   PROP-037 territory. They will be assigned to the `OOF-SL*` namespace
   (which already exists: `OOF-SL1` is used in lab VM for service loop
   time errors) when PROP-037 service liveness implementation is authorized.
   A note has been added to Ch13 §13.7.

3. Ch13 OOF-R5 ("unbounded loop") is close in meaning to PROP-039 OOF-L1
   (collection not Collection[T]) and OOF-R deferred codes. It remains
   deferred; no conflict with the active PROP-039 surface.

4. OOF-R1 (recur() outside context): identical meaning in both Ch13 and
   PROP-039. No conflict; remains a candidate for future proof gate.

---

## Authority Table (after Gate 6)

| Code | Status | Proof route | Owner |
|------|--------|-------------|-------|
| OOF-L1 | `experiment-pass compiler surface` | loop_typechecker_proof 49/49 | PROP-039 |
| OOF-L2 | `candidate` | not yet proven | PROP-039 |
| OOF-L3 | `candidate` | not yet proven (Postulate 28 pressure) | PROP-039 |
| OOF-L4 | `candidate` | deferred (break not in v0) | PROP-039 |
| OOF-L5 | `candidate` | deferred | PROP-039 |
| OOF-L6 | `active` | Ch8 wording anchor | Ch8 |
| OOF-R1 | `candidate` | not yet proven (recur() not in v0) | PROP-039 |
| OOF-R2 | `experiment-pass compiler surface` | loop_typechecker_proof 49/49 | PROP-039 |
| OOF-R3 | `candidate` | future TypeChecker proof | PROP-039 |
| OOF-R4 | `experiment-pass compiler surface` | loop_typechecker_proof 49/49 | PROP-039 |
| OOF-R5 | `candidate` | future type proof | PROP-039 |

---

## Governance Shim

### Rule: Gate closure → authority wording must update

When a parser, TypeChecker, or SemanticIR gate closes on experiment-pass
proof, the OOF codes proven in that gate MUST be marked
`experiment-pass compiler surface` at gate closure time.

Authority levels (ordered):

| Level | Meaning |
|-------|---------|
| `candidate` | Proposal text only; not yet proven in compiler |
| `experiment-pass compiler surface` | Proven in a gate proof experiment; active in compiler pipeline; runtime closed |
| `active` | Full OOF registry authority; may require governance review beyond gate proofs |

### Current PROP-039 surface boundary

**Open (experiment-pass):**
- parse → classify → typecheck → SemanticIR pipeline
- OOF-L1, OOF-R2, OOF-R4 diagnostic detection

**Closed (runtime and beyond):**
- VM execution of recursive/fuel_bounded contracts
- `recur()` primitive implementation
- Loop body semantics (body=[] deferred)
- `igc run`, `.igbin`, RuntimeSmoke, Reference Runtime
- Production, release, performance, certification, portability
- Full OOF registry authority (separate governance review required)

---

## Conformance note (lab two-track)

Lab G1 (item variable) and G2 (recursive/fuel_bounded modifiers) are now
closed. Lab conformance gaps for loop-v0:

| Gap | Status |
|-----|--------|
| G1: item variable | ✅ closed 2026-06-07 |
| G2: recursive/fuel_bounded | ✅ closed 2026-06-07 |
| G3: PROP-037 fixture split | future |
| G4: body semantics | future |
| G5: recur() primitive | future |

Lab diagnostic codes remain lab-local (OOF-L1 in Rust parser has DIFFERENT
meaning — "unbounded loop" — than canon OOF-L1 "source not Collection[T]").
This is an acceptable lab delta pending a future diagnostic alignment pass.

---

## Evidence

- Gate 4 proof: `igniter-lang/experiments/loop_typechecker_proof/` — 49/49 PASS
- Gate 5 proof: `igniter-lang/experiments/loop_semanticir_proof/` — 49/49 PASS
- Active codes in compiler: `igniter-lang/lib/igniter_lang/classifier.rb` (OOF-R2, OOF-R4),
  `igniter-lang/lib/igniter_lang/typechecker.rb` (OOF-L1)
- Ch13 annotation: `igniter-lang/docs/spec/ch13-managed-recursion.md` §13.7 updated
- Gate 7 conformance package: `igniter-lang/.agents/work/conformance/PROP-039-managed-repetition-conformance-package-v0.md`
