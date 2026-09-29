-- REVIEW-1-VERIFY probe w03_set_at_untyped
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute r = call_contract(name, xs)
  compute a = set_at(r, 0, "s")
  compute b = concat(unwrap_or(a, []), [1])
  compute o : Integer = seed
  output o : Integer
}
