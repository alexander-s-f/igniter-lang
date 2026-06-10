# PROP-044: Path B Runtime Lowering Semantics — v0

**Card:** PROP-044-P8  
**Route:** GOVERNANCE / DESIGN LOCK / NO IMPLEMENTATION  
**Status:** LOCKED  
**Date:** 2026-06-10  
**Authority:** PROP-044 Ruby canon surfaces + Rust lab proof chain  
**Category:** lang / governance

---

## 1. Decision Summary

**Path B is accepted as the current lab runtime semantics for `variant`/`match`.**

Three decisions are locked:

1. **`variant`/`match` are source and typechecking authority surfaces.** They are lexical syntax and TypeChecker enforcement boundaries, not runtime type primitives. The VM does not receive a new `Value::Variant` type.

2. **Runtime representation in the lab VM is Path B record lowering.** A `variant_construct` expression is lowered by the compiler to `OP_PUSH_RECORD` with compiler-owned discriminant fields. This is an internal lowering strategy, not a user-facing convention.

3. **`Value::Variant` and `OP_MATCH` remain closed.** No evidence in the lab proof chain requires native runtime variant identity. Unless a future separate gate proves they are necessary and the risk justifies it, these surfaces stay closed.

This is a governance lock, not an implementation card. No compiler, VM, or canon source file is changed by this card.

---

## 2. Evidence Chain

The following proof chain grounds this decision:

| Card | What it proved | Checks |
|------|---------------|--------|
| PROP-044-P3 | Ruby parser: `variant`/`match` keywords, `VariantDecl`, `MatchExpr` AST nodes, `ParsedProgram.variants` | 50/50 |
| PROP-044-P5 | Ruby TypeChecker: `@variant_shapes`, exhaustive match accepted, `OOF-KIND1..5` ACTIVE | 75/75 |
| PROP-044-P6 | Ruby SemanticIR emitter: `variant_decl`, `variant_construct`, `match_node`, `match_arm` shapes | 50/50 |
| PROP-044-P7-READINESS | Rust toolchain blocker survey: ZERO variant/match support in Rust path; Path B recommended | 15/15 |
| LAB-VARIANT-RUST-P1 | Rust front-end (lexer → parser → typechecker → SIR emitter); OOF-KIND1..5 parity; SIR structural parity with Ruby P6 | 39/39 |
| LAB-VARIANT-VM-P1 | VM Path B lowering: 7 fixtures; construct + match + payload + wildcard + fail-closed + nested `match_expr`; compiler.rs-only | 42/42 |
| LAB-OUTCOME-VARIANT-P1 | `ReconciliationOutcome` (11 arms) executed end-to-end; OOF-KIND1..5 on real domain fixture; No-Upward-Coercion invariants proved | 58/58 |
| LAB-EPISTEMIC-OUTCOME-P4 | KDR routing as baseline; P4 STAB flag (Ruby rejects `==`/`||`) grounded the need for variant surface | 46/46 |

Combined: **335 checks across 8 cards**. No card required `Value::Variant` or `OP_MATCH`.

---

## 3. Runtime Representation

### Path B: Variant as Compiler-Lowered Record

A `variant_construct` expression in source Igniter:

```igniter
ConfirmedSucceededReal { request_id: "req-001", resource: "payment/123" }
```

is lowered by the compiler to an `OP_PUSH_RECORD` instruction with the following field layout:

| Field | Value | Owner |
|-------|-------|-------|
| `__arm` | arm name (`"ConfirmedSucceededReal"`) | compiler-owned discriminant |
| `__variant` | variant type name (`"ReconciliationOutcome"`) | compiler-owned diagnostic |
| payload fields | user-declared fields | user-defined |

Keys are sorted before emission (BTreeMap / alphabetical order), satisfying `OP_PUSH_RECORD`'s sorted-key invariant.

**Critically:** This lowering is a compiler strategy. Users do not write `__arm` or `__variant` in source. A user who writes `{ __arm: "Foo" }` is authoring a plain record, not a variant — the TypeChecker does not recognize it as a variant arm, and the VM does not treat it as one.

---

## 4. Match Lowering Semantics

A `match_node` in SemanticIR is lowered by the VM compiler to existing primitives:

```
OP_LOAD_REG  <subject_reg>
OP_GET_FIELD "__arm"
OP_PUSH_LIT  <arm_name>
OP_EQ
OP_JMP_UNLESS <next_arm_ip>
-- arm body --
OP_JMP <end_ip>
<next arm ...>
```

**Payload bindings:** each binding `x` in the arm pattern extracts the field from the subject record:

```
OP_LOAD_REG  <subject_reg>
OP_GET_FIELD <field_name>
OP_STORE_REG <binding_reg>
```

The binding register is inserted into `compute_node_registers` for the arm body and removed afterward.

**Wildcard arm:** lowered as a final unconditional body — no `OP_GET_FIELD`/`OP_EQ`/`OP_JMP_UNLESS` check.

**No new opcode.** The entire match lowering uses: `OP_LOAD_REG`, `OP_STORE_REG`, `OP_GET_FIELD`, `OP_PUSH_LIT`, `OP_EQ`, `OP_JMP_UNLESS`, `OP_JMP`. All pre-existing.

**Nested `match_expr` alias:** ARM bodies may themselves contain match expressions. The raw AST form of a nested match carries `kind: "match_expr"` (from `annotate_expr_with_type` preserving `Expr::MatchExpr`'s serde tag), while top-level matches are renamed to `kind: "match_node"` by `lower_annotated_expr`. Both are handled by a single Rust match arm: `"match_node" | "match_expr"`.

---

## 5. Exhaustiveness and Narrowing

| Property | Owner | Mechanism |
|----------|-------|-----------|
| Exhaustiveness (all arms covered) | TypeChecker | OOF-KIND1 fires if match is non-exhaustive |
| Unknown arm (arm not in variant) | TypeChecker | OOF-KIND2 |
| Duplicate arm | TypeChecker | OOF-KIND3 |
| Non-variant subject | TypeChecker | OOF-KIND4 |
| Divergent arm result types | TypeChecker | OOF-KIND5 |
| Arm-body type narrowing | TypeChecker | per-arm `variant_shapes` scope |
| Fail-closed on unmatched `__arm` | VM | `OP_UNSUPPORTED` appended for non-wildcard match |
| Malformed variant (missing `__arm`) | VM | `OP_GET_FIELD` returns error |

The VM does **not** prove exhaustiveness. It trusts that the TypeChecker-validated SIR has already ensured coverage. The VM's `OP_UNSUPPORTED` fallback is a safety net against compiler bugs or hand-authored SIR, not a semantic exhaustiveness check.

**Runtime mismatch must never silently return Nil.** If `__arm` is absent or unrecognized and no wildcard is present, the VM must error, not coerce.

---

## 6. Source/Type Authority vs. Runtime Representation

There are three distinct layers:

| Layer | What it sees | Authority |
|-------|-------------|-----------|
| Source | `variant ReconciliationOutcome { ... }` and `match outcome { Arm {} => ... }` | Grammar authority — what users write |
| TypeChecker | `@variant_shapes`, arm vocabulary, exhaustiveness, narrowed types | Semantic authority — what errors fire |
| VM runtime | `{ "__arm": "...", "__variant": "...", payload }` records | Lowering detail — internal compiler strategy |

**This separation is intentional.** The source layer and VM layer are deliberately disconnected. A user who sees the runtime representation should not conclude that `{ __arm: "Foo" }` is valid source Igniter. Public documentation must teach `variant`/`match`, not `__arm` records.

**Why this is not KDR:** The KDR convention (`kind: String`) gave the developer a record with a string discriminant, but nothing prevented a caller from providing `kind: "confirmed_succeeded"` when the receipt is genuinely still unknown. Exhaustiveness and arm identity lived in the developer's head. Under Path B, the TypeChecker enforces the vocabulary at source level — the runtime *happens* to use a similar shape, but the authority that matters lives in the typechecker, not in the record format.

---

## 7. KDR Relationship

KDR (`kind: String` convention) remains valid and useful:

- **Proof-local convention** for lab proofs that haven't yet adopted variant syntax
- **Boundary/serialization format** — KDR records are safe to pass across system boundaries (external APIs, queues, storage) where the receiving side doesn't run an Igniter TypeChecker
- **Interoperability shape** — KDR is a plain record; any language can produce or consume it
- **Migration bridge** — existing P2/P3/P4 proofs are not retroactively invalidated

Variant/match **supersedes KDR for domains** where:
- The vocabulary is finite and known
- Exhaustiveness should be enforced at source/typecheck time
- Arm identity matters (e.g., `ConfirmedSucceededModel` must not route as `ConfirmedSucceededReal`)

Variant/match does **not replace KDR everywhere**:
- External serialization still produces records; `__arm` is an internal field name
- Domains without a sealed vocabulary should use KDR or typed string fields
- Inter-process or inter-language boundaries need explicit serialization design

Path B may look like KDR at the VM level, but the source-level authority is categorically different.

---

## 8. Closed Alternatives

| Alternative | Status | Reason |
|-------------|--------|--------|
| Path A: native `Value::Variant` | **CLOSED** | 335 checks proved Path B sufficient; Path A would require new VM surface with higher risk and no demonstrated benefit |
| New opcodes (`OP_MATCH`, `OP_PUSH_VARIANT`) | **CLOSED** | All match semantics proved via existing opcodes |
| Native runtime reflection over variant identity | **CLOSED** | Not required by any proved use case |
| Generic sealed `Outcome[T,E]` | **CLOSED** | Requires PROP-044-P7 governance gate; `ReconciliationOutcome` is domain-specific, not a parametric type |
| Failure taxonomy | **CLOSED** | Separate proposal-planning card; not unblocked here |
| Production/runtime stability claims | **CLOSED** | Lab VM only; no stable API surface |
| Ruby canon changes | **CLOSED** | Ruby canon pipeline unchanged; Rust is conformance consumer |
| Public stable `__arm`/`__variant` field names | **CLOSED** | Internal compiler-owned fields; reserved under compiler authority |

---

## 9. Design Risks

The following risks are logged as known-and-accepted under Path B v0:

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **Reserved field collision** — a user writes `__arm` or `__variant` as a contract field name | Medium | Guardrail required (Section 10); no current parser-level rejection |
| **Hand-authored records imitating variant runtime shape** — `{ __arm: "Foo" }` passed as a variant to a match consumer | Medium | TypeChecker doesn't recognize this as a variant; VM match will `OP_GET_FIELD` the `__arm` and compare — will succeed if values match, but without exhaustiveness guarantee |
| **Cross-language serialization expectations** — external consumers see `__arm`/`__variant` fields and treat them as stable | High | Must be documented explicitly as internal; external serialization requires a separate design |
| **Future desire for native runtime identity** — a future proof requires knowing at runtime whether a value is a variant | Low | Path A remains available as a future gate; closing it now means future work must prove need explicitly |
| **Ruby/Rust parity drift** — Ruby SemanticIR emitter and Rust emitter diverge on `variant_decl`/`match_node` shapes | Medium | Parity proved at LAB-VARIANT-RUST-P1; requires explicit parity checks in future Rust changes |
| **Debugger/source-map implications** — bytecode for a match lowers to a chain of GET_FIELD/EQ/JMP; source-map from bytecode offset back to arm name requires G-SRCMAP work | Low | LAB-DEBUGGER-FEASIBILITY-P1 flags G-SRCMAP; independent; not blocked here |
| **Agents treating Path B as public ABI** — a future agent reads `__arm` directly in fixture inputs and treats it as user source convention | Medium | Section 10 guardrails + explicit documentation; `variant_construct` in SIR is the portable artifact |

---

## 10. Required Guardrails

The following rules apply to all work downstream of this governance lock:

1. **Users must not write `__arm` or `__variant` as public contract input/output fields.** These names are compiler-owned. A future reserved-field policy (proposed separately) may make this a TypeChecker OOF error; until then, it is a convention enforced by documentation and review.

2. **External serialization of variant values is not stable.** The `__arm`/`__variant` field names, their order, and their presence are VM-internal. Any cross-boundary serialization of variant values requires an explicit serialization design card.

3. **VM lowering format is an internal runtime detail.** Agents, fixtures, and documentation should reference `variant_construct` / `match_node` in SemanticIR as the portable compiler artifact — not the lowered Record shape.

4. **Public documentation must teach source `variant`/`match`.** Examples should show the source syntax and TypeChecker behavior. No public example should show `{ __arm: "Foo" }` as a way to create a variant value.

5. **Future cards that touch `compiler.rs` match lowering must re-verify parity with this specification** — especially the sorted-key invariant, the `"match_node" | "match_expr"` alias, and the `has_wildcard → unwrap_or(false)` fail-closed default.

---

## 11. Exact Next Routes

| Route | Condition | Status |
|-------|-----------|--------|
| `LAB-OUTCOME-VARIANT-P2` | Richer ReconciliationOutcome payloads, metadata fields, or variant-in-variant needed | Available if needed |
| `LAB-FAILURE-TAXONOMY-P1` | Failure taxonomy proposal-planning (not implementation) | Available after P8 closes; proposal-planning only |
| `PROP-044-P9` | Canon text update to reflect Path B semantics in igniter-lang docs | Requires explicit authorization; P8 does not authorize it |
| `LAB-SRCMAP-P1` | Source-map node_id+span threading (G-SRCMAP gap) | Independent; not blocked or unblocked by P8 |
| `PROP-044-P7` (VM dispatch) | Path A or Path B production promotion | Requires separate governance gate; P8 closes Path B as lab-only |
| Reserved-field policy card | Explicit TypeChecker OOF for `__arm`/`__variant` in user source | Recommended follow-up to prevent hand-authored field collision |

---

## 12. Explicit Answers

| Question | Answer |
|----------|--------|
| Is Path B accepted as current lab runtime semantics? | **YES** |
| Does this authorize `Value::Variant`? | **NO** |
| Does this authorize `OP_MATCH`? | **NO** |
| Is runtime representation stable/public? | **NO** — internal VM lowering detail |
| Is exhaustiveness runtime-checked? | **NO** — TypeChecker-owned; VM trusts SIR |
| Does VM still fail closed on malformed values? | **YES** — `OP_UNSUPPORTED` on no-wildcard unmatched; `OP_GET_FIELD` error on missing `__arm` |
| Does this create generic `Outcome[T,E]`? | **NO** |
| Does this authorize failure taxonomy? | **NO** — separate proposal-planning card |
| Does this change Ruby canon? | **NO** |
| Does this supersede KDR everywhere? | **NO** — only where variant vocabulary is known and should be sealed |
| Does this change any source file? | **NO** — governance lock only |
| What is the next implementation gate? | None authorized by this card; `LAB-OUTCOME-VARIANT-P2` or `LAB-FAILURE-TAXONOMY-P1` for proposal-planning only |
