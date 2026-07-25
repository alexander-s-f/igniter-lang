observed contract StreamWindowExtraKey {
  input device_id: String
  stream readings: Integer

  window "thermal/{device_id}" {
    kind: :count,
    size: 3,
    flavor: :spicy,
    on_close: :snapshot
  }

  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> acc + r) @window_bounded

  output total: Integer
}
