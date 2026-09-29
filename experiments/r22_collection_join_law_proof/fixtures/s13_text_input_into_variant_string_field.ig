-- REVIEW-1-RECHECK3 probe s13: a Text value into a variant field declared String (control for s07)
module R22Recheck3.S13
variant V {
  Box { s : String }
}
pure contract O {
  input seed : Integer
  input t : Text
  compute a = Box { s: t }
  compute o : Integer = seed
  output o : Integer
}
