observed contract StreamExecP2 {
  input device_id: String
  stream readings: Integer

  window "thermal/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }

  compute total: Integer =
    fold_stream(readings, 0, (acc, r) ->
      if r > 10 {
        acc + r
      } else {
        acc
      }) @window_bounded

  output total: Integer
}
