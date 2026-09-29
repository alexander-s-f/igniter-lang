-- REVIEW-1-VERIFY probe v08c_untyped_map_put_chain
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
  compute a = map_put(r, "k", 1)
  compute b = map_put(a, "j", "s")
  compute o : Integer = seed
  output o : Integer
}
