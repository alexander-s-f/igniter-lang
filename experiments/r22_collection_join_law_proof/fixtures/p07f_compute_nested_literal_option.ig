-- REVIEW probe p07f: an Option member against Collection[Option[Integer]] (non-literal member, known misfit)
module R22Review.P07f
pure contract O {
  input seed : Integer
  compute a : Collection[Option[Integer]] = [some("a")]
  compute o : Integer = seed
  output o : Integer
}
