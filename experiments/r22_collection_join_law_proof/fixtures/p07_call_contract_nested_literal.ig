-- REVIEW probe p07: nested array literal argument against Collection[Collection[Integer]]
module R22Review.P07
contract Callee {
  input xss : Collection[Collection[Integer]]
  compute n = count(xss)
  output n : Integer
}
pure contract O {
  input seed : Integer
  compute a = call_contract("Callee", [["a"]])
  compute o : Integer = seed
  output o : Integer
}
