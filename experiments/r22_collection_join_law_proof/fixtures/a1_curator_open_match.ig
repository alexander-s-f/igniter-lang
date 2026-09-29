module Curator.R22
variant V {
  Off {}
  On {}
}
pure contract Test {
  input cfg : Map[String, Unknown]
  compute open = unwrap_or(map_get(cfg, "x"), 0)
  compute result = match open {
    Off {} => 1
    _ => 2
  }
  output result : Integer
}
