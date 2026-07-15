# Implemented Epistemic Surface

Status: living, verify-first surface map
Updated: 2026-07-15
Authority: current source, emitted artifacts, and runtime behavior outrank older
proposal wording

Igniter calls itself an Epistemic Contract Language. This document makes that
claim inspectable: it separates declarations that exist in source, metadata that
survives compilation, and guarantees that a runtime actually enforces.

## The Epistemic Spine

```text
intent       -> why this code exists
assumptions  -> which named premises it relies on
entrypoint   -> which contract this artifact selects to run
evidence     -> which observations support an output or write
authority    -> which declared role is required for an effect
obligations  -> which operational properties are promised
receipt      -> what the runtime can prove actually happened
```

The arrows are not authority escalation. In particular, descriptive metadata
does not become proof merely because it is compiled.

## Status Vocabulary

| status | meaning |
| --- | --- |
| `runner-live` | the selected runtime consumes and acts on the field |
| `compiler-live` | both compiler pipelines parse, validate, and emit it |
| `canon-only` | the Ruby/canon pipeline supports it; Rust parity is absent |
| `metadata-only` | emitted and queryable, but grants no authority and causes no runtime action |
| `held` | designed or mentioned, but not implemented at that boundary |

## Live Matrix

| surface | epistemic question | Ruby canon | Rust compiler | artifact | runtime | current truth |
| --- | --- | --- | --- | --- | --- | --- |
| `entrypoint Contract` | What should run by default? | live | live | SemanticIR + `.igapp` manifest | VM selects it when `--entry` is absent | `runner-live`; selector only, never capability authority |
| module/contract `intent "..."` | Why does this declaration exist? | 53/53 proof live | rejected (`OOF-G1` / `OOF-P0`) | Ruby `intent_text` only | deliberately absent | `canon-only`, `metadata-only`; highest parity gap |
| `assumptions { ... }` | Which premises are declared? | live | live | `assumption_registry` | ignored | `compiler-live`, `metadata-only` |
| `uses assumptions name` | Which premises does this contract rely on? | live, `OOF-A1` | live, `OOF-A1` | `contract_ir.assumption_refs` | not copied into receipts | `compiler-live`; runtime provenance is held |
| `output ... evidence [refs]` | What supports this output? | live; pure placement refused by `OOF-M9` | live | output-port metadata | refs are not validated against observations at runtime | `compiler-live`, opaque provenance labels |
| `write store <- value evidence [refs]` | What supports this mutation? | live, mandatory refs | live, mandatory refs | write node | execution depends on host/runtime path | stronger compiler fence (`OOF-W1/W2/W3`), runtime proof remains host-owned |
| Effect Surface `receipt/failure/idempotency/affects/authority/compensation/reversibility` | What does an effect claim about itself? | live | live | unified `effect_surface_v1` | field-by-field; declaration alone proves nothing | dual compiler surface; enforcement varies and must be named separately |
| profile + service obligations | What policy/operational promises constrain execution? | live | substantial live surface | profile and contract metadata | liveness enforcement is not implied | declaration consistency is live; operational fulfillment is held unless separately proven |
| runtime receipt / observations | What actually happened? | N/A | N/A | runtime artifact | live on Machine-owned paths | evidence of execution, not evidence that every source declaration was enforced |

## Adjacent Epistemic Carriers

These surfaces participate in accountable knowledge but are not aliases for
assumptions or intent:

- `observed contract` and `escape` declare where external observations enter the
  graph. They identify a boundary, not the quality of the observation.
- `History[T]` / `BiHistory[T]`, explicit temporal coordinates, and runtime
  freshness states (`fresh`, `stale`, `unknown`, `provisional`) say *when* a
  value is known and whether it may be reused.
- `invariant`, recursion budgets, and termination evidence are compiler claims
  with named trust levels. The existing structural evidence is explicitly not a
  general proof of termination.
- `ConfidenceLabel` and `EvidenceLinkedAlert` are specialized typed surfaces
  that prevent confidence from collapsing into `Bool` and require evidence
  links on alerts. They do not yet form a general confidence algebra.
- Domain records named `Claim`, `Decision`, `Result`, or `*Intent` remain normal
  typed values unless a language construct explicitly gives them semantics.
- `SecretRef` is a confidentiality/authority boundary, not an epistemic state.

## Three Different Meanings of Intent

The word `intent` currently names three different things. They must not be
treated as aliases.

1. **Source purpose descriptor**: `intent "render a track"`. Human- and
   agent-readable metadata. It does not affect behavior, policy, capabilities,
   or receipts.
2. **Typed application command**: records or variants such as
   `EmailSendIntent`. These are ordinary values interpreted by a host adapter.
   Their `Intent` suffix is a domain naming convention, not language syntax.
3. **Declared authority intent**: `authority billing_operator` inside an Effect
   Surface. This names a requirement. Runtime admission must still resolve the
   role and fail closed; parsing the declaration grants nothing.

## Verified Receipts (2026-07-15)

- Ruby source `intent`: `experiments/intent_descriptor_proof/` passes 53/53.
- Ruby `entrypoint`: `experiments/entrypoint_descriptor_proof/` passes 53/53.
- Assumptions proof was refreshed against current output-evidence and type rules;
  its golden check passes. The local experiment tree is evidence, not runtime
  authority.
- Rust compiles an assumptions specimen and emits both
  `assumption_registry` and `assumption_refs`.
- Rust rejects the same source-intent specimen at parse time; there is no hidden
  parity implementation.
- Rust emits a manifest entrypoint, and the VM executes that contract without an
  explicit `--entry` selector (probe result `42`).
- No `assumption_refs` consumer exists in `igniter-vm` or `igniter-machine`.

## Known Drift and Gaps

1. **Intent parity:** Rust has no parser, typechecker, or emitter surface for
   source `intent`.
2. **Multifile module intent:** Ruby's multifile resolver currently emits
   `intent_text: nil`; preservation and duplicate semantics need a focused
   decision.
3. **Assumption receipts:** PROP-032 describes receipt propagation as a target,
   but the live runtime does not implement it. Ch2's explicit exclusion is the
   current truth.
4. **Evidence binding:** output evidence refs remain opaque labels. Write
   evidence checks local symbol existence, but neither form proves freshness,
   quality, or causal sufficiency by itself.
5. **Declared versus fulfilled:** Effect Surface and service obligations are
   increasingly rich declarations. Every runtime claim still needs a named
   admission/enforcement/receipt proof.
6. **Discovery:** intent, assumptions, evidence, and entrypoint are not yet one
   queryable command-center/MCP surface for developers and agents.

## Activation Order

The smallest sequence that gives the existing syntax real leverage is:

1. **Dual-toolchain intent parity.** Preserve module and contract intent through
   Rust and multifile compilation without changing behavior digests or granting
   authority.
2. **Epistemic discovery.** Expose entrypoint, intent, assumptions, evidence
   declarations, Effect Surface, and obligations through one read-only
   compiler/command-center query.
3. **Execution provenance envelope.** Design an additive runtime envelope that
   records the selected entrypoint and the declared assumption/evidence refs
   actually carried into execution. It must distinguish `declared`, `resolved`,
   `verified`, and `unknown` rather than collapsing them into a boolean.
4. **Assumption binding only under evidence pressure.** Runtime values,
   freshness, expiry, and cross-module assumptions remain held until a real
   application requires them and a receipt model exists.

## Closed Surfaces

- `intent` mismatch is not a compile error or a behavior guarantee.
- An assumption is not true because it was declared.
- Evidence labels are not automatically verified evidence.
- An entrypoint does not grant capabilities.
- An authority declaration is not runtime authorization.
- Service obligations do not prove liveness merely by appearing in SemanticIR.
- This map does not introduce a universal `Epistemic[T]` type hierarchy.
