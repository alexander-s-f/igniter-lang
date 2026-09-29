-- REVIEW probe q09d_fold_body_conflict_plus_unused_bad
module R22Review.X09d
type P { x : Integer }
type Q { x : Integer, y : Integer }
variant M {
  Raw { n : Integer }
  Mid { s : String }
  Off {}
}
pure contract O {
  input seed : Integer
  input m : M
  input xs : Collection[Integer]
  input opens : Collection[Unknown]
  input cfg : Map[String, Unknown]
  input km : Map[Unknown, Integer]
  input sm : Map[String, Integer]
  compute c = fold(xs, [], (acc, v) -> {
    let bad = 1 + "a"
    append(acc, "s")
  })
  compute d = concat(c, [1])
  compute o : Integer = seed
  output o : Integer
}
