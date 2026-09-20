-- LANG-CALLABLE-LEXICAL-TYPE-EVIDENCE-READINESS-R11 specimen e1_empty_carrier_s (stream only)
-- INSUFFICIENT evidence, declared before runs: the nested carrier is the empty literal [], so v has no element evidence on either frontend.
-- Both keep the ordinary permissive integer-named identity; the body never executes; result 0 (seed). Recorded as unresolved evidence, not a claim.
module R11.E1S

observed contract S {
  input device_id: String
  stream readings: Float

  window "r11/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }

  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> acc + fold([], 0, (a, v) -> if v > 10.5 { a + 1 } else { a })) @window_bounded

  output total: Integer
}
