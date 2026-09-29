-- REVIEW probe p02: a lambda parameter bound to a hole element, used as a HOF carrier
module R22Review.P02
pure contract O {
  input seed : Integer
  compute b = map([], x -> map(x, y -> y))
  compute c = concat(b, [["s"]])
  compute d = concat(c, [[1]])
  compute o : Integer = count(d)
  output o : Integer
}
