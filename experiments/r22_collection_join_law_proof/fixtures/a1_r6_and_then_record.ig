module A1R.r6andthenrecord
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
  compute r = and_then({ x: seed }, v -> ok(v))
  compute result = seed
  output result : Integer
}
