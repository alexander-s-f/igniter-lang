module A2.c2reportingcallinlinecompositions
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
  compute a = [int_to_text("s"), seed]
  compute b = unwrap_or(some(int_to_text("s")), seed)
  compute c = if seed > 0 { int_to_text("s") } else { seed }
  compute d : Integer = int_to_text("s")
  compute e = int_to_text("s") + 1
  compute f = concat([int_to_text("s")], xs)
  compute g = count(int_to_text("s"))
  compute h = match Raw { n: int_to_text("s") } {
    Raw { n } => n
    Nil {} => 0
  }
  compute result = seed
  output result : Integer
}
