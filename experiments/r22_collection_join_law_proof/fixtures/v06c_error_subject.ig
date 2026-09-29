-- REVIEW-1-VERIFY probe v06c_error_subject
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
  compute r = match 1 + "a" {
    Off {} => 1
    _ => 2
  }
  compute o : Integer = seed
  output o : Integer
}
