module Curator.R22
pure contract Test {
  input seed : Integer
  compute invalid = [seed, "a"]
  compute result = seed
  output result : Integer
}
