module R22A1.F2e
pure contract Zero {
  input a : Integer
  compute b = a
}
pure contract O {
  input seed : Integer
  compute r = call_contract("Zero", seed)
  compute o : Integer = seed
  output o : Integer
}
