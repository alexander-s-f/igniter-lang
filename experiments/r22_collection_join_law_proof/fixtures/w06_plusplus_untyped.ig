-- REVIEW-1-VERIFY probe w06_plusplus_untyped
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute r = call_contract(name, xs)
  compute a = r ++ ["s"]
  compute b = a ++ [1]
  compute o : Integer = seed
  output o : Integer
}
