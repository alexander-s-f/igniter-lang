-- REVIEW-1-RECHECK2 probe z11_hole_plusplus_integer
module R22Recheck2.Z
type A { x : Integer }
type B { x : Integer }
type Only { z : Integer }
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input cfg : Map[String, Unknown]
  compute a = map([], x -> x ++ 1)
  compute o : Integer = seed
  output o : Integer
}
