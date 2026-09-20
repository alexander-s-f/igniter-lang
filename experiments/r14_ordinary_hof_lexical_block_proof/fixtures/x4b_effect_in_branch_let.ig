-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen x4b_effect_in_branch_let
-- NEGATIVE (effect admission): forbidden now() as the expression of a BRANCH-local let inside a fold lambda. Must refuse.
module R14.X4B

pure contract O {
  input xs : Collection[Integer]

  compute total : Integer = fold(xs, 0, (acc, r) -> if r > 0 { let r = now()
      acc + r } else { acc })

  output total : Integer
}
