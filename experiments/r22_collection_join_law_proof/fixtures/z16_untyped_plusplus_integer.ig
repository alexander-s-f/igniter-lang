-- REVIEW-1-RECHECK2 probe z16: `++` of an untyped value with an Integer operand
module R22Recheck2.Z16
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute r = call_contract(name, xs)
  compute a = r ++ 1
  compute b = [a, "s"]
  compute c = [a, 1]
  compute o : Integer = seed
  output o : Integer
}
