# PROP-012: Compilation Artifact and Deployment Model v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-003-grammar-fragment-classification-v0.md`,
             `proposals/PROP-004-type-system-v0.md`,
             `proposals/PROP-005.1-obspacket-patch-lifecycle-verification-v0.md`,
             `proposals/PROP-006-runtime-contract-specification-v0.md`,
             `proposals/PROP-008-tbackend-contract-v0.md`,
             `proposals/PROP-010-temporal-lifecycle-retention-semantics-v0.md`,
             `proposals/PROP-011-runtime-machine-lifecycle-v0.md`,
             `docs/compilation-deployment.md`

---

## Purpose

`compilation-deployment.md` establishes:

> The primary compiler result is a **semantic deployment artifact** that
> a Runtime Machine can load, verify, observe, checkpoint, and resume.
> Define what compilation produces before implementing a compiler.

This proposal formalises: `CompiledProgram`, the four compiler stages,
`SemanticIR`, artifact identity and hashing, deployment modes, host FFI
as contractable boundary, and backend targets.

---

## Compact Claim

[D] A **CompiledProgram** is a typed, content-addressed, loadable semantic
artifact. It is the contract between the compiler frontend and the Runtime
Machine `load` step (PROP-011 §Step 2). It does not execute logic, call
TBackend, or perform host effects — those are Runtime Machine concerns.

```text
source
  -> parse  -> ParsedProgram
  -> classify -> ClassifiedProgram
  -> typecheck -> TypedProgram
  -> build IR  -> SemanticIR
  -> emit      -> CompiledProgram  (artifact)
                    -> RuntimeMachine.load(...)
```

---

## Compiler Stages

### Stage 0: ParsedProgram

```text
ParsedProgram = Record {
  source_ref   : SourceRef           -- file path, registry URI, or :inline
  source_hash  : Hash                -- SHA-256 of raw source bytes
  ast          : RawAST              -- untyped, un-annotated
  source_spans : Map[NodeId, Span]   -- for diagnostics
  grammar_version: String            -- parser grammar version
  parse_errors : Collection[ParseError]  -- non-empty => cannot proceed
}

SourceRef = Record { kind: :file | :registry | :inline; ref: String }
```

**[D]** A `ParsedProgram` with non-empty `parse_errors` cannot proceed to
classification. The compiler halts at Stage 0 and returns diagnostics only.

### Stage 1: ClassifiedProgram

```text
ClassifiedProgram = Record {
  parsed        : ParsedProgram
  nodes         : Map[NodeId, ClassifiedNode]
  fragment_class: FragmentClass           -- :core | :escape | :oof
  escape_set    : Collection[EscapeName]  -- declared escapes used
  oof_nodes     : Collection[NodeId]      -- OOF violations (if strict: false)
  oof_errors    : Collection[OOFError]    -- if strict: true -> non-empty = halt
  pass0_version : String
}

ClassifiedNode = Record {
  node_id     : NodeId
  kind        : NodeKind
  fragment    : FragmentClass
  escape_name : Option[EscapeName]
  oof_reason  : Option[OOFReason]
  span        : Span
}
```

**[D]** Classification is **Pass 0** (PROP-003). OOF nodes with
`strict_oof: true` halt compilation. With `strict_oof: false`, OOF
nodes are recorded but the classifier proceeds — ESCAPE mode.

**[D]** `fragment_class` for the whole program is the **maximum** class
of its nodes: OOF > ESCAPE > CORE. A program with one OOF node is OOF.

### Stage 2: TypedProgram

```text
TypedProgram = Record {
  classified   : ClassifiedProgram
  nodes        : Map[NodeId, TypedNode]
  type_env     : TypeEnv              -- final type assignments
  projection_descriptors: Collection[ProjectionDescriptor]
  temporal_requirements : TemporalRequirements
  lifecycle_requirements: LifecycleRequirements
  capability_requirements: CapabilityRequirements
  effect_declarations   : Collection[EffectDecl]
  ffi_requirements      : Collection[FFIRequirement]
  type_errors  : Collection[TypeError]   -- non-empty => halt
  pass1_version: String
}

TypedNode = Record {
  node_id   : NodeId
  type_tag  : TypeTag
  lifecycle : LifecycleClass
  obs_kind  : Option[ObsKind]
}

TemporalRequirements = Record {
  requires_as_of    : Bool
  requires_replay   : Bool
  requires_snapshot : Bool
  min_consistency   : ConsistencyClass
  windows           : Collection[TemporalWindow]
  slices            : Collection[NamedSlice]
}

LifecycleRequirements = Record {
  min_lifecycle : LifecycleClass      -- weakest lifecycle the program declares
  has_audit     : Bool
  has_window    : Bool
}

CapabilityRequirements = Record {
  required_caps : Collection[CapabilityName]
  effect_kinds  : Collection[EffectKind]    -- :read | :write | :observe | :notify
}
```

**[D]** `TemporalRequirements.min_consistency` is the strictest consistency
level declared across all `read` nodes. A `:memory` TBackend with
`:strong` consistency satisfies any program; `:eventual` only satisfies
programs that declare `min_consistency: :eventual` or weaker.

### Stage 3: SemanticIR

```text
SemanticIR = Record {
  program_id      : String            -- hash-derived stable ID
  source_hash     : Hash              -- from ParsedProgram
  grammar_version : String
  axiom_version   : String            -- which AxiomDescriptor this IR targets
  contracts       : Collection[ContractIR]
  dependency_graph: DependencyGraph
  evaluation_targets: Collection[EvalTarget]
  -- all TypedProgram requirements embedded:
  temporal_requirements  : TemporalRequirements
  lifecycle_requirements : LifecycleRequirements
  capability_requirements: CapabilityRequirements
  effect_declarations    : Collection[EffectDecl]
  ffi_requirements       : Collection[FFIRequirement]
  projection_descriptors : Collection[ProjectionDescriptor]
  boundary_descriptors   : Collection[BoundaryDescriptor]
}

ContractIR = Record {
  contract_id   : String
  name          : String
  fragment_class: FragmentClass
  escape_set    : Collection[EscapeName]
  input_ports   : Collection[Port]
  output_ports  : Collection[Port]
  compute_nodes : Collection[ComputeNodeIR]
  lifecycle     : LifecycleClass
  type_signature: ContractTypeSignature
}

Port = Record {
  name      : String
  type_tag  : TypeTag
  lifecycle : LifecycleClass
  required  : Bool
}

DependencyGraph = Record {
  nodes : Collection[NodeId]
  edges : Collection[DependencyEdge]   -- directed; topologically sortable
}

DependencyEdge = Record {
  from : NodeId
  to   : NodeId
  kind : :data | :temporal | :capability | :effect
}

EvalTarget = Record {
  name         : String
  contract_id  : String
  output_ports : Collection[String]
  as_projection: Option[ProjectionDescriptor]
}
```

**[D]** The `SemanticIR` is the **centre of the toolchain**. All backends
(bundle, interpreter, native) compile from `SemanticIR`. The frontend
(parser, classifier, typechecker) produces `SemanticIR`. This is the
stable boundary.

**[D]** `DependencyGraph` must be **acyclic** (DAG). A cycle in the
dependency graph is a compile error. The compiler verifies this before
emitting `SemanticIR`.

---

## CompiledProgram

```text
CompiledProgram = Record {
  -- Identity
  program_id        : String           -- hash_content(SemanticIR)
  artifact_hash     : Hash             -- content hash of the full artifact
  language_version  : String           -- Igniter-Lang version
  grammar_version   : String
  axiom_descriptor_ref: Option[String] -- AxiomDescriptor version ref

  -- Semantic content
  semantic_ir       : SemanticIR
  contracts         : Collection[ContractIR]
  classified_ast    : ClassifiedProgram  -- for inspection and audit

  -- Requirements (what RuntimeMachine must provide)
  temporal_requirements  : TemporalRequirements
  lifecycle_requirements : LifecycleRequirements
  capability_requirements: CapabilityRequirements
  effect_declarations    : Collection[EffectDecl]
  ffi_requirements       : Collection[FFIRequirement]
  required_tbackend_caps : TBackendCaps  -- minimum TBackend capabilities

  -- Projection and window metadata
  projection_descriptors : Collection[ProjectionDescriptor]
  boundary_descriptors   : Collection[BoundaryDescriptor]

  -- Diagnostics
  diagnostics       : Collection[CompileDiagnostic]
  warnings          : Collection[CompileWarning]

  -- Artifact format
  format            : ArtifactFormat
  compiled_at       : Timestamp
}

ArtifactFormat = :igapp_dir | :igc_json | :igc_pack | :native_bin | :container

CompileDiagnostic = Record {
  severity  : :error | :warning | :info
  code      : String
  message   : String
  span      : Option[Span]
  node_id   : Option[NodeId]
}
```

### Artifact Identity and Hashing

```text
program_id   = hash_content(SemanticIR canonical serialisation)
source_hash  = hash_content(raw source bytes)
artifact_hash = hash_content(
  program_id
  ++ language_version
  ++ grammar_version
  ++ axiom_descriptor_ref
  ++ hash_content(contracts ordered by contract_id)
  ++ hash_content(classified_ast)
)
```

**[D]** `artifact_hash` is the **content-addressed identity** of the
compiled artifact. Two compilations of the same source under the same
language version and grammar produce the same `artifact_hash`. This makes
`CompiledProgram` a reproducibility witness at the compilation boundary.

**[D]** `program_id` depends only on `SemanticIR`. Two programs with
different source representations but equivalent semantics may produce the
same `program_id` (semantic equivalence). `artifact_hash` includes source
and grammar — it is more specific.

---

## RuntimeMachine Load Contract

The `load` step (PROP-011 §Step 2) consumes a `CompiledProgram`:

```text
RuntimeMachine.load(program: CompiledProgram) ->
  -- verify requirements
  check: program.required_tbackend_caps ⊆ backend.capabilities
  check: program.temporal_requirements.min_consistency ≤ backend.consistency
  check: program.capability_requirements.required_caps ⊆ runtime.granted_caps
  check: program.fragment_class ∈ runtime.permitted_fragments

  -- emit descriptor observations
  for each contract C in program.contracts:
    Obs[:descriptor_observation, ContractDescriptor {
      contract_id:    C.contract_id
      name:           C.name
      fragment_class: C.fragment_class
      escape_set:     C.escape_set
      type_signature: C.type_signature
      lifecycle:      C.lifecycle
      artifact_hash:  program.artifact_hash
    }]

  -- emit classified ast
  Obs[:platform_observation, ClassifiedAST {
    program_id:   program.program_id
    artifact_hash: program.artifact_hash
    fragment_class: program.classified_ast.fragment_class
    contracts:    program.contracts.map(&:name)
    oof_count:    program.classified_ast.oof_nodes.count
  }]

  -- emit load receipt
  Obs[:platform_observation, LoadReceipt {
    program_id:       program.program_id
    artifact_hash:    program.artifact_hash
    contracts_loaded: program.contracts.count
    status:           :loaded | :partial | :rejected
  }]
```

**[D]** If any requirement check fails, `load` emits a `failure_observation`
with `reason_code: constraint.load_requirement_unmet` and returns
`status: :rejected`. No contracts are loaded.

**[D]** `ContractDescriptor` carries `artifact_hash` — this links every
observation produced during evaluation back to the exact compiled artifact.
This makes the artifact a provenance anchor in the observation chain.

---

## Deployment Modes

### dev mode

```text
DeploymentMode = :dev

Flow:
  compiler + runtime in same process
  hot compile: source change -> recompile -> reload (new program_id)
  rich diagnostics emitted as Obs[:platform_observation]
  TBackend: :memory or :file
  verification: run at every reload
  golden fixtures: executed as conformance tests
```

**[D]** Hot reload produces a new `program_id` and `artifact_hash`. The
RuntimeMachine must treat a reloaded program as a new load — not an in-place
update. This avoids silent semantic drift.

### server mode

```text
DeploymentMode = :server

Flow:
  compile separately -> artifact (.igc.json or .igc.pack)
  runtime loads artifact from file, registry, or container
  artifact is verified: artifact_hash checked against registry or signing key
  TBackend: :ledger | :redis_like | :remote
  verification: run at startup; re-run on TBackend swap
```

**[D]** Server mode requires **artifact signing** or registry hash
verification before `load`. An artifact whose `artifact_hash` does not
match the registry entry produces `status: :rejected` with
`reason_code: constraint.artifact_integrity_failed`.

### embedded mode

```text
DeploymentMode = :embedded

Flow:
  host app (Ruby/Rails) embeds RuntimeMachine via igniter-lang-runtime adapter
  artifact loaded from disk or registry at host startup
  host APIs exposed through contractable FFI (see below)
  TBackend: :redis_like | :ledger (configured at runtime)
  session lifecycle managed by host app request/job lifecycle

Example:
  Rails app
    -> Igniter::Runtime.load("app.igc.json")
    -> expose SparkCRM::OrderLookup as contractable FFI
    -> evaluate DispatchCandidate contract per request
    -> emit observations to configured TBackend
```

### native mode

```text
DeploymentMode = :native

Flow:
  SemanticIR -> native backend (LLVM / Cranelift) -> native binary
  binary links igniter-lang-runtime library
  embedded .igmeta section carries SemanticIR + artifact_hash
  native code calls runtime library for:
    TBackend.read / TBackend.append
    observation emission
    capability checks
    checkpoint / resume
    temporal lifecycle
  TBackend configured via environment or embedded config
```

**[D]** Native mode does not replace RuntimeMachine semantics. Native
code accelerates pure compute nodes (projections, filters, scoring) while
the runtime library owns time, evidence, effects, lifecycle, and
compatibility. The `.igmeta` section ensures the artifact remains
auditable even in binary form.

**[D]** Native mode is a **later backend**. First practical artifact:
`.igapp/` directory (dev) or `.igc.json` (server/embedded).

---

## Artifact Formats

| Format | Description | Use case |
|--------|-------------|----------|
| `.igapp/` | Directory bundle; human-readable JSON files | dev, golden fixtures, agent inspection |
| `.igc.json` | Canonical portable JSON bundle | server, embedded, CI |
| `.igc.pack` | Compact binary; same structure as `.igc.json` | production, mobile, edge |
| `native binary` | OS executable with `.igmeta` section | compute-intensive, CLI tools |
| `container` | OCI image: runtime + artifact + TBackend config | cloud deployment |

**`.igapp/` directory structure:**

```text
app.igapp/
  manifest.json        -- program_id, artifact_hash, language_version, format
  semantic_ir.json     -- SemanticIR canonical
  contracts/
    <contract_id>.json -- one ContractIR per file
  classified_ast.json  -- ClassifiedProgram
  requirements.json    -- temporal + lifecycle + capability + ffi
  diagnostics.json     -- compile diagnostics and warnings
  projections.json     -- ProjectionDescriptors
  boundaries.json      -- BoundaryDescriptors
```

**[D]** `.igapp/` is diffable by design: each contract is its own file.
A CI system can diff `contracts/` to detect semantic changes across commits.
An agent can inspect individual contracts without loading the full artifact.

---

## Contractable FFI

External host calls enter through typed contractable boundaries.

```text
FFIRequirement = Record {
  ffi_id      : String
  host_lang   : :ruby | :rust | :python | :js | :wasm | :native
  host_ref    : String               -- fully qualified host function/class ref
  input_ports : Collection[Port]
  output_ports: Collection[Port]
  effects     : Collection[EffectKind]
  capabilities: Collection[CapabilityName]
  lifecycle   : LifecycleClass
  failures    : Collection[FailureKind]
  audit       : Bool
}
```

**DSL form (informative; not final syntax):**

```text
-- Read-only FFI (ESCAPE)
external ruby SparkCRM::OrderLookup do
  input  :order_id, OrderId
  output :order,    OrderSnapshot
  effects none
  lifecycle :session
  failures :not_found, :permission_denied, :timeout
end

-- Write FFI (ESCAPE + capability + receipt)
external ruby SparkCRM::AssignTechnician do
  input  :order_id,       OrderId
  input  :technician_id,  TechnicianId
  output :assignment_receipt, AssignmentReceipt
  effects :write
  capability :dispatch_assign
  lifecycle :durable
  audit true
  failures :conflict, :permission_denied, :timeout
end
```

**Call discipline:**

```text
call FFI(SparkCRM::OrderLookup, { order_id: x })
  1. emit Obs[:intent_observation, FFICallPlan]    (lifecycle: :session)
  2. capability check: :dispatch_assign ∈ granted_caps
  3. host call: SparkCRM::OrderLookup.call(order_id: x)
  4a. success: emit Obs[:receipt_observation, AssignmentReceipt]  (lifecycle: :durable)
  4b. failure: emit Obs[:failure_observation, FailureKind]         (lifecycle: :session)
  5. return typed result or failure to calling contract
```

**Fragment classification:**

| FFI type | Class | Condition |
|----------|-------|-----------|
| Pure deterministic adapter | CORE candidate | No external state; declared types |
| Read external state | ESCAPE | External state may change |
| Write external world | ESCAPE + capability + receipt | `:write` effect declared |
| Ambient time / network / random | OOF | Not declared as FFI; violates Law 6 |
| Undeclared effects | OOF | Effects not in `FFIRequirement.effects` |

**[D]** The outside world is not trusted by default. An FFI call becomes
usable when wrapped with types, capabilities, lifecycle, receipts, failure
kinds, and runtime evidence. An undeclared FFI call is OOF.

**[D]** `audit: true` means the FFI call's `receipt_observation` has
`lifecycle: :audit` — the receipt is preserved long-term as an action
rights record. Required for any FFI that mutates durable business state.

---

## Toolchain Component Map

```text
igniter-lang-compiler
  parser           : source -> ParsedProgram
  classifier       : ParsedProgram -> ClassifiedProgram  (Pass 0)
  typechecker      : ClassifiedProgram -> TypedProgram   (Pass 1)
  ir_builder       : TypedProgram -> SemanticIR
  artifact_emitter : SemanticIR -> CompiledProgram (+ ArtifactFormat)

igniter-lang-runtime
  loader           : CompiledProgram -> LoadReceipt (PROP-011 load step)
  evaluator        : EvaluationRequest -> EvaluationReceipt
  lifecycle_manager: flush, checkpoint, compact
  tbackend_adapter : TBackend[T] interface

igniter-lang-ffi-ruby
  ffi_host         : FFIRequirement + Ruby class -> contractable adapter
  capability_gate  : checks required_caps at call time
  receipt_emitter  : emits receipt_observation after successful host call

igniter-lang-stdlib
  core contracts   : arithmetic, compare, hash, parse (PROP-004b Tier 1)
  temporal         : TemporalCtx, ProjectionHorizon, TemporalWindow
  lifecycle        : LifecycleClass declarations

igniter-lang-devkit
  fixture_runner   : executes golden fixtures (PROP-011 / golden-fixtures-v0)
  artifact_validator: checks artifact_hash, requirements against TBackend caps
  diagnostics      : CompileDiagnostic formatting and reporting
```

---

## CompiledProgram as Observation

A `CompiledProgram` may itself be registered as a `descriptor_observation`
in a TBackend at publish time:

```text
Obs[:descriptor_observation, ArtifactDescriptor] where ArtifactDescriptor = Record {
  program_id    : String
  artifact_hash : Hash
  language_version: String
  format        : ArtifactFormat
  location      : String    -- :igapp path, registry URI, container ref
}
with:
  subject  : "artifact://<program_id>"
  lifecycle : :durable
  links    : [{ rel: :materializes, ref: "source://<source_hash>" }]
```

This makes the artifact itself traceable in the observation chain. A
Runtime Machine that loads an artifact can verify:
- `artifact_hash` matches the published `ArtifactDescriptor`
- `axiom_descriptor_ref` is compatible with the current AxiomDescriptor
- `program_id` has not been superseded by a newer artifact for the same
  source

---

## Fragment Classification

| Construct | Class | Condition |
|-----------|-------|-----------|
| `CompiledProgram` production | CORE | Deterministic; content-addressed |
| Load with satisfied requirements | CORE | All capability/backend checks pass |
| Load with unsatisfied requirements | → `status: :rejected` | Requirements not met |
| FFI read | ESCAPE | External state |
| FFI write | ESCAPE + capability | `:write` declared |
| Undeclared FFI | OOF | No FFIRequirement entry |
| Hot reload (dev mode) | CORE | New program_id; no in-place mutation |
| Native backend kernel | CORE (pure compute) | No TBackend/FFI calls in kernel |
| Ambient FFI (no declaration) | OOF | Outside world is not trusted |

---

## Open Questions

[Q] Should `CompiledProgram` be loadable incrementally (contract by
contract) or only as a whole unit? Recommendation: whole unit in v0 for
simplicity. Incremental load is an ESCAPE extension (requires dependency
graph partitioning).

[Q] Should `artifact_hash` include diagnostics and warnings in its
canonical computation? Recommendation: no — diagnostics are advisory. The
hash covers semantic content only: `SemanticIR`, contracts, requirements,
and metadata. This allows re-emission of diagnostics without changing the
artifact identity.

[Q] Should `.igapp/` format be the primary format for golden fixtures, or
should fixtures use `.igc.json`? Recommendation: `.igapp/` for golden
fixtures (human-readable, diffable, agent-friendly).

[Q] Should `FFIRequirement.host_lang: :wasm` be CORE or ESCAPE?
Recommendation: CORE candidate if the WASM module is deterministic and
has no ambient IO. ESCAPE if it accesses external state. OOF if undeclared.

---

## Rejected Paths

[X] Compiler as the first thing to implement. Compilation produces a
`CompiledProgram`; the first executable proof may be a hand-authored fixture
that tests RuntimeMachine semantics without source compilation.

[X] Bytecode or native binary as the primary artifact. The primary artifact
is a semantic bundle (`.igapp/`, `.igc.json`). Native binary is a later
optimisation backend.

[X] In-place hot reload (mutating loaded contracts). Hot reload produces
a new `program_id`. The old program is superseded — never mutated.

[X] Undeclared FFI. All host calls must enter through `FFIRequirement`.
An undeclared call is OOF — it violates observability, capability, and
lifecycle contracts.

[X] Self-hosting as an early goal. Self-hosting requires stable SemanticIR
and enough stdlib. It is a Stage 3 concern, not Stage 0.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-012
Status: done

[D] Decisions:
- Four compiler stages: ParsedProgram -> ClassifiedProgram -> TypedProgram
  -> SemanticIR -> CompiledProgram.
- SemanticIR is the toolchain boundary. All backends share this frontend.
- CompiledProgram carries: program_id (hash of SemanticIR), artifact_hash
  (hash over program_id + language + grammar + axiom + contracts + AST),
  requirements, diagnostics, projection/boundary descriptors, format.
- artifact_hash excludes diagnostics (advisory); includes semantic content.
- Load contract: checks requirements -> emits descriptor_obs per contract ->
  ClassifiedAST obs -> LoadReceipt. Fails fast on unmet requirements.
- ContractDescriptor carries artifact_hash: links evaluations back to the
  exact compiled artifact (provenance anchor).
- Four deployment modes: dev, server, embedded, native.
  First practical format: .igapp/ (dir) and .igc.json.
  Native binary is a later backend; never replaces RuntimeMachine semantics.
- .igapp/ is diffable by design: one file per contract; CI-friendly.
- Contractable FFI: FFIRequirement types + call discipline
  (intent_obs -> capability check -> host call -> receipt/failure obs).
  Undeclared FFI is OOF. audit: true -> :audit lifecycle receipt.
- CompiledProgram publishable as descriptor_observation (ArtifactDescriptor).
- Hot reload: new program_id; no in-place mutation.
- DependencyGraph must be DAG; cycles are compile errors.
- program.fragment_class = max(node fragment classes): OOF > ESCAPE > CORE.

[R] Recommendations:
- First implementation target: hand-authored .igapp/ fixture for the Add
  contract from golden-fixtures-v0 (FIXTURE-003..005). This tests the
  RuntimeMachine load step without requiring a real parser.
- igniter-lang-devkit should include an artifact_validator that checks
  artifact_hash, required_tbackend_caps, and fragment_class compatibility
  before load.
- The .igapp/ format manifest.json should be the canonical source for
  program_id and artifact_hash in all tooling.
- ArtifactDescriptor should be emitted to TBackend at publish time in
  server and embedded modes.

[S] Signals:
- The four-stage pipeline (Parse -> Classify -> Type -> IR -> Artifact)
  maps cleanly to the existing Igniter compiler architecture:
  graph_compiler.rb (classify + type) -> compiled_graph.rb (artifact).
  The gap is IR and artifact serialisation.
- .igapp/ as a diffable directory is a powerful design: it enables
  semantic change review in git (what changed in the contracts?),
  agent inspection without loading, and golden fixture comparison.
- FFI call discipline (intent -> gate -> call -> receipt) is already
  partially present in Igniter's materializer gate + approval receipts.
  PROP-012 formalises it as a language-level contractable boundary.

[Q] Open Questions:
- Incremental load: whole unit or contract-by-contract?
- artifact_hash: include diagnostics or semantic content only?
- .igapp/ vs .igc.json for golden fixtures?
- FFI WASM: CORE or ESCAPE?

[X] Rejected:
- Compiler as the first thing to implement.
- Bytecode/native binary as primary artifact.
- In-place hot reload.
- Undeclared FFI.
- Self-hosting as early goal.

[Next] Proposed next tracks:
- Implementation: hand-authored .igapp/ fixture for Add contract (devkit)
- Implementation: .igc.json canonical format schema (JSON Schema or proto)
- Research Agent: igniter-lang-stdlib v0 (core contracts, temporal primitives)
- Bridge: igniter-lang-ffi-ruby adapter using existing Igniter platform
```
