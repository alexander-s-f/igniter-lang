# PROP-043: Map[K, V] Stage 1 Surface — Immutable Homogeneous Maps

**PROP:** 043
**Track:** prop043-map-kv-design-lock-v0
**Status:** design-lock (P1 authored 2026-06-09)
**Depends on:** PROP-004 (ch3 type grammar), PROP-013 (stdlib), LAB-DYNAMIC-DATA-P1
**Author:** Portfolio Architect Supervisor
**Gate route:** proof-local P2 → production promotion P3+ (P4/P5 auth)

---

## 1. Motivation

`Map[K, V]` appears in the Igniter ch3 type grammar (PROP-004 §3.1) and in the EBNF
(`TypeRef ::= ... | "Map[" TypeRef "," TypeRef "]"`), but is not in the Stage 1
compiler-proven subset. The production typechecker treats `Map[K,V]` annotations as
opaque — no Map-specific typing rules, no stdlib lookup operations, no SemanticIR
node kinds for Map construction or lookup.

This gap is concrete and blocking:

- **Rack headers** (`Map[String, String]`) were explicitly deferred in LAB-RACK-P12
  because Map[K,V] had no proven typechecking path. RackResponse was simplified to
  `{ status: Integer, body: String }` as a result.
- **Query params**, **cookie keys**, **environment variables**, and **configuration
  tables** all have the same `Map[String, String]` shape.
- **Any web framework design** requires Map[String,String] as a first-class type.

Named `Record` (proven via LAB-RACK-P12/P13, LAB-SIDEKIQ-P4) covers known-schema data
well. `Map[K,V]` covers the remainder: data whose *key set* is dynamic at runtime but
whose *value type* is uniform. These are distinct design needs, not alternatives.

---

## 2. Design Stance

`Map[K, V]` in Igniter Stage 1 is:

- **Immutable.** Once created, a Map cannot be mutated. Deriving a new Map with one
  entry changed returns a new Map. `Ref[Map[K,V]]` is possible but requires ESCAPE.
- **Homogeneous.** All values have type `V`. `Map[String, Any]` is permanently closed.
  Heterogeneous value types require named Records or `Variant`.
- **Dynamic-key.** The key set is not known at compile time (contrast: Record fields).
  Lookup always returns `Option[V]` — presence is never guaranteed by the type system.
- **Not a Record substitute.** A Map with a known static key set should be a named
  `Record`, not a `Map`. The compiler does not prevent misuse, but the design intent
  is law: `Map` is for genuinely dynamic key sets only.

This stance follows directly from Covenant Axiom 1 (Honesty), Postulate 5 (Immutable
Outputs), and ch3 §3.9 (Any discouraged at contract boundaries).

---

## 3. Grammar / Type Annotation (§3.1 — already in parser)

The production parser (`parse_type_ref`) already handles `Map[K,V]`:

```
Map[String, String]  →  { "kind": "type_ref", "name": "Map",
                          "params": [
                            { "kind": "type_ref", "name": "String", "params": [] },
                            { "kind": "type_ref", "name": "String", "params": [] }
                          ] }
```

**No parser change is needed for type annotations.**

A future literal syntax (`{ "key" => value }`) would require a new grammar production
(`MapLit`). This is **deferred to v1** — see §5.

### 3.1 Confirmed grammar form (v0)

Type annotations in `input`, `output`, `compute` declarations:

```igniter
input  headers    : Map[String, String]
output params     : Map[String, String]
compute filtered  = stdlib.map.get(headers, "content-type")
```

### 3.2 Type annotation shape in SemanticIR (v0)

```json
{
  "name": "Map",
  "params": [
    { "name": "String", "params": [] },
    { "name": "String", "params": [] }
  ]
}
```

This is the standard `type_ir` output. The typechecker `type_ir` method produces this
already for any `{ "kind" => "type_ref", "name" => "Map", "params" => [...] }` annotation.

---

## 4. Key Type Restrictions (v0)

**v0 restricts K to `String` only.**

Rationale: The immediate proven need is `Map[String, String]` (HTTP headers, query params).
Generic `Map[K,V]` with arbitrary K raises key constraint questions (what makes a valid key
type — comparable? hashable? orderable?) that are not yet decided and not yet needed.

**v0 rule:** If K is not `String`, the typechecker emits OOF-MAP1 (candidate).

`Map[String, V]` for any Stage 1 V is valid. Examples:
- `Map[String, String]` ✅ — headers, query params
- `Map[String, Integer]` ✅ — integer-valued configuration
- `Map[String, Bool]` ✅ — feature flags
- `Map[String, Collection[String]]` ✅ — multi-value headers
- `Map[Integer, String]` ❌ → OOF-MAP1 (Integer key: v1)
- `Map[Symbol, String]` ❌ → OOF-MAP1 (Symbol key: v1)
- `Map[String, Any]` ❌ → OOF-MAP2 (Any value: permanently closed)

**Design decision: `group_by` exception.** The `group_by` stdlib function returns
`Map[K, Collection[T]]` where K is derived from the key function. This is a *computed*
result type, not a user-declared annotation. The key constraint in §4 applies to
*user-declared annotations* only. The typechecker may propagate a `Map[Integer, ...]`
result from `group_by` without triggering OOF-MAP1 — the constraint is on explicit
user-written type annotations in `input`/`output`/`compute` declarations.

---

## 5. Literal Syntax — Deferred to v1

**No map literal syntax in v0.** Map values may only enter a contract through:
1. An `input` declaration typed `Map[String, V]` (external caller provides the value)
2. Constructed via `stdlib.map.from_pairs` (see §6)
3. Returned by `stdlib.collection.group_by` (computed result)

A future v1 map literal would require a new parser production:
```ebnf
MapLit ::= "map" "{" (StrLiteral "=>" Expr ("," StrLiteral "=>" Expr)*)? "}"
```

The `map { ... }` keyword prefix disambiguates from `RecordLit { name: expr }`.
Using `{ "key" => value }` without a prefix keyword risks parsing ambiguity with
existing `RecordLit` and `BlockExpr` productions. This design is explicitly deferred.

**Why defer?** Proof-local P2 can validate Map[String,String] semantics without a literal
syntax: fixture contracts receive Map values as inputs, which is the primary use case
(HTTP request headers are provided by the caller, not constructed in the contract body).

---

## 6. Stdlib Surface (`stdlib.map.*`)

### 6.1 v0 — Required operations

| Function | Signature | SemanticIR fn name | Notes |
|----------|-----------|-------------------|-------|
| `get` | `(m: Map[String,V], k: String) → Option[V]` | `stdlib.map.get` | Primary lookup. Never returns Unknown or null. |
| `has_key` | `(m: Map[String,V], k: String) → Bool` | `stdlib.map.has_key` | Explicit presence check. |
| `from_pairs` | `(pairs: Collection[{key: String, value: V}]) → Map[String,V]` | `stdlib.map.from_pairs` | Construction from a key-value collection. |
| `empty` | `() → Map[String,V]` | `stdlib.map.empty` | Returns an empty Map of the declared type. |

### 6.2 v1 — Deferred operations

| Function | Signature | Notes |
|----------|-----------|-------|
| `with_entry` | `(m: Map[K,V], k: K, v: V) → Map[K,V]` | Immutable update; returns new Map |
| `without_key` | `(m: Map[K,V], k: K) → Map[K,V]` | Immutable delete |
| `keys` | `(m: Map[K,V]) → Collection[K]` | Key enumeration |
| `values` | `(m: Map[K,V]) → Collection[V]` | Value enumeration |
| `size` | `(m: Map[K,V]) → Integer` | Entry count |
| `merge` | `(a: Map[K,V], b: Map[K,V]) → Map[K,V]` | Right-biased merge |
| `to_pairs` | `(m: Map[K,V]) → Collection[{key:K, value:V}]` | Round-trips with `from_pairs` |

### 6.3 Map count and numeric measure

`count(m: Map[K,V]) → Integer` — delegates to T3 numeric measure proposal (PROP-042).
A `decreases count(entries)` form on a `Map[String, V]` would use the same `count`
builtin as Collection[T]. This is noted here for cross-reference; not required for PROP-043 v0.

### 6.4 Type inference rules for `stdlib.map.get`

```
Rule MAP-GET:
  m : Map[String, V]
  k : String
  ─────────────────────────────────────────
  stdlib.map.get(m, k) : Option[V]
```

The return type is always `Option[V]` where V is inferred from the Map type annotation
of `m`. If `m` has type `Unknown`, the return type is `Unknown` (Unknown-compat propagation).
If `m` has type `Map[String, String]`, the return type is `Option[String]`.

### 6.5 Type inference rules for `stdlib.map.from_pairs`

```
Rule MAP-FROM-PAIRS:
  pairs : Collection[{ key: String, value: V }]
  ──────────────────────────────────────────────
  stdlib.map.from_pairs(pairs) : Map[String, V]
```

In v0, where no map literal exists, `from_pairs` is the primary construction path.

---

## 7. SemanticIR Shapes

### 7.1 Map type annotation (already works)

Represented as a standard `type_ir` result:
```json
{ "name": "Map", "params": [{ "name": "String", "params": [] }, { "name": "String", "params": [] }] }
```

No new IR change needed for type annotations.

### 7.2 Map lookup call node (v0)

Map `get` is a stdlib call — uses the existing `call` node kind:

```json
{
  "kind": "call",
  "fn": "stdlib.map.get",
  "args": [
    { "kind": "ref", "name": "headers", "resolved_type": { "name": "Map", "params": [...] } },
    { "kind": "literal", "value": "content-type", "type": "String" }
  ],
  "resolved_type": { "name": "Option", "params": [{ "name": "String", "params": [] }] }
}
```

No new node kind needed — `call` node with `fn: "stdlib.map.get"` is sufficient.

### 7.3 Map construction via `from_pairs`

```json
{
  "kind": "call",
  "fn": "stdlib.map.from_pairs",
  "args": [{ "kind": "ref", "name": "pairs", "resolved_type": { "name": "Collection", "params": [...] } }],
  "resolved_type": { "name": "Map", "params": [{ "name": "String", "params": [] }, { "name": "String", "params": [] }] }
}
```

### 7.4 Map literal node (v1 — not in v0)

When v1 literal syntax is added, a new node kind would be introduced:
```json
{
  "kind": "map_literal",
  "entries": [
    { "key": "content-type", "value": { "kind": "literal", "value": "text/html", "type": "String" } }
  ],
  "resolved_type": { "name": "Map", "params": [{ "name": "String", "params": [] }, { "name": "String", "params": [] }] }
}
```

This is **deferred to v1** (requires parser change for `MapLit` grammar production).

### 7.5 Contract IR with Map annotations

```json
{
  "contract_name": "GetRootHandler",
  "modifier": "pure",
  "declarations": [
    { "name": "method",  "kind": "input",  "type": { "name": "String", "params": [] } },
    { "name": "path",    "kind": "input",  "type": { "name": "String", "params": [] } },
    { "name": "headers", "kind": "input",  "type": { "name": "Map", "params": [{ "name": "String", "params": [] }, { "name": "String", "params": [] }] } },
    { "name": "content_type", "kind": "compute", "type": { "name": "Option", "params": [{ "name": "String", "params": [] }] } },
    { "name": "response", "kind": "output", "type": { "name": "RackResponse", "params": [] } }
  ]
}
```

---

## 8. Failure Semantics (Design Lock)

These failure semantics are design-locked and must not be changed without a new PROP:

| Failure case | Correct semantic | Closed alternatives |
|-------------|-----------------|---------------------|
| Missing key in `get` | `None` (Option[V]) | `Unknown`, `null`, runtime error, default value as primary return |
| Key is not String in v0 annotation | OOF-MAP1 at typecheck time | Silently accepting; Using Unknown |
| Value type is `Any` | OOF-MAP2 at typecheck time | Silently accepting; Treating as valid |
| Map used where named Record expected | OOF-TY0 type mismatch (existing) | No error (dangerous implicit widening) |
| `get` on Unknown-typed map | Returns Unknown (Unknown-compat) | Not applicable |

The canonical lookup pattern in Igniter:

```igniter
-- Preferred: named lookup with explicit fallback
compute content_type = or_else(stdlib.map.get(headers, "content-type"),
                               "application/octet-stream")

-- Preferred: presence-guarded branch
compute has_auth = stdlib.map.has_key(headers, "authorization")
compute auth_value = stdlib.map.get(headers, "authorization")
```

---

## 9. Diagnostic Candidates (OOF-MAP*)

These codes are **experiment-only candidates** until production promotion via P3+.

| Code | Trigger | Message template |
|------|---------|-----------------|
| `OOF-MAP1` | `Map[K,V]` annotation where K ≠ String in v0 | `"Map key type in v0 must be String; Map[K,V] where K = '{K}' requires v1 authorization; use Map[String,V] or a named Record for known key schemas"` |
| `OOF-MAP2` | `Map[K,Any]` annotation | `"Map value type 'Any' is permanently closed at contract boundaries; use a homogeneous type V or a named Record"` |
| `OOF-MAP3` | `Map[K,Unknown]` declared as output annotation | `"Map value type 'Unknown' is a compiler uncertainty marker and must not appear in user-declared output type annotations"` |

OOF-MAP1 and OOF-MAP2 are **blocking** (prevent SemanticIR emission). OOF-MAP3 is **blocking**.

Note: OOF-MAP1–3 are candidates. They require production promotion (P3+) before they are
canonical error codes. In proof-local P2, they are exercised as experiment diagnostics.

---

## 10. Interaction with Named Records (Design Lock)

**Principle:** Map is for genuinely dynamic key sets. Named Record is for known schemas.

These two types must not be interchangeable:
- `Map[String, String]` ≠ `Record { status: String, body: String }` (even if both have String values)
- The type system enforces this: a `Map[String,String]` cannot be passed where `RackResponse` is expected (OOF-TY0)
- The type system does NOT enforce that "you should use a Record when the keys are static" — this is a design intent, enforced by convention and code review, not by a new diagnostic

Legitimate Map uses (v0):
- HTTP request headers: `Map[String, String]` ✅
- HTTP query parameters: `Map[String, String]` ✅
- Environment variables: `Map[String, String]` ✅
- Feature flag overrides: `Map[String, Bool]` ✅
- Multi-value parameters: `Map[String, Collection[String]]` ✅

Incorrect Map uses that should instead be named Records:
- `Map[String, String]` with keys `{ job_class, job_id, attempt }` → should be `JobReceipt` ❌
- `Map[String, Integer]` with keys `{ status }` → should be inline `status: Integer` field ❌

---

## 11. JSON Boundary Relationship (Design Lock)

**No change to JSON status.** PROP-043 does not open JSON.

- `JsonValue` remains deferred (no grammar, no stdlib, no PROP)
- `JsonObject` does not exist and is NOT defined as `Map[String, JsonValue]` in v0
- JSON parse/decode remains closed
- `Map[String, String]` is NOT the same as `JsonObject` — they are semantically distinct
  (`Map` is a language-internal type; `JsonObject` is a boundary serialization artifact)
- HTTP request body parsing (raw JSON → typed value) remains closed

If `JsonValue` is introduced in a future PROP, it will be a stdlib type, NOT a grammar
primitive, and its `JsonObject` component will be defined separately with its own design
decisions around duplicate key handling and key order preservation.

---

## 12. Explicitly Closed Surfaces

| Surface | Closed because |
|---------|---------------|
| `Map[K,Any]` | Heterogeneous values; violates Axiom 1 |
| `Map[K,Unknown]` in user annotations | Unknown is compiler state, not a domain type |
| Map mutation / `Ref[Map[K,V]]` outside ESCAPE | Violates Postulate 5 (immutable outputs) |
| Map literal syntax in v0 | Parser change deferred; from_pairs covers construction |
| Map with non-String key in v0 | Key constraints not yet designed; only String keys proven |
| `Map[String, JsonValue]` | JsonValue not designed; closes JSON scope creep |
| Map as a substitute for named Records | Design intent law; Records are always preferred for known schemas |
| `stdlib.map.*` production implementation | Requires P3+; proof-local P2 next |
| Production compiler edits | Requires P4/P5 authorization; proof-local P2 is the gate |
| Runtime execution / VM map operations | Closed until production MapLiteral/MapLookup bytecode designed |

---

## 13. P2 Proof-Local Fixture Matrix

The P2 proof-local experiment should validate all of the following.

### Section MAP-A: Type annotation acceptance (≥3 checks)

| Fixture | Contract | Declaration | Expected |
|---------|----------|------------|----------|
| `map_a_string_string.ig` | `HeadersPass` | `input headers: Map[String, String]` | No OOF; type = Map[String,String] |
| `map_a_string_integer.ig` | `IntValPass` | `input counts: Map[String, Integer]` | No OOF; type = Map[String,Integer] |
| `map_a_string_collection.ig` | `MultiValPass` | `input multi: Map[String, Collection[String]]` | No OOF; type = Map[String,Collection[String]] |

### Section MAP-B: Key type restriction (≥2 checks)

| Fixture | Contract | Declaration | Expected |
|---------|----------|------------|---------|
| `map_b_integer_key.ig` | `BadKey` | `input m: Map[Integer, String]` | OOF-MAP1 fires; blocked |
| `map_b_any_value.ig` | `BadValue` | `input m: Map[String, Any]` | OOF-MAP2 fires; blocked |

### Section MAP-C: Stdlib `get` lookup (≥3 checks)

| Fixture | Contract | Expression | Expected |
|---------|----------|----------|---------|
| `map_c_get_present.ig` | `GetPresent` | `compute ct = stdlib.map.get(headers, "content-type")` | type = Option[String]; no OOF |
| `map_c_get_with_fallback.ig` | `GetFallback` | `compute ct = or_else(stdlib.map.get(headers, "content-type"), "text/plain")` | type = String; no OOF |
| `map_c_has_key.ig` | `HasKey` | `compute present = stdlib.map.has_key(headers, "x-auth")` | type = Bool; no OOF |

### Section MAP-D: RackResponse with full headers (≥3 checks)

| Fixture | Contract | Shape | Expected |
|---------|----------|-------|---------|
| `map_d_rack_response_headers.ig` | `HeaderedResponse` | `type FullRackResponse { status: Integer, body: String, headers: Map[String,String] }` | Named Record with Map field typechecked; RecordLiteral upgrade succeeds |
| `map_d_header_lookup.ig` | `HeaderLookup` | Handler receives `Map[String,String]`, looks up "content-type" → `or_else(…, "text/html")` | type = String; no OOF |
| `map_d_regression_rackresponse.ig` | `SimpleResponse` | Original RackResponse (P12 shape, `{ status, body }`) | structural_size_v1 / Record checks unchanged |

### Section MAP-E: SemanticIR shape (≥3 checks)

| Check | Fixture | Verified shape |
|-------|---------|---------------|
| MAP-E1 | `map_a_string_string.ig` | Input declaration type.name = "Map", params[0].name = "String" |
| MAP-E2 | `map_c_get_present.ig` | compute node resolved_type.name = "Option", params[0].name = "String" |
| MAP-E3 | `map_d_rack_response_headers.ig` | `headers` field in FullRackResponse type shape has Map type |

### Section MAP-F: T1/T2/T3/Named-Record regression (≥4 checks)

| Check | Fixture | Expected |
|-------|---------|---------|
| MAP-F1 | existing t3a (T3 numeric measure) | Unaffected — numeric_measure_v0 unchanged |
| MAP-F2 | existing RackResponse P12 (no headers) | Unaffected — structural check unchanged |
| MAP-F3 | existing JobReceipt P4 fixture | Unaffected — named Record typechecking unchanged |
| MAP-F4 | `map_f_record_not_map.ig` — `type JobReceipt { ... }` + RecordLiteral | OOF-TY0 fires if Map[String,String] provided where JobReceipt expected |

**Minimum bar:** ≥18 checks, all PASS. No regression against existing proof suites.

---

## 14. Design Decision Matrix

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| D1 | Is Map[K,V] a Stage 1 design target? | ✅ YES | Grammar presence + concrete Rack header need |
| D2 | v0: generic Map[K,V] or narrowed to Map[String,V]? | Narrowed: K must be String in v0 | Key constraint design not yet needed; String covers all immediate needs |
| D3 | Map literal syntax in v0? | ❌ Deferred to v1 | Requires parser change; from_pairs covers construction; literals need MapLit grammar production |
| D4 | Construction path in v0? | `stdlib.map.from_pairs` + `stdlib.map.empty`; Map inputs from callers | Sufficient for proof-local P2 without parser change |
| D5 | Lookup return type? | `Option[V]` — always | Never Unknown, never null, never runtime error |
| D6 | Map[K,Any]? | ❌ OOF-MAP2 — permanently closed | Violates Axiom 1; breaks accountability chain |
| D7 | Map as named Record substitute? | ❌ Design law (not compiler-enforced in v0) | Records preferred for known schemas; Map for dynamic key sets only |
| D8 | JSON opens with Map? | ❌ No | JsonValue deferred; JsonObject ≠ Map[String,JsonValue] in v0 |
| D9 | Production compiler implementation opens? | ❌ Not yet; P3+ after proof-local P2 gate | P4/P5 auth required; proof-local gate is the standard route |
| D10 | SemanticIR new node kind needed for v0? | No new node kind for type annotation or lookup call | Existing `call` node + `type_ir` covers v0 |
| D11 | Map v0 key types? | String only | Immediate need only; Symbol/Integer keys deferred |
| D12 | Stdlib module name? | `stdlib.map.*` | Consistent with `stdlib.text.*`, `stdlib.collection.*` |
| D13 | Diagnostic namespace? | `OOF-MAP1..3` (experiment candidates) | Consistent with OOF namespace pattern; promoted at P3+ |
| D14 | from_pairs pair shape? | `Collection[{ key: String, value: V }]` | Named Record for the pair; explicit key/value naming |
| D15 | Immutability model? | Value semantics — no in-place mutation; `with_entry` in v1 | Consistent with Postulate 5 (immutable outputs) |

---

## 15. Next Route

### PROP-043-P2 (Immediate): Proof-Local Experiment

Build proof-local experiment `igniter-lang/experiments/prop043_map_kv_proof/`:
- `MapPipeline` extending production TypeChecker with Map[K,V] rules
- `stdlib.map.get`, `stdlib.map.has_key`, `stdlib.map.from_pairs` in the proof-local pipeline
- ≥18 fixture/check cases (MAP-A through MAP-F)
- Full RackResponse with `headers: Map[String, String]` field proven
- OOF-MAP1/MAP2 proven as diagnostic candidates
- T3/Named-Record regression clean

**Authorized writes:** `igniter-lang/experiments/prop043_map_kv_proof/` only.
**Do not touch:** production compiler files, Rust lab files, runtime/VM.

### PROP-043-P3+ (After P2): Production Promotion

After proof-local gate passes:
1. Production `typechecker.rb`: Map[K,V] annotation checking, OOF-MAP1/2/3, `stdlib.map.get` return type rule
2. Production `semanticir_emitter.rb`: Map type annotation propagation in typed contract IR
3. Optional: `parser.rb` — no change needed (Map[K,V] already parses)
4. Update ch3 type system spec: Map[K,V] moves from "grammar only" to "Stage 1 proven"
5. Update ch8 stdlib spec: add `stdlib.map.*` section

**Authorization required:** P4/P5 for production compiler edits.

### PROP-043-P4+ (Later): v1 Extensions

- Map literal syntax (`map { ... }` production)
- `stdlib.map.with_entry`, `without_key`, `keys`, `values`, `size`, `merge`
- Non-String key types (Symbol, Integer) — requires key constraint design
- `group_by` key type propagation in typechecker (currently OOF-MAP1 exempt for computed results)

---

## Appendix A: Fixture Contract Examples

### A.1 RackResponse with headers (P2 target)

```igniter
module Rack.Lab

type FullRackResponse {
  status  : Integer,
  body    : String,
  headers : Map[String, String]
}

pure contract GetRootHandler {
  input  method  : String
  input  path    : String
  input  headers : Map[String, String]
  compute status    = 200
  compute body_val  = "OK"
  compute ct        = or_else(stdlib.map.get(headers, "content-type"), "text/html")
  compute resp_hdrs = stdlib.map.from_pairs([])
  compute response  = { status: status, body: body_val, headers: resp_hdrs }
  output  response  : FullRackResponse
}
```

### A.2 Map key restriction (OOF-MAP1)

```igniter
module Map.Test

pure contract BadKey {
  input m : Map[Integer, String]  -- OOF-MAP1: Integer key not allowed in v0
  output result : String
}
```

### A.3 Map with Option[V] lookup

```igniter
module Map.Test

pure contract ContentTypeExtract {
  input  request_headers : Map[String, String]
  compute raw_ct    = stdlib.map.get(request_headers, "content-type")
  compute ct        = or_else(raw_ct, "application/octet-stream")
  output  ct        : String
}
```

### A.4 from_pairs construction

```igniter
module Map.Test

pure contract BuildHeaders {
  input   base_ct    : String
  compute pair_list  = [{ key: "content-type", value: base_ct }]
  compute hdrs       = stdlib.map.from_pairs(pair_list)
  output  hdrs       : Map[String, String]
}
```
