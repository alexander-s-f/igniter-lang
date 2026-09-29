module R22A1.D1
variant M {
  Raw { n : Integer }
  Off {}
}
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute r = call_contract(name, xs)
  compute a = filter(r, c -> Unresolved(c) == 0)
  compute o : Integer = seed
  output o : Integer
}
