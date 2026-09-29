module R22A1.F4ac
type Box { xs : Collection[Integer] }
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
  compute b : Box = { xs: [seed] }
  compute c = count(b.xs)
  compute m = map(b.xs, v -> v + 1)
  compute o : Integer = seed
  output o : Integer
}
