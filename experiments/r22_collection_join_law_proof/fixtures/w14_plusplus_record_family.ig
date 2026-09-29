-- REVIEW-1-VERIFY probe w14_plusplus_record_family
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute a = { a: 1 } ++ ["s"]
  compute b = a ++ [1]
  compute o : Integer = seed
  output o : Integer
}
