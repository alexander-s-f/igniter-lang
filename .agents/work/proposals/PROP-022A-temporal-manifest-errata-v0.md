# PROP-022A Errata: TEMPORAL Manifest Contract v0

Status: experiment-pass
Proven: 2026-05-08 (S3-R5-C1 — manifest.fragment_summary + contract_index PASS)
Date: 2026-05-08
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Amends: `accepted/PROP-022A-igapp-assembler-contract-v0.md`
Depends on: PROP-022, PROP-028
Stage: 3
Source: `docs/discussions/temporal-manifest-and-cache-boundary-pressure-v0.md`
Track evidence: `docs/tracks/prop-022a-temporal-manifest-errata-v0.md` (S3-R4-C2)
               `docs/tracks/temporal-assembler-manifest-contract-index-v0.md` (S3-R5-C1)

---

## § 1. Purpose

PROP-022A defined the Stage 1 `.igapp/` assembler contract when loadable
contracts were effectively `core | escape | mixed`. PROP-028 and the Stage 3
temporal proofs add a refined `TEMPORAL` fragment class with explicit axes and
runtime cache-key pressure.

This errata specifies how `.igapp/manifest.json`, `requirements.json`, and
`contracts/<Name>.json` must carry TEMPORAL metadata without authorizing runtime
memoization, Ledger binding, or production TBackend access.

---

## § 2. Decision: Explicit Dual-Index

[D] The authoritative semantic source remains each `contracts/<Name>.json`
ContractIR.

[D] The authoritative load-time dispatch source is a manifest-level
per-contract index derived from ContractIR:

```text
manifest.contract_index[contract_name]
```

RuntimeMachine load reads this index first to decide whether a contract is
CORE, TEMPORAL, STREAM, ESCAPE, or mixed. It must then validate the indexed
fields against the referenced ContractIR file before returning `loaded`.

[D] This is an explicit dual-index, not two independent sources of truth:

```text
ContractIR       = canonical semantic record
manifest index   = load-time projection of ContractIR
loader invariant = manifest index agrees with ContractIR, or load refuses
```

Rationale:

- Manifest-only would duplicate too much semantic detail.
- ContractIR-only forces RuntimeMachine to parse every contract deeply before it
  can choose fragment/cache/capability handling.
- The dual-index keeps load dispatch cheap and explicit while retaining
  ContractIR as the complete contract definition.

---

## § 3. Resolve `core | mixed` Collapse

[D] `manifest.fragment_class` is no longer authoritative for Stage 3 load
dispatch.

The old aggregate:

```json
{
  "kind": "igapp_manifest",
  "fragment_class": "mixed",
  "contracts": ["Add", "HistoryAxesTest"]
}
```

collapses TEMPORAL into `"mixed"` and loses required cache-key semantics.

[D] Stage 3 manifests must add explicit fragment summary and per-contract
fragment index:

```json
{
  "kind": "igapp_manifest",
  "format_version": "0.1.0",
  "fragment_summary": {
    "fragment_classes": ["core", "temporal"],
    "max_fragment_class": "temporal",
    "precedence_high_to_low": ["oof", "temporal", "stream", "escape", "core"]
  },
  "contract_index": {
    "Add": {
      "contract_ref": "contract/Add/sha256:7379226c21b2cdcd69464bb7",
      "contract_path": "contracts/add.json",
      "fragment_class": "core"
    },
    "HistoryAxesTest": {
      "contract_ref": "contract/HistoryAxesTest/sha256:7e26cc28736928117931083d",
      "contract_path": "contracts/history_axes_test.json",
      "fragment_class": "temporal"
    }
  }
}
```

`fragment_class: "mixed"` may remain as a backward-compatible presentation
field, but loaders must not use it for TEMPORAL cache or capability dispatch.

---

## § 4. Minimal Temporal Manifest Fields

For every TEMPORAL contract, `manifest.contract_index[contract_name]` must
include:

```json
{
  "contract_ref": "contract/HistoryAxesTest/sha256:7e26cc28736928117931083d",
  "contract_path": "contracts/history_axes_test.json",
  "fragment_class": "temporal",
  "temporal": {
    "axes": ["valid_time"],
    "required_capabilities": ["history_read"],
    "coordinates": [
      {
        "name": "as_of",
        "axis": "valid_time",
        "source_ref": "input:as_of",
        "type": "DateTime"
      }
    ],
    "cache_key_schema_hint": {
      "schema": "runtime-cache-key-v1",
      "fragment": "TEMPORAL",
      "axis": "valid_time",
      "coordinate_names": ["as_of"]
    }
  }
}
```

Bitemporal form:

```json
{
  "contract_ref": "contract/BiHistoryAxesTest/sha256:56e10668457e5f40e57d22ef",
  "contract_path": "contracts/bihistory_axes_test.json",
  "fragment_class": "temporal",
  "temporal": {
    "axes": ["valid_time", "transaction_time"],
    "required_capabilities": ["bihistory_read"],
    "coordinates": [
      {
        "name": "valid_time",
        "axis": "valid_time",
        "source_ref": "input:valid_time",
        "type": "DateTime"
      },
      {
        "name": "transaction_time",
        "axis": "transaction_time",
        "source_ref": "input:transaction_time",
        "type": "DateTime"
      }
    ],
    "cache_key_schema_hint": {
      "schema": "runtime-cache-key-v1",
      "fragment": "TEMPORAL",
      "axis": "bitemporal",
      "coordinate_names": ["valid_time", "transaction_time"]
    }
  }
}
```

[D] The cache-key schema hint is declarative only. It means "this contract
requires a TEMPORAL key shape if memoization is enabled." It does not enable
RuntimeMachine caching.

---

## § 5. Relationship Between Manifest, Requirements, and Contract Files

### `contracts/<Name>.json`

Contract files remain the canonical contract records. For TEMPORAL contracts,
the ContractIR must carry:

- `fragment_class: "temporal"`
- `temporal_input_node` / `temporal_access_node`
- `node_fragment_class: "temporal"`
- `value_fragment_class: "core"`
- `axis` / `temporal_axis`
- coordinate refs
- `required_capability` / `required_caps`
- `escape_boundaries` listing temporal capabilities

### `manifest.json`

The manifest is the package-level load index. It must expose enough
per-contract metadata for RuntimeMachine to choose load-time checks without
deep semantic inference:

- contract ref and path
- per-contract fragment class
- temporal axes
- required temporal capabilities
- cache-key schema hint

The manifest is hash-bound to the assembled artifact. If its temporal index
disagrees with the contract file, load must refuse.

### `requirements.json`

`requirements.json` is a package-level capability negotiation summary derived
from `contract_index`, ContractIR `escape_boundaries`, and node `required_caps`.
It is not the semantic source of the temporal axes.

Minimal Stage 3 temporal shape:

```json
{
  "capabilities": {
    "required_caps": ["history_read"]
  },
  "temporal": {
    "contracts": ["HistoryAxesTest"],
    "axes": ["valid_time"],
    "requires_temporal_cache_key": true,
    "cache_key_schema": "runtime-cache-key-v1"
  }
}
```

[D] `requirements.json` may be used for adapter negotiation, but
RuntimeMachine must still validate per-contract details through
`manifest.contract_index` and `contracts/<Name>.json`.

---

## § 6. Loader Rules

Add Stage 3 load rules to PROP-022A:

```text
L-T1: If any contract file has fragment_class "temporal",
      manifest.contract_index must contain a matching entry.

L-T2: If manifest.contract_index marks a contract temporal,
      the referenced contract file must also be fragment_class "temporal".

L-T3: Temporal manifest entry axes must match temporal_access_node axes.

L-T4: Temporal required_capabilities must match the union of ContractIR
      escape_boundaries.required_caps and temporal node required_caps.

L-T5: TEMPORAL cache_key_schema_hint must use runtime-cache-key-v1 and
      fragment TEMPORAL. A CORE hint on a TEMPORAL contract is a load refusal.

L-T6: Missing temporal coordinates for a TEMPORAL entry are a load refusal.
```

Load refusal shape should reuse PROP-022A `load_refusal` and set:

```json
{
  "kind": "load_refusal",
  "gate": "L-T5",
  "reason": "TEMPORAL contract cannot use CORE cache key schema",
  "program_id": "semanticir/history-valid-te"
}
```

---

## § 7. Before / After

### Before: ambiguous temporal package

```json
{
  "kind": "igapp_manifest",
  "format_version": "0.1.0",
  "fragment_class": "mixed",
  "contracts": ["HistoryAxesTest"],
  "contract_refs": {
    "HistoryAxesTest": "contract/HistoryAxesTest/sha256:7e26cc28736928117931083d"
  }
}
```

Problem: RuntimeMachine cannot distinguish TEMPORAL from generic mixed/escape
without opening contract files and reconstructing temporal axes.

### After: temporal contract indexed for load

```json
{
  "kind": "igapp_manifest",
  "format_version": "0.1.0",
  "fragment_summary": {
    "fragment_classes": ["temporal"],
    "max_fragment_class": "temporal",
    "precedence_high_to_low": ["oof", "temporal", "stream", "escape", "core"]
  },
  "contracts": ["HistoryAxesTest"],
  "contract_index": {
    "HistoryAxesTest": {
      "contract_ref": "contract/HistoryAxesTest/sha256:7e26cc28736928117931083d",
      "contract_path": "contracts/history_axes_test.json",
      "fragment_class": "temporal",
      "temporal": {
        "axes": ["valid_time"],
        "required_capabilities": ["history_read"],
        "coordinates": [
          {
            "name": "as_of",
            "axis": "valid_time",
            "source_ref": "input:as_of",
            "type": "DateTime"
          }
        ],
        "cache_key_schema_hint": {
          "schema": "runtime-cache-key-v1",
          "fragment": "TEMPORAL",
          "axis": "valid_time",
          "coordinate_names": ["as_of"]
        }
      }
    }
  }
}
```

---

## § 8. C1/C3 Implementation Alignment

[Next] C1 assembler boundary alignment:

- fix `contract_file` so `temporal_input_node` and `temporal_access_node` do
  not crash assembly;
- preserve temporal nodes in contract files;
- emit `manifest.fragment_summary` and `manifest.contract_index`;
- derive temporal `requirements.json` from ContractIR `escape_boundaries` and
  temporal node metadata;
- refuse temporal manifest/index mismatches.

[Next] C3 runtime cache alignment:

- RuntimeMachine load reads `manifest.contract_index` first;
- load validates contract file agreement before trusting the index;
- load records cache schema capability as metadata only;
- evaluate may construct TEMPORAL keys only after explicit runtime cache work is
  approved;
- absence of cache implementation means no memoization, not fallback to CORE.

No runtime cache, Ledger adapter, or production TBackend binding is authorized
by this errata.

---

## Acceptance Checklist

```text
☐ Manifest carries fragment_summary and contract_index.
☐ TEMPORAL contract entries carry axes, required capabilities, coordinates,
  and cache_key_schema_hint.
☐ requirements.json summarizes temporal capability requirements but is not the
  semantic authority for axes.
☐ Loader validates manifest index against ContractIR before trusting it.
☐ TEMPORAL + CORE cache schema mismatch is a load refusal.
☐ Runtime cache and Ledger binding remain disabled unless separately approved.
```

---

## Handoff

```text
Card: S3-R4-C2-P
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/prop-022a-temporal-manifest-errata-v0
Status: done

[D] Decisions:
- Use explicit dual-index: ContractIR is semantic source; manifest.contract_index
  is load-time dispatch source validated against ContractIR.
- `manifest.fragment_class: mixed` is not authoritative for TEMPORAL.
- TEMPORAL manifest entries require axes, capabilities, coordinates, and a
  declarative cache-key schema hint.

[S] Signals:
- Provides before/after manifest examples.
- Defines manifest / requirements / contract-file responsibilities.
- Adds Stage 3 loader refusal rules L-T1..L-T6.

[R] Risks:
- Existing assembler output does not yet implement this shape.
- RuntimeMachine must not fallback to CORE cache keys for TEMPORAL contracts.

[Next]:
- Implement temporal-assembler-boundary-v0 before RuntimeMachine cache or Ledger
  binding work.
```
