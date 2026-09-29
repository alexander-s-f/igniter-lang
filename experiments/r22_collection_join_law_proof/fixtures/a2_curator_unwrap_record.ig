module Curator.UnwrapRecord
pure contract T {
  input seed : Integer
  compute rec = { x: seed }
  compute value = unwrap_or(rec, 1)
  output value : Integer
}
