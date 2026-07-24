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

**Operator form**: `++` is the concat operator (Ch2 §2.2). `String ++ String`
lowers to `stdlib.string.concat` and `Collection[T] ++ Collection[T]` lowers
to `stdlib.collection.concat` in both toolchains; collection element mismatch
refuses `OOF-COL7`. `+` never concatenates. The named `concat(...)` call form
above stays accepted; `Text ++ Text` currently refuses (the operator accepts
the `String` spelling — String/Text alias seam, not a `++` decision). String
interpolation (`"a ${expr} b"`, Ch2) is parse-time sugar over the same concat
lowering. Landed by LANG-CONCAT-OPERATOR-DUAL-PARITY-P1 (2026-07-14).

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

`stdlib.bytes.*` is a qualified language module: qualified names, never bare-imported.
Since LANG-STDLIB-INVENTORY-QUALIFIED-IMPORT-SURFACE-P2 the 17 operations ARE canon inventory
entries with `import_surface: "qualified_only"` — discoverable via inventory/help/MCP, callable
only through their qualified names; a bare/named import is refused (OOF-IMP3). Capability/effect
modules (`stdlib.IO.*`, `stdlib.net.*`) remain OUT of the inventory (see 8.11.6):

```
stdlib.bytes.length(Bytes)                     -> Integer
stdlib.bytes.zeros(Integer)                    -> Bytes                        -- zero-filled; collection-budget bounded
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
stdlib.bytes.encode_hex(Bytes)                 -> Text                        -- total, canonical lower-case hex, 2 digits/octet
stdlib.bytes.decode_hex(Text)                  -> Result[Bytes, BytesError]   -- even-length 0-9/a-f/A-F only; rejects 0x/whitespace/separators
stdlib.bytes.sha256(Bytes)                     -> Text                        -- total, exactly 64 lower-case hex digits, NO prefix
```

**`zeros` — qualified zero-filled allocation
(LANG-STDLIB-BYTES-ZEROS-P2, 2026-07-24).** The exact law is:

- `stdlib.bytes.zeros(length)` returns empty `Bytes` when `length <= 0`;
- for `1 <= length <= MAX_COLLECTION_ELEMENTS`, it returns exactly `length` octets and every
  octet is `0x00`;
- for `length > MAX_COLLECTION_ELEMENTS`, evaluation fails before allocation with
  `OOF-VM-COLLECTION-BUDGET: stdlib.bytes.zeros would create <length> element(s), max 1000000`.

The signed `length <= 0` check precedes conversion to an allocation size. The positive budget
check precedes capacity calculation and allocation. `MAX_COLLECTION_ELEMENTS` is the same shared
VM limit used by collection construction; `zeros` does not define a Bytes-specific second limit.
The result is the existing opaque, sealed `Bytes` carrier: authored code can observe it only
through the public Bytes algebra, and `OOF-BY1` applies unchanged at direct and nested ports.
There is no bare `zeros`, named import, generic `bytes.fill`, non-zero fill byte, or second
embedded/carrier representation admitted by this operation.

**`sha256` — content-addressed evidence an application can author itself
(LANG-STDLIB-CONTENT-DIGEST-P1, 2026-07-23).** SHA-256 over the exact ordered octets of the
input value, rendered as exactly 64 lower-case hex digits from the alphabet `[0-9a-f]`, with no
`sha256:` prefix, whitespace or separators. It is pure, total and deterministic: the same Bytes
value always yields byte-identical Text, and every octet participates — `00`, `80` and `ff` are
hashed as bytes, never as text or as signed integers. The NIST anchors hold:

```
stdlib.bytes.sha256(from_octets([]))        = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
stdlib.bytes.sha256(from_text("abc"))       = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
```

**The caller owns framing.** A receipt or intent that wants `sha256:<64-lower-hex>` builds that
text itself; the cryptographic operation does not carry receipt syntax, an algorithm parameter or
a tagged digest record, and it does not hash `Text` implicitly — encode first with `from_text`,
so the octets being digested are the ones the author chose.

**What this is NOT**, stated because a digest is routinely mistaken for all of them: it is not
password hashing, not a MAC or signature, not a secret-redaction mechanism, not canonical JSON
hashing, and not a streaming API. Above all it is **not evidence that the digested content is
true, trusted, admitted or authorized** — it says only that these exact octets hash to this
value. Whoever consumes the digest still owes the argument about where the octets came from.

`BytesError` is a sealed error record `{ error_type : String, message : String }` (e.g.
`invalid_range`, `octet_out_of_range`, `invalid_utf8`, `invalid_length`, `invalid_hex`).
Operational failures are **err data, never a VM abort**.

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
Application-level crossings use the explicit text codec — `stdlib.bytes.encode_hex` /
`stdlib.bytes.decode_hex` (`Bytes <-> Text`, canonical lower-case hex, LANG-STDLIB-BYTES-HEX-CODEC-P1)
— instead. A base64 text codec remains deferred (8.11.6).

### 8.11.5 Dual-toolchain responsibilities

Ruby/canon owns **parser + typechecker + emitter parity** (qualified names and resolved SIR type
shapes byte-comparable with the lab Rust compiler on shared fixtures) and the same `OOF-BY1`
seal. **Execution is VM authority** — the canon toolchain has no Bytes runtime, mirroring
`stdlib.IO.*`/`stdlib.net.*`.

### 8.11.6 Held boundaries

| Item | Status |
|------|--------|
| Positional IO (`read_at`/`write_at`/`file_size`) | NOT admitted — lab capability surface |
| `stdlib-inventory.json` entries for qualified modules | RESOLVED for pure Bytes (17 rows, `import_surface: "qualified_only"`, LANG-STDLIB-INVENTORY-QUALIFIED-IMPORT-SURFACE-P2, LANG-STDLIB-BYTES-HEX-CODEC-P1, LANG-STDLIB-CONTENT-DIGEST-P1, LANG-STDLIB-BYTES-ZEROS-P2); capability/effect modules (`stdlib.IO.*`, `stdlib.net.*`) stay OUT — the separately-owned capability catalog remains a named follow-up |
| `Bytes[N]` fixed-length refinement | absent; future refinement over dynamic `Bytes`, kept compatible, no dependent types pretended |
| `_be` / native-endian families | closed until demanded; naming law fixed above |
| hex as identity or default representation | closed — `encode_hex`/`decode_hex` (LANG-STDLIB-BYTES-HEX-CODEC-P1) are explicit codecs, not a default representation |
| base64 text codec | deferred — `$bytes` v1 host envelope already uses base64 internally; no `encode_base64`/`decode_base64` language-level codec exists yet |
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

Comparator lambdas, multi-key ordering, `Float` admission as a key, `Bool`/`Option`/
record/variant/`Bytes` keys, `Map` construction, `index_by`, `group_by`, `distinct_by`, relational
joins, DB/query-engine ordering, locale collation, parallel or lazy collections, mutable
collections, and any relaxation of the existing collection/step/depth/memory budgets.

> **Narrowed 2026-07-21** (LANG-STDLIB-COLLECTION-SORT-BY-DESC-PROP-P1): this list originally
> also closed "descending ordering". That single item is narrowed by §8.14 — stable descending
> ordering is admitted as the separate sibling operation `sort_by_desc`, with its own section.
> `sort_by` itself is unchanged: it remains ascending-only, and comparator lambdas, runtime
> direction parameters, and multi-key ordering remain closed for BOTH operations.

### 8.12.4 Dual-toolchain responsibilities

Ruby/canon owns typechecker parity (qualified `stdlib.collection.sort_by`, `OOF-COL11` message
parity, element-type-preserved result discipline) and the `stdlib-inventory.json` entry (bare
collection ops ARE inventory-owned, unlike qualified `stdlib.IO.*`/`stdlib.net.*`/`stdlib.bytes.*`
modules). **Execution is Rust VM authority** — Ruby canon has no collection-HOF interpreter/runtime
(same boundary as every other collection op); the VM implements the bytecode `OP_CALL` arm and both
`eval_ast` HOF dispatch sites with a shared native stable merge sort.

## 8.13 Collection `take` — prefix-bounded reader (LANG-STDLIB-COLLECTION-TAKE-CANON-P5, 2026-07-13)

Supersedes the §8.2 placeholder signature with the v0-implemented, dual-toolchain contract. The
predicate/query slice (`find`/`any`/`all`) and the ordering slice (`sort_by`, §8.12) landed first;
`take` is the slicing-cluster promotion named by
`lang-stdlib-collection-algebra-parity-prop-p1-v0.md` (`drop`, `chunk`, `window`, lazy iteration,
and pagination policy remain OUT of scope — see §8.13.3).

### 8.13.1 Signature

```
take(xs: Collection[T], n: Integer) -> Collection[T]
```

- A prefix-bounded **READER**, not a HOF — the second argument is an Integer count, never a
  predicate lambda (unlike `filter`/`sort_by`/`find`/`any`/`all`, `take` never binds a lambda
  parameter to the element type).
- Preserves input order; element type is **unchanged** — the result is `Collection[T]`, the
  ORIGINAL element type (the same discipline as `filter`/`sort_by`, never `map`'s transform).
- `n <= 0` (including negative `n`) returns `[]`.
- `n >= count(xs)` returns all input elements (clamped, never an error, never padded).
- Otherwise returns exactly the first `n` elements.
- Pure, finite, deterministic, no mutation, no authority surface.

### 8.13.2 Diagnostics — `OOF-COL12`

A second argument that is neither `Integer` nor `Unknown` — including a predicate lambda, which is
explicitly refused rather than silently accepted as a HOF — is refused fail-closed **at typecheck**
by the new diagnostic `OOF-COL12`:

```
stdlib.collection.take: second argument must be Integer, got <Type>
```

`OOF-COL10` is `at`'s index-type check and `OOF-COL11` is `sort_by`'s key-type check — neither is
reused. `OOF-COL1` (arity) and `OOF-COL2` (non-Collection first argument) are shared with the rest
of the collection HOF family. Runtime bounds (`n<=0`, `n>=count(xs)`) are never diagnostics — they
are total, clamped VM semantics.

### 8.13.3 Closed (v0)

`drop`, `chunk`, `window`, lazy/streaming iteration, pagination policy beyond a single `take`,
database pushdown, comparator-driven slicing, and any new effect/capability surface.

### 8.13.4 Dual-toolchain responsibilities

Ruby/canon owns typechecker parity (dedicated `infer_take_call`, qualified
`stdlib.collection.take`, `OOF-COL12` message parity, element-type-preserved result discipline) and
the `stdlib-inventory.json` entry. Before this card, Ruby canon had **zero** `take` support at all
(confirmed live: `OOF-TY0 "Unknown function: take"`). **Execution is Rust VM authority** — the
bytecode `OP_CALL` arm and both `eval_ast` HOF dispatch sites already executed `take` before this
card (the existing `stdlib.collection.*` -> bare qualified-name normalization already covered it);
this card is a canon-admission/parity promotion, not a new VM capability. The Rust lab compiler
previously shared a `"filter" | "take"` typechecker arm that gave `take` no arity/type diagnostics
of its own — it now has a dedicated arm, and the emitter's bare-name qualify lists were extended so
`take` reaches the SIR as `stdlib.collection.take` (mirroring `sort_by`, not `at`'s deliberate bare
choice).

## 8.14 Collection `sort_by_desc` — stable descending total-scalar ordering (LANG-STDLIB-COLLECTION-SORT-BY-DESC-PROP-P1, 2026-07-21)

Canon-ACCEPTED, spec-first: unlike §8.12/§8.13, this section was written at ADMISSION time, before
any toolchain implemented the operation. Per-toolchain state: canon Ruby types and lowers the call
as of `LANG-STDLIB-COLLECTION-SORT-BY-DESC-P2` (2026-07-21); Rust compiler typing/lowering and VM
bytecode/eval-AST execution landed in `LANG-STDLIB-COLLECTION-SORT-BY-DESC-P3` (2026-07-22), with
the normative stable-tie specimen and existing ceilings executable-proven; the inventory row and
generated Surface Catalog still wait for P4. Second slice
of the ordering cluster named by `lang-stdlib-collection-order-group-readiness-p2-v0.md`; admitted
on the measured evidence of `lang-stdlib-collection-reverse-prepend-readiness-p1-v0.md`
(igniter-lab `lab-docs/lang/`).

### 8.14.1 Signature and laws

```
sort_by_desc(xs: Collection[T], key_fn: T -> K) -> Collection[T]
```

- **Stable DESCENDING sort** by the extracted key; equal keys preserve authored/input order
  exactly — the SAME tie discipline as ascending `sort_by`, NOT its mirror image (§8.14.2).
- Element type is **unchanged** — the result is `Collection[T]`, the ORIGINAL element type, never
  `Collection[K]` (sort_by_desc reorders, it does not transform elements).
- `K` is restricted to **exactly** `Integer`, `Text`, or `Decimal` — the same three total scalar
  orders as `sort_by` (§8.12.1). Descending is defined as the strict inversion of the SAME order
  relation: Integer numeric inverted; Text byte/codepoint lexicographic inverted (no locale
  collation); Decimal `cmp_decimal` scale-normalized comparison inverted. Descending-by-`Text` is
  therefore a first-class capability, NOT an arithmetic key trick — no `BIG - key` inversion
  exists for `Text`, which is one of the two measured admission drivers.
- The key extractor runs **exactly once per input item** (decorate-sort-undecorate); errors from
  the extractor propagate deterministically in input order (first-in-input-order failure) —
  identical to `sort_by`.
- Empty and singleton collections return unchanged with contextual element type preserved.
- Pure, deterministic, no mutation of the input collection, no authority surface, and the SAME
  collection/step/depth/memory budget posture as `sort_by` — one stable merge sort with the
  comparison inverted charges exactly what the ascending sort charges.

### 8.14.2 The tie non-law (normative)

`sort_by_desc(xs, k)` is explicitly **NOT** `reverse-of(sort_by(xs, k))` whenever any tie group
has two or more members. The measured canonical counterexample (readiness packet §2.1):

```
items                                = [(k=10,seq=1) (k=5,seq=2) (k=10,seq=3) (k=5,seq=4) (k=7,seq=5)]
sort_by(items, it -> it.key)         → keys [ 5, 5, 7,10,10]  seq [2,4,5,1,3]   (stable ascending)
element-reversal of that result      → keys [10,10, 7, 5, 5]  seq [3,1,5,4,2]   (ties ANTI-stable)
sort_by_desc(items, it -> it.key)    → keys [10,10, 7, 5, 5]  seq [1,3,5,2,4]   (ties stable)
```

Both descending routes produce IDENTICAL key sequences and DIFFERENT element order — the
difference is invisible in the key column and only shows in the payload. What IS a law is the
keys-only duality: `map(sort_by_desc(xs,k), k)` equals the element-reversal of
`map(sort_by(xs,k), k)`. Implementations MUST realize descending order by inverting the key
comparison inside the same stable merge (`Less`/`Greater` swapped, `Equal` unchanged) — NEVER by
reversing an ascending result, which silently violates the tie law behind an identical key column.

### 8.14.3 Diagnostics — `OOF-COL11` reused

Unsupported key shapes (`Float`, `Bool`, `Option`, records, variants, `Map`, `Bytes`, nested
`Collection`) are refused fail-closed **at typecheck** by the EXISTING diagnostic `OOF-COL11` —
the key-type law is shared with `sort_by`, so no competing code is minted:

```
sort_by_desc key must have a total order; expected Integer, Text, or Decimal
```

The `Float` variant of the message routes to the fix (convert to `Decimal` or `Integer`), exactly
as in §8.12.2. `OOF-COL1` (arity) and `OOF-COL2` (non-Collection first argument) are shared with
the rest of the collection HOF family. `OOF-COL10` (`at`) and `OOF-COL12` (`take`) are not reused.

### 8.14.4 Closed (v0)

Comparator lambdas, runtime string/enum direction parameters (a direction-aware `sort_by` may
later be defined only as sugar OVER this operation), multi-key ordering, `Float` admission as a
key, any `_asc` alias for `sort_by`, `reverse`, `prepend`, `min_by`/`max_by`, `Map` construction,
`index_by`, `group_by`, `distinct_by`, locale collation, parallel or lazy collections, mutable
collections, and any relaxation of the existing collection/step/depth/memory budgets.

### 8.14.5 Dual-toolchain responsibilities and implementation cards

Same ownership boundary as §8.12.4: Ruby/canon owns typechecker parity (a dedicated
`infer_sort_by_desc_call` mirroring `infer_sort_by_call`, qualified
`stdlib.collection.sort_by_desc`, `OOF-COL11` message parity, element-type-preserved result
discipline) and the `stdlib-inventory.json` entry; **execution is Rust VM authority** — the
bytecode `OP_CALL` arm and the live nested `eval_ast` HOF dispatcher share the existing native
stable merge sort (`compare_sort_by_keys` / `stable_sort_by_key_pairs`) with the comparison
inverted per §8.14.2. Implementation sequence (named at admission; each gates the next):

```text
LANG-STDLIB-COLLECTION-SORT-BY-DESC-P2   canon Ruby typing + proof suite (incl. a dedicated
                                         tie-stability case reproducing §8.14.2)
LANG-STDLIB-COLLECTION-SORT-BY-DESC-P3   Rust compiler parity + VM execution (bytecode arm +
                                         both eval_ast sites; eval_ast<->bytecode parity;
                                         100k-element budget proof mirroring sort_by's)
LANG-STDLIB-COLLECTION-SORT-BY-DESC-P4   stdlib-inventory.json row + surface-digest recompute +
                                         runtime_stdlib_op_catalog() census sync
```

## 8.15 `stdlib.math` — the scalar/transcendental surface in three reproducibility tiers (LANG-STDLIB-MATH-SURFACE-CANON-ADMISSION-P2, 2026-07-22)

Admits fifteen operations that were already executable in the lab VM but had **no canon standing**:
no spec section, no inventory row, no import path, and — decisively — canon Ruby refused every one
of them with `OOF-TY0 Unknown function`. Runtime callability is not admission; this section, the
inventory rows and dual-toolchain typing together are.

The surface is deliberately split into **three tiers that differ only in what they promise about
reproducibility**. The distinction IS the canon value: a program that must replay bit-identically
elsewhere may use N0 and D1 freely, and must treat F1 as a platform-dependent convenience.

### 8.15.1 Tier N0 — scalar helpers, deterministic by construction

```
abs(x: T) -> T          min(a: T, b: T) -> T          max(a: T, b: T) -> T
clamp(x: T, lo: T, hi: T) -> T                        sign(x: T) -> Integer
```

- `T` is `Integer` or `Float`, **homogeneous**. There is no implicit coercion: a mixed pair is
  refused at typecheck with `OOF-MATH3`. `Decimal` is deliberately NOT admitted here — a Decimal
  surface needs its own pressure and its own checked-scale law.
- `abs`/`min`/`max`/`clamp` return the operand type `T`; `sign` returns `Integer` in `{-1, 0, 1}`.
- **`sign(-0.0) == 0`** — consistent with §8.14's signed-zero law, where `-0.0 == 0.0`.
- `clamp(value, lo, hi)` refuses `lo > hi` at runtime rather than silently reordering the bounds.
- Integer overflow fails closed, including `abs(i64::MIN)`, which has no positive counterpart.
- These are deterministic BY CONSTRUCTION: comparisons and sign flips are bit-identical on every
  target, so N0 needs no `det_*` sibling.

**`min`/`max` are overloaded, and this admission does not close the overload.** The bare names
are declared twice in canon `.ig` source: the scalar helpers above (`stdlib.Math`,
`math.ig:41-42`) and the collection aggregates `min(coll: Collection[T], field: Symbol) ->
Option[T]` (`stdlib.Collections`, `collections.ig:20-21`). They are routed by **first-argument
type** — a `Collection` first argument selects the aggregate, anything else selects the scalar
helper. This admission is **additive only**: it claims the scalar reading and leaves the
aggregate reading exactly as it was, including its refusal text where a toolchain does not
implement it. A toolchain must never answer the aggregate shape with `OOF-MATH2`, which would
assert that a live `collections.ig` declaration is a type error.

Consequence for the published surface: `stdlib.math.min` and `stdlib.math.max` are the only two
rows of this admission that the Surface Catalog reports as `conflicting`
(`declared_identity_matches_multiple_source_defs`), because the catalog's identity join is
bare-name based and both `.ig` defs are real. That verdict is CORRECT — it is the overload made
visible, not a defect in either plane — and it is the same shape already carried by
`stdlib.collection.concat`. Collapsing it would require a module-qualified identity join, which
is a Surface Catalog change with its own blast radius and belongs to its own card.

### 8.15.2 Tier F1 — fast platform-f64

```
sin(x: Float) -> Float    cos(x: Float) -> Float    sqrt(x: Float) -> Float    pi() -> Float
```

- Evaluated through the platform's own f64 routines. They are tolerance-tested and make **no
  bit-identical cross-ISA claim**. A program whose replay must be bit-exact on another
  architecture uses Tier D1 instead.
- Inputs and results must be FINITE. `sqrt(x)` refuses `x < 0` and a non-finite input is refused
  for all three — a canon-visible `NaN` is a leak, not a value. (Before this admission `sqrt(-1.0)`
  returned a NaN that serialized as `null`; closing that was a precondition of publishing the row,
  not a footnote.)
- No implicit `Integer`/`Decimal` conversion is introduced by this tier.

### 8.15.3 Tier D1 — deterministic, fixed-carrier

```
det_sin  det_cos  det_sqrt  det_ln  det_exp  det_tan     -- each (Float) -> Float
```

- Their contract is a **fixed result carrier plus golden-bit drift locks**: vendored pure-Rust
  `libm` owns `det_sin`, `det_cos`, `det_ln`, `det_exp` and `det_tan`; IEEE-correct
  `f64::sqrt` owns `det_sqrt`. This section claims governed deterministic execution; it does
  **not** claim verified multi-ISA parity — cross-architecture confirmation is a separate CI
  matter and must not be inferred from this text.
- Non-finite inputs and non-finite results fail closed.
- `det_sqrt` requires `x >= 0`; `det_ln` requires `x > 0`; `det_exp` refuses overflow while finite
  underflow to zero is permitted; `det_tan` refuses a non-finite pole result.

### 8.15.4 Identity, spelling and diagnostics

- The natural BARE spelling is the source form (`sqrt(x)`), and both toolchains lower it to the
  qualified identity `stdlib.math.sqrt`. **No newly emitted SIR row carries a bare math identity.**
  Bare names remain runtime compatibility inputs so previously compiled artifacts keep executing.
- `import stdlib.math` and selective `import stdlib.math.{ … }` expose the natural bare call
  spelling; the emitted SIR identity remains qualified. This section does not introduce a new
  dotted function-call source grammar.
- Recognized typed collection-HOF bodies emit the same qualified identity as direct positions
  (the lexical-environment owner admitted by `LANG-NUMERIC-LAMBDA-OPERATOR-IDENTITY-P3`).
- Diagnostics reuse the already-authoritative families verbatim in BOTH toolchains — `OOF-MATH1`
  arity, `OOF-MATH2` wrong argument type, `OOF-MATH3` mixed numeric family. No new code is minted.
- Direct `OP_CALL` and nested eval-AST execution return byte-identical values, or the same bounded
  refusal, for the same qualified identity.

### 8.15.5 Closed (v0)

`isqrt`, `ipow` and bare `mod` (the last collides with the admitted `stdlib.integer.modulo` — two
spellings for one Euclidean remainder), `to_float`, `float_to_text`, Decimal math, Float sort keys,
implicit numeric coercion, locale/formatting concerns, quantization, and any new algorithm added
for symmetry rather than for measured pressure.

### 8.15.6 Dual-toolchain responsibilities

Canon Ruby owns typing parity through one owner-local `MATH_STDLIB_FNS` table (arity, accepted
types, result type, the three OOF-MATH families) and the `stdlib-inventory.json` rows. **Execution
is Rust VM authority** — the same boundary as every other stdlib family; the VM owns the single
math semantic owner that both the bytecode and eval-AST paths call, and it owns the domain and
finite-value refusals stated above.
