-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen k2_block_bare_stmt_def
-- p17 shape: a BARE statement between the let and the tail, app-local def calls. [1,11,21] -> 66.
module R14.K2

def twice(a: Integer) -> Integer {
  a * 2
}

pure contract O {
  input xs : Collection[Integer]

  compute total : Integer = fold(xs, 0, (acc, r) -> {
      let r = twice(r)
      twice(r)
      acc + r
    })

  output total : Integer
}

observed contract S {
  input device_id: String
  stream readings: Integer

  window "r14/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }

  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> {
      let r = twice(r)
      twice(r)
      acc + r
    }) @window_bounded

  output total: Integer
}
