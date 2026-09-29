-- REVIEW probe p04: a record literal written at an IoError-annotated compute
module R22Review.P04
pure contract O {
  input seed : Integer
  compute e : IoError = { message: "x" }
  compute o : Integer = seed
  output o : Integer
}
