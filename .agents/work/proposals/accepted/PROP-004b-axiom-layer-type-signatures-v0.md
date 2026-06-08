# PROP-004b: Axiom Layer Type Signatures v0

Status: proposal
Date: 2026-05-05
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Supervisor: `[Architect Supervisor / Codex]`
Depends on: `proposals/PROP-001-semantic-domain-v0.md`,
             `proposals/PROP-003-grammar-fragment-classification-v0.md`,
             `proposals/PROP-004-type-system-v0.md`,
             `docs/axiomatic-contract-model.md`

---

## Purpose

PROP-004 defined the type grammar and stated that built-in functions are typed
by the "axiom layer descriptor." This proposal makes that axiom layer explicit:

1. Classify every built-in family as **language contract**, **runtime contract**,
   or **platform observation anchor**.
2. Assign formal type signatures to each family.
3. Specify which families are CORE, ESCAPE, or platform-only (not addressable
   by user contracts at all).
4. Define the **language boundary**: where the language ends and the runtime
   contract begins.

The Architect Supervisor's directive from `axiomatic-contract-model.md` §Next:

> Compiler/Grammar Expert should investigate axiom-layer type signatures:
> which built-ins are language contracts, which are runtime contracts, and
> which host details must remain platform observations.

This proposal answers that directive in full.

---

## Core Claim

[D] The axiom layer is a **three-tier stack**:

```text
Tier 1: Language Built-ins
  Pure, total, typed functions over V (values).
  No external effects. No temporal context needed.
  Classification: CORE.
  Visible to: user contracts, type checker, compiler.

Tier 2: Runtime Contracts
  Typed contracts with temporal context and/or effects.
  Declared and versioned at the runtime boundary.
  Classification: CORE when declared; ESCAPE when causal/distributed.
  Visible to: user contracts via explicit typed handles.

Tier 3: Platform Observations
  Host details that affect meaning but are not user-addressable.
  Exposed only as Obs[:platform_observation, PlatformDescriptor].
  Classification: OOF for user contracts; visible as observations only.
  Visible to: observation consumers (agents, compilers, auditors).
```

The language boundary is the line between Tier 1 and Tier 2. Above the
boundary: the user writes contracts. At the boundary: the runtime contract
is declared. Below the boundary: platform physics.

---

## Tier 1: Language Built-ins (CORE)

These are pure, total functions over the value domain `V`. They have no side
effects, require no temporal context, and terminate for all inputs.

### Group A: Arithmetic

```text
add     : Int × Int   -> Int
add_f   : Float × Float -> Float
sub     : Int × Int   -> Int
sub_f   : Float × Float -> Float
mul     : Int × Int   -> Int
mul_f   : Float × Float -> Float
div     : Int × Int   -> Option[Int]       -- None when divisor = 0
div_f   : Float × Float -> Option[Float]   -- None when divisor = 0.0
mod     : Int × Int   -> Option[Int]       -- None when divisor = 0
pow     : Int × Int   -> Option[Int]       -- None when result overflows
abs     : Int   -> Int
abs_f   : Float -> Float
floor   : Float -> Int
ceil    : Float -> Int
round   : Float -> Int
to_float: Int   -> Float
to_int  : Float -> Option[Int]             -- None on NaN or overflow
```

**[D]** `div` and `mod` return `Option[Int]`, not `Int`. Division by zero is
not a runtime exception — it is a typed `None` value. The consumer must handle
the `None` case explicitly. This prevents silent division-by-zero failures.

**[D]** Integer overflow in `pow` returns `Option[Int]`. All arithmetic in
the CORE fragment is **total** (no hidden exceptions).

### Group B: Comparison and Boolean

```text
eq      : T × T   -> Bool            -- structural equality for all T in V
neq     : T × T   -> Bool
lt      : Ord × Ord -> Bool          -- Ord = Int | Float | String
lte     : Ord × Ord -> Bool
gt      : Ord × Ord -> Bool
gte     : Ord × Ord -> Bool
and     : Bool × Bool -> Bool
or      : Bool × Bool -> Bool
not     : Bool -> Bool
if_then : Bool × T × T -> T         -- strict: both branches evaluated
```

**[D]** `eq` is **structural equality** over all V. Two `Record` values are
equal iff all their fields are equal. `Ref` values are equal iff they point
to the same named contract or store. `Redacted` values are never equal to
anything (including each other) — equality of redacted values is OOF.

**[D]** `if_then` is **strict** (both branches evaluated before selection)
because lazy evaluation requires a different evaluation order (out-of-CORE).
Conditional branching over contracts uses the `branch` composition operator,
not `if_then`.

### Group C: String Operations

```text
str_concat  : String × String  -> String
str_length  : String           -> Int
str_slice   : String × Int × Int -> Option[String]   -- None on out-of-bounds
str_upcase  : String           -> String
str_downcase: String           -> String
str_trim    : String           -> String
str_contains: String × String  -> Bool
str_starts  : String × String  -> Bool
str_ends    : String × String  -> Bool
str_to_int  : String           -> Option[Int]         -- None on parse fail
str_to_float: String           -> Option[Float]       -- None on parse fail
int_to_str  : Int              -> String
float_to_str: Float            -> String
bool_to_str : Bool             -> String
```

**Classification:** All CORE. Purely structural string operations with no
I/O, no locale, no encoding ambiguity (all strings are UTF-8).

**ESCAPE:** `str_match_regex : String × Pattern -> Bool` is ESCAPE
(`refinement_predicate`) because regex matching is not linearly decidable
in the general case and patterns may be Turing-complete.

### Group D: Structural Access

```text
record_get   : Record × Symbol -> Option[Any]   -- None if field missing
record_set   : Record × Symbol × Any -> Record  -- returns new record (immutable)
record_has   : Record × Symbol -> Bool
record_keys  : Record -> Collection[Symbol]

variant_tag  : Variant -> Symbol
variant_value: Variant -> Any

collection_get   : Collection[T] × Int -> Option[T]   -- None on OOB
collection_length: Collection[T] -> Int
collection_append: Collection[T] × T -> Collection[T]
collection_map   : Collection[T] × ContractRef[{item:T},{result:S}] -> Collection[S]
collection_filter: Collection[T] × ContractRef[{item:T},{keep:Bool}] -> Collection[T]
collection_fold  : Collection[T] × S × ContractRef[{acc:S,item:T},{acc:S}] -> S
collection_any   : Collection[T] × ContractRef[{item:T},{result:Bool}] -> Bool
collection_all   : Collection[T] × ContractRef[{item:T},{result:Bool}] -> Bool
collection_empty : Collection[T] -> Bool
collection_first : Collection[T] -> Option[T]
collection_last  : Collection[T] -> Option[T]
```

**[D]** `collection_map`, `collection_filter`, `collection_fold` accept a
`ContractRef` (a statically-resolved contract reference), not a lambda.
This keeps higher-order collection operations in the CORE fragment: the
contract reference is resolved at compile time, the type-checker verifies
the contract's input/output types against the collection element type.

**[D]** `record_get` returns `Option[Any]` because the field name is a
runtime `Symbol`. For statically-known fields, `FieldAccess(expr, label)`
(PROP-001 §5) is preferred — it returns `T` directly with a compile-time
type guarantee.

### Group E: Type Coercion and Inspection

```text
type_of     : Any -> Symbol               -- returns type tag: :int, :float, :string, etc.
is_none     : Option[T] -> Bool
unwrap      : Option[T] -> T | Never      -- Never if None; use in guarded context only
unwrap_or   : Option[T] × T -> T          -- safe: returns default if None
some        : T -> Option[T]
none        : Option[T]                   -- typed None constructor
```

**[D]** `unwrap` has return type `T | Never`. It is safe in a guarded context
(after `is_none` check or inside a `Case` arm). Using `unwrap` without a
guard is a type warning at Pass 1 (not an error — the type system handles it
via `Never` propagation).

---

## Tier 2: Runtime Contracts (CORE / ESCAPE)

Runtime contracts are typed handles to runtime-provided capabilities. They are
not free functions — they are **contract references** that the user binds
explicitly. The runtime emits a `platform_observation` declaring which runtime
contracts are available and at which versions.

### Group F: Clock and Time (CORE when explicit)

```text
RuntimeClock = ContractRef[
  inputs  : { as_of_policy: :caller | :monotonic | :wall },
  outputs : { timestamp: Timestamp }
]
```

**Usage in contracts:**

```text
clock_read : RuntimeClock × TemporalCtx -> Timestamp
```

**[D]** The clock is not a free built-in. It is a **runtime contract** bound
explicitly in the contract's `TemporalPolicy`. A contract that reads the clock
must declare `requires_as_of: true`. Ambient clock reads (undeclared `Time.now`)
are OOF — they violate Law 6 (Temporal Explicitness).

**Classification:**

| Clock use | Class | Reason |
|-----------|-------|--------|
| `clock_read` with explicit `TemporalCtx` | CORE | Explicit, observable |
| `causal_clock` synchronization | ESCAPE `causal_clock` | Multi-node consistency |
| `Time.now` without TemporalCtx | OOF | Ambient time; violates Law 6 |
| Wall-clock with no declared policy | OOF | Hidden runtime dependency |

### Group G: Randomness (ESCAPE)

```text
RandomSource = ContractRef[
  inputs  : { seed: Option[Int], kind: :secure | :pseudo },
  outputs : { value: Int | Float }
]

random_int  : RandomSource × Int × Int -> Int     -- bounded random integer
random_float: RandomSource -> Float               -- [0.0, 1.0)
random_uuid : RandomSource -> String              -- UUID v4
```

**[D]** Randomness is ESCAPE (`platform_extension_code`) because:
1. It is non-deterministic — it violates observation conservation (Law 5)
   unless the seed is fixed.
2. It requires a capability boundary for secure random (OS entropy source).

**[D]** Seeded randomness (`seed: Some(n)`) is CORE when the seed is a
declared input: the result is deterministic given the seed. Unseeded
randomness is always ESCAPE.

**Classification:** ESCAPE by default; CORE when seed is a declared input.

### Group H: Hashing and Content Addressing (CORE)

```text
hash_sha256   : Bytes -> Hash           -- cryptographic; deterministic
hash_sha512   : Bytes -> Hash
hash_blake3   : Bytes -> Hash
hash_content  : Any -> Hash             -- canonical hash of any V value
str_to_bytes  : String -> Bytes
bytes_to_str  : Bytes -> Option[String] -- None if not valid UTF-8
bytes_length  : Bytes -> Int
bytes_concat  : Bytes × Bytes -> Bytes
```

**[D]** `hash_content` is the **canonical hash function** over V values.
It is CORE because:
- It is deterministic (same V produces same Hash)
- It is total (no V value fails to hash)
- It is the basis for `content_hash` in the observation envelope (PROP-005)

**[D]** The hash algorithm used by `hash_content` must be declared via a
`platform_observation` at the runtime boundary. The name is CORE; the
algorithm is platform-declared.

### Group I: Parsing and Serialization (CORE / ESCAPE)

```text
-- CORE: deterministic structural serialization
encode_json     : Any -> String          -- canonical JSON; deterministic
decode_json     : String -> Option[Any]  -- None on parse error
encode_base64   : Bytes -> String
decode_base64   : String -> Option[Bytes]

-- ESCAPE: format-specific or locale-sensitive
parse_datetime  : String × Format -> Option[Timestamp]   -- ESCAPE: locale
parse_number    : String × Locale -> Option[Float]        -- ESCAPE: locale
format_number   : Float × Locale × Precision -> String    -- ESCAPE: locale
```

**Classification:**

| Function | Class | Reason |
|----------|-------|--------|
| `encode_json` | CORE | Canonical; deterministic; no locale |
| `decode_json` | CORE | Total (returns Option); no locale |
| `encode_base64` / `decode_base64` | CORE | Deterministic encoding |
| `parse_datetime` with format | ESCAPE `platform_extension_code` | Format/locale dependency |
| `parse_number` with locale | ESCAPE `platform_extension_code` | Locale dependency |
| `format_number` | ESCAPE `platform_extension_code` | Locale + precision |

---

## Tier 3: Platform Observations (Not User-Addressable)

These are host runtime capabilities that **cannot** be called from user
contracts. They are visible only as `Obs[:platform_observation, T]` packets.
Attempts to call them directly are OOF.

### Group J: Host I/O (OOF for user contracts)

```text
-- These are platform-level; not addressable from user contracts:
file_read       (-> platform_observation)
file_write      (-> platform_observation + effect receipt)
network_call    (-> platform_observation + effect receipt)
process_exec    (-> platform_observation + effect receipt)
```

**[D]** File, network, and process operations are **not built-ins**. They
are effects declared through `EffectDecl` and executed by a capability
executor. The capability executor emits a `receipt_observation` or a
`failure_observation`. The contract declares the effect shape; the runtime
executes it under capability policy.

If a contract needs file I/O, it must declare:
```text
effect :write_file, input: { path: String, content: Bytes },
                    receipt: { bytes_written: Int }
```

The type of the effect is `EffectDecl[{path,content}, {bytes_written}]`.
The call is typed; the execution is platform. This is the language/runtime
boundary.

### Group K: Storage Physics (OOF for user contracts)

```text
-- Storage physics: WAL, compaction, replication, index scans
-- Not addressable by user contracts.
-- Visible as: Obs[:platform_observation, StorageDescriptor]
wal_append         (-> platform_observation)
segment_seal       (-> platform_observation)
compaction_run     (-> platform_observation)
replica_sync       (-> platform_observation)
```

**[D]** Storage physics are **always platform_observation**. The user
contract accesses storage through `Store[T]` and `History[T]` typed handles.
The physical operations are invisible to the contract; they are visible to
auditors and operations teams through observation packets.

### Group L: Scheduler and Concurrency (OOF / ESCAPE)

```text
-- Thread/async internals: OOF
thread_spawn       (-> OOF)
heap_allocate      (-> OOF)
gc_collect         (-> OOF)

-- Concurrency primitives with declared semantics: ESCAPE
worker_pool_submit : WorkerPool × ContractRef -> Future[ObsPacket]
  (ESCAPE: concurrent; non-deterministic completion order)
```

**[D]** Raw thread spawning and heap operations are OOF. They are host
physics, not semantic contracts.

**[D]** `worker_pool_submit` is ESCAPE because the completion order of
parallel workers is non-deterministic — it violates the determinism of
`eval(G, Tt, inputs)` at the Tt level unless each worker uses the same
fixed `Tt`. If Tt is fixed and shared, worker_pool_submit is semantically
equivalent to `||` composition with deferred receipt collection.

### Group M: LLM / AI Provider (Platform Observation Only)

```text
-- LLM inference: always platform_observation
llm_infer (model, prompt) -> OOF for user contracts
```

**[D]** LLM inference is **not a built-in**. It is an agent participation
contract (PROP-004 / PROP-005): the agent receives an `intent_observation`
with a hashed prompt, the LLM runtime produces a `receipt_observation` with
the result, and the model/provider boundary is declared as a
`platform_observation` with a `ModelDescriptor`.

The user contract never calls `llm_infer` directly. It declares an agent
participation effect; the runtime executes it under capability and privacy
policy. Raw prompt capture in the contract is OOF (PROP-005 WF rules).

---

## The Language Boundary: Formal Definition

[D] The language boundary is defined as follows:

```text
LANGUAGE SIDE (user-addressable):
  - Tier 1 built-ins: pure, total, typed over V
  - Tier 2 runtime contracts: typed handles declared in contract TemporalPolicy
    or EffectDecl
  - Observation production: observe(kind, value, privacy) -> ObsPacket[kind,T]

BOUNDARY (where language meets runtime):
  - EffectDecl: declares effect shape; execution is runtime
  - RuntimeClock: declared in TemporalPolicy; clock read is runtime
  - WorkerPool (ESCAPE): declared; execution order is runtime
  - ContractRef resolution: compile-time (language); execution: runtime

RUNTIME SIDE (not user-addressable; visible as platform_observations):
  - Host I/O (file, network, process)
  - Storage physics (WAL, compaction, replication)
  - LLM/AI provider inference
  - Scheduler / thread / heap internals
  - Random entropy source (the value is addressable; the source is platform)
```

**[D]** The language boundary is NOT a sharp line between "in language" and
"outside." It is a **typed interface**: effects, clock reads, and worker
pool submissions cross the boundary through declared, typed, versioned
handles. The handle is language; the execution is runtime.

This matches the axiomatic-contract-model.md thesis:

```text
Runtime = contract over execution of contracts
```

The runtime contract declares what it promises (scheduling, clock, storage,
capability execution). The user contract declares what it needs (effects,
temporal context, worker submission). The intersection is the typed boundary.

---

## Built-in Version and Axiom Descriptor

Every Tier 1 built-in group and every Tier 2 runtime contract must be
described by a `platform_observation` at session/compilation start:

```text
Obs[:platform_observation, AxiomDescriptor] where AxiomDescriptor = Record {
  axiom_group   : Symbol          -- :arithmetic, :string, :structural, :clock, etc.
  version       : String          -- semver
  hash_algorithm: Option[String]  -- for hash_content only
  locale        : Option[String]  -- for locale-sensitive ESCAPE functions
  capabilities  : Collection[Symbol]  -- which Tier 2 runtime contracts are available
}
```

This is the "thin axiom layer" from **Law 9** (observable-contract-language-v0):

> The axiom layer should be small, typed, versioned, and inspectable at its
> boundary.

The `AxiomDescriptor` observation makes the axiom layer inspectable. A
consumer can determine which arithmetic semantics, hash algorithm, and runtime
contracts were active during a given evaluation — and therefore whether the
result is reproducible under the same axiom descriptor.

---

## Fragment Classification Summary

| Group | Class | Condition |
|-------|-------|-----------|
| A: Arithmetic | CORE | Total, pure, typed; Option on division |
| B: Comparison/Boolean | CORE | Structural; strict if_then |
| C: String | CORE | UTF-8 only; Option on bounds/parse |
| C: `str_match_regex` | ESCAPE `refinement_predicate` | Regex not linearly decidable |
| D: Structural Access | CORE | Immutable; ContractRef for HOF |
| E: Type/Option | CORE | With `unwrap` warning in unguarded context |
| F: Clock (explicit) | CORE | Declared TemporalPolicy |
| F: Clock (ambient) | OOF | Violates Law 6 |
| F: `causal_clock` | ESCAPE | Multi-node consistency |
| G: Randomness (seeded) | CORE | Seed is declared input |
| G: Randomness (unseeded) | ESCAPE `platform_extension_code` | Non-deterministic |
| H: Hashing | CORE | Deterministic; canonical |
| I: JSON/Base64 | CORE | Deterministic; no locale |
| I: Locale-sensitive parse/format | ESCAPE `platform_extension_code` | Locale dependency |
| J: Host I/O | OOF (user contracts) | Effects via EffectDecl only |
| K: Storage physics | OOF (user contracts) | platform_observation only |
| L: Thread/heap | OOF | Host physics |
| L: WorkerPool submit | ESCAPE | Non-deterministic completion order |
| M: LLM inference | OOF (user contracts) | Agent participation via EffectDecl |

---

## Compiler Actions for Each Class

| Class | Pass 0 action | Pass 1 action | Runtime action |
|-------|--------------|--------------|----------------|
| CORE built-in | Accept silently | Type-check signature | Execute directly |
| ESCAPE | Accept + emit escape `platform_observation` | Type-check + add escape marker | Execute with escape flag |
| OOF | Reject immediately | Never reached | Never reached |
| Platform observation | Accept as `Obs[:platform_observation, T]` value | Type-check as ObsPacket | Receive from runtime, not called |

---

## Open Questions

[Q] Should `collection_map` / `collection_filter` / `collection_fold` accept
`ContractRef` only, or also inline lambda-like syntax? If inline lambda syntax
is allowed, it must be restricted to CORE expressions (no recursion, no
higher-order). Recommendation: `ContractRef` only in v0; inline expression
syntax as a grammar convenience in v1 (desugared to a named ContractRef at
compile time).

[Q] Is `encode_json` truly canonical? JSON has no canonical form (key
ordering, whitespace). Recommendation: define a **canonical JSON form** as
part of the axiom descriptor — sorted keys, no whitespace, UTF-8 encoded.
Reference `RFC 8785 (JSON Canonicalization Scheme)` as the standard.

[Q] Should `hash_content` be a single function or a family (one per
algorithm)? Recommendation: single `hash_content` function whose algorithm
is declared in the `AxiomDescriptor` platform_observation. This ensures
all content hashes in a given evaluation use the same algorithm.

[Q] How are ESCAPE runtime contracts versioned? A `WorkerPool` or
`RandomSource` might change behavior across runtime versions.
Recommendation: each runtime contract handle carries a version from the
`AxiomDescriptor`. Observations produced under a specific handle version
carry a `platform_observation` link.

---

## Rejected Paths

[X] Untyped built-ins (functions without declared signatures). Every axiom
layer function must have a declared type signature. Untyped built-ins make
the type checker unable to verify callers.

[X] Total arithmetic (no Option for division). Division by zero as a runtime
exception is OOF — it produces untyped failure. Option-returning division
keeps failure in the value domain.

[X] Ambient clock/random without declaration. Both clock and randomness have
non-trivial effects on reproducibility and observation conservation. They
must be declared in TemporalPolicy or EffectDecl.

[X] LLM inference as a built-in. LLM calls are agent participation effects
with privacy, capability, and redaction requirements. Treating them as
built-ins would bypass all of those.

[X] Storage physics as user-addressable. WAL, compaction, and replication
details are host physics. Exposing them as user-callable functions would
couple user contracts to storage implementation details.

---

## Handoff

```text
[Igniter-Lang Compiler/Grammar Expert]
Track: igniter-lang/docs/proposals/PROP-004b
Status: done

[D] Decisions:
- Axiom layer is a three-tier stack: Language Built-ins (CORE, pure, total),
  Runtime Contracts (CORE/ESCAPE, typed handles), Platform Observations
  (OOF for user contracts, visible as Obs[:platform_observation, T]).
- The language boundary is a typed interface, not a sharp wall: EffectDecl,
  TemporalPolicy, and ContractRef handles are how user contracts cross into
  runtime execution.
- Division by zero returns Option[Int], not a runtime exception. All Tier 1
  arithmetic is total.
- clock and randomness are not free built-ins: clock is a RuntimeClock
  ContractRef bound via TemporalPolicy; randomness is ESCAPE when unseeded.
- collection_map/filter/fold accept ContractRef (statically resolved),
  not lambdas. This keeps HOF collection operations in the CORE fragment.
- hash_content is CORE; its algorithm is declared via AxiomDescriptor
  platform_observation. All content hashes in an evaluation use the same
  algorithm.
- LLM inference is OOF for user contracts. It is agent participation via
  EffectDecl and privacy/capability policy.
- Storage physics (WAL, compaction) are platform_observation only.
- Every axiom group must be described by an AxiomDescriptor platform_observation
  at session/compilation start. This implements Law 9 (Thin Axiom Layer).

[R] Recommendations:
- Adopt RFC 8785 (JSON Canonicalization Scheme) as the canonical JSON form
  for encode_json and content-addressing.
- Define AxiomDescriptor as a standard platform_observation shape; emit it
  before the first contract evaluation in every runtime session.
- Proceed to Research Agent track: temporal-contracts-and-projections-v0
  (named slices, projection horizon, command lifecycle).
- Consider PROP-006: Runtime Contract Specification — a formal spec for the
  RuntimeContract that the runtime promises (scheduler, clock, cache, storage,
  capability executor). This follows directly from axiomatic-contract-model.md
  §Runtime As Contract.

[S] Signals:
- The three-tier model is consistent with axiomatic-contract-model.md's
  fractal stack: LanguageContract / RuntimeContract / UserContract are
  exactly Tier 1 / Tier 2 / user-authored contracts.
- Making collection HOFs accept ContractRef (not lambdas) is the key design
  choice that keeps higher-order collection operations in the decidable CORE
  fragment. It costs syntax convenience but gains static verifiability.
- The AxiomDescriptor observation is the formal implementation of Law 9
  (Thin Axiom Layer). It makes the axiom layer observable, versioned, and
  reproducibility-relevant — exactly what the law requires.
- option-returning arithmetic (div, mod, to_int) aligns with the soundness
  theorem from PROP-004: no well-typed program produces untyped failure.

[Q] Open Questions:
- Should collection HOF syntax accept inline CORE expressions (v1 convenience)?
- Is encode_json canonical? Adopt RFC 8785?
- Should hash_content be a family or a single function with AxiomDescriptor?
- How are ESCAPE runtime contract handles versioned?

[X] Rejected:
- Untyped built-ins.
- Total arithmetic without Option.
- Ambient clock/random.
- LLM inference as built-in.
- Storage physics as user-addressable.

[Next] Proposed next slices:
- Research Agent track: temporal-contracts-and-projections-v0
  (named slices, projection horizon, command lifecycle, reproducibility)
- PROP-006: Runtime Contract Specification
  (formal spec for the runtime contract: scheduler, clock, storage, capability
   executor — directly from axiomatic-contract-model.md §Runtime As Contract)
```
