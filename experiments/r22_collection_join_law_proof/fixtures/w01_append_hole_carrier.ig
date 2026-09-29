-- REVIEW-1-VERIFY probe w01_append_hole_carrier
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute a = map([], x -> append(x, "s"))
  compute b = concat(a, [[1]])
  compute o : Integer = seed
  output o : Integer
}
