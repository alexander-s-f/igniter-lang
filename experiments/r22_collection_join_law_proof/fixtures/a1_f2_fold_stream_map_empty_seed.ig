module R22A1.F2l
observed contract S {
  input device_id: String
  stream readings: Float
  window "r22/{device_id}" {
    kind: :count,
    size: 3,
    on_close: :snapshot
  }
  compute total: Map[String, Float] =
    fold_stream(readings, map_empty(), (acc, r) -> map_put(acc, "k", "x")) @window_bounded
  output total: Map[String, Float]
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
