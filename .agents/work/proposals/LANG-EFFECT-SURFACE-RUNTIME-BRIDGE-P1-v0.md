# LANG-EFFECT-SURFACE-RUNTIME-BRIDGE-P1

**Status:** authored — readiness/proposal only  
**Route:** LANG EFFECT SURFACE / RUNTIME BRIDGE / READINESS  
**Date:** 2026-06-13  
**Authority:** proposal/readiness only; no parser/compiler implementation  
**Proof:** `experiments/effect_surface_runtime_bridge_proof/verify_effect_surface_runtime_bridge_p1.rb` — 51/51 PASS  
**Card:** `LANG-EFFECT-SURFACE-RUNTIME-BRIDGE-P1.md`  
**Grounded by:** `LAB-IGNITER-LANG-IO-RUNTIME-P1` (lab evidence, not canon authority)

---

## Scope

`LAB-IGNITER-LANG-IO-RUNTIME-P1` proved that `capability` / `effect_binding` grammar
is experiment-pass (parse → classify → typecheck → SemanticIR). The blocking gap is at
`RuntimeMachine.evaluate`: no `CapabilityExecutor` registry, no `effect_surface` object
in SemanticIR, no executor dispatch.

This document bridges that gap. It defines the **minimal Effect Surface subset** that the
executor needs before the full seven-field PROP-035 grammar lands.

**Authority boundary:** This document is a design/readiness record. No compiler
implementation is authorized. No SemanticIR emitter changes are authorized. No grammar
changes are authorized. The deliverable is the design decisions and the static survey proof.

---

## Q1 — Which Ch12 Fields Are Mandatory for First Runtime IO

The `CapabilityExecutor` interface from `LAB-IGNITER-LANG-IO-RUNTIME-P1 Q5` needs:

| Field | Source in compiler | Mandatory for executor? |
|---|---|---|
| `effect_name` | `effect_binding` name (typed AST) | ✅ yes — identifies the declared effect |
| `capability` | `capability` decl + IO.Capability sentinel (typed AST) | ✅ yes — executor family lookup |
| `inputs` | contract input declarations (typed AST) | ✅ yes — passed to substrate |
| `authority_ref` | `authority` clause (Effect Surface) | ✅ yes (nil-safe for basic `effect`) |
| `idempotency_mode` + key | `idempotency` clause (Effect Surface) | ✅ yes — needed for retry profiles |
| `receipt_type` | `receipt` clause (Effect Surface) | ✅ yes — executor must emit typed receipt |
| `failure_type` | `failure` clause + 7-outcome taxonomy | ✅ yes — executor must branch on outcome |
| `affects_scope` + `affects_target` | `affects` clause (Effect Surface) | ✅ yes — substrate routing |
| `reversibility` | `reversibility` clause (Effect Surface) | ❌ compile-time OOF only |
| `compensation` | `compensation` clause (Effect Surface) | ❌ irreversible only; bridge targets `effect` |

**Mandatory bridge subset (6 semantic fields):**

```
affects_scope        "external" | "internal"
affects_target       String   -- from affects clause; routes to substrate family
authority_ref        String | nil  -- nil-safe for basic effect contracts
idempotency_mode     "key" | "natural" | "none"
idempotency_key_expr String | nil  -- present when mode = "key"
receipt_type         String | nil  -- type reference for emitted receipt
failure_type         String | nil  -- type reference; maps to 7-outcome taxonomy
```

The `effect_name`, `capability`, and `inputs` are already available from the experiment-pass
surface (typed AST) and do not require new Effect Surface fields.

---

## Q2 — Can Any Field Be Staged Without Violating the Covenant

Yes. The relevant Covenant postulates are all `planned PROP` (pending PROP-035):

| Postulate | Promise | Status |
|---|---|---|
| P7 | Effect Surface readable from header | `planned PROP` |
| P8 | Receipts are immutable proofs | `planned PROP` |
| P9 | Authority is explicit typed value | `planned PROP` |
| P16 | Non-idempotent ops in retry profile = compile error | `planned PROP` |
| P17 | Irreversible contract names compensation | `planned PROP` |
| P19 | Reversibility is a scale; profile max enforced | `planned PROP` |

None are `enforced`. The Covenant governs what must hold when the system is complete.

**Staging without violation requires:**

1. Not claiming fields are complete when they aren't.
2. Not emitting SemanticIR `effect_surface` object until it is validated by PROP-035.
3. Not widening runtime authority beyond what the compiler currently enforces.
4. Each staged field has a named follow-up: PROP-035 for all seven fields.

**Staged fields (not needed for executor bridge):**

- `reversibility` — profile maximum check is compile-time only (OOF-M5, pending PROP-035);
  the executor does not need to gate on reversibility at runtime for basic `effect` contracts.
- `compensation` — required only for `irreversible` contracts (OOF-M3); the bridge targets
  basic `effect` contracts.

---

## Q3 — Which Omissions Must Be Compile-Time OOF vs Runtime Refusal

### Compile-Time OOF (pending PROP-035 full enforcement)

| Condition | Code | Severity |
|---|---|---|
| `effect`/`privileged`/`irreversible` missing Effect Surface fields | OOF-M2 | error |
| `idempotency: none` in retry-enabled profile | OOF-M4 | error |
| Missing `authority` on `privileged`/`irreversible` | OOF-M2 | error |
| `reversibility` exceeds profile maximum | OOF-M5 | error |
| `irreversible` without `compensation` or `no_compensation` | OOF-M3 | warn |

OOF-M2/M4/M5 for the `capability`/`effect_binding` subset are already experiment-pass
(proven in `io_capability_proof`). The broader Effect Surface field enforcement (affects,
authority, reversibility, idempotency, receipt, failure, compensation) is PROP-035 pending.

### Runtime Refusal (executor-level, fail-closed)

| Condition | Code | Returns |
|---|---|---|
| No executor registered for the IO family | `effect.unsupported_family` | RuntimeRefusal |
| Capability passport missing from inputs | `effect.missing_passport` | RuntimeRefusal |
| Passport present but expired or revoked | `effect.passport_invalid` | RuntimeRefusal |
| Authority clause present but runtime mismatch | `effect.authority_mismatch` | RuntimeRefusal |
| Idempotency key required but absent at runtime | `effect.missing_idempotency_key` | RuntimeRefusal |
| No receipt emitted after execution attempt | (executor contract violation) | Runtime assertion |

All runtime refusals return typed variants. They do not raise exceptions. This is the
"denial-as-data" invariant from `LAB-STORAGE-CAPABILITY-P1` and `LAB-FILE-IO-P1`.

**Rule:** every omission that can be proven at compile time → OOF. Every omission that
requires runtime context (passport validity, executor presence, idempotency key) → runtime
refusal. The two lists must not overlap.

---

## Q4 — How Should `unknown_external_state` Be Represented Before Full Failure Taxonomy

Covenant Postulate 15 is **governing now**:

> A timeout waiting for an external system is `UnknownExternalOutcome`, not
> `ObservedFailure`. These are different types. They require different responses:
> reconciliation, not retry.

This rule applies regardless of whether PROP-035 has shipped. The 7-outcome taxonomy in
Ch12 §12.3 is the target shape:

| Outcome | Kind | Resolution |
|---|---|---|
| `succeeded` | `EffectReceipt` | immutable proof |
| `failed` | `EffectError` | known error from external system |
| `partial` | `PartialReceipt` | reconciliation needed |
| `timed_out` | `UnknownExternalOutcome` | **NOT failure — reconcile** |
| `unknown_external_state` | `UnknownExternalOutcome` | request sent, no confirmation |
| `compensated` | `CompensationReceipt` | compensation ran |
| `cancelled` | `CancellationReceipt` | cancelled before completion |

**For the bridge:** `unknown_external_state` is used as an `EffectResult` variant with a
`last_known_ref: String` field. The executor must return this variant (not raise an
exception) when the outcome cannot be determined. Callers must reconcile; they must not
retry blindly.

The full failure taxonomy (including compiler enforcement that `timed_out` cannot be
treated as `ObservedFailure`) ships with PROP-035. P15 is load-bearing from today.

---

## Q5 — Minimal SemanticIR `effect_surface` Object for Executor Dispatch

**Current state (confirmed by proof):** The SemanticIR emitter does NOT emit an
`effect_surface` object for IO capability contracts. The `escape_boundaries` field is
empty for capability contracts. This is the gap.

**Target schema for PROP-035** (design-only in this document):

```json
{
  "kind": "effect_surface_v0",
  "affects_scope": "external",
  "affects_target": "IO.Capability",
  "authority_ref": null,
  "idempotency_mode": "none",
  "idempotency_key_expr": null,
  "receipt_type": null,
  "failure_type": null
}
```

This object is NOT emitted by the current compiler. It is the design target.

**What the bridge uses instead (experiment-pass, already in typed AST):**

```json
{
  "kind": "contract_ir",
  "modifier": "effect",
  "fragment_class": "escape",
  "declarations": [
    {
      "kind": "capability",
      "name": "net_conn",
      "type": { "name": "IO.Capability" }
    },
    {
      "kind": "effect_binding",
      "name": "connect_to_service",
      "capability_ref": "net_conn",
      "deps": ["net_conn"]
    }
  ]
}
```

The executor bridge reads `modifier`, `fragment_class`, and `declarations` from the
typed AST to derive what it needs. This is sufficient for a mocked P2 executor without
SemanticIR `effect_surface` emission.

**When does full SemanticIR `effect_surface` emission happen?** With PROP-035. That PROP
adds the grammar for all seven fields and wires them into `contract_ir` as an
`effect_surface` object. The bridge document defines the schema target for that work.

---

## Q6 — What Remains Closed Until Full PROP-035

| Surface | Status |
|---|---|
| Grammar for `affects` / `authority` / `reversibility` / `idempotency` / `receipt` / `failure` / `compensation` | CLOSED — PROP-035 pending |
| SemanticIR `effect_surface` object emission | CLOSED — PROP-035 pending |
| OOF-M2 enforcement for missing Effect Surface header fields | CLOSED — PROP-035 pending |
| OOF-M4 enforcement for `idempotency: none` in retry profile | CLOSED — PROP-035 pending |
| OOF-M5 enforcement for reversibility scale | CLOSED — PROP-035 pending |
| Receipt type enforcement at compiler | CLOSED — PROP-035 pending |
| Failure type enforcement at compiler | CLOSED — PROP-035 pending |
| Authority clause validation beyond experiment-pass | CLOSED — PROP-035 pending |
| Compensation contract validation | CLOSED — PROP-035 pending |
| Profile maximum reversibility enforcement | CLOSED — PROP-035 pending |
| Receipt field linking to `escape_boundaries` | CLOSED — PROP-035 + P28 open question |
| `escape_boundaries` wired for IO capability nodes | CLOSED — PROP-035 pending |
| Any CapabilityExecutor implementation | CLOSED — requires LANG-IO-CAPABILITY-EXECUTOR-P1 |
| Real substrate IO (DB, file, network, queue, clock, random) | PERMANENTLY CLOSED for this card |
| Rack / HTTP / ORM / ActiveRecord references | PERMANENTLY CLOSED |
| Production runtime claim | PERMANENTLY CLOSED |

---

## Bridge Design Decisions

### Decision 1 — Minimum Mandatory Set

The minimal bridge `effect_surface_v0` has 7 leaf fields:
`affects_scope`, `affects_target`, `authority_ref`, `idempotency_mode`,
`idempotency_key_expr`, `receipt_type`, `failure_type`.

`reversibility` and `compensation` are staged out. Their absence does not block P2
executor dispatch for basic `effect` contracts.

### Decision 2 — IO.Capability Sentinel Is the Routing Key

The canon TypeChecker normalizes all `IO.*` names to `"IO.Capability"` (CR-001).
The executor uses this sentinel to look up the IO family from a separate passport.
The passport carries the family-specific schema (e.g., `IO.StorageCapability` fields).
The bridge does not know passport internals.

### Decision 3 — authority_ref Is Nil-Safe for Basic `effect`

Ch12 §12.3: "Required for `privileged` and `irreversible`. Optional for `effect`."
The bridge passes `nil` when no authority clause is declared. The executor gate
checks for `nil` and proceeds. Non-nil authority_ref triggers a runtime authority
check before executor dispatch.

### Decision 4 — Executor Lookup Uses Effect Name + Passport Family

The `CapabilityExecutor` registry is keyed by IO family (derived from the capability
passport, not the `IO.Capability` sentinel). The effect name identifies which declared
effect within that family is being executed.

### Decision 5 — P2 First Family Is Storage Read

From `LAB-IGNITER-LANG-IO-RUNTIME-P1 Q11`: Storage read has the deepest proof chain
(LAB-EXECUTE-QUERY-P3 68/68, LAB-STORAGE-CAPABILITY-P1/P2, denial-as-data at all 6
gates, `QueryExecutionReceipt` 15-field schema). PROP-046 authored the storage capability
query execution boundary. Storage read is the recommended P2 first family.

### Decision 6 — Effect Surface V0 Is Design-Only; PROP-035 Wires It

The `effect_surface_v0` schema defined in Q5 is a design target. It describes what
PROP-035 must emit into `contract_ir`. The bridge document authorizes no implementation.

---

## Follow-Up Cards

| Card | What it does |
|---|---|
| **LANG-IO-CAPABILITY-EXECUTOR-P1** | Defines the CapabilityExecutor interface, passport shape, EffectResult envelope, refusal codes, and receipt contract. Chooses P2 family. |
| **PROP-035** (to be authored) | Full Effect Surface grammar, all 7 fields, OOF-M2/3/4/5 enforcement, SemanticIR `effect_surface` object emission, receipt/failure type enforcement. |

---

## Closed Surfaces (this card)

- No parser, classifier, typechecker, or SemanticIR emitter changes.
- No `effect_surface` object emitted by any compiler component.
- No CapabilityExecutor implementation.
- No real DB, file, network, queue, clock, random, or process execution.
- No Rack / HTTP / ORM / ActiveRecord authority.
- No production runtime claim.
- No Reference Runtime claim.
- No public or stable API claim.
- No canon claim from lab evidence alone (CR-001, CR-002).
