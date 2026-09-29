module R22A1.F2f
pure contract One {
  input a : Integer
  compute b = a
  output b : Integer
}
pure contract O {
  input seed : Integer
  compute r = call_contract("One", seed)
  compute c = r + 1
  compute o : Integer = c
  output o : Integer
}
