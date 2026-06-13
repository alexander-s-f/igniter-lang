# LANG-STDLIB-COLLECTION-RANGE-P1 — Proposal / Readiness

**Date:** 2026-06-13
**Status:** CLOSED — ROUTED
**Track:** lang / stdlib / collections
**Predecessors:** LAB-STDLIB-STRINGLY-CALL-CONTRACT-MIGRATION-P2, LANG-STDLIB-IS-EMPTY-PROP-P3/P4

---

## Question

Should `stdlib` expose `range(start, stop)` or `range(count)` as the deterministic
bounded collection generation primitive?

---

## Trigger

`bloom_filter/example.ig` (`InitFilter16` contract) builds a 16-slot Bloom filter manually:

```ig
compute s0 = { pos: 0, set: false }
compute s1 = { pos: 1, set: false }
-- ... 14 more
compute s15 = { pos: 15, set: false }

compute b0 : Collection[BitSlot] = [s0, s1]
compute b1 = append(b0, s2)
-- ... 12 more
compute b14 = append(b13, s15)
```

The source comment says it explicitly:
`"Build slots manually since there's no range() function"`

**31 compute nodes** to initialize a single 16-slot collection. With `range`:

```ig
compute slots = map(range(0, 16), i -> { pos: i, set: false })
```

2 compute nodes. 31 → 2.

---

## Evidence Base

### Canon source usage

**`stdlib_extension.ig`**:
```ig
if count(zip(range(0, count(leads)), range(0, count(leads)))) > 0 { ...
```
Uses `range(0, count(leads))` — two-arg form with zero start offset.

**`availability_projection.ig`**:
```ig
fold(range(start, end), [], (acc, hour) -> { ... })
```
Uses `range(start, end)` where `start = schedule.working_hours[0]` — non-zero start.
The two-arg form is required here; `range(count)` cannot express it.

### Lab stdlib declaration

`igniter-lab/igniter-stdlib/stdlib/collections.ig`:
```ig
def range(start: Integer, end: Integer) -> Collection[Integer]
```
Two-arg form. No single-arg variant declared.

### Lab stdlib Rust implementation

`igniter-lab/igniter-stdlib/src/collections.rs`:
```rust
pub fn range(start: i64, end: i64) -> Vec<Value> {
    (start..end).map(|v| Value::Number(v.into())).collect()
}
```
Two-arg. Exclusive upper bound `[start..end)`. Total — empty vec when `start >= end`.

### Rust TC arm

`igniter-lab/igniter-compiler/src/typechecker.rs` (~line 2865):
```rust
"range" => {
    is_resolved = true;
    // builds Collection[Integer] output type
    resolved_type = ...Collection[Integer]...;
}
```
Already implemented. No arg type validation. Returns `Collection[Integer]` on any call.

---

## Form Candidates

### Candidate A: `range(start, stop)` — ACCEPT

```ig
range(0, 16)    -- [0, 1, 2, ..., 15]
range(start, end)  -- [start, start+1, ..., end-1]
```

- All existing canon usage is two-arg
- Lab stdlib.ig declares two-arg
- Rust TC implements two-arg
- Covers non-zero start (required by `availability_projection.ig`)
- `range(0, n)` is the count-only special case

### Candidate B: `range(count)` — REJECT

```ig
range(16)  -- [0, 1, 2, ..., 15]
```

- No existing usage in any canon or lab source
- Strict subset of `range(start, stop)` — expressible as `range(0, n)`
- Cannot express `range(start, end)` with non-zero start
- Adding it alongside `range(start, stop)` creates ambiguity (same function name, different arity)
- Rust TC has no single-arg arm
- Rejected

**Verdict: `range(start, stop)` only.**

---

## Entry Contract

### Signature

```ig
def range(start: Integer, stop: Integer) -> Collection[Integer]
```

- `[start, stop)` exclusive upper bound — consistent with Rust `(start..end)` semantics
- Totality: `range(5, 5) = []`; `range(5, 3) = []` — no error, just empty
- Type: concrete `Collection[Integer]` — not generic `Collection[T]`
- Arity: exactly 2

### Canonical name

`stdlib.collection.range`

Follows module convention: function belongs to the collection generator namespace,
not to integer (it produces a collection from integers, not an operation on an integer).
Source alias: `range`.

### OOF Codes

| Code | Trigger |
|------|---------|
| OOF-COL1 | arity != 2 — "stdlib.collection.range: expected 2 arguments (start, stop), got N" |

No element-type validation needed. The Rust TC arm returns `Collection[Integer]` without
checking arg types. P2 Ruby TC follows the same permissive design. Unknown args are
permissive (no OOF-COL2 — OOF-COL2 is defined as "first arg must be Collection[T]",
which does not apply to range). No new OOF codes.

---

## Current State

| Toolchain | State | Detail |
|-----------|-------|--------|
| Ruby TC | **MISSING** | No `when "range"` arm. OOF-TY0 "Unknown function: range" |
| Rust TC | **PRESENT** | `"range" =>` arm at ~line 2865. `Collection[Integer]` output |
| Lab stdlib.ig | **DECLARED** | `def range(start: Integer, end: Integer) -> Collection[Integer]` |
| stdlib-inventory.json | **ABSENT** | No entry. Inventory edit is P2 scope |

---

## Bloom_filter Pressure Detail

| Item | Count |
|------|-------|
| Manual slot computes (`s0`..`s15`) | 16 |
| Chained append computes (`b1`..`b14`) | 14 |
| Bootstrap compute (`b0 : Collection[BitSlot]`) | 1 |
| **Total** | **31** |
| With `map(range(0, 16), i -> {...})` | **2** |

bloom_filter is currently DUAL-CLEAN (BF-P01/P02 resolved via stringly migration P2).
Range doesn't fix a current diagnostic — it enables a significant source simplification
once P2 dispatch lands.

---

## What Is NOT Changed by This Card

- No Ruby TC changes
- No Rust TC changes (already implemented)
- No parser changes (range() is already parsed as a regular call)
- No stdlib-inventory.json changes (P2 scope)
- No app source changes (bloom_filter/example.ig stays as-is)
- No emitter changes
- No new OOF codes

---

## Next Routes

| Card | Scope |
|------|-------|
| `LANG-STDLIB-COLLECTION-RANGE-P2` | Ruby TC: `when "range"` arm + `infer_range_call` + inventory entry |
| `LANG-STDLIB-COLLECTION-RANGE-P3` | Rust TC: OOF-COL1 parity + SIR fn qualification proof |
