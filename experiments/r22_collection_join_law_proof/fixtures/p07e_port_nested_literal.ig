-- REVIEW probe p07e: nested array literal behind a same-named output port Collection[Collection[Integer]]
module R22Review.P07e
pure contract O {
  input seed : Integer
  compute a = [["a"]]
  output a : Collection[Collection[Integer]]
}
