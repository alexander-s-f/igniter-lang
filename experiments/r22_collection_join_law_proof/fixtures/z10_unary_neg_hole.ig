-- REVIEW-1-RECHECK2 probe z10_unary_neg_hole
module R22Recheck2.Z
type A { x : Integer }
type B { x : Integer }
type Only { z : Integer }
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input cfg : Map[String, Unknown]
  compute a = map([], x -> -x)
  compute b = concat(a, ["s"])
  compute o : Integer = seed
  output o : Integer
}
