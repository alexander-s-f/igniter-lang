-- REVIEW probe p06b: concat of an UNTYPED carrier, then a conflicting concat
module R22Review.P06b
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
  compute c = concat(r, ["s"])
  compute e = concat(c, [1])
  compute o : Integer = seed
  output o : Integer
}
