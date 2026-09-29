module R22A1.F1g
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
  compute bad = 1 + "a"
  compute r = match bad {
    Off {} => 1
    _ => 2
  }
  compute o : Integer = seed
  output o : Integer
}
