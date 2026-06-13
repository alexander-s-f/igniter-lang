# LANG-EFFECT-SURFACE-RUNTIME-BRIDGE-P2 — Implementation Planning

**Status:** implementation-planning-only — CLOSED / READY FOR P3  
**Route:** LANG EFFECT SURFACE / SEMANTICIR BRIDGE PLANNING  
**Date:** 2026-06-13  
**Authority:** planning only; no parser/compiler/runtime implementation  
**Proof:** `experiments/effect_surface_runtime_bridge_proof/verify_effect_surface_runtime_bridge_p2.rb` — 55/55 PASS  
**Card:** `LANG-EFFECT-SURFACE-RUNTIME-BRIDGE-P2.md`  
**Precondition:** P1 closed 52/52 (proposal + readiness)

---

## Scope

P1 defined the minimal `effect_surface_v0` schema and confirmed the gap:
`escape_boundaries` is empty, no `effect_surface` field exists in SemanticIR for IO effect
contracts. This document plans the bounded implementation that closes that gap.

**Planning decision: READY FOR P3.**

No new parser syntax is required. All seven bridge fields can be derived from existing
`capability` / `effect_binding` typed declarations. One file changes: `semanticir_emitter.rb`.
Two new private methods. Two insertion points.

---

## Q1 — Can `effect_surface_v0` Be Derived from Current Grammar?

**YES.** The typed AST already contains everything needed for a stub:

| Bridge field | Source in typed AST |
|---|---|
| `affects_scope` | Default `"external"` (all `IO.*` types are external) |
| `affects_target` | `capability` decl `type.name` = `"IO.Capability"` (CR-001 sentinel) |
| `authority_ref` | `nil` — no `authority` clause grammar yet (PROP-035) |
| `idempotency_mode` | `"none"` — no `idempotency` clause grammar yet (PROP-035) |
| `idempotency_key_expr` | `nil` — pending PROP-035 |
| `receipt_type` | `nil` — pending PROP-035 |
| `failure_type` | `nil` — pending PROP-035 |

**Conclusion:** No new parser productions. No classifier changes. No typechecker changes.

The stub is derived by iterating `contract["declarations"]` in the emitter:
- `kind == "capability"` → supplies `capability_name` and `capability_type`
- `kind == "effect_binding"` → supplies `effect_name` via `deps` back-reference

---

## Q2 — Minimal Grammar Subset and Exact Insertion Points

**No new grammar.** One file only: `lib/igniter_lang/semanticir_emitter.rb`.

### Insertion Point 1 — `typed_contract_ir` (~line 174)

After the `escape_boundaries` line, add an optional `effect_surface` field:

```ruby
# LANG-EFFECT-SURFACE-RUNTIME-BRIDGE-P3: emit stub for IO effect contracts
effect_surface = io_effect_surface_stub(contract)
contract_ir["effect_surface"] = effect_surface if effect_surface
```

The stub is emitted only when:
- `contract["modifier"]` is `"effect"`, `"privileged"`, or `"irreversible"` AND
- At least one `kind == "capability"` declaration exists.

### Insertion Point 2 — `typed_escape_boundaries` (~line 452)

At the end of the method (after the stream boundary logic), append IO capability entries:

```ruby
# LANG-EFFECT-SURFACE-RUNTIME-BRIDGE-P3: IO capability escape boundaries
boundaries + io_capability_escape_boundaries(contract)
```

### New Method 1 — `io_effect_surface_stub(contract)`

```ruby
def io_effect_surface_stub(contract)
  modifier = contract.fetch("modifier", "pure")
  return nil unless %w[effect privileged irreversible].include?(modifier)

  decls     = contract.fetch("declarations", [])
  cap_decls = decls.select { |d| d.fetch("kind") == "capability" }
  return nil if cap_decls.empty?

  eff_decls = decls.select { |d| d.fetch("kind") == "effect_binding" }
  bindings  = cap_decls.map do |cap|
    cap_name = cap.fetch("name")
    eff      = eff_decls.find { |e| e.fetch("deps", []).include?(cap_name) }
    {
      "capability_name" => cap_name,
      "capability_type" => cap.fetch("type", {}).fetch("name", "IO.Capability"),
      "effect_name"     => eff&.fetch("name")
    }
  end

  {
    "kind"                 => "effect_surface_v0_stub",
    "capability_bindings"  => bindings,
    "affects_scope"        => "external",
    "affects_target"       => "IO.Capability",
    "authority_ref"        => nil,
    "idempotency_mode"     => "none",
    "idempotency_key_expr" => nil,
    "receipt_type"         => nil,
    "failure_type"         => nil
  }
end
```

### New Method 2 — `io_capability_escape_boundaries(contract)`

```ruby
def io_capability_escape_boundaries(contract)
  decls     = contract.fetch("declarations", [])
  cap_decls = decls.select { |d| d.fetch("kind") == "capability" }
  eff_decls = decls.select { |d| d.fetch("kind") == "effect_binding" }

  cap_decls.map do |cap|
    cap_name = cap.fetch("name")
    eff      = eff_decls.find { |e| e.fetch("deps", []).include?(cap_name) }
    {
      "kind"            => "io_capability",
      "name"            => eff&.fetch("name") || cap_name,
      "required_caps"   => ["IO.Capability"],
      "capability_name" => cap_name,
      "capability_type" => cap.fetch("type", {}).fetch("name", "IO.Capability")
    }
  end
end
```

---

## Q3 — Missing Fields: OOF-M2 vs Runtime Refusal

Confirmed from P1. Not changed by this planning:

| Missing field in source | Resolution |
|---|---|
| `affects` clause absent | OOF-M2 (pending PROP-035 grammar) |
| `authority` absent on `privileged`/`irreversible` | OOF-M2 (pending PROP-035) |
| `idempotency: none` in retry profile | OOF-M4 (pending PROP-035) |
| `reversibility` exceeds profile max | OOF-M5 (pending PROP-035) |
| No executor for family | `effect.unsupported_family` — runtime |
| Passport missing | `effect.missing_passport` — runtime |

The stub emitter does NOT fire any OOF codes. OOF-M2 enforcement for missing Effect
Surface header fields is deferred to PROP-035 grammar landing.

---

## Q4 — SemanticIR Shape for Executor Dispatch

After P3 implementation, `contract_ir` will look like:

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

The `CapabilityExecutor` (from `LANG-IO-CAPABILITY-EXECUTOR-P1`) reads:
- `effect_surface.capability_bindings[].capability_type` → `"IO.Capability"` → route to family
- `effect_surface.capability_bindings[].effect_name` → effect to dispatch
- `effect_surface.authority_ref` → runtime authority gate (nil = no gate for basic `effect`)
- `effect_surface.idempotency_mode` → retry policy check
- `escape_boundaries[].required_caps` → passport requirement list

---

## Q5 — How This Avoids Implementing Full PROP-035

| Guard | Mechanism |
|---|---|
| `kind: "effect_surface_v0_stub"` | Consumers must not treat this as full PROP-035 output |
| `nil` for all grammar-dependent fields | No false authority; no premature enforcement |
| No OOF codes emitted | OOF enforcement remains PROP-035 work |
| Only emitted when capability decls exist | No stub for pure/observed contracts |
| One file only | No parser/classifier/typechecker changes |
| No schema validation of nil fields | No silent PROP-035 feature grab |

**PROP-035 guard:** When PROP-035 ships, it changes the emitter to emit `kind: "effect_surface_v0"` (without `_stub`). Any consumer checking for `effect_surface_v0_stub` will know it's the bridge version. This creates a clean upgrade path.

---

## Q6 — What `LAB-IGNITER-LANG-IO-RUNTIME-P3` May Assume

After P3 implementation, the lab mocked executor may assume:

1. `contract_ir["effect_surface"]["kind"] == "effect_surface_v0_stub"` is present for IO effect contracts with at least one capability declaration.
2. `contract_ir["effect_surface"]["capability_bindings"]` is a non-empty array.
3. Each binding has `capability_name`, `capability_type == "IO.Capability"`, and `effect_name`.
4. `contract_ir["escape_boundaries"]` includes at least one entry with `kind == "io_capability"` and `required_caps == ["IO.Capability"]`.
5. `authority_ref`, `idempotency_mode`, `receipt_type`, `failure_type` may all be nil or `"none"` — the executor must not require them for a mocked v0 dispatch.

**Lab P3 must NOT assume:**
- `affects_scope` is anything other than `"external"` (for now always external).
- Any of the nil fields are semantically validated.
- This is a PROP-035-grade output.

---

## Authorized Files

- `lib/igniter_lang/semanticir_emitter.rb` — 2 insertion points + 2 new private methods (~60 new lines)
- `experiments/effect_surface_runtime_bridge_proof/verify_effect_surface_runtime_bridge_p3.rb` — P3 proof runner

## Not Authorized

- `lib/igniter_lang/parser.rb` — no changes
- `lib/igniter_lang/classifier.rb` — no changes
- `lib/igniter_lang/typechecker.rb` — no changes
- Any assembler or runtime files
- Any grammar changes

---

## Proof Matrix

**P3 proof target: ≥ 65 checks across 8 sections:**

| Section | Scope | Target checks |
|---|---|---|
| A: Baseline regression | io_capability_proof 64/64 still PASS | 8 |
| B: effect_surface present | `effect_surface` key in contract_ir | 8 |
| C: stub kind correct | `kind == "effect_surface_v0_stub"` | 5 |
| D: capability_bindings shape | array, capability_type, effect_name | 8 |
| E: escape_boundaries IO entries | kind=io_capability, required_caps | 8 |
| F: nil fields present | authority_ref/idempotency/receipt/failure all nil | 6 |
| G: multi-capability | multi_capability fixture | 8 |
| H: closed surfaces | no PROP-035 grammar landed, no new OOF | 6 |
| I: pure/observed unaffected | no stub for pure contracts | 8 |

**Total:** ≥ 65 checks

---

## Closed Surfaces (this planning card)

- No parser changes.
- No classifier changes.
- No typechecker changes.
- No assembler changes.
- No runtime / VM changes.
- No OOF codes introduced.
- No real IO execution.
- No Rack / HTTP / ORM / DB references.
- No production runtime claim.
- No PROP-035 grammar landed by this card.
