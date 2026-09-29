module R22A1.F2i
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
  compute v = unwrap_or(map_get(cfg, "x"), 0)
  compute w = concat(opens, [1])
  compute u : Collection[Unknown] = [1, "a"]
  compute o : Integer = seed
  output o : Integer
}
