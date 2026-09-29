module A1R.r7opencontrolsadmitted
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
  compute a = join(opens, ",")
  compute b = concat("a", open)
  compute c = and_then(open, v -> ok(v))
  compute d = map_from_pairs(opens)
  compute e = is_some(open)
  compute f = join([], ",")
  compute g = concat("a", "b")
  compute h = join(["a"], ",")
  compute result = seed
  output result : Integer
}
