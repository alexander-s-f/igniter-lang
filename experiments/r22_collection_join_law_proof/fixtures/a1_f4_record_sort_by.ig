module R22A1.F4h
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
  compute rec = { x: seed }
  compute invalid = sort_by(rec, v -> 1)
  compute o : Integer = seed
  output o : Integer
}
