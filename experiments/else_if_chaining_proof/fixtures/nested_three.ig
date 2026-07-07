module Proof.ElseIfChain

contract ChainThree {
  input x: Integer

  compute y = if x == 0 { 10 } else { if x == 1 { 20 } else { if x == 2 { 30 } else { 40 } } }

  output y: Integer
}
