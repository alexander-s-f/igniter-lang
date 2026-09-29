-- REVIEW-1-VERIFY probe v02_legacy_hint_suppresses_ambiguity
module R22Verify.X
type Point { x : Integer, y : Integer }
type P { x : Integer }
type Q { x : Integer }
variant M {
  Raw { n : Integer }
  Off {}
}
variant V {
  Box { xss : Collection[Collection[Integer]] }
}
pure contract O {
  input seed : Integer
  input m : M
  input xs : Collection[Integer]
  input opens : Collection[Unknown]
  input cfg : Map[String, Unknown]
  input name : String
  compute p : P = { x: count([{ x: 1 }]) }
  compute o : Integer = seed
  output o : Integer
}
