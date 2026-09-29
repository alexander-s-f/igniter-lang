-- REVIEW probe p07c: nested array literal at an annotated compute Collection[Collection[Integer]]
module R22Review.P07c
pure contract O {
  input seed : Integer
  compute a : Collection[Collection[Integer]] = [["a"]]
  compute o : Integer = seed
  output o : Integer
}
