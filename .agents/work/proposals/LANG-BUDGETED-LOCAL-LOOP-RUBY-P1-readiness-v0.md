# Proposal: LANG-BUDGETED-LOCAL-LOOP-RUBY-P1 Readiness

**Date:** 2026-06-15  
**Status:** PROPOSED — READINESS AND PARITY STUDY ONLY  
**Route:** lang / control-flow / BudgetedLocalLoop / Ruby parity readiness  
**Authority:** readiness and parity planning only; no implementation  

---

## 1. Rust/Ruby Divergence Analysis

### 1.1 The Symptom
Managed bounded local loops (`loop ... max_steps`) are dual-parsed cleanly. However, in the `job_runner` retry simulator, rewriting `RunWithRetry3` as a managed loop body that reassigns compute bindings triggers `OOF-L7` (targets outer contract symbol read-only violation) under the Ruby toolchain but compiles with 0 diagnostics under the Rust toolchain.

### 1.2 The Root Cause
The divergence resides in the loop body typechecking logic of the two compilers:

1. **Rust TypeChecker (`igniter-compiler/src/typechecker.rs`):**
   In the Rust compiler, the target checks for loop bodies are conditional on the presence of `lead` bindings inside the body:
   ```rust
   let is_gate8_body = body_nodes.iter().any(|n| n.kind == "lead");
   ...
   if is_gate8_body {
       // Perform OOF-L7 and OOF-L5 target checks
   }
   ```
   If a loop has **no `lead` bindings** in its body (e.g. `is_gate8_body == false`), the Rust compiler completely bypasses the `OOF-L7` checks. This allows the body to reassign outer contract symbols (e.g. `compute outer_var = outer_var + item`) for VM backwards-compatibility.

2. **Ruby TypeChecker (`igniter-lang/lib/igniter_lang/typechecker.rb`):**
   In the Ruby compiler, `check_loop_body` unconditionally runs target checks for any `compute` node inside a loop body, regardless of whether `lead` bindings are present:
   ```ruby
   # compute must target a lead binding — not outer symbols, not item
   if target == item_name
     errors << oof("OOF-L7", ...)
   elsif outer_symbols.key?(target) && !lead_names.include?(target)
     errors << oof("OOF-L7", ...)
   elsif !lead_names.include?(target) && ...
     errors << oof("OOF-L5", ...)
   end
   ```
   Thus, if a loop body mutates an outer symbol without declaring a `lead` binding, Ruby raises `OOF-L7`. If it targets any other symbol, it raises `OOF-L5`. Any loop body reassignments without `lead` are rejected.

---

## 2. Job Runner Unrolling Analysis

Today, the `job_runner` retry simulator (`igniter-lab/igniter-apps/job_runner/engine.ig`) unrolls three attempts by hand via `RunWithRetry3`:

```igniter
pure contract RunWithRetry3 {
  input req : JobRequest
  input ok1 : Integer
  input ok2 : Integer
  input ok3 : Integer

  compute known = call_contract("KnownJob", req.job_class)
  compute result = call_contract("DispatchJob", req.job_class, req.job_id, req.arg1, req.arg2)

  compute o1 = if known == 0 {
    DeadLetter { reason: "unknown job class" }
  } else {
    call_contract("AttemptOutcome", result, ok1, 1, req.max_attempts)
  }
  compute o2 = if call_contract("ShouldRetry", o1) == 1 {
    call_contract("AttemptOutcome", result, ok2, 2, req.max_attempts)
  } else {
    o1
  }
  compute o3 = if call_contract("ShouldRetry", o2) == 1 {
    call_contract("AttemptOutcome", result, ok3, 3, req.max_attempts)
  } else {
    o2
  }
  output o3 : JobOutcome
}
```

This manual unrolling is necessary for two reasons:
1. **Divergence:** As noted above, mutating an outer state binding within a local loop body is rejected by the canon Ruby toolchain, making a naive loop implementation not dual-clean.
2. **Loop Void/Unit Return:** In PROP-039 v0, a local loop node (`loop_node`) always evaluates to the type `Unit`. It has no syntax to return a value (since `break <value>` is deferred and there are no expression semantics for local loops). Thus, a loop has no pure way to pass a computed outcome back to the outer contract without mutating outer contract variables—which is strictly forbidden by `OOF-L7` to maintain single-assignment purity.

---

## 3. Route Evaluation and Recommendation

We evaluate three potential routes to resolve the divergence:

### Route A: Ruby Parity for BudgetedLocalLoop (Relax Ruby TC)
Update Ruby's typechecker to mirror Rust's `is_gate8_body` conditional check.
* **Pros:** Allows the `job_runner` retry simulator to compile with a managed loop that mutates an outer outcome symbol.
* **Cons:** Violates referential transparency and single-assignment purity by allowing mutable side-effects/reassignments on outer variables from within loop bodies. This is a significant safety regression and contradicts `OOF-L7`'s status as an **experiment-pass** rule in `docs/spec/ch13-managed-recursion.md`.

### Route B: A Narrower Retry-Loop Idiom
Introduce a new construct, such as `retry_loop`, designed specifically for retry semantics.
* **Pros:** Specialized ergonomics.
* **Cons:** Widens the language surface, requiring new parser grammar, typechecker rules, and emitter code, adding complexity for a narrow use case.

### Route C: Deferral in Favor of Fold-to-Struct (RECOMMENDED)
Retain `BudgetedLocalLoop` as a restricted experiment-only surface, refuse to relax `OOF-L7` in Ruby, and align Rust to strictly reject outer variable reassignments in loops. Recommend the use of **fold-to-struct** (which is already implemented, closed, and dual-clean) for retry-loop patterns that need loop repetition.
* **Pros:**
  - Preserves strict referential transparency and single-assignment purity.
  - Avoids compiler code changes for parser/compiler pipelines.
  - `fold` naturally threads accumulator state (fully pure) and **returns a value** (the final accumulator), which can be bound directly to a compute variable and returned by the contract.
* **Cons:** Requires constructing a dummy collection of attempts to drive the fold.

---

## 4. Modeling Retries with Fold-to-Struct

Using the closed and dual-clean `fold` (LANG-FOLD-STRUCT-ACCUMULATOR) implementation, a retry loop can be expressed cleanly without mutating any outer state. 

### 4.1 Accumulator Type
First, we define a struct/record type to hold the threaded state:
```igniter
type RetryState {
  outcome: JobOutcome
  ok_injections: Collection[Integer]
}
```

### 4.2 Pure Fold Contract
The retry loop is then modeled as a fold over a collection of attempt indices:
```igniter
pure contract RunWithRetryFold {
  input req : JobRequest
  input ok_injections : Collection[Integer] -- e.g. [ok1, ok2, ok3]

  compute known = call_contract("KnownJob", req.job_class)
  compute result = call_contract("DispatchJob", req.job_class, req.job_id, req.arg1, req.arg2)

  compute init_outcome = if known == 0 {
    DeadLetter { reason: "unknown job class" }
  } else {
    Done { result: 0, attempts: 0 } -- dummy initial
  }

  compute initial_state = {
    outcome: init_outcome,
    ok_injections: ok_injections
  }

  -- Fold threads the retry state through the attempts
  compute final_state = fold(
    range(1, 4), -- Collection[Integer]: [1, 2, 3]
    initial_state,
    (acc, attempt) -> {
      outcome: if call_contract("ShouldRetry", acc.outcome) == 1 {
        call_contract("AttemptOutcome", result, get(acc.ok_injections, attempt), attempt, req.max_attempts)
      } else {
        acc.outcome
      },
      ok_injections: acc.ok_injections
    }
  )

  output final_outcome: JobOutcome = final_state.outcome
}
```
This is fully pure, threads state explicitly, returns the final outcome, and compiles dual-clean under the existing language features.

---

## 5. Alignment Guidelines

To close the divergence, the Rust lab typechecker should be hardened to align with the canon Ruby typechecker. The conditional check `if is_gate8_body` should be removed in a future implementation card, forcing the Rust typechecker to unconditionally check for `OOF-L7` and `OOF-L5` targets in all loop bodies:

```rust
// In igniter-lab/igniter-compiler/src/typechecker.rs:
// Remove is_gate8_body check and unconditionally enforce OOF-L7/OOF-L5
if target == &item_var || target == "item" {
    // emit OOF-L7
} else if symbol_types.contains_key(target.as_str()) && !lead_names.contains(target) {
    // emit OOF-L7
} else if !lead_names.contains(target) && !symbol_types.contains_key(target.as_str()) && target != &item_var && target != "item" {
    // emit OOF-L5
}
```
This ensures complete toolchain parity and prevents the lab compiler from accepting unsafe, non-canonical mutation patterns.
