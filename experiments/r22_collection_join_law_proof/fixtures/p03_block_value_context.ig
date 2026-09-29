-- REVIEW probe p03: a block expression's value under a declared-open annotated compute (the written context
-- reaches the expression and its branches; a block's value is that expression)
module R22Review.P03
pure contract O {
  input seed : Integer
  compute ys : Collection[Unknown] = {
    let k = seed
    if k > 0 { [k, "a"] } else { [2] }
  }
  compute o : Integer = count(ys)
  output o : Integer
}
