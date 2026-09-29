module A1R.r3unresolvedsymboloperands
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
  compute k1 : Integer = nope1
  compute k2 = concat(nope2, [1])
  compute k3 : Integer = "${nope3}b"
  compute k4 = nope4 + "s"
  compute k5 = map(nope5, v -> v ++ 1)
  compute k6 = count(nope6)
  compute result = seed
  output result : Integer
}
