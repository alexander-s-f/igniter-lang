module Curator.R22
pure contract Test {
  input cfg : Map[String, Unknown]
  compute open = unwrap_or(map_get(cfg, "x"), 0)
  compute bad = open && 1
  compute result = 1
  output result : Integer
}
