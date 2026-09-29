module A2.c1unwrap_orrecordoutput
pure contract U {
  input seed : Integer
  compute rec = { x: seed }
  compute v = unwrap_or(rec, 1)
  output v : Integer
}
