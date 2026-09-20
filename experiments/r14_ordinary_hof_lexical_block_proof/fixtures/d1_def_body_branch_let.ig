-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen d1_def_body_branch_let
-- ADDED AFTER THE PIN (the corpus map showed a def body shares the branch selection site): a def body's branch-local let. [1,11,21] -> 67 (dropped let: 35).
module R14.D1

def bump(a: Integer) -> Integer {
  if a > 10 { let a = a * 2
    a + 1 } else { a }
}

pure contract O {
  input xs : Collection[Integer]

  compute total : Integer = fold(xs, 0, (acc, r) -> acc + bump(r))

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
    fold_stream(readings, 0, (acc, r) -> acc + bump(r)) @window_bounded

  output total: Integer
}
