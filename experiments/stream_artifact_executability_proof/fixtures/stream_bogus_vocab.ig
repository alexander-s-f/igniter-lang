observed contract StreamExecP2BogusVocab {
  input device_id: String
  stream readings: Integer

  window "thermal/{device_id}" {
    kind: :bogus,
    size: 3,
    on_close: :bogus
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
