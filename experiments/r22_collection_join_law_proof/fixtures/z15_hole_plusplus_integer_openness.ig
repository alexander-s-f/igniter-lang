-- REVIEW-1-RECHECK2 probe z15: `++` of a hole with an Integer operand (a family ++ does not accept)
module R22Recheck2.Z15
pure contract O {
  input seed : Integer
  compute a = map([], x -> x ++ 1)
  compute b = concat(a, ["s"])
  compute c = concat(b, [1])
  compute o : Integer = seed
  output o : Integer
}
