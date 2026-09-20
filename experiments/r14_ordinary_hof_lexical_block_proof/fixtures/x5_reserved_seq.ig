-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen x5_reserved_seq
-- NEGATIVE (reserved binder): the ordinary route now lowers a bare statement to let __seq__, exactly like the stream carrier; a PARAMETER spelled __seq__ would be shadowed by that lowering (acc + twice(x) instead of acc + x). Refused OOF-COL4 by the carrier's own law.
module R14.X5

def twice(a: Integer) -> Integer {
  a * 2
}

pure contract O {
  input xs : Collection[Integer]

  compute total : Integer = fold(xs, 0, (acc, __seq__) -> {
      twice(__seq__)
      acc + __seq__
    })

  output total : Integer
}
