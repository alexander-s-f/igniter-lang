-- REVIEW-1-VERIFY probe w11_plusplus_hole_carrier
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute a = map([], x -> x ++ ["s"])
  compute b = concat(a, [[1]])
  compute o : Integer = seed
  output o : Integer
}
