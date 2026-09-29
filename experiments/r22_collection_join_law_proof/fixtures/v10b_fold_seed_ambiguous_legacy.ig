-- REVIEW-1-VERIFY probe v10b_fold_seed_ambiguous_legacy
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
  compute t : P = fold(xs, { x: 0 }, (acc, v) -> { x: acc.x + v })
  compute o : Integer = seed
  output o : Integer
}
