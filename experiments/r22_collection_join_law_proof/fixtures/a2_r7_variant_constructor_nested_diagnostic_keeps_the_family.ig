module A2.r7variantconstructornesteddiagnostickeepsthefamily
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
  compute m = Raw { n: count(map(xs, v -> {
    let bad = 1 + "a"
    v
  })) }
  compute c = [m, "s"]
  compute result = seed
  output result : Integer
}
