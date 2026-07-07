module Proof.ElseIfChain

contract ChainInner {
  input x: Integer

  compute y = if x > 5 { if x == 6 { 1 } else { if x == 7 { 2 } else { 3 } } } else { 0 }

  output y: Integer
}
