module Curator.RefusedTextOrigin
pure contract T {
  input seed : Integer
  compute bad = int_to_text("not an integer")
  output seed : Integer
}
