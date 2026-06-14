# LANG-STDLIB-MATH-P1 — Proposal / Readiness

**Date:** 2026-06-14  
**Status:** CLOSED — ROUTED  
**Track:** lang / stdlib / math  
**Predecessors:** LAB-STDLIB-NUMERIC-FIXED-POINT-P1, LANG-STDLIB-NUMERIC-COMPARISON-P3/P4  

---

## 1. Trigger

The `air_combat` strategy/swarm application baseline closure (`LAB-AIR-COMBAT-BASELINE-P1`) exposes a significant standard library limitation under pressure **AC-P07**:
* Exact proportional navigation and steering laws require vector normalization (direction unit vectors) and true distance thresholds.
* Because the Igniter language lacks any square root (`sqrt`) or vector hypotenuse (`hypot`) standard library functions, `vec.ig` is forced to keep all distance measures squared (`VMag2`, `VDist2`), and `guidance.ig` must approximate steering via gain-scaled linear offsets clamped component-wise rather than along the true direction vector.
* While acceptable for a clean baseline proof, this workaround degrades physical simulation fidelity and forces developers to write complex axis-aligned clamping logic (`VClampSpeed`).

---

## 2. Design Questions & Decisions

### Question 1: What is the immediate math standard library surface?
**Decision: Bounded Integer Surface**
The immediate surface should expose three core integer arithmetic functions:
1. `stdlib.math.abs(x: Integer) -> Integer`
   * Computes the absolute value of `x`.
2. `stdlib.math.sqrt(x: Integer) -> Integer`
   * Computes the integer square root of `x`.
3. `stdlib.math.hypot(x: Integer, y: Integer) -> Integer`
   * Computes the length of the hypotenuse `sqrt(x^2 + y^2)` without intermediate overflow risks.

### Question 2: Should these math functions be fixed-point-aware?
**Decision: Strictly Integer Operations**
Fixed-point scaling is highly domain-specific:
* `neural_net` and `vector_math` use a scale of `1000` (`1.0` = `1000`).
* `air_combat` uses a scale of `100` (`1.0` = `100`).
Hardcoding a scale parameter into the stdlib or introducing multiple scaling variants (e.g. `sqrt_milli`, `sqrt_centi`) would clutter the compiler and VM bindings. Math functions must remain strictly integer-based. App-level contracts can adjust inputs/outputs dynamically where necessary (e.g. scaling by multiplying before `sqrt` or dividing after).

### Question 3: What totality/rounding policy is acceptable for `sqrt`?
**Decision: Floor Truncation (`isqrt`)**
`sqrt(x)` returns the largest integer \(y\) such that \(y^2 \le x\). This matches the standard behavior of integer square root (`isqrt`) across modern programming languages and ensures clean totality over integers.
* E.g., `sqrt(9) -> 3`, `sqrt(10) -> 3`, `sqrt(15) -> 3`, `sqrt(16) -> 4`.

### Question 4: How are negative inputs handled?
**Decision: Clamped Totality at Runtime + Compile-time Literal Guard**
* **At Runtime**: To prevent transient negative inputs (e.g. from Kalman filter estimation fluctuations) from crashing simulation ticks, `sqrt(x)` is total: for any `x < 0`, it returns `0`.
* **At Compile-time**: If the compiler detects a literal negative integer passed to `sqrt` (e.g. `sqrt(-25)` or `sqrt(0 - 5)`), it must block compilation with a diagnostic error: `OOF-MTH1: literal argument to sqrt is negative`.

### Question 5: Do other apps besides `air_combat` need this?
**Decision: Yes, for vector math and neural networks**
* `vector_math` currently implements custom squared length computations (`Vec2LengthSq`) and is blocked from implementing true vector normalization.
* `neural_net` uses sigmoid piecewise linear approximations; absolute differences (`abs`) will simplify threshold calculations and activation functions.

### Question 6: Is this stdlib-only or does it require VM changes?
**Decision: Stdlib-only (no new VM instructions)**
No new virtual machine instructions are introduced. The compiler lowers calls to standard library bindings:
* Ruby toolchain dispatches to `Integer.sqrt` or `Math.sqrt(x).to_i`.
* Rust toolchain dispatches to Rust's integer square root or `num-integer::isqrt` crate support in standard library bindings.
The functions are formally declared in `docs/spec/stdlib-inventory.json`.

### Question 7: What proof matrix and OOF namespace should be used?
**Decision: `OOF-MTH*` Namespace**
* **Diagnostic Code**: `OOF-MTH1` (negative literal input to `sqrt` or `hypot` calculations where applicable).
* **Verification Matrix**:
  * `abs` behavior: verify `abs(5) -> 5`, `abs(-5) -> 5`, `abs(0) -> 0`.
  * `sqrt` behavior: verify `sqrt(25) -> 5`, `sqrt(26) -> 5`, `sqrt(0) -> 0`, `sqrt(-10) -> 0`.
  * `hypot` behavior: verify `hypot(3, 4) -> 5`, `hypot(-3, -4) -> 5`.
  * Type constraints: reject non-Integer args with `OOF-TY0`.
  * Arity constraints: reject wrong arity with `OOF-TY0`.

---

## 3. Stdlib Inventory Specifications

```json
[
  {
    "canonical_name": "stdlib.math.abs",
    "semantic_ir_name": "stdlib.math.abs",
    "aliases": [{"kind": "source_alias", "name": "abs"}],
    "category": "math",
    "lifecycle_status": "production-implemented",
    "semantic_stability": "design-locked",
    "lowering_status": "dual-toolchain",
    "compatibility_status": "pre-v1-none",
    "fragment_class": "core",
    "purity": "pure",
    "deterministic": true,
    "totality": "total",
    "type_params": [],
    "input_signature": ["Integer"],
    "output_signature": "Integer",
    "diagnostics": [],
    "failure_behavior": "none"
  },
  {
    "canonical_name": "stdlib.math.sqrt",
    "semantic_ir_name": "stdlib.math.sqrt",
    "aliases": [{"kind": "source_alias", "name": "sqrt"}],
    "category": "math",
    "lifecycle_status": "production-implemented",
    "semantic_stability": "design-locked",
    "lowering_status": "dual-toolchain",
    "compatibility_status": "pre-v1-none",
    "fragment_class": "core",
    "purity": "pure",
    "deterministic": true,
    "totality": "total: returns 0 for negative input",
    "type_params": [],
    "input_signature": ["Integer"],
    "output_signature": "Integer",
    "diagnostics": ["OOF-MTH1"],
    "failure_behavior": "negative literal is compile-time OOF-MTH1; runtime clamps to 0"
  },
  {
    "canonical_name": "stdlib.math.hypot",
    "semantic_ir_name": "stdlib.math.hypot",
    "aliases": [{"kind": "source_alias", "name": "hypot"}],
    "category": "math",
    "lifecycle_status": "production-implemented",
    "semantic_stability": "design-locked",
    "lowering_status": "dual-toolchain",
    "compatibility_status": "pre-v1-none",
    "fragment_class": "core",
    "purity": "pure",
    "deterministic": true,
    "totality": "total",
    "type_params": [],
    "input_signature": ["Integer", "Integer"],
    "output_signature": "Integer",
    "diagnostics": [],
    "failure_behavior": "none"
  }
]
```

---

## 4. Closed Surfaces

* No float or decimal math support.
* No trigonometry (`sin`, `cos`, `tan`).
* No logarithmic or exponential operations (`log`, `exp`).
* No runtime execution widening.
