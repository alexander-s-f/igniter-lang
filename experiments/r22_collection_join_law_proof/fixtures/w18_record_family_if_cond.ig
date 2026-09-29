-- REVIEW-1-VERIFY probe w18_record_family_if_cond
module R22Verify.X
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input name : String
  compute a = if { a: 1 } { 1 } else { 2 }
  compute o : Integer = seed
  output o : Integer
}
