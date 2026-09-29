module R22A1.F1h
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
  input m : M
  compute r = match m {
    Raw { n } => n
    Off {} => 0
  }
  compute o : Integer = seed
  output o : Integer
}
