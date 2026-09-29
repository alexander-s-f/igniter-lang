module R22A1.F4aa
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
  compute m : Map[String, Integer] = { x: seed }
  compute n : Map[String, Unknown] = { x: seed, y: "s" }
  compute o : Integer = seed
  output o : Integer
}
