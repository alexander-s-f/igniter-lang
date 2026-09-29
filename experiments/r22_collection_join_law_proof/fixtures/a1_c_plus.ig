module R22A1.Cplus
variant M {
  Raw { n : Integer }
  Off {}
}
type Pt { x : Integer }
def twice(a: Integer) -> Integer {
  a * 2
}
pure contract One {
  input a : Integer
  compute b = a
  output b : Integer
}
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  input m : M
  compute r = call_contract(name, xs)
  compute a = r + 1
  compute sink1 : Collection[String] = a
  compute sink2 = concat(a, [1])
  compute sink3 = a ++ "s"
  compute o : Integer = seed
  output o : Integer
}
