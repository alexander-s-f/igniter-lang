-- reviewer s06: STREAM route control — an INPUT spelled __seq__ read after a bare statement in the fold_stream callable.
-- events [1,2], __seq__=100 : lawful 203 ; smuggled 9
module RVW.S06

def twice(a: Integer) -> Integer {
  a * 2
}

observed contract S {
  input device_id: String
  input __seq__ : Integer
  stream readings: Integer

  window "rvw/{device_id}" {
    kind: :count,
    size: 2,
    on_close: :snapshot
  }

  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> {
      twice(r)
      acc + r + __seq__
    }) @window_bounded

  output total: Integer
}
