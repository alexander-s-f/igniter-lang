-- REVIEW probe p13: an unnamed record family (a KNOWN family) where a stdlib Collection argument is expected
module R22Review.P13
pure contract O {
  input seed : Integer
  compute n = count({ a: 1 })
  compute m = map({ a: 1 }, v -> v)
  compute c = concat({ a: 1 }, [1])
  compute o : Integer = seed
  output o : Integer
}
