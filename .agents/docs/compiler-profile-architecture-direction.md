# Compiler Profile Architecture Direction

Status: direction / post-POC target
Owner: [Architect Supervisor / Codex]
Date: 2026-05-10
Source: `docs/inbox/profile-baseline-pack-pattern-analysis.md`

---

## Summary

The current igniter-lang compiler remains the **POC / proof compiler**. Its job is
to finish the current semantic proof chain, expose the real pass boundaries, and
produce executable evidence.

The next compiler architecture should be a **profile-assembled compiler** based
on the Profile / Baseline / Pack pattern proven in `packages/igniter-contracts`
and `packages/igniter-extensions`.

```text
Current compiler = proof compiler / semantic wind tunnel
Future compiler  = profile-assembled compiler platform
```

This document is a direction record, not an implementation authorization.

---

## Direction

Adopt the Profile–Baseline–Pack assembly pattern as the target architecture for
the next compiler generation.

The pattern:

```text
Kernel -> install Packs -> finalize -> frozen Profile -> Environment
```

maps to igniter-lang as:

```text
CompilerKernel
  -> CoreLanguagePack
  -> TemporalPack
  -> StreamPack
  -> OLAPPack
  -> InvariantPack
  -> ContractModifiersPack
  -> AssumptionsPack
  -> finalize
  -> CompilerProfile
  -> CompilerEnvironment
```

The resulting `CompilerProfile` is a content-addressed compiler identity. It
declares which language capabilities are installed and which pass handlers,
fragment classes, OOF codes, and artifact emitters are present.

---

## Why This Direction Fits

### 1. It turns language growth into component assembly

Each PROP can become a pack that declares what it adds:

- parser rules
- classifier rules
- TypeChecker rules
- SemanticIR handlers
- assembler handlers
- OOF descriptors
- fragment classes
- capabilities
- dependencies on other packs

This replaces "edit every monolithic pass by hand" with "install a named
language-surface pack and validate completeness".

### 2. It makes compiler profiles verifiable

The profile fingerprint can become a first-class `.igapp` compatibility field:

```text
compiler_profile_id: sha256(profile surface)
```

That lets RuntimeMachine or tooling answer:

```text
Was this artifact compiled with TemporalPack?
Was AssumptionsPack installed?
Was this SemanticIR produced by a profile compatible with this runtime?
```

### 3. It supports replaceable implementations

A pack name can describe capability, while the concrete pack implementation can
vary:

```text
TemporalPack::ProofLocal
TemporalPack::Memory
TemporalPack::LedgerBacked
TemporalPack::AuditedProduction
```

This is important for Igniter because the same language surface often needs
different implementations in proof, local app, production, and audited
production contexts.

### 4. It matches the agent workflow

Agent cards can assign a bounded pack:

```text
Implement AssumptionsPack manifest + proof fixtures.
Do not touch TemporalPack.
Do not alter CoreLanguagePack.
```

That gives agents clearer ownership, smaller blast radius, and better
parallelization.

---

## Current POC Boundary

Do not rewrite the current compiler into packs yet.

The current compiler should first reach a logical POC close:

1. Gate 3 / Phase 1 durable audit chain reaches bounded closure.
2. PROP-032 assumptions receives the required governance gate and proof path.
3. Current monolithic passes produce enough golden evidence to reveal real pass
   boundaries.
4. A "lessons learned from the POC compiler" report summarizes where the pack
   boundaries should be.

Only after that should a migration plan authorize code movement.

---

## Target Components

| Component | Meaning |
|-----------|---------|
| `CompilerKernel` | Mutable assembly accumulator; accepts pack installation |
| `CompilerPack` | Named language capability unit with manifest + install hook |
| `CompilerManifest` | Declares provided pass slots, requirements, capabilities |
| `CoreLanguagePack` | Baseline pack for CORE contracts and basic expressions |
| `CompilerProfile` | Frozen, fingerprinted snapshot of installed compiler surface |
| `CompilerEnvironment` | Facade over a profile: compile, emit, assemble |
| `PassRegistry` | Keyed registry for handlers |
| `OrderedPassRegistry` | Ordered registry for classifier/typechecker pipelines |
| `OOFRegistry` | Registry of OOF descriptors and ownership |
| `FragmentClassRegistry` | Registry of fragment classes and precedence rules |

---

## Open Design Questions

### Q1 — Ordered rule precedence

The current contracts `OrderedRegistry` is insertion-order only. The compiler
needs explicit precedence for rules such as:

```text
observed + temporal -> temporal
```

Question:

```text
Is canonical pack install order enough, or do classifier/type rules need
before:/after: constraints?
```

### Q2 — `.igapp` compiler profile identity

Question:

```text
Should `compiler_profile_id` become mandatory in `.igapp` manifests once
CompilerProfile exists?
```

### Q3 — Greenfield packs before full migration

Question:

```text
Can new surfaces such as AssumptionsPack be designed as packs before
CoreLanguagePack is extracted from the monolithic compiler?
```

Initial direction: yes for design; code implementation requires a separate
migration or adapter plan.

### Q4 — Multiple implementations per capability

Question:

```text
How does a profile distinguish the capability name from the implementation
class, especially for proof-local vs production variants?
```

Initial direction: the manifest needs both:

- stable capability name
- implementation identity / provider id

---

## Non-Goals

This direction does not authorize:

- rewriting parser/classifier/typechecker/SemanticIR now
- replacing the current proof compiler mid-Gate-3 work
- implementing PROP-032 as a pack before its implementation gate
- changing `.igapp` manifest format now
- binding Ledger, Phase 2, BiHistory, stream/OLAP production executor, or
  production cache

---

## Recommended Next Research Slice

Run a no-code proof/report:

```text
compiler-pack-boundary-report-v0
```

Goal:

```text
Prove a candidate pack decomposition by mapping existing compiler code,
PROPs, golden fixtures, OOF codes, and pass responsibilities into pack
boundaries.
```

The report should produce a package/pack map, migration risk table, and
recommended order without writing implementation code.
