module A2.c2reportingcallsadmittedcontrols
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
  compute a = [int_to_text(seed), "s"]
  compute b = unwrap_or(some(int_to_text(seed)), "s")
  compute c = [contains(name, "a"), true]
  compute d = [modulo(seed, 2), seed]
  compute e = [decimal(150, 2), decimal(1, 2)]
  compute f = [twice(seed), seed]
  compute g = [call_contract("One", seed), seed]
  compute h = count(map(xs, v -> v + 1))
  compute result = seed
  output result : Integer
}
