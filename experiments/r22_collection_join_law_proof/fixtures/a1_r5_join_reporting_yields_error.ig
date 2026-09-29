module A1R.r5joinreportingyieldserror
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
  compute u : Integer = join({ x: "a" }, ",")
  compute v = join({ x: "a" }, ",") + 1
  compute y : Integer = join("a", ",")
  compute result = seed
  output result : Integer
}
