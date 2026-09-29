module R22A1.D2
variant M {
  Raw { n : Integer }
  Off {}
}
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute r = call_contract(name, xs)
  compute a = map(r, v -> 1 + "a")
  compute b = concat(a, [1])
  compute o : Integer = seed
  output o : Integer
}
