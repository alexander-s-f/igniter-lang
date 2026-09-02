# Chapter 12: Effect Surface

Status: proposed (body-decl subset experiment-pass via PROP-035 v0)
Stage: 3 (Phase 2)
Source PROP: PROP-035 — authored + experiment-pass 2026-06-07
  (`.agents/work/proposals/PROP-035-effect-surface-io-capability-v0.md`,
  proof 64/64 `experiments/io_capability_proof/`)
Governance: META-EXPERT-013
Delta tracking: igniter-gov `DELTA-LEDGER.md` rows D-001 / D-005 / D-009
Last updated: 2026-07-07

> **Proposed, all seven fields implemented as parsed metadata.** PROP-035 v0's scope was the
> body-level `capability` / `effect ... using` declarations plus structural
> checks — NOT the seven-field Effect Surface this chapter defines. Completion
> slices have since landed **all seven fields** as dual-toolchain parsed
> metadata in the unified `effect_surface_v1` IR object emitted by BOTH
> compilers (Ruby's former `effect_surface_v0_stub` was renamed by
> IR-UNIFICATION-P3): `receipt`/`failure` (18/18 + 8/8), `idempotency`
> (16/16 + 9/9), `affects` (12/12 + 8/8), `authority` (12/12 + 9/9;
> declared intent only — see §12.3), `compensation` (17/17 + 8/8), and
> `reversibility` (15/15 + 8/8; no default, absent ⇒ null);
> proof anchors and per-slice caveats in §12.5. Required-field completeness now
> has a **gated warning** layer: `required_effect_surface` (default OFF) emits
> `OOF-M17` for effect-family contracts missing a required field (19/19 + 9/9;
> LANG-EFFECT-SURFACE-REQUIRED-FIELDS-P28) — a fresh code, NOT the target-table
> OOF-M2 (retired). Profile-policy enforcement has begun in the `OOF-PROF*`
> namespace (ch11 §11.4): the target-table OOF-M4 rule ("`idempotency none` in a
> retry-enabled profile") is implemented as **OOF-PROF4** (PROP-048 /
> LANG-PROFILE-IDEMPOTENCY-RETRY-P31, Ruby-canon, hard error); target OOF-M5
> ("reversibility exceeds profile maximum") is implemented as **OOF-PROF5**
> (PROP-048 / LANG-PROFILE-MAX-REVERSIBILITY-P32 — which encodes the ch12
> reversibility scale ordering for the first time). The target-table OOF-M4/M5
> codes stay retired prose (they collide with implemented PROP-035 structural
> codes). Profile `allowed_effects` (OOF-PROF1) also landed — it restricts a
> bound contract's `affects` targets (PROP-048 / LANG-PROFILE-ALLOWED-EFFECTS-P35,
> Ruby-canon, hard error). Profile `requires_authority` (OOF-PROF2) also landed —
> a bound contract must declare a ch12 `authority` role the profile requires
> (PROP-049 / LANG-PROFILE-REQUIRES-AUTHORITY-P41, Ruby-canon, hard error); it is
> declaration-consistency only and **grants no runtime authority** (the runtime
> `authority_ref` → host `AuthorityPolicy` line stays separate and HELD). Profile
> loop-class (OOF-PROF3) also landed (PROP-048 / LANG-PROFILE-LOOP-CLASS-P42, live
> loop vocabulary, hard error) — **the ch11 §11.4 profile-policy set
> (OOF-PROF1–6) is now complete Ruby-canon**. Still open: the seven-outcome
> taxonomy as TYPES (outcomes are proven at the host boundary, not as language
> types). Escalation of OOF-M17 from warn to error and default-ON stay explicit
> later decisions; Rust profile parity stays HELD (P33). Authority host-policy
> resolution exists as proof/loopback machine wiring only — no production
> runner enforces it (public bind stays human-gated). Chapter status stays
> `proposed`; it advances to `accepted` when the full surface regression
> suite passes.
>
> Lab evidence (igniter-machine capability-IO receipts/reconcile; softphone
> P6–P8 unknown→reconcile loop) proves the outcome semantics at the host
> boundary. That is design evidence for this chapter — not canon acceptance.

---

## § 12.1 Overview

An `effect`, `privileged`, or `irreversible` contract must declare its Effect
Surface — a set of seven fields that make the contract's consequences explicit and
compiler-verifiable.

```igniter
effect contract ChargeCustomer(customer_id: String, amount: Decimal[2], currency: String)
  -> receipt: ChargeReceipt
  affects  external PaymentGateway.ChargeEndpoint
  authority billing_operator
  reversibility :compensatable
  idempotency key content_hash(customer_id, amount, currency)
  receipt  ChargeReceipt
  failure  PaymentFailure
  compensation RefundCustomer
  via audited_billing
{
  ...
}
```

The Effect Surface separates the *declaration of consequence* from the *body of
computation*. A reader can understand the full external impact of a contract by
reading the surface alone, without inspecting the body.

`pure` and `observed` contracts do not carry an Effect Surface. `observed` contracts
may carry `receipt` and `failure` for the observation result, but the remaining
fields are not applicable.

---

## § 12.2 Grammar

```
effect-surface ::= affects-clause
                   authority-clause?
                   reversibility-clause
                   idempotency-clause
                   receipt-clause
                   failure-clause
                   compensation-clause?

affects-clause       ::= "affects" ("external" | "internal") qualified-name
authority-clause     ::= "authority" ident
reversibility-clause ::= "reversibility" reversibility-value
reversibility-value  ::= ":reversible" | ":compensatable" | ":refundable"
                       | ":append_only" | ":irreversible" | ":destructive"
idempotency-clause   ::= "idempotency" ("key" expr | "natural" | "none")
receipt-clause       ::= "receipt" type-ref
failure-clause       ::= "failure" type-ref
compensation-clause  ::= "compensation" contract-ref | "no_compensation"
```

The Effect Surface appears between the return type and the `via` clause in a
contract declaration.

**Effect call (PROP-050, ratified 2026-07-08; v0 implemented — see § 12.7):**

```
invoke-decl   ::= "invoke" ident "=" contract-name "(" (expr ("," expr)*)? ")"
                  "using" ident ("," ident)*
contract-name ::= ident ("." ident)*
```

`invoke` is a BODY-LEVEL declaration (effect altitude — ordered with effects in
declaration order). The `using` clause is mandatory and non-empty. The callee
is a literal (possibly module-qualified) contract name; dynamic dispatch stays
closed. `call_contract` remains the pure call — permanently. (The
`contract("...")` spelling was retired by LANG-EFFECT-CALL-NATURAL-SUGAR-P1,
2026-07-13; the retired form draws one targeted `OOF-EC6` migration
diagnostic.)

The `invoke` binding receives the callee's single result value: a callee
declaring two or more outputs is refused at declaration by `OOF-RET1` (Ch2
single-output law), so no invoke path ever silently receives output zero of a
multi-output contract.

---

## § 12.3 The Seven Fields

### affects

Names the external or internal system that the contract mutates. Required for all
three modifiers. The `external` keyword signals that the named system is outside
the current igniter-lang application boundary.

### authority

Names the authority requirement of this contract. Required for `privileged`
and `irreversible`. Optional for `effect`.

> **Declaration vs enforcement (split 2026-07-06,
> LANG-EFFECT-SURFACE-AUTHORITY-SPEC-SPLIT-P7).** The clause declares
> `authority_ref` — a SOURCE-DECLARED intent/requirement reference, following
> the CR-003 pattern (a source-level intent record, like `profile_binding`).
> **Parsing or IR presence of `authority_ref` must NOT be read as proof that
> any runtime authority check happened.** Host enforcement is a HELD runtime
> responsibility: it activates only when an explicit, reviewed mapping exists
> from the source reference to one of —
> a passport subject/scope/capability requirement;
> a PROP-030-style executor approval token requirement;
> or another reviewed host-policy binding.
> **Ratified mapping model (2026-07-06,
> LANG-EFFECT-SURFACE-AUTHORITY-GOVERNANCE-P9, decision A — model F of the
> P8 readiness packet, unchanged):**
> - source domain: `authority_ref` is a **bare role ident**
>   (`billing_operator`) — no dotted refs, no host-policy keys, no secrets;
> - compile-time responsibility: syntax, placement, and IR emission ONLY —
>   the compiler never resolves roles;
> - runtime responsibility (**HELD** until the host-policy slice is
>   separately authorized): the HOST policy table resolves role → required
>   passport scope(s) on the existing `verify_passport` seam; a **missing
>   mapping fails closed** (refusal, no receipt — never silent allow);
>   receipts record the declared role alongside the checked authority digest;
> - a PROP-030 executor approval token remains an ORTHOGONAL
>   executor/artifact gate, not the role mapping;
> - a future profile PROP may constrain the allowed role set
>   (ch11's `requires_authority` prose — currently unauthored).
>
> With this model ratified: **the parser may accept `authority_ref` as
> declared intent only** (route: LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10);
> host role→scope enforcement remains held until the runtime/host-policy
> slice lands. Parser acceptance is NOT runtime enforcement — the
> declaration-vs-enforcement rule above stays load-bearing.

### reversibility

Declares where the action sits on the reversibility scale:

| Value | Meaning |
|-------|---------|
| `:reversible` | Can be undone without consequence |
| `:compensatable` | Cannot be undone, but can be compensated |
| `:refundable` | Monetary or resource compensation is possible |
| `:append_only` | Data can be appended but not deleted |
| `:irreversible` | No compensation is possible |
| `:destructive` | Data is deleted or permanently altered |

### idempotency

Declares the idempotency contract for this operation. Required for all three
modifiers. Non-idempotent operations under automatic retry are a compile-time error.

- `key expr`: the operation is idempotent when the key expression matches a prior call
- `natural`: the operation is naturally idempotent (e.g., `SET x = 5`)
- `none`: explicitly declares non-idempotency; prohibited in retry-enabled profiles

### receipt

Names the type of audit proof emitted when the operation completes. The receipt
is returned as part of the contract's output.

### failure

Names the error type emitted when the operation fails. This is not an exception —
it is a declared output variant. The full error taxonomy includes seven possible
outcomes:

| Outcome | Description |
|---------|-------------|
| `succeeded` | Operation completed as expected |
| `failed` | Operation returned a known error |
| `partial` | Operation partially completed |
| `timed_out` | Time limit exceeded — outcome unknown |
| `unknown_external_state` | Request sent, no confirmation received |
| `compensated` | Failure triggered compensation |
| `cancelled` | Operation was cancelled before completion |

`unknown_external_state` is not a failure. It signals that a reconciliation pass
is required before retrying.

### compensation

Names the contract that reverses or compensates for the operation if it must be
undone. Required for `irreversible` contracts unless `no_compensation` is declared.
Optional for `effect` and `privileged`.

---

## § 12.4 Reversibility Scale

```
reversible < compensatable < refundable < append_only < irreversible < destructive
```

A profile may declare a maximum reversibility level. An `irreversible` contract
in a profile that only permits `compensatable` is a compile-time error (OOF-M2).

---

## § 12.5 OOF Rules

| Code | Condition | Severity |
|------|-----------|----------|
| OOF-EC1 | `invoke` callee unknown; or `pure` (use `call_contract`); or a recursion-class callee (`recursive`/`service`/`convergent`/`fuel_bounded`, held in v0); or self-invocation | error |
| OOF-EC2 | surface absorption violation — a callee effect (verb + declared capability TYPE) or `affects` target has no covering caller declaration | error |
| OOF-EC3 | attenuation mismatch — callee capability slot unmatched by a same-TYPE `using` name; a `using` name matching no slot (over-grant); a `using` name not a declared caller capability | error |
| OOF-EC4 | escalation placement — `pure` caller never invokes; `observed` → `observed` only; `effect`/`privileged`/`irreversible` → `observed`\|`effect`; all other caller classes fail closed | error |
| OOF-EC5 | depth — the callee itself contains an `invoke` (v0 is depth-1) | error |
| OOF-EC6 | form/position — malformed `invoke` (incl. missing or empty `using`); `invoke` in loop-body position; a **direct host-IO call** (`stdlib.IO.*` / `stdlib.net.request`) inside an iteration context — a collection-HOF lambda body, or a managed-loop body (any nesting, incl. under `if`/`match`); **or an app-local helper `def` call whose call graph transitively reaches such a host-IO sink, in that same iteration context**. Remedy: build a pure `Collection[EffectIntent]`, then perform ONE declaration-position `invoke` outside the iteration. Top-level direct or helper IO is unaffected. | error |
| OOF-M17 | `effect/privileged/irreversible` missing a required Effect Surface field, under the `required_effect_surface` completeness gate | warn |
| OOF-M3 | `irreversible` without `compensation` or `no_compensation` | warn |
| OOF-M4 | `idempotency: none` used in a retry-enabled profile | **implemented as `OOF-PROF4`** (ch11 §11.4; PROP-048/P31, hard error) — this M4 code stays retired prose |
| OOF-M5 | `reversibility` exceeds profile maximum | **implemented as `OOF-PROF5`** (ch11 §11.4; PROP-048/P32, hard error) — this M5 code stays retired prose |

> **OOF-EC6 host-IO placement fence — IMPLEMENTED (2026-07-13,
> LANG-EFFECT-ITERATION-DIRECT-IO-FAIL-CLOSED-P2).** In addition to the malformed
> `invoke` and `invoke`-in-loop cases, `OOF-EC6` now also fences a **direct
> host-IO call** (`stdlib.IO.*` / `stdlib.net.request`; membership from the live
> `IO_STDLIB_FNS` / `capability_mode` census, never a name substring) that occurs
> inside an ITERATION context — a collection-HOF lambda body, or a managed-loop
> body (finite, budgeted, or service; any nesting, including under `if`/`match`).
> Reads are fenced as well as writes (reads also need durable observation
> lineage). Exactly one root `OOF-EC6` per offending call; derivative
> Unknown/output noise is suppressed via `blocking_rule_present`. Earlier root
> laws are preserved: an unknown `stdlib.IO.*` op, a capability type/mode error
> (`E-IO-CAP-*`), or a malformed `invoke` keep their own codes. **Top-level direct
> IO is unaffected** and keeps its receipt. Enforced in the Ruby canon
> typechecker, the Rust lab classifier, and — as an independent backstop over
> hand-built/external SIR — the VM compiler (refused before any bytecode executes;
> the readiness row L2 "one byte written, `observations: 0`" shape is now
> unreachable). This closes the placement slice only; effect-iteration syntax
> stays HELD (`LAB-EFFECT-INTENT-BULK-WRITE-PROOF-P1`).
>
> **Extended to app-local helper indirection — IMPLEMENTED (2026-07-13,
> LANG-EFFECT-ITERATION-HELPER-WRAP-FAIL-CLOSED-P3).** The fence now covers not
> only a *direct* host-IO call but also a call to an app-local helper `def` whose
> **call graph transitively reaches** a host-IO sink (same census), when that call
> occurs in an iteration context. Reachability is decided by a deterministic
> transitive summary over the program's `def` call graph (Tarjan SCC; cyclic
> helper groups terminate and share one summary value) — the SAME summary machinery
> that `OOF-M1` uses to catch a `pure` contract laundering I/O through a helper (one
> analyzer, two consumers — dual-true after PROP-051: Ruby gains the `OOF-M1`
> transitive-laundering consumer over the same one-graph summary, so both
> toolchains now run both consumers; seeded by the shared host-IO census incl.
> `stdlib.net.request`). The helper diagnostic is one root `OOF-EC6` at the helper
> call site, naming the helper, the iteration locus, the transitively-reached host
> IO, and the same rewrite. Ownership is preserved: `OOF-M1` keeps the pure-laundering
> case; a genuinely unknown callee keeps its own resolution diagnostic; a top-level
> helper call keeps its receipt. Enforced in all three layers (Ruby canon, Rust lab,
> and the VM backstop, which builds the static helper summary from `functions[]` and
> refuses one-hop / two-hop / cyclic helper indirection before any bytecode). Scope
> stays statically-known app-local `def` indirection — **no** dynamic helper target,
> **no** cross-package effect inference, **no** effect annotations.
> **Module-scoped resolution (PROP-051).** App-local `def` resolution is
> module-scoped and position-independent: a helper visible in the caller's
> module resolves everywhere, including HOF-lambda position, in both
> toolchains. A name NOT visible in the caller's module refuses
> `OOF-TY0` (`Unknown function: <name>`) — out-of-module `def`s do not
> resolve; cross-module calls stay closed. The earlier Ruby-canon behavior
> (app-local `def`s not resolved inside lambdas, leaving a pre-existing
> "Unknown function" diagnostic on non-IO-reaching helpers) is superseded.
> `OOF-EC6` remains a NON-pure-contract fence only (Ruby's gate aligned to
> `modifier != "pure"`); pure-contract laundering stays owned by `OOF-M1`.

> The target-prose row "OOF-M2 — missing required Effect Surface fields (error)"
> is **RETIRED**: implemented `OOF-M2` is PROP-035's structural
> pure-with-capability check, and required-field completeness landed under a
> FRESH code (`OOF-M17`) as a **gated warning**, not a hard error — see the
> numbering decision and the P28 bullet below.

> **Numbering decision (2026-07-06, LANG-EFFECT-SURFACE-RECEIPT-FAILURE-P1 D1).**
> The implemented v0 allocation is KEPT: OOF-M2/M4/M5 remain PROP-035's
> capability/effect_binding **structural** checks (pure-with-capability /
> undeclared-capability-ref / unbound-capability), dual-toolchain proven. The
> table above is this chapter's TARGET-requirement prose; its rules will receive
> fresh codes as each field slice lands (do not read table codes as implemented).
> Codes allocated so far by completion slices: **OOF-M6** — Effect Surface
> metadata illegal placement (pure contract; observed for `idempotency` and
> `affects`) or duplicate clause; **OOF-M10** — `receipt`/`failure` references
> an unresolvable type; **OOF-M11** — malformed `idempotency` mode
> (parse-time); **OOF-M12** — malformed `affects` scope (parse-time);
> **OOF-M13** — malformed `authority` reference form (dotted ref or string
> literal; parse-time); **OOF-M16** — malformed/unknown `reversibility` value
> (parse-time); **OOF-M17** — missing required Effect Surface field under the
> `required_effect_surface` completeness gate (typechecker, **warn**;
> LANG-EFFECT-SURFACE-REQUIRED-FIELDS-P28). This **retires** the target-table
> "OOF-M2 = missing required fields" prose: M2 stays PROP-035 structural, and
> completeness is a fresh gated warning. The profile-policy target rows
> (OOF-M4 idempotency-none-in-retry-profile, OOF-M5 reversibility-exceeds-max)
> likewise stay target-prose and landed as **fresh profile-policy codes**
> `OOF-PROF4/OOF-PROF5` in ch11 — their table codes collide with implemented
> PROP-035 structural M4/M5.
> (**OOF-M3 resolution history:** the PROP-035 card once deferred "M3 =
> authority resolution" to "PROP-034" — a numbering-era ghost (PROP-034 is
> Output Evidence Syntax, owns OOF-M9), later re-pointed at PROP-030
> territory. **Superseded 2026-07-07 by P22:** OOF-M3 is now LIVE as the
> target-table rule — irreversible without compensation/no_compensation,
> WARN. Authority-resolution enforcement, if it ever lands, takes a FRESH
> code with the PROP-030/PROP-040 wave — M3 is no longer available to it.
> OOF-M7/M8 remain taken by PROP-040 profile binding.) Tracked as ledger
> row D-009 in igniter-gov `DELTA-LEDGER.md`.
>
> **Implemented so far (2026-07-06):**
> - `receipt <TypeRef>` / `failure <TypeRef>` parse as body-level Effect
>   Surface metadata in both toolchains; typechecker resolves the referenced
>   type (declared type/variant or builtin scalar) and fails closed otherwise;
>   SemanticIR carries the parsed `receipt_type`/`failure_type` (historically
>   Ruby `effect_surface_v0_stub`; Rust `contract_ir` fields — both unified
>   into `effect_surface_v1` by the IR-unification bullet below). Proofs:
>   `experiments/effect_surface_receipt_failure_proof/` (18/18) + lab
>   `tests/effect_surface_receipt_failure_tests.rs` (8/8).
> - `idempotency key <expr>` / `natural` / `none` parse as body-level metadata
>   in both toolchains (LANG-EFFECT-SURFACE-IDEMPOTENCY-P2); the key expression
>   types through normal inference; placement = effect/privileged/irreversible
>   only (pure AND observed refused — idempotency governs mutation retry);
>   SemanticIR carries parsed `idempotency_mode`/`idempotency_key_expr`.
>   Proofs: `experiments/effect_surface_idempotency_proof/` (16/16) + lab
>   `tests/effect_surface_idempotency_tests.rs` (9/9). The §12.5 target rule
>   "`idempotency: none` in a retry-enabled profile" is now implemented in the
>   profile-policy namespace as **OOF-PROF4** (Ruby-canon; see ch11 §11.4 and
>   LANG-PROFILE-IDEMPOTENCY-RETRY-P31).
> - `affects external|internal <qualified-name>` parses as body-level metadata
>   in both toolchains (LANG-EFFECT-SURFACE-AFFECTS-P5); the dotted target
>   preserves source spelling; placement = effect/privileged/irreversible only
>   (pure AND observed refused — affects names a mutation target); parsed
>   values replace the former `effect_surface_v1` constants, absent clause
>   keeps the documented defaults (`external` / `IO.Capability`). Profile
>   `allowed_effects` enforcement stays **HELD** (profile policy). Proofs:
>   `experiments/effect_surface_affects_proof/` (12/12) + lab
>   `tests/effect_surface_affects_tests.rs` (8/8).
> - `authority <ident>` parses as body-level DECLARED-INTENT metadata in both
>   toolchains (LANG-EFFECT-SURFACE-AUTHORITY-PARSER-P10, under the ratified
>   model F): bare role symbol only — dotted refs and string literals fail
>   closed with OOF-M13; placement = effect/privileged/irreversible only
>   (pure AND observed refused, OOF-M6); `effect_surface_v1.authority_ref`
>   carries the parsed ident, absent → null. **Parser acceptance is NOT
>   runtime enforcement** — the declaration-vs-enforcement rule in §12.3
>   stays load-bearing; runtime status is the next bullet. Proofs:
>   `experiments/effect_surface_authority_proof/` (12/12) + lab
>   `tests/effect_surface_authority_tests.rs` (9/9).
> - Host-side role→scope resolution has a machine PROOF
>   (LANG-EFFECT-SURFACE-AUTHORITY-HOST-POLICY-P12, the runtime half of the
>   ratified model F): igniter-machine's host-constructed `AuthorityPolicy`
>   resolves the declared role to required passport scope(s) on the UNCHANGED
>   `verify_passport` seam; a declared role with no mapping **fails closed**
>   (`AuthRefusal::UnmappedAuthorityRole`, before the executor, no receipt);
>   receipts gain additive `declared_authority_role` / `resolved_scopes` /
>   `authority_policy_digest`; null `authority_ref` is a nil-safe passthrough.
>   **Proof/loopback only — NOT production-wired**: the follow-on slices
>   (host-config P14, runner-wire P16, prod-gate P19, write-bridge P20)
>   landed the config→runner chain plus an operator smoke app
>   (lab `server/igniter-web/examples/authority_demo_app`), all at
>   proof/loopback scope; public bind stays human-gated, so no production
>   runner enforces configured authority yet. Proof: machine
>   `tests/capability_io_authority_policy_tests.rs` (7/7).
> - `compensation <ContractName>` / `no_compensation` parse as body-level
>   metadata in both toolchains (LANG-EFFECT-SURFACE-COMPENSATION-P22);
>   three-state emission `compensation_mode: "ref"|"none"|null` +
>   `compensation_ref` (null=undeclared ≠ explicit waiver ≠ named ref —
>   Covenant P17); bare same-module ref only (dotted → OOF-M14; unknown →
>   OOF-M15); placement/duplicate/mutual-exclusion → OOF-M6; bare
>   `irreversible` → OOF-M3 warn. **Declaration only: names intent — grants no
>   authority, binds no host executor, executes nothing** (runtime compensation
>   = machine P12; a future host-binding card follows the authority
>   host-policy pattern). Typed compensator input/output compatibility is
>   deferred to a PROP-002-aligned slice. Proofs:
>   `experiments/effect_surface_compensation_proof/` (17/17) + lab
>   `tests/effect_surface_compensation_tests.rs` (8/8).
> - `reversibility :<value>` parses as body-level metadata in both toolchains
>   (LANG-EFFECT-SURFACE-REVERSIBILITY-P25; the SEVENTH and final field):
>   colon symbol required, six ch12 scale values, bare value emitted as
>   `effect_surface_v1.reversibility`, **absent ⇒ null — no default**;
>   placement/duplicate → OOF-M6; unknown value → OOF-M16; the ONE specified
>   contradiction (`:irreversible`/`:destructive` + `compensation <Ref>`) →
>   OOF-M6 (soft capable-but-waived cases deliberately accepted). HELD:
>   profile max-reversibility (future profile PROP + a FRESH code — the
>   target-table "OOF-M5" collides with implemented M5 = unbound capability),
>   required-field enforcement, host/executor interpretation, scale ordering
>   (encoded nowhere in v0). Proofs:
>   `experiments/effect_surface_reversibility_proof/` (15/15) + lab
>   `tests/effect_surface_reversibility_tests.rs` (8/8).
> - **Gated completeness warnings (LANG-EFFECT-SURFACE-REQUIRED-FIELDS-P28):**
>   an opt-in typechecker gate — Ruby `TypeChecker.new(required_effect_surface:
>   true)`, Rust `TypeChecker::new().with_required_effect_surface(true)`,
>   **default OFF** (gate off ⇒ no OOF-M17, warning/error sets byte-identical).
>   Under the gate, effect-family contracts (`effect`/`privileged`/
>   `irreversible`) missing a required field get `OOF-M17` at **warn** severity:
>   `affects`/`reversibility`/`idempotency`/`receipt`/`failure` for all three
>   modifiers, `authority` for `privileged`/`irreversible` only (declared-intent
>   text — the warning does NOT imply runtime verification). `compensation`
>   requiredness stays the live `OOF-M3` warn (declared-or-waived ≠ presence),
>   never OOF-M17; `observed`/`pure` are outside enforcement; the warning never
>   blocks acceptance. HELD: hard errors, default-ON, profile policy, host/
>   runtime enforcement. Proofs:
>   `experiments/effect_surface_required_fields_proof/` (19/19) + lab
>   `tests/effect_surface_required_fields_tests.rs` (9/9).
> - **Unified IR object (LANG-EFFECT-SURFACE-IR-UNIFICATION-P3):** both
>   toolchains emit the same nested `contract_ir["effect_surface"]` with
>   `kind: "effect_surface_v1"` (Ruby's former `effect_surface_v0_stub` renamed;
>   all stub-era proofs updated). Fields: `capability_bindings[{capability_name,
>   capability_type, effect_name}]` (capability_type follows **CR-001** — `IO.*`
>   normalizes to the `"IO.Capability"` sentinel), `affects_scope`/
>   `affects_target` (parsed since the `affects` slice P5), `authority_ref`
>   (parsed since the `authority` slice P10), `idempotency_mode`/
>   `idempotency_key_expr`, `receipt_type`/`failure_type`, and — since P22 —
>   `compensation_mode`/`compensation_ref`. The Rust flat fields remain a
>   LEGACY compatibility surface; the `capabilities[]`/`effects[]` arrays are
>   the dual declaration-artifact identity law below (igniter-machine
>   `discover_effect_surface` consumes the arrays; the arrays keep the
>   concrete `IO.*` type name); new effect-surface consumers read
>   `effect_surface`.
>   Proofs: lab `tests/effect_surface_ir_unification_tests.rs` (5/5) + machine
>   `capability_io_host_tests` (9/9) + all Ruby effect-surface proofs green.
> - **Dual typed declaration-artifact identity
>   (LANG-CAPABILITY-DECLARATION-ARTIFACT-PARITY-IMPLEMENTATION-P3):** both
>   toolchains emit, for EVERY contract, per-contract `capabilities[]` /
>   `effects[]` declaration rows (empty arrays when no declaration exists) and
>   aggregate the same rows into the manifest in SIR contract order. A
>   capability row is `{name, type: {name, params}}` where `type` is the
>   DECLARED interface identity — name and ordered type parameters,
>   recursively (`IO.LedgerCapability[Int]` carries
>   `params: [{"name":"Int","params":[]}]`); an effect row is
>   `{name, capability_ref}`. Rows are emitted BEFORE `contract_ref`
>   computation and therefore enter contract identity. **Disclosed limit:**
>   a name-less structured parameter (today only the OLAPPoint dims-record
>   form) is NOT carried — BOTH toolchains erase it to
>   `{"name":"Unknown","params":[]}`, so declared capability types differing
>   only in a dims-record alias to one declaration row; parity holds
>   symmetrically, and structured-parameter carriage is future work under a
>   separate card, not implied by this clause. **CR-001 is
>   unchanged:** the typed-IR sentinel and
>   `effect_surface.capability_bindings[].capability_type` keep the
>   `"IO.Capability"` normalization; the declaration rows carry the declared
>   identity — the two carriers answer different questions (typing versus
>   declared authority identity), and the missing information lives in the
>   declared artifact identity carrier, never recovered from grants, bindings
>   or Runtime state. Grammar outcome: capability alias, effect operation and
>   `using`-operand positions accept contextual `ident|keyword` names
>   identically in both toolchains (`effect read using cap` is legal dual).
>   No grant, endpoint, credential, provider id or runtime capability id
>   enters declaration identity.

---

## § 12.6 Relationship to Other Chapters

- **Ch10 (Contract Modifiers):** Effect Surface applies only to `effect`, `privileged`,
  and `irreversible` contracts. Ch10 is a prerequisite.
- **Ch11 (Profile System):** profile `allowed_effects` restricts `affects` targets;
  `reversibility` maximum enforces OOF-M5.
- **Ch6 (SemanticIR):** the Effect Surface fields are emitted into the `contract_ir`
  node as a structured `effect_surface` object.

---

## § 12.7 Effect Calls and Surface Absorption (PROP-050, v0)

> Ratified 2026-07-08 (D1–D4); v0 implemented dual-toolchain under
> `LAB-EFFECT-CALL-V0-P3`. Runtime execution of an invoked callee (attenuated
> grant threading) is the VM half of the same card; a passing compile confers
> no runtime authority — grants come from the host at run start, live IO stays
> human-gated.

`invoke <name> = Callee(args…) using cap[, cap]` composes non-pure
contracts under three laws:

1. **Absorption (OOF-EC2).** The caller's effective Effect Surface is its own
   ∪ every invoked callee's. Nothing reachable through `invoke` may be
   invisible at the caller: each callee effect (verb + declared capability
   TYPE) and each callee `affects` target must be covered by a caller
   declaration. In SIR, the caller's `effect_surface.effects` gains the
   callee's entries flattened with `via_invoke` provenance, and an additive
   `invokes[]` array carries the full per-callee absorbed record
   (`effects`/`affects`/`idempotency_mode`/`reversibility`/`receipt_type`/
   `failure_type`/`authority`; absent fields are null). Policy fields are NOT
   merged into the caller's own fields — profile rules evaluate the caller
   AND each absorbed record conservatively (no merge lattice in v0).
2. **Attenuation (OOF-EC3).** Capabilities are delegated by explicit `using`
   names only — each callee capability slot must be matched by a caller
   capability of the same declared TYPE, with no over-granting and no ambient
   inheritance. Capability-TYPE comparison uses the DECLARED annotation name
   verbatim.
3. **Escalation (OOF-EC4) + boundedness (EC1/EC5/EC6).** `pure` never invokes;
   `observed` → `observed` only; `effect`/`privileged`/`irreversible` →
   `observed`|`effect`; recursion-class callers and callees are held; depth is
   1 in v0; an `invoke` is an effect for ordering (declaration order); the
   invoke binding takes the callee's single output type and is a legal
   ch13 §13.6 `evidence` ref. Self-invocation and cycles stay closed.

`call_contract` remains the pure call permanently; the static plugin registry
remains pure-only. Arity errors reuse `OOF-TY0` and ambiguous short names reuse
`OOF-DECL-AMBIGUOUS-CONTRACT` (the call_contract conventions), so `OOF-EC*`
stays purely the composition family.
