module R22A1.F2h
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
  compute e = []
  compute n = unwrap_or(none(), 1)
  compute m = map_empty()
  compute k = concat(e, [1])
  compute o : Integer = seed
  output o : Integer
}
