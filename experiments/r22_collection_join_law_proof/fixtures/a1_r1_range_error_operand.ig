module A1R.r1rangeerroroperand
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
  compute k : Text = range(call_contract(name, xs), 2)
  compute result = seed
  output result : Integer
}
