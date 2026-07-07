module Proof.ElseIfChain

contract ChainTwo {
  input x: Integer

  compute y = if x == 0 { 10 } else { if x == 1 { 20 } else { 30 } }

  output y: Integer
}
