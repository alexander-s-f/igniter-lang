# Ch8: Stdlib

Source PROP: PROP-013, PROP-013 errata v0.1
Status: ✅ PASS (kernel)
Proof: experiments/stdlib_execution_kernel_stage1/ — PASS (12 cases):
  integer/float/decimal.add, fold, map, filter, count, or_else (Some + None),
  numeric.add rejected (pre-resolution boundary enforced),
  RuntimeMachine igapp-style evaluate with stdlib.integer.add
Note: stdlib not yet connected to the full RuntimeMachine evaluate path via .igapp/ (pending Slice A)

**String core update (2026-06-08):**
§8.1 `string.ig` surface is superseded by `stdlib.text.*` (§8.10).
Canonical type is `Text` (not `String`). The old ambiguous `length` function
is held/legacy — prefer explicit unit-qualified ops (`byte_length`, `rune_length`,
`grapheme_length`). See §8.10 for the full experiment-pass surface.

---

## 8.1 Stdlib Module Structure (PROP-013 §Stdlib Module Map)

```
stdlib/
  core/
    collection.ig   — fold, map, filter, group_by, sort_by, take, first, last
    option.ig       — some, none, or_else, map, flat_map, some?
    result.ig       — ok, err, ok?, err?, map, flat_map, unwrap_or
    numeric.ig      — add, sub, mul, div, neg, compare (generic, pre-resolution)
    integer.ig      — stdlib.integer.add, sub, mul, div, neg, compare
    float.ig        — stdlib.float.add, ...
    decimal.ig      — stdlib.decimal.add (scale-aware), mul
    string.ig       — SUPERSEDED by stdlib.text.* (§8.10); old `length` held/legacy; see §8.10
  temporal/
    date.ig         — add_days, diff_days, day_of_week, beginning_of, end_of
    datetime.ig     — add_duration, diff, as_of (CORE); now() → OOF
  stream/           — Stage 2: fold_stream, window (deferred)
  temporal_ops/     — Stage 2: history_at, rollup (deferred)
  olap/             — Stage 2: olap_slice, olap_rollup (deferred)
```

**Tier classification**:
- `stdlib/core/` — Tier 1: no TBackend reads, no FFI, no ambient clock → CORE
- `stdlib/temporal/` — date arithmetic is CORE; TBackend reads are ESCAPE

---

## 8.2 Collection[T] (PROP-013 §Collection)

```
Collection[T] is always finite and bounded at classification time.
Termination Rule TR-1: if Collection[T].count is statically bounded,
any fold/map/filter terminates unconditionally.

fold(xs: Collection[T], init: A, fn: (A, T) -> A) -> A
map(xs: Collection[T], fn: T -> U) -> Collection[U]
filter(xs: Collection[T], pred: T -> Bool) -> Collection[T]
filter_map(xs: Collection[T], fn: T -> Option[U]) -> Collection[U]  -- keep each Some payload, drop None
count(xs: Collection[T]) -> Integer
sum(xs: Collection[T]) -> T           -- requires Numeric[T]
avg(xs: Collection[T]) -> Option[T]   -- None if empty; requires Numeric[T]
min(xs: Collection[T]) -> Option[T]
max(xs: Collection[T]) -> Option[T]
group_by(xs, fn: T -> K) -> Map[K, Collection[T]]
sort_by(xs, fn: T -> K) -> Collection[T]
take(xs, n: Integer) -> Collection[T]
first(xs) -> Option[T]
last(xs) -> Option[T]
```

**avg([]) = None** — never OOF; zero-guard is a language invariant.
**Lambda nodes** in SemanticIR: anonymous, non-recursive, bounded.

---

## 8.3 Option[T] (PROP-013 §Option)

```
some(v: T) -> Option[T]
none() -> Option[T]
some?(opt) -> Bool
or_else(opt: Option[T], fallback: T) -> T
map(opt: Option[T], fn: T -> U) -> Option[U]
flat_map(opt: Option[T], fn: T -> Option[U]) -> Option[U]
```

---

## 8.4 Result[T, E] (PROP-013 §Result)

```
ok(v: T) -> Result[T, E]
err(e: E) -> Result[T, E]
ok?(r) -> Bool
err?(r) -> Bool
map(r: Result[T,E], fn: T -> U) -> Result[U, E]
unwrap_or(r: Result[T,E], fallback: T) -> T
```

---

## 8.5 Numeric Operations

**Generic pre-resolution names** (resolved by TypeChecker):
```
stdlib.numeric.add(a: T, b: T) -> T    -- T must impl Numeric
stdlib.numeric.sub, mul, div, neg, compare
```

**Monomorphic post-resolution names** (appear in SemanticIR):
```
stdlib.integer.add(a: Integer, b: Integer) -> Integer
stdlib.float.add(a: Float, b: Float) -> Float
stdlib.decimal.add(a: Decimal[N], b: Decimal[N]) -> Decimal[N]  -- scales must match
stdlib.decimal.mul(a: Decimal[A], b: Decimal[B]) -> Decimal[A+B]
```

---

## 8.6 Temporal / Date Primitives (PROP-013 §Temporal / Date)

```
-- CORE (pure arithmetic)
add_days(d: Date, n: Integer) -> Date
diff_days(a: Date, b: Date) -> Integer
beginning_of(d: Date, grain: Symbol) -> Date
end_of(d: Date, grain: Symbol) -> Date
day_of_week(d: Date) -> Integer

-- now() is OOF (ambient clock, Law 6):
now() -> DateTime    -- OOF-L6: use TemporalCtx.as_of instead
```

`OOF-L6` is the current source-level wording anchor for ambient-clock refusal.
This cross-reference does not mint a new OOF registry code. In managed
loop/service-loop design text, event time must enter through an explicit
TemporalCtx-style input or a materialized event binding such as `tick.time`, not
through `now()`.

---

## 8.7 Aggregate Observations (PROP-013 §Aggregate Observations)

Every aggregate operation (fold, avg, sum, etc.) must carry `aggregated_from` links
to all source observations. Without them, the aggregate is not CORE-reproducible:

```json
{
  "kind": "aggregate_observation",
  "result": { "avg_score": 87.4 },
  "aggregated_from": ["obs:abc123", "obs:def456", "obs:ghi789"]
}
```

---

## 8.8 SemanticIR Representation (PROP-013 §SemanticIR Representation)

```json
{
  "kind": "compute_node",
  "name": "total",
  "operator": "stdlib.collection.fold",
  "arg_refs": ["items", "zero", "add_fn"],
  "lambda": {
    "kind": "lambda_node",
    "params": [{"name": "acc", "type": "Integer"}, {"name": "x", "type": "Integer"}],
    "body": { "kind": "call", "operator": "stdlib.integer.add", "arg_refs": ["acc", "x"] },
    "recursive": false
  },
  "type": "Integer"
}
```

---

## 8.9 Stage 2 Stdlib (deferred — errata v0.1)

```
fold_stream     → PROP-023 (Stage 2)
history_at      → PROP-022 (Stage 2)
olap_slice      → PROP-024 (Stage 2)
```

Stage 1 compilers must treat these as OOF if encountered.

---

## 8.10 Text / String Core (experiment-pass, 2026-06-08)

**Track:** `igniter-lang/.agents/work/tracks/string-core-units-pure-stdlib-boundary-v0.md`
**Proof:** `igniter-lang/experiments/string_core_proof/string_core_proof.rb` — 60/60 PASS
**Supersedes:** §8.1 `string.ig` entry (PROP-013)

### 8.10.1 Canonical type: `Text`

`Text` is the canonical Igniter type for text values in contracts.
String literals from the parser carry `type_tag: "String"` and are
accepted as `Text` arguments without a type error (v0 compatibility rule).
`String` remains an internal metadata type for assumption schema fields only.

### 8.10.2 Grammar form (v0): bare function calls

```igniter
pure contract ConcatExample {
  input first: Text
  input second: Text
  compute result: Text = concat(first, second)
  output result: Text
}
```

Method syntax (`text.concat(other)`) is deferred.

### 8.10.3 Text unit model

Three explicit, non-ambiguous unit families.
The old `length` function from PROP-013 `string.ig` is **held/legacy** —
prefer the explicit unit-qualified ops below.

| Unit | Description | Depends on |
|------|-------------|------------|
| Byte | UTF-8 encoded bytes | encoding only |
| Rune | Unicode scalar values (code points) | encoding only |
| Grapheme | User-perceived characters (grapheme clusters, Unicode UAX #29) | Unicode algorithm dependency |

Grapheme operations are provable at the type-signature level.
Runtime implementation requires a Unicode grapheme cluster algorithm;
that implementation is a separate runtime gate.

### 8.10.4 v0 stdlib surface (14 operations)

| Source fn | SemanticIR fn | Arg types | Return type | Notes |
|-----------|--------------|-----------|-------------|-------|
| `concat` | `stdlib.text.concat` | (Text, Text) | Text | |
| `trim` | `stdlib.text.trim` | (Text) | Text | both ends, whitespace |
| `contains` | `stdlib.text.contains` | (Text, Text) | Bool | |
| `starts_with` | `stdlib.text.starts_with` | (Text, Text) | Bool | |
| `ends_with` | `stdlib.text.ends_with` | (Text, Text) | Bool | |
| `split` | `stdlib.text.split` | (Text, Text) | Collection[Text] | literal delimiter |
| `replace` | `stdlib.text.replace` | (Text, Text, Text) | Text | literal pattern; first match |
| `replace_all` | `stdlib.text.replace_all` | (Text, Text, Text) | Text | literal pattern; all matches |
| `byte_length` | `stdlib.text.byte_length` | (Text) | Integer | UTF-8 byte count |
| `rune_length` | `stdlib.text.rune_length` | (Text) | Integer | Unicode scalar values |
| `grapheme_length` | `stdlib.text.grapheme_length` | (Text) | Integer | grapheme clusters (UAX #29) |
| `byte_slice` | `stdlib.text.byte_slice` | (Text, Integer, Integer) | Text | \[start, end) bytes |
| `rune_slice` | `stdlib.text.rune_slice` | (Text, Integer, Integer) | Text | \[start, end) runes |
| `grapheme_slice` | `stdlib.text.grapheme_slice` | (Text, Integer, Integer) | Text | \[start, end) graphemes |

**v0 compat rule:** `Text` parameter positions accept `String`-typed string
literals (parser type_tag) without a type error.

### 8.10.5 OOF diagnostics

No new OOF codes. `OOF-TY0` fires for:
- Arity mismatch: `stdlib.text.<fn>: expected N argument(s), got M`
- Type mismatch: `stdlib.text.<fn> arg N: expected <Type>, got <ActualType>`

### 8.10.6 SemanticIR shape

Text stdlib calls emit as `kind: "call"` — same shape as integer ops.
No special IR kind for text operations.

```json
{
  "kind": "call",
  "fn": "stdlib.text.concat",
  "args": [
    { "kind": "ref", "name": "first",  "resolved_type": {"name": "Text", "params": []} },
    { "kind": "ref", "name": "second", "resolved_type": {"name": "Text", "params": []} }
  ],
  "resolved_type": {"name": "Text", "params": []}
}
```

`split` return carries the full parameterised type:

```json
{
  "kind": "call",
  "fn": "stdlib.text.split",
  "resolved_type": {"name": "Collection", "params": [{"name": "Text", "params": []}]}
}
```

### 8.10.7 Closed surface

The following are outside the v0 surface. Calling them produces `OOF-TY0`
(unknown function) and blocks SIR emission.

| Surface | Status |
|---------|--------|
| `regex_match`, `regex_find`, `regex_replace` | Closed — regex deferred |
| `locale_fold_case`, `upcase`, `downcase` | Closed — locale-sensitive case folding deferred |
| `tokenize`, tokenizer framework | Closed — deferred |
| `TextEngine`, streaming text | Closed — deferred |
| Parser combinators | Closed — deferred |
| Source-level method syntax (`text.concat(other)`) | Closed — forms/method sugar deferred |
| `trim_start`, `trim_end` | Closed — directional trim deferred |
| File I/O | Closed — not part of stdlib.text |
| Runtime execution, `igc run`, `.igbin` | Closed — runtime gate not open |
| Unicode algorithm authority, UAX #29 impl | Closed — runtime/impl gate |
| Bounds policy for slice (out-of-bounds semantics) | Closed — value-semantics proof required |
| Stable public stdlib.text API | Closed — experiment-pass only; no stability guarantee |

### 8.10.8 Future deferred items

| Item | Notes |
|------|-------|
| `trim_start` / `trim_end` | v0 has `trim` (both ends) only |
| Non-locale `upcase` / `downcase` | Needs case-folding model |
| Bounds error handling | out-of-bounds slice: `Result[Text, BoundsError]` or runtime panic — deferred |
| `Collection[Text]` parametric depth check | Typechecker v0 compares only top-level type name |
| Method syntax | `text.concat(other)` — after forms route |
| OOF-STR* dedicated namespace | v0 reuses `OOF-TY0`; dedicated codes deferred |
| Lab Rust symmetry | `Lab STR-CORE` gate — not yet authorized |
| Value-semantics proof | UTF-8 byte slicing fail-closed vs replacement, rune reference impl |
