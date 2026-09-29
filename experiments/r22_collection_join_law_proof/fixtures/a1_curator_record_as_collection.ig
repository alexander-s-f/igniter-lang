module Curator.R22
pure contract Test {
  input seed : Integer
  compute invalid = map({x: seed}, v -> v)
  compute result = seed
  output result : Integer
}
