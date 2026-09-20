-- LANG-CALLABLE-COMPATIBILITY-AND-BINDER-PROOF-REPAIR-R12 specimen r12_empty_carrier_neg
-- Empty carrier with a NEGATION of the bound-but-unknown element: no invented type, permissive stdlib.integer.neg on both; body never executes: value 0.
module R12.EmptyNeg

observed contract S {
  input device_id: String
  stream readings: Float

  window "r12/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }
  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> acc + fold([], 0, (a, v) -> if -v > 10 { a + 1 } else { a })) @window_bounded

  output total: Integer
}
