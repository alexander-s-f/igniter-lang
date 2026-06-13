# LANG-IO-CAPABILITY-EXECUTOR-P1: CapabilityExecutor Interface Proposal

**Status:** proposal — readiness proof PASS (57/57)  
**Route:** LANG RUNTIME / IO CAPABILITY EXECUTOR / PROPOSAL  
**Date:** 2026-06-13  
**Authority:** proposal + readiness proof only; no runtime implementation  
**Grounded by:** LAB-IGNITER-LANG-IO-RUNTIME-P1 (85/85 PASS)

---

## Context

`LAB-IGNITER-LANG-IO-RUNTIME-P1` identified the blocking gap precisely: the
`RuntimeMachine.evaluate` path supports `input_node`, `compute_node`, and
`output_node`. There is no `CapabilityExecutor` registry and no effect dispatch.

This proposal defines:
1. The minimal `CapabilityExecutor` interface — one contract, no ambient IO.
2. The `CapabilityPassport` shape — what is verified before any substrate call.
3. The `EffectResult` envelope — the 7-outcome result type from Ch12.
4. Which refusals are runtime-level vs compile-time OOF.
5. How executor lookup uses `escape_set` / `escape_boundaries` without promoting
   report-only metadata to authority.
6. How replay and determinism are preserved through receipts.
7. Which IO family P2 should target first.
8. What stays closed.

---

## Q1 — Minimal Executor Interface

The `CapabilityExecutor` contract for one IO family:

```
CapabilityExecutor {
  family_id: String             -- "storage" | "file" | "network" | "queue" | ...

  execute(
    context:         ExecutionContext,
    effect_name:     String,          -- declared effect_binding name
    passport:        CapabilityPassport,
    inputs:          Map[String, Value],
    authority_ref:   String,          -- from effect contract authority clause
    idempotency_key: String | nil,    -- nil only when idempotency: natural or profile allows
    deadline_ms:     Integer | nil    -- nil = no deadline declared
  ) -> EffectResult
}

ExecutionContext {
  program_id:    String,   -- from .igapp manifest (for receipt lineage)
  contract_ref:  String,   -- from contract_ir contract_ref (for receipt lineage)
  effect_ref:    String,   -- "effect/<contract_ref>/<effect_name>"
  session_id:    String    -- from RuntimeMachine session context
}
```

**Why `ExecutionContext` separate from `inputs`?** The context carries receipt
lineage fields (program_id, contract_ref) that are not user-declared inputs.
They must not be conflatable with domain inputs. Separating them keeps the
`inputs` map semantically identical to what the contract declared.

**Why `deadline_ms`?** P15 (Timeout Is Not Failure) — a timeout must produce
`EffectResult::timed_out`, not raise an exception. The executor must own the
deadline and return the correct outcome type.

---

## Q2 — CapabilityPassport Shape

```
CapabilityPassport {
  capability_id:  String,       -- unique identity (e.g. "storage-read-users-v0")
  family:         String,       -- matches executor.family_id
  authority_ref:  String,       -- who granted this passport
  granted_at:     String,       -- ISO8601 (from clock binding, not now())
  expires_at:     String | nil, -- nil = no expiry
  revoked:        Bool,         -- fail-closed: true = refuse
  family_fields:  Map[String, Value]
                                -- opaque family-specific fields
                                -- (e.g. allowed_sources, allowed_ops, row_limit)
}
```

**Fields required before any substrate call:**

| Check | Refusal code |
|---|---|
| `passport` present | `effect.missing_passport` |
| `passport.family == executor.family_id` | `effect.passport_family_mismatch` |
| `passport.authority_ref` matches required authority | `effect.authority_mismatch` |
| `passport.revoked == false` | `effect.passport_revoked` |
| `passport.expires_at` nil or in the future | `effect.passport_expired` |

**Family-specific fields are opaque to the generic interface.** The executor for
each family interprets `passport.family_fields`. The canon TypeChecker sees only
`IO.Capability` (CR-001 opacity). Only the executor at runtime knows the full
schema.

This mirrors the existing pattern in `IO.StorageCapability` (LAB-STORAGE-CAPABILITY-P1):
`allowed_sources`, `allowed_ops`, `row_limit`, `allow_include_all`,
`read_allowed`, `write_allowed` all live in family_fields for the storage executor.

---

## Q3 — EffectResult Envelope (7-Outcome Taxonomy)

The 7-outcome taxonomy from Ch12 §12.3, mapped to a concrete result type:

```
EffectResult = one of:
  succeeded(
    receipt:      EffectReceipt,
    value:        Map[String, Value] | nil   -- output values if any
  )
  denied(
    receipt:      EffectReceipt,             -- denial is evidence too
    gate:         String,                    -- which gate fired (G1..GN)
    reason:       String
  )
  failed(
    receipt:      EffectReceipt,
    error_kind:   String,                    -- named error from failure clause
    message:      String
  )
  partial(
    receipt:      EffectReceipt,
    completed:    [String],                  -- which sub-operations completed
    pending:      [String]                   -- which sub-operations did not
  )
  timed_out(                                 -- P15: this is UnknownExternalOutcome
    receipt:      EffectReceipt,
    after_ms:     Integer,
    last_known:   String | nil               -- last observable state reference
  )
  unknown_external_state(                    -- P15: reconciliation required
    receipt:      EffectReceipt,
    sent_at:      String,                    -- when request was sent
    last_known:   String | nil
  )
  cancelled(
    receipt:      EffectReceipt,
    reason:       String
  )
```

**P15 is enforced structurally.** `timed_out` and `unknown_external_state` are
both `UnknownExternalOutcome` variants in the Covenant. They must never be
down-cast to `denied` or `failed` by the executor. The consumer receives a
distinct type and cannot treat it as a failure without an explicit typed
conversion. A future PROP-035 compiler check will flag code that treats
`timed_out` as `ObservedFailure` (OOF from ch12).

**`denied` is a normal result, not an error.** Denial-as-data is a proven
pattern across Storage (6 gates), File (8 gates), and Network lab evidence.
Denial must flow as a typed result variant; no exception may be raised.

**Every result variant carries an `EffectReceipt`.** Even denial and failure
produce evidence. Postulate 8: "A receipt is not a log entry. It is a proof that
a specific operation completed with specific inputs and produced a specific
output."

```
EffectReceipt {
  receipt_id:       String,       -- content-addressed immutable identity
  effect_ref:       String,       -- from ExecutionContext.effect_ref
  program_id:       String,       -- from ExecutionContext.program_id
  contract_ref:     String,       -- from ExecutionContext.contract_ref
  capability_id:    String,       -- from passport.capability_id
  family:           String,       -- IO family
  authority_ref:    String,       -- who authorized execution
  idempotency_key:  String | nil,
  idempotency_used: Bool,
  inputs_hash:      String,       -- sha256(canonical_json(inputs))
  outcome:          String,       -- "succeeded" | "denied" | "failed" | "partial"
                                  -- | "timed_out" | "unknown_external_state" | "cancelled"
  substrate:        String,       -- "storage" | "file" | "http" | "queue" | ...
  emitted_at:       String,       -- ISO8601, from clock binding — NOT now()
  evidence_refs:    [String]      -- prior evidence this receipt builds on
}
```

---

## Q4 — Refusal Classification: Runtime vs Compile-Time OOF

### Compile-time OOF (compiler enforces before `.igapp` exists)

| OOF | Trigger | Status |
|---|---|---|
| `OOF-M1` | `escape` body node in `pure` contract | enforced (PROP-031) |
| `OOF-M2` | `capability` declared in `pure` contract | experiment-pass (PROP-035 subset) |
| `OOF-M4` | `effect_binding` references undeclared capability | experiment-pass (PROP-035 subset) |
| `OOF-M5` | Capability declared but no `effect_binding` uses it | experiment-pass (PROP-035 subset) |
| Future Ch12 | Missing Effect Surface fields on effect/privileged/irreversible | planned PROP-035 |
| Future Ch12 | `idempotency: none` in retry-enabled profile | planned PROP-035 |
| Future Ch12 | `reversibility` exceeds profile maximum | planned PROP-035 |

### Runtime refusals (no `.igapp` load or evaluate proceeds)

| Code | Trigger | When |
|---|---|---|
| `effect.unsupported_family` | No executor registered for the declared IO family | evaluate |
| `effect.missing_passport` | No passport provided for a declared capability | evaluate |
| `effect.passport_family_mismatch` | Passport family ≠ executor family_id | evaluate |
| `effect.authority_mismatch` | Passport authority_ref does not match required authority | evaluate |
| `effect.passport_revoked` | `passport.revoked == true` | evaluate |
| `effect.passport_expired` | `passport.expires_at` is past (per clock binding) | evaluate |
| `effect.missing_idempotency_key` | Executor requires idempotency_key; nil provided | evaluate |
| `effect.no_receipt_emitted` | Executor returned without a receipt | runtime assertion |

All runtime refusals produce a structured `RuntimeRefusal`:

```
RuntimeRefusal {
  reason_code:  String,    -- one of the codes above
  effect_ref:   String,
  contract_ref: String,
  detail:       String
}
```

Refusals at the RuntimeMachine level are **not** exceptions. They are typed
results. The RuntimeMachine must return a `RefuseResult` from `evaluate`, not
raise. This preserves the honesty model: the runtime cannot hide a refusal.

---

## Q5 — Executor Lookup via escape_set / escape_boundaries

**Source of truth:** the assembled `.igapp` contract artifact `escape_set` field
(from Ch6 §6.6):

```json
{
  "escape_set": [
    {
      "name": "connect_to_service",
      "required_caps": ["IO.Capability"],
      "produces": ["effect_execution_observation"]
    }
  ]
}
```

**Lookup procedure (no runtime promotion of report-only metadata):**

1. `RuntimeMachine.evaluate` reads the assembled contract's `escape_set`.
2. For each `effect_binding_node` in the effect plan, look up `name` in `escape_set`.
3. Read `required_caps` — these are the declared capability names from source.
4. Look up the capability passport by name from the `inputs` map (the caller must
   inject passports as named inputs matching declared capability names).
5. Determine `family` from `passport.family`.
6. Look up the `CapabilityExecutor` in the executor registry by `family`.
7. If no executor found → `effect.unsupported_family` refusal.

**Why not trust `requirements.json` as authority?** Ch7 §7.2 establishes the
gate invariant: "CompatibilityReport must not be trusted before Boot +
Verification complete." The TEMPORAL precedent (Ch7 §7.8) shows that `report_only:
true` metadata on the CompatibilityReport does not authorize live execution. The
same principle applies here: `requirements.json` is a package-level capability
negotiation summary — it is evidence for the caller to verify supported families,
not a runtime gate. The gate is the executor registry + passport verification at
evaluate time.

**`escape_set` is the authoritative compiled surface.** It is derived from
`SemanticIR.escape_boundaries` (Ch6 §6.8), which is itself derived from the
source-level `escape` declarations. The assembled artifact is the gating surface,
not the report.

---

## Q6 — Replay and Determinism: What Must Be Recorded

**Root principle (Covenant P8):** a receipt is a proof of a specific operation
with specific inputs and a specific output. It must be immutable.

**What must be recorded per execution attempt:**

| Field | Why |
|---|---|
| `inputs_hash` | Canonical hash of inputs → same hash = same logical operation |
| `idempotency_key` | For replay deduplication at substrate level |
| `capability_id` | Which passport authorized the execution |
| `authority_ref` | Who authorized; required by P9 |
| `outcome` | What happened (7-outcome enum) |
| `substrate` | Which substrate binding carried out the execution |
| `emitted_at` | When (from clock binding; Covenant forbids `now()`) |
| `evidence_refs` | What prior facts this builds on (P6 — evidence chains) |

**Replay invariant:** given the same `inputs_hash + idempotency_key +
capability_id`, a re-execution at the substrate level must produce no duplicate
external effect. The executor owns deduplication at the substrate boundary. The
runtime owns recording the idempotency key on the receipt.

**Determinism invariant:** the pure compute nodes must evaluate first. All
`input_node` + `compute_node` evaluation is deterministic given the same inputs.
Effect dispatch follows, with recorded receipts. A complete replay of a program
run is possible from: (1) the `.igapp` artifact, (2) the original inputs, (3)
the stored receipts. If a receipt shows `unknown_external_state`, replay must not
re-dispatch without reconciliation — the receipt is the evidence of the ambiguous
prior state.

---

## Q7 — First Executable Family for P2: Storage Read

**Recommendation: Storage read family.**

Evidence depth comparison:

| Family | Lab proof depth | Passport schema | Gate sequence | Receipt shape |
|---|---|---|---|---|
| **Storage read** | LAB-EXECUTE-QUERY-P3 (68/68) + P2 (51/51) + P1 design | Locked v0 | G1–G6 proven | 15-field receipt locked |
| File read | LAB-FILE-IO-P1 (78/78) | Locked | G1–G8 proven | Receipt schema locked |
| HTTP outbound | LAB-STDLIB-NET-P6/P9; delegation algebra | Partial | Not fully gated | No receipt schema |
| Queue enqueue | LAB-SIDEKIQ-P1 (feasibility only) | Not designed | Not proven | No receipt schema |

Storage read wins because:

1. `IO.StorageCapability` v0 schema is locked (LAB-STORAGE-CAPABILITY-P1).
2. 6-gate denial-as-data sequence proven twice (P1 design + P2 proof 51/51).
3. `QueryExecutionReceipt` 15-field schema is proven and locked.
4. `ExecuteQuery` effect contract form is already drafted as a design target.
5. PROP-046 authored with full boundary decisions (9-field schema, 15 design decisions).
6. The family_fields schema for `StoragePassport` can be derived directly from
   `IO.StorageCapability` v0 without new design work.

P2 scope: one mocked `StorageExecutor` that implements the `CapabilityExecutor`
interface for Storage read, drives the proven 6-gate sequence, and emits a
`QueryExecutionReceipt`-shaped `EffectReceipt`. No real DB.

---

## Q8 — Closed Surfaces

These surfaces are closed for P1 and must not be opened without explicit authorization:

| Surface | Status |
|---|---|
| No runtime implementation | CLOSED — P1 is proposal only |
| No real DB / SQL / network / file / queue / process execution | CLOSED |
| No ORM / ActiveRecord / Rack implementation authority | PERMANENTLY CLOSED |
| No old Ruby `igniter` framework dependency | PERMANENTLY CLOSED |
| No production runtime claim | CLOSED |
| No Reference Runtime claim | CLOSED |
| No public / stable API claim | CLOSED |
| No ambient IO (capability required for every IO family) | CLOSED |
| No generic executor (each family has its own typed executor) | CLOSED |
| No capability widening by config/env/global state | CLOSED |
| No parser/grammar changes in P1 | CLOSED |
| No SemanticIR emitter changes in P1 | CLOSED |
| No assembler changes in P1 | CLOSED |

---

## Proposal Summary

| Decision | Choice |
|---|---|
| Executor interface | `execute(context, effect_name, passport, inputs, authority_ref, idempotency_key, deadline_ms) -> EffectResult` |
| Passport shape | `capability_id + family + authority_ref + granted_at + expires_at + revoked + family_fields` |
| Result envelope | 7-outcome: succeeded / denied / failed / partial / timed_out / unknown_external_state / cancelled |
| timed_out classification | `UnknownExternalOutcome` (P15) — not failure |
| Denial-as-data | All denials are `EffectResult::denied` — no exception raised |
| Receipt in all outcomes | Every outcome carries an `EffectReceipt` |
| Executor lookup | `escape_set` (assembled artifact) → passport.family → executor registry |
| requirements.json role | Package-level capability negotiation summary — not runtime gate authority |
| Replay requirement | inputs_hash + idempotency_key + capability_id recorded on every receipt |
| First P2 family | Storage read (deepest evidence; schema locked) |

---

## Implementability

P1 does not implement any runtime code. The next narrow cards authorized by this
proposal:

1. **LAB-IGNITER-LANG-IO-RUNTIME-P2** — mocked `StorageExecutor` implementing
   `CapabilityExecutor` for Storage read. Drives the proven 6-gate sequence.
   Emits `EffectReceipt`. No real DB. Proof-local only.

2. **LAB-IGNITER-LANG-MICROSERVICE-P1** — service runtime envelope after P2:
   ingress → pure evaluate → StorageExecutor dispatch → response + receipts.
   Only after P2 PASS.
