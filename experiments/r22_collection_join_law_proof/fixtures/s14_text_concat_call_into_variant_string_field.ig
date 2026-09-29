-- REVIEW-1-RECHECK3 probe s14: concat(String, Text) (stdlib text path) into a variant field declared String
module R22Recheck3.S14
variant V {
  Box { s : String }
}
pure contract O {
  input seed : Integer
  input t : Text
  compute a = Box { s: concat("a", t) }
  compute o : Integer = seed
  output o : Integer
}
