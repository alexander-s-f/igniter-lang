module Curator.OptionScalar
pure contract T {
  input seed : Integer
  compute value = unwrap_or(seed, 1)
  output value : Integer
}
