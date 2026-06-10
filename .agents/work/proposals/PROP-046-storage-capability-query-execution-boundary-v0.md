# PROP-046: IO.StorageCapability — Query Execution Boundary

**Status:** authored — proposal only; no implementation authorized
**Date:** 2026-06-10
**Author:** `[Portfolio Architect Supervisor / Language Design Agent]`
**Depends on:**
  - PROP-035 (effect surface: `capability`/`effect_binding` grammar — experiment-pass)
  - PROP-043-P5 (Map[K,V] production — Map[String,String] on QueryPlan.metadata)
  - LAB-QUERY-P1 (query boundary research)
  - LAB-QUERY-P2 (QueryPlan pure builder proof — 42/42)
  - LAB-QUERY-P3 (QueryPlan v1 nested records + Collection[FilterPredicate] — 44/44)
  - LAB-STORAGE-CAPABILITY-P1 (IO.StorageCapability design — design-locked)
  - LAB-VM-MAP-P1 (VM map_get/or_else — 48/48)
  - STAB-P4 (Mode A governance decision packet — Mode A closed)

**Stage:** 3
**Route:** PROPOSAL AUTHORING ONLY
**Governance note:** STAB-P4 (2026-06-10) explicitly named PROP-046-P1 as "proposal authoring if explicitly authorized." The issuing card is the explicit authorization. Mode A is closed per STAB-P4 executive verdict. No grammar/parser/typechecker/runtime implementation is authorized by this document.

---

## § 1. Purpose

This proposal defines the design boundary for `IO.StorageCapability` and future
query execution authority in Igniter-Lang.

It answers the question: *what is the authority surface for bounded storage reads?*

PROP-035 established `IO.NetworkCapability` as the pattern for IO capability
types. That proposal introduced `capability`/`effect_binding` grammar productions
and the `IO.*` opaque type sentinel. The same grammar already applies to
`IO.StorageCapability` — no new grammar productions are needed. What this
proposal adds is the **semantic design** for the storage capability surface:
its schema, its denial gates, its receipt shape, its fragment classification,
and the design questions that must be resolved before any P2 implementation.

The lab evidence base for this proposal is:

| Lab card | Checks | Scope |
|---|---|---|
| LAB-QUERY-P1 | research | QueryPlan boundary; ORM closed; StorageCapability boundary modelled |
| LAB-QUERY-P2 | 42/42 | QueryPlan v0 + pure builder contracts; denial-as-data |
| LAB-QUERY-P3 | 44/44 | QueryPlan v1 nested records; Collection[FilterPredicate]; chained access |
| LAB-STORAGE-CAPABILITY-P1 | design | 6-gate sequence; receipt shape; 10 decisions locked |

**Non-goals:**
- No grammar changes: PROP-035 grammar is already sufficient for `capability storage: IO.StorageCapability`
- No TypeChecker changes: `IO.StorageCapability` already resolves to the `IO.Capability` opaque sentinel via PROP-035
- No new SemanticIR nodes: capability/effect_binding IR already emitted by PROP-035
- No runtime execution: no DB connection, no SQL executor, no ORM, no ActiveRecord
- No stable public API
- No ORM compatibility

---

## § 2. Core Formula

```
QueryPlan     =  pure typed intent data
                 Constructing a QueryPlan requires no capability.
                 QueryPlan is CORE fragment class.

StorageCapability  =  authority to attempt bounded storage execution
                      StorageCapability is required for ExecuteQuery.
                      ExecuteQuery is ESCAPE (v0) → STORAGE (Stage 2+).

QueryResult   =  typed outcome or denial
                 All denials: QueryResult{kind:"denied"}.
                 No exception. No raise. No untyped error.
```

And the permanent closed-surface laws:

```
StorageCapability  ≠  database connection
StorageCapability  ≠  ORM or ActiveRecord
StorageCapability  ≠  SQL runtime or raw SQL text
StorageCapability  ≠  persistence framework
StorageCapability  ≠  TBackend (orthogonal track — see §7)
```

---

## § 3. Grammar (Existing — PROP-035)

No new grammar productions are required. PROP-035 already provides the full
surface needed for storage capability declarations:

```
capability-decl      ::= "capability" ident ":" type-ref
effect-binding-decl  ::= "effect" ident "using" ident
```

Illustrative source for a future `ExecuteQuery` contract:

```igniter
-- Future: not yet written in any fixture. DESIGN TARGET ONLY.
effect contract ExecuteQuery {
  capability storage: IO.StorageCapability
  effect read_from_storage using storage
  input  plan   : QueryPlan
  output result : QueryResult
}
```

The grammar for `capability storage: IO.StorageCapability` and
`effect read_from_storage using storage` already compiles cleanly via PROP-035.
`IO.StorageCapability` resolves to the `IO.Capability` opaque sentinel — the
same path as `IO.NetworkCapability`. The typechecker does not validate schema
fields at compile time (opaque type design law, per PROP-035 §5.2).

This means **P2 does not need new grammar work.** It can go directly to a proof
runner that exercises the PROP-035 grammar with storage-specific inputs. See §12.

---

## § 4. Design Question Answers

### Q1: Should the capability type name be `IO.StorageCapability`, `StorageCapability`, or another namespace?

**Answer: `IO.StorageCapability`.**

Rationale:
- The `IO.*` namespace is the established opaque type sentinel pattern (PROP-035
  §5.2: `IO.NetworkCapability`, `IO.FileCapability`, `IO.Capability`). Using it
  signals that this is an I/O boundary type, not a pure-code domain record.
- `StorageCapability` without the `IO.` prefix would be indistinguishable from a
  user-defined named Record at the parser level — it would not trigger the
  opaque sentinel path in the TypeChecker.
- `IO.StorageCapability` is self-documenting: it is a storage-domain capability
  in the IO namespace.

### Q2: Is `allowed_sources` enough for v0, or is `allowed_tables` clearer?

**Answer: `allowed_sources` (preferred); `allowed_tables` is acceptable but discouraged.**

Rationale:
- The language-level concept is already `QuerySource` (not `QueryTable`). The
  QueryPlan field is `source: QuerySource`, and `QuerySource.table: String`. Using
  "source" at the capability level aligns with the plan vocabulary.
- "Table" is a relational/SQL implementation detail behind the capability boundary.
  The capability governs access to named sources; what those sources physically are
  (tables, views, CTEs, virtual sources) is not the language's concern in v0.
- `allowed_sources` mirrors `allowed_hosts` (not `allowed_IPs`) in
  `IO.NetworkCapability` — the host concept, not the transport implementation.
- **Decision: `allowed_sources` is the canonical field name.**

### Q3: Should row limit overflow clamp or deny?

**Answer: Clamp (record in receipt; no denial).**

Rationale:
- Row limit is a budget constraint, not an access control boundary. The capability
  grants authority to read from the named source; it limits result set size for
  safety and performance.
- If the plan requests 10,000 rows and the capability allows 1,000, the correct
  behavior is to return 1,000 rows (the maximum the capability permits) — not to
  deny the read entirely.
- Denial (G1–G3) is reserved for access control failures: wrong source, wrong op,
  read_allowed: false. These are authorization failures. Row limit excess is not.
- Gate G4: `effective_limit = min(plan.limit, cap.row_limit)`.
  Receipt records `row_limit_clamped: true` when clamping occurred.
- `row_limit: 0` is a misconfig (OOF-STORE5 candidate) that happens to deny all
  rows. This is unusual and detectable at proposal/proof time.

### Q4: Should `include_all` violation be `query_error` or `denied`?

**Answer: `query_error` (not `denied`).**

Rationale:
- `allow_include_all: false` is a plan-formation constraint. The capability *is*
  willing to serve this source and this operation. The plan asked for full
  projection (`Projection{include_all: true}`) which the capability doesn't support.
- This is analogous to a malformed API request — the server is reachable, it would
  serve the resource, but the request form is invalid for the current policy.
- `denied` is semantically "you may not access this resource." `query_error` is
  "your plan is malformed for this capability's configuration." These have different
  consumer semantics: `denied` → don't retry same plan; `query_error` → fix the
  plan and resubmit.
- **The consumer who submits a plan with `include_all: true` against a restricted
  capability must fix the projection, not wait for authorization to change.**

### Q5: Are write ops completely closed in v0 or proposal-deferred?

**Answer: Closed in v0; design-deferred (not permanently closed).**

Rationale:
- `write_allowed: Bool` is present in the schema but always `false` in v0. The
  field is reserved to avoid a breaking schema change when write ops are designed.
- Write operations require: mutation capability design, WAL/conflict semantics,
  transaction isolation design, write `QueryPlan` variant, `WriteResult` envelope.
  None of these are designed. v0 read-only is the correct scope.
- "Deferred" (v1+) is correct — write ops are architecturally possible with
  `IO.StorageCapability` extended. "Permanently closed" would be incorrect since
  write authorization is a natural future capability surface.

### Q6: Should SQL text generation be mentioned at all, or stay proof-local/deferred?

**Answer: Stay deferred/proof-local. Do not mention SQL text generation as a
language surface.**

Rationale:
- SQL text generation is an executor implementation detail, not a language-level
  design. `IO.StorageCapability` grants authority for the executor to perform
  bounded reads; how the executor implements that (SQL, Datalog, NoSQL, in-memory)
  is behind the capability boundary.
- Prescribing SQL in the language proposal would tie the design to a specific
  executor technology. The QueryPlan is typed intent data; it is the executor's
  responsibility to interpret it.
- If a proof-local SQL generation module is needed in a future lab card, it stays
  lab-only evidence — not a canonical language surface.

### Q7: How does `StorageCapability` differ from TBackend/Temporal storage?

**Answer: Orthogonal tracks. Must not be conflated.**

| Axis | `IO.StorageCapability` | `TBackend[T]` (PROP-008) |
|------|------------------------|--------------------------|
| Purpose | Bounded relational-like query execution | Time-ordered, append-only event storage |
| Data model | Tabular sources (tables/views) | Event streams with History[T]/BiHistory[T] |
| Temporal semantics | None in v0 | Valid-time / transaction-time coordinates |
| Read form | `QueryPlan{kind:"select", source, filters, ...}` | `read h: History[T] at_time(...)` |
| Fragment class | ESCAPE (v0) → STORAGE (Stage 2+) | TEMPORAL |
| Event sourcing | No | Yes (`append`, `replay`) |
| OOF space | OOF-STORE1..5 (candidates) | OOF-T1..Tn (TEMPORAL) |
| Grammar surface | `capability storage: IO.StorageCapability` + PROP-035 | `read h: History[T]` |

**Design law:** `IO.StorageCapability` is NOT a temporal storage capability. It
does not provide History[T]/BiHistory[T] access. Any contract that needs temporal
reads uses TBackend directly. These are separate authority surfaces.

### Q8: How does this relate to denial-as-data and future epistemic outcomes?

**Answer: Denial-as-data is the base invariant. No broader epistemic infrastructure
required for v0.**

The denial-as-data pattern is now confirmed across 4 domains and 8 proofs:
- Network: `ContractResult{kind:"capability_denied"}`
- HTTP: `HttpResult{kind:"denied"}`
- Validation: `ValidationResult{kind:"unauthorized"}`
- Query: `QueryResult{kind:"denied"}`

`IO.StorageCapability` v0 follows the same pattern. All gate failures (G1–G3, G5)
return typed `QueryResult` data. No exception is raised. The consumer branches on
`result.kind`.

Future epistemic outcome work (if any) would extend the receipt shape or the
executor's accountability surface. StorageCapability v0 does not require broader
epistemic infrastructure — the 5-kind `QueryResult` vocabulary is sufficient.

### Q9: Which OOF-STORE codes are candidates and which stay deferred?

**Answer: OOF-STORE1..5 as defined below; all remain candidates until PROP-035
grammar enforcement is added for storage-specific constraints. See §9.**

### Q10: What proof gate should open next?

**Answer: LAB-STORAGE-CAPABILITY-P2. Scope: proof runner that exercises the
6-gate denial sequence with a mocked StorageCapability via PROP-035 grammar + Layer
C simulation. See §12.**

---

## § 5. IO.StorageCapability Schema

### § 5.1 JSON schema (v0)

```json
{
  "capability_id":     "storage-read-users-v0",
  "resource_type":     "storage",
  "allowed_sources":   ["users", "posts", "sessions"],
  "allowed_ops":       ["read"],
  "row_limit":         1000,
  "allow_include_all": false,
  "read_allowed":      true,
  "write_allowed":     false,
  "deny_reason":       ""
}
```

### § 5.2 Field definitions

| Field | Type | Default | Semantics |
|-------|------|---------|----------|
| `capability_id` | String | — | Unique identifier. Surfaced in `QueryExecutionReceipt.cap_id`. Used for audit trail and receipt correlation. |
| `resource_type` | String | `"storage"` | Domain discriminant. Always `"storage"` for this capability class. Distinguishes from `"network"`, `"file"`, etc. |
| `allowed_sources` | `[String]` | `[]` | Source names eligible for query. **Empty = deny all (fail-closed).** Exact-match in v0. Glob/pattern matching deferred to v1. Mirrors `allowed_hosts` in NetworkCapability. |
| `allowed_ops` | `[String]` | `[]` | Operations permitted on allowed sources. Closed set in v0: `"read"` only. `"write"` is reserved but not designed. Empty = deny all (fail-closed). |
| `row_limit` | Integer | `0` | Maximum rows returned per execution. `0` = clamp to zero rows (effective deny; OOF-STORE5 misconfig candidate). Executor applies `effective_limit = min(plan.limit, row_limit)`. Clamps; does not deny. |
| `allow_include_all` | Bool | `false` | Whether `Projection{include_all: true}` plans are allowed. `false` → Gate G5 fires `QueryResult{kind:"query_error"}` if plan requests `include_all`. |
| `read_allowed` | Bool | `false` | Master read gate. `false` → deny all reads regardless of `allowed_sources` or `allowed_ops`. Mirrors `connect_allowed` in NetworkCapability. |
| `write_allowed` | Bool | `false` | Master write gate. Always `false` in v0 (write path not designed). Field reserved for v1. |
| `deny_reason` | String | `""` | Human-readable denial context. Surfaced in `QueryResult.message` when denied. Does not leak capability internals. |

### § 5.3 Fail-closed defaults

All fields default to the most restrictive value:
- `allowed_sources: []` → denies all sources
- `allowed_ops: []` → denies all operations
- `read_allowed: false` → denies all reads
- `write_allowed: false` → denies all writes
- `row_limit: 0` → clamps to 0 rows
- `allow_include_all: false` → rejects `include_all` plans

A `StorageCapability` with no explicit configuration denies all access. This
mirrors the fail-closed design of `IO.NetworkCapability`.

### § 5.4 Capability schema matrix

| Dimension | v0 | v1 (deferred) |
|-----------|----|----|
| Source allowlist | `allowed_sources: [String]` — exact match | glob/pattern match |
| Op set | `["read"]` only | add `"write"`, `"aggregate"`, `"stream"` |
| Row budget | clamp `min(plan.limit, row_limit)` | per-query budget tokens |
| Projection | allow/deny `include_all` | field-level projection rules |
| Read authority | `read_allowed: Bool` | read scopes by source pattern |
| Write authority | `write_allowed: false` always | `write_allowed: Bool`; mutation design |
| Sub-delegation | not present | delegation algebra (like NetworkCapability) |
| Source namespacing | flat `table` string | schema-qualified `schema.table` |
| Fail-closed | all fields default to deny/false | preserved |

---

## § 6. Denial-as-Data Gate Sequence

### § 6.1 Gate table (6 gates, fail-closed, short-circuit)

| Gate | Check | Failure outcome | Outcome kind |
|------|-------|----------------|--------------|
| G1 | `plan.source.table` ∈ `cap.allowed_sources`? (fail-closed: empty = deny all) | `QueryResult{kind:"denied", message: cap.deny_reason, count:0, metadata:{gate:"G1"}}` | `"denied"` |
| G2 | `"read"` ∈ `cap.allowed_ops`? | `QueryResult{kind:"denied", count:0, metadata:{gate:"G2"}}` | `"denied"` |
| G3 | `cap.read_allowed == true`? | `QueryResult{kind:"denied", count:0, metadata:{gate:"G3"}}` | `"denied"` |
| G4 | `plan.limit > cap.row_limit`? → clamp: `effective_limit = min(plan.limit, cap.row_limit)` | *(clamp; no denial; receipt records `row_limit_clamped:true`)* | — |
| G5 | `plan.projection.include_all == true` and `cap.allow_include_all == false`? | `QueryResult{kind:"query_error", message:"include_all not permitted by capability", count:0}` | `"query_error"` |
| G6 | Execute plan (mocked in v0) | `QueryResult{kind:"rows"\|"empty"\|"system_error", count:N, ...}` | result-dependent |

### § 6.2 Gate semantics notes

**G1 (source allowlist):** The most common gate failure in practice. Protects
against unauthorized source access. An empty `allowed_sources` list fails G1 for
*all* plans — this is the fail-closed default.

**G4 (row budget):** Not a denial gate. Row limit is a safety clamp, not an
access control boundary. The executor silently applies `effective_limit` and
records `row_limit_clamped: true` in the receipt. The caller receives fewer rows
than requested but is not denied.

**G5 (include_all):** Not a denial — it is a plan-formation error. The capability
would serve the source and op; the plan asks for full projection which the
capability policy restricts. Consumer must fix the projection and resubmit.
`"query_error"` not `"denied"`.

**G6 (execution):** In v0, execution is always mocked (Layer C simulation). No
DB connection is opened. No real query is executed.

### § 6.3 Denial-as-data invariant

> All `IO.StorageCapability` gate failures (G1, G2, G3) return `QueryResult`
> typed data with `kind:"denied"`. G5 returns `kind:"query_error"`. No exception
> is raised. No `raise` appears in any execution path. The consumer branches
> deterministically on `result.kind`.

This invariant is consistent with the denial-as-data pattern confirmed across
4 domains (8 proofs): network, HTTP, validation, and query.

### § 6.4 Denial/query_error/outcome matrix

| Scenario | Gate | outcome.kind | Consumer action |
|----------|------|-------------|-----------------|
| Source not in `allowed_sources` | G1 | `"denied"` | Do not retry same plan |
| `"read"` not in `allowed_ops` | G2 | `"denied"` | Requires capability change |
| `read_allowed: false` | G3 | `"denied"` | Requires capability change |
| Row limit exceeded | G4 | *(clamped; no failure)* | Handle reduced result set |
| `include_all` on restricted cap | G5 | `"query_error"` | Fix plan: use explicit projection |
| Executor infrastructure failure | G6 | `"system_error"` | Retry (infrastructure, not authorization) |
| Zero rows matched | G6 | `"empty"` | Show empty state to consumer |
| Rows returned successfully | G6 | `"rows"` | Iterate and transform result |

---

## § 7. QueryExecutionReceipt Shape

### § 7.1 Shape definition

```
QueryExecutionReceipt {
  cap_id:            String,              -- capability.capability_id
  plan_kind:         String,              -- QueryPlan.kind (always "select" in v0)
  source_table:      String,              -- QueryPlan.source.table
  op_requested:      String,              -- "read" in v0
  cap_checked:       Bool,               -- was capability gate sequence evaluated?
  cap_granted:       Bool,               -- false if any gate denied
  denial_gate:       String,              -- "G1"..".G5"; empty if granted
  deny_reason:       String,              -- non-empty if denied; empty if granted
  plan_limit:        Integer,             -- from QueryPlan.limit
  row_limit_cap:     Integer,             -- from capability.row_limit
  effective_limit:   Integer,             -- min(plan_limit, row_limit_cap)
  row_limit_clamped: Bool,               -- true if effective_limit < plan_limit
  rows_returned:     Integer,             -- actual row count
  result_kind:       String,              -- QueryResult.kind
  metadata:          Map[String, String]  -- trace_id, requester, request_id, etc.
}
```

### § 7.2 Receipt invariants

1. `cap_granted == false` iff `result_kind ∈ {"denied", "query_error"}`
2. `denial_gate` is non-empty iff `cap_granted == false`
3. `rows_returned == 0` when `cap_granted == false`
4. `effective_limit ≤ row_limit_cap` always
5. `row_limit_clamped == (effective_limit < plan_limit)`
6. `denial_gate ∈ {"", "G1", "G2", "G3", "G5"}` — G4 never produces a denial

### § 7.3 Receipt is evidence, not authority

A `QueryExecutionReceipt` with `cap_granted: true` does NOT re-authorize subsequent
executions. Each execution independently re-evaluates the full gate sequence. The
receipt is for audit, observability, and test assertion — not runtime re-use.

This follows the `PolicySchedulingReceipt` precedent (LAB-CONCURRENCY-P4): receipts
are telemetry. The capability is the authority.

---

## § 8. Fragment Classification

### § 8.1 Classification matrix

| Contract | Fragment class | Rationale |
|----------|---------------|-----------|
| `BuildFilterPredicate` | CORE | Pure; no capability |
| `BuildOrderBy` | CORE | Pure; no capability |
| `BuildProjection` | CORE | Pure; no capability |
| `BuildQuerySource` | CORE | Pure; no capability |
| `BuildRichSelectPlan` | CORE | Pure; no capability |
| `PlanNestedFieldReader` | CORE | Pure; no capability |
| `PlanMetadataReader` | CORE | Pure; no capability |
| `QueryResultDenied` | CORE | Pure; denial data construction; no IO |
| `ExecuteQuery` (future) | ESCAPE (v0) → STORAGE (Stage 2+) | Has `capability`/`effect_binding`; external surface |

### § 8.2 STORAGE fragment class

`STORAGE` is a named fragment class, analogous to `TEMPORAL` (PROP-028). It would
classify contracts that execute queries against a storage subsystem via
`IO.StorageCapability`.

```text
STORAGE   Requires IO.StorageCapability.
          Bounded storage reads only in v0.
          Produces CORE-typed values (QueryResult), but the contract is STORAGE.
```

This is a Stage 2+ concern. `STORAGE` requires:
- PROP-035 effect grammar (already implemented — ✅)
- An `ExecuteQuery` proof (LAB-STORAGE-CAPABILITY-P2 — not yet written)
- A ch4 amendment to add STORAGE to the fragment class table
- Explicit governance authorization

Until STORAGE class is defined in ch4, `ExecuteQuery` contracts are classified as
`ESCAPE` — the coarse external-surface label. This is the same path `TEMPORAL` took
before PROP-028 defined it.

### § 8.3 Fragment class interaction with TBackend

```text
TBackend read    →  TEMPORAL  (requires History/BiHistory coordinates)
StorageCapability query  →  ESCAPE (v0) → STORAGE (Stage 2+)
```

These must NEVER be conflated. The fragment classes are orthogonal. A contract
must not use both `TBackend.read` and `IO.StorageCapability.ExecuteQuery` in the
same contract — this would require both TEMPORAL and STORAGE capabilities, which
are separate authority surfaces with different semantics.

---

## § 9. OOF-STORE Diagnostic Candidates

These are proposed diagnostic codes for the STORAGE capability surface. **All
remain candidates — not active.** No grammar currently enforces them. Activation
requires a future proposal amendment after P2 proof.

### § 9.1 Candidate table

| Code | Stage | Severity | Trigger condition | Priority | Analogy |
|------|-------|----------|-----------------|---------|---------|
| OOF-STORE1 | Classifier | error | Dynamic source name: `source_table` is a computed value, not a string literal | High | OOF-MAP2: `Map[String,Any]` — dynamic type risks |
| OOF-STORE2 | Classifier | error | Write op on read-only capability: `QueryPlan.kind` includes write intent and `write_allowed: false` | High | OOF-M2: pure contract with capability |
| OOF-STORE3 | TypeChecker | warning | Source name not in static `allowed_sources` at analysis time (literal source, but not in literal allowlist) | Medium | OOF-M5: capability declared but not bound |
| OOF-STORE4 | TypeChecker | warning | `include_all: true` in plan against cap with literal `allow_include_all: false` | Medium | Static plan-capability mismatch detectable |
| OOF-STORE5 | Classifier | warning | `row_limit: 0` in capability — effective deny-all misconfig | Low | `allowed_hosts: []` in NetworkCapability |

### § 9.2 OOF-STORE1 detail (high priority)

Dynamic source names break static analysis:

```igniter
-- BAD (OOF-STORE1 candidate):
compute table_name = or_else(map_get(context, "table"), "users")
compute plan = { kind: "select", source: { table: table_name, ... }, ... }
```

Static analysis cannot verify that `table_name` is in the capability's
`allowed_sources` allowlist. This is the storage analog of `Map[String,Any]`
(OOF-MAP2) — the type system can only enforce static guarantees.

Mitigation path: require literal string sources at static analysis time, or
accept that only runtime enforcement can catch this class of error (G1 gate check).

### § 9.3 Activation conditions

OOF-STORE codes should be activated in the same proposal that implements
`ExecuteQuery` effect contract checking. They are not useful without the grammar
that makes `ExecuteQuery` a typechecked construct. Current status: candidates
reserved, not active.

---

## § 10. Closed Surface Matrix

### § 10.1 Permanently closed

| Surface | Reason | Status |
|---------|--------|--------|
| Real database connection (`PG::Connection`, `ActiveRecord::Base.connection`, `mysql2`, etc.) | Architectural incompatibility with the pure-contract model; connection lifecycle not managed by the language | PERMANENTLY CLOSED |
| SQL string execution (`execute_sql`, `raw_query`, `ActiveRecord::Base.connection.execute`) | Same as DB connection; also self-modifying query risk; SQL injection surface | PERMANENTLY CLOSED |
| ORM / ActiveRecord | Global connection state, callbacks, `save!`, `has_many`, implicit transactions — fundamentally incompatible with capability-gated, pure-contract model | PERMANENTLY CLOSED |
| Schema migrations (DDL) | DDL authority is completely separate from query execution authority; requires human oversight and migration tooling | PERMANENTLY CLOSED — separate authority class |
| Transactions (cross-statement atomicity) | Requires connection runtime and distributed coordination; not a single-query execution surface | PERMANENTLY CLOSED for v0 |
| Persistence framework wiring | No persistent state machine outside TBackend (PROP-008) | PERMANENTLY CLOSED |
| Public data API / stable query API | No stable surface; lab evidence only | CLOSED — requires explicit governance authorization |

### § 10.2 Deferred (not permanently closed)

| Surface | Deferred to | Unblock condition |
|---------|-------------|-----------------|
| Write operations (`write_allowed`) | v1 | Mutation capability design; WAL/conflict semantics; `WriteQueryPlan` type; `WriteResult` envelope |
| JOINs | v1 | Cross-source type complexity; N+1 risk; join plan type |
| Aggregates | v1 | New projection node kind (`count`, `sum`, `avg`); aggregate result type |
| OR/NOT predicates | v1 (requires PROP-044 variant) | Variant grammar for `FilterPredicate` with `and`/`or`/`not` arms |
| Row projection `Row[T]` | v1 (requires PROP-044 variant) | Typed row variant; row access contract |
| StorageCapability delegation algebra | v1 | Sub-delegation design (analogous to NetworkCapability delegation) |
| Glob/pattern in `allowed_sources` | v1 | Wildcard source matching (like `allowed_hosts: ["*.internal"]`) |
| STORAGE fragment class in ch4 | Stage 2+ | ch4 amendment; LAB-STORAGE-CAPABILITY-P2 proof; governance authorization |
| SQL generation (proof-local only) | Proof-local | Never a language surface; lab executor only |

### § 10.3 Explicitly answered questions — boolean summary

| Question | Answer |
|----------|--------|
| Should `IO.StorageCapability` open as a proposal? | YES — this document is that proposal |
| Is QueryPlan sufficiently mature for capability design? | YES — LAB-QUERY-P1/P2/P3 (88/88 checks; nested types; denied-as-data; C1 chain) |
| Should execution authority be separate from plan construction? | YES — plan construction = CORE (no capability); execution = ESCAPE/STORAGE (requires capability) |
| Does real DB execution remain closed? | YES — permanently closed |
| Does ORM/ActiveRecord compatibility remain closed? | YES — permanently closed |
| Do write operations remain closed in v0? | YES — closed in v0; deferred to v1 |
| Does SQL generation remain deferred/proof-local? | YES — not a language surface |
| Do TBackend and StorageCapability remain separate? | YES — orthogonal tracks; must not conflate |
| Is `QueryResult` denial-as-data sufficient for v0? | YES — 5-kind vocabulary proved across 8 domains |
| Must broader epistemic outcome work precede execution? | NO — `QueryResult` KDR is sufficient; epistemic extensions are additive |

---

## § 11. Evidence Base

| Source | Status | What it proves |
|--------|--------|----------------|
| LAB-QUERY-P1 | research complete | QueryPlan boundary; ORM incompatibility; StorageCapability boundary concept |
| LAB-QUERY-P2 (42/42) | proof complete | 6 pure builder contracts; 7 types; `QueryResult` 5-kind KDR; denial-as-data; C1 chain in 4th domain |
| LAB-QUERY-P3 (44/44) | proof complete | QueryPlan v1 nested records (QuerySource/Projection/FilterPredicate/OrderBy); Collection[FilterPredicate]; chained field access; denial-as-data 8th proof |
| LAB-STORAGE-CAPABILITY-P1 | design-locked | IO.StorageCapability schema; 6-gate sequence; QueryExecutionReceipt shape; 10 decisions locked |
| PROP-035 (64/64) | experiment-pass | `capability`/`effect_binding` grammar live; `IO.*` opaque sentinel; OOF-M2/M4/M5 active |
| PROP-043-P5 (55/55) | production | `Map[String,String]` metadata on QueryPlan; `map_get`/`or_else` chain proved |
| LAB-VM-MAP-P1 (48/48) | proof complete | VM `map_get`/`map_has_key` runtime; `Value::Record` = Map; QueryPlan metadata chain in VM |
| STAB-P4 | governance decision | Mode A closed; PROP-046-P1 authorized; P0/P1 seams resolved |

---

## § 12. P2 Recommendation

### § 12.1 What P2 authorizes

**Card: `LAB-STORAGE-CAPABILITY-P2`**
**Track:** `lab-storage-capability-6gate-execution-boundary-proof-v0`
**Route:** EXPERIMENTAL / LAB-ONLY
**Requires:** explicit authorization card

P2 is the first proof that exercises `IO.StorageCapability` with real grammar.
Specifically, P2 should:

1. **Write an `ExecuteQuery` effect contract in a fixture** using the PROP-035
   grammar (`capability storage: IO.StorageCapability` + `effect read_from_storage
   using storage`). This should compile cleanly through the Ruby TypeChecker (Layer A)
   and the Rust compiler (Layer B).

2. **Run the 6-gate denial sequence** with a mocked `IO.StorageCapability` via
   Layer C (Ruby simulation module). Exercise all gate paths: G1 denied, G2 denied,
   G3 denied, G4 clamp, G5 query_error, G6 rows/empty/system_error.

3. **Verify `QueryExecutionReceipt` shape**: prove that each gate path produces a
   receipt with the correct `cap_granted`, `denial_gate`, `effective_limit`,
   `row_limit_clamped`, and `result_kind` fields.

4. **Compose with QueryPlan v1**: use the nested `QueryPlan` shape proved in
   LAB-QUERY-P3 as the input to the mocked executor. Verify that
   `plan.source.table` drives gate G1 correctly.

5. **Verify closed surfaces**: no DB connection, no SQL execution, no ORM, no
   `raise`, no persistence runtime at any layer.

**Note on grammar:** P2 does NOT require new grammar work. PROP-035 already
provides `capability`/`effect_binding` grammar. `IO.StorageCapability` already
resolves to the `IO.Capability` opaque sentinel. P2 can go directly to proof
runner authoring.

### § 12.2 P2 scope boundary

| In scope for P2 | Out of scope for P2 |
|-----------------|---------------------|
| `capability storage: IO.StorageCapability` + `effect_binding` compilation | New grammar or parser changes |
| 6-gate denial sequence proof (mocked Layer C) | Real DB connection or SQL execution |
| `QueryExecutionReceipt` shape proof | ORM or ActiveRecord compatibility |
| `QueryPlan` v1 as executor input | Write operations |
| `QueryResult` 5-kind KDR verified per gate path | Joins, aggregates, OR/NOT predicates |
| Layer C mocked executor (Ruby proof-local) | STORAGE fragment class in ch4 |
| Closed-surface verification (no DB/SQL/ORM) | Delegation algebra |
| `row_limit_clamped` receipt field proof | Stable public API |

### § 12.3 P2 target check count

Suggested proof structure for `LAB-STORAGE-CAPABILITY-P2`:

| Section | n | What |
|---------|---|------|
| SCAP2-COMPILE | 4 | ExecuteQuery contract compiles; Layer A + Layer B accept |
| SCAP2-SCHEMA | 6 | Schema field types; fail-closed defaults; capability_id present |
| SCAP2-G1 | 4 | Source not in allowlist → `kind:"denied"`, `denial_gate:"G1"` |
| SCAP2-G2 | 3 | Op not in allowlist → `kind:"denied"`, `denial_gate:"G2"` |
| SCAP2-G3 | 3 | `read_allowed:false` → `kind:"denied"`, `denial_gate:"G3"` |
| SCAP2-G4 | 4 | Row limit clamp → `row_limit_clamped:true`, `effective_limit` correct |
| SCAP2-G5 | 3 | `include_all` on restricted cap → `kind:"query_error"`, `denial_gate:"G5"` |
| SCAP2-G6 | 4 | Mocked execution → `kind:"rows"`, `kind:"empty"`, `kind:"system_error"` |
| SCAP2-RECEIPT | 6 | Receipt invariants: `cap_granted`, `denial_gate`, `rows_returned`, `effective_limit` |
| SCAP2-KDR | 4 | 5-kind vocabulary routing; `"denied"` ≠ `"query_error"` ≠ `"system_error"` |
| SCAP2-COMPOSE | 5 | QueryPlan v1 as executor input; `plan.source.table` drives G1 |
| SCAP2-CLOSED | 5 | No DB/SQL/ORM/raise/persistence at any layer |

**Estimated: ~51 checks** (adjustable ± 5 in authoring).

### § 12.4 Blocker assessment

No blockers for P2 authoring:

| Dependency | Status | Impact on P2 |
|-----------|--------|-------------|
| PROP-035 grammar | ✅ experiment-pass | Grammar ready; no new grammar needed |
| QueryPlan v1 shape | ✅ LAB-QUERY-P3 (44/44) | Nested records proved and VM-executed |
| `map_get`/`or_else` VM runtime | ✅ LAB-VM-MAP-P1 (48/48) | Receipt metadata Map chain ready |
| IO.StorageCapability design | ✅ LAB-STORAGE-CAPABILITY-P1 | Schema + 6 gates + receipt shape locked |
| Mode A governance | ✅ STAB-P4 (Mode A closed) | P2 card can be issued when authorized |

**P2 is unblocked. The issuing authority (Portfolio Architect Supervisor or Language
Design Agent) may issue a P2 card after reviewing this proposal.**

---

## § 13. Design Decision Table (Locked)

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | Type name: `IO.StorageCapability` (not `StorageCapability`) | IO.* namespace is the established opaque sentinel pattern (PROP-035); distinguishes from user-defined Records |
| D2 | Field name: `allowed_sources` (not `allowed_tables`) | Mirrors QueryPlan vocabulary (`source: QuerySource`); more general than tables; mirrors `allowed_hosts` pattern |
| D3 | `allowed_sources` is fail-closed (empty = deny all) | Mirrors `allowed_hosts` NetworkCapability; safe default |
| D4 | `allowed_ops: ["read"]` only in v0; `"write"` deferred | Write path not designed; separate mutation capability needed |
| D5 | Row limit **clamps**, does not deny | Budget constraint, not authorization failure; receipt records clamping |
| D6 | `include_all` violation → `"query_error"`, not `"denied"` | Plan formation error (consumer's responsibility to fix the plan); capability is not the blocker |
| D7 | `read_allowed/write_allowed` are master gates (G3) | Global kill-switch even when allowlists would pass; mirrors `connect_allowed`/`listen_allowed` pattern |
| D8 | `deny_reason` on capability surfaced in `QueryResult.message` | Actionable context without leaking capability internals |
| D9 | `QueryExecutionReceipt` is evidence-only | Receipt does not re-authorize; follows `PolicySchedulingReceipt` precedent (LAB-CONCURRENCY-P4) |
| D10 | `ExecuteQuery` is ESCAPE (not STORAGE) in v0 | STORAGE fragment class requires ch4 amendment; ESCAPE is correct coarse label until ch4 is extended |
| D11 | No delegation algebra in v0 | Single flat capability; sub-delegation deferred to v1 |
| D12 | SQL text generation is not a language surface | Executor implementation detail; language defines typed intent (QueryPlan), not SQL text |
| D13 | `IO.StorageCapability` and `TBackend` are orthogonal tracks | STORAGE ≠ TEMPORAL; different data models, semantics, fragment classes |
| D14 | No grammar changes needed for P2 | PROP-035 already provides `capability`/`effect_binding` productions |
| D15 | Write ops closed in v0; deferred (not permanently closed) | Write path is architecturally possible; just not designed yet |

---

## § 14. Proposal Acceptance Criteria

For this proposal to advance from "authored" to "experiment-pass":

1. `LAB-STORAGE-CAPABILITY-P2` proof runner passes (≥51 checks).
2. `ExecuteQuery` effect contract compiles through Layer A and Layer B using PROP-035 grammar.
3. 6-gate denial sequence verified with mocked `IO.StorageCapability` in Layer C.
4. `QueryExecutionReceipt` shape verified with all invariants.
5. Closed surface verification: no DB connection, no SQL execution, no ORM, no `raise`.

None of these require grammar changes — P2 uses existing PROP-035 grammar.
The proposal advances to "experiment-pass" when the P2 proof runner passes and
is accepted by the Portfolio Architect Supervisor.

---

*PROPOSAL AUTHORING ONLY. No grammar/parser/typechecker/runtime implementation
authorized by this document. P2 requires explicit authorization card. DB/SQL/ORM/
migrations/transactions/persistence remain permanently closed or deferred.*
*LAB-ONLY lab evidence. No canon claim until experiment-pass + explicit acceptance.*
