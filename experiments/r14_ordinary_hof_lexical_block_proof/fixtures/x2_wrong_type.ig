-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen x2_wrong_type
-- NEGATIVE (wrong type): Integer accumulator, the block tail is the FLOAT let. Must refuse OOF-COL4 on both frontends.
module R14.X2

pure contract O {
  input xs : Collection[Float]

  compute total : Integer = fold(xs, 0, (acc, r) -> {
      let r = r * 2.0
      r
    })

  output total : Integer
}
