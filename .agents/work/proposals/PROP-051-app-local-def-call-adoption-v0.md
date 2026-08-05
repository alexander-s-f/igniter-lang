# PROP-051 — App-local `def` call adoption (typed calls, purity parity, SIR)

Status: experiment-pass (implemented and verified by `LANG-APP-LOCAL-DEF-CALL-CANON-ADOPTION-P2`;
review per Covenant CR-002 by the Compiler/Grammar Expert)
Date: 2026-08-05
Authorized by: `LANG-APP-LOCAL-DEF-CALL-CANON-ADOPTION-READINESS-P1`
(CLOSED / GO_CANON_APP_LOCAL_DEF_ADOPTION; curator-accepted) and the
curator-fixed identity/collision/visibility law in the P2 card.
Evidence basis: P1 corpus pair `091301d5…` (17 records, both public
doors), reproduced 17/17 at the P2 baselines with zero semantic drift.

> **Numbering note.** First drafted as PROP-040; renumbered to **PROP-051**
> because `PROP-040` is the already-accepted *profile declarations*
> proposal (cited in the covenant and ch11/ch12). The P2 curator reconciled
> the app-local-def references to PROP-051 while preserving unrelated
> profile-declaration references to PROP-040.

## 1. Language law

Canon adopts statically-known module-local `def` calls as a first-class
typed SemanticIR surface. All seven points below are one law; partial
implementation is non-conforming.

1. **Registry.** One module-local function registry per toolchain:
   `(module, name) → FunctionDecl`. It is the single source for call
   resolution, signature/body typing, recursion and IO/time analysis, and
   SIR emission. Ruby reuses the existing `fn_extract_all_calls` +
   `tarjan_sccs` + `compute_io_helper_summary` graph; no second graph may
   exist in either toolchain.
2. **Identity and visibility.** Function identity is `(module, name)`;
   the emitted identity is `user.<module>.<name>`. An unqualified call
   resolves ONLY an app-local `def` declared in the caller's module.
   Equal names in different modules are legal and permanently distinct.
   Cross-module function calls and function imports are CLOSED by this
   PROP (they refuse; a later PROP may open a qualified-call surface).
3. **Collision law.** A same-module `def` whose name collides with a
   visible stdlib callable (bare/ad-hoc or imported) or with a derived or
   sealed constructor REFUSES (`OOF-F2`) — shadowing is never silently
   resolved in either direction. A duplicate `(module, name)` declaration
   REFUSES (`OOF-F3`). Keywords are not legal `def` names.
4. **Signature and body typing (fail-closed).** Call sites check arity
   and parameter types; `def` bodies are typechecked with parameters in
   scope; the body's type must match the declared return type. `Unknown`
   never silently authorizes a call. Diagnostics use the `OOF-TY0` typing
   family with the pinned message shapes of §3.
5. **Transitive purity and temporal laws.** The `OOF-M1` pure-contract
   purity family covers (a) escape-capability declarations and (b)
   transitive ambient-IO laundering through `def`s — including through
   lambda bodies — in BOTH toolchains over the one graph. `now()` is
   forbidden in `def` bodies (`OOF-L2`) in both toolchains. The
   `OOF-EC6` iteration fence applies to NON-pure contracts only (pure
   contracts are owned by `OOF-M1`/`E-IO-AMBIENT-BLOCKED`).
6. **Recursion.** Every member of a nontrivial call-graph SCC must carry
   the literal `decreases fuel` (`OOF-L4`, message byte-locked).
   `decreases fuel` is a compile-time recursion-law token with NO
   independent runtime fuel; the shared runtime call-depth bound
   (`MAX_CALL_DEPTH = 64`) is the executable backstop.
7. **SemanticIR.** The SIR envelope gains a top-level `functions` array
   (emitted when non-empty): per-function keys exactly
   `{kind: "function_ir", name, params: [{name, type}], return_type,
   decreases?, body}` where `name` is the emitted identity
   `user.<module>.<name>`, types are display text, and `body` is the
   right-nested `let` lowering of the block (bare statements bind
   `__seq__`). Resolved call sites lower to
   `{kind: "call", fn: "user.<module>.<name>", args: […]}`. The `user.`
   prefix is reserved: no stdlib re-qualification pass may rewrite it,
   and no stdlib identity may ever begin with `user.`. PROP-015's
   §Part-1 lowering (`user.<module>.<name>` apply, "inlined at
   classification time") is superseded by this registry emission — the
   identity survives, the inlining claim does not. Dynamic targets,
   reflection, closures-as-function-identity and runtime string dispatch
   remain closed. Ruby runtime execution is not required; compiler
   evidence mints no runtime capability or admission authority.

## 2. Rule-id allocation (CR-002)

| Id | Law (after this PROP) | Provenance |
| --- | --- | --- |
| `OOF-L4` | recursive `def` in a nontrivial SCC without literal `decreases fuel` | LIVE in both toolchains, byte-identical message — allocation follows the shipped law; ch13's unrelated loop-`break` candidate moves to `OOF-L10` |
| `OOF-L2` | temporal access (`now()`) forbidden in `def` bodies and contract expressions | LIVE in Rust; Ruby adds the per-def scan; ch13's dynamic-`max_steps` candidate moves to `OOF-L9`; ch8's `OOF-L6` wording anchor is superseded by `OOF-L2` (L6 retired-historical, never emitted) |
| `OOF-M1` | pure-contract purity family: escape-capability declaration AND transitive ambient-IO laundering | both sub-laws LIVE in Rust under this id; Ruby's live escape-decl law keeps the id and gains the laundering consumer |
| `OOF-EC6` | iteration helper fence, non-pure contracts | unchanged; Ruby aligns its gate to `modifier != "pure"`; remedy wording remains byte-locked |
| `OOF-COL1` | superseded on the def surface — Ruby's live same-module bare-stdlib-collision refusal (measured on S14c `def take`) is re-allocated to `OOF-F2`'s collision LAW; `OOF-COL1` keeps its stdlib-arity meaning elsewhere | live Ruby, reconciled by this PROP |
| `OOF-F2` | NEW — `def` collides with visible stdlib callable (bare/ad-hoc or imported) / derived or sealed constructor | this PROP |
| `OOF-F3` | NEW — duplicate `(module, name)` `def` declaration | this PROP |
| `OOF-TY0` | typing family: unknown function (not visible in the caller's module), call arity/param mismatch, declared-return-vs-body mismatch | existing family; new members pinned in §3 |
| `OOF-F1` | retired-historical (spec'd non-recursion, never implemented; superseded by `OOF-L4`) | recorded, never reused |
| `OOF-G1`/`OOF-C3` | PROP-015 recursion ids: superseded-historical, never implemented | recorded, never reused |

## 3. Pinned diagnostic texts

Byte-locked (normative wording):

- `OOF-L4`: `Recursive function '<f>' must specify 'decreases fuel'`
- `OOF-L2`: `now() is forbidden in function '<f>' — use explicit as_of binding or tick.time`
- `OOF-M1` (laundering): the shipped Rust text — `pure contract '<C>'
  performs ambient I/O transitively through helper def '<d>' (a
  capability-backed host-IO sink is reachable via the call graph); pure
  contracts cannot launder effects through a def — use 'observed' for
  read-only access or move the I/O behind a declared capability`
- `OOF-EC6`: existing byte-locked remedy wording (unchanged)
- `OOF-F2`: `function '<name>' collides with <stdlib function|constructor> '<surface>' — rename the def; shadowing is refused`
- `OOF-F3`: `function '<name>' is declared more than once in module '<module>'`
- `OOF-TY0` members: `Unknown function: <name>` (surface absence /
  out-of-module); `Call to '<f>': expected N argument(s), got M`;
  `Call to '<f>': parameter '<p>' expects <T>, got <U>`;
  `function '<f>': body type <U> does not match declared return type <T>`

All other diagnostic wording remains non-normative per PROP-027
(stability attaches to rule id + disposition + law).

## 4. Grammar

`FunctionDecl := "def" Name "(" Params? ")" "->" TypeRef
["decreases" "fuel"] "{" Body "}"` — the `decreases fuel` slot becomes
canon grammar (both parsers already accept it). `def` declarations carry
source spans in diagnostics (Ruby adds them).

## 5. Spec deltas carried with this PROP

ch2 §2.4 (semantic rules rewritten: recursion-under-fuel, transitive
purity, registry emission, module scope, collision law; `OOF-F1` note
retired); ch2 EBNF appendix (production + decreases); ch6 + igapp schema
appendix (`functions` key and shape); ch12 (the "one analyzer, two
consumers" claim becomes dual-true; Unknown-function note updated to the
module-scoped law); ch13 (candidate re-allocations `OOF-L9`/`OOF-L10`;
L6 note); ch8 (`OOF-L6` → superseded by `OOF-L2`).

## 6. Compatibility

The P1 census (63 bodied defs / 25 files, all Rust-only; dual-clean
cohort empty) bounds the blast radius: no tracked app declares a def
colliding with a stdlib/constructor name; the previously-silent Rust
flat first-wins multifile behavior and def-shadows-stdlib precedence are
replaced by refusals, which is fail-closed hardening, not silent
reinterpretation. Old artifacts with bare-name `functions[]`/call nodes
remain executable (the VM registry is string-keyed); new artifacts carry
`user.`-qualified identities.
