-- R10 design probe s3_nested_float_param_ordering: nested lambda Float param ordering; opaque by the shared law -> integer identity -> refusal
-- R10 declared regression: nested lambda params are opaque -> stdlib.integer.gt -> refusal 'stdlib.integer.gt expects' on both B frontends; legacy v1 raw '>' closed 2.
module R10.D2.S3

observed contract S {
  input device_id: String
  stream readings: Float

  window "r10/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }

  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> acc + fold([r], 0, (a, v) -> if v > 10.5 { a + 1 } else { a })) @window_bounded

  output total: Integer
}
