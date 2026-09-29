module R22A1.Cfs
observed contract S {
  input device_id: String
  input name : String
  input xs : Collection[Float]
  stream readings: Float
  window "r22/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }
  compute r = call_contract(name, xs)
  compute total: Collection[Float] =
    fold_stream(readings, r, (acc, x) -> append(acc, x)) @window_bounded
  output total: Collection[Float]
}
