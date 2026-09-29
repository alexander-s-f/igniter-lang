module R22A1.F2m
observed contract S {
  input device_id: String
  stream readings: Float
  window "r22/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }
  compute total =
    fold_stream(readings, [], (acc, r) -> append(acc, "x")) @window_bounded
  compute d : Collection[Float] = total
  output d: Collection[Float]
}
variant M {
  Raw { n : Integer }
  Off {}
}
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input fs : Collection[Float]
  input cfg : Map[String, Unknown]
  input opens : Collection[Unknown]
  input sm : Map[String, Integer]
  input name : String
  compute o : Integer = seed
  output o : Integer
}
