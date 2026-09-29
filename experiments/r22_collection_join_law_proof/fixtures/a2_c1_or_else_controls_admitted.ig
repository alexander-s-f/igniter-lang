module A2.c1orelsecontrolsadmitted
type P {
  px : Integer
}
variant M {
  Raw { n : Integer }
  Nil {}
}
def twice(a: Integer) -> Integer {
  a * 2
}
pure contract One {
  input a : Integer
  compute b = a
  output b : Integer
}
pure contract T {
  input cfg : Map[String, Unknown]
  input opens : Collection[Unknown]
  input xs : Collection[Integer]
  input declared : Option[Unknown]
  input rr : Result[Integer, String]
  input name : String
  input seed : Integer
  compute open = unwrap_or(map_get(cfg, "x"), 0)
  compute rec = { x: seed }
  compute a = or_else(some(seed), 1)
  compute b = or_else(none(), 1)
  compute c = or_else(declared, 1)
  compute d = or_else(rr, 1)
  compute e = or_else(open, 1)
  compute f = or_else(map_get(cfg, "k"), 1)
  compute g = or_else(at(xs, 0), 1)
  compute h = or_else(some({ x: seed }), { x: 1 })
  compute i = or_else(first(xs), 1)
  compute result = seed
  output result : Integer
}
