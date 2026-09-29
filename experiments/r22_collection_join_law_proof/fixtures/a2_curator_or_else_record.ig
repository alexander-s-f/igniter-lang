module Curator.OrElseRecord
pure contract T {
  input seed : Integer
  compute rec = { x: seed }
  compute value = or_else(rec, 1)
  output value : Integer
}
