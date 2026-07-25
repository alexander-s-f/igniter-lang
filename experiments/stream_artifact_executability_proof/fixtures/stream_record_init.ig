type Totals {
  sum : Integer,
  count : Integer
}

observed contract StreamExecP2 {
  input device_id: String
  stream readings: Integer

  window "thermal/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }

  compute totals: Totals =
    fold_stream(readings, { sum: 0, count: 0 }, (acc, r) ->
      if r > 10 {
        { sum: acc.sum + r, count: acc.count + 1 }
      } else {
        acc
      }) @window_bounded

  output totals: Totals
}
