module A1R.r2unknownfunctionoperands
variant M {
  Raw { n : Integer }
  Nil {}
}
pure contract T {
  input cfg : Map[String, Unknown]
  input opens : Collection[Unknown]
  input xs : Collection[Integer]
  input name : String
  input seed : Integer
  compute open = unwrap_or(map_get(cfg, "x"), 0)
  compute k1 : Integer = nosuch1(seed)
  compute k2 = nosuch2(seed) ++ 1
  compute k3 = nosuch3(seed) + "s"
  compute k4 = map(nosuch4(seed), v -> v ++ 1)
  compute k5 = concat(nosuch5(seed), [1])
  compute k6 = count(nosuch6(seed))
  compute result = seed
  output result : Integer
}
