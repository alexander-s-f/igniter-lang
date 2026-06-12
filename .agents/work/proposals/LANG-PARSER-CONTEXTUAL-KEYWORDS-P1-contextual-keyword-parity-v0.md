# LANG-PARSER-CONTEXTUAL-KEYWORDS-P1 — Ruby Contextual Keyword Parity

**Track:** parser-contextual-keyword-binding-position-parity-v0
**Route:** PROPOSAL / PLANNING ONLY / NO IMPLEMENTATION
**Date:** 2026-06-12
**Status:** planning-complete — ready for P2 direct fix
**Predecessors:**
- LAB-PARSER-LABEL-IDENTIFIER-P1 (60/60 PASS — readiness proof; corpus survey; Rust parity analysis)

---

## Problem Statement

The Ruby parser in `igniter-lang` rejects keywords as binding names in 5 declaration positions plus 3 lambda-related call sites. The Rust parser accepts keywords as names uniformly in all positions. This divergence blocks any contract that uses a language keyword (e.g. `label`, `step`, `from`) as an `input`/`output`/`compute`/param/let binding name — a real use pattern confirmed by the decision_tree `DT-P02` app fixture.

The root cause is **inconsistent `name_token!` call sites** in parser.rb. Permissive call sites (type fields, record keys, dotted access) already use `name_token!(%i[ident keyword])`. Binding-position call sites use `name_token!(%i[ident])` — ident-only — which hard-rejects `:keyword` tokens.

---

## Grounding: LAB-PARSER-LABEL-IDENTIFIER-P1

All findings below are grounded in the 60/60 PASS lab proof. Key sections:

| Section | Claims | Result |
|---------|--------|--------|
| A INVENTORY | keyword set, call site taxonomy | 6/6 PASS |
| B FAILING POSITIONS | 5 decl + lambda | 8/8 PASS |
| C WORKING POSITIONS | fields/records/dotted | 6/6 PASS |
| D RUST BEHAVIOR | uniform acceptance | 8/8 PASS |
| E ROOT CAUSE | inconsistent call sites | 6/6 PASS |
| F SIBLING RISK | 8 affected keywords | 8/8 PASS |
| G APP PRESSURE | decision_tree DT-P02 | 4/4 PASS |
| H RECOMMENDED ROUTE | broad > narrow | 6/6 PASS |

---

## Q1 — Rust Divergence: Already Permissive

**Finding: Rust parser is already fully permissive. No Rust changes needed.**

`igniter-compiler/src/parser.rs` has a single `name_token()` helper (line 720–727):

```rust
fn name_token(&mut self) -> Result<String, String> {
    let tok = self.advance().ok_or_else(|| "Unexpected EOF".to_string())?;
    if tok.token_type == TokenType::Ident || tok.token_type == TokenType::Keyword {
        Ok(tok.value.clone())
    } else {
        Err(format!("Expected name, got {:?}({})", tok.token_type, tok.value))
    }
}
```

This function is used uniformly in **all** name positions — declarations, params, let bindings, lambda params. There are no ident-only call sites. Rust already achieves the target state. P1 documents this as confirmed parity target; no divergence to fix on the Rust side.

---

## Q2 — Sibling Keyword Corpus

All 8 keywords in the P1 acceptance corpus are confirmed in the Ruby `KEYWORDS` constant (`parser.rb` lines 42–60):

| Keyword | Group in KEYWORDS | Fails in Ruby binding? |
|---------|-------------------|----------------------|
| `label` | invariant-attributes | YES — DT-P02 confirmed |
| `message` | invariant-attributes | YES |
| `from` | cycle | YES |
| `match` | variant | YES |
| `profile` | profile | YES |
| `authority` | profile | YES |
| `lead` | loop | YES |
| `step` | pipeline | YES |

All fail for identical root cause: their token type is `:keyword`, and binding-position `name_token!(%i[ident])` rejects `:keyword`.

Safe non-keyword alternatives exist (`kind`, `state`, `name`, `when`, `action`) but requiring rename workarounds is not acceptable when the fix is mechanical.

---

## Q3 — Failing Call Sites (Ruby)

**8 sites total** across 5 methods. All in `lib/igniter_lang/parser.rb`.

### Site 1 — `parse_input_decl` line 950
```ruby
name = name_token!(%i[ident])        # FAILS for keyword names
```
Fix: `name_token!(%i[ident keyword])`

### Site 2 — `parse_output_decl` line 957
```ruby
name = name_token!(%i[ident])        # FAILS for keyword names
```
Fix: `name_token!(%i[ident keyword])`

### Site 3 — `parse_compute_decl` line 1031
```ruby
name = name_token!(%i[ident])        # FAILS for keyword names
```
Fix: `name_token!(%i[ident keyword])`

### Site 4 — `parse_params` line 1358
```ruby
pname = name_token!(%i[ident])       # FAILS for keyword param names
```
Fix: `name_token!(%i[ident keyword])`

### Site 5 — `parse_let_stmt` line 1388
```ruby
name = name_token!(%i[ident])        # FAILS for keyword let-binding names
```
Fix: `name_token!(%i[ident keyword])`

### Site 6 — `parse_lambda` line 1816 (multi-param branch)
```ruby
pname = name_token!(%i[ident])       # FAILS for keyword lambda params
```
Fix: `name_token!(%i[ident keyword])`

### Site 7 — `parse_lambda` line 1821 (single-param branch)
```ruby
elsif peek_type?(:ident)             # FAILS to match keyword single-param lambdas
  params << advance.value
```
Fix: `elsif peek_type?(:ident) || peek_type?(:keyword)`
(`advance.value` is correct as-is — reads token value regardless of type.)

### Site 8 — `parse_call_arg` line 1781 (lambda dispatch)
```ruby
elsif peek_type?(:ident) && peek(1)&.type == :arrow   # FAILS to dispatch keyword -> lambda
```
Fix: `elsif (peek_type?(:ident) || peek_type?(:keyword)) && peek(1)&.type == :arrow`

---

## Q4 — Working Call Sites (Unchanged)

These already use `%i[ident keyword]` and must NOT be touched:

| Method | Line | Pattern | Position |
|--------|------|---------|----------|
| `parse_type_decl` | 1323 | `name_token!(%i[ident keyword])` | type field names |
| `parse_record_or_block` | 2018 | `name_token!(%i[ident keyword])` | record literal keys |
| `parse_postfix` | 1736 | (dotted access, reads token directly) | `.field` access |
| `parse_index_slice_record` | 1769 | `name_token!(%i[ident keyword])` | index slice keys |
| `parse_evidence_list` | 1023 | `name_token!(%i[ident keyword])` | evidence refs |

P2 must not regress these.

---

## Q5 — Semantic Safety

The typechecker resolves names by string value, not by token type. Changing `name_token!` to accept `:keyword` tokens does not affect:

- OOF error codes
- Type checking
- SemanticIR shape
- Assembler / manifest
- Any downstream artifact

A binding named `label` is stored as the string `"label"` identically whether the token was classified `:ident` or `:keyword`. The change is purely syntactic.

---

## Q6 — Scope and Size Assessment

| Dimension | Value |
|-----------|-------|
| Files changed | 1 (`lib/igniter_lang/parser.rb`) |
| Lines changed | 8 (5× `%i[ident]` → `%i[ident keyword]`, 2× ident peek conditions, 1× call_arg dispatch) |
| Methods touched | 6 (`parse_input_decl`, `parse_output_decl`, `parse_compute_decl`, `parse_params`, `parse_let_stmt`, `parse_lambda`, `parse_call_arg`) |
| New keywords added | None |
| Grammar/spec changes | None required (contextual keyword acceptance is a parser implementation detail) |
| Typechecker changes | None |
| Test scope | New cases for each keyword × each binding position |

**Assessment: TINY fix.** Routing as direct P2 implementation (no separate P2 planning document required).

---

## Q7 — Closed Surfaces

The following are explicitly out of scope for P2:

- No escape syntax (e.g. `\label`, `` `label` ``)
- No changes to the `KEYWORDS` constant (no additions, no removals)
- No changes to `igniter-compiler/src/lexer.rs` or `parser.rs`
- No changes to app source files (decision_tree etc.)
- No typechecker changes
- No SemanticIR changes
- No OOF error code changes
- No canon keyword policy changes

---

## P2 Routing Decision

**Route: Direct P2 Fix.**

The fix is 8 lines in 1 file. A separate P2 planning document would add ceremony without value. P2 implementer should:

1. Apply the 8 site changes from Q3 above.
2. Add test cases covering each of the 8 keywords × 5 binding positions (40 cases minimum).
3. Verify existing test suite continues to pass (no regressions at working call sites).
4. Update portfolio index.

No additional planning gate is required before P2.

---

## Acceptance Matrix

| Criterion | Met by P2? | Grounding |
|-----------|-----------|-----------|
| `input kw : T` parses | Yes — site 1 | parse_input_decl:950 |
| `output kw : T` parses | Yes — site 2 | parse_output_decl:957 |
| `compute kw = expr` parses | Yes — site 3 | parse_compute_decl:1031 |
| `def f(kw: T)` parses | Yes — site 4 | parse_params:1358 |
| `let kw = expr` parses | Yes — site 5 | parse_let_stmt:1388 |
| `kw ->` lambda dispatch | Yes — sites 7+8 | parse_lambda:1821, parse_call_arg:1781 |
| `(kw) ->` lambda multi-param | Yes — site 6 | parse_lambda:1816 |
| `%i[ident keyword]` parity at working sites | Unchanged | Q4 above |
| All 8 corpus keywords covered | Yes — identical root cause | Q2 above |
| Rust behavior proven permissive | Documented | Q1 above |
| No semantic/typechecker changes | Confirmed | Q5 above |
| Tiny fix → direct P2 | Confirmed | Q6 above |
