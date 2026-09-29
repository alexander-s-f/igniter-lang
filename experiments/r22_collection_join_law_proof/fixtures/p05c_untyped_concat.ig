-- REVIEW probe p05c: concat / append on a Tier-2 call_contract result
module R22Review.P05c
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
  compute d = append(r, "s")
  compute e = concat(c, [1])
  compute o : Integer = seed
  output o : Integer
}
