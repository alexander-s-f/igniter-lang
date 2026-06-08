# Axiomatic And System-Forming Ideas Lens v0

Role: `[Igniter-Lang Archive/Form Expert]`
Card: `S3-R1-C5-P`
Track: `axiomatic-and-system-forming-ideas-lens-v0`
Status: research-note
Date: 2026-05-08

Related:
- [META-EXPERT-010](META-EXPERT-010-human-agent-symbiosis-vision-v0.md)
- [META-EXPERT-011](META-EXPERT-011-stage3-governance-opening-v0.md)
- [META-EXPERT-008.2](META-EXPERT-008.2-fresh-language-model-report-v0.md)
- [Human-Agent Comprehension Synthesis](human-agent-comprehension-synthesis-v0.md)

---

## Purpose

Capture `АИ/СОИ` as a design lens for Igniter-Lang.

This is a meta/design note, not a formal spec and not a new PROP.

---

## Terms

### АИ — Axiomatic Idea

Question:

```text
How is this possible?
Under what conditions can it exist?
What must be true for this construct to be sound?
```

АИ is the condition-of-possibility layer. It asks for the thin law underneath a
feature before we design syntax or implementation.

### СОИ — System-Forming Idea

Question:

```text
Why does this exist?
What is it organizing around?
What kind of system does this make possible?
```

СОИ is the organizing-center layer. It asks what a construct gathers into a
coherent system and why it deserves to exist in the language.

---

## Working Form

For any proposed language/runtime idea:

```text
АИ:  What condition makes this possible?
СОИ: What system does this organize?
```

If a design has СОИ without АИ, it may be inspiring but unsound.

If a design has АИ without СОИ, it may be correct but sterile.

[S] Igniter-Lang needs both: strong conditions of possibility and strong
system-forming centers.

---

## Examples

### 1. Contract As The Root Unit

АИ:

```text
A computation can be treated as a contract if its inputs, outputs, dependencies,
effects, and obligations are declared enough to be checked.
```

СОИ:

```text
Contract organizes language, compiler, runtime, evidence, diagnostics, and
human-agent handoff around one shared unit of meaning.
```

Current decision pressure:
- Keep `contract` as more than a function.
- Do not let convenient syntax erase input/output/evidence/lifecycle identity.
- Let primitive sugar lower into contracts, but keep contract semantics visible
  in diagnostics and SemanticIR.

### 2. Time As Explicit Semantic Dimension

АИ:

```text
Temporal evaluation is sound only when time is an explicit input or context,
not an ambient call to "now".
```

СОИ:

```text
Time organizes History[T], BiHistory[T], stream windows, replay, cache keys,
forecasting, and auditability.
```

Current decision pressure:
- `as_of`, `knowledge_as_of`, valid time, and transaction time are not just API
  parameters.
- TEMPORAL fragment class belongs in Stage 3 because runtime routing and cache
  semantics need temporal capability awareness.
- Human-agent explanations should say which time a statement belongs to.

### 3. Projection As A First-Class Form

АИ:

```text
A projection is possible when source, shape, refresh/materialization boundary,
and evidence path can be named.
```

СОИ:

```text
Projection organizes views, OLAP points, status dashboards, reports, OSINT
summaries, and agent-readable state.
```

Current decision pressure:
- Separate `type` shape from `view` materialization.
- Treat `current-status.md` and close candidates as project-process projections.
- Let future `section`/`entrypoint` syntax improve projection readability
  without hiding runtime obligations.

### 4. RuntimeMachine As Contract Executor

АИ:

```text
A runtime can execute safely only if it can verify artifact compatibility,
runtime capabilities, lifecycle expectations, and temporal/evidence requirements.
```

СОИ:

```text
RuntimeMachine organizes execution, load/evaluate/checkpoint/resume, TBackend
capabilities, observations, compatibility reports, and distributed handoff.
```

Current decision pressure:
- Runtime is not "just implementation"; runtime is a contract boundary.
- TBackend descriptor evidence is a valid Stage 2 close surface, while
  production Ledger read/write binding is correctly deferred.
- Multiple RuntimeMachines imply composition of RuntimeContracts, not informal
  clustering.

### 5. Agent Work As Contract-Native Collaboration

АИ:

```text
Human-agent collaboration is possible when intent, role, authority, evidence,
status, and handoff are explicit enough to be reviewed and resumed.
```

СОИ:

```text
Human-agent symbiosis organizes cards, roles, tracks, typed handoffs, review
points, status projections, and memory roots into a shared work system.
```

Current decision pressure:
- `Card`, `Agent`, `Role`, and `Track` are proto-language signals, not only
  project management labels.
- `await_review` should be lifecycle/suspension semantics, not a function call.
- Syntax comprehension tests should measure both "can explain" and "can verify".

### 6. Evidence / Proof / Receipt Separation

АИ:

```text
Traceability is sound only when provenance, proof obligation, durable decision,
hash identity, and cryptographic signature are not collapsed into one word.
```

СОИ:

```text
This separation organizes audit systems, mathematical verification, OSINT
fact-checking, receipts, and replayable runtime observations.
```

Current decision pressure:
- `evidence` is provenance, not automatically proof or crypto.
- `receipt` is a durable operational artifact, not a theorem.
- Academic profiles likely need `proof`/`witness` vocabulary distinct from
  audit `receipt`.

---

## Lens Checklist

Use this as a lightweight review prompt:

```text
1. What is the АИ?
2. What is the СОИ?
3. What existing Igniter-Lang law or proof supports the АИ?
4. What system surface becomes simpler if the СОИ is accepted?
5. What ambiguity appears if АИ and СОИ are not separated?
6. Is this ready for PROP work, or only pressure/research?
```

This should be short. If a proposal cannot answer these in a few sentences, the
idea probably needs another research slice before canon work.

---

## Recommendation

[R] Adopt `АИ/СОИ` as **Stage 3 governance vocabulary**, but only as a soft lens:

- Add it to proposal/research review practice.
- Use it in Meta Expert and Archive/Form Expert synthesis.
- Encourage Compiler/Grammar Expert PROPs to include one compact `АИ/СОИ` block.
- Do not make it a hard acceptance gate for every small implementation track.
- Do not let it replace proofs, tests, or formal grammar work.

[S] Best use:

```text
АИ/СОИ prevents valuable signals from being flattened into implementation tasks.
```

[T] Risk:

```text
If overused, it becomes ceremony. Keep it small, sharp, and tied to decisions.
```

---

## Handoff

```text
Card: S3-R1-C5-P
Agent: [Igniter-Lang Archive/Form Expert]
Role: archive-form-expert
Track: axiomatic-and-system-forming-ideas-lens-v0
Status: done

[D] Captured АИ/СОИ as a design lens:
    АИ = conditions of possibility; СОИ = organizing/system-forming purpose.

[S] Connected the lens to contracts, time, projections, RuntimeMachine,
    agents, human-agent symbiosis, and evidence/proof/receipt separation.

[T] This is a research note only. No semantics or spec changes.

[R] Recommend adopting АИ/СОИ as soft Stage 3 governance vocabulary for
    proposals and synthesis, not as a hard gate.
```
