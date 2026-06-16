# LANG-EFFECT-NAME-PARITY-P2 — proof: effect names are labels, not authority selectors

**Card:** `LANG-EFFECT-NAME-PARITY-P2` (implementation / dual-toolchain parity / language-core).
Follows `LANG-EFFECT-CAPABILITY-SURFACE-P1`. **No profile/via, no machine code, no live IO, no new
language fields.**

## Change (narrow)

`igniter-lab/igniter-compiler/src/classifier.rs` — **removed the hardcoded effect-name allowlist**
(the `if name != "read_file" && … && name != "write" { … E-IO-EFFECT-UNKNOWN … }` block that
previously sat in the effect-processing pass). Effect names are now LABELS/verbs; ANY well-formed
name is accepted, matching the Ruby canon. The capability binding remains the actual authority
declaration. One block removed; nothing else touched.

## Live parity (both compilers, this session)

| `effect <e> using c` | Ruby (canon) | Rust (lab, post-change) |
|---|---|---|
| `read_file` | ok | ok |
| `connect` | **ok** | **ok** (was E-IO-EFFECT-UNKNOWN) |
| `charge_vendor` | ok | ok |
| `sync_customer` | ok | ok |
| `connect using missing` (undeclared cap) | OOF-M4 | **E-IO-CAP-UNKNOWN** (still fails) |
| `capability d` with no effect | OOF-M5 | **E-IO-EFFECT-UNDECLARED** (still fails) |

Ruby via `ruby -I lib bin/igc compile`; Rust via the relaxed classifier
(`tests/effect_name_parity_tests.rs`, 4/4 green).

## Answers (the 6 questions)

1. **Where was the allowlist?** `igniter-compiler/src/classifier.rs`, effect-processing pass
   (former lines ~324–332), emitting `E-IO-EFFECT-UNKNOWN`. **Removed.**
2. **Label preserved in IR?** YES. The emitter builds `effects: [{name, capability_ref}]` from the
   parsed decl independently of the (removed) name check (`emitter.rs:425–441`). Proven:
   `effect_label_preserved_in_ir` — the SIR for `effect charge_vendor using c` contains
   `"charge_vendor"`.
3. **Diagnostics remaining?** ALL except the name allowlist: `E-IO-CAP-UNKNOWN` (effect → undeclared
   capability), `E-IO-EFFECT-UNDECLARED` (capability with no effect), `E-IO-AMBIENT-BLOCKED` /
   `E-IO-CAP-MISSING` (IO-call gates), `OOF-M1` (privileged token), parser `OOF-P0` (malformed
   declaration). Only `E-IO-EFFECT-UNKNOWN` is gone.
4. **Does Ruby already match?** YES — Ruby never had the allowlist (`typechecker.rb`: effect binding
   → `Unit`, any name). Re-confirmed live (`connect` → ok).
5. **dev-tutorial note?** YES — `igniter-lang/docs/dev-tutorial.md` row "Effect surface" said Rust
   limits effect names; **updated** to "dual-clean for any well-formed effect name (P2)".
6. **Does this alter host execution?** **NO.** The machine keys execution by capability **TYPE** +
   passport (`service_loop::discover_effect_surface` → executor id = capability type name;
   `run_service` never reads the effect verb). The effect label was already a non-authority label in
   the host model. No machine code changed.

## Acceptance

- ✅ `effect connect using c` is Ruby ok and Rust ok.
- ✅ ≥2 non-read/write labels dual-clean (`connect`, `charge_vendor`, `sync_customer`, `notify_slack`).
- ✅ IR/SIR still records the effect label.
- ✅ undeclared (`E-IO-CAP-UNKNOWN`) / unbound (`E-IO-EFFECT-UNDECLARED`) capability diagnostics fire.
- ✅ `profile`/`via` untouched (still Rust-OOF-G1, Ruby-only).
- ✅ No machine code changes; no runtime authority inferred from the effect label.

## Blast radius (honest)

- **`cargo test` (igniter-compiler):** the effect/capability area + the new parity proof (4/4) pass.
  The 4 failing `loop_conformance_tests` are **PRE-EXISTING and unrelated** — they fail identically
  on a clean tree with my change stashed (10 passed / 4 failed, loop IR tests, no effect path).
- **3 cross-track MANUAL proof runners** (`ruby proofs/*.rb`, NOT cargo tests) asserted the removed
  `E-IO-EFFECT-UNKNOWN` and will report FAIL on re-run until refreshed:
  `igniter-compiler/proofs/io_capability_schema_generalization.rb` (iocg_8),
  `igniter-vm/proofs/io_observability_e2e.rb` (iodbg_3),
  `igniter-vm/proofs/io_passport_static_loader_alignment_hardening.rb` (ioh_3). They belong to other
  tracks (LAB-STDLIB-IO-P7 / observability-debugger / passport-loader-hardening) — flagged for owner
  refresh (a background task was spawned), NOT silently rewritten here (out of this card's authority).
- **Descriptive lab-docs** (`lab-docs/stdlib/*`, the lab-storage-capability finding) describe the old
  allowlist as a finding — now stale, harmless, noted.

## Closed surfaces

No `profile`/`via`. No host/igniter-machine changes. No live IO. No app migrations. No new
authority/idempotency/receipt language fields. No diagnostics overhaul beyond removing the
effect-name allowlist.

## Next (named, not done)

Owner refresh of the 3 cross-track unknown-effect proof runners to the parity expectation; optional
reconciliation of the OOF-M* (Ruby) vs E-IO-* (Rust) diagnostic CODE vocabulary for the two shared
capability-binding cases (undeclared / unbound) — a separate, small, dual-toolchain card.
