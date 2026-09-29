module R22A1.Cport
pure contract O {
  input xs : Collection[Integer]
  input name : String
  compute r = call_contract(name, xs)
  output r : Integer
}
