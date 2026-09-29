-- REVIEW probe p14: map_get over a hole-typed value (lambda parameter over []) yields a declared-open value
module R22Review.P14
pure contract O {
  input seed : Integer
  compute a = map([], m -> unwrap_or(map_get(m, "k"), 0))
  compute b = concat(a, ["s"])
  compute c = concat(b, [1])
  compute o : Integer = seed
  output o : Integer
}
