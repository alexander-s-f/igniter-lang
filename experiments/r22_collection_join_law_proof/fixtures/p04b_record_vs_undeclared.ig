-- REVIEW probe p04b: a record literal written at an undeclared-name annotation
module R22Review.P04b
pure contract O {
  input seed : Integer
  compute e : Nope = { message: "x" }
  compute o : Integer = seed
  output o : Integer
}
