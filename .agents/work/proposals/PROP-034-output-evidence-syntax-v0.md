# PROP-034: Output Evidence Syntax v0

Status: experiment-pass
Date: 2026-06-07
Implemented: 2026-06-07
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Depends on: PROP-031 (contract modifiers)
Stage: 3
Evidence: experiments/output_evidence_proof/ — 51/51 PASS (2026-06-07)
Source: PROP-031 §12 (dependency specification)

---

## § 1. Purpose

PROP-031 §12 specified an optional `evidence [refs]` suffix on output declarations as the
immediate downstream grammar extension for output evidence:

> `output-decl ::= "output" ident (":" type)? ("evidence" "[" ref-list "]")?`

This proposal closes that deferral. An output declaration may optionally carry one or more
evidence reference identifiers, linking the output to the named escape/observation sources
that provided external evidence for its value.

Non-goals:
- No runtime evidence validation or linkage (Phase 2)
- No evidence ref type-checking at compile time (refs are opaque identifiers in v0)
- No cross-contract evidence references (same-body refs only in v0)
- No changes to the contract-decl production or modifier logic (body-level only)

---

## § 2. Grammar Change

### § 2.1 Updated production

```
output-decl ::= "output" ident (":" type-ref)? ("evidence" "[" ref-list "]")?

ref-list ::= ident ("," ident)*
```

The `evidence [...]` clause is positioned after the optional type annotation. It is
additive — contracts without evidence refs compile identically to before.

### § 2.2 Illustrative source

```igniter
-- no evidence: unchanged
observed contract ReadSensor {
  input sensor_id: String
  escape sensor_read
  output sensor_id: String
}

-- with evidence: links output to escape surface
observed contract ReadSensorWithEvidence {
  input sensor_id: String
  escape sensor_read
  output sensor_id: String evidence [sensor_read]
}

-- multiple refs
observed contract ReadMultiSensor {
  input sensor_id: String
  escape sensor_read
  escape calibration_read
  output sensor_id: String evidence [sensor_read, calibration_read]
}
```

### § 2.3 Backward compatibility

All existing output declarations compile unchanged. The `evidence` clause is entirely
optional. The `evidence` identifier does not need to be in the KEYWORDS list — it is
parsed using `peek_value?` which matches by value regardless of token type.

---

## § 3. ParsedProgram AST Delta

The `output` body node gains one optional field:

```json
{
  "kind": "output",
  "name": "sensor_id",
  "type_annotation": "String",
  "evidence": ["sensor_read"]
}
```

`evidence` is absent (not null) when no `evidence [...]` clause is present.

---

## § 4. Classifier Changes

### § 4.1 Passthrough

`classified_decl` passes `evidence` through to the classified declaration node.
The existing passthrough mechanism (`%w[bound options evidence]`) handles this transparently.

### § 4.2 OOF-M9 — pure contract with output evidence refs

If a `pure` contract declares any output with an `evidence [...]` clause, OOF-M9 fires.
Pure contracts have no external observation surface; evidence refs imply external
linkage, which is incompatible with the `pure` semantic.

```
OOF-M9  pure contract with output evidence refs
         severity: error
         message:  "pure contract '${name}' cannot declare output evidence refs
                    (${output_names}); use 'observed' or higher modifier"
```

OOF-M9 fires before `contract_fragment_for` so the contract's fragment class becomes
`"oof"` (blocked).

---

## § 5. TypeChecker Changes

`typed_decl_output` passes `evidence` through to the typed declaration node:

```ruby
result["evidence"] = decl.fetch("evidence") if decl.key?("evidence")
```

No type-checking of evidence ref identifiers in v0 — refs are opaque strings.

---

## § 6. SemanticIR Changes

`typed_ports` includes `evidence` in the output port when present:

```ruby
port["evidence"] = decl.fetch("evidence") if decl.key?("evidence")
```

Output port in `contract_ir`:

```json
{
  "name": "sensor_id",
  "type": { "kind": "type_ref", "name": "String" },
  "lifecycle": "session",
  "evidence": ["sensor_read"]
}
```

---

## § 7. OOF Code Summary

| Code | Stage | Severity | Trigger | Message |
|------|-------|----------|---------|---------|
| OOF-M9 | Classifier | error | `pure` contract output with `evidence` refs | `"pure contract '${name}' cannot declare output evidence refs (${outputs}); use 'observed' or higher modifier"` |

---

## § 8. Backward Compatibility

All existing source files compile unchanged. The `evidence` clause is optional and additive.
The parser method `parse_evidence_list` was already present; this PROP wires it through
the classifier, typechecker, and SemanticIR stages.

---

## § 9. Must Not Touch

Per PROP-031 §12, this PROP must not touch:
- The contract-decl production or modifier logic (body-level only)
- OOF-M1 or the modifier→fragment_class mapping
- Any PROP-031, PROP-035, or PROP-040 classifier logic
