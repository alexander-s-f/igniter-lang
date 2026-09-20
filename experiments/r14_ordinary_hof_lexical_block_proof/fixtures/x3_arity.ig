-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen x3_arity
-- NEGATIVE (arity): a three-parameter fold lambda with a block body. Must refuse OOF-COL4 on both frontends.
module R14.X3

pure contract O {
  input xs : Collection[Float]

  compute total : Float = fold(xs, 0.0, (acc, r, z) -> {
      let r = r + 1.0
      acc + r
    })

  output total : Float
}
