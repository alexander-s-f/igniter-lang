-- REVIEW-1-VERIFY probe v08d_untyped_element_join_known
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
  compute r = call_contract(name, xs)
  compute a = append(r, "s")
  compute b = concat(a, [1])
  compute o : Integer = seed
  output o : Integer
}
