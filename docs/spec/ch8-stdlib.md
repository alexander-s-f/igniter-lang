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
sum(xs: Collection[T]) -> T           -- scalar; requires Numeric[T] (Integer/Float/Decimal[N])
sum(xs: Collection[R], :field) -> F   -- field projection; F = R.field's type
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
stdlib.decimal.decimal(value: Integer, scale: Integer literal) -> Decimal[scale]
                                                -- explicit constructor; exact minor units;
                                                -- scale must be an Integer literal (OOF-DM4);
                                                -- no implicit Float/Integer -> Decimal (OOF-TY1)
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

---

## 8.11 Bytes — dynamic opaque byte sequence (LANG-STDLIB-BYTES-CANON-ADMISSION-P7, 2026-07-12)

Admission scope: the **pure dynamic `Bytes` scalar and its qualified algebra** only. Positional IO
(`stdlib.IO.read_at`/`write_at`/`file_size`) is **not** admitted by this section — it remains a
lab surface behind the capability/IO gate, exactly like the rest of `stdlib.IO.*`.

### 8.11.1 Identity

`Bytes` is a dynamically-sized, immutable, opaque sequence of octets. It has **byte-for-byte
equality**, an octet **length**, and **no ordering** (`<`/sort over Bytes is not defined; a future
consumer must justify lexicographic order explicitly). Its runtime representation is
**non-authoritative and inaccessible to authored `.ig`**: no program may construct, inspect, or
depend on the internal carrier; every admitted operation is carrier-invariant.

### 8.11.2 Qualified pure algebra (exact signatures)

`stdlib.bytes.*` is a qualified language module (the `stdlib.IO.*`/`stdlib.net.*` precedent —
qualified names, not bare-imported, not inventory entries; see 8.11.6):

```
stdlib.bytes.length(Bytes)                     -> Integer
stdlib.bytes.equal(Bytes, Bytes)               -> Bool
stdlib.bytes.concat(Bytes, Bytes)              -> Bytes
stdlib.bytes.slice(Bytes, Integer, Integer)    -> Result[Bytes, BytesError]    -- (offset, length), half-open, checked
stdlib.bytes.from_octets(Collection[Integer])  -> Result[Bytes, BytesError]    -- each octet checked 0..255
stdlib.bytes.from_text(Text)                   -> Bytes                        -- total (UTF-8 encode)
stdlib.bytes.to_text(Bytes)                    -> Result[Text, BytesError]     -- strict UTF-8; invalid input is err DATA
stdlib.bytes.pack_u16_le(Integer)              -> Result[Bytes, BytesError]    -- 0..65535
stdlib.bytes.pack_u32_le(Integer)              -> Result[Bytes, BytesError]    -- 0..4294967295
stdlib.bytes.pack_i16_le(Integer)              -> Result[Bytes, BytesError]    -- -32768..32767
stdlib.bytes.unpack_u16_le(Bytes)              -> Result[Integer, BytesError]  -- exactly 2 bytes
stdlib.bytes.unpack_u32_le(Bytes)              -> Result[Integer, BytesError]  -- exactly 4 bytes
stdlib.bytes.unpack_i16_le(Bytes)              -> Result[Integer, BytesError]  -- exactly 2 bytes
```

`BytesError` is a sealed error record `{ error_type : String, message : String }` (e.g.
`invalid_range`, `octet_out_of_range`, `invalid_utf8`, `invalid_length`). Operational failures are
**err data, never a VM abort**.

Bare `text_to_bytes` / `bytes_to_text` are thin compat aliases; both toolchains type AND emit them
as `stdlib.bytes.from_text` / `stdlib.bytes.to_text`.

**Endian/width naming law**: every pack/unpack name carries explicit width, signedness, and
endianness (`_u16_`, `_i16_`, `_le`). There is **no native-endian default** and no `_be` family
until a consumer demands one; a future `_be` family follows the same naming law.

### 8.11.3 Boundary seal — `OOF-BY1`

A contract **input or output** whose declared type contains `Bytes` — directly, nested in
`Result`/`Collection`/`Option` parameters, or through a named record's fields — is refused at
typecheck with `OOF-BY1`:

```
Bytes cannot cross the host boundary implicitly — use an explicit codec or envelope
```

Diagnostics name `Bytes`, never any internal representation. Intermediate `compute` declarations
keep the full algebra — only the host-crossing ports are sealed. A runtime host-conversion
backstop additionally refuses any carrier-shaped value that reaches a host boundary dynamically
(crafted or legacy artifacts), without echoing its contents.

### 8.11.4 Explicit host envelope — `$bytes` v1

When byte **values** must persist or cross a host boundary by explicit intent, hosts use the
versioned tagged envelope:

```json
{"$bytes": {"version": 1, "encoding": "base64", "data": "..."}}
```

This is a **host serialization contract, not language semantics**: default JSON serialization
never emits it, default deserialization never decodes it (no silent resurrection), and no
implicit encoder exists. v1 requires exact outer and inner key sets, `version == 1`,
`encoding == "base64"`, and canonical base64 data; anything else fails closed.
Application-level crossings use the explicit text codecs
(`encode_hex` / `encode_base64` → `Text`) instead.

### 8.11.5 Dual-toolchain responsibilities

Ruby/canon owns **parser + typechecker + emitter parity** (qualified names and resolved SIR type
shapes byte-comparable with the lab Rust compiler on shared fixtures) and the same `OOF-BY1`
seal. **Execution is VM authority** — the canon toolchain has no Bytes runtime, mirroring
`stdlib.IO.*`/`stdlib.net.*`.

### 8.11.6 Held boundaries

| Item | Status |
|------|--------|
| Positional IO (`read_at`/`write_at`/`file_size`) | NOT admitted — lab capability surface |
| `stdlib-inventory.json` entries for qualified modules | held — a joint IO/net/bytes inventory-ownership question, tracked separately; drift locked by tests, not by inventory |
| `Bytes[N]` fixed-length refinement | absent; future refinement over dynamic `Bytes`, kept compatible, no dependent types pretended |
| `_be` / native-endian families | closed until demanded; naming law fixed above |
| hex/base64 as identity or default representation | closed — explicit codecs only |
| ordering / sorting over Bytes | closed — no total-order claim |
| streaming / mmap / compression / crypto | closed |

---

## 8.12 Collection `sort_by` — stable total-scalar ordering (LANG-STDLIB-COLLECTION-SORT-BY-P3, 2026-07-12)

Supersedes the §8.2 placeholder signature with the v0-implemented, dual-toolchain contract. First
slice of the ordering/grouping cluster named by
`lang-stdlib-collection-order-group-readiness-p2-v0.md`; `group_by`/`index_by` remain BLOCKED on a
Map-construction VM runtime (§3 of that packet) and are not part of this admission.

### 8.12.1 Signature

```
sort_by(xs: Collection[T], key_fn: T -> K) -> Collection[T]
```

- Stable ascending sort by the extracted key; equal keys preserve authored/input order exactly.
- Element type is **unchanged** — the result is `Collection[T]`, the ORIGINAL element type, never
  `Collection[K]` (unlike `map`, sort_by reorders, it does not transform elements).
- `K` is restricted to **exactly** `Integer`, `Text`, or `Decimal` — the three total scalar orders
  live natively in the VM today (Integer: numeric; Text: byte/codepoint lexicographic, no locale
  collation; Decimal: `cmp_decimal` scale-normalized checked comparison).
- The key extractor runs **exactly once per input item** (decorate-sort-undecorate); errors from
  the extractor propagate deterministically in input order (first-in-input-order failure).
- Empty and singleton collections return unchanged with element type intact.
- No mutation of the input collection; no comparator-lambda API (the extractor shape bounds
  invocation to O(n), not O(n log n)).

### 8.12.2 Diagnostics — `OOF-COL11`

`Float`, `Bool`, `Option`, records, variants, `Map`, `Bytes`, and nested `Collection` keys are
refused fail-closed **at typecheck** (not a runtime failure) by the new diagnostic `OOF-COL11`:

```
sort_by key must have a total order; expected Integer, Text, or Decimal
```

The `Float` variant of the message additionally routes to the fix: convert to `Decimal` or
`Integer`. `OOF-COL10` is `at`'s index-type check and is **not** reused. `OOF-COL1` (arity) and
`OOF-COL2` (non-Collection first argument) are shared with the rest of the collection HOF family.

### 8.12.3 Closed (v0)

Comparator lambdas, descending or multi-key ordering, `Float` admission as a key, `Bool`/`Option`/
record/variant/`Bytes` keys, `Map` construction, `index_by`, `group_by`, `distinct_by`, relational
joins, DB/query-engine ordering, locale collation, parallel or lazy collections, mutable
collections, and any relaxation of the existing collection/step/depth/memory budgets.

### 8.12.4 Dual-toolchain responsibilities

Ruby/canon owns typechecker parity (qualified `stdlib.collection.sort_by`, `OOF-COL11` message
parity, element-type-preserved result discipline) and the `stdlib-inventory.json` entry (bare
collection ops ARE inventory-owned, unlike qualified `stdlib.IO.*`/`stdlib.net.*`/`stdlib.bytes.*`
modules). **Execution is Rust VM authority** — Ruby canon has no collection-HOF interpreter/runtime
(same boundary as every other collection op); the VM implements the bytecode `OP_CALL` arm and both
`eval_ast` HOF dispatch sites with a shared native stable merge sort.
