module A2.r8joinnesteddiagnosticinargumentkeepsthefamily
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
  compute j = join(map(xs, v -> {
    let bad = 1 + "a"
    int_to_text(v)
  }), ",")
  compute c = [j, seed]
  compute result = seed
  output result : Integer
}
