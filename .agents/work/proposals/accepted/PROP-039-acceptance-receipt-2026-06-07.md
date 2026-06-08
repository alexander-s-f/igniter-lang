# Governance Acceptance Receipt — PROP-039

**From:** Portfolio Architect Supervisor
**Date:** 2026-06-07
**Proposal:** PROP-039 — Managed Local Recursion and Loop Classes v0
**Prior status:** authored-pending-review
**New status:** accepted; proposal-only

---

## Acceptance Scope

PROP-039 is accepted as **language-design authority for vocabulary and loop-class taxonomy only**.

Accepted content:
- Loop-class vocabulary: `FiniteLoop`, `BudgetedLocalLoop`, `StructuralRecursion`,
  `FuelBoundedRecursion`, `ConvergentLoop` (deferred-proof), `ServiceLoop` (excluded/PROP-037)
- Finite local loop form: `for Name item in collection { ... }`
- Budgeted local loop form: `loop Name item in collection max_steps: N { ... }`
- Structural recursion form: `recursive contract ... decreases <variant> { ... }`
- Fuel-bounded recursion form: `fuel_bounded contract ... max_steps N { ... }`
- `decreases fuel` shorthand as candidate vocabulary only
- Static-first `max_steps` policy (dynamic forms deferred)
- `break` deferral
- `now()` / OOF-L6 boundary (unchanged)
- Postulate 28 loop naming requirement
- Candidate diagnostics (OOF-L1..L5, OOF-R1..R5) as vocabulary candidates — not registry authority
- PROP-037/progression exclusion and boundary statement
- `for`/`loop` split recommendation
- 7 future implementation gates (listed below)

---

## Five Acceptance Gates — Verified

| Gate | Criterion | Status |
|------|-----------|--------|
| 1 | Bounded local loops and service loops separated | ✅ Explicit separation; ServiceLoop → PROP-037 |
| 2 | Service loops remain tied to PROP-037/progression authority | ✅ Progression, ProgressionSource, ProgressionEvent, clock.every, tick.time all excluded |
| 3 | Lab/Rack/Web pressure cited as pressure only | ✅ "R248 fixtures are proof-local evidence only"; Rust experiments "not source of truth" |
| 4 | No parser/typechecker/runtime/igc run widening implied | ✅ Authority Boundary closes all implementation surfaces explicitly |
| 5 | Implementation remains closed | ✅ Separate authorization required; 7 future gates must close first |

---

## What Remains Closed

The following surfaces remain closed. They are not opened by this acceptance:

- Parser implementation (grammar productions for `for`, `loop`, `recursive`, `fuel_bounded`)
- TypeChecker implementation (finite collection proof, static budget, decreases/fuel checks)
- SemanticIR emitter changes
- Runtime support of any kind
- `igc run` widening
- `.igapp` / `.igbin` execution
- OOF-L\*/OOF-R\* registry authority (candidates only — not registered OOF codes)
- `ConvergentLoop` detailed rules (deferred proof)
- `decreases fuel` as accepted parser syntax (candidate vocabulary only)
- Dynamic `max_steps` expressions
- `break` surface
- Service-loop diagnostics (OOF-SL\* remains PROP-037 companion territory)
- Lab behavior or R248 fixture grammar as canon
- Spark integration, release, public demo, or production claims

---

## Next Implementation Gates (from PROP-039 §Future Gates)

1. Proof-local source semantics fixture for FiniteLoop, BudgetedLocalLoop, StructuralRecursion, FuelBoundedRecursion
2. Parser boundary proof (only after grammar syntax is separately authorized)
3. TypeChecker proof for finite collection, static budget, and recursive decreases/fuel obligations
4. SemanticIR lowering design/proof (after parser/typechecker boundaries accepted)
5. OOF registry / diagnostic namespace review (if candidate diagnostics need canon authority)
6. Alternate implementation conformance consumer route (after canonical proof fixtures exist)
7. Runtime gates (runtime execution, igc run, .igbin, RuntimeSmoke, Reference Runtime) remain separately closed

---

## Routing

- Next action: author proof-local semantics fixture for FiniteLoop/BudgetedLocalLoop when
  the queue reaches implementation authorization (after PROP-039 gates 1+ open)
- PROP-037 boundary: any candidate for OOF-SL\* codes must route through PROP-037 governance,
  not PROP-039
- Candidate OOF-L\*/OOF-R\* codes must pass through OOF registry review before becoming
  canon diagnostic codes

---

*Accepted by: Portfolio Architect Supervisor — 2026-06-07*
