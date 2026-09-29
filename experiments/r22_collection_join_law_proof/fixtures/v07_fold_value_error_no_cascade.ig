-- REVIEW-1-VERIFY probe v07_fold_value_error_no_cascade
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
  compute c = fold(xs, 0, (acc, v) -> acc + "a")
  compute d : String = c
  compute e = [c, "s"]
  compute o : Integer = seed
  output o : Integer
}
