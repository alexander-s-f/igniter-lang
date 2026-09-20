-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen t1_string_block
-- String route: a block let holding a concat result, concat tail. ["a","b"] -> "a!b!".
module R14.T1

pure contract O {
  input words : Collection[String]

  compute joined : String = fold(words, "", (acc, w) -> {
      let w = concat(w, "!")
      concat(acc, w)
    })

  output joined : String
}
