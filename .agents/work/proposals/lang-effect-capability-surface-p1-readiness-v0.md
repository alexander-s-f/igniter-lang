# lang-effect-capability-surface-p1-readiness-v0 — dual-toolchain effect/capability map

**Card:** `LANG-EFFECT-CAPABILITY-SURFACE-P1`
**Lane:** readiness / language-canon / dual-toolchain map. **No syntax implemented, no machine
code changed, no app migration, no live IO.**
**Verify-first:** live triple-compile on BOTH compilers (recipes below) + source reading of
`parser`/`classifier`/`typechecker`/`emitter` in each toolchain.

## Method (live evidence)

- **Ruby (igniter-lang canon):** `ruby -I lib bin/igc compile SRC.ig --out OUT` →
  `"status": "ok"|"oof"` + diagnostics.
- **Rust (igniter-lab):** `IgniterMachine::check_source(src)` (full Rust front-end) → typed
  diagnostics; the real `storage_capability` effect fixture also compiled live this session (P2).

Three probe contracts, run live on both:

| contract | Ruby | Rust |
|---|---|---|
| **c1 core** — `effect contract A { capability c : IO.Capability  effect read_file using c }` | **ok** | **ok** |
| **c2 profile** — `profile p { authority: effect }` + `effect contract A via p { … }` | **ok** | **OOF-G1** (lexer rejects `profile`/`via`) |
| **c3 effect-name** — `effect connect using c` | **ok** | **E-IO-EFFECT-UNKNOWN** |

## Readiness matrix (per feature × toolchain)

| feature | Ruby parse | Ruby typecheck | Rust parse | Rust typecheck | dual-clean? |
|---|---|---|---|---|---|
| modifier `pure/observed/effect/privileged/irreversible` | ✓ | ✓ | ✓ (+`recursive/fuel_bounded`) | ✓ | **✓** |
| `capability <name> : IO.<X>` | ✓ | ✓ → `IO.Capability` sentinel | ✓ | ✓ | **✓** |
| `effect <e> using <cap>`, **e ∈ {read,read_file,read_json,write,write_file,write_json}** | ✓ | ✓ (binding→Unit) | ✓ | ✓ | **✓** |
| `effect <e> using <cap>`, e arbitrary (e.g. `connect`) | ✓ | ✓ | ✓ parse | **✗ E-IO-EFFECT-UNKNOWN** | **✗ Ruby-only** |
| undeclared capability ref | ✗ OOF-M4 | — | ✗ E-IO-CAP-UNKNOWN | — | both reject, **different code** |
| capability declared, no effect | ✗ OOF-M5 | — | ✗ E-IO-EFFECT-UNDECLARED | — | both reject, **different code** |
| `pure` contract declaring a capability | ✗ OOF-M2 | — | (E-IO-AMBIENT-BLOCKED on IO use) | — | **divergent shape** |
| `profile <p> { authority: <m> }` | ✓ | ✓ (OOF-M7/M8) | **✗ OOF-G1 (unknown keyword)** | — | **✗ Ruby-only** |
| `via <profile>` | ✓ | ✓ | **✗ OOF-G1** | — | **✗ Ruby-only** |

Evidence: Ruby `lib/igniter_lang/{parser.rb:1131,1139,506,814; typechecker.rb:458,466;
classifier.rb:120,373}`; Rust `igniter-compiler/src/{parser.rs:965,1664,1671 (no profile/via);
classifier.rs:324 (effect-name allowlist),334,347,1884; emitter.rs:403,425; assembler.rs:343}`.

## Answers

**1. Ruby effect/capability today:** all of modifiers, `capability : Type`, `effect using`,
`profile`/`via` PARSE + TYPECHECK. Effect names are unrestricted (any identifier → `Unit`).
Diagnostics: OOF-M2/M4/M5 (+ OOF-M7/M8 for profiles). Emits a rich `effect_surface_v0_stub` IR
(capability_bindings, affects_scope, **authority_ref, idempotency_mode, receipt_type,
failure_type** — all stubs).

**2. Rust today:** modifiers, `capability : Type`, `effect using` PARSE + TYPECHECK. **No
`profile`/`via` (lexer doesn't know the keywords → OOF-G1).** Effect names are **restricted** to a
fixed read/write set (E-IO-EFFECT-UNKNOWN otherwise). Diagnostics: E-IO-CAP-UNKNOWN /
E-IO-EFFECT-UNKNOWN / E-IO-EFFECT-UNDECLARED / E-IO-AMBIENT-BLOCKED / E-IO-CAP-MISSING / OOF-M1.
Emits flat `modifier` + `capabilities[{name,type}]` + `effects[{name,capability_ref}]` +
`escape_set`.

**3. Canon vs lab vs proposed:** `effect`/`capability`/`profile` are **canon-TRACK proposed, not
accepted** — PROP-031 (modifiers), PROP-033 (via), PROP-035 (effect surface), PROP-040 (profiles)
are all `experiment-pass`; spec chapters ch10/11/12 are `proposed`, Stage 3. The Ruby toolchain is
the canon-track implementation (regression-evidenced). The Rust toolchain is **lab evidence**:
core effect/capability IS implemented; **profile/via is NOT**; the effect-name policy DIVERGES.

**4. Does IR carry enough for host execution?** YES for the core. The MACHINE
(`service_loop::discover_effect_surface`) consumes the **Rust IR** shape
(`modifier`/`capabilities`/`effects`) and resolves effect → capability **type** → executor id →
`run_write_effect` — proven this session (P2) on the real `ExecuteQuery` fixture. Ruby's extra
`effect_surface` fields (`authority_ref`/`idempotency_mode`/`receipt_type`/`failure_type`) are
**stubs the host does NOT consume** — the host owns authority/idempotency/receipt (P5/P6). So the
language declares; the host supplies the runtime envelope. No new IR fields are needed for host
execution.

**5. Minimal dual-clean declared-effect contract shape:**
```igniter
effect contract Name {
  capability cap : IO.<X>Capability
  effect read_file using cap     -- effect name MUST be in the read/write family for Rust
}
```
(= probe c1, verified dual-clean; the machine's `ExecuteQuery` fixture is exactly this shape.)
NO `profile`, NO `via`.

**6. profile/via — postpone or split?** **SPLIT and postpone.** They are Ruby-only (Rust lexer
rejects them outright) and the host does not consume them. Core `effect`/`capability` stands alone
and is dual-clean. Do not couple profile/via into the next core slice; reopen only under a
separate dual-toolchain authorization.

**7. Diagnostics both should agree on:** today they DON'T (OOF-M* vs E-IO-*). The two universal,
should-agree cases: (a) effect → undeclared capability (Ruby OOF-M4 / Rust E-IO-CAP-UNKNOWN); (b)
capability with no effect binding (Ruby OOF-M5 / Rust E-IO-EFFECT-UNDECLARED). Recommend ONE shared
code per case. The BIGGEST divergence is the **effect-name allowlist**: Rust's E-IO-EFFECT-UNKNOWN
has no Ruby counterpart. It must be resolved one way (see #10).

**8. Maps to machine `run_service` / passports:** the language surface is the **DECLARATION half**;
the machine is the **EXECUTION half**. `discover_effect_surface` reads `modifier`/`capabilities`/
`effects`; the effect's capability **TYPE** (e.g. `IO.StorageCapability`) = the executor id;
`run_service_with_passport` carries authority (signed passport, P21), idempotency, clock, receipt —
NONE from the contract. The contract never carries a credential or a receipt; the host does.

**9. Must remain closed:** ambient IO in contract bodies (Rust E-IO-AMBIENT-BLOCKED enforces; Ruby
should mirror); direct HTTP/DB calls in contracts (the contract body does no IO — proven host-side,
`dispatch` has no executor); **runtime authority as a contract field** (Ruby's `authority_ref`
stub must NOT become a contract-carried credential — authority is the host passport). No live IO.

**10. Next implementation slice (one, narrow):** `LANG-EFFECT-DIAGNOSTIC-PARITY-P2` — reconcile the
**effect-name policy + the two shared diagnostic codes** across Ruby/Rust for the CORE
(`capability` + `effect using`), with NO profile/via. **Recommended direction:** Rust **relaxes**
its effect-name allowlist to accept any declared effect name (matching Ruby), because the host
keys on the capability **TYPE** as the executor id — the effect name is only a label, never used as
a closed vocabulary by `run_service`. This makes c3-style contracts dual-clean and aligns the
language with the proven host model. It is a small `igniter-compiler` classifier change (relax
`E-IO-EFFECT-UNKNOWN`) + a diagnostic-code agreement — **not new syntax, not machine code, not
profile/via.** (This packet only NAMES it; it does not implement.)

## Closed surfaces

No app migrations. No live IO. No machine IO changes. No profile/via implementation. No claim that
IO is a language primitive (it is host-side; the language only DECLARES the effect surface).
