-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen c1_fresh_block_let
-- RESIDUAL (classifier, not an authorized owner): a FRESH-named lambda-block let is refused OOF-P1 by BOTH classifiers on the ordinary route.
module R14.C1

pure contract O {
  input xs : Collection[Float]

  compute total : Float = fold(xs, 0.0, (acc, r) -> {
      let d = r * 2.0
      acc + d
    })

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
    fold_stream(readings, 0.0, (acc, r) -> {
      let d = r * 2.0
      acc + d
    }) @window_bounded

  output total: Float
}
