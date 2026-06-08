# PROP-040: Profile Declarations v0

Status: experiment-pass
Date: 2026-06-07
Author: `[Portfolio Architect Supervisor]`
Depends on: PROP-033 (via profile binding), PROP-031 (contract modifiers), PROP-036 (compiler_profile_id)
Stage: 3
Evidence: experiments/profile_declarations_proof/ — 63/63 PASS (2026-06-07)
Source: MFN-001 § 3 (open dangling end from PROP-033); Postulate 10 (Profiles Are Policy)
Implemented: 2026-06-07

---

## Authority Boundary

Authorized by this document:
- Grammar design for module-level `profile` declarations
- OOF-M7/M8 diagnostic code specifications
- Pipeline propagation design (parse → classify → typecheck → SemanticIR)
- Dependency and non-goal statements

Not authorized by this document:
- Parser implementation (requires Compiler/Grammar Expert card)
- TypeChecker/Classifier implementation
- SemanticIR emitter changes
- Profile schema validation (runtime concern)
- Profile authority injection (Phase 2)
- Any changes to PROP-036/038 compiler_profile_id infrastructure

---

## § 1. Purpose

PROP-033 adds a `via <profile_name>` clause to contract declarations and emits
`profile_binding` in `contract_ir`. As of PROP-033, the compiler records the intent
but cannot validate it: it does not know whether the named profile exists or whether
it is compatible with the contract's modifier.

This PROP closes that open hook by introducing **profile declarations** as module-level
source constructs. A profile declaration gives a name to a compile-time policy that
contracts may bind to via the `via` clause.

Postulate 10 of the Language Covenant states:

> A profile is not configuration. It is a compile-time policy that restricts and
> obligates what a contract may do. Profiles cannot be bypassed at runtime.

PROP-040 makes profiles first-class citizens of the source grammar. It enables the
compiler to enforce that:

1. `via <name>` references a profile that is declared in scope (OOF-M8)
2. The binding contract's modifier is compatible with the profile's declared authority (OOF-M7)

Non-goals:
- No runtime profile injection or resolution (Phase 2)
- No capability schema validation at compile time (schema is lab-only, CR-001)
- No profile inheritance or composition (future)
- No cross-module profile imports (PROP-040 v0 is same-module scope only)
- No changes to PROP-036 `compiler_profile_id` manifest field
- No changes to PROP-038 compiler_profile_contract schema

---

## § 2. Grammar Design

### § 2.1 New module-level production

Profile declarations appear at module level, alongside `type`, `contract`, and `import`
declarations. They are not body-level declarations inside a contract.

```
profile-decl ::= "profile" ident "{" profile-body "}"

profile-body ::= profile-field*

profile-field ::= "authority" ":" contract-modifier
                | "description" ":" string-literal   -- optional, informational
```

`contract-modifier` is one of: `pure`, `observed`, `effect`, `privileged`, `irreversible`
(the same set as PROP-031).

Minimal v0 profile declaration:

```igniter
module Payments

profile payments_profile {
  authority: effect
}

effect contract ChargeCustomer via payments_profile {
  capability charge_cap: IO.NetworkCapability
  effect charge using charge_cap
}
```

The `authority` field declares the minimum contract modifier required for a contract to
bind this profile. A contract with a modifier that is lower authority than the profile's
declared `authority` triggers OOF-M7.

### § 2.2 Authority ordering

The contract modifier authority ordering (from PROP-031):

```
pure < observed < effect < privileged < irreversible
```

A contract's modifier must be ≥ the profile's declared authority for the binding to be valid.
This means `privileged` and `irreversible` contracts may bind a profile with `authority: effect`
(higher authority is acceptable). A `pure` contract may not bind a profile with `authority: effect`
(lower authority — OOF-M7).

### § 2.3 Illustrative examples

```igniter
-- Profile for read-only sensor access
profile telemetry_profile {
  authority: observed
}

-- Profile for network operations
profile payments_profile {
  authority: effect
}

-- Profile for irreversible operations
profile archive_profile {
  authority: irreversible
}

-- Valid bindings
observed contract ReadSensor via telemetry_profile { ... }  -- exact match: ok
effect    contract ReadSensor2 via telemetry_profile { ... } -- higher: ok
privileged contract Charge via payments_profile { ... }     -- higher: ok

-- Invalid bindings (OOF-M7)
pure contract Bad via payments_profile { ... }  -- pure < effect: OOF-M7
```

### § 2.4 Scope rule (v0)

A profile must be declared in the same module as the contracts that reference it.
Cross-module profile references are not in PROP-040 v0 scope.

---

## § 3. ParsedProgram AST Delta

Profile declarations appear in a new top-level `profiles` list in the parsed program:

```json
{
  "kind": "program",
  "module": "Payments",
  "profiles": [
    {
      "kind": "profile",
      "name": "payments_profile",
      "authority": "effect"
    }
  ],
  "contracts": [ ... ],
  "types": [ ... ]
}
```

The `profiles` list is empty (not absent) when no profile declarations exist, consistent
with how `types` and `contracts` are handled.

---

## § 4. Classifier Changes

The classifier gains a profile index built before contract body classification begins:

```ruby
profile_index = parsed_program.fetch("profiles", [])
                              .each_with_object({}) { |p, h| h[p.fetch("name")] = p }
```

For each contract's `via_profile` binding, two checks run after the body loop:

**OOF-M8 — Unknown profile name**

If `via_profile` is set but the name is not in `profile_index`:

```
OOF-M8  unknown profile referenced in via clause
         severity: error
         message:  "contract '#{name}' binds unknown profile '#{via_profile}'; declare 'profile #{via_profile}' in this module"
```

**OOF-M7 — Modifier/authority mismatch**

If `via_profile` resolves to a profile and the contract's modifier is below the profile's
declared authority:

```
OOF-M7  contract modifier too weak for bound profile authority
         severity: error
         message:  "contract '#{name}' (#{modifier}) cannot bind profile '#{via_profile}' which requires '#{profile_authority}' or higher"
```

Authority ordering for comparison: `pure=0, observed=1, effect=2, privileged=3, irreversible=4`.

---

## § 5. TypeChecker Changes

The TypeChecker validates that the `via_profile` field (propagated from classifier) resolves
correctly. In v0, profile authority is enforced at classifier level (OOF-M7/M8); the
TypeChecker passes profile metadata through to the typed contract without re-validation.

The `typed_contract` gains one optional field when a profile is declared and resolved:

```json
{
  "via_profile": "payments_profile",
  "profile_authority": "effect"
}
```

`profile_authority` is the authority from the declared profile, resolved at classify time
and carried forward for SemanticIR consumers.

---

## § 6. SemanticIR Emitter Changes

`typed_contract_ir` gains an additional field when `profile_authority` is present:

```json
{
  "kind": "contract_ir",
  "contract_name": "ChargeCustomer",
  "modifier": "effect",
  "profile_binding": "payments_profile",
  "profile_authority": "effect",
  ...
}
```

`profile_authority` is absent when `profile_binding` is absent.

---

## § 7. OOF Code Summary

| Code | Stage | Severity | Trigger | Message |
|------|-------|----------|---------|---------|
| OOF-M7 | Classifier | error | Contract modifier < profile authority | `"contract '${name}' (${modifier}) cannot bind profile '${profile}' which requires '${authority}' or higher"` |
| OOF-M8 | Classifier | error | `via_profile` references undeclared profile | `"contract '${name}' binds unknown profile '${via_profile}'; declare 'profile ${via_profile}' in this module"` |

---

## § 8. Backward Compatibility

All existing source files without profile declarations compile unchanged. The `profiles` key
in the parsed program is empty. No `via_profile` bindings exist in existing fixtures, so
OOF-M7/M8 do not fire.

Contracts with `via_profile` from PROP-033 fixtures continue to compile — they will emit
OOF-M8 if run against a classifier that has PROP-040 active and the profile is not declared.
This is correct and expected: PROP-033 fixtures that use `via` without a profile declaration
are structurally incomplete programs.

---

## § 9. Dependency Chain

```
PROP-031: contract modifiers     ✅ experiment-pass
    ↓
PROP-033: via profile binding    ✅ experiment-pass   ← installs profile_binding hook
    ↓
PROP-040: profile declarations   ◯ in-design          ← this PROP; closes the hook
    ↓
OOF-M7/M8 enforcement            defined here; implemented when PROP-040 is authorized
    ↓
PROP-036/038: compiler_profile_id ← separate track; not blocked by PROP-040
```

---

## § 10. Open Questions

1. **Cross-module profile imports** — Should profiles be importable across modules? PROP-040 v0
   says no (same-module only). Cross-module profile governance is a separate PROP.

2. **Capability requirements in profiles** — Should a profile declare which capability types
   it provides? (e.g., `requires capability: IO.NetworkCapability`.) Deferred: capability
   schema is lab-only (CR-001). The `authority` field is sufficient for v0.

3. **Profile schema vs compiler_profile** — PROP-036/038 define `compiler_profile_id` as a
   manifest identity field for the compiler itself. PROP-040 profiles are source-level policy
   objects that contracts bind to. These are distinct namespaces. A future integration PROP
   may link them, but that is out of scope for v0.

---

## § 11. Implementation Gate

This proposal is in `in-design` state. The following must be true before an implementation
card is authorized:

- [ ] Proposal reviewed and accepted by Compiler/Grammar Expert
- [ ] Grammar production finalized (§ 2 may require refinement at implementation time)
- [ ] OOF-M7/M8 codes reviewed and registered
- [ ] Proof runner skeleton drafted (minimum: parse, OOF-M7, OOF-M8, backward compat)
- [ ] Backward compatibility confirmed against all existing fixtures
