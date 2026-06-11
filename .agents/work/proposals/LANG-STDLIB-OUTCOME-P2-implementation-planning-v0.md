# LANG-STDLIB-OUTCOME-P2 — Implementation Planning

**Track:** stdlib-outcome-helper-predicates-typechecker-semanticir-planning-v0
**Status:** CLOSED — planning-complete / READY FOR P3
**Date:** 2026-06-11
**Route:** IMPLEMENTATION PLANNING ONLY / NO CODE
**Predecessor:** LANG-STDLIB-OUTCOME-PROP-P1 (proposal authored)
**Successor:** LANG-STDLIB-OUTCOME-PROP-P3 (bounded Ruby implementation — not yet authorized)

---

## Q1 — Implementation Scope

**Decision: Option A — TypeChecker dispatch + correct SemanticIR naming.**

`docs/spec/stdlib-inventory.json` does not yet exist. LANG-STDLIB-ENTRY-CONTRACT-P3
(READY FOR P3 but not yet run) will create it. LANG-STDLIB-OUTCOME-PROP-P3 is
independent of that track; it does not depend on the inventory file existing.

P3 scope:
- Add `OUTCOME_STDLIB_FNS` constant to `typechecker.rb`
- Add dispatch case in `infer_call`
- Add `infer_outcome_helper` private method (shared handler for all 7 helpers)
- Proof runner verifies TC dispatch, return types, canonical SIR naming, OOF-OUT1
- Entry contract records planned here (§7); written to `stdlib-inventory.json` when
  LANG-STDLIB-ENTRY-CONTRACT-P3 runs (separate parallel track, not a gate for P3)

**SemanticIR emitter: zero changes required.**
The generic `semantic_expr` recursion in `semanticir_emitter.rb` (lines 338–368)
already preserves the `fn` field from TypeChecker output verbatim. TypeChecker sets
`fn` to the canonical qualified name; the emitter passes it through. No emitter
work is needed.

---

## Q2 — Input Shape

**Decision: v0 = `Map[String, String]` only.**

Named Record with `kind: String` deferred to P2+/P3+.

### Accepted types

| Input type | Behavior |
|-----------|---------|
| `Map[String, String]` | PASS — expected shape |
| `Map[String, V]` (any V) | PASS — TypeChecker only checks `Map` base; V not inspected |
| `Unknown` | PASS — lenient; avoids cascading errors |
| `Map` (no params) | PASS — treated as `Map[String, Unknown]` |
| Any non-Map type (String, Integer, Bool, Record, etc.) | FAIL → OOF-OUT1 |

### Lenient treatment of Map params

The TypeChecker checks that `type_name(resolved_type) == "Map"`. It does NOT verify
that both params are exactly `String`. This mirrors the lenient treatment in `infer_map_get`
(which checks `Map` but does not enforce `Map[String,*]` strictly). The value type in
a KDR record may be `Unknown` when the map is constructed without explicit typing.

### Missing kind key

TypeChecker cannot inspect Map content at compile time. Missing `"kind"` key is a
runtime concern. P3 TypeChecker does NOT emit OOF-OUT1 for this case. P4+ (when
VM lowering is added) will decide the runtime behavior.

### Non-String kind value

Undefined in v0. Deferred to P4+ VM lowering.

---

## Q3 — Function Signatures

All 7 accepted helpers take exactly 1 argument and produce a scalar type.

| Source alias | Input type | Output type | Canonical name |
|-------------|-----------|------------|----------------|
| `outcome_kind` | `Map[String, String]` | `String` | `stdlib.outcome.kind` |
| `outcome_is_denied` | `Map[String, String]` | `Bool` | `stdlib.outcome.is_denied` |
| `outcome_is_unknown_external_state` | `Map[String, String]` | `Bool` | `stdlib.outcome.is_unknown_external_state` |
| `outcome_is_timed_out` | `Map[String, String]` | `Bool` | `stdlib.outcome.is_timed_out` |
| `outcome_is_system_error` | `Map[String, String]` | `Bool` | `stdlib.outcome.is_system_error` |
| `outcome_is_query_error` | `Map[String, String]` | `Bool` | `stdlib.outcome.is_query_error` |
| `outcome_is_partial_success` | `Map[String, String]` | `Bool` | `stdlib.outcome.is_partial_success` |

### Source alias rationale

The `outcome_` prefix follows the existing stdlib naming convention:
- `map_get`, `map_has_key`, `map_from_pairs` (MAP_STDLIB_FNS)
- `outcome_kind`, `outcome_is_denied`, etc. (OUTCOME_STDLIB_FNS)

Source aliases are `source_alias` entries in the governance registry per
LANG-STDLIB-ENTRY-CONTRACT-P1 §4. They never appear in SemanticIR output.

---

## Q4 — TypeChecker Dispatch

### OUTCOME_STDLIB_FNS constant

Insert after `MAP_STDLIB_FNS` (around line 70 of `typechecker.rb`):

```ruby
OUTCOME_STDLIB_FNS = {
  "outcome_kind"                      => { qualified_name: "stdlib.outcome.kind",                      return_type: "String" },
  "outcome_is_denied"                 => { qualified_name: "stdlib.outcome.is_denied",                 return_type: "Bool" },
  "outcome_is_unknown_external_state" => { qualified_name: "stdlib.outcome.is_unknown_external_state", return_type: "Bool" },
  "outcome_is_timed_out"              => { qualified_name: "stdlib.outcome.is_timed_out",              return_type: "Bool" },
  "outcome_is_system_error"           => { qualified_name: "stdlib.outcome.is_system_error",           return_type: "Bool" },
  "outcome_is_query_error"            => { qualified_name: "stdlib.outcome.is_query_error",            return_type: "Bool" },
  "outcome_is_partial_success"        => { qualified_name: "stdlib.outcome.is_partial_success",        return_type: "Bool" },
}.freeze
```

### Dispatch case in `infer_call`

Insert after `when *MAP_STDLIB_FNS.keys` (around line 833):

```ruby
when *OUTCOME_STDLIB_FNS.keys
  infer_outcome_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
```

### `infer_outcome_call` private method

Single shared handler (all 7 helpers are structurally identical: 1 Map arg → scalar):

```ruby
def infer_outcome_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  spec           = OUTCOME_STDLIB_FNS.fetch(fn)
  qualified_name = spec[:qualified_name]
  return_type    = spec[:return_type]

  # Arity check
  unless args.length == 1
    type_errors << oof("OOF-TY0",
      "#{qualified_name}: expected 1 argument (Map[String, String]), got #{args.length}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified_name, "args" => [])
  end

  # Type check: argument must be Map or Unknown
  outcome_arg  = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  outcome_type = outcome_arg.fetch("resolved_type")
  actual_name  = type_name(outcome_type)
  unless actual_name == "Unknown" || actual_name == "Map"
    type_errors << oof("OOF-OUT1",
      "#{qualified_name}: argument must be Map[String, String], got #{actual_name}",
      node_name)
  end

  typed_expr("call", type_ir(return_type), outcome_arg.fetch("deps", []),
             "fn" => qualified_name, "args" => [outcome_arg])
end
```

Insert after the existing `infer_map_*` methods (around line 2090+).

**No other dispatch handling:** `is_retryable` and `route` are NOT registered. Calls to
them fall through to OOF-TY0 "Unknown function" (existing else branch in `infer_call`).

---

## Q5 — SemanticIR Naming

**No SemanticIR emitter changes required.**

The TypeChecker emits `typed_expr("call", ..., ..., "fn" => qualified_name)`.
The generic `semantic_expr` in `semanticir_emitter.rb` (lines 338–368) recursively
preserves all Hash fields including `fn`. The qualified canonical name passes through
unchanged.

### SIR call node shape for outcome helpers

```json
{
  "kind":          "call",
  "fn":            "stdlib.outcome.is_denied",
  "args":          [{ "kind": "ref", "name": "outcome_record", "resolved_type": { ... } }],
  "resolved_type": { "name": "Bool", "params": [] }
}
```

**Invariant satisfied:** `semantic_ir_name == canonical_name` for all 7 entries.
The `fn` field in SIR will always be the fully-qualified `stdlib.outcome.*` name.

---

## Q6 — Diagnostics

| Condition | Code | Trigger | Message pattern |
|-----------|------|---------|-----------------|
| Arity mismatch | OOF-TY0 | args.length ≠ 1 | `"stdlib.outcome.<fn>: expected 1 argument (Map[String, String]), got N"` |
| Wrong input type | OOF-OUT1 | type_name ≠ "Map" and ≠ "Unknown" | `"stdlib.outcome.<fn>: argument must be Map[String, String], got <actual>"` |
| is_retryable called | OOF-TY0 | not in OUTCOME_STDLIB_FNS | `"Unknown function: is_retryable"` (existing catch-all) |
| route called | OOF-TY0 | not in OUTCOME_STDLIB_FNS | `"Unknown function: route"` (existing catch-all) |

**OOF-OUT2..OUT4:** Reserved. Not triggered in P3. Missing kind / non-String kind are
runtime concerns; no compile-time diagnostic in P3.

**OOF-TY0 for arity** is consistent with `infer_text_call` and `infer_map_get` patterns.
OOF-OUT1 is the first outcome-specific diagnostic code, reserved in LANG-STDLIB-OUTCOME-PROP-P1.

---

## Q7 — Stdlib Inventory Integration

`docs/spec/stdlib-inventory.json` does not yet exist.
LANG-STDLIB-ENTRY-CONTRACT-P3 (separate parallel track; READY FOR P3) will create it.
LANG-STDLIB-OUTCOME-PROP-P3 does not wait for that file.

**P3 proof runner verifies:** that `OUTCOME_STDLIB_FNS` qualified_name values
match the P1 canonical_names exactly. This provides inventory consistency without
requiring the JSON file.

### Entry contract records (ready for LANG-STDLIB-ENTRY-CONTRACT-P3)

When `stdlib-inventory.json` is created, append these 7 entries:

```jsonc
// stdlib.outcome.kind
{
  "canonical_name":    "stdlib.outcome.kind",
  "category":          "outcome",
  "aliases":           [{ "type": "source_alias", "name": "outcome_kind" }],
  "status":            "lab-implemented",
  "stability": {
    "semantic":        "convention",
    "lowering":        "single-toolchain",
    "compatibility":   "pre-v1-none"
  },
  "fragment_class":    "core",
  "purity":            "pure",
  "deterministic":     true,
  "totality":          "total",
  "input_signature":   ["Map[String, String]"],
  "output_signature":  "String",
  "failure_behavior":  "absent 'kind' key → runtime error (P4+ decides exact form)",
  "authority_surface": "none",
  "semantic_ir_name":  "stdlib.outcome.kind",
  "lowering": {
    "ruby_production":  "typechecker.rb OUTCOME_STDLIB_FNS / infer_outcome_call",
    "rust_typechecker": "not-lowered",
    "rust_vm":          "not-lowered",
    "kernel_only":      false
  },
  "vm_lowering_status": "not-lowered",
  "proof_lineage":     ["LAB-STDLIB-OUTCOME-P1 (66/66 PASS)", "LANG-STDLIB-OUTCOME-PROP-P3"]
}
```

```jsonc
// stdlib.outcome.is_denied  (and symmetrically for the other 5 is_* entries)
{
  "canonical_name":    "stdlib.outcome.is_denied",
  "category":          "outcome",
  "aliases":           [{ "type": "source_alias", "name": "outcome_is_denied" }],
  "status":            "lab-implemented",
  "stability": {
    "semantic":        "experiment-pass",
    "lowering":        "single-toolchain",
    "compatibility":   "pre-v1-none"
  },
  "fragment_class":    "core",
  "purity":            "pure",
  "deterministic":     true,
  "totality":          "total",
  "input_signature":   ["Map[String, String]"],
  "output_signature":  "Bool",
  "failure_behavior":  "absent 'kind' key → runtime error (P4+ decides exact form)",
  "authority_surface": "none",
  "semantic_ir_name":  "stdlib.outcome.is_denied",
  "lowering": {
    "ruby_production":  "typechecker.rb OUTCOME_STDLIB_FNS / infer_outcome_call",
    "rust_typechecker": "not-lowered",
    "rust_vm":          "not-lowered",
    "kernel_only":      false
  },
  "vm_lowering_status": "not-lowered",
  "proof_lineage":     ["LAB-STDLIB-OUTCOME-P1 C-01 PASS", "PROP-047-P2 §2.1",
                        "LAB-FAILURE-TAXONOMY-P1", "LANG-STDLIB-OUTCOME-PROP-P3"]
}
```

The other 5 `is_*` entries follow the same shape; only `canonical_name`, `aliases`,
`stability.semantic`, and `proof_lineage` differ. `is_partial_success` must include
`"LAB-FAILURE-TAXONOMY-P4 (54/54 PASS)"` in its `proof_lineage`.

After P3 closes, the `status` for all 7 entries becomes `"lab-implemented"` and
`stability.lowering` becomes `"single-toolchain"` (Ruby canon only).

---

## Q8 — Runtime / VM

**No VM implementation in P3.**

`vm_lowering_status: "not-lowered"` for all 7 entries. Runtime behavior of the helpers
(the actual Bool/String value produced) is deferred to P4+ when VM lowering is added.

P3 proves that the TypeChecker recognizes the calls, assigns correct types, and emits
canonical SIR names. P4+ proves that the VM executes them correctly.

---

## Q9 — Domain-Local Preservation (P3 level)

At TypeChecker level, domain-local preservation is automatic: the TypeChecker only
checks that the argument is a `Map` type. It does NOT inspect the `"kind"` field
value. Any `Map[String, String]` (whether its kind is `"denied"` or `"found"` or
`"still_unknown"`) is accepted. The return type is always `Bool` (or `String` for
`outcome_kind`), regardless of the map's content.

**Runtime semantics** (actual false-return for domain-local kinds) are in the VM
lowering layer — deferred to P4+.

P3 proof checks (H section):
- TypeChecker accepts a Map with kind `"found"` for `outcome_is_denied` → PASS (type-level)
- TypeChecker accepts a Map with kind `"rows"` for `outcome_is_system_error` → PASS
- SIR emits `fn: "stdlib.outcome.is_denied"` regardless of map content
- Return type is always `Bool`

These checks prove domain-local preservation at the TypeChecker boundary; they do not
(and cannot) prove that the runtime returns `false`. The LANG-STDLIB-OUTCOME-P1 proof
already covers that in the proof-local Ruby model.

---

## Q10 — Retryability and Route Boundary

**is_retryable:** Not in `OUTCOME_STDLIB_FNS`. Calls to `is_retryable(x)` or
`outcome_is_retryable(x)` fall through to the OOF-TY0 "Unknown function" branch.
This is the correct behavior: is_retryable is a design candidate for P2 (LAB-STDLIB-OUTCOME-P2
or a dedicated retryability proof). It must not be dispatched in P3.

**route:** Not in `OUTCOME_STDLIB_FNS`. Permanently rejected per LANG-STDLIB-OUTCOME-PROP-P1 §7.
Any call to `route(x, y)` or `outcome_route(x, y)` → OOF-TY0.

**No scheduling, no policy, no capability** surface is opened by this plan.

---

## Q11 — Proof Matrix

**Proof runner:** `experiments/stdlib_outcome_proof/verify_stdlib_outcome_p3.rb`
**Target:** ≥60 checks across 9 sections (A–I)

| Section | Checks | Focus |
|---------|--------|-------|
| A — Regression | 6 | text/map stdlib unaffected; entrypoint; import; typed-ref fixtures compile |
| B — Helper registration and dispatch | 7 | Each of 7 helpers recognized by TypeChecker; compile succeeds |
| C — Return type assignment | 7 | outcome_kind → String; 6 is_* → Bool |
| D — Input type validation | 8 | Map accepted; Unknown accepted; non-Map → OOF-OUT1; arity → OOF-TY0 |
| E — SemanticIR canonical naming | 7 | Each helper emits `fn: "stdlib.outcome.<fn>"`; no bare names |
| F — Fixture compilation | 6 | 3 domain fixtures compile; helpers used on domain outcomes |
| G — Authority closed | 7 | is_retryable/route/outcome_route → OOF-TY0; no Outcome[T,E]; no parser change |
| H — Domain-local non-collapse (TC level) | 6 | Any Map accepted; domain-local kind Maps compile; return type unchanged |
| I — Stdlib entry consistency | 6 | OUTCOME_STDLIB_FNS qualified_names match P1 canonical_names; no drift |

**Total: 60 checks minimum.**

### Section detail

**A (6 checks):**
- A-01: `concat("a", "b")` → compiles (TEXT_STDLIB_FNS unaffected)
- A-02: `map_get(m, "k")` → compiles (MAP_STDLIB_FNS unaffected)
- A-03: Entrypoint fixture compiles (PROP-ENTRYPOINT-P3 regression)
- A-04: Multifile import fixture compiles (PROP-IMPORT-RESOLUTION-P5 regression)
- A-05: Typed contract ref fixture compiles (LANG-TYPED-CONTRACT-REF-P5 regression)
- A-06: Unknown function name → OOF-TY0 still fires (catch-all unbroken)

**B (7 checks):** one per helper — source alias recognized; no type error emitted when Map input provided.

**C (7 checks):** one per helper — compile fixture; read `resolved_type.name` from SIR; assert "String" for kind, "Bool" for is_*.

**D (8 checks):**
- D-01: Map[String, String] input → PASS (no OOF)
- D-02: Map[String, Unknown] input → PASS
- D-03: Unknown type input → PASS
- D-04: String input → OOF-OUT1
- D-05: Integer input → OOF-OUT1
- D-06: 0 arguments → OOF-TY0
- D-07: 2 arguments → OOF-TY0
- D-08: OOF-OUT1 message includes "Map[String, String]" and canonical helper name

**E (7 checks):** one per helper — read SIR `fn` field from typed_node; assert equals
`"stdlib.outcome.<canonical-suffix>"` exactly.

**F (6 checks):**
- F-01..F-03: Each domain fixture (http/storage/epistemic) compiles without errors
- F-04: `outcome_kind` called on a Map outcome expression in fixture → compiles
- F-05: `outcome_is_denied` called on a Map outcome expression → compiles
- F-06: `outcome_is_system_error` called on a Map → compiles

**G (7 checks):**
- G-01: `is_retryable(x)` → OOF-TY0
- G-02: `outcome_is_retryable(x)` → OOF-TY0
- G-03: `route(x, y)` → OOF-TY0
- G-04: `outcome_route(x, y)` → OOF-TY0
- G-05: No `Outcome[T,E]` type in type registry
- G-06: No new parser keywords introduced (grammar_version unchanged)
- G-07: `semanticir_emitter.rb` is not modified (file fingerprint check)

**H (6 checks):**
- H-01: Map with `"kind" => "found"` → `outcome_is_denied` compiles; return type Bool
- H-02: Map with `"kind" => "rows"` → `outcome_is_system_error` compiles; return type Bool
- H-03: Map with `"kind" => "confirmed_succeeded"` → `outcome_kind` compiles; return type String
- H-04: No restriction on Map content inspected by TC
- H-05: OOF-OUT1 fires for String arg (not for Map with any kind value)
- H-06: Return type is always Bool/String regardless of map content

**I (6 checks):**
- I-01: All 7 `OUTCOME_STDLIB_FNS.values.map { |v| v[:qualified_name] }` start with `"stdlib.outcome."`
- I-02: No entry in OUTCOME_STDLIB_FNS has a bare (non-qualified) name
- I-03: `"is_retryable"` not in OUTCOME_STDLIB_FNS keys
- I-04: `"route"` not in OUTCOME_STDLIB_FNS keys
- I-05: `OUTCOME_STDLIB_FNS` keys follow `"outcome_"` prefix consistently
- I-06: All 7 qualified_names exactly match LANG-STDLIB-OUTCOME-PROP-P1 canonical_names

---

## Q12 — Authorized Files for P3

| File | Change |
|------|--------|
| `lib/igniter_lang/typechecker.rb` | Add `OUTCOME_STDLIB_FNS` constant; add `when *OUTCOME_STDLIB_FNS.keys` dispatch case in `infer_call`; add `infer_outcome_call` private method |
| `experiments/stdlib_outcome_proof/verify_stdlib_outcome_p3.rb` | New proof runner |
| `experiments/stdlib_outcome_proof/*.ig` | New/updated fixture files using outcome helpers |

**Approximate line count:** ~40–60 lines in `typechecker.rb` (constant + dispatch + method).

**Not authorized:**
- `lib/igniter_lang/semanticir_emitter.rb` — zero changes needed
- `lib/igniter_lang/parser.rb` — no new keywords
- `lib/igniter_lang/classifier.rb` — no classification changes
- `lib/igniter_lang/assembler.rb` — no manifest changes
- VM, runtime, or Rust toolchain
- `docs/spec/stdlib-inventory.json` — independent track (LANG-STDLIB-ENTRY-CONTRACT-P3)

---

## Q13 — Recommendation

**READY FOR NARROW P3**

Scope is bounded: ~40–60 lines in one file (`typechecker.rb`) + proof runner.
SemanticIR emitter requires zero changes. Parser requires zero changes.
Domain-local preservation and runtime semantics deferred to P4+ (VM lowering).
is_retryable and route remain closed.

P3 gate conditions:
1. This planning doc closes ✓
2. LANG-STDLIB-OUTCOME-PROP-P1 proposal authored ✓
3. LAB-STDLIB-OUTCOME-P1 66/66 PASS ✓

P3 proof target: ≥60 checks / 9 sections. All must PASS.

---

## Implementation Sketch (reference for P3)

```ruby
# typechecker.rb — new constant (after MAP_STDLIB_FNS, ~line 70)

OUTCOME_STDLIB_FNS = {
  "outcome_kind"                      => { qualified_name: "stdlib.outcome.kind",                      return_type: "String" },
  "outcome_is_denied"                 => { qualified_name: "stdlib.outcome.is_denied",                 return_type: "Bool" },
  "outcome_is_unknown_external_state" => { qualified_name: "stdlib.outcome.is_unknown_external_state", return_type: "Bool" },
  "outcome_is_timed_out"              => { qualified_name: "stdlib.outcome.is_timed_out",              return_type: "Bool" },
  "outcome_is_system_error"           => { qualified_name: "stdlib.outcome.is_system_error",           return_type: "Bool" },
  "outcome_is_query_error"            => { qualified_name: "stdlib.outcome.is_query_error",            return_type: "Bool" },
  "outcome_is_partial_success"        => { qualified_name: "stdlib.outcome.is_partial_success",        return_type: "Bool" },
}.freeze

# typechecker.rb — infer_call dispatch (after MAP case, ~line 833)
when *OUTCOME_STDLIB_FNS.keys
  infer_outcome_call(fn, args, symbol_types, type_errors, type_warnings, node_name)

# typechecker.rb — private method (after infer_map_* methods, ~line 2090+)
def infer_outcome_call(fn, args, symbol_types, type_errors, type_warnings, node_name)
  spec           = OUTCOME_STDLIB_FNS.fetch(fn)
  qualified_name = spec[:qualified_name]
  return_type    = spec[:return_type]

  unless args.length == 1
    type_errors << oof("OOF-TY0",
      "#{qualified_name}: expected 1 argument (Map[String, String]), got #{args.length}",
      node_name)
    return typed_expr("call", type_ir("Unknown"), [], "fn" => qualified_name, "args" => [])
  end

  outcome_arg = infer_expr(args[0], symbol_types, type_errors, type_warnings, node_name)
  actual_name = type_name(outcome_arg.fetch("resolved_type"))
  unless actual_name == "Unknown" || actual_name == "Map"
    type_errors << oof("OOF-OUT1",
      "#{qualified_name}: argument must be Map[String, String], got #{actual_name}",
      node_name)
  end

  typed_expr("call", type_ir(return_type), outcome_arg.fetch("deps", []),
             "fn" => qualified_name, "args" => [outcome_arg])
end
```
