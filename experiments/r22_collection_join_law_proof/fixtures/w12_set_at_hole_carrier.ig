-- REVIEW-1-VERIFY probe w12_set_at_hole_carrier
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute a = map([], x -> unwrap_or(set_at(x, 0, "s"), []))
  compute b = concat(a, [[1]])
  compute o : Integer = seed
  output o : Integer
}
