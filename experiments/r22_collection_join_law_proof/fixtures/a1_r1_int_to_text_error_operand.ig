module A1R.r1inttotexterroroperand
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
  compute k : Integer = int_to_text(call_contract(name, xs))
  compute result = seed
  output result : Integer
}
