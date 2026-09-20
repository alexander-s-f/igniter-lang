-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen h1_map_block
-- STANDALONE map with a lambda BLOCK body (generic lambda lowering, not the fold pipeline). -> [3.0,23.0,43.0].
module R14.H1

pure contract O {
  input xs : Collection[Float]

  compute ys : Collection[Float] = map(xs, (x) -> {
      let x = x * 2.0
      x + 1.0
    })

  output ys : Collection[Float]
}
