-- LANG-ORDINARY-HOF-LEXICAL-BLOCK-LOWERING-IMPLEMENTATION-R14 specimen n2_capture_block_let
-- the nested lambda CAPTURES the block-local let r (r + 1.0), not the outer parameter. -> 34.0 (outer r captured: 32.0).
module R14.N2

pure contract O {
  input xs : Collection[Float]

  compute total : Float = fold(xs, 0.0, (acc, r) -> {
      let r = r + 1.0
      acc + fold([r], 0.0, (a, v) -> if v > 10.5 { a + r } else { a })
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
      let r = r + 1.0
      acc + fold([r], 0.0, (a, v) -> if v > 10.5 { a + r } else { a })
    }) @window_bounded

  output total: Float
}
