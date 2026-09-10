# text_concat_typed_arg_reuse_proof

Permanent regression proof for `LANG-CANON-TEXT-CONCAT-TYPED-ARG-REUSE-IMPLEMENTATION-P3`
(H+B landed in `lib/igniter_lang/typechecker.rb`):

- **B** — `infer_concat_call` hands its already-inferred positional argument(s) to `infer_text_call`
  (`typed:` keyword); absent positions are inferred exactly as before. A Text-prefixed interpolation
  chain is now typed once per node (the old route re-inferred the whole left prefix at every enclosing
  concat: `V = 1 + 2V(left) + V(right)`).
- **H** — the guarded `DEBUG: unresolved l backtrace` `puts` block in `infer_expr`'s ref case is removed;
  OOF-P1 emission is unchanged.

Run from anywhere; it loads THIS repo's `lib` and asserts the loaded typechecker's realpath:

```bash
ruby experiments/text_concat_typed_arg_reuse_proof/verify_text_concat_typed_arg_reuse.rb             # full suite
ruby experiments/text_concat_typed_arg_reuse_proof/verify_text_concat_typed_arg_reuse.rb --controls  # S1/S2/S3 only
```

Coverage: String/String fast path, Text/Text, both mixed orders, long chain, Collection and Unknown-first
routing, wrong arity, unknown non-ref second argument, default `trim(t)` path, nested dependencies and
branch context, ordered multiple refusals and dedupe, nonempty OOF-M3 and in-expression OOF-O2 with a
no-warning control, real `bin/igc check --json` on `fixtures/unresolved_l.ig` / `unresolved_zz.ig`
(strict JSON, no DEBUG, exit 1, ordered diagnostics), a bounded work-count guard (test-only
`prepend` counter; exact 31 / 11 / 4 infer_expr entries), and the source law itself.
The two sensitivity controls (S1 work count, S2 DEBUG-free stdout) fail on the pre-H+B source by design.
Lab evidence for the accepted comparison: `igniter-lab/proofs/lang-canon-text-concat-typed-arg-reuse-readiness-p2-a1/`.
