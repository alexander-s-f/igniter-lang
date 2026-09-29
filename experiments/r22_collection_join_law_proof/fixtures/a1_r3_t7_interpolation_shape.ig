module A1R.r3t7interpolationshape
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
  compute line : Text = "${nope}b${int_to_text(seed)}c"
  compute result = seed
  output result : Integer
}
