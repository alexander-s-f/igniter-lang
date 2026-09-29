-- REVIEW probe p13b: a match over an unnamed record family subject (not a variant) with arms that do not join
module R22Review.P13b
variant M {
  Raw { n : Integer }
  Off {}
}
pure contract O {
  input seed : Integer
  compute rec = { a: 1 }
  compute r = match rec {
    Off {} => [1]
    _ => ["a"]
  }
  compute o : Integer = seed
  output o : Integer
}
