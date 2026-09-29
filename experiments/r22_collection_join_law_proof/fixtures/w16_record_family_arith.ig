-- REVIEW-1-VERIFY probe w16_record_family_arith
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute a = { a: 1 } + 1
  compute o : Integer = seed
  output o : Integer
}
