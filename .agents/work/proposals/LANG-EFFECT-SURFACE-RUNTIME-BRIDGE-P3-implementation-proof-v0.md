# LANG-EFFECT-SURFACE-RUNTIME-BRIDGE-P3 — Implementation Proof

**Date:** 2026-06-13  
**Route:** LANG EFFECT SURFACE / SEMANTICIR STUB IMPLEMENTATION  
**Status:** CLOSED — PROOF COMPLETE (65/65)  
**Authority:** compiler evidence only; no runtime dispatch and no full PROP-035  
**Precondition:** P2 closed 55/55 (implementation planning)

---

## What this proves

Two bounded insertions in `lib/igniter_lang/semanticir_emitter.rb` cause SemanticIR to emit:

1. An `effect_surface_v0_stub` object on all IO-effect contracts that have at least one `capability` declaration.
2. One or more `io_capability` escape boundary entries per capability declaration.

Both outputs are consumed by `LAB-IGNITER-LANG-IO-RUNTIME-P4` as the evidence source for executor dispatch.

---

## Implementation

**One file only:** `lib/igniter_lang/semanticir_emitter.rb`

### Insertion 1 — `typed_contract_ir`

After the `escape_boundaries` assignment line, the method now calls:

```ruby
# LANG-EFFECT-SURFACE-RUNTIME-BRIDGE-P3: emit effect_surface_v0_stub for IO effect contracts
effect_surface = io_effect_surface_stub(contract)
contract_ir["effect_surface"] = effect_surface if effect_surface
```

Only emits when modifier is `effect`, `privileged`, or `irreversible` AND at least one `capability` declaration exists.

### Insertion 2 — `typed_escape_boundaries`

At the end of the existing method, after the stream boundary logic:

```ruby
boundaries + io_capability_escape_boundaries(contract)
```

### New method: `io_effect_surface_stub(contract)`

Iterates `declarations` to collect:
- `cap_decls` — all `kind == "capability"` entries
- `eff_decls` — all `kind == "effect_binding"` entries
- Derives each binding: `capability_name`, `capability_type`, `effect_name` (via `deps` back-reference)

Emits:

```json
{
  "kind": "effect_surface_v0_stub",
  "capability_bindings": [
    {
      "capability_name": "net_conn",
      "capability_type": "IO.Capability",
      "effect_name": "connect_to_service"
    }
  ],
  "affects_scope": "external",
  "affects_target": "IO.Capability",
  "authority_ref": null,
  "idempotency_mode": "none",
  "idempotency_key_expr": null,
  "receipt_type": null,
  "failure_type": null
}
```

### New method: `io_capability_escape_boundaries(contract)`

Per capability declaration, emits:

```json
{
  "kind": "io_capability",
  "name": "connect_to_service",
  "required_caps": ["IO.Capability"],
  "capability_name": "net_conn",
  "capability_type": "IO.Capability"
}
```

---

## PROP-035 upgrade-path guard

| Key property | Mechanism |
|---|---|
| `kind: "effect_surface_v0_stub"` | Consumers must not treat this as PROP-035 output |
| All nil/none fields | No false authority; no premature enforcement |
| No OOF codes emitted | OOF enforcement remains PROP-035 work |
| Only emits for capability contracts | No stub for pure/observed/recursive |
| One file only | No parser/classifier/typechecker changes |

When PROP-035 ships, the emitter changes `kind` to `"effect_surface_v0"` (without `_stub`). Any consumer checking for `"effect_surface_v0_stub"` knows it is using the bridge.

---

## SemanticIR shape after P3

```json
{
  "kind": "contract_ir",
  "modifier": "effect",
  "fragment_class": "escape",
  "escape_boundaries": [
    {
      "kind": "io_capability",
      "name": "connect_to_service",
      "required_caps": ["IO.Capability"],
      "capability_name": "net_conn",
      "capability_type": "IO.Capability"
    }
  ],
  "effect_surface": {
    "kind": "effect_surface_v0_stub",
    "capability_bindings": [
      {
        "capability_name": "net_conn",
        "capability_type": "IO.Capability",
        "effect_name": "connect_to_service"
      }
    ],
    "affects_scope": "external",
    "affects_target": "IO.Capability",
    "authority_ref": null,
    "idempotency_mode": "none",
    "idempotency_key_expr": null,
    "receipt_type": null,
    "failure_type": null
  }
}
```

---

## P1 and P2 runner regression

| Runner | Pre-P3 | Post-P3 |
|--------|--------|---------|
| `verify_effect_surface_runtime_bridge_p1.rb` | 52/52 PASS | 52/52 PASS (3 gap-doc checks updated to fixed-state) |
| `verify_effect_surface_runtime_bridge_p2.rb` | 55/55 PASS | 55/55 PASS (3 gap-doc checks already updated to fixed-state) |

---

## Proof runner

**Path:** `experiments/effect_surface_runtime_bridge_proof/verify_effect_surface_runtime_bridge_p3.rb`  
**Score:** 65/65 PASS

### Section breakdown

| Section | Scope | Checks |
|---------|-------|--------|
| A | Baseline regression (io_capability fixtures compile clean) | 8 |
| B | `effect_surface` present in SIR contract_ir | 8 |
| C | Stub kind `== "effect_surface_v0_stub"` | 5 |
| D | `capability_bindings` shape — capability_name, capability_type, effect_name | 8 |
| E | `escape_boundaries` IO entries — kind, name, required_caps | 8 |
| F | Nil/none fields — authority_ref, idempotency, receipt, failure | 6 |
| G | Multi-capability fixture — 2 bindings, 2 escape boundaries | 8 |
| H | Pure/observed unaffected — stub nil for non-IO-effect | 8 |
| I | Closed surfaces — one file, no grammar, no new OOF | 6 |
| **Total** | | **65** |

---

## Boundary declarations

- No parser syntax changed.
- No classifier changes.
- No typechecker changes.
- No runtime dispatch.
- No executor registry wiring.
- No full PROP-035 implementation.
- No Rack, DB, SQL, ORM, network, file IO, or public API claim.
- `io_effect_surface_stub` and `io_capability_escape_boundaries` are private methods — not part of any public API.

---

## Recommended next card

`LAB-IGNITER-LANG-IO-RUNTIME-P4` — consumes `effect_surface_v0_stub` and executor runtime substrate from P3-IO to prove minimal RuntimeMachine dispatch wiring (ESCAPE → registry lookup → passport check → executor dispatch → EffectResult envelope).
