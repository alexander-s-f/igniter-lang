-- REVIEW probe p06: the HOF element of an UNTYPED carrier (Tier-2 call_contract) becomes declared openness
module R22Review.P06
contract Callee {
  input a : Collection[Integer]
  compute m = a
  output m : Collection[Integer]
}
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute r = call_contract(name, xs)
  compute m = map(r, x -> x)
  compute c = concat(m, ["s"])
  compute e = concat(c, [1])
  compute o : Integer = seed
  output o : Integer
}
