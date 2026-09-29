-- REVIEW probe p01c: un-hinted record literals inside a record-annotated compute become open (legacy node hint),
-- hiding a collection literal with no join
module R22Review.P01c
type Point { x : Integer, y : Integer }
pure contract O {
  input seed : Integer
  compute p : Point = { x: count([{ a: 1 }, { a: "s" }]), y: 2 }
  compute o : Integer = p.x
  output o : Integer
}
