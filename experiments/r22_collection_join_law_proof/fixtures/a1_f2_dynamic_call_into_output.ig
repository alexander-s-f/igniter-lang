module R22A1.F2d
pure contract O {
  input seed : Integer
  input name : String
  compute r = call_contract(name, seed)
  output r : Integer
}
