-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen x1_branch_let_out_of_scope
-- NEGATIVE (binder scope): the then-branch let d is read in the ELSE branch. Must refuse OOF-P1 on both frontends.
module R14.X1

pure contract O {
  input xs : Collection[Float]

  compute total : Float = fold(xs, 0.0, (acc, r) -> if r > 10.5 { let d = 1.0
      acc + d } else { acc + d })

  output total : Float
}
