module Curator.RefusedTextCollection
pure contract T {
  input seed : Integer
  compute bad = int_to_text("not an integer")
  compute values = [bad, seed]
  output seed : Integer
}
