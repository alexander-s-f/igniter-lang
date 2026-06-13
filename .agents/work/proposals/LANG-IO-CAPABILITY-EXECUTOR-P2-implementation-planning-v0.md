# LANG-IO-CAPABILITY-EXECUTOR-P2: Implementation Planning v0

**Status:** implementation-planning-only — CLOSED / READY FOR P3  
**Route:** LANG RUNTIME / CAPABILITY EXECUTOR / IMPLEMENTATION PLANNING  
**Date:** 2026-06-13  
**Authority:** planning + proof only; no runtime implementation unless explicitly upgraded

---

## Context

`LANG-IO-CAPABILITY-EXECUTOR-P1` (CLOSED 80/80) defined:
- `execute(context, effect_name, passport, inputs, authority_ref, idempotency_key, deadline_ms) -> EffectResult`
- `CapabilityPassport` shape (7 fields)
- 7-outcome `EffectResult` union, each with `EffectReceipt`
- Executor lookup via `escape_set` → `passport.family` → registry
- First P2 family: Storage read

`LAB-IGNITER-LANG-IO-RUNTIME-P2` (CLOSED 69/69) proved the mocked runtime path:
- `MockStorageCapabilityExecutor` Layer C (3-layer mocked stack)
- 6-gate G1–G6 sequence → `QueryResult` + `QueryExecutionReceipt`
- `CapabilityExecutorRegistry.register("IO.StorageCapability", executor)`
- Runtime refusal vs denial-as-data boundary

This P2 planning card turns those decisions into bounded Ruby insertion points
for P3 implementation.

---

## Q1 — Proof-Local vs Lib Boundary

**Decision: PROOF-LOCAL under `experiments/`.**

**Rationale:**

| Option | Assessment |
|---|---|
| `experiments/io_capability_executor/` | CHOSEN — follows `temporal_access_runtime.rb` precedent |
| `lib/igniter_lang/` | CLOSED — lib/ contains compiler components (parser/TC/emitter/assembler); runtime executor is NOT a compiler component |
| New gem / package | CLOSED — no package/stable API surface authorized |

The `temporal_access_runtime.rb` pattern (in `experiments/temporal_access_runtime/`) establishes proof-local runtime helpers as single-file experiment modules that are `require_relative`d from proof runners. `CapabilityExecutorRuntime` follows the same shape.

**Authorized file for P3:**

```
experiments/io_capability_executor/capability_executor_runtime.rb
```

This file contains all modules and classes defined in Q2 below. It is:
- NOT in `lib/` (not a compiler component)
- NOT required by `lib/igniter_lang.rb` (no production entry point)
- Required only by proof runners via `require_relative`

**Proof runner path (P3):**

```
experiments/io_capability_executor_proof/verify_io_capability_executor_p3.rb
```

**No other file additions authorized in P3.**

---

## Q2 — Ruby Structs/Classes/Modules

All definitions live inside module `CapabilityExecutorRuntime` in
`experiments/io_capability_executor/capability_executor_runtime.rb`.

### CapabilityPassport (Struct)

```ruby
CapabilityPassport = Struct.new(
  :capability_id,   # String — unique identity e.g. "storage-read-users-v0"
  :family,          # String — "storage" | "file" | "network" | "queue" | ...
  :authority_ref,   # String — who granted this passport
  :granted_at,      # String — ISO8601 from clock binding
  :expires_at,      # String | nil — nil = no expiry
  :revoked,         # Bool — fail-closed: true = refuse
  :family_fields,   # Hash — opaque family-specific fields
  keyword_init: true
) do
  def expired?(now_iso8601)
    return false if expires_at.nil?
    expires_at < now_iso8601
  end

  def valid_family?(expected_family)
    family == expected_family
  end
end
```

### EffectReceipt (Struct)

```ruby
EffectReceipt = Struct.new(
  :receipt_id,        # String — content-addressed identity
  :effect_ref,        # String — "effect/<contract_ref>/<effect_name>"
  :program_id,        # String — from ExecutionContext
  :contract_ref,      # String — from ExecutionContext
  :capability_id,     # String — from passport
  :family,            # String — IO family
  :authority_ref,     # String — who authorized
  :idempotency_key,   # String | nil
  :idempotency_used,  # Bool
  :inputs_hash,       # String — sha256(canonical_json(inputs))
  :outcome,           # String — 7-outcome enum value
  :substrate,         # String — "storage" | "file" | ...
  :emitted_at,        # String — ISO8601 from clock binding
  :evidence_refs,     # Array[String] — prior evidence this builds on
  keyword_init: true
) do
  def to_h
    super.transform_keys(&:to_s)
  end
end
```

### ExecutionContext (Struct)

```ruby
ExecutionContext = Struct.new(
  :program_id,    # String — from .igapp manifest
  :contract_ref,  # String — from contract_ir
  :effect_ref,    # String — "effect/<contract_ref>/<effect_name>"
  :session_id,    # String — from RuntimeMachine session context
  keyword_init: true
)
```

### RuntimeRefusal (Struct)

```ruby
RuntimeRefusal = Struct.new(
  :reason_code,  # String — e.g. "effect.missing_passport"
  :effect_ref,   # String
  :contract_ref, # String
  :detail,       # String
  keyword_init: true
) do
  def to_h
    super.transform_keys(&:to_s)
  end
end
```

### EffectResult (module with factory class methods)

**WHY module + class methods (not Struct):** Each outcome has different fields.
A single Struct cannot model a 7-outcome union cleanly without optional field
confusion. Module with factory methods returns tagged Hashes, consistent with
the existing `ObsPacket#to_h` serialization pattern in the proof runtime.

```ruby
module EffectResult
  OUTCOMES = %w[
    succeeded denied failed partial
    timed_out unknown_external_state cancelled
  ].freeze

  def self.succeeded(receipt:, value: nil)
    { "outcome" => "succeeded", "receipt" => receipt.to_h, "value" => value }
  end

  def self.denied(receipt:, gate:, reason:)
    { "outcome" => "denied", "receipt" => receipt.to_h, "gate" => gate, "reason" => reason }
  end

  def self.failed(receipt:, error_kind:, message:)
    { "outcome" => "failed", "receipt" => receipt.to_h, "error_kind" => error_kind, "message" => message }
  end

  def self.partial(receipt:, completed:, pending:)
    { "outcome" => "partial", "receipt" => receipt.to_h, "completed" => completed, "pending" => pending }
  end

  # P15: timed_out = UnknownExternalOutcome, NOT ObservedFailure
  def self.timed_out(receipt:, after_ms:, last_known: nil)
    { "outcome" => "timed_out", "receipt" => receipt.to_h, "after_ms" => after_ms, "last_known" => last_known }
  end

  # P15: reconciliation required before re-dispatch
  def self.unknown_external_state(receipt:, sent_at:, last_known: nil)
    { "outcome" => "unknown_external_state", "receipt" => receipt.to_h, "sent_at" => sent_at, "last_known" => last_known }
  end

  def self.cancelled(receipt:, reason:)
    { "outcome" => "cancelled", "receipt" => receipt.to_h, "reason" => reason }
  end

  # Denial-as-data: denial flows as a typed variant, not an exception
  def self.outcome_of(result_hash)
    result_hash.fetch("outcome")
  end

  def self.denied?(result_hash)
    outcome_of(result_hash) == "denied"
  end

  def self.succeeded?(result_hash)
    outcome_of(result_hash) == "succeeded"
  end

  def self.unknown_external_outcome?(result_hash)
    %w[timed_out unknown_external_state].include?(outcome_of(result_hash))
  end
end
```

### CapabilityExecutor (module — interface contract)

```ruby
module CapabilityExecutor
  # Required: every executor must declare its family
  def family_id
    raise NotImplementedError, "#{self.class} must implement #family_id"
  end

  # Required: main dispatch
  # Returns: EffectResult Hash (see EffectResult module above)
  # Must NOT raise on business logic outcomes — raise only on programmer error
  def execute(context:, effect_name:, passport:, inputs:, authority_ref:, idempotency_key:, deadline_ms:)
    raise NotImplementedError, "#{self.class} must implement #execute"
  end
end
```

### CapabilityExecutorRegistry (class)

```ruby
class CapabilityExecutorRegistry
  def initialize
    @executors = {}
  end

  # Register an executor for a capability class name
  # capability_class: String e.g. "IO.StorageCapability"
  # executor: Object including CapabilityExecutor
  def register(capability_class, executor)
    @executors[capability_class.to_s] = executor
    self
  end

  # Fetch executor or nil
  def fetch(capability_class)
    @executors[capability_class.to_s]
  end

  # Boolean: is this family supported?
  def supports?(capability_class)
    @executors.key?(capability_class.to_s)
  end

  # All registered family names
  def registered_families
    @executors.keys
  end
end
```

---

## Q3 — Registry API

The registry is keyed by **capability class name** (the string used in the
`capability` body declaration, e.g. `"IO.StorageCapability"`). This matches the
`CR-001` model: the TypeChecker sees `IO.Capability` sentinel, but at runtime the
executor registry uses the source-level declared name as lookup key.

```ruby
registry = CapabilityExecutorRegistry.new

# Register
registry.register("IO.StorageCapability", StorageCapabilityExecutor.new)

# Check
registry.supports?("IO.StorageCapability")  # => true
registry.supports?("IO.FileCapability")      # => false (not yet registered)

# Fetch
executor = registry.fetch("IO.StorageCapability")  # => StorageCapabilityExecutor instance
```

**Key invariant:** `registry.fetch` returns nil (not raises) if not found.
The RuntimeMachine evaluate path checks for nil and returns an `effect.unsupported_family`
`RuntimeRefusal` before calling execute.

---

## Q4 — Validation Layers

Three layers, each responsible for a distinct slice of validation:

### Layer 1: CapabilityExecutorRegistry (registration check only)

Responsibility: Is there an executor registered for this family?

```
registry.supports?(capability_class)
  → false → RuntimeRefusal{ reason_code: "effect.unsupported_family" }
  → true  → proceed to Layer 2
```

No passport inspection. No inputs inspection. Just family lookup.

### Layer 2: RuntimeMachine evaluate (pre-call passport verification)

Responsibility: Is the injected passport safe to pass to the executor?

Five checks, in order (all fail-closed):

| Check | Refusal code |
|---|---|
| `passport` present in inputs by capability name | `effect.missing_passport` |
| `passport.family == executor.family_id` | `effect.passport_family_mismatch` |
| `passport.authority_ref` matches declared `authority_ref` | `effect.authority_mismatch` |
| `passport.revoked == false` | `effect.passport_revoked` |
| `passport.expired?(now)` == false | `effect.passport_expired` |

These checks are performed by the RuntimeMachine BEFORE calling `executor.execute`.
If any check fails → `RuntimeRefusal` returned; `execute` never called.

**Why in RuntimeMachine, not registry?** The registry is a lookup table (family →
executor); it has no access to passport state. Passport verification requires the
actual passport object from the inputs map, which RuntimeMachine resolves.

**Why not in executor?** The executor should receive only pre-verified passports.
This prevents each executor from needing to re-implement the same verification
boilerplate. The boundary is clean: RuntimeMachine guards passport correctness,
executor guards business logic (G1–G6 gates).

### Layer 3: Executor (business logic gates + idempotency check)

Responsibility: Does this passport grant permission for this specific operation?

For `StorageCapabilityExecutor`:

| Gate | Check | Output on fail |
|---|---|---|
| Idempotency | `idempotency_key` nil when executor requires it | `RuntimeRefusal{ reason_code: "effect.missing_idempotency_key" }` |
| G1 | `allowed_sources.include?(plan.source_table)` | `EffectResult.denied(gate:"G1")` |
| G2 | `allowed_ops.include?("read")` | `EffectResult.denied(gate:"G2")` |
| G3 | `read_allowed == true` | `EffectResult.denied(gate:"G3")` |
| G4 | clamp `effective_limit = min(plan.limit, row_limit)` | not denial — clamp recorded in receipt |
| G5 | `include_all && !allow_include_all` | `EffectResult.failed(error_kind:"query_error", gate:"G5")` |
| G6 | mocked execution | `EffectResult.succeeded` / `EffectResult.denied` |

**Receipt emitted on all paths** (including denial). P8: Receipts Are Proof.
If executor returns without a receipt field → RuntimeMachine assertion: `effect.no_receipt_emitted`.

---

## Q5 — Result Envelope Serialization for Proof Artifacts

All envelopes are serialized as nested Hashes with string keys (not symbol keys).
This matches the canonical JSON pattern already established across the proof runtime:

- `ObsPacket#to_h` returns string-keyed hashes
- `MemoryTBackend` stores and retrieves string-keyed payloads
- `Canonical.normalize` converts symbol keys to strings

**Serialization contract for EffectResult:**

```ruby
result = EffectResult.denied(
  receipt: some_receipt,
  gate:    "G1",
  reason:  "source not in allowed_sources"
)
# result is already a string-keyed Hash — no additional serialization needed
# JSON.generate(result) works directly
```

**Serialization contract for EffectReceipt:**

```ruby
receipt = EffectReceipt.new(
  receipt_id:       "receipt/sha256:...",
  outcome:          "denied",
  # ... other fields
)
receipt.to_h  # returns string-keyed Hash via Struct#to_h + transform_keys
```

**Proof artifact pattern (follows ObsPacket pattern):**

```ruby
# The host proof runner wraps results in platform_observation packets:
ObsPacket.new(
  kind:    "effect_execution_observation",
  subject: "effect://ExecuteQuery/read_file",
  payload: {
    "effect_result" => result,
    "receipt"       => receipt.to_h
  },
  temporal: { as_of: PROOF_AS_OF },
  links:    evidence_links
)
```

**No new serialization format.** Existing `ObsPacket` + `MemoryTBackend` pattern
is sufficient for proof artifact capture. P3 proof runner creates a mini-session
(boot → load fixture → inject passport → execute → check receipt).

---

## Q6 — Minimal Implementation Required by P3

P3 must produce an **executable proof** that the full P1-defined interface works
against the Storage read family. Minimal implementation:

### Authorized files — P3 only

| File | Role |
|---|---|
| `experiments/io_capability_executor/capability_executor_runtime.rb` | All module/class definitions from Q2 |
| `experiments/io_capability_executor_proof/verify_io_capability_executor_p3.rb` | Proof runner ≥ 55 checks |

**No other files added or modified in P3.**

### Minimal class implementations required

**1. `CapabilityPassport` Struct** — as defined in Q2. Must support `.expired?` and `.valid_family?`.

**2. `EffectReceipt` Struct** — as defined in Q2. 14 fields. `#to_h` returns string keys.

**3. `ExecutionContext` Struct** — as defined in Q2. 4 fields.

**4. `RuntimeRefusal` Struct** — as defined in Q2. 4 fields. `#to_h` returns string keys.

**5. `EffectResult` module** — 7 factory class methods returning string-keyed Hashes.
Each includes `"receipt"` key for the EffectReceipt.

**6. `CapabilityExecutor` module** — interface only; `#family_id` and `#execute` raise `NotImplementedError`.

**7. `CapabilityExecutorRegistry` class** — `#register`, `#fetch`, `#supports?`, `#registered_families`.

**8. `StorageCapabilityExecutor` class** — includes `CapabilityExecutor`. Implements `#family_id` → `"storage"`. Implements `#execute` with G1–G6 gates using `passport.family_fields` (the `IO.StorageCapability` schema: `allowed_sources`, `allowed_ops`, `row_limit`, `allow_include_all`, `read_allowed`, `write_allowed`, `deny_reason`).

### P3 proof runner must verify (≥55 checks)

- A: file loadable without error
- B: CapabilityPassport fields + expired?/valid_family? methods
- C: ExecutionContext fields
- D: RuntimeRefusal shape + to_h string keys
- E: EffectResult 7 factory methods + outcome helpers
- F: EffectReceipt 14 fields + to_h string keys
- G: CapabilityExecutor module interface (family_id/execute raise NotImplementedError)
- H: CapabilityExecutorRegistry (register/fetch/supports?/registered_families)
- I: StorageCapabilityExecutor G1–G6 gate sequence
- J: Denial-as-data: each G1/G2/G3 produces EffectResult.denied with receipt
- K: G4 clamp: not denial; effective_limit in receipt
- L: G5 query_error: EffectResult.failed (not denied)
- M: G6 success path: EffectResult.succeeded with rows_returned > 0
- N: Receipt emitted on ALL paths (denied, failed, succeeded)
- O: P15: timed_out + unknown_external_state are distinct from denied/failed
- P: Closed surfaces (no real DB/SQL/ORM/network/production)

---

## Implementation Dimensions Summary

| Dimension | Decision |
|---|---|
| Location | `experiments/io_capability_executor/` — NOT lib/ |
| CapabilityExecutor | Ruby module (interface) — include in executor classes |
| CapabilityPassport | Ruby Struct, 7 fields, keyword_init |
| EffectResult | Ruby module with 7 factory class methods → string-keyed Hash |
| EffectReceipt | Ruby Struct, 14 fields, keyword_init, to_h → string keys |
| ExecutionContext | Ruby Struct, 4 fields, keyword_init |
| RuntimeRefusal | Ruby Struct, 4 fields, keyword_init, to_h → string keys |
| Registry key | Capability class string e.g. "IO.StorageCapability" |
| Registry API | register(class, executor) / fetch(class) → executor|nil / supports?(class) → bool |
| Layer 1 validation | Registry: family supported? check only |
| Layer 2 validation | RuntimeMachine: 5-point passport verification before execute |
| Layer 3 validation | Executor: idempotency + G1–G6 business logic gates |
| Serialization | String-keyed Hashes — native to ObsPacket/MemoryTBackend pattern |
| P3 file count | 2 (runtime lib + proof runner) |
| Regression requirement | P1 proof (80/80) must still PASS after P3 |

---

## Closed Surfaces

| Surface | Status |
|---|---|
| No lib/ changes | CLOSED — executor is NOT a compiler component |
| No real DB / SQL / ORM / network / file | PERMANENTLY CLOSED |
| No production runtime claim | CLOSED |
| No Reference Runtime claim | CLOSED |
| No public / stable API | CLOSED |
| No ambient IO | CLOSED |
| No write ops | CLOSED (v0 read-only) |
| No grammar / parser / TC / emitter changes in P3 | CLOSED |
| No assembler changes in P3 | CLOSED |
| No PROP-035 Effect Surface enforcement in P3 | CLOSED — P3 is executor only |
| No Stage 2+ STORAGE fragment class | CLOSED |
