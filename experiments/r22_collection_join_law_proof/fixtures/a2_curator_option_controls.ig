module Curator.OptionControls
pure contract T {
  input seed : Integer
  input declared : Option[Unknown]
  compute present = unwrap_or(some(seed), 1)
  compute absent = unwrap_or(none(), 1)
  compute fallback = or_else(some(seed), 1)
  compute open = unwrap_or(declared, 1)
  compute value = present + absent + fallback
  output value : Integer
}
