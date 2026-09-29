-- REVIEW probe p01: a record literal in an un-hinted position inside a record-annotated compute
module R22Review.P01
type Point { x : Integer, y : Integer }
pure contract O {
  input seed : Integer
  compute p : Point = { x: unwrap_or(map_get({ a: 1, b: "s" }, "a"), 0), y: 2 }
  compute o : Integer = p.x
  output o : Integer
}
