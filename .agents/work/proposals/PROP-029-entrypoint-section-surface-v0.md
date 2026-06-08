# PROP-029: Entrypoint and Section Surface v0

Status: proposal
Date: 2026-05-08
Author: `[Igniter-Lang Compiler/Grammar Expert]`
Depends on: PROP-014, PROP-015, PROP-027
Stage: 3
Source: `docs/tracks/spec-entrypoint-sync-v0.md`,
`docs/meta-proposals/syntax-pressure-registry-v0.md`,
`docs/meta-proposals/syntax-pressure-review-results-v0.md`

Implementation state:
  - No parser support exists today.
  - `entrypoint` and `section` are not current canon.
  - `entrypoint` and `section` are not hard-reserved parser keywords today.
  - This PROP does not authorize parser implementation by itself.

---

## 1. Purpose

Human/agent syntax pressure repeatedly asked: where does a source file start,
and how can a larger source file be organized without pretending organization
is a namespace?

Current Igniter-Lang already has a canonical computation boundary:

```text
contract
```

This PROP does not replace that boundary. It proposes a small source surface for
navigation and tool selection:

```text
entrypoint  -- named evaluation/run profile over an existing contract
section     -- grouping-only source organization
```

Non-goals:

- no parser implementation in this PROP
- no runtime scheduler
- no package/API entrypoint rename
- no namespace/module/profile semantics for `section`
- no production runtime authorization for TEMPORAL evaluation
- no fixture language for top-level sample values

---

## 2. Entrypoint Meaning Candidates

| Candidate | v0 Disposition | Reason |
|-----------|----------------|--------|
| Default contract | rejected for v0 | A `contract` is already the computation boundary. Making `entrypoint` a second contract-like declaration would blur graph identity. |
| Evaluation target | accepted | Tools need a named source-level target that points at an existing contract and optional output. |
| Fixture/run profile | accepted, constrained | An entrypoint may carry explicit sample args for proof fixtures or tools, but it must not create ambient defaults or scheduler behavior. |
| Runtime route/scheduler trigger | deferred | Runtime routing, schedules, UI routes, and deployment profiles require separate runtime/package proposals. |

### v0 recommendation

`entrypoint` is a named source-level evaluation profile.

It references an existing contract, may narrow to one output, may provide a
complete explicit argument record for tool/proof execution, and may be marked as
the default source entrypoint. It does not create a SemanticIR node and does not
change contract classification.

---

## 3. Entrypoint Semantics

An entrypoint declaration has:

```text
name       -- unique program-local entrypoint name
contract   -- required existing contract name
output     -- optional output name from the target contract
args       -- optional explicit record of input values
default    -- optional Bool; at most one entrypoint may be default
```

Example candidate syntax:

```text
entrypoint plan_today {
  contract: PlanDay
  output: summary
  default: true
  args: {
    team: sample_team,
    tasks: open_tasks
  }
}
```

Rules:

- A program may contain zero or more entrypoints.
- Entrypoint names are program-local, not module-path names.
- Entrypoints do not define contracts, functions, types, inputs, outputs, reads,
  effects, lifecycles, or cache keys.
- Entrypoints inherit the fragment behavior of their target contract. A
  TEMPORAL contract remains TEMPORAL and runtime evaluation remains guarded by
  the existing TEMPORAL load/evaluate policy.
- If `args` is absent, the entrypoint is a target selector only.
- If `args` is present, the argument record must match the target contract input
  surface exactly unless a future defaults proposal changes that rule.
- If `default: true` is absent on all entrypoints, compilation may still
  succeed. Tools that need a default must ask for a target explicitly.
- If exactly one entrypoint exists, tools may offer it as a convenience, but the
  language does not turn it into an implicit contract.

---

## 4. Section Meaning Candidates

| Candidate | v0 Disposition | Reason |
|-----------|----------------|--------|
| Visual grouping | accepted | Helps humans and agents navigate larger files without changing semantics. |
| Namespace/module | rejected for v0 | `module` already owns module identity; `section` must not create hidden names. |
| Visibility/scope | rejected for v0 | Visibility and scoping would affect resolution and diagnostics. |
| Evaluation order | rejected for v0 | Declaration order must not become runtime order. |
| Profile/surface alias | deferred | Profiles need separate capability/runtime semantics. |

### v0 recommendation

`section` is grouping-only source organization.

It may wrap top-level declarations, including entrypoints, but the compiler
flattens those declarations into the same program-level declaration sets while
preserving source spans and `section_path` metadata.

---

## 5. Section Semantics

Example candidate syntax:

```text
section Entry {
  entrypoint plan_today {
    contract: PlanDay
    output: summary
  }
}
```

Rules:

- A section has a label and a body.
- A section body may contain only top-level declarations accepted by the source
  grammar plus entrypoint declarations if this PROP is implemented.
- A section does not create a namespace.
- A section does not affect name resolution.
- A section does not affect dependency analysis, fragment classification,
  SemanticIR, cache keys, lifecycle, or runtime scheduling.
- Nested sections are rejected in v0.
- Duplicate section labels are not semantic. A future formatter/tool may warn,
  but the compiler should not reject duplicates solely because labels repeat.

---

## 6. Proposed Grammar Delta

This grammar is a proposal target only. It is not implemented today.

```text
TopDecl          := SectionDecl | EntryPointDecl
                 | ContractDecl | TypeDecl | FunctionDecl | ExternalDecl

SectionDecl      := "section" Name "{" SectionBodyDecl* "}"
SectionBodyDecl  := EntryPointDecl | ContractDecl | TypeDecl
                 | FunctionDecl | ExternalDecl

EntryPointDecl   := "entrypoint" Name "{" EntryPointField* "}"
EntryPointField  := "contract" ":" Name
                 | "output" ":" Name
                 | "default" ":" BoolLit
                 | "args" ":" RecordLit
```

Keyword policy:

- Current parser behavior is unchanged.
- Future parser implementation should treat `entrypoint` and `section` as
  contextual declaration keywords, recognized only where declarations are
  expected.
- The proposal does not require hard reservation of those words as ordinary
  identifiers outside declaration position.

---

## 7. ParsedProgram Shape

If implemented, the parser should preserve both the flattened declaration view
and source organization metadata.

Recommended shape:

```json
{
  "kind": "parsed_program",
  "sections": [
    {
      "kind": "section_decl",
      "name": "Entry",
      "section_path": ["Entry"],
      "decl_refs": ["entrypoint:plan_today"],
      "source_span": {"start": 120, "end": 180}
    }
  ],
  "entrypoints": [
    {
      "kind": "entrypoint_decl",
      "name": "plan_today",
      "contract": "PlanDay",
      "output": "summary",
      "default": true,
      "args": {
        "kind": "record_lit",
        "fields": {
          "team": {"kind": "ref", "name": "sample_team"},
          "tasks": {"kind": "ref", "name": "open_tasks"}
        }
      },
      "section_path": ["Entry"],
      "source_span": {"start": 130, "end": 175}
    }
  ],
  "contracts": []
}
```

Downstream rules:

- TypeChecker resolves entrypoint targets after contract/type surfaces exist.
- SemanticIREmitter does not emit entrypoints as SemanticIR nodes.
- A future assembler may include an `entrypoints` metadata artifact, but that
  artifact must not authorize runtime behavior beyond target selection.

---

## 8. OOF / Error Rules

Entrypoint diagnostics:

```text
OOF-EP1  Duplicate entrypoint name in one parsed program.
OOF-EP2  Entrypoint missing required contract field.
OOF-EP3  Entrypoint references unknown contract.
OOF-EP4  Entrypoint output references unknown output on the target contract.
OOF-EP5  Entrypoint args include a key that is not a target contract input.
OOF-EP6  Entrypoint args omit a required target contract input when args are present.
OOF-EP7  Entrypoint arg expression does not typecheck against the target input type.
OOF-EP8  More than one entrypoint is marked default.
OOF-EP9  Entrypoint field appears more than once with conflicting values.
```

Section diagnostics:

```text
OOF-SEC1 Nested section in v0.
OOF-SEC2 Illegal declaration inside section body.
OOF-SEC3 Section label is missing or malformed.
```

General parser behavior:

```text
OOF-G1 remains the current parser response until this PROP is implemented.
```

---

## 9. Acceptance Checklist

This PROP is proposal-only until a future implementation card proves:

- parser accepts top-level `entrypoint`
- parser accepts grouping-only `section`
- parser accepts entrypoint inside section and preserves `section_path`
- parser rejects nested section with OOF-SEC1
- parser/typechecker rejects OOF-EP1..EP9 with targeted diagnostics
- entrypoints do not alter contract classification
- entrypoints do not create SemanticIR nodes
- existing source-to-SemanticIR goldens remain stable except explicit metadata
  additions
- current parser keywords remain contextual, not hard-reserved everywhere

Suggested proof slice:

```text
entrypoint-section-parser-typechecker-v0
```

---

## 10. Status

Proposal status: `proposal`.

Recommended disposition:

- accept `entrypoint` as a named evaluation/run profile over an existing
  contract;
- accept `section` as grouping-only syntax;
- defer parser implementation to a dedicated proof slice;
- reject namespace, scheduler, and runtime-route meanings for v0.

This PROP supersedes the unnumbered `entrypoint/section` proposal-candidate
slot from `spec-entrypoint-sync-v0`.
