module A2.r1sinkgrowthsweepn04
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
  compute f1 = fold(xs, [], (acc, v) -> {
    let bad = 1 + "a"
    append(acc, "s")
  })
  compute f2 = fold(xs, [], (acc, v) -> {
    let bad = 1 + "a"
    append(acc, "s")
  })
  compute f3 = fold(xs, [], (acc, v) -> {
    let bad = 1 + "a"
    append(acc, "s")
  })
  compute f4 = fold(xs, [], (acc, v) -> {
    let bad = 1 + "a"
    append(acc, "s")
  })
  compute fz = fold(xs, [], (acc, v) -> {
    let bad = 1 + "a"
    append(acc, "s")
  })
  compute cz = concat(fz, [1])
  compute result = seed
  output result : Integer
}
