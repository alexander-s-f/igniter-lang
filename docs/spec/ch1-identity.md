# Ch1: Identity and Semantic Model

Source PROP: PROP-001
Status: accepted
Proof: — (no executable proof needed; normative foundation)

---

## 1.1 Language Identity

Igniter-Lang is an **Epistemic Contract Language (ECL)** — a language in which
every computation is a declared, observable, time-aware dependency graph.

Five formal identities (convergent, not analogies):

| Theory | Contract identity |
|--------|------------------|
| Anokhin TFS | Result-oriented functional system |
| Attribute Grammars (Knuth 1968) | `compute` = synthesized attr; `in` = inherited attr; resolution_order = AG evaluation schedule |
| Concurrent Constraint Programming (Saraswat 1989) | `tell` = compute write; `ask` = guard; confluence = determinism |
| Stratified Datalog | DAG = decidable, PTIME, confluent; resolution_order IS the Datalog stratification |
| Category Theory | Contracts form a monoidal category; `compose` = morphism composition |

---

## 1.2 Semantic Domains (PROP-001 §Semantic Domains)

```
V  — Values:    scalars, records, variants, collections, functions, temporal
T  — Types:     base, structural, temporal, observation, refinement
Tt — Temporal:  DateTime context passed to every evaluation
C  — Contracts: named, typed DAG nodes + lifecycle + observations
O  — Obs:       Obs[kind, T] — typed observation packets
F  — Failures:  typed structured failures with reason codes
```

**Ten Laws** (PROP-001 §Formal Restatement):

```
Law 1   Every meaningful computation produces an observable.
Law 2   Observations carry identity, provenance, and policy.
Law 3   The core is a finite stratified DAG parameterized over explicit Tt.
Law 4   Contracts are values: composable, passable, returnable.
Law 5   Every failure is a typed structured value.
Law 6   Time is explicit: no ambient Time.now. All reads require TemporalCtx.
Law 7   Lifecycle is declared: local, session, window, durable, audit.
Law 8   Evidence links are required: aggregates carry aggregated_from.
Law 9   The axiom layer is thin and named (stdlib).
Law 10  Schema evolution is a language concern, not a deployment afterthought.
```

---

## 1.3 Contract as Object (PROP-001 §4)

A contract `C` is a tuple:
```
C = (name, inputs, outputs, nodes, lifecycle, observations, capabilities)
```

- `inputs` — declared typed parameters (in, read, stream)
- `outputs` — declared typed results (out)
- `nodes` — dependency-ordered compute/branch/compose/effect nodes
- `lifecycle` — retention class for each stored value
- `observations` — emitted Obs[kind, T] packets at each evaluation
- `capabilities` — declared ESCAPE capabilities (affects classification)

**Semantic equivalence** (PROP-001 §Semantic Equivalence):

Two contracts C₁ ≡ C₂ iff for all inputs and all Tt:
1. Output values are equal
2. Observation evidence links agree
3. Lifecycle commitments are equal

Raw value equality alone does NOT prove equivalence.

---

## Hash tiers (identity policy note, 2026-07-07 — LANG-ID-P2)

Two named hash tiers, deliberately distinct (precedent: the TBackend P112
two-tier decision):

- **Program/pass identity = SHA-256.** `program_id` for every compiler pass is
  `sha256(source_path|grammar_version|source_hash|pass_version)` truncated to
  16 hex chars (e.g. `classifier_pass/<16hex>`); `source_hash` is
  `sha256:<hex>` of the source bytes. Ruby canon and the Rust lab compiler
  produce **byte-identical** ids for identical input — locked by the lab
  cross-toolchain test `tests/program_id_parity_tests.rs` (the 2026-06-10
  "Ruby SHA-256 vs Rust blake3" divergence is resolved; Rust aligned to canon).
- **Lab-internal artifact/ledger hashing = blake3** (e.g. capsule content
  addresses, `AuthorityPolicy::policy_digest`, machine receipt digests).
  Blake3 values are lab evidence, never program identity, and never enter
  `program_id` seeds.

`source_path` is part of pass identity BY DESIGN (same bytes at a different
path = a different classified program); the path-independent semantic identity
lives in the manifest `semantic_hash` (additive, 2026-07-05), not here.
