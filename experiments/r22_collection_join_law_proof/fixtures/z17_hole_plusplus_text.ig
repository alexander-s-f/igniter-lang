-- REVIEW-1-RECHECK2 probe z17: `++` of a hole with a Text operand (String and Text are one scalar)
module R22Recheck2.Z17
pure contract O {
  input seed : Integer
  input t : Text
  compute a = map([], x -> x ++ t)
  compute b = concat(a, [1])
  compute o : Integer = seed
  output o : Integer
}
