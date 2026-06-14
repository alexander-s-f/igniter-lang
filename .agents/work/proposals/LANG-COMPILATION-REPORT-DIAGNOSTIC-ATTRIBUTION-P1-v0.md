# LANG-COMPILATION-REPORT-DIAGNOSTIC-ATTRIBUTION-P1 v0

**Status:** CLOSED - implemented/proved (60/60)  
**Route:** LANG HYGIENE / MULTIFILE DIAGNOSTIC ATTRIBUTION  
**Date:** 2026-06-14  
**Authority:** compiler/reporting hygiene only; no semantic changes

## Goal

Fix the multifile report attribution bug where typecheck diagnostics were
enriched with the first contract in the merged compilation unit instead of the
actual contract that produced the diagnostic.

The bug was surfaced during `LAB-VECTOR-MATH-FIELD-ALIGNMENT-P1`: all Ruby
diagnostics appeared under `SimulateFrame/result` because the first contract in
the multifile universe was used as the fallback attribution contract.

## Findings

### Q1: Where did the wrong attribution happen?

`CompilationReport.enrich` used:

```ruby
contract_name = parsed.fetch("contracts", []).fetch(0, {}).fetch("name", nil)
```

That value was passed as the single fallback contract for every diagnostic.
In multifile runs, `MultifileResolver` merges all contracts into one synthetic
program, so `contracts[0]` is only the first contract in sorted source-unit
order. It is not the owner of every diagnostic.

### Q2: What fields already carried attribution evidence?

Raw report diagnostics carried `rule`, `message`, `node`, and `line`, but not
`contract` or source-unit path.

The missing evidence already existed one layer earlier:

```text
typed_program["contracts"][*]["type_errors"]
```

Each typed contract owns its own deduped `type_errors` before the emitter
flattens them into the compilation report.

### Q3: Are raw diagnostics missing contract/source data?

Raw diagnostics are missing explicit `contract`. That does not require a
TypeChecker semantic change because the typed-program contract partition
preserves ownership. Source-unit attribution remains a separate possible future
enhancement; P1 only fixes contract/node attribution.

### Q4: Can the fix be report-only?

Yes.

The patch is report/orchestrator only:

- `CompilationReport.enrich(report:, parsed:, typed: nil)` now accepts optional
  typed context.
- `CompilerOrchestrator` passes `typed: typed` when enriching reports.
- `CompilationReport` builds a queue keyed by
  `[rule, message, node, line]` from `typed["contracts"][*]["type_errors"]`.
- Report diagnostics are enriched in report order by shifting from that queue.
- If typed context is absent or a diagnostic has no match, behavior falls back
  to the old first-contract fallback.

No parser, classifier, TypeChecker, SemanticIR, assembler, runtime, or app
source behavior changes.

### Q5: Does deduplication preserve attribution?

Yes. TypeChecker deduplication remains per contract. The proof includes a
duplicate-node multifile case where two later contracts both emit diagnostics
for `node: "bad"`. The final report keeps:

```text
contract:LaterFailOne/node:bad
contract:LaterFailTwo/node:bad
```

### Q6: Does single-file output remain unchanged?

Yes. In single-file mode, old and new enrichment both attribute diagnostics to
the only contract.

### Q7: Rust parity?

Rust report parity was not changed in this card. P1 uses Ruby canon proof
evidence and keeps Rust as comparison context only.

## Implementation

Changed files:

- `lib/igniter_lang/compilation_report.rb`
- `lib/igniter_lang/compiler_orchestrator.rb`

`CompilationReport.enrich` now has this signature:

```ruby
def enrich(report:, parsed:, typed: nil)
```

The new helper methods are private module functions inside
`CompilationReport`:

- `diagnostic_contracts_for(diagnostics, typed)`
- `diagnostic_key(entry)`

The diagnostic key is intentionally narrow:

```text
rule + message + node + line
```

That matches the existing TypeChecker and SemanticIR diagnostic shapes and
does not add a new public diagnostic schema.

## Proof Runner

**Path:** `experiments/diagnostic_attribution_proof/verify_compilation_report_diagnostic_attribution_p1.rb`  
**Result:** 60/60 PASS

| Section | Checks | Scope |
|---|---:|---|
| A | 8 | Source guard |
| B | 10 | Minimal multifile reproduction |
| C | 6 | End-to-end compiler report |
| D | 6 | Raw diagnostics and typed context |
| E | 8 | Duplicate node and dedupe behavior |
| F | 5 | Multiple nodes in one later contract |
| G | 6 | Single-file regression |
| H | 5 | Explicit contract and fallback behavior |
| I | 6 | Closed surfaces |
| **Total** | **60** | |

## Acceptance

- Minimal multifile fixture documents old wrong attribution:
  `contract:FirstClean/node:bad`.
- Fixed report attributes later-contract diagnostics to:
  `contract:LaterFail/node:bad`.
- End-to-end `CompilerOrchestrator.compile_sources` produces the fixed report.
- Single-file attribution is unchanged.
- Duplicate node names across contracts stay contract-specific.
- No semantic/typechecking behavior changes.
- No app source edits.

## Closed Surfaces

- No TypeChecker semantic changes.
- No app source migration.
- No new OOF codes.
- No parser/classifier/emitter/assembler/runtime changes.
- No runtime or IO work.
- No Rust implementation in this card.

## Next Route

Optional future diagnostic work should be separate:

- source-unit path attribution for typecheck diagnostics;
- Rust report parity review if a user-facing report format demands exact
  cross-toolchain alignment.
