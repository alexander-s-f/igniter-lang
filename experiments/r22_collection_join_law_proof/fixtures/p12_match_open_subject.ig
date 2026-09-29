-- REVIEW probe p12: a match whose subject is declared-open (ch3 3.3b: declared openness is not a variant)
module R22Review.P12
variant M {
  Raw { n : Integer }
  Off {}
}
pure contract O {
  input seed : Integer
  input cfg : Map[String, Unknown]
  compute v = unwrap_or(map_get(cfg, "a"), 0)
  compute r = match v {
    Off {} => [1]
    _ => ["a"]
  }
  compute z = concat(r, [true])
  compute o : Integer = seed
  output o : Integer
}
