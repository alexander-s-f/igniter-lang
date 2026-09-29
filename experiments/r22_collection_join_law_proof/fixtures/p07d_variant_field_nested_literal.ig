-- REVIEW probe p07d: nested array literal in a variant field declared Collection[Collection[Integer]]
module R22Review.P07d
variant V {
  Box { xss : Collection[Collection[Integer]] }
}
pure contract O {
  input seed : Integer
  compute v = Box { xss: [["a"]] }
  compute o : Integer = seed
  output o : Integer
}
