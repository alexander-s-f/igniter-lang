# PROP-005: Bridge Observation Envelope v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `tracks/observable-spine-v0.md`,
             `tracks/failure-observation-v0.md`,
             `proposals/PROP-001-semantic-domain-v0.md`,
             `proposals/PROP-003-grammar-fragment-classification-v0.md`,
             `proposals/PROP-004-type-system-v0.md`

---

## Purpose

The `observable-spine-v0` track defined an observation packet model
informally. PROP-001 through PROP-004 defined the formal semantic domain,
composition algebra, fragment classifier, and type system.

This proposal **bridges** those two bodies of work into a single formal
envelope specification:

1. Bind `Obs[kind, T]` (the PROP-004 type) to the observation packet
   structure from `observable-spine-v0`.
2. Formalize the three field groups — **Identity**, **Provenance**,
   **Policy** — as typed record types.
3. Specify how `Option[T]` payload handles redaction.
4. Define the canonical mapping: package facts / receipts / failures →
   language observations of type `Obs[kind, T]`.

This is a **formal specification only**. No runtime bridge code. No package
edits. Bridge implementation tracks must cite this document and go through
Architect review before touching packages.

---

## Compact Claim

[D] The observation envelope is the typed boundary between Igniter-Lang
semantics and the outside world (packages, agents, runtimes, humans).

```text
Igniter-Lang contract evaluation
  -> produces Obs[kind, T] values
  -> serialized as ObservationPacket
  -> consumed by agents, compilers, runtimes, humans, and bridge adapters
```

An `Obs[kind, T]` is not a log line. It is a value in the semantic domain
(PROP-001 §6) with a declared type, a closed kind, and a structured field
model.

---

## Formal Envelope Type

### Top-Level: ObsPacket

Building on PROP-004's `Obs[kind, T]`, we define the full typed envelope:

```text
ObsPacket[kind, T] = Record {
  -- Identity group (determines equivalence)
  id       : ObsId
  space    : ObsSpace
  kind     : ObsKind                -- closed v0 family
  subject  : SubjectRef

  -- Provenance group (determines lineage)
  producer : ProducerRef
  emitted_at : Timestamp
  content_hash : Hash               -- over canonical payload

  -- Policy group (determines what consumers may do)
  privacy   : PrivacyPolicy
  links     : Collection[TypedLink]

  -- Temporal group (when meaning depends on time)
  temporal  : Option[TemporalCtx[policy]]

  -- Payload group
  payload   : Option[T]             -- None when redacted or hash-only
  payload_hash : Option[Hash]       -- present when payload is None

  -- Constraint / diagnostic group
  constraints  : Collection[ConstraintRef]
  diagnostics  : Collection[DiagnosticSummary]

  -- Capability group
  capabilities : Option[CapabilitySummary]

  -- Actor group (agent, human, system, compiler, materializer)
  actor     : Option[ActorRef]

  -- Extension group (unknown extensions cannot change v0 semantics)
  extensions : Record {}            -- open record; typed as Any at extension sites
}
```

**[D]** `ObsPacket[kind, T]` is a **parameterized record type** in the
PROP-004 type grammar. The `kind` parameter is a closed enum (CORE fragment);
`T` is the payload type (structural, from the type grammar).

---

## Identity Group

The Identity group determines when two packets are the **same observation**:

```text
ObsId    = String                -- stable, local to space; content-addressed when possible
ObsSpace = String                -- minting authority: contract, store, agent run, etc.
ObsKind  = :descriptor_observation
         | :value_observation
         | :constraint_observation
         | :fact_observation
         | :intent_observation
         | :receipt_observation
         | :failure_observation
         | :platform_observation
SubjectRef = String              -- typed URI: contract://, store://, fact://, etc.
```

**Equivalence rule:**

```text
p1 ≡ p2  iff  p1.id = p2.id  AND  p1.space = p2.space  AND  p1.kind = p2.kind
```

Two packets with the same identity but different `producer` or `emitted_at`
are **re-emissions** of the same observation — not new observations.

**[D]** Re-emissions are valid (e.g., retry, fan-out delivery). The
receiver must deduplicate by identity, not by provenance.

**Content-addressing rule:**

```text
If payload is fully present and not redacted:
  id = hash(space ++ kind ++ subject ++ canonical_payload)

If payload is hash-only or redacted:
  id = hash(space ++ kind ++ subject ++ payload_hash)

If no payload (descriptor-only):
  id = hash(space ++ kind ++ subject ++ descriptor_ref)
```

This makes the `id` a **content-addressable stable identifier**. Mutable
ids are OOF (PROP-003 classification).

---

## Provenance Group

The Provenance group determines lineage — who produced this packet and when:

```text
ProducerRef = Record {
  kind     : :compiler | :runtime | :agent | :materializer | :platform | :human
  id       : String         -- stable identifier for this producer instance
  version  : Option[String] -- producer version (required for :compiler, :platform)
}

Timestamp = Int   -- Unix epoch milliseconds; UTC; monotonic within a space
Hash      = String -- content hash; algorithm declared in extensions or platform_observation
```

**[D]** `emitted_at` is **packet production time** — when this packet was
created by the producer. It is not `as_of` (semantic read time). These are
always distinct fields (PROP-001 correction confirmed: `observed_at` ≠ `as_of`).

**[D]** `content_hash` is computed over the **canonical payload** before any
redaction is applied. This allows consumers to verify completeness of a
redacted packet: they can check the hash even if payload is `None`.

---

## Policy Group

The Policy group determines what consumers may do with the packet:

### PrivacyPolicy

```text
PrivacyPolicy = Record {
  payload_policy   : :present | :present_summary | :hashed | :redacted | :omitted
  prompt_policy    : :present | :hashed | :redacted | :omitted   -- for agent packets
  value_policy     : :present | :hashed | :redacted | :omitted   -- for value packets
  debug_ref        : Option[GatedArtifactRef]                    -- gated host details
  retention_class  : Option[String]                              -- e.g. "7d", "audit"
}
```

**Payload policy meanings:**

| Policy | `payload` field | `payload_hash` field | Consumer action |
|--------|----------------|---------------------|----------------|
| `:present` | `Some(v)` | `Some(h)` | Use payload; verify hash |
| `:present_summary` | `Some(summary_v)` | `Some(h)` | Use summary; full payload via debug_ref |
| `:hashed` | `None` | `Some(h)` | Acknowledge presence; cannot read value |
| `:redacted` | `None` | `Some(h)` | Sealed by policy; reason in diagnostics |
| `:omitted` | `None` | `None` | Not produced; reason in diagnostics |

**[D]** The `Option[T]` payload from PROP-004 maps to these policies:
`Some(v)` for `:present` and `:present_summary`; `None` for `:hashed`,
`:redacted`, and `:omitted`.

**[D]** Agents and compilers must handle `None` payload explicitly. A type
check on `obs.payload` returns `Option[T]`; the `:none` branch must be
handled by the consumer. This is type-system-enforced privacy.

### TypedLink

```text
TypedLink = Record {
  rel      : LinkRel
  ref      : ObsId | ExternalRef
  role     : Option[Symbol]
  required : Bool
}

LinkRel = :describes | :depends_on | :caused_by | :derived_from
        | :satisfies | :violates | :observed_under | :materializes
        | :redacts | :supersedes
```

**Required link policy:** If `required: true` and the referenced packet is
unavailable, the packet is incomplete. The consumer must emit a
`failure_observation` with `reason_code: dependency.unresolved_reference`.
Missing optional links mean "not available" — they do not require a failure.

---

## Temporal Group

```text
TemporalCtx[policy] = Record {
  as_of          : Option[TimeRef]      -- None = "current" (only when policy allows)
  as_of_source   : Option[:caller | :execution_context | :store_consistency | :replay]
  valid_time     : Option[TimeRange]    -- fact world-truth interval
  transaction_time : Option[Timestamp] -- system acceptance time
  rule_version   : Option[VersionRef]
  replay         : Option[ReplayContext]
  freshness      : Option[FreshnessPolicy]
}
```

**[D]** The temporal group is `Option[TemporalCtx[policy]]` at the packet
level because not all packets are time-sensitive. A `descriptor_observation`
for a static contract shape has no temporal group. A `value_observation`
from a `History[T]` read must have one.

**Typing rule for temporal group presence:**

```text
If obs : Obs[:value_observation, T]  AND  T came from Store[T] or History[T]:
  obs.temporal must be Some(TemporalCtx[...])

If obs : Obs[:descriptor_observation, T]:
  obs.temporal may be None
```

The type system enforces temporal group presence based on `kind` and payload
type. Missing temporal context on time-sensitive packets is a
`compile.missing_temporal_context` failure.

---

## Payload Group and Redaction

```text
payload      : Option[T]
payload_hash : Option[Hash]
```

**Typing:**

```text
obs : ObsPacket[kind, T]
obs.payload      : Option[T]
obs.payload_hash : Option[Hash]
```

**Redaction contract:**

```text
-- Well-formed redaction:
obs.privacy.payload_policy ∈ {:hashed, :redacted, :omitted}
=> obs.payload = None

-- Well-formed presence:
obs.privacy.payload_policy ∈ {:present, :present_summary}
=> obs.payload = Some(v)
AND obs.payload_hash = Some(hash(canonical(v)))
```

**[D]** A packet is **well-formed** iff its `payload` and `payload_hash`
fields are consistent with its `privacy.payload_policy`. The compiler
checks this at `observe(kind, e)` call sites; the runtime checks at
receipt.

**[D]** `payload_hash` is always present when `payload` is `None` and
policy is `:hashed` or `:redacted`. It is `None` only when policy is
`:omitted` (not produced at all).

---

## Package Mapping: Facts / Receipts / Failures → Obs[kind, T]

This section defines the **canonical lowering** from current Igniter package
concepts to `Obs[kind, T]`. This is a specification; bridge implementation
is a separate track.

### Ledger Facts → fact_observation

```text
LedgerFact {
  fact_id    : String
  subject    : String
  data       : Any
  appended_at: Timestamp
  causation  : Option[String]
}
```

Lowers to:

```text
Obs[:fact_observation, T] where T = Record {
  fact_id    : String
  data       : T_data      -- typed by Ledger schema if known, Any otherwise
  causation  : Option[ObsId]
}
with:
  id      = fact_id
  space   = "ledger/<partition>"
  subject = "fact://<partition>/<fact_id>"
  status  = :observed
  temporal = Some(TemporalCtx { transaction_time: appended_at })
  links   = [ { rel: :caused_by, ref: causation, required: false } ]
```

**Type note:** If the Ledger schema for the fact's subject is known to the
type system (via a `descriptor_observation` for that store), then `T_data`
is the declared store element type. Otherwise it is `Any`. Typed schema
facts enable compile-time checks on consumers; `Any` facts require runtime
narrowing guards.

---

### Durable Model Receipts → receipt_observation

```text
DurableModelReceipt {
  receipt_id       : String
  command          : String
  idempotency_key  : Option[String]
  status           : :accepted | :rejected | :deduplicated
  written_at       : Timestamp
}
```

Lowers to:

```text
Obs[:receipt_observation, T] where T = Record {
  receipt_id      : String
  command         : String
  idempotency_key : Option[String]
  status          : Variant { accepted: Unit, rejected: Unit, deduplicated: Unit }
}
with:
  id      = receipt_id (or idempotency_key if present)
  space   = "durable_model/<model_name>"
  subject = "receipt://<model_name>/<receipt_id>"
  status  = :observed
  temporal = Some(TemporalCtx { transaction_time: written_at })
  links   = [ { rel: :caused_by, ref: command_intent_id, required: true } ]
```

**[D]** The `links.caused_by` link to the originating `intent_observation`
is **required**. A receipt without a causal intent link is incomplete and
must emit `dependency.unresolved_reference`.

---

### Igniter::Error / Diagnostics → failure_observation

```text
Igniter::Error {
  message        : String
  graph          : Option[...]
  node           : Option[...]
  path           : Option[String]
  execution      : Option[...]
  source_location: Option[String]
}
```

Lowers to:

```text
Obs[:failure_observation, FailurePayload] where FailurePayload = Record {
  reason_code  : ReasonCode        -- from closed v0 family
  path         : Option[String]
  expectation  : Option[SubjectRef]
  actual       : Option[T]         -- subject to payload_policy
  remediation  : Option[RemediationHint]
}
with:
  status      = :failed | :rejected (map from error class)
  subject     = "contract://<graph_name>#<node_path>"
  temporal    = Some(TemporalCtx from execution context if available)
  links = [
    { rel: :violates,      ref: failed_constraint_or_contract_ref, required: true },
    { rel: :caused_by,     ref: upstream_failure_id,               required: false },
    { rel: :observed_under, ref: platform_version_obs_id,          required: false }
  ]
  privacy.payload_policy = :present_summary   -- actual value redacted by default
  privacy.debug_ref = gated ref to raw error if debug capability granted
```

**[D]** `source_location` (Ruby file + line) goes to `privacy.debug_ref`,
not to the packet body. It is a host-level detail, not a semantic field.

**[D]** The reason code must map to the closed v0 family. If no exact match
exists, use the closest family root (`compile.*`, `input.*`, etc.) and add
a `platform_extension_code` escape annotation.

---

### Materializer Status → intent_observation + receipt_observation

A materializer cycle produces two packets:

**Before execution (plan):**

```text
Obs[:intent_observation, MaterializerPlan] where MaterializerPlan = Record {
  plan_id       : String
  target_refs   : Collection[ArtifactRef]
  source_horizon: Collection[SubjectRef]
  parity_check  : Option[SubjectRef]
  execution_allowed: Bool
}
with:
  subject = "materializer://<name>/plan/<plan_id>"
  capabilities = CapabilitySummary {
    requested: [...],
    granted:   [],           -- no grants at plan time
    denied:    [...]
  }
```

**After execution (receipt or block):**

```text
-- Executed:
Obs[:receipt_observation, MaterializerReceipt] where MaterializerReceipt = Record {
  plan_id      : String
  artifact_refs: Collection[ArtifactRef]
  content_hashes: Collection[Hash]
  parity_status: Variant { passed: Unit, failed: String, skipped: Unit }
}

-- Blocked (no capability):
Obs[:failure_observation, FailurePayload] with:
  status = :blocked
  reason_code = capability.approval_required
  links = [ { rel: :caused_by, ref: intent_obs_id, required: true } ]
```

---

### Agent Actions → intent + receipt + failure

Agent participation produces a chain:

```text
agent proposal -> Obs[:intent_observation, AgentProposal]
agent tool result -> Obs[:receipt_observation, ToolReceipt]
agent refusal -> Obs[:failure_observation, FailurePayload]
model boundary -> Obs[:platform_observation, ModelDescriptor]
```

**AgentProposal type:**

```text
AgentProposal = Record {
  run_id          : String
  prompt_hash     : Hash             -- never raw prompt in packet
  proposed_action : Variant { patch: ArtifactRef, approval: SubjectRef,
                               query: SubjectRef, no_action: Unit }
  confidence      : Option[Float]    -- when declared by agent
  evidence_refs   : Collection[ObsId]
}
with:
  actor    = ActorRef { kind: :agent, id: agent_id, run_id: run_id }
  privacy  = PrivacyPolicy { prompt_policy: :hashed, ... }
  capabilities = CapabilitySummary { requested: [...], granted: [], denied: [...] }
```

**[D]** Raw prompts are never in packet body — only `prompt_hash`. Raw
prompts need an explicit observation contract with retention, privacy, and
capability terms. This enforces the audit-without-retention principle from
`observable-spine-v0`.

---

## Wellformedness Rules (Summary)

An `ObsPacket[kind, T]` is **well-formed** iff:

| Rule | Condition |
|------|-----------|
| WF-1 Identity | `id`, `space`, `kind`, `subject` are all non-empty strings |
| WF-2 Hash consistency | `content_hash` = hash over canonical payload (or declared-omitted hash) |
| WF-3 Payload consistency | `payload` and `payload_hash` are consistent with `privacy.payload_policy` |
| WF-4 Temporal presence | Time-sensitive kinds (`value_observation` from store/history) carry `temporal = Some(...)` |
| WF-5 Required links | All `required: true` links must resolve to known `ObsId` or `ExternalRef` |
| WF-6 Kind closed | `kind` ∈ the eight closed v0 kinds |
| WF-7 Failure links | `failure_observation` packets carry at least one `:violates` link |
| WF-8 No mutable id | `id` is computed from content; it does not change after emission |

Violations of WF-1 through WF-8 are compile-time errors when the packet is
produced by a contract. They are `constraint.invariant_violated` failures
when detected at runtime (e.g., from an external source).

---

## Typing Rules for Obs[kind, T]

### Producing an observation

```text
Γ ⊢ e : T
kind ∈ ObsKind    (closed)
privacy : PrivacyPolicy
Obs_envelope_wellformed(kind, T, privacy)    (static check)
──────────────────────────────────────────────────────────────
Γ ⊢ observe(kind, e, privacy: privacy) : ObsPacket[kind, T]
```

### Consuming payload

```text
Γ ⊢ obs : ObsPacket[kind, T]
────────────────────────────────────────
Γ ⊢ obs.payload : Option[T]
```

### Consuming identity

```text
Γ ⊢ obs : ObsPacket[kind, T]
────────────────────────────────────────
Γ ⊢ obs.id    : ObsId
Γ ⊢ obs.space : ObsSpace
Γ ⊢ obs.kind  : ObsKind
```

### Following a link

```text
Γ ⊢ obs : ObsPacket[kind, T]
link ∈ obs.links    link.rel = r
──────────────────────────────────────────────────────────────────────
Γ ⊢ obs.link(r) : Option[ObsPacket[Any, Any] | ExternalRef]
```

Link dereferencing returns `Option` because the referenced packet may not
be locally available. Consumers must handle the `None` case.

---

## Fragment Classification of Envelope Constructs

| Construct | Class | Reason |
|-----------|-------|--------|
| `ObsPacket[kind, T]` production | CORE | Typed, closed kind, wellformedness checkable |
| `obs.payload : Option[T]` access | CORE | Safe; None branch always possible |
| `obs.link(r) : Option[...]` | CORE | Safe; None for unavailable |
| `privacy.payload_policy` switching | CORE | Closed enum |
| `BiHistory` read in temporal group | ESCAPE `bi_temporal` | Two-axis temporal |
| `prompt_policy: :present` (raw prompt in packet) | OOF | Violates audit-without-retention |
| Mutable `id` (id changes after emission) | OOF | Violates content-address stability |
| Unknown `kind` (outside closed family) | OOF | Violates closed kind requirement |
| `extensions` field access as typed | ESCAPE `platform_extension_code` | Open; advisory only |

---

## Non-Goals (Deferred to Bridge Implementation Track)

[X] Wire format (JSON Schema, Protobuf, MessagePack). This proposal defines
the **semantic type** of packets. Wire format is a serialization concern for
a separate bridge implementation track.

[X] Delivery protocol (HTTP/SSE, WebSocket, gRPC). Not a language semantics
concern.

[X] Runtime deduplication algorithm. Deduplication is guided by identity
fields but the algorithm is implementation-specific.

[X] Cross-package packet routing. Which package receives which packet kind
is a runtime concern. The formal envelope only specifies what is in each
packet.

[X] Migration of existing Ledger/Durable Model packet schemas. Migration is
a bridge implementation concern; this document specifies only the target
formal shape.

---

## Open Questions

[Q] Should `ObsSpace` be a typed URI (`space://project/contract`) or a flat
string? Flat string is simpler; typed URI enables compile-time validation of
space references. Recommendation: flat string in v0; typed URI in v1 after
bridge pressure repeats.

[Q] Should `content_hash` declare its algorithm in the packet, or is the
algorithm a platform-level constant? Recommendation: declare algorithm in a
`platform_observation` at the producer boundary; reference by hash type tag
in individual packets. This avoids repeating the algorithm in every packet.

[Q] Should there be a v0 canonical serialization for content-addressing (to
ensure identical hashes across Ruby, future DSLs, and non-Igniter clients)?
Recommendation: define canonical serialization as a separate research note
after the bridge implementation track identifies repeated pain points.

---

## Rejected Paths

[X] One flat untyped JSON blob with any fields. A generic envelope still
needs a closed kind vocabulary and required field groups. The three-group
model (Identity / Provenance / Policy) is not optional — it determines
equivalence, lineage, and consumer rights respectively.

[X] Separate packet schemas per subsystem (separate Ledger packet, separate
Durable Model packet, separate Agent packet). The whole purpose of the
spine is a unified envelope. Subsystem differences belong in the `T`
parameter and the `kind` field.

[X] Raw prompt in packet body as an audit field. Prompts carry user data,
system instructions, and model internals. Audit should preserve evidence
and responsibility without forcing unsafe data retention.

[X] Observation packet as a runtime side-channel (not a semantic value).
PROP-001 and PROP-004 both establish observations as first-class values in
the semantic domain. The bridge cannot demote them back to logging.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-005
Status: done

[D] Decisions:
- ObsPacket[kind, T] is a parameterized record type in the PROP-004 type grammar.
- Field groups: Identity (id, space, kind, subject), Provenance (producer,
  emitted_at, content_hash), Policy (privacy, links), plus temporal, payload,
  constraints/diagnostics, capabilities, actor, extensions.
- Equivalence is determined by Identity group only. Re-emissions share identity
  but differ in provenance.
- payload : Option[T]; payload_hash : Option[Hash]. The Option[T] from PROP-004
  maps to five payload_policy values: present, present_summary, hashed,
  redacted, omitted.
- content_hash is computed over canonical payload BEFORE redaction. Allows
  verification of redacted packets.
- Temporal group is Option[TemporalCtx]; required for value/fact/receipt
  observations from Store/History; optional for descriptor observations.
- Four canonical mappings defined: Ledger facts, Durable Model receipts,
  Igniter::Error/diagnostics, materializer status, agent actions.
- Eight wellformedness rules (WF-1 through WF-8); violations are compile-time
  errors when packet is produced by a contract.
- Raw prompts in packet body are OOF. prompt_hash is CORE.
- Wire format, delivery protocol, runtime deduplication, cross-package routing
  are deferred to bridge implementation track.

[R] Recommendations:
- Treat ObsPacket[kind, T] wellformedness as a compiler check at observe()
  call sites. This prevents malformed packets from being produced by CORE
  contracts.
- The bridge implementation track must cite this document; no bridge code
  before Architect approval.
- Research Agent track temporal-contracts-and-projections-v0 can reference
  Projection[T, horizon] from PROP-004 and use fact_observation / value_observation
  envelope shapes from this document.
- Define canonical hash algorithm as a platform_observation in the first bridge
  implementation slice.

[S] Signals:
- The three-group model (Identity / Provenance / Policy) aligns well with
  standard distributed systems thinking: identity for dedup, provenance for
  audit, policy for access control. Having all three formally typed makes
  bridge adapter testing straightforward.
- The Option[T] payload + payload_hash pattern is structurally similar to
  content-addressed storage (IPFS, Git objects): hash-only references are
  first-class, not a degraded state.
- The canonical Ledger/Receipt/Error/Agent mappings reveal a consistent
  pattern: every lowering adds temporal context, requires a caused_by link
  (when applicable), and redacts raw host details. This consistency is a
  signal that the envelope design is correct.

[Q] Open Questions:
- Should ObsSpace be a flat string or a typed URI?
- Should hash algorithm be declared in-packet or via platform_observation?
- When is canonical serialization (for cross-language hashing) needed?

[X] Rejected:
- Flat untyped JSON blobs.
- Per-subsystem packet schemas.
- Raw prompt in packet body.
- Observations as runtime side-channels.

[Next] Proposed next slices:
- Research Agent track: temporal-contracts-and-projections-v0
  (named slices, projection horizon, command lifecycle — builds on PROP-004
   Projection[T, horizon] and PROP-005 envelope shapes)
- Bridge implementation track: bridge-observation-envelope-v0
  (first concrete mapping; cite PROP-005 as spec; no package edits without
   Architect approval)
- Optional: PROP-004b Axiom Layer Type Signatures
  (formal types for built-in functions; thin axiom layer from Law 9)
```
