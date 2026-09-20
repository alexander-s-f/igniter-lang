-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen x6_unbound_name_in_let
-- NEGATIVE (name): a block let's expression reads a name that is bound nowhere. Must refuse OOF-P1 on both frontends.
module R14.X6

pure contract O {
  input xs : Collection[Float]

  compute total : Float = fold(xs, 0.0, (acc, r) -> {
      let r = r + missing
      acc + r
    })

  output total : Float
}
