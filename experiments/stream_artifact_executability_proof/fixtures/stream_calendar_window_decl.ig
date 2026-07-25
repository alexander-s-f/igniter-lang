observed contract StreamCalendarWindow {
  input device_id: String
  stream readings: Integer

  window "daily/{device_id}" {
    kind: :calendar,
    period: :day,
    on_close: :snapshot
  }

  compute total: Integer =
    fold_stream(readings, 0, (acc, r) -> acc + r) @window_bounded

  output total: Integer
}
