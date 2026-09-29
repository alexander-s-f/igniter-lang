-- REVIEW-1-VERIFY probe w01b_append_hole_control
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute a = map([], x -> append([], "s"))
  compute b = concat(a, [[1]])
  compute o : Integer = seed
  output o : Integer
}
