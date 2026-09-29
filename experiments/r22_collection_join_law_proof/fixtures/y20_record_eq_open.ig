-- REVIEW-1-RECHECK2 probe y20_record_eq_open
module R22Recheck2.X
type Point { x : Integer, y : Integer }
type A { x : Integer }
type B { x : Integer }
type Only { z : Integer }
type Outer { inner : A }
type Tot { total : Integer }
variant V {
  Box { a : A }
}
variant M {
  Raw { n : Integer }
  Off {}
}
def mk(n: Integer) -> A {
  { x: n }
}
def fa(a: A) -> Integer {
  a.x
}
contract Callee {
  input a : A
  compute r = a.x
  output r : Integer
}
pure contract O {
  input seed : Integer
  input flag : Bool
  input m : M
  input xs : Collection[Integer]
  input cfg : Map[String, Unknown]
  input name : String
  input p0 : Point
  compute b = { a: 1 } == unwrap_or(map_get(cfg, "k"), 0)
  compute o : Integer = seed
  output o : Integer
}
