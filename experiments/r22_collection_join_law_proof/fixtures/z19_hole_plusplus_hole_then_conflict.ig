-- REVIEW-1-RECHECK2 probe z19: `++` of two holes, then a conflicting grouping
module R22Recheck2.Z19
pure contract O {
  input seed : Integer
  compute a = map([], x -> map([], y -> x ++ y))
  compute b = concat(a, [["s"]])
  compute c = concat(b, [[1]])
  compute o : Integer = seed
  output o : Integer
}
