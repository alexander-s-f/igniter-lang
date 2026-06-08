# POC MVP Live Touch Scope Decision v0

Card: S3-R157-C1-A
Agent: [Igniter-Lang Supervisor]
Role: igniter-lang-supervisor
Route: UPDATE
Track: poc-mvp-live-touch-scope-decision-v0
Depends on: S3-R156-C2-P1
Status: authorized-bounded-local-poc-implementation-proof
Date: 2026-05-23

---

## Decision

Authorize a bounded local POC/MVP implementation/proof route.

The next route may create a tiny local-only POC lab that lets the user run and
inspect a small end-to-end Igniter-Lang experience: source contracts, compile
results, `.igapp` outputs, and proof-local runtime/evaluation traces.

This is not a public demo, not release readiness, not production runtime, not
Spark integration, and not a language-semantics route.

---

## Evidence Read

- `igniter-lang/docs/tracks/compiler-profile-internal-carrier-docs-spec-sync-v0.md`
- `igniter-lang/docs/tracks/stage3-round156-status-curation-v0.md`
- `igniter-lang/docs/current-status.md`
- `igniter-lang/docs/spec/README.md`
- `igniter-lang/docs/dev/README.md` — requested path is absent; `igniter-lang/docs/dev/`
  exists with topic files but no README.
- `igniter-lang/experiments/pressure-specimens/igniter-swarm-rescue-orchestrator-v2.ig`
- `igniter-lang/experiments/pressure-specimens/igniter-swarm-rescue-orchestrator-v1.ig`
- existing compile/runtime surfaces:
  `IgniterLang.compile`, `igniter-lang/bin/igniter-lang compile`, and
  `IgniterLang::RuntimeSmoke`.

---

## Route Choice

Selected route:

```text
bounded local POC/MVP implementation/proof
```

Reason:

- Existing compiler surfaces are sufficient for a local hands-on POC:
  parser, classifier, TypeChecker, SemanticIR emitter, assembler, CLI/API
  compile path, `.igapp` output, and proof-backed runtime smoke already exist.
- The accepted carrier lane is paused and does not need to be widened for this
  POC.
- A local experiment directory can show a coherent "feelable" loop without
  changing public API/CLI, specs, proposals, runtime production behavior, or
  Spark surfaces.

Not selected:

- design/proof map first: unnecessary; the local POC can be kept inside a tight
  experiment write scope and use only existing compiler/runtime surfaces;
- hold pending more compiler-mainline stabilization: unnecessary for local-only
  proof-lab scope;
- redirect to docs/spec sync: R156 already completed the relevant docs/status
  sync;
- rescue-orchestrator specimen as-is: not selected because v1/v2 include
  advanced pressure syntax such as service contracts, progression, receipts,
  include/module composition, assumptions/constraints, and effect surfaces that
  are not appropriate for the first runnable POC without new semantics.

---

## POC/MVP Shape

Chosen domain:

```text
synthetic order/channel economics toy model
```

This domain is inspired by Spark Orders Analytics pressure but must be fully
synthetic. It must not use Spark data, Spark class names, Spark raw ids, Spark
fixtures, or Spark production vocabulary as public Igniter-Lang vocabulary.

Target source file count:

```text
4 .ig modules
```

Allowed source files:

```text
igniter-lang/experiments/poc_mvp_live_touch_v0/src/channel_signal_score.ig
igniter-lang/experiments/poc_mvp_live_touch_v0/src/order_readiness_gate.ig
igniter-lang/experiments/poc_mvp_live_touch_v0/src/economics_shadow_margin.ig
igniter-lang/experiments/poc_mvp_live_touch_v0/src/fulfillment_attention_trace.ig
```

The files are compiled independently as separate compile units. This route does
not authorize multi-file module resolution, `include`, package loading,
generated indexes, or loader/report behavior.

---

## What "Live Touch" Means

Live touch means:

- the user can run one local proof command;
- the command compiles the small `.ig` files through existing Igniter-Lang
  compiler surfaces;
- each successful compile produces an `.igapp` output under the POC `out/`
  directory;
- the proof captures a compact runtime/evaluation trace using existing
  proof-backed runtime smoke where compatible;
- the proof writes a readable local summary with source file, contract name,
  compile status, output path, sample input, and observed output/trace.

Live touch does not mean:

- production runtime;
- public demo/release claim;
- public API/CLI widening;
- Spark integration;
- manager-facing dashboard or narrative;
- new parser/classifier/typechecker/SemanticIR/assembler behavior;
- module loader, report carrier, CompatibilityReport, manifest migration, or
  artifact identity work.

---

## Exact Next Allowed Boundary

Open exactly one next route:

```text
Card: S3-R157-C2-I
Agent: [Igniter-Lang Compiler/Grammar Expert]
Role: compiler-grammar-expert
Track: poc-mvp-live-touch-v0
Route: UPDATE
Mode: bounded local implementation/proof
```

Goal:

Create and prove a tiny local POC/MVP lab under
`igniter-lang/experiments/poc_mvp_live_touch_v0/**` using 4 small independent
`.ig` modules, existing compile surfaces, and proof-local runtime/evaluation
trace output.

Allowed write scope:

```text
igniter-lang/experiments/poc_mvp_live_touch_v0/**
igniter-lang/docs/tracks/poc-mvp-live-touch-v0.md
```

No other files may be edited by S3-R157-C2-I.

---

## Allowed Commands

The implementation/proof card may create and run:

```text
ruby -c igniter-lang/experiments/poc_mvp_live_touch_v0/poc_mvp_live_touch_v0.rb
ruby igniter-lang/experiments/poc_mvp_live_touch_v0/poc_mvp_live_touch_v0.rb
```

The proof runner may call existing APIs/commands internally:

```text
IgniterLang.compile(...)
IgniterLang::RuntimeSmoke.callback(...)
ruby igniter-lang/bin/igniter-lang compile SOURCE --out OUT.igapp
```

It must not add new CLI flags, new public API methods, new compiler stages, new
runtime entrypoints, or new production execution commands.

---

## Expected Outputs / Artifacts

Allowed outputs, all under the POC directory:

```text
igniter-lang/experiments/poc_mvp_live_touch_v0/src/*.ig
igniter-lang/experiments/poc_mvp_live_touch_v0/out/*.igapp/**
igniter-lang/experiments/poc_mvp_live_touch_v0/out/poc_mvp_live_touch_summary.json
igniter-lang/experiments/poc_mvp_live_touch_v0/out/runtime_trace.json
igniter-lang/experiments/poc_mvp_live_touch_v0/out/compile_transcript.json
igniter-lang/experiments/poc_mvp_live_touch_v0/README.md
igniter-lang/experiments/poc_mvp_live_touch_v0/poc_mvp_live_touch_v0.rb
```

The route may write `.compilation_report.json` files only inside the POC `out/`
directory if a negative/blocked compile case is intentionally included. The
recommended first POC should prefer all-positive compile paths.

No output may be written outside `igniter-lang/experiments/poc_mvp_live_touch_v0/**`
except the track doc.

---

## Success Criteria

S3-R157-C2-I succeeds only if:

- 3-5 `.ig` source files exist; target is exactly 4;
- all `.ig` files compile through existing compiler surfaces;
- each source writes an `.igapp` under the POC `out/` directory;
- runtime/evaluation trace is real proof-local runtime smoke when compatible,
  and any unavailable trace is explicitly marked as proof-local blocked rather
  than silently simulated;
- the summary records source path, module/contract name, compile status,
  `.igapp` path, sample input, observed outputs, and trace/trust status;
- no Spark data, Spark fixtures, Spark class names, or Spark raw ids appear;
- no compiler/library files are edited;
- no public API/CLI widening occurs;
- no spec/proposal/canon mutation occurs;
- no production runtime, deployment, signing, cache, Ledger/TBackend,
  BiHistory, stream/OLAP, or demo behavior opens.

---

## Proof / Regression Matrix

S3-R157-C2-I must record PASS for:

| Command | Required result |
| --- | --- |
| `ruby -c igniter-lang/experiments/poc_mvp_live_touch_v0/poc_mvp_live_touch_v0.rb` | Syntax OK |
| `ruby igniter-lang/experiments/poc_mvp_live_touch_v0/poc_mvp_live_touch_v0.rb` | PASS |

The proof runner must assert:

- source file count is between 3 and 5, target 4;
- each source compiles successfully;
- all `.igapp` outputs are inside `experiments/poc_mvp_live_touch_v0/out/`;
- runtime/evaluation trace entries are present for each source, either trusted
  or explicitly blocked with reason;
- no public API/CLI additions were made;
- no root require was changed;
- parser/classifier/TypeChecker/SemanticIR/assembler files are unchanged by
  this route;
- no report/CompatibilityReport/manifest/sidecar/artifact-hash/golden output is
  produced outside the POC directory;
- no Spark tokens or forbidden production/demo tokens appear in source or
  output except inside an explicit negative-scan token list;
- current accepted Stage 3 closed surfaces remain closed.

Optional non-mutating checks:

```text
git status --short
```

may be recorded by the track, but the implementation proof should not rely on
git state for correctness because adjacent governance docs may be in flight.

---

## Explicit Answers

### Are Existing Compiler / Runtime Surfaces Sufficient For A Local POC?

Yes.

Existing compiler surfaces can compile small `.ig` modules and assemble `.igapp`
outputs. Existing `RuntimeSmoke` can provide proof-backed runtime/evaluation
trace for compatible compiled programs.

### Is Runtime Execution Real, Simulated, Or Proof-Local?

Runtime execution is real proof-local runtime smoke.

It uses the existing proof-backed runtime machine harness. It is not production
runtime, not deployment, not durable runtime, and not a public runtime
guarantee.

If a source is not compatible with `RuntimeSmoke`, the proof must mark that
trace as blocked with a reason. It must not fake a successful runtime trace.

### Are Modules / Files Compiled Independently Or As A Single Fixture?

Files are compiled independently as separate source modules.

This decision does not authorize multi-file module resolution, `include`,
package loading, `.iform` resolution, generated indexes, or loader behavior.

### Are Spec / Proposal / Canon Changes Required?

No.

This route uses existing accepted syntax and compiler surfaces. No spec,
proposal, canon, parser, classifier, TypeChecker, SemanticIR, assembler, or
runtime semantics may be changed.

### Does Demo-Shadow Become A Local POC Lane?

Only locally and narrowly.

This opens a local POC lane for hands-on inspection under an experiment
directory. Public demo-shadow remains held. No public demo, release claim,
manager-facing narrative, deployment, or production-facing scenario is opened.

### Is Portfolio Review Required Before Implementation?

No additional Portfolio review is required before S3-R157-C2-I if it stays
inside the exact local experiment boundary above.

Portfolio review is required before any widening beyond that boundary,
especially public demo/release, Spark fixture/spec pressure, report/artifact
carriers, runtime/production behavior, or CLI/API changes.

---

## Closed Surfaces

This decision does not authorize:

- production behavior;
- public demo or release claims;
- root require changes;
- classifier wiring or live classifier dispatch unrelated to the existing
  compile path;
- `contract_fragment_for` replacement;
- parser, TypeChecker, SemanticIR, assembler changes;
- public API/CLI widening;
- loader/report;
- CompatibilityReport;
- manifest, sidecar, artifact hash, or golden migration outside the named POC
  scope;
- PROP-036 or PROP-038 mutation;
- Spark access, Spark fixtures, Spark specs, or Spark integration;
- production runtime;
- Ledger/TBackend, BiHistory, stream/OLAP, cache, signing, deployment.

The only narrowly opened surface is a local experiment/proof directory:

```text
igniter-lang/experiments/poc_mvp_live_touch_v0/**
```

---

## Compact Summary

[D] Authorize bounded local POC/MVP implementation/proof.

[S] Build a tiny synthetic order/channel economics toy model with 4 independent
`.ig` modules, compile them with existing compiler surfaces, and capture local
proof-backed runtime/evaluation traces. This is local live touch only, not
public demo/release.

[T] Decision doc only. No code implemented by this card.

[R] Next route is exactly S3-R157-C2-I `poc-mvp-live-touch-v0`, bounded local
implementation/proof inside `igniter-lang/experiments/poc_mvp_live_touch_v0/**`.
