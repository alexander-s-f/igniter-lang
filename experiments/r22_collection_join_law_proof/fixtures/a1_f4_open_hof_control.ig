module R22A1.F4x
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
  compute m = map(opens, v -> v)
  compute c = count(opens)
  compute v = unwrap_or(map_get(cfg, "x"), [1])
  compute f = filter(v, w -> true)
  compute o : Integer = seed
  output o : Integer
}
