-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen b3_int_outer_float_shadow
-- Integer element, then-branch let shadows it with a FLOAT: outer r > 10 is stdlib.integer.gt, inner r > 2.0 is stdlib.float.gt. [1,11,21] -> 2.
module R14.B3

pure contract O {
  input xs : Collection[Integer]

  compute total : Integer = fold(xs, 0, (acc, r) -> if r > 10 { let r = 2.5
      if r > 2.0 { acc + 1 } else { acc } } else { acc })

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
    fold_stream(readings, 0, (acc, r) -> if r > 10 { let r = 2.5
      if r > 2.0 { acc + 1 } else { acc } } else { acc }) @window_bounded

  output total: Integer
}
