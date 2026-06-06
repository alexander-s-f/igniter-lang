# Compilation and Deployment

Status: meta thesis
Date: 2026-05-05
Author: `[Architect Supervisor / Codex]`

## Claim

Igniter-Lang should not start by implementing a compiler. It should first
define what compilation produces.

The compiler result is not merely bytecode, Ruby code, or a native executable.
The primary result is a **semantic deployment artifact** that a Runtime Machine
can load, verify, observe, checkpoint, and resume.

```text
Igniter-Lang source
  -> parse
  -> classify CORE / ESCAPE / OOF
  -> typecheck
  -> build Semantic IR
  -> emit CompiledProgram artifact
  -> RuntimeMachine.load(...)
```

[D] The compiler does not execute application logic, call TBackend, or perform
host effects. It produces a loadable meaning artifact plus diagnostics and
requirements.

## Compilation Result

The expected compilation result is a typed semantic bundle:

```text
CompiledProgram = {
  program_id
  language_version
  source_hash
  grammar_version
  axiom_descriptor_ref
  contracts
  classified_ast
  type_report
  dependency_graph
  temporal_requirements
  lifecycle_requirements
  capability_requirements
  effect_declarations
  projection_descriptors
  boundary_descriptors
  ffi_requirements
  required_tbackend_caps
  diagnostics
  artifact_hash
}
```

RuntimeMachine consumes it through `load`:

```text
load(CompiledProgram)
  -> descriptor_observations
  -> ClassifiedAST observation
  -> LoadReceipt
```

## Compiler Stages

Compilation should expose intermediate products.

```text
ParsedProgram
  raw AST + source spans

ClassifiedProgram
  AST + CORE / ESCAPE / OOF markers
  rejects ambient time, hidden IO, undeclared effects

TypedProgram
  structural types
  Projection[T, horizon]
  Obs[kind, T]
  lifecycle classes
  capability/effect types

LoadableProgram
  stable artifact for RuntimeMachine
  dependency graph
  descriptors
  hashes
  requirements
  evaluation targets
```

[D] The **Semantic IR** between `TypedProgram` and `LoadableProgram` is the
center of the toolchain. Interpreters, bundle loaders, native backends, and
future self-hosting should all share this frontend.

## Artifact Forms

Early artifact forms should favor transparency.

```text
.igapp/        directory bundle for development; diffable and agent-friendly
.igc.json      canonical portable bundle
.igc.pack      compact binary format later
native binary  later; linked runtime + embedded semantic metadata
container      production package: runtime + artifact + config
```

[R] The first practical artifact should be `.igapp/` or canonical JSON, not a
native binary. Readability and golden fixtures matter more than performance at
the first stage.

## Deployment Modes

```text
dev mode
  compiler + runtime together
  hot compile/load
  rich diagnostics

server mode
  compile separately
  runtime loads signed/hashed artifact
  TBackend configured at runtime

embedded mode
  host app embeds RuntimeMachine
  artifact loaded from disk/registry
  host APIs exposed through contractable FFI

native mode
  artifact lowered to native executable
  executable links RuntimeMachine runtime library
  semantic metadata embedded
```

For Ruby/Rails/Spark CRM, embedded mode is essential:

```text
Rails app
  -> Igniter-Lang runtime adapter
  -> load compiled artifact
  -> expose Ruby services through contractable FFI
```

## Native / LLVM Backend

Native compilation should be kept as a backend option, not the first path.

```text
Igniter-Lang Frontend
  -> Semantic IR
     -> Bundle Backend       -- first
     -> Interpreter/VM       -- first executable proof
     -> Native Backend       -- later: LLVM / Cranelift / similar
```

A native artifact would look like:

```text
native binary
  + linked Igniter runtime library
  + embedded app.igmeta section
  + external TBackend / FFI configuration
```

Native code is a good fit for:

- pure compute nodes
- type-safe transforms
- projection calculations
- filters and aggregations
- deterministic scoring/ranking

Native code should still call runtime services for:

- TBackend reads/writes
- observation emission
- capability checks
- FFI calls
- checkpoint/resume
- temporal lifecycle and retention

[D] LLVM or any native backend does not replace RuntimeMachine semantics. It
accelerates selected kernels while the runtime still owns time, evidence,
effects, lifecycle, and compatibility.

## Self-Hosting Path

The semantic-bundle model is not immediately self-hosting. That is acceptable.

A possible self-hosting ladder:

```text
Stage 0: Ruby/Rust compiler compiles Igniter-Lang
Stage 1: compiler subset written in Igniter-Lang
Stage 2: Stage 0 compiles Stage 1
Stage 3: Stage 1 compiles itself
```

Self-hosting requires more than LLVM:

- general-purpose compiler data structures
- text/file parsing capabilities
- deterministic build model
- host FFI for IO
- stable Semantic IR
- enough stdlib to express the compiler

[R] Do not optimize for self-hosting before the Semantic IR and RuntimeMachine
contract are stable.

## Contractable FFI

External host calls must enter the language through contractable boundaries.

```text
Igniter-Lang contract
  -> ExternalCapability contract
  -> host adapter
  -> result observation | receipt observation | failure observation
```

Example shape:

```text
external ruby SparkCRM::OrderLookup do
  input  :order_id, OrderId
  output :order, OrderSnapshot
  effects none
  lifecycle :session
  failure :not_found, :permission_denied, :timeout
end
```

Mutation shape:

```text
external ruby SparkCRM::AssignTechnician do
  input :order_id
  input :technician_id
  output :assignment_receipt

  effect :write
  capability :dispatch_assign
  audit true
end
```

Call discipline:

```text
call external
  -> intent_observation
  -> capability check
  -> host call
  -> receipt_observation | failure_observation
  -> links to runtime/session/artifact
```

Classification:

```text
pure declared deterministic adapter -> CORE candidate
read external state                 -> ESCAPE
write external world                -> ESCAPE + capability + receipt
ambient time/network/random         -> OOF unless explicitly declared
```

[D] The outside world is not trusted by default. It becomes usable when wrapped
as contractable FFI with types, capabilities, lifecycle, receipts, failures,
and runtime evidence.

## Toolchain Components

Logical components may later become separate packages:

```text
igniter-lang-compiler
  parser + classifier + typechecker + artifact builder

igniter-lang-runtime
  RuntimeMachine + evaluator + TBackend interface

igniter-lang-ffi-ruby
  Ruby host adapter / bridge

igniter-lang-stdlib
  core contracts, types, temporal primitives

igniter-lang-devkit
  fixtures, validators, diagnostics, agent tooling
```

## Next Research Need

The next formal proposal should define:

- `CompiledProgram`
- compiler stages
- Semantic IR
- artifact identity and hashing
- RuntimeMachine load contract
- deployment modes
- host FFI as contractable boundary
- backend targets: bundle, interpreter, native

Suggested name:

```text
PROP-012: Compilation Artifact and Deployment Model v0
```

Until then, agents should avoid implementing a real parser/compiler or claiming
a native backend shape. The executable proof may stay hand-authored because it
tests RuntimeMachine semantics, not source-language compilation.
