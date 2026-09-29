module A2.c1or_elserecordoutput
pure contract U {
  input seed : Integer
  compute rec = { x: seed }
  compute v = or_else(rec, 1)
  output v : Integer
}
