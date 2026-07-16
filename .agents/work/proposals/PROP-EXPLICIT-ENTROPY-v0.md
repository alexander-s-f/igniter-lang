# PROP — Explicit Entropy (`seed` is to `random` as `as_of` is to `now`)

**Status:** DRAFT / UNNUMBERED / NOT ADOPTED
**Track:** explicit-entropy-v0
**Route:** PROPOSAL AUTHORING ONLY — no Covenant/spec/grammar/compiler/VM/stdlib/
inventory/OOF-registry change until ratified
**Date:** 2026-07-16
**Authority:** governance owns adoption, the official PROP number, OOF codes, and
any canon edit. This draft proposes; it does not adopt.
**Card:** `LANG-EXPLICIT-ENTROPY-PROP-P2` (igniter-lab)
**Predecessor:** `LANG-EXPLICIT-ENTROPY-POSTULATE-READINESS-P1` — packet
`igniter-lab/lab-docs/lang/lang-explicit-entropy-postulate-readiness-p1-v0.md`
(cited, not duplicated)
**Pressure:** `igniter-lab/apps/igniter-apps/evolve` (EV-P05/P06/P11); the live
lab SplitMix64 surface; the Covenant's time/randomness asymmetry.

---

## 0. Summary

The Covenant finished the accountability boundary for **time** — Postulate 3
(Explicit Time), the `now()` → `OOF-L6` ambient-clock refusal, and `as_of` as
the declared replacement — but left **randomness** unfinished: one PROP-filter
row (`language-covenant.md:431`, "external access (I/O, time, randomness)
requires an explicit modifier") and no postulate, no ambient-refusal rule, and
no declared-origin vocabulary.

This PROP proposes the symmetric completion: a candidate **Explicit Entropy**
postulate. Variation may enter a program only through a **declared deterministic
stream coordinate** (a seed) or through an **explicit external-entropy
observation/effect with a receipt** — never through ambient state. Determinism
is the declaration of the seed; it buys replayability and accountability, not
truth. Entropy *origin* and a downstream claim's *epistemic standing* stay
orthogonal.

The mechanism is already satisfiable in the lab: a pure, explicit-state
SplitMix64 surface exists (`igniter-stdlib/stdlib/random.ig`, native in the VM).
This PROP does not implement RNG — it proposes the LAW the existing surface
already obeys, and names the boundary a future host-entropy edge must respect.

## 1. Evidence and authority boundary (verified live 2026-07-16)

Verified against source, not memory or the inventory-scoped discovery tool (its
public wording does not currently distinguish curated registration from live
implementation — see §7):

- **Canon has no randomness postulate.** Grep of `language-covenant.md` + `spec/*`:
  `now()`→OOF-L6 is the only ambient-primitive refusal; "randomness" appears once
  (the filter row); `Seed`/`rng`/`entropy` appear zero times in the spec.
- **A live explicit-state PRNG exists — in the lab only.** `random.ig` module
  `stdlib.Random`, six functions: `rng_seed`/`rng_next`/`rng_value`/
  `rng_uniform01`/`rng_uniform_int`/`rng_bernoulli_per_million`. SplitMix64 is
  native in the VM (`igniter-vm/src/vm.rs:6338-6360`, wrapping integer
  arithmetic, reference golden `SplitMix64(0)=0xE220A8397B1DCDAF`), typechecked
  at `igniter-compiler/src/typechecker/stdlib_calls.rs:750-800` (compile codes
  `OOF-RAND1` arity / `OOF-RAND2` non-Integer). Landed by
  `LAB-STDLIB-RANDOM-PROBABILITY-READINESS-P1` / `-PRNG-WITHOUT-BITOPS-P2` /
  `-DISTRIBUTIONS-P3`.
- **Correction to the P1 packet:** the `rng_*` surface is **lab-Rust-only, NOT
  dual-toolchain.** Canon `igniter-lang` contains no `random.ig` and no `rng_*`.
  (Contrast `modulo`/`range`, which are genuinely dual-toolchain and
  inventoried.) So this PROP proposes a canon *law*; it does not thereby canonize
  the lab RNG surface — stdlib canon admission (Ruby parity + inventory) is a
  separate route, exactly like the Bytes admission precedent.
- **Inventory absence is not a complete authority or liveness verdict.** The
  normative, hand-curated inventory already contains mixed lifecycle states
  (`production-implemented`, `lab-implemented`, and `orphaned`). Therefore
  `not_found` means only "not registered in this curated inventory"; it cannot
  by itself prove non-existence, non-implementation, or a required admission.
- **`evolve` is pressure evidence only** — its `Predicted` result and declared
  assumptions are `declared_only / not_inferable`, not language-enforced
  constructor authority.

**Authorized by this draft:** this file only. Closed: Covenant/spec chapters,
parser, typechecker, emitter, VM, Machine, stdlib implementation,
`stdlib-inventory.json`, the OOF registry, and host adapters.

## 2. Proposed postulate text (D1)

> **Candidate Postulate — Explicit Entropy** *(Nondeterminism Is Declared Incompleteness)*
>
> There is no ambient entropy primitive. A value a program cannot derive from
> its declared inputs must name its source of variation explicitly — either a
> **seed** (a declared coordinate selecting a deterministic stream) or an
> **external-entropy observation/effect** carrying a receipt. Randomness is not
> an unnamed value source; it is a provenance boundary. A program that produces a
> value it cannot account for does not compile.
>
> Determinism is the declaration of the seed. A seeded computation is a pure
> function of `(declared inputs, seed)` and is replayable from its recorded
> replay identity. This buys replayability and accountability — **not** truth.
> Entropy origin and the epistemic standing of a downstream claim are separate
> axes: neither a fixed seed nor an observed entropy source silently upgrades a
> claim.

Shape is Postulate 3's, transposed one axis: **`seed` is to `random` as `as_of`
is to `now`.** Ambient `random()` is refused for the same reason `now()` is —
an ambient draw is hidden implicit state (P2) and an unaccountable value
(Axiom 2).

**D1 boundary honored:** the postulate makes NO claim about whether physical
randomness is fundamental. A seed is a *computational* stream coordinate, not a
physical branch selector. See §9 (non-normative).

## 3. Origin is not epistemic standing (D2)

Entropy **origin** is a new, small axis, defined independently of the existing
Epistemic State Machine (`covenant:375-403`):

```text
entropy_origin ∈ { declared_seed, external_entropy }
```

This proposes to ratify the posture the lab already holds rather than inventing
one: today
a draw is an **ordinary pure derived value** ("seed is data — an Integer in the
lineage; same seed → identical stream"), and the RNG surface is **not**
special-cased anywhere in the epistemic machinery (grep of `epistemic_delta.rs`
/ `epistemic_index.rs` for rng/random/prng: empty). Epistemic weight lives at
the external-entropy *receipt*, not on pure draws.

Locked non-coercion rules (No-Upward-Coercion applied without collapsing the two
axes):

- **replayability does not upgrade truth** — a claim is not more true because its
  computation is deterministic;
- **a seeded draw is a derived value** — its consumer decides whether a domain
  claim is `simulated` / `estimated` / `decided` / later `verified`; there is
  **no blanket `estimated` classifier rule** (a seeded draw feeding an exact
  combinatorial result is not an estimate);
- **an externally observed draw does not make downstream claims `observed`** —
  origin `external_entropy` describes where a byte came from, not the standing
  of what was computed from it;
- **promotion is only through the existing authorized path** — an independent
  verifier or explicit review may raise a claim's standing; the entropy source
  never does so silently.

`evolve` is the live app-path witness (`converged != verified`: reaches the
OneMax ceiling, still returns `Predicted`), and it is honest that this is an
app convention, not yet language-enforced constructor authority.

## 4. Seed surface and migration (D3)

The live RNG threads an **opaque `Integer`** — deliberately: `-PRNG-WITHOUT-
BITOPS-P2` explicitly rejected a candidate `type Rng { state: Integer }` record
("replaced by the scalar pair"; SplitMix64 splits into additive step +
stateless finalizer, and there is no record-returning stdlib precedent). The
`Integer` carries the `u64` state bit-reinterpreted and is documented "opaque —
do not treat it as a meaningful number."

Three routes compared:

| Route | What | Consequence |
|---|---|---|
| 1. keep `Integer` forever, provenance in receipts only | no in-language type change | zero ABI churn; but the *value* threaded through source carries no provenance — provenance lives only at the receipt boundary |
| 2. introduce nominal `Seed`/`SeedProvenance` now | new canon type, migrate the 6 functions | breaks the landed lab ABI + golden tests; and the surface is lab-Rust-only, so a nominal type would need Ruby-canon parity it does not have — premature |
| **3. staged: keep the live `Integer` ABI; add provenance as a receipt-level protocol boundary first** | the threaded stream value stays `Integer`; a `Seed`/`SeedProvenance` shape lives in the *receipt/replay-identity* layer, not in the hot path | **chosen** — no ABI break, no golden churn; provenance is captured where accountability needs it (the receipt); an in-language nominal `Seed` type is deferred to a separate readiness card, taken up only under real pressure |

**Chosen: Route 3.** Migration is *designed, not forced*. The `Seed` /
`SeedProvenance` shape below is a **receipt/protocol** shape (D4), not a
replacement for the threaded `Integer` state. A future nominal in-language `Seed`
type remains an open, separately-gated decision
(`LANG-SEED-PROTOCOL-MIGRATION-READINESS-P4`).

```text
# Receipt/protocol shape (NOT the threaded state value):
SeedProvenance ∈ {
  OperatorChosen,                     # a human/operator fixed the seed
  DerivedFrom { receipt_ref },        # chained from a prior run's receipt
  ExternalEntropy { receipt_ref }     # drawn at the host edge (see D6)
}
```

## 5. Replay identity (D4)

**Seed alone is insufficient.** The minimum complete replay tuple:

```text
replay_identity = {
  artifact_digest,                  # the compiled program (already an Igniter identity)
  algorithm_id + stdlib_version,    # WHICH PRNG + which stdlib produced the stream
  seed,                             # the declared coordinate
  params_digest,                    # generations / sample counts / bounds / etc.
  external_entropy_receipt_ref?     # present iff entropy_origin = external_entropy
}
```

Why seed alone fails, concretely: `-PRNG-WITHOUT-BITOPS-P2` bumped
`STDLIB_VERSION` 0.1.2 → 0.1.3 — the *same seed* under a different stdlib
algorithm version can yield a different stream, so the stream is only reproducible
against a pinned `algorithm_id + stdlib_version`. Likewise a changed
`params_digest` (e.g. `evolve`'s generations/λ) or `artifact_digest` reproduces a
different run. Any of these changing **invalidates** the replay identity. This
promotes `evolve`'s app-level "replay identity = artifact + seed + params" to a
receipt protocol, with the two additions the app could not express: the
algorithm/stdlib pin and the external-entropy receipt reference.

Cross-ISA note (kept honest): SplitMix64 here is integer-only wrapping
arithmetic, so bit-identity across architectures is *structurally* expected — but
this PROP asserts only what is proven (same-machine determinism); cross-ISA
bit-identity remains a separate hardware-proof item (the emergence `det_*`
discipline), not a claim of this proposal.

## 6. Ambient refusal (D5)

Compared with `now()`/OOF-L6 rather than copied. Two facts shape the decision:

- there is **no ambient `random()`** in the surface today — it is explicit-state
  by construction, so an authored `random()` is currently just an unknown-call
  failure;
- an `OOF-RAND` family already exists at compile time (`OOF-RAND1` arity /
  `OOF-RAND2` non-Integer), but runtime domain errors are uncoded strings and
  there is no ambient-spelling refusal.

**Proposed:** the PROP **reserves** a diagnostic family for reserved ambient
spellings (`random()`, `rand()`, and any future ambient draw), parallel to
OOF-L6, so that if a source surface ever tempts an ambient draw it is refused by
name, not merely as an unknown call. This draft does **not** allocate a code or
touch the registry (governance owns it; CR-002). Until a source surface actually
proposes `random()`, the unknown-call failure plus the postulate is operationally
sufficient — the dedicated code is the *symmetry* with the clock, filed for the
smallest enforcement slice (`LANG-EXPLICIT-ENTROPY-AMBIENT-REFUSAL-P3`), gated on
ratification.

## 7. Host entropy boundary (D6)

This proposes the boundary `LAB-STDLIB-RANDOM-PROBABILITY-READINESS-P1` already
chose: external entropy is a **host capability**, modeled on `now()`/OOF-L6,
never pure stdlib. The minimum language↔host contract:

- **host owns** the physical/provider implementation (hardware RNG, OS entropy,
  device, service);
- **language owns** the explicit declaration and the result/provenance *shape*
  (an `external_entropy` observation/effect with a typed result);
- the **receipt records the external origin** (`ExternalEntropy { receipt_ref }`)
  — a host draws a seed **once** at the edge, the receipt captures it, the pure
  PRNG expands it, and replay re-injects the recorded seed for an identical
  stream (the pure graph never touches ambient entropy);
- **no secret/provider configuration enters `.ig` source**;
- the host-entropy implementation is a **separate lane**
  (`LAB-HOST-ENTROPY-CAPABILITY-READINESS-P1`), not designed here — this PROP
  designs no plugin protocol or provider taxonomy.

## 8. Rejected alternatives

| # | Alternative | Verdict (purity / replay / provenance / honesty / ergonomics / live-RNG compat) |
|---|---|---|
| 1 | Status quo (one filter row, no postulate) | Reject as end state: leaves an unaccountable value class with no refusal and no origin vocabulary; the exact gap `evolve` hand-worked. |
| 2 | Model every random draw as an effect | Reject as the general rule: correct that entropy is external, but most stochasticity is a *pure* function of a seed (no world touched). Framing every draw as I/O overstates the effect surface and would make the live pure `rng_*` illegal. Keep effects for the genuine-entropy edge only (D6). |
| 3 | **Explicit seed for pure streams + host entropy at the effect edge** | **Chosen.** Pure-by-default (seed is an input, not an effect); replay via the full tuple (D4); provenance orthogonal to standing (D2); compatible with the live scalar-Integer RNG (Route 3, D3); genuine entropy stays a receipted host draw (D6). |
| 4 | Ban stochastic programs | Reject: the language already hosts them (`evolve`, emergence Kuramoto, the live RNG). The goal is accountability, not prohibition. |
| 5 | Hidden runtime-global RNG seeded by operator config | Reject hardest: reintroduces exactly the ambient hidden state (P2) and unaccountable value (Axiom 2) the postulate forbids; non-replayable per-graph; the opposite of explicit threading. |

## 9. Physics framing (short, non-normative — not part of the law)

The proposal is interpretation-independent and makes no physics claim. Whether
physical randomness is fundamental (Copenhagen), merely apparent under
determinism (Bohm / many-worlds — where "randomness" is self-locating
uncertainty), or otherwise, the language's obligation is identical: no value
enters a program unaccountably; variation is a declared seed or a declared
observation. The seed is a computational coordinate; it is explicitly **not** a
claim that a program selects a physical branch. This section is context, not
normative content.

## 10. Enforcement stages

1. **Postulate adoption** (governance) — the law enters the Covenant with an
   enforcement status of `spec_candidate` → `planned PROP`, symmetric with P3's
   registry row for time.
2. **Ambient refusal** — the smallest compiler slice: reserve/allocate the
   ambient-spelling code (governance-numbered), parallel to OOF-L6.
3. **Replay-identity receipt fields** — `algorithm_id + stdlib_version + seed +
   params_digest (+ external receipt)` as receipt schema.
4. **Origin axis** — `entropy_origin` recorded, kept orthogonal to standing; no
   blanket `estimated`.
5. **Host entropy** — separate readiness/implementation lane.
6. **Seed typing** — optional, pressure-gated; the staged `Integer`-ABI route
   means this never blocks the above.

## 11. Governance questions requiring ratification

- **G1 — Postulate number/wording.** Governance alone assigns the number and
  finalizes wording; this draft intentionally proposes no candidate number.
- **G2 — OOF code.** The reserved ambient-refusal code's registry number and
  whether it joins the `OOF-L*` "Law" family or the existing `OOF-RAND*` family.
- **G3 — Canon admission of the RNG surface.** The postulate is a law; the live
  `rng_*` surface is lab-Rust-only. Does canon admit a randomness stdlib surface
  (with Ruby parity + inventory) as the conformance vehicle, or does the law
  stand while the surface remains lab evidence? (Bytes-admission precedent.)
- **G4 — Origin vocabulary.** Ratify `{declared_seed, external_entropy}` as the
  closed origin set, or leave room for a third named origin.
- **G5 — Replay-identity ownership.** Which existing receipt schema carries the
  replay tuple, and whether `algorithm_id`/`stdlib_version` are already present.

## 12. Named implementation cards (all gated on ratification)

- `LANG-EXPLICIT-ENTROPY-AMBIENT-REFUSAL-P3` — smallest compiler/canon
  enforcement slice (the ambient-spelling refusal), **after** ratification.
- `LANG-SEED-PROTOCOL-MIGRATION-READINESS-P4` — reconcile a nominal `Seed` type
  with the live opaque-`Integer` ABI, only if D3 pressure escalates beyond
  receipt-level provenance.
- `LAB-HOST-ENTROPY-CAPABILITY-READINESS-P1` — the explicit external-entropy
  edge (host capability + receipt); separate lane.
- `LANG-LANGUAGE-SURFACE-DISCOVERY-READINESS-P1` — model curated admission and
  source/compiler/VM liveness as separate planes, so `rng_seed` is reported as
  live-but-unregistered rather than flattened to either `not_found` or canon
  admission. This route may recommend inventory work, but must not auto-admit a
  lab-only surface.

---

**Boundary restated:** DRAFT / UNNUMBERED / NOT ADOPTED. No Covenant, spec,
grammar, compiler, VM, stdlib, inventory, or OOF-registry change is made or
implied by this file. Adoption, numbering, OOF allocation, host entropy, and
inventory hygiene are separate, governance-gated routes.
