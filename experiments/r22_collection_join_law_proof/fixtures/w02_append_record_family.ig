-- REVIEW-1-VERIFY probe w02_append_record_family
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute a = append({ a: 1 }, "s")
  compute b = concat(a, [1])
  compute o : Integer = seed
  output o : Integer
}
