-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen h2_filter_block_count
-- filter STAGE of an aggregate pipeline (count(filter(..))) with a block body. x + 10.0 > 20.5 -> 2.
module R14.H2

pure contract O {
  input xs : Collection[Float]

  compute total : Integer = count(filter(xs, (x) -> {
      let x = x + 10.0
      x > 20.5
    }))

  output total : Integer
}
