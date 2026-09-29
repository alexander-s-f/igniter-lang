-- REVIEW probe p06c: control - the same chain through a DECLARED-open input (grouping loss is lawful here)
module R22Review.P06c
pure contract O {
  input seed : Integer
  input u : Collection[Unknown]
  compute c = concat(u, ["s"])
  compute e = concat(c, [1])
  compute o : Integer = seed
  output o : Integer
}
