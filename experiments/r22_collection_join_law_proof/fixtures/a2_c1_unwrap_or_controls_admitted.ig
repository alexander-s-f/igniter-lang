module A2.c1unwraporcontrolsadmitted
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
  compute a = unwrap_or(some(seed), 1)
  compute b = unwrap_or(none(), 1)
  compute c = unwrap_or(declared, 1)
  compute d = unwrap_or(rr, 1)
  compute e = unwrap_or(open, 1)
  compute f = unwrap_or(map_get(cfg, "k"), 1)
  compute g = unwrap_or(at(xs, 0), 1)
  compute h = unwrap_or(some({ x: seed }), { x: 1 })
  compute i = unwrap_or(first(xs), 1)
  compute result = seed
  output result : Integer
}
