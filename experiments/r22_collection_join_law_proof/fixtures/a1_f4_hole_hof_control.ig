module R22A1.F4y
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
  compute m = map([], v -> v)
  compute c = count([])
  compute s = sum([])
  compute o : Integer = seed
  output o : Integer
}
