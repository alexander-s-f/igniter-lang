# PROP-017: Schema Evolution and Contract Migration v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `PROP-009`, `PROP-011`, `PROP-012`, `PROP-016`

---

## Purpose

Contracts evolve. A contract deployed in production changes when:
- a new input port is added (e.g. `input locale: String`)
- an output type changes (e.g. `output score: Float` was `Integer`)
- a compute node is renamed or restructured
- a TypeDecl gains or loses a field

When a contract changes, the system faces three questions:

1. **Resume**: can an existing `SemanticImage` from the old version be resumed
   under the new contract?
2. **Observations**: do prior `ObsPacket` records remain valid evidence?
3. **Migration**: if resume is blocked, how does the system transition?

PROP-009 introduced `CompatibilityReport` with checks for runtime descriptor,
TBackend, and observation hash. This proposal adds a **fourth check dimension**:
`schema_check` — the formal treatment of contract version compatibility.

[D] Schema evolution is a first-class language concern, not an operational
afterthought. A contract that changes without a migration declaration is
**blocked from resume** by default.

---

## Part 1: Contract Versioning

### Version field in CompiledProgram

```text
CompiledProgram.schema_version : SemVer

-- SemVer: major.minor.patch (e.g. "1.2.0")
-- Declared in contract source:

contract Add {
  version "1.0.0"
  input  a: Integer
  input  b: Integer
  compute sum = a + b
  output sum: Integer
}
```

**Grammar extension:**

```text
VersionDecl := "version" StringLit    -- inside ContractDecl
```

**[D] Every contract has an explicit version declaration.**
A contract without `version` is `"0.0.0"` (development/unstable).
`"0.x.x"` contracts have no backward compatibility guarantees.

### Schema fingerprint

```text
SchemaFingerprint = Canonical.hash({
  input_ports:   [{ name, type_tag, required }],   -- sorted by name
  output_ports:  [{ name, type_tag, lifecycle }],   -- sorted by name
  type_env:      { TypeName -> { fields } },         -- all user types, sorted
  trait_bounds:  [{ param, constraint }]             -- sorted
})
```

The `schema_fingerprint` is stored in `CompiledProgram` and in `SemanticImage`.
It is **not** the same as `artifact_hash` (which includes compute nodes and
implementation details). The fingerprint covers **only the observable surface**.

---

## Part 2: Change Classification

### Safe changes (backward compatible, minor/patch version bump)

```text
SC-1: Add optional input port (with default value or Option[T]).
  old: input a: Integer
  new: input a: Integer; input locale: Option[String]
  -> existing sessions: locale = None (default). Resume: TRUSTED.

SC-2: Add output port.
  old: output sum: Integer
  new: output sum: Integer; output debug_sum: Integer
  -> existing sessions: debug_sum absent (not in SemanticImage). Resume: PROVISIONAL.

SC-3: Widen an output type (subtype-compatible).
  old: output score: Integer
  new: output score: Float
  -> widening: all Integer values are valid Float. Resume: PROVISIONAL.
  -- Note: Float -> Integer is NARROWING (see BC-3).

SC-4: Add a field to a TypeDecl (optional field only).
  old: type GeoSignal { hour: Integer; signal: String }
  new: type GeoSignal { hour: Integer; signal: String; accuracy: Option[Float] }
  -> existing observations: accuracy = None. Resume: PROVISIONAL.

SC-5: Rename a compute node (not an input/output port).
  old: compute tmp = a + b
  new: compute result = a + b (output: sum still bound to result)
  -> internal rename only. Output surface unchanged. Resume: TRUSTED.
```

### Breaking changes (major version bump required)

```text
BC-1: Remove an input port.
  old: input a: Integer; input b: Integer
  new: input a: Integer
  -> existing sessions had b. Resume: BLOCKED.

BC-2: Remove an output port.
  old: output sum: Integer; output debug: Integer
  new: output sum: Integer
  -> existing sessions expected debug. Resume: BLOCKED.

BC-3: Narrow an output type.
  old: output score: Float
  new: output score: Integer
  -> Float values may not be valid Integer. Resume: BLOCKED.

BC-4: Change required input type (not widening).
  old: input a: Integer
  new: input a: String
  -> type mismatch. Resume: BLOCKED.

BC-5: Remove or rename an output port.
  Resume: BLOCKED.

BC-6: Add required input port (no default).
  old: input a: Integer
  new: input a: Integer; input b: Integer  -- b has no default
  -> existing sessions have no value for b. Resume: BLOCKED.

BC-7: Remove a field from a TypeDecl that appears in output ports.
  -> breaks existing observations. Resume: BLOCKED.
```

---

## Part 3: CompatibilityReport — schema_check Dimension

### Extended CompatibilityReport

```text
CompatibilityReport = Record {
  report_id       : String
  session_id      : String
  machine_id      : String
  as_of           : Timestamp
  runtime_check   : CompatCheck    -- from PROP-009
  backend_check   : CompatCheck    -- from PROP-009
  observation_check: CompatCheck   -- from PROP-009
  schema_check    : SchemaCheck    -- NEW in PROP-017
  overall         : CompatDecision
}

SchemaCheck = Record {
  old_version          : SemVer
  new_version          : SemVer
  old_fingerprint      : Hash
  new_fingerprint      : Hash
  fingerprint_match    : Bool
  changes_detected     : Collection[SchemaChange]
  change_class         : :safe | :breaking | :none
  migration_available  : Bool      -- is a MigrationDecl present?
  migration_ref        : Option[String]
  decision             : :trusted | :provisional | :blocked | :migrating
}

SchemaChange = Record {
  kind    : :port_added | :port_removed | :port_type_changed |
            :type_field_added | :type_field_removed | :type_widened |
            :type_narrowed | :version_bumped | :compute_renamed
  target  : String    -- port name or type name
  detail  : String
}
```

### SchemaCheck decision rules

```text
fingerprint_match == true:
  -> schema_check decision = :trusted (no schema change)

fingerprint_match == false:
  change_class == :none:
    -> :trusted (fingerprint diverged for non-observable reason — should not happen)

  change_class == :safe AND migration_available == false:
    -> :provisional (resume allowed; new ports absent from old SemanticImage)

  change_class == :safe AND migration_available == true:
    -> :migrating (apply migration contract, then resume)

  change_class == :breaking AND migration_available == false:
    -> :blocked (cannot resume; migration required)

  change_class == :breaking AND migration_available == true:
    -> :migrating (apply migration; re-evaluate; resume)

  version_major changed (1.x -> 2.x) AND no migration:
    -> :blocked (major version without migration declaration is always blocked)
```

### CompatibilityReport.overall update rule

```text
overall = max_severity(runtime_check, backend_check, observation_check, schema_check)

Severity order: :trusted < :provisional < :migrating < :blocked

-- Example:
runtime_check:      :trusted
backend_check:      :trusted
observation_check:  :provisional
schema_check:       :migrating
overall:            :migrating
```

---

## Part 4: Migration Contracts

### The core idea

A migration is a **contract** that takes the old session state as input and
produces a new session state as output. It is typed, observable, and
receipt-producing.

```text
migration "Add" from "1.0.0" to "2.0.0" {
  -- Inputs: the old session's observable outputs
  input old_sum: Integer

  -- Compute: transform old state to new state
  compute new_sum  = old_sum               -- identity: Integer compatible with Integer
  compute new_label = "migrated"           -- new output port added in v2.0.0

  -- Outputs: what the new contract expects in its SemanticImage
  output new_sum:   Integer  lifecycle :session
  output new_label: String   lifecycle :session
}
```

### MigrationDecl grammar

```text
MigrationDecl := "migration" StringLit "from" StringLit "to" StringLit
                 "{" BodyDecl* "}"
-- "migration" ContractName "from" OldVersion "to" NewVersion
```

### Migration as an ESCAPE contract

```text
MigrationDecl fragment_class: ESCAPE
  -- Why ESCAPE? Migration reads the old TBackend state (SemanticImage)
  -- and writes new observations. It has side effects on the session.

Migration produces:
  [1] Obs[:intent_observation, MigrationPlan]
        subject: "migration://<contract>/<old_ver>-><new_ver>"
        lifecycle: :local
  [2] (for each compute node) Obs[:value_observation, result]
        lifecycle: inherits from new contract node lifecycle
  [3] Obs[:receipt_observation, MigrationReceipt]
        subject: "migration://<contract>/<old_ver>-><new_ver>/receipt"
        lifecycle: :audit   -- migration receipts are always :audit
        links: [caused_by: migration_intent_obs.id,
                produced_by: "migration://<contract>",
                replaces: old_semantic_image.id]
```

**[D] Migration receipts are always `lifecycle: :audit`.**
A migration is an irreversible transformation of session state. Its evidence
must be preserved for the lifetime of the data.

**[D] The `replaces` link is mandatory on migration receipts.**
It connects the new SemanticImage to the old one, preserving the
cross-session continuity chain.

---

## Part 5: Observation Validity Across Schema Changes

### The epistemic question

When a contract changes, do prior observations remain valid evidence?

```text
Case 1: Safe change (SC-1..SC-5)
  Old Obs[:value_observation, sum: 5] from Add v1.0.0
  New contract: Add v1.1.0 (adds optional locale input)
  -> Old observation is still valid: sum: Integer is still an output.
  -> Observation validity: PRESERVED.
  -> SemanticImage: old obs linked in continuity chain with schema_version note.

Case 2: Breaking change (BC-1..BC-7) with migration
  Old Obs[:value_observation, score: 3.14] from Scorer v1.0.0
  New contract: Scorer v2.0.0 (score: Integer instead of Float)
  -> Old observation is SUPERSEDED by migration.
  -> Migration receipt links: { rel: "replaces", ref: old_obs.id }
  -> Old observation not deleted; marked as :compacted in TBackend lifecycle.

Case 3: Breaking change without migration
  -> Resume: BLOCKED.
  -> Old observations: preserved as :audit.
  -> New session must start fresh (boot, not resume).
  -> CompatibilityReport.overall: :blocked.
```

### Schema version in ObsPacket

```text
ObsPacket gains an optional field:
  schema_version : Option[SemVer]   -- contract schema_version at observation time

This enables the TBackend to identify which schema version produced each
observation without loading the full SemanticImage.
```

---

## Part 6: Resume Semantics Under Schema Evolution

### Extended Resume decision table

```text
| schema_check  | overall  | RuntimeMachine action |
|---------------|----------|-----------------------|
| :trusted      | *        | Resume as before (PROP-009 rules apply) |
| :provisional  | *        | Resume with provisional status; new ports = None/default |
| :migrating    | *        | Execute MigrationDecl, then resume under new contract |
| :blocked      | :blocked | Refuse resume; emit failure_observation; require fresh boot |
```

### Migration execution sequence

```text
[1] CompatibilityReport.schema_check.decision = :migrating
[2] RuntimeMachine.find_migration(contract_id, old_version, new_version)
    -> if not found: schema_check -> :blocked
[3] RuntimeMachine.execute_migration(migration_contract, old_semantic_image)
    -> emits intent, compute obs, receipt obs
    -> produces new_semantic_image with new schema_version
[4] CompatibilityReport.schema_check.decision -> :migrating (was)
    New CompatibilityReport with new_semantic_image:
      schema_check.decision = :trusted (new fingerprint matches new contract)
[5] RuntimeMachine.resume(new_semantic_image)
```

---

## Part 7: Schema Change in SemanticIR

### SchemaDescriptor in CompiledProgram

```text
CompiledProgram.schema_descriptor = Record {
  schema_version     : SemVer
  schema_fingerprint : Hash
  changes_from_prev  : Collection[SchemaChange]    -- populated by compiler
  migrations         : Collection[MigrationRef]    -- available migration paths
}

MigrationRef = Record {
  from_version : SemVer
  to_version   : SemVer
  migration_id : String     -- e.g. "migration://add/1.0.0->2.0.0"
}
```

### SemanticImage schema field

```text
SemanticImage gains:
  schema_version     : SemVer
  schema_fingerprint : Hash

CompatibilityReport.schema_check compares:
  SemanticImage.schema_fingerprint vs CompiledProgram.schema_fingerprint
```

---

## Part 8: OOF Rules for Schema Evolution

```text
OOF-S1: Contract version regression.
  Deploying schema_version "1.0.0" after "1.1.0" was in production.
  A version must be >= all versions that produced observations in TBackend.
  Blocked at deploy-time schema check.

OOF-S2: Breaking change without version bump.
  BC-1..BC-7 changes with same schema_version -> compile error.
  The compiler detects the fingerprint change and rejects unchanged version.

OOF-S3: Migration without observation.
  A migration contract that does not emit a receipt_observation -> OOF.
  Migration must always produce a receipt (audit: true implied).

OOF-S4: Circular migration.
  migration "Add" from "1.0.0" to "2.0.0" and
  migration "Add" from "2.0.0" to "1.0.0"
  -> downgrade cycle. Blocked at compile time (DAG check on migration graph).

OOF-S5: Migration with undeclared ESCAPE.
  A MigrationDecl that reads TBackend without escape declaration -> OOF-C4.
  Migrations must declare their escape_set explicitly.
```

---

## Relation to PROP-009 Resume Ordering Errata

PROP-009.1 fixed the ordering of `CompatibilityReport` relative to `Boot(B)`.
PROP-017 adds `schema_check` as a fourth dimension to the existing report.
The ordering rule from PROP-009.1 applies unchanged:

```text
Boot(B) -> Load(L) -> CompatibilityReport(CR) -> Resume(R) | Blocked

CR now includes schema_check alongside runtime/backend/observation checks.
schema_check :blocked -> overall :blocked -> no Resume.
schema_check :migrating -> migration execution -> new CR -> Resume.
```

---

## Open Questions

[Q-1] Should `schema_version` be required in all contracts, or only for
contracts that have been deployed? Recommendation: required for all contracts
where `version >= 1.0.0`. `"0.x.x"` contracts are exempt.

[Q-2] Should schema_fingerprint include lifecycle annotations on ports?
A change in `lifecycle: :session -> :durable` is semantically significant.
Recommendation: yes, include lifecycle in fingerprint.

[Q-3] Should the migration graph (from_version -> to_version) support
multi-hop migrations (1.0.0 -> 1.1.0 -> 2.0.0)? Recommendation: yes,
RuntimeMachine should find the shortest path in the migration DAG.

[Q-4] Should safe changes (SC-1..SC-5) require a minor version bump, or
can they be deployed without a version change? Recommendation: minor bump
required for any fingerprint change. Patch bumps for internal compute changes
only (fingerprint unchanged).

---

## Rejected Paths

[X] Silent schema migration (automatic field mapping without a MigrationDecl).
Automatic migration without observation is not compatible with the ECL
epistemic model. Every state transition must be observable and receipt-producing.

[X] Schema evolution without version declarations.
A contract without a version is development-only. Production contracts must
declare schema_version. This is enforced by the deploy-time schema check.

[X] Type coercion at resume time (implicit Integer -> Float at runtime).
Type coercion is a compile-time concern (SC-3 widening). Runtime coercion
without a typed migration contract is OOF.

[X] Downgrade migrations as production path.
Migration from "2.0.0" to "1.0.0" is an OOF-S4 cycle risk and semantically
problematic (data loss). Downgrade is not a supported migration direction.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-017-schema-evolution-contract-migration-v0.md
Status: done

[D] Decisions:
- Every contract has explicit schema_version (SemVer). 0.x.x = unstable.
- schema_fingerprint covers observable surface only (ports + types + trait bounds).
  It is NOT artifact_hash.
- CompatibilityReport gains schema_check as 4th dimension.
- SchemaCheck.decision: :trusted | :provisional | :migrating | :blocked.
- overall = max_severity across all 4 checks.
- SC-1..SC-5: safe changes -> :provisional resume (no migration needed).
- BC-1..BC-7: breaking changes -> :blocked without migration.
- MigrationDecl is a typed ESCAPE contract: intent -> compute -> receipt (audit).
- Migration receipts: lifecycle :audit (mandatory, irreversible).
- Migration receipt must carry { rel: "replaces", ref: old_semantic_image.id }.
- schema_version field added to ObsPacket (optional, for TBackend queries).
- Migration graph must be a DAG (OOF-S4: circular migration is blocked).
- PROP-009.1 ordering errata applies unchanged: Boot -> Load -> CR -> Resume|Blocked.

[R] Recommendations:
- Implement schema_check as 5th pass in compilation pipeline (after TypedProgram).
- Store SchemaDescriptor in CompiledProgram.schema_descriptor.
- RuntimeMachine.find_migration should search migration DAG by shortest path.
- Add schema_version to SemanticImage generation in compiled_program.rb.
- Extend packet_builder_check.rb to validate schema_check field in
  CompatibilityReport golden fixtures.

[S] Signals:
- current-status.md lists schema evolution as a "Critical" open gap.
  PROP-017 closes it formally.
- The MigrationDecl ESCAPE pattern mirrors FFIAdapter (PROP-012 §FFI + ffi_ruby_proof.rb):
  intent -> capability check -> action -> receipt. Same discipline.
- The "replaces" link is the first example of a cross-session evidence link
  that explicitly supersedes rather than extends prior observations.

[Q] Open Questions:
- schema_version required for all contracts or only >= 1.0.0?
- lifecycle in schema_fingerprint? (recommendation: yes)
- Multi-hop migration DAG: shortest path or explicit chain declaration?
- Minor bump required for safe changes? (recommendation: yes)

[X] Rejected:
- Silent automatic migration.
- Contracts without version in production.
- Runtime type coercion at resume.
- Downgrade migrations.

[Next] Proposed next slice:
- PROP-018: Higher-Kinded Types and Associated Types v0
  (Functor, Iterator, Associated Types — deferred from PROP-016)
- Devkit: extend CompiledProgram with schema_descriptor;
  add SchemaCheck to CompatibilityReport in compiled_program.rb;
  update golden fixtures with schema_version fields
- Research track: ffi-ruby-migration-receipt-proof-v0
  (prove MigrationDecl as an ESCAPE contract using FFIAdapter discipline)
```
