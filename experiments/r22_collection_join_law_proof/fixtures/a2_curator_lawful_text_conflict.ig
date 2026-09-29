module Curator.LawfulTextConflict
pure contract T {
  input seed : Integer
  compute text = int_to_text(seed)
  compute values = [text, seed]
  output seed : Integer
}
