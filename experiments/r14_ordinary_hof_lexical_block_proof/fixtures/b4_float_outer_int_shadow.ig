-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen b4_float_outer_int_shadow
-- Float element, then-branch let shadows it with an INTEGER: outer r > 10.5 is stdlib.float.gt, inner r > 2 is stdlib.integer.gt. -> 2.
module R14.B4

pure contract O {
  input xs : Collection[Float]

  compute total : Integer = fold(xs, 0, (acc, r) -> if r > 10.5 { let r = 5
      if r > 2 { acc + 1 } else { acc } } else { acc })

  output total : Integer
}

observed contract S {
  input device_id: String
  stream readings: Float

  window "r14/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }

  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> if r > 10.5 { let r = 5
      if r > 2 { acc + 1 } else { acc } } else { acc }) @window_bounded

  output total: Integer
}
