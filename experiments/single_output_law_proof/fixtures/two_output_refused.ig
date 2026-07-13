module LawTwoOut

contract TwoOut {
  input a : Integer
  compute x = a + 1
  compute y = a + 2
  output x : Integer
  output y : Integer
}
