module Curator.RefusedTextOptionJoin
pure contract T {
  input seed : Integer
  compute bad = int_to_text("not an integer")
  compute value = unwrap_or(some(bad), seed)
  output seed : Integer
}
