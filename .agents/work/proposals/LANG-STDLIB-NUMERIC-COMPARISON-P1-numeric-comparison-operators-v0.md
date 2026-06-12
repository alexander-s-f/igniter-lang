# LANG-STDLIB-NUMERIC-COMPARISON-P1 — Numeric Comparison Operators

**Track:** lang / stdlib / numeric / comparison
**Route:** READINESS PROOF
**Status:** CLOSED — PROVED 37/37 PASS
**Date:** 2026-06-12
**Proof runner:** `igniter-lang/experiments/numeric_comparison_proof/verify_numeric_comparison_p1.rb`
**Predecessors:** LAB-STDLIB-NUMERIC-FIXED-POINT-P1 (NN-P03 / STAB-P4 operator gate); LAB-NEURAL-NET-BASELINE-P1 (85/85, app pressure source)

---

## Summary

Proves the current state of `<`, `>`, `<=`, `>=` in both Ruby and Rust Igniter compilers.
`>` is already implemented in both TCs. `<` exists in Rust but is absent from Ruby. `<=` and `>=`
are absent from both TCs. All four operators parse correctly — the gaps are in typecheck dispatch only.

**Next route:** LANG-STDLIB-NUMERIC-COMPARISON-P2 — implementation planning for Ruby `<`/`<=`/`>=` +
Rust `<=`/`>=` + inventory 4-entry promotion.

---

## 1. Scoping Questions — All Answered

### Q1: Which operators in v0?

**Decided: `<`, `<=`, `>`, `>=` — all four.**

These are the standard integer comparison operators. All four parse correctly today (Ruby parser
`BINARY_OPS` includes them at precedence 3; Rust parser `op_prec` returns `Some(3)` for all four).
No parser work is needed. Only TC dispatch is missing.

`==` stays in the text/equality primitive track (`stdlib.primitive.eq`). This card does not
touch `==`.

### Q2: Which operand types?

**Decided: Integer only in v0. Decimal HOLD. Float deferred.**

- **Integer:** All existing app pressure is Integer (neural_net scale=1000 milli-values,
  arch_patterns amount checks, dataframes row filters). Integer comparison requires zero new
  infrastructure — the pattern is the same as the existing `>` arm.
- **Decimal[N]: HOLD.** BK-P02 blocks Decimal equality; BK-P03 blocks Decimal literal typing.
  No Decimal comparison pressure exists in actual code. The Decimal comparison track belongs to
  LAB-STDLIB-DECIMAL-P1 → LANG-STDLIB-DECIMAL-OPERATOR-P1, not here.
- **Float: DEFERRED.** No real Float type support exists in the language.

Proof evidence: `Decimal[2] < Decimal[2]` compiles with OOF-TY0 in Ruby (I-01 proves the gap is
structural, not a missing comparison case — Decimal arithmetic is separately blocked).

### Q3: Canonical SIR names?

**Decided: `stdlib.integer.*` namespace.**

The established precedent from existing code:
- Ruby TC `operator_type`: `">" → ["stdlib.integer.gt", Bool]`
- Rust TC: `">" → ("stdlib.integer.gt", Bool)` and `"<" → ("stdlib.integer.lt", Bool)`
- Inventory: `stdlib.integer.gt` entry (orphaned/sketch/dual-toolchain)

The `stdlib.primitive.cmp.*` alternative would only be appropriate if comparison generalized to
non-Integer types (Text ordering, Decimal). In v0 with Integer-only scope, `stdlib.integer.*`
is the correct namespace. The `stdlib.primitive.*` namespace is for cross-type primitives
(`stdlib.primitive.eq`, `stdlib.bool.and`) — comparison ordering is Integer-specific here.

**Canonical names for v0:**

| Operator | SIR Name |
|----------|----------|
| `>` | `stdlib.integer.gt` ✓ (already live) |
| `<` | `stdlib.integer.lt` (Rust TC live; Ruby + inventory missing) |
| `<=` | `stdlib.integer.lte` (both TCs missing; inventory missing) |
| `>=` | `stdlib.integer.gte` (both TCs missing; inventory missing) |

### Q4: Diagnostics?

**Decided: OOF-TY0 reuse. No new OOF codes.**

The existing `>` arm already emits `OOF-TY0` for type mismatches (e.g., Text > Integer). The
`<`, `<=`, `>=` arms will follow the same pattern: OOF-TY0 with message
`"Type mismatch: expected Integer, got X+Y"` (or similar). This is consistent with all
existing binary operator arms.

No numeric-specific OOF code is needed in v0. Numeric-specific diagnostics (overflow, scale
mismatch) are a future concern that would require separate inventory entries or a dedicated
`OOF-NUM*` namespace — not in scope here.

### Q5: Unknown permissive?

**Decided: YES — Unknown is permissive on both sides.**

The existing `>` arm: `unless unknown?(left, right) || ...`. Same pattern applies to `<`, `<=`, `>=`.
If either operand is Unknown, skip the type error. This matches every other binary operator arm
in both Ruby and Rust TCs.

### Q6: Does `==` stay in the text/equality track?

**Decided: YES — `==` stays as `stdlib.primitive.eq`. No change.**

`==` is cross-type (Text/String/Integer/Bool). It is separate from numeric ordering. This card
does not touch `==`, `!=`, `&&`, `||`, or any other non-comparison operator.

---

## 2. Current-State Matrix

### Ruby TC (`operator_type` in `typechecker.rb`)

| Operator | Ruby TC Status | SIR Name emitted | OOF code |
|----------|---------------|------------------|----------|
| `+` | ✓ | `stdlib.integer.add` | OOF-TY0 on non-Integer |
| `-` | ✓ | `stdlib.integer.sub` | OOF-TY0 on non-Integer |
| `*` | ✓ | `stdlib.integer.mul` | OOF-TY0 on non-Integer |
| `/` | ✓ | `stdlib.integer.div` | OOF-TY0 on non-Integer |
| `>` | ✓ | `stdlib.integer.gt` | OOF-TY0 on non-Integer |
| `&&` | ✓ | `stdlib.bool.and` | OOF-TY0 on non-Bool |
| `==` | ✓ | `stdlib.primitive.eq` | OOF-TY0 on incompatible pair |
| `<` | **✗ GAP** | `stdlib.unsupported.<` | OOF-TY0 "Unsupported operator: <" |
| `<=` | **✗ GAP** | `stdlib.unsupported.<=` | OOF-TY0 "Unsupported operator: <=" |
| `>=` | **✗ GAP** | `stdlib.unsupported.>=` | OOF-TY0 "Unsupported operator: >=" |

### Rust TC (`match op` in `typechecker.rs`)

| Operator | Rust TC Status | SIR Name emitted | Note |
|----------|---------------|------------------|------|
| `>` | ✓ | (`stdlib.integer.gt`, Bool) | |
| `<` | ✓ | (`stdlib.integer.lt`, Bool) | Ruby gap only |
| `&&` | ✓ | (`stdlib.bool.and`, Bool) | |
| `==` | ✓ | (`stdlib.primitive.eq`, Bool) | |
| `<=` | **✗ GAP** | (`stdlib.unsupported.<=`, Unknown) | `_` arm |
| `>=` | **✗ GAP** | (`stdlib.unsupported.>=`, Unknown) | `_` arm |

### Rust SIR binary_op qualification gap (secondary)

Ruby TC emits `"operator": "stdlib.integer.gt"` on `binary_op` SIR nodes. Rust emitter emits
only `"op": ">"` (raw symbol) — no qualified name in the SIR binary_op node. This is a secondary
SIR qualification gap, separate from the TC dispatch gap. It should be noted in the P2 planning
card but is not a blocker for functional correctness — the TC dispatch (resolved_type=Bool +
OOF-TY0 guards) is the material gap.

### Mismatch matrix

| Operator | Ruby | Rust | Gap |
|----------|------|------|-----|
| `>` | ✓ ok | ✓ ok | None (dual-toolchain, orphaned in inventory) |
| `<` | ✗ OOF-TY0 | ✓ ok | Ruby only — 1-arm insertion needed |
| `<=` | ✗ OOF-TY0 | ✗ OOF-TY0 | Both — 2 insertions needed |
| `>=` | ✗ OOF-TY0 | ✗ OOF-TY0 | Both — 2 insertions needed |

---

## 3. App Pressure

### 3.1 `neural_net/activations.ig` — Two operators

**ReLU function (line 12):**
```
compute out = if x > 0 { x } else { 0 }
```
`>` works in both Ruby and Rust. This compiles today.

**SigmoidApprox function (lines 22–29):**
```
-- x < -2500 => 0
-- x > 2500  => 1000
-- else => (x / 5) + 500
compute out = if x < (0 - 2500) { 0 } else { if x > 2500 { 1000 } else { (x / 5) + 500 } }
```
`x < (0 - 2500)` → OOF-TY0 in Ruby. Compiles in Rust (D-05: 37/37). The sigmoid function
is currently blocked in Ruby. The `>` in the else branch works.

### 3.2 `arch_patterns/pipeline.ig` — `<` validation guards

Lines 30 and 108 (two separate guards):
```
if ctx.command.amount < 1 { ... }
if ctx.account.balance < ctx.command.amount { ... }
```
Both blocked in Ruby (OOF-TY0). Both compile in Rust (F-05: 37/37).

### 3.3 `decision_tree/evaluator.ig` — `>` threshold (already works)

```
if node.threshold > 0 { ... }
```
Works in both Ruby and Rust (`>` is implemented).

### 3.4 `arch_patterns/state_machine.ig` — `>` balance check (already works)

```
compute passed = if balance > required_min { ... }
```
Works in both.

### 3.5 `dataframes/dataframe.ig` — `>` filter guard (already works)

```
if p.val > min_val { ... }
```
Works in both.

### 3.6 No `<=` / `>=` in actual code (only in comments)

`dataframes/example.ig` line 51: `-- Filter where age >= 35` (comment only, not code).
`decision_tree/example.ig` line 12: `-- [income > 50000?]` (comment/diagram, not code).

No current production pressure for `<=` or `>=`. They are natural completions of the operator set
but have no blocking app fixtures today.

---

## 4. Relation to Other Cards

### Relation to LAB-STDLIB-NUMERIC-FIXED-POINT-P1

That card established that neural_net and vector_math use fixed-point Integer convention
(scale=1000). The SigmoidApprox uses `< (0 - 2500)` which is Integer comparison — unblocked
by fixing `<` in Ruby. No fixed-point helpers (multiply-normalize, scale conversion) are
needed for comparison.

**Comparison is sufficient for all threshold-style activations.**

### Relation to LAB-UNARY-MINUS-P1

Comparison operators are independent of unary minus. The sigmoid `x < (0 - 2500)` uses
`0 - 2500` (binary subtract, already works) as the threshold — it does NOT require unary minus.
`<` is the only gap for this fixture.

### Relation to `==` / text equality (LANG-STDLIB-TEXT-EQUALITY-P3)

`==` is already implemented in both TCs (`stdlib.primitive.eq`). This card does not touch `==`.
The comparison operators (`<`, `<=`, `>`, `>=`) return Bool; equality returns Bool. They are
additive, not conflicting.

### Relation to Decimal

Decimal comparison is HOLD. The BK-P02/BK-P03 track (Decimal equality + literal typing) must
be resolved before any Decimal operator work. This card is explicitly Integer-only.

---

## 5. Inventory State

### `stdlib.integer.gt` (PRESENT, orphaned)

```json
{
  "canonical_name": "stdlib.integer.gt",
  "lifecycle_status": "orphaned",
  "semantic_stability": "sketch",
  "lowering_status": "dual-toolchain",
  "owner_surface": "operator-lowering-implicit",
  "compatibility_note": "Numeric category is HOLD (STAB-P4 operator parity gate). Triage route required before any promotion."
}
```

**P2 action:** Upgrade to `lab-implemented` / `ruby-only` → `dual-toolchain` (already dual-toolchain). Promote `lifecycle_status` from `orphaned` to `lab-implemented`. Add `aliases` with `source_alias: ">"`.

Wait — operator lowering entries don't have `source_alias` in the same sense as call-site stdlib entries. The source alias for operator-lowering entries is the operator token (`>`). The P2 planning should decide whether to treat these as `operator-lowering-implicit` entries (no user-callable alias) or assign an `source_alias: ">"` convention.

### `stdlib.integer.lt`, `stdlib.integer.lte`, `stdlib.integer.gte` (ABSENT)

All three must be added to the inventory in P2. Proposed entry shape:

```json
{
  "canonical_name": "stdlib.integer.lt",
  "semantic_ir_name": "stdlib.integer.lt",
  "legacy_sir": null,
  "aliases": [],
  "category": "numeric",
  "lifecycle_status": "lab-implemented",
  "semantic_stability": "stable",
  "lowering_status": "ruby-only",   // promoted to dual-toolchain once Rust P3 done
  "purity": "pure",
  "deterministic": true,
  "totality": "total",
  "input_signature": ["Integer", "Integer"],
  "output_signature": "Bool",
  "diagnostics": ["OOF-TY0"],
  "authority_surface": "none",
  "owner_surface": "operator-lowering-implicit"
}
```

`stdlib.integer.lte` and `stdlib.integer.gte` start as `ruby-only` (if Ruby is implemented first),
upgraded to `dual-toolchain` when Rust P3 (or P2 Rust slice) lands.

---

## 6. Proof Matrix

| Section | Description | Checks | Result |
|---------|-------------|--------|--------|
| A | Ruby `>` baseline (regression: already works) | 4 | PASS |
| B | Ruby `<` gap (OOF-TY0; message; sigmoid form) | 4 | PASS |
| C | Ruby `<=` / `>=` gap | 4 | PASS |
| D | Rust `>` and `<` work (status=ok; SIR op field) | 5 | PASS |
| E | Rust `<=` / `>=` gap | 4 | PASS |
| F | App pressure (ReLU / sigmoid / pipeline) | 5 | PASS |
| G | Mismatch matrix (source text confirmation) | 4 | PASS |
| H | Inventory (gt present orphaned; lt/lte/gte absent) | 4 | PASS |
| I | Authority closed (Decimal HOLD; no arithmetic; unary separate) | 3 | PASS |
| **Total** | | **37** | **PASS** |

---

## 7. P2 Implementation Scope

### Files (minimal — all insertions, no deletions)

| File | Change |
|------|--------|
| `igniter-lang/lib/igniter_lang/typechecker.rb` | Add `when "<"`, `when "<="`, `when ">="` arms in `operator_type` (3 arms, ~12 lines) |
| `igniter-lab/igniter-compiler/src/typechecker.rs` | Add `"<="` and `">="` arms in `match op` (2 arms, ~20 lines) |
| `igniter-lang/docs/spec/stdlib-inventory.json` | Add 3 new entries + promote `stdlib.integer.gt` from orphaned to lab-implemented |

### Ruby TC arms (sketch)

```ruby
when "<"
  type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}+#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
  ["stdlib.integer.lt", type_ir("Bool")]
when "<="
  type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}+#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
  ["stdlib.integer.lte", type_ir("Bool")]
when ">="
  type_errors << type_mismatch(type_ir("Integer"), type_ir("#{left_name}+#{right_name}"), node_name) unless unknown?(left, right) || left_name == "Integer" && right_name == "Integer"
  ["stdlib.integer.gte", type_ir("Bool")]
```

Three lines each (error push + return). Insert after `when ">"` arm, before `when "&&"`.

### Rust TC arms (sketch)

```rust
"<=" => {
    if (left_name != "Integer" || right_name != "Integer") && left_name != "Unknown" && right_name != "Unknown" {
        type_errors.push(ClassifierDiagnostic { rule: "OOF-TY0".to_string(), message: format!("Type mismatch for <=: expected Integer on both sides, got {} <= {}", left_name, right_name), node: node_name.to_string(), line: None });
    }
    ("stdlib.integer.lte".to_string(), self.type_ir(&serde_json::Value::String("Bool".to_string())))
}
">=" => {
    // same pattern, "stdlib.integer.gte"
}
```

Insert after `"<"` arm, before `_` arm.

### Proof matrix for P2 (≥40 checks / ~9 sections)

| Section | Coverage |
|---------|----------|
| A | Regression: `>` unchanged; `==`, `&&`, arithmetic unchanged; Ruby+Rust |
| B | Ruby `<` happy (Integer/Integer → ok; Bool; `stdlib.integer.lt`) |
| C | Ruby `<=` and `>=` happy |
| D | Rust `<=` and `>=` happy |
| E | OOF-TY0 type guard active for all four (non-Integer args) |
| F | Unknown permissive for all four |
| G | SIR operator qualification (Ruby emits `"operator"` field; Rust SIR gap noted) |
| H | App fixtures compile (sigmoid, pipeline, ReLU — regression) |
| I | Inventory (lt/lte/gte entries present; gt promoted) |

---

## 8. Authority Boundary

- No arithmetic operators changed (`+`, `-`, `*`, `/` unchanged).
- No unary minus (separate track: LAB-UNARY-MINUS-P1 → LANG-UNARY-OPERATORS-P2).
- No Decimal comparison (HOLD: BK-P02 track).
- No Float (deferred: no real Float type).
- No `==` changes (text equality track).
- No parser changes (all four operators already parsed).
- No VM/runtime changes (VM already handles Integer comparison at runtime; no new dispatch needed).
- No assembler changes.
- No new OOF codes (OOF-TY0 reused).
- Inventory: 3 new entries + 1 promotion. No digest recomputation required in P2
  (follows append/is_empty precedent — digest recomputed when inventory stabilizes).
