module R22A1.F4z
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
  compute g = map_get({ x: seed }, "x")
  compute p = map_put({ x: seed }, "y", 2)
  compute h = map_has_key({ x: seed }, "x")
  compute o : Integer = seed
  output o : Integer
}
