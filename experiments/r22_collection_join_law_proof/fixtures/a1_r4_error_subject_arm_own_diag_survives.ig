module A1R.r4errorsubjectarmowndiagsurvives
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
  compute m = Raw { n: call_contract(name, xs) }
  compute k = match m {
    Raw { n } => 1 ++ 2
    Nil {} => 0
  }
  compute result = seed
  output result : Integer
}
