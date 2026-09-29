module R22A1.F1c
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
  compute open = unwrap_or(map_get(cfg, "x"), 0)
  compute r = match open {
    Off {} => [1]
    _ => ["a"]
  }
  compute z = concat(r, [true])
  compute o : Integer = seed
  output o : Integer
}
