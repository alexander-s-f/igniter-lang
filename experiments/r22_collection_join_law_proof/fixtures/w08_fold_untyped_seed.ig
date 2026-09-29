-- REVIEW-1-VERIFY probe w08_fold_untyped_seed
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute r = call_contract(name, xs)
  compute a = fold(xs, r, (acc, v) -> append(acc, "s"))
  compute b = concat(a, [1])
  compute o : Integer = seed
  output o : Integer
}
