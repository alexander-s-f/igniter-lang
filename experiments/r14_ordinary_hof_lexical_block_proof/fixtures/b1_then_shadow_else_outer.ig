-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen b1_then_shadow_else_outer
-- then-branch let shadows r (3.0); the ELSE branch reads the OUTER r. [1.0,11.0,21.0] -> 7.0 (dropped let: 33.0).
module R14.B1

pure contract O {
  input xs : Collection[Float]

  compute total : Float = fold(xs, 0.0, (acc, r) -> if r > 10.5 { let r = 3.0
      acc + r } else { acc + r })

  output total : Float
}

observed contract S {
  input device_id: String
  stream readings: Float

  window "r14/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }

  compute total: Float =
    fold_stream(readings, 0.0, (acc, r) -> if r > 10.5 { let r = 3.0
      acc + r } else { acc + r }) @window_bounded

  output total: Float
}
