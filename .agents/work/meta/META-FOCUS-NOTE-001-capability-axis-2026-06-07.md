# Meta Focus Note — MFN-001

**From:** Portfolio Meta-Architect
**To:** Portfolio Architect Supervisor
**Date:** 2026-06-07
**Subject:** IO.Capability / PROP-033 / PROP-035 — New Axis Assessment and PROP-039 Supersession Question

---

## § 1. Trigger

Three canon commits landed in the same session:

| Commit | Artifact | Evidence |
|--------|----------|----------|
| PROP-035 | `capability` / `effect_binding` grammar productions; OOF-M2/M4/M5 | 64/64 PASS |
| PROP-033 | `via <profile>` clause on contract declarations; `profile_binding` in contract_ir | 52/52 PASS |
| Reg. clean | PROP-031 contract_modifiers_proof | 200/200 PASS |

The question posed: does this cluster constitute a new **primary Main Line axis** that should
temporarily supersede `forms/PROP-039`?

---

## § 2. Five Questions — Assessed

### Q1 — Is `IO.Capability` now the central canon spine?

**Finding: No. It is a structural extension of the escape surface, not a new spine.**

The canon spine remains: `module → contract → fragment_class → SemanticIR`. PROP-035 extends
the `escape` surface of contracts — it adds two new body-level productions inside the existing
grammar hierarchy. The OOF codes (M2/M4/M5) enforce consistency within that surface.

What has changed: the canon grammar now has a **first-class hook** for IO surfaces. Previously,
`escape` declarations were name-only (`escape <ident>`). Now a contract may declare *what kind*
of IO surface it accesses and *what effect* uses it. That is meaningful, but it is an extension,
not a structural pivot.

The spine did not change. The escape surface became richer.

### Q2 — How does lab `IO.NetworkCapability` relate to canon `IO.Capability`?

**Finding: Correct boundary, but boundary must be named explicitly to prevent drift.**

The canon typechecker normalizes all `IO.*` type references to the opaque sentinel `"IO.Capability"`.
It does not distinguish `IO.NetworkCapability` from `IO.FileCapability`. The compiler:

- Accepts any `IO.*` identifier in a `capability` declaration ✅
- Normalizes to `"IO.Capability"` in the typed IR ✅
- Does not validate the JSON schema of the capability value ✅ (lab-only)
- Does not resolve delegation chains at compile time ✅ (lab-only, NET-P2/P5)

The lab owns: schema fields, delegation algebra (8 conditions), glob semantics, FFI surface,
E-NET-* codes, stub mode, runtime injection.

The canon owns: the grammatical surface — that capabilities must be declared, must be bound by an
effect statement, must respect modifier constraints (OOF-M2).

**This boundary is currently implicit.** It is scattered across PROP-035 §5.2, the lab bridge doc,
and the portfolio alignment note. It must become an explicit named rule (see § 4).

### Q3 — Does `via_profile` change compiler/profile authority?

**Finding: It installs the hook but exercises no authority. The hook is structurally open-ended.**

PROP-033 emits `profile_binding` in `contract_ir`. The compiler records which profile a contract
declares, but:

- It does not validate that the named profile exists ← PROP-040 scope
- It does not validate that the profile's authority level matches the contract modifier ← OOF-M7/M8 scope
- It does not inject runtime profile state ← Phase 2

The compiler's authority has not changed. What has changed is that the `contract_ir` now contains
a field (`profile_binding`) that downstream consumers — profile resolvers, runtime injectors, audit
tools — can read. This is forward-compatible and correct.

**Risk:** `profile_binding` is emitted with no schema to validate against. PROP-040 is queued but
not authored. Until PROP-040 closes, every `contract_ir` with a `profile_binding` field references
a profile that the compiler cannot verify exists or is well-formed. This is known structural debt.

### Q4 — What must remain lab-only?

Explicit closure list — the following surfaces must not cross into canon grammar without a formal
PROP with cross-repo authority review:

| Surface | Why lab-only |
|---------|--------------|
| `IO.NetworkCapability` JSON schema fields | Schema is stdlib territory, not grammar territory |
| Delegation algebra (grant/scope/chain conditions) | Proved in NET-P2/P5; canon has no delegation grammar yet |
| E-NET-* compiler diagnostic codes (10 codes) | Lab classification tool, not canon OOF codes |
| HTTP types (`ContractRef[HttpRequest, HttpResponse]`) | HTTP-TYPES-P1 is lab-only; no grammar PROP authored |
| Middleware compose / Rack | Web framework track; no grammar surface; no PROP |
| FFI stubs / stub mode | Runtime concern |
| Runtime capability injection | Phase 2; no PROP |
| Capability runtime authority resolution | Requires profile schema + runtime; both future |

**Rule anchor (see § 4.1).**

### Q5 — What exact rule prevents Rack/Web/Ruby drift?

**Finding: The rule exists in intent but is not written as a named canon rule.**

The risk path: IO.Capability grammar exists in canon → next card asks "can we validate the HTTP
request shape at compile time?" → grammar for HTTP types enters canon → Rack/Middleware types
follow → canon grammar now depends on web framework vocabulary.

This is the classic semantic drift pattern. The firewall must be explicit:

> **Canon Rule CR-001 (proposed):** The igniter-lang canon grammar may reference external type
> names (e.g. `IO.NetworkCapability`) as opaque identifiers only. The compiler must not import,
> validate, or generate code that depends on the internal schema of any type defined in igniter-lab,
> igniter-ruby, or any third-party gem. Type schema knowledge is lab-only until a formal
> cross-repo PROP with governance review promotes it to canon.

See § 4 for formal rule text.

---

## § 3. Main Line Axis Verdict

**Question:** Does the IO.Capability / PROP-033 / PROP-035 cluster create a new primary Main Line
axis that should temporarily supersede PROP-039?

**Verdict: Partial. PROP-040 should precede PROP-039. PROP-039 is not superseded — it runs on a
parallel track.**

### Rationale

The capability cluster has created an open chain:

```
PROP-035: capability grammar      ✅ experiment-pass
    ↓
PROP-033: profile binding         ✅ experiment-pass
    ↓
PROP-040: profile declarations    ◯ queued; not authored   ← OPEN DANGLING END
    ↓
OOF-M7/M8: profile constraint     ✗ future
validation
```

The chain is live at the grammar level but structurally incomplete: `profile_binding` is emitted in
`contract_ir` referencing profiles that the compiler cannot yet validate. This is bounded,
non-blocking debt — it does not corrupt existing proofs — but it does mean the capability axis
is mid-stream.

PROP-039 (Managed Local Recursion) is logically independent. It addresses Postulate 14
(repetition must be managed), not the IO/authority surface. It does not block and is not blocked
by the capability chain.

**Recommendation:** PROP-040 before PROP-039 in the Main Line design/proposal queue. Not because
PROP-039 is lower priority, but because PROP-040 is narrow (profile declaration grammar), closes
an open hook created by PROP-033, and gives the capability trilogy a clean termination before
the queue moves to a different axis.

PROP-039 then proceeds in its own right, as a separate grammar axis.

---

## § 4. Rule Patches

### Rule CR-001 — Canon type opacity

> The igniter-lang canon grammar may accept external type names (e.g. `IO.NetworkCapability`,
> `IO.FileCapability`) as opaque string identifiers. The compiler normalizes all `IO.*` names
> to the `"IO.Capability"` sentinel in the typed IR. The canon must not import, validate, or
> generate behavior that depends on the internal schema, field list, or delegation semantics of
> any type whose schema is defined outside igniter-lang itself (lab, gem, runtime). Schema
> promotion to canon requires a cross-repo PROP with explicit governance review.

**Placement:** Propose adding to `docs/language-covenant.md` §CR section (new subsection).

### Rule CR-002 — Lab diagnostic boundary

> E-NET-* codes, LAB-STDLIB-NET codes, and any diagnostic codes authored in igniter-lab proofs
> are lab-local. They inform the design of OOF-* canon codes but are not OOF-* canon codes
> themselves. Promoting a lab diagnostic code to canon OOF status requires a formal PROP with
> the compiler expert authority reviewing grammar and classifier impact.

**Placement:** Same `docs/language-covenant.md` §CR section.

### Rule CR-003 — Profile binding is an intent record, not an authority grant

> The `profile_binding` field in `contract_ir` (produced by PROP-033) is a source-level intent
> record. The presence of `profile_binding` does not grant, validate, or enforce any runtime
> authority. A contract with `profile_binding` that references a non-existent profile is a
> compile-time warning (OOF-M8, deferred to PROP-040), not a silent grant. No consumer of
> `contract_ir` may treat `profile_binding` as validated authority without a PROP-040 schema
> check in the pipeline.

**Placement:** Add to PROP-033 § 5 as explicit non-goal, and to PROP-040 intake when authored.

---

## § 5. Attention Vector

Ordered by recommended next focus:

| Priority | Item | Why now |
|----------|------|---------|
| 1 | **PROP-040: profile declarations** | Closes the open hook from PROP-033; narrow grammar scope; unblocks OOF-M7/M8 |
| 2 | **CR-001/CR-002/CR-003 rule text** | Firewall against Rack/Web/lab drift; low cost to write now while boundary is fresh |
| 3 | **PROP-039: managed local recursion** | Independent axis; `authored-pending-review` → review gate next; not blocked by above |
| 4 | **DA-005: experiments/ archive pass** | Hygiene; ~150 experiments; Stage 1/2 → `_archive/`; delegate to simple card |

---

## § 6. Acceptance/Risk Verdict

| Area | Status | Risk |
|------|--------|------|
| PROP-035 grammar | ✅ Closed | None — 64/64, regressions clean |
| PROP-033 binding | ✅ Closed | None — 52/52, regressions clean |
| IO.Capability boundary | ⚠️ Implicit | Medium — needs CR-001 to prevent lab drift into canon |
| Profile binding open hook | ⚠️ Open | Low — bounded debt; PROP-040 closes it |
| PROP-039 supersession | ✅ Assessed | None — parallel axis, not superseded; queue reordering only |
| Rack/Web/Ruby drift | ⚠️ Latent | Medium — no rule written yet; risk grows as capability grammar matures |

---

*MFN-001 — Portfolio Meta-Architect → Portfolio Architect Supervisor*
*Next action by Supervisor: queue PROP-040 as the next design/proposal target; draft CR-001/002/003 rule text for covenant review.*
