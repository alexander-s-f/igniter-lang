module R22A1.F2a
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
  compute unknown_result = call_contract(name, xs)
  compute inferred = concat(unknown_result, [1])
  compute o : Integer = seed
  output o : Integer
}
