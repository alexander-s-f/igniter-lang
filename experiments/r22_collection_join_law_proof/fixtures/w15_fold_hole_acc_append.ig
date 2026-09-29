-- REVIEW-1-VERIFY probe w15_fold_hole_acc_append
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute a = map([], x -> fold(xs, x, (acc, v) -> append(acc, "s")))
  compute b = concat(a, [[1]])
  compute o : Integer = seed
  output o : Integer
}
