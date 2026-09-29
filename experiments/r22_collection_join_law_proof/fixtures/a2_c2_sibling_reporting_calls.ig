module A2.c2siblingreportingcalls
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
  compute a = [contains(1, "a"), seed]
  compute b = [trim(1), seed]
  compute c = [modulo("a", 2), seed]
  compute d = [parse_int(1), seed]
  compute e = [decimal("x", 2), seed]
  compute f = [split(name, 1), seed]
  compute g = [twice("s"), seed]
  compute h = [call_contract("One", "s"), seed]
  compute i = [some(1, 2), seed]
  compute j = [split(1, ","), seed]
  compute result = seed
  output result : Integer
}
