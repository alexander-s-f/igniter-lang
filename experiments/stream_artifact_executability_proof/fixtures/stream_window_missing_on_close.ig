observed contract StreamWindowMissingOnClose {
  input device_id: String
  stream readings: Integer

  window "thermal/{device_id}" {
    kind: :count,
    size: 3
  }

  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> acc + r) @window_bounded

  output total: Integer
}
