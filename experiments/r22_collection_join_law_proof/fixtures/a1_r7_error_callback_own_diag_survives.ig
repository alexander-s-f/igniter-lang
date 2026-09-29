module A1R.r7errorcallbackowndiagsurvives
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
  compute a = filter(call_contract(name, xs), c -> 1 ++ 2)
  compute b = map(call_contract(name, xs), v -> nosuch(v))
  compute result = seed
  output result : Integer
}
