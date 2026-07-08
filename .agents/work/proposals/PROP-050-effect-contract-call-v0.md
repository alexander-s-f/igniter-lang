# PROP-050 — Effect-Contract Call (`invoke … using`): composing non-pure contracts

**Track:** effect-contract-call-v0
**Route:** PROPOSAL AUTHORING ONLY
**Authority:** governance / proposal text only — no grammar, compiler, VM, or chapter change until ratified
**Date:** 2026-07-08
**Predecessor:** `LANG-EFFECT-COMPOSITION-READINESS-P1` (packet
`igniter-lab/lab-docs/lang/lab-effect-composition-readiness-p1-v0.md`, alternative E ratified as the route)
**Status:** RATIFIED (owner, 2026-07-08) — D1 `invoke … using` spelling; D2 `OOF-EC*` namespace; D3 mandatory non-empty `using`; D4 full compile-side escalation matrix, runtime v0 = observed→observed. Implementation: `LAB-EFFECT-CALL-V0-P3` (in flight); chapter/gov registration lands with it.

---

## Purpose

Give Igniter one designed way to CALL a non-pure contract from a non-pure
contract, so effectful workflows can be factored into reusable steps — without
weakening any effect-surface, authority, or determinism law. Today
`call_contract` is pure-only (deliberately, four enforcement sites), so every IO
workflow is a forced monolith.

**This proposal does NOT:**
- Change `call_contract` — it stays pure-only permanently (it is the
  pure-function call; this is a design statement, not a v0 limitation).
- Grant any runtime authority (declaration ≠ execution; live effects stay
  human-gated).
- Introduce async, parallel effects, retries, or compensation semantics.
- Open dynamic (`String -> Contract`) dispatch — callee is a literal name,
  resolved at compile time exactly like `call_contract` (qualified-id rules from
  the contract-identity wave apply unchanged).
- Change the static plugin registry's pure-only rule.

## Evidence base

- **IGDB-P17** (`apps/igniter-apps/igdb/PRESSURE_REGISTRY.md`): `call_contract`
  rejects observed callees; `wal_io.ig` exhibit — `CheckpointDb` inlines
  `RecoverDb` verbatim (lines 88–95 ≡ 66–73); `RunWalDemo` = ~30 computes / 11
  effects because nothing effectful can be factored out. Stage 4: `recursive`
  callees rejected by the same gate.
- Enforcement is quadruple and intentional: Ruby `typechecker.rb:992`, Rust
  `typechecker/stdlib_calls.rs` (OOF-TY0, purity first), VM `vm.rs` runtime
  refusal, plugin registry (pure-only static dispatch).
- The VM's cross-contract machinery (dispatch table, `__call_chain__` cycle
  detection, `__call_depth__` budget, callee `execute`) is already complete; the
  callee `execute` receives NO capability grants — attenuation is the missing
  design, not dispatch. (Readiness packet §2.)
- Landed law this composes with: ch12 `effect_surface_v1` (all 7 fields,
  dual-toolchain), ch11 profile policy (OOF-PROF1 `allowed_effects`, OOF-PROF2
  `requires_authority`), ch13 §13.6 `write … evidence`, PROP-039/041 managed
  recursion (now VM-runnable), interprocedural effect-summary pass (Tarjan SCC).

## EC-SURFACE — Proposed source surface

A new **body-level declaration** (not an expression — an effect call must be
visible at the same altitude as `effect` and `write`):

```ig
observed contract CheckpointDb {
  capability io_db_read: IO.Capability
  effect read_file using io_db_read
  capability io_db_write: IO.Capability
  effect write_file using io_db_write

  invoke recovered = contract("RecoverDb") using io_db_read
  compute page = call_contract("EncodePage", recovered.rows)
  compute w1 = stdlib.IO.write_text("users.tbl", page, io_db_write)
  compute w2 = stdlib.IO.write_text("wal.log", "", io_db_write)
  output w2 : Result[WriteReceipt, IoError]
}
```

With arguments:

```ig
  invoke receipt = contract("WalAppendInsert", r) using io_db_read, io_db_write
```

### Grammar delta (ch2 appendix, on ratification)

```ebnf
BodyDecl   ::= ... | InvokeDecl
InvokeDecl ::= "invoke" Name "=" "contract" "(" String ("," Expr)* ")"
               "using" Name ("," Name)*
```

- `invoke` — new keyword. Verified free in both parsers and the app fleet
  (2026-07-08). NOT `composes` (reserved by PROP-016 for structural
  composition — a different axis; see D1).
- The `using` clause is MANDATORY and non-empty (see D3): capability delegation
  must be visible at the call site. `using` is the existing capability-binding
  keyword, reused with the same meaning: "under these capabilities".
- Callee name is a string literal (parity with `call_contract`; qualified
  `"Module.Name"` allowed under the identity-wave rules).

## EC-SEMANTICS — Static semantics (dual-toolchain, fail-closed)

Result binding: `invoke <name> = …` binds the callee's single output type
(same single-output rule as `call_contract` v0); the bound name is an ordinary
local — usable in later computes and as a §13.6 `evidence` ref.

Proposed diagnostic family **`OOF-EC*`** (namespace free as of 2026-07-08;
follows the P30 namespace policy of one family per surface — see D2):

| Rule | Fires when |
|---|---|
| **OOF-EC1** | callee not found, or callee class not invocable: `pure` callee → "use call_contract"; `recursive`/`service` callee → held in v0 |
| **OOF-EC2** | **surface absorption violation** — a callee effect (verb + capability TYPE) or `affects` target has no covering declaration in the caller. The caller's effective surface = its own ∪ every invoked callee's; that union is what SIR reports and what ch11/ch12 policy sees. Nothing reachable through `invoke` may be invisible at the caller |
| **OOF-EC3** | **attenuation mismatch** — a callee capability slot not satisfied by a `using` name of matching capability TYPE, or a `using` name that satisfies no callee slot (no over-granting), or a `using` name not declared as a caller capability |
| **OOF-EC4** | placement/escalation — `pure` caller may not `invoke` at all; `observed` caller may invoke only `observed` callees; `effect`/`privileged`/`irreversible` may invoke `observed` or `effect` callees (mirror of the OOF-W3 escalation discipline) |
| **OOF-EC5** | depth — the callee itself contains an `invoke` (v0 is depth-1; lifts only by a later PROP with a worked attenuation-chain story) |
| **OOF-EC6** | position — `invoke` anywhere but the contract body's declaration list (no lambda, loop, or branch position; effect order must stay a static total order) |

Self-recursion/cycles: closed, by the existing `call_contract` rules (compile
self-check + VM `__call_chain__`), unchanged.

Ordering: an `invoke` is an EFFECT for ordering purposes — declaration order,
same law as today's effects. Deterministic and replayable; no new scheduler.

Profiles (ch11): OOF-PROF1 `allowed_effects` and OOF-PROF2 `requires_authority`
evaluate against the ABSORBED surface — a profile cannot be escaped by pushing
an effect down one `invoke` level. (No new PROF rules needed; absorption feeds
the existing ones.)

Receipts/evidence (ch12/ch13): the callee's receipts join the caller's
receipt/evidence stream in call position, preserving ONE total audit order; the
invoke-bound name is a legal `write … evidence` ref.

## EC-RUNTIME — Runtime shape (GATED, not granted here)

Implementation card (post-ratification) threads an **attenuated grant subset**
through the callee `execute`: exactly the grants corresponding to the `using`
names, nothing else. The VM refuses at runtime if the callee's declared
capability set is not covered by the passed subset — the same
compile-check + runtime-check dual enforcement the purity gate has today.
A passing compile confers nothing: grants still come from the host at run
start; live IO stays human-gated.

## EC-V0 — Ratified scope fence (the IGDB subset)

- `observed` → `observed`, file-IO capabilities, depth-1, no `invoke` in
  loops/lambdas, single-output callees.
- Living proof: refactor `apps/igniter-apps/igdb/wal_io.ig` — `RecoverDb`
  invoked from `CheckpointDb` and `RunWalDemo`, deleting the verbatim block.
- Explicitly untouched: IO `Result` shaping (IGDB-P14), durability/LSN
  (IGDB-P18), effect→effect invocation (compile rules land with EC4, runtime
  stays observed→observed until a later gate), outcome taxonomy as types.

## DECISIONS — for the owner (ratification gates)

- **D1 — spelling.** `invoke … using` (recommended) vs `effect call …` vs a
  `composes`-derived form. Recommendation: `invoke`; keep `composes` clear
  (PROP-016 axis is structural composition, not effect sequencing).
- **D2 — diagnostic namespace.** New `OOF-EC*` family (recommended, per the P30
  one-family-per-surface policy) vs extending OOF-TY0/OOF-M*.
- **D3 — mandatory non-empty `using`.** Recommended yes: delegation visible at
  the call site, no zero-cap effectful callees exist in practice.
- **D4 — escalation matrix scope.** Compile-side full matrix (EC4 as specified)
  with runtime v0 = observed→observed only (recommended), vs compiling only the
  observed→observed pair.

## Chapter/gov registration plan (on ratification, at impl time — P29 precedent)

- ch2 §2.2 + EBNF appendix: `InvokeDecl` production.
- ch12: annex "Surface absorption across effect calls" (EC2 law).
- ch11: one paragraph — profile policy evaluates the absorbed surface.
- ch10: escalation table row for `invoke` placement (EC4).
- gov DELTA-LEDGER: one row (effect-composition delta), citing IGDB-P17 and the
  readiness packet.
- Covenant postulate map: P10/P15-adjacent rows updated when the impl closes.

## Held (restated)

Ambient/dynamic dispatch; effect plugins in the static registry; depth>1;
`invoke` of `recursive`/`service` contracts; async/parallel effects;
retry/compensation execution semantics; any runtime authority beyond the
attenuated-grant threading described above.
