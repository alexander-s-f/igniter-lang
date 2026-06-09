# PROP-042: T3 Numeric Measure Expressions v0

Status: proposal-authored  
Date: 2026-06-08  
Author: `[Portfolio Architect Supervisor]`  
Depends on: PROP-039 (managed recursion), PROP-041-P7 (T2 structural-size, experiment-pass)  
Design lock: igniter-lang/.agents/work/tracks/prop041-t3-numeric-measure-design-lock-v0.md  
Stage: 2 (proposal authored — proof-local experiment required before Stage 3)  
Evidence: none yet — experiment gate is PROP-042-P2

---

## Authority Boundary

Authorized by this document:

- Grammar design for `decreases count(items)` (function-call numeric measure form)
- NUMERIC_MEASURE_BUILTINS v0 registry: `count(Collection[T])` (stdlib_numeric_certified)
- Trust-metadata model: `stdlib_numeric_certified` trust level definition
- OOF-R10 and OOF-R11 diagnostic code specifications (candidate → canonical pending P2 gate)
- SemanticIR shape: `numeric_measure_v0` termination variant with `numeric_measure` sub-object
- Dispatch priority extension from T2 to T3
- Call-site decrease obligation specification (T2 structural coverage → T3 numeric decrease)
- Backward compatibility rule for T3-unaware compilers
- PROP-042-P2 proof-local experiment gate scope definition

Not authorized by this document:

- Production edits to classifier.rb / typechecker.rb / semanticir_emitter.rb (requires P4/P5)
- Lab Rust compiler T3 symmetry (requires production graduation)
- Proof-local experiment (requires P2 authorization)
- Text length measures (byte_length, rune_length, grapheme_length) — deferred
- User-defined numeric measures — deferred to v1
- `size` / `length` / aliases in NUMERIC_MEASURE_BUILTINS — deferred
- Arithmetic on measures (`count(items) - 1`) — T4 territory
- Lexicographic / multi-variant decrease (T4)
- SMT, proof receipts (T5)
- Runtime execution, VM stack, TCO
- Public, stable, or production API claims
- OOF-R10/R11 as canon codes without gate proof

---

## § 1. Purpose

### § 1.1 The Problem

PROP-041 introduced T2 structural-size relation, rehabilitating dotted-path `decreases`
variants (e.g., `decreases items.tail`) when a named size relation covers the (type, accessor)
pair. T2 deliberately reserves a "numeric accessor" boundary via the NUMERIC_ACCESSORS
closed list (`count`, `length`, `size`, `total_count`, `num_items`, `num_elements`).

When a programmer writes `decreases items.count`, the compiler routes to OOF-R3 rather than
OOF-R8 — preventing numeric field names from being silently treated as structural sub-values.
From PROP-041 § 3.4:

> "Extension of this list, or a mechanism to override it, is deferred to T3."

This leaves two legitimate use cases unsupported:

1. A programmer who wants to express "the collection shrinks by element count" without naming
   a specific structural accessor (abstracting over `tail` vs. `rest`).
2. A program that steps through a collection where either `tail` or `rest` is equally valid —
   T2 would require picking one; T3 allows expressing the count guarantee directly.

There is also a forward-compatibility need: as user-defined types and custom iterators grow,
a numeric measure form will be needed for cases where no single structural accessor is the
canonical decreasing path.

### § 1.2 T3 Numeric Measure Evidence

PROP-042 introduces the third termination evidence tier: **T3 numeric measure evidence**.

T3 is not a proof of termination. It is a mechanism for the compiler to record that:

1. The programmer has declared a compiler-known numeric measure over a recursive input;
2. The measure's value at each `recur()` call site is provably smaller than at the entry
   point, via the T2 structural-coverage relation;
3. The SemanticIR records the numeric measure evidence and trust level.

What the compiler does NOT do:
- Evaluate the measure function at runtime.
- Prove that the measure is bounded below (this is a trust axiom for `stdlib_numeric_certified`).
- Guarantee termination for user-declared measures (deferred to v1 with `user_assumed_numeric`).

The trust level carries this distinction explicitly:

| Trust level | Meaning |
|-------------|---------|
| `stdlib_numeric_certified` | The compiler certifies that this measure function is pure, total, and returns a non-negative integer. The decrease obligation is checked at call sites via the T2 structural registry. |

### § 1.3 Design Postulates

1. **Evidence is not proof.** `numeric_measure_v0` in SemanticIR means "numeric measure
   evidence recorded with trust metadata." It does not mean "termination proven."

2. **Strictly additive after T1/T2.** T3 adds a new dispatch branch for function-call
   expression forms. T1 (`decreases n`) and T2 (`decreases items.accessor`) are unaffected.
   No existing program changes behavior under T3 extension.

3. **Call-site obligation is compiler-checked.** At each `recur()` call, the compiler verifies
   that the argument at the measured-input position is a structurally-covered subtype per the
   T2 registry. This links T3's numeric evidence to T2's structural evidence as its foundation.

4. **NUMERIC_ACCESSORS (T2) unchanged.** The dotted-path numeric accessor list in T2 is frozen.
   T3 opens a new path (`count(items)`, function-call form) — it does not rehabilitate the
   dotted path (`items.count`).

5. **Text length deferred.** Text length measures (`byte_length`, `rune_length`,
   `grapheme_length`) are not part of T3 v0. The Text Unicode authority is currently
   `lab-only-evidence`. This is a dependency, not a design question.

6. **User-defined measures deferred.** v0 contains only `stdlib_numeric_certified` measures.
   A `user_assumed_numeric` trust level and purity-verification mechanism are v1 work.

---

## § 2. Grammar Design

### § 2.1 T3 dispatch trigger

T3 is triggered when a `decreases` variant is a **function-call expression** of the form:

```
fn_name(arg_name)
```

where `fn_name` is a single identifier and `arg_name` is the name of one of the contract's
declared inputs. The function-call form is syntactically distinct from:

- Simple identifier (`decreases n`) — T1 dispatch
- Dotted-path (`decreases items.tail`) — T2 dispatch
- Arithmetic expression (`decreases n - 1`) — T1 dispatch (syntactic whitelist)

No parser change is required if `decreases` already accepts a general expression; the
dispatch logic in the typechecker distinguishes by expression shape.

### § 2.2 v0 canonical form

```igniter
module SumProcessing

recursive contract SumList {
  input items: Collection[Integer]
  compute result = recur(items.tail)
  output result: Integer
  decreases count(items)
  max_steps 1000
}
```

**Interpretation:** The programmer declares that the element count of `items` strictly
decreases at each recursive step. The compiler checks this at the `recur()` call site by
verifying that `items.tail` is a T2-registered structural subvalue of `items` for type
`Collection` — which it is, via the `stdlib_certified` entry for `(Collection, tail)`.

### § 2.3 Multiple inputs

When a contract has multiple inputs, `count(arg_name)` identifies which input is the
measured argument by name. The compiler looks up the position of `arg_name` in the input
list and checks the corresponding argument at each `recur()` call site.

```igniter
recursive contract SumListWithAcc {
  input items: Collection[Integer]
  input acc: Integer
  compute result = recur(items.tail, acc + items.head)
  output result: Integer
  decreases count(items)
  max_steps 1000
}
```

Here `items` is at position 0; the call-site check examines `recur(items.tail, ...)` and
verifies that `items.tail` is a structurally-covered subvalue of `items`.

### § 2.4 What is NOT T3

The following forms are not T3 and are handled by other dispatch paths or OOF codes:

| Form | Path | Notes |
|------|------|-------|
| `decreases items.count` | OOF-R3 | Dotted numeric accessor; NUMERIC_ACCESSORS blocks; unchanged by T3 |
| `decreases count(items) - 1` | OOF-R3 (T4 territory) | Arithmetic on measure; not T3 in v0 |
| `decreases my_fn(items)` | OOF-R10 | `my_fn` not in NUMERIC_MEASURE_BUILTINS |
| `decreases size(items)` | OOF-R10 | `size` not in NUMERIC_MEASURE_BUILTINS v0 |
| `decreases length(items)` | OOF-R10 | `length` not in NUMERIC_MEASURE_BUILTINS v0 |
| `decreases byte_length(text)` | OOF-R10 | Text measures deferred; not in v0 |
| `decreases count(items, extra_arg)` | OOF-R3 | Multi-argument call; not recognized as T3 |
| `decreases count` (no call) | T1 or OOF-R3 | Plain identifier, no call; T1 dispatch |

### § 2.5 Dispatch priority (complete T3 extension)

```
decreases <variant>

  Is <variant> a simple identifier?
    → T1 dispatch (syntactic_v0 whitelist check)

  Is <variant> a dotted-path (ident.field)?
    Is field ∈ NUMERIC_ACCESSORS?
      → OOF-R3 (numeric accessor blocked at T2 boundary; unchanged by T3)
    Is (subject_type, field) ∈ size_registry?
      → T2 pass: structural_size_v1
    → OOF-R8 (missing structural size relation)

  Is <variant> a function-call (fn_name(arg_name))? [T3 entry point]
    Is fn_name ∈ NUMERIC_MEASURE_BUILTINS?
      Run T3 call-site check →
        All call sites pass? → T3 pass: numeric_measure_v0
        Any call site fails? → OOF-R11
    → OOF-R10 (measure function not recognized)

  Is <variant> an arithmetic expression?
    → T1 dispatch (syntactic_v0 whitelist check; rejects n + 1 etc.)

  Anything else?
    → OOF-R3
```

T3-unaware compilers encountering a function-call decreases form may emit OOF-R3 (conservative
fallback). This is a conformance allowance — not a conformance break.

---

## § 3. NUMERIC_MEASURE_BUILTINS Registry

### § 3.1 Registry design

At compile time, the compiler maintains a **numeric measure registry** — a map from
function names to certified measure objects. In T3 v0, this registry is hardcoded and
immutable (same pattern as STDLIB_SIZE_REGISTRY in T2).

### § 3.2 v0 builtin entries (exhaustive)

| Function name | Qualified name | Input type | Return type | Trust | Source |
|---------------|---------------|------------|-------------|-------|--------|
| `count` | `stdlib.collection.count` | `Collection[T]` | `Integer` (≥ 0) | `stdlib_numeric_certified` | `compiler_builtin` |

**Compiler axioms for `count`:**
- `count(x.tail) < count(x)` for all `x: Collection[T]` — covered by T2 `stdlib_certified` (Collection, tail)
- `count(x.rest) < count(x)` for all `x: Collection[T]` — covered by T2 `stdlib_certified` (Collection, rest)
- `count(x) ≥ 0` for all `x: Collection[T]`

These axioms are not verified by the compiler at call sites — they are trusted as
`stdlib_numeric_certified`. The call-site check verifies structural coverage via the T2
registry (§ 5), not the axioms themselves.

### § 3.3 Trust levels

The T3 registry introduces one new trust level:

| Level | Value string | Meaning |
|-------|-------------|---------|
| Stdlib-numeric-certified | `"stdlib_numeric_certified"` | Compiler-attested pure, total measure returning Integer ≥ 0. Decrease obligation verified at call sites via T2 structural coverage. |

This is distinct from T2's trust levels (`stdlib_certified`, `user_assumed`) and from any
future `user_assumed_numeric` level (deferred to v1).

No other trust levels exist for T3 in v0. Trust levels are not user-extensible in v0.

### § 3.4 Deferred entries

The following measure functions are NOT in the v0 registry. Inclusion requires a separate
PROP amendment or a new experiment gate proving the semantic:

| Function | Reason deferred |
|----------|----------------|
| `size` | Ambiguous — could refer to byte size, element count, or domain-specific size |
| `length` | Ambiguous — `length(text)` has unit ambiguity (byte/rune/grapheme) |
| `byte_length` | Deferred — Text Unicode authority is `lab-only-evidence` |
| `rune_length` | Deferred — same; Unicode codepoint count depends on UAX #29 policy |
| `grapheme_length` | Deferred — same; grapheme cluster semantics are Unicode-version-dependent |
| User-defined | Deferred — purity verification and non-negativity check infrastructure required |

---

## § 4. Diagnostics

### § 4.1 OOF-R10 — Unrecognized numeric measure function

**Code:** OOF-R10  
**Stage:** TypeChecker  
**Trigger:** `decreases fn(arg)` where `fn` is not in NUMERIC_MEASURE_BUILTINS.  
**Severity:** Blocking

**When it fires:**
- `decreases my_fn(items)` — user-defined function, no T3 builtin
- `decreases size(items)` — `size` not in v0 builtin list
- `decreases byte_length(text)` — Text measures deferred
- `decreases count(items, extra)` — multi-argument call not recognized as T3

**Message format:**
```
contract '<name>' — decreases measure '<fn>(<arg>)': '<fn>' is not a recognized
stdlib numeric measure in v0; allowed: count; user-defined measures and Text
length measures require future authorization
```

**Example:**
```
contract 'SearchTree' — decreases measure 'depth(tree)': 'depth' is not a
recognized stdlib numeric measure in v0; allowed: count; user-defined measures
and Text length measures require future authorization
```

### § 4.2 OOF-R11 — Numeric measure decrease obligation not satisfied

**Code:** OOF-R11  
**Stage:** TypeChecker  
**Trigger:** A T3 pass context is active (recognized measure, valid input), but the
`recur()` call site does not pass a structurally-covered sub-value at the measured
input position.  
**Severity:** Blocking

**When it fires:**
- `recur(items)` when `decreases count(items)` — plain ref, count cannot decrease
- `recur(other_items)` — different variable, count relationship unknown
- `recur(items.secondary)` when `(Collection, secondary)` is not in size_registry

**Message format:**
```
recur() in '<contract>' — numeric measure decrease obligation not satisfied for
'<fn>(<subject>)': argument at position <N> does not satisfy <fn>(arg) <
<fn>(<subject>); expected a T2-registered structural subvalue of '<subject>'
(e.g., <subject>.tail or <subject>.rest for Collection, or a declared
size_relation for the type)
```

**Example:**
```
recur() in 'SumList' — numeric measure decrease obligation not satisfied for
'count(items)': argument at position 1 does not satisfy count(arg) < count(items);
expected a T2-registered structural subvalue of 'items' (e.g., items.tail or
items.rest for Collection, or a declared size_relation for the type)
```

### § 4.3 OOF-R3 — Unchanged as conservative fallback

OOF-R3 continues to fire for:
- Dotted-path numeric accessors (`decreases items.count`) — NUMERIC_ACCESSORS; unchanged
- T1 syntactic whitelist violations
- Any unrecognized `decreases` form not handled by T1, T2, or T3

A T3-unaware compiler encountering `decreases count(items)` may emit OOF-R3 without
conformance break. OOF-R3 is the conservative fallback for all implementations.

### § 4.4 OOF-R8 / OOF-R9 — Unchanged

OOF-R8 (missing T2 structural size relation) and OOF-R9 (T2 call-site mismatch) are not
affected by T3. They apply exclusively to the dotted-path T2 dispatch branch.

### § 4.5 Diagnostic precedence (complete chain)

When a `decreases` variant is present on a `recursive` contract:

1. No `decreases` → **OOF-R2** (stop)
2. Simple identifier → T1 whitelist check
   - Passes whitelist → `syntactic_v0`
   - Fails whitelist → **OOF-R3**
3. Dotted-path (`ident.field`) →
   - `field` ∈ NUMERIC_ACCESSORS → **OOF-R3** (stop)
   - `(type, field)` ∈ size_registry → T2 call-site check
     - All call sites pass → `structural_size_v1`
     - Any call site fails → **OOF-R9**
   - Not in registry → **OOF-R8**
4. Function-call (`fn_name(arg)`) →
   - `fn_name` ∈ NUMERIC_MEASURE_BUILTINS → T3 call-site check
     - All call sites pass → `numeric_measure_v0`
     - Any call site fails → **OOF-R11**
   - Not in registry → **OOF-R10**
5. Arithmetic expression → T1 whitelist check (same as #2)
6. Any other form → **OOF-R3**

OOF-R10 and OOF-R11 are mutually exclusive for a given contract.

---

## § 5. SemanticIR Shape

### § 5.1 T3 clean contract — numeric_measure_v0

When a contract passes T3 validation (recognized measure + all call sites pass), the
SemanticIR termination object is emitted as `numeric_measure_v0`:

```json
{
  "contract_name": "SumList",
  "modifier": "recursive",
  "termination": {
    "decreases": "count(items)",
    "variant_check": "numeric_measure_v0",
    "numeric_measure": {
      "fn": "stdlib.collection.count",
      "arg": "items",
      "trust": "stdlib_numeric_certified",
      "source": "compiler_builtin"
    }
  }
}
```

**Field specifications:**

| Field | Type | Value | Notes |
|-------|------|-------|-------|
| `decreases` | String | `"count(items)"` | The `decreases` expression verbatim |
| `variant_check` | String | `"numeric_measure_v0"` | Distinguishes T3 from `"syntactic_v0"` and `"structural_size_v1"` |
| `numeric_measure.fn` | String | `"stdlib.collection.count"` | Fully-qualified stdlib function name — must not vary by compiler implementation |
| `numeric_measure.arg` | String | `"items"` | Name of the measured input variable |
| `numeric_measure.trust` | String | `"stdlib_numeric_certified"` | Trust level — must not vary |
| `numeric_measure.source` | String | `"compiler_builtin"` | Source string — must be `"compiler_builtin"` for v0 builtin entries |

### § 5.2 T1 contracts — syntactic_v0 unchanged

T3 does not modify T1 SemanticIR output:

```json
{
  "termination": {
    "decreases": "n",
    "variant_check": "syntactic_v0"
  }
}
```

### § 5.3 T2 contracts — structural_size_v1 unchanged

T3 does not modify T2 SemanticIR output:

```json
{
  "termination": {
    "decreases": "items.tail",
    "variant_check": "structural_size_v1",
    "size_relation": {
      "accessor": "tail",
      "trust": "stdlib_certified",
      "source": "compiler_builtin"
    }
  }
}
```

### § 5.4 OOF-R10 / OOF-R11 contracts

Contracts that fire OOF-R10 or OOF-R11 receive `status: "blocked"` and do not emit a
`termination` object. Same pattern as OOF-R3/R8/R9 blocking contracts.

### § 5.5 `variant_check` value registry (complete after T3)

| String value | Tier | Meaning |
|---|---|---|
| `"syntactic_v0"` | T1 | Syntactic whitelist check — proven |
| `"structural_size_v1"` | T2 | Structural-size relation — proven |
| `"numeric_measure_v0"` | T3 | Numeric measure evidence — candidate (PROP-042-P2 required) |

No other values are canonical. Compilers must not emit unlisted `variant_check` strings.

---

## § 6. Call-Site Decrease Obligation

### § 6.1 Mechanism

For `decreases count(items)` on input `items: SomeType`:

At each `recur()` call, the argument at the position corresponding to `items` must be
a value `a` for which the compiler can certify `count(a) < count(items)`. The compiler
certifies this by checking whether `a` is a T2-registered structural subvalue of `items`.

**Why this links T3 to T2:** The axioms `count(x.tail) < count(x)` and
`count(x.rest) < count(x)` are the backing truths for `stdlib_numeric_certified`. Rather
than re-proving these axioms at each call site, the compiler delegates to the T2 structural
registry: if a T2 relation certifies `a` is a structural subvalue of `items`, then
`count(a) < count(items)` follows from the stdlib-certified axioms.

### § 6.2 Accepted call-site arguments (v0)

For `decreases count(items)` where `items: Collection[T]`:

| Argument at items position | Accepted? | Why |
|---------------------------|-----------|-----|
| `items.tail` | ✅ | T2 `stdlib_certified` for (Collection, tail) — count decreases |
| `items.rest` | ✅ | T2 `stdlib_certified` for (Collection, rest) — count decreases |
| `items.sub` where `size_relation Collection sub` is declared | ✅ | T2 `user_assumed` — structural decrease declared, numeric decrease implied |
| `items` (plain ref) | ❌ OOF-R11 | `count(items) < count(items)` is false |
| `other` (different variable) | ❌ OOF-R11 | Count relationship to `items` is unknown |
| `items.head` (not in registry) | ❌ OOF-R11 | `(Collection, head)` not in T2 registry |

### § 6.3 Relationship to T2

T3 call-site checking is a superset of T2 in terms of what it accepts at call sites, but
a looser contract at the declaration level:

- **T2 `decreases items.tail`**: names a specific accessor; the compiler checks that the
  recur argument at the items position IS `items.tail`.
- **T3 `decreases count(items)`**: names a measure; the compiler checks that the recur
  argument at the items position is ANY T2-registered structural subvalue.

This is intentional. T3 expresses "the count decreases" without committing to a specific
accessor. The tradeoff: T3 cannot catch the case where a programmer changes `recur(items.tail)`
to `recur(items.rest)` — both are valid under T3. T2 can catch this. Use T2 when you want
accessor-level precision; use T3 when accessor flexibility is desired.

### § 6.4 Multi-recur call sites

When a contract has multiple `recur()` calls (e.g., `recur(items.tail) + recur(items.rest)`),
the call-site check applies to each `recur()` independently. All call sites must satisfy the
decrease obligation. Any single failure fires OOF-R11 for that call site.

The compiler does not suppress OOF-R11 for one failing call site because another call site
is correct.

---

## § 7. T3 vs T2 — Usage Guide

T2 and T3 are complementary. This section clarifies when to use each.

| Situation | Recommended form | Reason |
|-----------|-----------------|--------|
| Standard Collection recursion, single accessor | T2: `decreases items.tail` | Precise — names the structural path; `stdlib_certified` |
| Custom type with declared accessor | T2: `decreases items.remaining` + `size_relation` | Same precision; `user_assumed` structural evidence |
| Collection recursion, either `tail` or `rest` valid | T3: `decreases count(items)` | Abstraction over accessor choice |
| Abstract interface — accessor is an implementation detail | T3: `decreases count(items)` | Measure is the public contract |
| Programs migrating from OOF-R3 without declaring a specific accessor | T3: `decreases count(items)` | Lower friction than T2; proof of structural decrease via stdlib_certified |
| Text recursion | Not T2, not T3 (hold) | Text length measures deferred pending Unicode authority |
| Numeric counter decrementing alongside structural argument | Not T3 (T4, deferred) | Compound decrease; T3 covers single-measure forms only |

### § 7.1 Choosing between T3 and T2 for Collection programs

**Use T2 when:** The structural accessor is fixed and known. The program always recurses via
`items.tail` and never via `items.rest`. T2's call-site enforcement ensures this doesn't drift.

**Use T3 when:** The structural accessor is not fixed, or the programmer wants to state
"any valid structural decrease satisfies the measure" as the invariant.

**Do not use T3 as a workaround for missing `size_relation` declarations.** The T3
call-site check still requires a T2-registered structural coverage. Without a T2 entry for
the specific accessor being passed, OOF-R11 fires. T3 is not a bypass for T2 obligations.

---

## § 8. Backward Compatibility

### § 8.1 T1/T2 programs — no change

All existing T1 programs (simple-identifier `decreases`, numeric arithmetic, `decreases fuel`)
are unaffected. All existing T2 programs (`decreases items.accessor` with registered relation)
are unaffected. T3 dispatch is entered only when `decreases` holds a function-call expression.
There is no automatic upgrade.

### § 8.2 T3-unaware compiler conformance allowance

A compiler that does not implement T3 (`numeric_measure_v0`) may emit OOF-R3 for
function-call decreases variants without conformance break.

This mirrors the T2-unaware allowance from PROP-041 § 6.2. The rationale is identical:
fail-closed is conservative, not incorrect. A compiler that fires OOF-R3 where a
T3-capable compiler would emit `numeric_measure_v0` is being conservatively strict.

Once a compiler implements T3, the following must hold:
- OOF-R10 must be distinct from OOF-R3 (separate code, separate message).
- OOF-R11 must be distinct from OOF-R3, OOF-R10, and all T2 codes.
- A recognized T3 builtin in NUMERIC_MEASURE_BUILTINS must not fire OOF-R3 or OOF-R10.
- A T3 passing contract must emit `numeric_measure_v0` variant check (not `syntactic_v0`
  or `structural_size_v1`).

### § 8.3 OOF-R3 message and code stability

OOF-R3 message format and diagnostic code are unchanged by this PROP. PROP-042 introduces
new codes (R10/R11); it does not modify R3, R8, or R9.

---

## § 9. Closed Surfaces

| Surface | Status |
|---------|--------|
| Production compiler edits (classifier.rb, typechecker.rb, semanticir_emitter.rb) | Closed — P4/P5 required after P2/P3 |
| Lab Rust T3 symmetry | Closed — opens after production graduation |
| Text length measures (byte_length, rune_length, grapheme_length) | Closed — pending Unicode receipt canon authority |
| User-defined numeric measures | Closed — v1; purity + non-negativity verification gap |
| `size` / `length` / aliases in NUMERIC_MEASURE_BUILTINS | Closed — deferred |
| `decreases count(items) - 1` arithmetic on measures | Closed — T4 territory |
| Lexicographic / multi-variant decrease (`decreases [a, b]`) | Closed — T4 / post-T3 |
| SMT-backed termination verification | Closed — T5 / post-v1 |
| Proof receipts / proof obligations | Closed — T5 / post-v1 |
| OOF-R10/R11 as canon codes without gate proof | Closed — candidates until PROP-042-P2 PASS |
| Runtime execution, VM stack, TCO | Closed — PROP-039 boundary |
| Stable public API for T3 surface | Closed — experiment-pass only |
| `decreases count(items, extra)` multi-argument | Closed — not T3 in v0 |
| T3 via dotted-path syntax (`items.count`) | Closed — NUMERIC_ACCESSORS blocks; T3 is function-call form only |
| Full termination proof authority | Closed — T3 is numeric evidence with trust metadata |
| NUMERIC_ACCESSORS list changes (T2) | Closed — T2 list is frozen in PROP-041 |
| Cross-module numeric measure import | Closed — out of scope for v0 |
| Numeric measure as PROP-041 amendment | Closed — PROP-042 is the authority surface |
| igniter-lab/igniter-machine/PROP-042.md | Closed — unrelated lab-only fused-machine sketch; not this PROP |

---

## § 10. Open Questions Resolved (from PROP-041-T3-P1 design lock)

| # | Question | Decision |
|---|----------|----------|
| Q1 | New PROP or PROP-041 amendment? | New PROP — PROP-042 (clean governance separation) |
| Q2 | Canonical wording | Numeric measure evidence — not termination proof |
| Q3 | Syntax form | Function-call: `decreases count(items)` |
| Q4 | NUMERIC_ACCESSORS unchanged? | Yes — T3 opens function-call path, not dotted path |
| Q5 | v0 builtin list | `count(Collection[T])` only — closed |
| Q6 | User-defined measures | Deferred to v1 |
| Q7 | T1/T2 interaction | Strictly additive; dispatch priority extended |
| Q8 | OOF codes | OOF-R10/R11 (candidates until P2 gate) |
| Q9 | SemanticIR shape | `numeric_measure_v0` with `fn/arg/trust/source` sub-object |
| Q10 | `count(items) - 1` | T4, not T3 |
| Q11 | Trust level | `stdlib_numeric_certified` |
| Q12 | Text length | Deferred — Unicode receipt authority required |

---

## § 11. Conformance Evidence Required (PROP-042-P2 Scope)

PROP-042-P2 must implement a proof-local `T3Pipeline` in
`igniter-lang/experiments/prop042_numeric_measure_proof/` and prove all cases in the
following fixture matrix before this proposal advances to Stage 3.

| Case ID | Fixture | Expected result |
|---------|---------|----------------|
| T3a-1 | t3a_count_tail.ig | `decreases count(items)` + `recur(items.tail)` → no errors; `numeric_measure_v0` in SIR |
| T3a-2 | t3a_count_rest.ig | `decreases count(items)` + `recur(items.rest)` → no errors; `numeric_measure_v0` in SIR |
| T3a-3 | t3a_multi_input.ig | `decreases count(items)` with additional non-measured input → no errors |
| T3b-1 | t3b_sir_shape.ig | SIR: `variant_check="numeric_measure_v0"`, `fn="stdlib.collection.count"`, `arg`, `trust`, `source` |
| T3b-2 | t3b_sir_trust.ig | SIR: `trust="stdlib_numeric_certified"` |
| T3b-3 | t3b_sir_source.ig | SIR: `source="compiler_builtin"` |
| T3c-1 | t3c_plain_ref.ig | `recur(items)` plain ref → OOF-R11 fires |
| T3c-2 | t3c_wrong_variable.ig | `recur(other_items)` different variable → OOF-R11 fires |
| T3c-3 | t3c_unregistered_accessor.ig | `recur(items.head)` accessor not in T2 registry → OOF-R11 fires |
| T3d-1 | t3d_unknown_fn.ig | `decreases depth(items)` → OOF-R10 fires |
| T3d-2 | t3d_size_fn.ig | `decreases size(items)` → OOF-R10 fires (deferred) |
| T3d-3 | t3d_text_length.ig | `decreases byte_length(text)` → OOF-R10 fires (deferred) |
| T3e-1 | t3e_user_relation.ig | User-declared `size_relation Collection sub` + `recur(items.sub)` → T3 pass |
| T3f-1 | t3f_t1_regression.ig | T1 `decreases n` → `syntactic_v0` in SIR (unchanged) |
| T3f-2 | t3f_t1_arithmetic.ig | T1 `decreases n - 1` → `syntactic_v0` in SIR (unchanged) |
| T3g-1 | t3g_t2_regression.ig | T2 `decreases items.tail` → `structural_size_v1` in SIR (unchanged) |
| T3h-1 | t3h_dotted_count.ig | `decreases items.count` (dotted numeric) → OOF-R3 fires (not OOF-R10) |
| T3i-1 | t3i_multi_recur_pass.ig | Multi-recur: both `recur(items.tail)` sites pass → T3 pass |
| T3i-2 | t3i_multi_recur_fail.ig | Multi-recur: one correct, one wrong → OOF-R11 fires |

**Target:** ≥ 19 fixtures, all PASS. Comparable in scope to the OOF-R3 gate (33 fixtures).

The T3Pipeline may be a sub-class of the existing proof pipelines or a standalone module.
It must operate on the production parser, classifier, typechecker, and semanticir_emitter —
not a custom stub. This mirrors the T2 proof structure.

---

## § 12. Next Route

| Next step | Route | Status |
|-----------|-------|--------|
| PROP-042-P2: Proof-local experiment gate | `igniter-lang/experiments/prop042_numeric_measure_proof/` | Opens after this proposal is reviewed |
| PROP-042-P3: Authorization review | Parallel to PROP-041-P4 | Opens after P2 gate PASS |
| PROP-042-P4: Production edit planning | Classifier + TypeChecker + SemanticIR emitter | Opens after P3 |
| PROP-042-P5: Formal production implementation | `.rb` edits + verify_prop042_t3_production.rb | Opens after P4 |
| LAB-T3-P1: Rust lab symmetry | igniter-lab/igniter-compiler | Opens after P5 graduation |
| T4 (lexicographic / numeric arithmetic) | Post-T3 PROP (PROP-043 or equivalent) | Closed |
| T5 (SMT / proof receipts) | Post-v1 | Closed |
| Text length measures in T3 | Requires Unicode receipt canon authority + separate PROP amendment | Closed |
