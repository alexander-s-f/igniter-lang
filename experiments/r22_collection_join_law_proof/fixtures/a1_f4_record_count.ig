module R22A1.F4b
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
  compute invalid = count(rec)
  compute o : Integer = seed
  output o : Integer
}
