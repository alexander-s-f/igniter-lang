-- REVIEW-1-RECHECK2 probe z01_collection_eq_open
module R22Recheck2.Z
type A { x : Integer }
type B { x : Integer }
pure contract O {
  input seed : Integer
  input xs : Collection[Integer]
  input cfg : Map[String, Unknown]
  compute b = [1] == unwrap_or(map_get(cfg, "k"), 0)
  compute o : Integer = seed
  output o : Integer
}
