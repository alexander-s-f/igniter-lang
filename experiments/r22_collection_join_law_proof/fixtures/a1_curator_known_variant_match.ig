module Curator.R22
variant V {
  Off {}
  On {}
}
pure contract Test {
  input value : V
  compute result = match value {
    Off {} => 1
    On {} => 2
  }
  output result : Integer
}
