module R22A1.F1f
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
  compute r = match seed {
    Off {} => 0
    _ => 1
  }
  compute o : Integer = seed
  output o : Integer
}
