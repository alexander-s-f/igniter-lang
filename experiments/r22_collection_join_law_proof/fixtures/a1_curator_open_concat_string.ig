module Curator.R22
pure contract Test {
  input cfg : Map[String, Unknown]
  compute open = unwrap_or(map_get(cfg, "x"), "")
  compute valid = open ++ "tail"
  compute result = 1
  output result : Integer
}
