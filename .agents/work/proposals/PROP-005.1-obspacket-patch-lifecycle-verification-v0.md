# PROP-005.1: ObsPacket Patch — Lifecycle Field and :verification_observation v0

Status: proposal (patch to PROP-005)
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Patches: `proposals/PROP-005-bridge-observation-envelope-v0.md`
Depends on: `proposals/PROP-007-conformance-verification-v0.md`,
             `proposals/PROP-010-temporal-lifecycle-retention-semantics-v0.md`

---

## Purpose

Two changes deferred from originating proposals:

1. **`:verification_observation`** (PROP-007) — new closed `ObsKind` for conformance results.
2. **`lifecycle` field** (PROP-010) — each `ObsPacket` carries its lifecycle class for TBackend routing, semantic GC, and flush decisions.

---

## Change 1: :verification_observation Added to ObsKind

```text
ObsKind (v0.1) =
  :descriptor_observation | :value_observation | :constraint_observation
  | :fact_observation | :intent_observation | :receipt_observation
  | :failure_observation | :platform_observation
  | :verification_observation    -- NEW (PROP-007)
```

**[D]** Nine members total. Any kind outside this set is OOF
(`compile.unknown_obs_kind` at Pass 0).

**WF-6 → WF-9**: renumbered, updated to nine members.

---

## Change 2: lifecycle and lifecycle_ref Added to ObsPacket

```text
ObsPacket[kind, T] = Record {
  ...all v0 fields...
  lifecycle    : LifecycleClass          -- NEW; required; default by kind
  lifecycle_ref: Option[ObsId]           -- NEW; links to owning window or boundary
  extensions   : Record {}
}
```

**Default lifecycle by ObsKind:**

| ObsKind | Default |
|---------|---------|
| `:descriptor_observation` | `:durable` |
| `:value_observation` | `:session` |
| `:constraint_observation` | `:session` |
| `:fact_observation` | `:durable` |
| `:intent_observation` | `:session` |
| `:receipt_observation` | `:durable` |
| `:failure_observation` | `:session` |
| `:platform_observation` | `:durable` |
| `:verification_observation` | `:audit` |

**[D]** `:verification_observation` defaults to `:audit` — conformance evidence
must be resolvable long after the session that produced it (required for
`CompatibilityReport.trust_level` checks at resume time).

---

## New Wellformedness Rules

**WF-10**: `lifecycle = :local` AND `obs.id ∈ SemanticImage.observation_log` → violation (`constraint.lifecycle_violation`). A `:local` observation must not persist into the SemanticImage.

**WF-11** (warning in v0): `lifecycle = :window` AND window has `boundary_key` AND `lifecycle_ref = None` → WF warning.

---

## content_hash Canonical Ordering (v0.1)

```text
canonical_fields = [
  id, space, kind, subject,
  producer, emitted_at,
  lifecycle, lifecycle_ref,   -- inserted here
  privacy, links, temporal,
  payload_hash,               -- hash of payload; not raw payload
  constraints, capabilities, actor
  -- extensions: excluded (advisory; hash-unstable)
]
```

**[D]** Adding `lifecycle` and `lifecycle_ref` changes `content_hash` vs v0 packets.
This is a **hash schema version** change. `TBackendDescriptor.version` must be
bumped when a backend transitions to v0.1. Mixed v0/v0.1 sessions trigger
`CompatibilityReport.runtime_version: :downgrade`.

---

## Backward Compatibility

| Scenario | Effect |
|----------|--------|
| v0 packet at v0.1 runtime | `lifecycle` defaulted by kind; `lifecycle_ref = None`; warning only |
| v0.1 packet at v0 runtime | `lifecycle` treated as unknown extension; no error; semantics not enforced |
| Mixed v0/v0.1 in same TBackend | Hash schema divergence → `CompatibilityReport: :downgrade` |

---

## Rejected Paths

[X] Lifecycle as extension field — lifecycle affects TBackend routing, GC,
flush; must be first-class typed.

[X] Keeping eight ObsKind members — `:verification_observation` is core to
PROP-007 conformance protocol.

[X] Extensions in `content_hash` — advisory, version-unstable; breaks
reproducibility.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-005.1
Status: done

[D] Nine ObsKind members; :verification_observation = CORE, default :audit.
    lifecycle field required with kind-based defaults.
    WF-10, WF-11 added. content_hash canonical ordering declared.
    v0 → v0.1 is a hash schema version change.

[Next] Research Agent track: temporal-contracts-and-projections-v0
```
